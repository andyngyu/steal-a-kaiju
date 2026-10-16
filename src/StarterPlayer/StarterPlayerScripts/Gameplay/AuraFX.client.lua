-- AuraFX: player auras, client-only and cosmetic (remade from scratch 16 Oct 2026; styles in Shared.Config.AuraConfig).
-- Every player wearing a trail (attribute EquippedTrail, set by TrailService) gets that trail's aura, built from
-- effects rather than pictures: particles (Roblox's own fire / smoke / spark / sparkle textures), glowing 3D pieces
-- floating round the body, procedural lightning (Beams), spiralling energy ribbons (Trails), a light and an outline.
-- Nothing is drawn flat on the ground. Auras idle while the player moves and power up while they stand still ("aura
-- farming"), with a burst at full power. Respects the Player Auras and Reduced Effects settings; auras fade with
-- distance and sleep beyond AuraConfig.Range. Rainbow trails (style Rainbow) also scroll the trail itself through the
-- rainbow on every screen, even with auras turned off. The trails themselves are TrailService + TrailFX, not this.
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
local TOP, BOTTOM = Enum.NormalId.Top, Enum.NormalId.Bottom
local BOX, SPHERE = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShape.Sphere
local VOLUME = Enum.ParticleEmitterShapeStyle.Volume
local STREAK = Enum.ParticleOrientation.VelocityParallel
local rng = Random.new()


local fxFolder = Instance.new("Folder")
fxFolder.Name = "PlayerAuras"
fxFolder.Parent = workspace

local auras = {} -- [player] = aura
local tokens = {} -- [player] = rebuild counter, drops stale rebuilds

---------------------------------------------------------------- helpers
local function lerp(a, b, t)
	return a + (b - a) * t
end
local function range(a, b)
	b = b or a
	return NumberRange.new(math.min(a, b), math.max(a, b))
end
local function seq(points)
	local k = {}
	for _, p in points do
		table.insert(k, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(k)
end
local function colorSeq(list)
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local k = {}
	for i, c in list do
		table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(k)
end
local function rainbowList(t, n)
	local out = {}
	for i = 1, n do
		out[i] = Color3.fromHSV((t * 0.22 + (i - 1) / n) % 1, 0.75, 1)
	end
	return out
end

local function palette(glow)
	return { glow = glow, light = glow:Lerp(WHITE, 0.55), deep = glow:Lerp(BLACK, 0.35), dark = glow:Lerp(BLACK, 0.86) }
end

-- one colour word / hex -> Color3
local function word(w, a)
	if typeof(w) == "Color3" then
		return w
	end
	local pal = a.pal
	if w == "Glow" then
		return pal.glow
	elseif w == "Light" then
		return pal.light
	elseif w == "Deep" then
		return pal.deep
	elseif w == "Dark" then
		return pal.dark
	elseif w == "White" then
		return WHITE
	elseif w == "Rainbow" then
		return Color3.fromHSV((os.clock() * 0.22) % 1, 0.75, 1)
	end
	local ok, c = pcall(Color3.fromHex, tostring(w))
	return ok and c or WHITE
end

-- a colour spec -> ColorSequence (and whether it changes over time)
local function resolveSeq(spec, a)
	if spec == "Rainbow" then
		return colorSeq(rainbowList(os.clock(), 5)), true
	end
	if type(spec) == "table" then
		local list, live = {}, false
		for _, w in spec do
			table.insert(list, word(w, a))
			live = live or w == "Glow" or w == "Light" or w == "Deep" or w == "Dark"
		end
		return colorSeq(list), live
	end
	local c = word(spec or "Glow", a)
	return ColorSequence.new(c:Lerp(WHITE, 0.25), c), spec == nil or spec == "Glow" or spec == "Light" or spec == "Deep" or spec == "Dark"
end
local function resolveColor(spec, a)
	if type(spec) == "table" then
		return word(spec[1], a)
	end
	return word(spec or "Glow", a)
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

---------------------------------------------------------------- aura plumbing
local function own(a, inst)
	table.insert(a.instances, inst)
	return inst
end

local function att(a, parent, name, pos)
	local at = own(a, Instance.new("Attachment"))
	at.Name = name
	at.Position = pos or Vector3.zero
	at.Parent = parent
	return at
end

-- something whose colour follows the palette (re-applied as a rainbow aura turns)
local function colored(a, inst, prop, spec, asSeq)
	table.insert(a.colored, { inst = inst, prop = prop, spec = spec, seq = asSeq })
end

-- particle emitters sharing a { moving, farming } rate (per emitter) and a power-up burst
local function emitters(a, parents, props, spec, rates, burst)
	local list = {}
	local cs = resolveSeq(spec, a)
	for _, parent in parents do
		local pe = Instance.new("ParticleEmitter")
		pe.LightInfluence = 0
		pe.LightEmission = 1
		for k, v in props do
			pe[k] = v
		end
		if not props.Color then
			pe.Color = cs
			colored(a, pe, "Color", spec, true)
		end
		pe.Rate = 0
		pe.Parent = parent
		own(a, pe)
		table.insert(list, pe)
	end
	table.insert(a.layers, { pes = list, moving = rates and rates[1] or 0, farming = rates and rates[2] or 0, burst = burst })
	return list
end

---------------------------------------------------------------- elements
local E = {}

function E.Smoke(a, el)
	local s, k = a.s, el.Size or 1
	emitters(a, { a.feetAtt }, {
		Name = "AuraSmoke",
		Texture = SMOKE,
		LightEmission = el.Dark and 0 or 0.35,
		LightInfluence = el.Dark and 0.6 or 0.15,
		EmissionDirection = TOP,
		Size = seq({ { 0, 1 * s * k }, { 1, 3.1 * s * k } }),
		Transparency = seq({ { 0, 1 }, { 0.25, el.Alpha or 0.55 }, { 1, 1 } }),
		Lifetime = range(1.2, 2),
		Speed = range(1.5 * s * (el.Rise or 1), 3 * s * (el.Rise or 1)),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 1.5 * s * (el.Rise or 1), 0),
		Drag = 1,
		Rotation = range(0, 360),
		RotSpeed = range(-40, 40),
		ZOffset = -0.6,
	}, el.Color, el.Rate or { 2, 8 }, 6)
end

function E.Flames(a, el)
	-- fire licking up round the body: emitted from the flame box (a little wider than the body) and drawn just behind
	-- it, so the flames frame the silhouette instead of hiding inside the limbs
	local s, k = a.s, el.Size or 1
	local rate = el.Rate or { 1, 7 }
	emitters(a, { a.flameBox }, {
		Name = "AuraFlames",
		Texture = FIRE,
		LightEmission = 0.45, -- part solid colour, part glow: pure glow washes out on the bright floors
		Brightness = el.Brightness or 2,
		Shape = BOX,
		ShapeStyle = VOLUME,
		EmissionDirection = TOP,
		Size = seq({ { 0, 0.9 * s * k }, { 0.4, 2.3 * s * k }, { 1, 0.4 * s * k } }),
		Transparency = seq({ { 0, 0.05 }, { 0.6, 0.25 }, { 1, 1 } }),
		Lifetime = range(0.4, 0.7),
		Speed = range(2 * s, 4 * s),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 8 * s, 0),
		Drag = 0.5,
		Rotation = range(-20, 20),
		RotSpeed = range(-40, 40),
		ZOffset = -0.2,
	}, el.Color or { "Light", "Glow", "Deep" }, { rate[1] * 6, rate[2] * 6 }, 12)
end

function E.Embers(a, el)
	local s, k = a.s, el.Size or 1
	emitters(a, { a.core }, {
		Name = "AuraEmbers",
		Texture = SPARKS,
		LightEmission = 0.6,
		Brightness = 3,
		Orientation = STREAK,
		Shape = BOX,
		ShapeStyle = VOLUME,
		EmissionDirection = TOP,
		Size = seq({ { 0, 0 }, { 0.2, 0.7 * s * k }, { 1, 0 } }),
		Squash = seq({ { 0, -1 }, { 1, 2.5 } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = range(0.5, 0.9),
		Speed = range(3 * s, 6 * s),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 6 * s, 0),
		Drag = 1,
	}, el.Color, el.Rate or { 3, 30 }, 18)
end

function E.Motes(a, el)
	local s, k = a.s, el.Size or 1
	emitters(a, { a.core }, {
		Name = "AuraMotes",
		Texture = SPARKLE,
		LightEmission = 0.6,
		Brightness = 2.5,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
		Size = seq({ { 0, 0 }, { 0.3, 0.58 * s * k }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(1.2, 2),
		Speed = range(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.6 * s, 0),
		Drag = 1.5,
		Rotation = range(0, 360),
		RotSpeed = range(-60, 60),
	}, el.Color, el.Rate or { 4, 20 }, 10)
end

function E.Glints(a, el)
	local s = a.s
	emitters(a, { a.core }, {
		Name = "AuraGlints",
		Texture = TEX.Star,
		Color = ColorSequence.new(WHITE),
		Brightness = 2,
		Shape = BOX,
		ShapeStyle = VOLUME,
		Size = seq({ { 0, 0 }, { 0.3, 1.1 * s }, { 1, 0 } }),
		Lifetime = range(0.25, 0.45),
		Speed = range(0, 0),
		Rotation = range(-10, 10),
		LockedToPart = true,
	}, nil, el.Rate or { 1, 10 }, 6)
end

function E.Drift(a, el)
	local s, k = a.s, el.Size or 1
	local props = {
		Name = "AuraDrift",
		Texture = TEX[el.Texture] or SPARKLE,
		LightEmission = el.Glow and 0.6 or 0,
		LightInfluence = el.Glow and 0 or 1,
		Shape = SPHERE,
		ShapeStyle = VOLUME,
		Size = seq({ { 0, 0.35 * s * k }, { 1, 0.3 * s * k } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0 }, { 0.85, 0 }, { 1, 1 } }),
		Lifetime = range(1.5, 2.5),
		Speed = range(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, el.Fall and -1.2 * s or 0.4 * s, 0),
		Drag = 1,
		Rotation = range(0, 360),
		RotSpeed = range(-180, 180),
	}
	if el.Texture == "Butterfly" then
		props.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		props.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		props.FlipbookFramerate = range(18, 24)
		props.FlipbookStartRandom = true
		props.RotSpeed = range(-20, 20)
		props.Rotation = range(-20, 20)
	end
	emitters(a, { a.core }, props, el.Color, el.Rate or { 2, 10 }, 4)
end

function E.Drips(a, el)
	local s = a.s
	emitters(a, { a.core }, {
		Name = "AuraDrips",
		Texture = SPARKS,
		Brightness = 2,
		Orientation = STREAK,
		Shape = BOX,
		ShapeStyle = VOLUME,
		EmissionDirection = BOTTOM,
		Size = seq({ { 0, 0.25 * s }, { 0.6, 0.2 * s }, { 1, 0.05 } }),
		Squash = seq({ { 0, 0 }, { 1, 1.6 } }),
		Lifetime = range(0.45, 0.75),
		Speed = range(0.2, 1),
		Acceleration = Vector3.new(0, -28, 0),
	}, el.Color, el.Rate or { 0, 6 })
end

function E.Chips(a, el)
	local s = a.s
	emitters(a, { a.feetAtt }, {
		Name = "AuraChips",
		Texture = SQUARE,
		LightEmission = 0,
		LightInfluence = 1,
		EmissionDirection = TOP,
		Size = seq({ { 0, 0.22 * s }, { 1, 0.16 * s } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(6 * s, 10 * s),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -30, 0),
		Rotation = range(0, 360),
		RotSpeed = range(-300, 300),
	}, el.Color, el.Rate or { 1, 8 }, 10)
end

function E.Cloud(a, el)
	local s = a.s
	emitters(a, { a.cloudAtt }, {
		Name = "AuraCloud",
		Texture = SMOKE,
		LightEmission = 0,
		LightInfluence = 0.4,
		Size = seq({ { 0, 1.4 * s }, { 1, 2.4 * s } }),
		Transparency = seq({ { 0, 1 }, { 0.25, 0.25 }, { 0.8, 0.3 }, { 1, 1 } }),
		Lifetime = range(1.6, 2.4),
		Speed = range(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 30),
		EmissionDirection = Enum.NormalId.Right,
		Rotation = range(0, 360),
		RotSpeed = range(-10, 10),
	}, el.Color, el.Rate or { 0, 8 }, 6)
end

-- 3D pieces floating round the body
local function makePiece(a, el, i)
	local s, k = a.s, (el.Size or 1) * rng:NextNumber(0.75, 1.25)
	local shape = el.Shape or "Rock"
	local p
	local extra = {}
	if shape == "Orb" then
		p = anchoredPart("AuraOrb", Vector3.one * 0.45 * s * k)
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
	elseif shape == "Crystal" then
		p = anchoredPart("AuraCrystal", Vector3.new(0.28, 0.9, 0.28) * s * k)
		p.Material = Enum.Material.Neon
	elseif shape == "Shard" then
		p = anchoredPart("AuraShard", Vector3.new(0.5, 0.08, 0.32) * s * k)
		p.Material = Enum.Material.Glass
		p.Reflectance = 0.3
	else
		p = anchoredPart("AuraRock", Vector3.new(rng:NextNumber(0.4, 0.7), rng:NextNumber(0.3, 0.55), rng:NextNumber(0.4, 0.7)) * s * k)
		p.Material = Enum.Material[el.Material or "Slate"] or Enum.Material.Slate
		if el.Core then
			-- a glowing core poking out of the rock's corners (a magma rock)
			local c = anchoredPart("AuraRockCore", p.Size * 0.78)
			c.Material = Enum.Material.Neon
			c.Color = word(el.Core, a)
			table.insert(extra, { part = c, base = 0, tilt = CFrame.Angles(0.6, 0.8, 0.3) })
			own(a, c)
		end
	end
	p.Color = resolveColor(el.Color, a)
	if el.Color == "Rainbow" or el.Color == nil or el.Color == "Glow" then
		colored(a, p, "Color", el.Color, false)
	end
	own(a, p)
	local base = shape == "Crystal" and 0.25 or (shape == "Shard" and 0.15 or 0)
	local piece = {
		part = p,
		extra = extra,
		base = base,
		r = (el.Radius or 2) * s * rng:NextNumber(0.85, 1.15),
		speed = (el.Speed or 1) * (i % 2 == 0 and 1 or 0.85),
		phase = (i - 1) * math.pi * 2 / 7 + rng:NextNumber(-0.3, 0.3),
		h = (el.Height or 0) * s + rng:NextNumber(-0.6, 0.6) * s,
		bob = (el.Bob or 0.3) * s,
		lift = (el.Lift or 0) * s,
		spin = el.Spin or 0.6,
		tilt = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
		alpha = 1,
	}
	if el.Trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, p.Size.Y * 0.4, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -p.Size.Y * 0.4, 0)
		a1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = resolveSeq(el.Color, a)
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
		tr.WidthScale = seq({ { 0, 1 }, { 1, 0 } })
		tr.Lifetime = 0.35
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = p
		piece.trail = tr
	end
	p.Transparency = 1
	return piece
end

function E.Pieces(a, el)
	local count = el.Count or { 0, 4 }
	local n = math.max(count[1], count[2])
	local group = { el = el, count = count, list = {} }
	for i = 1, n do
		table.insert(group.list, makePiece(a, el, i))
	end
	table.insert(a.pieceGroups, group)
end

-- energy streaks spiralling round the body
function E.Ribbons(a, el)
	local count = el.Count or { 0, 2 }
	local n = math.max(count[1], count[2])
	local group = { count = count, list = {} }
	for i = 1, n do
		local a0 = att(a, a.core, "AuraRibbon")
		local a1 = att(a, a.core, "AuraRibbon")
		local tr = own(a, Instance.new("Trail"))
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = resolveSeq(el.Color, a)
		colored(a, tr, "Color", el.Color, true)
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Transparency = seq({ { 0, 0.05 }, { 1, 1 } })
		tr.WidthScale = seq({ { 0, 1 }, { 1, 0 } })
		tr.Lifetime = 0.4
		tr.MinLength = 0.02
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = a.core
		table.insert(group.list, { a0 = a0, a1 = a1, trail = tr, on = false, phase = (i - 1) / n * math.pi * 2,
			speed = 3.6 + i * 0.35, dir = i % 2 == 0 and -1 or 1 })
	end
	table.insert(a.ribbonGroups, group)
end

-- procedural lightning: a chain of Beams through jittered points, re-rolled while it shows
local function newBolt(a, segments, spec, width)
	local bolt = { atts = {}, beams = {}, life = 0, width = width, jitterAt = 0 }
	for i = 1, segments + 1 do
		bolt.atts[i] = att(a, a.arcHost, "AuraBolt")
	end
	local cs = resolveSeq(spec, a)
	for i = 1, segments do
		local b = own(a, Instance.new("Beam"))
		b.Attachment0, b.Attachment1 = bolt.atts[i], bolt.atts[i + 1]
		b.Color = cs
		colored(a, b, "Color", spec, true)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 2.5
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = width
		b.Width1 = width
		b.Transparency = NumberSequence.new(0)
		b.Enabled = false
		b.Parent = a.arcHost
		bolt.beams[i] = b
	end
	return bolt
end

local function layBolt(bolt, p0, p1)
	local n = #bolt.atts
	local dir = p1 - p0
	local len = dir.Magnitude
	local side = dir:Cross(Vector3.new(0, 1, 0))
	if side.Magnitude < 0.01 then
		side = Vector3.new(1, 0, 0)
	end
	side = side.Unit
	local up = side:Cross(dir.Unit)
	for i = 1, n do
		local t = (i - 1) / (n - 1)
		local j = (i == 1 or i == n) and 0 or len * 0.16
		bolt.atts[i].WorldPosition = p0 + dir * t + side * rng:NextNumber(-j, j) + up * rng:NextNumber(-j, j)
	end
	for i, b in bolt.beams do
		local w = bolt.width * (1 - (i - 1) / #bolt.beams * 0.5)
		b.Width0, b.Width1 = w, w * 0.85
	end
end

local function fireBolt(bolt, p0, p1, life)
	bolt.p0, bolt.p1 = p0, p1
	bolt.life = life
	bolt.jitterAt = life * 0.5
	layBolt(bolt, p0, p1)
	for _, b in bolt.beams do
		b.Enabled = true
	end
end

function E.Arcs(a, el)
	local group = { el = el, bolts = {}, next = 0 }
	for _ = 1, el.Bolts or 2 do
		table.insert(group.bolts, newBolt(a, 5, el.Color, (el.Width or 0.12) * 1.4 * a.s))
	end
	table.insert(a.arcGroups, group)
end

function E.Strike(a, el)
	a.strike = { el = el, bolt = newBolt(a, 8, el.Color, 0.32 * a.s), next = 0 }
end

---------------------------------------------------------------- build
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
	local top = 2.6 * s
	local a = {
		player = other,
		char = char,
		hrp = hrp,
		style = style,
		pal = palette(style.Glow),
		s = s,
		feet = feet,
		midY = (feet + top) / 2,
		halfH = (top - feet) / 2,
		instances = {},
		layers = {},
		colored = {},
		pieceGroups = {},
		ribbonGroups = {},
		arcGroups = {},
		farm = 0,
		still = 0,
		powered = false,
		flash = 0,
		nextColor = 0,
	}
	a.core = own(a, anchoredPart("AuraCore", Vector3.new(2.6 * s, top - feet, 2.6 * s)))
	a.feetAtt = att(a, a.core, "AuraFeet", Vector3.new(0, feet - a.midY + 0.1, 0))
	a.flameBox = own(a, anchoredPart("AuraFlameBox", Vector3.new(3.6 * s, (top - feet) * 0.75, 2.6 * s)))
	a.cloudAtt = att(a, a.core, "AuraCloud", Vector3.new(0, top - a.midY + 2 * s, 0))
	a.arcHost = own(a, anchoredPart("AuraArcs", Vector3.one * 0.2))
	a.arcHost.CFrame = CFrame.identity

	for _, el in style.Elements or {} do
		local f = E[el.Type]
		if f then
			f(a, el)
		else
			warn("[AuraFX] unknown aura element", el.Type)
		end
	end

	-- the power-up burst: a sphere of sparkles
	a.burst = emitters(a, { a.core }, {
		Name = "AuraBurst",
		Texture = SPARKLE,
		Brightness = 2,
		Shape = SPHERE,
		Size = seq({ { 0, 0.55 * s }, { 1, 0 } }),
		Lifetime = range(0.5, 0.8),
		Speed = range(8 * s, 14 * s),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	}, style.Rainbow and "Rainbow" or { "Light", "Glow" }, { 0, 0 })[1]

	a.light = own(a, Instance.new("PointLight"))
	a.light.Color = a.pal.glow
	a.light.Shadows = false
	a.light.Brightness = 0
	a.light.Parent = a.core
	colored(a, a.light, "Color", "Glow", false)

	local h = own(a, Instance.new("Highlight"))
	h.Name = "AuraOutline"
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Enabled = false
	h.Adornee = char
	h.Parent = char
	a.highlight = h
	return a
end

-- re-colours everything that follows the palette (rainbow auras turn through the colour wheel)
local function recolor(a)
	for _, c in a.colored do
		if c.inst.Parent then
			if c.seq then
				c.inst[c.prop] = (resolveSeq(c.spec, a))
			else
				c.inst[c.prop] = resolveColor(c.spec, a)
			end
		end
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
	if a.burst then
		a.burst:Emit(math.ceil(26 * scale))
	end
	a.flash = 1
	if a.strike then
		a.strike.next = 0 -- strike right away
	end
end

---------------------------------------------------------------- per frame
local function update(a, dt, t, camPos, reduced)
	local hrp = a.hrp
	local pos = hrp.Position
	local style = a.style
	local dist = (pos - camPos).Magnitude
	local near = dist < AuraConfig.Range
	local scale = reduced and AuraConfig.ReducedScale or 1
	local mult = near and scale * math.clamp(1.4 - dist / 90, 0.35, 1) or 0
	local s = a.s

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

	if style.Rainbow and near and t >= a.nextColor then
		a.nextColor = t + 0.06
		a.pal = palette(Color3.fromHSV((t * 0.22) % 1, 0.7, 1))
		recolor(a)
	end

	-- the core follows the body; pieces float round it
	local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
	local root = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local centre = CFrame.new(pos + Vector3.new(0, a.midY, 0))
	local parts, cfs = { a.core, a.flameBox }, { root * CFrame.new(0, a.midY, 0), root * CFrame.new(0, a.midY - a.halfH * 0.2, 0) }
	for _, g in a.pieceGroups do
		local want = near and lerp(g.count[1], g.count[2], f) or 0
		if reduced then
			want = math.min(want, 2)
		end
		for i, pc in g.list do
			local target = (i <= want + 0.001) and 1 or 0
			pc.alpha = math.clamp(pc.alpha + (target - pc.alpha) * math.min(1, dt * 5), 0, 1)
			local vis = pc.alpha > 0.02
			local tr = lerp(1, pc.base, pc.alpha)
			pc.part.Transparency = vis and tr or 1
			for _, x in pc.extra do
				x.part.Transparency = vis and tr or 1
			end
			if pc.trail then
				pc.trail.Enabled = vis and near
			end
			if vis then
				local ang = t * pc.speed + pc.phase
				local y = pc.h + pc.lift * f + math.sin(t * 1.7 + pc.phase) * pc.bob
				local cf = centre * CFrame.new(math.cos(ang) * pc.r, y, math.sin(ang) * pc.r)
					* CFrame.Angles(t * pc.spin * 0.7, t * pc.spin, 0) * pc.tilt
				table.insert(parts, pc.part)
				table.insert(cfs, cf)
				for _, x in pc.extra do
					table.insert(parts, x.part)
					table.insert(cfs, cf * x.tilt)
				end
			end
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)

	-- particle layers
	for _, L in a.layers do
		local rate = lerp(L.moving, L.farming, f) * mult
		for _, pe in L.pes do
			pe.Rate = rate
		end
	end

	-- ribbons
	for _, g in a.ribbonGroups do
		local want = near and math.floor(lerp(g.count[1], g.count[2], f) + 0.5) or 0
		if reduced then
			want = math.min(want, 1)
		end
		for i, rb in g.list do
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
				local y = math.sin(t * 2.1 + rb.phase * 1.7) * a.halfH * 0.85
				local r = (1.5 + 0.3 * math.sin(t * 2.9 + rb.phase)) * s
				local p = Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)
				rb.a0.Position = p
				rb.a1.Position = p + Vector3.new(0, 0.45 * s, 0)
			end
		end
	end

	-- lightning
	local body = pos + Vector3.new(0, a.midY, 0)
	local function tickBolt(bolt)
		if bolt.life > 0 then
			bolt.life -= dt
			if bolt.life <= 0 then
				for _, b in bolt.beams do
					b.Enabled = false
				end
			elseif bolt.jitterAt > 0 and bolt.life <= bolt.jitterAt then
				bolt.jitterAt = 0
				layBolt(bolt, bolt.p0, bolt.p1)
			end
		end
	end
	for _, g in a.arcGroups do
		for _, bolt in g.bolts do
			tickBolt(bolt)
		end
		local every = f > 0.5 and g.el.Every[2] or g.el.Every[1]
		if every and near and t >= g.next then
			g.next = t + every * rng:NextNumber(0.6, 1.4) * (reduced and 2.5 or 1)
			for _, bolt in g.bolts do
				if bolt.life <= 0 then
					local d0 = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
					if d0.Magnitude < 0.01 then
						d0 = Vector3.new(1, 0, 0)
					end
					local p0 = body + d0.Unit * rng:NextNumber(0.5, 1.3) * s + Vector3.new(0, rng:NextNumber(-1, 1) * a.halfH * 0.7, 0)
					local d1 = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-1, 1))
					if d1.Magnitude < 0.01 then
						d1 = Vector3.new(0, 1, 0)
					end
					local p1 = p0 + d1.Unit * (g.el.Length or 2) * s * rng:NextNumber(0.7, 1.2)
					fireBolt(bolt, p0, p1, rng:NextNumber(0.08, 0.16))
					break
				end
			end
		end
	end
	local st = a.strike
	if st then
		tickBolt(st.bolt)
		if near and a.powered and t >= st.next then
			st.next = t + (st.el.Every or 3) * rng:NextNumber(0.75, 1.3) * (reduced and 2 or 1)
			local head = pos + Vector3.new(0, a.midY + a.halfH, 0)
			local sky = head + Vector3.new(rng:NextNumber(-2, 2) * s, 14 * s, rng:NextNumber(-2, 2) * s)
			fireBolt(st.bolt, sky, head, 0.18)
			a.flash = math.max(a.flash, 0.8)
		end
	end

	-- light + outline
	a.light.Brightness = near and (lerp(0.2, 0.8 + style.Tier * 0.08, f) + a.flash * 2) or 0
	a.light.Range = (6 + 4 * f) * s
	local outline = style.Outline
	a.wantOutline = (near and outline and (style.Tier >= 3 or f > 0.05)) and true or false
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

-- outlines go to you first, then the nearest players, up to AuraConfig.MaxOutlines
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

-- Rainbow trails scroll through the rainbow on every screen (this is the trail, so it runs even with auras off)
local function rainbowTrails(t)
	for _, other in Players:GetPlayers() do
		local id = other:GetAttribute("EquippedTrail")
		local style = type(id) == "string" and AuraConfig.Styles[id]
		if style and style.Rainbow then
			local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local tr = hrp and hrp:FindFirstChild("KaijuTrail")
			if tr then
				tr.Color = colorSeq(rainbowList(t * 2, 7))
				tr.LightEmission = 0.35
				local sparkles = hrp:FindFirstChild("KaijuTrailSparkles", true)
				if sparkles then
					sparkles.Color = tr.Color
				end
			end
		end
	end
end

---------------------------------------------------------------- lifecycle
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
