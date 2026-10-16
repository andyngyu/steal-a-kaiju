-- KaijuAnimation.Actions: keyframed signature actions (Config.Actions). Each definition is compiled once, bound to a
-- creature's joints when it registers (selectors resolved to joint records, gains and mirroring worked out), and
-- Actions.Apply adds the running action's pose to the joints every frame and fires its timed events through
-- Actions.OnEvent (set by the controller). Nothing here allocates per frame.
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local Actions = {}

local CH = { pitch = 1, yaw = 2, roll = 3, x = 4, y = 5, z = 6, plant = 7, spin = 8, spinRate = 9, curl = 10, glow = 11 }
Actions.Channels = CH

local RAD, TAU = Util.RAD, Util.TAU
local evalCurve, window, smooth = Util.evalCurve, Util.window, Util.smooth
local sin, sqrt = math.sin, math.sqrt

-- called as OnEvent(rec, kind, arg) when an action reaches one of its events
Actions.OnEvent = function() end

local compiled = {}

local function compile(def)
	local c = compiled[def]
	if c then
		return c
	end
	c = { duration = def.Duration or 1, calm = def.Calm or 0.6, pivot = def.Pivot or "Center", tracks = {}, events = {} }
	for _, tr in def.Tracks or {} do
		local ch = CH[tr[2]]
		assert(ch, "KaijuAnimation: unknown action channel " .. tostring(tr[2]))
		local t = {
			sel = tr[1],
			ch = ch,
			curve = tr[3] and Util.curve(tr[3]) or nil,
			mirror = tr.Mirror == true,
			grow = tr.Grow or 0,
			height = tr.Height == true,
			spread = tr.Spread or 0,
		}
		if tr.Osc then
			local o = tr.Osc
			t.osc = true
			t.hz, t.amp, t.from, t.to = o.Hz or 1, o.Amp or 0, o.From or 0, o.To or 1
			t.phase, t.decay = o.Phase or 0, o.Decay == true
			t.fade = math.min(0.08, (t.to - t.from) * 0.3)
		end
		table.insert(c.tracks, t)
	end
	for _, ev in def.Events or {} do
		table.insert(c.events, { t = ev[1], kind = ev[2], arg = ev[3] })
	end
	table.sort(c.events, function(a, b)
		return a.t < b.t
	end)
	compiled[def] = c
	return c
end

-- A variant with Extends = "<other variant>" is that variant plus its own extra Tracks and Events (and any field it
-- sets itself, like Duration).
local extended = {}
local function extend(variants, def)
	local merged = extended[def]
	if merged then
		return merged
	end
	local base = variants[def.Extends]
	assert(base, "KaijuAnimation: Extends names a missing variant " .. tostring(def.Extends))
	merged = {}
	for k, v in base do
		merged[k] = v
	end
	for k, v in def do
		if k ~= "Tracks" and k ~= "Events" and k ~= "Extends" then
			merged[k] = v
		end
	end
	merged.Tracks = table.clone(base.Tracks or {})
	for _, t in def.Tracks or {} do
		table.insert(merged.Tracks, t)
	end
	merged.Events = table.clone(base.Events or {})
	for _, e in def.Events or {} do
		table.insert(merged.Events, e)
	end
	extended[def] = merged
	return merged
end

-- The definition a creature uses: by creature name, then profile, then Default.
function Actions.Resolve(name, creature, profile)
	local variants = Config.Actions[name]
	if not variants then
		return nil
	end
	local def = variants[creature] or variants[profile] or variants.Default
	if def and def.Extends then
		def = extend(variants, def)
	end
	return def
end

