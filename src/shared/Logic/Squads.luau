--!strict
-- Pure squad membership rules, keyed by userId. No Roblox APIs and no requires, so it runs
-- under Lune tests. A player not in any squad is a squad of one.

export type Squad = { members: { number } } -- members[1] is the leader

export type State = {
	maxSize: number,
	inviteSeconds: number,
	nextId: number,
	squads: { [number]: Squad },
	squadOf: { [number]: number },
	invites: { [number]: { [number]: number } }, -- invitee -> inviter -> expiresAt
}

export type Result = "ok" | "self" | "already_squadmates" | "full" | "no_invite"

local Squads = {}

function Squads.new(maxSize: number, inviteSeconds: number): State
	return {
		maxSize = maxSize,
		inviteSeconds = inviteSeconds,
		nextId = 1,
		squads = {},
		squadOf = {},
		invites = {},
	}
end

-- Everyone in `userId`'s squad, including them. Leader first.
function Squads.members(state: State, userId: number): { number }
	local id = state.squadOf[userId]
	if not id then
		return { userId }
	end
	return table.clone(state.squads[id].members)
end

function Squads.areSquadmates(state: State, a: number, b: number): boolean
	return a ~= b and state.squadOf[a] ~= nil and state.squadOf[a] == state.squadOf[b]
end

function Squads.invite(state: State, from: number, to: number, now: number): Result
	if from == to then
		return "self"
	end
	if Squads.areSquadmates(state, from, to) then
		return "already_squadmates"
	end
	if #Squads.members(state, from) >= state.maxSize then
		return "full"
	end
	state.invites[to] = state.invites[to] or {}
	state.invites[to][from] = now + state.inviteSeconds
	return "ok"
end

-- Removes `userId` from their squad. A squad left with one member dissolves.
function Squads.leave(state: State, userId: number)
	local id = state.squadOf[userId]
	if not id then
		return
	end
	state.squadOf[userId] = nil
	local members = state.squads[id].members
	table.remove(members, table.find(members, userId) :: number)
	if #members <= 1 then
		for _, member in members do
			state.squadOf[member] = nil
		end
		state.squads[id] = nil
	end
end

-- `to` accepts an invite from `from`, leaving any squad they were in.
function Squads.accept(state: State, to: number, from: number, now: number): Result
	local pending = state.invites[to]
	local expiresAt = pending and pending[from]
	if not pending or not expiresAt or now > expiresAt then
		return "no_invite"
	end
	pending[from] = nil
	if Squads.areSquadmates(state, from, to) then
		return "already_squadmates"
	end
	if #Squads.members(state, from) >= state.maxSize then
		return "full"
	end

	Squads.leave(state, to)
	local id: number = state.squadOf[from] or state.nextId
	if not state.squads[id] then
		state.nextId += 1
		state.squads[id] = { members = { from } }
		state.squadOf[from] = id
	end
	table.insert(state.squads[id].members, to)
	state.squadOf[to] = id
	return "ok"
end

-- The player left the server: drop their membership and every invite to or from them.
function Squads.removePlayer(state: State, userId: number)
	Squads.leave(state, userId)
	state.invites[userId] = nil
	for _, pending in state.invites do
		pending[userId] = nil
	end
end

return Squads
