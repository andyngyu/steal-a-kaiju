-- Player auras, client-only and cosmetic. Every player wearing a trail (attribute EquippedTrail, set by TrailService)
-- gets that trail's aura from Shared.Config.AuraConfig: a list of layer recipes (RECIPES below) in the trail's theme -
-- dust and pebbles, leaves and fireflies, frost, void plasma, lightning, fire, rainbow light, or the Shadow Monarch's
-- black flames and glowing eyes. Auras idle quietly while the player moves and power up when they stand still ("aura
-- farming"), with a burst when they reach full power. On top of the layers: a glowing outline (Highlight, on you and the
-- nearest few players) that can also tint the body, energy ribbons spiralling round the body, a coloured light and, for
-- the Monarch, glowing eye slits.
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
	return NumberRange.new(a, b)
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

local function flatSwirl(a, s, role, dir, lightEmission)
	layer(a, { newEmitter(a.ground, {
		Texture = TEX.Swirl,
		LightEmission = lightEmission,
		Orientation = FLAT,
		Size = numSeq({ { 0, 4 * s }, { 1, 6 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.25, 0.4 }, { 1, 1 } }),
		Lifetime = range(1, 1.4),
		Speed = range(0.01, 0.01),
		SpreadAngle = Vector2.new(0, 0),
		Rotation = range(0, 360),
		RotSpeed = dir > 0 and range(80, 140) or range(-140, -80),
		EmissionDirection = TOP,
		LockedToPart = true,
	}) }, role, 0, 1.6)
end

local function ringPulse(a, s, role, every)
	layer(a, { newEmitter(a.ground, {
		Texture = TEX.Ring,
		LightEmission = 1,
		Orientation = FLAT,
		Size = numSeq({ { 0, 1 * s }, { 1, 9 * s } }),
		Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = range(0.7, 0.7),
		Speed = range(0.01, 0.01),
		SpreadAngle = Vector2.new(0, 0),
		Rotation = range(0, 360),
		EmissionDirection = TOP,
	}) }, role, 0, 0, { burst = 2, pulse = every })
end

local function risingLines(a, s, role)
	layer(a, { newEmitter(a.base, {
		Texture = TEX.Streak,
		LightEmission = 1,
		Orientation = STREAK,
		Size = numSeq({ { 0, 0.6 * s }, { 0.5, 1.6 * s }, { 1, 0.4 * s } }),
		Transparency = numSeq({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = range(0.4, 0.65),
		Speed = range(8, 14),
		SpreadAngle = Vector2.new(3, 3),
		EmissionDirection = TOP,
	}) }, role, 0, 28, { burst = 30 })
end

-- Layer recipes, named in AuraConfig.Styles[...].Layers. s = character scale (1 for a normal character).
local RECIPES = {}

-- Backdrop: big flames behind the body in the style's Back colours (black for the Shadow Monarch, dark red for magma,
-- storm grey for thunder...). The fire texture renders dark, which is what makes the bright tongues in front pop in
-- daylight.
function RECIPES.Backdrop(a, s)
	layer(a, onBody(a, "Big", {
		Name = "AuraBackdrop",
		Texture = FIRE,
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
	}), "Dark", 5, 26, { burst = 3 })
end

-- Tongues: bright flame tongues in the style's Tongue colours (soft discs stretched upward, additive)
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

function RECIPES.SmokePool(a, s)
	layer(a, { newEmitter(a.base, {
		Texture = TEX.Smoke,
		LightEmission = 0,
		Size = numSeq({ { 0, 1.5 * s }, { 1, 3.2 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }),
		Lifetime = range(1, 1.6),
		Speed = range(0.3, 1),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = range(0, 360),
		RotSpeed = range(-20, 20),
		EmissionDirection = TOP,
	}) }, "Dark", 0, 5)
end

function RECIPES.GroundSwirl(a, s)
	flatSwirl(a, s, "Glow", 1, 1)
end

function RECIPES.EnergyLines(a, s)
	risingLines(a, s, "Glow")
end

function RECIPES.Crackle(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = TEX.Crackle,
		LightEmission = 1,
		Size = numSeq({ { 0, 0.9 * s }, { 1, 1.4 * s } }),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.12, 0.2),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		LockedToPart = true,
		ZOffset = 0.5,
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Glow", 1, 11, { burst = 6 })
end

function RECIPES.Crescents(a, s)
	layer(a, { newEmitter(a.centre, {
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
	}) }, "Glow", 0, 3.5)
end

function RECIPES.Shockwave(a, s)
	ringPulse(a, s, "Glow", 1.15)
end

-- Pebble Dust
function RECIPES.Dust(a, s)
	layer(a, { newEmitter(a.base, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(Color3.fromHex("E2D6BA"), Color3.fromHex("A89A7C")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.8 * s }, { 1, 2.6 * s } }),
		Transparency = numSeq({ { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } }),
		Lifetime = range(1, 1.6),
		Speed = range(0.4, 1.2),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 1.2, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-30, 30),
		EmissionDirection = TOP,
	}) }, "Fixed", 2, 12)
