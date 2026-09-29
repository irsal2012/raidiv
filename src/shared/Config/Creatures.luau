--!strict
-- Creature tuning. Speeds are studs/second; compare with Config/Swim.luau and the fins track.
--
-- Drifter: chase speed sits between an unloaded diver's swim and sprint speed, so a diver
--   escapes by sprinting; a loaded diver has to drop loot or kill the lamp.
-- Lurker: hides in a wall vent and lunges at noise in its own room. The lunge goes to where
--   the noise was, after a visible windup, so an alert diver can dodge it.
-- Warden: rare boss drawn by heavy loot. An unloaded diver outruns it, a full-bag diver
--   can't even when sprinting: drop loot or die.

return table.freeze({
	Drifter = table.freeze({
		patrolSpeed = 8,
		investigateSpeed = 12,
		chaseSpeed = 18,
		returnSpeed = 10,
		lightSightRange = 60, -- sees a diver with the lamp on from this far (needs line of sight)
		darkSenseRange = 10, -- notices a diver with the lamp off only this close
		hearingMultiplier = 2, -- applied to every noise radius
		catchRange = 4,
		searchSeconds = 4,
	}),
	Lurker = table.freeze({
		hearingMultiplier = 2.5,
		windupSeconds = 0.7,
		lungeSpeed = 40,
		lungeRange = 30, -- max distance from its vent
		retreatSpeed = 10,
		cooldownSeconds = 6,
		catchRange = 5,
	}),
	Warden = table.freeze({
		patrolSpeed = 8,
		huntSpeed = 11,
		chaseSpeed = 14,
		sightRange = 45,
		catchRange = 5,
		spawnCheckSeconds = 10,
		spawnChance = 0.35,
		-- "Heavy" means bag at least this full, or carrying at least this many Coins of loot.
		heavyLoadFraction = 0.7,
		heavyValue = 400,
		lingerSeconds = 20, -- leaves after this long with nobody heavy to hunt
		repathSeconds = 1.5,
	}),
})
