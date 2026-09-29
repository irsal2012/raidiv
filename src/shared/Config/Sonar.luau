--!strict
-- Sonar gear behaviour. Range per level lives in Config/Gear.luau (sonar track).

return table.freeze({
	IntervalSeconds = 5,
	MarkerSeconds = 1.6,
	-- Each pulse is audible to creatures: sonar near a Lurker vent is a gamble.
	NoiseRadius = 6,
})
