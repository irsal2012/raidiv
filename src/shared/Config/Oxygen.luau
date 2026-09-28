--!strict
-- Oxygen tuning. All values are placeholders until the Phase 1 playtest.

return table.freeze({
	-- Drain per second while idle/swimming normally.
	BaseDrainPerSecond = 1,
	SprintDrainMultiplier = 1.75,
	-- Extra drain per unit of carried weight, as a fraction of base drain.
	WeightDrainPerUnit = 0.02,
	-- Breathing audio intensifies below this fraction.
	LowOxygenThreshold = 0.25,
	-- Refill rate at stations / air pockets, per second.
	RefillPerSecond = 20,
})
