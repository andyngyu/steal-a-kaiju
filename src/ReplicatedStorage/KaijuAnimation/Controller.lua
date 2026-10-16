-- KaijuAnimation.Controller: the client controller of the kaiju animation engine.
--   Register(model, info)   queues a creature; its rig is built a slice per frame (Config.Performance.BuildBudgetMs)
--   every frame (RunService.PreSimulation): each creature updates at its tier's rate (Motion, then VFX)
--   batched pass (ClassifyHz): distance and on-screen checks, tiers with caps (own kaiju first), states, particle budget
--   actions: random from the creature's list, never more than ActionShare of the visible creatures in any second
--   Command(...): debug control (the Studio tools call it through KaijuAnimationClient's Debug BindableFunction)
-- Live kaiju are only taken over for species in Config.Rollout (empty in Phase 1: only the Studio Gallery registers).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local Rig = require(script.Parent.Rig)
local Motion = require(script.Parent.Motion)
local Actions = require(script.Parent.Actions)
local States = require(script.Parent.States)
local VFX = require(script.Parent.VFX)

local Controller = {}

local player = Players.LocalPlayer
local perf = Config.Performance
local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local caps = mobile and perf.Caps.Mobile or perf.Caps.Desktop
local buildBudget = (mobile and perf.BuildBudgetMs.Mobile or perf.BuildBudgetMs.Desktop) / 1000
local particleBudget = mobile and perf.Particles.Mobile or perf.Particles.Desktop
local TAU = Util.TAU
local TIER_NAMES = { [0] = "Full", [1] = "Reduced", [2] = "Far", [3] = "Off" }

local creatures = {} -- live (rigged) records
local pending = {} -- waiting for their rig
local byModel = {}
local clock = 0 -- controller time in seconds (slow motion included)
local frame = 0
local slowmo = 1
local frozen = false
local forcedNight = nil
local labels = false
local particleFactor = 1
local nextClassify = 0
local actionStarts = {}
local shakeAmp, shakeOffset = 0, CFrame.identity
local stats = { Full = 0, Reduced = 0, Far = 0, Off = 0, Pending = 0, Ms = 0, Particles = 0, Builds = 0, BuildMs = 0 }
Controller.Stats = stats

-- KaijuMotion (Gameplay) voices actions through GameAudio; Settings for camera shake and reduced effects
local kaijuMotion, settings
local function gameplayModule(name)
	local ps = player and player:FindFirstChild("PlayerScripts")
	local gp = ps and ps:FindFirstChild("Gameplay")
	local m = gp and gp:FindFirstChild(name)
	if m then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
	end
	return nil
end

local function setting(name, default)
	settings = settings or gameplayModule("Settings")
	if settings and settings.Get then
		local ok, v = pcall(settings.Get, name)
		if ok and v ~= nil then
			return v
		end
	end
	return default
end

------------------------------------------------------------------------------------------------------- helpers

local function merge(profile, overrides)
	local out = {}
	for k, v in profile do
		out[k] = v
	end
	for k, v in overrides do
		if type(v) == "table" and type(out[k]) == "table" and #v == 0 then
			local m = {}
			for k2, v2 in out[k] do
				m[k2] = v2
			end
			for k2, v2 in v do
				m[k2] = v2
			end
			out[k] = m
		else
			out[k] = v
		end
	end
	return out
end

local function findPath(model, path)
	local inst = model
	for name in string.gmatch(path or "", "[^/]+") do
		inst = inst and inst:FindFirstChild(name)
	end
	return inst ~= model and inst or nil
end

local function byChain(a, b)
	return a.chain < b.chain
end

local function shake(amount)
	if setting("CameraShake", true) then
		shakeAmp = math.max(shakeAmp, amount)
	end
end

local function fireSound(rec, name)
	kaijuMotion = kaijuMotion or gameplayModule("KaijuMotion")
	if kaijuMotion and kaijuMotion.FireEmote then
		kaijuMotion.FireEmote(rec.model, name)
	end
end

Actions.OnEvent = function(rec, kind, arg, amount)
	if kind == "Sound" then
		if rec.tier <= 1 then
			fireSound(rec, arg)
		end
	elseif kind == "Shake" then
		local d = rec.dist or math.huge
		if d < 60 then
			shake(arg * math.clamp(1.15 - d / 60, 0, 1))
		end
	elseif rec.tier <= 1 then
		VFX.Event(rec, kind, arg, amount)
	end
end

-- at most ActionShare of the visible creatures may start an action in any one second
local function canStart()
	local n = 0
	for i = #actionStarts, 1, -1 do
		if clock - actionStarts[i] > 1 then
			table.remove(actionStarts, i)
		else
			n += 1
		end
	end
	local visible = stats.Full + stats.Reduced
	return n < math.max(1, math.floor(Config.Global.ActionShare * visible + 0.5))
end

local function startAction(rec, name)
	if Actions.Start(rec, name) then
		table.insert(actionStarts, clock)
		rec.lastAction = name
		return true
	end
	return false
end

local function scheduleActions(rec)
	if rec.action then
		return
	end
	if rec.queued then
		local q = rec.queued
		rec.queued = nil
		if q then
			startAction(rec, q)
		end
		return
	end
	if rec.tier > 1 or rec.sleep > 0.5 or rec.doze > 0.5 or rec.panic > 0.5 or rec.noActions then
		return
	end
	if clock < rec.nextActionAt then
		local IH = rec.P.IdleHop
		if IH and clock >= (rec.nextHopAt or 0) then
			if rec.nextHopAt and canStart() then
				startAction(rec, IH.Action)
			end
			rec.nextHopAt = clock + Util.range(rec.rng, IH.Every) / rec.fidget
		end
		return
	end
	if not canStart() then
		rec.nextActionAt = clock + rec.rng:NextNumber(0.3, 1.2)
		return
	end
	local list = rec.actionList
	if #list == 0 then
		rec.nextActionAt = math.huge
		return
	end
	local name = list[rec.rng:NextInteger(1, #list)]
	if name == rec.lastAction and #list > 1 then
		name = list[rec.rng:NextInteger(1, #list)]
	end
	startAction(rec, name)
	local dur = rec.action and rec.action.duration or 0
	rec.nextActionAt = clock + dur + Util.range(rec.rng, rec.rarity.ActionGap)
end

------------------------------------------------------------------------------------------------- registration

local function newJoint(name, role, motor, parent)
	return {
		name = name, role = role, motor = motor, parent = parent, kind = 0,
		side = 0, chain = 1, stab = 0, spring = false, omega = 1, zeta = 1, inertia = 0,
		curlX = 0, curlZ = 0, plant = 1, plantDefault = 1, planted = false,
		ax = 0, ay = 0, az = 0, tx = 0, ty = 0, tz = 0, curl = 0,
		sx = 0, sy = 0, sz = 0, svx = 0, svy = 0, svz = 0,
		pwx = 0, pwy = 0, pwz = 0, wx = 0, wy = 0, wz = 0,
		spin = 0, spinRate = 0, spinBoost = 0, spinAdd = 0,
	}
end

local function finalize(rec)
	local job, model = rec.job, rec.model
	local map, P = job.map, rec.P
	local scale = job.scale
	local rng = rec.rng
	rec.scale = scale
	rec.root = job.root
	rec.rootCF = job.root.CFrame
	local bbCF, bbSize = model:GetBoundingBox()
	rec.size = bbSize
	rec.height = map.size.Y * scale
	rec.centreOffset = rec.rootCF:PointToObjectSpace(bbCF.Position)
	rec.groundY = rec.centreOffset.Y - bbSize.Y / 2
	rec.radius = math.max(bbSize.X, bbSize.Z) / 2
	rec.bulk = (bbSize.X * bbSize.Y * bbSize.Z) ^ (1 / 3)
	rec.centerWorld = rec.rootCF * rec.centreOffset

	-- joint records
	local body = newJoint("Body", "Body", job.bodyMotor, nil)
	body.kind = 1
	body.c0 = job.bodyMotor.C0
	if job.bodyMotor.C1 ~= CFrame.identity then
		body.c1inv = job.bodyMotor.C1:Inverse()
	end
	body.restW = body.c0
	body.world = body.c0
	local joints, J = { body }, { Body = body }
	local records = {}
	local H = P.Head
	for i, jm in map.joints do
		local m = job.motors[i]
		local parent = jm.parent == 0 and body or records[jm.parent]
		local j = newJoint(jm.name, jm.role, m, parent)
		j.side, j.chain, j.chainId, j.tentacle = jm.side or 0, jm.chain or 1, jm.chainId, jm.tentacle
		j.c0 = m.C0
		local parentPart = parent.restW
		if parent.c1inv then
			parentPart *= parent.c1inv
		end
		j.restW = parentPart * j.c0
		j.restPos = j.restW.Position
		j.restRot = j.restW - j.restPos
		if jm.planted and parent == body and jm.foot then
			j.kind = 2
			j.planted = true
			j.foot = jm.foot * scale
			j.d0 = j.restPos - j.foot
			j.plantDefault = P.PlantWeight or 1
		elseif jm.axis then
			j.kind = 3
			j.axis = jm.axis.Unit
		end
		local S = Config.Springs[jm.role]
		if S then
			local hz, damping = S.Hz, S.Damping
			if jm.role == "Head" and H and H.Mode == "Snap" then
				hz, damping = H.SnapHz or hz, H.SnapDamping or damping
			end
			j.spring = true
			j.omega = TAU * hz / math.sqrt(scale) * rec.speed
			j.zeta = math.clamp(damping, 0.05, 0.98)
			j.inertia = S.Inertia + (S.Grow or 0) * (j.chain - 1)
		end
		if jm.role == "Head" then
			j.stab = H and H.Stabilize or 0
			j.hs = { seed = rng:NextNumber(0, 100), holdUntil = 0, ty = 0, tp = 0, tr = 0, nextGlance = 0, glanceUntil = 0, gy = 0, gp = 0, lookYaw = 0, lookPitch = 0 }
		end
		if jm.curl then
			j.curlX, j.curlZ = jm.curl.X, jm.curl.Z
		end
		records[i] = j
		table.insert(joints, j)
		J[j.name] = j
	end
	rec.joints, rec.J, rec.body = joints, J, body

	-- role lists
	local function list(role, sort)
		local out = {}
		for _, j in joints do
			if j.role == role then
				table.insert(out, j)
			end
		end
		if sort then
			table.sort(out, byChain)
		end
		return out
	end
	rec.heads = list("Head")
	rec.tail = list("Tail", true)
	rec.spine = list("Seg", true)
	rec.necks = list("Neck", true)
	rec.trunk = list("Trunk", true)
	rec.ears = list("Ear")
	rec.arms = list("Arm")
	rec.legs = list("Leg")
	rec.wings = list("Wing")
	rec.claws = list("Claw")
	rec.stalks = list("EyeStalk")
	rec.jaw, rec.tongue, rec.cloud = J.Jaw, J.Tongue, J.Cloud
	rec.halo, rec.ring, rec.moons = J.Halo, J.Ring, J.Moons
	if rec.halo then
		for _, jm in map.joints do
			if jm.name == "Halo" then
				rec.haloGroup = findPath(model, jm.path)
			end
		end
	end
	local O = P.Orbit
	if O then
		if rec.ring then
			rec.ring.spinRate = O.Ring * Util.RAD * rec.speed
		end
		if rec.moons then
			rec.moons.spinRate = O.Moons * Util.RAD * rec.speed
		end
	end
	-- tentacles: one chain per tentacle, each curling on its own frequency and phase
	local chains, chainOf = {}, {}
	for _, j in joints do
		if j.role == "Tentacle" then
			local c = chainOf[j.chainId]
			if not c then
				c = {}
				chainOf[j.chainId] = c
				table.insert(chains, c)
			end
			table.insert(c, j)
		end
	end
	rec.tentacleChains, rec.tentacleHz, rec.tentaclePhase = chains, {}, {}
	for ci, c in chains do
		table.sort(c, byChain)
		local T = P.Tentacles
		rec.tentacleHz[ci] = T and rng:NextNumber(T.Hz[1], T.Hz[2]) or 0.3
		rec.tentaclePhase[ci] = rng:NextNumber(0, TAU)
	end
	rec.breathJoint = P.Breath.Joint and J[P.Breath.Joint] or body
	rec.pulseHz = (P.Gills and P.Gills.Hz) or (P.Throat and P.Throat.Hz) or (P.Jaw and P.Jaw.Pulse and P.Jaw.Hz) or nil

	-- pivots the body can rotate about, in the body joint's frame
	local bodyPos = map.body.pos * scale
	rec.pivots = {
		Center = map.centre * scale - bodyPos,
		Hips = map.hips * scale - bodyPos,
		Shoulders = map.shoulders * scale - bodyPos,
	}
	rec.pivot, rec.pivotTarget = rec.pivots.Center, rec.pivots.Center

	-- breathing period from size (Config.Breath), desynced by the creature's speed
	local B = rec.guardian and Config.Breath.Guardian or (rec.bulk < Config.Breath.SmallBelow and Config.Breath.Small or Config.Breath.Large)
	local u = math.clamp((rec.bulk - B.Bulk[1]) / (B.Bulk[2] - B.Bulk[1]), 0, 1)
	rec.breathPeriod = B.Period[1] + (B.Period[2] - B.Period[1]) * u
	rec.breathRate = rec.speed * (P.Breath.Speed or 1) / rec.breathPeriod

	-- effects
	local fxParent = job.folder
	if not fxParent then
		fxParent = Instance.new("Folder")
		fxParent.Name = Rig.FolderName
		fxParent.Parent = model
	end
	local eyeSets = {}
	for _, parts in job.eyes do
		table.insert(eyeSets, parts)
	end
	VFX.Setup(rec, fxParent, eyeSets)
	Actions.Bind(rec)

	-- spawned a moment ago: the hatch pop
	local spawned = model:GetAttribute("SpawnedAt")
	if spawned and workspace:GetServerTimeNow() - spawned < Config.States.Hatched.Window then
		rec.queued = Config.States.Hatched.Action
	end
	rec.ready = true
	rec.job = nil
	table.insert(creatures, rec)
end

-- info: { name = Config.Creatures key, rarity, biome, owner (UserId), guardian = true for guardian rigs }
function Controller.Register(model, info)
	if byModel[model] then
		return byModel[model]
	end
	local spec = Config.Creatures[info.name]
	if not spec or not model.PrimaryPart then
		return nil
	end
	local profileName = spec.Profile
	local overrides = {}
	for k, v in spec do
		if k ~= "Profile" and k ~= "Rename" and k ~= "Parents" and k ~= "Guardian" and k ~= "Shimmer" then
			overrides[k] = v
		end
	end
	local P = merge(Config.Profiles[profileName], overrides)
	local rarityId = info.rarity or "Common"
	local rng = Random.new()
	local jitter = Config.Global.SpeedJitter
	local rarity = Config.Rarity[rarityId] or Config.Rarity.Common
	local speed = rng:NextNumber(jitter[1], jitter[2])
	local rec = {
		model = model, name = info.name, spec = spec, P = P, profileName = profileName,
		rarityId = rarityId, rarity = rarity, biome = info.biome, ownerId = info.owner or 0, guardian = info.guardian == true,
		rng = rng, seed = rng:NextNumber(0, 1000), speed = speed, tempo = speed * rarity.Tempo, fidget = rarity.Fidget,
		t = rng:NextNumber(0, 100), breathPhase = rng:NextNumber(), breath = 0,
		tempoMul = 1, breathMul = 1, breathAmp = 1, ampMul = 1, glowMul = 1, glow = 0, calm = 0, weight = 0,
		lookW = 0, lookWTarget = 0, alert = 0, alertTarget = 0, panic = 0, panicTarget = 0,
		sleep = 0, sleepTarget = 0, doze = 0, dozeTarget = 0, night = 0, nightTarget = 0,
		dozer = rng:NextNumber() < Config.States.Night.DozeShare, headYaw = 0,
		tm = {}, tier = 3, slot = rng:NextInteger(0, 5), acc = 0, dist = math.huge,
		nextActionAt = clock + Util.range(rng, Config.Global.FirstAction),
	}
	byModel[model] = rec
	table.insert(pending, rec)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			Controller.Unregister(model)
		end
	end)
	return rec
end

function Controller.Unregister(model)
	local rec = byModel[model]
	if not rec then
		return
	end
	byModel[model] = nil
	for _, list in { creatures, pending } do
		for i, r in list do
			if r == rec then
				table.remove(list, i)
				break
			end
		end
	end
	if rec.label then
		rec.label:Destroy()
	end
end

-- Shared predicate for Gameplay.KaijuFX at rollout: true when this engine animates the model.
function Controller.Handles(model)
	return byModel[model] ~= nil
end

local function buildStep()
	if #pending == 0 then
		return
	end
	local t0 = os.clock()
	local deadline = t0 + buildBudget
	while #pending > 0 and os.clock() < deadline do
		local rec = pending[1]
		if not rec.model.Parent then
			table.remove(pending, 1)
			continue
		end
		local ok, err = pcall(function()
			if not rec.job then
				if rec.guardian then
					rec.job = Rig.FromMotors(rec.model, rec.spec, rec.profileName, rec.P)
				else
					rec.job = Rig.Begin(rec.model, Rig.Analyze(rec.model, rec.spec, rec.profileName, rec.P))
				end
				if not rec.job then
					error("no rig")
				end
			end
			if Rig.Step(rec.job, deadline) then
				table.remove(pending, 1)
				finalize(rec)
				stats.Builds += 1
			end
		end)
		if not ok then
			warn("[KaijuAnimation] could not rig " .. tostring(rec.name) .. ": " .. tostring(err))
			table.remove(pending, 1)
			byModel[rec.model] = nil
		end
	end
	stats.BuildMs += (os.clock() - t0) * 1000
end

------------------------------------------------------------------------------------------------ classification

local ctx = { people = {}, userId = player and player.UserId or 0, now = 0, night = false }
local order = {}
local function byEffective(a, b)
	return a.eff < b.eff
end

local function updateLabel(rec)
	if not labels then
		if rec.label then
			rec.label.Enabled = false
		end
		return
	end
	if not rec.label then
		local bb = Instance.new("BillboardGui")
		bb.Name = "_AnimLabel"
		bb.Size = UDim2.fromOffset(240, 44)
		bb.StudsOffsetWorldSpace = Vector3.new(0, rec.size.Y + 2, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 400
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.2
		l.Parent = bb
		bb.Adornee = rec.root
		bb.Parent = rec.root
		rec.label = bb
	end
	rec.label.Enabled = true
	local colors = { [0] = "7CFF6B", [1] = "FFD84A", [2] = "FF9F4A", [3] = "FF5A5A" }
	rec.label.TextLabel.RichText = true
	rec.label.TextLabel.Text = string.format('%s  <font color="#%s">%s %.0f</font>\n%s%s', rec.name, colors[rec.tier], TIER_NAMES[rec.tier], rec.dist,
		rec.state and rec.state.Name or "?", rec.action and ("  " .. rec.action.name) or "")
end

local function classify()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local tanY = math.tan(math.rad(cam.FieldOfView / 2))
	local vp = cam.ViewportSize
	local tanX = tanY * (vp.Y > 0 and vp.X / vp.Y or 1.78)

	-- who is around (read only)
	table.clear(ctx.people)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local head = char:FindFirstChild("Head") or hrp
			table.insert(ctx.people, { userId = p.UserId, pos = hrp.Position, head = head })
		end
	end
	ctx.now = clock
	if forcedNight ~= nil then
		ctx.night = forcedNight
	else
		ctx.night = workspace:GetAttribute("IsNight") == true
	end

	table.clear(order)
	for _, rec in creatures do
		if rec.root.Parent then
			rec.rootCF = rec.root.CFrame
			rec.centerWorld = rec.rootCF * rec.centreOffset
			local d = (rec.centerWorld - camPos).Magnitude
			local v = camCF:PointToObjectSpace(rec.centerWorld)
			local z, r = -v.Z, rec.radius + rec.size.Y
			rec.visible = d < r or (z > -r and math.abs(v.X) <= z * tanX + r and math.abs(v.Y) <= z * tanY + r)
			rec.dist = d
			rec.eff = d * ((rec.ownerId == ctx.userId and rec.ownerId ~= 0) and perf.OwnBaseBonus or 1)
			States.Evaluate(rec, ctx)
			VFX.Near(rec, d)
			table.insert(order, rec)
		end
	end
	table.sort(order, byEffective)
	local nFull, nReduced, nFar, nOff = 0, 0, 0, 0
	local particles = 0
	for _, rec in order do
		local d = rec.dist
		local tier
		if rec.forcedTier then
			tier = rec.forcedTier
		elseif not rec.visible or d > perf.Far then
			tier = 3
		elseif d <= perf.Full and nFull < caps.Full then
			tier = 0
		elseif d <= perf.Reduced and nReduced < caps.Reduced then
			tier = 1
		else
			tier = 2
		end
		if tier == 0 then
			nFull += 1
		elseif tier == 1 then
			nReduced += 1
		elseif tier == 2 then
			nFar += 1
		else
			nOff += 1
		end
		particles += VFX.ParticleCost(rec, tier)
		if tier ~= rec.tier then
			rec.tier = tier
			rec.tierDirty = true
		end
	end
	-- particle budget (Reduced Effects cuts it to about a third)
	local budget = particleBudget * (setting("ReducedEffects", false) and 0.35 or 1)
	local factor = particles > budget and budget / particles or 1
	local refactor = math.abs(factor - particleFactor) > 0.1
	if refactor then
		particleFactor = factor
	end
	for _, rec in order do
		if rec.tierDirty or refactor then
			rec.tierDirty = false
			VFX.SetTier(rec, rec.tier, particleFactor)
		end
		updateLabel(rec)
	end
	stats.Full, stats.Reduced, stats.Far, stats.Off = nFull, nReduced, nFar, nOff
	stats.Pending = #pending
	stats.Particles = math.floor(math.min(particles, budget) + 0.5)
end

----------------------------------------------------------------------------------------------------- the loop

local function update(rec, dt, lod)
	scheduleActions(rec)
	Motion.Step(rec, dt, lod)
	VFX.Update(rec, dt, lod, clock)
end

local function step(rawDt)
	local t0 = os.clock()
	buildStep()
	local dt = math.min(rawDt, 0.1) * slowmo
	clock += dt
	frame += 1
	if t0 >= nextClassify then
		nextClassify = t0 + 1 / perf.ClassifyHz
		classify()
	end
	if not frozen then
		local every = stats.Reduced > perf.CrowdedAt and perf.ReducedEveryCrowded or perf.ReducedEvery
		local farStep = 1 / perf.FarHz
		for _, rec in creatures do
			rec.acc += dt
			local tier = rec.tier
			if tier == 0 then
				if rec.dist <= perf.FullNear or rec.forcedTier == 0 or (frame + rec.slot) % perf.FullEvery == 0 then
					update(rec, rec.acc, 0)
					rec.acc = 0
				end
			elseif tier == 1 then
				if (frame + rec.slot) % every == 0 then
					update(rec, rec.acc, 1)
					rec.acc = 0
				end
			elseif tier == 2 then
				if rec.acc >= farStep * slowmo then
					update(rec, rec.acc, 2)
					rec.acc = 0
				end
			elseif rec.acc > 1 then
				rec.acc = 1
			end
		end
	end
	local ms = (os.clock() - t0) * 1000
	stats.Ms = stats.Ms + (ms - stats.Ms) * 0.05
end

local started = false
function Controller.Start()
	if started then
		return
	end
	started = true
	RunService.PreSimulation:Connect(step)
	-- camera shake: added after the camera scripts run, removed again before they run next frame
	RunService:BindToRenderStep("KaijuAnimShakeUndo", Enum.RenderPriority.Camera.Value - 2, function()
		if shakeOffset ~= CFrame.identity then
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * shakeOffset:Inverse()
			shakeOffset = CFrame.identity
		end
	end)
	RunService:BindToRenderStep("KaijuAnimShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if shakeAmp < 0.003 then
			shakeAmp = 0
			return
		end
		local n = os.clock() * 24
		local a = shakeAmp
		shakeOffset = CFrame.new(math.noise(n, 1.7) * a * 0.6, math.noise(n, 2.3) * a * 0.6, 0) * CFrame.Angles(math.noise(n, 3.1) * a * 0.04, math.noise(n, 4.9) * a * 0.04, 0)
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * shakeOffset
		shakeAmp *= math.exp(-5 * dt)
	end)
end

------------------------------------------------------------------------------------------------------- debug

local function find(name)
	for _, rec in creatures do
		if rec.name == name then
			return rec
		end
	end
	return nil
end
Controller.Find = find

local function targets(name)
	if name == "all" or name == nil then
		return creatures
	end
	local r = find(name)
	return r and { r } or {}
end

function Controller.Creatures()
	return creatures
end

-- The numbers behind a creature's motion, for tuning by name.
function Controller.Numbers(rec)
	local P = rec.P
	local lines = {}
	local function add(s)
		table.insert(lines, s)
	end
	add(string.format("%s: %s, %s, scale %.2f, speed x%.2f, tempo x%.2f", rec.name, rec.profileName, rec.rarityId, rec.scale, rec.speed, rec.tempo))
	add(string.format("Breathing: period %.2f s (%.2f s before desync), lift %.3f studs, pitch %.1f deg", 1 / rec.breathRate, rec.breathPeriod, (P.Breath.Lift or 0) * rec.scale, (P.Breath.Pitch or 0) * Config.Global.Exaggerate))
	if P.Shift then
		add(string.format("Weight shift: roll %.1f deg, slide %.3f studs, about %.1f s per sway", P.Shift.Roll * Config.Global.Exaggerate, (P.Shift.Slide or 0) * rec.scale, 1 / P.Shift.Hz / rec.tempo))
	end
	if P.Head then
		local H = P.Head
		add(string.format("Head: look-around yaw %d deg, pitch %d deg, tilt %d deg, %s", H.Yaw * Config.Global.Exaggerate, H.Pitch * Config.Global.Exaggerate, (H.Tilt or 0) * Config.Global.Exaggerate,
			H.Mode == "Snap" and string.format("holds %.1f to %.1f s then snaps", H.Hold[1], H.Hold[2]) or string.format("glances %d deg every %.0f to %.0f s", H.Glance or 0, (H.GlanceEvery or { 0, 0 })[1], (H.GlanceEvery or { 0, 0 })[2])))
	end
	local seen = {}
	for _, j in rec.joints do
		if j.spring and not seen[j.role] then
			seen[j.role] = true
			add(string.format("Spring %s: %.2f Hz, damping %.2f, inertia %.2f", j.role, j.omega / TAU, j.zeta, j.inertia))
		end
	end
	add("Actions: " .. table.concat(rec.actionList, ", "))
	return table.concat(lines, "\n")
end

-- Samples a creature for a while: the farthest each planted foot drifts and the largest angle per joint.
local function probe(rec, seconds)
	local feet = {}
	for _, j in rec.joints do
		if j.kind == 2 then
			local localFoot = j.restW:PointToObjectSpace(j.foot)
			table.insert(feet, { j = j, localFoot = localFoot, start = nil, max = 0, maxLifted = 0 })
		end
	end
	local maxAngle = {}
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		RunService.PostSimulation:Wait()
		for _, f in feet do
			local pos = f.j.motor.Part1.CFrame:PointToWorldSpace(f.localFoot)
			f.start = f.start or pos
			local d = (pos - f.start).Magnitude
			if f.j.plant > 0.99 then
				f.max = math.max(f.max, d)
			else
				f.maxLifted = math.max(f.maxLifted, d)
			end
		end
		for _, j in rec.joints do
			local x, y, z = j.motor.Transform:ToEulerAnglesYXZ()
			local a = math.deg(math.max(math.abs(x), math.abs(y), math.abs(z)))
			maxAngle[j.name] = math.max(maxAngle[j.name] or 0, a)
		end
	end
	local out = {}
	for _, f in feet do
		table.insert(out, string.format("foot %s: drift %.4f studs while planted (%.2f while lifted)", f.j.name, f.max, f.maxLifted))
	end
	local names = {}
	for n in maxAngle do
		table.insert(names, n)
	end
	table.sort(names)
	local parts = {}
	for _, n in names do
		table.insert(parts, string.format("%s %.1f", n, maxAngle[n]))
	end
	table.insert(out, "max angle (deg): " .. table.concat(parts, ", "))
	return table.concat(out, "\n")
end

function Controller.Status()
	return string.format("Full %d  Reduced %d  Far %d  Off %d  |  building %d  |  %.2f ms per frame  |  particles about %d",
		stats.Full, stats.Reduced, stats.Far, stats.Off, stats.Pending, stats.Ms, stats.Particles)
end

function Controller.Command(cmd, a, b)
	if cmd == "status" then
		return Controller.Status()
	elseif cmd == "list" then
		local names = {}
		for _, rec in creatures do
			table.insert(names, string.format("%s (%s, %s, %s)", rec.name, rec.profileName, TIER_NAMES[rec.tier], rec.state and rec.state.Name or "?"))
		end
		return table.concat(names, "\n")
	elseif cmd == "action" then
		local n = 0
		for _, rec in targets(a) do
			if Actions.Start(rec, b) then
				n += 1
				rec.nextActionAt = clock + rec.action.duration + Util.range(rec.rng, rec.rarity.ActionGap)
			end
		end
		return n
	elseif cmd == "state" then
		for _, rec in targets(a) do
			rec.forcedState = b
		end
		nextClassify = 0
		return true
	elseif cmd == "slowmo" then
		slowmo = tonumber(a) or 1
		return slowmo
	elseif cmd == "freeze" then
		frozen = a == true
		return frozen
	elseif cmd == "labels" then
		labels = a == true
		nextClassify = 0
		return labels
	elseif cmd == "night" then
		forcedNight = a
		nextClassify = 0
		return forcedNight
	elseif cmd == "actions" then
		local rec = find(a)
		if not rec then
			return ""
		end
		local names = {}
		for name in rec.actionBinds do
			table.insert(names, name)
		end
		table.sort(names)
		return table.concat(rec.actionList, ",") .. " | all: " .. table.concat(names, ",")
	elseif cmd == "numbers" then
		local rec = find(a)
		return rec and Controller.Numbers(rec) or "not found"
	elseif cmd == "probe" then
		local rec = find(a)
		return rec and probe(rec, tonumber(b) or 3) or "not found"
	elseif cmd == "noactions" then
		for _, rec in creatures do
			rec.noActions = a == true
		end
		return true
	elseif cmd == "tier" then
		for _, rec in targets(a) do
			rec.forcedTier = b
		end
		nextClassify = 0
		return true
	elseif cmd == "pose" then
		local rec = find(a)
		if not rec then
			return "not found"
		end
		local out = {}
		for _, j in rec.joints do
			local x, y, z = j.motor.Transform:ToEulerAnglesYXZ()
			local p = j.motor.Transform.Position
			table.insert(out, string.format("%s p%.1f y%.1f r%.1f t(%.2f,%.2f,%.2f)", j.name, math.deg(x), math.deg(y), math.deg(z), p.X, p.Y, p.Z))
		end
		return table.concat(out, "\n")
	end
	return "unknown command " .. tostring(cmd)
end

return Controller
