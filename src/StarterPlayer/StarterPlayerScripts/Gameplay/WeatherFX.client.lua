-- WeatherFX: the client side of the server-wide weather events (ServerScriptService.Services.WeatherService,
-- Shared.Config.WeatherConfig). Purely cosmetic: reads workspace attribute WeatherId / WeatherEndsAt and the GameEvents
-- WeatherStrike / HailHit, and the eggs' Mutation / MutatedAt / WeatherEgg attributes.
--   look      colour grade (its own ColorCorrection), darkness + sky clock through DayNightFX's Lighting attributes
--             (WeatherDark, WeatherAmbient, WeatherClock, WeatherClockBlend), atmosphere colour / haze, stars, sun
--   particles rigs that follow the camera: Sky (rain, hail, golden drops), Near (snow, motes), High (clouds, stars,
--             shooting stars), Ground (splashes, mist); sky pieces (blood moon, eclipse, sun rays, aurora curtains)
--   strikes   lightning bolts, meteors with craters, crystal hail chunks - where the server says, with flash, shake, sound
--   eggs      a burst when an egg mutates; a light pillar over the server's "weather egg"
-- Textures are VFX Studio library images (rbxassetid), sounds are Creator Store audio. Reduced Effects cuts rates.
-- Playbook add-ons (PLUS): per-event dark layer + ground layer + accents + a recurring beat, an edge vignette, lens
-- flares / stacked halos / chroma / dark lingers on strikes (with a ground telegraph while falling), an arrival burst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local WeatherConfig = require(Config:WaitForChild("WeatherConfig"))
local MutationConfig = require(Config:WaitForChild("MutationConfig"))
local MutationVisuals = require(ReplicatedStorage.Shared:WaitForChild("Util"):WaitForChild("MutationVisuals"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local gameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent")

local player = Players.LocalPlayer
local rng = Random.new()
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local FADE = 3 -- seconds in / out

-- VFX Studio textures
local T = {
	RainDrop = "rbxassetid://5889875399",
	RainThin = "rbxassetid://6820821916",
	Glitter = "rbxassetid://106213021633252",
	Sparkle = "rbxassetid://97748444811872",
	CrossGlint = "rbxassetid://14197583306",
	BlueGlint = "rbxassetid://14197626379",
	SunRays = "rbxassetid://12386392796",
	SunHalo = "rbxassetid://37037765",
	SoftGlow = "rbxassetid://15513493035",
	Disc = "rbxassetid://12402851670",
	MoonShade = "rbxassetid://14346169397",
	Shockwave = "rbxassetid://12402854196",
	RingImpact = "rbxassetid://12402900657",
	BoltBranch = "rbxassetid://1463939561",
	BoltBlue = "rbxassetid://243043229",
	BoltThin = "rbxassetid://12402873530",
	BoltBranch2 = "rbxassetid://11736666805",
	BoltRadial = "rbxassetid://332491482",
	BoltBall = "rbxassetid://103597677385771",
	CloudPuff = "rbxassetid://4510290214",
	CloudBig = "rbxassetid://291880914",
	Snowflake = "rbxassetid://86390398432271",
	SoftDot = "rbxassetid://241779220",
	Streak = "rbxassetid://12363818232",
	MeteorLine = "rbxassetid://128424131054950",
	FireExplosion = "rbxassetid://15811794808",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	MagmaRibbon = "rbxassetid://3052949762",
	Crater = "rbxassetid://85474069372331",
	LavaCracks = "rbxassetid://10365551764",
	Diamond = "rbxassetid://7245988767",
	ShardBurst = "rbxassetid://14241995242",
	CrystalSpikes = "rbxassetid://12402863766",
	Aurora = "rbxassetid://303195022",
	PrismSparkles = "rbxassetid://73385444872956",
	ColorStars = "rbxassetid://78694460034696",
	RainbowArc = "rbxassetid://14198091244",
	Corona = "rbxassetid://12386390257",
	Corona2 = "rbxassetid://8214519968",
	Galaxy = "rbxassetid://15265627476",
	StarDust = "rbxassetid://134563328683175",
	Star4 = "rbxassetid://5946093983",
	Coin = "rbxassetid://133140224705236",
	LightColumn = "rbxassetid://530839385",
	Smoke = "rbxassetid://2671910894",
}

-- Creator Store audio (swap freely)
local S = {
	Rain = { Id = 13039198193, Volume = 0.45 },
	LightRain = { Id = 7127218501, Volume = 0.25 },
	Wind = { Id = 4175285709, Volume = 0.5 },
	DeepWind = { Id = 93877258352428, Volume = 0.35 },
	Thunder = { Id = 130457325001606, Volume = 0.9 },
	ThunderFar = { Id = 139319051979882, Volume = 0.45 },
	Boom = { Id = 138533090376585, Volume = 0.8 },
	Shatter = { Id = 118987440163311, Volume = 0.6 },
	Chime = { Id = 9119834248, Volume = 0.5 },
	Twinkle = { Id = 9116394545, Volume = 0.3 },
}

local function reduced()
	return Settings.Get("ReducedEffects") == true
end
local function soundOn()
	return Settings.Get("SoundEffects") ~= false
end

local folder = Instance.new("Folder")
folder.Name = "WeatherFXLocal"
folder.Parent = workspace

local function NS(...)
	local pts = { ... }
	if #pts == 1 then
		return NumberSequence.new(pts[1])
	end
	if #pts == 2 then
		return NumberSequence.new(pts[1], pts[2])
	end
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end
local CS = MutationVisuals.Sequence

local function newPart(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent or folder
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

local function playSound(spec, parent, extra)
	if not (spec and soundOn()) then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(spec.Id)
	s.Volume = spec.Volume * ((extra and extra.Volume) or 1)
	s.PlaybackSpeed = (extra and extra.Pitch or 1) * rng:NextNumber(0.95, 1.05)
	s.RollOffMaxDistance = extra and extra.MaxDist or 700
	s.RollOffMinDistance = extra and extra.MinDist or 30
	local group = SoundService:FindFirstChild("SFX")
	if group and group:IsA("SoundGroup") then
		s.SoundGroup = group
	end
	s.Parent = parent or SoundService
	s:Play()
	Debris:AddItem(s, 8)
	return s
end

local function soundAt(spec, pos, extra)
	local p = newPart("Sound", Vector3.new(0.2, 0.2, 0.2))
	p.Position = pos
	playSound(spec, p, extra)
	Debris:AddItem(p, 8)
end

-- quick one-shot burst somewhere in the world
local function burst(pos, props, count, life)
	local p = newPart("Burst", Vector3.new(0.5, 0.5, 0.5))
	p.Position = pos
	local att = Instance.new("Attachment")
	att.Parent = p
	props.Rate = 0
	local pe = emitter(att, props)
	pe:Emit(count or 1)
	Debris:AddItem(p, life or 3)
	return p, pe
end

-- a flat glowing decal on the ground that fades (craters, scorch, cracks)
local function groundDecal(pos, size, image, color, hold, fade, transparency)
	local p = newPart("GroundDecal", Vector3.new(size, 0.05, size))
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = image
	d.Color3 = color or WHITE
	d.Transparency = transparency or 0
	d.Parent = p
	task.delay(hold or 2, function()
		if p.Parent then
			TweenService:Create(d, TweenInfo.new(fade or 2), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(p, (hold or 2) + (fade or 2) + 0.2)
	return p, d
end

-- flat ring that grows along the ground
local function groundRing(pos, color, size, life, image)
	burst(pos + Vector3.new(0, 0.3, 0), {
		Texture = image or T.Shockwave,
		Color = ColorSequence.new(color),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Size = NS(0, 0.5, 1, size),
		Transparency = NS(0, 0.05, 1, 1),
		Lifetime = NumberRange.new(life or 0.6),
		Rotation = NumberRange.new(0, 360),
	}, 1, (life or 0.6) + 0.5)
end

-- camera shake (Camera Shake setting)
local shakeUntil, shakeMag = 0, 0
local function shake(mag, seconds, pos)
	if Settings.Get("CameraShake") == false then
		return
	end
	local cam = workspace.CurrentCamera
	if pos and cam then
		local d = (cam.CFrame.Position - pos).Magnitude
		mag *= math.clamp(1 - d / 140, 0, 1)
	end
	if mag <= 0.02 then
		return
	end
	shakeMag = math.max(shakeMag, mag)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end
RunService:BindToRenderStep("WeatherShake", Enum.RenderPriority.Camera.Value + 2, function()
	local now = os.clock()
	if now >= shakeUntil then
		shakeMag = 0
		return
	end
	local cam = workspace.CurrentCamera
	local k = shakeMag * math.clamp((shakeUntil - now) / 0.4, 0, 1)
	cam.CFrame = cam.CFrame * CFrame.Angles(rng:NextNumber(-1, 1) * 0.01 * k, rng:NextNumber(-1, 1) * 0.01 * k, 0)
end)

---------------------------------------------------------------- lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "WeatherColor"
cc.Parent = Lighting
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local sky = Lighting:FindFirstChildOfClass("Sky")
local baseAtmo = atmo and { Color = atmo.Color, Decay = atmo.Decay, Haze = atmo.Haze, Glare = atmo.Glare }
local baseSky = sky and { StarCount = sky.StarCount, Celestial = sky.CelestialBodiesShown }
-- the sky to blend from and back to: the current biome's (GameVFX publishes it as Lighting ZoneAtmo* attributes,
-- e.g. Storm Spires' overcast), else the start-up one
local function zoneAtmo()
	return {
		Color = Lighting:GetAttribute("ZoneAtmoColor") or baseAtmo.Color,
		Decay = Lighting:GetAttribute("ZoneAtmoDecay") or baseAtmo.Decay,
		Haze = Lighting:GetAttribute("ZoneAtmoHaze") or baseAtmo.Haze,
		Glare = Lighting:GetAttribute("ZoneAtmoGlare") or baseAtmo.Glare,
	}
end
local flash = 0 -- lightning flash, decays each frame
-- Atmosphere.Density also belongs to GameVFX (biome haze): weather adds on top of whatever it last set
local densAdd, densWritten = 0, nil
local function setDensity(add)
	if not atmo then
		return
	end
	local cur = atmo.Density
	local base
	if densWritten and math.abs(cur - densWritten) < 1e-4 then
		base = cur - densAdd
	else
		base = cur -- GameVFX set a new biome value
	end
	densAdd = add
	densWritten = math.clamp(base + add, 0, 1)
	atmo.Density = densWritten
end

-- per event: colour grade + darkness + sky + builder for its particles / sky pieces
local LOOKS = {}

---------------------------------------------------------------- the running event
local active = nil -- { id, look, weight, target, emitters = { {pe, rate} }, sky = { {part, dir, dist} }, cleanup = {}, loops = {} }
local rigs = {}

local function makeRigs()
	rigs.Sky = newPart("SkyRig", Vector3.new(160, 2, 160))
	rigs.High = newPart("HighRig", Vector3.new(640, 6, 640))
	rigs.Near = newPart("NearRig", Vector3.new(80, 36, 80))
	rigs.Ground = newPart("GroundRig", Vector3.new(90, 0.4, 90))
	rigs.Streak = newPart("StreakRig", Vector3.new(300, 4, 300))
end
makeRigs()

local groundY = 0
local lastGroundCheck = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateRigs()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local pos = cam.CFrame.Position
	if os.clock() - lastGroundCheck > 0.25 then
		lastGroundCheck = os.clock()
		local ignore = { folder }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		rayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -300, 0), rayParams)
		groundY = hit and hit.Position.Y or (pos.Y - 20)
	end
	local look = cam.CFrame.LookVector
	local ahead = Vector3.new(look.X, 0, look.Z)
	ahead = ahead.Magnitude > 0.01 and ahead.Unit * 18 or Vector3.zero
	local flat = Vector3.new(pos.X, 0, pos.Z) + ahead
	rigs.Sky.CFrame = CFrame.new(flat.X, math.max(pos.Y, groundY) + 46, flat.Z)
	rigs.High.CFrame = CFrame.new(flat.X, groundY + 105, flat.Z)
	rigs.Near.CFrame = CFrame.new(flat.X, pos.Y + 4, flat.Z)
	rigs.Ground.CFrame = CFrame.new(flat.X, groundY + 0.25, flat.Z)
	rigs.Streak.CFrame = CFrame.new(flat.X - 60, groundY + 170, flat.Z) * CFrame.Angles(0, 0, math.rad(-38))
end

-- ctx helpers handed to each LOOKS[id].Build
local function ctxFor(state)
	local ctx = {}
	function ctx.emit(rigName, props)
		local rig = rigs[rigName]
		local rate = props.Rate or 10
		props.Rate = 0
		local pe = emitter(rig, props)
		table.insert(state.emitters, { pe = pe, rate = rate })
		return pe
	end
	-- a picture far up in the sky, kept at the same angle from the camera (moon, eclipse, sun rays)
	function ctx.sky(dir, dist, size, layers)
		local p = newPart("SkyPiece", Vector3.new(1, 1, 1))
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(size, size)
		bb.LightInfluence = 0
		bb.MaxDistance = math.huge
		bb.Brightness = 1.5
		bb.Adornee = p
		bb.Parent = p
		local spins = {}
		for i, l in layers do
			local img = Instance.new("ImageLabel")
			img.Name = "Layer" .. i
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(l.Scale or 1, l.Scale or 1)
			img.Image = l.Image
			img.ImageColor3 = l.Color or WHITE
			img.ImageTransparency = 1
			img.ZIndex = i
			img.Parent = bb
			table.insert(spins, { img = img, spin = l.Spin or 0, base = l.Transparency or 0, pulse = l.Pulse })
		end
		table.insert(state.sky, { part = p, dir = dir.Unit, dist = dist, spins = spins })
		return p
	end
	-- wavy light curtains high above (the aurora)
	function ctx.curtains(count, props)
		for i = 1, count do
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			local z = (i - (count + 1) / 2) * 55
			a0.Position = Vector3.new(-260, rng:NextNumber(-10, 25), z + rng:NextNumber(-15, 15))
			a1.Position = Vector3.new(260, rng:NextNumber(-10, 25), z + rng:NextNumber(-15, 15))
			a0.Parent = rigs.High
			a1.Parent = rigs.High
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = props.Texture
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = props.TextureLength or 90
			b.TextureSpeed = rng:NextNumber(0.08, 0.2) * (rng:NextNumber() < 0.5 and -1 or 1)
			b.Color = props.Color
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = props.Brightness or 3
			b.Width0 = rng:NextNumber(60, 110)
			b.Width1 = rng:NextNumber(60, 110)
			b.Segments = 40
			b.FaceCamera = true
			b.Transparency = NumberSequence.new(1)
			b.Parent = rigs.High
			table.insert(state.cleanup, a0)
			table.insert(state.cleanup, a1)
			table.insert(state.beams, { beam = b, phase = rng:NextNumber(0, 10), base = props.Transparency })
		end
	end
	function ctx.loop(spec, pitch)
		if not spec then
			return
		end
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(spec.Id)
		s.Looped = true
		s.Volume = 0
		s.PlaybackSpeed = pitch or 1
		local group = SoundService:FindFirstChild("Ambience")
		if group and group:IsA("SoundGroup") then
			s.SoundGroup = group
		end
		s.Parent = SoundService
		s:Play()
		table.insert(state.loops, { sound = s, volume = spec.Volume })
	end
	-- run fn every few seconds while the event lasts
	function ctx.every(range, fn)
		table.insert(state.timers, { range = range, fn = fn, at = os.clock() + rng:NextNumber(range[1], range[2]) })
	end
	return ctx
end

local function stopActive(instant)
	local state = active
	if not state then
		return
	end
	active = nil
	state.ending = true
	local function clear()
		for _, e in state.emitters do
			e.pe:Destroy()
		end
		for _, s in state.sky do
			s.part:Destroy()
		end
		for _, b in state.beams do
			b.beam:Destroy()
		end
		for _, c in state.cleanup do
			if typeof(c) == "Instance" then
				c:Destroy()
			elseif typeof(c) == "RBXScriptConnection" then
				c:Disconnect()
			elseif type(c) == "function" then
				pcall(c)
			end
		end
		for _, l in state.loops do
			l.sound:Destroy()
		end
	end
	if instant then
		clear()
		return
	end
	-- fade out on its own
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local w = math.clamp(1 - (os.clock() - start) / FADE, 0, 1)
		state.weight = math.min(state.weight, w)
		state.apply(state)
		local cam = workspace.CurrentCamera
		for _, s in state.sky do
			s.part.CFrame = CFrame.new((cam and cam.CFrame.Position or Vector3.zero) + s.dir * s.dist)
		end
		if w <= 0 then
			conn:Disconnect()
			clear()
		end
	end)
end

local function applyState(state)
	local w = state.weight
	local scale = reduced() and 0.35 or 1
	for _, e in state.emitters do
		e.pe.Rate = e.rate * w * scale
	end
	for _, b in state.beams do
		local t = os.clock() + b.phase
		local k = 1 - w * (1 - (b.base or 0.4))
		b.beam.Transparency = NS(0, 1, 0.2, k + (1 - k) * 0.3, 0.5, k, 0.8, k + (1 - k) * 0.3, 1, 1)
		b.beam.CurveSize0 = math.sin(t * 0.25) * 70
		b.beam.CurveSize1 = math.cos(t * 0.21) * 70
	end
	for _, s in state.sky do
		for _, l in s.spins do
			l.img.Rotation += l.spin * (1 / 60)
			local base = l.base
			if l.pulse then
				base += math.sin(os.clock() * l.pulse) * 0.08
			end
			l.img.ImageTransparency = 1 - (1 - base) * w
		end
	end
	for _, l in state.loops do
		l.sound.Volume = (soundOn() and l.volume or 0) * w
	end
end

local function startEvent(id)
	local look = LOOKS[id]
	if active and active.id == id then
		return
	end
	stopActive(false)
	if not look then
		return
	end
	local state = { id = id, look = look, weight = 0, emitters = {}, sky = {}, beams = {}, cleanup = {}, loops = {}, timers = {}, startedAt = os.clock() }
	state.apply = applyState
	active = state
	local ok, err = pcall(look.Build, ctxFor(state), state)
	if not ok then
		warn("[WeatherFX] build " .. id .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------- frame update: weight, rigs, sky, grade
local lightingState = { w = 0, look = nil }
RunService.RenderStepped:Connect(function(dt)
	updateRigs()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local state = active
	if state then
		local endsAt = workspace:GetAttribute("WeatherEndsAt")
		local fadeOut = type(endsAt) == "number" and math.clamp((endsAt - workspace:GetServerTimeNow()) / FADE, 0, 1) or 1
		state.weight = math.min(math.clamp((os.clock() - state.startedAt) / FADE, 0, 1), fadeOut)
		applyState(state)
		for _, t in state.timers do
			if os.clock() >= t.at then
				t.at = os.clock() + rng:NextNumber(t.range[1], t.range[2])
				task.spawn(t.fn)
			end
		end
		if state.look.Update then
			state.look.Update(state, dt)
		end
	end
	-- sky pieces of the running and the fading-out events
	for _, s in (state and state.sky) or {} do
		s.part.CFrame = CFrame.new(camPos + s.dir * s.dist)
	end
	-- the grade follows whichever event is showing (fading-out ones keep their look until gone)
	local look = state and state.look or lightingState.look
	local w = state and state.weight or math.max(0, lightingState.w - dt / FADE)
	lightingState.look, lightingState.w = look, w
	flash = math.max(0, flash - dt * 3.2)
	if look and w > 0 then
		cc.TintColor = WHITE:Lerp(look.Tint or WHITE, w)
		cc.Saturation = (look.Saturation or 0) * w
		cc.Contrast = (look.Contrast or 0) * w
		cc.Brightness = (look.Brightness or 0) * w + flash
		Lighting:SetAttribute("WeatherDark", (look.Dark or 0) * w * (1 - math.min(1, flash * 1.4)))
		Lighting:SetAttribute("WeatherAmbient", look.Ambient)
		Lighting:SetAttribute("WeatherClock", look.Clock)
		Lighting:SetAttribute("WeatherClockBlend", look.Clock and w or nil)
		if atmo and baseAtmo then
			local za = zoneAtmo()
			atmo.Color = za.Color:Lerp(look.AtmoColor or za.Color, w)
			atmo.Decay = za.Decay:Lerp(look.AtmoDecay or za.Decay, w)
			atmo.Haze = za.Haze + (look.Haze or 0) * w
			atmo.Glare = math.max(0, za.Glare + (look.Glare or 0) * w)
			setDensity((look.Density or 0) * w)
		end
		if sky and baseSky then
			sky.StarCount = look.Stars and math.floor(baseSky.StarCount + (look.Stars - baseSky.StarCount) * w) or baseSky.StarCount
			sky.CelestialBodiesShown = not (look.HideSun and w > 0.4) and baseSky.Celestial
		end
	else
		cc.TintColor = WHITE
		cc.Saturation, cc.Contrast = 0, 0
		cc.Brightness = flash
		if Lighting:GetAttribute("WeatherDark") ~= nil then
			Lighting:SetAttribute("WeatherDark", nil)
			Lighting:SetAttribute("WeatherAmbient", nil)
			Lighting:SetAttribute("WeatherClock", nil)
			Lighting:SetAttribute("WeatherClockBlend", nil)
			if atmo and baseAtmo then
				local za = zoneAtmo()
				atmo.Color, atmo.Decay, atmo.Haze, atmo.Glare = za.Color, za.Decay, za.Haze, za.Glare
				setDensity(0)
			end
			if sky and baseSky then
				sky.StarCount, sky.CelestialBodiesShown = baseSky.StarCount, baseSky.Celestial
			end
		end
	end
end)

---------------------------------------------------------------- the eight events
local SKY_DIR = Vector3.new(0.78, 0.42, 0.18) -- over the lane, up from the bases

local function rain(ctx, color, rate, size, speed, texture, transparency)
	return ctx.emit("Sky", {
		Name = "Rain",
		Texture = texture or T.RainDrop,
		Color = ColorSequence.new(color),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(speed, speed * 1.15),
		Lifetime = NumberRange.new(0.55, 0.65),
		Size = NS(size),
		Squash = NS(1.6),
		Transparency = NS(transparency or 0.35),
		LightEmission = 0.5,
		LightInfluence = 0.4,
		Rate = rate,
	})
end

LOOKS.GoldenSunshower = {
	Tint = hex("FFF1CC"), Saturation = 0.15, Brightness = 0.04, Contrast = 0.03, Dark = 0,
	AtmoColor = hex("FFE7A8"), AtmoDecay = hex("FFC86A"), Haze = 0.4, Glare = 0.8,
	Build = function(ctx)
		local gold = rain(ctx, hex("FFD84A"), 200, 2.4, 70, T.RainThin, 0.1)
		gold.LightEmission = 1
		gold.LightInfluence = 0
		ctx.emit("Near", {
			Name = "GoldMotes", Texture = T.Glitter, Color = CS({ "#FFF6B0", "#FFD23F", "#FF9E1F" }),
			Size = NS(0, 0, 0.3, 1.2, 1, 0), Transparency = NS(0, 0.2, 1, 1), Lifetime = NumberRange.new(2, 3.5),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -1, 0),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Rate = 30,
		})
		ctx.emit("Sky", {
			Name = "Coins", Texture = T.Coin, Color = ColorSequence.new(WHITE), LightEmission = 0.3,
			Size = NS(0.9), Lifetime = NumberRange.new(1.4, 1.8), Speed = NumberRange.new(30, 40),
			EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200), Rate = 4,
		})
		ctx.emit("Ground", {
			Name = "GoldSplash", Texture = T.CrossGlint, Color = ColorSequence.new(hex("FFE27A")),
			Size = NS(0, 0, 0.3, 1.4, 1, 0), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 90), Rate = 45,
		})
		ctx.sky(SKY_DIR + Vector3.new(0, 0.35, 0), 420, 260, {
			{ Image = T.SoftGlow, Color = hex("FFD23F"), Scale = 1.4, Transparency = 0.35 },
			{ Image = T.SunRays, Color = hex("FFE27A"), Scale = 1.6, Spin = 4, Transparency = 0.2 },
			{ Image = T.SunRays, Color = hex("FFF6B0"), Scale = 1.1, Spin = -6, Transparency = 0.3 },
			{ Image = T.SunHalo, Color = hex("FFFFFF"), Scale = 0.6, Transparency = 0.1, Pulse = 2 },
		})
		ctx.loop(S.LightRain)
		ctx.every({ 7, 12 }, function()
			playSound(S.Chime, nil, { Volume = 0.6, Pitch = rng:NextNumber(0.9, 1.2) })
		end)
	end,
}

