-- KaijuAnimation.VFX: a creature's visual effects, all created once when it registers (never per frame):
--   neon accents pulse with the breath (brightest on the inhale, 25 percent brighter at night), eyes blink, rarity extras
--   (Uncommon sparkle, Rare soft light, Legendary ground aura and gold sparkle, Mythic aura, orbiting motes and a
--   close-up highlight, Secret rainbow), biome particles, and the one-shot effects actions trigger (dust, sparkle bursts,
--   neon flashes, Raijin's drum flashes, Prismling's facet shimmer).
-- Per frame it only writes colours, at Config.Performance.PulseHz, and moves a Mythic's few motes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local VFX = {}

local TAU, RAD = Util.TAU, Util.RAD
local sin, clamp, floor = math.sin, math.clamp, math.floor
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD84A")

local rarityColors = {}
do
	local ok, EggConfig = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EggConfig"))
	end)
	if ok and EggConfig.RarityById then
		for id, r in EggConfig.RarityById do
			rarityColors[id] = r.Color
		end
	end
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFB84D")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFF04D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4DFF88")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("4DB8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("C44DFF")),
})

local function ns(a, b)
	return NumberSequence.new(a, b)
end

local function emitter(rec, parent, props, rate, life)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = parent
	if rate then
		table.insert(rec.emitters, { pe = pe, rate = rate, life = life or 2 })
	end
	return pe
end

-- Biome particles: low rates, fading in and out.
local BIOME_PARTICLES = {
	Dust = function(c, s)
		return { Texture = SMOKE, Color = ColorSequence.new(c), Size = ns(0.5 * s, 1.3 * s), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }), Speed = NumberRange.new(0.2, 0.6), Acceleration = Vector3.new(0, 0.3, 0), Lifetime = NumberRange.new(1.6, 2.4), RotSpeed = NumberRange.new(-20, 20) }, 2
	end,
	Embers = function(c, s)
		return { Texture = SPARKS, Color = ColorSequence.new(c, Color3.fromHex("FF3B1F")), LightEmission = 1, Size = ns(0.22 * s, 0), Transparency = ns(0, 1), Speed = NumberRange.new(0.6, 1.6), Acceleration = Vector3.new(0, 2, 0), Lifetime = NumberRange.new(1.4, 2.4), SpreadAngle = Vector2.new(25, 25) }, 1.9
	end,
	Snow = function(c, s)
		return { Texture = SPARKLE, Color = ColorSequence.new(c), LightEmission = 0.4, Size = ns(0.18 * s, 0.08 * s), Transparency = ns(0.2, 1), Speed = NumberRange.new(0.1, 0.4), Acceleration = Vector3.new(0, -0.6, 0), Lifetime = NumberRange.new(2.5, 3.5), RotSpeed = NumberRange.new(-60, 60) }, 3
	end,
	Spores = function(c, s)
		return { Texture = SPARKLE, Color = ColorSequence.new(c, Color3.fromHex("F6FF7A")), LightEmission = 0.6, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.2 * s), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(0.1, 0.4), Acceleration = Vector3.new(0, 0.35, 0), Lifetime = NumberRange.new(2.5, 3.5), RotSpeed = NumberRange.new(-40, 40) }, 3
	end,
	Bubbles = function(c, s)
		return { Texture = SPARKLE, Color = ColorSequence.new(c, WHITE), LightEmission = 0.5, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05 * s), NumberSequenceKeypoint.new(1, 0.28 * s) }), Transparency = ns(0.3, 1), Speed = NumberRange.new(0.2, 0.5), Acceleration = Vector3.new(0, 1.3, 0), Lifetime = NumberRange.new(1.8, 2.6) }, 2.2
	end,
	Sparks = function(c, s)
		return { Texture = SPARKS, Color = ColorSequence.new(WHITE, c), LightEmission = 1, Size = ns(0.3 * s, 0), Transparency = ns(0, 1), Speed = NumberRange.new(2, 4), Lifetime = NumberRange.new(0.15, 0.35), SpreadAngle = Vector2.new(180, 180) }, 0.25
	end,
	Stars = function(c, s)
		return { Texture = SPARKLE, Color = ColorSequence.new(c, WHITE), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3 * s), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(0.05, 0.25), Lifetime = NumberRange.new(1.5, 2.5), RotSpeed = NumberRange.new(-90, 90) }, 2
	end,
	Glints = function(c, s)
		return { Texture = SPARKLE, Color = RAINBOW, LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.35 * s), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(0.1, 0.4), Lifetime = NumberRange.new(0.8, 1.4), RotSpeed = NumberRange.new(-120, 120) }, 1.1
	end,
}

