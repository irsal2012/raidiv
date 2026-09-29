--!strict
-- Gear Locker panel. Opens when the server says so (the player used the locker prompt),
-- closes on X or when a dive starts. Buying is validated on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Gear = require(Shared:WaitForChild("Config"):WaitForChild("Gear"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local ROW_HEIGHT = 52
local AFFORDABLE_COLOR = Color3.fromRGB(40, 160, 80)
local DISABLED_COLOR = Color3.fromRGB(70, 75, 80)

local UpgradeController = {}

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

local function button(parent: Instance, text: string, position: UDim2, size: UDim2): TextButton
	local textButton = Instance.new("TextButton")
	textButton.Font = Enum.Font.GothamBlack
	textButton.TextColor3 = Color3.new(1, 1, 1)
	textButton.TextScaled = true
	textButton.Text = text
	textButton.Position = position
	textButton.Size = size
	textButton.BackgroundColor3 = DISABLED_COLOR
	corner(textButton)
	textButton.Parent = parent
	return textButton
end

type Row = { info: TextLabel, buy: TextButton }

function UpgradeController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Upgrades"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 90 + #Gear.Shop * ROW_HEIGHT)
	panel.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
	panel.BackgroundTransparency = 0.1
	corner(panel)
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, math.huge)
	sizeLimit.Parent = panel

	label(panel, "Gear Locker", UDim2.fromOffset(16, 12), UDim2.new(0.5, 0, 0, 30))
	local coinsLabel = label(panel, "Coins: 0", UDim2.new(0.5, 0, 0, 16), UDim2.new(0.5, -60, 0, 24))
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

	local close = button(panel, "X", UDim2.new(1, -48, 0, 12), UDim2.fromOffset(36, 30))
	close.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	local buyRemote = Remotes.get("BuyUpgrade")
	local rows: { [string]: Row } = {}
	for i, key in Gear.Shop do
		local y = 56 + (i - 1) * ROW_HEIGHT
		label(panel, Gear.Tracks[key].displayName, UDim2.fromOffset(16, y + 6), UDim2.new(0.35, -16, 0, 28))
		local info = label(panel, "", UDim2.new(0.35, 0, 0, y + 10), UDim2.new(0.4, 0, 0, 22))
		info.Font = Enum.Font.Gotham
		local buy = button(panel, "", UDim2.new(0.75, 4, 0, y + 4), UDim2.new(0.25, -20, 0, 36))
		buy.Activated:Connect(function()
			buyRemote:FireServer(key)
		end)
		rows[key] = { info = info, buy = buy }
	end

	Remotes.get("ProfileState").OnClientEvent:Connect(function(state: Types.ProfileState)
		coinsLabel.Text = `Coins: {state.coins}`
		for key, row in rows do
			local track = Gear.Tracks[key]
			local level = state.gear[key]
			local current = track.values[level]
			local cost = Gear.nextCost(key, level)
			if cost and level == 0 then
				row.info.Text = `Not owned → {track.values[1]} {track.unit}`
				row.buy.Text = `{cost}`
				row.buy.BackgroundColor3 = if state.coins >= cost then AFFORDABLE_COLOR else DISABLED_COLOR
			elseif cost then
				row.info.Text = `Lv {level} · {current} → {track.values[level + 1]} {track.unit}`
				row.buy.Text = `{cost}`
				row.buy.BackgroundColor3 = if state.coins >= cost then AFFORDABLE_COLOR else DISABLED_COLOR
			else
				row.info.Text = `Lv MAX · {current} {track.unit}`
				row.buy.Text = "MAX"
				row.buy.BackgroundColor3 = DISABLED_COLOR
			end
		end
	end)

	Remotes.get("OpenUpgrades").OnClientEvent:Connect(function()
		gui.Enabled = true
	end)

	Remotes.get("DiveState").OnClientEvent:Connect(function(state: Types.DiveState)
		if state.diving then
			gui.Enabled = false
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return UpgradeController
