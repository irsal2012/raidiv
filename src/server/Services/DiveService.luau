--!strict
-- Dive sessions: start, oxygen, swim speed, lamp, extraction and death.
-- Phase 1: everyone dives into one shared grey-box zone. Per-squad instances come in Phase 2.
--
-- A dive starts when a player sinks below GreyboxService.DiveStartY (jumping in, or the DIVE
-- button teleporting them into the shaft) and ends when they climb out (extraction), die, or leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Gear = require(Shared.Config.Gear)
local OxygenConfig = require(Shared.Config.Oxygen)
local Relics = require(Shared.Config.Relics)
local SquadConfig = require(Shared.Config.Squad)
local SwimConfig = require(Shared.Config.Swim)
local Loot = require(Shared.Logic.Loot)
local OxygenMath = require(Shared.Logic.OxygenMath)
local SwimMath = require(Shared.Logic.SwimMath)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local TICK_SECONDS = 0.2
local LAMP_NAME = "DiveLamp"

export type Session = {
	oxygen: number,
	maxOxygen: number,
	baseSpeed: number,
	sprinting: boolean,
	lampOn: boolean,
	carried: { Types.RelicInstance },
	weight: number,
	capacity: number,
	-- Downed: waiting for a squadmate to revive. Oxygen is paused and the body is frozen.
	downed: boolean,
	downedUntil: number,
	revivePrompt: ProximityPrompt?,
	-- Analytics
	startedAt: number,
	carriedValue: number, -- sell value picked up this dive; kept after a death drop
	deathCause: string?,
}

local DiveService = {}

local services: any
local sessions: { [Player]: Session } = {}

local diveStateRemote = Remotes.get("DiveState")
local notifyRemote = Remotes.get("Notify")

