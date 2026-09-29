--!strict
-- Pure daily-current helpers. No Roblox APIs and no requires, so it runs under Lune tests.
-- They return modified copies of configs; the originals stay frozen and untouched.

local Currents = {}

-- The current for a seed. Lua's % is floored, so negative seeds still give a valid index.
function Currents.forSeed(list: { any }, seed: number): any
	return list[(math.floor(seed) % #list) + 1]
end

-- Relics config with the current's rarity and mutation multipliers applied.
function Currents.relics(relicsConfig: any, current: any): any
	local weights = {}
	for rarity, weight in relicsConfig.RaritySpawnWeights do
		local multiplier = current.rarityMultipliers and current.rarityMultipliers[rarity] or 1
		weights[rarity] = weight * multiplier
	end
	local copy = table.clone(relicsConfig)
	copy.RaritySpawnWeights = weights
	copy.MutationChance = relicsConfig.MutationChance * (current.mutationMultiplier or 1)
	return copy
end

-- Oxygen config with the current's drain multiplier applied.
function Currents.oxygen(oxygenConfig: any, current: any): any
	local copy = table.clone(oxygenConfig)
	copy.BaseDrainPerSecond = oxygenConfig.BaseDrainPerSecond * (current.oxygenDrainMultiplier or 1)
	return copy
end

return Currents
