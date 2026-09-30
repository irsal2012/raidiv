--!strict
-- Studio-only test shortcuts: P grants Coins and Pearls, K summons the Warden in your room (see server DevService, which enforces
-- Studio-only on its side too). Does nothing in the published game.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))

local DevController = {}

function DevController.start()
	if not RunService:IsStudio() then
		return
	end
	local grant = Remotes.get("DevGrant")
	ContextActionService:BindAction("DevGrant", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			grant:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)

	local summon = Remotes.get("DevWarden")
	ContextActionService:BindAction("DevWarden", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			summon:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.K)
end

return DevController