end

function RECIPES.Pebbles(a, s)
	layer(a, { newEmitter(a.base, {
		Texture = SQUARE,
		Color = ColorSequence.new(Color3.fromHex("B7B9C4"), Color3.fromHex("7E8190")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.32 * s }, { 0.85, 0.26 * s }, { 1, 0 } }),
		Lifetime = range(1.4, 2),
		Speed = range(1.2, 2.6),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 0.4, 0),
		Drag = 1.4,
		Rotation = range(0, 360),
		RotSpeed = range(-120, 120),
		EmissionDirection = TOP,
	}) }, "Fixed", 0, 9, { burst = 10 })
end

-- Jungle Leaf
function RECIPES.Leaves(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SQUARE,
		Color = ColorSequence.new(Color3.fromHex("B6FF5A"), Color3.fromHex("1F8A1F")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.36 * s }, { 0.8, 0.32 * s }, { 1, 0 } }),
		Squash = NumberSequence.new(-0.4),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 0.6 } }),
		Lifetime = range(0.9, 1.4),
		Speed = range(1.5, 3.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 2.2, 0),
		Drag = 1.2,
		Rotation = range(0, 360),
		RotSpeed = range(-220, 220),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Fixed", 2, 14, { burst = 12 })
end

function RECIPES.Fireflies(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromHex("F4FF8A"), Color3.fromHex("B6FF4A")),
		LightEmission = 1,
		Size = numSeq({ { 0, 0 }, { 0.2, 0.32 * s }, { 0.8, 0.32 * s }, { 1, 0 } }),
		Lifetime = range(1.4, 2.2),
		Speed = range(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.3, 0),
		Drag = 1,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}) }, "Fixed", 1, 8)
end

-- Frost Breath
function RECIPES.FrostMist(a, s)
	layer(a, { newEmitter(a.base, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("DFF4FF")),
		LightEmission = 0,
		Size = numSeq({ { 0, 1.5 * s }, { 1, 3.5 * s } }),
		Transparency = numSeq({ { 0, 0.35 }, { 1, 1 } }),
		Lifetime = range(1.2, 1.8),
		Speed = range(0.4, 1),
		SpreadAngle = Vector2.new(85, 85),
		Acceleration = Vector3.new(0, 0.15, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-15, 15),
		EmissionDirection = TOP,
	}) }, "Fixed", 2, 10)
end

function RECIPES.IceShards(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SQUARE,
		Color = ColorSequence.new(WHITE, Color3.fromHex("7FD0FF")),
		LightEmission = 0.1,
		Size = numSeq({ { 0, 0.45 * s }, { 1, 0.3 * s } }),
		Squash = NumberSequence.new(1.6),
		Transparency = numSeq({ { 0, 0 }, { 1, 0.6 } }),
		Lifetime = range(1, 1.6),
		Speed = range(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 1,
		Rotation = range(0, 360),
		RotSpeed = range(-90, 90),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Fixed", 3, 18, { burst = 14 })
end

function RECIPES.Snowfall(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SPARKLE,
		Color = ColorSequence.new(WHITE),
		LightEmission = 0.4,
		Size = numSeq({ { 0, 0.4 * s }, { 1, 0.2 * s } }),
		Lifetime = range(1.2, 1.8),
		Speed = range(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -1.5, 0),
		Drag = 0.5,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}) }, "Fixed", 2, 12)
