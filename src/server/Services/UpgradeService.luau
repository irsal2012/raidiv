--!strict
-- Gear upgrades bought at the surface Gear Locker. New levels apply from the next dive,
-- because DiveService reads gear when a dive starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Config.Gear)
local Upgrade = require(Shared.Logic.Upgrade)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

-- Wider than the prompt range so players can step back while the panel is open.
local STATION_RANGE = 20

local UpgradeService = {}

local services: any
local profileStateRemote = Remotes.get("ProfileState")
local notifyRemote = Remotes.get("Notify")

local function sendProfileState(player: Player)
	local profile = services.PlayerDataService.get(player)
	if profile then
		profileStateRemote:FireClient(player, { coins = profile.coins, gear = profile.gear })
	end
end

local function isNear(player: Player, station: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - station.Position).Magnitude <= STATION_RANGE
end

function UpgradeService.init(allServices: any)
	services = allServices
end

function UpgradeService.start()
	local prompt = services.GreyboxService.UpgradePrompt :: ProximityPrompt
	local station = prompt.Parent :: BasePart
	local openRemote = Remotes.get("OpenUpgrades")

	prompt.Triggered:Connect(function(player)
		if services.DiveService.getSession(player) or not isNear(player, station) then
			return
		end
		sendProfileState(player)
		openRemote:FireClient(player)
	end)

	local allowBuy = RateLimiter.new(3, 3)
	Remotes.get("BuyUpgrade").OnServerEvent:Connect(function(player, track)
		if not allowBuy(player) or typeof(track) ~= "string" then
			return
		end
		local profile = services.PlayerDataService.get(player)
		if not profile or services.DiveService.getSession(player) or not isNear(player, station) then
			return
		end

		local levels = profile.gear :: any
		local result, cost = Upgrade.check(Gear, levels, profile.coins, track)
		if result == "ok" and cost then
			services.PlayerDataService.addCoins(player, -cost)
			levels[track] += 1
			services.AnalyticsService.economy(player, "Sink", cost, profile.coins, `Upgrade_{track}_{levels[track]}`)
			services.AnalyticsService.onboardingStep(player, "FirstUpgrade")
			local name = Gear.Tracks[track].displayName
			notifyRemote:FireClient(player, `{name} upgraded to level {levels[track]}. Active on your next dive.`)
		elseif result == "not_enough_coins" then
			notifyRemote:FireClient(player, `Need {cost} Coins`)
		elseif result == "max_level" then
			notifyRemote:FireClient(player, "Already at max level")
		end
		sendProfileState(player)
	end)
end

return UpgradeService
