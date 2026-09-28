--!strict
-- Pure upgrade purchase rule. No Roblox APIs and no requires, so it runs under Lune tests.
-- Callers pass the Gear config.

export type Result = "ok" | "unknown_track" | "max_level" | "not_enough_coins"

local Upgrade = {}

-- Whether `track` can be bought now. The cost is returned for "ok" and "not_enough_coins".
function Upgrade.check(gear: any, levels: { [string]: number }, coins: number, track: string): (Result, number?)
	if not table.find(gear.Shop, track) then
		return "unknown_track", nil
	end
	local cost = gear.nextCost(track, levels[track])
	if not cost then
		return "max_level", nil
	end
	if coins < cost then
		return "not_enough_coins", cost
	end
	return "ok", cost
end

return Upgrade