local function weldTo(part, root)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
	part.Anchored = false
end

local function fxPart(name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	return p
end

-- Everything a creature needs, once. parent: a folder inside the model (the rig folder).
function VFX.Setup(rec, parent, eyeSets)
	rec.emitters = {}
	local model, root = rec.model, rec.root
	local s = math.sqrt(rec.scale)
	local size = rec.size
	local centre = rec.rootCF * rec.centreOffset

	-- particle holder: an invisible box round the body, welded to the root
	local holder = fxPart("_AnimFX", Vector3.new(math.max(size.X * 0.7, 0.5), math.max(size.Y * 0.6, 0.5), math.max(size.Z * 0.7, 0.5)), CFrame.new(centre))
	holder.Parent = parent
	weldTo(holder, root)
	rec.fxHolder = holder
	local ground = Instance.new("Attachment")
	ground.Name = "Ground"
	ground.Parent = holder
	rec.groundAtt = ground

	-- neon accents
	local neon, base, bright, hue, index = {}, {}, {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Parent ~= parent then
			table.insert(neon, d)
			table.insert(base, d.Color)
			local h, sat, v = d.Color:ToHSV()
			table.insert(bright, Color3.fromHSV(h, sat * 0.7, math.min(1, v * 1.25 + 0.15)))
			local lp = rec.rootCF:PointToObjectSpace(d.Position)
			table.insert(hue, ((math.atan2(lp.X, lp.Z) / TAU) + lp.Y * 0.08) % 1)
		end
	end
	rec.neon, rec.neonBase, rec.neonBright, rec.neonHue = neon, base, bright, hue
	rec.flashT = table.create(#neon, 0)
	rec.flashSets = {}
	rec.pulseAcc = 0
	rec.neonIndex = index
	for i, p in neon do
		index[p] = i
	end

	-- eyes
	rec.eyeSets = {}
	for _, parts in eyeSets do
		if #parts > 0 then
			table.insert(rec.eyeSets, { parts = parts, nextAt = rec.rng:NextNumber(1, 4), untilAt = 0, closed = false, double = false })
		end
	end

	-- rarity extras
	local R = Config.VFX.Rarity[rec.rarityId] or {}
	rec.pulseAmount = R.Pulse or rec.P.Pulse or Config.VFX.Pulse
	if rec.P.Pulse and R.Pulse then
		rec.pulseAmount = math.max(R.Pulse, rec.P.Pulse)
	end
	rec.rainbow = R.Rainbow
	local color = rarityColors[rec.rarityId] or WHITE
	if rec.guardian then
		color = Color3.fromHex(Config.VFX.GuardianAura[rec.biome or ""] or "FFFFFF")
	end
	rec.rarityColor = color
	if R.Sparkle then
		emitter(rec, holder, {
			Texture = SPARKLE, Color = ColorSequence.new(color, WHITE), LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3 * s), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(0.3, 0.9), Acceleration = Vector3.new(0, 1, 0), Lifetime = NumberRange.new(0.9, 1.4),
		}, R.Sparkle, 1.2)
	end
	if R.Gold then
		emitter(rec, holder, {
			Texture = SPARKLE, Color = ColorSequence.new(GOLD, WHITE), LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35 * s), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(0.2, 0.7), Acceleration = Vector3.new(0, 0.8, 0), Lifetime = NumberRange.new(1.2, 1.8), RotSpeed = NumberRange.new(-90, 90),
		}, R.Gold, 1.5)
	end
	if R.Light then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = R.Light.Range * s
		light.Brightness = R.Light.Brightness
		light.Shadows = false
		light.Parent = holder
		rec.light, rec.lightBase = light, R.Light.Brightness
	end
	if R.GroundAura then
		-- a ring of glowing motes rising round the creature's feet (a solid neon disc read as a rug, so there is none)
		local d = math.max(size.X, size.Z) * (R.AuraScale or 1.1)
		local ring = fxPart("_AnimAuraRing", Vector3.new(d * 0.9, 0.1, d * 0.9), rec.rootCF * CFrame.new(rec.centreOffset.X, rec.groundY + 0.1, rec.centreOffset.Z))
		ring.Parent = parent
		weldTo(ring, root)
		emitter(rec, ring, {
			Texture = SPARKLE, Color = ColorSequence.new(color, color:Lerp(WHITE, 0.5)), LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 0.7 * s), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = ns(0, 1), Speed = NumberRange.new(1.2 * s, 2.6 * s), Lifetime = NumberRange.new(0.8, 1.4),
		}, R.AuraRate or 10, 1.1)
	end
	if R.Motes then
		rec.motes, rec.moteCFs = {}, {}
		for i = 1, R.Motes do
			local m = fxPart("_AnimMote", Vector3.one * 0.22 * s, CFrame.new(centre))
			m.Shape = Enum.PartType.Ball
			m.Material = Enum.Material.Neon
			m.Color = color:Lerp(WHITE, 0.35)
			m.Transparency = 0.1
			m.Parent = parent
			rec.motes[i] = m
			rec.moteCFs[i] = m.CFrame
		end
		rec.moteRadius = math.max(size.X, size.Z) * 0.6
	end
	if R.Highlight then
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.85
		h.FillColor = color
		h.OutlineColor = color:Lerp(WHITE, 0.4)
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Adornee = model
		h.Parent = parent
		rec.highlight, rec.highlightRange = h, R.Highlight
	end

	-- biome particles
	local B = Config.VFX.Biome[rec.biome or ""]
	if B and BIOME_PARTICLES[B.Kind] then
		local props, life = BIOME_PARTICLES[B.Kind](Color3.fromHex(B.Color), s)
		rec.biomeEmitter = emitter(rec, holder, props, B.Rate, life)
		if B.FrostBreath then
			rec.frostBreath = true
		end
	end

	-- one-shot emitters for action events
	rec.dustEmitter = emitter(rec, ground, {
		Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("E8DCC4")), Size = ns(0.8 * s, 2.2 * s),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(2 * s, 4 * s), SpreadAngle = Vector2.new(80, 10), Drag = 4,
		Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, 1, 0), EmissionDirection = Enum.NormalId.Top,
	})
	rec.burstEmitter = emitter(rec, holder, {
		Texture = SPARKLE, Color = rec.rainbow and RAINBOW or ColorSequence.new(color, WHITE), LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = ns(0, 1), Speed = NumberRange.new(6 * s, 12 * s), SpreadAngle = Vector2.new(180, 180), Drag = 3,
		Lifetime = NumberRange.new(0.5, 1),
	})

	-- Raijin's drums and Prismling's facets, for their event effects
	if rec.halo then
		local drums = {}
		local haloModel = rec.haloGroup
		if haloModel then
			local c = rec.rootCF * (rec.halo.restW.Position)
			local axis = rec.halo.axis
			local ref = math.abs(axis.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
			local u = axis:Cross(ref).Unit
			local v = axis:Cross(u)
			for _, p in haloModel:GetChildren() do
				if p:IsA("BasePart") and (p.Name == "DrumHead" or p.Name == "Tomoe") then
					local d = rec.rootCF:VectorToObjectSpace(p.Position - c)
					table.insert(drums, { part = p, angle = math.atan2(d:Dot(v), d:Dot(u)) % TAU, color = p.Color, material = p.Material })
				end
			end
			table.sort(drums, function(a, b)
				return a.angle < b.angle
			end)
		end
		rec.drums = drums
	end
	if rec.spec.Shimmer then
		local want = {}
		for _, n in rec.spec.Shimmer do
			want[n] = true
		end
		local list, lo, hi = {}, math.huge, -math.huge
		for i, p in neon do
			if want[p.Name] then
				local z = rec.rootCF:PointToObjectSpace(p.Position).Z
				table.insert(list, { i = i, z = z })
				lo, hi = math.min(lo, z), math.max(hi, z)
			end
		end
		for _, e in list do
			e.u = hi > lo and (e.z - lo) / (hi - lo) or 0
		end
		rec.shimmerList = list
	end

	-- a guardian's sleep sign (Zzz over its head)
	if rec.guardian then
		rec.sleepSigns = {}
		for _, g in model:GetDescendants() do
			if g:IsA("BillboardGui") and (g.Name == "Sleep" or g.Name == "Alert") then
				g.Enabled = false
				if g.Name == "Sleep" then
					table.insert(rec.sleepSigns, g)
				end
			end
		end
	end
	VFX.SetTier(rec, 3, 1)
end

-- Emitter rates for a tier: Full 100 percent, Reduced 50 percent, Far and Off none. factor: the global particle budget.
function VFX.SetTier(rec, tier, factor)
	if not rec.emitters then
		return
	end
	local k = (tier == 0 and 1 or tier == 1 and 0.5 or 0) * factor
	for _, e in rec.emitters do
		if e.rate then
			e.pe.Rate = e.rate * k
			e.pe.Enabled = k > 0
		end
	end
	if rec.motes then
		for _, m in rec.motes do
			m.Transparency = tier <= 1 and 0.1 or 1
		end
	end
end

-- Particles this creature keeps alive at a given tier (rate x lifetime), for the budget.
function VFX.ParticleCost(rec, tier)
	if not rec.emitters or tier > 1 then
		return 0
	end
	local n = 0
	for _, e in rec.emitters do
		if e.rate then
			n += e.rate * e.life
		end
	end
	return tier == 0 and n or n * 0.5
end

-- Close-up highlight for Mythics.
function VFX.Near(rec, dist)
	if rec.highlight then
		rec.highlight.Enabled = dist < rec.highlightRange
	end
end

local function setEyes(set, closed)
	if set.closed ~= closed then
		set.closed = closed
		for _, p in set.parts do
			p.LocalTransparencyModifier = closed and 1 or 0
		end
	end
end

local function flashIndices(rec, names)
	local list = rec.flashSets[names]
	if not list then
		list = {}
		local want = {}
		for n in string.gmatch(names, "[^,]+") do
			want[n] = true
		end
		for i, p in rec.neon do
			if want[p.Name] then
				table.insert(list, i)
			end
		end
		rec.flashSets[names] = list
	end
	return list
end

-- Action events that are visual. Returns true when handled.
function VFX.Event(rec, kind, arg, amount)
	if kind == "Dust" then
		local j = arg and rec.J[arg]
		local foot = j and j.foot or Vector3.new(rec.centreOffset.X, 0, rec.centreOffset.Z)
		rec.groundAtt.WorldPosition = rec.rootCF * foot
		rec.dustEmitter:Emit(math.floor((amount or 1) * 14 + 0.5))
		return true
	elseif kind == "Biome" then
		-- a burst of the creature's own biome particles (bubbles, spores, embers...)
		if rec.biomeEmitter then
			rec.biomeEmitter:Emit(math.floor((tonumber(arg) or 1) * 12 + 0.5))
		end
		return true
	elseif kind == "Breath" then
		-- a puff of breath (frost, a snort) in front of the first head
		local h = rec.heads[1]
		if h then
			rec.groundAtt.WorldPosition = rec.rootCF * (h.restPos + Vector3.new(0, 0, -0.5 * rec.scale))
			rec.dustEmitter:Emit(math.floor((tonumber(arg) or 1) * 8 + 0.5))
		end
		return true
	elseif kind == "Burst" then
		rec.burstEmitter:Emit(30)
		return true
	elseif kind == "Flash" then
		for _, i in flashIndices(rec, arg) do
			rec.flashT[i] = 0.4
		end
		rec.pulseAcc = 1e9
		return true
	elseif kind == "DrumFlash" then
		rec.drumAt, rec.drumLen = rec.t, (arg or 1.2) * rec.tempo
		return true
	elseif kind == "Shimmer" then
		rec.shimmerAt, rec.shimmerLen = rec.t, (arg or 0.9) * rec.tempo
		return true
	end
	return false
end

local function updateBlinks(rec, now)
	local B = Config.VFX.Blink
	local shut = rec.sleep > 0.6 or rec.doze > 0.6
	for _, set in rec.eyeSets do
		if shut then
			setEyes(set, true)
		elseif set.closed then
			if now >= set.untilAt then
				setEyes(set, false)
				if set.double then
					set.double = false
					set.nextAt = now + 0.12
				else
					set.nextAt = now + Util.range(rec.rng, B.Every) / rec.fidget
				end
			end
		elseif now >= set.nextAt then
			setEyes(set, true)
			set.untilAt = now + B.Length
			if not set.double and rec.rng:NextNumber() < B.Double then
				set.double = true
			end
		end
	end
end

-- Per update: blinks every update, colours at the tier's pulse rate. now: controller time (seconds).
function VFX.Update(rec, dt, lod, now)
	if lod == 0 then
		updateBlinks(rec, now)
	end
	if rec.motes and lod <= 1 then
		local c = rec.rootCF * rec.centreOffset
		local r = rec.moteRadius
		for i, m in rec.motes do
			local a = rec.t * 0.9 + i * TAU / #rec.motes
			rec.moteCFs[i] = CFrame.new(c + Vector3.new(math.cos(a) * r, sin(a * 1.7 + i) * 0.3 * rec.scale, sin(a) * r))
		end
		workspace:BulkMoveTo(rec.motes, rec.moteCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local hz = Config.Performance.PulseHz[lod + 1]
	if not hz then
		return
	end
	for i, f in rec.flashT do
		if f > 0 then
			rec.flashT[i] = math.max(0, f - dt)
		end
	end
	rec.pulseAcc += dt
	if rec.pulseAcc < 1 / hz then
		return
	end
	rec.pulseAcc = 0
	local wave = rec.pulseHz and (0.5 + 0.5 * sin(TAU * rec.pulseHz * rec.t + rec.seed)) or rec.breath
	local k = clamp((rec.pulseAmount * wave + rec.glow * 0.8) * rec.glowMul, 0, 1)
	local neon, base, bright, flashT = rec.neon, rec.neonBase, rec.neonBright, rec.flashT
	local shimmer = rec.shimmerAt and (rec.t - rec.shimmerAt) / rec.shimmerLen or nil
	if shimmer and shimmer > 1.3 then
		rec.shimmerAt, shimmer = nil, nil
	end
	local rainbow = rec.rainbow
	local hues = rec.neonHue
	for i, p in neon do
		local kk = k
		local f = flashT[i]
		if f > 0 then
			kk = math.max(kk, f / 0.4)
		end
		local c
		if rainbow then
			c = Color3.fromHSV((hues[i] + now * rainbow) % 1, 0.55, 1):Lerp(WHITE, kk * 0.35)
		else
			c = base[i]:Lerp(bright[i], kk)
		end
		if f > 0 then
			c = c:Lerp(WHITE, f / 0.4 * 0.6)
		end
		p.Color = c
	end
	if shimmer and rec.shimmerList then
		for _, e in rec.shimmerList do
			local d = (shimmer * 1.3 - 0.15) - e.u
			local band = d > -0.15 and d < 0.15 and (1 - math.abs(d) / 0.15) or 0
			if band > 0 then
				neon[e.i].Color = neon[e.i].Color:Lerp(WHITE, band)
			end
		end
	end
	-- Raijin's drums light up one after another round the halo
	if rec.drumAt and rec.drums then
		local pr = (rec.t - rec.drumAt) / rec.drumLen
		local n = #rec.drums
		for i, d in rec.drums do
			local lit = pr < 1 and math.abs(pr * n - (i - 0.5)) < 1.2
			if lit then
				d.part.Material = Enum.Material.Neon
				d.part.Color = GOLD
			else
				d.part.Material = d.material
				d.part.Color = d.color
			end
		end
		if pr >= 1 then
			rec.drumAt = nil
		end
	end
	if rec.light then
		rec.light.Brightness = rec.lightBase * (0.75 + 0.5 * wave) * rec.glowMul
	end
	if rec.aura then
		rec.aura.Transparency = clamp(rec.auraBase - 0.08 * wave * rec.glowMul - 0.1 * rec.glow, 0, 1)
	end
	-- frost breath on the exhale
	if rec.frostBreath and lod == 0 and rec.breath < 0.15 and not rec.breathPuffed and rec.heads[1] then
		rec.breathPuffed = true
		local h = rec.heads[1]
		rec.groundAtt.WorldPosition = rec.rootCF * (h.restPos + Vector3.new(0, 0, -0.4 * rec.scale))
		rec.dustEmitter:Emit(2)
	elseif rec.breath > 0.5 then
		rec.breathPuffed = false
	end
end

return VFX
