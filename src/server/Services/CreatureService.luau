--!strict
-- Server-side creature AI. Decisions run every 0.2 s; movement runs on Heartbeat.
-- Creatures travel room to room through doorway centers (see GreyboxService), so the grey box
-- needs no pathfinding. Chase and Search move straight at a position that was in line of sight.
-- Studio-built room modules (Phase 3) will need PathfindingService + SimplePath.
--
-- Drifter (patrols): Patrol -> Investigate (noise) -> Chase (lit lamp, or very close)
--                    -> Search (lost sight) -> Return -> Patrol
-- Lurker (vent):     Hidden -> Windup (noise in its room) -> Lunge (to the noise) -> Retreat
--                    -> Cooldown -> Hidden
-- Warden (boss):     spawns while someone carries a heavy load; Hunt (room to room toward the
--                    heaviest carrier) <-> Chase (in sight); Patrol while nobody is heavy, then leaves.
--
-- Downed divers are never targets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CreatureConfig = require(Shared.Config.Creatures)
local Relics = require(Shared.Config.Relics)
local Loot = require(Shared.Logic.Loot)
local Remotes = require(Shared.Net.Remotes)

local THINK_SECONDS = 0.2

local TEAL = Color3.fromRGB(80, 220, 200)
local AMBER = Color3.fromRGB(255, 170, 40)
local RED = Color3.fromRGB(255, 40, 40)

local STATE_COLORS: { [string]: Color3 } = {
	Patrol = TEAL,
	Return = TEAL,
	Investigate = AMBER,
	Search = AMBER,
	Chase = RED,
	Hidden = TEAL,
	Windup = AMBER,
	Lunge = RED,
	Retreat = TEAL,
	Cooldown = TEAL,
	Hunt = RED,
}

type Kind = "Drifter" | "Lurker" | "Warden"
type State =
	"Patrol"
	| "Investigate"
	| "Chase"
	| "Search"
	| "Return"
	| "Hidden"
	| "Windup"
	| "Lunge"
	| "Retreat"
	| "Cooldown"
	| "Hunt"

type Creature = {
	kind: Kind,
	config: any,
	part: BasePart,
	light: PointLight,
	state: State,
	path: { Vector3 }, -- positions to visit in order; unused while chasing
	room: string, -- room it is in or heading to
	lastRoom: string?, -- previous patrol room, to avoid instant backtracking
	target: Player?,
	lastKnown: Vector3?, -- Drifter: last seen target. Lurker: lunge point.
	searchUntil: number?,
	stateUntil: number, -- Lurker windup/cooldown end; Warden departure time (0 = has a target)
	repathAt: number,
	home: Vector3, -- Lurker vent
	gone: boolean,
}

local CreatureService = {}

local services: any
local greybox: any
local creatures: { Creature } = {}
local random = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true
local notifyRemote = Remotes.get("Notify")

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

-- Divers a creature may target: mid-dive, not downed, alive. Yields player, session, root.
local function eligibleDivers(): { { player: Player, session: any, root: BasePart } }
	local result = {}
	for _, player in Players:GetPlayers() do
		local session = services.DiveService.getSession(player)
		local root, humanoid = getBody(player)
		if session and not session.downed and root and humanoid and humanoid.Health > 0 then
			table.insert(result, { player = player, session = session, root = root })
		end
	end
	return result
end

local function routeTo(creature: Creature, position: Vector3)
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
	creature.room = toRoom
end

local function speedFor(creature: Creature): number
	local config, state = creature.config, creature.state
	if creature.kind == "Lurker" then
		return if state == "Lunge" then config.lungeSpeed elseif state == "Retreat" then config.retreatSpeed else 0
	elseif creature.kind == "Warden" then
		return if state == "Chase"
			then config.chaseSpeed
			elseif state == "Hunt" then config.huntSpeed
			else config.patrolSpeed
	end
	if state == "Chase" then
		return config.chaseSpeed
	elseif state == "Investigate" or state == "Search" then
		return config.investigateSpeed
	elseif state == "Return" then
		return config.returnSpeed
	end
	return config.patrolSpeed
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

-- Drifter ------------------------------------------------------------------------------------

