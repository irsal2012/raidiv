--!strict
-- Pure oxygen math. No Roblox APIs and no requires, so it runs under Lune tests.

local OxygenMath = {}

function OxygenMath.drainPerSecond(oxygenConfig: any, sprinting: boolean, carriedWeight: number): number
	local rate = oxygenConfig.BaseDrainPerSecond
	if sprinting then
		rate *= oxygenConfig.SprintDrainMultiplier
	end
	return rate * (1 + carriedWeight * oxygenConfig.WeightDrainPerUnit)
end

-- Steps oxygen forward by `dt` seconds; never goes below 0.
function OxygenMath.step(
	oxygenConfig: any,
	current: number,
	dt: number,
	sprinting: boolean,
	carriedWeight: number
): number
	return math.max(0, current - OxygenMath.drainPerSecond(oxygenConfig, sprinting, carriedWeight) * dt)
end

return OxygenMath
