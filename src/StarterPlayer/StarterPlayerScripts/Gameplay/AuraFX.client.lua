-- Player auras, client-only and cosmetic, in the Sung Jin-Woo / Shadow Monarch style. Every player wearing a trail
-- (attribute EquippedTrail, set by TrailService) gets the matching aura from Shared.Config.AuraConfig: dark smoky
-- flames behind the body rimmed with glowing flames in the trail's colour. It idles quietly while they move and powers
-- up when they stand still ("aura farming"), with a burst when it reaches full power. Layers by tier:
--   1+  glowing flames off every body part, drawn just behind the body (ZOffset) so the silhouette glows
--   2+  shadow flames (very dark, bigger, further back), energy lines rising from the feet, glowing eyes
--   3+  glowing outline (Highlight, on you and the nearest few players), electric crackle round the body, a spiral
--       swirling on the ground and dark smoke pooling at the feet
--   4+  crescents spinning round the body
--   5+  shockwave rings while farming
--   plus energy ribbons spiralling round the body (style.Ribbons), a coloured light, and per-trail extras: dust,
--   leaves, snow + mist, void motes pulled into the body, lightning flipbook, embers, sparkles.
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
local TEX = AuraConfig.Textures
local BUILTIN = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

-- Body parts that give off flames (R15 names, then R6). Shadow flames only come off the bigger ones.
local BODY_PARTS = {
	"UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local SHADOW_PARTS = {
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
				Size = numSeq({ { 0, 0.6 * s }, { 1, 2 * s } }),
				Transparency = numSeq({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }),
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
				Texture = BUILTIN.Square,
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
				Texture = BUILTIN.Square,
				Color = ColorSequence.new(WHITE, Color3.fromHex("BFE8FF")),
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
				Texture = BUILTIN.Smoke,
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
				Texture = BUILTIN.Square,
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
				Texture = TEX.Lightning,
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Color = ColorSequence.new(WHITE, Color3.fromHex("FFE24A")),
				LightEmission = 1,
				Size = numSeq({ { 0, 1.7 * s }, { 1, 2.3 * s } }),
				Lifetime = NumberRange.new(0.25, 0.35),
				Speed = NumberRange.new(0, 0),
				Rotation = NumberRange.new(0, 360),
				LockedToPart = true,
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			}), 2, 12 },
		}
	end,
	Embers = function(a, s)
		return {
			{ emitter(a.base, {
				Texture = BUILTIN.Sparks,
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
				Texture = BUILTIN.Sparkle,
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
	local tier = style.Tier
	local s = hrp.Size.Y / 2
	local feet = -(hrp.Size.Y / 2 + (hum.RigType == Enum.HumanoidRigType.R15 and hum.HipHeight or 2))
	local top = 2.6 * s -- just above the head
	local glow = style.Glow
	local light = glow:Lerp(WHITE, 0.55)
	local dark = glow:Lerp(BLACK, 0.8)
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
		shadows = {},
		eyes = {},
		extras = {},
		ribbons = {},
		farm = 0,
		still = 0,
		powered = false,
		flash = 0,
		nextPulse = 0,
		nextColor = 0,
	}
	local function own(inst)
		table.insert(a.instances, inst)
		return inst
	end
	local function attachment(parent, name, pos)
		local att = own(Instance.new("Attachment"))
		att.Name = name
		att.Position = pos or Vector3.zero
		att.Parent = parent
		return att
	end

	a.shell = own(anchoredPart("AuraShell", Vector3.new(3.2 * s, top - feet, 3.2 * s)))
	a.base = own(anchoredPart("AuraBase", Vector3.new(4.6 * s, 0.1, 4.6 * s)))
	local centre = attachment(a.shell, "AuraCentre")
	local ground = attachment(a.base, "AuraGround")

	-- glowing flames off every body part; dark shadow flames bigger and further back behind them
	local size = style.FlameSize * s
	for _, name in BODY_PARTS do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(a.flames, own(emitter(part, {
				Name = "AuraFlame",
				Texture = style.Smoke and BUILTIN.Smoke or TEX.Flame,
				Color = colorSeq(style.Colors),
				LightEmission = style.LightEmission,
				Size = numSeq({ { 0, 0.2 * size }, { 0.25, 1.1 * size }, { 1, 0.3 * size } }),
				Transparency = numSeq({ { 0, 0.35 }, { 0.3, 0.05 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.35, 0.6),
				Speed = NumberRange.new(1.5, 3),
				SpreadAngle = Vector2.new(20, 20),
				Acceleration = Vector3.new(0, 8 * s, 0),
				Drag = 1.2,
				Rotation = NumberRange.new(-30, 30),
				RotSpeed = NumberRange.new(-60, 60),
				ZOffset = -1,
				EmissionDirection = Enum.NormalId.Top,
			})))
			if tier >= 2 and SHADOW_PARTS[name] then
				table.insert(a.shadows, own(emitter(part, {
					Name = "AuraShadow",
					Texture = TEX.Wisp,
					Color = ColorSequence.new(dark, BLACK),
					LightEmission = 0,
					Size = numSeq({ { 0, 0.3 * size }, { 0.3, 1.7 * size }, { 1, 0.8 * size } }),
					Transparency = numSeq({ { 0, 0.5 }, { 0.3, 0.12 }, { 1, 1 } }),
					Lifetime = NumberRange.new(0.5, 0.9),
					Speed = NumberRange.new(1, 2.5),
					SpreadAngle = Vector2.new(25, 25),
					Acceleration = Vector3.new(0, 6 * s, 0),
					Drag = 1,
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-40, 40),
					ZOffset = -1.6,
					EmissionDirection = Enum.NormalId.Top,
				})))
			end
		end
	end

	-- energy lines rising from the feet
	if tier >= 2 then
		a.streaks = own(emitter(a.base, {
			Texture = TEX.Streak,
			Color = ColorSequence.new(light, glow),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = numSeq({ { 0, 0.6 * s }, { 0.5, 1.6 * s }, { 1, 0.4 * s } }),
			Transparency = numSeq({ { 0, 0.15 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.4, 0.65),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(3, 3),
			EmissionDirection = Enum.NormalId.Top,
		}))
	end

	-- glowing eyes
	local head = char:FindFirstChild("Head")
	if tier >= 2 and head and head:IsA("BasePart") then
		for _, side in { -1, 1 } do
			local eye = attachment(head, "AuraEye", Vector3.new(side * 0.21 * s, 0.1 * s, -head.Size.Z / 2))
			table.insert(a.eyes, own(emitter(eye, {
				Texture = TEX.Flare,
				Color = ColorSequence.new(light),
				LightEmission = 1,
				Size = numSeq({ { 0, 0.6 * s }, { 1, 0.35 * s } }),
				Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.12, 0.18),
				Speed = NumberRange.new(0, 0),
				Rotation = NumberRange.new(0, 360),
				LockedToPart = true,
				ZOffset = 0.4,
			})))
		end
	end

	if tier >= 3 then
		-- electric crackle round the body
		a.crackle = own(emitter(a.shell, {
			Texture = TEX.Crackle,
			Color = ColorSequence.new(light, glow),
			LightEmission = 1,
			Size = numSeq({ { 0, 0.9 * s }, { 1, 1.4 * s } }),
			Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.12, 0.2),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			LockedToPart = true,
			ZOffset = 0.5,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		}))
		-- spiral swirling on the ground + dark smoke pooling at the feet
		a.swirl = own(emitter(ground, {
			Texture = TEX.Swirl,
			Color = ColorSequence.new(glow),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = numSeq({ { 0, 4 * s }, { 1, 6 * s } }),
			Transparency = numSeq({ { 0, 1 }, { 0.25, 0.45 }, { 1, 1 } }),
			Lifetime = NumberRange.new(1, 1.4),
			Speed = NumberRange.new(0.01, 0.01),
			SpreadAngle = Vector2.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(80, 140),
			EmissionDirection = Enum.NormalId.Top,
			LockedToPart = true,
		}))
		a.smokePool = own(emitter(a.base, {
			Texture = TEX.Smoke,
			Color = ColorSequence.new(dark, BLACK),
			LightEmission = 0,
			Size = numSeq({ { 0, 1.5 * s }, { 1, 3.2 * s } }),
			Transparency = numSeq({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(70, 70),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			EmissionDirection = Enum.NormalId.Top,
		}))
	end

	-- crescents spinning round the body
	if tier >= 4 then
		a.crescents = own(emitter(centre, {
			Texture = TEX.Crescent,
			Color = ColorSequence.new(light, glow),
			LightEmission = 1,
			Size = numSeq({ { 0, 3.2 * s }, { 1, 4.2 * s } }),
			Transparency = numSeq({ { 0, 1 }, { 0.2, 0.35 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.35, 0.5),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-420, 420),
			LockedToPart = true,
			ZOffset = -0.5,
		}))
	end

	-- shockwave rings on the ground (a pulse while farming, and the power-up burst)
	if tier >= 3 then
		a.shock = own(emitter(ground, {
			Texture = TEX.Ring,
			Color = ColorSequence.new(light, glow),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = numSeq({ { 0, 1 * s }, { 1, 9 * s } }),
			Transparency = numSeq({ { 0, 0.05 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.7, 0.7),
			Speed = NumberRange.new(0.01, 0.01),
			SpreadAngle = Vector2.new(0, 0),
			Rotation = NumberRange.new(0, 360),
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

	-- ribbons spiralling round the body
	local count = math.max(style.Ribbons, style.RibbonsMoving)
	for i = 1, count do
		local a0 = attachment(hrp, "AuraRibbon")
		local a1 = attachment(hrp, "AuraRibbon")
		local tr = own(Instance.new("Trail"))
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(light, glow)
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

	-- glowing outline (the budget pass decides who actually shows one) + light
	a.highlight = own(Instance.new("Highlight"))
	a.highlight.Adornee = char
	a.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	a.highlight.FillColor = glow
	a.highlight.OutlineColor = light
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
	for _, pe in a.shadows do
		pe:Emit(math.ceil(3 * mult))
	end
	if a.shock then
		a.shock:Emit(2)
	end
	if a.streaks then
		a.streaks:Emit(math.ceil(30 * mult))
	end
	if a.crackle then
		a.crackle:Emit(math.ceil(6 * mult))
	end
	a.flash = 1
end

local function setColors(a, glow)
	local light = glow:Lerp(WHITE, 0.55)
	local dark = glow:Lerp(BLACK, 0.8)
	local pair = ColorSequence.new(light, glow)
	for _, pe in a.shadows do
		pe.Color = ColorSequence.new(dark, BLACK)
	end
	for _, pe in a.eyes do
		pe.Color = ColorSequence.new(light)
	end
	for _, pe in { a.streaks, a.crackle, a.crescents, a.shock } do
		pe.Color = pair
	end
	if a.swirl then
		a.swirl.Color = ColorSequence.new(glow)
	end
	if a.smokePool then
		a.smokePool.Color = ColorSequence.new(dark, BLACK)
	end
	for _, rb in a.ribbons do
		rb.trail.Color = pair
	end
	a.highlight.OutlineColor = light
	a.highlight.FillColor = glow
	a.light.Color = glow
end

local function update(a, dt, t, camPos, reduced)
	local hrp = a.hrp
	local pos = hrp.Position
	local style = a.style
	local tier = style.Tier
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

	-- particle rates
	local flameRate = lerp(style.Flames[1], style.Flames[2], f) * mult / math.max(1, #a.flames)
	for _, pe in a.flames do
		pe.Rate = flameRate
	end
	local shadowRate = lerp(style.Shadow[1], style.Shadow[2], f) * mult / math.max(1, #a.shadows)
	for _, pe in a.shadows do
		pe.Rate = shadowRate
	end
	local eyeRate = (f > 0.5 or tier >= 6) and 18 * (near and 1 or 0) or 0
	for _, pe in a.eyes do
		pe.Rate = eyeRate
	end
	if a.streaks then
		a.streaks.Rate = f * (10 + tier * 4) * mult
	end
	if a.crackle then
		a.crackle.Rate = (f * (5 + tier) + (tier >= 5 and 2 or 0)) * mult
	end
	if a.swirl then
		a.swirl.Rate = f * 1.6 * mult
	end
	if a.smokePool then
		a.smokePool.Rate = f * 4 * mult
	end
	if a.crescents then
		a.crescents.Rate = f * 3.5 * mult
	end
	for _, x in a.extras do
		x.pe.Rate = lerp(x.moving, x.farming, f) * mult
	end
	if a.shock and tier >= 5 and near and f > 0.9 and t >= a.nextPulse then
		a.nextPulse = t + 1.15
		a.shock:Emit(1)
	end
	a.light.Brightness = near and (lerp(0.25, 1.4 + tier * 0.15, f) + a.flash * 3) or 0
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
	a.wantOutline = near and (tier >= 3 or (tier == 2 and f > 0.05))
	if a.highlight.Enabled then
		a.highlight.OutlineTransparency = math.clamp(lerp(0.6, 0, f) + 0.08 * math.sin(t * 7), 0, 1)
		a.highlight.FillTransparency = lerp(1, 0.82, f)
	end

	-- rainbow: every colour turns round the colour wheel
	if style.Rainbow and near and t >= a.nextColor then
		a.nextColor = t + 0.06
		local seq = colorSeq(rainbow(t, 6))
		for _, pe in a.flames do
			pe.Color = seq
		end
		for _, x in a.extras do
			x.pe.Color = seq
		end
		setColors(a, Color3.fromHSV((t * 0.22) % 1, 0.7, 1))
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
