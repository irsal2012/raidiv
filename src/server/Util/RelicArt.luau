--!strict
-- Relic models (doc/07 §4): each of the 30 relics built from a handful of parts, so a compass
-- looks like a compass. Models are drawn in a unit box and scaled to the relic's old cube size,
-- so pickup range, prompts and spacing are unchanged. Rarity reads from a shimmering ring
-- under world relics (plus the glow light RelicService adds); mutations restyle the whole model
-- as doc/07 §2 describes. Unknown relic keys fall back to the old grey-box shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Palette = require(Shared.Config.Palette)
local Relics = require(Shared.Config.Relics)

local RelicArt = {}

type Look = { material: Enum.Material, color: Color3, transparency: number? }

local function look(material: Enum.Material, r: number, g: number, b: number, transparency: number?): Look
	return { material = material, color = Color3.fromRGB(r, g, b), transparency = transparency }
end

local BRASS = look(Enum.Material.Metal, 181, 146, 66)
local RUST = look(Enum.Material.CorrodedMetal, 130, 78, 48)
local SILVER = look(Enum.Material.Metal, 196, 200, 206)
local GOLD = look(Enum.Material.Foil, 220, 180, 70)
local COPPER = look(Enum.Material.Metal, 190, 112, 70)
local BRONZE = look(Enum.Material.Metal, 160, 110, 60)
local IRON = look(Enum.Material.Metal, 70, 72, 76)
local WOOD = look(Enum.Material.Wood, 120, 82, 50)
local DARKWOOD = look(Enum.Material.WoodPlanks, 80, 55, 35)
local PORCELAIN = look(Enum.Material.SmoothPlastic, 236, 236, 228)
local BLUEPAINT = look(Enum.Material.SmoothPlastic, 60, 90, 160)
local GLASS = look(Enum.Material.Glass, 150, 210, 200, 0.35)
local GREENGLASS = look(Enum.Material.Glass, 70, 140, 90, 0.3)
local JADE = look(Enum.Material.Glass, 70, 170, 120, 0.1)
local LEATHER = look(Enum.Material.Fabric, 92, 58, 36)
local PAPER = look(Enum.Material.SmoothPlastic, 220, 210, 180)
local ROPE = look(Enum.Material.Fabric, 170, 150, 110)
local BLACK = look(Enum.Material.SmoothPlastic, 25, 25, 28)
local AQUA_GEM = look(Enum.Material.Neon, 90, 230, 220)
local PURPLE_GEM = look(Enum.Material.Neon, 160, 90, 255)

-- Drawing kit. All sizes and offsets are in the unit box; `s` scales them to the world.
type Kit = {
	box: (Look, Vector3, CFrame?) -> BasePart,
	cyl: (Look, number, number, CFrame?) -> BasePart, -- diameter, height (along Y)
	ball: (Look, number, CFrame?) -> BasePart,
	ell: (Look, Vector3, CFrame?) -> BasePart,
	wedge: (Look, Vector3, CFrame?) -> BasePart,
	ring: (Look, number, number, CFrame?, number?) -> (), -- radius, thickness, frame (ring in its XZ plane)
}

