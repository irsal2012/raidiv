--!strict
-- Grey-box zone builder. The layout comes from Logic/ZoneLayout (seeded, unit-tested); this
-- service turns it into flooded rooms with doors, plus the surface: shaft, ladder, boat,
-- sell counter and gear locker. Phase 3 swaps the grey-box room modules for Studio-built
-- models with tagged door attachments.
--
-- Seed: the day number by default, so everyone gets the same layout each day ("seed of the
-- day"). To reproduce a layout, set a number attribute ZoneSeed on Workspace in Studio.
-- The seed in use is written to Workspace's ActiveZoneSeed attribute and printed.
--
-- Doorways sit at the center of shared walls, so a straight line between adjacent room
-- centers always passes through the door. CreatureService relies on this.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ZoneConfig = require(Shared.Config.Zone)
local Loot = require(Shared.Logic.Loot)
local ZoneLayout = require(Shared.Logic.ZoneLayout)

local ROOM_SPACING = 50 -- 48 interior + 2 wall
local ROOM_HALF = 24 -- interior half-width
local ROOM_HEIGHT = 24
local ROOM_Y = -40
local WALL = 2
local DOOR = 12
local SHAFT = 16

-- Floor-level offsets from a room center. Each room uses the first N. All sit well off the
-- center lines so they never block the doorway-to-doorway paths.
local SPAWN_OFFSETS = {
	Vector3.new(-14, -10, -14),
	Vector3.new(14, -10, 10),
	Vector3.new(-16, -10, 14),
	Vector3.new(16, -10, -16),
	Vector3.new(4, -10, 18),
}

local FLAT = CFrame.Angles(math.rad(90), 0, 0)

local GreyboxService = {
	SurfaceY = 0,
	-- A player below this height counts as diving.
	DiveStartY = -4,
	-- A diving player above this height has climbed out: extraction.
	ExtractAboveY = 2,
	DiveEntry = Vector3.new(0, -6, 0),
	Seed = 0,
	CreatureSpawnRoom = "",
	ZoneFolder = nil :: Folder?,
	SellPrompt = nil :: ProximityPrompt?,
	UpgradePrompt = nil :: ProximityPrompt?,
}

local layout: ZoneLayout.Layout
local roomKinds: { [string]: string } = {}
local relicSpawns: { Vector3 } = {}

function GreyboxService.roomCenter(key: string): Vector3
	local room = layout.rooms[key]
	return Vector3.new(room.x * ROOM_SPACING, ROOM_Y, room.z * ROOM_SPACING)
end

-- Room containing `position` by grid cell, or nil outside the zone. The shaft counts as the
-- start room.
function GreyboxService.roomAt(position: Vector3): string?
	local key = ZoneLayout.key(math.round(position.X / ROOM_SPACING), math.round(position.Z / ROOM_SPACING))
	return if layout.rooms[key] then key else nil
end

function GreyboxService.neighbors(key: string): { string }
	return layout.neighbors[key]
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
		for _, nextKey in layout.neighbors[key] do
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

-- Grey-box "room modules": interior props that break line of sight so a diver can hide from
-- a lamp-hunting creature. Props sit on the diagonals, clear of the center lines and spawns.
local function decorate(parent: Instance, center: Vector3, kind: string)
	local floorY = center.Y - ROOM_HEIGHT / 2
	if kind == "pillars" then
		for _, corner in { Vector3.new(8, 0, 8), Vector3.new(-8, 0, 8), Vector3.new(8, 0, -8), Vector3.new(-8, 0, -8) } do
			local pillar = block(parent, CFrame.new(center + corner), Vector3.new(4, ROOM_HEIGHT, 4))
			pillar.Name = "Pillar"
		end
	elseif kind == "crates" then
		for _, spot in { Vector3.new(8, 0, -8), Vector3.new(-8, 0, 8), Vector3.new(9, 0, 9) } do
			local crate =
				block(parent, CFrame.new(center.X + spot.X, floorY + 3, center.Z + spot.Z), Vector3.new(6, 6, 6))
			crate.Name = "Crate"
			crate.Material = Enum.Material.WoodPlanks
			crate.Color = Color3.fromRGB(95, 75, 55)
		end
	end
end

local function buildRoom(parent: Instance, key: string)
	local room = layout.rooms[key]
	local center = GreyboxService.roomCenter(key)
	local outer = ROOM_HALF * 2 + WALL * 2
	local verticalOffset = ROOM_HEIGHT / 2 + WALL / 2

	local model = Instance.new("Model")
	model.Name = `Room {key} ({roomKinds[key]})`
	model.Parent = parent

	panel(model, CFrame.new(center - Vector3.yAxis * verticalOffset) * FLAT, outer, outer, 0, 0)
	local shaftHole = if key == layout.start then SHAFT else 0
	panel(model, CFrame.new(center + Vector3.yAxis * verticalOffset) * FLAT, outer, outer, shaftHole, shaftHole)

	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local neighbor = ZoneLayout.key(room.x + math.round(dir.X), room.z + math.round(dir.Z))
		local door = if table.find(layout.neighbors[key], neighbor) then DOOR else 0
		local wallCenter = center + dir * (ROOM_HALF + WALL / 2)
		panel(model, CFrame.lookAt(wallCenter, wallCenter + dir), outer, ROOM_HEIGHT + WALL * 2, door, door)
	end

	decorate(model, center, roomKinds[key])

	-- Flood the room including its walls, so water runs continuously through doorways.
	Workspace.Terrain:FillBlock(
		CFrame.new(center),
		Vector3.new(outer, ROOM_HEIGHT + WALL * 2, outer),
		Enum.Material.Water
	)
end

local function buildSurface(parent: Instance)
	-- Shaft from the top of room A's ceiling to the surface.
	local shaftHeight = -(ROOM_Y + ROOM_HEIGHT / 2 + WALL)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local wallCenter = Vector3.new(0, -shaftHeight / 2, 0) + dir * (SHAFT / 2 + WALL / 2)
		panel(parent, CFrame.lookAt(wallCenter, wallCenter + dir), SHAFT + WALL * 2, shaftHeight, 0, 0)
	end

	-- Climbable ladder on the boat side of the shaft, rising a little above the ground so
	-- players can step off. Jumping out of terrain water is unreliable.
	-- TrussPart sizes snap to multiples of 2, so keep the height even.
	local ladderTop = GreyboxService.SurfaceY + 4
	local ladder = Instance.new("TrussPart")
	ladder.Name = "ExitLadder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, ladderTop - -shaftHeight, 2)
	ladder.CFrame = CFrame.new(0, (ladderTop - shaftHeight) / 2, -SHAFT / 2 + 1)
	ladder.Color = Color3.fromRGB(230, 180, 40)
	ladder.Parent = parent

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

	local locker = block(parent, CFrame.new(-24, 2, -20), Vector3.new(8, 4, 3))
	locker.Name = "GearLocker"
	locker.Color = Color3.fromRGB(60, 120, 200)

	local upgradePrompt = Instance.new("ProximityPrompt")
	upgradePrompt.ActionText = "Upgrade gear"
	upgradePrompt.ObjectText = "Gear Locker"
	upgradePrompt.MaxActivationDistance = 10
	upgradePrompt.Parent = locker
	GreyboxService.UpgradePrompt = upgradePrompt
end

-- Picks the seed, generates the layout, room kinds and relic spawns. Deterministic per seed.
local function generate()
	local override = Workspace:GetAttribute("ZoneSeed")
	local seed = if typeof(override) == "number" then override else math.floor(os.time() / 86400)
	GreyboxService.Seed = seed
	Workspace:SetAttribute("ActiveZoneSeed", seed)
	print(`[Zone] seed {seed}`)

	local random = Random.new(seed)
	local function rng(): number
		return random:NextNumber()
	end

	layout = ZoneLayout.generate({
		roomCount = ZoneConfig.RoomCount,
		extraDoors = ZoneConfig.ExtraDoors,
		minCoord = ZoneConfig.MinCoord,
		maxCoord = ZoneConfig.MaxCoord,
	}, rng)
	GreyboxService.CreatureSpawnRoom = layout.deepest

	local kinds: { string } = {}
	for kind in ZoneConfig.RoomKindWeights :: { [string]: number } do
		table.insert(kinds, kind)
	end
	table.sort(kinds) -- table iteration order isn't stable; the seed must be
	for _, key in layout.order do
		roomKinds[key] = if key == layout.start
			then "plain"
			else Loot.weightedPick(kinds, ZoneConfig.RoomKindWeights :: any, rng) :: string
	end

	for _, key in layout.order do
		local room = layout.rooms[key]
		local count = if key == layout.start
			then ZoneConfig.SpawnsStart
			elseif room.deadEnd then ZoneConfig.SpawnsDeadEnd
			else ZoneConfig.SpawnsNormal
		for i = 1, count do
			table.insert(relicSpawns, GreyboxService.roomCenter(key) + SPAWN_OFFSETS[i])
		end
	end
end

function GreyboxService.init()
	-- The default Studio template's baseplate and spawn would cover the shaft.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	generate()

	local folder = Instance.new("Folder")
	folder.Name = "Zone"
	for _, key in layout.order do
		buildRoom(folder, key)
	end
	buildSurface(folder)
	folder.Parent = Workspace
	GreyboxService.ZoneFolder = folder

	-- Water up the shaft (rooms flood themselves in buildRoom).
	local terrain = Workspace.Terrain
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
