-- GameVFX: extra visuals, client-only and purely cosmetic (reads replicated attributes + Remotes.GameEvent, never
-- changes game state). Tuning lives in ReplicatedStorage.Shared.Config.VFXConfig. Respects the Reduced Effects and
-- Camera Shake settings (Gameplay.Settings).
--   auras     Epic+ kaiju (pens and market keepers): no ground layers, no orbits; Legendary+ rising
--             light rays and a halo; Mythic pink flame wisps; Secret rainbow colours + star bursts. Layered on top of
--             KaijuModel's own sparkles, attached to parts KaijuFX already animates so they move with the kaiju.
--   hatches   every hatch: cartoon smoke poof; Rare+: sparkle fountain; Legendary+: fireworks overhead
--             (KaijuFX still does the shell burst, flash and grand light pillar)
--   purchases coins spray off the player; trails: colour swirl (buy) / ring burst (equip); pen upgrade: golden
--             shockwave + confetti across the pen
--   weather   Pebble Plains pollen + leaves, Lava Lagoon embers + ash, Frostfang Peaks snow, Venom Jungle spores, Sunken
--             Abyss bubbles, Storm Spires rain, Cosmic Rift stardust; lighting mood per biome
--   guardians roar: sonic rings from the mouth, ground shockwave, dust, flying rocks, camera shake nearby;
--             glowing eyes while awake; dust puff (sparks in lava, snow in frost) on every stomp (on KaijuFX's footfall
--             markers StepAt / StepPos once they arrive, else on a timer)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local VFX = require(Config:WaitForChild("VFXConfig"))
local EggConfig = require(Config:WaitForChild("EggConfig"))
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local KaijuConfig = require(Config:WaitForChild("KaijuConfig"))
local TrailConfig = require(Config:WaitForChild("TrailConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local gameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent")

local player = Players.LocalPlayer
local rng = Random.new()
local T = VFX.Textures
local WHITE = Color3.new(1, 1, 1)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GameVFXLocal"
fxFolder.Parent = workspace

---------------------------------------------------------------- helpers
local function reduced()
	return Settings.Get("ReducedEffects") == true
end
local function count(n)
	return reduced() and math.max(1, math.ceil(n * VFX.ReducedScale)) or n
end
local function serverNow()
	return workspace:GetServerTimeNow()
end
local function seq(...)
	local pts = { ... }
	if #pts == 2 and type(pts[1]) == "number" then
		return NumberSequence.new(pts[1], pts[2])
	end
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end
local function colors(a, b)
	return ColorSequence.new(a, b or a)
end
-- a colour that only lightens a little over a particle's life (fading all the way to white washes out on bright maps)
local function tintSeq(c)
	return ColorSequence.new(c, c:Lerp(Color3.new(1, 1, 1), 0.3))
end

local function holderPart(cf, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.one
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 1
	pe.LightInfluence = 0
	for k, v in props do
		pe[k] = v
	end
	if props.Rate and reduced() then
		pe.Rate = props.Rate * VFX.ReducedScale
	end
	pe.Parent = parent
	return pe
end

-- one-shot burst at a CFrame (emission direction = the CFrame's Top unless props say otherwise)
local function burst(cf, n, props, life)
	local holder = holderPart(cf, props.HolderSize)
	props.HolderSize = nil
	props.Rate = 0
	local pe = emitter(holder, props)
	pe:Emit(count(n))
	Debris:AddItem(holder, life or 3)
	return pe
end

-- flat ring lying on the ground that grows from r0 to r1 (studs, diameter)
local function groundRing(pos, color, r0, r1, life, transparency)
	burst(CFrame.new(pos + Vector3.new(0, 0.2, 0)), 1, {
		Texture = T.Ring,
		Color = colors(color),
		LightEmission = 0.3,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Size = seq(0, r0, 1, math.min(r1, 100)),
		Transparency = seq(0, transparency or 0.15, 1, 1),
		Lifetime = NumberRange.new(life or 0.6),
		ZOffset = 1,
	}, (life or 0.6) + 0.5)
end

local function pointFlash(pos, color, range, brightness, seconds)
	local holder = holderPart(CFrame.new(pos))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(seconds or 0.8, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(holder, (seconds or 0.8) + 0.2)
end

local function rarityInfo(id)
	return EggConfig.RarityById[id or ""]
end
local function rarityColor(id)
	local r = rarityInfo(id)
	return r and r.Color or WHITE
end
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFB84D")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFF04D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4DFF88")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("4DB8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("C44DFF")),
})

local function bottomOf(model)
	local cf, size = model:GetBoundingBox()
	return Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z), size
end

---------------------------------------------------------------- camera shake (applied after the camera scripts, undone before
-- they run next frame, like KaijuFX's; the two stack cleanly)
local shakeAmp, shakeOffset = 0, CFrame.identity
local function addShake(amount, at)
	if not Settings.Get("CameraShake") then
		return
	end
	local d = (workspace.CurrentCamera.CFrame.Position - at).Magnitude
	amount *= math.clamp(1 - d / VFX.Guardian.ShakeRange, 0, 1)
	shakeAmp = math.max(shakeAmp, amount)
end
RunService:BindToRenderStep("GameVFXShakeUndo", Enum.RenderPriority.Camera.Value - 2, function()
	if shakeOffset ~= CFrame.identity then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * shakeOffset:Inverse()
		shakeOffset = CFrame.identity
	end
end)
RunService:BindToRenderStep("GameVFXShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if shakeAmp < 0.003 then
		shakeAmp = 0
		return
	end
	local n = os.clock() * 26
	local a = shakeAmp
	shakeOffset = CFrame.new(math.noise(n, 7.7) * a * 0.8, math.noise(n, 8.3) * a * 0.8, 0)
		* CFrame.Angles(math.noise(n, 9.1) * a * 0.05, math.noise(n, 10.9) * a * 0.05, math.noise(n, 11.3) * a * 0.04)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * shakeOffset
	shakeAmp *= math.exp(-4.5 * dt)
end)

---------------------------------------------------------------- rare kaiju auras
local auras = {} -- [model] = entry
local TWO_PI = math.pi * 2

local function speciesRarity(model)
	local r = model:GetAttribute("Rarity")
	if r then
		return r
	end
	local cfg = KaijuConfig[model:GetAttribute("Species") or ""]
	return cfg and cfg.Rarity
end

local function removeAura(model)
	local e = auras[model]
	if not e then
		return
	end
	auras[model] = nil
	for _, inst in e.instances do
		inst:Destroy()
	end
end

local function addAura(model)
	if auras[model] or not model:IsA("Model") then
		return
	end
	local rarityId = speciesRarity(model)
	local info = rarityInfo(rarityId)
	local tier = VFX.Aura.Tiers[rarityId or ""]
	if not (info and tier and info.Order >= VFX.Aura.MinOrder) then
		return
	end
	local host = model:FindFirstChild("Aura") or model.PrimaryPart or model:FindFirstChild("Root")
	if not (host and host:IsA("BasePart")) then
		return
	end
	local _, ext = model:GetBoundingBox()
	local radius = math.max(ext.X, ext.Z) * 0.55 + 0.5
	local height = ext.Y
	-- host-local Y of the ground and the top of the body (host may be the Aura box or the Root part)
	local groundY = (model:GetBoundingBox().Position.Y - ext.Y / 2) - host.Position.Y
	local color = info.Color
	local colorSeq = tier.Rainbow and RAINBOW or tintSeq(color)
	local e = { model = model, host = host, tier = tier, radius = radius, groundY = groundY, height = height, instances = {}, emitters = {}, orbits = {}, enabled = true }
	local function track(inst)
		table.insert(e.instances, inst)
		return inst
	end
	local function att(name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos
		a.Parent = host
		return track(a)
	end
	local function em(parent, props)
		local pe = emitter(parent, props)
		pe.Name = "GameVFXAura"
		table.insert(e.emitters, pe)
		if parent == host then
			track(pe)
		end
		return pe
	end

	local ground = att("AuraGround", Vector3.new(0, groundY + 0.5, 0))
	-- (no ground glow disc / rings under kaiju: tier.Rings is ignored)
	if tier.Rays then
		-- light rays rising out of the body (box emission needs a part, so this sits on the host)
		em(host, {
			Texture = T.Sparkle,
			Color = colorSeq,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(3, 6),
			LightEmission = 0.6,
			Squash = NumberSequence.new(2.4),
			Size = seq(0, 0, 0.2, 0.45 + radius * 0.08, 1, 0),
			Transparency = seq(0, 0.1, 1, 1),
			Lifetime = NumberRange.new(1.2, 1.8),
			Rate = 7,
		})
	end
	if tier.Halo then
		local halo = att("AuraHalo", Vector3.new(0, groundY + height + 0.8, 0))
		em(halo, {
			Texture = T.Ring,
			Color = colorSeq,
			LightEmission = 0.5,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01),
			LockedToPart = true,
			Size = NumberSequence.new(math.clamp(radius * 0.7, 1.2, 5)),
			Transparency = seq(0, 1, 0.25, 0.15, 0.75, 0.15, 1, 1),
			RotSpeed = NumberRange.new(60),
			Lifetime = NumberRange.new(1.2),
			Rate = 1.6,
		})
		em(halo, {
			Texture = T.Sparkle,
			Color = colorSeq,
			Speed = NumberRange.new(0.5, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			Size = seq(0, 0.5, 1, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 5,
		})
	end
	if tier.Flames then
		em(host, {
			Texture = T.Fire,
			Color = ColorSequence.new(tier.Flames, Color3.fromHex("8A3BFF")),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(1.5, 3),
			Acceleration = Vector3.new(0, 3, 0),
			Size = seq(0, 0.4 + radius * 0.12, 1, 0),
			Transparency = seq(0, 0.45, 1, 1),
			RotSpeed = NumberRange.new(-60, 60),
			Rotation = NumberRange.new(0, 360),
			Lifetime = NumberRange.new(0.6, 1.1),
			Rate = 14,
		})
	end

	-- (no orbiting light trails around kaiju: tier.Orbits is ignored)

	if tier.Rainbow then
		e.rainbow = true
	end
	if tier.StarBurstEvery then
		e.nextStar = os.clock() + rng:NextNumber(0, tier.StarBurstEvery)
	end
	auras[model] = e
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			removeAura(model)
		end
	end)
end

local function watchKaijuFolder(folder)
	local function onAdded(m)
		if not m:IsA("Model") or m:GetAttribute("NoAura") then -- NoAura: e.g. the market's golden Rumblerex NPC
			return
		end
		-- wait for the model to finish arriving (KaijuModel stamps PartCount)
		task.spawn(function()
			local want = m:GetAttribute("PartCount")
			local t0 = os.clock()
			while want and m.Parent and os.clock() - t0 < 10 do
				local n = 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						n += 1
					end
				end
				if n >= want then
					break
				end
				task.wait(0.1)
			end
			task.wait(0.2) -- let KaijuFX build its rig first (pose uses the model's resting layout)
			if m.Parent then
				addAura(m)
			end
		end)
	end
	folder.ChildAdded:Connect(onAdded)
	for _, m in folder:GetChildren() do
		onAdded(m)
	end
end

local function stepAuras(t)
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, e in auras do
		if not e.host.Parent then
			continue
		end
		local near = (e.host.Position - camPos).Magnitude < VFX.Aura.Range
		if near ~= e.enabled then
			e.enabled = near
			for _, pe in e.emitters do
				pe.Enabled = near
			end
			for _, o in e.orbits do
				o.trail.Enabled = near
			end
		end
		if not near then
			continue
		end
		local speed = e.tier.OrbitSpeed or 1.6
		for _, o in e.orbits do
			local a = t * speed + o.phase
			local y = e.groundY + e.height * (0.45 + 0.25 * math.sin(t * 1.3 + o.phase)) + math.cos(a) * o.tilt * e.radius
			local p = Vector3.new(math.cos(a) * e.radius, y, math.sin(a) * e.radius)
			o.a0.Position = p
			o.a1.Position = p + Vector3.new(0, 0.35 + e.radius * 0.07, 0)
		end
		if e.rainbow then
			local c = Color3.fromHSV((t * 0.3) % 1, 0.75, 1)
			local cs = tintSeq(c)
			for _, pe in e.emitters do
				pe.Color = cs
			end
			for _, o in e.orbits do
				o.trail.Color = cs
			end
		end
		if e.nextStar and t >= e.nextStar then
			e.nextStar = t + e.tier.StarBurstEvery
			local top = e.host.CFrame * Vector3.new(0, e.groundY + e.height * 0.6, 0)
			burst(CFrame.new(top), 16, {
				Texture = T.Sparkle,
				Color = RAINBOW,
				Speed = NumberRange.new(6, 12),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 3,
				Size = seq(0, 0.9, 1, 0),
				Lifetime = NumberRange.new(0.6, 1),
			}, 2)
		end
	end
end

---------------------------------------------------------------- hatches (everyone nearby sees them)
local function poof(pos, scale)
	burst(CFrame.new(pos + Vector3.new(0, 0.8 * scale, 0)), 18, {
		Texture = T.Smoke,
		Color = colors(Color3.fromHex("FFFFFF")),
		LightEmission = 0.25,
		LightInfluence = 0.6,
		Speed = NumberRange.new(6 * scale, 11 * scale),
		SpreadAngle = Vector2.new(180, 25),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 5,
		Size = seq(0, 1.6 * scale, 1, 4 * scale),
		Transparency = seq(0, 0.15, 1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Lifetime = NumberRange.new(0.6, 0.9),
	}, 1.5)
end

local function fountain(pos, color, scale)
	local holder = holderPart(CFrame.new(pos + Vector3.new(0, 0.5, 0)))
	local pe = emitter(holder, {
		Texture = T.Sparkle,
		Color = tintSeq(color),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(20 * math.sqrt(scale), 30 * math.sqrt(scale)),
		SpreadAngle = Vector2.new(16, 16),
		Acceleration = Vector3.new(0, -34, 0),
		Drag = 0.6,
		Size = seq(0, 0.7 * math.sqrt(scale), 1, 0),
		Lifetime = NumberRange.new(1.2, 1.7),
		Rate = 70,
	})
	task.delay(0.9, function()
		pe.Enabled = false
	end)
	Debris:AddItem(holder, 3)
end

local function firework(pos, colorSeq)
	-- rising spark, then the burst
	local start = pos - Vector3.new(0, 14, 0)
	local rocket = holderPart(CFrame.new(start))
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.25, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.25, 0)
	a1.Parent = rocket
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = colorSeq
	trail.LightEmission = 0.7
	trail.FaceCamera = true
	trail.Lifetime = 0.35
	trail.Transparency = seq(0, 0, 1, 1)
	trail.Parent = rocket
	local rise = TweenService:Create(rocket, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos) })
	rise:Play()
	rise.Completed:Once(function()
		burst(CFrame.new(pos), 60, {
			Texture = T.Sparkle,
			Color = colorSeq,
			LightEmission = 0.35,
			Speed = NumberRange.new(14, 20),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -7, 0),
			Drag = 2.2,
			Size = seq(0, 1.1, 0.7, 0.6, 1, 0),
			Lifetime = NumberRange.new(1, 1.6),
		}, 2.5)
		burst(CFrame.new(pos), 24, {
			Texture = T.Sparks,
			Color = colorSeq,
			Speed = NumberRange.new(6, 12),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -16, 0),
			Size = seq(0, 0.5, 1, 0),
			Lifetime = NumberRange.new(1.2, 2),
		}, 3)
		pointFlash(pos, colorSeq.Keypoints[1].Value, 40, 4, 0.9)
		Debris:AddItem(rocket, 0.5)
	end)