---------------------------------------------------------------- playbook layers: lens flares, halo rings, chroma, dark lingers
-- (Project doc claude/vfx-reference-playbook.md: white core + coloured edges, a dark layer under bright ones, lens flares,
-- stacked halo rings, chromatic slivers, a quick screen tint on big hits, snappy charge -> hit -> linger beats.)
local TX = {
	FourStar = "rbxassetid://14198353638", Anamorphic = "rbxassetid://114278596683627", Halo = "rbxassetid://7504062906",
	CleanRing = "rbxassetid://7136539160", FrostRing = "rbxassetid://7136551175", MagicRing = "rbxassetid://91168521719532",
	GlowRing = "rbxassetid://82033827591449", Octagon = "rbxassetid://3283071087", Chroma = "rbxassetid://14221474657",
	PrismRays = "rbxassetid://76815628297122", BigCross = "rbxassetid://14969367343", CrescentSmoke = "rbxassetid://140591030585994",
	Nebula = "rbxassetid://14242201435", Arc1 = "rbxassetid://12402856027", Arc2 = "rbxassetid://12402856928",
	FlameFlip = "rbxassetid://126174900723501", CrackBright = "rbxassetid://92861858089952", SpikyCrater = "rbxassetid://71146205854637",
	DoubleRing = "rbxassetid://14186586240", JaggedRing = "rbxassetid://12402854196",
}
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular
local STREAK = Enum.ParticleOrientation.VelocityParallel
local UP = Enum.NormalId.Top

