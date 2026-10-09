-- Speed visuals, client-only:
--   personal treadmills: run animation for the local runner, chevrons scrolling while anyone runs, jump to get off,
--   "+Speed" popups while training, pulsing hologram when locked, burst on unlock/upgrade
--   running VFX (any runner, scales with tier): belt sparks, pulsing ground rings, glowing trim + belt light,
--   wind streaks (2+), sparkle shower (3+), roaring fire jets (Blaze), light pillar (5).
--   Popups and ground rings fire on a beat (TreadmillConfig.PopupEveryTicks), "SPEED UP!" every MilestoneEvery Speed.
--   Speed Shop kiosk showing this viewer's own price; biome signs showing the viewer's speed vs recommended
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local SpeedConfig = require(Config.SpeedConfig)
local TreadmillConfig = require(Config.TreadmillConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameEvent = remotes:WaitForChild("GameEvent")
local treadmillRemote = remotes:WaitForChild("Treadmill")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local shop = map:WaitForChild("SpeedShop")
shop:WaitForChild("Board")
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

local function fmtSpeed(n)
	return (string.format("%.1f", n):gsub("%.0$", ""))
end

-- ---------- signs ----------

local function refreshShop()
	local gui = shop.Board:FindFirstChildOfClass("SurfaceGui")
	local prompt = shop.Board:FindFirstChild("BuyPrompt")
	if not gui then
		return
	end
	local speed = player:GetAttribute("Speed") or SpeedConfig.BaseSpeed
	local cost = player:GetAttribute("NextSpeedCost")
	if cost and speed < SpeedConfig.MaxSpeed then
		-- the equipped trail multiplies every point of Speed
		local step = SpeedConfig.Upgrade.SpeedPerLevel * (player:GetAttribute("TrailSpeedMultiplier") or 1)
		local nextSpeed = math.min(SpeedConfig.MaxSpeed, speed + step)
		gui.Detail.Text = "Speed " .. fmtSpeed(speed) .. " > " .. fmtSpeed(nextSpeed)
		gui.PriceFrame.Price.Text = Format.Money(cost)
		if prompt then
			prompt.ObjectText = "+" .. fmtSpeed(step) .. " Speed: " .. Format.Money(cost)
			prompt.Enabled = true
		end
	else
		gui.Detail.Text = "Speed " .. fmtSpeed(speed) .. " (Max)"
		gui.PriceFrame.Price.Text = "MAX"
		if prompt then
			prompt.Enabled = false
		end
	end
end

local function refreshBiomeSigns()
	local speed = player:GetAttribute("Speed") or SpeedConfig.BaseSpeed
	for _, biome in lane:GetChildren() do
		local sign = biome:FindFirstChild("Sign")
		local rec = sign and sign:GetAttribute("RecommendedSpeed")
		local board = sign and sign:FindFirstChild("Board")
		if rec and board then
			local ready = speed >= rec
			local gui = board:FindFirstChildOfClass("SurfaceGui")
			if gui and gui:FindFirstChild("Status") then
				gui.Status.Text = "Your Speed: " .. fmtSpeed(speed) .. (ready and "  OK" or "  Too slow")
				gui.Status.TextColor3 = ready and GREEN or RED
			end
			local lamp = sign:FindFirstChild("Lamp")
			if lamp then
				lamp.Color = ready and GREEN or RED
			end
		end
	end
end

local function refreshAll()
	refreshShop()
	refreshBiomeSigns()
end
player:GetAttributeChangedSignal("Speed"):Connect(refreshAll)
player:GetAttributeChangedSignal("NextSpeedCost"):Connect(refreshShop)
refreshAll()
task.delay(3, refreshAll) -- lane signs may still be loading on join

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
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Speed = NumberRange.new(8, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 1)
	pe.Drag = 2
	pe.Rate = 0
	pe.Parent = holder
	holder.Parent = workspace
	pe:Emit(count)
	Debris:AddItem(holder, 1.5)
end

local function burstOnCharacter(color)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		burstAt(hrp.Position, color, 40)
	end
end

-- treadmill gains: batched into one popup every PopupEveryTicks training ticks (the beat);
-- a bigger "SPEED UP!" burst each time the treadmill bonus passes a multiple of MilestoneEvery
local lastTrained = player:GetAttribute("TrainedSpeed")
local pendingGain, pendingTicks = 0, 0
local beat = Instance.new("BindableEvent") -- fired on each popup so the local treadmill's ground ring lands on it
player:GetAttributeChangedSignal("TrainedSpeed"):Connect(function()
	local now = player:GetAttribute("TrainedSpeed") or 0
	if lastTrained and now > lastTrained and player:GetAttribute("OnTreadmill") then
		pendingGain += now - lastTrained
		pendingTicks += 1
		if pendingTicks >= TreadmillConfig.PopupEveryTicks then
			popup("+" .. string.format("%.2f", pendingGain):gsub("0+$", ""):gsub("%.$", "") .. " Speed", ORANGE, true, 170)
			pendingGain, pendingTicks = 0, 0
			beat:Fire()
		end
		local step = TreadmillConfig.MilestoneEvery
		if math.floor(now / step) > math.floor(lastTrained / step) then
			local level = TreadmillConfig.Levels[player:GetAttribute("TreadmillLevel") or 1]
			local color = level and level.Theme.Chevron or GOLD
			popup("SPEED UP!", GOLD, false, 230)
			burstOnCharacter(color)
		end
	end
	lastTrained = now
end)
player:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
	pendingGain, pendingTicks = 0, 0
end)

gameEvent.OnClientEvent:Connect(function(name, data)
	if name == "SpeedBought" then
		popup("Speed " .. fmtSpeed(data.Speed) .. "!", GOLD)
		burstOnCharacter(GOLD)
	elseif name == "TreadmillMaxed" then
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
	pe.Parent = parent
	return pe
end

local function fade(seq0, seq1)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, seq0), NumberSequenceKeypoint.new(1, seq1) })
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
	local fx = { folder = folder, level = levelIndex, theme = th, nextRing = 0, saved = {}, glow = {} }

	-- sparks flying off the back of the belt (box emitter across the belt, aimed back and up)
	local rear = fxPart(folder, pivot * CFrame.new(0, 1.7, 4.7) * CFrame.Angles(math.rad(70), 0, 0), Vector3.new(3.6, 0.2, 0.2))
	emitter(rear, {
		Texture = SPARK,
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

	-- fire jets roar while running (Blaze)
	if th.Fire then
		for _, jet in model:GetChildren() do
			local fire = jet.Name == "Jet" and jet:FindFirstChildOfClass("Fire")
			if fire then
				table.insert(fx.saved, { fire, fire.Size, fire.Heat })
				fire.Size = 6
				fire.Heat = 15
			end
		end
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

-- run animation for the local player while on their treadmill
local runTrack
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
	local level = TreadmillConfig.Levels[player:GetAttribute("TreadmillLevel") or 1]
	runTrack:AdjustSpeed(level and level.RunAnimSpeed or 1.2)
end

player:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
	if player:GetAttribute("OnTreadmill") then
		startRunning()
		popup("Jump to get off", Color3.new(1, 1, 1), false, 160)
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
		if st.ghost then
			local a = 0.25 + (math.sin(t * 2.5) + 1) * 0.2
			for _, p in st.ghost do
				p.LocalTransparencyModifier = a
			end
		elseif model:GetAttribute("Runner") then
			local level = TreadmillConfig.Levels[model:GetAttribute("Level") or 1]
			st.phase = (st.phase + (level and level.BeltSpeed or 8) * dt) % (BELT_HALF * 2)
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
