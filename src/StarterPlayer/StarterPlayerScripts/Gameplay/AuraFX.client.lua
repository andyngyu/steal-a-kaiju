-- Player auras, client-only and cosmetic. Every player wearing a trail (attribute EquippedTrail, set by TrailService)
-- gets that trail's aura from Shared.Config.AuraConfig: a list of layer recipes (RECIPES below) in the trail's theme -
-- levitating rocks, a leaf whirlwind, frost and snowflakes, a void portal, a storm cloud, real fire, rainbow light, or
-- the Shadow Monarch's spiky black aura and glowing eyes. Every aura has its own textures. Auras idle quietly while the player moves and power up when they stand still ("aura
-- farming"), with a burst when they reach full power. On top of the layers: a glowing outline (Highlight, on you and the
-- nearest few players) that can also tint the body, energy ribbons spiralling round the body, a glowing sigil on the
-- ground while farming, a coloured light and, for the Monarch, glowing eye slits.
-- Rainbow styles cycle every colour, and the wearer's trail itself scrolls through the rainbow on every screen (even
-- with auras turned off). Respects the Player Auras and Reduced Effects settings; auras fade with distance and sleep
-- beyond AuraConfig.Range.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AuraConfig = require(Config:WaitForChild("AuraConfig"))
local TrailConfig = require(Config:WaitForChild("TrailConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer
local F = AuraConfig.Farm
local TEX = AuraConfig.Textures
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local TOP = Enum.NormalId.Top
local SPHERE = Enum.ParticleEmitterShape.Sphere
local SURFACE = Enum.ParticleEmitterShapeStyle.Surface
local VOLUME = Enum.ParticleEmitterShapeStyle.Volume
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular
local STREAK = Enum.ParticleOrientation.VelocityParallel

-- Body parts that give off body layers (R15 names, then R6); "Big" layers only use the bigger ones.
local BODY_PARTS = {
	"UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local BIG_PARTS = {
	UpperTorso = true, LowerTorso = true, Head = true, LeftUpperArm = true, RightUpperArm = true,
	LeftUpperLeg = true, RightUpperLeg = true,
	Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "PlayerAuras"
fxFolder.Parent = workspace

local auras = {} -- [player] = aura
local tokens = {} -- [player] = rebuild counter, drops stale rebuilds

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function range(a, b)
	b = b or a
	return NumberRange.new(math.min(a, b), math.max(a, b)) -- order-safe (negative spins)
end

local function colorSeq(colors)
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

local function numSeq(points)
	local keypoints = {}
	for _, p in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keypoints)
end

-- n colours round the colour wheel, turning over time
local function rainbow(t, n, sat)
	local out = {}
	for i = 1, n do
		out[i] = Color3.fromHSV((t * 0.22 + (i - 1) / n) % 1, sat or 0.8, 1)
	end
	return out
end

-- back = backdrop flame colours (default: a near-black shade of the glow), tongue = bright flame-tongue colours
local function palette(glow, colors, back, tongue)
	local light = glow:Lerp(WHITE, 0.55)
	local deep = glow:Lerp(BLACK, 0.35)
	local dark = glow:Lerp(BLACK, 0.86)
	return {
		glow = glow,
		light = light,
		deep = deep,
		dark = dark,
		colors = colors,
		back = back or { dark, BLACK },
		tongue = tongue or { light, glow, deep },
	}
end

-- Colour roles a layer can take from its aura's palette (re-applied as a rainbow aura turns); "Fixed" keeps its own.
local function roleColor(role, pal)
	if role == "Glow" then
		return ColorSequence.new(pal.light, pal.glow)
	elseif role == "Flame" then
		return colorSeq(pal.tongue)
	elseif role == "Dark" then
		return colorSeq(pal.back)
	elseif role == "Trail" then
		return colorSeq(pal.colors)
	end
	return nil
end

local function newEmitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightInfluence = 0
	for k, v in props do
		pe[k] = v
	end
	pe.Rate = 0
	pe.Parent = parent
	return pe
end

local function anchoredPart(name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	return p
end

-- A layer: emitters sharing a rate { moving, farming } (per emitter), a colour role, a power-up burst and an optional
-- pulse (one particle every `pulse` seconds while farming). Style.Rates can override a recipe's rates.
local function layer(a, pes, role, moving, farming, opts)
	local override = a.style.Rates[a.recipe]
	local L = {
		pes = pes,
		role = role,
		moving = override and override[1] or moving,
		farming = override and override[2] or farming,
		burst = opts and opts.burst,
		pulse = opts and opts.pulse,
		pulseCount = opts and opts.pulseCount,
		nextPulse = 0,
	}
	local c = roleColor(role, a.pal)
	for _, pe in pes do
		table.insert(a.instances, pe)
		if c then
			pe.Color = c
		end
	end
	table.insert(a.layers, L)
	return L
end

-- One emitter per body part ("All" or only the "Big" ones)
local function onBody(a, which, props)
	local pes = {}
	for _, name in BODY_PARTS do
		local part = a.char:FindFirstChild(name)
		if part and part:IsA("BasePart") and (which == "All" or BIG_PARTS[name]) then
			table.insert(pes, newEmitter(part, props))
		end
	end
	return pes
end

local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local LOOP = Enum.ParticleFlipbookMode.Loop
local ONESHOT = Enum.ParticleFlipbookMode.OneShot
local UPRIGHT = Enum.ParticleOrientation.FacingCameraWorldUp
local FRONT = Enum.NormalId.Front
local NO_SPREAD = Vector2.new(0, 0)

local function cs(c0, c1)
	return ColorSequence.new(Color3.fromHex(c0), Color3.fromHex(c1 or c0))
end

-- Sprite sheets: fps 0 = every particle shows one random frame of the sheet (variety); OneShot plays the sheet once
-- over the particle's life.
local function flipbook(props, layout, mode, fps, startRandom)
	props.FlipbookLayout = layout
	props.FlipbookMode = mode or LOOP
	props.FlipbookFramerate = range(fps or 0, fps or 0)
	props.FlipbookStartRandom = startRandom or (fps or 0) == 0
	return props
end

-- A layer with one emitter
local function one(a, parent, props, role, moving, farming, opts)
	return layer(a, { newEmitter(parent, props) }, role, moving, farming, opts)
end

-- An attachment circling the body (update moves it); emitters on it draw a trail as it goes round
local function orbiter(a, radius, speed, phase, height, bob)
	local att = a.attach(a.shell, "AuraOrbit")
	table.insert(a.orbits, { att = att, r = radius, speed = speed, phase = phase, y = height or 0, bob = bob or 0 })
	return att
end

-- An attachment at a fixed spot relative to the body's centre (storm cloud, halo, bolt sources)
local function point(a, name, pos)
	local att = a.attach(a.shell, name)
	att.Position = pos
	return att
end

-- One big image on the body's centre, facing the camera and drawn behind it (silhouettes, portals, bursts)
local function behind(a, props, role, moving, farming, opts)
	props.Speed = props.Speed or range(0, 0)
	props.LockedToPart = true
	props.ZOffset = props.ZOffset or -2.5
	return one(a, a.centre, props, role, moving, farming, opts)
end

-- An expanding ring on the ground, pulsing while farming
local function groundRing(a, s, texture, role, color, light, every, size)
	return one(a, a.ground, {
		Texture = texture,
		Color = color,
		LightEmission = light,
		Orientation = FLAT,
		Size = numSeq({ { 0, 1 * s }, { 1, size * s } }),
		Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = range(0.75, 0.75),
		Speed = range(0.01, 0.01),
		SpreadAngle = NO_SPREAD,
		Rotation = range(0, 360),
		EmissionDirection = TOP,
	}, role, 0, 0, { burst = 2, pulse = every })
end

-- A spinning disc flat on the ground (vortexes, wind)
local function groundSpin(a, s, texture, role, color, light, size, spin, alpha)
	return one(a, a.ground, {
		Texture = texture,
		Color = color,
		LightEmission = light,
		Orientation = FLAT,
		Size = numSeq({ { 0, size * 0.8 * s }, { 1, size * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.25, alpha or 0.35 }, { 1, 1 } }),
		Lifetime = range(1, 1.4),
		Speed = range(0.01, 0.01),
		SpreadAngle = NO_SPREAD,
		Rotation = range(0, 360),
		RotSpeed = spin > 0 and range(spin * 0.7, spin) or range(spin, spin * 0.7),
		EmissionDirection = TOP,
		LockedToPart = true,
	}, role, 0, 1.6)
end

-- Layer recipes, named in AuraConfig.Styles[...].Layers. s = character scale (1 for a normal character).
local RECIPES = {}

-- Fallback aura (a trail with no style): glowing tongues + energy lines in the trail's colour
function RECIPES.Tongues(a, s)
	layer(a, onBody(a, "All", {
		Name = "AuraTongue",
		Texture = TEX.Blob,
		LightEmission = 1,
		Size = numSeq({ { 0, 0.15 * s }, { 0.2, 0.85 * s }, { 1, 0 } }),
		Squash = numSeq({ { 0, 0.6 }, { 1, 1.6 } }),
		Transparency = numSeq({ { 0, 0.2 }, { 0.2, 0 }, { 1, 0.7 } }),
		Lifetime = range(0.3, 0.5),
		Speed = range(1.5, 3),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 6 * s, 0),
		Drag = 1.2,
		Rotation = range(-15, 15),
		ZOffset = -0.8,
		EmissionDirection = TOP,
	}), "Flame", 8, 45, { burst = 4 })
end

function RECIPES.EnergyLines(a, s)
	one(a, a.base, {
		Texture = TEX.Streak,
		LightEmission = 1,
		Orientation = STREAK,
		Size = numSeq({ { 0, 0.6 * s }, { 0.5, 1.6 * s }, { 1, 0.4 * s } }),
		Transparency = numSeq({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = range(0.4, 0.65),
		Speed = range(8, 14),
		SpreadAngle = Vector2.new(3, 3),
		EmissionDirection = TOP,
	}, "Glow", 0, 28, { burst = 30 })
end

-- Pebble Dust ---------------------------------------------------------------------------------------------------------
function RECIPES.DustCloud(a, s)
	one(a, a.base, {
		Texture = TEX.DustCloud,
		Color = cs("E6DAC0", "A89A7C"),
		LightEmission = 0,
		Size = numSeq({ { 0, 1 * s }, { 1, 3 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.35 }, { 1, 1 } }),
		Lifetime = range(1.2, 1.8),
		Speed = range(0.4, 1.2),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, 0.8, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-25, 25),
		EmissionDirection = TOP,
	}, "Fixed", 2, 10, { burst = 8 })
end

-- rocks lifting off the ground and hovering round you
function RECIPES.Boulders(a, s)
	one(a, a.base, flipbook({
		Texture = TEX.Boulders,
		Color = cs("C9C2B2", "8E8676"),
		LightEmission = 0,
		Size = numSeq({ { 0, 0 }, { 0.12, 0.8 * s }, { 0.85, 0.7 * s }, { 1, 0 } }),
		Lifetime = range(2, 2.8),
		Speed = range(1, 1.8),
		SpreadAngle = Vector2.new(10, 10),
		Drag = 0.9,
		Rotation = range(0, 360),
		RotSpeed = range(-45, 45),
		EmissionDirection = TOP,
	}, GRID4), "Fixed", 0.8, 6, { burst = 8 })
end

function RECIPES.Gravel(a, s)
	one(a, a.base, flipbook({
		Texture = TEX.Gravel,
		Color = ColorSequence.new(Color3.fromHex("D8CDB8")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.5 * s }, { 1, 0.4 * s } }),
		Lifetime = range(0.6, 0.9),
		Speed = range(3.5, 5.5),
		SpreadAngle = Vector2.new(28, 28),
		Acceleration = Vector3.new(0, -16, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-300, 300),
		EmissionDirection = TOP,
	}, GRID2), "Fixed", 1.5, 9, { burst = 14 })
end

function RECIPES.Debris(a, s)
	one(a, a.shell, {
		Texture = TEX.Debris,
		Color = cs("B3A382", "7A6A52"),
		LightEmission = 0,
		Size = numSeq({ { 0, 1.1 * s }, { 1, 1.4 * s } }),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(1, 2),
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, "Fixed", 0, 2.5, { burst = 6 })
end

-- Jungle Leaf ---------------------------------------------------------------------------------------------------------
function RECIPES.WindSwirl(a, s)
	groundSpin(a, s, TEX.WindSwirl, "Fixed", cs("C8FF9A", "6CDF4A"), 0.35, 6, 160, 0.4)
end

-- grass sprouting round your feet
function RECIPES.Grass(a, s)
	one(a, a.base, {
		Texture = TEX.Grass,
		Color = cs("9CFF5A", "2C8A1E"),
		LightEmission = 0,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 0 }, { 0.25, 1.6 * s }, { 0.8, 1.6 * s }, { 1, 0 } }),
		Lifetime = range(1.4, 2),
		Speed = range(0.01, 0.01),
		SpreadAngle = NO_SPREAD,
		Rotation = range(-8, 8),
		EmissionDirection = TOP,
	}, "Fixed", 0, 7, { burst = 10 })