-- Joint records matching a selector.
function Actions.Select(rec, sel)
	local out = {}
	if sel == "Body" then
		table.insert(out, rec.body)
	elseif sel == "@Spine" or sel == "@Heads" or sel == "@Tentacles" then
		local role = sel == "@Spine" and "Seg" or sel == "@Heads" and "Head" or "Tentacle"
		for _, j in rec.joints do
			if j.role == role then
				table.insert(out, j)
			end
		end
	elseif sel:sub(-1) == "*" then
		local prefix = sel:sub(1, -2)
		for _, j in rec.joints do
			if j ~= rec.body and j.name:sub(1, #prefix) == prefix then
				table.insert(out, j)
			end
		end
	else
		local j = rec.J[sel]
		if j then
			table.insert(out, j)
		end
	end
	return out
end

-- Binds every action this creature can do (a variant exists and at least one track finds a joint).
function Actions.Bind(rec)
	local binds = {}
	for name in Config.Actions do
		local def = Actions.Resolve(name, rec.name, rec.profileName)
		if def then
			local c = compile(def)
			local list = {}
			for _, t in c.tracks do
				for _, j in Actions.Select(rec, t.sel) do
					local sign = 1
					if t.mirror and j.side < 0 and (t.ch == CH.yaw or t.ch == CH.roll or t.ch == CH.x) then
						sign = -1
					end
					local gain = 1 + t.grow * ((j.chain or 1) - 1)
					table.insert(list, { j = j, t = t, gain = gain, sign = sign, phase = t.spread * (j.tentacle or 0) })
				end
			end
			if #list > 0 then
				binds[name] = { c = c, binds = list }
			end
		end
	end
	rec.actionBinds = binds
	-- the creature's own list: its config, then its profile's, keeping only actions it can do
	local wanted = rec.spec.Actions or rec.P.Actions or {}
	local list = {}
	for _, name in wanted do
		if binds[name] then
			table.insert(list, name)
		end
	end
	rec.actionList = list
	rec.actionState = {}
end

function Actions.Can(rec, name)
	return rec.actionBinds ~= nil and rec.actionBinds[name] ~= nil
end

-- Starts an action now (replacing any running one). Duration grows with sqrt(scale) and the rarity's ActionSpeed.
function Actions.Start(rec, name)
	local b = rec.actionBinds and rec.actionBinds[name]
	if not b then
		return false
	end
	local a = rec.actionState
	a.name = name
	a.c = b.c
	a.binds = b.binds
	a.time = 0
	a.duration = b.c.duration * sqrt(rec.scale) * rec.rarity.ActionSpeed
	a.amp = rec.rarity.ActionAmp * Config.Global.Exaggerate
	a.nextEvent = 1
	rec.action = a
	rec.pivotTarget = rec.pivots[b.c.pivot] or rec.pivots.Center
	return true
end

function Actions.Stop(rec)
	rec.action = nil
	rec.calm = 0
	rec.pivotTarget = rec.pivots.Center
end

-- Adds the running action to the joints' accumulators (applyPose false: only advances time and events).
function Actions.Apply(rec, dt, applyPose)
	local a = rec.action
	if not a then
		rec.calm = 0
		return
	end
	a.time += dt
	local e = a.time / a.duration
	if e >= 1 then
		-- events not reached yet still fire (a skipped frame must not lose a sound)
		local events = a.c.events
		while a.nextEvent <= #events do
			local ev = events[a.nextEvent]
			a.nextEvent += 1
			Actions.OnEvent(rec, ev.kind, ev.arg)
		end
		Actions.Stop(rec)
		return
	end
	rec.calm = a.c.calm * window(e, 0, 1, 0.12)
	if applyPose then
		local amp, scale, height = a.amp, rec.scale, rec.height
		local time = a.time
		for _, b in a.binds do
			local t = b.t
			local v = t.curve and evalCurve(t.curve, e) or 0
			if t.osc then
				local w = window(e, t.from, t.to, t.fade)
				if w > 0 then
					if t.decay then
						w *= 1 - smooth((e - t.from) / (t.to - t.from))
					end
					v += sin(TAU * t.hz * time + t.phase + b.phase) * t.amp * w
				end
			end
			local j, ch = b.j, t.ch
			if ch <= 3 then
				v *= RAD * b.gain * b.sign * amp
				if ch == 1 then
					j.ax += v
				elseif ch == 2 then
					j.ay += v
				else
					j.az += v
				end
			elseif ch <= 6 then
				v *= (t.height and height or scale) * b.gain * b.sign * amp
				if ch == 4 then
					j.tx += v
				elseif ch == 5 then
					j.ty += v
				else
					j.tz += v
				end
			elseif ch == 7 then
				if v < j.plant then
					j.plant = v < 0 and 0 or v
				end
			elseif ch == 8 then
				j.spinAdd += v * RAD * b.gain * amp
			elseif ch == 9 then
				j.spinBoost += v
			elseif ch == 10 then
				j.curl += v * RAD * b.gain * amp
			else
				rec.glow += v
			end
		end
	end
	local events = a.c.events
	while a.nextEvent <= #events and events[a.nextEvent].t <= e do
		local ev = events[a.nextEvent]
		a.nextEvent += 1
		Actions.OnEvent(rec, ev.kind, ev.arg)
	end
end

return Actions
