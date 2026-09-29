--!strict
-- Saved player profiles via ProfileStore (Vendor/, official MadStudioRoblox source).
-- ProfileStore session-locks each profile, so a player's data can't be loaded on two
-- servers at once. That is what stops item duplication and lost progress on server hops.
--
-- API used by other services: get(player), addCoins(player, amount).
-- get() returns nil until the profile has loaded (usually well under a second).
--
-- In Studio, data saves only with Game Settings > Security > "Enable Studio Access to API
-- Services" on. Otherwise ProfileStore prints "data will not be saved" and uses memory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local Types = require(ReplicatedStorage.Shared.Types)

local STORE_NAME = "PlayerData"
local CURRENT_VERSION = 1

local TEMPLATE: Types.Profile = {
	version = CURRENT_VERSION,
	coins = 0,
	pearls = 0,
	level = 1,
	xp = 0,
	gear = { tank = 1, fins = 1, lamp = 1, bag = 1, sonar = 0, suit = 1 },
	inventory = {},
	base = { displays = {} },
	collection = {},
	cosmetics = { owned = {}, equipped = {} },
	purchases = {},
	stats = { dives = 0, extractions = 0, deaths = 0 },
	onboarding = {},
	titles = {},
	collectionRewards = {},
	tutorial = { step = "" },
	vipLastClaimDay = 0,
}

-- MIGRATIONS[n] upgrades saved data from version n to n + 1. Add one whenever the
-- profile shape changes in a way Reconcile() can't handle (renames, restructures).
local MIGRATIONS: { [number]: (data: any) -> () } = {}

local PlayerDataService = {}

local services: any
local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, Types.Profile) -> () } = {}

local function migrate(data: any)
	while data.version < CURRENT_VERSION do
		MIGRATIONS[data.version](data)
		data.version += 1
	end
end

local function createLeaderstats(player: Player, coins: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = coins
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server still holds the session lock, or DataStore is down.
		player:Kick("Couldn't load your save. Please rejoin in a minute.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: lets Roblox erasure requests find this key
	profile:Reconcile() -- fills in fields added to TEMPLATE since this profile was saved
	migrate(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		-- Left while loading.
		profile:EndSession()
		return
	end

	profiles[player] = profile
	createLeaderstats(player, profile.Data.coins)
	services.AnalyticsService.onboardingStep(player, "Joined")
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
end

-- Saves now and waits until the DataStore holds data for which `check(savedData)` is true.
-- Used before confirming Robux purchases. Returns false on timeout or if the session ended.
function PlayerDataService.saveUntil(player: Player, check: (saved: any) -> boolean, timeoutSeconds: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if profile.LastSavedData and check(profile.LastSavedData) then
		return true
	end
	local confirmed = false
	local connection = profile.OnAfterSave:Connect(function(saved)
		if check(saved) then
			confirmed = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + timeoutSeconds
	while not confirmed and os.clock() < deadline and profile:IsActive() do
		task.wait(0.25)
	end
	connection:Disconnect()
	return confirmed
end

-- Runs `callback(player, data)` whenever a player's profile finishes loading. Register in init.
function PlayerDataService.onProfileLoaded(callback: (Player, Types.Profile) -> ())
	table.insert(loadedCallbacks, callback)
end

function PlayerDataService.get(player: Player): Types.Profile?
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerDataService.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data.coins += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value = profile.Data.coins
	end
end

function PlayerDataService.init(allServices: any)
	services = allServices
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
