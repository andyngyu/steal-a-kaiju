-- KaijuAnimation.States: what each creature is doing, read from game state (never written). A registry: each state has
-- a Priority, a Detect check (run in the controller's batched pass, with a shared context of who is around), optional
-- Enter / Exit / Tick hooks, and pose blends that States.Pose turns into joint offsets every frame. The highest-priority
-- state whose Detect passes is active; debug can force any state by name. Night is a modifier layered on top of any
-- state. Adding a state later (a raid boss, say) is one States.Register call: nothing else in the engine changes.
-- Detect reads: OwnerUserId on the model, player characters nearby, the guardian State attribute, workspace IsNight.
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local States = {}
States.List = {} -- highest priority first
States.ByName = {}

local RAD, TAU = Util.RAD, Util.TAU
local exp, clamp, sin, atan2, sqrt, deg = math.exp, math.clamp, math.sin, math.atan2, math.sqrt, math.deg

function States.Register(name, def)
	def.Name = name
	def.Priority = def.Priority or 0
	for i, s in States.List do
		if s.Name == name then
			table.remove(States.List, i)
			break
		end
	end
	States.ByName[name] = def
	table.insert(States.List, def)
	table.sort(States.List, function(a, b)
		return a.Priority > b.Priority
	end)
end

-- first action in the list the creature can do
local function firstAvailable(rec, list)
	for _, name in list do
		if rec.actionBinds[name] then
			return name
		end
	end
	return nil
end

-- Owner greeting: small creatures hop, wag or wiggle; big ones show off their first signature action.
function States.GreetFor(rec)
	local S = Config.States.OwnerNearby
	if rec.bulk < Config.Breath.SmallBelow then
		return firstAvailable(rec, S.GreetSmall) or rec.actionList[1]
	end
	return rec.actionList[1] or firstAvailable(rec, S.GreetSmall)
end

local function nearest(rec, ctx, wantOwner, range)
	local best, bestD = nil, range
	for _, o in ctx.people do
		if (o.userId == rec.ownerId) == wantOwner then
			local d = (o.pos - rec.centerWorld).Magnitude
			if d < bestD then
				best, bestD = o, d
			end
		end
	end
	return best
end

States.Register("PenIdle", {
	Priority = 0,
	Detect = function()
		return true
	end,
})

-- The local player owns this creature and is close: it watches them and greets them.
States.Register("OwnerNearby", {
	Priority = 40,
	Detect = function(rec, ctx)
		if rec.ownerId ~= ctx.userId then
			return false
		end
		local o = nearest(rec, ctx, true, Config.States.OwnerNearby.Range + rec.radius)
		if o and o.userId == ctx.userId then
			rec.lookPart = o.head
			return true
		end
		return false
	end,
	Enter = function(rec, ctx)
		rec.lookWTarget = 1
		if ctx.now - (rec.lastGreet or -1e9) > Config.States.OwnerNearby.GreetCooldown then
			rec.lastGreet = ctx.now
			rec.queued = rec.queued or States.GreetFor(rec) -- a hatch pop already waiting goes first
		end
	end,
	Exit = function(rec)
		rec.lookWTarget = 0
	end,
})

-- Someone who is not the owner is close: alert pose, it watches them, the odd warning growl.
States.Register("StrangerNearby", {
	Priority = 45,
	Detect = function(rec, ctx)
		local o = nearest(rec, ctx, false, Config.States.StrangerNearby.Range + rec.radius)
		if o then
			rec.lookPart = o.head
			return true
		end
		return false
	end,
	Enter = function(rec, ctx)
		rec.lookWTarget = 1
		rec.alertTarget = 1
		rec.nextWarn = ctx.now + rec.rng:NextNumber(1.5, 3.5)
	end,
	Tick = function(rec, ctx)
		if ctx.now >= (rec.nextWarn or 0) and not rec.action then
			rec.nextWarn = ctx.now + Util.range(rec.rng, Config.States.StrangerNearby.WarnEvery)
			rec.queued = firstAvailable(rec, Config.States.StrangerNearby.Warn)
		end
	end,
	Exit = function(rec)
		rec.lookWTarget = 0
		rec.alertTarget = 0
	end,
})

-- Guardians asleep by their nest (GuardianService State "Sleeping").
States.Register("Asleep", {
	Priority = 80,
	Detect = function(rec)
		return rec.guardian and rec.model:GetAttribute("State") == "Sleeping"
	end,
	Enter = function(rec)
		rec.sleepTarget = 1
		for _, g in rec.sleepSigns or {} do
			g.Enabled = true
		end
	end,
	Exit = function(rec)
		rec.sleepTarget = 0
		for _, g in rec.sleepSigns or {} do
			g.Enabled = false
		end
	end,
})

-- Guardians waking up (State "Waking"): the big wake-up roar.
States.Register("Wake", {
	Priority = 85,
	Detect = function(rec)
		return rec.guardian and rec.model:GetAttribute("State") == "Waking"
	end,
	Enter = function(rec)
		rec.queued = "Roar"
		rec.alertTarget = 1
	end,
	Exit = function(rec)
		rec.alertTarget = 0
	end,
})

-- Being carried by a thief: the panic profile. Never detected: Controller.WatchCarried forces it on the stolen copy,
-- and the debug tools can force it on any creature to preview it.
States.Register("Carried", {
	Priority = 90,
	Detect = function()
		return false
	end,
	Enter = function(rec)
		rec.panicTarget = 1
	end,
	Exit = function(rec)
		rec.panicTarget = 0
	end,
})

-- Runs in the controller's batched pass: picks the active state and runs its hooks.
function States.Evaluate(rec, ctx)
	local chosen
	if rec.forcedState then
		chosen = States.ByName[rec.forcedState]
		if chosen and chosen.Detect then
			chosen.Detect(rec, ctx) -- fills in the look target when there is one
		end
	end
	if not chosen then
		for _, s in States.List do
			if s.Detect(rec, ctx) then
				chosen = s
				break
			end
		end
	end
	if chosen ~= rec.state then
		local old = rec.state
		if old and old.Exit then
			old.Exit(rec, ctx)
		end
		rec.state = chosen
		if chosen.Enter then
			chosen.Enter(rec, ctx)
		end
	end
	if chosen.Tick then
		chosen.Tick(rec, ctx)
	end
	-- night: calmer, slower idles, brighter glows; some creatures doze off while idle
	rec.nightTarget = ctx.night and 1 or 0
	rec.dozeTarget = (ctx.night and rec.dozer and chosen.Name == "PenIdle") and 1 or 0
end

-- Every frame (Full and Reduced tiers): blends, rate multipliers and the state's pose offsets.
function States.Pose(rec, dt, t)
	local k = 1 - exp(-4 * dt)
	rec.lookW += (rec.lookWTarget - rec.lookW) * k
	rec.alert += (rec.alertTarget - rec.alert) * k
	rec.panic += (rec.panicTarget - rec.panic) * k
	rec.sleep += (rec.sleepTarget - rec.sleep) * (1 - exp(-1.2 * dt))
	rec.doze += (rec.dozeTarget - rec.doze) * (1 - exp(-0.8 * dt))
	rec.night += (rec.nightTarget - rec.night) * (1 - exp(-0.6 * dt))
	local N, A, C = Config.States.Night, Config.States.Asleep, Config.States.Carried
	local night, sleep, panic, doze = rec.night, rec.sleep, rec.panic, rec.doze
	rec.tempoMul = (1 + (N.Tempo - 1) * night) * (1 + (A.Tempo - 1) * sleep) * (1 + 0.6 * panic) * (1 - 0.3 * doze)
	rec.breathMul = (1 + (N.Tempo - 1) * night) * (1 + (A.Tempo - 1) * sleep) * (1 + (1 / C.Breath - 1) * panic) * (1 - 0.25 * doze)
	rec.breathAmp = 1 + (A.Breath - 1) * sleep + 0.4 * doze
	rec.ampMul = 1 + (N.Amp - 1) * night
	rec.glowMul = 1 + (N.Glow - 1) * night

	-- look target (owner or stranger) as joint-local yaw / pitch for every head
	local part = rec.lookPart
	if rec.lookW > 0.01 and part and part.Parent then
		local S = rec.state == States.ByName.StrangerNearby and Config.States.StrangerNearby or Config.States.OwnerNearby
		local lp = rec.rootCF:PointToObjectSpace(part.Position)
		for _, h in rec.heads do
			local d = lp - h.restPos
			h.hs.lookYaw = clamp(deg(atan2(-d.X, -d.Z)), -S.LookYaw, S.LookYaw)
			h.hs.lookPitch = clamp(deg(atan2(d.Y, sqrt(d.X * d.X + d.Z * d.Z))), -S.LookPitch, S.LookPitch)
		end
	end

	local body = rec.body
	local alert = rec.alert
	if alert > 0.001 then
		body.ax += 2 * RAD * alert
		body.ty += 0.02 * rec.scale * alert
		for _, h in rec.heads do
			h.ax += 6 * RAD * alert
		end
		for _, e in rec.ears do
			e.az += e.side * 12 * RAD * alert
		end
		for _, j in rec.tail do
			j.ax -= 4 * RAD * alert
		end
	end
	if sleep > 0.001 then
		body.ty -= A.Drop * rec.height * sleep
		body.ax -= 3 * RAD * sleep
		for _, h in rec.heads do
			h.ax += A.Head * RAD * sleep
		end
		for _, j in rec.tail do
			j.ay += 10 * RAD * sleep
		end
		for _, a in rec.arms do
			a.ax -= 6 * RAD * sleep
		end
	end
	if doze > 0.001 then
		body.ty -= N.DozeDrop * rec.scale * doze
		for _, h in rec.heads do
			h.ax += N.DozeHead * RAD * doze
		end
	end
	if panic > 0.001 then
		local ph = TAU * C.PaddleHz * t
		for i, l in rec.legs do
			l.plant *= 1 - panic
			l.ax += C.Paddle * RAD * panic * sin(ph + i * 1.7)
		end
		for i, a in rec.arms do
			a.plant *= 1 - panic
			a.ax += C.Paddle * RAD * panic * sin(ph + i * 2.3 + 1)
		end
		local th = sin(TAU * C.ThrashHz * t)
		for _, j in rec.tail do
			j.ay += C.Thrash * RAD * panic * th
		end
		for _, j in rec.spine do
			j.ay += C.Thrash * 0.6 * RAD * panic * sin(TAU * C.ThrashHz * t - j.chain)
		end
		local back = sin(TAU * 0.35 * t)
		for _, h in rec.heads do
			h.ay += C.LookBack * RAD * panic * back
			h.ax += 8 * RAD * panic
		end
		if rec.jaw then
			rec.jaw.ax -= (6 + 8 * math.max(0, sin(TAU * 3 * t))) * RAD * panic
		end
		for _, e in rec.ears do
			e.az -= e.side * 16 * RAD * panic
		end
	end
end

return States