local function newKit(model: Model, s: number): Kit
	local function make(l: Look, size: Vector3, cf: CFrame?, shape: Enum.PartType?, mesh: Enum.MeshType?): BasePart
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			part.Shape = shape
		end
		part.Size = size * s
		local frame = cf or CFrame.identity
		part.CFrame = frame.Rotation + frame.Position * s
		part.Material = l.material
		part.Color = l.color
		part.Transparency = l.transparency or 0
		if mesh then
			local special = Instance.new("SpecialMesh")
			special.MeshType = mesh
			special.Parent = part
		end
		part.Parent = model
		return part
	end
	local kit = {} :: Kit
	kit.box = function(l, size, cf)
		return make(l, size, cf)
	end
	kit.cyl = function(l, diameter, height, cf)
		-- Cylinder parts run along X; turn them upright.
		return make(
			l,
			Vector3.new(height, diameter, diameter),
			(cf or CFrame.identity) * CFrame.Angles(0, 0, math.pi / 2),
			Enum.PartType.Cylinder
		)
	end
	kit.ball = function(l, diameter, cf)
		return make(l, Vector3.one * diameter, cf, Enum.PartType.Ball)
	end
	kit.ell = function(l, size, cf)
		return make(l, size, cf, nil, Enum.MeshType.Sphere)
	end
	kit.wedge = function(l, size, cf)
		return make(l, size, cf, Enum.PartType.Wedge)
	end
	kit.ring = function(l, radius, thickness, cf, segments)
		local count = segments or 10
		local length = 2 * math.pi * radius / count * 1.08
		for i = 1, count do
			local angle = i / count * math.pi * 2
			local at = (cf or CFrame.identity) * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0)
			make(l, Vector3.new(thickness, thickness, length), at)
		end
	end
	return kit
end

local up = CFrame.new
local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Builders --------------------------------------------------------------------------------------

local function compass(k: Kit, case: Look, face: Look)
	k.cyl(case, 0.9, 0.22, up(0, -0.2, 0))
	k.cyl(face, 0.72, 0.04, up(0, -0.08, 0))
	k.box(BLUEPAINT, Vector3.new(0.6, 0.03, 0.07), up(0, -0.05, 0) * rot(0, 35, 0))
	k.ball(case, 0.14, up(0, -0.2, -0.48))
	k.ring(case, 0.08, 0.03, up(0, -0.2, -0.58) * rot(90, 0, 0), 6)
end

local function watch(k: Kit, case: Look)
	k.cyl(case, 0.8, 0.2, up(0, -0.25, 0))
	k.cyl(PORCELAIN, 0.64, 0.04, up(0, -0.14, 0))
	k.box(BLACK, Vector3.new(0.03, 0.02, 0.26), up(0, -0.11, -0.1))
	k.box(BLACK, Vector3.new(0.2, 0.02, 0.03), up(0.09, -0.11, 0))
	k.cyl(case, 0.12, 0.12, up(0, -0.25, -0.45) * rot(90, 0, 0))
	k.ring(case, 0.09, 0.035, up(0, -0.25, -0.58) * rot(90, 0, 0), 6)
end

