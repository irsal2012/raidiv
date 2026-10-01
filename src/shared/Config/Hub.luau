--!strict
-- Surface hub layout around the dive shaft at the origin (doc/07 §1). The plaza is a paved
-- square holding the spawn platform, sell stall and gear shed; the boards stand along its
-- north edge facing the spawn (south). Base plots flank it (Config/Base.luau).

return table.freeze({
	PlazaHalfX = 36,
	PlazaMinZ = -40,
	PlazaMaxZ = 44,
	BoardZ = 42, -- board faces sit on this line, facing -Z
	-- Boards, left to right as seen from the spawn: How to Play, the leaderboard, today's current.
	HowToPlay = table.freeze({ x = 21, width = 13, height = 9 }),
	Leaderboard = table.freeze({ x = 0, width = 16, height = 12 }),
	Current = table.freeze({ x = -21, width = 13, height = 6 }),
	BoardBottom = 1.5, -- height of each board's lower edge above the ground
})
