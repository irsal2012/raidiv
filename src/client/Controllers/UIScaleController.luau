--!strict
-- Scales the game's screens to the viewport so panels fit phones (mobile-first, doc/02 §4.7).
-- Layouts are authored at 720 px tall; a landscape phone is ~360 px, so everything shrinks,
-- but never below MIN_SCALE so buttons stay tappable. Only our own ScreenGuis are touched:
-- Roblox's TouchGui and ContextActionGui also live in PlayerGui and must keep their size.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DESIGN_HEIGHT = 720
local MIN_SCALE = 0.7
local MAX_SCALE = 1.15

local OUR_GUIS = {
	Hud = true,
	Upgrades = true,
	Squad = true,
	Collection = true,
	DisplayPicker = true,
	Tutorial = true,
	Sonar = true,
	Shop = true,
}

local UIScaleController = {}

local scales: { UIScale } = {}

local function currentScale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else DESIGN_HEIGHT
	return math.clamp(height / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)
end

local function attach(gui: Instance)
	if not gui:IsA("ScreenGui") or not OUR_GUIS[gui.Name] or gui:FindFirstChildOfClass("UIScale") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Scale = currentScale()
	scale.Parent = gui
	table.insert(scales, scale)
end

function UIScaleController.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in playerGui:GetChildren() do
		attach(gui)
	end
	playerGui.ChildAdded:Connect(attach)

	local function refresh()
		local value = currentScale()
		for _, scale in scales do
			scale.Scale = value
		end
	end
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return UIScaleController