end

local function onHatched(model)
	local pos, size = bottomOf(model)
	local rarityId = model:GetAttribute("Rarity") or speciesRarity(model) or "Common"
	local info = rarityInfo(rarityId)
	local order = info and info.Order or 1
	local color = rarityColor(rarityId)
	local scale = math.clamp(math.max(size.X, size.Z) / 5, 0.8, 3)
	if VFX.Hatch.Poof then
		poof(pos, scale)
	end
	if order >= VFX.Hatch.FountainMinOrder then
		task.delay(0.15, fountain, pos, color, scale)
	end
	if order >= VFX.Hatch.FireworksMinOrder then
		local n = count(VFX.Hatch.Fireworks[rarityId] or 3)
		local cs = rarityId == "Secret" and RAINBOW or colors(color)
		for i = 1, n do
			local at = pos + Vector3.new(rng:NextNumber(-10, 10), size.Y + rng:NextNumber(18, 30), rng:NextNumber(-10, 10))
			task.delay(0.5 + (i - 1) * 0.35, firework, at, cs)
		end
	end
end

---------------------------------------------------------------- purchases
local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function coinSpray(n)
	local root = hrp()
	if not root or n <= 0 then
		return
	end
	burst(CFrame.new(root.Position + Vector3.new(0, 1, 0)), n, {
		Texture = T.Coin,
		Color = colors(WHITE),
		LightEmission = 0.2,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(14, 20),
		SpreadAngle = Vector2.new(45, 45),
		Acceleration = Vector3.new(0, -48, 0),
		Size = NumberSequence.new(0.9),
		Transparency = seq(0, 0, 0.8, 0, 1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-260, 260),
		Lifetime = NumberRange.new(0.9, 1.2),
	}, 2)
	burst(CFrame.new(root.Position + Vector3.new(0, 1.5, 0)), 14, {
		Texture = T.Sparkle,
		Color = ColorSequence.new(Color3.fromHex("6BE04A"), Color3.fromHex("FFD23F")),
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Size = seq(0, 0.7, 1, 0),
		Lifetime = NumberRange.new(0.5, 0.8),
	}, 1.5)
