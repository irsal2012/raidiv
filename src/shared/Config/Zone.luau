--!strict
-- Zone generation tuning (Harbor). See Logic/ZoneLayout.luau.

return table.freeze({
	RoomCount = 10,
	-- Doors added after the tree is built, creating loops to escape through.
	ExtraDoors = 2,
	-- Grid bounds in rooms, both axes. The start room is (0, 0), under the shaft.
	MinCoord = -3,
	MaxCoord = 3,
	-- Relic spawn points per room. Dead ends hold more: that's the greed pull.
	SpawnsStart = 1,
	SpawnsNormal = 3,
	SpawnsDeadEnd = 5,
	-- Lurkers hide in wall vents in this many rooms (never the start room or its neighbours).
	LurkerCount = 2,
	-- Relative odds for grey-box room modules (not used for the start room).
	RoomKindWeights = table.freeze({ plain = 3, pillars = 2, crates = 2 }),
})