local function camDist(pos)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude or 0
end

-- a 4-point star with a horizontal anamorphic streak through it
local function flarePop(pos, color, size, life)
	life = life or 0.4
	local c = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	burst(pos, {
		Texture = TX.FourStar, Color = c, Speed = NumberRange.new(0), Size = NS(0, 0, 0.25, size, 1, 0),
		Lifetime = NumberRange.new(life), Rotation = NumberRange.new(-8, 8), Brightness = 2.5, ZOffset = 1,
	}, 1, life + 0.3)
	burst(pos, {
		Texture = TX.Anamorphic, Color = c, Speed = NumberRange.new(0), Size = NS(0, 0, 0.25, size * 2.4, 1, 0),
		Transparency = NS(0.2), Lifetime = NumberRange.new(life * 0.85), Brightness = 2, ZOffset = 1,
	}, 1, life + 0.3)
end

-- flat rings stacked at several heights, popping one after another (the "ascend" halo)
local function haloStack(pos, color, count, size, gap, life)
	life = life or 0.55
	for i = 1, count do
		task.delay((i - 1) * 0.06, function()
			local k = 1 - (i - 1) * 0.18
			burst(pos + Vector3.new(0, (i - 1) * gap, 0), {
				Texture = TX.Halo, Color = ColorSequence.new(color), Orientation = FLAT, EmissionDirection = UP,
				Speed = NumberRange.new(0.01), Size = NS(0, size * 0.3 * k, 0.4, size * k, 1, size * 1.1 * k),
				Transparency = NS(0, 0.1, 0.6, 0.35, 1, 1), Lifetime = NumberRange.new(life), Rotation = NumberRange.new(0, 360),
				Brightness = 2,
			}, 1, life + 0.4)
		end)
	end
end

-- rainbow-edged slivers flying out
local function chroma(pos, count, speed)
	burst(pos, {
		Texture = TX.Chroma, Color = ColorSequence.new(WHITE), Orientation = STREAK, Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = Vector2.new(180, 180), Drag = 3, Size = NS(0, 0, 0.2, 1.4, 1, 0), Squash = NS(0, -1, 1, 2),
		Lifetime = NumberRange.new(0.35, 0.6), Brightness = 2,
	}, reduced() and math.ceil(count / 3) or count, 1.2)
end

-- dark, non-glowing smoke that lingers after a bright hit (value contrast)
local function darkLinger(pos, color, size, count)
	burst(pos, {
		Texture = T.Smoke, Color = ColorSequence.new(color), LightEmission = 0, LightInfluence = 0.8,
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 25), Size = NS(0, size * 0.4, 1, size),
		Transparency = NS(0, 1, 0.15, 0.45, 1, 1), Lifetime = NumberRange.new(1.2, 1.8), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25), Drag = 1.5,
	}, count or 5, 2.5)
end

-- warning circle on the ground while something is falling
local function telegraph(pos, color, texture, size, delay)
	if delay <= 0.05 or camDist(pos) > 300 then
		return
	end
	burst(pos + Vector3.new(0, 0.25, 0), {
		Texture = texture, Color = ColorSequence.new(color), Orientation = FLAT, EmissionDirection = UP,
		Speed = NumberRange.new(0.01), Size = NS(0, size * 0.25, 1, size), Transparency = NS(0, 0.9, 0.8, 0.25, 1, 0.6),
		Lifetime = NumberRange.new(delay), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(40, 70), Brightness = 1.5,
	}, 1, delay + 0.2)
end

