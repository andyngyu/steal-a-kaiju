-- KaijuAnimation.Motion: the per-frame pose of one creature, written to its Motor6D.Transforms. Layers in order:
-- breathing, weight shift, head life, the profile's own idle layers, the state, the action. Then the solve: follow-through
-- springs (exact damped springs driven by the parent's motion, so tips lag, overshoot a little and settle), head
-- stabilising (the gaze stays steady while the body moves) and grounding (a planted limb pivots about its foot so the
-- foot never slides, floats or sinks). Far creatures (lod 2) only breathe and spin their orbits.
-- No table allocation and no tree searches per frame: everything touched was cached on the record at registration.
local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local Actions = require(script.Parent.Actions)
local States = require(script.Parent.States)

local Motion = {}

local RAD, TAU = Util.RAD, Util.TAU
local sin, cos, clamp, min, exp, atan2 = math.sin, math.cos, math.clamp, math.min, math.exp, math.atan2
local noise, breathCurve, range = Util.noise, Util.breath, Util.range
local springCoeffs, springStep = Util.springCoeffs, Util.springStep
local IDENTITY, cfnew, fromEuler, fromAxisAngle = CFrame.identity, CFrame.new, CFrame.fromEulerAnglesYXZ, CFrame.fromAxisAngle
local EXAGGERATE = Config.Global.Exaggerate
local BLEND_IN = Config.Global.BlendIn
local MAX_ANGLE = 1.5 -- radians, a safety clamp on sprung joints

-- 0 -> 1 -> 0 over u in 0..1, flat at both ends
local function bump(u)
	if u <= 0 or u >= 1 then
		return 0
	end
	return 0.5 - 0.5 * cos(TAU * u)
end

-- A recurring micro event (glance, tap, sniff): returns its 0..1 envelope. The two timer keys live in rec.tm.
local function cycle(rec, t, nextKey, atKey, every, length)
	local tm = rec.tm
	local n = tm[nextKey]
	if not n then
		tm[nextKey] = t + range(rec.rng, every) / rec.fidget
		return 0
	end
	if t >= n then
		tm[atKey] = t
		tm[nextKey] = t + length + range(rec.rng, every) / rec.fidget
	end
	local at = tm[atKey]
	if not at then
		return 0
	end
	return bump((t - at) / length)
end

-- A spring kick (flicks, snaps): adds velocity so the spring swings out and settles by itself.
local function kick(j, axis, degrees)
	if not j or not j.spring then
		return
	end
	local v = degrees * RAD * j.omega
	if axis == 1 then
		j.svx += v
	elseif axis == 2 then
		j.svy += v
	else
		j.svz += v
	end
end

---------------------------------------------------------------------------------------------------- shared layers

local function breathLayer(rec, dt, ex)
	local B = rec.P.Breath
	rec.breathPhase = (rec.breathPhase + dt * rec.breathRate * rec.breathMul) % 1
	local b = breathCurve(rec.breathPhase)
	rec.breath = b
	local a = rec.breathAmp
	local j = rec.breathJoint
	j.ty += (B.Lift or 0) * rec.scale * b * a
	j.ax += (B.Pitch or 0) * RAD * ex * b * a
	if B.Neck then
		local n = rec.necks[1]
		if n then
			n.ax += B.Neck * RAD * ex * b * a
		end
	end
	if B.Shoulder then
		for _, arm in rec.arms do
			if not arm.planted then
				arm.az += arm.side * B.Shoulder * RAD * ex * b
			end
		end
	end
	if B.HeadBob then
		for _, h in rec.heads do
			h.ax += B.HeadBob * RAD * ex * (b - 0.5)
		end
	end
end

local function shiftLayer(rec, t, ex)
	local S = rec.P.Shift
	if not S then
		return
	end
	local w = noise(t * S.Hz, rec.seed)
	local body = rec.body
	body.az += (S.Roll or 0) * RAD * ex * w -- leans towards -X ...
	body.tx -= (S.Slide or 0) * rec.scale * w -- ... and slides that way
	if S.Pitch then
		body.ax += S.Pitch * RAD * ex * noise(t * S.Hz, rec.seed + 7.7)
	end
	if S.Yaw then
		body.ay += S.Yaw * RAD * ex * noise(t * S.Hz * 0.8, rec.seed + 3.1)
	end
end

local function headLayer(rec, t, ex, micro)
	local H = rec.P.Head
	if not H then
		return
	end
	local quiet = 1 - rec.calm
	local rng = rec.rng
	local lw = rec.lookW
	for i, h in rec.heads do
		local hs = h.hs
		local yaw, pitch, tilt
		if H.Mode == "Snap" then
			-- holds a pose, then snaps to a new one (the fast head spring gives the snap its overshoot)
			if t >= hs.holdUntil then
				hs.holdUntil = t + range(rng, H.Hold) / rec.fidget
				hs.ty = rng:NextNumber(-1, 1) * H.Yaw
				hs.tp = (H.Base or 0) + rng:NextNumber(-1, 1) * H.Pitch
				hs.tr = rng:NextNumber(-1, 1) * (H.Tilt or 0)
			end
			yaw, pitch, tilt = hs.ty, hs.tp, hs.tr
		else
			local f = H.Hz
			yaw = noise(t * f, hs.seed) * H.Yaw
			pitch = (H.Base or 0) + noise(t * f * 0.8, hs.seed + 5.3) * H.Pitch
			tilt = noise(t * f * 0.6, hs.seed + 9.1) * (H.Tilt or 0)
			if micro and H.GlanceEvery then
				if t >= hs.nextGlance then
					if hs.nextGlance > 0 then
						hs.glanceUntil = t + range(rng, H.GlanceHold)
						hs.gy = (rng:NextNumber() < 0.5 and -1 or 1) * H.Glance * rng:NextNumber(0.7, 1)
						hs.gp = rng:NextNumber(-0.3, 0.6) * H.Pitch
					end
					hs.nextGlance = t + range(rng, H.GlanceEvery) / rec.fidget
				end
				if t < hs.glanceUntil then
					yaw = hs.gy
					pitch += hs.gp
				end
			end
		end
		if i == 1 then
			rec.headYaw = yaw
		end
		yaw *= ex
		pitch *= ex
		tilt *= ex
		if lw > 0.001 then
			yaw += (hs.lookYaw - yaw) * lw
			pitch += (hs.lookPitch - pitch) * lw
			tilt *= 1 - lw
		end
		h.ax += pitch * RAD * quiet
		h.ay += yaw * RAD * quiet
		h.az += tilt * RAD * quiet
	end
end

local function tailLayer(rec, T, t, ex, micro)
	local chain = rec.tail
	local n = #chain
	if n == 0 or not T then
		return
	end
	local sway, hz, wave = (T.Sway or 0) * RAD * ex, T.Hz or 0.2, T.Wave or 0.6
	local lift = (T.Lift or 0) * RAD * ex * (0.8 + 0.4 * rec.breath) / n
	local counter = T.Counter and -T.Counter * (rec.headYaw or 0) * RAD * ex / n or 0
	local sd = rec.seed
	for i, j in chain do
		j.ay += sway * sin(TAU * hz * t - wave * (i - 1) + sd) + counter
		j.ax -= lift
	end
	if micro and T.FlickEvery then
		local tm = rec.tm
		if t >= (tm.flick or 0) then
			if tm.flick then
				kick(chain[1], 2, (rec.rng:NextNumber() < 0.5 and -1 or 1) * T.Flick)
			end
			tm.flick = t + range(rec.rng, T.FlickEvery) / rec.fidget
		end
	end
end

local function earLayer(rec, E, t, ex, micro)
	if not E then
		return
	end
	for _, e in rec.ears do
		if E.Fan and E.Fan > 0 then
			e.az += e.side * E.Fan * RAD * ex * sin(TAU * (E.FanHz or 0.3) * t + rec.seed + e.side)
		end
		if micro and E.FlickEvery then
			if t >= (e.nextFlick or 0) then
				if e.nextFlick then
					kick(e, 3, e.side * E.Flick)
				end
				e.nextFlick = t + range(rec.rng, E.FlickEvery) / rec.fidget
			end
		end
	end
end

local function jawLayer(rec, Jc, t, ex, micro)
	local jaw = rec.jaw
	if not jaw or not Jc then
		return
	end
	if Jc.Breath then
		jaw.ax -= Jc.Breath * RAD * ex * (1 - rec.breath)
	end
	if Jc.Pulse then
		jaw.ax -= Jc.Pulse * RAD * ex * (0.5 + 0.5 * sin(TAU * Jc.Hz * t + rec.seed))
	end
	if micro and Jc.HuffEvery then
		local tm = rec.tm
		if t >= (tm.huff or 0) then
			if tm.huff then
				kick(jaw, 1, -Jc.Huff)
			end
			tm.huff = t + range(rec.rng, Jc.HuffEvery) / rec.fidget
		end
	end
end

local function armsLayer(rec, A, t, ex)
	if not A then
		return
	end
	for _, a in rec.arms do
		if not a.planted then
			a.ax += A.Flex * RAD * ex * (0.6 * sin(TAU * A.Hz * t + rec.seed + (a.side > 0 and 0 or 1.7)) + 0.4 * rec.breath)
		end
	end
end

local function tongueLayer(rec, Tc, t)
	local tg = rec.tongue
	if not tg or not Tc then
		return
	end
	local w = cycle(rec, t, "tongue", "tongueAt", Tc.Every, Tc.Length)
	if w > 0 then
		tg.tz -= Tc.Reach * rec.scale * w
		tg.ay += 7 * RAD * w * sin(TAU * 9 * t)
	end
end

local function waveLayer(rec, W, t, ex)
	if not W then
		return
	end
	local sd = rec.seed
	for _, j in rec.spine do
		local i = j.chain
		j.ay += W.Amp * (1 + W.Grow * (i - 1)) * RAD * ex * sin(TAU * W.Hz * t - W.K * i + sd)
		j.ax += (W.Vertical or 0) * RAD * ex * sin(TAU * W.Hz * 0.5 * t - W.K * i + sd * 1.7)
	end
end

------------------------------------------------------------------------------------------------ profile layers

local PROFILES = {}

function PROFILES.Rex(rec, P, t, ex, micro)
	tailLayer(rec, P.Tail, t, ex, micro)
	armsLayer(rec, P.Arms, t, ex)
	jawLayer(rec, P.Jaw, t, ex, micro)
end
PROFILES.Raptor = PROFILES.Rex

function PROFILES.Ape(rec, P, t, ex, micro)
	armsLayer(rec, P.Arms, t, ex)
	local S = P.Shoulders
	if S then
		-- shoulder roll: the chest rocks side to side over the planted knuckles
		local s = sin(TAU * S.Hz * t + rec.seed)
		rec.body.az += S.Roll * RAD * ex * s
		rec.body.ay += S.Roll * 0.4 * RAD * ex * sin(TAU * S.Hz * t + rec.seed + 1.2)
	end
	local K = P.Knuckles
	if micro and K and #rec.arms > 0 then
		local tm = rec.tm
		if t >= (tm.knuckle or 0) then
			if tm.knuckle then
				tm.knuckleAt = t
				tm.knuckleArm = rec.rng:NextInteger(1, #rec.arms)
			end
			tm.knuckle = t + K.Length + range(rec.rng, K.Every) / rec.fidget
		end
		if tm.knuckleAt then
			local w = bump((t - tm.knuckleAt) / K.Length)
			local a = rec.arms[tm.knuckleArm]
			if w > 0 and a then
				a.plant *= 1 - w
				a.ty += K.Lift * rec.scale * w
				a.ax += K.Pitch * RAD * w
			end
		end
	end
	earLayer(rec, P.Ears, t, ex, micro)
	jawLayer(rec, P.Jaw, t, ex, micro)
end

function PROFILES.HeavyQuad(rec, P, t, ex, micro)
	tailLayer(rec, P.Tail, t, ex, micro)
	earLayer(rec, P.Ears, t, ex, micro)
	local Tr = P.Trunk
	local n = #rec.trunk
	if Tr and n > 0 then
		for i, j in rec.trunk do
			j.ay += Tr.Sway * RAD * ex * noise(t * Tr.Hz - i * 0.35, rec.seed + 31) / n
			j.ax += Tr.Curl * RAD * ex * (i / n) * (0.5 + 0.5 * sin(TAU * Tr.Hz * 0.7 * t + rec.seed - i * 0.6))
		end
	end
end

function PROFILES.AgileQuad(rec, P, t, ex, micro)
	tailLayer(rec, P.Tail, t, ex, micro)
	earLayer(rec, P.Ears, t, ex, micro)
	if not micro then
		return
	end
	local S = P.Sniff
	if S then
		local w = cycle(rec, t, "sniff", "sniffAt", S.Every, S.Length)
		if w > 0 then
			local h = rec.heads[1]
			if h then
				h.ax += S.Pitch * RAD * w * sin(TAU * S.Hz * (t - rec.tm.sniffAt)) - 4 * RAD * w
			end
			if rec.jaw then
				rec.jaw.ax -= 3 * RAD * w
			end
		end
	end
	local C = P.Crouch
	if C then
		local w = cycle(rec, t, "crouch", "crouchAt", C.Every, C.Length)
		if w > 0 then
			rec.body.ty -= C.Drop * rec.scale * w
			rec.body.ax -= 1.5 * RAD * w
		end
	end
end

function PROFILES.LowCrawler(rec, P, t, ex, micro)
	local S = P.Spine
	if S then
		rec.body.ay += S.Bend * RAD * ex * sin(TAU * S.Hz * t + rec.seed)
	end
	tailLayer(rec, P.Tail, t, ex, micro)
	jawLayer(rec, P.Jaw, t, ex, micro)
end

function PROFILES.Hopper(rec, P, t, ex, micro)
	local Th = P.Throat
	if Th then
		local s = 0.5 + 0.5 * sin(TAU * Th.Hz * t + rec.seed)
		rec.body.ty += Th.Lift * rec.scale * s
		rec.body.ax += Th.Pitch * RAD * ex * s
	end
end

function PROFILES.Shelled(rec, P, t, ex, micro)
	local E = P.Extend
	local h = rec.heads[1]
	if E and h then
		local s = 0.5 + 0.5 * sin(TAU * E.Hz * t + rec.seed)
		h.tz -= E.Reach * rec.scale * s
		h.ax += 3 * RAD * ex * (s - 0.5)
	end
	tailLayer(rec, P.Tail, t, ex, micro)
end

function PROFILES.Arthropod(rec, P, t, ex, micro)
	local C = P.Claws
	if C then
		for _, c in rec.claws do
			c.ax += C.Hold * RAD * ex + 2 * RAD * noise(t * 0.4, rec.seed + c.side * 3)
		end
		if micro then
			local tm = rec.tm
			if t >= (tm.click or 0) then
				if tm.click and #rec.claws > 0 then
					kick(rec.claws[rec.rng:NextInteger(1, #rec.claws)], 1, C.Click)
				end
				tm.click = t + range(rec.rng, C.ClickEvery) / rec.fidget
			end
		end
	end
	local S = P.Stalks
	if S then
		for _, s in rec.stalks do
			s.ax += S.Wiggle * RAD * noise(t * S.Hz, rec.seed + s.side * 5)
			s.az += S.Wiggle * RAD * noise(t * S.Hz, rec.seed + s.side * 9 + 2)
		end
		if micro then
			local tm = rec.tm
			if t >= (tm.stalk or 0) then
				if tm.stalk and #rec.stalks > 0 then
					local s = rec.stalks[rec.rng:NextInteger(1, #rec.stalks)]
					kick(s, 3, (rec.rng:NextNumber() < 0.5 and -1 or 1) * S.Kick)
				end
				tm.stalk = t + range(rec.rng, S.KickEvery) / rec.fidget
			end
		end
	end
	local L = P.LegTap
	if micro and L then
		local tm = rec.tm
		local total = L.Step * (#L.Order + 1)
		if t >= (tm.tap or 0) then
			if tm.tap then
				tm.tapAt = t
			end
			tm.tap = t + total + range(rec.rng, L.Every) / rec.fidget
		end
		if tm.tapAt and t - tm.tapAt < total + L.Step then
			for k, name in L.Order do
				local leg = rec.J[name]
				if leg then
					local w = bump((t - tm.tapAt - (k - 1) * L.Step) / (2 * L.Step))
					if w > 0 then
						leg.plant *= 1 - w
						leg.az += leg.side * L.Lift * RAD * w
						leg.ty += 0.04 * rec.scale * w
					end
				end
			end
		end
	end
end

function PROFILES.Serpent(rec, P, t, ex, micro)
	waveLayer(rec, P.Wave, t, ex)
	local N = P.Neck
	local n = rec.necks[1]
	if N and n then
		n.ay += N.Sway * RAD * ex * noise(t * N.Hz, rec.seed + 41)
	end
	if micro then
		tongueLayer(rec, P.Tongue, t)
	end
end

function PROFILES.VerticalCoil(rec, P, t, ex, micro)
	local C = P.Coil
	if C then
		for _, j in rec.spine do
			local sign = j.chain % 2 == 0 and -1 or 1
			j.ax += C.Breathe * RAD * ex * (rec.breath - 0.5) * sign
			j.ay += C.Sway * RAD * ex * noise(t * C.Hz, rec.seed + j.chain * 3)
		end
	end
	local N = P.Neck
	local n = rec.necks[1]
	if N and n then
		n.ay += N.Sway * RAD * ex * noise(t * N.Hz, rec.seed + 51)
	end
	local Cl = P.Cloud
	local cloud = rec.cloud
	if Cl and cloud then
		cloud.ty += Cl.Bob * rec.scale * sin(TAU * Cl.Hz * t + rec.seed)
		cloud.ay += Cl.Yaw * RAD * noise(t * Cl.Hz, rec.seed + 61)
		cloud.az += Cl.Roll * RAD * sin(TAU * Cl.Hz * 0.7 * t + rec.seed)
	end
	local Ha = P.Halo
	if Ha and rec.halo then
		rec.halo.spinAdd += Ha.Sway * RAD * sin(TAU * Ha.Hz * t + rec.seed)
	end
	local L = P.Legs
	if L then
		for _, l in rec.legs do
			l.ax += L.Curl * RAD * ex * sin(TAU * L.Hz * t + rec.seed + l.side)
		end
	end
	if micro then
		tongueLayer(rec, P.Tongue, t)
	end
end

function PROFILES.Hydra(rec, P, t, ex, micro)
	waveLayer(rec, P.Wave, t, ex)
	local N = P.Necks
	if N then
		for i, n in rec.necks do
			n.ay += N.Sway * RAD * ex * sin(TAU * N.Hz * t + rec.seed + i * 2.1)
			n.ax += N.Pitch * RAD * ex * sin(TAU * N.Hz * 0.8 * t + rec.seed + i * 1.3)
		end
	end
	if not micro then
		return
	end
	local J = rec.J
	local L = P.LookAtEachOther
	if L then
		local w = cycle(rec, t, "look", "lookAt", L.Every, L.Length)
		if w > 0 then
			local y = L.Yaw * RAD * w
			if J.HeadLeft then
				J.HeadLeft.ay += y
			end
			if J.HeadRight then
				J.HeadRight.ay -= y
			end
		end
	end
	local S = P.SnapSequence
	if S then
		local tm = rec.tm
		if t >= (tm.snap or 0) then
			if tm.snap then
				tm.snapAt = t
				tm.snapDone = 0
			end
			tm.snap = t + range(rec.rng, S.Every) / rec.fidget
		end
		if tm.snapAt and tm.snapDone < 3 and t >= tm.snapAt + tm.snapDone * S.Gap then
			local k = tm.snapDone
			tm.snapDone = k + 1
			local h = k == 0 and J.HeadLeft or k == 1 and J.Head or J.HeadRight
			kick(h, 1, -S.Pitch)
			if k == 1 then
				kick(rec.jaw, 1, -S.Pitch * 2)
			end
		end
	end
	tongueLayer(rec, P.Tongue, t)
end

function PROFILES.Winged(rec, P, t, ex, micro)
	local W = P.Wings
	if W then
		local settle = micro and cycle(rec, t, "settle", "settleAt", W.SettleEvery, W.SettleLength) or 0
		for _, w in rec.wings do
			w.az += w.side * (W.Breathe * rec.breath + W.Settle * settle) * RAD * ex
		end
	end
	tailLayer(rec, P.Tail, t, ex, micro)
end

function PROFILES.FinLegFish(rec, P, t, ex, micro)
	tailLayer(rec, P.Tail, t, ex, micro)
	local G = P.Gills
	if G and rec.jaw then
		rec.jaw.ax -= G.Jaw * RAD * ex * (0.5 + 0.5 * sin(TAU * G.Hz * t + rec.seed))
	end
	local Pd = P.Paddle
	if Pd then
		for _, l in rec.legs do
			local pair = (l.name == "LegFL" or l.name == "LegBR") and 0 or math.pi
			l.ax += Pd.Pitch * RAD * ex * sin(TAU * Pd.Hz * t + rec.seed + pair)
		end
	end
end

function PROFILES.Tentacled(rec, P, t, ex, micro)
	local T = P.Tentacles
	local R = micro and P.Ripple
	local ripAt
	if R then
		cycle(rec, t, "ripple", "rippleAt", R.Every, R.Length + R.Gap * #rec.tentacleChains)
		ripAt = rec.tm.rippleAt
	end
	for ci, chain in rec.tentacleChains do
		local f, ph = rec.tentacleHz[ci], rec.tentaclePhase[ci]
		local n = #chain
		local rip = 0
		if ripAt then
			rip = bump((t - ripAt - R.Gap * (ci - 1)) / R.Length) * R.Curl
		end
		for k, j in chain do
			local c = T.Curl[min(k, #T.Curl)]
			j.curl += (c * sin(TAU * f * t + ph - 0.6 * k) + rip * k / n) * RAD * ex
			j.ay += T.Sway * RAD * ex * noise(t * 0.2, rec.seed + ci * 3 + k) * k / n
		end
	end
end

function PROFILES.Sauropod(rec, P, t, ex, micro)
	local N = P.NeckSway
	if N then
		for i, n in rec.necks do
			local ph = TAU * N.Hz * t + rec.seed - N.Delay * (i - 1)
			n.ay += N.Yaw * RAD * ex * sin(ph)
			n.ax += N.Pitch * RAD * ex * sin(ph * 0.7 + 0.8)
		end
		local T = P.Tail
		if T and T.Counter then
			for i, j in rec.tail do
				j.ay -= T.Counter * N.Yaw * RAD * ex * sin(TAU * N.Hz * t + rec.seed - N.Delay * (2 + i)) / #rec.tail
			end
		end
	end
	tailLayer(rec, P.Tail, t, ex, micro)
	local O = P.Orbit
	if O and rec.moons then
		rec.moons.ty += O.Bob * rec.scale * sin(TAU * 0.15 * t + rec.seed)
	end
end

function PROFILES.GuardianTitan(rec, P, t, ex, micro)
	tailLayer(rec, P.Tail, t, ex, micro)
	armsLayer(rec, P.Arms, t, ex)
	local TJ = P.TrapJaw
	if TJ and rec.jaw then
		rec.jaw.ax -= TJ.Open * RAD * (0.5 - 0.5 * cos(TAU * TJ.Hz * t + rec.seed)) * (1 - rec.sleep * 0.7)
		if micro then
			local tm = rec.tm
			if t >= (tm.trap or 0) then
				if tm.trap then
					kick(rec.jaw, 1, TJ.Open * 0.8)
				end
				tm.trap = t + range(rec.rng, TJ.SnapEvery) / rec.fidget
			end
		end
	end
	local D = P.Dust
	if D and micro and #rec.legs > 0 then
		local tm = rec.tm
		if t >= (tm.dust or 0) then
			if tm.dust then
				Actions.OnEvent(rec, "Dust", rec.legs[rec.rng:NextInteger(1, #rec.legs)].name, 0.35)
			end
			tm.dust = t + range(rec.rng, D.Every)
		end
	end
end

Motion.Profiles = PROFILES

---------------------------------------------------------------------------------------------------------- walking

-- The gait while the creature wanders (rec.moveBlend 0 standing .. 1 walking, rec.moveSpeed in studs per second).
-- Planted limbs get a foot target that slides back under the body during stance and swings forward, lifted, after it.
local function gaitLayer(rec, dt)
	local mb = rec.moveBlend
	local G = rec.gait
	if mb < 0.001 or not G then
		return
	end
	local speed = rec.moveSpeed
	if G.Phase then
		local L = rec.legLength
		local duty = G.Duty
		local cadence = math.clamp(speed * duty / (G.Stride * L), 0.6 / math.sqrt(rec.scale), 3)
		rec.gaitPhase = (rec.gaitPhase + dt * cadence) % 1
		local stride = speed * duty / cadence
		local travel = rec.travelDir
		local ph = rec.gaitPhase
		for _, j in rec.joints do
			local off = j.gaitOffset
			if off then
				local phi = (ph + off) % 1
				local a, lift
				if phi < duty then
					a, lift = stride * (0.5 - phi / duty), 0
				else
					local u = (phi - duty) / (1 - duty)
					a = stride * (Util.smooth(u) - 0.5)
					lift = sin(math.pi * u) * G.Lift * L
				end
				j.fox, j.foy, j.foz = travel.X * a * mb, lift * mb, travel.Z * a * mb
			end
		end
		local body = rec.body
		if G.Bob then
			body.ty += G.Bob * rec.scale * (0.5 - 0.5 * cos(2 * TAU * ph)) * mb
		end
		if G.Lean then
			body.ax += G.Lean * RAD * mb
		end
		if G.Roll then
			body.az += G.Roll * RAD * sin(TAU * ph) * mb
		end
		if G.Yaw then
			body.ay += G.Yaw * RAD * sin(TAU * ph) * mb
		end
		if G.Hop and ph >= duty then
			local u = (ph - duty) / (1 - duty)
			body.ty += G.Hop * rec.scale * sin(math.pi * u) * mb
			body.ax += 6 * RAD * cos(math.pi * u) * mb
		end
		-- the tail counter-swings the hips, free arms pump against the legs
		for i, j in rec.tail do
			j.ay -= 7 * RAD * sin(TAU * ph - i * 0.6) * mb
		end
		for _, a in rec.arms do
			if not a.planted then
				a.ax += 12 * RAD * a.side * sin(TAU * ph) * mb
			end
		end
	elseif G.Wave then
		-- slither: an S-wave travels down the body; the neck cancels it so the head keeps its course
		rec.gaitPhase = (rec.gaitPhase + dt * speed / (2.5 * rec.scale)) % 1
		local ph = TAU * rec.gaitPhase
		for _, j in rec.spine do
			j.ay += G.Wave * RAD * sin(ph - G.K * j.chain) * mb
		end
		local n = rec.necks[1]
		if n then
			n.ay -= G.Neck * RAD * sin(ph) * mb
		end
	elseif G.Curl then
		rec.gaitPhase = (rec.gaitPhase + dt * speed / (2 * rec.scale)) % 1
		for ci, chain in rec.tentacleChains do
			local n = #chain
			for k, j in chain do
				j.curl += G.Curl * RAD * sin(TAU * rec.gaitPhase + ci * 0.9 - 0.6 * k) * k / n * mb
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------- solve

local function solve(rec, dt, lod)
	local w = rec.weight
	local useSprings = lod < 2
	local pivot = rec.pivot
	local body = rec.body
	for _, j in rec.joints do
		local p = j.parent
		local tx, ty, tz = j.ax * w, j.ay * w, j.az * w
		if j.curl ~= 0 then
			local c = j.curl * w
			tx += c * j.curlX
			tz += c * j.curlZ
		end
		local pwx, pwy, pwz = 0, 0, 0
		if p then
			pwx, pwy, pwz = p.wx, p.wy, p.wz
		end
		local stab = j.stab
		if stab > 0 then
			tx -= pwx * stab
			ty -= pwy * stab
			tz -= pwz * stab
		end
		local fx, fy, fz
		if j.spring and useSprings then
			-- inertia: the joint lags behind what its parent just did, then the spring pulls it to its target
			local k = j.inertia
			j.sx -= (pwx - j.pwx) * k
			j.sy -= (pwy - j.pwy) * k
			j.sz -= (pwz - j.pwz) * k
			local e, c, s, zw, wd = springCoeffs(j.omega, j.zeta, dt)
			local x, v = springStep(j.sx - tx, j.svx, e, c, s, zw, wd)
			j.sx, j.svx = clamp(tx + x, -MAX_ANGLE, MAX_ANGLE), v
			x, v = springStep(j.sy - ty, j.svy, e, c, s, zw, wd)
			j.sy, j.svy = clamp(ty + x, -MAX_ANGLE, MAX_ANGLE), v
			x, v = springStep(j.sz - tz, j.svz, e, c, s, zw, wd)
			j.sz, j.svz = clamp(tz + x, -MAX_ANGLE, MAX_ANGLE), v
			fx, fy, fz = j.sx, j.sy, j.sz
		else
			fx, fy, fz = tx, ty, tz
			j.sx, j.sy, j.sz = tx, ty, tz
			j.svx, j.svy, j.svz = 0, 0, 0
		end
		j.pwx, j.pwy, j.pwz = pwx, pwy, pwz
		j.wx, j.wy, j.wz = pwx + fx, pwy + fy, pwz + fz

		local kind = j.kind
		local T
		if kind == 1 then
			-- body: rotates about the pivot (centre, or the hips / shoulders during some actions)
			local px, py, pz = pivot.X, pivot.Y, pivot.Z
			T = cfnew(px + j.tx * w, py + j.ty * w, pz + j.tz * w) * fromEuler(fx, fy, fz) * cfnew(-px, -py, -pz)
			local world = j.c0 * T
			if j.c1inv then
				world *= j.c1inv
			end
			j.world = world
		elseif kind == 2 then
			-- planted limb: swing the rest pose about the foot until the hip meets the moved body
			local L = cfnew(j.tx * w, j.ty * w, j.tz * w) * fromEuler(fx, fy, fz)
			local plant = j.plant
			if plant <= 0.001 then
				T = L
			else
				local Jw = body.world * j.c0
				local foot, d0 = j.foot, j.d0
				if j.fox ~= 0 or j.foy ~= 0 or j.foz ~= 0 then
					foot += Vector3.new(j.fox, j.foy, j.foz) -- walking: the foot's place in the step cycle
				end
				local d1 = Jw.Position - foot
				local cr = d0:Cross(d1)
				local cm = cr.Magnitude
				local G
				if cm > 1e-6 then
					local q = fromAxisAngle(cr / cm, atan2(cm, d0:Dot(d1)))
					G = Jw:ToObjectSpace((q * j.restRot) + (foot + q * d0))
				else
					G = Jw:ToObjectSpace(j.restW)
				end
				if plant >= 0.999 then
					T = G * L
				else
					T = IDENTITY:Lerp(G, plant) * L
				end
			end
		elseif kind == 3 then
			j.spin = (j.spin + dt * j.spinRate * (1 + j.spinBoost)) % TAU
			T = cfnew(j.tx * w, j.ty * w, j.tz * w) * fromAxisAngle(j.axis, j.spin + j.spinAdd * w) * fromEuler(fx, fy, fz)
		else
			T = cfnew(j.tx * w, j.ty * w, j.tz * w) * fromEuler(fx, fy, fz)
		end
		j.motor.Transform = T
	end
end

-- One update of a creature. dt: seconds since its last update (slow motion included). lod: 0 Full, 1 Reduced (no micro
-- layers), 2 Far (breathing and orbits only).
function Motion.Step(rec, dt, lod)
	local t = rec.t + dt * rec.tempo * rec.tempoMul
	rec.t = t
	for _, j in rec.joints do
		j.ax, j.ay, j.az, j.tx, j.ty, j.tz, j.curl = 0, 0, 0, 0, 0, 0, 0
		j.fox, j.foy, j.foz = 0, 0, 0
		j.plant = j.plantDefault
		j.spinBoost, j.spinAdd = 0, 0
	end
	rec.glow = 0
	rec.weight = min(1, rec.weight + dt / BLEND_IN)
	local ex = EXAGGERATE * rec.ampMul
	breathLayer(rec, dt, ex)
	if lod < 2 then
		local micro = lod == 0 and rec.moveBlend < 0.5
		shiftLayer(rec, t, ex * (1 - rec.moveBlend))
		gaitLayer(rec, dt)
		headLayer(rec, t, ex, micro)
		local layer = PROFILES[rec.profileName]
		if layer then
			layer(rec, rec.P, t, ex, micro)
		end
		States.Pose(rec, dt, t)
		Actions.Apply(rec, dt, true)
	else
		Actions.Apply(rec, dt, false)
	end
	-- the body pivot eases between centre and hips / shoulders so switching never pops
	local target = rec.pivotTarget
	if rec.pivot ~= target then
		local d = target - rec.pivot
		rec.pivot = d.Magnitude < 1e-3 and target or rec.pivot + d * (1 - exp(-10 * dt))
	end
	solve(rec, dt, lod)
end

-- Puts every joint back at rest (used when a creature is released or frozen).
function Motion.Rest(rec)
	for _, j in rec.joints do
		j.motor.Transform = IDENTITY
	end
end

return Motion
