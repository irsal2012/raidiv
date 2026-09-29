--!strict
-- Pings: G / gamepad R1 / touch button marks the spot under the cursor (or screen centre on
-- touch and gamepad). The server labels it and relays it to the squad; markers are local-only.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local SquadConfig = require(Shared:WaitForChild("Config"):WaitForChild("Squad"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local KIND_COLORS: { [string]: Color3 } = {
	relic = Color3.fromRGB(255, 200, 60),
	danger = Color3.fromRGB(255, 60, 60),
	look = Color3.fromRGB(120, 200, 255),
}

local PingController = {}

local localPlayer = Players.LocalPlayer

local function aimPoint(input: InputObject?): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local screen = if input and input.UserInputType == Enum.UserInputType.Keyboard
		then UserInputService:GetMouseLocation()
		else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character :: Instance }
	params.IgnoreWater = true
	local result = Workspace:Raycast(ray.Origin, ray.Direction * SquadConfig.PingRange, params)
	return if result then result.Position else nil
end

local function showMarker(position: Vector3, kind: Types.PingKind, text: string, fromName: string)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position

	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = anchor

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextScaled = true
	textLabel.TextStrokeTransparency = 0.2
	textLabel.TextColor3 = KIND_COLORS[kind]
	textLabel.Text = `◆ {text}\n{fromName}`
	textLabel.Parent = billboard

	anchor.Parent = Workspace
	Debris:AddItem(anchor, SquadConfig.PingSeconds)
end

function PingController.start()
	local pingRemote = Remotes.get("Ping")

	ContextActionService:BindAction("Ping", function(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState == Enum.UserInputState.Begin then
			local point = aimPoint(input)
			if point then
				pingRemote:FireServer(point)
			end
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)
	ContextActionService:SetTitle("Ping", "Ping")
	ContextActionService:SetPosition("Ping", UDim2.new(1, -170, 1, -150))

	Remotes.get("PingShown").OnClientEvent:Connect(showMarker)
end

return PingController
