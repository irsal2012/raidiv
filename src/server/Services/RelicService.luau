--!strict
-- Relic spawning, server-validated pickup, and death drops.
-- A relic exists in exactly one place at a time: in the world (tracked here), in a dive
-- session's bag, or in a profile's inventory. Its id never changes, which keeps dupes traceable.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Relics = require(Shared.Config.Relics)
local Loot = require(Shared.Logic.Loot)
local Remotes = require(Shared.Net.Remotes)

-- Prompt range is 10; the extra covers latency.
local PICKUP_RANGE = 14
local RESPAWN_SECONDS = 60

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(85, 200, 110),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}

type WorldRelic = {
	relic: Types.RelicInstance,
	part: BasePart,
	slot: number?,
}

local RelicService = {}

local services: any
local worldRelics: { [string]: WorldRelic } = {}
local slotOccupant: { [number]: string } = {}
local folder: Folder
local random = Random.new()
local notifyRemote = Remotes.get("Notify")

local function rng(): number
	return random:NextNumber()
end

local function newRelic(relicKey: string, mutation: string?): Types.RelicInstance
	return {
		id = HttpService:GenerateGUID(false),
		relicKey = relicKey,
		mutation = mutation,
		obtainedAt = 0,
	}
end

local function tryPickup(player: Player, id: string)
	local entry = worldRelics[id]
	if not entry or not services.DiveService.getSession(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - entry.part.Position).Magnitude > PICKUP_RANGE then
		return
	end
	if not services.DiveService.addCarried(player, entry.relic) then
		notifyRemote:FireClient(player, "Bag full")
		return
	end

	worldRelics[id] = nil
	if entry.slot then
		slotOccupant[entry.slot] = nil
	end
	local position = entry.part.Position
	entry.part:Destroy()
	services.CreatureService.emitNoise(position, Relics.Defs[entry.relic.relicKey].noise)
end

local function spawnWorldRelic(relic: Types.RelicInstance, position: Vector3, slot: number?)
	local def = Relics.Defs[relic.relicKey]

	local part = Instance.new("Part")
	part.Name = relic.relicKey
	part.Size = Vector3.one * (1 + def.weight * 0.35)
	part.Anchored = true
	part.CanCollide = false
	part.Color = RARITY_COLORS[def.rarity]
	part.Material = if relic.mutation then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Position = position

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = if relic.mutation then `{relic.mutation} {def.displayName}` else def.displayName
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		tryPickup(player, relic.id)
	end)

	part.Parent = folder
	worldRelics[relic.id] = { relic = relic, part = part, slot = slot }
	if slot then
		slotOccupant[slot] = relic.id
	end
end

local function fillEmptySlots()
	for slot, position in services.GreyboxService.relicSpawns() do
		if slotOccupant[slot] then
			continue
		end
		local relicKey, mutation = Loot.rollRelic(Relics, rng)
		if relicKey then
			spawnWorldRelic(newRelic(relicKey, mutation), position, slot)
		end
	end
end

-- Puts relics back into the world around `position` (death or disconnect mid-dive).
function RelicService.dropAt(position: Vector3, relics: { Types.RelicInstance })
	for _, relic in relics do
		local offset = Vector3.new(random:NextNumber(-3, 3), 0, random:NextNumber(-3, 3))
		spawnWorldRelic(relic, position + offset, nil)
	end
end

function RelicService.init(allServices: any)
	services = allServices
end

function RelicService.start()
	folder = Instance.new("Folder")
	folder.Name = "Relics"
	folder.Parent = Workspace

	fillEmptySlots()
	while true do
		task.wait(RESPAWN_SECONDS)
		-- Phase 1 has one shared zone; don't pop relics in while someone is looking.
		local anyoneDiving = false
		for _, player in Players:GetPlayers() do
			if services.DiveService.getSession(player) then
				anyoneDiving = true
				break
			end
		end
		if not anyoneDiving then
			fillEmptySlots()
		end
	end
end

return RelicService
