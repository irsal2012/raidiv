--!strict
-- Look of the surface and the water (doc/07 §1): the surface warm and safe, the depths cold,
-- murky and quiet. AtmosphereController blends between the two when the camera crosses the
-- water line. Tune by eye in Studio; keep red and amber out of the water (doc/07 §2).

return table.freeze({
	-- Camera below this height counts as underwater. Matches GreyboxService.SurfaceY (0), with a
	-- small margin so the switch happens as the camera goes under, not as the diver's head does.
	WaterLineY = -0.5,
	BlendSeconds = 0.6,

	Surface = table.freeze({
		atmosphereDensity = 0.3,
		atmosphereColor = Color3.fromRGB(199, 214, 222),
		atmosphereDecay = Color3.fromRGB(106, 125, 140),
		atmosphereHaze = 1,
		tint = Color3.fromRGB(255, 250, 240), -- slightly warm afternoon
		saturation = 0.05,
		contrast = 0.05,
		brightness = 0,
		blur = 0,
	}),

	Underwater = table.freeze({
		-- Fog colour doubles as what you see in the murk: keep it a mid teal. Dark values here
		-- black out the rooms (first playtest, 2026-09-30).
		atmosphereDensity = 0.4,
		atmosphereColor = Color3.fromRGB(70, 140, 150),
		atmosphereDecay = Color3.fromRGB(45, 110, 125),
		atmosphereHaze = 1.5,
		tint = Color3.fromRGB(190, 230, 232), -- cold teal
		saturation = -0.15,
		contrast = 0.05,
		brightness = 0.06,
		blur = 1,
	}),

	-- Makes relic glows, neon mutations and creature lights bloom.
	Bloom = table.freeze({ intensity = 0.6, size = 24, threshold = 1.4 }),

	-- Specks drifting in the water around the camera ("marine snow"). Built-in texture for now.
	Snow = table.freeze({
		texture = "rbxasset://textures/particles/smoke_main.dds",
		rate = 40,
		boxSize = 50,
		lifetime = NumberRange.new(6, 10),
		size = NumberRange.new(0.08, 0.18),
		speed = NumberRange.new(0.2, 0.6),
		color = Color3.fromRGB(200, 225, 225),
		transparency = 0.55,
	}),

	-- Bubbles rising from every diver's head while underwater.
	Bubbles = table.freeze({
		texture = "rbxasset://textures/particles/smoke_main.dds",
		rate = 6,
		lifetime = NumberRange.new(1.5, 2.5),
		size = NumberRange.new(0.06, 0.16), -- the soft texture reads as smoke when bigger
		speed = NumberRange.new(2, 4),
		rise = 6, -- upward acceleration, studs/s²
		color = Color3.fromRGB(230, 250, 255),
		transparency = 0.2,
	}),
})
