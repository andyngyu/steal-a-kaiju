-- Speed visuals, client-only:
--   personal treadmills: run animation for the local runner, chevrons scrolling while anyone runs, jump to get off,
--   "+Speed" popups while training, pulsing hologram when locked, burst on unlock/upgrade
--   running VFX (any runner, scales with tier): belt sparks, pulsing ground rings, glowing trim + belt light,
--   wind streaks (2+), sparkle shower (3+), light pillar (5).
--   every tier also has its own look (TIERS below), idle and while running: Rookie dust + green blips, Sporty blue
--   hex seal + electric zips + speed lines, Golden sun seal + twinkles + raining stars, Blaze nozzle flames + roaring
--   flame jets + fire bursts, Kaiju plasma motes + green lightning + energy blasts.
--   Popups and ground rings fire on a beat (TreadmillConfig.PopupEveryTicks), "SPEED UP!" each time your running speed
--   goes up a whole step (RunSpeed attribute).
--   biome signs showing the viewer's Speed vs the Speed needed for the biome's recommended running speed
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local SpeedConfig = require(Config.SpeedConfig)
local TreadmillConfig = require(Config.TreadmillConfig)
local Settings = require(script.Parent:WaitForChild("Settings"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameEvent = remotes:WaitForChild("GameEvent")
local treadmillRemote = remotes:WaitForChild("Treadmill")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local lane = map:WaitForChild("Lane")
local plotsFolder = map:WaitForChild("Plots")

local GREEN = Color3.fromHex("6BE04A")
local RED = Color3.fromHex("FF4D5E")
local GOLD = Color3.fromHex("FFD23F")
local ORANGE = Color3.fromHex("FF9A2E")
local DEFAULT_RUN = "rbxassetid://913376220" -- Roblox's default R15 run
local BELT_HALF = 4.3

local rng = Random.new()
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FX_RANGE = 200

local localFx = Instance.new("Folder")
localFx.Name = "TreadmillFXLocal"
localFx.Parent = workspace

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))

-- Speed is a currency: 0.75, 12.5, 980, 1.23K, 4.5M ...
local function fmtSpeed(n)
	if n >= 1000 then
		return Format.Short(n)
	end
	local s = string.format(n < 10 and "%.2f" or "%.1f", n)
	return (s:gsub("0+$", ""):gsub("%.$", ""))
end

-- ---------- signs ----------

local function refreshBiomeSigns()
	local points = player:GetAttribute("Speed") or 0
	local run = player:GetAttribute("RunSpeed") or SpeedConfig.RunSpeed(points)
	for _, biome in lane:GetChildren() do
		local sign = biome:FindFirstChild("Sign")
		local rec = sign and sign:GetAttribute("RecommendedSpeed") -- a running speed (BiomeConfig)
		local board = sign and sign:FindFirstChild("Board")
		if rec and board then
			local ready = run >= rec - 1e-6
			local gui = board:FindFirstChildOfClass("SurfaceGui")
			if gui and gui:FindFirstChild("Rec") then
				local need = SpeedConfig.PointsForRunSpeed(rec)
				gui.Rec.Text = "Recommended Speed: " .. (need <= 0 and "Any" or fmtSpeed(math.ceil(need)))
			end
			if gui and gui:FindFirstChild("Status") then
				gui.Status.Text = "Your Speed: " .. fmtSpeed(points) .. (ready and "  OK" or "  Too slow")
				gui.Status.TextColor3 = ready and GREEN or RED
			end
			local lamp = sign:FindFirstChild("Lamp")
			if lamp then
				lamp.Color = ready and GREEN or RED
			end
		end
	end
end

player:GetAttributeChangedSignal("Speed"):Connect(refreshBiomeSigns)
player:GetAttributeChangedSignal("RunSpeed"):Connect(refreshBiomeSigns)
refreshBiomeSigns()
task.delay(3, refreshBiomeSigns) -- lane signs may still be loading on join

-- ---------- popups & bursts ----------

local function popup(text, color, jitter, size)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local start = Vector3.new(jitter and rng:NextNumber(-1.6, 1.6) or 0, 2.2, 0)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 140, (size or 140) * 0.28)
	bb.StudsOffsetWorldSpace = start
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromHex("1A1033")
	l.Text = text
	l.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = l
	bb.Parent = head
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffsetWorldSpace = start + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.2)
end