local MODELS: { [string]: (Kit) -> () } = {
	RustyCompass = function(k)
		compass(k, RUST, look(Enum.Material.Glass, 190, 200, 180, 0.2))
	end,
	CrackedTeacup = function(k)
		k.cyl(PORCELAIN, 1, 0.06, up(0, -0.42, 0))
		k.cyl(PORCELAIN, 0.62, 0.42, up(0, -0.2, 0))
		k.cyl(look(Enum.Material.SmoothPlastic, 90, 70, 50), 0.54, 0.02, up(0, 0.01, 0))
		k.cyl(BLUEPAINT, 0.64, 0.06, up(0, -0.1, 0))
		k.ring(PORCELAIN, 0.12, 0.05, up(0.36, -0.2, 0) * rot(90, 0, 0), 6)
	end,
	BentSpoon = function(k)
		k.box(SILVER, Vector3.new(0.08, 0.04, 0.5), up(0, -0.4, 0.22))
		k.box(SILVER, Vector3.new(0.08, 0.04, 0.35), up(0, -0.3, -0.15) * rot(25, 0, 0))
		k.ell(SILVER, Vector3.new(0.34, 0.1, 0.44), up(0, -0.22, -0.45) * rot(25, 0, 0))
	end,
	GlassFloat = function(k)
		k.ball(GREENGLASS, 0.85)
		k.ring(ROPE, 0.43, 0.04)
		k.ring(ROPE, 0.43, 0.04, rot(90, 0, 0))
	end,
	CopperCoin = function(k)
		k.cyl(COPPER, 0.9, 0.12, up(0, -0.44, 0))
		k.cyl(look(Enum.Material.Metal, 150, 88, 55), 0.6, 0.14, up(0, -0.43, 0))
	end,
	BrokenPocketWatch = function(k)
		watch(k, SILVER)
		k.box(BLACK, Vector3.new(0.5, 0.01, 0.02), up(0, -0.115, 0) * rot(0, 60, 0)) -- crack
	end,
	SodaBottle = function(k)
		k.cyl(GREENGLASS, 0.45, 0.55, up(0, -0.2, 0))
		k.ball(GREENGLASS, 0.45, up(0, 0.08, 0))
		k.cyl(GREENGLASS, 0.18, 0.3, up(0, 0.3, 0))
		k.cyl(RUST, 0.2, 0.05, up(0, 0.46, 0))
	end,
	FishingReel = function(k)
		k.cyl(IRON, 0.8, 0.08, up(-0.2, 0, 0) * rot(0, 0, 90))
		k.cyl(IRON, 0.8, 0.08, up(0.2, 0, 0) * rot(0, 0, 90))
		k.cyl(ROPE, 0.55, 0.36, rot(0, 0, 90))
		k.box(BRASS, Vector3.new(0.06, 0.4, 0.06), up(0.28, 0.12, 0))
		k.cyl(DARKWOOD, 0.1, 0.18, up(0.36, 0.3, 0) * rot(0, 0, 90))
	end,
	RopeCleat = function(k)
		k.box(IRON, Vector3.new(0.3, 0.12, 0.3), up(0, -0.44, 0))
		k.box(IRON, Vector3.new(0.14, 0.3, 0.14), up(0, -0.25, 0))
		k.box(IRON, Vector3.new(1, 0.14, 0.18), up(0, -0.08, 0))
		k.ring(ROPE, 0.14, 0.06, up(0.25, -0.08, 0) * rot(0, 0, 90), 6)
	end,
	OldBoot = function(k)
		k.box(LEATHER, Vector3.new(0.34, 0.55, 0.38), up(0, -0.05, 0.15))
		k.box(LEATHER, Vector3.new(0.34, 0.25, 0.7), up(0, -0.32, -0.02))
		k.box(BLACK, Vector3.new(0.36, 0.06, 0.74), up(0, -0.47, -0.02))
		k.box(DARKWOOD, Vector3.new(0.36, 0.06, 0.4), up(0, 0.2, 0.15))
	end,
	BrassBell = function(k)
		k.cyl(BRASS, 0.9, 0.12, up(0, -0.42, 0))
		k.cyl(BRASS, 0.75, 0.25, up(0, -0.25, 0))
		k.cyl(BRASS, 0.55, 0.3, up(0, 0.02, 0))
		k.ell(BRASS, Vector3.new(0.55, 0.3, 0.55), up(0, 0.17, 0))
		k.ring(BRASS, 0.1, 0.05, up(0, 0.38, 0) * rot(90, 0, 0), 6)
	end,
	HarborLantern = function(k)
		k.box(IRON, Vector3.new(0.6, 0.1, 0.6), up(0, -0.45, 0))
		k.cyl(look(Enum.Material.Glass, 200, 230, 210, 0.4), 0.45, 0.55, up(0, -0.13, 0))
		for _, x in { -0.26, 0.26 } do
			for _, z in { -0.26, 0.26 } do
				k.box(IRON, Vector3.new(0.05, 0.6, 0.05), up(x, -0.13, z))
			end
		end
		k.wedge(IRON, Vector3.new(0.6, 0.2, 0.3), up(0, 0.26, 0.15))
		k.wedge(IRON, Vector3.new(0.6, 0.2, 0.3), up(0, 0.26, -0.15) * rot(0, 180, 0))
		k.ring(IRON, 0.1, 0.04, up(0, 0.44, 0) * rot(90, 0, 0), 6)
	end,
	WheelSpoke = function(k)
		k.cyl(WOOD, 0.18, 1, rot(0, 0, 80))
		k.ball(WOOD, 0.26, up(-0.42, -0.08, 0))
		k.cyl(DARKWOOD, 0.26, 0.12, up(0.1, 0.02, 0) * rot(0, 0, 80))
		k.cyl(BRASS, 0.24, 0.06, up(0.3, 0.05, 0) * rot(0, 0, 80))
	end,
	PorcelainVase = function(k)
		k.cyl(PORCELAIN, 0.4, 0.1, up(0, -0.45, 0))
		k.ell(PORCELAIN, Vector3.new(0.75, 0.6, 0.75), up(0, -0.12, 0))
		k.cyl(PORCELAIN, 0.3, 0.35, up(0, 0.3, 0))
		k.cyl(PORCELAIN, 0.42, 0.05, up(0, 0.47, 0))
		k.cyl(BLUEPAINT, 0.76, 0.08, up(0, -0.12, 0))
	end,
	SilverLocket = function(k)
		k.ell(SILVER, Vector3.new(0.6, 0.72, 0.16), up(0, -0.05, 0))
		k.ell(look(Enum.Material.Metal, 150, 155, 165), Vector3.new(0.4, 0.5, 0.18), up(0, -0.05, 0))
		k.ring(SILVER, 0.18, 0.03, up(0, 0.42, 0) * rot(90, 0, 0), 8)
	end,
	TelegraphKey = function(k)
		k.box(DARKWOOD, Vector3.new(0.9, 0.15, 0.5), up(0, -0.42, 0))
		k.box(BRASS, Vector3.new(0.7, 0.06, 0.1), up(0.05, -0.25, 0) * rot(0, 0, -6))
		k.box(BRASS, Vector3.new(0.12, 0.14, 0.12), up(-0.25, -0.3, 0))
		k.cyl(BLACK, 0.22, 0.1, up(0.4, -0.17, 0))
		k.cyl(BRASS, 0.12, 0.08, up(0.25, -0.31, 0.15))
	end,
	HelmetVisor = function(k)
		k.ell(BRASS, Vector3.new(0.9, 0.85, 0.9))
		k.cyl(GLASS, 0.48, 0.08, up(0, 0, -0.43) * rot(90, 0, 0))
		k.ring(BRASS, 0.26, 0.06, up(0, 0, -0.45) * rot(90, 0, 0), 10)
		for _, x in { -0.3, 0.3 } do
			k.ball(BRASS, 0.1, up(x, 0.25, -0.35))
		end
	end,
	CannonBall = function(k)
		k.ball(IRON, 0.95)
		k.cyl(BLACK, 0.14, 0.04, up(0, 0.47, 0))
	end,
	SilverChalice = function(k)
		k.cyl(SILVER, 0.55, 0.06, up(0, -0.46, 0))
		k.cyl(SILVER, 0.1, 0.4, up(0, -0.23, 0))
		k.ball(SILVER, 0.18, up(0, -0.12, 0))
		k.cyl(SILVER, 0.34, 0.12, up(0, 0.02, 0))
		k.cyl(SILVER, 0.6, 0.35, up(0, 0.25, 0))
		k.cyl(PURPLE_GEM, 0.12, 0.62, up(0, 0.22, 0) * rot(90, 0, 0))
	end,
	CaptainsLogbook = function(k)
		k.box(LEATHER, Vector3.new(0.75, 0.22, 0.95), up(0, -0.38, 0))
		k.box(PAPER, Vector3.new(0.68, 0.16, 0.9), up(0.04, -0.38, 0))
		k.box(BRASS, Vector3.new(0.06, 0.24, 0.3), up(0.38, -0.38, 0))
	end,
	GoldPocketWatch = function(k)
		watch(k, GOLD)
	end,
	Figurehead = function(k)
		k.ell(WOOD, Vector3.new(0.35, 0.4, 0.35), up(0, 0.3, -0.25))
		k.box(look(Enum.Material.Wood, 70, 45, 30), Vector3.new(0.4, 0.2, 0.2), up(0, 0.35, -0.1)) -- hair
		k.wedge(WOOD, Vector3.new(0.4, 0.6, 0.45), up(0, -0.05, -0.05) * rot(0, 180, 0))
		k.wedge(look(Enum.Material.Wood, 60, 110, 110), Vector3.new(0.35, 0.3, 0.6), up(0, -0.35, 0.25))
		k.wedge(look(Enum.Material.Wood, 60, 110, 110), Vector3.new(0.5, 0.12, 0.25), up(0, -0.42, 0.5))
	end,
	BronzeAstrolabe = function(k)
		k.ring(BRONZE, 0.4, 0.06, rot(90, 0, 0), 12)
		k.ring(BRONZE, 0.4, 0.05, rot(90, 90, 0), 12)
		k.ring(BRONZE, 0.3, 0.04, rot(30, 0, 0), 10)
		k.ball(BRONZE, 0.16)
		k.cyl(BRONZE, 0.3, 0.06, up(0, -0.46, 0))
	end,
	JadeCompass = function(k)
		compass(k, JADE, look(Enum.Material.SmoothPlastic, 225, 230, 215))
	end,
	CaptainsSextant = function(k)
		k.wedge(BRASS, Vector3.new(0.06, 0.7, 0.6), up(0, 0, 0))
		k.ring(BRASS, 0.42, 0.05, up(0, -0.1, 0) * rot(0, 0, 90), 12)
		k.cyl(BRASS, 0.12, 0.55, up(0.08, 0.15, -0.1) * rot(90, 0, 0))
		k.box(DARKWOOD, Vector3.new(0.1, 0.3, 0.1), up(-0.1, -0.2, 0.2))
		k.cyl(GLASS, 0.1, 0.02, up(0.08, 0.15, -0.38) * rot(90, 0, 0))
	end,
	BellClapper = function(k)
		k.ball(IRON, 0.62, up(0, -0.18, 0))
		k.cyl(IRON, 0.14, 0.55, up(0, 0.3, 0))
		k.ring(IRON, 0.1, 0.05, up(0, 0.6, 0) * rot(90, 0, 0), 6)
	end,
	MayorsSeal = function(k)
		k.cyl(BRONZE, 0.8, 0.12, up(0, -0.44, 0))
		k.cyl(BRONZE, 0.25, 0.4, up(0, -0.18, 0))
		k.ball(DARKWOOD, 0.34, up(0, 0.1, 0))
		k.cyl(look(Enum.Material.Metal, 120, 80, 45), 0.55, 0.13, up(0, -0.43, 0))
	end,
	ClockworkSquid = function(k)
		k.ell(COPPER, Vector3.new(0.45, 0.7, 0.45), up(0, 0.1, 0))
		k.ball(GLASS, 0.14, up(0.12, 0.05, -0.2))
		k.ball(GLASS, 0.14, up(-0.12, 0.05, -0.2))
		for i = 1, 6 do
			local angle = i / 6 * 360
			k.box(BRASS, Vector3.new(0.06, 0.05, 0.45), rot(0, angle, 0) * up(0, -0.35, -0.2) * rot(-25, 0, 0))
		end
		k.box(BRASS, Vector3.new(0.05, 0.2, 0.2), up(0, 0.35, 0.25))
	end,
	DrownedCrown = function(k)
		k.ring(GOLD, 0.38, 0.12, up(0, -0.35, 0), 12)
		for i = 1, 6 do
			local angle = i / 6 * 360
			k.wedge(GOLD, Vector3.new(0.12, 0.35, 0.16), rot(0, angle, 0) * up(0, -0.12, -0.38))
			k.ball(if i % 2 == 0 then AQUA_GEM else PURPLE_GEM, 0.1, rot(0, angle + 30, 0) * up(0, -0.35, -0.44))
		end
	end,
	HarborHeart = function(k)
		k.ell(AQUA_GEM, Vector3.new(0.45, 0.6, 0.45))
		k.ell(look(Enum.Material.Glass, 120, 220, 230, 0.55), Vector3.new(0.7, 0.9, 0.7))
		k.ring(GOLD, 0.37, 0.04, CFrame.identity, 12)
		k.ring(GOLD, 0.37, 0.04, rot(90, 0, 0), 12)
	end,
}

