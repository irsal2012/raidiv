--!strict
-- Phase 1 HUD from plain Instances: DIVE button, oxygen bar, bag weight, toasts.
-- Moves to Fusion components in the Phase 3 UI pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local OxygenConfig = require(Shared:WaitForChild("Config"):WaitForChild("Oxygen"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local TOAST_SECONDS = 2.5
local OXYGEN_COLOR = Color3.fromRGB(70, 200, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(255, 70, 70)

local HudController = {}

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

local function label(parent: Instance, name: string): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Parent = parent
	return text
end

function HudController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local diveButton = Instance.new("TextButton")
	diveButton.Name = "DiveButton"
	diveButton.AnchorPoint = Vector2.new(0.5, 1)
	diveButton.Position = UDim2.new(0.5, 0, 1, -40)
	diveButton.Size = UDim2.fromOffset(200, 64)
	diveButton.BackgroundColor3 = Color3.fromRGB(20, 110, 160)
	diveButton.Font = Enum.Font.GothamBlack
	diveButton.Text = "DIVE"
	diveButton.TextColor3 = Color3.new(1, 1, 1)
	diveButton.TextScaled = true
	corner(diveButton)
	diveButton.Parent = gui
	diveButton.Activated:Connect(function()
		Remotes.get("StartDive"):FireServer()
	end)

	local bar = Instance.new("Frame")
	bar.Name = "OxygenBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 12)
	bar.Size = UDim2.new(0.5, 0, 0, 32)
	bar.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
	bar.BackgroundTransparency = 0.2
	bar.Visible = false
	corner(bar)
	bar.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = OXYGEN_COLOR
	corner(fill)
	fill.Parent = bar

	local oxygenText = label(bar, "Text")
	oxygenText.Size = UDim2.fromScale(1, 1)
	oxygenText.ZIndex = 2

	local bagText = label(gui, "BagText")
	bagText.AnchorPoint = Vector2.new(0.5, 0)
	bagText.Position = UDim2.new(0.5, 0, 0, 48)
	bagText.Size = UDim2.new(0.3, 0, 0, 22)
	bagText.Visible = false

	local toast = label(gui, "Toast")
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.fromScale(0.5, 0.3)
	toast.Size = UDim2.new(0.6, 0, 0, 36)
	toast.TextStrokeTransparency = 0.3
	toast.Visible = false

	Remotes.get("DiveState").OnClientEvent:Connect(function(state: Types.DiveState)
		diveButton.Visible = not state.diving
		bar.Visible = state.diving
		bagText.Visible = state.diving
		if not state.diving then
			return
		end

		local fraction = if state.maxOxygen > 0 then math.clamp(state.oxygen / state.maxOxygen, 0, 1) else 0
		local low = fraction < OxygenConfig.LowOxygenThreshold
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = if low then LOW_OXYGEN_COLOR else OXYGEN_COLOR
		-- Blink "LOW AIR" at 1 Hz. Breathing audio joins in the Phase 3 audio pass.
		local blinkOn = os.clock() % 1 < 0.5
		oxygenText.Text = if low and blinkOn then "LOW AIR" else `O₂ {math.floor(fraction * 100)}%`
		bagText.Text = `Bag {state.weight} / {state.capacity}{if state.lampOn then "" else "   (lamp off)"}`
	end)

	local toastToken = 0
	Remotes.get("Notify").OnClientEvent:Connect(function(message: string)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		task.delay(TOAST_SECONDS, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return HudController