local function burstAt(pos, color, count)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://12402859532" -- four-point star
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-180, 180)
	pe.Speed = NumberRange.new(8, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 1)
	pe.Drag = 2
	pe.Rate = 0
	pe.Parent = holder
	holder.Parent = workspace
	pe:Emit(Settings.Get("ReducedEffects") and math.ceil(count * 0.35) or count)
	Debris:AddItem(holder, 1.5)
end

local function burstOnCharacter(color)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		burstAt(hrp.Position, color, 40)
	end
end

-- treadmill gains: batched into one popup every PopupEveryTicks training ticks (the beat);
-- a bigger "SPEED UP!" burst each time your running speed goes up a whole step (below)
local lastTrained = player:GetAttribute("TrainedSpeed")
local pendingGain, pendingTicks = 0, 0
local beat = Instance.new("BindableEvent") -- fired on each popup so the local treadmill's ground ring lands on it
player:GetAttributeChangedSignal("TrainedSpeed"):Connect(function()
	local now = player:GetAttribute("TrainedSpeed") or 0
	if lastTrained and now > lastTrained and player:GetAttribute("OnTreadmill") then
		pendingGain += now - lastTrained
		pendingTicks += 1
		if pendingTicks >= TreadmillConfig.PopupEveryTicks then
			popup("+" .. fmtSpeed(pendingGain) .. " Speed", ORANGE, true, 170)
			pendingGain, pendingTicks = 0, 0
			beat:Fire()
		end
	end
	lastTrained = now
end)
-- "SPEED UP!" when training pushes your running speed up a whole step
local lastRun = player:GetAttribute("RunSpeed")
player:GetAttributeChangedSignal("RunSpeed"):Connect(function()
	local now = player:GetAttribute("RunSpeed") or 0
	if lastRun and math.floor(now) > math.floor(lastRun) and player:GetAttribute("OnTreadmill") then
		local level = TreadmillConfig.Levels[player:GetAttribute("TreadmillLevel") or 1]
		local color = level and level.Theme.Chevron or GOLD
		popup("SPEED UP!", GOLD, false, 230)
		burstOnCharacter(color)
	end
	lastRun = now
end)
player:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
	pendingGain, pendingTicks = 0, 0
end)

gameEvent.OnClientEvent:Connect(function(name, data)
	if name == "TreadmillMaxed" then
		popup(data.NextName and ("Maxed! Upgrade to " .. data.NextName) or "Treadmill fully trained!", GOLD, false, 220)
	elseif name == "TreadmillUpgraded" then
		local plot = plotsFolder:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
		local tm = plot and plot:FindFirstChild("Treadmill")
		if tm then
			local theme = TreadmillConfig.Levels[data.Level].Theme
			burstAt(tm:GetPivot().Position + Vector3.new(0, 4, 0), theme.Trim, 60)
		end
		popup(data.Name .. " Treadmill!", GOLD, false, 200)
	elseif name == "TreadmillCarrying" then
		popup("Drop your egg first!", RED, false, 180)
	end
end)

-- ---------- running VFX ----------

local function fxPart(parent, cf, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	for k, v in props do
		pe[k] = v
	end
	if Settings.Get("ReducedEffects") then
		pe.Rate *= 0.35
	end
	pe.Parent = parent
	return pe
end

local function fade(seq0, seq1)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, seq0), NumberSequenceKeypoint.new(1, seq1) })
end

-- ---------- per-tier looks ----------
-- Each tier has its own textures (from the VFX Studio library): an idle effect while the treadmill just stands there
-- and a signature effect while someone runs on it, on top of the shared belt sparks, wind, ground ring and light.
-- Offsets are relative to the treadmill's pivot (the deck centre, level with the plot floor); the runner faces -Z,
-- so +Z is behind them.
local TEX = {
	Dust = "rbxassetid://291880914", -- billowing dust puff
	Glint = "rbxassetid://12386386944", -- small four-point sparkle
	SoftRing = "rbxassetid://12402862092", -- soft glowing ring
	HexSeal = "rbxassetid://12403125823", -- hexagon seal
	Zip = "rbxassetid://278520320", -- blue electric bolt (full colour)
	SpeedLine = "rbxassetid://119645012596917", -- thin bright streak
	DoubleRing = "rbxassetid://14186586240", -- double ring
	Twinkle = "rbxassetid://14197583306", -- cross flare
	SunSeal = "rbxassetid://12403138547", -- sun-ray seal
	Stars = "rbxassetid://121770043350309", -- 4x4 sheet of stars
	BigGlint = "rbxassetid://12402859532", -- big four-point star
	Flame = "rbxassetid://13504062786", -- 2x2 sheet of flames
	FireBurst = "rbxassetid://76321714916033", -- 4x4 fire burst flipbook (full colour)
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
	FireRing = "rbxassetid://9573351641", -- spiky ring
	Mote = "rbxassetid://15513493035", -- soft glow star
	Bolt = "rbxassetid://12402856027", -- small lightning bolt
	Blast = "rbxassetid://15265630895", -- radial energy burst
}
local UP = Enum.NormalId.Top
local BACK = Enum.NormalId.Back
local BOX = Enum.ParticleEmitterShape.Box
local VOLUME = Enum.ParticleEmitterShapeStyle.Volume
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular
local STREAK = Enum.ParticleOrientation.VelocityParallel
local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local WHITE = Color3.new(1, 1, 1)
local FLOOR = 0.04 -- just above the plot floor (the deck is sunk into it, so the pivot sits at floor level)