---------------------------------------------------------------- screen tint: a coloured edge vignette per event + pulses on big hits
local screen = Instance.new("ScreenGui")
screen.Name = "WeatherScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = -6
local vigEdges = {}
for _, spec in {
	{ UDim2.new(1, 0, 0.32, 0), UDim2.fromScale(0, 0), 90 },
	{ UDim2.new(1, 0, 0.32, 0), UDim2.fromScale(0, 0.68), -90 },
	{ UDim2.new(0.24, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
	{ UDim2.new(0.24, 0, 1, 0), UDim2.fromScale(0.76, 0), 180 },
} do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = spec[1]
	f.Position = spec[2]
	f.BackgroundTransparency = 1
	f.BackgroundColor3 = WHITE
	local g = Instance.new("UIGradient")
	g.Rotation = spec[3]
	g.Transparency = NS(0, 0, 1, 1)
	g.Parent = f
	f.Parent = screen
	table.insert(vigEdges, f)
end
screen.Parent = player:WaitForChild("PlayerGui")

local pulse = { color = WHITE, amount = 0 }
local function tintPulse(color, amount)
	if amount >= pulse.amount then
		pulse.color = color
	end
	pulse.amount = math.max(pulse.amount, amount)
end
RunService.RenderStepped:Connect(function(dt)
	pulse.amount = math.max(0, pulse.amount - dt * 2.2)
	local look = active and active.look or lightingState.look
	local w = active and active.weight or lightingState.w
	local v = look and look.Vignette
	local base = v and v[2] * w or 0
	if v and look.VignettePulse then
		base *= 1 + look.VignettePulse(os.clock())
	end
	local total = math.clamp(base + pulse.amount, 0, 0.8)
	local col = v and v[1] or pulse.color
	if pulse.amount > 0 then
		col = col:Lerp(pulse.color, math.clamp(pulse.amount / math.max(total, 0.01), 0, 1))
	end
	for _, f in vigEdges do
		f.BackgroundColor3 = col
		f.BackgroundTransparency = 1 - total
	end
end)

---------------------------------------------------------------- strike beats: telegraph while falling -> flash -> halo -> linger
local STRIKE = {
	Lightning = { color = hex("BFF1FF"), deep = hex("1A2A40"), tint = hex("9FEAFF"), flare = 18, halo = 20, gap = 3.5 },
	Meteor = { color = hex("FFB060"), deep = hex("2A1610"), tint = hex("FF6A1F"), flare = 22, halo = 24, gap = 4 },
	Hail = { color = hex("DFFBFF"), deep = hex("3A5A70"), tint = hex("BFF4FF"), flare = 10, halo = 12, gap = 2.2 },
}

local function strikeCharge(kind, pos, delay)
	if kind == "Lightning" then
		telegraph(pos, hex("9FEAFF"), TX.GlowRing, 11, delay)
		task.delay(math.max(0, delay - 0.15), function()
			flarePop(pos + Vector3.new(0, 2, 0), hex("CFF6FF"), 5, 0.18) -- the charge glint
		end)
	elseif kind == "Meteor" then
		telegraph(pos, hex("FF8A2A"), TX.CrackBright, 18, delay)
	elseif kind == "Hail" then
		telegraph(pos, hex("BFF4FF"), TX.Octagon, 9, delay)
	end
end

local function strikePlus(kind, pos)
	local k = STRIKE[kind]
	local d = camDist(pos)
	if not k or d > 450 then
		return
	end
	flarePop(pos + Vector3.new(0, 3, 0), k.color, k.flare, 0.35)
	if d > 260 then
		return
	end
	local near = math.clamp(1 - d / 260, 0, 1)
	haloStack(pos + Vector3.new(0, 0.6, 0), k.color, 3, k.halo, k.gap, 0.5)
	if kind ~= "Meteor" then
		chroma(pos + Vector3.new(0, 1.5, 0), 14, 40)
	end
	task.delay(0.15, function()
		darkLinger(pos + Vector3.new(0, 1, 0), k.deep, kind == "Meteor" and 18 or 11, kind == "Meteor" and 7 or 4)
	end)
	tintPulse(k.tint, 0.35 * near)
	if kind == "Meteor" then
		-- the crater keeps burning for a few seconds
		local p = newPart("CraterFire", Vector3.new(8, 0.4, 8))
		p.Position = pos + Vector3.new(0, 0.4, 0)
		local pe = emitter(p, {
			Texture = TX.FlameFlip, Color = CS({ "#FFE08A", "#FF6A1F", "#B81E00" }),
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Size = NS(0, 2.5, 0.5, 4, 1, 1), Transparency = NS(0, 0.1, 0.8, 0.3, 1, 1), Lifetime = NumberRange.new(0.7, 1),
			Speed = NumberRange.new(1, 3), EmissionDirection = UP, Acceleration = Vector3.new(0, 4, 0), Brightness = 1.5,
			Rate = reduced() and 6 or 16,
		})
		task.delay(3.5, function()
			pe.Enabled = false
		end)
		Debris:AddItem(p, 5)
	end
end

local function lightningBolt(pos, scale, color)
	local top = pos + Vector3.new(0, 48 * scale, 0)
	local textures = { T.BoltBranch, T.BoltBlue, T.BoltThin, T.BoltBranch2 }
	for i = 1, 2 do
		task.delay((i - 1) * 0.07, function()
			burst(top, {
				Texture = textures[rng:NextInteger(1, #textures)],
				Color = ColorSequence.new(color or hex("D8F6FF")),
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				Speed = NumberRange.new(0), Size = NS(100 * scale),
				Transparency = NS(0, 0, 0.6, 0.1, 1, 1), Lifetime = NumberRange.new(0.16, 0.22),
				LightEmission = 1, Brightness = 3, ZOffset = 2,
			}, 1, 1)
		end)
	end
end

local function lightningStrike(pos, delay, mutation)
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - pos).Magnitude or 0
	-- charge-up glow on the spot
	burst(pos + Vector3.new(0, 1.5, 0), {
		Texture = T.BoltBall, Color = ColorSequence.new(hex("9FEAFF")), Speed = NumberRange.new(0),
		Size = NS(0, 1, 1, 7), Transparency = NS(0, 0.6, 1, 0.1), Lifetime = NumberRange.new(delay), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
	}, 2, delay + 0.3)
	strikeCharge("Lightning", pos, delay)
	task.wait(delay)
	lightningBolt(pos, 1)
	flash = math.max(flash, 0.55 * math.clamp(1 - dist / 500, 0.15, 1))
	local lp = newPart("BoltLight", Vector3.new(1, 1, 1))
	lp.Position = pos + Vector3.new(0, 8, 0)
	local light = Instance.new("PointLight")
	light.Color = hex("BFF1FF")
	light.Range = 60
	light.Brightness = 10
	light.Shadows = true
	light.Parent = lp
	TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()
	Debris:AddItem(lp, 0.6)
	groundDecal(pos, 16, T.BoltRadial, hex("9FEAFF"), 1.2, 1.5, 0)
	groundDecal(pos, 9, T.Crater, hex("1A1A22"), 3, 2, 0.25)
	groundRing(pos, hex("CFF6FF"), 26, 0.45)
	burst(pos + Vector3.new(0, 0.5, 0), {
		Texture = T.Sparks, Color = ColorSequence.new(hex("BFF1FF"), hex("2E7BFF")), Speed = NumberRange.new(18, 35),
		SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -60, 0),
		Size = NS(0.5, 0), Lifetime = NumberRange.new(0.4, 0.8),
	}, reduced() and 10 or 30, 2)
	burst(pos + Vector3.new(0, 1, 0), {
		Texture = T.CloudPuff, Color = ColorSequence.new(hex("8A93A6")), LightEmission = 0, LightInfluence = 1,
		Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(180, 30), Size = NS(3, 8), Transparency = NS(0, 0.5, 1, 1),
		Lifetime = NumberRange.new(1.2, 1.8), Rotation = NumberRange.new(0, 360),
	}, 6, 3)
	soundAt(S.Thunder, pos, { MaxDist = 900, MinDist = 60 })
	shake(1, 0.45, pos)
	strikePlus("Lightning", pos)
end

LOOKS.Thunderstorm = {
	Tint = hex("A9B6D2"), Saturation = -0.45, Contrast = 0.14, Brightness = -0.06, Dark = 0.9, Ambient = hex("4A5672"),
	AtmoColor = hex("7D879A"), AtmoDecay = hex("4A505E"), Haze = 2.5, Glare = -0.1, Density = 0.22,
	Build = function(ctx)
		rain(ctx, hex("C2D8FF"), 420, 2.8, 125)
		ctx.emit("Near", {
			Name = "CloseRain", Texture = T.RainDrop, Color = ColorSequence.new(hex("DCEBFF")),
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, EmissionDirection = Enum.NormalId.Bottom,
			Speed = NumberRange.new(110, 130), Lifetime = NumberRange.new(0.3, 0.35), Size = NS(1.6), Squash = NS(2),
			Transparency = NS(0.3), LightEmission = 0.6, Rate = 160,
		})
		ctx.emit("Ground", {
			Name = "Splash", Texture = T.Shockwave, Color = ColorSequence.new(hex("DCEBFF")),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01), Size = NS(0, 0.1, 1, 1.4), Transparency = NS(0, 0.35, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.4), LightEmission = 0.4, LightInfluence = 0.6, Rate = 160,
		})
		ctx.emit("High", {
			Name = "StormClouds", Texture = T.CloudBig, Color = CS({ "#3A4152", "#262B38" }), LightEmission = 0, LightInfluence = 0.3,
			Size = NS(0, 90, 0.5, 130, 1, 140), Transparency = NS(0, 1, 0.2, 0.1, 0.8, 0.1, 1, 1), Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Front,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-4, 4), Rate = 16,
		})
		ctx.loop(S.Rain)
		-- distant flashes and rolling thunder
		ctx.every({ 3, 6.5 }, function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(160, 320)
			local pos = Vector3.new(cam.CFrame.Position.X + math.cos(a) * r, groundY, cam.CFrame.Position.Z + math.sin(a) * r)
			lightningBolt(pos, 2.2, hex("E6F7FF"))
			flash = math.max(flash, 0.22)
			task.delay(rng:NextNumber(0.6, 1.6), function()
				playSound(S.ThunderFar, nil, { Volume = rng:NextNumber(0.6, 1), Pitch = rng:NextNumber(0.8, 1) })
			end)
		end)
	end,
}

LOOKS.Blizzard = {
	Tint = hex("E3F0FF"), Saturation = -0.25, Brightness = 0.06, Contrast = -0.03, Dark = 0.15, Ambient = hex("C8D8F0"),
	AtmoColor = hex("EAF4FF"), AtmoDecay = hex("DCE8F5"), Haze = 3, Glare = -0.1, Density = 0.3,
	Build = function(ctx, state)
		local wind = Vector3.new(-26, -7, 9)
		ctx.emit("Near", {
			Name = "Snow", Texture = T.Snowflake, Color = ColorSequence.new(WHITE), LightEmission = 0.4, LightInfluence = 0.5,
			Size = NS(0, 0.35, 1, 0.25), Transparency = NS(0, 0.1, 1, 0.6), Lifetime = NumberRange.new(2.2, 3),
			Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), Acceleration = wind,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Rate = 160,
		})
		ctx.emit("Near", {
			Name = "SnowDots", Texture = T.SoftDot, Color = ColorSequence.new(WHITE), LightEmission = 0.5,
			Size = NS(0.18), Transparency = NS(0.15), Lifetime = NumberRange.new(2, 2.8), Speed = NumberRange.new(3, 8),
			SpreadAngle = Vector2.new(180, 180), Acceleration = wind * 1.4, Rate = 260,
		})
		ctx.emit("Near", {
			Name = "WindStreaks", Texture = T.Streak, Color = ColorSequence.new(WHITE), LightEmission = 0.6,
			Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Left,
			Size = NS(0, 1.2, 0.5, 2.2, 1, 0.8), Transparency = NS(0, 1, 0.3, 0.55, 1, 1), Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(55, 75), Rate = 26,
		})
		ctx.emit("Ground", {
			Name = "GroundMist", Texture = T.CloudPuff, Color = ColorSequence.new(hex("F4FAFF")), LightEmission = 0.2, LightInfluence = 0.8,
			Size = NS(0, 10, 1, 22), Transparency = NS(0, 1, 0.3, 0.55, 1, 1), Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Left, Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-10, 10), Rate = 14,
		})
		ctx.loop(S.Wind)
		-- frost creeping in at the screen edges
		local gui = Instance.new("ScreenGui")
		gui.Name = "WeatherFrost"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = -5
		local edges = {}
		for _, spec in { { 0, UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 }, { 1, UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90 },
			{ 2, UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 }, { 3, UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 } } do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = hex("E8F6FF")
			f.Size = spec[2]
			f.Position = spec[3]
			f.BackgroundTransparency = 1
			local g = Instance.new("UIGradient")
			g.Rotation = spec[4]
			g.Transparency = NS(0, 0.35, 1, 1)
			g.Parent = f
			f.Parent = gui
			table.insert(edges, f)
		end
		gui.Parent = player:WaitForChild("PlayerGui")
		table.insert(state.cleanup, gui)
		state.edges = edges
	end,
	Update = function(state)
		for _, f in state.edges or {} do
			f.BackgroundTransparency = 1 - 0.75 * state.weight
		end
	end,
}

