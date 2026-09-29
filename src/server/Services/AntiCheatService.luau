--!strict
-- Server-side exploit checks (doc/02 §4.6). Flags and logs; never bans.
--   Movement: every 0.5 s, horizontal distance vs the player's server-set WalkSpeed. Suspicious
--     moves are logged; flagrant ones (teleports) also pull the player back to their last good
--     spot. Server teleports call expectTeleport() first so they aren't flagged.
--   Economy: Coins gained per rolling minute above a threshold are logged.
-- Rules live in Logic/Movement.luau (unit-tested); thresholds in Config/AntiCheat.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.AntiCheat)
local Movement = require(Shared.Logic.Movement)

local FLAG_LOG_COOLDOWN = 10 -- seconds between analytics logs per player per kind

type Track = {
	last: Vector3?,
	lastGood: Vector3?,
	lastCheck: number,
	graceUntil: number,
	maxSpeed: number,
	coinEvents: { { at: number, amount: number } },
	lastLogged: { [string]: number },
}

local AntiCheatService = {}

local services: any
local tracks: { [Player]: Track } = {}

local function trackOf(player: Player): Track
	local track = tracks[player]
	if not track then
		track = { lastCheck = os.clock(), graceUntil = 0, maxSpeed = 0, coinEvents = {}, lastLogged = {} }
		tracks[player] = track
	end
	return track
end

local function flag(player: Player, kind: string, detail: string)
	local track = trackOf(player)
	local now = os.clock()
	warn(`[AntiCheat] {player.Name} ({player.UserId}) {kind}: {detail}`)
	if now - (track.lastLogged[kind] or -math.huge) >= FLAG_LOG_COOLDOWN then
		track.lastLogged[kind] = now
		services.AnalyticsService.exploitFlag(player, kind)
	end
end

-- Call right before the server moves a player's character, so the jump isn't flagged.
function AntiCheatService.expectTeleport(player: Player)
	local track = trackOf(player)
	track.graceUntil = os.clock() + Config.TeleportGraceSeconds
	track.last = nil
end

-- Called by PlayerDataService for every Coin gain.
function AntiCheatService.onCoins(player: Player, amount: number)
	local track = trackOf(player)
	local now = os.clock()
	table.insert(track.coinEvents, { at = now, amount = amount })
	local total = 0
	for i = #track.coinEvents, 1, -1 do
		local event = track.coinEvents[i]
		if now - event.at > 60 then
			table.remove(track.coinEvents, i)
		else
			total += event.amount
		end
	end
	if total > Config.CoinsPerMinuteAlert then
		flag(player, "economy", `{total} Coins in the last minute`)
	end
end

local function check(player: Player, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local track = trackOf(player)
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		track.last = nil
		return
	end

	local position = root.Position
	-- Use the higher of this window's and last window's speed: sprint may just have ended.
	local maxSpeed = math.max(track.maxSpeed, humanoid.WalkSpeed)
	track.maxSpeed = humanoid.WalkSpeed

	local last = track.last
	if now < track.graceUntil or not last then
		track.last, track.lastGood, track.lastCheck = position, position, now
		return
	end

	local horizontal = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
	local verdict = Movement.judge(
		horizontal,
		now - track.lastCheck,
		maxSpeed,
		Config.SpeedTolerance,
		Config.SlackStuds,
		Config.FlagrantFactor
	)
	track.lastCheck = now

	if verdict == "ok" then
		track.last, track.lastGood = position, position
	elseif verdict == "suspicious" then
		flag(player, "speed", `{math.floor(horizontal)} studs in {Config.CheckSeconds}s at WalkSpeed {maxSpeed}`)
		track.last = position
	else
		flag(player, "teleport", `{math.floor(horizontal)} studs in {Config.CheckSeconds}s`)
		local lastGood = track.lastGood or last;
		(character :: Model):PivotTo(CFrame.new(lastGood))
		track.last = lastGood
	end
end

function AntiCheatService.init(allServices: any)
	services = allServices
end

function AntiCheatService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			AntiCheatService.expectTeleport(player) -- spawning is a teleport
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)

	while true do
		task.wait(Config.CheckSeconds)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			check(player, now)
		end
	end
end

return AntiCheatService
