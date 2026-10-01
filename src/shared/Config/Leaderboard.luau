--!strict
-- The plaza's global leaderboard: lifetime Coins earned from selling (profile.stats.earned).
-- Studio play sessions write to a separate store, so test grants (P) never reach the real board.

return table.freeze({
	StoreName = "TopSalvagers_v1",
	StudioStoreName = "TopSalvagers_Studio_v1",
	Size = 10,
	RefreshSeconds = 60, -- write changed scores, then re-read the top list
	FirstRefreshSeconds = 5,
})