local function range(a, b)
	return NumberRange.new(a, b or a)
end

local function seq(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function cs(...)
	local list = { ... }
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local kps = {}
	for i, c in list do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(kps)
end

-- a flat picture on the floor round the treadmill (a SurfaceGui, so it glows and spins as one crisp image)
local function floorDecal(owner, st, size, image, color, transparency, spin)
	local cf = st.pivot * CFrame.new(0, FLOOR, 0)
	local p = fxPart(owner.folder, cf, Vector3.new(size, 0.05, size))
	local gui = Instance.new("SurfaceGui")
	gui.Face = UP
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = color
	img.ImageTransparency = transparency
	img.Parent = gui
	local d = { part = p, img = img, base = cf, angle = 0, spin = spin or 0, alpha = transparency }
	table.insert(owner.decals, d)
	return d
end

-- an emitter on an invisible box at an offset from the pivot
local function boxEmitter(owner, st, offset, size, props)
	return emitter(fxPart(owner.folder, st.pivot * offset, size), props)
end

-- a flat ring that only fires on the beat (the "+Speed" popup)
local function beatRing(fx, st, texture, color, light, size, count)
	local pe = boxEmitter(fx, st, CFrame.new(0, FLOOR + 0.15, 0), Vector3.new(1, 0.05, 1), {
		Texture = texture,
		Color = color,
		LightEmission = light,
		Orientation = FLAT,
		Size = seq({ { 0, 3 }, { 1, size } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = range(0.7),
		Speed = range(0.01),
		SpreadAngle = Vector2.new(0, 0),
		Rotation = range(0, 360),
		EmissionDirection = UP,
		Rate = 0,
	})
	table.insert(fx.beats, { pe, count or 1 })
	return pe
end

local TIERS = {}

-- 1 Rookie: a green "ready" blip on the screen; running kicks dust off the belt
TIERS[1] = {
	idle = function(idle, st, th)
		boxEmitter(idle, st, CFrame.new(0, 4.8, -2.55), Vector3.new(3, 0.6, 0.1), {
			Texture = TEX.Glint,
			Color = cs(th.Screen),
			LightEmission = 1,
			Size = seq({ { 0, 0 }, { 0.4, 0.8 }, { 1, 0 } }),
			Lifetime = range(0.5, 0.7),
			Speed = range(0),
			Rotation = range(0, 90),
			Rate = 0.8,
			Shape = BOX,
		})
	end,
	run = function(fx, st, th)
		boxEmitter(fx, st, CFrame.new(0, 0.8, 5.2), Vector3.new(4, 0.2, 0.4), {
			Texture = TEX.Dust,
			Color = cs(Color3.fromHex("C9B89A"), Color3.fromHex("857B6A")),
			LightEmission = 0,
			Size = seq({ { 0, 1 }, { 1, 3 } }),
			Transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
			Lifetime = range(0.6, 1),
			Speed = range(2, 4),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, 1, 0),
			Rotation = range(0, 360),
			RotSpeed = range(-40, 40),
			Rate = 12,
			EmissionDirection = BACK,
			Shape = BOX,
		})
		boxEmitter(fx, st, CFrame.new(0, 0.75, 1), Vector3.new(1.6, 0.1, 1.6), {
			Texture = TEX.Glint,
			Color = cs(th.Screen, WHITE),
			LightEmission = 1,
			Size = seq({ { 0, 0.6 }, { 1, 0 } }),
			Lifetime = range(0.25, 0.4),
			Speed = range(2, 4),
			SpreadAngle = Vector2.new(60, 60),
			Rate = 8,
			EmissionDirection = UP,
			Shape = BOX,
		})
		beatRing(fx, st, TEX.SoftRing, cs(th.Screen), 0.5, 16)
	end,
}

-- 2 Sporty: a blue hex seal on the floor; running sends electric zips along the side strips and speed lines past you
TIERS[2] = {
	idle = function(idle, st, th)
		floorDecal(idle, st, 15, TEX.HexSeal, th.Trim, 0.4, 6)
	end,
	run = function(fx, st, th)
		for _, side in { -1, 1 } do
			boxEmitter(fx, st, CFrame.new(side * 3, 1.25, 0), Vector3.new(0.2, 0.2, 9.5), {
				Texture = TEX.Zip,
				Color = cs(WHITE),
				LightEmission = 0.5,
				Brightness = 2,
				Size = seq({ { 0, 2 }, { 1, 2.6 } }),
				Transparency = seq({ { 0, 0 }, { 1, 1 } }),
				Lifetime = range(0.12, 0.2),
				Speed = range(0),
				Rotation = range(0, 360),
				LockedToPart = true,
				Rate = 14,
				Shape = BOX,
				ShapeStyle = VOLUME,
			})
		end
		boxEmitter(fx, st, CFrame.new(0, 3.6, -3), Vector3.new(5.5, 4, 0.5), {
			Texture = TEX.SpeedLine,
			Color = cs(Color3.fromHex("CFEFFF"), th.Trim),
			LightEmission = 0.35,
			Brightness = 2,
			Size = seq({ { 0, 1.4 }, { 1, 0.9 } }),
			Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
			Lifetime = range(0.2, 0.3),
			Speed = range(30, 42),
			Orientation = STREAK,
			Rate = 22,
			EmissionDirection = BACK,
			Shape = BOX,
			ShapeStyle = VOLUME,
		})
		beatRing(fx, st, TEX.DoubleRing, cs(th.Trim), 0.6, 18)
	end,
	runSpin = 5, -- the floor seal spins faster while running
}

-- 3 Golden: a golden sun seal and twinkles on the frame; running rains golden stars with big glints on the beat
TIERS[3] = {
	idle = function(idle, st, th)
		floorDecal(idle, st, 15, TEX.SunSeal, th.Trim, 0.4, 4)
		boxEmitter(idle, st, CFrame.new(0, 2.5, -1), Vector3.new(6, 4.5, 10), {
			Texture = TEX.Twinkle,
			Color = cs(Color3.fromHex("FFE680"), th.Trim),
			LightEmission = 0.4,
			Brightness = 2,
			Size = seq({ { 0, 0 }, { 0.4, 1.4 }, { 1, 0 } }),
			Lifetime = range(0.45, 0.6),
			Speed = range(0),
			Rate = 3,
			Shape = BOX,
			ShapeStyle = VOLUME,
		})
	end,
	run = function(fx, st, th)
		boxEmitter(fx, st, CFrame.new(0, 8, 1), Vector3.new(6, 0.5, 6), {
			Texture = TEX.Stars,
			FlipbookLayout = GRID4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = range(0),
			FlipbookStartRandom = true,
			Color = cs(Color3.fromHex("FFE680"), th.Trim),
			LightEmission = 0.3,
			Brightness = 2,
			Size = seq({ { 0, 0.55 }, { 1, 0.4 } }),
			Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
			Lifetime = range(1, 1.4),
			Speed = range(2, 4),
			Acceleration = Vector3.new(0, -6, 0),
			Rotation = range(0, 360),
			RotSpeed = range(-200, 200),
			Rate = 16,
			EmissionDirection = Enum.NormalId.Bottom,
			Shape = BOX,
		})
		local glint = boxEmitter(fx, st, CFrame.new(0, 3.7, 1), Vector3.new(3, 4, 1.5), {
			Texture = TEX.BigGlint,
			Color = cs(Color3.fromHex("FFF0A0"), th.Trim),
			LightEmission = 0.4,
			Brightness = 2,
			Size = seq({ { 0, 0 }, { 0.3, 2.2 }, { 1, 0 } }),
			Lifetime = range(0.35, 0.5),
			Speed = range(0),
			Rotation = range(0, 45),
			Rate = 2.5,
			Shape = BOX,
			ShapeStyle = VOLUME,
		})
		table.insert(fx.beats, { glint, 4 })
	end,
	runSpin = 4,
}

-- 4 Blaze: little flames dancing on the rear nozzles; running roars flame jets out the back with fire bursts
local function nozzles(owner, st, props)
	for _, side in { -1, 1 } do
		boxEmitter(owner, st, CFrame.new(side * 2, 0.5, 6.2), Vector3.new(0.5, 0.5, 0.2), props)
	end
end

TIERS[4] = {
	idle = function(idle, st, th)
		nozzles(idle, st, {
			Texture = TEX.Flame,
			FlipbookLayout = GRID2,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = range(0),
			FlipbookStartRandom = true,
			Color = cs(Color3.fromHex("FF9A2E"), th.Trim, Color3.fromHex("A81A08")),
			LightEmission = 0.3,
			Brightness = 1.6,
			Size = seq({ { 0, 0.5 }, { 0.4, 1.1 }, { 1, 0.2 } }),
			Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
			Lifetime = range(0.35, 0.5),
			Speed = range(1, 2),
			Acceleration = Vector3.new(0, 4, 0),
			Rotation = range(-10, 10),
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			Rate = 10,
			EmissionDirection = UP,
		})
		boxEmitter(idle, st, CFrame.new(0, 0.6, 5.9), Vector3.new(4.5, 0.3, 0.6), {
			Texture = TEX.Embers,
			Color = cs(Color3.fromHex("FFD23F"), th.Chevron),
			LightEmission = 1,
			Size = seq({ { 0, 0.3 }, { 1, 0 } }),
			Lifetime = range(0.8, 1.4),
			Speed = range(1, 3),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 3, 0),
			Rate = 5,
			EmissionDirection = UP,
			Shape = BOX,
		})
	end,
	run = function(fx, st, th)
		nozzles(fx, st, {
			Texture = TEX.Flame,
			FlipbookLayout = GRID2,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = range(0),
			FlipbookStartRandom = true,
			Color = cs(Color3.fromHex("FFA83A"), Color3.fromHex("FF5A1F"), Color3.fromHex("9A1606")),
			LightEmission = 0.3,
			Brightness = 1.6,
			Size = seq({ { 0, 0.9 }, { 0.5, 2.4 }, { 1, 1 } }),
			Transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
			Lifetime = range(0.3, 0.45),
			Speed = range(12, 18),
			SpreadAngle = Vector2.new(8, 8),
			Acceleration = Vector3.new(0, 8, 0),
			Rotation = range(0, 360),
			RotSpeed = range(-120, 120),
			Rate = 45,
			EmissionDirection = BACK,
		})
		boxEmitter(fx, st, CFrame.new(0, 1.5, 4.5), Vector3.new(4.4, 0.3, 1), {
			Texture = TEX.Embers,
			Color = cs(Color3.fromHex("FFE24A"), th.Chevron),
			LightEmission = 1,
			Size = seq({ { 0, 0.4 }, { 1, 0 } }),
			Lifetime = range(0.6, 1),
			Speed = range(6, 12),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, 4, 0),
			Rate = 30,
			EmissionDirection = UP,
			Shape = BOX,
		})
		local burst = boxEmitter(fx, st, CFrame.new(0, 3, 2.5), Vector3.new(3, 2, 1), {
			Texture = TEX.FireBurst,
			FlipbookLayout = GRID4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = cs(WHITE),
			LightEmission = 0.4,
			Size = seq({ { 0, 2 }, { 1, 4.5 } }),
			Lifetime = range(0.55, 0.7),
			Speed = range(1, 2),
			Rotation = range(0, 360),
			Rate = 0,
			Shape = BOX,
			ShapeStyle = VOLUME,
		})
		table.insert(fx.beats, { burst, 2 })
		beatRing(fx, st, TEX.FireRing, cs(Color3.fromHex("FFD25A"), th.Trim), 0.6, 20)
	end,
}

