--!strict
-- First-time user experience (doc/01 §4). New players start at a small, creature-free
-- tutorial cove, grab 3 glowing relics only they can take, get a harmless scripted scare,
-- then climb out to the main harbor to sell, upgrade, see their base and learn about squads.
-- Step rules live in Logic/Tutorial.luau (unit-tested); progress saves in profile.tutorial.
--
-- Players who have already extracted skip it. In Studio, set a boolean attribute
-- ForceTutorial = true on Workspace to replay it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local TutorialConfig = require(Shared.Config.Tutorial)
local Tutorial = require(Shared.Logic.Tutorial)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Geometry = require(script.Parent.Parent.Util.Geometry)

-- Cove layout: a platform with a shaft down into one flooded room, well away from the harbor.
local COVE = Vector3.new(0, 0, -300)
local COVE_SHAFT = 12
local COVE_ROOM = 36 -- interior width
local COVE_ROOM_HEIGHT = 14
local COVE_ROOM_TOP = -16 -- interior ceiling height
local COVE_SPAWN = COVE + Vector3.new(0, 3, -18)
local COVE_ENTRY = COVE + Vector3.new(0, -10, 0) -- near the shaft bottom (-14)
local RELIC_SPOTS = {
	Vector3.new(-10, -28.5, 8),
	Vector3.new(10, -28.5, 8),
	Vector3.new(0, -28.5, -12),
}

local COVE_STEPS = { dive = true, relics = true, escape = true }

local TutorialService = {}

local services: any
local relicsTaken: { [Player]: number } = {}
local stateRemote = Remotes.get("TutorialState")
local notifyRemote = Remotes.get("Notify")

local function buildCove()
	local folder = Instance.new("Folder")
	folder.Name = "TutorialCove"
	local wall = Geometry.WALL
	local roomCenter = COVE + Vector3.new(0, COVE_ROOM_TOP - COVE_ROOM_HEIGHT / 2, 0)
	local outer = COVE_ROOM + wall * 2

	-- Room: floor, ceiling with the shaft hole, four solid walls.
	Geometry.panel(
		folder,
		CFrame.new(roomCenter - Vector3.yAxis * (COVE_ROOM_HEIGHT / 2 + wall / 2)) * Geometry.FLAT,
		outer,
		outer,
		0,
		0
	)
	Geometry.panel(
		folder,
		CFrame.new(roomCenter + Vector3.yAxis * (COVE_ROOM_HEIGHT / 2 + wall / 2)) * Geometry.FLAT,
		outer,
		outer,
		COVE_SHAFT,
		COVE_SHAFT
	)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local wallCenter = roomCenter + dir * (COVE_ROOM / 2 + wall / 2)
		Geometry.panel(folder, CFrame.lookAt(wallCenter, wallCenter + dir), outer, COVE_ROOM_HEIGHT + wall * 2, 0, 0)
	end

	-- Shaft, ground platform with a hole, ladder on the boat side, boat and spawn.
	local shaftBottom = COVE_ROOM_TOP + wall
	Geometry.shaft(folder, COVE, COVE_SHAFT, shaftBottom, COVE.Y)
	Geometry.panel(
		folder,
		CFrame.new(COVE - Vector3.yAxis * (wall / 2)) * Geometry.FLAT,
		60,
		60,
		COVE_SHAFT,
		COVE_SHAFT
	)
	local ladder = Geometry.ladder(
		folder,
		COVE + Vector3.new(0, 0, -COVE_SHAFT / 2 + 1),
		COVE_ROOM_TOP - COVE_ROOM_HEIGHT,
		COVE.Y + 4
	)
	ladder.Name = "TutorialLadder"

	local boat = Geometry.block(folder, CFrame.new(COVE_SPAWN - Vector3.new(0, 2, 0)), Vector3.new(14, 2, 10))
	boat.Name = "CoveBoat"
	boat.Material = Enum.Material.WoodPlanks
	boat.Color = Color3.fromRGB(120, 85, 55)

	-- Water through shaft and room.
	local terrain = Workspace.Terrain
	terrain:FillBlock(
		CFrame.new(COVE.X, (COVE_ROOM_TOP + COVE.Y) / 2, COVE.Z),
		Vector3.new(COVE_SHAFT, COVE.Y - COVE_ROOM_TOP + wall, COVE_SHAFT),
		Enum.Material.Water
	)
	terrain:FillBlock(
		CFrame.new(roomCenter),
		Vector3.new(outer, COVE_ROOM_HEIGHT + wall * 2, outer),
		Enum.Material.Water
	)

	folder.Parent = Workspace
end

local function stepOf(player: Player): string?
	local profile = services.PlayerDataService.get(player)
	return profile and profile.tutorial.step
end

local function sendState(player: Player)
	local step = stepOf(player)
	if step then
		stateRemote:FireClient(player, step, relicsTaken[player] or 0)
	end
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		services.AntiCheatService.expectTeleport(player)
		character:PivotTo(CFrame.new(position))
	end
