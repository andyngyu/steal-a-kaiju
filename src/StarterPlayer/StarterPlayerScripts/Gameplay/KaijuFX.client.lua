-- World animations, client-only and purely visual (reads server attributes, never changes gameplay):
--   kaiju: walk with hop + waddle, smooth turning, idle bob, random emotes (hop-spin, look around, wiggle), hatch pop-out, "+$" popups
--   eggs:  toss arc + landing squash, nest bob, incubating wobble (faster near the end), ready bounce + glow, hatch shake + shell burst
--   misc:  carried egg hover/spin, pen fence rising after an upgrade, guardian Z Z float
--   grand hatches (EggConfig.IsGrand: Epic+ or Huge+): egg levitates + spins inside a rarity light pillar with inward sparkles
--     and pulse rings, triple shockwave + confetti on burst, kaiju leaps out and slams down, "GIANT LEGENDARY!" banner
--     over it for everyone nearby, camera shake (strongest for the owner). Big (non-grand) hatches get a small banner.
--   chat: GameEvent "HatchAnnouncement" -> coloured system message in the general channel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local TextChatService = game:GetService("TextChatService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EggConfig = require(Config.EggConfig)
local BaseConfig = require(Config.BaseConfig)
local KaijuConfig = require(Config.KaijuConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local gameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent")

local player = Players.LocalPlayer

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

-- Rarity colour that can change over time (Secret cycles through the rainbow).
local function liveColor(id, t)
	if id == "Secret" then
		return Color3.fromHSV((t * 0.35) % 1, 0.55, 1)
	end
	return rarityColor(id)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFB84D")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFF04D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4DFF88")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("4DB8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("C44DFF")),
})

-- Colour of a grand hatch: the rarity colour for Epic+, gold when it's grand only because of its size.
local SIZE_GOLD = Color3.fromHex("FFD84A")
local function grandColor(id, t)
	local r = EggConfig.RarityById[id or ""]
	if r and r.Order >= EggConfig.Announce.MinRarityOrder then
		return liveColor(id, t)
	end
	return SIZE_GOLD
end

local function bannerGradient(id)
	if id == "Secret" then
		return RAINBOW
	end
	local c = grandColor(id, 0)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(0.5, c:Lerp(Color3.new(1, 1, 1), 0.6)),
		ColorSequenceKeypoint.new(1, c),
	})
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

local function burstParticles(pos, color, count, speed, size)
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
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.9), NumberSequenceKeypoint.new(1, 0) })
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

local function shockwave(pos, color, size, duration)
	duration = duration or 0.5
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
	TweenService:Create(ringPart, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ringPart, duration + 0.1)
end

local function dust(pos, scale)
	scale = scale or 1
	for _ = 1, math.min(14, math.floor(6 + 3 * (scale - 1))) do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CastShadow = false
		puff.Color = Color3.fromHex("F2EBDD")
		puff.Size = Vector3.one * 0.8 * scale
		puff.Transparency = 0.2
		puff.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
		puff.Parent = fxFolder
		local a = rng:NextNumber(0, math.pi * 2)
		local goal = pos + Vector3.new(math.cos(a) * 2.2, 0.8, math.sin(a) * 2.2) * scale
		TweenService:Create(puff, TweenInfo.new(0.45 + 0.1 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal), Size = Vector3.one * 1.8 * scale, Transparency = 1 }):Play()
		Debris:AddItem(puff, 0.6 + 0.1 * scale)
	end
end

local CONFETTI = {
	Color3.fromHex("FF4D6D"),
	Color3.fromHex("FFD84A"),
	Color3.fromHex("4DD8FF"),
	Color3.fromHex("6BE04A"),
	Color3.fromHex("C44DFF"),
	Color3.fromHex("FF9F1C"),
}