-- 5 Kaiju: plasma motes rising off the plates; running crackles green lightning round
-- the arch and blasts purple energy on the beat
TIERS[5] = {
	idle = function(idle, st, th)
		boxEmitter(idle, st, CFrame.new(0, 6.4, -3.6), Vector3.new(4.5, 0.5, 0.8), {
			Texture = TEX.Mote,
			Color = cs(Color3.fromHex("C8FFB0"), th.Chevron),
			LightEmission = 1,
			Size = seq({ { 0, 0 }, { 0.3, 0.7 }, { 1, 0 } }),
			Lifetime = range(1.2, 1.8),
			Speed = range(0.8, 1.6),
			SpreadAngle = Vector2.new(20, 20),
			Rate = 5,
			EmissionDirection = UP,
			Shape = BOX,
		})
	end,
	run = function(fx, st, th)
		boxEmitter(fx, st, CFrame.new(0, 4.2, -3.6), Vector3.new(6.5, 5.5, 1.5), {
			Texture = TEX.Bolt,
			Color = cs(Color3.fromHex("C8FFB0"), th.Chevron),
			LightEmission = 0.4,
			Brightness = 3,
			Size = seq({ { 0, 2 }, { 1, 2.8 } }),
			Transparency = seq({ { 0, 0 }, { 1, 1 } }),
			Lifetime = range(0.12, 0.2),
			Speed = range(0),
			Rotation = range(0, 360),
			LockedToPart = true,
			Rate = 12,
			Shape = BOX,
			ShapeStyle = VOLUME,
		})
		boxEmitter(fx, st, CFrame.new(0, 0.8, 1), Vector3.new(4, 0.2, 4), {
			Texture = TEX.Mote,
			Color = cs(Color3.fromHex("D8B0FF"), th.Trim),
			LightEmission = 0.5,
			Brightness = 2,
			Size = seq({ { 0, 0 }, { 0.3, 0.9 }, { 1, 0 } }),
			Lifetime = range(0.8, 1.2),
			Speed = range(4, 7),
			SpreadAngle = Vector2.new(10, 10),
			Rate = 18,
			EmissionDirection = UP,
			Shape = BOX,
		})
		local blast = boxEmitter(fx, st, CFrame.new(0, 3.7, 1.6), Vector3.new(0.5, 0.5, 0.5), {
			Texture = TEX.Blast,
			Color = cs(Color3.fromHex("D8B0FF"), th.Trim),
			LightEmission = 0.4,
			Brightness = 2,
			Size = seq({ { 0, 3 }, { 1, 12 } }),
			Transparency = seq({ { 0, 0.05 }, { 1, 1 } }),
			Lifetime = range(0.5),
			Speed = range(0),
			Rotation = range(0, 360),
			RotSpeed = range(-90, 90),
			ZOffset = -2,
			Rate = 0,
		})
		table.insert(fx.beats, { blast, 1 })
	end,
	runSpin = 4,
}

