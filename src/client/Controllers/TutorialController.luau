--!strict
-- Tutorial on the client: an objective banner (with Skip), a highlight on whatever the
-- current step points at, and the scripted, harmless creature scare. The server owns the step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TutorialConfig = require(Shared:WaitForChild("Config"):WaitForChild("Tutorial"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local HIGHLIGHT_COLOR = Color3.fromRGB(255, 220, 80)
local REFRESH_SECONDS = 0.5

local TutorialController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local currentStep = "done"

-- World instances and UI buttons the current step points at.
local function targetsFor(step: string): ({ Instance }, { GuiObject })
	local world: { Instance } = {}
	local ui: { GuiObject } = {}
	local function find(parent: Instance?, ...: string): any
		local node = parent
		for _, name in { ... } do
			node = node and node:FindFirstChild(name)
		end
		return node
	end

	if step == "dive" then
		local button = find(playerGui, "Hud", "DiveButton")
		if button then
			table.insert(ui, button :: GuiObject)
		end
	elseif step == "relics" then
		local relics = Workspace:FindFirstChild("Relics")
		for _, part in if relics then relics:GetChildren() else {} do
			if part:GetAttribute("TutorialFor") == localPlayer.UserId then
				table.insert(world, part)
			end
		end
	elseif step == "escape" then
		table.insert(world, find(Workspace, "TutorialCove", "TutorialLadder"))
	elseif step == "sell" then
		table.insert(world, find(Workspace, "Zone", "SellCounter"))
	elseif step == "upgrade" then
		table.insert(world, find(Workspace, "Zone", "GearLocker"))
	elseif step == "base" then
		table.insert(world, find(Workspace, "Bases", `Base_{localPlayer.Name}`))
	elseif step == "squad" then
		local button = find(playerGui, "Squad", "SquadButton")
		if button then
			table.insert(ui, button :: GuiObject)
		end
	end
	return world, ui
end

-- Harmless client-only creature: glides at you out of the dark, then vanishes.
local function playScare()
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return
	end
	local ghost = Instance.new("Part")
	ghost.Name = "TutorialScare"
	ghost.Shape = Enum.PartType.Ball
	ghost.Size = Vector3.one * 7
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.Color = Color3.fromRGB(20, 25, 30)
	ghost.Position = root.Position + camera.CFrame.LookVector * 30
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 18
	light.Brightness = 4
	light.Parent = ghost
	ghost.Parent = Workspace

	local rush = TweenService:Create(
		ghost,
		TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = root.Position + camera.CFrame.LookVector * 6 }
	)
	rush:Play()
	rush.Completed:Once(function()
		local fade = TweenService:Create(ghost, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.one * 12 })
		fade:Play()
		fade.Completed:Once(function()
			ghost:Destroy()
		end)
	end)
end

-- Other players' tutorial relics can't be taken by us, so hide their prompts.
local function filterRelicPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		local owner = instance:GetAttribute("OwnerUserId")
		if owner ~= nil then
			instance.Enabled = owner == localPlayer.UserId
		end
	end
end

function TutorialController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 78)
	banner.Size = UDim2.new(0.5, 0, 0, 44)
	banner.BackgroundColor3 = Color3.fromRGB(20, 70, 110)
	banner.BackgroundTransparency = 0.1
	banner.Parent = gui
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = banner

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(12, 4)
	text.Size = UDim2.new(1, -96, 1, -8)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = banner

	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -8, 0.5, 0)
	skip.Size = UDim2.fromOffset(72, 30)
	skip.BackgroundColor3 = Color3.fromRGB(60, 70, 80)
	skip.Font = Enum.Font.GothamBold
	skip.Text = "Skip"
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Parent = banner
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skip
	skip.Activated:Connect(function()
		Remotes.get("TutorialSkip"):FireServer()
	end)

	Remotes.get("TutorialState").OnClientEvent:Connect(function(step: string, relicsTaken: number)
		currentStep = step
		gui.Enabled = step ~= "done"
		local message = TutorialConfig.Text[step] or ""
		if step == "relics" then
			message ..= ` ({relicsTaken}/{TutorialConfig.RelicCount})`
		end
		text.Text = message
	end)
	Remotes.get("TutorialScare").OnClientEvent:Connect(playScare)

	local relics = Workspace:WaitForChild("Relics")
	for _, descendant in relics:GetDescendants() do
		filterRelicPrompt(descendant)
	end
	relics.DescendantAdded:Connect(filterRelicPrompt)

	-- Highlights follow the current targets. Checked twice a second so streamed-in or
	-- respawned targets get picked up; only changes are applied, so nothing flickers.
	local highlights: { [Instance]: Highlight } = {}
	local strokes: { [GuiObject]: UIStroke } = {}
	task.spawn(function()
		while true do
			local world: { Instance }, ui: { GuiObject } = {}, {}
			if currentStep ~= "done" then
				world, ui = targetsFor(currentStep)
			end
			local wantWorld: { [Instance]: boolean }, wantUi: { [GuiObject]: boolean } = {}, {}
			for _, target in world do
				wantWorld[target] = true
				if not highlights[target] or not highlights[target].Parent then
					local highlight = Instance.new("Highlight")
					highlight.FillColor = HIGHLIGHT_COLOR
					highlight.FillTransparency = 0.6
					highlight.OutlineColor = HIGHLIGHT_COLOR
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Adornee = target
					highlight.Parent = target
					highlights[target] = highlight
				end
			end
			for target, highlight in highlights do
				if not wantWorld[target] then
					highlight:Destroy()
					highlights[target] = nil
				end
			end
			for _, button in ui do
				wantUi[button] = true
				if not strokes[button] then
					local stroke = Instance.new("UIStroke")
					stroke.Color = HIGHLIGHT_COLOR
					stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					stroke.Parent = button
					strokes[button] = stroke
				end
			end
			for button, stroke in strokes do
				if not wantUi[button] then
					stroke:Destroy()
					strokes[button] = nil
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)

	-- Pulse the UI outlines.
	RunService.RenderStepped:Connect(function()
		local thickness = 3 + math.sin(os.clock() * 6) * 2
		for _, stroke in strokes do
			stroke.Thickness = thickness
		end
	end)

	gui.Parent = playerGui
end

return TutorialController