local function meteor(pos, delay, mutation)
	local cam = workspace.CurrentCamera
	local from = pos + Vector3.new(-95, 170, 45)
	local ball = newPart("Meteor", Vector3.new(4.5, 4.5, 4.5))
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = hex("FF8A2A")
	ball.Transparency = 0
	ball.CFrame = CFrame.lookAt(from, pos)
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 1.6, 0)
	att0.Parent = ball
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -1.6, 0)
	att1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = att0, att1
	trail.Texture = T.MagmaRibbon
	trail.Color = CS({ "#FFE08A", "#FF6A1F", "#5A1A08" })
	trail.Transparency = NS(0, 0, 1, 1)
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.WidthScale = NS(1, 0.2)
	trail.FaceCamera = true
	trail.Parent = ball
	emitter(ball, {
		Texture = T.Fire, Color = CS({ "#FFE08A", "#FF6A1F", "#B81E00" }), Size = NS(5, 1), Transparency = NS(0.1, 1),
		Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(1, 3), Rate = 70, Shape = Enum.ParticleEmitterShape.Sphere,
	})
	emitter(ball, {
		Texture = T.CloudPuff, Color = ColorSequence.new(hex("3A2A28")), LightEmission = 0, LightInfluence = 1,
		Size = NS(3, 8), Transparency = NS(0.3, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5), Rate = 24,
		Rotation = NumberRange.new(0, 360),
	})
	local light = Instance.new("PointLight")
	light.Color = hex("FF8A2A")
	light.Range = 40
	light.Brightness = 4
	light.Parent = ball
	soundAt(S.ThunderFar, from, { Pitch = 1.6, Volume = 0.5, MaxDist = 600 })
	strikeCharge("Meteor", pos, delay)
	local start = os.clock()
	while os.clock() - start < delay do
		local t = (os.clock() - start) / delay
		ball.CFrame = CFrame.lookAt(from:Lerp(pos, t * t * (0.6 + 0.4 * t) / 1), pos)
		RunService.RenderStepped:Wait()
	end
	ball:Destroy()
	-- impact
	burst(pos + Vector3.new(0, 4, 0), {
		Texture = T.FireExplosion, Color = CS({ "#FFE08A", "#FF7A1F" }), Speed = NumberRange.new(0), Size = NS(0, 6, 0.3, 28, 1, 34),
		Transparency = NS(0, 0, 0.6, 0.2, 1, 1), Lifetime = NumberRange.new(0.55), Rotation = NumberRange.new(0, 360),
	}, 1, 2)
	groundRing(pos, hex("FFB060"), 40, 0.6)
	groundDecal(pos, 20, T.Crater, hex("2A1610"), 6, 3, 0)
	groundDecal(pos, 15, T.LavaCracks, hex("FF7A1F"), 5, 3, 0)
	burst(pos + Vector3.new(0, 1, 0), {
		Texture = T.Sparks, Color = CS({ "#FFE08A", "#FF6A1F" }), Speed = NumberRange.new(25, 50), SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -70, 0), Size = NS(0.7, 0), Lifetime = NumberRange.new(0.6, 1.1),
	}, reduced() and 14 or 45, 2.5)
	burst(pos + Vector3.new(0, 2, 0), {
		Texture = T.Smoke, Color = ColorSequence.new(hex("4A3A36")), LightEmission = 0, LightInfluence = 1, Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top, Size = NS(5, 16), Transparency = NS(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(2, 3), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
	}, 8, 4)
	-- rock chunks
	if not reduced() then
		for _ = 1, 6 do
			local rock = Instance.new("Part")
			rock.Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.6, 1.4)
			rock.Material = Enum.Material.Basalt
			rock.Color = hex("3A2420")
			rock.CanCollide = false
			rock.CanQuery = false
			rock.CanTouch = false
			rock.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
			rock.Parent = folder
			rock.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(30, 50), rng:NextNumber(-25, 25))
			rock.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
			Debris:AddItem(rock, 2)
		end
	end
	local dist = cam and (cam.CFrame.Position - pos).Magnitude or 0
	flash = math.max(flash, 0.3 * math.clamp(1 - dist / 400, 0.1, 1))
	soundAt(S.Boom, pos, { MaxDist = 800, MinDist = 50 })
	shake(1.4, 0.6, pos)
	strikePlus("Meteor", pos)
end

LOOKS.MeteorShower = {
	Tint = hex("FFD6BF"), Saturation = 0.05, Contrast = 0.1, Dark = 0.45, Ambient = hex("7A4A5A"), Clock = 19.1,
	AtmoColor = hex("FF9F7A"), AtmoDecay = hex("8A4A3A"), Haze = 1.5, Glare = 0.4, Stars = 4000, Density = 0.08,
	Build = function(ctx)
		ctx.emit("Streak", {
			Name = "ShootingStars", Texture = T.RainThin, Color = CS({ "#FFFFFF", "#FFB060" }),
			Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Bottom,
			Speed = NumberRange.new(150, 210), Size = NS(0, 4, 0.5, 7, 1, 2), Squash = NS(2.5),
			Transparency = NS(0, 1, 0.15, 0, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Rate = 7,
		})
		ctx.emit("Near", {
			Name = "Embers", Texture = T.Sparks, Color = CS({ "#FFE08A", "#FF6A1F" }), Size = NS(0, 0.3, 0.5, 0.25, 1, 0),
			Transparency = NS(0, 0, 1, 1), Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(4, -3, 0), Rate = 40,
		})
		ctx.emit("High", {
			Name = "AshClouds", Texture = T.CloudBig, Color = CS({ "#6A3A3A", "#3A2028" }), LightEmission = 0, LightInfluence = 0.4,
			Size = NS(0, 60, 1, 90), Transparency = NS(0, 1, 0.3, 0.35, 0.8, 0.35, 1, 1), Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Front, Rotation = NumberRange.new(0, 360), Rate = 4,
		})
		ctx.loop(S.DeepWind, 0.8)
		-- streaks far off in the sky, for show
		ctx.every({ 2, 4 }, function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(200, 330)
			task.spawn(meteor, Vector3.new(cam.CFrame.Position.X + math.cos(a) * r, groundY, cam.CFrame.Position.Z + math.sin(a) * r), 1.4)
		end)
	end,
}

local function hailChunk(pos, delay, mutation)
	local from = pos + Vector3.new(10, 75, -6)
	local gem = newPart("Hail", Vector3.new(3.4, 5, 3.4))
	gem.Transparency = 0.15
	gem.Material = Enum.Material.Glass
	gem.Color = hex("BFF4FF")
	gem.Reflectance = 0.4
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = gem
	local core = newPart("Core", Vector3.new(1.8, 3, 1.8), gem)
	core.Transparency = 0
	core.Material = Enum.Material.Neon
	core.Color = hex("7FDFFF")
	local m2 = mesh:Clone()
	m2.Parent = core
	emitter(gem, {
		Texture = T.BlueGlint, Color = CS({ "#FFFFFF", "#7FDFFF" }), Size = NS(0, 1.6, 1, 0), Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(0), Rate = 25, Rotation = NumberRange.new(0, 90),
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.9, 0, 0)
	a0.Parent = gem
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.9, 0, 0)
	a1.Parent = gem
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(hex("CFF8FF"))
	trail.Transparency = NS(0.3, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = gem
	strikeCharge("Hail", pos, delay)
	local start = os.clock()
	local spin = rng:NextNumber(-8, 8)
	while os.clock() - start < delay do
		local t = (os.clock() - start) / delay
		local p = from:Lerp(pos + Vector3.new(0, 1.5, 0), t * t)
		gem.CFrame = CFrame.new(p) * CFrame.Angles(t * spin, t * spin * 0.7, 0)
		core.CFrame = gem.CFrame
		RunService.RenderStepped:Wait()
	end
	gem:Destroy()
	burst(pos + Vector3.new(0, 2, 0), {
		Texture = T.ShardBurst, Color = CS({ "#FFFFFF", "#9FEAFF" }), Speed = NumberRange.new(0), Size = NS(0, 3, 0.4, 20, 1, 22),
		Transparency = NS(0, 0, 0.6, 0.2, 1, 1), Lifetime = NumberRange.new(0.45), Rotation = NumberRange.new(0, 360),
	}, 1, 2)
	burst(pos + Vector3.new(0, 0.4, 0), {
		Texture = T.CrystalSpikes, Color = CS({ "#FFFFFF", "#7FDFFF" }), Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Size = NS(0, 1, 0.3, 15, 1, 16),
		Transparency = NS(0, 0, 0.7, 0.3, 1, 1), Lifetime = NumberRange.new(1.4), Rotation = NumberRange.new(0, 360),
	}, 1, 2.5)
	groundRing(pos, hex("CFF8FF"), 26, 0.45)
	flash = math.max(flash, 0.12)
	local lp = newPart("HailLight", Vector3.new(1, 1, 1))
	lp.Position = pos + Vector3.new(0, 4, 0)
	local light = Instance.new("PointLight")
	light.Color = hex("BFF4FF")
	light.Range = 30
	light.Brightness = 6
	light.Parent = lp
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	Debris:AddItem(lp, 0.6)
	if not reduced() then
		for _ = 1, 7 do
			local shard = Instance.new("Part")
			shard.Size = Vector3.new(0.4, 0.9, 0.4) * rng:NextNumber(0.7, 1.4)
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.2
			shard.Color = hex("BFF4FF")
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
			shard.Parent = folder
			shard.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(18, 32), rng:NextNumber(-18, 18))
			shard.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
			Debris:AddItem(shard, 1.6)
		end
	end
	soundAt(S.Shatter, pos, { MaxDist = 250, MinDist = 20 })
	shake(0.5, 0.3, pos)
	strikePlus("Hail", pos)
end

LOOKS.CrystalHail = {
	Tint = hex("D3EEFF"), Saturation = -0.2, Brightness = 0.02, Contrast = 0.08, Dark = 0.4, Ambient = hex("8FB8D6"),
	AtmoColor = hex("CDEEFF"), AtmoDecay = hex("9CCBEA"), Haze = 2, Glare = 0.3, Density = 0.14,
	Build = function(ctx)
		ctx.emit("Sky", {
			Name = "Shards", Texture = T.Diamond, Color = CS({ "#FFFFFF", "#9FEAFF" }), EmissionDirection = Enum.NormalId.Bottom,
			Size = NS(0.75), Lifetime = NumberRange.new(0.65, 0.8), Speed = NumberRange.new(65, 80), LightEmission = 1,
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400), Rate = 110,
		})
		ctx.emit("Near", {
			Name = "Glints", Texture = T.CrossGlint, Color = CS({ "#FFFFFF", "#B8F4FF" }), Size = NS(0, 0, 0.5, 0.9, 1, 0),
			Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 90), Rate = 30,
		})
		ctx.emit("Ground", {
			Name = "ShardHits", Texture = T.ShardBurst, Color = ColorSequence.new(hex("DFFBFF")), Size = NS(0, 0, 0.3, 1.1, 1, 1.3),
			Transparency = NS(0, 0.2, 1, 1), Lifetime = NumberRange.new(0.2, 0.3), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), Rate = 70,
		})
		ctx.loop(S.LightRain, 1.3)
	end,
}

