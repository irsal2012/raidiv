--!strict
-- Pure movement sanity rules for the anti-cheat. No Roblox APIs and no requires.
-- Only horizontal movement is judged: swimming up and falling are vertical and legitimately
-- fast in short bursts, while speed hacks and teleports show up horizontally.

export type Verdict = "ok" | "suspicious" | "flagrant"

local Movement = {}

-- `maxSpeed` is the fastest the player may legitimately move (studs/s). `tolerance` absorbs
-- network jitter; `slack` absorbs small bursts (knockback, ladder dismounts).
function Movement.judge(
	horizontalDistance: number,
	dt: number,
	maxSpeed: number,
	tolerance: number,
	slack: number,
	flagrantFactor: number
): Verdict
	if dt <= 0 then
		return "ok"
	end
	local allowed = maxSpeed * tolerance * dt + slack
	if horizontalDistance <= allowed then
		return "ok"
	end
	if horizontalDistance > allowed * flagrantFactor then
		return "flagrant"
	end
	return "suspicious"
end

return Movement
