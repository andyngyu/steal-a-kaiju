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
local stats = { Full = 0, Reduced = 0, Far = 0, Off = 0, Pending = 0, Ms = 0, Particles = 0, Builds = 0, BuildMs = 0, MotionMs = 0, VFXMs = 0, MoveMs = 0 }
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
	if rec.forceAction then
		Actions.Start(rec, rec.forceAction)
		rec.forceAction = nil
		return
	end
	if rec.action then
		return
	end
	if rec.struggle then
		Actions.Start(rec, "Wiggle") -- someone is holding Steal on it: it struggles until they stop
		return
	end
	local walking = rec.moveBlend and rec.moveBlend > 0.1
	if rec.queuedUntil and clock > rec.queuedUntil then
		rec.queued, rec.queuedUntil = nil, nil
	end
	if rec.queued then
		if walking and rec.queued ~= "Eat" then
			return -- greetings wait until it stops
		end
		local q = rec.queued
		rec.queued, rec.queuedUntil = nil, nil
		startAction(rec, q)
		return
	end
	if walking or rec.tier > 1 or rec.sleep > 0.5 or rec.doze > 0.5 or rec.panic > 0.5 or rec.noActions then
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
		sx = 0, sy = 0, sz = 0, svx = 0, svy = 0, svz = 0, fox = 0, foy = 0, foz = 0,
		pwx = 0, pwy = 0, pwz = 0, wx = 0, wy = 0, wz = 0,
		spin = 0, spinRate = 0, spinBoost = 0, spinAdd = 0,
	}
end

