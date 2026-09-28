--!strict
-- Phase 1 grey-box zone, built in code so the prototype runs from an empty place.
-- Six flooded rooms on a grid, reached by a water shaft from the surface above room A.
-- Phase 2 replaces this with hand-built room modules assembled by ZoneGenerator.
--
--   F   D - E      (gz = 1)
--       |   |
--   A - B - C      (gz = 0)
--
-- B-C-E-D is a loop; F is a dead end off D with extra relic spawns.
-- Doorways sit at the center of shared walls, so a straight line between adjacent room
-- centers always passes through the door. CreatureService relies on this.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local ROOM_SPACING = 50 -- 48 interior + 2 wall
local ROOM_HALF = 24 -- interior half-width
local ROOM_HEIGHT = 24
local ROOM_Y = -40
local WALL = 2
local DOOR = 12
local SHAFT = 16

local ROOM_ORDER = { "A", "B", "C", "D", "E", "F" }
local ROOM_GRID: { [string]: { number } } = {
	A = { 0, 0 },
	B = { 1, 0 },
	C = { 2, 0 },
	D = { 1, 1 },
	E = { 2, 1 },
	F = { 0, 1 },
}
local EDGES = { { "A", "B" }, { "B", "C" }, { "C", "E" }, { "E", "D" }, { "D", "B" }, { "D", "F" } }

-- Floor-level offsets from a room center. Each room uses the first N.
local SPAWN_OFFSETS = {
	Vector3.new(-14, -10, -14),
	Vector3.new(14, -10, 10),
	Vector3.new(0, -10, 16),
	Vector3.new(16, -10, -16),
	Vector3.new(-16, -10, 12),
}
local SPAWNS_PER_ROOM: { [string]: number } = { A = 1, B = 3, C = 3, D = 3, E = 3, F = 5 }

local FLAT = CFrame.Angles(math.rad(90), 0, 0)

local gridLookup: { [string]: string } = {}
for key, cell in ROOM_GRID do
	gridLookup[`{cell[1]},{cell[2]}`] = key
end

local neighbors: { [string]: { string } } = {}
local connected: { [string]: { [string]: boolean } } = {}
for _, key in ROOM_ORDER do
	neighbors[key] = {}
	connected[key] = {}
end
for _, edge in EDGES do
	local a, b = edge[1], edge[2]
	table.insert(neighbors[a], b)
	table.insert(neighbors[b], a)
	connected[a][b] = true
	connected[b][a] = true
end

local GreyboxService = {
	SurfaceY = 0,
	-- A player below this height counts as diving.
	DiveStartY = -4,
	-- A diving player above this height has climbed out: extraction.
	ExtractAboveY = 2,
	DiveEntry = Vector3.new(0, -6, 0),
	CreatureSpawnRoom = "C",
	ZoneFolder = nil :: Folder?,
	SellPrompt = nil :: ProximityPrompt?,
}

function GreyboxService.roomCenter(key: string): Vector3
	local cell = ROOM_GRID[key]
	return Vector3.new(cell[1] * ROOM_SPACING, ROOM_Y, cell[2] * ROOM_SPACING)
end

-- Room containing `position` by grid cell. The shaft counts as room A.
function GreyboxService.roomAt(position: Vector3): string?
	return gridLookup[`{math.round(position.X / ROOM_SPACING)},{math.round(position.Z / ROOM_SPACING)}`]
end

function GreyboxService.neighbors(key: string): { string }
	return neighbors[key]
end

-- Breadth-first route of room keys from `fromKey` to `toKey`, inclusive.
function GreyboxService.path(fromKey: string, toKey: string): { string }
	if fromKey == toKey then
		return { fromKey }
	end
	local previous: { [string]: string } = {}
	local visited = { [fromKey] = true }
	local queue = { fromKey }
	local head = 1
	while head <= #queue do
		local key = queue[head]
		head += 1
		for _, nextKey in neighbors[key] do
			if visited[nextKey] then
				continue
			end
			visited[nextKey] = true
			previous[nextKey] = key
			if nextKey == toKey then
				local route = { toKey }
				local current = toKey
				while previous[current] do
					current = previous[current]
					table.insert(route, 1, current)
				end
				return route
			end
			table.insert(queue, nextKey)
		end
	end
	return { fromKey }
end

local relicSpawns: { Vector3 } = {}
for _, key in ROOM_ORDER do
	for i = 1, SPAWNS_PER_ROOM[key] do
		table.insert(relicSpawns, GreyboxService.roomCenter(key) + SPAWN_OFFSETS[i])
	end
end

function GreyboxService.relicSpawns(): { Vector3 }
	return relicSpawns
end