end

local function trailColor(id)
	local t = TrailConfig.ById and TrailConfig.ById[id or ""]
	local c = t and t.Color
	if type(c) == "string" then
		local ok, col = pcall(Color3.fromHex, c)
		return ok and col or WHITE
	end
	return typeof(c) == "Color3" and c or WHITE
end

-- two light ribbons spiralling up around the player
local function swirl(color)
	local root = hrp()
	if not root then
		return
	end
	local cs = tintSeq(color)
	local pieces = {}
	for i = 1, 2 do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = root
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = cs
		trail.LightEmission = 0.5
		trail.FaceCamera = true
		trail.Lifetime = 0.4
		trail.Transparency = seq(0, 0, 1, 1)
		trail.Parent = root
		table.insert(pieces, { a0 = a0, a1 = a1, trail = trail, phase = (i - 1) * math.pi })
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / 1.1
		if k >= 1 or not root.Parent then
			conn:Disconnect()
			for _, p in pieces do
				p.a0:Destroy()
				p.a1:Destroy()
				p.trail:Destroy()
			end
			if root.Parent then
				burst(CFrame.new(root.Position + Vector3.new(0, 3.2, 0)), 30, {
					Texture = T.Sparkle,
					Color = cs,
					Speed = NumberRange.new(8, 14),
					SpreadAngle = Vector2.new(180, 180),
					Drag = 3,
					Size = seq(0, 0.9, 1, 0),
					Lifetime = NumberRange.new(0.5, 0.9),
				}, 1.5)
			end
			return
		end
		for _, p in pieces do
			local a = k * math.pi * 5 + p.phase
			local r = 2.6 * (1 - k * 0.5)
			local pos = Vector3.new(math.cos(a) * r, -2.6 + k * 6, math.sin(a) * r)
			p.a0.Position = pos
			p.a1.Position = pos + Vector3.new(0, 0.35, 0)
		end
	end)
	groundRing(root.Position - Vector3.new(0, 3, 0), color, 2, 10, 0.6)
