--!strict
-- Daily "currents": one modifier per day, picked from the zone seed so it rotates with the
-- seed of the day. Unset multipliers count as 1.

export type Current = {
	id: string,
	name: string,
	description: string,
	rarityMultipliers: { [string]: number }?,
	mutationMultiplier: number?,
	oxygenDrainMultiplier: number?,
	hearingMultiplier: number?,
	sellMultiplier: number?,
}

local currents: { Current } = {
	{
		id = "rich",
		name = "Rich Currents",
		description = "Rare, Epic and Legendary relics are twice as common.",
		rarityMultipliers = { Rare = 2, Epic = 2, Legendary = 2 },
	},
	{
		id = "glowing",
		name = "Glowing Tide",
		description = "Mutations are three times as likely.",
		mutationMultiplier = 3,
	},
	{
		id = "calm",
		name = "Calm Waters",
		description = "Your oxygen lasts about 15% longer.",
		oxygenDrainMultiplier = 0.85,
	},
	{
		id = "restless",
		name = "Restless Deep",
		description = "Creatures hear you from 50% farther away.",
		hearingMultiplier = 1.5,
	},
	{
		id = "market",
		name = "Collector's Market",
		description = "Relics sell for 25% more.",
		sellMultiplier = 1.25,
	},
}

return table.freeze(currents)
