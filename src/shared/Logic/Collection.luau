--!strict
-- Pure collection book rules. No Roblox APIs and no requires, so it runs under Lune tests.
-- A profile's collection maps entry keys to true: "RelicKey" for the base relic and
-- "RelicKey#Mutation" for each mutated variant found.

local Collection = {}

function Collection.entryKey(relicKey: string, mutation: string?): string
	return if mutation then `{relicKey}#{mutation}` else relicKey
end

-- Base relics found, total base relics, and mutated variants found.
function Collection.progress(relicsConfig: any, collection: { [string]: boolean }): (number, number, number)
	local found, total, mutations = 0, 0, 0
	for relicKey in relicsConfig.Defs do
		total += 1
		if collection[relicKey] then
			found += 1
		end
	end
	for entry in collection do
		if string.find(entry, "#", 1, true) then
			mutations += 1
		end
	end
	return found, total, mutations
end

-- Marks relics as discovered. Returns the entry keys that are new, in order.
-- `relics` are relic instances; only relicKey and mutation are read.
function Collection.record(collection: { [string]: boolean }, relics: { any }): { string }
	local added = {}
	for _, relic in relics do
		local entries = { relic.relicKey }
		if relic.mutation then
			table.insert(entries, Collection.entryKey(relic.relicKey, relic.mutation))
		end
		for _, entry in entries do
			if not collection[entry] then
				collection[entry] = true
				table.insert(added, entry)
			end
		end
	end
	return added
end

-- Milestones reached and not yet in `claimed`, in config order.
function Collection.newMilestones(
	milestones: { any },
	found: number,
	total: number,
	mutations: number,
	claimed: { [string]: boolean }
): { any }
	local reached = {}
	for _, milestone in milestones do
		if claimed[milestone.id] then
			continue
		end
		local byFraction = milestone.fraction and total > 0 and found / total >= milestone.fraction
		local byMutations = milestone.mutations and mutations >= milestone.mutations
		if byFraction or byMutations then
			table.insert(reached, milestone)
		end
	end
	return reached
end

return Collection