end

local function equipBurst(color)
	local root = hrp()
	if not root then
		return
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	groundRing(feet, color, 1, 12, 0.5)
	task.delay(0.12, groundRing, feet, WHITE, 1, 8, 0.45, 0.4)
	burst(CFrame.new(feet), 20, {
		Texture = T.Sparkle,
		Color = tintSeq(color),
		Shape = Enum.ParticleEmitterShape.Disc,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(10, 10),
		Size = seq(0, 0.6, 1, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		HolderSize = Vector3.new(3, 0.2, 3),
	}, 1.5)
end

local function penCelebration()
	local plot = workspace.Map.Plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
	if not plot then
		return
	end
	-- the pen is rebuilt on upgrade; give it a moment, then use its real bounds (fall back to the lot)
	task.wait(0.25)
	local pen = plot:FindFirstChild("Pen")
	local cf, ext
	if pen then
		cf, ext = pen:GetBoundingBox()
	else
		local lot = plot:FindFirstChild("Zone")
		if not lot then
			return
		end
		cf, ext = lot.CFrame, lot.Size
	end
	local zone = { Size = ext }
	local gold = VFX.Purchase.PenGold
	local center = Vector3.new(cf.Position.X, cf.Position.Y - ext.Y / 2, cf.Position.Z)
	local span = math.max(ext.X, ext.Z)
	groundRing(center, gold, 4, span * 1.15, 0.8)
	task.delay(0.15, groundRing, center, WHITE, 4, span * 0.8, 0.7, 0.35)
	pointFlash(center + Vector3.new(0, 6, 0), gold, 60, 3, 1.2)
	local confettiColors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D6D")),
		ColorSequenceKeypoint.new(0.25, Color3.fromHex("FFD84A")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("4DD8FF")),
		ColorSequenceKeypoint.new(0.75, Color3.fromHex("6BE04A")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("C44DFF")),
	})
	local hx, hz = zone.Size.X / 2 - 3, zone.Size.Z / 2 - 3
	for _, corner in { Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, -hz), Vector3.new(-hx, 0, -hz) } do
		burst(CFrame.new(center + corner + Vector3.new(0, 1, 0)), 28, {
			Texture = T.Soft,
			Color = confettiColors,
			LightEmission = 0,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(22, 32),
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, -26, 0),
			Drag = 1.2,
			Squash = NumberSequence.new(-0.6),
			Size = NumberSequence.new(0.7),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
			Transparency = seq(0, 0, 0.8, 0, 1, 1),
			Lifetime = NumberRange.new(1.6, 2.2),
		}, 3)
	end
end

