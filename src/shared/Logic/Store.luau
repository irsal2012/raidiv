--!strict
-- Pure store rules: receipts, cosmetics and the VIP daily bonus. No Roblox APIs and no
-- requires, so it runs under Lune tests. All functions mutate the profile data they're given.

export type ReceiptOutcome = "granted" | "duplicate" | "unknown_product"
export type CosmeticOutcome = "ok" | "owned" | "not_owned" | "unknown" | "not_enough_pearls"

local Store = {}

-- Applies a developer-product receipt at most once. The purchase id is recorded in the same
-- change as the grant, so a retried receipt can never grant twice.
function Store.applyReceipt(data: any, purchaseId: string, productId: number, packs: { any }): (ReceiptOutcome, number?)
	if data.purchases[purchaseId] then
		return "duplicate", nil
	end
	for _, pack in packs do
		if pack.id ~= 0 and pack.id == productId then
			data.pearls += pack.pearls
			data.purchases[purchaseId] = true
			return "granted", pack.pearls
		end
	end
	return "unknown_product", nil
end

function Store.findCosmetic(catalog: { any }, id: string): any?
	for _, item in catalog do
		if item.id == id then
			return item
		end
	end
	return nil
end

function Store.ownsCosmetic(data: any, item: any): boolean
	return item.price == 0 or data.cosmetics.owned[item.id] == true
end

function Store.buyCosmetic(data: any, catalog: { any }, id: string): CosmeticOutcome
	local item = Store.findCosmetic(catalog, id)
	if not item then
		return "unknown"
	end
	if Store.ownsCosmetic(data, item) then
		return "owned"
	end
	if data.pearls < item.price then
		return "not_enough_pearls"
	end
	data.pearls -= item.price
	data.cosmetics.owned[item.id] = true
	return "ok"
end

function Store.equipCosmetic(data: any, catalog: { any }, id: string): CosmeticOutcome
	local item = Store.findCosmetic(catalog, id)
	if not item then
		return "unknown"
	end
	if not Store.ownsCosmetic(data, item) then
		return "not_owned"
	end
	data.cosmetics.equipped[item.slot] = item.id
	return "ok"
end

-- The equipped item for a slot, falling back to the free default for that slot.
function Store.equipped(data: any, catalog: { any }, slot: string): any?
	local item = Store.findCosmetic(catalog, data.cosmetics.equipped[slot] or "")
	if item and item.slot == slot and Store.ownsCosmetic(data, item) then
		return item
	end
	for _, candidate in catalog do
		if candidate.slot == slot and candidate.price == 0 then
			return candidate
		end
	end
	return nil
end

-- VIP bonus: once per UTC day. Returns the Pearls granted (0 if already claimed today).
function Store.claimVipDaily(data: any, today: number, amount: number): number
	if data.vipLastClaimDay >= today then
		return 0
	end
	data.vipLastClaimDay = today
	data.pearls += amount
	return amount
end

return Store
