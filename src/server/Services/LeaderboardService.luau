--!strict
-- The plaza's global leaderboard: "TOP SALVAGERS", lifetime Coins earned from selling
-- (profile.stats.earned) across every server. An OrderedDataStore keyed by UserId holds the
-- scores. Every RefreshSeconds this server writes the scores of its players that changed,
-- then reads the top list and redraws the board. Studio uses a separate store (see
-- Config/Leaderboard). Every DataStore call is pcall-guarded: if the store is unavailable
-- (e.g. Studio without API access) the board says so and the game carries on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Leaderboard)
local Format = require(Shared.Logic.Format)

local LeaderboardService = {}

local services: any
local store: OrderedDataStore? = nil
local written: { [number]: number } = {} -- UserId -> score last written by this server
local names: { [number]: string } = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local SILVER = Color3.fromRGB(215, 220, 230)
local BRONZE = Color3.fromRGB(215, 145, 90)
local WHITE = Color3.new(1, 1, 1)
local TEAL = Color3.fromRGB(80, 220, 200)

type Row = { rank: TextLabel, name: TextLabel, score: TextLabel }
local rows: { Row } = {}
local status: TextLabel

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.DisplayName else nil
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok then result else "Diver"
	end
	names[userId] = name :: string
	return name :: string
end

local function cell(
	parent: Instance,
	x: number,
	width: number,
	y: number,
	height: number,
	align: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextXAlignment = align
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildBoard(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = part

	local title = cell(gui, 0, 1, 0.03, 0.1, Enum.TextXAlignment.Center)
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = GOLD
	title.Text = "TOP SALVAGERS"
	local subtitle = cell(gui, 0, 1, 0.13, 0.05, Enum.TextXAlignment.Center)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextColor3 = TEAL
	subtitle.Text = "Lifetime Coins from selling relics"

	local top, height = 0.21, 0.072
	for i = 1, Config.Size do
		local y = top + (i - 1) * height
		table.insert(rows, {
			rank = cell(gui, 0.05, 0.1, y, height * 0.85, Enum.TextXAlignment.Left),
			name = cell(gui, 0.16, 0.54, y, height * 0.85, Enum.TextXAlignment.Left),
			score = cell(gui, 0.7, 0.25, y, height * 0.85, Enum.TextXAlignment.Right),
		})
	end
	status = cell(gui, 0, 1, 0.94, 0.045, Enum.TextXAlignment.Center)
	status.Font = Enum.Font.Gotham
	status.TextColor3 = TEAL
	status.Text = "Loading..."
end

local function render(entries: { { key: string, value: number } })
	for i, row in rows do
		local entry = entries[i]
		local color = if i == 1 then GOLD elseif i == 2 then SILVER elseif i == 3 then BRONZE else WHITE
		row.rank.TextColor3, row.name.TextColor3, row.score.TextColor3 = color, color, color
		if entry then
			row.rank.Text = `#{i}`
			row.name.Text = nameOf(tonumber(entry.key) or 0)
			row.score.Text = Format.compact(entry.value)
		else
			row.rank.Text, row.name.Text, row.score.Text = "", "", ""
		end
	end
	status.Text = if #entries == 0 then "Be the first: sell some relics!" else "Updates every minute"
end

-- Writes this player's score if it changed since this server last wrote it.
local function writeScore(player: Player)
	local profile = services.PlayerDataService.get(player)
	if not store or not profile then
		return
	end
	local score = math.floor(profile.stats.earned)
	if score <= 0 or written[player.UserId] == score then
		return
	end
	local ok = pcall(store.SetAsync, store, tostring(player.UserId), score)
	if ok then
		written[player.UserId] = score
	end
end

local function refresh()
	if not store then
		status.Text = "Leaderboard unavailable"
		return
	end
	for _, player in Players:GetPlayers() do
		writeScore(player)
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Size)
	if not ok then
		status.Text = "Leaderboard unavailable right now"
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage() :: any
	render(entries)
end

function LeaderboardService.init(allServices: any)
	services = allServices
end

function LeaderboardService.start()
	local board = services.GreyboxService.LeaderboardBoard :: BasePart?
	if not board then
		return
	end
	buildBoard(board)

	local name = if RunService:IsStudio() then Config.StudioStoreName else Config.StoreName
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	store = if ok then result else nil

	Players.PlayerRemoving:Connect(function(player)
		writeScore(player) -- best effort: the profile may already be released; the last refresh wrote it anyway
		written[player.UserId] = nil
	end)

	task.spawn(function()
		task.wait(Config.FirstRefreshSeconds)
		while true do
			refresh()
			task.wait(Config.RefreshSeconds)
		end
	end)
end

return LeaderboardService
