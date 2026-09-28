--!strict
-- Creature tuning. Speeds are studs/second; compare with Config/Swim.luau and the fins track.
-- Drifter chase speed sits between an unloaded diver's swim and sprint speed, so a diver
-- escapes by sprinting, and a loaded diver has to drop loot or kill the lamp.

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
})
