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
	-- Not sold yet, and not a track at all.
	expectEq((Upgrade.check(Gear, levels, 1e9, "sonar")), "unknown_track")
	expectEq((Upgrade.check(Gear, levels, 1e9, "rocketboots")), "unknown_track")
end)

test("every shop track has a unit and a full cost ladder", function()
	for _, key in Gear.Shop do
		local track = Gear.Tracks[key]
		assert(track.unit ~= "", `{key} has no unit`)
		expectEq(#track.costs, Gear.MaxLevel)
	end
end)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
