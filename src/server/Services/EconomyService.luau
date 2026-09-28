--!strict
-- Selling relics for Coins. Prices always come from server config, never the client.
-- Phase 2 adds gear upgrades (Config/Gear.luau costs) and economy analytics events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Relics = require(Shared.Config.Relics)
local Loot = require(Shared.Logic.Loot)
local Remotes = require(Shared.Net.Remotes)

-- Prompt range is 10; the extra covers latency.
local SELL_RANGE = 14

local EconomyService = {}

local services: any
local notifyRemote = Remotes.get("Notify")

local function sellAll(player: Player, counter: BasePart)
	local profile = services.PlayerDataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root or (root.Position - counter.Position).Magnitude > SELL_RANGE then
		return
	end
	if #profile.inventory == 0 then
		notifyRemote:FireClient(player, "Nothing to sell. Go dive!")
		return
	end

	local total = 0
	for _, relic in profile.inventory do
		total += Loot.sellValue(Relics, relic.relicKey, relic.mutation)
	end
	local count = #profile.inventory
	table.clear(profile.inventory)
	services.PlayerDataService.addCoins(player, total)
	services.AnalyticsService.economy(player, "Source", total, profile.coins, "SellRelics")
	services.AnalyticsService.onboardingStep(player, "FirstSale")
	notifyRemote:FireClient(player, `Sold {count} relic(s) for {total} Coins`)
end

function EconomyService.init(allServices: any)
	services = allServices
end

function EconomyService.start()
	local prompt = services.GreyboxService.SellPrompt :: ProximityPrompt
	local counter = prompt.Parent :: BasePart
	prompt.Triggered:Connect(function(player)
		sellAll(player, counter)
	end)
end

return EconomyService
