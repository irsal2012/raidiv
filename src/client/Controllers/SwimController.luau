--!strict
-- Sprint input. Swimming itself is Roblox's native Terrain-water swimming for Phase 1;
-- the server sets WalkSpeed from gear, load and sprint. Hold Shift / L3 / the touch button.
-- X / B / touch drops the heaviest carried relic.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))

local SwimController = {}

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
end

return SwimController