local function buildIdle(model, st)
	local level = TreadmillConfig.Levels[model:GetAttribute("Level") or 0]
	local tier = level and TIERS[model:GetAttribute("Level")]
	if not (tier and tier.idle) then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Idle"
	folder.Parent = localFx
	local idle = { folder = folder, decals = {}, tier = tier }
	tier.idle(idle, st, level.Theme)
	return idle
end

local function clearIdle(st)
	if st.idle then
		st.idle.folder:Destroy()
	end
	st.idle = nil
end

local function spinDecals(owner, dt, mult, alphaMult)
	for _, d in owner.decals do
		d.angle = (d.angle + d.spin * mult * dt) % 360
		d.part.CFrame = d.base * CFrame.Angles(0, math.rad(d.angle), 0)
		d.img.ImageTransparency = 1 - (1 - d.alpha) * alphaMult
	end
end

local GLOW_NAMES = { Arm = true, Strip = true, ConsoleTrim = true, Screen = true, Plate = true }

local function startFX(model, st)
	local levelIndex = model:GetAttribute("Level") or 1
	local level = TreadmillConfig.Levels[levelIndex]
	if not level then
		return
	end
	local th = level.Theme
	local pivot = st.pivot
	local folder = Instance.new("Folder")
	folder.Name = "FX"
	folder.Parent = localFx
	local fx = { folder = folder, level = levelIndex, theme = th, nextRing = 0, saved = {}, glow = {}, beats = {}, decals = {} }

	-- sparks flying off the back of the belt (box emitter across the belt, aimed back and up)
	local rear = fxPart(folder, pivot * CFrame.new(0, 1.7, 4.7) * CFrame.Angles(math.rad(70), 0, 0), Vector3.new(3.6, 0.2, 0.2))
	emitter(rear, {
		Texture = TEX.Glint,
		Color = ColorSequence.new(th.Chevron, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = fade(0.35, 0),
		Speed = NumberRange.new(8, 15),
		SpreadAngle = Vector2.new(20, 35),
		Lifetime = NumberRange.new(0.3, 0.6),
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 18 + levelIndex * 8,
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})

	-- wind streaks rushing past the runner, front to back
	if levelIndex >= 2 then
		local front = fxPart(folder, pivot * CFrame.new(0, 4, -2.5), Vector3.new(6.5, 4.5, 0.5))
		emitter(front, {
			Color = ColorSequence.new(Color3.new(1, 1, 1), th.Trim),
			LightEmission = 0.6,
			Size = NumberSequence.new(0.09),
			Squash = NumberSequence.new(2.8),
			Transparency = fade(0.25, 1),
			Speed = NumberRange.new(28, 40),
			Lifetime = NumberRange.new(0.18, 0.3),
			Rate = 22 + levelIndex * 6,
			EmissionDirection = Enum.NormalId.Back,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
		})
	end

	-- sparkle shower around the runner
	if levelIndex >= 3 then
		local around = fxPart(folder, pivot * CFrame.new(0, 3.6, 1), Vector3.new(5.5, 5, 4))
		emitter(around, {
			Texture = SPARK,
			Color = ColorSequence.new(th.Trim, Color3.new(1, 1, 1)),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(1, 3),
			Lifetime = NumberRange.new(0.6, 1.1),
			Rate = 10 + levelIndex * 4,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			Acceleration = Vector3.new(0, 3, 0),
		})
	end

	-- the tier's own signature effect
	local tier = TIERS[levelIndex]
	if tier and tier.run then
		tier.run(fx, st, th)
	end

	-- light pillar (Kaiju)
	if levelIndex >= 5 then
		local beam = fxPart(folder, pivot * CFrame.new(0, 16, 1) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(30, 3, 3))
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = th.Chevron
		beam.Transparency = 0.6
		fx.beam = beam
	end

	-- glow under the belt
	local light = Instance.new("PointLight")
	light.Color = th.Chevron
	light.Range = 16
	light.Brightness = 2
	light.Parent = fxPart(folder, pivot * CFrame.new(0, 2.6, 0), Vector3.one)
	fx.light = light

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and GLOW_NAMES[d.Name] then
			table.insert(fx.glow, { d, d.Color })
		end
	end
	st.fx = fx
end

local function stopFX(st)
	local fx = st.fx
	if not fx then
		return
	end
	st.fx = nil
	st.ownBeat = nil
	for _, s in fx.saved do
		if s[1].Parent then
			s[1].Size = s[2]
			s[1].Heat = s[3]
		end
	end
	for _, g in fx.glow do
		if g[1].Parent then
			g[1].Color = g[2]
		end
	end
	for _, d in fx.folder:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false -- let live particles finish
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	if fx.beam then
		fx.beam:Destroy()
	end
	Debris:AddItem(fx.folder, 1.2)
end

local function ringPulse(st)
	local fx = st.fx
	fx.ringToggle = not fx.ringToggle
	local ring = fxPart(fx.folder, st.pivot * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.15, 7, 7))
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = fx.ringToggle and fx.theme.Chevron or fx.theme.Trim
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, 20 + fx.level * 2, 20 + fx.level * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1)
	local reduced = Settings.Get("ReducedEffects")
	for _, b in fx.beats do
		if b[1].Parent then
			b[1]:Emit(reduced and 1 or b[2])
		end
	end
