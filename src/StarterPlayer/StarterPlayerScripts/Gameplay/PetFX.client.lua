-- PetFX: extra layered VFX for kaiju and eggs, client-only and cosmetic (built on the VFX reference playbook:
-- dark light-balancing base -> magic circle on the ground -> body layers -> sparkles / glitter -> lens-flare pops).
--   rarity   Rare and up get more than GameVFX's aura: Epic+ a dark base + spinning magic circle, Legendary+ lens flares
--            and rising glitter, Secret stacked halo rings + chromatic slivers (rainbow)
--   mutation every weather mutation (model attribute Mutation, Shared.Config.MutationConfig) gets its own themed set:
--            Golden glitter + light rays, Shocked crawling lightning, Frozen frost + ice + snow, Molten flipbook fire +
--            embers + smoke + lava cracks, Diamond chromatic slivers + octagon, Rainbow prism, Bloodmoon crimson smoke, Galaxy nebula + galaxy disc + stars
--   eggs     mutated eggs (nest / ground / pen) get a small circle, glitter and flare pops
-- Textures: VFX Studio library. Sleeps beyond RANGE studs; Reduced Effects cuts the rates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MutationConfig = require(Config:WaitForChild("MutationConfig"))
local EggConfig = require(Config:WaitForChild("EggConfig"))
local KaijuConfig = require(Config:WaitForChild("KaijuConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local RANGE = 140
local rng = Random.new()
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular
local STREAK = Enum.ParticleOrientation.VelocityParallel
local TOP = Enum.NormalId.Top

local function id(n)
	return "rbxassetid://" .. n
end
local T = {
	-- rings / circles
	ThinRing = id(12403112662), JaggedRing = id(12402854196), CleanRing = id(7136539160), FrostRing = id(7136551175),
	DoubleRing = id(14186586240), Octagon = id(3283071087), Corona = id(12386390257), MagicRing = id(91168521719532),
	GlowRing = id(82033827591449), RainbowSwirl = id(14242380855), Galaxy = id(15265627476), SpikyCrater = id(71146205854637),
	CrackBright = id(92861858089952), WebRing = id(90549255948014),
	-- smoke / dark bases
	SoftSmoke = id(2671910894), Wisp = id(12302665387), Cloud = id(291880914), StarSmoke = id(883906867),
	CrescentSmoke = id(140591030585994), Tendril = id(16034294138), Nebula = id(14242201435),
	-- flares / sparkles
	FourStar = id(14198353638), CrossGlint = id(14197583306), BlueGlint = id(14197626379), BigCross = id(14969367343),
	Anamorphic = id(114278596683627), Rays = id(12386392796), SoftGlow = id(15513493035), Glitter = id(106213021633252),
	Chroma = id(14221474657), PrismRays = id(76815628297122), PrismSparkles = id(73385444872956), PrismOrb = id(14199216697),
	ShardBurst = id(14241995242), Twinkle = id(5946093983), StarDust = id(134563328683175), ColorStars = id(78694460034696),
	Sparkle = id(97748444811872), Point = id(105068602933805), Streak = id(6820821916),
	-- themed
	Arc1 = id(12402856027), Arc2 = id(12402856928), ArcBlue = id(278520320), BoltBall = id(103597677385771),
	Diamond = id(7245988767), Snowflake = id(86390398432271), FlameFlip = id(126174900723501),
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
}

local function reduced()
	return Settings.Get("ReducedEffects") == true
end
local function NS(...)
	local p = { ... }
	if #p == 1 then
		return NumberSequence.new(p[1])
	end
	if #p == 2 then
		return NumberSequence.new(p[1], p[2])
	end
	local k = {}
	for i = 1, #p, 2 do
		table.insert(k, NumberSequenceKeypoint.new(p[i], p[i + 1]))
	end
	return NumberSequence.new(k)
end
local function CS(list)
	if typeof(list) == "Color3" then
		return ColorSequence.new(list)
	end
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local k = {}
	for i, c in list do
		table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#list - 1), typeof(c) == "Color3" and c or hex(c)))
	end
	return ColorSequence.new(k)
end
local function NR(a, b)
	b = b or a
	return NumberRange.new(math.min(a, b), math.max(a, b)) -- order-safe (negative spins)
end
local RAINBOW = CS({ "#FF4D4D", "#FFB84D", "#FFF04D", "#4DFF88", "#4DB8FF", "#C44DFF" })

---------------------------------------------------------------- per-model rig
local fxs = {} -- [model] = fx

local BRIGHT = 0.85 -- every PetFX layer's Brightness is multiplied by this
local MAX_SIZE = 18 -- studs; no single particle bigger than this

local function newFx(model, host, ext, groundY)
	-- radius is clamped so giant (VisualScale 6-8) kaiju don't get 60-stud discs; `dim` softens them further
	local raw = math.max(ext.X, ext.Z) * 0.55 + 0.5
	local fx = { model = model, host = host, ext = ext, groundY = groundY, radius = math.clamp(raw, 1.4, 7),
		dim = math.clamp((raw - 7) / 14, 0, 0.5),
		height = ext.Y, instances = {}, emitters = {}, pulses = {}, cycles = {}, enabled = true }
	function fx.att(name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos or Vector3.zero
		a.Parent = host
		table.insert(fx.instances, a)
		return a
	end
	-- props.Rate is the full rate; reduced effects scale it
	function fx.em(parent, props, role)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "PetFX"
		pe.LightEmission = 1
		pe.LightInfluence = 0
		local rate = props.Rate or 0
		props.Rate = nil
		for k, v in props do
			pe[k] = v
		end
		pe.Rate = rate * (reduced() and 0.35 or 1) * (1 - fx.dim * 0.5)
		-- global balance: additive layers stack, so keep every layer modest and cap particle size
		pe.Brightness = pe.Brightness * BRIGHT * (1 - fx.dim)
		local kps, peak = pe.Size.Keypoints, 0
		for _, k in kps do
			peak = math.max(peak, k.Value)
		end
		if peak > MAX_SIZE then
			local f, out = MAX_SIZE / peak, {}
			for _, k in kps do
				table.insert(out, NumberSequenceKeypoint.new(k.Time, k.Value * f, k.Envelope * f))
			end
			pe.Size = NumberSequence.new(out)
		end
		pe.Parent = parent
		table.insert(fx.instances, pe)
		table.insert(fx.emitters, pe)
		if role == "cycle" then
			table.insert(fx.cycles, pe)
		end
		return pe
	end
	-- every `every` seconds: emit `count` from emitters at a random point on the body (lens-flare pops etc.)
	function fx.pulse(every, emitters, count, onBody)
		local a = fx.att("PetFXPop")
		local pes = {}
		for _, props in emitters do
			props.Rate = 0
			props.LockedToPart = props.LockedToPart or false
			table.insert(pes, fx.em(a, props))
		end
		table.insert(fx.pulses, { att = a, every = every, next = os.clock() + rng:NextNumber(0, every), count = count or 1, onBody = onBody ~= false, pes = pes })
		return a
	end
	fx.ground = fx.att("PetFXGround", Vector3.new(0, groundY + 0.15, 0))
	fx.mid = fx.att("PetFXMid", Vector3.new(0, groundY + ext.Y * 0.5, 0))
	fx.top = fx.att("PetFXTop", Vector3.new(0, groundY + ext.Y + 0.3, 0))
	return fx
end

-- common building blocks ----------------------------------------------------------------
local function darkBase(fx, color, size)
	if fx.noGround then
		return
	end
	-- light-balancing: a dark, non-glowing smoke disc under the bright layers so they read on bright grass
	fx.em(fx.ground, {
		Texture = T.SoftSmoke, Color = CS(color), LightEmission = 0, LightInfluence = 0.6,
		Orientation = FLAT, EmissionDirection = TOP, Speed = NR(0.01), LockedToPart = true,
		Size = NS(0, size * 0.7, 1, size), Transparency = NS(0, 1, 0.3, 0.55, 1, 1),
		Rotation = NR(0, 360), RotSpeed = NR(-15, 15), Lifetime = NR(1.6, 2.4), Rate = 2.2, ZOffset = -0.3,
	})
end

local function circle(fx, texture, color, size, spin, alpha, rate, brightness)
	if fx.noGround then
		return
	end
	fx.em(fx.ground, {
		Texture = texture, Color = typeof(color) == "ColorSequence" and color or CS(color), Brightness = brightness or 3,
		Orientation = FLAT, EmissionDirection = TOP, Speed = NR(0.01), LockedToPart = true,
		Size = NS(size), Transparency = NS(0, 1, 0.25, math.min(0.9, (alpha or 0.55) + 0.12), 0.75, math.min(0.9, (alpha or 0.55) + 0.12), 1, 1),
		Rotation = NR(0, 360), RotSpeed = NR(spin * 0.8, spin), Lifetime = NR(2.2, 2.8), Rate = rate or 0.8,
	}, typeof(color) == "ColorSequence" and "cycle" or nil)
end

local function ringPulse(fx, texture, color, from, to, every)
	if fx.noGround then
		return
	end
	fx.pulse(every, { {
		Texture = texture, Color = CS(color), Orientation = FLAT, EmissionDirection = TOP, Speed = NR(0.01),
		LockedToPart = true, Size = NS(0, from, 1, to), Transparency = NS(0, 0.1, 1, 1), Lifetime = NR(0.9),
		Rotation = NR(0, 360), Brightness = 2,
	} }, 1, false).Position = fx.ground.Position
end

local function glitter(fx, texture, color, rate, size)
	-- rising glitter from the body volume (box emission from the host part)
	fx.em(fx.host, {
		Texture = texture, Color = typeof(color) == "ColorSequence" and color or CS(color), Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		EmissionDirection = TOP, Speed = NR(0.5, 2), Acceleration = Vector3.new(0, 2.5, 0), Drag = 1.5,
		Size = NS(0, 0, 0.25, size, 1, 0), Transparency = NS(0, 0.1, 1, 0.6), Rotation = NR(0, 45),
		Lifetime = NR(0.8, 1.5), Rate = rate, Brightness = 2,
	}, typeof(color) == "ColorSequence" and "cycle" or nil)
end

local function flares(fx, color, every, size)
	-- a 4-point star with a horizontal anamorphic streak through it, popping somewhere on the body
	local c = typeof(color) == "ColorSequence" and color or CS(color)
	fx.pulse(every, {
		{ Texture = T.FourStar, Color = c, Speed = NR(0), Size = NS(0, 0, 0.3, size, 1, 0), Lifetime = NR(0.35, 0.5), Rotation = NR(0, 15), Brightness = 4 },
		{ Texture = T.Anamorphic, Color = c, Speed = NR(0), Size = NS(0, 0, 0.3, size * 2.2, 1, 0), Lifetime = NR(0.3, 0.4), Transparency = NS(0.15), Brightness = 3 },
	}, 1)
end

---------------------------------------------------------------- rarity extras
local RARITY = {
	Rare = function(fx, c)
		circle(fx, T.ThinRing, c, fx.radius * 2.2, 10, 0.75, 0.5)
		fx.pulse(2.2, { { Texture = T.CrossGlint, Color = CS(c), Speed = NR(0), Size = NS(0, 0, 0.3, 1.1, 1, 0), Lifetime = NR(0.4) } }, 1)
	end,
	Epic = function(fx, c)
		darkBase(fx, c:Lerp(Color3.new(), 0.82), fx.radius * 2.6)
		circle(fx, T.MagicRing, c, fx.radius * 2.6, 14, 0.5, 0.7)
		glitter(fx, T.Sparkle, { WHITE, c }, 5, 0.6)
		flares(fx, { WHITE, c }, 3, 1.6)
	end,
	Legendary = function(fx, c)
		darkBase(fx, c:Lerp(Color3.new(), 0.82), fx.radius * 2.8)
		circle(fx, T.Corona, c, fx.radius * 3, -18, 0.45, 0.8)
		circle(fx, T.CleanRing, c, fx.radius * 1.9, 30, 0.6, 0.6)
		glitter(fx, T.Glitter, { WHITE, c }, 9, 0.8)
		flares(fx, { WHITE, c }, 1.8, 2)
	end,
	Mythic = function(fx, c)
		darkBase(fx, c:Lerp(Color3.new(), 0.8), fx.radius * 3)
		circle(fx, T.WebRing, c, fx.radius * 3.2, 16, 0.45, 0.8)
		circle(fx, T.DoubleRing, c, fx.radius * 2, -36, 0.55, 0.6)
		glitter(fx, T.Glitter, { WHITE, c }, 10, 0.9)
		flares(fx, { WHITE, c }, 1.4, 2.2)
	end,
	Secret = function(fx, c)
		darkBase(fx, Color3.fromHex("1A0A33"), fx.radius * 3.2)
		circle(fx, T.RainbowSwirl, WHITE, fx.radius * 3.2, 20, 0.35, 0.8, 1.5)
		-- stacked halo rings climbing the body
		for i, h in { 0.25, 0.6, 0.95 } do
			local a = fx.att("PetFXHalo" .. i, Vector3.new(0, fx.groundY + fx.height * h, 0))
			fx.em(a, {
				Texture = T.CleanRing, Color = RAINBOW, Orientation = FLAT, EmissionDirection = TOP, Speed = NR(0.01),
				LockedToPart = true, Size = NS(0, fx.radius * (2.4 - h), 1, fx.radius * (2.8 - h)),
				Transparency = NS(0, 1, 0.3, 0.35, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(40 * (i % 2 == 0 and -1 or 1)),
				Lifetime = NR(1.2), Rate = 1.2, Brightness = 2,
			}, "cycle")
		end
		glitter(fx, T.PrismSparkles, WHITE, 12, 1)
		fx.pulse(0.7, { { Texture = T.Chroma, Color = CS(WHITE), Speed = NR(2, 5), SpreadAngle = Vector2.new(180, 180),
			Size = NS(0, 0, 0.3, 1.2, 1, 0), Rotation = NR(0, 360), Lifetime = NR(0.4, 0.6), Drag = 3 } }, 3)
		flares(fx, RAINBOW, 1, 2.6)
	end,
}

---------------------------------------------------------------- mutation sets
local MUTATION = {
	Golden = function(fx, m)
		local gold = { "#FFF6B0", "#FFD23F", "#FF9E1F" }
		darkBase(fx, hex("3A2400"), fx.radius * 2.6)
		circle(fx, T.GlowRing, gold, fx.radius * 2.6, 20, 0.45, 0.8)
		glitter(fx, T.Glitter, gold, 14, 0.9)
		fx.em(fx.mid, { Texture = T.Rays, Color = CS(gold), Speed = NR(0), LockedToPart = true, Size = NS(fx.radius * 2.6),
			Transparency = NS(0, 1, 0.4, 0.7, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(10, 20), Lifetime = NR(2.5), Rate = 0.8, ZOffset = -2 })
		flares(fx, gold, 1.2, 2)
	end,
	Shocked = function(fx, m)
		local blue = { "#FFFFFF", "#7FE8FF", "#2E7BFF" }
		darkBase(fx, hex("06142E"), fx.radius * 2.6)
		ringPulse(fx, T.JaggedRing, blue, fx.radius * 1.2, fx.radius * 3.4, 1.6)
		for _, tex in { T.Arc1, T.Arc2, T.ArcBlue } do -- lightning crawling over the body
			fx.em(fx.host, { Texture = tex, Color = CS(blue), Shape = Enum.ParticleEmitterShape.Box, Speed = NR(0),
				Size = NS(fx.radius * rng:NextNumber(0.9, 1.4)), Transparency = NS(0, 0, 0.7, 0.2, 1, 1), Rotation = NR(0, 360),
				Lifetime = NR(0.1, 0.18), Rate = 5, Brightness = 4 })
		end
		fx.pulse(0.9, { { Texture = T.BoltBall, Color = CS(blue), Speed = NR(0), Size = NS(0, 0.6, 1, 2.2), Transparency = NS(0, 0.2, 1, 1),
			Rotation = NR(0, 360), Lifetime = NR(0.25), Brightness = 4 } }, 1)
		flares(fx, blue, 1.1, 2)
	end,
	Frozen = function(fx, m)
		local ice = { "#FFFFFF", "#BFEFFF", "#6FC8FF" }
		darkBase(fx, hex("0E2A44"), fx.radius * 2.6)
		circle(fx, T.FrostRing, ice, fx.radius * 2.8, -8, 0.4, 0.8)
		fx.em(fx.ground, { Texture = T.SoftSmoke, Color = CS({ "#F4FAFF", "#BFE6FF" }), LightEmission = 0.3, Speed = NR(0.5, 1.2),
			SpreadAngle = Vector2.new(180, 10), Size = NS(0, fx.radius * 0.8, 1, fx.radius * 1.6), Transparency = NS(0, 1, 0.3, 0.65, 1, 1),
			Rotation = NR(0, 360), RotSpeed = NR(-10, 10), Lifetime = NR(2, 3), Rate = 3 })
		glitter(fx, T.Diamond, ice, 6, 0.7)
		fx.em(fx.top, { Texture = T.Snowflake, Color = CS(ice), Speed = NR(0.5, 1), SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -1.5, 0), Size = NS(0, 0.35, 1, 0.2), Transparency = NS(0, 0.1, 1, 0.7),
			Rotation = NR(0, 360), RotSpeed = NR(-90, 90), Lifetime = NR(2, 3), Rate = 5 })
		flares(fx, ice, 1.5, 1.8)
	end,
	Molten = function(fx, m)
		local fire = { "#FFE08A", "#FF7A1F", "#B81E00" }
		fx.em(fx.ground, { Texture = T.Cloud, Color = CS({ "#3A1208", "#120604" }), LightEmission = 0, LightInfluence = 0.5,
			Speed = NR(1.5, 3), SpreadAngle = Vector2.new(25, 25), EmissionDirection = TOP, Size = NS(0, fx.radius * 0.8, 1, fx.radius * 2),
			Transparency = NS(0, 1, 0.25, 0.45, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(-20, 20), Lifetime = NR(1.5, 2.2), Rate = 4, ZOffset = -1 })
		circle(fx, T.CrackBright, fire, fx.radius * 2.6, 0, 0.35, 0.6, 4)
		local flames = fx.em(fx.host, { Texture = T.FlameFlip, Color = CS(fire), Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = TOP, Speed = NR(1.5, 3), Size = NS(0, fx.radius * 0.5, 0.4, fx.radius * 0.8, 1, 0.2),
			Transparency = NS(0, 0.2, 1, 1), Lifetime = NR(0.6, 0.9), Rate = 10, Brightness = 2,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot })
		fx.em(fx.host, { Texture = T.Embers, Color = CS(fire), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = TOP,
			Speed = NR(2, 5), Acceleration = Vector3.new(0, 3, 0), Size = NS(0, 0.25, 1, 0), Lifetime = NR(1, 1.8), Rate = 18 })
		flares(fx, fire, 1.6, 1.8)
	end,
	Diamond = function(fx, m)
		local gem = { "#FFFFFF", "#CFF8FF", "#7FDFFF" }
		darkBase(fx, hex("0A1E2A"), fx.radius * 2.6)
		circle(fx, T.Octagon, gem, fx.radius * 2.4, 24, 0.4, 0.8)
		fx.em(fx.mid, { Texture = T.PrismRays, Color = CS(WHITE), Speed = NR(0), LockedToPart = true, Size = NS(fx.radius * 2.4),
			Transparency = NS(0, 1, 0.4, 0.75, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(-15, 15), Lifetime = NR(2), Rate = 0.8, ZOffset = -2 })
		fx.pulse(0.5, { { Texture = T.Chroma, Color = CS(WHITE), Speed = NR(1, 3), SpreadAngle = Vector2.new(180, 180),
			Size = NS(0, 0, 0.3, 1, 1, 0), Rotation = NR(0, 360), Lifetime = NR(0.4, 0.6), Drag = 3 } }, 2)
		fx.pulse(0.8, { { Texture = T.BigCross, Color = CS(gem), Speed = NR(0), Size = NS(0, 0, 0.3, 1.6, 1, 0), Lifetime = NR(0.35), Brightness = 4 } }, 1)
		flares(fx, gem, 1.1, 2.2)
	end,
	Rainbow = function(fx, m)
		darkBase(fx, hex("1A0A2A"), fx.radius * 2.8)
		circle(fx, T.RainbowSwirl, WHITE, fx.radius * 3, 24, 0.3, 0.9, 1.5)
		glitter(fx, T.PrismSparkles, WHITE, 12, 1)
		fx.pulse(0.6, { { Texture = T.ColorStars, Color = CS(WHITE), Speed = NR(0), Size = NS(0, 0, 0.4, 1.4, 1, 0), Lifetime = NR(0.5), Brightness = 2 } }, 1)
		fx.em(fx.mid, { Texture = T.PrismOrb, Color = CS(WHITE), Speed = NR(0.3, 0.8), SpreadAngle = Vector2.new(180, 180),
			Size = NS(0, 0, 0.3, 0.8, 1, 0), Transparency = NS(0.2, 1), Lifetime = NR(1.2, 2), Rate = 3 })
		flares(fx, RAINBOW, 1, 2.4)
	end,
	Bloodmoon = function(fx, m)
		local blood = { "#FF8A8A", "#FF1F3D", "#5A0010" }
		fx.em(fx.ground, { Texture = T.Wisp, Color = CS({ "#3A0008", "#0A0002" }), LightEmission = 0, LightInfluence = 0.5,
			Speed = NR(1, 2), SpreadAngle = Vector2.new(30, 30), EmissionDirection = TOP, Size = NS(0, fx.radius, 1, fx.radius * 2.2),
			Transparency = NS(0, 1, 0.3, 0.4, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(-30, 30), Lifetime = NR(1.6, 2.4), Rate = 4, ZOffset = -1 })
		circle(fx, T.SpikyCrater, blood, fx.radius * 2.8, -12, 0.4, 0.7, 3)
		fx.em(fx.host, { Texture = T.Embers, Color = CS(blood), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = TOP,
			Speed = NR(1, 3), Acceleration = Vector3.new(0, 2, 0), Size = NS(0, 0.25, 1, 0), Lifetime = NR(1.2, 2), Rate = 12 })
		fx.em(fx.mid, { Texture = T.SoftGlow, Color = CS(blood), Speed = NR(0), LockedToPart = true, Size = NS(fx.radius * 3),
			Transparency = NS(0, 1, 0.5, 0.82, 1, 1), Lifetime = NR(2.4), Rate = 0.6, ZOffset = -2.5 })
		flares(fx, blood, 1.4, 1.8)
	end,
	Galaxy = function(fx, m)
		local cosmos = { "#FFFFFF", "#C9A6FF", "#6A2CFF" }
		fx.em(fx.ground, { Texture = T.StarSmoke, Color = CS({ "#1B0B4D", "#05021A" }), LightEmission = 0, LightInfluence = 0.4,
			Speed = NR(0.5, 1.2), SpreadAngle = Vector2.new(40, 40), EmissionDirection = TOP, Size = NS(0, fx.radius, 1, fx.radius * 2.4),
			Transparency = NS(0, 1, 0.3, 0.35, 1, 1), Rotation = NR(0, 360), RotSpeed = NR(-15, 15), Lifetime = NR(2, 3), Rate = 3, ZOffset = -1 })
		circle(fx, T.Galaxy, cosmos, fx.radius * 3.2, 18, 0.25, 0.8, 2)
		fx.em(fx.host, { Texture = T.StarDust, Color = CS(cosmos), Shape = Enum.ParticleEmitterShape.Box, Speed = NR(0),
			Size = NS(0, 0, 0.5, 2.5, 1, 0), Rotation = NR(0, 360), Lifetime = NR(1.5, 2.5), Rate = 4 })
		fx.pulse(0.35, { { Texture = T.Twinkle, Color = CS(cosmos), Speed = NR(0), Size = NS(0, 0, 0.4, 1.1, 1, 0), Lifetime = NR(0.4, 0.7), Brightness = 3 } }, 1)
		fx.em(fx.host, { Texture = T.Streak, Color = CS(cosmos), Shape = Enum.ParticleEmitterShape.Box, Orientation = STREAK,
			EmissionDirection = TOP, Speed = NR(4, 7), Squash = NS(2), Size = NS(0, 0.4, 1, 0.1), Lifetime = NR(0.6, 1), Rate = 6 })
		flares(fx, cosmos, 1, 2.4)
	end,
}

---------------------------------------------------------------- attach / detach
local function partCountReady(model)
	local want = model:GetAttribute("PartCount")
	if not want then
		return true
	end
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n >= want
end

local function remove(model)
	local fx = fxs[model]
	fxs[model] = nil
	if fx then
		for _, inst in fx.instances do
			inst:Destroy()
		end
	end
end

local function rarityOf(model)
	local r = model:GetAttribute("Rarity")
	if r then
		return r
	end
	local cfg = KaijuConfig[model:GetAttribute("Species") or ""]
	return cfg and cfg.Rarity
end

local function build(model, isEgg)
	remove(model)
	local mutation = model:GetAttribute("Mutation")
	local rarity = rarityOf(model)
	local rInfo = EggConfig.RarityById[rarity or ""]
	local wantRarity = not isEgg and rInfo and RARITY[rarity]
	local wantMutation = mutation and MutationConfig.ById[mutation] and MUTATION[mutation]
	if not (wantRarity or wantMutation) then
		return
	end
	local host = model:FindFirstChild("MutationAura") or model:FindFirstChild("Aura") or model.PrimaryPart
	if not (host and host:IsA("BasePart")) then
		return
	end
	local cf, ext = model:GetBoundingBox()
	local groundY = (cf.Position.Y - ext.Y / 2) - host.Position.Y
	local fx = newFx(model, host, ext, groundY)
	fx.noGround = not isEgg -- nothing flat on the ground under kaiju (no circles / discs / ring pulses)
	if isEgg then
		local m = MutationConfig.ById[mutation]
		local list = {}
		for _, h in m.Colors do
			table.insert(list, hex(h))
		end
		if model:GetAttribute("State") == "Pen" or model:GetAttribute("State") == "Nest" or model:GetAttribute("State") == "Ground" then
			circle(fx, T.MagicRing, list, fx.radius * 2.6, 20, 0.45, 0.7)
		end
		glitter(fx, T.Sparkle, list, 6, 0.6)
		flares(fx, m.Rainbow and RAINBOW or list, 1.6, 1.6)
	else
		if wantRarity and not wantMutation then
			wantRarity(fx, rInfo.Color)
		elseif wantRarity and rInfo.Order >= 6 then
			-- mutated Mythic / Secret: keep the rarity's halo / crescents too, under the mutation set
			wantRarity(fx, rInfo.Color)
		end
		if wantMutation then
			wantMutation(fx, MutationConfig.ById[mutation])
		end
	end
	fxs[model] = fx
end

local function watch(model, isEgg)
	if not model:IsA("Model") or model:GetAttribute("NoAura") then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and not partCountReady(model) and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		task.wait(0.35) -- after KaijuFX / GameVFX rig the model
		if not model.Parent then
			return
		end
		build(model, isEgg)
		model:GetAttributeChangedSignal("Mutation"):Connect(function()
			build(model, isEgg)
		end)
		if isEgg then
			model:GetAttributeChangedSignal("State"):Connect(function()
				if model:GetAttribute("Mutation") then
					build(model, isEgg)
				end
			end)
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			remove(model)
		end
	end)
end

task.spawn(function()
	local runtime = workspace:WaitForChild("Runtime")
	local kaiju = runtime:WaitForChild("Kaiju")
	kaiju.ChildAdded:Connect(function(m)
		watch(m, false)
	end)
	for _, m in kaiju:GetChildren() do
		watch(m, false)
	end
	local eggs = runtime:WaitForChild("Eggs")
	local function egg(m)
		if m:GetAttribute("Mutation") then
			watch(m, true)
		else
			local conn
			conn = m:GetAttributeChangedSignal("Mutation"):Connect(function()
				conn:Disconnect()
				watch(m, true)
			end)
		end
	end
	eggs.ChildAdded:Connect(egg)
	for _, m in eggs:GetChildren() do
		egg(m)
	end
end)

---------------------------------------------------------------- light budget
-- Every rarity / mutation rig adds PointLights scaled to the model. A pen full of giant kaiju stacks 20-30
-- overlapping lights on pale surfaces and the whole pen washes out white, so: only the nearest few kaiju
-- keep their lights, and every kaiju light is capped in range and brightness.
local LIGHT_KAIJU = 4
local LIGHT_RANGE = 16
local LIGHT_BRIGHT = 1
task.spawn(function()
	local runtime = workspace:WaitForChild("Runtime")
	local folders = { runtime:WaitForChild("Kaiju"), runtime:WaitForChild("Eggs") }
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		if not cam then
			continue
		end
		local camPos = cam.CFrame.Position
		local list = {}
		for _, folder in folders do
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					local ok, pivot = pcall(model.GetPivot, model)
					if ok then
						table.insert(list, { model = model, d = (pivot.Position - camPos).Magnitude })
					end
				end
			end
		end
		table.sort(list, function(a, b)
			return a.d < b.d
		end)
		for rank, e in list do
			local allow = rank <= LIGHT_KAIJU
			for _, l in e.model:GetDescendants() do
				if l:IsA("Light") then
					if l:GetAttribute("PetFXRange") == nil then
						l:SetAttribute("PetFXRange", l.Range)
						l:SetAttribute("PetFXOn", l.Enabled)
					end
					if l.Range > LIGHT_RANGE then
						l.Range = LIGHT_RANGE
					end
					if l.Brightness > LIGHT_BRIGHT then
						l.Brightness = LIGHT_BRIGHT
					end
					local want = allow and l:GetAttribute("PetFXOn") ~= false
					if l.Enabled ~= want then
						l.Enabled = want
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------- per frame: culling, pops, rainbow
RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	local hue = (now * 0.25) % 1
	for model, fx in fxs do
		if not fx.host.Parent then
			continue
		end
		local near = (fx.host.Position - camPos).Magnitude < RANGE
		if near ~= fx.enabled then
			fx.enabled = near
			for _, pe in fx.emitters do
				pe.Enabled = near
			end
		end
		if not near then
			continue
		end
		for _, p in fx.pulses do
			if now >= p.next then
				p.next = now + p.every * rng:NextNumber(0.7, 1.3)
				if p.onBody then
					p.att.Position = Vector3.new(rng:NextNumber(-0.5, 0.5) * fx.ext.X, fx.groundY + rng:NextNumber(0.2, 0.95) * fx.ext.Y, rng:NextNumber(-0.5, 0.5) * fx.ext.Z)
				end
				for _, pe in p.pes do
					pe:Emit(p.count)
				end
			end
		end
		if #fx.cycles > 0 then
			local c = ColorSequence.new(Color3.fromHSV(hue, 0.7, 1), Color3.fromHSV((hue + 0.2) % 1, 0.7, 1))
			for _, pe in fx.cycles do
				pe.Color = c
			end
		end
	end
end)