-- Just put in this pen (delivered from a steal or equipped: PlacedAt, server time): it greets its new home, unless a
-- hatch pop is already waiting.
local function arrive(rec)
	local placed = rec.model:GetAttribute("PlacedAt")
	if placed and workspace:GetServerTimeNow() - placed < Config.States.Placed.Window and not rec.queued then
		rec.queued = States.GreetFor(rec)
		rec.queuedUntil = clock + Config.States.Placed.Window -- off screen until later: it doesn't greet late
	end
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
	-- walking: the gait, which way the feet travel (crabs walk sideways), leg length for the stride
	local gaitName = P.Gait or Config.ProfileGaits[rec.profileName]
	local G = gaitName and Config.Gaits[gaitName]
	rec.gait = G
	rec.faceOffset = (G and G.Sideways) and math.pi / 2 or 0
	rec.travelDir = Vector3.new(math.sin(rec.faceOffset), 0, -math.cos(rec.faceOffset))
	local legSum, legs = 0, 0
	for _, j in joints do
		if G and G.Phase and G.Phase[j.name] and j.kind == 2 then
			j.gaitOffset = G.Phase[j.name]
			legSum += j.d0.Magnitude
			legs += 1
		end
	end
	rec.legLength = legs > 0 and math.max(legSum / legs, 0.5) or 1
	rec.moveBlend, rec.moveSpeed, rec.gaitPhase = 0, 0, 0
	rec.pos = rec.root.Position
	local look = rec.rootCF.LookVector
	rec.yaw = math.atan2(-look.X, -look.Z)
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
	-- a live guardian runs on its own gait (Motion's guardian layer) and plays nothing unprompted: its moods come from
	-- GuardianService, and GameAudio / GameVFX already voice its roar
	if rec.liveGuardian then
		local hum = model:FindFirstChildOfClass("Humanoid")
		local groundY = -(rec.root.Size.Y / 2 + (hum and hum.HipHeight or 0))
		local legL, legR = J.LegL, J.LegR
		rec.run = {
			speed = 0, moving = 0, run = 0, phase = 0, turnRate = 0, yawOffset = 0, bank = 0, lift = 0, wobble = 0,
			chomp = 0, hold = 0, holdJaw = Config.States.Guardian.HoldJaw, dip = 0, ape = P.Run == "Ape", groundY = groundY,
			legLength = legL and math.max(1.5, legL.restPos.Y - groundY) or 4,
			legXL = legL and legL.restPos.X or -1.5,
			legXR = legR and legR.restPos.X or 1.5,
		}
		rec.gait = nil
	end
	VFX.Setup(rec, fxParent, eyeSets)
	Actions.Bind(rec)
	if rec.liveGuardian then
		rec.actionList = {}
	end

	-- spawned a moment ago: the hatch pop
	local spawned = model:GetAttribute("SpawnedAt")
	if spawned and not rec.carried and workspace:GetServerTimeNow() - spawned < Config.States.Hatched.Window then
		rec.queued = Config.States.Hatched.Action
	end
	if rec.live then
		arrive(rec)
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
	if info.liveGuardian then
		rec.liveGuardian = true
	end
	if info.carried then
		-- over a thief's head: panics the whole way (States.Carried), never walks or plays idle actions
		rec.carried = true
		rec.forcedState = "Carried"
	end
	if info.live then
		-- read-only game state: the wander path, thrown food landing, someone holding Steal on it
		rec.live = true
		local function wander()
			rec.wFrom, rec.wTo = model:GetAttribute("WanderFrom"), model:GetAttribute("WanderTo")
			rec.mStart, rec.mEnd = model:GetAttribute("MoveStart"), model:GetAttribute("MoveEnd")
		end
		wander()
		for _, a in { "WanderFrom", "WanderTo", "MoveStart", "MoveEnd" } do
			model:GetAttributeChangedSignal(a):Connect(wander)
		end
		model:GetAttributeChangedSignal("EatAt"):Connect(function()
			rec.forceAction = "Eat" -- food interrupts whatever it was doing
		end)
		model:GetAttributeChangedSignal("PlacedAt"):Connect(function()
			if rec.ready then
				arrive(rec) -- set just after it appeared; before the rig is ready, finalize catches it
			end
		end)
		model:GetAttributeChangedSignal("StealBy"):Connect(function()
			rec.struggle = model:GetAttribute("StealBy") ~= nil
		end)
		rec.struggle = model:GetAttribute("StealBy") ~= nil
	end
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
			-- a carried copy is built in one go: it is small, and a half-built rig would hang off a running character
			if Rig.Step(rec.job, rec.carried and math.huge or deadline) then
				if rec.carried then
					Rig.Release(rec.job)
				end
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

-- Walking roots are moved together once a frame (one BulkMoveTo, CFrame events only): each anchored root carries a whole
-- welded rig, and a property write per root costs far more.
local moveParts, moveCFs = {}, {}

-- A live kaiju walks its server wander path (WanderFrom to WanderTo between MoveStart and MoveEnd), turning smoothly.
-- Only the root's CFrame is written, and only while it moves or turns.
local function updateMove(rec, dt)
	local from, to, ms, me = rec.wFrom, rec.wTo, rec.mStart, rec.mEnd
	if not (from and to and ms and me) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local alpha = me > ms and math.clamp((now - ms) / (me - ms), 0, 1) or 1
	local pos = from:Lerp(to, alpha)
	local moving = alpha < 1 and now >= ms
	local dir = to - from
	local yaw = rec.yaw
	if moving and dir.Magnitude > 0.05 then
		local heading = math.atan2(-dir.X, -dir.Z) + rec.faceOffset
		local d = (heading - yaw + math.pi) % TAU - math.pi
		yaw += d * (1 - math.exp(-6 * dt))
		rec.moveSpeed = dir.Magnitude / math.max(me - ms, 0.05)
	end
	rec.moveBlend += ((moving and 1 or 0) - rec.moveBlend) * (1 - math.exp(-8 * dt))
	local turn = yaw - rec.yaw
	if math.abs(turn) > 1e-5 then
		-- tails, heads and necks lag the turn and swing back
		for _, j in rec.joints do
			if j.spring and j.parent == rec.body then
				j.sy -= turn * j.inertia * 0.6
			end
		end
	end
	rec.yaw = yaw
	if (pos - rec.pos).Magnitude > 1e-4 or math.abs(turn) > 1e-5 then
		rec.pos = pos
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		table.insert(moveParts, rec.root)
		table.insert(moveCFs, cf)
		rec.rootCF = cf
		rec.centerWorld = cf * rec.centreOffset
	end
end

local function wrapAngle(a)
	return (a + math.pi) % TAU - math.pi
end

-- a copy bursting out of the ground or sinking back into it
local function groundBurst(rec)
	Actions.OnEvent(rec, "Dust", nil, math.clamp(rec.height / 6, 1, 3))
	Actions.OnEvent(rec, "Shake", 0.45)
end

-- A live guardian's inputs for Motion's guardian layer, all read from game state: its Humanoid-driven speed and heading,
-- its player (TargetUserId) while it chases, the egg it hauls (CarryingEgg), a copy's RiseAt / SinkAt.
local function updateGuardian(rec, dt)
	local R, model, root = rec.run, rec.model, rec.root
	local cf = root.CFrame
	rec.rootCF = cf
	rec.centerWorld = cf * rec.centreOffset
	local k6 = 1 - math.exp(-6 * dt)
	local v = root.AssemblyLinearVelocity
	R.speed += (Vector3.new(v.X, 0, v.Z).Magnitude - R.speed) * k6
	local sp = R.speed
	R.moving = math.clamp((sp - 1) / 5, 0, 1)
	R.run = math.clamp(sp / 30, 0, 1.2) * R.moving
	rec.moveBlend = R.moving -- quiets the idles and holds actions while it runs
	-- the Humanoid snaps to each new goal: the visible body turns after it smoothly and banks into the turn
	local look = cf.LookVector
	local rootYaw = math.atan2(-look.X, -look.Z)
	R.yaw = R.yaw or rootYaw
	local turn = math.clamp(wrapAngle(rootYaw - R.yaw) * (1 - math.exp(-9 * dt)), -7 * dt, 7 * dt)
	R.yaw = wrapAngle(R.yaw + turn)
	R.turnRate += (turn / math.max(dt, 1e-3) - R.turnRate) * (1 - math.exp(-8 * dt))
	R.yawOffset = wrapAngle(R.yaw - rootYaw)
	R.bank = math.clamp(R.turnRate * 0.07, -0.22, 0.22) * R.moving
	local near = false
	if model:GetAttribute("State") == "Chasing" then
		local who = Players:GetPlayerByUserId(model:GetAttribute("TargetUserId") or 0)
		local hrp = who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
		near = hrp ~= nil and (hrp.Position - cf.Position).Magnitude < Config.States.Chasing.Chomp + rec.height * 0.5
	end
	R.chomp += ((near and 1 or 0) - R.chomp) * k6
	R.hold += ((model:GetAttribute("CarryingEgg") ~= nil and 1 or 0) - R.hold) * (1 - math.exp(-8 * dt))
	local H = Config.States.Guardian
	R.holdJaw = model:GetAttribute("HoldJaw") or H.HoldJaw -- GuardianService fits the egg to this opening
	-- reaching down for a dropped egg: down, a moment low, back up
	local dip = 0
	local grabAt = model:GetAttribute("GrabAt")
	if grabAt then
		local e = workspace:GetServerTimeNow() - grabAt
		if e >= 0 and e < H.GrabDown then
			dip = Util.smooth(e / H.GrabDown)
		elseif e >= H.GrabDown and e < H.GrabDown + H.GrabLow then
			dip = 1
		elseif e >= H.GrabDown + H.GrabLow then
			dip = 1 - Util.smooth(math.clamp((e - H.GrabDown - H.GrabLow) / H.GrabUp, 0, 1))
		end
	end
	R.dip = dip
	local riseAt, sinkAt = model:GetAttribute("RiseAt"), model:GetAttribute("SinkAt")
	R.lift, R.wobble = 0, 0
	if sinkAt or riseAt then
		local now = workspace:GetServerTimeNow()
		local wob = math.sin(os.clock() * 30)
		if sinkAt then
			local k = math.clamp((now - sinkAt) / H.Sink, 0, 1)
			R.lift = -(k ^ 2) * rec.height * 1.1
			R.wobble = wob * 0.05 * (1 - k)
			if not R.sinkFx then
				R.sinkFx = true
				groundBurst(rec)
			end
		else
			local k = math.clamp((now - riseAt) / H.Rise, 0, 1)
			R.lift = -((1 - k) ^ 3) * rec.height * 1.1
			R.wobble = wob * 0.06 * (1 - k)
			if not R.riseFx and k < 1 then
				R.riseFx = true
				groundBurst(rec)
			end
		end
	end
end

local function update(rec, dt, lod)
	if rec.live then
		updateMove(rec, dt)
	elseif rec.run then
		updateGuardian(rec, dt)
	elseif rec.carried then
		-- the thief moves it every frame
		rec.rootCF = rec.root.CFrame
		rec.centerWorld = rec.rootCF * rec.centreOffset
	end
	scheduleActions(rec)
	local t0 = os.clock()
	Motion.Step(rec, dt, lod)
	local t1 = os.clock()
	VFX.Update(rec, dt, lod, clock)
	stats.motionAcc = (stats.motionAcc or 0) + t1 - t0
	stats.vfxAcc = (stats.vfxAcc or 0) + os.clock() - t1
end

local fpsEma = 30 -- smoothed frame rate, for Performance.FastFps

local function step(rawDt)
	local t0 = os.clock()
	buildStep()
	local dt = math.min(rawDt, 0.1) * slowmo
	clock += dt
	frame += 1
	fpsEma += (1 / math.max(rawDt, 1e-3) - fpsEma) * 0.05
	local fullEvery = fpsEma >= perf.FastFps and perf.FullEveryFast or perf.FullEvery
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
				if rec.dist <= perf.FullNear or rec.forcedTier == 0 or (frame + rec.slot) % fullEvery == 0 then
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
	local tm = os.clock()
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFs)
	end
	local ms = (os.clock() - t0) * 1000
	stats.Ms = stats.Ms + (ms - stats.Ms) * 0.05
	stats.MoveMs += ((os.clock() - tm) * 1000 - stats.MoveMs) * 0.05
	stats.MotionMs += ((stats.motionAcc or 0) * 1000 - stats.MotionMs) * 0.05
	stats.VFXMs += ((stats.vfxAcc or 0) * 1000 - stats.VFXMs) * 0.05
	stats.motionAcc, stats.vfxAcc = 0, 0
