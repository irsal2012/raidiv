--!strict
-- Squads of up to 4 within a server: invites, accept/decline, leave. Membership rules live in
-- Logic/Squads.luau (unit-tested); this service wires them to players and remotes.
-- Phase 1-2 has one shared zone, so squadmates dive together automatically.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local SquadConfig = require(Shared.Config.Squad)
local Squads = require(Shared.Logic.Squads)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local SquadService = {}

local services: any
local state = Squads.new(SquadConfig.MaxSize, SquadConfig.InviteSeconds)
local squadStateRemote = Remotes.get("SquadState")
local notifyRemote = Remotes.get("Notify")

local function playersFor(userIds: { number }): { Player }
	local result = {}
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(result, player)
		end
	end
	return result
end

local function sendState(userIds: { number })
	for _, player in playersFor(userIds) do
		local squad: Types.SquadState = { members = {} }
		for _, member in playersFor(Squads.members(state, player.UserId)) do
			table.insert(squad.members, { userId = member.UserId, name = member.DisplayName })
		end
		squadStateRemote:FireClient(player, squad)
	end
end

-- Everyone in the player's squad who is in this server, including the player.
function SquadService.members(player: Player): { Player }
	return playersFor(Squads.members(state, player.UserId))
end

function SquadService.areSquadmates(a: Player, b: Player): boolean
	return Squads.areSquadmates(state, a.UserId, b.UserId)
end

-- True if another squad member is mid-dive and not downed, i.e. someone could revive you.
function SquadService.hasDivingSquadmate(player: Player): boolean
	for _, member in SquadService.members(player) do
		local session = member ~= player and services.DiveService.getSession(member)
		if session and not session.downed then
			return true
		end
	end
	return false
end

function SquadService.init(allServices: any)
	services = allServices
end

function SquadService.start()
	local inviteReceivedRemote = Remotes.get("SquadInviteReceived")

	local allowInvite = RateLimiter.new(1, 3)
	Remotes.get("SquadInvite").OnServerEvent:Connect(function(player, targetUserId)
		if not allowInvite(player) or typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return
		end
		local result = Squads.invite(state, player.UserId, target.UserId, os.clock())
		if result == "ok" then
			inviteReceivedRemote:FireClient(target, player.UserId, player.DisplayName)
			notifyRemote:FireClient(player, `Invite sent to {target.DisplayName}`)
		elseif result == "full" then
			notifyRemote:FireClient(player, "Your squad is full")
		elseif result == "already_squadmates" then
			notifyRemote:FireClient(player, `{target.DisplayName} is already in your squad`)
		end
	end)

	local allowRespond = RateLimiter.new(2, 4)
	Remotes.get("SquadRespond").OnServerEvent:Connect(function(player, fromUserId, accept)
		if not allowRespond(player) or typeof(fromUserId) ~= "number" or typeof(accept) ~= "boolean" then
			return
		end
		local inviter = Players:GetPlayerByUserId(fromUserId)
		if not accept then
			local pending = state.invites[player.UserId]
			if pending then
				pending[fromUserId] = nil
			end
			if inviter then
				notifyRemote:FireClient(inviter, `{player.DisplayName} declined your invite`)
			end
			return
		end

		local previous = Squads.members(state, player.UserId)
		local result = Squads.accept(state, player.UserId, fromUserId, os.clock())
		if result == "ok" then
			sendState(previous)
			sendState(Squads.members(state, player.UserId))
			for _, member in SquadService.members(player) do
				notifyRemote:FireClient(member, `{player.DisplayName} joined the squad`)
			end
		elseif result == "full" then
			notifyRemote:FireClient(player, "That squad is full")
		elseif result == "no_invite" then
			notifyRemote:FireClient(player, "That invite expired")
		end
	end)

	local allowLeave = RateLimiter.new(1, 2)
	Remotes.get("SquadLeave").OnServerEvent:Connect(function(player)
		if not allowLeave(player) then
			return
		end
		local previous = Squads.members(state, player.UserId)
		Squads.leave(state, player.UserId)
		sendState(previous)
	end)

	-- Analytics only: how many friends were invited from the in-game button.
	local allowInviteLog = RateLimiter.new(0.2, 2)
	Remotes.get("InviteSent").OnServerEvent:Connect(function(player, count)
		if allowInviteLog(player) and typeof(count) == "number" and count >= 1 and count <= 100 then
			services.AnalyticsService.invitesSent(player, math.floor(count))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local previous = Squads.members(state, player.UserId)
		Squads.removePlayer(state, player.UserId)
		table.remove(previous, table.find(previous, player.UserId) :: number)
		sendState(previous)
	end)
end

return SquadService
