--!strict
-- Sonar markers: brief rarity-coloured dots on relics the server's sonar pulse found,
-- visible through walls, plus a small "SONAR" flash.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared:WaitForChild("Config"):WaitForChild("Palette"))
local Types = require(Shared:WaitForChild("Types"))
local SonarConfig = require(Shared:WaitForChild("Config"):WaitForChild("Sonar"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local RARITY_COLORS = Palette.Rarity

local SonarController = {}

function SonarController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Sonar"
	gui.ResetOnSpawn = false
	local flash = Instance.new("TextLabel")
	flash.AnchorPoint = Vector2.new(1, 0)
	flash.Position = UDim2.new(1, -16, 0, 80)
	flash.Size = UDim2.fromOffset(120, 28)
	flash.BackgroundTransparency = 1
	flash.Font = Enum.Font.GothamBlack
	flash.TextScaled = true
	flash.TextColor3 = Color3.fromRGB(120, 220, 255)
	flash.TextStrokeTransparency = 0.3
	flash.Visible = false
	flash.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.get("SonarPing").OnClientEvent:Connect(function(hits: { Types.SonarHit })
		flash.Text = `SONAR · {#hits}`
		flash.Visible = true
		task.delay(SonarConfig.MarkerSeconds, function()
			flash.Visible = false
		end)

		for _, hit in hits do
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one
			anchor.Position = hit.position

			local billboard = Instance.new("BillboardGui")
			billboard.AlwaysOnTop = true
			billboard.Size = UDim2.fromOffset(18, 18)
			billboard.Parent = anchor
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromScale(1, 1)
			dot.BackgroundColor3 = RARITY_COLORS[hit.rarity] or Color3.new(1, 1, 1)
			dot.Parent = billboard
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = dot

			anchor.Parent = Workspace
			Debris:AddItem(anchor, SonarConfig.MarkerSeconds)
		end
	end)
end

return SonarController
