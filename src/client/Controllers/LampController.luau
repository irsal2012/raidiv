--!strict
-- Lamp toggle input (F / gamepad Y / touch button). The server owns the lamp state and the
-- light itself, because creatures react to it.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local LampController = {}

local lampOn = false

function LampController.start()
	local setLamp = Remotes.get("SetLamp")

	Remotes.get("DiveState").OnClientEvent:Connect(function(state: Types.DiveState)
		lampOn = state.lampOn
	end)

	ContextActionService:BindAction("ToggleLamp", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			setLamp:FireServer(not lampOn)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("ToggleLamp", "Lamp")
	ContextActionService:SetPosition("ToggleLamp", UDim2.new(1, -100, 1, -150))
end

return LampController
