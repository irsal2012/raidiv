--!strict
-- Creature art (doc/07 §4). The server moves each creature as one anchored ball and colours its
-- PointLight by state (teal calm, amber alerted, red attacking). Here every client hides that
-- ball and draws a body that follows it and animates every frame, so the server does no extra
-- work and behaviour is untouched. Glowing parts take the light's colour, keeping the state
-- cue players learn.
--   Drifter: ghostly jellyfish, glowing core, swaying tentacles.
--   Lurker: eel peering from its vent; only its eyes show while hidden.
--   Warden: huge anglerfish with teeth and a glowing lure.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CreatureVisualsController = {}

type Visual = {
	core: BasePart,
	light: PointLight?,
	update: (now: number, dt: number) -> (),
	parts: { BasePart },
}

local visuals: { [BasePart]: Visual } = {}
local folder: Folder

local function piece(size: Vector3, color: Color3, material: Enum.Material?, shape: string?): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ellipsoid" then
		-- A sphere mesh stretches to the part's size, unlike a Ball part.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif shape == "wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = part
	elseif shape == "cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = folder
	return part
end

-- Upright frame at the core, turned to where it's heading (ignores pitch).
local function uprightFrame(core: BasePart): CFrame
	local look = core.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(core.Position)
	end
	return CFrame.lookAt(core.Position, core.Position + flat)
end

local function stateColor(visual: Visual, fallback: Color3): Color3
	-- The light may replicate a moment after its part.
	local light = visual.light or visual.core:FindFirstChildOfClass("PointLight")
	visual.light = light
	return if light then light.Color else fallback
end

-- Drifter -------------------------------------------------------------------------------------

local function buildDrifter(core: BasePart, visual: Visual)
	local k = core.Size.X / 6
	local bell = piece(Vector3.new(6, 4, 6) * k, Color3.fromRGB(80, 120, 130), nil, "ellipsoid")
	bell.Transparency = 0.35
	local heart = piece(Vector3.new(2.6, 1.8, 2.6) * k, Color3.new(1, 1, 1), Enum.Material.Neon, "ellipsoid")
	heart.Transparency = 0.25
	local eyes = {}
	for _ = 1, 2 do
		table.insert(eyes, piece(Vector3.one * 0.45 * k, Color3.new(1, 1, 1), Enum.Material.Neon, "ellipsoid"))
	end
	local tentacles = {}
	for i = 1, 8 do
		local length = (4.5 + (i % 3) * 1.2) * k
		local strand = piece(Vector3.new(0.25 * k, length, 0.25 * k), Color3.fromRGB(150, 190, 195))
		strand.Transparency = 0.4
		table.insert(tentacles, { part = strand, length = length, angle = (i / 8) * math.pi * 2 })
	end
	for _, p in { bell, heart, table.unpack(eyes) } do
		table.insert(visual.parts, p)
	end
	for _, t in tentacles do
		table.insert(visual.parts, t.part)
	end

	visual.update = function(now)
		local frame = uprightFrame(core) * CFrame.new(0, math.sin(now * 1.3) * 0.4 * k, 0)
		local pulse = 1 + 0.08 * math.sin(now * 2.6)
		bell.Size = Vector3.new(6 * pulse, 4 / pulse, 6 * pulse) * k
		bell.CFrame = frame
		local glow = stateColor(visual, Color3.fromRGB(80, 220, 200))
		heart.Color = glow
		heart.CFrame = frame * CFrame.new(0, -0.3 * k, 0)
		for i, eye in eyes do
			eye.Color = glow
			eye.CFrame = frame * CFrame.new((i == 1 and -0.9 or 0.9) * k, 0.1 * k, -2.75 * k)
		end
		for i, t in tentacles do
			local root = frame * CFrame.new(math.cos(t.angle) * 2 * k, -1.4 * k, math.sin(t.angle) * 2 * k)
			local sway = CFrame.Angles(math.sin(now * 2 + i) * 0.3, 0, math.cos(now * 1.6 + i * 1.3) * 0.3)
			t.part.CFrame = root * sway * CFrame.new(0, -t.length / 2, 0)
		end
	end
end

-- Lurker --------------------------------------------------------------------------------------

local SEGMENTS = 6

