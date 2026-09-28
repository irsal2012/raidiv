--!strict
-- Server-side creature AI. Phase 1: one Drifter.
--
-- FSM: Patrol -> Investigate (heard noise) -> Chase (sees a lit lamp, or a diver very close)
--      -> Search (lost sight) -> Return (to nearest room center) -> Patrol
--
-- Decisions run every 0.2 s; movement runs on Heartbeat. Creatures travel room to room through
-- doorway centers (see GreyboxService), so the grey box needs no pathfinding. Chase and Search
-- move in a straight line to a position that was in line of sight. Room modules in Phase 2
-- will need PathfindingService + SimplePath.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureConfig = require(ReplicatedStorage.Shared.Config.Creatures)

local THINK_SECONDS = 0.2

local STATE_COLORS = {
	Patrol = Color3.fromRGB(80, 220, 200),
	Return = Color3.fromRGB(80, 220, 200),
	Investigate = Color3.fromRGB(255, 170, 40),
	Search = Color3.fromRGB(255, 170, 40),
	Chase = Color3.fromRGB(255, 40, 40),
}

type State = "Patrol" | "Investigate" | "Chase" | "Search" | "Return"

type Creature = {
	config: any,
	part: BasePart,
	light: PointLight,
	state: State,
	path: { Vector3 }, -- positions to visit in order; unused while chasing
	room: string, -- room it is in or heading to
	lastRoom: string?, -- previous patrol room, to avoid instant backtracking
	target: Player?,
	lastKnown: Vector3?,
	searchUntil: number?,
}

local CreatureService = {}

local services: any
local greybox: any
local creatures: { Creature } = {}
local random = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

local function getBody(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	return Workspace:Raycast(from, to - from, rayParams) == nil
end

local function speedFor(creature: Creature): number
	local config = creature.config
	if creature.state == "Chase" then
		return config.chaseSpeed
	elseif creature.state == "Investigate" or creature.state == "Search" then
		return config.investigateSpeed
	elseif creature.state == "Return" then
		return config.returnSpeed
	end
	return config.patrolSpeed
end

local function findVisibleTarget(creature: Creature): Player?
	local position = creature.part.Position
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local session = services.DiveService.getSession(player)
		local root, humanoid = getBody(player)
		if not session or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local distance = (root.Position - position).Magnitude
		local range = if session.lampOn then creature.config.lightSightRange else creature.config.darkSenseRange
		if distance <= range and distance < bestDistance and hasLineOfSight(position, root.Position) then
			best = player
			bestDistance = distance
		end
	end
	return best
end

local function startReturn(creature: Creature)
	creature.state = "Return"
	creature.target = nil
	creature.searchUntil = nil
	creature.room = greybox.roomAt(creature.part.Position) or creature.room
	creature.path = { greybox.roomCenter(creature.room) }
end

local function patrolNext(creature: Creature)
	local options = {}
	for _, key in greybox.neighbors(creature.room) do
		if key ~= creature.lastRoom then
			table.insert(options, key)
		end
	end
	if #options == 0 then
		options = greybox.neighbors(creature.room)
	end
	local nextRoom = options[random:NextInteger(1, #options)]
	creature.lastRoom = creature.room
	creature.room = nextRoom
	creature.path = { greybox.roomCenter(nextRoom) }
end

local function think(creature: Creature)
	local config = creature.config
	local target = findVisibleTarget(creature)
	local targetRoot: BasePart?, targetHumanoid: Humanoid? = nil, nil
	if target then
		targetRoot, targetHumanoid = getBody(target)
	end

	if target and targetRoot and targetHumanoid then
		creature.state = "Chase"
		creature.target = target
		creature.lastKnown = targetRoot.Position
		creature.searchUntil = nil
		if (targetRoot.Position - creature.part.Position).Magnitude <= config.catchRange then
			targetHumanoid.Health = 0
			startReturn(creature)
		end
	else
		if creature.state == "Chase" then
			creature.state = "Search"
			creature.target = nil
			creature.searchUntil = nil
			creature.path = if creature.lastKnown then { creature.lastKnown } else {}
		end

		if creature.state == "Search" then
			if #creature.path == 0 then
				if not creature.searchUntil then
					creature.searchUntil = os.clock() + config.searchSeconds
				elseif os.clock() >= creature.searchUntil then
					startReturn(creature)
				end
			end
		elseif creature.state == "Investigate" then
			if #creature.path == 0 then
				creature.state = "Search"
				creature.searchUntil = os.clock() + config.searchSeconds
			end
		elseif creature.state == "Return" then
			if #creature.path == 0 then
				creature.state = "Patrol"
			end
		elseif creature.state == "Patrol" then
			if #creature.path == 0 then
				patrolNext(creature)
			end
		end
	end

	creature.light.Color = STATE_COLORS[creature.state]
end

local function move(creature: Creature, dt: number)
	local goal: Vector3? = nil
	if creature.state == "Chase" then
		local root = if creature.target then getBody(creature.target) else nil
		goal = root and root.Position
	else
		goal = creature.path[1]
	end
	if not goal then
		return
	end

	local position = creature.part.Position
	local delta = goal - position
	local distance = delta.Magnitude
	local step = speedFor(creature) * dt
	if distance <= step then
		creature.part.CFrame = CFrame.new(goal) * creature.part.CFrame.Rotation
		if creature.state ~= "Chase" then
			table.remove(creature.path, 1)
		end
	else
		creature.part.CFrame = CFrame.lookAt(position + delta.Unit * step, goal)
	end
end

local function spawnDrifter(room: string): Creature
	local part = Instance.new("Part")
	part.Name = "Drifter"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 6
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(20, 30, 35)
	part.Material = Enum.Material.SmoothPlastic
	part.Position = greybox.roomCenter(room)

	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 2
	light.Parent = part

	part.Parent = Workspace

	local creature: Creature = {
		config = CreatureConfig.Drifter,
		part = part,
		light = light,
		state = "Patrol",
		path = {},
		room = room,
	}
	table.insert(creatures, creature)
	return creature
end

-- Something made noise at `position`. Creatures within `radius * hearingMultiplier` investigate.
function CreatureService.emitNoise(position: Vector3, radius: number)
	for _, creature in creatures do
		if creature.state == "Chase" then
			continue
		end
		if (creature.part.Position - position).Magnitude > radius * creature.config.hearingMultiplier then
			continue
		end
		local fromRoom = greybox.roomAt(creature.part.Position) or creature.room
		local toRoom = greybox.roomAt(position) or fromRoom
		local path = {}
		if fromRoom ~= toRoom then
			for _, key in greybox.path(fromRoom, toRoom) do
				table.insert(path, greybox.roomCenter(key))
			end
		end
		table.insert(path, position)
		creature.path = path
		creature.state = "Investigate"
		creature.room = toRoom
		creature.searchUntil = nil
	end
end

function CreatureService.init(allServices: any)
	services = allServices
	greybox = allServices.GreyboxService
end

function CreatureService.start()
	rayParams.FilterDescendantsInstances = { greybox.ZoneFolder }
	spawnDrifter(greybox.CreatureSpawnRoom)

	RunService.Heartbeat:Connect(function(dt)
		for _, creature in creatures do
			move(creature, dt)
		end
	end)

	while true do
		task.wait(THINK_SECONDS)
		for _, creature in creatures do
			think(creature)
		end
	end
end

return CreatureService
