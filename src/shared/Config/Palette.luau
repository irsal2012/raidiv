--!strict
-- The game's colours in one place (see doc/07-style-guide.md). Server and client both read
-- this, so relics, pedestals, sonar dots and the collection book always agree.

return table.freeze({
	Rarity = table.freeze({
		Common = Color3.fromRGB(170, 170, 170),
		Uncommon = Color3.fromRGB(85, 200, 110),
		Rare = Color3.fromRGB(70, 140, 255),
		Epic = Color3.fromRGB(170, 90, 255),
		Legendary = Color3.fromRGB(255, 190, 40),
	} :: { [string]: Color3 }),
})