local purchaseHandlers = {
	FoodBought = function()
		coinSpray(count(VFX.Purchase.Coins.FoodBought))
	end,
	TrailBought = function(d)
		coinSpray(count(VFX.Purchase.Coins.TrailBought))
		swirl(trailColor(d.Id))
	end,
	TrailEquipped = function(d)
		equipBurst(trailColor(d.Id))
	end,
	PenUpgraded = function()
		coinSpray(count(VFX.Purchase.Coins.PenUpgraded))
		task.spawn(penCelebration)
	end,
	TreadmillUpgraded = function()
		coinSpray(count(VFX.Purchase.Coins.TreadmillUpgraded))
	end,
}

---------------------------------------------------------------- guardians
local guardians = {} -- [model] = state

local function guardianLook(model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head", true)
	local pos, size = bottomOf(model)
	local fwd = root and root.CFrame.LookVector or Vector3.new(-1, 0, 0)
	fwd = Vector3.new(fwd.X, 0, fwd.Z)
	fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(-1, 0, 0)
	local mouth
	if head and head:IsA("BasePart") then
		mouth = head.Position + fwd * (head.Size.Z * 0.5 + 0.5)
	else
		mouth = pos + Vector3.new(0, size.Y * 0.7, 0) + fwd * size.Z * 0.5
	end
	return pos, size, fwd, mouth, head
end

local function roar(model, g)
	local pos, size, fwd, mouth = guardianLook(model)
	local tint = VFX.Guardian.Biome[model:GetAttribute("BiomeId") or ""] or VFX.Guardian.Biome.PebblePlains
	local s = math.clamp(math.max(size.X, size.Z) / 10, 1, 3)
	-- sonic rings blasting forward out of the mouth
	for i = 0, 2 do
		task.delay(i * 0.14, function()
			burst(CFrame.lookAt(mouth, mouth + fwd), 1, {
				Texture = T.Ring,
				Color = colors(tint.Ring),
				LightEmission = 0.6,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Front,
				Speed = NumberRange.new(34),
				Drag = 1.5,
				Size = seq(0, 3 * s, 1, 22 * s),
				Transparency = seq(0, 0, 0.6, 0.3, 1, 1),
				Lifetime = NumberRange.new(0.7),
			}, 1.4)
		end)
	end
	-- roar lines streaming out of the mouth
	burst(CFrame.lookAt(mouth, mouth + fwd), 26, {
		Texture = T.Sparkle,
		Color = colors(WHITE, tint.Ring),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Front,
		Speed = NumberRange.new(40, 60),
		SpreadAngle = Vector2.new(28, 20),
		Squash = NumberSequence.new(3),
		Size = seq(0, 0.6 * s, 1, 0.2),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.55),
	}, 1.2)
	-- ground shockwave + dust ring + rocks
	groundRing(pos, tint.Ring, 4 * s, 38 * s, 0.75)
	task.delay(0.12, groundRing, pos, WHITE, 3 * s, 26 * s, 0.6, 0.35)
	burst(CFrame.new(pos + Vector3.new(0, 0.6, 0)), 30, {
		Texture = T.Smoke,
		Color = colors(tint.Dust),
		LightEmission = 0.15,
		LightInfluence = 0.7,
		Shape = Enum.ParticleEmitterShape.Disc,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(85, 85),
		Speed = NumberRange.new(14 * s, 22 * s),
		Drag = 4,
		Size = seq(0, 2.2 * s, 1, 5.5 * s),
		Transparency = seq(0, 0.25, 1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Lifetime = NumberRange.new(0.9, 1.3),
		HolderSize = Vector3.new(size.X, 0.2, size.Z),
	}, 2)
	for _ = 1, count(10) do
		local rock = Instance.new("Part")
		local r = rng:NextNumber(0.5, 1.1) * s
		rock.Size = Vector3.new(r, r * 0.8, r)
		rock.Color = tint.Rock
		rock.Material = Enum.Material.Slate
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CastShadow = false
		local a = rng:NextNumber(0, TWO_PI)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		rock.CFrame = CFrame.new(pos + out * size.X * 0.4 + Vector3.new(0, 0.6, 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		rock.Parent = fxFolder
		rock.AssemblyLinearVelocity = out * rng:NextNumber(10, 20) + Vector3.new(0, rng:NextNumber(22, 34), 0)
		rock.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		task.delay(1.1, function()
			if rock.Parent then
				TweenService:Create(rock, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(rock, 1.7)
	end
	if tint.Sparks then
		burst(CFrame.new(pos + Vector3.new(0, 0.5, 0)), 40, {
			Texture = T.Sparks,
			Color = colors(tint.Sparks, Color3.fromHex("FFD23F")),
			Speed = NumberRange.new(18, 30),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -30, 0),
			Size = seq(0, 0.5, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.3),
		}, 2)
	end
	pointFlash(mouth, tint.Ring, 30, 2.5, 0.7)
	addShake(VFX.Guardian.Shake * s, pos)
end

local function stompPuff(model, g, at)
	local pos, size = bottomOf(model)
	local tint = VFX.Guardian.Biome[model:GetAttribute("BiomeId") or ""] or VFX.Guardian.Biome.PebblePlains
	local s = math.clamp(math.max(size.X, size.Z) / 10, 1, 3)
	g.side = -(g.side or 1)
	local root = g.root
	local right = root.CFrame.RightVector
	local foot = at or (pos + Vector3.new(right.X, 0, right.Z) * g.side * size.X * 0.25)
	burst(CFrame.new(foot + Vector3.new(0, 0.4, 0)), 8, {
		Texture = T.Smoke,
		Color = colors(tint.Dust),
		LightEmission = 0.15,
		LightInfluence = 0.7,
		Speed = NumberRange.new(4 * s, 8 * s),
		SpreadAngle = Vector2.new(180, 20),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 5,
		Size = seq(0, 1.2 * s, 1, 3 * s),
		Transparency = seq(0, 0.35, 1, 1),
		Rotation = NumberRange.new(0, 360),
		Lifetime = NumberRange.new(0.5, 0.8),
	}, 1.2)
	groundRing(foot, tint.Ring, 1.5 * s, 9 * s, 0.4, 0.5)
	if tint.Sparks then
		burst(CFrame.new(foot + Vector3.new(0, 0.3, 0)), 8, {
			Texture = T.Sparks,
			Color = colors(tint.Sparks),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -30, 0),
			Size = seq(0, 0.35, 1, 0),
			Lifetime = NumberRange.new(0.5, 0.8),
		}, 1.2)
	end
	addShake(0.1 * s, foot)
end

local function setEyes(g, on)
	if g.eyeLight then
		TweenService:Create(g.eyeLight, TweenInfo.new(on and 0.15 or 0.6), { Brightness = on and 4 or 0 }):Play()
	end
	if g.eyeSparks then
		g.eyeSparks.Enabled = on
	end
end

local function addGuardian(model)
	if guardians[model] or not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local g = { root = root, state = model:GetAttribute("State"), nextStomp = 0 }
	local _, _, fwd, mouth, head = guardianLook(model)
	local eyeParent = head or root
	local eyeAtt = Instance.new("Attachment")
	eyeAtt.Name = "GameVFXEyes"
	eyeAtt.Parent = eyeParent
	eyeAtt.WorldPosition = mouth - fwd * 0.8 + Vector3.new(0, 0.6, 0)
	local light = Instance.new("PointLight")
	light.Color = VFX.Guardian.EyeGlow
	light.Range = 14
	light.Brightness = 0
	light.Shadows = false
	light.Parent = eyeAtt
	g.eyeLight = light
	g.eyeSparks = emitter(eyeAtt, {
		Texture = T.Glow,
		Color = colors(VFX.Guardian.EyeGlow),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = seq(0, 2.4, 0.5, 3.2, 1, 2.4),
		Transparency = seq(0, 0.15, 1, 1),
		Lifetime = NumberRange.new(0.25),
		ZOffset = 3,
		Rate = 14,
		Enabled = false,
	})
	guardians[model] = g
	-- KaijuFX marks every footfall (local attributes StepAt / StepPos): puff right under the foot from then on
	model:GetAttributeChangedSignal("StepAt"):Connect(function()
		g.footfalls = true
		local at = model:GetAttribute("StepPos")
		if (g.state == "Chasing" or g.state == "Returning") and typeof(at) == "Vector3" then
			stompPuff(model, g, at)
		end
	end)
	local function awake(state)
		return state == "Waking" or state == "Chasing"
	end
	setEyes(g, awake(g.state))
	model:GetAttributeChangedSignal("State"):Connect(function()
		local state = model:GetAttribute("State")
		local prev = g.state
		g.state = state
		setEyes(g, awake(state))
		if state == "Waking" or (state == "Chasing" and prev ~= "Waking" and prev ~= "Chasing") then
			roar(model, g)
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			guardians[model] = nil
		end
	end)
end

local function stepGuardians()
	local now = os.clock()
	for model, g in guardians do
		if (g.state == "Chasing" or g.state == "Returning") and g.root.Parent and not g.footfalls then
			local v = g.root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if speed > 3 and now >= g.nextStomp then
				stompPuff(model, g)
				local _, size = model:GetBoundingBox()
				local s = math.clamp(math.max(size.X, size.Z) / 10, 1, 3)
				g.nextStomp = now + math.clamp(9 / speed, 0.22, 0.75) * math.sqrt(s)
			end
		end
	end
end

---------------------------------------------------------------- weather + lighting mood
local safeX = 302
-- Zones come from the lane's Zone parts (each carries its BiomeId and spans its biome's X range), so they always match
-- the built map. (They used to be summed from BiomeConfig lengths plus a 3-stud border the map doesn't have, which
-- drifted 3 studs further out per biome.)
local laneZones = {}
local function readZones()
	local map = workspace:FindFirstChild("Map")
	local lane = map and map:FindFirstChild("Lane")
	local list = {}
	if lane then
		for _, m in lane:GetChildren() do
			local z = m:FindFirstChild("Zone")
			if z and z:IsA("BasePart") then
				table.insert(list, { x0 = z.Position.X - z.Size.X / 2, x1 = z.Position.X + z.Size.X / 2, id = z:GetAttribute("BiomeId") or m.Name })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.x0 < b.x0
	end)
	laneZones = list
end
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	safeX = map:GetAttribute("SafeZoneX") or (map:FindFirstChild("SafeZoneLine") and map.SafeZoneLine.Position.X) or safeX
	local lane = map:WaitForChild("Lane", 30)
	if lane then
		readZones()
		lane.ChildAdded:Connect(function()
			task.wait(1)
			readZones()
		end)
		lane.ChildRemoved:Connect(readZones)
	end
end)
local function zoneAt(x)
	if x < safeX then
		return "Hub"
	end
	local last
	for _, z in laneZones do
		last = z.id
		if x < z.x1 then
			return z.id
		end
	end
	if last then
		return last
	end
	-- map not read yet: sum the open biomes' lengths
	local x0 = safeX
	for _, biome in BiomeConfig.List do
		last = biome.Id
		x0 += biome.Length
		if x < x0 then
			return biome.Id
		end
	end
	return last
