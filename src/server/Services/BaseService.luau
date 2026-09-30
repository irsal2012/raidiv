--!strict
-- Personal bases: each player gets a surface plot with display pedestals. Owners move unsold
-- relics from their inventory onto pedestals and back; anyone can walk over and look.
-- Displayed relics live in profile.base.displays and are not in the inventory, so selling
-- never touches them. Pedestal prompts carry an OwnerUserId attribute; BaseController hides
-- other players' prompts on each client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Palette = require(Shared.Config.Palette)
local Types = require(Shared.Types)
local BaseConfig = require(Shared.Config.Base)
local Monetization = require(Shared.Config.Monetization)
local Relics = require(Shared.Config.Relics)
local RelicArt = require(script.Parent.Parent.Util.RelicArt)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local RARITY_COLORS = Palette.Rarity

type Plot = {
	index: number,
	center: Vector3,
	owner: Player?,
	model: Model?,
	pedestals: { [string]: BasePart },
}

local BaseService = {}

local services: any
local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local folder: Folder
local notifyRemote = Remotes.get("Notify")

local function relicLabel(relic: Types.RelicInstance): string
	local name = Relics.Defs[relic.relicKey].displayName
	return if relic.mutation then `{relic.mutation} {name}` else name
end

local function pedestalOffset(slot: number, slots: number): Vector3
	-- Rows of five, centred on the plot and nudged away from the sign at the front edge.
	local column = (slot - 1) % 5
	local row = math.floor((slot - 1) / 5)
	local rows = math.ceil(slots / 5)
	return Vector3.new(-10 + column * 5, 0, 1.5 + (row - (rows - 1) / 2) * 6)
end

local function slotCount(player: Player): number
	local extra = if services.MonetizationService.owns(player, "DeluxeBase")
		then Monetization.DeluxeBaseExtraSlots
		else 0
	return BaseConfig.Slots + extra
end

-- Shows (or clears) the relic on one pedestal.
local function renderSlot(plot: Plot, slot: string, relic: Types.RelicInstance?)
	local pedestal = plot.pedestals[slot]
	local old = pedestal:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	if not relic then
		prompt.ActionText = "Display a relic"
		return
	end
	prompt.ActionText = "Take back"

	local def = Relics.Defs[relic.relicKey]
	local display = Instance.new("Part")
	display.Name = "Display"
	display.Anchored = true
	display.CanCollide = false
	display.Size = Vector3.one * (1 + def.weight * 0.3)
	display.Shape = (Enum.PartType :: any)[def.shape or "Block"]
	display.CFrame = CFrame.new(pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + display.Size.Y / 2 + 0.2, 0))
	display.Color = RARITY_COLORS[def.rarity]
	display.Material = if relic.mutation then Enum.Material.Neon else Enum.Material.SmoothPlastic
	display.Transparency = 1 -- anchors the label; the model is the look
	local art = RelicArt.build(relic.relicKey, relic.mutation, display.Size.X, false)
	art:PivotTo(display.CFrame)
	art.Parent = display

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 40
	billboard.Parent = display
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = RARITY_COLORS[def.rarity]
	text.Text = relicLabel(relic)
	text.Parent = billboard

	display.Parent = pedestal
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= BaseConfig.PedestalRange
end

local function onPedestal(player: Player, plot: Plot, slot: string)
	local profile = services.PlayerDataService.get(player)
	if plot.owner ~= player or not profile or not isNear(player, plot.pedestals[slot]) then
		return
	end

	local displayed = profile.base.displays[slot]
	if displayed then
		profile.base.displays[slot] = nil
		table.insert(profile.inventory, displayed)
		renderSlot(plot, slot, nil)
		notifyRemote:FireClient(player, `{relicLabel(displayed)} is back in your bag of unsold relics`)
		return
	end

	if #profile.inventory == 0 then
		notifyRemote:FireClient(player, "No unsold relics to display. Keep some instead of selling them!")
		return
	end
	local items: { Types.DisplayItem } = {}
	for _, relic in profile.inventory do
		table.insert(
			items,
			{ id = relic.id, name = relicLabel(relic), rarity = Relics.Defs[relic.relicKey].rarity :: string }
		)
	end
	Remotes.get("OpenDisplayPicker"):FireClient(player, slot, items)
end

