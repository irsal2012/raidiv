--!strict
-- Server-side exploit checks (doc/02 §4.6): flag and log, never auto-ban.

return table.freeze({
	CheckSeconds = 0.5,
	SpeedTolerance = 1.5, -- allowed speed = WalkSpeed x this
	SlackStuds = 6,
	FlagrantFactor = 3, -- beyond allowed x this: pull the player back to their last good spot
	TeleportGraceSeconds = 2, -- after a server teleport or respawn, skip checks this long
	CoinsPerMinuteAlert = 20000, -- a legit big haul sells for a few thousand
})
