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
	base: { displays: { [string]: RelicInstance } }, -- slot ("1"..) -> displayed relic; not in inventory
	collection: { [string]: boolean }, -- discovered relicKeys
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	purchases: { [string]: boolean }, -- processed receipt IDs
	stats: { dives: number, extractions: number, deaths: number },
	onboarding: { [string]: boolean }, -- onboarding funnel steps already logged
	titles: { [string]: boolean }, -- earned titles (display comes with cosmetics)
	collectionRewards: { [string]: boolean }, -- collection milestones already paid
	tutorial: { step: string }, -- "" until first join; see Config/Tutorial
	vipLastClaimDay: number, -- UTC day number of the last VIP Pearl bonus
}

-- Server -> client every dive tick.
export type DiveState = {
	diving: boolean,
	oxygen: number,
	maxOxygen: number,
	weight: number,
	capacity: number,
	lampOn: boolean,
	downed: boolean,
	downedSecondsLeft: number,
}

-- Server -> client when the upgrade panel opens or after a purchase.
export type ProfileState = {
	coins: number,
	gear: { [string]: number },
}

-- Server -> client whenever squad membership changes. Leader first.
export type SquadState = {
	members: { { userId: number, name: string } },
}

-- Server -> client when the collection book opens or changes.
export type CollectionState = {
	collection: { [string]: boolean },
	claimed: { [string]: boolean },
}

-- One unsold relic offered in the base display picker.
export type DisplayItem = { id: string, name: string, rarity: string }

export type SonarHit = { position: Vector3, rarity: string }

-- Server -> client for the shop panel.
export type ShopState = {
	unlocked: boolean, -- the shop appears after the first extraction (doc/04 §3)
	pearls: number,
	passes: { [string]: boolean },
	ownedCosmetics: { [string]: boolean },
	equipped: { [string]: string },
}

export type PingKind = "relic" | "danger" | "look"

return nil
