--!strict
-- Studio-only test shortcuts. The server refuses every request outside Studio, so the remote
-- existing in the live game grants nothing even if an exploiter fires it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local GRANT_COINS = 5000
local GRANT_PEARLS = 500

local DevService = {}

local services: any

function DevService.init(allServices: any)
	services = allServices
end

function DevService.start()
	if not RunService:IsStudio() then
		return
	end
	local allowGrant = RateLimiter.new(1, 2)
	Remotes.get("DevGrant").OnServerEvent:Connect(function(player)
		local data = services.PlayerDataService.get(player)
		if not RunService:IsStudio() or not allowGrant(player) or not data then
			return
		end
		services.PlayerDataService.addCoins(player, GRANT_COINS)
		data.pearls += GRANT_PEARLS
		services.MonetizationService.sendShopState(player)
		Remotes.get("Notify"):FireClient(player, `[Studio] +{GRANT_COINS} Coins, +{GRANT_PEARLS} Pearls`)
	end)
	print("[Dev] Studio shortcuts on: press P for Coins and Pearls")
end

return DevService
