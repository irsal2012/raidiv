--!strict
-- Art pass over the surface hub (doc/07 §1: "bright afternoon, wooden docks, warm"): a stone
-- quay in a shallow harbor, a dive platform with a diver-down flag, a market stall around the
-- sell counter, a gear shed around the locker, lamp posts and a path to the player bases.
-- Everything the game code uses (spawn, shaft, ladder, SellCounter, GearLocker, their prompts,
-- the floating labels and base plots) keeps its position and size; this only restyles those
-- parts and builds around them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.Shared.Config.Hub)

local SurfaceDressing = {}

type Look = { material: Enum.Material, color: Color3 }

local function look(material: Enum.Material, r: number, g: number, b: number): Look
	return { material = material, color = Color3.fromRGB(r, g, b) }
end

local QUAY = look(Enum.Material.Cobblestone, 140, 134, 122)
local PLAZA = look(Enum.Material.Pavement, 176, 170, 158)
local BOARD = look(Enum.Material.SmoothPlastic, 22, 36, 46)
local RIM = look(Enum.Material.Concrete, 170, 164, 150)
local DECK = look(Enum.Material.WoodPlanks, 150, 110, 70)
local DARK_WOOD = look(Enum.Material.WoodPlanks, 92, 64, 42)
local HULL = look(Enum.Material.SmoothPlastic, 35, 62, 92)
local WHITE = look(Enum.Material.SmoothPlastic, 235, 235, 230)
local FLAG_RED = look(Enum.Material.Fabric, 200, 40, 40)
local TANK = look(Enum.Material.Metal, 230, 190, 40)
local IRON = look(Enum.Material.Metal, 55, 58, 62)
local BRASS = look(Enum.Material.Metal, 181, 146, 66)
local ROPE = look(Enum.Material.Fabric, 170, 150, 110)
local COUNTER = look(Enum.Material.WoodPlanks, 130, 90, 55)
local COUNTER_TRIM = look(Enum.Material.Metal, 200, 170, 60) -- the "gold counter" players learn
local AWNING_A = look(Enum.Material.Fabric, 200, 170, 60)
local AWNING_B = look(Enum.Material.Fabric, 240, 236, 225)
local LOCKER = look(Enum.Material.Metal, 60, 120, 200) -- the "blue locker" players learn
local FIN = look(Enum.Material.SmoothPlastic, 240, 200, 50)
local LAMP_GLOW = look(Enum.Material.Neon, 255, 228, 170)

local function style(part: BasePart, l: Look)
	part.Material = l.material
	part.Color = l.color
end

-- Scenery piece. `solid` ones block walking (crates, barrels); the rest are see-through to
-- movement so nothing traps a player or a spawn.
local function prop(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	l: Look,
	shape: Enum.PartType?,
	solid: boolean?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = solid == true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	style(part, l)
	part.Parent = parent
	return part
end

-- Upright cylinder (Cylinder parts run along X).
local function column(parent: Instance, base: Vector3, diameter: number, height: number, l: Look, solid: boolean?): Part
	return prop(
		parent,
		CFrame.new(base + Vector3.yAxis * height / 2) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		l,
		Enum.PartType.Cylinder,
		solid
	)
end

local function ring(parent: Instance, center: CFrame, radius: number, thickness: number, l: Look)
	local count = 10
	for i = 1, count do
		local angle = i / count * math.pi * 2
		prop(
			parent,
			center * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0),
			Vector3.new(thickness, thickness, 2 * math.pi * radius / count * 1.1),
			l
		)
	end
end

local function crate(parent: Instance, at: Vector3, size: number, yaw: number)
	local c = prop(
		parent,
		CFrame.new(at + Vector3.yAxis * size / 2) * CFrame.Angles(0, yaw, 0),
		Vector3.one * size,
		DARK_WOOD,
		nil,
		true
	)
	-- Plank bands so it reads as a crate, not a block.
	for _, y in { -0.3, 0.3 } do
		prop(parent, c.CFrame * CFrame.new(0, y * size, 0), Vector3.new(size + 0.1, 0.25, size + 0.1), DECK)
	end
