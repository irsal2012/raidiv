--!strict
-- Underwater look: fog, colour grade and blur that blend in when the camera goes below the
-- water line, drifting specks around the camera, and bubbles rising from every diver's head.
-- All client-side; tuning is in Config/Atmosphere.luau.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Atmosphere"))

local AtmosphereController = {}

-- The place template may already have an Atmosphere or Bloom; two of either would fight.
local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className :: any)
	if existing then
		return existing
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function emitter(settings: any): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = settings.texture
	e.Rate = settings.rate
	e.Lifetime = settings.lifetime
	e.Size = NumberSequence.new(settings.size.Min, settings.size.Max)
	e.Speed = settings.speed
	e.Color = ColorSequence.new(settings.color)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, settings.transparency),
		NumberSequenceKeypoint.new(0.8, settings.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 0.3
	e.LightInfluence = 0.6
	e.Enabled = false
	return e
end

-- Bubbles on one character's head; enabled while that head is underwater.
local bubbleEmitters: { [Model]: ParticleEmitter } = {}

local function addBubbles(character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	local e = emitter(Config.Bubbles)
	e.Name = "DiverBubbles"
	e.Acceleration = Vector3.new(0, Config.Bubbles.rise, 0)
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = head
	bubbleEmitters[character] = e
	character.Destroying:Once(function()
		bubbleEmitters[character] = nil
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		task.spawn(addBubbles, player.Character)
	end
	player.CharacterAdded:Connect(addBubbles)
	player.CharacterRemoving:Connect(function(character)
		bubbleEmitters[character] = nil
	end)
end

function AtmosphereController.start()
	local atmosphere = ensure("Atmosphere", "DeepSalvageAtmosphere") :: Atmosphere
	local bloom = ensure("BloomEffect", "DeepSalvageBloom") :: BloomEffect
	bloom.Intensity = Config.Bloom.intensity
	bloom.Size = Config.Bloom.size
	bloom.Threshold = Config.Bloom.threshold

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DeepSalvageGrade"
	grade.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "DeepSalvageBlur"
	blur.Parent = Lighting

	local camera = Workspace.CurrentCamera :: Camera
	local snowAnchor = Instance.new("Part")
	snowAnchor.Name = "MarineSnow"
	snowAnchor.Anchored = true
	snowAnchor.CanCollide = false
	snowAnchor.CanQuery = false
	snowAnchor.CanTouch = false
	snowAnchor.Transparency = 1
	snowAnchor.Size = Vector3.one * Config.Snow.boxSize
	snowAnchor.Parent = camera
	local snow = emitter(Config.Snow)
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Parent = snowAnchor

	local function apply(look: any, seconds: number)
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)
		TweenService:Create(atmosphere, info, {
			Density = look.atmosphereDensity,
			Color = look.atmosphereColor,
			Decay = look.atmosphereDecay,
			Haze = look.atmosphereHaze,
		}):Play()
		TweenService:Create(grade, info, {
			TintColor = look.tint,
			Saturation = look.saturation,
			Contrast = look.contrast,
			Brightness = look.brightness,
		}):Play()
		TweenService:Create(blur, info, { Size = look.blur }):Play()
	end

	local underwater = false
	apply(Config.Surface, 0)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.RenderStepped:Connect(function()
		local cameraPosition = camera.CFrame.Position
		local below = cameraPosition.Y < Config.WaterLineY
		if below ~= underwater then
			underwater = below
			apply(if below then Config.Underwater else Config.Surface, Config.BlendSeconds)
			snow.Enabled = below
		end
		if below then
			snowAnchor.CFrame = CFrame.new(cameraPosition)
		end
		for _, bubbles in bubbleEmitters do
			local head = bubbles.Parent :: BasePart?
			bubbles.Enabled = head ~= nil and head.Position.Y < Config.WaterLineY
		end
	end)
end

return AtmosphereController