end

local function spawnTutorialRelics(player: Player)
	services.RelicService.removeOwnedBy(player.UserId)
	relicsTaken[player] = 0
	for i, relicKey in TutorialConfig.RelicKeys do
		local spot = RELIC_SPOTS[i]
		services.RelicService.spawnOwned(relicKey, TutorialConfig.Mutation, COVE + spot, player.UserId)
	end
end

local function advance(player: Player, event: Tutorial.Event, value: number?)
	local profile = services.PlayerDataService.get(player)
	if not profile then
		return
	end
	local before = profile.tutorial.step
	local after = Tutorial.next(before, event, value, TutorialConfig.RelicCount)
	if after == before then
		sendState(player)
		return
	end
	profile.tutorial.step = after

	if after == "relics" then
		spawnTutorialRelics(player)
	elseif after == "escape" then
		Remotes.get("TutorialScare"):FireClient(player)
	elseif after == "sell" then
		services.RelicService.removeOwnedBy(player.UserId)
		task.delay(1, teleport, player, services.GreyboxService.BoatSpawn)
	elseif after == "squad" then
		task.delay(TutorialConfig.SquadTipSeconds, function()
			if player.Parent == Players then
				advance(player, "squadTip")
			end
		end)
	elseif after == "done" then
		services.RelicService.removeOwnedBy(player.UserId)
		if COVE_STEPS[before] then
			teleport(player, services.GreyboxService.BoatSpawn)
		end
		if event ~= "skip" then
			notifyRemote:FireClient(player, "You're ready. Good luck down there, diver.")
		end
	end
	sendState(player)
end

-- Hooks called by other services ------------------------------------------------------------

-- Where the DIVE button should take this player, or nil for the main shaft.
function TutorialService.diveEntryFor(player: Player): Vector3?
	local step = stepOf(player)
	return if step and COVE_STEPS[step] then COVE_ENTRY else nil
end

function TutorialService.onDiveStarted(player: Player)
	local step = stepOf(player)
	if step == "dive" then
		advance(player, "diveStarted")
	elseif (step == "relics" or step == "escape") and not relicsTaken[player] then
		spawnTutorialRelics(player) -- rejoined mid-tutorial
		sendState(player)
	end
end

function TutorialService.onTutorialRelicTaken(player: Player)
	relicsTaken[player] = (relicsTaken[player] or 0) + 1
	advance(player, "relicTaken", relicsTaken[player])
end

function TutorialService.onExtracted(player: Player, carried: number)
	local step = stepOf(player)
	if step == "relics" or step == "escape" then
		relicsTaken[player] = nil
		advance(player, "extracted", carried)
	end
end

-- Died mid-tutorial: the next dive gets a fresh set of relics.
function TutorialService.onDied(player: Player)
	local step = stepOf(player)
	if step == "relics" or step == "escape" then
		relicsTaken[player] = nil
		services.RelicService.removeOwnedBy(player.UserId)
		if step == "escape" then
			local profile = services.PlayerDataService.get(player)
			if profile then
				profile.tutorial.step = "relics"
			end
		end
	end
end

function TutorialService.onSold(player: Player)
	advance(player, "sold")
end

function TutorialService.onUpgraded(player: Player)
	advance(player, "upgraded")
end

-- Lifecycle -----------------------------------------------------------------------------------

local function onProfileLoaded(player: Player, profile: any)
	local forced = RunService:IsStudio() and Workspace:GetAttribute("ForceTutorial") == true
	if forced then
		profile.tutorial.step = "dive"
	elseif profile.tutorial.step == "" then
		profile.tutorial.step = Tutorial.initialStep(profile.stats.extractions)
	end
	if COVE_STEPS[profile.tutorial.step] then
		teleport(player, COVE_SPAWN)
	end
	sendState(player)
end

function TutorialService.init(allServices: any)
	services = allServices
	buildCove()
	services.PlayerDataService.onProfileLoaded(onProfileLoaded)
end

function TutorialService.start()
	local allowSkip = RateLimiter.new(1, 2)
	Remotes.get("TutorialSkip").OnServerEvent:Connect(function(player)
		if allowSkip(player) then
			advance(player, "skip")
		end
	end)

	-- Respawns during the cove steps go back to the cove.
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local step = stepOf(player)
			if step and COVE_STEPS[step] then
				character:WaitForChild("HumanoidRootPart")
				task.wait(0.1)
				teleport(player, COVE_SPAWN)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		relicsTaken[player] = nil
		services.RelicService.removeOwnedBy(player.UserId)
	end)

	-- The base step completes by walking onto your plot.
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			if stepOf(player) ~= "base" then
				continue
			end
			local center = services.BaseService.plotCenter(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if center and root and (root.Position - center).Magnitude <= TutorialConfig.BaseReachDistance then
				advance(player, "reachedBase")
			end
		end
	end
end

return TutorialService
