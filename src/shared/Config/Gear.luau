--!strict
-- Gear upgrade tracks: 6 tracks x 5 levels. Placeholder numbers.
-- `values[n]` is the stat at level n; `costs[n]` is the Coin price to reach level n
-- (costs[1] is 0 because level 1 is the starting level).

export type TrackKey = "tank" | "fins" | "lamp" | "bag" | "sonar" | "suit"

export type Track = {
	displayName: string,
	stat: string,
	unit: string, -- shown in the upgrade panel
	values: { number },
	costs: { number },
}

local tracks: { [string]: Track } = {
	tank = {
		displayName = "Oxygen Tank",
		stat = "oxygenCapacity", -- seconds of air at base drain
		unit = "s air",
		values = { 180, 210, 245, 285, 330 },
		costs = { 0, 250, 700, 1600, 3500 },
	},
	fins = {
		displayName = "Fins",
		stat = "swimSpeed", -- studs/second
		unit = "speed",
		values = { 16, 17.5, 19, 20.5, 22 },
		costs = { 0, 200, 600, 1400, 3000 },
	},
	lamp = {
		displayName = "Lamp",
		stat = "lampRange", -- studs; SpotLight.Range caps at 60
		unit = "range",
		values = { 28, 34, 42, 50, 60 },
		costs = { 0, 150, 500, 1200, 2600 },
	},
	bag = {
		displayName = "Salvage Bag",
		stat = "carryCapacity", -- total relic weight
		unit = "capacity",
		values = { 10, 14, 18, 23, 28 },
		costs = { 0, 300, 800, 1800, 4000 },
	},
	sonar = {
		-- Profile starts sonar at level 0 (not owned). Level 1 must be bought.
		displayName = "Sonar",
		stat = "sonarRange", -- studs
		unit = "range",
		values = { 40, 60, 80, 105, 130 },
		costs = { 400, 700, 1300, 2400, 4500 },
	},
	suit = {
		-- OPEN QUESTION: the design doc doesn't define what the suit upgrades.
		-- Assumed: depth rating that gates deeper zones.
		displayName = "Dive Suit",
		stat = "maxDepth", -- meters
		unit = "m",
		values = { 50, 80, 120, 170, 230 },
		costs = { 0, 500, 1200, 2800, 6000 },
	},
}

local Gear = {}

Gear.Tracks = table.freeze(tracks)
Gear.MaxLevel = 5

-- Tracks sold at the upgrade station, in display order. The suit joins once its effect is
-- decided (doc/06 §4).
local shop: { string } = { "tank", "fins", "bag", "lamp", "sonar" }
Gear.Shop = table.freeze(shop)

function Gear.valueAt(track: string, level: number): number?
	return tracks[track].values[level]
end

-- Cost to go from `currentLevel` to `currentLevel + 1`, or nil if maxed.
function Gear.nextCost(track: string, currentLevel: number): number?
	return tracks[track].costs[currentLevel + 1]
end

return table.freeze(Gear)
