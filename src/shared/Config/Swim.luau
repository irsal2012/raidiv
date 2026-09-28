--!strict
-- Swim tuning. Base swim speed comes from the fins gear track (Config/Gear.luau).

return table.freeze({
	SurfaceWalkSpeed = 16,
	SprintMultiplier = 1.4,
	-- Speed multiplier with a completely full bag; scales linearly with load.
	FullBagSpeedFactor = 0.6,
	-- Creatures within this radius (times their hearing multiplier) hear a sprinting diver.
	SprintNoiseRadius = 20,
})