local function findVisibleTarget(creature: Creature): (Player?, BasePart?)
	local position = creature.part.Position
	local best: Player?, bestRoot: BasePart? = nil, nil
	local bestDistance = math.huge
	for _, diver in eligibleDivers() do
		local distance = (diver.root.Position - position).Magnitude
		local range = if diver.session.lampOn then creature.config.lightSightRange else creature.config.darkSenseRange
		if distance <= range and distance < bestDistance and hasLineOfSight(position, diver.root.Position) then
			best, bestRoot, bestDistance = diver.player, diver.root, distance
		end
	end
	return best, bestRoot
end

local function thinkDrifter(creature: Creature)
	local config = creature.config
	local target, targetRoot = findVisibleTarget(creature)

	if target and targetRoot then
		creature.state = "Chase"
		creature.target = target
		creature.lastKnown = targetRoot.Position
		creature.searchUntil = nil
		if (targetRoot.Position - creature.part.Position).Magnitude <= config.catchRange then
			services.DiveService.kill(target, "drifter")
			startReturn(creature)
		end
		return
	end

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

-- Lurker -------------------------------------------------------------------------------------

local function thinkLurker(creature: Creature)
	local config, now = creature.config, os.clock()
	if creature.state == "Windup" and now >= creature.stateUntil then
		creature.state = "Lunge"
		creature.path = { creature.lastKnown or creature.home }
	end

	if creature.state == "Lunge" then
		for _, diver in eligibleDivers() do
			if (diver.root.Position - creature.part.Position).Magnitude <= config.catchRange then
				services.DiveService.kill(diver.player, "lurker")
			end
		end
		if #creature.path == 0 then
			creature.state = "Retreat"
			creature.path = { creature.home }
		end
	elseif creature.state == "Retreat" and #creature.path == 0 then
		creature.state = "Cooldown"
		creature.stateUntil = now + config.cooldownSeconds
	elseif creature.state == "Cooldown" and now >= creature.stateUntil then
		creature.state = "Hidden"
	end

	-- Nearly invisible in its vent; the windup glow is the dodge cue.
	local exposed = creature.state == "Windup" or creature.state == "Lunge"
	creature.light.Enabled = exposed
	creature.light.Brightness = if creature.state == "Windup" then 5 else 3
	creature.part.Transparency = if exposed then 0 else 0.7
end

-- Warden -------------------------------------------------------------------------------------

local function isHeavy(config: any, session: any): boolean
	if session.capacity > 0 and session.weight / session.capacity >= config.heavyLoadFraction then
		return true
	end
	local value = 0
	for _, relic in session.carried do
		value += Loot.sellValue(Relics, relic.relicKey, relic.mutation)
	end
	return value >= config.heavyValue
end

local function heaviestCarrier(config: any): (Player?, BasePart?)
	local best: Player?, bestRoot: BasePart? = nil, nil
	local bestWeight = -1
	for _, diver in eligibleDivers() do
		if isHeavy(config, diver.session) and diver.session.weight > bestWeight then
			best, bestRoot, bestWeight = diver.player, diver.root, diver.session.weight
		end
	end
	return best, bestRoot
end

local function thinkWarden(creature: Creature)
	local config, now = creature.config, os.clock()
	local target, targetRoot = heaviestCarrier(config)

	if not target or not targetRoot then
		creature.target = nil
		if creature.stateUntil == 0 then
			creature.stateUntil = now + config.lingerSeconds
			creature.state = "Patrol"
			creature.path = {}
		elseif now >= creature.stateUntil then
			creature.gone = true
			return
		end
		if #creature.path == 0 then
			creature.room = greybox.roomAt(creature.part.Position) or creature.room
			patrolNext(creature)
		end
		return
	end

	creature.stateUntil = 0
	creature.target = target
	local position = creature.part.Position
	local distance = (targetRoot.Position - position).Magnitude
	if distance <= config.catchRange then
		services.DiveService.kill(target, "warden")
	elseif distance <= config.sightRange and hasLineOfSight(position, targetRoot.Position) then
		creature.state = "Chase"
	else
		if creature.state ~= "Hunt" or now >= creature.repathAt or #creature.path == 0 then
			creature.state = "Hunt"
			routeTo(creature, targetRoot.Position)
			creature.repathAt = now + config.repathSeconds
		end
	end
end

-- Shared -------------------------------------------------------------------------------------

