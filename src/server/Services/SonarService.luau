--!strict
-- Sonar gear: divers with sonar level 1+ pulse every few seconds, revealing relics within
-- range (through walls) on their own screen. Each pulse makes a small noise.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Config.Gear)
local SonarConfig = require(Shared.Config.Sonar)
local Remotes = require(Shared.Net.Remotes)

local SonarService = {}

local services: any

function SonarService.init(allServices: any)
	services = allServices
end

function SonarService.start()
	local pingRemote = Remotes.get("SonarPing")
	while true do
		task.wait(SonarConfig.IntervalSeconds)
		for _, player in Players:GetPlayers() do
			local session = services.DiveService.getSession(player)
			local profile = services.PlayerDataService.get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not session or session.downed or not profile or not root then
				continue
			end
			local range = Gear.valueAt("sonar", profile.gear.sonar)
			if not range then
				continue -- level 0: not owned
			end
			pingRemote:FireClient(player, services.RelicService.near(root.Position, range, player.UserId))
			services.CreatureService.emitNoise(root.Position, SonarConfig.NoiseRadius)
		end
	end
end

return SonarService
