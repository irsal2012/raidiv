--!strict
-- Phase 1: in-memory profiles only; nothing saves. Phase 2 swaps the internals for
-- ProfileStore and keeps this API: get(player), addCoins(player, amount).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = {}

local profiles: { [Player]: Types.Profile } = {}

local function newProfile(): Types.Profile
	return {
		version = 1,
		coins = 0,
		pearls = 0,
		level = 1,
		xp = 0,
		gear = { tank = 1, fins = 1, lamp = 1, bag = 1, sonar = 0, suit = 1 },
		inventory = {},
		base = { displays = {} },
		collection = {},
		cosmetics = { owned = {}, equipped = {} },
		purchases = {},
		stats = { dives = 0, extractions = 0, deaths = 0 },
	}
end

local function onPlayerAdded(player: Player)
	profiles[player] = newProfile()

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

function PlayerDataService.get(player: Player): Types.Profile?
	return profiles[player]
end

function PlayerDataService.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.coins += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value = profile.coins
	end
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if not profiles[player] then
			onPlayerAdded(player)
		end
	end
end

return PlayerDataService
