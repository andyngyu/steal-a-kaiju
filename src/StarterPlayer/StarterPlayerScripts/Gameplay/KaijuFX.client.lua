-- World animations, client-only and purely visual (reads server attributes, never changes gameplay):
--   kaiju: walk with hop + waddle, smooth turning, idle bob, random emotes (hop-spin, look around, wiggle), hatch pop-out, "+$" popups
--   eggs:  toss arc + landing squash, nest bob, incubating wobble (faster near the end), ready bounce + glow, hatch shake + shell burst
--   misc:  carried egg hover/spin, pen fence rising after an upgrade, guardian Z Z float
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EggConfig = require(Config.EggConfig)
local BaseConfig = require(Config.BaseConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local runtime = workspace:WaitForChild("Runtime")
local kaijuFolder = runtime:WaitForChild("Kaiju")
local eggFolder = runtime:WaitForChild("Eggs")
local guardianFolder = runtime:WaitForChild("Guardians")
local plotsFolder = workspace:WaitForChild("Map"):WaitForChild("Plots")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "KaijuFXLocal"
fxFolder.Parent = workspace

local rng = Random.new()
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local ANIM_RANGE = 220
local POPUP_RANGE = 90

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpAngle(a, b, t)
	local d = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + d * t
end

local function rarityColor(id)
	local r = EggConfig.RarityById[id or ""]
	return r and r.Color or Color3.new(1, 1, 1)
end

-- Rigid animator: remembers each part's offset from the model pivot and moves all parts together in one call.
local function makeRig(model)
	local pivot = model:GetPivot()
	local parts, offsets = {}, {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			table.insert(offsets, pivot:ToObjectSpace(p.CFrame))
		end
	end
	local _, size = model:GetBoundingBox()
	return { parts = parts, offsets = offsets, base = pivot, size = size, cfs = table.create(#parts) }
end

local function pose(rig, cf)
	for i, off in rig.offsets do
		rig.cfs[i] = cf * off
	end
	workspace:BulkMoveTo(rig.parts, rig.cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ---------- one-shot effects ----------

local function burstParticles(pos, color, count, speed)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Drag = 3
	pe.Rate = 0
	pe.Parent = holder
	holder.Parent = fxFolder
	pe:Emit(count)
	Debris:AddItem(holder, 2)
end

local function flash(pos, color, size)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one
	ball.Transparency = 0.1
	ball.CFrame = CFrame.new(pos)
	ball.Parent = fxFolder
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.5)
end

local function shockwave(pos, color, size)
	local ringPart = Instance.new("Part")
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart.Anchored = true
	ringPart.CanCollide = false
	ringPart.CanQuery = false
	ringPart.CastShadow = false
	ringPart.Material = Enum.Material.Neon
	ringPart.Color = color
	ringPart.Size = Vector3.new(0.15, 1, 1)
	ringPart.Transparency = 0.2
	ringPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ringPart.Parent = fxFolder
	TweenService:Create(ringPart, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ringPart, 0.6)
end

local function dust(pos)
	for _ = 1, 6 do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CastShadow = false
		puff.Color = Color3.fromHex("F2EBDD")
		puff.Size = Vector3.one * 0.8
		puff.Transparency = 0.2
		puff.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
		puff.Parent = fxFolder
		local a = rng:NextNumber(0, math.pi * 2)
		local goal = pos + Vector3.new(math.cos(a) * 2.2, 0.8, math.sin(a) * 2.2)
		TweenService:Create(puff, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal), Size = Vector3.one * 1.8, Transparency = 1 }):Play()
		Debris:AddItem(puff, 0.5)
	end
end

local function shellBurst(model, color)
	local shell = model.PrimaryPart
	if not shell then
		return
	end
	local pos = shell.Position
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		elseif p:IsA("BillboardGui") then
			p.Enabled = false
		elseif p:IsA("PointLight") then
			p.Enabled = false
		end
	end
	for i = 1, 12 do
		local shard = Instance.new("WedgePart")
		local s = rng:NextNumber(0.5, 1)
		shard.Size = Vector3.new(0.25, s, s * 0.8)
		shard.Color = i % 3 == 0 and color or shell.Color
		shard.Material = i % 3 == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-0.8, 0.8))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Parent = fxFolder
		local out = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		out = out.Magnitude > 0.01 and out.Unit or Vector3.xAxis
		shard.AssemblyLinearVelocity = out * rng:NextNumber(10, 18) + Vector3.new(0, rng:NextNumber(18, 28), 0)
		shard.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(1.1, function()
			if shard.Parent then
				TweenService:Create(shard, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(shard, 1.8)
	end
	flash(pos, color, 9)
	shockwave(pos - Vector3.new(0, EggConfig.Size.Y / 2 - 0.1, 0), color, 14)
	burstParticles(pos, color, 45, 22)
end

local function cashPopup(part, height, amount)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(110, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = POPUP_RANGE
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromHex("6BE04A")
	l.TextStrokeTransparency = 0.1
	l.Text = "+" .. Format.Money(amount)
	l.Parent = bb
	bb.Parent = part
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffsetWorldSpace = Vector3.new(0, height + 2.5, 0) }):Play()
	TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.3)