end

-- weather boxes follow the camera; each emitter's Rate fades to its zone target
local skyBox = holderPart(CFrame.new(0, 40, 0), Vector3.new(150, 1, 150)) -- falling things
skyBox.Name = "WeatherSky"
local airBox = holderPart(CFrame.new(0, 8, 0), Vector3.new(110, 22, 110)) -- floating things
airBox.Name = "WeatherAir"
local groundBox = holderPart(CFrame.new(0, 1, 0), Vector3.new(110, 1, 110)) -- rising things
groundBox.Name = "WeatherGround"

local W = VFX.Weather
local weather = {} -- { emitter, zone, rate }
local function weatherEmitter(zone, key, parent, props)
	local def = W[zone] and W[zone][key]
	if not def then
		return
	end
	props.Rate = 0
	props.Color = props.Color or colors(def.Color)
	local pe = emitter(parent, props)
	pe.Name = zone .. key
	table.insert(weather, { emitter = pe, zone = zone, rate = def.Rate })
end

weatherEmitter("PebblePlains", "Pollen", airBox, {
	Texture = T.Soft,
	LightEmission = 0.6,
	Speed = NumberRange.new(0.4, 1.4),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0.6, 0.15, 0.3),
	Size = seq(0, 0, 0.2, 0.35, 0.8, 0.35, 1, 0),
	Transparency = seq(0, 0.25, 1, 1),
	Lifetime = NumberRange.new(5, 8),
})
weatherEmitter("PebblePlains", "Leaves", skyBox, {
	Texture = T.Soft,
	LightEmission = 0,
	LightInfluence = 1,
	EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(3, 5),
	SpreadAngle = Vector2.new(30, 30),
	Acceleration = Vector3.new(2.5, 0, 1),
	Squash = NumberSequence.new(-0.7),
	Size = NumberSequence.new(0.55),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-160, 160),
	Transparency = seq(0, 0.1, 0.85, 0.1, 1, 1),
	Lifetime = NumberRange.new(8, 11),
	Color = ColorSequence.new(Color3.fromHex("7FD957"), Color3.fromHex("C9E86B")),
})
weatherEmitter("LavaLagoon", "Embers", groundBox, {
	Texture = T.Soft,
	EmissionDirection = Enum.NormalId.Top,
	Speed = NumberRange.new(3, 7),
	SpreadAngle = Vector2.new(25, 25),
	Acceleration = Vector3.new(1.2, 2.5, 0),
	Size = seq(0, 0.45, 0.5, 0.35, 1, 0),
	Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
	Lifetime = NumberRange.new(3, 5),
	Color = ColorSequence.new(Color3.fromHex("FFD23F"), Color3.fromHex("FF4A1F")),
})
weatherEmitter("LavaLagoon", "Ash", skyBox, {
	Texture = T.Soft,
	LightEmission = 0,
	LightInfluence = 1,
	EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(2, 4),
	SpreadAngle = Vector2.new(25, 25),
	Acceleration = Vector3.new(1.5, 0, 0.5),
	Size = NumberSequence.new(0.3),
	RotSpeed = NumberRange.new(-90, 90),
	Transparency = seq(0, 0.3, 0.9, 0.3, 1, 1),
	Lifetime = NumberRange.new(9, 12),
})
weatherEmitter("FrostfangPeaks", "Snow", skyBox, {
	Texture = T.Soft,
	LightEmission = 0.2,
	EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(6, 9),
	SpreadAngle = Vector2.new(12, 12),
	Acceleration = Vector3.new(4, 0, 1.5),
	RotSpeed = NumberRange.new(-40, 40),
	Size = seq(0, 0.55, 1, 0.45),
	Transparency = seq(0, 0.05, 0.9, 0.05, 1, 1),
	Lifetime = NumberRange.new(5, 7),
})
weatherEmitter("VenomJungle", "Spores", airBox, {
	Texture = T.Soft,
	LightEmission = 0.8,
	Speed = NumberRange.new(0.3, 1),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0.3, 0.4, 0.2),
	Size = seq(0, 0, 0.25, 0.3, 0.8, 0.3, 1, 0),
	Transparency = seq(0, 0.2, 1, 1),
	Lifetime = NumberRange.new(5, 9),
})
weatherEmitter("SunkenAbyss", "Bubbles", groundBox, {
	Texture = T.Soft,
	LightEmission = 0.3,
	EmissionDirection = Enum.NormalId.Top,
	Speed = NumberRange.new(2, 4),
	SpreadAngle = Vector2.new(15, 15),
	Acceleration = Vector3.new(0, 1.2, 0),
	Size = seq(0, 0.2, 1, 0.5),
	Transparency = seq(0, 0.3, 0.85, 0.4, 1, 1),
	Lifetime = NumberRange.new(5, 8),
})
weatherEmitter("StormSpires", "Rain", skyBox, {
	Texture = T.Soft,
	LightEmission = 0,
	LightInfluence = 1,
	EmissionDirection = Enum.NormalId.Bottom,
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	Speed = NumberRange.new(55, 65),
	SpreadAngle = Vector2.new(4, 4),
	Acceleration = Vector3.new(6, 0, 2),
	Squash = NumberSequence.new(3),
	Size = NumberSequence.new(0.18),
	Transparency = seq(0, 0.35, 1, 0.35),
	Lifetime = NumberRange.new(0.7, 0.9),
})
weatherEmitter("CosmicRift", "Stardust", airBox, {
	Texture = T.Soft,
	LightEmission = 1,
	Speed = NumberRange.new(0.2, 0.8),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0, 0.25, 0),
	Size = seq(0, 0, 0.3, 0.25, 0.7, 0.25, 1, 0),
	Transparency = seq(0, 0.1, 1, 1),
	Lifetime = NumberRange.new(4, 7),
})

