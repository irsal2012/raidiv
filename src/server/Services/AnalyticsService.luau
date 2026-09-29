--!strict
-- Thin wrapper over Roblox's AnalyticsService (results appear in Creator Hub > Analytics).
-- Every call is pcall-wrapped: analytics must never break gameplay. Roblox ignores events
-- sent from Studio playtests, so data only shows up from the published game.
--
-- What we log (doc/02-tech-stack.md §4.8):
--   Onboarding funnel   Joined -> FirstDive -> FirstRelic -> FirstExtraction -> FirstSale -> FirstUpgrade
--                       Each step logged once per player, ever (tracked in profile.onboarding).
--   Dive results        DiveEnded (value = seconds), DiveLoot (value = Coins carried), DiveDeath (cause)
--                       Field 2 on dive events is squad size ("1".. "4"): target is >= 40% of dives in squads.
--   Squads              Revive (who revived)
--   Economy             Coins sourced by selling, sunk into upgrades

local RobloxAnalytics = game:GetService("AnalyticsService")

local ONBOARDING_STEPS = { "Joined", "FirstDive", "FirstRelic", "FirstExtraction", "FirstSale", "FirstUpgrade" }
local CURRENCY = "Coins"

local AnalyticsService = {}

local services: any

local function safely(fn: () -> ...any)
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

-- Up to three string fields per event; Roblox caps how many distinct values each may have,
-- so only pass small fixed sets (results, causes), never ids or free text.
local function fields(first: string?, second: string?): { [string]: string }
	local result = {}
	if first then
		result[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = first
	end
	if second then
		result[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = second
	end
	return result
end

function AnalyticsService.onboardingStep(player: Player, stepName: string)
	local profile = services.PlayerDataService.get(player)
	local step = table.find(ONBOARDING_STEPS, stepName)
	if not profile or not step or profile.onboarding[stepName] then
		return
	end
	profile.onboarding[stepName] = true
	safely(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function AnalyticsService.diveEnded(
	player: Player,
	result: "extracted" | "died" | "left",
	seconds: number,
	lootValue: number,
	deathCause: string?,
	squadSize: number
)
	local squad = tostring(squadSize)
	safely(function()
		RobloxAnalytics:LogCustomEvent(player, "DiveEnded", math.floor(seconds), fields(result, squad))
		RobloxAnalytics:LogCustomEvent(player, "DiveLoot", lootValue, fields(result, squad))
		if result == "died" then
			RobloxAnalytics:LogCustomEvent(player, "DiveDeath", 1, fields(deathCause or "other", squad))
		end
	end)
end

function AnalyticsService.revived(rescuer: Player)
	safely(function()
		RobloxAnalytics:LogCustomEvent(rescuer, "Revive", 1)
	end)
end

-- `amount` is positive for both flows; `sku` says what it was for (e.g. "SellRelics", "Upgrade_fins_2").
function AnalyticsService.economy(
	player: Player,
	flow: "Source" | "Sink",
	amount: number,
	endingBalance: number,
	sku: string
)
	local flowType = if flow == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local transactionType = if flow == "Source"
		then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		else Enum.AnalyticsEconomyTransactionType.Shop.Name
	safely(function()
		RobloxAnalytics:LogEconomyEvent(player, flowType, CURRENCY, amount, endingBalance, transactionType, sku)
	end)
end

-- Anti-cheat flags ("speed", "teleport", "economy"). Review these before banning anyone.
function AnalyticsService.exploitFlag(player: Player, kind: string)
	safely(function()
		RobloxAnalytics:LogCustomEvent(player, "ExploitFlag", 1, fields(kind))
	end)
end

-- Robux Pearl packs. Logged as an economy source in the premium currency.
function AnalyticsService.pearlsPurchased(player: Player, pearls: number, productId: number)
	local data = services.PlayerDataService.get(player)
	safely(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Pearls",
			pearls,
			if data then data.pearls else pearls,
			Enum.AnalyticsEconomyTransactionType.IAP.Name,
			`PearlPack_{productId}`
		)
	end)
end

function AnalyticsService.init(allServices: any)
	services = allServices
end

return AnalyticsService
