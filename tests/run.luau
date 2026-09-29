--!strict
-- Lune test runner for pure shared logic: `lune run tests/run`
-- Only modules with no Roblox APIs and no instance-based requires can be tested here.

local process = require("@lune/process")

local Relics = require("../src/shared/Config/Relics")
local Gear = require("../src/shared/Config/Gear")
local Oxygen = require("../src/shared/Config/Oxygen")
local Swim = require("../src/shared/Config/Swim")
local Creatures = require("../src/shared/Config/Creatures")
local Loot = require("../src/shared/Logic/Loot")
local OxygenMath = require("../src/shared/Logic/OxygenMath")
local SwimMath = require("../src/shared/Logic/SwimMath")
local Upgrade = require("../src/shared/Logic/Upgrade")
local Squads = require("../src/shared/Logic/Squads")
local ZoneLayout = require("../src/shared/Logic/ZoneLayout")
local Currents = require("../src/shared/Logic/Currents")
local CurrentsList = require("../src/shared/Config/Currents")
local Collection = require("../src/shared/Logic/Collection")
local CollectionMilestones = require("../src/shared/Config/Collection")
local Tutorial = require("../src/shared/Logic/Tutorial")
local TutorialConfig = require("../src/shared/Config/Tutorial")
local Store = require("../src/shared/Logic/Store")
local CosmeticsCatalog = require("../src/shared/Config/Cosmetics")
local MonetizationConfig = require("../src/shared/Config/Monetization")
local Movement = require("../src/shared/Logic/Movement")
local AntiCheatConfig = require("../src/shared/Config/AntiCheat")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}\n  {err}`)
	end
end

local function expectEq(actual: any, expected: any)
	if actual ~= expected then
		error(`expected {expected}, got {actual}`, 2)
	end
end

local function expectNear(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected ~{expected}, got {actual}`, 2)
	end
end

