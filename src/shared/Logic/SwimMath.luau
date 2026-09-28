--!strict
-- Pure swim speed math. No Roblox APIs and no requires, so it runs under Lune tests.

local SwimMath = {}

function SwimMath.speed(
	swimConfig: any,
	baseSpeed: number,
	sprinting: boolean,
	weight: number,
	capacity: number
): number
	local load = if capacity > 0 then math.clamp(weight / capacity, 0, 1) else 0
	local speed = baseSpeed * (1 - (1 - swimConfig.FullBagSpeedFactor) * load)
	if sprinting then
		speed *= swimConfig.SprintMultiplier
	end
	return speed
end

return SwimMath
