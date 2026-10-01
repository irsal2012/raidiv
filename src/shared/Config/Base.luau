--!strict
-- Personal bases: surface plots in two blocks either side of the central plaza, one per
-- player, each with display pedestals and a name sign facing the plaza. Set the place's Max
-- Players to at most 2 * Columns * Rows (16) so everyone gets a plot.

return table.freeze({
	Slots = 10, -- the Deluxe Base game pass adds 10 more (doc/04)
	-- Per side: Columns plots across (outward from the plaza) by Rows plots along Z.
	Columns = 2,
	Rows = 4,
	PlotSize = 30,
	PlotSpacing = 34, -- center to center; leaves a 4-stud walkway between plots
	InnerX = 53, -- |X| of the column nearest the plaza (plaza edge at 36)
	FirstZ = -51, -- Z of the southernmost row
	PedestalRange = 12, -- server-side check for pedestal prompts
})