-- Deterministic rng for tests (LCG), returns floats in [0, 1).
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function fixed(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[i]
	end
end

test("weightedPick hits first and last buckets at the extremes", function()
	expectEq(Loot.weightedPick(Relics.RarityOrder, Relics.RaritySpawnWeights, fixed(0)), "Common")
	expectEq(Loot.weightedPick(Relics.RarityOrder, Relics.RaritySpawnWeights, fixed(0.9999)), "Legendary")
end)

test("rarity distribution roughly matches spawn weights", function()
	local rng = seeded(42)
	local counts: { [string]: number } = {}
	local n = 100000
	for _ = 1, n do
		local r = Loot.weightedPick(Relics.RarityOrder, Relics.RaritySpawnWeights, rng)
		counts[r] = (counts[r] or 0) + 1
	end
	local common = counts.Common / n
	assert(common > 0.58 and common < 0.62, `Common share {common} outside 0.58-0.62`)
end)

test("rollMutation respects MutationChance", function()
	expectEq(Loot.rollMutation(Relics, fixed(Relics.MutationChance)), nil)
	expectEq(Loot.rollMutation(Relics, fixed(0, 0)), "Glowing")
end)

test("rollRelic is deterministic for a seed", function()
	local a = { Loot.rollRelic(Relics, seeded(7)) }
	local b = { Loot.rollRelic(Relics, seeded(7)) }
	expectEq(a[1], b[1])
	expectEq(a[2], b[2])
end)

test("every rarity tier has at least one relic", function()
	for _, rarity in Relics.RarityOrder do
		local found = false
		for _, def in Relics.Defs do
			if def.rarity == rarity then
				found = true
			end
		end
		assert(found, `no relic with rarity {rarity}`)
	end
end)

test("sellValue applies mutation multiplier", function()
	expectEq(Loot.sellValue(Relics, "RustyCompass", nil), 15)
	expectEq(Loot.sellValue(Relics, "RustyCompass", "Gilded"), 45)
end)

test("gear tracks have 5 increasing levels", function()
	for key, track in Gear.Tracks do
		expectEq(#track.values, Gear.MaxLevel)
		expectEq(#track.costs, Gear.MaxLevel)
		for i = 2, Gear.MaxLevel do
			assert(track.values[i] > track.values[i - 1], `{key} values not increasing at {i}`)
			assert(track.costs[i] > track.costs[i - 1], `{key} costs not increasing at {i}`)
		end
	end
end)

test("nextCost is nil at max level", function()
	expectEq(Gear.nextCost("tank", Gear.MaxLevel), nil)
	expectEq(Gear.nextCost("tank", 1), 250)
	expectEq(Gear.nextCost("sonar", 0), 400)
end)

test("sprinting with a load drains faster and never goes negative", function()
	local idle = OxygenMath.drainPerSecond(Oxygen, false, 0)
	local loaded = OxygenMath.drainPerSecond(Oxygen, true, 10)
	assert(loaded > idle, "loaded sprint should drain faster")
	expectEq(OxygenMath.step(Oxygen, 1, 100, true, 10), 0)
end)

test("swim speed drops with load and rises with sprint", function()
	expectEq(SwimMath.speed(Swim, 16, false, 0, 10), 16)
	expectNear(SwimMath.speed(Swim, 16, false, 10, 10), 16 * Swim.FullBagSpeedFactor)
	expectNear(SwimMath.speed(Swim, 16, true, 0, 10), 16 * Swim.SprintMultiplier)
	-- Overloading past capacity is clamped.
	expectNear(SwimMath.speed(Swim, 16, false, 50, 10), 16 * Swim.FullBagSpeedFactor)
end)

test("an unloaded starter diver escapes the Drifter only by sprinting", function()
	local baseSpeed = Gear.valueAt("fins", 1) :: number
	local capacity = Gear.valueAt("bag", 1) :: number
	local chase = Creatures.Drifter.chaseSpeed
	assert(SwimMath.speed(Swim, baseSpeed, false, 0, capacity) < chase, "swimming should not outrun the chase")
	assert(SwimMath.speed(Swim, baseSpeed, true, 0, capacity) > chase, "sprinting should outrun the chase")
end)

test("the Warden catches a full-bag diver but not an unloaded one", function()
	local baseSpeed = Gear.valueAt("fins", 1) :: number
	local capacity = Gear.valueAt("bag", 1) :: number
	local warden = Creatures.Warden.chaseSpeed
	assert(SwimMath.speed(Swim, baseSpeed, false, 0, capacity) > warden, "unloaded swim should outrun the Warden")
	assert(
		SwimMath.speed(Swim, baseSpeed, true, capacity, capacity) < warden,
		"full-bag sprint should not outrun the Warden"
	)
	-- At the top fins level a full bag must still be a liability.
	local topSpeed = Gear.valueAt("fins", Gear.MaxLevel) :: number
	assert(SwimMath.speed(Swim, topSpeed, false, capacity, capacity) < warden, "maxed fins, full bag, no sprint")
end)

test("lamp range fits SpotLight's 60-stud cap", function()
	for _, range in Gear.Tracks.lamp.values do
		assert(range <= 60, `lamp range {range} exceeds 60`)
	end
end)

test("upgrade check covers ok, broke, maxed and unknown tracks", function()
	local levels = { tank = 1, fins = 1, lamp = 1, bag = 1, sonar = 0, suit = 1 }
	local result, cost = Upgrade.check(Gear, levels, 250, "tank")
	expectEq(result, "ok")
	expectEq(cost, 250)
	result, cost = Upgrade.check(Gear, levels, 249, "tank")
	expectEq(result, "not_enough_coins")
	expectEq(cost, 250)
	expectEq((Upgrade.check(Gear, { tank = Gear.MaxLevel }, 1e9, "tank")), "max_level")
	-- Sonar starts unowned (level 0) and costs its first rung; the suit isn't sold yet.
	expectEq((Upgrade.check(Gear, levels, 400, "sonar")), "ok")
	expectEq((Upgrade.check(Gear, levels, 1e9, "suit")), "unknown_track")
	expectEq((Upgrade.check(Gear, levels, 1e9, "rocketboots")), "unknown_track")
end)

test("every shop track has a unit and a full cost ladder", function()
	for _, key in Gear.Shop do
		local track = Gear.Tracks[key]
		assert(track.unit ~= "", `{key} has no unit`)
		expectEq(#track.costs, Gear.MaxLevel)
	end
end)

test("squad invite and accept forms a squad led by the inviter", function()
	local state = Squads.new(4, 60)
	expectEq(Squads.invite(state, 1, 2, 0), "ok")
	expectEq(Squads.accept(state, 2, 1, 10), "ok")
	local members = Squads.members(state, 2)
	expectEq(#members, 2)
	expectEq(members[1], 1)
	assert(Squads.areSquadmates(state, 1, 2), "should be squadmates")
	expectEq(Squads.invite(state, 1, 2, 20), "already_squadmates")
end)

test("squad invites reject self, expire, and can't be reused", function()
	local state = Squads.new(4, 60)
	expectEq(Squads.invite(state, 1, 1, 0), "self")
	Squads.invite(state, 1, 2, 0)
	expectEq(Squads.accept(state, 2, 1, 61), "no_invite")
	Squads.invite(state, 1, 3, 0)
	expectEq(Squads.accept(state, 3, 1, 1), "ok")
	Squads.leave(state, 3)
	expectEq(Squads.accept(state, 3, 1, 2), "no_invite")
end)

test("squads cap at max size", function()
	local state = Squads.new(2, 60)
	Squads.invite(state, 1, 2, 0)
	Squads.accept(state, 2, 1, 0)
	expectEq(Squads.invite(state, 1, 3, 0), "full")
end)

test("leaving dissolves a two-person squad; accepting switches squads", function()
	local state = Squads.new(4, 60)
	Squads.invite(state, 1, 2, 0)
	Squads.accept(state, 2, 1, 0)
	Squads.leave(state, 1)
	expectEq(#Squads.members(state, 2), 1)
	assert(not Squads.areSquadmates(state, 1, 2), "squad should be dissolved")

	Squads.invite(state, 1, 2, 0)
	Squads.accept(state, 2, 1, 0)
	Squads.invite(state, 3, 2, 0)
	expectEq(Squads.accept(state, 2, 3, 0), "ok")
	assert(Squads.areSquadmates(state, 2, 3), "2 should have joined 3")
	expectEq(#Squads.members(state, 1), 1)
end)

test("removing a player clears their invites both ways", function()
	local state = Squads.new(4, 60)
	Squads.invite(state, 1, 2, 0)
	Squads.invite(state, 2, 3, 0)
	Squads.removePlayer(state, 2)
	expectEq(Squads.accept(state, 3, 2, 0), "no_invite")
	expectEq(state.invites[2], nil)
end)

local LAYOUT_PARAMS = { roomCount = 10, extraDoors = 2, minCoord = -3, maxCoord = 3 }

test("zone layouts are deterministic per seed and differ across seeds", function()
	local a = ZoneLayout.generate(LAYOUT_PARAMS, seeded(1))
	local b = ZoneLayout.generate(LAYOUT_PARAMS, seeded(1))
	local c = ZoneLayout.generate(LAYOUT_PARAMS, seeded(2))
	expectEq(table.concat(a.order, ";"), table.concat(b.order, ";"))
	assert(table.concat(a.order, ";") ~= table.concat(c.order, ";"), "different seeds should differ")
end)

test("zone layouts are valid for many seeds", function()
	for seed = 1, 200 do
		local layout = ZoneLayout.generate(LAYOUT_PARAMS, seeded(seed))
		expectEq(#layout.order, LAYOUT_PARAMS.roomCount)
		expectEq(layout.start, "0,0")
		assert(layout.deepest ~= layout.start, `seed {seed}: deepest is the start room`)
		for key, room in layout.rooms do
			assert(room.x >= -3 and room.x <= 3 and room.z >= -3 and room.z <= 3, `seed {seed}: {key} out of bounds`)
			-- Every room except the start is reachable (BFS gave it a depth).
			assert(key == layout.start or room.depth > 0, `seed {seed}: {key} unreachable`)
			expectEq(room.deadEnd, key ~= layout.start and #layout.neighbors[key] == 1)
		end
		for _, edge in layout.edges do
			local a, b = layout.rooms[edge[1]], layout.rooms[edge[2]]
			expectEq(math.abs(a.x - b.x) + math.abs(a.z - b.z), 1) -- doors only between adjacent cells
		end
		-- A tree has roomCount - 1 doors; loops add up to extraDoors more.
		local doors = #layout.edges
		assert(doors >= 9 and doors <= 11, `seed {seed}: {doors} doors`)
	end
end)

test("daily current rotates with the seed and handles negative seeds", function()
	expectEq(Currents.forSeed(CurrentsList, 0).id, CurrentsList[1].id)
	expectEq(Currents.forSeed(CurrentsList, 1).id, CurrentsList[2].id)
	expectEq(Currents.forSeed(CurrentsList, #CurrentsList).id, CurrentsList[1].id)
	assert(Currents.forSeed(CurrentsList, -3) ~= nil, "negative seed should still pick a current")
end)

test("currents modify copies of configs, not the originals", function()
	local rich = CurrentsList[1]
	local modified = Currents.relics(Relics, rich)
	expectEq(modified.RaritySpawnWeights.Rare, Relics.RaritySpawnWeights.Rare * 2)
	expectEq(modified.RaritySpawnWeights.Common, Relics.RaritySpawnWeights.Common)
	expectEq(modified.MutationChance, Relics.MutationChance)
	expectEq(modified.Defs, Relics.Defs)

	local glowing = CurrentsList[2]
	expectNear(Currents.relics(Relics, glowing).MutationChance, Relics.MutationChance * 3)
	expectNear(Currents.oxygen(Oxygen, CurrentsList[3]).BaseDrainPerSecond, Oxygen.BaseDrainPerSecond * 0.85)
	expectEq(Currents.oxygen(Oxygen, rich).BaseDrainPerSecond, Oxygen.BaseDrainPerSecond)
	-- Loot rolls still work on a modified config.
	local key = Loot.rollRelic(modified, seeded(3))
	assert(key ~= nil, "roll on modified config")
end)

test("every current has a name, description and at least one effect", function()
	for _, current in CurrentsList do
		assert(current.name ~= "" and current.description ~= "", `{current.id} missing text`)
		local effects = (current.rarityMultipliers and 1 or 0)
			+ (current.mutationMultiplier and 1 or 0)
			+ (current.oxygenDrainMultiplier and 1 or 0)
			+ (current.hearingMultiplier and 1 or 0)
			+ (current.sellMultiplier and 1 or 0)
		assert(effects >= 1, `{current.id} has no effect`)
	end
end)

test("collection records base and mutated finds once", function()
	local book = {}
	local added = Collection.record(book, {
		{ relicKey = "BrassBell" },
		{ relicKey = "BrassBell", mutation = "Gilded" },
		{ relicKey = "BrassBell" },
	})
	expectEq(table.concat(added, ","), "BrassBell,BrassBell#Gilded")
	expectEq(#Collection.record(book, { { relicKey = "BrassBell", mutation = "Gilded" } }), 0)
	local found, total, mutations = Collection.progress(Relics, book)
	expectEq(found, 1)
	local defs = 0
	for _ in Relics.Defs do
		defs += 1
	end
	expectEq(total, defs)
	expectEq(mutations, 1)
end)

test("collection milestones pay once and in order", function()
	local claimed = {}
	local reached = Collection.newMilestones(CollectionMilestones, 1, 7, 1, claimed)
	expectEq(#reached, 1)
	expectEq(reached[1].id, "firstMutation")
	claimed.firstMutation = true
	expectEq(#Collection.newMilestones(CollectionMilestones, 3, 7, 1, claimed), 0) -- 3/7 < half
	reached = Collection.newMilestones(CollectionMilestones, 7, 7, 1, claimed)
	expectEq(#reached, 2)
	expectEq(reached[1].id, "half")
	expectEq(reached[2].id, "complete")
end)

test("tutorial walks the happy path in order", function()
	local n = TutorialConfig.RelicCount
	local step = Tutorial.initialStep(0)
	expectEq(step, "dive")
	step = Tutorial.next(step, "diveStarted", nil, n)
	expectEq(step, "relics")
	step = Tutorial.next(step, "relicTaken", 2, n)
	expectEq(step, "relics")
	step = Tutorial.next(step, "relicTaken", 3, n)
	expectEq(step, "escape")
	step = Tutorial.next(step, "extracted", 3, n)
	expectEq(step, "sell")
	for _, pair in { { "sold", "upgrade" }, { "upgraded", "base" }, { "reachedBase", "squad" }, { "squadTip", "done" } } do
		step = Tutorial.next(step, pair[1] :: any, nil, n)
		expectEq(step, pair[2])
	end
	-- Every step the machine reaches is a configured step.
	expectEq(TutorialConfig.Steps[#TutorialConfig.Steps], "done")
end)

test("tutorial ignores out-of-order events, handles empty extraction and skip", function()
	local n = TutorialConfig.RelicCount
	expectEq(Tutorial.next("dive", "sold", nil, n), "dive")
	expectEq(Tutorial.next("escape", "extracted", 0, n), "relics")
	expectEq(Tutorial.next("relics", "extracted", 1, n), "sell")
	expectEq(Tutorial.next("upgrade", "skip", nil, n), "done")
	expectEq(Tutorial.next("done", "diveStarted", nil, n), "done")
	expectEq(Tutorial.initialStep(4), "done")
	for _, step in TutorialConfig.Steps do
		assert(step == "done" or TutorialConfig.Text[step], `step {step} has no banner text`)
	end
end)

local function storeProfile(): any
	return { pearls = 0, purchases = {}, cosmetics = { owned = {}, equipped = {} }, vipLastClaimDay = 0 }
end

local TEST_PACKS = { { key = "A", id = 111, pearls = 100 }, { key = "B", id = 0, pearls = 999 } }

test("receipts grant once, ignore duplicates, unknown and not-yet-created products", function()
	local data = storeProfile()
	local outcome, pearls = Store.applyReceipt(data, "p1", 111, TEST_PACKS)
	expectEq(outcome, "granted")
	expectEq(pearls, 100)
	expectEq(data.pearls, 100)
	-- Roblox retries the same receipt: nothing more is granted.
	expectEq((Store.applyReceipt(data, "p1", 111, TEST_PACKS)), "duplicate")
	expectEq(data.pearls, 100)
	-- Product id 0 means "not created yet" and must never match.
	expectEq((Store.applyReceipt(data, "p2", 0, TEST_PACKS)), "unknown_product")
	expectEq((Store.applyReceipt(data, "p3", 222, TEST_PACKS)), "unknown_product")
	expectEq(data.purchases.p2, nil)
	expectEq(data.pearls, 100)
end)

test("cosmetics: buy, refuse when broke or owned, equip, default fallback", function()
	local data = storeProfile()
	expectEq(Store.equipped(data, CosmeticsCatalog, "lamp").id, "lamp_standard")
	expectEq(Store.buyCosmetic(data, CosmeticsCatalog, "lamp_teal"), "not_enough_pearls")
	data.pearls = 200
	expectEq(Store.buyCosmetic(data, CosmeticsCatalog, "lamp_teal"), "ok")
	expectEq(data.pearls, 50)
	expectEq(Store.buyCosmetic(data, CosmeticsCatalog, "lamp_teal"), "owned")
	expectEq(Store.buyCosmetic(data, CosmeticsCatalog, "lamp_standard"), "owned") -- free items
	expectEq(Store.equipCosmetic(data, CosmeticsCatalog, "lamp_violet"), "not_owned")
	expectEq(Store.equipCosmetic(data, CosmeticsCatalog, "lamp_teal"), "ok")
	expectEq(Store.equipped(data, CosmeticsCatalog, "lamp").id, "lamp_teal")
	expectEq(Store.buyCosmetic(data, CosmeticsCatalog, "nope"), "unknown")
end)

test("VIP daily bonus pays once per day", function()
	local data = storeProfile()
	expectEq(Store.claimVipDaily(data, 100, 25), 25)
	expectEq(Store.claimVipDaily(data, 100, 25), 0)
	expectEq(Store.claimVipDaily(data, 101, 25), 25)
	expectEq(data.pearls, 50)
end)

test("monetization config: ids default to 0 and bigger packs are better value", function()
	local previousRate = 0
	for _, pack in MonetizationConfig.PearlPacks do
		local rate = pack.pearls / pack.price
		assert(rate > previousRate, `{pack.key} is not better value than the smaller pack`)
		previousRate = rate
	end
	for _, item in CosmeticsCatalog do
		expectEq(#item.color, 3)
	end
end)

test("movement judge allows legit swims, flags speed hacks and teleports", function()
	local function judge(distance: number, dt: number, speed: number)
		return Movement.judge(
			distance,
			dt,
			speed,
			AntiCheatConfig.SpeedTolerance,
			AntiCheatConfig.SlackStuds,
			AntiCheatConfig.FlagrantFactor
		)
	end
	-- Fastest legit mover: max fins, sprinting, empty bag.
	local fastest = SwimMath.speed(Swim, Gear.valueAt("fins", Gear.MaxLevel) :: number, true, 0, 10)
	expectEq(judge(fastest * 0.5, 0.5, fastest), "ok")
	expectEq(judge(0, 0, fastest), "ok")
	-- 2.5x speed hack over half a second.
	expectEq(judge(fastest * 2.5 * 0.5, 0.5, fastest), "suspicious")
	-- A 200-stud teleport.
	expectEq(judge(200, 0.5, fastest), "flagrant")
end)

test("relic set: 30 relics, saved keys kept, rarity tiers never overlap in value", function()
	local count = 0
	for _ in Relics.Defs do
		count += 1
	end
	expectEq(count, 30)
	-- Keys already in players' saves must never disappear.
	for _, key in
		{
			"RustyCompass",
			"CrackedTeacup",
			"BrassBell",
			"HarborLantern",
			"SilverChalice",
			"CaptainsSextant",
			"DrownedCrown",
		}
	do
		assert(Relics.Defs[key] ~= nil, `saved relic key {key} was removed`)
	end
	for _, key in TutorialConfig.RelicKeys do
		assert(Relics.Defs[key] ~= nil, `tutorial relic {key} missing`)
	end
	local validShapes = { Block = true, Ball = true, Cylinder = true, Wedge = true }
	local low, high = {}, {}
	for key, def in Relics.Defs do
		assert(def.shape == nil or validShapes[def.shape], `{key} has invalid shape`)
		assert(def.weight >= 1 and def.noise > 0 and def.value > 0, `{key} has bad numbers`)
		low[def.rarity] = math.min(low[def.rarity] or math.huge, def.value)
		high[def.rarity] = math.max(high[def.rarity] or 0, def.value)
	end
	for i = 2, #Relics.RarityOrder do
		local lower, upper = Relics.RarityOrder[i - 1], Relics.RarityOrder[i]
		assert(low[upper] > high[lower], `{upper} relics should all be worth more than {lower} ones`)
	end
end)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