LOOKS.RainbowAurora = {
	Tint = hex("F1E6FF"), Saturation = 0.3, Brightness = 0.02, Dark = 0.4, Ambient = hex("6A5A9A"), Clock = 21.6, Stars = 6000,
	AtmoColor = hex("C8B8FF"), AtmoDecay = hex("6A4AA8"), Haze = 0.3, Glare = 0.5,
	Build = function(ctx)
		ctx.curtains(5, {
			Texture = T.Aurora, Transparency = 0.25, Brightness = 4,
			Color = CS({ "#FF4D4D", "#FFE84D", "#4DFF88", "#4DD8FF", "#C44DFF", "#FF4DC4" }),
		})
		ctx.emit("Near", {
			Name = "PrismMotes", Texture = T.PrismSparkles, Color = ColorSequence.new(WHITE), Size = NS(0, 0, 0.3, 1.6, 1, 0),
			Transparency = NS(0, 0.1, 1, 1), Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(0.3, 1.5),
			SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Rate = 22,
		})
		ctx.emit("Near", {
			Name = "ColorStars", Texture = T.ColorStars, Color = ColorSequence.new(WHITE), Size = NS(0, 0, 0.5, 0.8, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 90), Rate = 18,
		})
		ctx.every({ 8, 13 }, function()
			playSound(S.Twinkle, nil, { Volume = 0.8, Pitch = rng:NextNumber(0.85, 1.1) })
		end)
	end,
}

LOOKS.BloodMoon = {
	Tint = hex("FFB3B3"), Saturation = -0.12, Contrast = 0.16, Brightness = -0.02, Dark = 0.65, Ambient = hex("5A1020"), Clock = 0, HideSun = true,
	AtmoColor = hex("7A1020"), AtmoDecay = hex("4A0A14"), Haze = 2, Glare = 0, Stars = 3000, Density = 0.12,
	Build = function(ctx)
		ctx.sky(SKY_DIR, 520, 150, {
			{ Image = T.SoftGlow, Color = hex("FF1F3D"), Scale = 2.6, Transparency = 0.3, Pulse = 1.4 },
			{ Image = T.Corona, Color = hex("FF3B4E"), Scale = 1.5, Spin = 3, Transparency = 0.35 },
			{ Image = T.Disc, Color = hex("D8142E"), Scale = 1, Transparency = 0 },
			{ Image = T.MoonShade, Color = hex("5A0010"), Scale = 1, Transparency = 0.45 },
		})
		ctx.emit("Ground", {
			Name = "BloodMist", Texture = T.CloudPuff, Color = CS({ "#A0102A", "#5A0010" }), LightEmission = 0.3, LightInfluence = 0.6,
			Size = NS(0, 12, 1, 24), Transparency = NS(0, 1, 0.3, 0.5, 1, 1), Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Left, Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-10, 10), Rate = 14,
		})
		ctx.emit("Near", {
			Name = "BloodEmbers", Texture = T.Sparks, Color = CS({ "#FF8A8A", "#FF1F3D" }), Size = NS(0, 0.25, 1, 0),
			Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 2.5, 0), Rate = 35,
		})
		ctx.loop(S.DeepWind, 0.6)
	end,
	Update = function(state)
		-- a slow heartbeat in the light
		flash = math.max(flash, (math.max(0, math.sin(os.clock() * 2.2)) ^ 8) * 0.06 * state.weight)
	end,
}

LOOKS.KaijuEclipse = {
	Tint = hex("D2C2FF"), Saturation = -0.25, Contrast = 0.14, Dark = 0.72, Ambient = hex("3A2A6A"), Clock = 23.5, HideSun = true,
	AtmoColor = hex("5A3AA0"), AtmoDecay = hex("2A1A50"), Haze = 1, Glare = 0, Stars = 8000,
	Build = function(ctx)
		ctx.sky(SKY_DIR + Vector3.new(0, 0.25, 0), 520, 170, {
			{ Image = T.SunRays, Color = hex("B78CFF"), Scale = 2.6, Spin = 5, Transparency = 0.35 },
			{ Image = T.Corona, Color = hex("E2D1FF"), Scale = 1.6, Spin = -8, Transparency = 0.05, Pulse = 1.2 },
			{ Image = T.Corona, Color = hex("9B5CFF"), Scale = 1.25, Spin = 12, Transparency = 0.15 },
			{ Image = T.Disc, Color = hex("05030A"), Scale = 1, Transparency = 0 },
		})
		ctx.sky(Vector3.new(-0.5, 0.6, -0.4), 600, 420, {
			{ Image = T.Galaxy, Color = hex("C9A6FF"), Scale = 1, Spin = 2, Transparency = 0.45 },
			{ Image = T.Galaxy, Color = hex("FF8AF0"), Scale = 0.7, Spin = -3, Transparency = 0.6 },
		})
		ctx.emit("High", {
			Name = "StarField", Texture = T.StarDust, Color = CS({ "#FFFFFF", "#C9A6FF" }), Size = NS(0, 0, 0.5, 14, 1, 0),
			Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), Rate = 10,
		})
		ctx.emit("High", {
			Name = "Twinkles", Texture = T.Star4, Color = CS({ "#FFFFFF", "#E2D1FF" }), Size = NS(0, 0, 0.5, 3, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(0), Rate = 40,
		})
		ctx.emit("Near", {
			Name = "Stardust", Texture = T.Sparkle, Color = CS({ "#FFFFFF", "#9B5CFF" }), Size = NS(0, 0, 0.3, 0.7, 1, 0),
			Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 3), EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -2, 0), Rotation = NumberRange.new(0, 360), Rate = 40,
		})
		ctx.loop(S.DeepWind, 0.5)
		shake(1.2, 1.2)
	end,
}

---------------------------------------------------------------- playbook add-ons per event (layered on top of each Build)
-- Each event gets: an edge vignette (Vignette = { colour, strength }), a dark light-balancing layer, a ground layer,
-- an accent sparkle / flare layer and a recurring "beat" (cloud flickers, gusts, rainbow comets, heartbeat rings...).
local ACCENT = {
	GoldenSunshower = hex("FFD84A"), Thunderstorm = hex("9FEAFF"), Blizzard = hex("E8F6FF"), MeteorShower = hex("FF8A2A"),
	CrystalHail = hex("9FEAFF"), RainbowAurora = hex("C44DFF"), BloodMoon = hex("FF1F3D"), KaijuEclipse = hex("9B5CFF"),
}
local VIGNETTE = {
	GoldenSunshower = { hex("FFB84A"), 0.16 }, Thunderstorm = { hex("060A16"), 0.42 }, MeteorShower = { hex("2A0800"), 0.34 },
	CrystalHail = { hex("BFEFFF"), 0.18 }, RainbowAurora = { hex("1E0A40"), 0.36 }, BloodMoon = { hex("3A0008"), 0.46 },
	KaijuEclipse = { hex("05030A"), 0.55 },
}
local function heartbeat(t)
	return math.max(0, math.sin(t * 2.2)) ^ 8
end

-- somewhere on the ground near the local player
local function nearGround(minR, maxR)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local c = hrp and hrp.Position or (cam and cam.CFrame.Position) or Vector3.zero
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(minR, maxR)
	return Vector3.new(c.X + math.cos(a) * r, groundY, c.Z + math.sin(a) * r)
end

local function emitterNamed(state, name)
	for _, e in state.emitters do
		if e.pe.Name == name then
			return e.pe
		end
	end
	return nil
end

local PLUS = {}

PLUS.GoldenSunshower = function(ctx)
	ctx.emit("Near", { -- slanted sun shafts
		Name = "SunShafts", Texture = T.LightColumn, Color = CS({ "#FFF6B0", "#FFD23F" }),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp, Speed = NumberRange.new(0.001), Size = NS(0, 9, 0.5, 12, 1, 9),
		Transparency = NS(0, 1, 0.4, 0.84, 0.7, 0.84, 1, 1), Lifetime = NumberRange.new(3, 5), Rotation = NumberRange.new(-12, -6),
		Brightness = 1, Rate = 2.5,
	})
	ctx.emit("Ground", { -- floor stars where the gold rain lands
		Name = "FloorStars", Texture = TX.FourStar, Color = CS({ "#FFFFFF", "#FFD23F" }), Speed = NumberRange.new(0.001),
		Size = NS(0, 0, 0.3, 2.2, 1, 0), Lifetime = NumberRange.new(0.4, 0.8), Rotation = NumberRange.new(-10, 10),
		Brightness = 2, Rate = 30,
	})
	ctx.emit("Near", { -- streaky glitter
		Name = "GoldStreaks", Texture = T.Glitter, Color = CS({ "#FFFFFF", "#FFC21F" }), Orientation = STREAK,
		EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(8, 14), Size = NS(0, 0, 0.25, 0.9, 1, 0),
		Squash = NS(0, -1, 1, 3), Lifetime = NumberRange.new(0.6, 1), Brightness = 1.5, Rate = 18,
	})
	ctx.every({ 2.5, 5 }, function() -- a coin glint popping on the ground near you
		flarePop(nearGround(6, 30) + Vector3.new(0, 1.2, 0), hex("FFE27A"), 5, 0.35)
	end)
end

