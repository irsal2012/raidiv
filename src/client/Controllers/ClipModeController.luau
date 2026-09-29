--!strict
-- Clip mode (doc/05 §5.2): H hides all game UI and Roblox's core UI so players can record
-- clean clips; H again restores it. Our ScreenGuis are parked (parent = nil) rather than
-- disabled, because controllers toggle Enabled themselves and would fight over it.
-- Mobile touch controls stay, so the player can still move.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local HIDDEN_GUIS = {
	Hud = true,
	Upgrades = true,
	Squad = true,
	Collection = true,
	DisplayPicker = true,
	Tutorial = true,
	Sonar = true,
	Shop = true,
	ContextActionGui = true, -- Roblox's action buttons (Sprint, Lamp, Ping, Drop)
}

local ClipModeController = {}

local parked: { ScreenGui } = {}
local active = false

local function setCoreGui(enabled: boolean)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, enabled)
	pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", enabled)
end

local function toggle()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	active = not active
	if active then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and HIDDEN_GUIS[gui.Name] then
				table.insert(parked, gui)
				gui.Parent = nil
			end
		end
		setCoreGui(false)
	else
		for _, gui in parked do
			gui.Parent = playerGui
		end
		table.clear(parked)
		setCoreGui(true)
	end
end

function ClipModeController.start()
	ContextActionService:BindAction("ClipMode", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H)
end

return ClipModeController
