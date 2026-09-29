--!strict
-- Cosmetics bought with Pearls (doc/04 §2.3). Looks only, never power.
-- Colors are RGB arrays so this module stays free of Roblox types (Lune tests).

export type Cosmetic = {
	id: string,
	slot: string, -- equip slot, e.g. "lamp"
	name: string,
	price: number, -- Pearls; 0 = everyone owns it
	color: { number },
}

local catalog: { Cosmetic } = {
	{ id = "lamp_standard", slot = "lamp", name = "Standard Lamp", price = 0, color = { 255, 244, 214 } },
	{ id = "lamp_teal", slot = "lamp", name = "Abyss Teal", price = 150, color = { 60, 230, 210 } },
	{ id = "lamp_amber", slot = "lamp", name = "Harbor Amber", price = 150, color = { 255, 170, 60 } },
	{ id = "lamp_violet", slot = "lamp", name = "Deep Violet", price = 250, color = { 170, 110, 255 } },
	{ id = "lamp_crimson", slot = "lamp", name = "Crimson Signal", price = 400, color = { 255, 60, 70 } },
}

return table.freeze(catalog)
