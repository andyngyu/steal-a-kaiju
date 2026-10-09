-- Player auras, client-only and cosmetic. Every player wearing a trail (attribute EquippedTrail, set by TrailService)
-- gets the matching aura from Shared.Config.AuraConfig. It idles quietly while they move and powers up when they stand
-- still ("aura farming"), with a burst when it reaches full power. Pieces, switched on by the style's tier:
--   flames   fire / smoke wisps rising off every body part, drawn just behind the body (ZOffset) so the silhouette
--            glows like an anime aura; a soft glow behind the body from tier 3
--   outline  glowing silhouette (Highlight) on you and the nearest few players (AuraConfig.MaxOutlines)
--   ribbons  energy streaks spiralling round the body (Trails on orbiting attachments)
--   ground   rising streaks (tier 4+) and shockwave rings (tier 5+) at the feet while farming
--   extra    per trail: dust, leaves, snow + mist, void motes pulled into the body, lightning arcs, embers, sparkles
--   light    a coloured glow on the body
-- Rainbow styles cycle every colour, and the wearer's trail itself scrolls through the rainbow on every screen (even
-- with auras turned off). Respects the Player Auras and Reduced Effects settings; auras beyond AuraConfig.Range sleep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AuraConfig = require(Config:WaitForChild("AuraConfig"))
local TrailConfig = require(Config:WaitForChild("TrailConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer
local F = AuraConfig.Farm

local TEX = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Glow = "rbxasset://textures/particles/explosion01_core_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
}

-- Body parts that give off flames (R15 names, then R6).
local BODY_PARTS = {
	"UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "PlayerAuras"
fxFolder.Parent = workspace

local auras = {} -- [player] = aura
local tokens = {} -- [player] = rebuild counter, drops stale rebuilds

local function lerp(a, b, t)
	return a + (b - a) * t
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

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightInfluence = 0
	pe.Rate = 0
	for k, v in props do
		pe[k] = v
	end
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

-- Per-trail extras: list of { emitter, rate while moving, rate while farming, rainbow? }.
-- a.shell is an invisible box round the body, a.base a flat one at the feet (both follow the body).
local EXTRAS = {
	Dust = function(a, s)
		return {
			{ emitter(a.base, {
				Texture = TEX.Smoke,
				Color = ColorSequence.new(Color3.fromHex("EDE5D2"), Color3.fromHex("B8AE98")),
				LightEmission = 0.2,
				Size = numSeq({ { 0, 0.5 * s }, { 1, 1.6 * s } }),
				Transparency = numSeq({ { 0, 0.55 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1, 1.6),
				Speed = NumberRange.new(0.4, 1.2),
				SpreadAngle = Vector2.new(60, 60),
				Acceleration = Vector3.new(0, 1.2, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-30, 30),
				EmissionDirection = Enum.NormalId.Top,
			}), 2, 10 },
		}
	end,
	Leaves = function(a, s)
		return {
			{ emitter(a.shell, {
				Texture = TEX.Square,
				Color = ColorSequence.new(Color3.fromHex("8CFF5A"), Color3.fromHex("2FA82A")),
				LightEmission = 0.25,
				Size = numSeq({ { 0, 0.22 * s }, { 0.8, 0.2 * s }, { 1, 0 } }),
				Transparency = numSeq({ { 0, 0.1 }, { 1, 0.6 } }),
				Lifetime = NumberRange.new(0.9, 1.4),
				Speed = NumberRange.new(1.5, 3.5),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 2.2, 0),
				Drag = 1.2,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-220, 220),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			}), 2, 14 },
		}
	end,
	Snow = function(a, s)
		return {
			{ emitter(a.shell, {
				Texture = TEX.Square,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("BFE8FF")),
				LightEmission = 0.6,
				Size = numSeq({ { 0, 0.16 * s }, { 1, 0.08 * s } }),
				Transparency = numSeq({ { 0, 0.05 }, { 1, 0.7 } }),
				Lifetime = NumberRange.new(1, 1.6),
				Speed = NumberRange.new(0.6, 1.6),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, -1.2, 0),
				Drag = 0.8,
				Rotation = NumberRange.new(0, 90),
				RotSpeed = NumberRange.new(-90, 90),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			}), 3, 16 },
			{ emitter(a.base, {
				Texture = TEX.Smoke,
				Color = ColorSequence.new(Color3.fromHex("DFF4FF")),
				LightEmission = 0.3,
				Size = numSeq({ { 0, 1.2 * s }, { 1, 3 * s } }),
				Transparency = numSeq({ { 0, 0.7 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.2, 1.8),
				Speed = NumberRange.new(0.8, 1.6),
				SpreadAngle = Vector2.new(85, 85),
				Acceleration = Vector3.new(0, 0.2, 0),
				Rotation = NumberRange.new(0, 360),
				EmissionDirection = Enum.NormalId.Top,
			}), 0, 6 },
		}
	end,
	Void = function(a, s)
		return {
			{ emitter(a.shell, {
				Texture = TEX.Square,
				Color = ColorSequence.new(Color3.fromHex("2A0A4A"), Color3.fromHex("8A3CFF")),
				LightEmission = 0,
				Size = numSeq({ { 0, 0.28 * s }, { 1, 0 } }),
				Transparency = numSeq({ { 0, 0.15 }, { 1, 0.4 } }),
				Lifetime = NumberRange.new(0.45, 0.6),
				Speed = NumberRange.new(4, 6),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-180, 180),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			}), 4, 26 },
		}
	end,
	Lightning = function(a, s)
		return {
			{ emitter(a.shell, {
				Texture = TEX.Sparks,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("FFE24A")),
				LightEmission = 1,
				Size = numSeq({ { 0, 0.3 * s }, { 1, 0 } }),
				Lifetime = NumberRange.new(0.15, 0.3),
				Speed = NumberRange.new(4, 8),
				SpreadAngle = Vector2.new(180, 180),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			}), 2, 16 },
		}
	end,
	Embers = function(a, s)
		return {
			{ emitter(a.base, {
				Texture = TEX.Sparks,
				Color = ColorSequence.new(Color3.fromHex("FFE24A"), Color3.fromHex("FF4A1A")),
				LightEmission = 1,
				Size = numSeq({ { 0, 0.35 * s }, { 1, 0 } }),
				Lifetime = NumberRange.new(0.7, 1.2),
				Speed = NumberRange.new(4, 9),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, 5, 0),
				Drag = 0.8,
				EmissionDirection = Enum.NormalId.Top,
			}), 6, 34 },
		}
	end,
	Sparkles = function(a, s)
		return {
			{ emitter(a.shell, {
				Texture = TEX.Sparkle,
				LightEmission = 1,
				Size = numSeq({ { 0, 0.45 * s }, { 1, 0 } }),
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(1, 2.5),
				SpreadAngle = Vector2.new(180, 180),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			}), 4, 22, true },
		}
	end,
}

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
		scale = s,
		feet = feet,
		midY = (feet + top) / 2,
		halfH = (top - feet) / 2,
		instances = {},
		flames = {},
		extras = {},
		ribbons = {},
		arcs = {},
		farm = 0,
		still = 0,
		powered = false,
		flash = 0,
		nextArc = 0,
		nextPulse = 0,
		nextColor = 0,
	}
	local function own(inst)
		table.insert(a.instances, inst)
		return inst
	end
	local colors = colorSeq(style.Colors)
	local glow = style.Glow

	a.shell = own(anchoredPart("AuraShell", Vector3.new(4 * s, top - feet, 4 * s)))
	a.base = own(anchoredPart("AuraBase", Vector3.new(4.6 * s, 0.1, 4.6 * s)))

	-- flames off every body part, just behind the body
	local size = style.FlameSize * s
	for _, name in BODY_PARTS do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(a.flames, own(emitter(part, {
				Name = "AuraFlame",
				Texture = style.Smoke and TEX.Smoke or TEX.Fire,
				Color = colors,
				LightEmission = style.LightEmission,
				Size = numSeq({ { 0, 0.15 * size }, { 0.25, 0.85 * size }, { 1, 0.1 * size } }),
				Transparency = numSeq({ { 0, 0.35 }, { 0.3, 0.12 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.35, 0.65),
				Speed = NumberRange.new(0.6, 2),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, 8 * s, 0),
				Drag = 1.5,
				Rotation = NumberRange.new(-25, 25),
				RotSpeed = NumberRange.new(-60, 60),
				ZOffset = -1.2,
				EmissionDirection = Enum.NormalId.Top,
			})))
		end
	end

	-- soft glow behind the body
	if style.Tier >= 3 then
		a.glow = own(emitter(a.shell, {
			Texture = TEX.Glow,
			Color = ColorSequence.new(glow),
			LightEmission = 1,
			Size = numSeq({ { 0, 2.6 * s }, { 1, 4 * s } }),
			Transparency = numSeq({ { 0, 1 }, { 0.3, 0.8 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(0, 0),
			LockedToPart = true,
			ZOffset = -2.5,
		}))
	end

	-- ground: rising streaks and shockwave rings
	if style.Tier >= 4 then
		a.streaks = own(emitter(a.base, {
			Texture = TEX.Square,
			Color = colors,
			LightEmission = 1,
			Size = numSeq({ { 0, 0.12 * s }, { 1, 0.04 * s } }),
			Squash = NumberSequence.new(2.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(7, 13),
			SpreadAngle = Vector2.new(4, 4),
			EmissionDirection = Enum.NormalId.Top,
		}))
	end
	if style.Tier >= 5 then
		local center = own(Instance.new("Attachment"))
		center.Parent = a.base
		a.shock = own(emitter(center, {
			Texture = TEX.Ring,
			Color = ColorSequence.new(glow),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = numSeq({ { 0, 1 * s }, { 1, 8 * s } }),
			Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.75, 0.75),
			Speed = NumberRange.new(0.01, 0.01),
			SpreadAngle = Vector2.new(0, 0),
			EmissionDirection = Enum.NormalId.Top,
		}))
	end

	-- trail extras
	local extra = style.Extra and EXTRAS[style.Extra]
	if extra then
		for _, x in extra(a, s) do
			table.insert(a.extras, { pe = own(x[1]), moving = x[2], farming = x[3], rainbow = x[4] })
		end
	end

	-- lightning arcs: 4 jittered points joined by 3 beams, re-drawn several times a second
	if style.Extra == "Lightning" then
		for _ = 1, 2 do
			local arc = { atts = {}, beams = {} }
			for i = 1, 4 do
				local att = own(Instance.new("Attachment"))
				att.Name = "AuraArc"
				att.Parent = hrp
				arc.atts[i] = att
			end
			for i = 1, 3 do
				local b = own(Instance.new("Beam"))
				b.Attachment0 = arc.atts[i]
				b.Attachment1 = arc.atts[i + 1]
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				b.Width0 = 0.16 * s
				b.Width1 = 0.16 * s
				b.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("FFE24A"))
				b.Transparency = NumberSequence.new(0)
				b.Enabled = false
				b.Parent = hrp
				arc.beams[i] = b
			end
			table.insert(a.arcs, arc)
		end
	end

	-- ribbons spiralling round the body
	local count = math.max(style.Ribbons, style.RibbonsMoving)
	for i = 1, count do
		local a0 = own(Instance.new("Attachment"))
		a0.Name = "AuraRibbon"
		a0.Parent = hrp
		local a1 = own(Instance.new("Attachment"))
		a1.Name = "AuraRibbon"
		a1.Parent = hrp
		local tr = own(Instance.new("Trail"))
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = colors
		tr.LightEmission = math.max(style.LightEmission, 0.6)
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

	-- glowing outline (the budget pass decides who actually shows one) + light
	a.highlight = own(Instance.new("Highlight"))
	a.highlight.Adornee = char
	a.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	a.highlight.FillColor = glow
	a.highlight.OutlineColor = glow
	a.highlight.FillTransparency = 1
	a.highlight.OutlineTransparency = 1
	a.highlight.Enabled = false
	a.highlight.Parent = fxFolder
	a.light = own(Instance.new("PointLight"))
	a.light.Color = glow
	a.light.Shadows = false
	a.light.Brightness = 0
	a.light.Parent = a.shell
	return a
end

local function powerUp(a, mult)
	for _, pe in a.flames do
		pe:Emit(math.ceil(4 * mult))
	end
	if a.shock then
		a.shock:Emit(1)
	end
	if a.streaks then
		a.streaks:Emit(math.ceil(30 * mult))
	end
	a.flash = 1
end

local function update(a, dt, t, camPos, reduced)
	local hrp = a.hrp
	local pos = hrp.Position
	local style = a.style
	local near = (pos - camPos).Magnitude < AuraConfig.Range
	local scale = reduced and AuraConfig.ReducedScale or 1
	local mult = near and scale or 0

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

	-- the helper boxes follow the body (yaw only)
	local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
	local root = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	workspace:BulkMoveTo({ a.shell, a.base }, { root * CFrame.new(0, a.midY, 0), root * CFrame.new(0, a.feet + 0.05, 0) }, Enum.BulkMoveMode.FireCFrameChanged)

	-- particles
	local flameRate = lerp(style.Flames[1], style.Flames[2], f) * mult / math.max(1, #a.flames)
	for _, pe in a.flames do
		pe.Rate = flameRate
	end
	if a.glow then
		a.glow.Rate = lerp(0, 7, f) * mult
	end
	for _, x in a.extras do
		x.pe.Rate = lerp(x.moving, x.farming, f) * mult
	end
	if a.streaks then
		a.streaks.Rate = f * 36 * mult
	end
	if a.shock and near and f > 0.9 and t >= a.nextPulse then
		a.nextPulse = t + 1.15
		a.shock:Emit(1)
	end
	a.light.Brightness = near and (lerp(0.25, 1.4 + style.Tier * 0.15, f) + a.flash * 3) or 0
	a.light.Range = (8 + 6 * f) * a.scale

	-- ribbons
	local want = near and math.floor(lerp(style.RibbonsMoving, style.Ribbons, f) + 0.5) or 0
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

	-- outline (shown or not by the budget pass)
	a.wantOutline = near and (style.Tier >= 3 or (style.Tier == 2 and f > 0.05))
	if a.highlight.Enabled then
		a.highlight.OutlineTransparency = math.clamp(lerp(0.6, 0, f) + 0.08 * math.sin(t * 7), 0, 1)
		a.highlight.FillTransparency = lerp(1, 0.82, f)
	end

	-- lightning
	if #a.arcs > 0 and t >= a.nextArc then
		a.nextArc = t + 0.05 + math.random() * 0.07
		local chance = (near and not reduced) and lerp(0.12, 0.7, f) or 0
		for _, arc in a.arcs do
			local on = math.random() < chance
			for _, b in arc.beams do
				b.Enabled = on
			end
			if on then
				local ang = math.random() * math.pi * 2
				local sweep = (math.random() < 0.5 and -1 or 1) * (0.7 + math.random() * 1.1)
				local y0 = a.feet + 1 + math.random() * (a.halfH * 2 - 1.5)
				local y1 = y0 + (math.random() - 0.5) * 2.4 * a.scale
				for i, att in arc.atts do
					local k = (i - 1) / 3
					local r = (1.1 + math.random() * 0.6) * a.scale
					local aa = ang + sweep * k
					att.Position = Vector3.new(math.cos(aa) * r, lerp(y0, y1, k) + (math.random() - 0.5) * 0.6, math.sin(aa) * r)
				end
			end
		end
	end

	-- rainbow: every colour turns round the colour wheel
	if style.Rainbow and near and t >= a.nextColor then
		a.nextColor = t + 0.06
		local seq = colorSeq(rainbow(t, 6))
		local c = Color3.fromHSV((t * 0.22) % 1, 0.7, 1)
		for _, pe in a.flames do
			pe.Color = seq
		end
		for _, rb in a.ribbons do
			rb.trail.Color = seq
		end
		for _, x in a.extras do
			x.pe.Color = seq
		end
		if a.streaks then
			a.streaks.Color = seq
		end
		if a.shock then
			a.shock.Color = ColorSequence.new(c)
		end
		if a.glow then
			a.glow.Color = ColorSequence.new(c)
		end
		a.highlight.OutlineColor = c
		a.highlight.FillColor = c
		a.light.Color = c
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
			local ok, err = pcall(update, a, dt, t, camPos, reduced)
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