local function buildLurker(core: BasePart, visual: Visual)
	local k = core.Size.X / 4
	-- It spawns facing nowhere in particular; face out of the nearest vent instead.
	local restLook = Vector3.zAxis
	local zone = Workspace:FindFirstChild("Zone")
	if zone then
		local best = math.huge
		for _, vent in zone:GetDescendants() do
			if vent:IsA("BasePart") and vent.Name == "Vent" then
				local distance = (vent.Position - core.Position).Magnitude
				if distance < best and distance < 8 then
					best = distance
					restLook = -vent.CFrame.LookVector -- the vent looks at the wall
				end
			end
		end
	end

	local skin = Color3.fromRGB(40, 36, 48)
	local head = piece(Vector3.new(1.8, 1.4, 2.8) * k, skin, nil, "ellipsoid")
	local jaw = piece(Vector3.new(1.4, 0.5, 2.0) * k, Color3.fromRGB(30, 26, 36), nil, "wedge")
	local eyes = {}
	for _ = 1, 2 do
		table.insert(eyes, piece(Vector3.one * 0.5 * k, Color3.new(1, 1, 1), Enum.Material.Neon, "ellipsoid"))
	end
	local segments = {}
	for i = 1, SEGMENTS do
		local s = (1 - i / (SEGMENTS + 2)) * 1.5 * k
		table.insert(segments, piece(Vector3.new(s, s, s * 1.4), skin, nil, "ellipsoid"))
	end
	for _, p in { head, jaw, table.unpack(eyes) } do
		table.insert(visual.parts, p)
	end
	for _, s in segments do
		table.insert(visual.parts, s)
	end

	-- The body follows the path the head took.
	local trail: { Vector3 } = { core.Position }
	local spacing = 1.1 * k

	visual.update = function(now)
		local state = core:GetAttribute("State")
		local shown = state == "Windup" or state == "Lunge" or state == "Retreat"
		local position = core.Position
		if (position - trail[#trail]).Magnitude > spacing * 0.5 then
			table.insert(trail, position)
			if #trail > SEGMENTS * 3 then
				table.remove(trail, 1)
			end
		end

		local look = if state == "Lunge" or state == "Retreat" then core.CFrame.LookVector else restLook
		if state == "Retreat" then
			look = -look -- it backs into the vent head first toward the room
		end
		local frame = CFrame.lookAt(position, position + look)
		if state == "Windup" then
			frame *= CFrame.new(math.sin(now * 40) * 0.08 * k, 0, 0) -- trembling
		end

		local glow = stateColor(visual, Color3.fromRGB(80, 220, 200))
		head.CFrame = frame
		jaw.CFrame = frame * CFrame.new(0, -0.55 * k, -0.4 * k) * CFrame.Angles(if shown then 0.35 else 0, 0, 0)
		for i, eye in eyes do
			eye.Color = if shown then glow else Color3.fromRGB(150, 200, 180)
			eye.Transparency = if shown then 0 else 0.8 -- a faint glint in the dark vent
			eye.CFrame = frame * CFrame.new((i == 1 and -0.55 or 0.55) * k, 0.35 * k, -1.1 * k)
		end
		head.Transparency = if shown then 0 else 1
		jaw.Transparency = head.Transparency
		for i, segment in segments do
			local point = trail[#trail - i]
			local ahead = if i == 1 then position else segments[i - 1].Position
			local at = if point and shown and state ~= "Windup" then point else position - look * spacing * i
			local wave = CFrame.new(0, math.sin(now * 6 - i) * 0.2 * k, 0)
			segment.CFrame = CFrame.lookAt(at, ahead) * wave
			segment.Transparency = if shown and state ~= "Windup" then 0 else 1
		end
	end
end

-- Warden --------------------------------------------------------------------------------------

local function buildWarden(core: BasePart, visual: Visual)
	local k = core.Size.X / 10
	local hide = Color3.fromRGB(58, 30, 34)
	local body = piece(Vector3.new(9, 7.5, 12) * k, hide, Enum.Material.Slate, "ellipsoid")
	local jaw = piece(Vector3.new(8, 2.5, 5) * k, Color3.fromRGB(44, 22, 26), Enum.Material.Slate, "wedge")
	local teeth = {}
	for i = 1, 7 do
		local tooth = piece(Vector3.new(0.5, 1.4, 0.5) * k, Color3.fromRGB(225, 220, 200), nil, "wedge")
		table.insert(teeth, { part = tooth, x = (i - 4) * 1.05 * k })
	end
	local eyes = {}
	for _ = 1, 2 do
		table.insert(eyes, piece(Vector3.one * 0.8 * k, Color3.new(1, 1, 1), Enum.Material.Neon, "ellipsoid"))
	end
	local stalk = piece(Vector3.new(4.5 * k, 0.35 * k, 0.35 * k), hide, nil, "cylinder")
	local bulb = piece(Vector3.one * 1.3 * k, Color3.new(1, 1, 1), Enum.Material.Neon, "ellipsoid")
	local tail = piece(Vector3.new(0.6, 5, 4) * k, hide, Enum.Material.Slate, "wedge")
	local fins = {}
	for _ = 1, 2 do
		table.insert(fins, piece(Vector3.new(0.4, 2.5, 3.5) * k, hide, Enum.Material.Slate, "wedge"))
	end
	for _, p in { body, jaw, stalk, bulb, tail, table.unpack(eyes) } do
		table.insert(visual.parts, p)
	end
	for _, f in fins do
		table.insert(visual.parts, f)
	end
	for _, t in teeth do
		table.insert(visual.parts, t.part)
	end

	visual.update = function(now)
		local frame = uprightFrame(core) * CFrame.new(0, math.sin(now * 0.8) * 0.3 * k, 0)
		local glow = stateColor(visual, Color3.fromRGB(255, 60, 40))
		local chomp = 0.15 + 0.15 * math.sin(now * 3)
		body.CFrame = frame
		jaw.CFrame = frame * CFrame.new(0, -2.6 * k, -3.8 * k) * CFrame.Angles(chomp, math.pi, 0)
		for _, t in teeth do
			t.part.CFrame = frame * CFrame.new(t.x, -1.4 * k, -5.9 * k) * CFrame.Angles(math.pi, 0, 0)
		end
		for i, eye in eyes do
			eye.Color = glow
			eye.CFrame = frame * CFrame.new((i == 1 and -2.4 or 2.4) * k, 1.4 * k, -4.6 * k)
		end
		-- The lure arcs up and forward from the forehead and bobs.
		local bob = math.sin(now * 2.2) * 0.15
		stalk.CFrame = frame * CFrame.new(0, 4.6 * k, -4.8 * k) * CFrame.Angles(0, math.pi / 2, math.rad(35) + bob)
		bulb.Color = glow
		bulb.CFrame = stalk.CFrame * CFrame.new(2.4 * k, 0, 0)
		local swish = math.sin(now * 2.4) * 0.35
		tail.CFrame = frame * CFrame.new(0, 0, 7 * k) * CFrame.Angles(0, swish, 0)
		for i, fin in fins do
			local side = if i == 1 then -1 else 1
			local flap = math.sin(now * 3 + i) * 0.4
			fin.CFrame = frame * CFrame.new(side * 4.6 * k, -1 * k, 0) * CFrame.Angles(0, 0, side * (0.6 + flap))
		end
	end
end

-- Shared --------------------------------------------------------------------------------------

local BUILDERS: { [string]: (BasePart, Visual) -> () } = {
	Drifter = buildDrifter,
	Lurker = buildLurker,
	Warden = buildWarden,
}

local function remove(core: BasePart)
	local visual = visuals[core]
	if visual then
		visuals[core] = nil
		for _, part in visual.parts do
			part:Destroy()
		end
	end
end

local function watch(instance: Instance)
	if not instance:IsA("BasePart") or not BUILDERS[instance.Name] or visuals[instance] then
		return
	end
	local core = instance
	core.LocalTransparencyModifier = 1 -- the server's ball stays for logic and light only
	local visual: Visual = {
		core = core,
		light = core:FindFirstChildOfClass("PointLight"),
		update = function() end,
		parts = {},
	}
	BUILDERS[core.Name](core, visual)
	visuals[core] = visual
	core.AncestryChanged:Connect(function()
		if not core:IsDescendantOf(Workspace) then
			remove(core)
		end
	end)
end

function CreatureVisualsController.start()
	folder = Instance.new("Folder")
	folder.Name = "CreatureVisuals"
	folder.Parent = Workspace

	for _, child in Workspace:GetChildren() do
		watch(child)
	end
	Workspace.ChildAdded:Connect(watch)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for core, visual in visuals do
			core.LocalTransparencyModifier = 1
			visual.update(now, dt)
		end
	end)
end

return CreatureVisualsController
