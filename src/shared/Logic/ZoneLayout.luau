--!strict
-- Pure zone layout generator. Rooms sit on a grid and grow outward from the start cell (0, 0),
-- under the surface shaft, as a random tree. A few extra doors then add loops, so divers have
-- escape routes. No Roblox APIs and no requires; the caller passes an rng returning [0, 1).
-- The same rng sequence always gives the same layout, which is what makes seeds reproducible.

export type Room = {
	key: string,
	x: number,
	z: number,
	depth: number, -- doors from the start room
	deadEnd: boolean, -- exactly one door (never the start room)
}

export type Layout = {
	rooms: { [string]: Room },
	order: { string }, -- creation order; start first
	edges: { { string } }, -- doors, as pairs of room keys
	neighbors: { [string]: { string } },
	start: string,
	deepest: string, -- farthest room from the start
}

export type Params = {
	roomCount: number,
	extraDoors: number,
	minCoord: number, -- grid bounds, both axes
	maxCoord: number,
}

local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local MAX_ATTEMPTS = 2000

local ZoneLayout = {}

function ZoneLayout.key(x: number, z: number): string
	return `{x},{z}`
end

local function pick<T>(list: { T }, rng: () -> number): number
	return math.floor(rng() * #list) + 1
end

function ZoneLayout.generate(params: Params, rng: () -> number): Layout
	local rooms: { [string]: Room } = {}
	local order: { string } = {}
	local edges: { { string } } = {}
	local neighbors: { [string]: { string } } = {}
	local connected: { [string]: { [string]: boolean } } = {}

	local function inBounds(x: number, z: number): boolean
		return x >= params.minCoord and x <= params.maxCoord and z >= params.minCoord and z <= params.maxCoord
	end

	local function addRoom(x: number, z: number): string
		local key = ZoneLayout.key(x, z)
		rooms[key] = { key = key, x = x, z = z, depth = 0, deadEnd = false }
		table.insert(order, key)
		neighbors[key] = {}
		connected[key] = {}
		return key
	end

	local function addDoor(a: string, b: string)
		table.insert(edges, { a, b })
		table.insert(neighbors[a], b)
		table.insert(neighbors[b], a)
		connected[a][b] = true
		connected[b][a] = true
	end

	local start = addRoom(0, 0)

	-- Grow a tree: branch off a random existing room in a random direction.
	local attempts = 0
	while #order < params.roomCount and attempts < MAX_ATTEMPTS do
		attempts += 1
		local from = rooms[order[pick(order, rng)]]
		local dir = DIRECTIONS[pick(DIRECTIONS, rng)]
		local x, z = from.x + dir[1], from.z + dir[2]
		if inBounds(x, z) and not rooms[ZoneLayout.key(x, z)] then
			addDoor(from.key, addRoom(x, z))
		end
	end

	-- Extra doors between adjacent rooms that aren't connected yet make loops.
	local candidates: { { string } } = {}
	for _, key in order do
		local room = rooms[key]
		for _, dir in { { 1, 0 }, { 0, 1 } } do -- each adjacent pair once
			local other = ZoneLayout.key(room.x + dir[1], room.z + dir[2])
			if rooms[other] and not connected[key][other] then
				table.insert(candidates, { key, other })
			end
		end
	end
	for _ = 1, math.min(params.extraDoors, #candidates) do
		local pair = table.remove(candidates, pick(candidates, rng)) :: { string }
		addDoor(pair[1], pair[2])
	end

	-- Depth by breadth-first search from the start.
	local visited = { [start] = true }
	local queue = { start }
	local head = 1
	local deepest = start
	while head <= #queue do
		local key = queue[head]
		head += 1
		for _, nextKey in neighbors[key] do
			if not visited[nextKey] then
				visited[nextKey] = true
				rooms[nextKey].depth = rooms[key].depth + 1
				if rooms[nextKey].depth > rooms[deepest].depth then
					deepest = nextKey
				end
				table.insert(queue, nextKey)
			end
		end
	end

	for key, room in rooms do
		room.deadEnd = key ~= start and #neighbors[key] == 1
	end

	return {
		rooms = rooms,
		order = order,
		edges = edges,
		neighbors = neighbors,
		start = start,
		deepest = deepest,
	}
end

return ZoneLayout