end

local function updateFX(st, t)
	local fx = st.fx
	local k = (math.sin(t * (8 + fx.level * 1.5)) + 1) / 2
	for _, g in fx.glow do
		g[1].Color = g[2]:Lerp(Color3.new(1, 1, 1), k * 0.45)
	end
	fx.light.Brightness = 1.5 + k * 2.5
	-- other players' treadmills pulse on a timer matching the popup beat; the local runner's pulses on the beat itself
	if not st.ownBeat and t >= fx.nextRing then
		fx.nextRing = t + TreadmillConfig.PopupEveryTicks * TreadmillConfig.CheckInterval
		ringPulse(st)
	end
	if fx.beam then
		fx.beam.Transparency = 0.5 + (1 - k) * 0.35
		local w = 2.4 + k * 1
		fx.beam.Size = Vector3.new(30, w, w)
	end
end

-- ---------- treadmills ----------

local treadmills = {}

beat.Event:Connect(function()
	for model, st in treadmills do
		if st.fx and model:GetAttribute("Runner") == player.UserId then
			st.ownBeat = true
			ringPulse(st)
		end
	end
end) -- [model] = { chevrons = { {arms = {parts}, offsets = {CFrame}, z = number} }, ghostParts }

local function addTreadmill(model)
	if treadmills[model] then
		return
	end
	local pivot = model:GetPivot()
	local st = { phase = 0, chevrons = {} }
	local folder = model:FindFirstChild("Chevrons")
	if folder then
		for _, ch in folder:GetChildren() do
			local entry = { parts = {}, offsets = {}, cfs = {} }
			local sumZ = 0
			for _, arm in ch:GetChildren() do
				if arm:IsA("BasePart") then
					local off = pivot:ToObjectSpace(arm.CFrame)
					table.insert(entry.parts, arm)
					table.insert(entry.offsets, off)
					sumZ += off.Position.Z
				end
			end
			entry.z = #entry.parts > 0 and sumZ / #entry.parts or 0
			table.insert(st.chevrons, entry)
		end
	end
	st.pivot = pivot
	if model:GetAttribute("Ghost") then
		st.ghost = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(st.ghost, p)
			end
		end
	end
	treadmills[model] = st
