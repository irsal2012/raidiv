--!strict
-- Squad, revive and ping tuning.

return table.freeze({
	MaxSize = 4,
	InviteSeconds = 60,
	-- A downed diver with a diving squadmate waits this long for a revive before dying.
	ReviveWindowSeconds = 20,
	ReviveHoldSeconds = 2,
	-- Revived divers get at least this fraction of a full tank.
	ReviveOxygenFraction = 0.3,
	PingSeconds = 6,
	-- Pings farther than this from the pinger are ignored.
	PingRange = 200,
})
