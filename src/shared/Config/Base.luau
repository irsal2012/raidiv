--!strict
-- Personal bases: surface plots behind the shaft, one per player, with display pedestals.
-- Set the place's Max Players to at most PlotsPerRow * Rows (Game Settings > Places) so
-- everyone gets a plot.

return table.freeze({
	Slots = 10, -- the Deluxe Base game pass adds 10 more (doc/04)
	PlotsPerRow = 8,
	Rows = 2,
	PlotSize = 30,
	PlotSpacing = 36,
	FirstRowZ = 60,
	RowSpacing = 40,
	PedestalRange = 12, -- server-side check for pedestal prompts
})
