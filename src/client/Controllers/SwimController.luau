--!strict
-- Sprint input and vertical swimming. Swimming itself is Roblox's native Terrain-water swimming
-- for Phase 1; the server sets WalkSpeed from gear, load and sprint. Hold Shift / L3 / the touch
-- button to sprint. X / B / touch drops the heaviest carried relic.
--
-- Native swimming floats an idle diver up to the surface and only goes down if you aim the
-- camera down. While diving, a LinearVelocity on the root takes over the vertical axis: Space /
-- A rises, C / Ctrl / L2 sinks, moving follows the camera's pitch, and otherwise the diver hovers.
-- The character is client-owned, so this runs here; the anti-cheat only checks horizontal speed.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

-- Vertical speed as a fraction of WalkSpeed, so fins, load and sprint all apply.
local VERTICAL_SPEED_FACTOR = 0.8

local SwimController = {}

local localPlayer = Players.LocalPlayer
local rising = false
local sinking = false
local diving = false
local downed = false

-- Begin -> true, End/Cancel -> false. Ignores Change, which analog triggers send while held.
local function heldState(inputState: Enum.UserInputState, current: boolean): boolean
	if inputState == Enum.UserInputState.Begin then
		return true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		return false
	end
	return current
end

local function bindVertical()
	ContextActionService:BindAction("SwimUp", function(_, inputState: Enum.UserInputState)
		rising = heldState(inputState, rising)
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("SwimUp", "Up")
	ContextActionService:SetPosition("SwimUp", UDim2.new(1, -240, 1, -210))

	ContextActionService:BindAction("SwimDown", function(_, inputState: Enum.UserInputState)
		sinking = heldState(inputState, sinking)
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("SwimDown", "Down")
	ContextActionService:SetPosition("SwimDown", UDim2.new(1, -240, 1, -150))
end

local function unbindVertical()
	ContextActionService:UnbindAction("SwimUp")
	ContextActionService:UnbindAction("SwimDown")
	rising = false
	sinking = false
end

-- The constraint lives on the current character's root; rebuilt after respawn.
local function getMover(root: BasePart): LinearVelocity
	local mover = root:FindFirstChild("SwimMover") :: LinearVelocity?
	if mover then
		return mover
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SwimAttachment"
	attachment.Parent = root
	local created = Instance.new("LinearVelocity")
	created.Name = "SwimMover"
	created.Attachment0 = attachment
	created.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	created.LineDirection = Vector3.yAxis
	created.RelativeTo = Enum.ActuatorRelativeTo.World
	created.MaxForce = math.huge
	created.Enabled = false
	created.Parent = root
	return created
end

local function updateVertical()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local mover = getMover(root)
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	if not diving or downed or not swimming or humanoid.Health <= 0 then
		mover.Enabled = false
		return
	end

	local speed = humanoid.WalkSpeed * VERTICAL_SPEED_FACTOR
	local vertical = 0
	if rising ~= sinking then
		vertical = if rising then speed else -speed
	elseif humanoid.MoveDirection.Magnitude > 0.1 then
		-- Moving forward while looking down swims down, and looking up swims up.
		local look = (Workspace.CurrentCamera :: Camera).CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			local forward = humanoid.MoveDirection:Dot(flat.Unit)
			vertical = look.Y * forward * humanoid.WalkSpeed
		end
	end
	mover.LineVelocity = vertical
	mover.Enabled = true
end

function SwimController.start()
	local setSprint = Remotes.get("SetSprint")

	ContextActionService:BindAction("Sprint", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			setSprint:FireServer(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			setSprint:FireServer(false)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Sprint")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -90))

	-- Drop the heaviest relic: the way to shake a Warden, or lighten up for a sprint.
	local dropRelic = Remotes.get("DropRelic")
	ContextActionService:BindAction("DropRelic", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			dropRelic:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("DropRelic", "Drop")
	ContextActionService:SetPosition("DropRelic", UDim2.new(1, -240, 1, -90))

	-- Up / Down (and their touch buttons) exist only during a dive.
	Remotes.get("DiveState").OnClientEvent:Connect(function(state: Types.DiveState)
		downed = state.downed
		if state.diving ~= diving then
			diving = state.diving
			if diving then
				bindVertical()
			else
				unbindVertical()
			end
		end
	end)

	RunService.PreSimulation:Connect(updateVertical)
end

return SwimController