local cc = Lighting:FindFirstChild("KaijuColor")
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local baseLook = {
	tint = cc and cc.TintColor,
	sat = cc and cc.Saturation,
	bri = cc and cc.Brightness,
	density = atmo and atmo.Density,
	color = atmo and atmo.Color,
	decay = atmo and atmo.Decay,
	haze = atmo and atmo.Haze,
	glare = atmo and atmo.Glare,
}

-- the zone's sky (Atmosphere Color / Decay / Haze / Glare, e.g. Storm Spires' overcast): published as the Lighting
-- attributes ZoneAtmo* so WeatherFX blends its events from (and back to) the zone's sky, and written to the
-- Atmosphere directly only while no weather event is showing (WeatherFX owns it while one is)
local atmoCur = atmo and { color = atmo.Color, decay = atmo.Decay, haze = atmo.Haze, glare = atmo.Glare }
local atmoFade = 0
local function fadeAtmo(target)
	if not atmo then
		return
	end
	atmoFade += 1
	local token = atmoFade
	local from = table.clone(atmoCur)
	task.spawn(function()
		local t0 = os.clock()
		while token == atmoFade do
			local a = math.clamp((os.clock() - t0) / W.Fade, 0, 1)
			local s = a * a * (3 - 2 * a)
			atmoCur.color = from.color:Lerp(target.color, s)
			atmoCur.decay = from.decay:Lerp(target.decay, s)
			atmoCur.haze = from.haze + (target.haze - from.haze) * s
			atmoCur.glare = from.glare + (target.glare - from.glare) * s
			Lighting:SetAttribute("ZoneAtmoColor", atmoCur.color)
			Lighting:SetAttribute("ZoneAtmoDecay", atmoCur.decay)
			Lighting:SetAttribute("ZoneAtmoHaze", atmoCur.haze)
			Lighting:SetAttribute("ZoneAtmoGlare", atmoCur.glare)
			if Lighting:GetAttribute("WeatherDark") == nil then
				atmo.Color, atmo.Decay, atmo.Haze, atmo.Glare = atmoCur.color, atmoCur.decay, atmoCur.haze, atmoCur.glare
			end
			if a >= 1 then
				break
			end
			task.wait(0.05)
		end
	end)
