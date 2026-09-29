--!strict
-- Base displays on the client: hides other players' pedestal prompts, and shows the relic
-- picker when the server opens it for an empty pedestal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared:WaitForChild("Config"):WaitForChild("Palette"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local RARITY_COLORS = Palette.Rarity

local BaseController = {}

local localPlayer = Players.LocalPlayer

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

-- Prompts are enabled locally only on your own pedestals.
local function filterPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		local owner = instance:GetAttribute("OwnerUserId")
		if owner ~= nil then
			instance.Enabled = owner == localPlayer.UserId
		end
	end
end

function BaseController.start()
	local bases = Workspace:WaitForChild("Bases")
	for _, descendant in bases:GetDescendants() do
		filterPrompt(descendant)
	end
	bases.DescendantAdded:Connect(filterPrompt)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DisplayPicker"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 360)
	panel.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
	panel.BackgroundTransparency = 0.05
	corner(panel)
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Choose a relic to display"
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -80, 0, 28)
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Font = Enum.Font.GothamBlack
	close.Text = "X"
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
	close.Position = UDim2.new(1, -48, 0, 12)
	close.Size = UDim2.fromOffset(36, 30)
	corner(close)
	close.Parent = panel
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -68)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local chooseRemote = Remotes.get("ChooseDisplay")
	Remotes.get("OpenDisplayPicker").OnClientEvent:Connect(function(slot: string, items: { Types.DisplayItem })
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for _, item in items do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -8, 0, 40)
			row.BackgroundColor3 = Color3.fromRGB(28, 36, 46)
			row.Font = Enum.Font.GothamBold
			row.TextScaled = true
			row.TextColor3 = RARITY_COLORS[item.rarity] or Color3.new(1, 1, 1)
			row.Text = `{item.name}  ({item.rarity})`
			corner(row)
			row.Parent = list
			row.Activated:Connect(function()
				chooseRemote:FireServer(slot, item.id)
				gui.Enabled = false
			end)
		end
		gui.Enabled = true
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return BaseController