end

function RECIPES.FrostRing(a, s)
	ringPulse(a, s, "Glow", 1.7)
end

-- Void Plasma
function RECIPES.VoidVortex(a, s)
	flatSwirl(a, s, "Dark", -1, 0)
end

function RECIPES.PlasmaOrbs(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = TEX.Blob,
		LightEmission = 1,
		Size = numSeq({ { 0, 0 }, { 0.3, 0.9 * s }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0.3 }, { 1, 0.6 } }),
		Lifetime = range(0.6, 0.9),
		Speed = range(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 1.5, 0),
		Drag = 1,
		ZOffset = -0.5,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}) }, "Flame", 6, 34, { burst = 10 })
end

function RECIPES.VoidMotes(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SQUARE,
		Color = ColorSequence.new(Color3.fromHex("2A0A4A"), Color3.fromHex("8A3CFF")),
		LightEmission = 0,
		Size = numSeq({ { 0, 0.28 * s }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0.15 }, { 1, 0.4 } }),
		Lifetime = range(0.45, 0.6),
		Speed = range(4, 6),
		Rotation = range(0, 360),
		RotSpeed = range(-180, 180),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	}) }, "Fixed", 4, 26)
end

function RECIPES.Stars(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SPARKLE,
		Color = ColorSequence.new(WHITE, Color3.fromHex("E6CCFF")),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.35 * s }, { 1, 0 } }),
		Lifetime = range(0.5, 0.9),
		Speed = range(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}) }, "Fixed", 2, 10)
end

-- Thunder Gold
function RECIPES.Lightning(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = TEX.Lightning,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(WHITE, Color3.fromHex("FFE24A")),
		LightEmission = 1,
		Size = numSeq({ { 0, 1.7 * s }, { 1, 2.3 * s } }),
		Lifetime = range(0.25, 0.35),
		Speed = range(0, 0),
		Rotation = range(0, 360),
		LockedToPart = true,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
	}) }, "Fixed", 2, 12, { burst = 5 })
end

function RECIPES.Sparks(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SPARKS,
		Color = ColorSequence.new(WHITE, Color3.fromHex("FFD23F")),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.3 * s }, { 1, 0 } }),
		Lifetime = range(0.15, 0.3),
		Speed = range(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Fixed", 2, 16, { burst = 12 })
end

-- Magma Roar
function RECIPES.Embers(a, s)
	layer(a, { newEmitter(a.base, {
		Texture = SPARKS,
		Color = ColorSequence.new(Color3.fromHex("FFE24A"), Color3.fromHex("FF4A1A")),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.35 * s }, { 1, 0 } }),
		Lifetime = range(0.7, 1.2),
		Speed = range(4, 9),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 5, 0),
		Drag = 0.8,
		EmissionDirection = TOP,
	}) }, "Fixed", 6, 34, { burst = 20 })
end

function RECIPES.LavaSwirl(a, s)
	flatSwirl(a, s, "Trail", 1, 1)
end

-- Prism Rainbow
function RECIPES.Prisms(a, s)
	layer(a, { newEmitter(a.shell, {
		Texture = SPARKLE,
		LightEmission = 1,
		Size = numSeq({ { 0, 0.45 * s }, { 1, 0 } }),
		Lifetime = range(0.6, 1),
		Speed = range(1, 2.5),
		SpreadAngle = Vector2.new(180, 180),
		Shape = SPHERE,
		ShapeStyle = SURFACE,
	}) }, "Trail", 4, 22, { burst = 16 })
end

function RECIPES.LightRays(a, s)
	risingLines(a, s, "Trail")
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

	for _, name in style.Layers do
		local recipe = RECIPES[name]
		if recipe then
			a.recipe = name
			recipe(a, s)
		else
			warn("[AuraFX] unknown aura layer", name)
		end
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
				pe:Emit(1)
			end
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