local function getBody(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function getLamp(player: Player): SpotLight?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return head and head:FindFirstChild(LAMP_NAME) :: SpotLight?
end

local function sendState(player: Player, session: Session?)
	local state: Types.DiveState = if session
		then {
			diving = true,
			oxygen = session.oxygen,
			maxOxygen = session.maxOxygen,
			weight = session.weight,
			capacity = session.capacity,
			lampOn = session.lampOn,
			downed = session.downed,
			downedSecondsLeft = if session.downed then math.max(0, session.downedUntil - os.clock()) else 0,
		}
		else {
			diving = false,
			oxygen = 0,
			maxOxygen = 0,
			weight = 0,
			capacity = 0,
			lampOn = false,
			downed = false,
			downedSecondsLeft = 0,
		}
	diveStateRemote:FireClient(player, state)
end

local function setLamp(player: Player, session: Session, on: boolean)
	session.lampOn = on
	local lamp = getLamp(player)
	if lamp then
		lamp.Enabled = on
	end
	sendState(player, session)
end

local function startDive(player: Player)
	local profile = services.PlayerDataService.get(player)
	if not profile or sessions[player] then
		return
	end

	local session: Session = {
		oxygen = Gear.valueAt("tank", profile.gear.tank) or 0,
		maxOxygen = Gear.valueAt("tank", profile.gear.tank) or 0,
		baseSpeed = Gear.valueAt("fins", profile.gear.fins) or SwimConfig.SurfaceWalkSpeed,
		sprinting = false,
		lampOn = true,
		carried = {},
		weight = 0,
		capacity = Gear.valueAt("bag", profile.gear.bag) or 0,
		downed = false,
		downedUntil = 0,
		startedAt = os.clock(),
		carriedValue = 0,
	}
	sessions[player] = session
	profile.stats.dives += 1
	services.AnalyticsService.onboardingStep(player, "FirstDive")

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		local lamp = getLamp(player) or Instance.new("SpotLight")
		lamp.Name = LAMP_NAME
		lamp.Face = Enum.NormalId.Front
		lamp.Angle = 70
		lamp.Brightness = 4
		lamp.Range = math.min(60, Gear.valueAt("lamp", profile.gear.lamp) or 30)
		lamp.Enabled = true
		lamp.Parent = head
	end

	sendState(player, session)
end

function DiveService.getSession(player: Player): Session?
	return sessions[player]
end

-- Adds a relic to the player's bag. Returns false if it doesn't fit.
function DiveService.addCarried(player: Player, relic: Types.RelicInstance): boolean
	local session = sessions[player]
	if not session or session.downed then
		return false
	end
	local weight = Relics.Defs[relic.relicKey].weight
	if session.weight + weight > session.capacity then
		return false
	end
	relic.obtainedAt = os.time()
	table.insert(session.carried, relic)
	session.weight += weight
	session.carriedValue += Loot.sellValue(Relics, relic.relicKey, relic.mutation)
	sendState(player, session)
	services.AnalyticsService.onboardingStep(player, "FirstRelic")
	return true
end

-- Unfreezes the body and removes the revive prompt. Safe to call when not downed.
local function clearDowned(player: Player, session: Session)
	session.downed = false
	if session.revivePrompt then
		session.revivePrompt:Destroy()
		session.revivePrompt = nil
	end
	local root = getBody(player)
	if root then
		root.Anchored = false
	end
end

local function revive(rescuer: Player, downedPlayer: Player)
	local session = sessions[downedPlayer]
	local rescuerSession = sessions[rescuer]
	if not session or not session.downed or not rescuerSession or rescuerSession.downed then
		return
	end
	if not services.SquadService.areSquadmates(rescuer, downedPlayer) then
		return
	end
	local rescuerRoot = getBody(rescuer)
	local downedRoot = getBody(downedPlayer)
	if not rescuerRoot or not downedRoot or (rescuerRoot.Position - downedRoot.Position).Magnitude > 14 then
		return
	end

	clearDowned(downedPlayer, session)
	session.deathCause = nil
	session.oxygen = math.max(session.oxygen, session.maxOxygen * SquadConfig.ReviveOxygenFraction)
	sendState(downedPlayer, session)
	notifyRemote:FireClient(downedPlayer, `{rescuer.DisplayName} revived you!`)
	notifyRemote:FireClient(rescuer, `You revived {downedPlayer.DisplayName}`)
	services.AnalyticsService.revived(rescuer)
end

local function goDown(player: Player, session: Session, root: BasePart, cause: string)
	session.downed = true
	session.downedUntil = os.clock() + SquadConfig.ReviveWindowSeconds
	session.deathCause = cause
	session.sprinting = false
	root.Anchored = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = SquadConfig.ReviveHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(rescuer)
		revive(rescuer, player)
	end)
	session.revivePrompt = prompt

	for _, member in services.SquadService.members(player) do
		if member ~= player then
			notifyRemote:FireClient(
				member,
				`{player.DisplayName} is down! Revive them within {SquadConfig.ReviveWindowSeconds}s`
			)
		end
	end
	sendState(player, session)
end

function DiveService.endDive(player: Player, reason: "extracted" | "died" | "left")
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	clearDowned(player, session)
	services.AnalyticsService.diveEnded(
		player,
		reason,
		os.clock() - session.startedAt,
		session.carriedValue,
		session.deathCause,
		#services.SquadService.members(player)
	)

	local profile = services.PlayerDataService.get(player)
	if profile and reason == "extracted" then
		for _, relic in session.carried do
			table.insert(profile.inventory, relic)
			profile.collection[relic.relicKey] = true
		end
		profile.stats.extractions += 1
		services.AnalyticsService.onboardingStep(player, "FirstExtraction")
		local count = #session.carried
		notifyRemote:FireClient(
			player,
			if count > 0 then `Extracted with {count} relic(s)!` else "Extracted empty-handed"
		)
	elseif profile and reason == "died" then
		profile.stats.deaths += 1
		notifyRemote:FireClient(player, "You didn't make it. Your loot is where you fell.")
	end

	if reason ~= "left" then
		local lamp = getLamp(player)
		if lamp then
			lamp.Enabled = false
		end
		local _, humanoid = getBody(player)
		if humanoid then
			humanoid.WalkSpeed = SwimConfig.SurfaceWalkSpeed
		end
		sendState(player, nil)
	end