end

-- Big models reach the client over several frames: wait for every part (the server stamps PartCount), like KaijuFX.
local function whenComplete(model, fn)
	local want = model:GetAttribute("PartCount")
	local function have()
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and want and have() < want and os.clock() - t0 < 10 do
			task.wait(0.05)
		end
		if model.Parent then
			fn()
		end
	end)
end

-- Live pen kaiju of the rolled-out species (Config.Rollout); KaijuFX skips exactly these (Config.Handles).
function Controller.WatchLive()
	if #Config.Rollout == 0 then
		return
	end
	task.spawn(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local ok, KaijuConfig = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("KaijuConfig"))
		end)
		KaijuConfig = ok and KaijuConfig or {}
		local folder = workspace:WaitForChild("Runtime"):WaitForChild("Kaiju")
		local function add(m)
			if not (m:IsA("Model") and Config.Handles(m)) then
				return
			end
			whenComplete(m, function()
				if m.Parent ~= folder or not m.PrimaryPart then
					return
				end
				local species = m:GetAttribute("Species") or m.Name
				local kc = KaijuConfig[species] or {}
				Controller.Register(m, {
					name = species,
					rarity = m:GetAttribute("Rarity") or kc.Rarity,
					biome = kc.Biome,
					owner = m:GetAttribute("OwnerUserId"),
					live = true,
				})
			end)
		end
		folder.ChildAdded:Connect(add)
		for _, m in folder:GetChildren() do
			add(m)
		end
	end)