local function block(parent: Instance, cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Slate
	part.Color = Color3.fromRGB(90, 96, 100)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Flat panel: local X = width, local Y = height, local Z = thickness. Optional centered hole.
local function panel(
	parent: Instance,
	cframe: CFrame,
	width: number,
	height: number,
	holeWidth: number,
	holeHeight: number
)
	if holeWidth <= 0 then
		block(parent, cframe, Vector3.new(width, height, WALL))
		return
	end
	local sideWidth = (width - holeWidth) / 2
	local capHeight = (height - holeHeight) / 2
	local sideX = (holeWidth + sideWidth) / 2
	local capY = (holeHeight + capHeight) / 2
	block(parent, cframe * CFrame.new(-sideX, 0, 0), Vector3.new(sideWidth, height, WALL))
	block(parent, cframe * CFrame.new(sideX, 0, 0), Vector3.new(sideWidth, height, WALL))
	block(parent, cframe * CFrame.new(0, capY, 0), Vector3.new(holeWidth, capHeight, WALL))
	block(parent, cframe * CFrame.new(0, -capY, 0), Vector3.new(holeWidth, capHeight, WALL))
end

local function buildRoom(parent: Instance, key: string)
	local center = GreyboxService.roomCenter(key)
	local cell = ROOM_GRID[key]
	local outer = ROOM_HALF * 2 + WALL * 2
	local verticalOffset = ROOM_HEIGHT / 2 + WALL / 2

	panel(parent, CFrame.new(center - Vector3.yAxis * verticalOffset) * FLAT, outer, outer, 0, 0)
	local shaftHole = if key == "A" then SHAFT else 0
	panel(parent, CFrame.new(center + Vector3.yAxis * verticalOffset) * FLAT, outer, outer, shaftHole, shaftHole)

	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local neighbor = gridLookup[`{cell[1] + math.round(dir.X)},{cell[2] + math.round(dir.Z)}`]
		local door = if neighbor and connected[key][neighbor] then DOOR else 0
		local wallCenter = center + dir * (ROOM_HALF + WALL / 2)
		panel(parent, CFrame.lookAt(wallCenter, wallCenter + dir), outer, ROOM_HEIGHT + WALL * 2, door, door)
	end
end

local function buildSurface(parent: Instance)
	-- Shaft from the top of room A's ceiling to the surface.
	local shaftHeight = -(ROOM_Y + ROOM_HEIGHT / 2 + WALL)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local wallCenter = Vector3.new(0, -shaftHeight / 2, 0) + dir * (SHAFT / 2 + WALL / 2)
		panel(parent, CFrame.lookAt(wallCenter, wallCenter + dir), SHAFT + WALL * 2, shaftHeight, 0, 0)
	end

	-- Ground with a hole over the shaft. Top face at SurfaceY.
	panel(parent, CFrame.new(0, GreyboxService.SurfaceY - WALL / 2, 0) * FLAT, 400, 400, SHAFT, SHAFT)

	local boat = block(parent, CFrame.new(0, 1, -20), Vector3.new(14, 2, 10))
	boat.Name = "DiveBoat"
	boat.Material = Enum.Material.WoodPlanks
	boat.Color = Color3.fromRGB(120, 85, 55)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BoatSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 2.5, -20)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent

	local counter = block(parent, CFrame.new(24, 2, -20), Vector3.new(8, 4, 3))
	counter.Name = "SellCounter"
	counter.Color = Color3.fromRGB(200, 170, 60)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell relics"
	prompt.ObjectText = "Salvage Buyer"
	prompt.MaxActivationDistance = 10
	prompt.Parent = counter
	GreyboxService.SellPrompt = prompt
end

function GreyboxService.init()
	-- The default Studio template's baseplate and spawn would cover the shaft.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Zone"
	for _, key in ROOM_ORDER do
		buildRoom(folder, key)
	end
	buildSurface(folder)
	folder.Parent = Workspace
	GreyboxService.ZoneFolder = folder

	-- Water: one block over the whole room grid, one up the shaft.
	local terrain = Workspace.Terrain
	local gridMin = Vector3.new(-ROOM_HALF - WALL, ROOM_Y - ROOM_HEIGHT / 2 - WALL, -ROOM_HALF - WALL)
	local gridMax = Vector3.new(
		2 * ROOM_SPACING + ROOM_HALF + WALL,
		ROOM_Y + ROOM_HEIGHT / 2 + WALL,
		ROOM_SPACING + ROOM_HALF + WALL
	)
	terrain:FillBlock(CFrame.new((gridMin + gridMax) / 2), gridMax - gridMin, Enum.Material.Water)
	local shaftBottom = ROOM_Y + ROOM_HEIGHT / 2 + WALL
	terrain:FillBlock(
		CFrame.new(0, (shaftBottom + GreyboxService.SurfaceY) / 2, 0),
		Vector3.new(SHAFT, GreyboxService.SurfaceY - shaftBottom, SHAFT),
		Enum.Material.Water
	)
	terrain.WaterColor = Color3.fromRGB(30, 95, 105)
	terrain.WaterTransparency = 0.5

	-- Bright surface; dim rooms you can navigate without the lamp, but where the lamp
	-- still helps you spot relics. Ambient drives indoor light, OutdoorAmbient the surface.
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 80, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 140)
end

return GreyboxService