end

-- Takes a diving player out and records why. With a diving squadmate who could revive them
-- they go down first; otherwise they die. Use instead of setting Health directly.
function DiveService.kill(player: Player, cause: "oxygen" | "creature")
	local session = sessions[player]
	local root, humanoid = getBody(player)
	if not session or session.downed or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if services.SquadService.hasDivingSquadmate(player) then
		goDown(player, session, root, cause)
	else
		session.deathCause = cause
		humanoid.Health = 0
	end
end

-- Carried relics go back into the world at the player's position for squadmates to recover.
local function dropCarried(player: Player, session: Session)
	local root = getBody(player)
	if root and #session.carried > 0 then
		services.RelicService.dropAt(root.Position, session.carried)
	end
	session.carried = {}
	session.weight = 0
end

local function tick(dt: number)
	local greybox = services.GreyboxService
	for _, player in Players:GetPlayers() do
		local root, humanoid = getBody(player)
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local session = sessions[player]
		if not session then
			if root.Position.Y < greybox.DiveStartY then
				startDive(player)
			end
			continue
		end

		if session.downed then
			if os.clock() >= session.downedUntil then
				-- Nobody came. Unfreeze first so dropped loot lands where the body is.
				clearDowned(player, session)
				humanoid.Health = 0
			else
				sendState(player, session)
			end
			continue
		end

		if root.Position.Y > greybox.ExtractAboveY then
			DiveService.endDive(player, "extracted")
			continue
		end

		session.oxygen = OxygenMath.step(OxygenConfig, session.oxygen, dt, session.sprinting, session.weight)
		humanoid.WalkSpeed =
			SwimMath.speed(SwimConfig, session.baseSpeed, session.sprinting, session.weight, session.capacity)
		if session.sprinting then
			services.CreatureService.emitNoise(root.Position, SwimConfig.SprintNoiseRadius)
		end
		if session.oxygen <= 0 then
			DiveService.kill(player, "oxygen")
		end
		sendState(player, session)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local session = sessions[player]
		if session then
			dropCarried(player, session)
			DiveService.endDive(player, "died")
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function DiveService.init(allServices: any)
	services = allServices
end

function DiveService.start()
	local greybox = services.GreyboxService

	local allowStartDive = RateLimiter.new(1, 2)
	Remotes.get("StartDive").OnServerEvent:Connect(function(player)
		if not allowStartDive(player) or sessions[player] then
			return
		end
		local root, humanoid = getBody(player)
		if root and humanoid and humanoid.Health > 0 and root.Position.Y > greybox.DiveStartY then
			(player.Character :: Model):PivotTo(CFrame.new(greybox.DiveEntry))
		end
	end)

	local allowSprint = RateLimiter.new(10, 10)
	Remotes.get("SetSprint").OnServerEvent:Connect(function(player, sprinting)
		if not allowSprint(player) or typeof(sprinting) ~= "boolean" then
			return
		end
		local session = sessions[player]
		if session then
			session.sprinting = sprinting
		end
	end)

	local allowLamp = RateLimiter.new(5, 5)
	Remotes.get("SetLamp").OnServerEvent:Connect(function(player, on)
		if not allowLamp(player) or typeof(on) ~= "boolean" then
			return
		end
		local session = sessions[player]
		if session then
			setLamp(player, session, on)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			dropCarried(player, session)
			DiveService.endDive(player, "left")
		end
	end)

	while true do
		tick(task.wait(TICK_SECONDS))
	end
end

return DiveService