local function buildPlot(plot: Plot, owner: Player, profile: Types.Profile)
	local model = Instance.new("Model")
	model.Name = `Base_{owner.Name}`

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(BaseConfig.PlotSize, 1, BaseConfig.PlotSize)
	floor.CFrame = CFrame.new(plot.center + Vector3.new(0, 0.5, 0))
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(150, 120, 85)
	floor.Parent = model
	model.PrimaryPart = floor

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = Vector3.new(14, 3, 0.5)
	sign.CFrame = CFrame.new(plot.center + Vector3.new(0, 5, -BaseConfig.PlotSize / 2 + 1))
	sign.Color = Color3.fromRGB(40, 50, 60)
	sign.Parent = model
	-- Two posts from the floor up to the sign.
	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Anchored = true
		post.Size = Vector3.new(0.6, 5, 0.6)
		post.CFrame = sign.CFrame * CFrame.new(side * 6, -2.5, 0.6)
		post.Material = Enum.Material.WoodPlanks
		post.Color = Color3.fromRGB(95, 75, 55)
		post.Parent = model
	end
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front -- faces -Z, toward the dock
	signGui.PixelsPerStud = 40
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.BackgroundTransparency = 1
	signText.Size = UDim2.fromScale(1, 1)
	signText.Font = Enum.Font.GothamBlack
	signText.TextScaled = true
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.Text = `{owner.DisplayName}'s Base`
	signText.Parent = signGui

	plot.pedestals = {}
	local slots = slotCount(owner) -- may yield once per session (game pass check)
	for i = 1, slots do
		local slot = tostring(i)
		local pedestal = Instance.new("Part")
		pedestal.Name = `Pedestal{slot}`
		pedestal.Anchored = true
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(3, 3, 3)
		-- Cylinders run along X; stand it up.
		pedestal.CFrame = CFrame.new(plot.center + pedestalOffset(i, slots) + Vector3.new(0, 2.5, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		pedestal.Color = Color3.fromRGB(200, 200, 205)
		pedestal.Material = Enum.Material.Marble
		pedestal.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = `Pedestal {slot}`
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt:SetAttribute("OwnerUserId", owner.UserId)
		prompt.Parent = pedestal
		prompt.Triggered:Connect(function(player)
			onPedestal(player, plot, slot)
		end)

		plot.pedestals[slot] = pedestal
	end

	model.Parent = folder
	plot.model = model
	plot.owner = owner
	plotOf[owner] = plot

	for slot, relic in profile.base.displays do
		if plot.pedestals[slot] then
			renderSlot(plot, slot, relic)
		end
	end
	for slot in plot.pedestals do
		if not profile.base.displays[slot] then
			renderSlot(plot, slot, nil)
		end
	end
end

-- Center of the player's plot, or nil if they don't have one.
function BaseService.plotCenter(player: Player): Vector3?
	local plot = plotOf[player]
	return plot and plot.center
end

-- Rebuilds the player's plot in place, e.g. after buying Deluxe Base.
function BaseService.rebuild(player: Player)
	local plot = plotOf[player]
	local profile = services.PlayerDataService.get(player)
	if not plot or not profile then
		return
	end
	if plot.model then
		plot.model:Destroy()
		plot.model = nil
	end
	buildPlot(plot, player, profile)
end

local function onProfileLoaded(player: Player, profile: Types.Profile)
	for _, plot in plots do
		if not plot.owner then
			buildPlot(plot, player, profile)
			return
		end
	end
	notifyRemote:FireClient(player, "No free base plots in this server")
end

function BaseService.init(allServices: any)
	services = allServices
	for row = 0, BaseConfig.Rows - 1 do
		for column = 0, BaseConfig.PlotsPerRow - 1 do
			local x = (column - (BaseConfig.PlotsPerRow - 1) / 2) * BaseConfig.PlotSpacing
			local z = BaseConfig.FirstRowZ + row * BaseConfig.RowSpacing
			table.insert(plots, {
				index = #plots + 1,
				center = Vector3.new(x, services.GreyboxService.SurfaceY, z),
				pedestals = {},
			})
		end
	end
	-- Created here, not in start(): a profile may finish loading before this service starts.
	folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = Workspace
	services.PlayerDataService.onProfileLoaded(onProfileLoaded)
end

function BaseService.start()
	local allowChoose = RateLimiter.new(3, 3)
	Remotes.get("ChooseDisplay").OnServerEvent:Connect(function(player, slot, relicId)
		if not allowChoose(player) or typeof(slot) ~= "string" or typeof(relicId) ~= "string" then
			return
		end
		local plot = plotOf[player]
		local profile = services.PlayerDataService.get(player)
		if not plot or not profile or not plot.pedestals[slot] or profile.base.displays[slot] then
			return
		end
		if not isNear(player, plot.pedestals[slot]) then
			return
		end
		for i, relic in profile.inventory do
			if relic.id == relicId then
				table.remove(profile.inventory, i)
				profile.base.displays[slot] = relic
				renderSlot(plot, slot, relic)
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local plot = plotOf[player]
		if plot then
			plotOf[player] = nil
			plot.owner = nil
			if plot.model then
				plot.model:Destroy()
				plot.model = nil
			end
			plot.pedestals = {}
		end
	end)
end

return BaseService