end

local function watchPlot(plot)
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Treadmill" then
			task.defer(addTreadmill, child)
		end
	end)
	plot.ChildRemoved:Connect(function(child)
		local st = treadmills[child]
		if st then
			stopFX(st)
			clearIdle(st)
		end
		treadmills[child] = nil
	end)
	local existing = plot:FindFirstChild("Treadmill")
	if existing then
		addTreadmill(existing)
	end
end
for _, plot in plotsFolder:GetChildren() do
	watchPlot(plot)
end

-- the lightning boost (TreadmillService: player attribute LightningBoost while it runs) speeds up the run + belt
local function boostFactor(p)
	return (p and p:GetAttribute("LightningBoost")) and (TreadmillConfig.LightningAnimMultiplier or 1.8) or 1
end

-- run animation for the local player while on their treadmill
local runTrack
local function runSpeed()
	local level = TreadmillConfig.Levels[player:GetAttribute("TreadmillLevel") or 1]
	return (level and level.RunAnimSpeed or 1.2) * boostFactor(player)
end
local function stopRunning()
	if runTrack then
		runTrack:Stop(0.25)
		runTrack = nil
	end
end

local function startRunning()
	stopRunning()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local id = DEFAULT_RUN
	local animate = char:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local runAnim = runFolder and runFolder:FindFirstChildOfClass("Animation")
	if runAnim and runAnim.AnimationId ~= "" then
		id = runAnim.AnimationId -- the player's own animation pack
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	runTrack = animator:LoadAnimation(anim)
	runTrack.Priority = Enum.AnimationPriority.Action
	runTrack.Looped = true
	runTrack:Play(0.2)
	runTrack:AdjustSpeed(runSpeed())
