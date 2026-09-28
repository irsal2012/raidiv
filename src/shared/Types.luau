--!strict
-- Shared types. Mirrors the profile template in doc/02-tech-stack.md §4.4.

export type RelicInstance = {
	id: string, -- HttpService:GenerateGUID(), for trade auditing
	relicKey: string,
	mutation: string?,
	obtainedAt: number,
}

export type Profile = {
	version: number,
	coins: number,
	pearls: number,
	level: number,
	xp: number,
	gear: { tank: number, fins: number, lamp: number, bag: number, sonar: number, suit: number },
	inventory: { RelicInstance },
	base: { displays: { [string]: string } }, -- slotId -> relic instance id
	collection: { [string]: boolean }, -- discovered relicKeys
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	purchases: { [string]: boolean }, -- processed receipt IDs
	stats: { dives: number, extractions: number, deaths: number },
	onboarding: { [string]: boolean }, -- onboarding funnel steps already logged
}

-- Server -> client every dive tick.
export type DiveState = {
	diving: boolean,
	oxygen: number,
	maxOxygen: number,
	weight: number,
	capacity: number,
	lampOn: boolean,
}

-- Server -> client when the upgrade panel opens or after a purchase.
export type ProfileState = {
	coins: number,
	gear: { [string]: number },
}

return nil