local function think(creature: Creature)
	if creature.kind == "Lurker" then
		thinkLurker(creature)
	elseif creature.kind == "Warden" then
		thinkWarden(creature)
	else
		thinkDrifter(creature)
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

	local speed = speedFor(creature)
	if speed <= 0 then
		return
	end
	local position = creature.part.Position
	local delta = goal - position
	local distance = delta.Magnitude
	local step = speed * dt
	if distance <= step then
		creature.part.CFrame = CFrame.new(goal) * creature.part.CFrame.Rotation
		if creature.state ~= "Chase" then
			table.remove(creature.path, 1)
		end
	else
		creature.part.CFrame = CFrame.lookAt(position + delta.Unit * step, goal)
	end
end

local function spawnCreature(
	kind: Kind,
	room: string,
	position: Vector3,
	size: number,
	color: Color3,
	initialState: State
): Creature
	local part = Instance.new("Part")
	part.Name = kind
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Position = position

	local light = Instance.new("PointLight")
	light.Range = size * 2.5
	light.Brightness = 2
	light.Parent = part

	part.Parent = Workspace

	local creature: Creature = {
		kind = kind,
		config = CreatureConfig[kind],
		part = part,
		light = light,
		state = initialState,
		path = {},
		room = room,
		stateUntil = 0,
		repathAt = 0,
		home = position,
		gone = false,
	}
	table.insert(creatures, creature)
	return creature
end

local function hasWarden(): boolean
	for _, creature in creatures do
		if creature.kind == "Warden" and not creature.gone then
			return true
		end
	end
	return false
end

local function wardenSpawnLoop()
	local config = CreatureConfig.Warden
	while true do
		task.wait(config.spawnCheckSeconds)
		if hasWarden() or not heaviestCarrier(config) or random:NextNumber() >= config.spawnChance then
			continue
		end
		local room = greybox.CreatureSpawnRoom
		spawnCreature("Warden", room, greybox.roomCenter(room), 10, Color3.fromRGB(60, 10, 10), "Hunt")
		for _, diver in eligibleDivers() do
			notifyRemote:FireClient(diver.player, "The water trembles... something is hunting heavy loot.")
		end
	end
end

function CreatureService.isNear(position: Vector3, radius: number): boolean
	for _, creature in creatures do
		-- A hidden Lurker stays a surprise: pings don't reveal it.
		if creature.state ~= "Hidden" and (creature.part.Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- Something made noise at `position`. Drifters within earshot investigate; a hidden Lurker
-- lunges if the noise is in its own room. Wardens ignore noise.
function CreatureService.emitNoise(position: Vector3, radius: number)
	for _, creature in creatures do
		if creature.kind == "Warden" then
			continue
		end
		local hearing = radius
			* creature.config.hearingMultiplier
			* (services.CurrentsService.current().hearingMultiplier or 1)
		local distance = (creature.part.Position - position).Magnitude
		if creature.kind == "Drifter" then
			if creature.state == "Chase" or distance > hearing then
				continue
			end
			routeTo(creature, position)
			creature.state = "Investigate"
			creature.searchUntil = nil
		elseif creature.kind == "Lurker" then
			if creature.state ~= "Hidden" or distance > hearing or greybox.roomAt(position) ~= creature.room then
				continue
			end
			local offset = position - creature.home
			local reach = math.min(offset.Magnitude, creature.config.lungeRange)
			creature.lastKnown = if offset.Magnitude > 0 then creature.home + offset.Unit * reach else creature.home
			creature.state = "Windup"
			creature.stateUntil = os.clock() + creature.config.windupSeconds
		end
	end
end

function CreatureService.init(allServices: any)
	services = allServices
	greybox = allServices.GreyboxService
end

function CreatureService.start()
	rayParams.FilterDescendantsInstances = { greybox.ZoneFolder }

	local drifterRoom = greybox.CreatureSpawnRoom
	spawnCreature("Drifter", drifterRoom, greybox.roomCenter(drifterRoom), 6, Color3.fromRGB(20, 30, 35), "Patrol")
	for _, spot in greybox.lurkerSpots() do
		spawnCreature("Lurker", spot.room, spot.position, 4, Color3.fromRGB(25, 20, 30), "Hidden")
	end
	task.spawn(wardenSpawnLoop)

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
		for i = #creatures, 1, -1 do
			if creatures[i].gone then
				creatures[i].part:Destroy()
				table.remove(creatures, i)
			end
		end
	end
end

return CreatureService