end
player:GetAttributeChangedSignal("LightningBoost"):Connect(function()
	if runTrack then
		runTrack:AdjustSpeed(runSpeed())
	end
end)

player:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
	if player:GetAttribute("OnTreadmill") then
		startRunning()
	else
		stopRunning()
	end
end)
player.CharacterAdded:Connect(stopRunning)

UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("OnTreadmill") then
		treadmillRemote:FireServer("Stop")
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, st in treadmills do
		if not model.Parent then
			stopFX(st)
			clearIdle(st)
			treadmills[model] = nil
			continue
		end
		local running = model:GetAttribute("Runner") ~= nil and not st.ghost
		local near = (st.pivot.Position - camPos).Magnitude < FX_RANGE
		if running and near then
			if not st.fx then
				startFX(model, st)
			end
			if st.fx then
				updateFX(st, t)
			end
		elseif st.fx then
			stopFX(st)
		end
		-- the tier's idle look, near the camera only
		if near and not st.ghost then
			if not st.idle then
				st.idle = buildIdle(model, st) or false
			end
			if st.idle then
				spinDecals(st.idle, dt, running and (st.idle.tier.runSpin or 1) or 1, running and 1.6 or 1)
			end
		elseif st.idle ~= nil then
			clearIdle(st)
		end
		if st.ghost then
			local a = 0.25 + (math.sin(t * 2.5) + 1) * 0.2
			for _, p in st.ghost do
				p.LocalTransparencyModifier = a
			end
		elseif model:GetAttribute("Runner") then
			local level = TreadmillConfig.Levels[model:GetAttribute("Level") or 1]
			local runner = Players:GetPlayerByUserId(model:GetAttribute("Runner"))
			st.phase = (st.phase + (level and level.BeltSpeed or 8) * boostFactor(runner) * dt) % (BELT_HALF * 2)
			for _, ch in st.chevrons do
				local z = ((ch.z + st.phase + BELT_HALF) % (BELT_HALF * 2)) - BELT_HALF
				local shift = CFrame.new(0, 0, z - ch.z)
				for i, off in ch.offsets do
					ch.cfs[i] = st.pivot * shift * off
				end
				workspace:BulkMoveTo(ch.parts, ch.cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
	end
end)
