--!strict
-- All game audio. Sound ids come from Config/Audio; empty ids are skipped, so this is silent
-- until audio is added. Creature cues are 3D (parented to the creature) and driven by the
-- "State" attribute CreatureService sets; everything else plays on the listener.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = Shared:WaitForChild("Config")
local AudioIds = require(Config:WaitForChild("Audio"))
local OxygenConfig = require(Config:WaitForChild("Oxygen"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local CREATURES = { Drifter = true, Lurker = true, Warden = true }

local AudioController = {}

local function makeSound(name: string, parent: Instance, looped: boolean, volume: number): Sound?
	local id = (AudioIds :: any)[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = parent
	return sound
end

local function playOnce(name: string, parent: Instance?, volume: number?)
	local sound = makeSound(name, parent or SoundService, false, volume or 0.8)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

-- Creature cues follow the server-set State attribute.
local function watchCreature(part: Instance)
	if not part:IsA("BasePart") or not CREATURES[part.Name] then
		return
	end
	local chase = makeSound("CreatureChase", part, true, 0.9)
	if chase then
		chase.RollOffMaxDistance = 90
	end
	if part.Name == "Warden" then
		playOnce("WardenArrive", part, 1)
	end
	part:GetAttributeChangedSignal("State"):Connect(function()
		local state = part:GetAttribute("State")
		local chasing = state == "Chase" or state == "Hunt"
		if chase then
			if chasing and not chase.IsPlaying then
				chase:Play()
			elseif not chasing and chase.IsPlaying then
				chase:Stop()
			end
		end
		if state == "Investigate" then
			playOnce("CreatureAlert", part, 0.8)
		elseif state == "Windup" then
			playOnce("LurkerWindup", part, 1)
		end
	end)
end

function AudioController.start()
	local ambience = makeSound("Ambience", SoundService, true, 0.4)
	local breathing = makeSound("Breathing", SoundService, true, 0.3)

	local wasDiving = false
	local lastWeight = 0
	Remotes.get("DiveState").OnClientEvent:Connect(function(state: Types.DiveState)
		if state.diving ~= wasDiving then
			for _, loop in { ambience, breathing } do
				if loop then
					if state.diving then
						loop:Play()
					else
						loop:Stop()
					end
				end
			end
			-- A dive ending with loot while alive is an extraction (a death also ends the dive).
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not state.diving and lastWeight > 0 and humanoid and humanoid.Health > 0 then
				playOnce("Extract")
			end
		end
		if state.diving and state.weight > lastWeight then
			playOnce("Pickup")
		end
		if breathing and state.diving then
			local fraction = if state.maxOxygen > 0 then state.oxygen / state.maxOxygen else 1
			local low = fraction < OxygenConfig.LowOxygenThreshold
			breathing.PlaybackSpeed = if low then 1.5 else 1
			breathing.Volume = if low then 0.7 else 0.3
		end
		wasDiving = state.diving
		lastWeight = if state.diving then state.weight else 0
	end)

	Remotes.get("TutorialScare").OnClientEvent:Connect(function()
		playOnce("Stinger", nil, 1)
	end)
	Remotes.get("SonarPing").OnClientEvent:Connect(function()
		playOnce("Sonar", nil, 0.6)
	end)

	for _, child in Workspace:GetChildren() do
		watchCreature(child)
	end
	Workspace.ChildAdded:Connect(watchCreature)
end

return AudioController
