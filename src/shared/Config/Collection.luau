--!strict
-- Collection book milestones for the Harbor zone. A milestone is reached by the fraction of
-- base relics discovered, or by the number of mutated relics discovered. Rewards are paid
-- once per player.

export type Milestone = {
	id: string,
	label: string,
	fraction: number?,
	mutations: number?,
	coins: number,
	pearls: number?, -- the free path to cosmetics (doc/04: earnable path to most things)
	title: string?,
}

local milestones: { Milestone } = {
	{ id = "firstMutation", label = "Find a mutated relic", mutations = 1, coins = 200, pearls = 25 },
	{ id = "half", label = "Discover half the Harbor relics", fraction = 0.5, coins = 250, pearls = 25 },
	{
		id = "complete",
		label = "Discover every Harbor relic",
		fraction = 1,
		coins = 1000,
		pearls = 100,
		title = "Harbor Historian",
	},
}

return table.freeze(milestones)
