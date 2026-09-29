--!strict
-- First-time user experience (doc/01-game-design.md §4). Steps run in this order; the
-- banner shows `text` while a step is active. "done" means the tutorial is finished.

return table.freeze({
	Steps = table.freeze({ "dive", "relics", "escape", "sell", "upgrade", "base", "squad", "done" }),
	Text = table.freeze({
		dive = "Press DIVE to jump in",
		relics = "Swim down and grab the 3 glowing relics",
		escape = "Something's coming! Climb the yellow ladder out",
		sell = "Sell your relics at the gold counter",
		upgrade = "Buy your first upgrade at the blue Gear Locker",
		base = "Visit your base: show off your best finds here",
		squad = "Diving is better with friends. Tap SQUAD to invite someone",
	} :: { [string]: string }),
	RelicCount = 3,
	-- Glowing relics chosen so the three together afford the cheapest upgrade.
	RelicKeys = table.freeze({ "RustyCompass", "HarborLantern", "BrassBell" }),
	Mutation = "Glowing",
	SquadTipSeconds = 12,
	BaseReachDistance = 20,
})
