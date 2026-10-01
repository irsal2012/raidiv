--!strict
-- Today's current (daily modifier). Picked from the zone seed, so it rotates daily and a
-- ZoneSeed override reproduces it too. Other services read it at runtime (start phase or
-- later), after GreyboxService has chosen the seed during init.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CurrentsList = require(Shared.Config.Currents)
local OxygenConfig = require(Shared.Config.Oxygen)
local Relics = require(Shared.Config.Relics)
local Currents = require(Shared.Logic.Currents)
local Remotes = require(Shared.Net.Remotes)

local WELCOME_DELAY_SECONDS = 4

local CurrentsService = {}

local services: any
local cached: { current: CurrentsList.Current, relics: any, oxygen: any }? = nil

local function state()
	if not cached then
		local current = Currents.forSeed(CurrentsList, services.GreyboxService.Seed)
		cached = {
			current = current,
			relics = Currents.relics(Relics, current),
			oxygen = Currents.oxygen(OxygenConfig, current),
		}
	end
	return cached :: { current: CurrentsList.Current, relics: any, oxygen: any }
end

function CurrentsService.current(): CurrentsList.Current
	return state().current
end

-- Relics config with today's rarity/mutation odds.
function CurrentsService.relics(): any
	return state().relics
end

-- Oxygen config with today's drain.
function CurrentsService.oxygen(): any
	return state().oxygen
end

function CurrentsService.init(allServices: any)
	services = allServices
end

function CurrentsService.start()
	local current = CurrentsService.current()
	print(`[Currents] {current.name}: {current.description}`)

	-- Written on the plaza's current board (SurfaceDressing), facing the spawn.
	local post = services.GreyboxService.CurrentBoard :: BasePart

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = post
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = `TODAY'S CURRENT\n{current.name}\n{current.description}`
	text.Parent = gui

	local notifyRemote = Remotes.get("Notify")
	local function welcome(player: Player)
		task.delay(WELCOME_DELAY_SECONDS, function()
			if player.Parent == Players then
				notifyRemote:FireClient(player, `Today's current: {current.name}. {current.description}`)
			end
		end)
	end
	Players.PlayerAdded:Connect(welcome)
	for _, player in Players:GetPlayers() do
		welcome(player)
	end
end

return CurrentsService