end

local currentZone
local function setZone(zone)
	if zone == currentZone then
		return
	end
	currentZone = zone
	local info = TweenInfo.new(W.Fade, Enum.EasingStyle.Sine)
	local scale = reduced() and VFX.ReducedScale or 1
	for _, w in weather do
		TweenService:Create(w.emitter, info, { Rate = w.zone == zone and w.rate * scale or 0 }):Play()
	end
	local look = W[zone] and W[zone].Lighting
	if cc and baseLook.tint then
		TweenService:Create(cc, info, {
			TintColor = look and look.Tint or baseLook.tint,
			Saturation = baseLook.sat + (look and look.Saturation or 0),
			Brightness = baseLook.bri + (look and look.Brightness or 0),
		}):Play()
	end
	if atmo and baseLook.density then
		TweenService:Create(atmo, info, { Density = baseLook.density + (look and look.Haze or 0) }):Play()
		fadeAtmo({
			color = look and look.AtmoColor or baseLook.color,
			decay = look and look.AtmoDecay or baseLook.decay,
			haze = look and look.AtmoHaze or baseLook.haze,
			glare = look and look.AtmoGlare or baseLook.glare,
		})
	end
end

-- Reduced Effects toggled mid-game: re-apply weather rates
Settings.Changed("ReducedEffects", function()
	local z = currentZone
	currentZone = nil
	if z then
		setZone(z)
	end
end)

---------------------------------------------------------------- wiring
task.spawn(function()
	local runtime = workspace:WaitForChild("Runtime")
	task.spawn(function()
		local folder = runtime:WaitForChild("Guardians")
		folder.ChildAdded:Connect(function(m)
			task.spawn(addGuardian, m)
		end)
		for _, m in folder:GetChildren() do
			task.spawn(addGuardian, m)
		end
	end)
	local kaijuFolder = runtime:WaitForChild("Kaiju")
	watchKaijuFolder(kaijuFolder)
	kaijuFolder.ChildAdded:Connect(function(m)
		task.wait()
		local spawned = m:GetAttribute("SpawnedAt")
		if spawned and serverNow() - spawned < 2.5 and not m:GetAttribute("LeveledAt") then
			local _, size = m:GetBoundingBox()
			if (m:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 260 and size.Magnitude > 0 then
				onHatched(m)
			end
		end
	end)
end)
task.spawn(function()
	local market = workspace:WaitForChild("Map"):WaitForChild("Market", 60)
	local keepers = market and market:WaitForChild("Keepers", 30)
	if keepers then
		watchKaijuFolder(keepers)
	end
end)

gameEvent.OnClientEvent:Connect(function(name, data)
	local handler = purchaseHandlers[name]
	if handler then
		local ok, err = pcall(handler, type(data) == "table" and data or {})
		if not ok then
			warn("[GameVFX] " .. tostring(name) .. ": " .. tostring(err))
		end
	end
end)

local zoneTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera.CFrame.Position
	skyBox.CFrame = CFrame.new(cam.X, cam.Y + 35, cam.Z)
	airBox.CFrame = CFrame.new(cam.X, cam.Y, cam.Z)
	groundBox.CFrame = CFrame.new(cam.X, 1, cam.Z)
	stepAuras(os.clock())
	stepGuardians()
	zoneTimer += dt
	if zoneTimer >= 0.3 then
		zoneTimer = 0
		local root = hrp()
		local x = root and root.Position.X or cam.X
		setZone(zoneAt(x))
	end
end)
