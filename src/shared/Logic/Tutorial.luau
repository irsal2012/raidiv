--!strict
-- Pure tutorial step machine. No Roblox APIs and no requires, so it runs under Lune tests.
-- Given the current step and an event, returns the next step (or the same step if the event
-- doesn't apply). `value` carries a count for "relicTaken" and "extracted".

export type Event =
	"diveStarted"
	| "relicTaken" -- value: tutorial relics picked up so far
	| "extracted" -- value: relics carried out
	| "sold"
	| "upgraded"
	| "reachedBase"
	| "squadTip"
	| "skip"

local Tutorial = {}

function Tutorial.next(step: string, event: Event, value: number?, relicCount: number): string
	if step == "done" then
		return "done"
	end
	if event == "skip" then
		return "done"
	end
	local count = value or 0

	if step == "dive" and event == "diveStarted" then
		return "relics"
	elseif step == "relics" and event == "relicTaken" and count >= relicCount then
		return "escape"
	elseif (step == "relics" or step == "escape") and event == "extracted" then
		-- Came up with loot: on to selling. Came up empty (e.g. died and lost it): try again.
		return if count > 0 then "sell" else "relics"
	elseif step == "sell" and event == "sold" then
		return "upgrade"
	elseif step == "upgrade" and event == "upgraded" then
		return "base"
	elseif step == "base" and event == "reachedBase" then
		return "squad"
	elseif step == "squad" and event == "squadTip" then
		return "done"
	end
	return step
end

-- Where a player with no saved tutorial step starts: veterans skip it.
function Tutorial.initialStep(extractions: number): string
	return if extractions > 0 then "done" else "dive"
end

return Tutorial