end

local function barrel(parent: Instance, at: Vector3)
	column(parent, at, 2.4, 3.2, DARK_WOOD, true)
	for _, y in { 0.5, 2.7 } do
		column(parent, at + Vector3.yAxis * (y - 0.15), 2.55, 0.3, IRON)
	end
end

local function lampPost(parent: Instance, at: Vector3)
	column(parent, at, 0.5, 8, IRON, true)
	prop(parent, CFrame.new(at + Vector3.new(0, 8.2, 0)), Vector3.new(1.4, 0.3, 1.4), IRON)
	prop(parent, CFrame.new(at + Vector3.new(0, 7.4, 0)), Vector3.new(0.9, 1.2, 0.9), LAMP_GLOW)
end

-- Shallow harbor water around the quay. Kept above DiveService's dive depth (y -4), so wading
-- never starts a dive. `holes` are X/Z rectangles left dry (the quay, the tutorial cove).
local function harbor(holes: { { minX: number, maxX: number, minZ: number, maxZ: number } }, extent: number)
	local terrain = Workspace.Terrain
	-- Split the square [-extent, extent]² into strips around the holes, on a coarse grid.
	local step = 40
	for x = -extent, extent - step, step do
		for z = -extent, extent - step, step do
			local covered = false
			for _, hole in holes do
				if x + step > hole.minX and x < hole.maxX and z + step > hole.minZ and z < hole.maxZ then
					covered = true
					break
				end
			end
			if not covered then
				local center = Vector3.new(x + step / 2, 0, z + step / 2)
				terrain:FillBlock(
					CFrame.new(center - Vector3.yAxis * 6),
					Vector3.new(step, 4, step),
					Enum.Material.Sand
				)
				terrain:FillBlock(
					CFrame.new(center - Vector3.yAxis * 2),
					Vector3.new(step, 4, step),
					Enum.Material.Water
				)
			end
		end
	end
end

-- A notice board on two posts along the plaza's north edge, facing the spawn (-Z). Returns
-- the board face part; callers put a SurfaceGui on its Front.
local function board(parent: Instance, x: number, width: number, height: number, name: string): Part
	local bottom = HubConfig.BoardBottom
	local center = Vector3.new(x, bottom + height / 2, HubConfig.BoardZ)
	local facing = CFrame.lookAt(center, center - Vector3.zAxis)
	local face = prop(parent, facing, Vector3.new(width, height, 0.4), BOARD, nil, true)
	face.Name = name
	prop(parent, facing * CFrame.new(0, 0, 0.35), Vector3.new(width + 1, height + 1, 0.3), DARK_WOOD, nil, true)
	prop(parent, facing * CFrame.new(0, height / 2 + 0.6, 0.1), Vector3.new(width + 1.6, 0.4, 1.2), DARK_WOOD)
	for _, side in { -1, 1 } do
		local foot = (facing * CFrame.new(side * (width / 2 + 0.3), 0, 0.6)).Position
		column(parent, Vector3.new(foot.X, 0, foot.Z), 0.6, bottom + height + 0.6, DARK_WOOD, true)
	end
	return face
end

local function surfaceFrame(part: BasePart, face: Enum.NormalId): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	return frame
end

