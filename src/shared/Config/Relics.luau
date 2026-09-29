--!strict
-- Relic definitions, rarity tiers and mutations. The 30 Harbor relics for launch (doc/01 §5).
-- Keys are saved in player data (inventory, collection, base displays): never rename or remove
-- one, only add. `shape` is the grey-box placeholder until real models exist (doc/07 §4).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type Mutation = "Glowing" | "Barnacled" | "Gilded" | "Cursed"

export type RelicDef = {
	displayName: string,
	rarity: Rarity,
	value: number, -- base Coins
	weight: number, -- counts against bag capacity, slows swimming
	noise: number, -- studs; creatures within this radius hear pickup/drop
	shape: Shape?, -- placeholder part shape; Block if unset
}

export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"

local Relics = {}

-- Relative spawn weights, not percentages.
Relics.RaritySpawnWeights = table.freeze({
	Common = 60,
	Uncommon = 25,
	Rare = 10,
	Epic = 4,
	Legendary = 1,
} :: { [Rarity]: number })

Relics.RarityOrder = table.freeze({ "Common", "Uncommon", "Rare", "Epic", "Legendary" } :: { Rarity })

-- Chance any spawned relic rolls a mutation (design: ~1-3%).
Relics.MutationChance = 0.02

Relics.Mutations = table.freeze({
	Glowing = { valueMultiplier = 2 },
	Barnacled = { valueMultiplier = 1.5 },
	Gilded = { valueMultiplier = 3 },
	Cursed = { valueMultiplier = 4 },
} :: { [Mutation]: { valueMultiplier: number } })

Relics.MutationOrder = table.freeze({ "Glowing", "Barnacled", "Gilded", "Cursed" } :: { Mutation })

Relics.Defs = table.freeze({
	-- Common (10)
	RustyCompass = {
		displayName = "Rusty Compass",
		rarity = "Common",
		value = 15,
		weight = 1,
		noise = 8,
		shape = "Cylinder",
	},
	CrackedTeacup = {
		displayName = "Cracked Teacup",
		rarity = "Common",
		value = 12,
		weight = 1,
		noise = 10,
		shape = "Cylinder",
	},
	BentSpoon = { displayName = "Bent Spoon", rarity = "Common", value = 10, weight = 1, noise = 8, shape = "Wedge" },
	GlassFloat = {
		displayName = "Glass Fishing Float",
		rarity = "Common",
		value = 14,
		weight = 1,
		noise = 12,
		shape = "Ball",
	},
	CopperCoin = {
		displayName = "Copper Coin",
		rarity = "Common",
		value = 12,
		weight = 1,
		noise = 6,
		shape = "Cylinder",
	},
	BrokenPocketWatch = {
		displayName = "Broken Pocket Watch",
		rarity = "Common",
		value = 16,
		weight = 1,
		noise = 8,
		shape = "Cylinder",
	},
	SodaBottle = {
		displayName = "Old Soda Bottle",
		rarity = "Common",
		value = 10,
		weight = 1,
		noise = 10,
		shape = "Cylinder",
	},
	FishingReel = {
		displayName = "Fishing Reel",
		rarity = "Common",
		value = 15,
		weight = 2,
		noise = 10,
		shape = "Cylinder",
	},
	RopeCleat = { displayName = "Rope Cleat", rarity = "Common", value = 13, weight = 2, noise = 12, shape = "Wedge" },
	OldBoot = {
		displayName = "Waterlogged Boot",
		rarity = "Common",
		value = 10,
		weight = 2,
		noise = 8,
		shape = "Wedge",
	},
	-- Uncommon (8)
	BrassBell = { displayName = "Brass Bell", rarity = "Uncommon", value = 45, weight = 3, noise = 20, shape = "Ball" },
	HarborLantern = { displayName = "Harbor Lantern", rarity = "Uncommon", value = 55, weight = 4, noise = 14 },
	WheelSpoke = {
		displayName = "Ship's Wheel Spoke",
		rarity = "Uncommon",
		value = 50,
		weight = 3,
		noise = 14,
		shape = "Cylinder",
	},
	PorcelainVase = {
		displayName = "Porcelain Vase",
		rarity = "Uncommon",
		value = 60,
		weight = 3,
		noise = 18,
		shape = "Cylinder",
	},
	SilverLocket = {
		displayName = "Silver Locket",
		rarity = "Uncommon",
		value = 65,
		weight = 1,
		noise = 8,
		shape = "Ball",
	},
	TelegraphKey = {
		displayName = "Telegraph Key",
		rarity = "Uncommon",
		value = 55,
		weight = 2,
		noise = 12,
		shape = "Wedge",
	},
	HelmetVisor = {
		displayName = "Diving Helmet Visor",
		rarity = "Uncommon",
		value = 60,
		weight = 4,
		noise = 16,
		shape = "Ball",
	},
	CannonBall = { displayName = "Cannonball", rarity = "Uncommon", value = 45, weight = 6, noise = 22, shape = "Ball" },
	-- Rare (6)
	SilverChalice = {
		displayName = "Silver Chalice",
		rarity = "Rare",
		value = 150,
		weight = 3,
		noise = 16,
		shape = "Cylinder",
	},
	CaptainsLogbook = { displayName = "Captain's Logbook", rarity = "Rare", value = 160, weight = 2, noise = 10 },
	GoldPocketWatch = {
		displayName = "Gold Pocket Watch",
		rarity = "Rare",
		value = 170,
		weight = 1,
		noise = 10,
		shape = "Cylinder",
	},
	Figurehead = {
		displayName = "Mermaid Figurehead",
		rarity = "Rare",
		value = 190,
		weight = 6,
		noise = 20,
		shape = "Wedge",
	},
	BronzeAstrolabe = {
		displayName = "Bronze Astrolabe",
		rarity = "Rare",
		value = 180,
		weight = 3,
		noise = 14,
		shape = "Cylinder",
	},
	JadeCompass = {
		displayName = "Jade Compass",
		rarity = "Rare",
		value = 165,
		weight = 2,
		noise = 12,
		shape = "Cylinder",
	},
	-- Epic (4)
	CaptainsSextant = {
		displayName = "Captain's Sextant",
		rarity = "Epic",
		value = 420,
		weight = 4,
		noise = 18,
		shape = "Wedge",
	},
	BellClapper = {
		displayName = "Cathedral Bell Clapper",
		rarity = "Epic",
		value = 450,
		weight = 6,
		noise = 26,
		shape = "Ball",
	},
	MayorsSeal = {
		displayName = "Sunken Mayor's Seal",
		rarity = "Epic",
		value = 480,
		weight = 2,
		noise = 12,
		shape = "Cylinder",
	},
	ClockworkSquid = {
		displayName = "Clockwork Squid",
		rarity = "Epic",
		value = 500,
		weight = 4,
		noise = 20,
		shape = "Ball",
	},
	-- Legendary (2)
	DrownedCrown = {
		displayName = "Drowned Crown",
		rarity = "Legendary",
		value = 1500,
		weight = 8,
		noise = 30,
		shape = "Cylinder",
	},
	HarborHeart = {
		displayName = "Heart of the Harbor",
		rarity = "Legendary",
		value = 1800,
		weight = 5,
		noise = 28,
		shape = "Ball",
	},
} :: { [string]: RelicDef })

return table.freeze(Relics)
