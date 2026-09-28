--!strict
-- Pure loot math. No Roblox APIs and no requires, so it runs under Lune tests.
-- Callers pass the Relics config and an rng returning a float in [0, 1).

type Rng = () -> number

local Loot = {}

-- Weighted pick over `order` using `weights[key]`.
function Loot.weightedPick<K>(order: { K }, weights: { [K]: number }, rng: Rng): K
	local total = 0
	for _, key in order do
		total += weights[key]
	end
	local roll = rng() * total
	for _, key in order do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return order[#order]
end

-- Returns a mutation key or nil. Mutations are equally likely once one triggers.
function Loot.rollMutation(relicsConfig: any, rng: Rng): string?
	if rng() >= relicsConfig.MutationChance then
		return nil
	end
	local order = relicsConfig.MutationOrder
	return order[math.floor(rng() * #order) + 1]
end

-- Picks a rarity, then a relic of that rarity, then maybe a mutation.
-- Returns nil if no relic of the rolled rarity exists.
function Loot.rollRelic(relicsConfig: any, rng: Rng): (string?, string?)
	local rarity = Loot.weightedPick(relicsConfig.RarityOrder, relicsConfig.RaritySpawnWeights, rng)

	local candidates = {}
	for key, def in relicsConfig.Defs do
		if def.rarity == rarity then
			table.insert(candidates, key)
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	-- Sort so the same seed gives the same relic regardless of table iteration order.
	table.sort(candidates)

	local relicKey = candidates[math.floor(rng() * #candidates) + 1]
	return relicKey, Loot.rollMutation(relicsConfig, rng)
end

function Loot.sellValue(relicsConfig: any, relicKey: string, mutation: string?): number
	local value = relicsConfig.Defs[relicKey].value
	if mutation then
		value *= relicsConfig.Mutations[mutation].valueMultiplier
	end
	return math.floor(value)
end

return Loot