local function textLabel(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	color: Color3,
	font: Enum.Font,
	align: Enum.TextXAlignment?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = text
	l.Parent = parent
	return l
end

local HOW_TO_PLAY = {
	"1  Press DIVE, swim down (C sinks)",
	"2  Hold E on glowing relics",
	"3  Watch your air!",
	"4  Climb the yellow ladder to keep loot",
	"5  Sell at the gold stall, upgrade at the blue shed",
}

export type Boards = { leaderboard: Part, current: Part }

local function buildBoards(parent: Instance): Boards
	local how = HubConfig.HowToPlay
	local howBoard = board(parent, how.x, how.width, how.height, "HowToPlayBoard")
	local frame = surfaceFrame(howBoard, Enum.NormalId.Front)
	textLabel(
		frame,
		"HOW TO PLAY",
		UDim2.fromScale(0, 0.04),
		UDim2.fromScale(1, 0.16),
		Color3.fromRGB(80, 220, 200),
		Enum.Font.GothamBlack
	)
	for i, line in HOW_TO_PLAY do
		textLabel(
			frame,
			line,
			UDim2.fromScale(0.05, 0.25 + (i - 1) * 0.145),
			UDim2.fromScale(0.9, 0.11),
			Color3.new(1, 1, 1),
			Enum.Font.GothamBold,
			Enum.TextXAlignment.Left
		)
	end

	local lb, cur = HubConfig.Leaderboard, HubConfig.Current
	return {
		leaderboard = board(parent, lb.x, lb.width, lb.height, "LeaderboardBoard"),
		current = board(parent, cur.x, cur.width, cur.height, "CurrentBoard"),
	}
end

-- A post with an arrow board pointing along +X (side 1) or -X (side -1), text on both faces.
local function signpost(parent: Instance, at: Vector3, side: number, text: string)
	column(parent, at, 0.5, 6.5, DARK_WOOD, true)
	local arrowCenter = at + Vector3.new(side * 2.8, 5.4, 0)
	local arrow = prop(parent, CFrame.new(arrowCenter), Vector3.new(5, 1.4, 0.3), BOARD)
	-- Arrow tip: two wedges, upper and lower, whose thin edges meet at the point. A wedge's
	-- thin edge is at its front (-Z), so each looks outward along X; the lower one is flipped.
	local tipBase = arrowCenter + Vector3.new(side * 3.1, 0, 0)
	local outward = CFrame.lookAt(tipBase, tipBase + Vector3.new(side, 0, 0))
	for _, half in { 1, -1 } do
		prop(
			parent,
			outward * CFrame.new(0, half * 0.35, 0) * CFrame.Angles(0, 0, if half == 1 then 0 else math.pi),
			Vector3.new(0.3, 0.7, 1.2),
			BOARD,
			Enum.PartType.Wedge
		)
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		textLabel(
			surfaceFrame(arrow, face),
			text,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			Color3.fromRGB(230, 230, 230),
			Enum.Font.GothamBlack
		)
	end
end

export type Hub = {
	ground: { Part },
	shaftSize: number,
	boat: BasePart,
	counter: BasePart,
	locker: BasePart,
	quayHalf: number, -- the ground plate's half-width
	cove: Vector3, -- tutorial cove center, kept dry
	coveHalf: number,
}

function SurfaceDressing.dress(parent: Instance, hub: Hub): Boards
	local folder = Instance.new("Folder")
	folder.Name = "SurfaceDressing"
	folder.Parent = parent

	for _, part in hub.ground do
		style(part, QUAY)
	end

	-- Stone rim around the shaft. The X sides run the full length and the Z sides fit between
	-- them, so the corners don't overlap (overlapping coplanar faces flicker).
	local half = hub.shaftSize / 2 + 1
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local length = if dir.X ~= 0 then hub.shaftSize + 4 else hub.shaftSize
		prop(
			folder,
			CFrame.lookAt(dir * half + Vector3.yAxis * 0.6, dir * half + Vector3.yAxis * 0.6 + dir),
			Vector3.new(length, 1.2, 2),
			RIM,
			nil,
			true
		)
	end

	-- Paved plaza around the shaft, in four slabs that leave the shaft and its rim open.
	local px, minZ, maxZ, inner = HubConfig.PlazaHalfX, HubConfig.PlazaMinZ, HubConfig.PlazaMaxZ, half + 1
	for _, slab in
		{
			{ -px, px, minZ, -inner },
			{ -px, px, inner, maxZ },
			{ -px, -inner, -inner, inner },
			{ inner, px, -inner, inner },
		}
	do
		local x0, x1, z0, z1 = slab[1], slab[2], slab[3], slab[4]
		prop(folder, CFrame.new((x0 + x1) / 2, 0.05, (z0 + z1) / 2), Vector3.new(x1 - x0, 0.1, z1 - z0), PLAZA)
	end

	local boards = buildBoards(folder)
	-- Signposts at the plaza's east and west edges, pointing out to the base plots.
	for _, side in { -1, 1 } do
		signpost(folder, Vector3.new(side * (px - 2), 0, 2), side, "PLAYER BASES")
	end

	-- Dive platform: the boat block becomes a deck with a hull band, rails, flag mast and gear.
	local boat = hub.boat
	style(boat, DECK)
	local bs, bc = boat.Size, boat.CFrame
	prop(folder, bc * CFrame.new(0, -0.3, 0), Vector3.new(bs.X + 0.4, bs.Y * 0.7, bs.Z + 0.4), HULL)
	-- White trim stripe just under the deck surface. Its top must not be level with the deck,
	-- or the two faces z-fight (flicker) across the whole deck.
	prop(folder, bc * CFrame.new(0, bs.Y / 2 - 0.25, 0), Vector3.new(bs.X + 0.5, 0.3, bs.Z + 0.5), WHITE)
	local deckY = bs.Y / 2
	for _, x in { -bs.X / 2 + 0.2, bs.X / 2 - 0.2 } do
		for z = -bs.Z / 2 + 0.5, bs.Z / 2 - 0.5, 3 do
			prop(folder, bc * CFrame.new(x, deckY + 1.1, z), Vector3.new(0.25, 2.2, 0.25), IRON)
		end
		prop(folder, bc * CFrame.new(x, deckY + 2.2, 0), Vector3.new(0.2, 0.2, bs.Z - 0.6), IRON)
	end
	prop(folder, bc * CFrame.new(0, deckY + 2.2, -bs.Z / 2 + 0.2), Vector3.new(bs.X - 0.4, 0.2, 0.2), IRON)
	-- Diver-down flag (red with a white diagonal) on a mast at the bow corner.
	local mastBase = (bc * CFrame.new(bs.X / 2 - 1.2, deckY, -bs.Z / 2 + 1.2)).Position
	column(folder, mastBase, 0.35, 9, WHITE)
	local flag = prop(folder, CFrame.new(mastBase + Vector3.new(-1.7, 7.8, 0)), Vector3.new(3, 2, 0.1), FLAG_RED)
	prop(
		folder,
		flag.CFrame * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, 0, math.atan2(2, 3)),
		Vector3.new(3.4, 0.45, 0.05),
		WHITE
	)
	-- Air tanks and a rope coil on deck.
	for i = 0, 2 do
		column(folder, (bc * CFrame.new(-bs.X / 2 + 1, deckY, -bs.Z / 2 + 1.2 + i * 0.9)).Position, 0.75, 2.4, TANK)
	end
	ring(folder, bc * CFrame.new(-bs.X / 2 + 1.4, deckY + 0.2, bs.Z / 2 - 1.4), 0.7, 0.3, ROPE)

	-- Market stall around the sell counter: wood with the familiar gold trim, striped awning.
	local counter = hub.counter
	style(counter, COUNTER)
	local cs, cc = counter.Size, counter.CFrame
	prop(folder, cc * CFrame.new(0, cs.Y / 2 + 0.15, 0), Vector3.new(cs.X + 0.4, 0.3, cs.Z + 0.4), COUNTER_TRIM)
	-- The hub parts are axis-aligned and stand on the ground (y 0).
	local stallBase = cc.Position - Vector3.yAxis * cc.Position.Y
	local awningY = 5.6 -- below the floating label at y 7
	for _, x in { -cs.X / 2 - 0.5, cs.X / 2 + 0.5 } do
		for _, z in { -cs.Z / 2 - 1.5, cs.Z / 2 + 1.5 } do
			prop(
				folder,
				CFrame.new(stallBase + Vector3.new(x, awningY / 2, z)),
				Vector3.new(0.4, awningY, 0.4),
				DARK_WOOD
			)
		end
	end
	local stripes = 5
	local awningDepth = cs.Z + 3.4
	for i = 1, stripes do
		local x = -cs.X / 2 - 0.9 + (i - 0.5) * (cs.X + 1.8) / stripes
		prop(
			folder,
			CFrame.new(stallBase + Vector3.new(x, awningY + 0.1, 0)) * CFrame.Angles(math.rad(8), 0, 0),
			Vector3.new((cs.X + 1.8) / stripes, 0.2, awningDepth),
			if i % 2 == 1 then AWNING_A else AWNING_B
		)
	end
	crate(folder, stallBase + Vector3.new(cs.X / 2 + 3.5, 0, -3), 2.6, 0.2)
	crate(folder, stallBase + Vector3.new(cs.X / 2 + 3.5, 2.6, -3), 1.8, 0.7)
	barrel(folder, stallBase + Vector3.new(cs.X / 2 + 4, 0, 3))

	-- Gear shed around the locker: a back wall, a sloped roof, fins, a helmet and tanks.
	local locker = hub.locker
	style(locker, LOCKER)
	local ls, lc = locker.Size, locker.CFrame
	local lockerBase = lc.Position - Vector3.yAxis * lc.Position.Y
	local shedHeight = 5.4
	prop(
		folder,
		CFrame.new(lockerBase + Vector3.new(0, shedHeight / 2, -ls.Z / 2 - 2)),
		Vector3.new(ls.X + 4, shedHeight, 0.5),
		DARK_WOOD,
		nil,
		true
	)
	prop(
		folder,
		CFrame.new(lockerBase + Vector3.new(0, shedHeight + 0.2, 0)) * CFrame.Angles(math.rad(-10), 0, 0),
		Vector3.new(ls.X + 5, 0.4, ls.Z + 5),
		IRON
	)
	for _, x in { -ls.X / 2 - 1.8, ls.X / 2 + 1.8 } do
		prop(
			folder,
			CFrame.new(lockerBase + Vector3.new(x, shedHeight / 2, ls.Z / 2 + 2)),
			Vector3.new(0.4, shedHeight, 0.4),
			DARK_WOOD
		)
	end
	local wallFront = lockerBase + Vector3.new(0, 0, -ls.Z / 2 - 1.7)
	for i, x in { -3.2, -2.2 } do
		prop(
			folder,
			CFrame.new(wallFront + Vector3.new(x, 3.8, 0)) * CFrame.Angles(0, 0, math.rad(8 * i)),
			Vector3.new(0.9, 2.2, 0.15),
			FIN,
			Enum.PartType.Wedge
		)
	end
	prop(folder, CFrame.new(wallFront + Vector3.new(0.5, 4.2, 0.3)), Vector3.one * 1.6, BRASS, Enum.PartType.Ball)
	for i = 0, 1 do
		column(folder, lockerBase + Vector3.new(3 + i * 0.9, 0, -ls.Z / 2 - 1.2), 0.75, 2.6, TANK)
	end
	crate(folder, lockerBase + Vector3.new(-ls.X / 2 - 4, 0, 2), 2.4, -0.3)

	-- Lamp posts along the walkways (no lights: neon heads only, for performance).
	for _, at in
		{
			Vector3.new(-13, 0, -9),
			Vector3.new(13, 0, -9),
			Vector3.new(-13, 0, 16),
			Vector3.new(13, 0, 16),
			Vector3.new(-px + 2, 0, minZ + 2),
			Vector3.new(px - 2, 0, minZ + 2),
			Vector3.new(-px + 2, 0, maxZ - 2),
			Vector3.new(px - 2, 0, maxZ - 2),
		}
	do
		lampPost(folder, at)
	end

	-- Bollards and a rope coil near the quay's front edge.
	for x = -30, 30, 15 do
		column(folder, Vector3.new(x, 0, -hub.quayHalf + 3), 1.2, 1.6, IRON, true)
	end

	local q, c, h = hub.quayHalf, hub.cove, hub.coveHalf
	harbor({
		{ minX = -q, maxX = q, minZ = -q, maxZ = q },
		{ minX = c.X - h, maxX = c.X + h, minZ = c.Z - h, maxZ = c.Z + h },
	}, 600)
	return boards
end

return SurfaceDressing
