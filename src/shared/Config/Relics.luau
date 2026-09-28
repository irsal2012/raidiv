--!strict
-- Relic definitions, rarity tiers and mutations.
-- Prototype set only; launch target is ~30 relics in Harbor.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type Mutation = "Glowing" | "Barnacled" | "Gilded" | "Cursed"

export type RelicDef = {
	displayName: string,
	rarity: Rarity,
	value: number, -- base Coins
	weight: number, -- counts against bag capacity, slows swimming
	noise: number, -- studs; creatures within this radius hear pickup/drop
}

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
	RustyCompass = { displayName = "Rusty Compass", rarity = "Common", value = 15, weight = 1, noise = 8 },
	CrackedTeacup = { displayName = "Cracked Teacup", rarity = "Common", value = 12, weight = 1, noise = 10 },
	BrassBell = { displayName = "Brass Bell", rarity = "Uncommon", value = 45, weight = 3, noise = 20 },
	HarborLantern = { displayName = "Harbor Lantern", rarity = "Uncommon", value = 55, weight = 4, noise = 14 },
	SilverChalice = { displayName = "Silver Chalice", rarity = "Rare", value = 150, weight = 3, noise = 16 },
	CaptainsSextant = { displayName = "Captain's Sextant", rarity = "Epic", value = 420, weight = 4, noise = 18 },
	DrownedCrown = { displayName = "Drowned Crown", rarity = "Legendary", value = 1500, weight = 8, noise = 30 },
} :: { [string]: RelicDef })

return table.freeze(Relics)