end

-- ---------- kaiju ----------

local kaiju = {}

local EMOTES = {
	{ name = "HopSpin", duration = 0.7 },
	{ name = "Look", duration = 1.6 },
	{ name = "Wiggle", duration = 0.8 },
	{ name = "Hop", duration = 0.45 },
}

local function addKaiju(model)
	if not model:IsA("Model") or kaiju[model] then
		return
	end
	local rig = makeRig(model)
	local _, yaw = rig.base:ToEulerAnglesYXZ()
	local st = {
		rig = rig,
		seed = rng:NextNumber(0, 100),
		yaw = yaw,
		phase = 0,
		moveBlend = 0,
		hopHeight = 0.25 + rig.size.Y * 0.07,
		nextEmote = os.clock() + rng:NextNumber(2, 7),
		nextPopup = os.clock() + rng:NextNumber(0, BaseConfig.IncomePopupSeconds),
	}
	local spawned = model:GetAttribute("SpawnedAt")
	if spawned and serverNow() - spawned < 1.5 then
		st.popStart = os.clock()
		local color = rarityColor(model:GetAttribute("Rarity"))
		burstParticles(rig.base.Position + Vector3.new(0, 1.5, 0), color, 30, 14)
	end
	kaiju[model] = st
end

local function updateKaiju(model, st, dt, t, camPos)
	local from, to = model:GetAttribute("WanderFrom"), model:GetAttribute("WanderTo")
	local ms, me = model:GetAttribute("MoveStart"), model:GetAttribute("MoveEnd")
	if not (from and to and ms and me) then
		return
	end
	local now = serverNow()
	local alpha = me > ms and math.clamp((now - ms) / (me - ms), 0, 1) or 1
	local pos = from:Lerp(to, alpha)
	local dist = (pos - camPos).Magnitude
	if dist > ANIM_RANGE then
		return
	end
	local moving = alpha < 1 and now >= ms
	local dir = to - from
	if moving and dir.Magnitude > 0.05 then
		st.yaw = lerpAngle(st.yaw, math.atan2(-dir.X, -dir.Z), 1 - math.exp(-8 * dt))
		st.phase += dt * 10
		st.emote = nil
	end
	st.moveBlend = lerp(st.moveBlend, moving and 1 or 0, 1 - math.exp(-10 * dt))

	local y = math.abs(math.sin(st.phase)) * st.hopHeight * st.moveBlend + math.sin(t * 2.2 + st.seed) * 0.06 * (1 - st.moveBlend)
	local roll = math.sin(st.phase) * 0.14 * st.moveBlend
	local pitch = -0.08 * st.moveBlend
	local extraYaw = 0

	if not moving and st.moveBlend < 0.1 then
		if not st.emote and os.clock() > st.nextEmote then
			st.emote = EMOTES[rng:NextInteger(1, #EMOTES)]
			st.emoteStart = os.clock()
		end
	end
	if st.emote then
		local e = (os.clock() - st.emoteStart) / st.emote.duration
		if e >= 1 then
			st.emote = nil
			st.nextEmote = os.clock() + rng:NextNumber(4, 10)
		elseif st.emote.name == "HopSpin" then
			y += math.sin(e * math.pi) * (1 + st.hopHeight * 2)
			extraYaw += e * math.pi * 2
		elseif st.emote.name == "Hop" then
			y += math.sin(e * math.pi) * (0.6 + st.hopHeight)
		elseif st.emote.name == "Look" then
			extraYaw += math.sin(e * math.pi * 2) * 0.7
		elseif st.emote.name == "Wiggle" then
			roll += math.sin(e * math.pi * 6) * 0.22 * (1 - e)
		end
	end

	if st.popStart then
		local p = (os.clock() - st.popStart) / 0.9
		if p >= 1 then
			st.popStart = nil
		else
			y += math.sin(p * math.pi) * 3.2
			extraYaw += (1 - p) ^ 2 * math.pi * 4
			roll += math.sin(p * math.pi * 3) * 0.2 * (1 - p)
		end
	end

	pose(st.rig, CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, st.yaw + extraYaw, 0) * CFrame.Angles(pitch, 0, roll))

	if os.clock() >= st.nextPopup then
		st.nextPopup = os.clock() + BaseConfig.IncomePopupSeconds
		local cps = model:GetAttribute("CashPerSecond")
		if cps and dist < POPUP_RANGE and model.PrimaryPart then
			cashPopup(model.PrimaryPart, st.rig.size.Y + 2.4, cps * BaseConfig.IncomePopupSeconds)
		end
	end
end

-- ---------- eggs ----------

local eggs = {}

local function addEgg(model)
	if not model:IsA("Model") or eggs[model] or not model.PrimaryPart then
		return
	end
	local st = { rig = makeRig(model), seed = rng:NextNumber(0, 100) }
	local from, at = model:GetAttribute("DropFrom"), model:GetAttribute("DroppedAt")
	if from and at and serverNow() - at < 0.8 then
		st.tossFrom = from
		st.tossStart = os.clock()
	end
	eggs[model] = st
end

local function setGlow(model, st, on)
	if on and not st.highlight then
		local h = Instance.new("Highlight")
		h.FillColor = rarityColor(model:GetAttribute("Rarity"))
		h.OutlineColor = Color3.new(1, 1, 1)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = model
		h.Parent = fxFolder
		st.highlight = h
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SPARKLE
		pe.Color = ColorSequence.new(h.FillColor)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Speed = NumberRange.new(1, 3)
		pe.Lifetime = NumberRange.new(0.6, 1)
		pe.Rate = 8
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = model.PrimaryPart
		st.sparkles = pe
	elseif not on and st.highlight then
		st.highlight:Destroy()
		st.highlight = nil
		if st.sparkles then
			st.sparkles:Destroy()
			st.sparkles = nil
		end
	end
end

local function updateEgg(model, st, t, camPos)
	local rig = st.rig
	local base = rig.base
	if (base.Position - camPos).Magnitude > ANIM_RANGE then
		return
	end
	local half = EggConfig.Size.Y / 2

	if st.tossStart then
		local p = (os.clock() - st.tossStart) / 0.45
		if p < 1 then
			local pos = st.tossFrom:Lerp(base.Position, p) + Vector3.new(0, math.sin(p * math.pi) * 3, 0)
			pose(rig, CFrame.new(pos) * CFrame.Angles(p * math.pi * 2, 0, p * math.pi))
			return
		end
		st.tossStart = nil
		st.landedAt = os.clock()
		dust(base.Position - Vector3.new(0, half, 0))
	end

	local state = model:GetAttribute("State")
	local y, pitch, yaw, roll = 0, 0, 0, 0

	if state == "Pen" then
		local hatchStart = model:GetAttribute("HatchStartedAt")
		if hatchStart then
			setGlow(model, st, false)
			local anim = BaseConfig.Hatch.AnimSeconds
			local e = serverNow() - hatchStart
			if e < anim - 0.3 then
				local k = math.clamp(e / (anim - 0.3), 0, 1) ^ 2
				roll = rng:NextNumber(-1, 1) * 0.35 * k
				pitch = rng:NextNumber(-1, 1) * 0.25 * k
				y = math.abs(math.sin(t * 38)) * 0.25 * k
			elseif not st.burst then
				st.burst = true
				shellBurst(model, rarityColor(model:GetAttribute("Rarity")))
				return
			else
				return
			end
		elseif model:GetAttribute("Ready") then
			setGlow(model, st, true)
			local b = math.abs(math.sin(t * 5 + st.seed))
			y = b * 0.7
			roll = math.sin(t * 10 + st.seed) * 0.08
			if st.highlight then
				st.highlight.FillTransparency = 0.55 + math.sin(t * 6) * 0.25
			end
		else
			local left = (model:GetAttribute("HatchAt") or 0) - serverNow()
			local soon = left < 15
			local period = soon and 1.1 or 3.5
			local w = (t + st.seed) % period
			if w < 0.6 then
				roll = math.sin(w * 26) * 0.12 * (1 - w / 0.6) * (soon and 1.8 or 1)
			end
		end
	else -- Nest / Ground
		y = math.sin(t * 1.6 + st.seed) * 0.12
		yaw = math.sin(t * 0.8 + st.seed) * 0.15
	end

	if st.landedAt then
		local l = os.clock() - st.landedAt
		if l < 0.4 then
			pitch += math.sin(l * 30) * 0.18 * (1 - l / 0.4)
		else
			st.landedAt = nil
		end
	end

	pose(rig, base * CFrame.new(0, -half, 0) * CFrame.Angles(pitch, yaw, roll) * CFrame.new(0, half + y, 0))
end

-- ---------- carried eggs, guardians, pens ----------

local function updateCarried(t)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local egg = char and char:FindFirstChild("Egg")
		local shell = egg and egg.PrimaryPart
		local weld = shell and shell:FindFirstChild("CarryWeld")
		if weld then
			weld.C0 = CFrame.new(0, EggConfig.Carry.OverheadOffset + math.sin(t * 3) * 0.25, 0) * CFrame.Angles(math.sin(t * 2) * 0.12, t * 1.6, 0)
		end
	end
end

local zzBase = {}
local function updateGuardians(t)
	for _, g in guardianFolder:GetChildren() do
		local head = g:FindFirstChild("Head")
		local zz = head and head:FindFirstChild("Sleep")
		if zz then
			zzBase[zz] = zzBase[zz] or zz.StudsOffsetWorldSpace
			zz.StudsOffsetWorldSpace = zzBase[zz] + Vector3.new(math.sin(t * 1.5) * 0.4, math.sin(t * 1.8) * 0.6, 0)
		end
		local alert = head and head:FindFirstChild("Alert")
		if alert and alert.Enabled then
			local s = 1 + math.abs(math.sin(t * 8)) * 0.3
			alert.Size = UDim2.fromOffset(160 * s, 60 * s)
		end
	end
end

local function riseFence(pen)
	local built = pen:GetAttribute("BuiltAt")
	if not built or serverNow() - built > 2 then
		return
	end
	local plot = pen.Parent
	local origin = plot and plot:GetAttribute("PenOrigin") or pen:GetPivot().Position
	local parts = {}
	for _, p in pen:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
	end)
	local maxDist = #parts > 0 and (parts[#parts].Position - origin).Magnitude or 1
	for _, p in parts do
		local goal = p.CFrame
		p.CFrame = goal - Vector3.new(0, 5, 0)
		local delay = (p.Position - origin).Magnitude / maxDist * 0.6
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { CFrame = goal }):Play()
	end
	local sign = plot and plot:FindFirstChild("UpgradeSign")
	if sign and sign.PrimaryPart then
		burstParticles(sign.PrimaryPart.Position, plot:GetAttribute("Color") or Color3.new(1, 1, 1), 40, 18)
	end
end

-- ---------- wiring ----------

kaijuFolder.ChildAdded:Connect(addKaiju)
kaijuFolder.ChildRemoved:Connect(function(m)
	kaiju[m] = nil
end)
for _, m in kaijuFolder:GetChildren() do
	addKaiju(m)
end

eggFolder.ChildAdded:Connect(addEgg)
eggFolder.ChildRemoved:Connect(function(m)
	local st = eggs[m]
	if st then
		setGlow(m, st, false)
	end
	eggs[m] = nil
end)
for _, m in eggFolder:GetChildren() do
	addEgg(m)
end

local function watchPlot(plot)
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Pen" then
			task.defer(riseFence, child)
		end
	end)
end
for _, plot in plotsFolder:GetChildren() do
	watchPlot(plot)
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, st in kaiju do
		if model.Parent then
			updateKaiju(model, st, dt, t, camPos)
		end
	end
	for model, st in eggs do
		if model.Parent == eggFolder then
			updateEgg(model, st, t, camPos)
		end
	end
	updateCarried(t)
	updateGuardians(t)
end)
