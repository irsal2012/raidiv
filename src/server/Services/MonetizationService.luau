--!strict
-- Robux purchases and the Pearl shop (doc/04). Never sells power: Pearls buy looks, passes
-- buy convenience and status.
--
-- Receipts (Pearl packs): the grant and the receipt id are written together, the profile is
-- saved, and only once the save is confirmed do we return PurchaseGranted. On any failure we
-- return NotProcessedYet and Roblox retries later; the stored id stops a double grant.
-- Game passes are checked once per session (cached) and on purchase.
-- Items with id 0 in Config/Monetization aren't created yet and are ignored.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Cosmetics = require(Shared.Config.Cosmetics)
local Monetization = require(Shared.Config.Monetization)
local Store = require(Shared.Logic.Store)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local SAVE_CONFIRM_SECONDS = 20
local VIP_TAG = "VipTag"

local MonetizationService = {}

local services: any
local passOwnership: { [Player]: { [string]: boolean } } = {}
local shopStateRemote = Remotes.get("ShopState")
local notifyRemote = Remotes.get("Notify")

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Whether the player owns a game pass. The first call per pass per session asks Roblox (yields).
function MonetizationService.owns(player: Player, passKey: string): boolean
	local cache = passOwnership[player]
	if not cache then
		cache = {}
		passOwnership[player] = cache
	end
	if cache[passKey] ~= nil then
		return cache[passKey]
	end
	local pass = (Monetization.GamePasses :: any)[passKey]
	local owned = false
	if pass and pass.id ~= 0 then
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		owned = ok and result == true
	end
	cache[passKey] = owned
	return owned
end

function MonetizationService.sendShopState(player: Player)
	local data = services.PlayerDataService.get(player)
	if not data then
		return
	end
	local passes = {}
	for key in Monetization.GamePasses :: any do
		passes[key] = MonetizationService.owns(player, key)
	end
	local state: Types.ShopState = {
		unlocked = data.stats.extractions > 0,
		pearls = data.pearls,
		passes = passes,
		ownedCosmetics = data.cosmetics.owned,
		equipped = data.cosmetics.equipped,
	}
	shopStateRemote:FireClient(player, state)
end

local function applyVip(player: Player)
	local data = services.PlayerDataService.get(player)
	if data then
		local granted = Store.claimVipDaily(data, today(), Monetization.VIPDailyPearls)
		if granted > 0 then
			notifyRemote:FireClient(player, `VIP daily bonus: {granted} Pearls`)
		end
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and not head:FindFirstChild(VIP_TAG) then
		local tag = Instance.new("BillboardGui")
		tag.Name = VIP_TAG
		tag.Size = UDim2.fromOffset(60, 22)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 60
		tag.Parent = head
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 205, 60)
		text.TextStrokeTransparency = 0.3
		text.Text = "VIP"
		text.Parent = tag
	end
end

local function applyPass(player: Player, passKey: string)
	if passKey == "DeluxeBase" then
		services.BaseService.rebuild(player)
	elseif passKey == "VIPDiver" then
		applyVip(player)
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and services.PlayerDataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local outcome, pearls = Store.applyReceipt(data, receipt.PurchaseId, receipt.ProductId, Monetization.PearlPacks)
	if outcome == "unknown_product" then
		warn(`[Monetization] Unknown product {receipt.ProductId}; add it to Config/Monetization`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Granted now or on an earlier attempt: either way, only confirm once it's saved.
	local saved = services.PlayerDataService.saveUntil(player, function(savedData)
		return savedData.purchases ~= nil and savedData.purchases[receipt.PurchaseId] == true
	end, SAVE_CONFIRM_SECONDS)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if outcome == "granted" then
		notifyRemote:FireClient(player, `+{pearls} Pearls. Thank you!`)
		services.AnalyticsService.pearlsPurchased(player, pearls :: number, receipt.ProductId)
		MonetizationService.sendShopState(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init(allServices: any)
	services = allServices
	services.PlayerDataService.onProfileLoaded(function(player: Player)
		if MonetizationService.owns(player, "VIPDiver") then
			applyVip(player)
		end
		MonetizationService.sendShopState(player)
	end)
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Monetization.GamePasses :: any do
			if pass.id ~= 0 and pass.id == passId then
				local cache = passOwnership[player] or {}
				passOwnership[player] = cache
				cache[key] = true
				applyPass(player, key)
				notifyRemote:FireClient(player, `{pass.name} unlocked. Thank you!`)
				MonetizationService.sendShopState(player)
			end
		end
	end)

	local allowShop = RateLimiter.new(3, 5)
	Remotes.get("ShopRequest").OnServerEvent:Connect(function(player)
		if allowShop(player) then
			MonetizationService.sendShopState(player)
		end
	end)

	Remotes.get("ShopBuyCosmetic").OnServerEvent:Connect(function(player, id)
		local data = services.PlayerDataService.get(player)
		if not allowShop(player) or typeof(id) ~= "string" or not data then
			return
		end
		local outcome = Store.buyCosmetic(data, Cosmetics, id)
		if outcome == "ok" then
			Store.equipCosmetic(data, Cosmetics, id)
			local item = Store.findCosmetic(Cosmetics, id)
			notifyRemote:FireClient(player, `Bought and equipped {if item then item.name else id}`)
		elseif outcome == "not_enough_pearls" then
			notifyRemote:FireClient(player, "Not enough Pearls")
		end
		MonetizationService.sendShopState(player)
	end)

	Remotes.get("ShopEquip").OnServerEvent:Connect(function(player, id)
		local data = services.PlayerDataService.get(player)
		if not allowShop(player) or typeof(id) ~= "string" or not data then
			return
		end
		Store.equipCosmetic(data, Cosmetics, id)
		MonetizationService.sendShopState(player)
	end)

	-- The VIP tag lives on the character, so reapply it after each respawn.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head")
			if passOwnership[player] and passOwnership[player].VIPDiver then
				applyVip(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passOwnership[player] = nil
	end)
end

return MonetizationService
