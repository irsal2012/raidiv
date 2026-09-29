--!strict
-- Collection book panel: a BOOK button next to SQUAD. Each Harbor relic is a card (name and
-- rarity, or "???" until found) with its mutations lit once found, plus milestone progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = Shared:WaitForChild("Config")
local Relics = require(Config:WaitForChild("Relics"))
local Milestones = require(Config:WaitForChild("Collection"))
local Collection = require(Shared:WaitForChild("Logic"):WaitForChild("Collection"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(85, 200, 110),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}
local UNFOUND = Color3.fromRGB(60, 65, 70)
local PANEL = Color3.fromRGB(15, 22, 30)

local CollectionController = {}

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text
	textLabel.Position = position
	textLabel.Size = size
	textLabel.Parent = parent
	return textLabel
end

-- Relic keys sorted by rarity, then name, so the book reads Common -> Legendary.
local function sortedRelicKeys(): { string }
	local keys = {}
	for key in Relics.Defs do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ra = table.find(Relics.RarityOrder, Relics.Defs[a].rarity) :: number
		local rb = table.find(Relics.RarityOrder, Relics.Defs[b].rarity) :: number
		return if ra ~= rb then ra < rb else Relics.Defs[a].displayName < Relics.Defs[b].displayName
	end)
	return keys
end

function CollectionController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Collection"
	gui.ResetOnSpawn = false

	local openButton = Instance.new("TextButton")
	openButton.Font = Enum.Font.GothamBlack
	openButton.Text = "BOOK"
	openButton.TextScaled = true
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
	openButton.Position = UDim2.fromOffset(134, 80)
	openButton.Size = UDim2.fromOffset(100, 40)
	corner(openButton)
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(540, 440)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	corner(panel)
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(540, 440)
	sizeLimit.Parent = panel

	local title = label(panel, "Harbor Collection", UDim2.fromOffset(16, 12), UDim2.new(1, -80, 0, 30))
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
		panel.Visible = false
	end)

	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(16, 52)
	grid.Size = UDim2.new(1, -32, 1, -150)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(158, 78)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local milestoneText = label(panel, "", UDim2.new(0, 16, 1, -92), UDim2.new(1, -32, 0, 80))
	milestoneText.TextScaled = false
	milestoneText.TextSize = 15
	milestoneText.Font = Enum.Font.Gotham
	milestoneText.TextYAlignment = Enum.TextYAlignment.Top

	local relicKeys = sortedRelicKeys()

	local function render(state: Types.CollectionState)
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		for order, key in relicKeys do
			local def = Relics.Defs[key]
			local found = state.collection[key] == true
			local card = Instance.new("Frame")
			card.LayoutOrder = order
			card.BackgroundColor3 = Color3.fromRGB(28, 36, 46)
			corner(card)
			card.Parent = grid

			local strip = Instance.new("Frame")
			strip.BorderSizePixel = 0
			strip.Size = UDim2.new(0, 6, 1, 0)
			strip.BackgroundColor3 = if found then RARITY_COLORS[def.rarity] else UNFOUND
			strip.Parent = card

			label(card, if found then def.displayName else "???", UDim2.fromOffset(14, 6), UDim2.new(1, -20, 0, 22))
			local rarity = label(card, def.rarity, UDim2.fromOffset(14, 30), UDim2.new(1, -20, 0, 16))
			rarity.Font = Enum.Font.Gotham
			rarity.TextColor3 = if found then RARITY_COLORS[def.rarity] else UNFOUND

			-- Mutation badges: first two letters, lit once that variant has been found.
			for i, mutation in Relics.MutationOrder do
				local badge = label(
					card,
					string.sub(mutation, 1, 2),
					UDim2.fromOffset(14 + (i - 1) * 30, 52),
					UDim2.fromOffset(26, 18)
				)
				badge.TextXAlignment = Enum.TextXAlignment.Center
				badge.TextColor3 = if state.collection[Collection.entryKey(key, mutation)]
					then Color3.fromRGB(255, 230, 120)
					else UNFOUND
			end
		end

		local found, total, mutations = Collection.progress(Relics, state.collection)
		title.Text = `Harbor Collection  {found}/{total}  ·  {mutations} mutations`
		local lines = {}
		for _, milestone in Milestones do
			local mark = if state.claimed[milestone.id] then "✓" else "·"
			local reward = `{milestone.coins} Coins`
				.. (if milestone.pearls then ` + {milestone.pearls} Pearls` else "")
				.. (if milestone.title then ` + "{milestone.title}"` else "")
			table.insert(lines, `{mark} {milestone.label}: {reward}`)
		end
		milestoneText.Text = "Mutations: Gl Glowing · Ba Barnacled · Gi Gilded · Cu Cursed\n"
			.. table.concat(lines, "\n")
	end

	local requestRemote = Remotes.get("RequestCollection")
	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			requestRemote:FireServer()
		end
	end)
	Remotes.get("CollectionState").OnClientEvent:Connect(render)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return CollectionController
