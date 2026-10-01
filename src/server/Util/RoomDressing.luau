--!strict
-- Art pass over a grey-box room (doc/07): sandy floor, algae-stained brick, moss along the
-- walls, stone doorway frames, drowned windows, kelp and rubble. Purely visual: dressing parts
-- don't collide and are invisible to raycasts, so creature sight, hiding and movement play
-- exactly as in the grey box. Nothing here sits on the center-to-door lines or on relic spawns
-- (doc/07 §3), and there are no lights (red/amber would read as danger, doc/07 §2).

local RoomDressing = {}

local STONE = { material = Enum.Material.Brick, color = Color3.fromRGB(88, 100, 98) }
local FLOOR = { material = Enum.Material.Sand, color = Color3.fromRGB(128, 122, 100) }
local CEILING = { material = Enum.Material.Slate, color = Color3.fromRGB(60, 66, 68) }
local TRIM = { material = Enum.Material.Cobblestone, color = Color3.fromRGB(120, 126, 118) }
local MOSS = { material = Enum.Material.Grass, color = Color3.fromRGB(46, 78, 56) }
local WINDOW = { material = Enum.Material.Glass, color = Color3.fromRGB(14, 24, 28) }
local ROCK = { material = Enum.Material.Rock, color = Color3.fromRGB(82, 88, 84) }
local COLUMN = { material = Enum.Material.Concrete, color = Color3.fromRGB(122, 132, 126) }
local KELP_GREENS = {
	Color3.fromRGB(38, 92, 52),
	Color3.fromRGB(52, 104, 48),
	Color3.fromRGB(34, 80, 60),
	Color3.fromRGB(60, 96, 40),
}

export type Room = {
	center: Vector3,
	halfWidth: number, -- interior half-width
	height: number, -- interior height
	door: number, -- doorway size
	openDirections: { Vector3 }, -- walls with a doorway
	spawns: { Vector3 }, -- relic spawn points to keep clear
	vents: { Vector3 }, -- Lurker vent positions to keep clear
}

type Look = { material: Enum.Material, color: Color3 }

local function style(part: BasePart, look: Look)
	part.Material = look.material
	part.Color = look.color
end