-- Mutations -------------------------------------------------------------------------------------

local function mutate(model: Model, mutation: string, s: number, random: Random)
	local parts: { BasePart } = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	if mutation == "Glowing" then
		for _, part in parts do
			part.Material = Enum.Material.Neon
			part.Color = part.Color:Lerp(Color3.fromRGB(150, 255, 235), 0.35)
		end
	elseif mutation == "Gilded" then
		for _, part in parts do
			part.Material = Enum.Material.Foil
			part.Color = GOLD.color
			part.Transparency = 0
		end
	elseif mutation == "Cursed" then
		for _, part in parts do
			part.Material = Enum.Material.Slate
			part.Color = Color3.fromRGB(42, 22, 52)
		end
		local wisp = Instance.new("Part")
		wisp.Name = "CurseWisp"
		wisp.Anchored = true
		wisp.CanCollide = false
		wisp.CanQuery = false
		wisp.CanTouch = false
		wisp.Shape = Enum.PartType.Ball
		wisp.Material = Enum.Material.Neon
		wisp.Color = Color3.fromRGB(150, 60, 220)
		wisp.Transparency = 0.35
		wisp.Size = Vector3.one * 0.25 * s
		wisp.CFrame = CFrame.new(0, 0.75 * s, 0)
		wisp.Parent = model
	elseif mutation == "Barnacled" then
		for _, part in parts do
			part.Material = Enum.Material.Slate
			part.Color = part.Color:Lerp(Color3.fromRGB(80, 100, 85), 0.5)
		end
		-- Barnacles stuck to random pieces.
		for _ = 1, 5 do
			local host = parts[random:NextInteger(1, #parts)]
			local offset =
				Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5))
			local barnacle = Instance.new("Part")
			barnacle.Anchored = true
			barnacle.CanCollide = false
			barnacle.CanQuery = false
			barnacle.CanTouch = false
			barnacle.Shape = Enum.PartType.Ball
			barnacle.Material = Enum.Material.Pebble
			barnacle.Color = Color3.fromRGB(215, 210, 195)
			barnacle.Size = Vector3.one * random:NextNumber(0.1, 0.18) * s
			barnacle.CFrame = host.CFrame * CFrame.new(host.Size * offset)
			barnacle.Parent = model
		end
	end
end

-- Public ----------------------------------------------------------------------------------------

-- A model of `relicKey` about `size` studs across, centered on the origin (pivot it into place).
-- `halo` adds the rarity ring for relics lying in the world.
function RelicArt.build(relicKey: string, mutation: string?, size: number, halo: boolean): Model
	local def = Relics.Defs[relicKey]
	local model = Instance.new("Model")
	model.Name = "Art"
	local kit = newKit(model, size)
	local builder = MODELS[relicKey]
	if builder then
		builder(kit)
	else
		local shape = (Enum.PartType :: any)[def and def.shape or "Block"]
		local part = kit.box(look(Enum.Material.SmoothPlastic, 170, 170, 170), Vector3.one) :: Part
		part.Shape = shape
	end
	if mutation then
		mutate(model, mutation, size, Random.new(#relicKey))
	end
	if halo and def then
		local ring = Instance.new("Part")
		ring.Name = "RarityHalo"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.ForceField
		ring.Color = Palette.Rarity[def.rarity]
		ring.Size = Vector3.new(0.05, 1.5, 1.5) * size
		ring.CFrame = CFrame.new(0, -0.5 * size, 0) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

return RelicArt