PLUS.Thunderstorm = function(ctx)
	ctx.emit("Near", { -- dark drifting storm fog (light balancing under the bolts)
		Name = "StormFog", Texture = T.CloudPuff, Color = CS({ "#2A3040", "#1A1E2A" }), LightEmission = 0, LightInfluence = 0.6,
		Speed = NumberRange.new(2, 5), EmissionDirection = Enum.NormalId.Left, Size = NS(0, 8, 1, 18),
		Transparency = NS(0, 1, 0.3, 0.72, 1, 1), Lifetime = NumberRange.new(4, 6), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8), Rate = 5,
	})
	for n, tex in { TX.Arc1, TX.Arc2 } do -- static crackling on the wet ground
		ctx.emit("Ground", {
			Name = "StaticArcs" .. n, Texture = tex, Color = CS({ "#FFFFFF", "#7FE8FF" }), Speed = NumberRange.new(0),
			Size = NS(0, 1.2, 1, 2.4), Transparency = NS(0, 0, 0.7, 0.2, 1, 1), Rotation = NumberRange.new(0, 360),
			Lifetime = NumberRange.new(0.1, 0.18), Brightness = 2, Rate = 2.5,
		})
	end
	ctx.every({ 1.8, 4 }, function() -- lightning flickering inside the clouds
		local p = rigs.High.Position + Vector3.new(rng:NextNumber(-220, 220), rng:NextNumber(-5, 10), rng:NextNumber(-220, 220))
		for n = 1, rng:NextInteger(1, 3) do
			task.delay((n - 1) * rng:NextNumber(0.06, 0.12), function()
				burst(p, {
					Texture = T.SoftGlow, Color = ColorSequence.new(hex("C8E6FF")), Speed = NumberRange.new(0),
					Size = NS(rng:NextNumber(90, 150)), Transparency = NS(0, 0.45, 1, 1), Lifetime = NumberRange.new(0.12),
					Brightness = 1.5,
				}, 1, 0.5)
				flash = math.max(flash, 0.04)
			end)
		end
	end)
end

PLUS.Blizzard = function(ctx, state)
	ctx.emit("Ground", { -- snow blowing low along the ground
		Name = "SnowDrift", Texture = T.Streak, Color = ColorSequence.new(WHITE), Orientation = STREAK,
		EmissionDirection = Enum.NormalId.Left, Speed = NumberRange.new(25, 40), Size = NS(0, 0.4, 0.5, 1.4, 1, 0.3),
		Transparency = NS(0, 1, 0.3, 0.45, 1, 1), Lifetime = NumberRange.new(0.8, 1.2), LightEmission = 0.6, Rate = 30,
	})
	ctx.emit("Near", { -- ice glints catching the light
		Name = "IceGlints", Texture = T.BlueGlint, Color = CS({ "#FFFFFF", "#BFEFFF" }), Speed = NumberRange.new(0.001),
		Size = NS(0, 0, 0.4, 0.8, 1, 0), Lifetime = NumberRange.new(0.3, 0.6), Rotation = NumberRange.new(0, 45),
		Brightness = 1.5, Rate = 14,
	})
	ctx.emit("Ground", { -- frost spreading on the floor
		Name = "FrostFloor", Texture = TX.FrostRing, Color = CS({ "#FFFFFF", "#BFEFFF" }), Orientation = FLAT,
		EmissionDirection = UP, Speed = NumberRange.new(0.01), Size = NS(0, 2, 1, 7), Transparency = NS(0, 1, 0.3, 0.7, 1, 1),
		Lifetime = NumberRange.new(2.5, 3.5), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
		LightEmission = 0.5, Rate = 3,
	})
	ctx.every({ 6, 10 }, function() -- a gust: streaks sweep past, the screen whitens a moment
		local streaks = emitterNamed(state, "WindStreaks")
		if streaks then
			streaks:Emit(reduced() and 12 or 40)
		end
		local snow = emitterNamed(state, "SnowDots")
		if snow then
			snow:Emit(reduced() and 40 or 140)
		end
		tintPulse(hex("F4FAFF"), 0.28)
		shake(0.25, 0.6)
		playSound(S.DeepWind, nil, { Volume = 0.6, Pitch = 1.35 })
	end)
end

PLUS.MeteorShower = function(ctx)
	ctx.emit("Near", { -- falling ash (dark, non-glowing: the contrast under the fire)
		Name = "Ash", Texture = T.SoftDot, Color = CS({ "#3A2622", "#1A100E" }), LightEmission = 0, LightInfluence = 1,
		Size = NS(0, 0.22, 1, 0.12), Transparency = NS(0, 0.2, 1, 0.8), Lifetime = NumberRange.new(2.5, 4),
		Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(2, -3, 1),
		Rotation = NumberRange.new(0, 360), Rate = 55,
	})
	ctx.emit("Ground", { -- hot glow patches on the ground
		Name = "HeatGlow", Texture = T.SoftGlow, Color = CS({ "#FF8A2A", "#B81E00" }), Orientation = FLAT,
		EmissionDirection = UP, Speed = NumberRange.new(0.01), Size = NS(0, 8, 1, 16), Transparency = NS(0, 1, 0.4, 0.82, 1, 1),
		Lifetime = NumberRange.new(3, 4), Rotation = NumberRange.new(0, 360), Rate = 2,
	})
	ctx.emit("Near", { -- ember streaks
		Name = "EmberStreaks", Texture = T.Sparks, Color = CS({ "#FFFFFF", "#FFB060", "#FF4A1A" }), Orientation = STREAK,
		Speed = NumberRange.new(10, 20), SpreadAngle = Vector2.new(30, 30), EmissionDirection = UP,
		Acceleration = Vector3.new(6, 4, 0), Size = NS(0, 0, 0.2, 0.5, 1, 0), Squash = NS(0, -1, 1, 3),
		Lifetime = NumberRange.new(0.5, 0.9), Brightness = 1.5, Rate = 14,
	})
end

PLUS.CrystalHail = function(ctx)
	ctx.emit("Near", { -- chromatic slivers drifting in the air
		Name = "ChromaDrift", Texture = TX.Chroma, Color = ColorSequence.new(WHITE), Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180), Size = NS(0, 0, 0.3, 0.9, 1, 0), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60), Lifetime = NumberRange.new(0.6, 1.1), Brightness = 1.5, Rate = 12,
	})
	ctx.emit("Ground", { -- prism glints across the floor
		Name = "FloorPrisms", Texture = TX.PrismRays, Color = ColorSequence.new(WHITE), Speed = NumberRange.new(0.001),
		Size = NS(0, 0, 0.3, 1.6, 1, 0), Rotation = NumberRange.new(0, 360), Lifetime = NumberRange.new(0.35, 0.6),
		Brightness = 1.5, Rate = 18,
	})
	ctx.emit("Ground", { -- cold blue haze low on the ground (keeps the bright shards readable)
		Name = "IceHaze", Texture = T.CloudPuff, Color = CS({ "#5A8AAA", "#2A4A66" }), LightEmission = 0, LightInfluence = 0.7,
		Size = NS(0, 8, 1, 16), Transparency = NS(0, 1, 0.3, 0.75, 1, 1), Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Left, Rotation = NumberRange.new(0, 360), Rate = 6,
	})
end

PLUS.RainbowAurora = function(ctx, state)
	state.floor = ctx.emit("Ground", { -- the aurora reflected on the floor
		Name = "FloorLights", Texture = T.SoftGlow, Color = ColorSequence.new(WHITE), Orientation = FLAT, EmissionDirection = UP,
		Speed = NumberRange.new(0.01), Size = NS(0, 12, 1, 22), Transparency = NS(0, 1, 0.4, 0.8, 1, 1),
		Lifetime = NumberRange.new(3, 4), Rotation = NumberRange.new(0, 360), Rate = 4,
	})
	ctx.emit("Near", { -- thin light ribbons rising
		Name = "Ribbons", Texture = T.Streak, Color = CS({ "#FF4D4D", "#FFE84D", "#4DFF88", "#4DD8FF", "#C44DFF" }),
		Orientation = STREAK, EmissionDirection = UP, Speed = NumberRange.new(3, 6), Size = NS(0, 0, 0.3, 0.8, 1, 0),
		Squash = NS(0, -1, 1, 3), Lifetime = NumberRange.new(1, 1.8), Brightness = 1.2, Rate = 10,
	})
	ctx.every({ 5, 9 }, function() -- a rainbow comet across the sky
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local p = cam.CFrame.Position + Vector3.new(rng:NextNumber(-180, 180), rng:NextNumber(110, 160), rng:NextNumber(-180, 180))
		local holder = newPart("Comet", Vector3.new(0.5, 0.5, 0.5))
		holder.CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(-20))
		local pe = emitter(holder, {
			Texture = T.Streak, Color = CS({ "#FFFFFF", "#4DD8FF", "#C44DFF" }), Orientation = STREAK,
			EmissionDirection = Enum.NormalId.Left, Speed = NumberRange.new(220, 260), Size = NS(0, 10, 1, 2),
			Squash = NS(4), Transparency = NS(0, 0, 1, 1), Lifetime = NumberRange.new(0.7), Brightness = 2, Rate = 0,
		})
		pe:Emit(1)
		Debris:AddItem(holder, 1.5)
		flarePop(p, hex("E6D4FF"), 14, 0.35)
	end)
	state.plusUpdate = function(st)
		if st.floor then
			local h = (os.clock() * 0.08) % 1
			st.floor.Color = ColorSequence.new(Color3.fromHSV(h, 0.6, 1), Color3.fromHSV((h + 0.25) % 1, 0.6, 1))
		end
	end
end

PLUS.BloodMoon = function(ctx, state)
	ctx.emit("Near", { -- dark crimson crescent wisps drifting past
		Name = "Crescents", Texture = TX.CrescentSmoke, Color = CS({ "#3A0008", "#1A0004" }), LightEmission = 0,
		LightInfluence = 0.5, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 40), Size = NS(0, 3, 1, 6),
		Transparency = NS(0, 1, 0.3, 0.55, 1, 1), Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(60, 120),
		Lifetime = NumberRange.new(2, 3), Rate = 6,
	})
	ctx.emit("Near", { -- red motes with a flare twinkle
		Name = "RedTwinkles", Texture = TX.FourStar, Color = CS({ "#FFB3B3", "#FF1F3D" }), Speed = NumberRange.new(0.001),
		Size = NS(0, 0, 0.4, 0.9, 1, 0), Lifetime = NumberRange.new(0.4, 0.7), Brightness = 1.5, Rate = 10,
	})
	-- a ring pulses out under you on every heartbeat
	local last = 0
	state.plusUpdate = function(st)
		local t = os.clock()
		if heartbeat(t) > 0.9 and t - last > 1.5 then
			last = t
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and st.weight > 0.5 then
				groundRing(Vector3.new(hrp.Position.X, groundY, hrp.Position.Z), hex("FF1F3D"), 22, 0.8, TX.SpikyCrater)
			end
		end
	end
