--!strict
-- Phase 1 HUD from plain Instances: DIVE button, oxygen bar, bag weight, toasts, coins.
-- Moves to Fusion components in the Phase 3 UI pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local OxygenConfig = require(Shared:WaitForChild("Config"):WaitForChild("Oxygen"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local TOAST_SECONDS = 2.5
local OXYGEN_COLOR = Color3.fromRGB(70, 200, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(255, 70, 70)
local COIN_GOLD = Color3.fromRGB(255, 205, 60)
local GAIN_COLOR = Color3.fromRGB(110, 230, 120)
local SPEND_COLOR = Color3.fromRGB(255, 110, 100)

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
		if state.downed then
			fill.BackgroundColor3 = LOW_OXYGEN_COLOR
			oxygenText.Text = `DOWN! Squadmate revive: {math.ceil(state.downedSecondsLeft)}s`
		else
			oxygenText.Text = if low and blinkOn then "LOW AIR" else `O₂ {math.floor(fraction * 100)}%`
		end
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

	-- Coin counter at the bottom of the left button column, under SHOP (doc/07 §5). It mirrors
	-- leaderstats.Coins, which the server updates on every change (PlayerDataService.addCoins).
	local coinPanel = Instance.new("Frame")
	coinPanel.Name = "Coins"
	coinPanel.Position = UDim2.new(0, 16, 0.5, 80)
	coinPanel.Size = UDim2.fromOffset(150, 40)
	coinPanel.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
	coinPanel.BackgroundTransparency = 0.25
	corner(coinPanel)
	coinPanel.Parent = gui

	local coin = Instance.new("Frame")
	coin.Name = "Icon"
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 6, 0.5, 0)
	coin.Size = UDim2.fromOffset(28, 28)
	coin.BackgroundColor3 = COIN_GOLD
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = coin
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(190, 140, 30)
	rim.Thickness = 2
	rim.Parent = coin
	coin.Parent = coinPanel
	local coinMark = label(coin, "Mark")
	coinMark.Size = UDim2.fromScale(1, 1)
	coinMark.Font = Enum.Font.GothamBlack
	coinMark.TextColor3 = Color3.fromRGB(150, 100, 20)
	coinMark.Text = "C"

	local coinText = label(coinPanel, "Amount")
	coinText.Position = UDim2.new(0, 42, 0, 6)
	coinText.Size = UDim2.new(1, -50, 1, -12)
	coinText.TextXAlignment = Enum.TextXAlignment.Left
	coinText.TextColor3 = COIN_GOLD
	coinText.Text = "0"

	-- "+230" / "-250" drifts up beside the counter and fades.
	local function showDelta(delta: number)
		local float = label(gui, "CoinDelta")
		float.Position = coinPanel.Position + UDim2.fromOffset(158, 8)
		float.Size = UDim2.fromOffset(90, 24)
		float.TextXAlignment = Enum.TextXAlignment.Left
		float.TextColor3 = if delta > 0 then GAIN_COLOR else SPEND_COLOR
		float.TextStrokeTransparency = 0.4
		float.Text = (if delta > 0 then "+" else "") .. Format.coins(delta)
		local tween = TweenService:Create(
			float,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = float.Position - UDim2.fromOffset(0, 30), TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tween.Completed:Once(function()
			float:Destroy()
		end)
		tween:Play()
	end

	task.spawn(function()
		local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats")
		local coins = leaderstats:WaitForChild("Coins") :: IntValue
		local shown = coins.Value
		coinText.Text = Format.coins(shown)
		coins.Changed:Connect(function()
			local delta = coins.Value - shown
			shown = coins.Value
			coinText.Text = Format.coins(shown)
			if delta ~= 0 then
				showDelta(delta)
			end
		end)
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return HudController