local function prop(parent: Instance, cframe: CFrame, size: Vector3, look: Look, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	style(part, look)
	part.Parent = parent
	return part
end

local function isOpen(room: Room, dir: Vector3): boolean
	for _, open in room.openDirections do
		if open:FuzzyEq(dir, 1e-3) then
			return true
		end
	end
	return false
end

local function clearOf(points: { Vector3 }, position: Vector3, distance: number): boolean
	for _, point in points do
		local flat = Vector3.new(point.X - position.X, 0, point.Z - position.Z)
		if flat.Magnitude < distance then
			return false
		end
	end
	return true
end

-- Re-skins the structural parts already built for the room by which surface they are.
local function skinStructure(model: Model, room: Room)
	local floorY = room.center.Y - room.height / 2
	local ceilingY = room.center.Y + room.height / 2
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		-- Floor and ceiling panels sit half a wall outside the interior; wall pieces never do.
		if math.abs(part.Position.Y - (floorY - 1)) < 0.5 then
			style(part, FLOOR)
		elseif math.abs(part.Position.Y - (ceilingY + 1)) < 0.5 then
			style(part, CEILING)
		elseif part.Name == "Pillar" or part.Name == "Crate" or part.Name == "Vent" then
			continue
		else
			style(part, STONE)
		end
	end
end

local function dressWalls(model: Model, room: Room, random: Random)
	local c, half, floorY = room.center, room.halfWidth, room.center.Y - room.height / 2
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local side = dir:Cross(Vector3.yAxis) -- along the wall
		local face = c + dir * half -- inner face center (at room height)
		local facing = CFrame.lookAt(Vector3.zero, -dir) -- local Z points out of the wall

		-- Moss strip along the foot of the wall. X walls run corner to corner and Z walls fit
		-- between them, so strips never overlap at the corners (overlaps flicker).
		prop(
			model,
			CFrame.new(Vector3.new(face.X, floorY + 0.4, face.Z) - dir * 0.4) * facing,
			Vector3.new(if dir.X ~= 0 then half * 2 else half * 2 - 1.6, 0.8, 0.8),
			MOSS
		)

		if isOpen(room, dir) then
			-- Stone frame: two jambs and a lintel, just inside the doorway.
			local d = room.door / 2
			for _, s in { -1, 1 } do
				prop(
					model,
					CFrame.new(face - dir * 0.4 + side * s * (d + 0.75)) * facing,
					Vector3.new(1.5, room.door + 1.5, 0.8),
					TRIM
				)
			end
			prop(
				model,
				CFrame.new(face - dir * 0.4 + Vector3.yAxis * (d + 0.75)) * facing,
				Vector3.new(room.door + 3, 1.5, 0.8),
				TRIM
			)
		else
			-- Two drowned windows high on the wall, with sills. The vent (if any) sits low and
			-- in the middle, between them.
			for _, s in { -1, 1 } do
				local at = face - dir * 0.15 + side * s * (half / 2) + Vector3.yAxis * 4
				prop(model, CFrame.new(at) * facing, Vector3.new(5, 7, 0.3), WINDOW)
				prop(model, CFrame.new(at - dir * 0.3 - Vector3.yAxis * 3.8) * facing, Vector3.new(6, 0.6, 0.9), TRIM)
			end
		end

		-- A couple of rocks against the wall, off the door line and away from spawns and vents.
		for _ = 1, 2 do
			local along = (random:NextNumber() * 2 - 1) * (half - 3)
			if math.abs(along) < room.door / 2 + 3 then
				continue
			end
			local size = random:NextNumber(1.2, 3.2)
			local at = Vector3.new(face.X, floorY + size * 0.35, face.Z) - dir * (size / 2 + 0.5) + side * along
			if clearOf(room.spawns, at, 4) and clearOf(room.vents, at, 6) then
				prop(
					model,
					CFrame.new(at) * CFrame.Angles(random:NextNumber() * 6, random:NextNumber() * 6, 0),
					Vector3.new(size, size * 0.7, size * random:NextNumber(0.8, 1.3)),
					ROCK,
					if random:NextNumber() < 0.5 then Enum.PartType.Ball else Enum.PartType.Block
				)
			end
		end
	end
end

-- Kelp clumps in some corners. Corners are far from the center lines and the spawns.
local function plantKelp(model: Model, room: Room, random: Random)
	local floorY = room.center.Y - room.height / 2
	local reach = room.halfWidth - 3
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		if random:NextNumber() < 0.35 then
			continue
		end
		local base = room.center + corner * reach
		for _ = 1, random:NextInteger(3, 5) do
			local height = random:NextNumber(6, room.height - 6)
			local offset = Vector3.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
			local root = Vector3.new(base.X, floorY, base.Z) + offset
			if not clearOf(room.spawns, root, 3) then
				continue
			end
			local lean = CFrame.Angles(
				random:NextNumber(-0.15, 0.15),
				random:NextNumber() * 6.28,
				random:NextNumber(-0.15, 0.15)
			)
			local strand = CFrame.new(root) * lean * CFrame.new(0, height / 2, 0)
			prop(model, strand, Vector3.new(0.6, height, 0.2), {
				material = Enum.Material.Grass,
				color = KELP_GREENS[random:NextInteger(1, #KELP_GREENS)],
			})
		end
		prop(model, CFrame.new(base.X, floorY + 0.5, base.Z), Vector3.new(4, 1.4, 3.5), ROCK, Enum.PartType.Ball)
	end
end

-- Pillar blocks become columns with a base and a capital, same footprint (still cover).
local function carvePillars(model: Model, room: Room)
	local floorY = room.center.Y - room.height / 2
	local ceilingY = room.center.Y + room.height / 2
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Pillar" then
			local x, z = part.Position.X, part.Position.Z
			part.Transparency = 1 -- keeps its collision and sight blocking
			prop(
				model,
				CFrame.new(x, room.center.Y, z) * CFrame.Angles(0, 0, math.rad(90)),
				Vector3.new(room.height, 3.6, 3.6),
				COLUMN,
				Enum.PartType.Cylinder
			)
			prop(model, CFrame.new(x, floorY + 0.75, z), Vector3.new(5, 1.5, 5), TRIM)
			prop(model, CFrame.new(x, ceilingY - 0.75, z), Vector3.new(5, 1.5, 5), TRIM)
		end
	end
end

function RoomDressing.dress(model: Model, room: Room, random: Random)
	skinStructure(model, room)
	carvePillars(model, room)
	dressWalls(model, room, random)
	plantKelp(model, room, random)
end

return RoomDressing