-- Floaty paper bits: real physics with most of gravity cancelled so they drift down slowly.
local function confetti(pos, count, scale)
	local s = math.clamp(scale or 1, 1, 2.2)
	for _ = 1, count do
		local bit = Instance.new("Part")
		bit.Size = Vector3.new(0.35, 0.06, 0.22) * s
		bit.Color = CONFETTI[rng:NextInteger(1, #CONFETTI)]
		bit.Material = Enum.Material.SmoothPlastic
		bit.CanCollide = false
		bit.CanQuery = false
		bit.CanTouch = false
		bit.CastShadow = false
		bit.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local att = Instance.new("Attachment")
		att.Parent = bit
		local lift = Instance.new("VectorForce")
		lift.Attachment0 = att
		lift.RelativeTo = Enum.ActuatorRelativeTo.World
		lift.ApplyAtCenterOfMass = true
		lift.Parent = bit
		bit.Parent = fxFolder
		lift.Force = Vector3.new(0, bit.AssemblyMass * workspace.Gravity * 0.88, 0)
		local a = rng:NextNumber(0, math.pi * 2)
		bit.AssemblyLinearVelocity = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 10) * s + Vector3.new(0, rng:NextNumber(14, 24), 0)
		bit.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		task.delay(2.3, function()
			if bit.Parent then
				TweenService:Create(bit, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(bit, 3)
	end
end

-- Camera shake: offset applied after the camera scripts run and removed again before they run next frame,
-- so it never drifts the player's view.
local shakeAmp = 0
local shakeOffset = CFrame.identity

local function addShake(amount, at)
	if at then
		local d = (workspace.CurrentCamera.CFrame.Position - at).Magnitude
		amount *= math.clamp(1.2 - d / 120, 0, 1)
	end
	shakeAmp = math.max(shakeAmp, amount)
end

-- Grand hatch build-up: light pillar + pulsing ground ring + sparkles sucked into the egg.
local function neonCylinder(name, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(1, 0.1, 0.1)
	p.Parent = fxFolder
	return p
end

local function startCharge(model, color)
	local shell = model.PrimaryPart
	local scale = shell.Size.Y / EggConfig.Size.Y
	local ch = {
		ground = shell.Position - Vector3.new(0, shell.Size.Y / 2, 0),
		scale = scale,
		core = neonCylinder("PillarCore", color, 1),
		glow = neonCylinder("PillarGlow", color, 1),
		ring = neonCylinder("ChargeRing", color, 1),
	}
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 14 * scale
	holder.CFrame = CFrame.new(shell.Position)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.Speed = NumberRange.new(9 * scale, 12 * scale)
	pe.Lifetime = NumberRange.new(0.6, 0.7)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2 * scale),
		NumberSequenceKeypoint.new(0.7, 0.6 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new(0.2, 0)
	pe.Rate = 0
	pe.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Shadows = false
	light.Brightness = 0
	light.Parent = holder
	holder.Parent = fxFolder
	ch.holder, ch.emitter, ch.light = holder, pe, light
	return ch
end

local PILLAR_HEIGHT = 90

local function updateCharge(ch, k, t, color)
	local s = ch.scale
	local fade = math.min(k * 3, 1)
	local w = (0.4 + 1.4 * k) * s * (1 + math.sin(t * 40) * 0.08)
	local up = CFrame.new(ch.ground + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ch.core.Size = Vector3.new(PILLAR_HEIGHT, w, w)
	ch.core.CFrame = up
	ch.core.Transparency = 1 - 0.8 * fade
	ch.glow.Size = Vector3.new(PILLAR_HEIGHT, w * 2.2, w * 2.2)
	ch.glow.CFrame = up
	ch.glow.Transparency = 1 - 0.2 * fade
	local r = (5 + 5 * k + math.sin(t * 12) * 0.6) * s
	ch.ring.Size = Vector3.new(0.12, r, r)
	ch.ring.CFrame = CFrame.new(ch.ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ch.ring.Transparency = 1 - 0.55 * fade
	for _, p in { ch.core, ch.glow, ch.ring } do
		p.Color = color
	end
	ch.emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	ch.emitter.Rate = 20 + 120 * k
	ch.light.Color = color
	ch.light.Range = math.min(8 + 14 * k * s, 40)
	ch.light.Brightness = 0.5 + 2.5 * k
end

local function stopCharge(ch)
	ch.emitter.Rate = 0
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, p in { ch.core, ch.glow } do
		TweenService:Create(p, info, { Size = Vector3.new(PILLAR_HEIGHT, p.Size.Y * 3, p.Size.Z * 3), Transparency = 1 }):Play()
	end
	TweenService:Create(ch.ring, info, { Transparency = 1 }):Play()
	TweenService:Create(ch.light, info, { Brightness = 0 }):Play()
	for _, p in { ch.core, ch.glow, ch.ring, ch.holder } do
		Debris:AddItem(p, 1)
	end
end

local function shellBurst(model, color, grand)
	local shell = model.PrimaryPart
	if not shell then
		return
	end
	local pos = shell.Position
	local scale = shell.Size.Y / EggConfig.Size.Y
	local ground = pos - Vector3.new(0, shell.Size.Y / 2 - 0.1, 0)
	local kick = math.sqrt(scale) * (grand and 1.3 or 1)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		elseif p:IsA("BillboardGui") then
			p.Enabled = false
		elseif p:IsA("PointLight") then
			p.Enabled = false
		end
	end
	for i = 1, grand and 24 or 12 do
		local shard = Instance.new("WedgePart")
		local s = rng:NextNumber(0.5, 1) * scale
		shard.Size = Vector3.new(0.25 * scale, s, s * 0.8)
		shard.Color = i % 3 == 0 and color or shell.Color
		shard.Material = i % 3 == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-0.8, 0.8)) * scale) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Parent = fxFolder
		local out = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		out = out.Magnitude > 0.01 and out.Unit or Vector3.xAxis
		shard.AssemblyLinearVelocity = (out * rng:NextNumber(10, 18) + Vector3.new(0, rng:NextNumber(18, 28), 0)) * kick
		shard.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(1.1, function()
			if shard.Parent then
				TweenService:Create(shard, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(shard, 1.8)
	end
	flash(pos, color, 9 * scale * (grand and 1.6 or 1))
	shockwave(ground, color, 14 * scale)
	burstParticles(pos, color, grand and 90 or 45, 22 * kick, 0.9 * math.sqrt(scale))
	if grand then
		task.delay(0.12, shockwave, ground, Color3.new(1, 1, 1), 24 * scale, 0.6)
		task.delay(0.26, shockwave, ground, color, 34 * scale, 0.75)
		confetti(pos + Vector3.new(0, 2 * scale, 0), 50, scale)
	end
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

local function bannerLabel(parent, text, font, height, order, strokeThickness)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, height, 0)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Color3.fromHex("1A1033")
	stroke.Parent = l
	l.Parent = parent
	return l, stroke
end

-- "GIANT LEGENDARY!" over a freshly hatched kaiju (world billboard, everyone nearby sees it).
local function hatchBanner(model, st)
	local rarityId = model:GetAttribute("Rarity") or "Common"
	local size = model:GetAttribute("Size") or 1
	local tier = model:GetAttribute("SizeTier") or ""
	local cfg = KaijuConfig[model:GetAttribute("Species") or ""]
	local grand = st.grand
	local headline = (tier ~= "" and string.upper(tier) .. " " or "") .. (grand and string.upper(rarityId) or "") .. "!"
	headline = headline:gsub(" !", "!")
	local bb = Instance.new("BillboardGui")
	bb.Name = "HatchBanner"
	bb.AlwaysOnTop = false -- sits well above the kaiju; AlwaysOnTop billboards also failed to show in Studio captures
	bb.LightInfluence = 0
	bb.MaxDistance = grand and 320 or 140
	bb.Size = UDim2.fromOffset(grand and 440 or 260, grand and 130 or 84)
	bb.StudsOffsetWorldSpace = Vector3.new(0, st.rig.size.Y + (grand and 7 or 4.5), 0)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = bb
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = frame
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = frame
	local head, headStroke = bannerLabel(frame, headline, Enum.Font.LuckiestGuy, 0.64, 1, grand and 5 or 3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = bannerGradient(rarityId)
	gradient.Parent = head
	local subText = string.format("%s  %.2fx  %s", cfg and cfg.DisplayName or "", size, Format.PerSecond(model:GetAttribute("CashPerSecond") or 0))
	local sub, subStroke = bannerLabel(frame, subText, Enum.Font.FredokaOne, 0.36, 2, 2.5)
	bb.Parent = model.PrimaryPart -- local-only child; goes away with the model
	-- The banner repeats the name tag, so hide the tag while it's up.
	local info = model.PrimaryPart:FindFirstChild("Info")
	if info then
		info.Enabled = false
	end

	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gradient, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.6, 0) }):Play()
	gradient.Offset = Vector2.new(-0.6, 0)
	local hold = grand and 6 or 3.5
	task.delay(hold, function()
		if not bb.Parent then
			return
		end
		local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pop, out, { Scale = 0.6 }):Play()
		for _, obj in { head, sub } do
			TweenService:Create(obj, out, { TextTransparency = 1 }):Play()
		end
		for _, obj in { headStroke, subStroke } do
			TweenService:Create(obj, out, { Transparency = 1 }):Play()
		end
		Debris:AddItem(bb, 0.6)
		task.delay(0.5, function()
			if info and info.Parent then
				info.Enabled = true
			end
		end)
	end)
end

-- Grand reveal landing: shockwaves, dust, confetti and a camera jolt.
local function slam(model, st, pos)
	local color = grandColor(model:GetAttribute("Rarity"), os.clock())
	local s = st.scale
	local ground = pos + Vector3.new(0, 0.1, 0)
	shockwave(ground, color, 16 * s, 0.6)
	task.delay(0.1, shockwave, ground, Color3.new(1, 1, 1), 26 * s, 0.75)
	dust(pos, s)
	confetti(pos + Vector3.new(0, st.rig.size.Y, 0), 60, s)
	burstParticles(pos + Vector3.new(0, st.rig.size.Y * 0.5, 0), color, 60, 20 * math.sqrt(s), 1.2 * math.sqrt(s))
	addShake(st.owned and 1.1 or 0.7, pos)
end

local function addKaiju(model)
	if not model:IsA("Model") or kaiju[model] then
		return
	end
	local rig = makeRig(model)
	local _, yaw = rig.base:ToEulerAnglesYXZ()
	local scale = model:GetAttribute("VisualScale") or 1
	local st = {
		rig = rig,
		scale = scale,
		owned = model:GetAttribute("OwnerUserId") == player.UserId,
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
		local rarityId = model:GetAttribute("Rarity")
		local size = model:GetAttribute("Size") or 1
		st.grand = EggConfig.IsGrand(rarityId or "Common", size)
		st.popStart = os.clock()
		st.popLen = st.grand and 1.4 or 0.9
		st.popHeight = 3.2 * math.sqrt(scale) * (st.grand and 1.6 or 1)
		burstParticles(rig.base.Position + Vector3.new(0, rig.size.Y * 0.4, 0), rarityColor(rarityId), st.grand and 50 or 30, 14 * math.sqrt(scale))
		if st.grand or (model:GetAttribute("SizeTier") or "") ~= "" then
			hatchBanner(model, st)
		end
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
		st.phase += dt * 10 / math.sqrt(st.scale)
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
		local p = (os.clock() - st.popStart) / st.popLen
		if p >= 1 then
			st.popStart = nil
			if st.grand then
				slam(model, st, pos)
			end
		else
			y += math.sin(p * math.pi) * st.popHeight
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
	local st = { rig = makeRig(model), seed = rng:NextNumber(0, 100), half = model.PrimaryPart.Size.Y / 2 }
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
	local half = st.half

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
			local anim = model:GetAttribute("HatchAnim") or BaseConfig.Hatch.AnimSeconds
			local grand = model:GetAttribute("HatchGrand")
			local owned = model:GetAttribute("OwnerUserId") == player.UserId
			local e = serverNow() - hatchStart
			local build = anim - 0.3
			if e < build then
				local p = math.clamp(e / build, 0, 1)
				local k = p ^ 2
				local amp = grand and 1.25 or 1
				roll = rng:NextNumber(-1, 1) * 0.35 * k * amp
				pitch = rng:NextNumber(-1, 1) * 0.25 * k * amp
				y = math.abs(math.sin(t * 38)) * 0.25 * k
				if grand then
					local color = grandColor(model:GetAttribute("Rarity"), t)
					y += p * p * (3 - 2 * p) * half * 0.9 -- rises off the ground
					yaw = e * e * 1.2 -- spins faster and faster
					st.charge = st.charge or startCharge(model, color)
					updateCharge(st.charge, k, t, color)
					if os.clock() >= (st.nextPulse or 0) then
						st.nextPulse = os.clock() + lerp(0.7, 0.18, k)
						shockwave(st.charge.ground + Vector3.new(0, 0.1, 0), color, (6 + 10 * k) * st.charge.scale)
					end
					addShake(owned and 0.08 + 0.4 * k or 0.25 * k, not owned and base.Position or nil)
				end
			elseif not st.burst then
				st.burst = true
				if st.charge then
					stopCharge(st.charge)
					st.charge = nil
				end
				local rarityId = model:GetAttribute("Rarity")
				shellBurst(model, grand and grandColor(rarityId, t) or rarityColor(rarityId), grand)
				if grand then
					addShake(owned and 0.9 or 0.6, base.Position)
				end
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
			local offset = egg:GetAttribute("CarryOffset") or EggConfig.Carry.OverheadOffset
			weld.C0 = CFrame.new(0, offset + math.sin(t * 3) * 0.25, 0) * CFrame.Angles(math.sin(t * 2) * 0.12, t * 1.6, 0)
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
		if st.charge then
			stopCharge(st.charge)
		end
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

-- Hatch announcements (server sends these for grand hatches) -> coloured system line in chat.
local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

gameEvent.OnClientEvent:Connect(function(kind, data)
	if kind ~= "HatchAnnouncement" or type(data) ~= "table" then
		return
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if not general then
		return
	end
	local rarity = EggConfig.RarityById[data.Rarity or ""]
	local tier = (data.SizeTier or "") ~= "" and string.upper(data.SizeTier) .. " " or ""
	local what = tier .. tostring(data.Rarity or "")
	local article = what:sub(1, 1):match("[AEIOUaeiou]") and "an" or "a"
	general:DisplaySystemMessage(string.format(
		'<font color="#FFD84A"><b>%s</b></font> hatched %s <font color="#%s"><b>%s %s</b></font>! <font color="#6BE04A">(%.2fx size)</font>',
		escape(data.PlayerName or "Someone"),
		article,
		rarity and rarity.Color:ToHex() or "FFFFFF",
		escape(what),
		escape(data.DisplayName or data.Species or "kaiju"),
		tonumber(data.Size) or 1
	))
end)

RunService:BindToRenderStep("KaijuShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
	if shakeOffset ~= CFrame.identity then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * shakeOffset:Inverse()
		shakeOffset = CFrame.identity
	end
end)

RunService:BindToRenderStep("KaijuShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmp < 0.003 then
		shakeAmp = 0
		return
	end
	local n = os.clock() * 24
	local a = shakeAmp
	shakeOffset = CFrame.new(math.noise(n, 1.7) * a * 0.7, math.noise(n, 2.3) * a * 0.7, 0)
		* CFrame.Angles(math.noise(n, 3.1) * a * 0.05, math.noise(n, 4.9) * a * 0.05, math.noise(n, 5.3) * a * 0.04)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * shakeOffset
	shakeAmp *= math.exp(-5 * dt)
end)

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