end

-- Stolen kaiju: StealService welds a shrunken copy ("StolenKaiju") over the thief's head. Each client rigs its own view
-- of it like a pen kaiju and holds it in the Carried state; the server's copy, CarryWeld and CarryPose are untouched.
function Controller.WatchCarried()
	local function watchCharacter(char)
		local function add(m)
			if not (m:IsA("Model") and m.Name == "StolenKaiju") then
				return
			end
			local species = m:GetAttribute("Species")
			if not (species and Config.Creatures[species] and table.find(Config.Rollout, species)) then
				return
			end
			whenComplete(m, function()
				if m.Parent == char and m.PrimaryPart then
					Controller.Register(m, { name = species, rarity = m:GetAttribute("Rarity"), carried = true })
				end
			end)
		end
		char.ChildAdded:Connect(add)
		for _, c in char:GetChildren() do
			add(c)
		end
	end
	local function watchPlayer(p)
		p.CharacterAdded:Connect(watchCharacter)
		if p.Character then
			watchCharacter(p.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
end

-- Live guardians (Runtime.Guardians) of the rolled-out biomes (Config.GuardianRollout); KaijuFX skips exactly these.
function Controller.WatchGuardians()
	if #Config.GuardianRollout == 0 then
		return
	end
	task.spawn(function()
		local folder = workspace:WaitForChild("Runtime"):WaitForChild("Guardians")
		local function add(m)
			if not (m:IsA("Model") and Config.Handles(m)) then
				return
			end
			-- a copy rising mid-game arrives before its parts (and guardians carry no PartCount): wait for the root and
			-- its Body motor, then a frame for the rest (short, so a rising copy never shows standing at full height)
			task.spawn(function()
				local t0 = os.clock()
				while m.Parent == folder and not (m.PrimaryPart and m.PrimaryPart:FindFirstChild("Body")) and os.clock() - t0 < 10 do
					task.wait(0.05)
				end
				task.wait()
				if m.Parent ~= folder or not m.PrimaryPart then
					return
				end
				local biome = m:GetAttribute("BiomeId")
				Controller.Register(m, { name = Config.GuardianFor(biome), rarity = "Guardian", biome = biome, guardian = true, liveGuardian = true })
			end)
		end
		folder.ChildAdded:Connect(add)
		for _, m in folder:GetChildren() do
			add(m)
		end
	end)
end

local started = false
function Controller.Start()
	if started then
		return
	end
	started = true
	Controller.WatchLive()
	Controller.WatchCarried()
	Controller.WatchGuardians()
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
	return string.format("Full %d  Reduced %d  Far %d  Off %d  |  building %d  |  %.2f ms per frame (pose %.2f, effects %.2f, walking %.2f)  |  particles about %d",
		stats.Full, stats.Reduced, stats.Far, stats.Off, stats.Pending, stats.Ms, stats.MotionMs, stats.VFXMs, stats.MoveMs, stats.Particles)
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
