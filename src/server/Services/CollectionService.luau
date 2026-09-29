--!strict
-- Collection book: records base and mutated relics on extraction, announces discoveries, and
-- pays milestone rewards once. Rules live in Logic/Collection.luau (unit-tested).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Milestones = require(Shared.Config.Collection)
local Relics = require(Shared.Config.Relics)
local Collection = require(Shared.Logic.Collection)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local CollectionService = {}

local services: any
local stateRemote = Remotes.get("CollectionState")
local notifyRemote = Remotes.get("Notify")

local function sendState(player: Player)
	local profile = services.PlayerDataService.get(player)
	if profile then
		local state: Types.CollectionState = { collection = profile.collection, claimed = profile.collectionRewards }
		stateRemote:FireClient(player, state)
	end
end

local function describe(entry: string): string
	local relicKey, mutation = string.match(entry, "^([^#]+)#?(.*)$")
	local name = Relics.Defs[relicKey :: string].displayName
	return if mutation and mutation ~= "" then `{mutation} {name}` else name
end

-- Call after an extraction with the relics brought up.
function CollectionService.record(player: Player, relics: { Types.RelicInstance })
	local profile = services.PlayerDataService.get(player)
	if not profile then
		return
	end

	local added = Collection.record(profile.collection, relics)
	local found, total, mutations = Collection.progress(Relics, profile.collection)
	for _, entry in added do
		local kind = if string.find(entry, "#", 1, true) then "mutation" else "relic"
		notifyRemote:FireClient(player, `New {kind}: {describe(entry)}! Collection {found}/{total}`)
	end

	for _, milestone in Collection.newMilestones(Milestones, found, total, mutations, profile.collectionRewards) do
		profile.collectionRewards[milestone.id] = true
		services.PlayerDataService.addCoins(player, milestone.coins)
		services.AnalyticsService.economy(player, "Source", milestone.coins, profile.coins, `Collection_{milestone.id}`)
		if milestone.title then
			profile.titles[milestone.title] = true
		end
		local titleText = if milestone.title then ` and the title "{milestone.title}"` else ""
		notifyRemote:FireClient(player, `Collection reward: {milestone.coins} Coins{titleText}!`)
	end

	if #added > 0 then
		sendState(player)
	end
end

function CollectionService.init(allServices: any)
	services = allServices
end

function CollectionService.start()
	local allowRequest = RateLimiter.new(1, 3)
	Remotes.get("RequestCollection").OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sendState(player)
		end
	end)
end

return CollectionService