end

-- a whirlwind of leaves: three orbiting points shedding leaves, plus a few drifting off the body
function RECIPES.LeafWhirl(a, s)
	local function leaf(parent, extra)
		local props = {
			Texture = TEX.Leaf,
			Color = cs("C8FF6A", "2FA02A"),
			LightEmission = 0,
			Size = numSeq({ { 0, 0 }, { 0.15, 0.55 * s }, { 0.85, 0.5 * s }, { 1, 0 } }),
			Lifetime = range(0.9, 1.3),
			Speed = range(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1,
			Rotation = range(0, 360),
			RotSpeed = range(-220, 220),
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return newEmitter(parent, props)
	end
	local orbit = {}
	for i = 1, 3 do
		table.insert(orbit, leaf(orbiter(a, 1.9 * s, 3, (i - 1) / 3 * math.pi * 2, (i - 2) * 0.9 * s, a.halfH * 0.3)))
	end
	layer(a, orbit, "Fixed", 0, 14, { burst = 5 })
	layer(a, { leaf(a.shell, {
		Lifetime = range(1.4, 2),
		Speed = range(0.6, 1.4),
		Acceleration = Vector3.new(0, -1.2, 0),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Fixed", 1.5, 4)
end

function RECIPES.Butterflies(a, s)
	one(a, a.shell, flipbook({
		Texture = TEX.Butterfly,
		Color = cs("FFF06A", "8CFF5A"),
		LightEmission = 0.15,
		Size = numSeq({ { 0, 0 }, { 0.15, 0.75 * s }, { 0.85, 0.75 * s }, { 1, 0 } }),
		Lifetime = range(2.2, 3),
		Speed = range(0.5, 1.1),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.4, 0),
		Drag = 0.8,
		Rotation = range(-20, 20),
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, GRID4, LOOP, 22, true), "Fixed", 0, 2, { burst = 3 })
end

function RECIPES.Fireflies(a, s)
	one(a, a.shell, {
		Texture = TEX.Firefly,
		Color = cs("F4FF8A", "C8FF4A"),
		LightEmission = 1,
		Brightness = 2,
		Size = numSeq({
			{ 0, 0 }, { 0.15, 0.5 * s }, { 0.3, 0.2 * s }, { 0.5, 0.5 * s }, { 0.7, 0.2 * s }, { 0.85, 0.5 * s }, { 1, 0 },
		}),
		Lifetime = range(2, 3),
		Speed = range(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.3, 0),
		Drag = 1,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, "Fixed", 1, 7)
end

-- Frost Breath --------------------------------------------------------------------------------------------------------
-- an icy blue cloud behind you, so the white frost reads on any floor
function RECIPES.FrostBack(a, s)
	behind(a, {
		Texture = TEX.FrostMist,
		Color = cs("8FD8FF", "3D8FE0"),
		LightEmission = 0,
		Size = numSeq({ { 0, 4 * s }, { 1, 5.5 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } }),
		Lifetime = range(0.9, 1.3),
		Rotation = range(0, 360),
		RotSpeed = range(-20, 20),
		ZOffset = -2.5,
	}, "Fixed", 1, 4, { burst = 2 })
end

function RECIPES.FrostMist(a, s)
	one(a, a.base, {
		Texture = TEX.FrostMist,
		Color = cs("FFFFFF", "DFF4FF"),
		LightEmission = 0,
		Size = numSeq({ { 0, 1.6 * s }, { 1, 3.6 * s } }),
		Transparency = numSeq({ { 0, 0.4 }, { 1, 1 } }),
		Lifetime = range(1.4, 2),
		Speed = range(0.4, 1),
		SpreadAngle = Vector2.new(85, 85),
		Acceleration = Vector3.new(0, 0.1, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-15, 15),
		EmissionDirection = TOP,
	}, "Fixed", 2, 9)
end

-- cold vapour steaming off the body, like dry ice
function RECIPES.FrostVapor(a, s)
	layer(a, onBody(a, "Big", {
		Name = "AuraFrostVapor",
		Texture = SMOKE,
		Color = cs("FFFFFF", "CFF0FF"),
		LightEmission = 0.1,
		Size = numSeq({ { 0, 0.5 * s }, { 1, 1.6 * s } }),
		Transparency = numSeq({ { 0, 0.55 }, { 1, 1 } }),
		Lifetime = range(0.7, 1),
		Speed = range(1, 2),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 2, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-30, 30),
		EmissionDirection = TOP,
	}), "Fixed", 1, 5)
end

-- ice crystals: two orbiting crystal rings while farming, a few glinting on the body otherwise
function RECIPES.IceCrystals(a, s)
	local function crystal(parent, extra)
		local props = {
			Texture = TEX.IceCrystal,
			Color = cs("CFF4FF", "4FB8FF"),
			LightEmission = 0.2,
			Size = numSeq({ { 0, 0 }, { 0.2, 0.55 * s }, { 1, 0 } }),
			Transparency = numSeq({ { 0, 0.05 }, { 1, 0.5 } }),
			Lifetime = range(0.5, 0.7),
			Speed = range(0, 0),
			Rotation = range(-20, 20),
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return newEmitter(parent, props)
	end
	layer(a, {
		crystal(orbiter(a, 1.8 * s, 2.2, 0, 0.6 * s, 0.2 * s)),
		crystal(orbiter(a, 1.8 * s, -2.2, math.pi, -0.8 * s, 0.2 * s)),
	}, "Fixed", 0, 12)
	layer(a, { crystal(a.shell, {
		Lifetime = range(1, 1.5),
		Speed = range(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = range(-60, 60),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Fixed", 2, 8, { burst = 12 })
end

function RECIPES.Snowflakes(a, s)
	one(a, a.shell, {
		Texture = TEX.Snowflake,
		Color = cs("E0F6FF", "8FD4FF"),
		LightEmission = 0.15,
		Size = numSeq({ { 0, 0.6 * s }, { 1, 0.4 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = range(1.6, 2.4),
		Speed = range(0.2, 0.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -1.2, 0),
		Drag = 0.5,
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, "Fixed", 2, 10)
end

-- frosty breath puffing from the mouth
function RECIPES.FrostBreathPuff(a, s)
	local head = a.char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local mouth = a.attach(head, "AuraBreath")
	mouth.Position = Vector3.new(0, -head.Size.Y * 0.15, -head.Size.Z / 2 - 0.05)
	one(a, mouth, {
		Texture = TEX.Breath,
		Color = cs("FFFFFF", "D8F3FF"),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.3 * s }, { 1, 1.5 * s } }),
		Transparency = numSeq({ { 0, 0.25 }, { 1, 1 } }),
		Lifetime = range(0.8, 1.1),
		Speed = range(2.5, 3.5),
		SpreadAngle = Vector2.new(14, 14),
		Drag = 2,
		Acceleration = Vector3.new(0, 0.5, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-40, 40),
		EmissionDirection = FRONT,
	}, "Fixed", 0.5, 0, { pulse = 1.6, pulseCount = 7, burst = 8 })
end

function RECIPES.IceRing(a, s)
	groundRing(a, s, TEX.IceRing, "Fixed", cs("8FDFFF", "2E8FFF"), 0.3, 1.6, 8)
end

-- the ice cracks off you when the aura reaches full power (and every few seconds after)
function RECIPES.IceShatter(a, s)
	one(a, a.shell, flipbook({
		Texture = TEX.IceShatter,
		Color = cs("F0FCFF", "8FD8FF"),
		LightEmission = 0.2,
		Size = numSeq({ { 0, 0.5 * s }, { 1, 0.35 * s } }),
		Lifetime = range(0.6, 0.9),
		Speed = range(4, 7),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-240, 240),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, GRID4), "Fixed", 0, 0, { burst = 18, pulse = 2.6, pulseCount = 6 })
end

-- Void Plasma ---------------------------------------------------------------------------------------------------------
-- a spiral galaxy portal opening behind you
function RECIPES.VoidRift(a, s)
	behind(a, {
		Texture = TEX.VoidRift,
		Color = cs("C48CFF", "7A2CFF"),
		LightEmission = 0.6,
		Brightness = 1.6,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 7 * s }, { 1, 8.5 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.25, 0.12 }, { 0.75, 0.12 }, { 1, 1 } }),
		Lifetime = range(2.4, 2.4),
		Rotation = range(0, 360),
		RotSpeed = range(-70, -50),
		ZOffset = -3,
	}, "Fixed", 0, 0.9, { burst = 1 })
end

function RECIPES.VoidWisps(a, s)
	layer(a, onBody(a, "Big", {
		Name = "AuraVoidWisp",
		Texture = TEX.VoidWisp,
		LightEmission = 0,
		Size = numSeq({ { 0, 0.8 * s }, { 1, 2.4 * s } }),
		Transparency = numSeq({ { 0, 0.2 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(1, 2),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 4 * s, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
		ZOffset = -1.5,
		EmissionDirection = TOP,
	}), "Dark", 2, 12, { burst = 3 })
end

-- three plasma orbs circling you, leaving glowing comet tails
function RECIPES.PlasmaOrbs(a, s)
	local pes = {}
	for i = 1, 3 do
		local att = orbiter(a, 2 * s, (i % 2 == 0) and -2.4 or 2.4, (i - 1) / 3 * math.pi * 2, (i - 2) * 1.1 * s, 0.3 * s)
		table.insert(pes, newEmitter(att, {
			Texture = TEX.PlasmaOrb,
			Color = ColorSequence.new(WHITE),
			LightEmission = 1,
			Size = numSeq({ { 0, 1 * s }, { 1, 0 } }),
			Transparency = numSeq({ { 0, 0 }, { 1, 0.4 } }),
			Lifetime = range(0.35, 0.5),
			Speed = range(0, 0),
			Rotation = range(0, 360),
		}))
	end
	layer(a, pes, "Fixed", 0, 24)
	-- a few plasma bubbles on the body while moving
	one(a, a.shell, {
		Texture = TEX.PlasmaOrb,
		Color = ColorSequence.new(WHITE),
		LightEmission = 1,
		Size = numSeq({ { 0, 0 }, { 0.3, 0.8 * s }, { 1, 0 } }),
		Lifetime = range(0.6, 0.9),
		Speed = range(0.5, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, "Fixed", 2, 4, { burst = 8 })
end

-- dark stars sucked into the body
function RECIPES.DarkStars(a, s)
	one(a, a.shell, {
		Texture = TEX.DarkStar,
		Color = ColorSequence.new(Color3.fromHex("2A0A4A")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.5 * s }, { 1, 0 } }),
		Lifetime = range(0.45, 0.6),
		Speed = range(4, 6),
		Rotation = range(0, 360),
		RotSpeed = range(-180, 180),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	}, "Fixed", 3, 16)
end

-- ornate crescent moons spinning round the body
function RECIPES.Moons(a, s)
	one(a, a.centre, {
		Texture = TEX.Moon,
		Color = cs("E6CCFF", "B05CFF"),
		LightEmission = 0.6,
		Size = numSeq({ { 0, 2.6 * s }, { 1, 3.3 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.25, 0.3 }, { 1, 1 } }),
		Lifetime = range(0.6, 0.8),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-300, 300),
		LockedToPart = true,
		ZOffset = -0.5,
	}, "Fixed", 0, 2.5)
end

-- Thunder Gold --------------------------------------------------------------------------------------------------------
-- a Super-Saiyan style golden power column
function RECIPES.GoldColumn(a, s)
	behind(a, {
		Texture = TEX.GoldColumn,
		LightEmission = 0.2,
		Brightness = 3,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 5.5 * s }, { 1, 7 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.7),
		Rotation = range(-4, 4),
		ZOffset = -2,
		Color = cs("FFE45A", "FFAA00"),
	}, "Fixed", 0.5, 6, { burst = 3 })
end

-- a storm cloud rolling over your head
function RECIPES.StormCloud(a, s)
	one(a, point(a, "AuraCloud", Vector3.new(0, a.halfH + 2.1 * s, 0)), {
		Texture = TEX.StormCloud,
		Color = cs("767C96", "3A3F55"),
		LightEmission = 0,
		Size = numSeq({ { 0, 1.4 * s }, { 1, 2.2 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.2, 0.05 }, { 0.8, 0.05 }, { 1, 1 } }),
		Lifetime = range(1.6, 2.2),
		Speed = range(0.5, 0.9),
		SpreadAngle = Vector2.new(180, 25),
		Drag = 1,
		Rotation = range(-10, 10),
		RotSpeed = range(-8, 8),
		EmissionDirection = Enum.NormalId.Right,
	}, "Fixed", 0, 6, { burst = 6 })
end

-- lightning striking down from the cloud on either side of you
function RECIPES.CloudBolts(a, s)
	local cloudY = a.halfH + 2.1 * s
	local length = cloudY + a.halfH
	local y = (cloudY - a.halfH) / 2
	for i, side in { -1, 1 } do
		one(a, point(a, "AuraBolt", Vector3.new(side * 1.2 * s, y, 0)), {
			Texture = TEX.Bolt,
			Color = cs("FFE45A", "FFB000"),
			LightEmission = 0.25,
			Brightness = 3,
			Orientation = UPRIGHT,
			Size = NumberSequence.new(length),
			Transparency = numSeq({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }),
			Lifetime = range(0.22, 0.3),
			Speed = range(0, 0),
			Rotation = range(-6, 6),
			LockedToPart = true,
			ZOffset = -1,
		}, "Fixed", 0, 0, { burst = 1, pulse = i == 1 and 0.9 or 1.35 })
	end
end

function RECIPES.Lightning(a, s)
	one(a, a.shell, flipbook({
		Texture = TEX.Lightning,
		Color = cs("FFE45A", "FFB000"),
		LightEmission = 0.3,
		Brightness = 3,
		Size = numSeq({ { 0, 1.7 * s }, { 1, 2.3 * s } }),
		Lifetime = range(0.25, 0.35),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		LockedToPart = true,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, GRID4, ONESHOT), "Fixed", 2, 10, { burst = 5 })
end

function RECIPES.Crackle(a, s)
	one(a, a.shell, {
		Texture = TEX.Crackle,
		Color = cs("FFD84A", "FFA000"),
		LightEmission = 0.3,
		Brightness = 3,
		Size = numSeq({ { 0, 0.9 * s }, { 1, 1.4 * s } }),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.12, 0.2),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		LockedToPart = true,
		ZOffset = 0.5,
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, "Fixed", 1, 10, { burst = 6 })
end

function RECIPES.Sparks(a, s)
	one(a, a.shell, {
		Texture = TEX.Spark,
		Color = cs("FFE45A", "FFA000"),
		LightEmission = 0.3,
		Brightness = 3,
		Orientation = STREAK,
		Size = numSeq({ { 0, 0.7 * s }, { 1, 0 } }),
		Lifetime = range(0.15, 0.3),
		Speed = range(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, "Fixed", 2, 14, { burst = 12 })
end

function RECIPES.GoldRing(a, s)
	groundRing(a, s, TEX.GoldRing, "Fixed", ColorSequence.new(WHITE), 0.8, 1.2, 9)
end

-- a radial lightning blast behind you every few seconds at full power
function RECIPES.ThunderBurst(a, s)
	behind(a, {
		Texture = TEX.ThunderBurst,
		Color = cs("FFE45A", "FFB000"),
		LightEmission = 0.3,
		Brightness = 3,
		Size = numSeq({ { 0, 2 * s }, { 1, 8 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = range(0.35, 0.35),
		Rotation = range(0, 360),
		ZOffset = -1.5,
	}, "Fixed", 0, 0, { burst = 1, pulse = 3.4 })
end

-- Magma Roar ----------------------------------------------------------------------------------------------------------
-- dark red flames behind the body; the fire texture renders dark, so the bright flames in front pop in daylight
function RECIPES.MagmaBack(a, s)
	layer(a, onBody(a, "Big", {
		Name = "AuraMagmaBack",
		Texture = TEX.MagmaFire,
		LightEmission = 0,
		Size = numSeq({ { 0, 0.6 * s }, { 0.3, 2.6 * s }, { 1, 0.8 * s } }),
		Squash = NumberSequence.new(0.4),
		Transparency = numSeq({ { 0, 0.15 }, { 0.3, 0 }, { 1, 1 } }),
		Lifetime = range(0.45, 0.75),
		Speed = range(1, 2.5),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 6 * s, 0),
		Drag = 1,
		Rotation = range(-20, 20),
		RotSpeed = range(-40, 40),
		ZOffset = -1.6,
		EmissionDirection = TOP,
	}), "Dark", 4, 22, { burst = 3 })
end

-- real flames (a hand-drawn fire flipbook) licking off the body
function RECIPES.FireFlames(a, s)
	layer(a, onBody(a, "Big", flipbook({
		Name = "AuraFireFlame",
		Texture = TEX.FireFlip,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.45,
		Brightness = 1.6,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 1.6 * s }, { 1, 2.6 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.7),
		Speed = range(1.5, 3),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 5 * s, 0),
		Drag = 1,
		Rotation = range(-10, 10),
		ZOffset = -0.6,
		EmissionDirection = TOP,
	}, GRID4, ONESHOT)), "Fixed", 3, 12, { burst = 3 })
end

-- fire geysers bursting out of the ground
function RECIPES.FireGeysers(a, s)
	one(a, a.base, flipbook({
		Texture = TEX.FirePuff,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.4,
		Size = numSeq({ { 0, 1.2 * s }, { 1, 3 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(3, 6),
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1,
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
		EmissionDirection = TOP,
	}, GRID2), "Fixed", 0, 6, { burst = 8 })
end

function RECIPES.Embers(a, s)
	one(a, a.base, {
		Texture = TEX.Embers,
		Color = ColorSequence.new(Color3.fromHex("FFE24A"), Color3.fromHex("FF4A1A")),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.35 * s }, { 1, 0 } }),
		Lifetime = range(0.7, 1.2),
		Speed = range(4, 9),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 5, 0),
		Drag = 0.8,
		EmissionDirection = TOP,
	}, "Fixed", 6, 30, { burst = 20 })
end

function RECIPES.RoarWave(a, s)
	groundRing(a, s, TEX.RoarRing, "Fixed", cs("FFD25A", "FF3A0F"), 0.7, 1.3, 10)
end

-- a magma explosion behind you, the roar
function RECIPES.MagmaBurst(a, s)
	behind(a, {
		Texture = TEX.MagmaBurst,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.5,
		Brightness = 1.4,
		Size = numSeq({ { 0, 2 * s }, { 1, 7 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
		Lifetime = range(0.45, 0.45),
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
		ZOffset = -2,
	}, "Fixed", 0, 0, { burst = 1, pulse = 2.6 })
end

-- Prism Rainbow -------------------------------------------------------------------------------------------------------
-- rays of light fanning out from behind you in every direction
function RECIPES.LightRays(a, s)
	behind(a, {
		Texture = TEX.LightRays,
		LightEmission = 0.35,
		Brightness = 1.5,
		Size = numSeq({ { 0, 5 * s }, { 1, 6.5 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.15 }, { 1, 1 } }),
		Lifetime = range(0.9, 1.2),
		Rotation = range(0, 360),
		RotSpeed = range(-30, 30),
		ZOffset = -2.5,
	}, "Trail", 0, 4, { burst = 3 })
end

-- a spinning rainbow halo behind your head
function RECIPES.RainbowHalo(a, s)
	one(a, point(a, "AuraHalo", Vector3.new(0, a.halfH - 0.9 * s, 0)), {
		Texture = TEX.RainbowHalo,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.5,
		Brightness = 1.8,
		ZOffset = -1.2,
		Size = NumberSequence.new(2.8 * s),
		Transparency = numSeq({ { 0, 1 }, { 0.25, 0.1 }, { 0.75, 0.1 }, { 1, 1 } }),
		Lifetime = range(1.6, 1.6),
		Speed = range(0.01, 0.01),
		SpreadAngle = NO_SPREAD,
		Rotation = range(0, 360),
		RotSpeed = range(90, 90),
		EmissionDirection = TOP,
		LockedToPart = true,
	}, "Fixed", 0.8, 1.6, { burst = 1 })
end

function RECIPES.PrismOrbs(a, s)
	one(a, a.shell, {
		Texture = TEX.PrismOrb,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.4,
		Size = numSeq({ { 0, 0 }, { 0.3, 0.7 * s }, { 1, 0 } }),
		Lifetime = range(0.8, 1.2),
		Speed = range(0.5, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, "Fixed", 2, 10)
end

function RECIPES.PrismStars(a, s)
	one(a, a.shell, {
		Texture = TEX.PrismStar,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.5,
		Brightness = 1.5,
		Size = numSeq({ { 0, 0.8 * s }, { 1, 0 } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = range(0, 360),
		RotSpeed = range(-90, 90),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, "Fixed", 2, 14, { burst = 14 })
end

function RECIPES.RainbowCrescents(a, s)
	one(a, a.centre, {
		Texture = TEX.RainbowCrescent,
		Color = ColorSequence.new(WHITE),
		LightEmission = 1,
		Brightness = 1.5,
		Size = numSeq({ { 0, 3.4 * s }, { 1, 4.2 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.2, 0.2 }, { 1, 1 } }),
		Lifetime = range(0.4, 0.55),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-420, 420),
		LockedToPart = true,
		ZOffset = -0.5,
	}, "Fixed", 0, 3.5)
end

-- glass shards flying off when the light breaks
function RECIPES.GlassShards(a, s)
	one(a, a.shell, {
		Texture = TEX.GlassShards,
		LightEmission = 0.4,
		Size = numSeq({ { 0, 0.7 * s }, { 1, 0.4 * s } }),
		Lifetime = range(0.6, 0.9),
		Speed = range(3, 6),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -8, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-200, 200),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}, "Trail", 0, 0, { burst = 10, pulse = 2.2, pulseCount = 4 })
end

function RECIPES.PrismBurst(a, s)
	behind(a, {
		Texture = TEX.PrismBurst,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.8,
		Brightness = 1.5,
		Size = numSeq({ { 0, 2 * s }, { 1, 7 * s } }),
		Transparency = numSeq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.5),
		Rotation = range(0, 360),
		ZOffset = -1.5,
	}, "Fixed", 0, 0, { burst = 1, pulse = 3 })
end

-- Shadow Monarch ------------------------------------------------------------------------------------------------------
-- a huge black spiky aura silhouette behind you
function RECIPES.ShadowSpikes(a, s)
	behind(a, {
		Texture = TEX.ShadowSpikes,
		LightEmission = 0,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 5.5 * s }, { 1, 7 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.2, 0 }, { 1, 1 } }),
		Lifetime = range(0.45, 0.6),
		Rotation = range(-6, 6),
		ZOffset = -3,
	}, "Dark", 1.5, 7, { burst = 3 })
end

function RECIPES.ShadowSmoke(a, s)
	one(a, a.base, {
		Texture = TEX.ShadowSmoke,
		LightEmission = 0,
		Size = numSeq({ { 0, 1.5 * s }, { 1, 3.2 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }),
		Lifetime = range(1, 1.6),
		Speed = range(0.3, 1),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = range(0, 360),
		RotSpeed = range(-20, 20),
		EmissionDirection = TOP,
	}, "Dark", 0, 5)
end

function RECIPES.ShadowVortex(a, s)
	groundSpin(a, s, TEX.ShadowVortex, "Fixed", cs("2A1446", "07040C"), 0, 6.5, -90, 0.25)
end

-- violet spiky flames engulfing the body
function RECIPES.BlueFlames(a, s)
	layer(a, onBody(a, "Big", {
		Name = "AuraBlueFlame",
		Texture = TEX.BlueFlame,
		LightEmission = 1,
		Brightness = 1.5,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 0.6 * s }, { 0.3, 1.5 * s }, { 1, 1.2 * s } }),
		Transparency = numSeq({ { 0, 0.3 }, { 0.3, 0.05 }, { 1, 1 } }),
		Lifetime = range(0.35, 0.5),
		Speed = range(1, 2),
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 5 * s, 0),
		Drag = 1,
		Rotation = range(-8, 8),
		ZOffset = -0.8,
		EmissionDirection = TOP,
	}), "Glow", 2, 10, { burst = 3 })
end

-- black smoke tendrils rising from the shadows
function RECIPES.ShadowTendrils(a, s)
	one(a, a.base, {
		Texture = TEX.Tendril,
		Color = cs("0C0814", "33195E"),
		LightEmission = 0,
		Orientation = UPRIGHT,
		Size = numSeq({ { 0, 0.8 * s }, { 1, 2.4 * s } }),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.7, 1),
		Speed = range(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 3, 0),
		Rotation = range(-20, 20),
		EmissionDirection = TOP,
	}, "Fixed", 1, 10, { burst = 6 })
end

function RECIPES.ShadowBolts(a, s)
	one(a, a.shell, {
		Texture = TEX.ShadowBolt,
		LightEmission = 1,
		Brightness = 1.5,
		Size = numSeq({ { 0, 1.4 * s }, { 1, 2 * s } }),
		Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = range(0.12, 0.2),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		LockedToPart = true,
		ZOffset = 0.5,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}, "Glow", 0.5, 8, { burst = 6 })
end

function RECIPES.Crescents(a, s)
	one(a, a.centre, {
		Texture = TEX.Crescent,
		LightEmission = 1,
		Size = numSeq({ { 0, 3.2 * s }, { 1, 4.2 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.2, 0.35 }, { 1, 1 } }),
		Lifetime = range(0.35, 0.5),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-420, 420),
		LockedToPart = true,
		ZOffset = -0.5,
	}, "Glow", 0, 3.5)
end

-- the Monarch's eye flashes open behind you ("Arise")
function RECIPES.MonarchEye(a, s)
	behind(a, {
		Texture = TEX.MonarchEye,
		LightEmission = 1,
		Brightness = 2,
		Size = numSeq({ { 0, 3 * s }, { 1, 5.5 * s } }),
		Transparency = numSeq({ { 0, 0.05 }, { 0.5, 0.2 }, { 1, 1 } }),
		Lifetime = range(0.8, 0.8),
		Rotation = range(0, 0),
		ZOffset = -2,
	}, "Glow", 0, 0, { burst = 1, pulse = 4 })
end

-- Playbook extras (AuraConfig.Styles[...].Plus, from the VFX reference playbook), drawn on top of the recipes:
--   Base    dark light-balancing smoke flat under the feet (so the bright layers read on bright grass)
--   Circle  a magic circle spinning flat on the ground while farming (Spin degrees/s, Alpha at full power)
--   Glitter sparkles rising out of the body volume (Box, Outward)
--   Flare   4-point lens-flare stars with an anamorphic streak popping on the body while farming
--   Halo    stacked flat halo rings climbing the body (top tiers)
local ANAMORPHIC = "rbxassetid://114278596683627"
local function plusLayers(a, s, plus)
	if plus.Base then
		a.recipe = "PlusBase"
		one(a, a.ground, {
			Name = "AuraPlusBase", Texture = TEX[plus.Base] or plus.Base, LightEmission = 0, LightInfluence = 0.6,
			Orientation = FLAT, EmissionDirection = TOP, Speed = range(0.01, 0.01), LockedToPart = true,
			Size = numSeq({ { 0, 4.5 * s }, { 1, 6.5 * s } }), Transparency = numSeq({ { 0, 1 }, { 0.3, plus.BaseAlpha or 0.5 }, { 1, 1 } }),
			Rotation = range(0, 360), RotSpeed = range(-12, 12), Lifetime = range(1.6, 2.4), ZOffset = -0.5,
		}, "Dark", 0.6, 3)
	end
	if plus.Circle then
		a.recipe = "PlusCircle"
		local spin = plus.Spin or 16
		one(a, a.ground, {
			Name = "AuraPlusCircle", Texture = TEX[plus.Circle] or plus.Circle, LightEmission = 1, Brightness = 3,
			Orientation = FLAT, EmissionDirection = TOP, Speed = range(0.01, 0.01), LockedToPart = true,
			Size = numSeq({ { 0, (plus.CircleSize or 6.5) * s }, { 1, (plus.CircleSize or 6.5) * 1.04 * s } }),
			Transparency = numSeq({ { 0, 1 }, { 0.25, plus.Alpha or 0.45 }, { 0.75, plus.Alpha or 0.45 }, { 1, 1 } }),
			Rotation = range(0, 360), RotSpeed = range(spin * 0.85, spin), Lifetime = range(2.4, 2.8),
		}, "Glow", 0, 0.9)
	end
	if plus.Glitter then
		a.recipe = "PlusGlitter"
		one(a, a.shell, {
			Name = "AuraPlusGlitter", Texture = TEX[plus.Glitter] or plus.Glitter, LightEmission = 1, Brightness = 2,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = VOLUME, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			EmissionDirection = TOP, Speed = range(0.5, 2), Acceleration = Vector3.new(0, 4 * s, 0), Drag = 1.5,
			Size = numSeq({ { 0, 0 }, { 0.25, 0.7 * s }, { 1, 0 } }), Transparency = numSeq({ { 0, 0.1 }, { 1, 0.6 } }),
			Rotation = range(0, 45), Lifetime = range(0.8, 1.4),
		}, plus.GlitterRole or "Glow", 2, 16)
	end
	if plus.Flare then
		local att = a.attach(a.shell, "AuraPlusPop")
		local function pop(tex, size, life, alpha)
			local pe = newEmitter(att, {
				Name = "AuraPlusFlare", Texture = tex, LightEmission = 1, Brightness = 4, Speed = range(0, 0),
				Size = numSeq({ { 0, 0 }, { 0.3, size * s }, { 1, 0 } }), Transparency = numSeq({ { 0, alpha or 0 }, { 1, alpha or 0 } }),
				Lifetime = range(life, life), Rotation = range(0, 15),
			})
			table.insert(a.instances, pe)
			return pe
		end
		local pes = { pop(TEX[plus.Flare] or plus.Flare, 2.2, 0.4), pop(ANAMORPHIC, 4.6, 0.32, 0.15) }
		a.recipe = "PlusFlare"
		layer(a, pes, plus.FlareRole or "Glow", 0, 0)
		a.pops = { att = att, pes = pes, every = plus.FlareEvery or 0.9, next = 0 }
	end
	if plus.Halo then
		a.recipe = "PlusHalo"
		for i, h in { 0.2, 0.55, 0.9 } do
			local att = point(a, "AuraPlusHalo" .. i, Vector3.new(0, a.feet - a.midY + (a.halfH * 2) * h, 0))
			one(a, att, {
				Name = "AuraPlusHalo", Texture = TEX[plus.Halo] or plus.Halo, LightEmission = 1, Brightness = 2,
				Orientation = FLAT, EmissionDirection = TOP, Speed = range(0.01, 0.01), LockedToPart = true,
				Size = numSeq({ { 0, (3.4 - h) * s }, { 1, (3.9 - h) * s } }), Transparency = numSeq({ { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } }),
				Rotation = range(0, 360), RotSpeed = range(i % 2 == 0 and -50 or 50, i % 2 == 0 and -50 or 50), Lifetime = range(1.2, 1.2),
			}, "Glow", 0, 1.3)
		end
	end
end

local function build(other, char, trailId)
	local trail = TrailConfig.ById[trailId]
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (trail and hrp and hum) then
		return nil
	end
	local style = AuraConfig.ForTrail(trail)
	local s = hrp.Size.Y / 2
	local feet = -(hrp.Size.Y / 2 + (hum.RigType == Enum.HumanoidRigType.R15 and hum.HipHeight or 2))
	local top = 2.6 * s -- just above the head
	local a = {
		player = other,
		char = char,
		hrp = hrp,
		style = style,
		pal = palette(style.Glow, style.Colors, style.Back, style.Tongue),
		scale = s,
		feet = feet,
		midY = (feet + top) / 2,
		halfH = (top - feet) / 2,
		instances = {},
		layers = {},
		ribbons = {},
		eyes = {},
		farm = 0,
		still = 0,
		powered = false,
		flash = 0,
		nextColor = 0,
	}
	local function own(inst)
		table.insert(a.instances, inst)
		return inst
	end
	local function attachment(parent, name)
		local att = own(Instance.new("Attachment"))
		att.Name = name
		att.Parent = parent
		return att
	end

	a.shell = own(anchoredPart("AuraShell", Vector3.new(3.2 * s, top - feet, 3.2 * s)))
	a.base = own(anchoredPart("AuraBase", Vector3.new(4.6 * s, 0.1, 4.6 * s)))
	a.centre = attachment(a.shell, "AuraCentre")
	a.ground = attachment(a.base, "AuraGround")
	a.attach = attachment
	a.orbits = {}

	for _, name in style.Layers do
		local recipe = RECIPES[name]
		if recipe then
			a.recipe = name
			recipe(a, s)
		else
			warn("[AuraFX] unknown aura layer", name)
		end
	end

	if style.Plus then
		plusLayers(a, s, style.Plus)
	end

	-- a sigil on the ground (SurfaceGui, so it can glow and spin as one crisp image)
	local sc = style.Sigil
	if sc and TEX[sc.Texture] then
		local size = sc.Size * s
		local p = own(anchoredPart("AuraSigil", Vector3.new(size, 0.05, size)))
		local gui = Instance.new("SurfaceGui")
		gui.Face = TOP
		gui.LightInfluence = sc.Lit and 1 or 0
		gui.Brightness = sc.Brightness or 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = p
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = TEX[sc.Texture]
		img.ImageColor3 = sc.Color == "Glow" and a.pal.glow or Color3.fromHex(sc.Color or "FFFFFF")
		img.ImageTransparency = 1
		img.Parent = gui
		a.sigil = { part = p, img = img, glow = sc.Color == "Glow", alpha = sc.Alpha or 0.25, spin = sc.Spin or 0, angle = 0 }
	end

	-- energy ribbons spiralling round the body
	local count = math.max(style.Ribbons[1], style.Ribbons[2])
	for i = 1, count do
		local a0 = attachment(hrp, "AuraRibbon")
		local a1 = attachment(hrp, "AuraRibbon")
		local tr = own(Instance.new("Trail"))
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = roleColor("Glow", a.pal)
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } })
		tr.WidthScale = numSeq({ { 0, 1 }, { 1, 0 } })
		tr.Lifetime = 0.4
		tr.MinLength = 0.02
		tr.FaceCamera = true
		if style.RibbonTexture and TEX[style.RibbonTexture] then
			tr.Texture = TEX[style.RibbonTexture]
			tr.TextureMode = Enum.TextureMode.Stretch
		end
		tr.Enabled = false
		tr.Parent = hrp
		table.insert(a.ribbons, {
			a0 = a0,
			a1 = a1,
			trail = tr,
			on = false,
			phase = (i - 1) / count * math.pi * 2,
			speed = 3.6 + i * 0.35,
			dir = i % 2 == 0 and -1 or 1,
		})
	end

	-- glowing eye slits (outside the character so the outline's body tint can't cover them)
	local head = char:FindFirstChild("Head")
	if style.Eyes and head and head:IsA("BasePart") then
		a.head = head
		local hs = head.Size.Y / 1.2
		for _, side in { -1, 1 } do
			local eye = own(Instance.new("Part"))
			eye.Name = "AuraEye"
			eye.Anchored = true
			eye.CanCollide = false
			eye.CanQuery = false
			eye.CanTouch = false
			eye.CastShadow = false
			eye.Material = Enum.Material.Neon
			eye.Color = a.pal.light
			eye.Transparency = 1
			eye.Size = Vector3.new(0.2, 0.09, 0.05) * hs
			eye.Parent = fxFolder
			local light = Instance.new("PointLight")
			light.Color = a.pal.glow
			light.Range = 2 * hs
			light.Brightness = 2
			light.Enabled = false
			light.Parent = eye
			table.insert(a.eyes, {
				part = eye,
				light = light,
				offset = CFrame.new(side * 0.2 * hs, 0.13 * hs, -head.Size.Z / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			})
		end
	end

	-- outline (the budget pass decides who actually shows one) + light
	a.highlight = own(Instance.new("Highlight"))
	a.highlight.Adornee = char
	a.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	a.highlight.FillTransparency = 1
	a.highlight.OutlineTransparency = 1
	a.highlight.Enabled = false
	a.highlight.Parent = fxFolder
	a.light = own(Instance.new("PointLight"))
	a.light.Shadows = false
	a.light.Brightness = 0
	a.light.Color = a.pal.glow
	a.light.Parent = a.shell
	return a
end

-- Re-colours everything that follows the palette (rainbow auras).
local function applyPalette(a)
	local pal = a.pal
	for _, L in a.layers do
		local c = roleColor(L.role, pal)
		if c then
			for _, pe in L.pes do
				pe.Color = c
			end
		end
	end
	local glowSeq = roleColor("Glow", pal)
	for _, rb in a.ribbons do
		rb.trail.Color = glowSeq
	end
	for _, eye in a.eyes do
		eye.part.Color = pal.light
		eye.light.Color = pal.glow
	end
	a.light.Color = pal.glow
	if a.sigil and a.sigil.glow then
		a.sigil.img.ImageColor3 = pal.glow
	end
end

local function powerUp(a, scale)
	for _, L in a.layers do
		if L.burst then
			for _, pe in L.pes do
				pe:Emit(math.max(1, math.ceil(L.burst * scale)))
			end
		end
	end
	a.flash = 1
end

local function update(a, dt, t, camPos, reduced)
	local hrp = a.hrp
	local pos = hrp.Position
	local style = a.style
	local tier = style.Tier
	local dist = (pos - camPos).Magnitude
	local near = dist < AuraConfig.Range
	local scale = reduced and AuraConfig.ReducedScale or 1
	local mult = near and scale * math.clamp(1.4 - dist / 90, 0.35, 1) or 0

	-- aura farming: standing still powers the aura up (running on a treadmill doesn't count)
	local v = hrp.AssemblyLinearVelocity
	local still = Vector3.new(v.X, 0, v.Z).Magnitude < F.StillSpeed and math.abs(v.Y) < 3 and not a.player:GetAttribute("OnTreadmill")
	a.still = still and a.still + dt or 0
	if a.still >= F.Delay then
		a.farm = math.min(1, a.farm + dt / F.RampSeconds)
	else
		a.farm = math.max(0, a.farm - dt * 4)
	end
	local f = a.farm
	if f >= 1 and not a.powered then
		a.powered = true
		if near then
			powerUp(a, scale)
		end
	elseif f < 0.4 then
		a.powered = false
	end
	a.flash = math.max(0, a.flash - dt * 2.5)

	-- rainbow: the palette turns round the colour wheel
	if style.Rainbow and near and t >= a.nextColor then
		a.nextColor = t + 0.06
		local hue = (t * 0.22) % 1
		a.pal = palette(Color3.fromHSV(hue, 0.7, 1), rainbow(t, 6), { Color3.fromHSV(hue, 0.85, 0.45), BLACK })
		applyPalette(a)
	end

	-- the helper boxes and the eyes follow the body
	local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
	local root = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local parts = { a.shell, a.base }
	local cfs = { root * CFrame.new(0, a.midY, 0), root * CFrame.new(0, a.feet + 0.05, 0) }
	local eyesOn = near and f > 0.5 and a.head ~= nil and a.head.Parent ~= nil
	for _, eye in a.eyes do
		eye.part.Transparency = eyesOn and 0 or 1
		eye.light.Enabled = eyesOn
		if eyesOn then
			table.insert(parts, eye.part)
			table.insert(cfs, a.head.CFrame * eye.offset)
		end
	end
	for _, o in a.orbits do
		local ang = t * o.speed + o.phase
		o.att.Position = Vector3.new(math.cos(ang) * o.r, o.y + math.sin(t * 1.7 + o.phase) * o.bob, math.sin(ang) * o.r)
	end
	local sigil = a.sigil
	if sigil then
		local show = near and f or 0
		sigil.img.ImageTransparency = lerp(1, sigil.alpha, show)
		if show > 0 then
			sigil.angle = (sigil.angle + sigil.spin * dt) % 360
			table.insert(parts, sigil.part)
			table.insert(cfs, root * CFrame.new(0, a.feet + 0.03, 0) * CFrame.Angles(0, math.rad(sigil.angle), 0))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)

	-- layers
	for _, L in a.layers do
		local rate = lerp(L.moving, L.farming, f) * mult
		for _, pe in L.pes do
			pe.Rate = rate
		end
		if L.pulse and near and f > 0.9 and t >= L.nextPulse then
			L.nextPulse = t + L.pulse
			for _, pe in L.pes do
				pe:Emit(L.pulseCount or 1)
			end
		end
	end
	local pops = a.pops
	if pops and near and f > 0.35 and t >= pops.next then
		pops.next = t + pops.every * (1.6 - f) * (0.7 + math.random() * 0.6)
		local sz = a.shell.Size
		pops.att.Position = Vector3.new((math.random() - 0.5) * sz.X, (math.random() - 0.3) * sz.Y * 0.8, (math.random() - 0.5) * sz.Z)
		for _, pe in pops.pes do
			pe:Emit(1)
		end
	end
	a.light.Brightness = near and (lerp(0.2, 0.8 + tier * 0.08, f) + a.flash * 2) or 0
	a.light.Range = (6 + 4 * f) * a.scale

	-- ribbons
	local want = near and math.floor(lerp(style.Ribbons[1], style.Ribbons[2], f) + 0.5) or 0
	if reduced then
		want = math.min(want, 1)
	end
	for i, rb in a.ribbons do
		local on = i <= want
		if on ~= rb.on then
			rb.on = on
			rb.trail.Enabled = on
			if on then
				rb.trail:Clear()
			end
		end
		if on then
			local ang = t * rb.speed * rb.dir + rb.phase
			local y = a.midY + math.sin(t * 2.1 + rb.phase * 1.7) * a.halfH * 0.85
			local r = (1.5 + 0.3 * math.sin(t * 2.9 + rb.phase)) * a.scale
			local p = Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)
			rb.a0.Position = p
			rb.a1.Position = p + Vector3.new(0, 0.3 * a.scale, 0)
		end
	end

	-- outline + body tint (shown or not by the budget pass)
	local outline = style.Outline
	a.wantOutline = (near and outline and (tier >= 3 or f > 0.05)) and true or false
	if a.highlight.Enabled and outline then
		local h = a.highlight
		h.OutlineColor = a.pal.light
		h.OutlineTransparency = math.clamp(lerp(0.6, 0, f) + 0.08 * math.sin(t * 7), 0, 1)
		if outline.Fill then
			h.FillColor = outline.Fill == "Dark" and a.pal.dark or a.pal.light
			h.FillTransparency = lerp(1, outline.FillMax or 0.6, f)
		else
			h.FillTransparency = 1
		end
	end
end

-- Outlines go to you first, then the nearest players, up to AuraConfig.MaxOutlines.
local function assignOutlines(camPos)
	local list = {}
	for other, a in auras do
		if a.wantOutline then
			table.insert(list, { a, other == player and -1 or (a.hrp.Position - camPos).Magnitude })
		else
			a.highlight.Enabled = false
		end
	end
	table.sort(list, function(x, y)
		return x[2] < y[2]
	end)
	for i, item in list do
		item[1].highlight.Enabled = i <= AuraConfig.MaxOutlines
	end
end

-- Rainbow trails (style Rainbow) scroll through the rainbow on every screen. Lower LightEmission keeps the colours
-- from washing out to white over the bright grass.
local function rainbowTrails(t)
	for _, other in Players:GetPlayers() do
		local id = other:GetAttribute("EquippedTrail")
		local style = type(id) == "string" and AuraConfig.Styles[id]
		if style and style.Rainbow then
			local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local tr = hrp and hrp:FindFirstChild("KaijuTrail")
			if tr then
				tr.Color = colorSeq(rainbow(t * 2, 7, 0.85))
				tr.LightEmission = 0.35
				local sparkles = hrp:FindFirstChild("KaijuTrailSparkles", true)
				if sparkles then
					sparkles.Color = tr.Color
				end
			end
		end
	end
end

local function clear(other)
	local a = auras[other]
	auras[other] = nil
	if a then
		for _, inst in a.instances do
			inst:Destroy()
		end
	end
end

local function rebuild(other)
	tokens[other] = (tokens[other] or 0) + 1
	local token = tokens[other]
	clear(other)
	local trailId = other:GetAttribute("EquippedTrail")
	local char = other.Character
	if not (Settings.Get("Auras") and char and type(trailId) == "string" and TrailConfig.ById[trailId]) then
		return
	end
	task.spawn(function()
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then
			char:WaitForChild("UpperTorso", 5)
		end
		task.wait(0.1)
		if not (hrp and hum) or tokens[other] ~= token or other.Character ~= char or not char.Parent then
			return
		end
		local ok, result = pcall(build, other, char, trailId)
		if ok then
			auras[other] = result
		else
			warn("[AuraFX] couldn't build an aura for", other.Name, result)
		end
	end)
end

local function watch(other)
	other:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
		rebuild(other)
	end)
	other.CharacterAdded:Connect(function()
		rebuild(other)
	end)
	other.CharacterRemoving:Connect(function()
		tokens[other] = (tokens[other] or 0) + 1
		clear(other)
	end)
	rebuild(other)
end

Players.PlayerAdded:Connect(watch)
for _, other in Players:GetPlayers() do
	watch(other)
end
Players.PlayerRemoving:Connect(function(other)
	clear(other)
	tokens[other] = nil
end)
Settings.Changed("Auras", function()
	for _, other in Players:GetPlayers() do
		rebuild(other)
	end
end)

local nextOutline, nextRainbow = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local reduced = Settings.Get("ReducedEffects")
	for other, a in auras do
		if a.hrp.Parent then
			local ok, err = pcall(update, a, dt, t, camPos, reduced) -- one bad aura must not take the others down
			if not ok then
				warn("[AuraFX]", other.Name, err)
				clear(other)
			end
		end
	end
	if t >= nextOutline then
		nextOutline = t + 0.25
		assignOutlines(camPos)
	end
	if t >= nextRainbow then
		nextRainbow = t + 0.05
		rainbowTrails(t)
	end
end)
