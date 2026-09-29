--!strict
-- Squad pings: a player marks a spot and their squad sees it. The server decides what the
-- ping is (relic / danger / look) from world state, so clients can't fake labels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SquadConfig = require(Shared.Config.Squad)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local RELIC_RADIUS = 4
local DANGER_RADIUS = 12

local PingService = {}

local services: any

local function isFiniteVector(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or math.abs(n) == math.huge then
			return false
		end
	end
	return true
end

function PingService.init(allServices: any)
	services = allServices
end

function PingService.start()
	local pingShownRemote = Remotes.get("PingShown")
	local allowPing = RateLimiter.new(1, 3)

	Remotes.get("Ping").OnServerEvent:Connect(function(player, position)
		if not allowPing(player) or typeof(position) ~= "Vector3" or not isFiniteVector(position) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - position).Magnitude > SquadConfig.PingRange then
			return
		end

		local kind, label = "look", "Look here"
		if services.CreatureService.isNear(position, DANGER_RADIUS) then
			kind, label = "danger", "DANGER"
		else
			local relicName = services.RelicService.nameNear(position, RELIC_RADIUS)
			if relicName then
				kind, label = "relic", relicName
			end
		end

		for _, member in services.SquadService.members(player) do
			pingShownRemote:FireClient(member, position, kind, label, player.DisplayName)
		end
	end)
end

return PingService
