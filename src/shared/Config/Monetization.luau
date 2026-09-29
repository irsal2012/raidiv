--!strict
-- Robux items (doc/04). Create each one in Creator Hub (your experience > Monetization >
-- Passes / Developer Products), then paste its ID here. An ID of 0 means "not created yet":
-- the item is hidden from the shop and ignored by the server.
-- Prices are the doc's suggestions; set the real price in Creator Hub.

return table.freeze({
	GamePasses = table.freeze({
		DeluxeBase = table.freeze({
			id = 0,
			name = "Deluxe Base",
			price = 199,
			description = "+10 display pedestals at your base",
		}),
		VIPDiver = table.freeze({
			id = 0,
			name = "VIP Diver",
			price = 299,
			description = "Gold VIP name tag and bonus Pearls every day",
		}),
	}),
	-- Developer products (repeatable). Bigger packs give more Pearls per Robux.
	PearlPacks = table.freeze({
		table.freeze({ key = "Pearls100", id = 0, pearls = 100, price = 80 }),
		table.freeze({ key = "Pearls550", id = 0, pearls = 550, price = 400 }),
		table.freeze({ key = "Pearls1500", id = 0, pearls = 1500, price = 1000 }),
		table.freeze({ key = "Pearls3500", id = 0, pearls = 3500, price = 2200 }),
	}),
	VIPDailyPearls = 25,
	DeluxeBaseExtraSlots = 10,
})