end

PLUS.KaijuEclipse = function(ctx, state)
	ctx.emit("Near", { -- void wisps (the dark layer)
		Name = "VoidWisps", Texture = TX.Nebula, Color = CS({ "#14082E", "#05021A" }), LightEmission = 0, LightInfluence = 0.4,
		Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Size = NS(0, 6, 1, 12),
		Transparency = NS(0, 1, 0.3, 0.62, 1, 1), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15),
		Lifetime = NumberRange.new(3, 4.5), Rate = 5,
	})
	ctx.every({ 2.6, 3.2 }, function() -- a slow magic circle that keeps forming under you
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or (active and active.weight or 0) < 0.3 then
			return
		end
		burst(Vector3.new(hrp.Position.X, groundY + 0.3, hrp.Position.Z), {
			Texture = TX.MagicRing, Color = CS({ "#E2D1FF", "#9B5CFF" }), Orientation = FLAT, EmissionDirection = UP,
			Speed = NumberRange.new(0.01), Size = NS(0, 26, 1, 30), Transparency = NS(0, 1, 0.3, 0.68, 0.7, 0.68, 1, 1),
			Lifetime = NumberRange.new(6), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(6, 9), Brightness = 1.2,
		}, 1, 6.5)
	end)
	ctx.emit("Streak", { -- starfall
		Name = "Starfall", Texture = T.Streak, Color = CS({ "#FFFFFF", "#C9A6FF" }), Orientation = STREAK,
		EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(160, 220), Size = NS(0, 4, 0.5, 6, 1, 1),
		Squash = NS(3), Transparency = NS(0, 1, 0.15, 0, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Brightness = 2, Rate = 5,
	})
	ctx.every({ 3, 6 }, function() -- corona flares sparking high above
		local cam = workspace.CurrentCamera
		if cam then
			local p = cam.CFrame.Position + Vector3.new(rng:NextNumber(-120, 120), rng:NextNumber(70, 110), rng:NextNumber(-120, 120))
			flarePop(p, CS({ "#FFFFFF", "#C9A6FF" }), rng:NextNumber(10, 18), 0.45)
		end
	end)
end

for id, plus in PLUS do
	local look = LOOKS[id]
	if look then
		look.Vignette = VIGNETTE[id]
		if id == "BloodMoon" then
			look.VignettePulse = function(t)
				return heartbeat(t) * 0.6
			end
		end
		local build, update = look.Build, look.Update
		look.Build = function(ctx, state)
			build(ctx, state)
			local ok, err = pcall(plus, ctx, state)
			if not ok then
				warn("[WeatherFX] add-ons " .. id .. ": " .. tostring(err))
			end
		end
		look.Update = function(state, dt)
			if update then
				update(state, dt)
			end
			if state.plusUpdate then
				state.plusUpdate(state, dt)
			end
		end
	end
end

-- the moment an event starts: a ring + stacked halos + a flare around you, and a tint pulse
local function arrival(id)
	local c = ACCENT[id or ""]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (c and hrp) then
		return
	end
	local feet = hrp.Position - Vector3.new(0, 2.8, 0)
	groundRing(feet, c, 60, 0.9, TX.CleanRing)
	haloStack(feet + Vector3.new(0, 0.6, 0), c, 4, 22, 3.5, 0.75)
	flarePop(hrp.Position + Vector3.new(0, 4, 0), c, 14, 0.5)
	chroma(hrp.Position, 16, 30)
	tintPulse(c, 0.45)
end

---------------------------------------------------------------- strikes from the server
gameEvent.OnClientEvent:Connect(function(name, d)
	if name == "WeatherStrike" and type(d) == "table" and typeof(d.Position) == "Vector3" then
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - d.Position).Magnitude > 600 then
			return
		end
		local delay = tonumber(d.Delay) or 0.5
		if d.Kind == "Lightning" then
			task.spawn(lightningStrike, d.Position, delay, d.Mutation)
		elseif d.Kind == "Meteor" then
			task.spawn(meteor, d.Position, delay, d.Mutation)
		elseif d.Kind == "Hail" then
			task.spawn(hailChunk, d.Position, delay, d.Mutation)
		end
	elseif name == "HailHit" then
		shake(1.3, 0.35)
	elseif name == "WeatherStarted" and type(d) == "table" then
		playSound({ Id = 15675016548, Volume = 0.55 }, nil, { Pitch = 0.9 })
		task.spawn(arrival, d.Id)
		local e = WeatherConfig.ById[d.Id or ""]
		if e and e.Announce then
			playSound(S.Boom, nil, { Volume = 0.7, Pitch = 0.6 })
		end
	end
end)

---------------------------------------------------------------- eggs: mutation bursts + weather egg pillars
local seen = {} -- [egg] = MutatedAt already played
local pillars = {} -- [egg] = { parts }

local function mutationBurst(egg, id)
	local m = MutationConfig.ById[id]
	local shell = egg.PrimaryPart
	if not (m and shell) then
		return
	end
	local color = hex(m.Glow)
	local pos = shell.Position
	local size = shell.Size.Y
	burst(pos, {
		Texture = m.FX.Accent, Color = CS(m.Colors), Speed = NumberRange.new(0), Size = NS(0, 1, 0.3, size * 3.2, 1, size * 3.6),
		Transparency = NS(0, 0, 0.6, 0.2, 1, 1), Lifetime = NumberRange.new(0.6), Rotation = NumberRange.new(0, 360),
	}, 1, 2)
	burst(pos, {
		Texture = m.FX.Main, Color = CS(m.Colors), Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(180, 180),
		Size = NS(0, 0.8, 1, 0), Lifetime = NumberRange.new(0.6, 1), Drag = 3, Rotation = NumberRange.new(0, 360),
	}, reduced() and 8 or 24, 2)
	groundRing(pos - Vector3.new(0, size / 2 - 0.2, 0), color, size * 4, 0.6)
	local lp = newPart("MutLight", Vector3.new(1, 1, 1))
	lp.Position = pos
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 22
	light.Brightness = 6
	light.Parent = lp
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(lp, 1)
	soundAt(S.Chime, pos, { MaxDist = 160, MinDist = 15, Pitch = 1.1 })
	flarePop(pos, m.Rainbow and CS({ "#FF4D4D", "#FFE84D", "#4DFF88", "#4DD8FF", "#C44DFF" }) or color, size * 3, 0.4)
	haloStack(pos - Vector3.new(0, size / 2 - 0.3, 0), color, 3, size * 3.5, size * 0.6, 0.5)
	if id == "Diamond" or id == "Rainbow" or id == "Galaxy" then
		chroma(pos, 12, 25)
	end
	task.delay(0.15, function()
		darkLinger(pos, color:Lerp(Color3.new(0, 0, 0), 0.75), size * 3, 3)
	end)
end

local function addPillar(egg, id)
	local m = MutationConfig.ById[id]
	local shell = egg.PrimaryPart
	if not (m and shell) or pillars[egg] then
		return
	end
	local base = newPart("WeatherEggPillar", Vector3.new(0.2, 0.2, 0.2))
	base.Position = shell.Position
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 90, 0)
	a1.Parent = base
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = T.LightColumn
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureSpeed = 0.6
	beam.Color = CS(m.Colors)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0, beam.Width1 = 4, 1.5
	beam.Transparency = NS(0, 0.15, 1, 1)
	beam.FaceCamera = true
	beam.Parent = base
	emitter(base, {
		Texture = m.FX.Main, Color = CS(m.Colors), Size = NS(0, 0.6, 1, 0), Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(6, 12), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Rate = reduced() and 4 or 10,
	})
	local rise = Instance.new("Attachment")
	rise.Parent = base
	emitter(rise, {
		Texture = TX.Halo, Color = CS(m.Colors), Orientation = FLAT, EmissionDirection = UP, Speed = NumberRange.new(9, 11),
		Size = NS(0, 2, 0.2, 7, 1, 3), Transparency = NS(0, 1, 0.15, 0.3, 1, 1), Lifetime = NumberRange.new(2.5),
		Rotation = NumberRange.new(0, 360), Brightness = 1.5, Rate = reduced() and 0.6 or 1.4,
	})
	local gnd = Instance.new("Attachment")
	gnd.Position = Vector3.new(0, -shell.Size.Y / 2 + 0.2, 0)
	gnd.Parent = base
	emitter(gnd, {
		Texture = TX.MagicRing, Color = CS(m.Colors), Orientation = FLAT, EmissionDirection = UP, Speed = NumberRange.new(0.01),
		LockedToPart = true, Size = NS(9), Transparency = NS(0, 1, 0.25, 0.45, 0.75, 0.45, 1, 1), Lifetime = NumberRange.new(2.4, 2.8),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(25, 35), Brightness = 1.5, Rate = 0.8,
	})
	emitter(a1, {
		Texture = TX.FourStar, Color = CS(m.Colors), Speed = NumberRange.new(0), Size = NS(0, 0, 0.3, 7, 1, 0),
		Lifetime = NumberRange.new(0.5), Rotation = NumberRange.new(-8, 8), Brightness = 2, Rate = 1.5,
	})
	pillars[egg] = base
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local runtime = workspace:FindFirstChild("Runtime")
		local eggs = runtime and runtime:FindFirstChild("Eggs")
		if eggs then
			for _, egg in eggs:GetChildren() do
				local at = egg:GetAttribute("MutatedAt")
				local id = egg:GetAttribute("Mutation")
				if at and id and seen[egg] ~= at then
					seen[egg] = at
					if workspace:GetServerTimeNow() - at < 3 then
						task.spawn(mutationBurst, egg, id)
					end
				end
				local st = egg:GetAttribute("State")
				if id and egg:GetAttribute("WeatherEgg") and (st == "Nest" or st == "Ground") then
					addPillar(egg, id)
				end
			end
		end
		for egg, p in pillars do
			local st = egg.Parent and egg:GetAttribute("State")
			if not (st == "Nest" or st == "Ground") then
				p:Destroy()
				pillars[egg] = nil
			elseif egg.PrimaryPart then
				p.Position = egg.PrimaryPart.Position
			end
		end
		for egg in seen do
			if not egg.Parent then
				seen[egg] = nil
			end
		end
	end
end)

---------------------------------------------------------------- follow the server's weather
local function sync()
	local id = workspace:GetAttribute("WeatherId")
	if id and LOOKS[id] then
		startEvent(id)
	elseif active then
		stopActive(false)
	end
end
workspace:GetAttributeChangedSignal("WeatherId"):Connect(sync)
sync()
