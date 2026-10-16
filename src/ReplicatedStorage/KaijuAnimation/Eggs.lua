-- KaijuAnimation.Eggs: the build-up of an egg incubating in a pen. Gameplay.KaijuFX poses every egg; while one sits in
-- a pen waiting to hatch it takes the pose from Eggs.Incubate. The build-up runs on the egg's own clock, PlacedAt to
-- HatchAt (read only): a slow rocking that never quite stops, wobble bursts that come closer together and grow
-- stronger, kicks from inside in the last stretch (a little hop and a sharp knock), and a heartbeat glow in the front gem
-- that quickens and brightens. Client-only and cosmetic; Ready, the hatch shake and the shell burst stay in KaijuFX.
local Config = require(script.Parent.Config)

local Eggs = {}

local E = Config.Eggs
local sin, exp, clamp, pi = math.sin, math.exp, math.clamp, math.pi

local function lerp(range, k)
	return range[1] + (range[2] - range[1]) * k
end

-- 0..1 of the way from placed to hatching
local function progress(model, now)
	local placed, hatch = model:GetAttribute("PlacedAt"), model:GetAttribute("HatchAt")
	if not hatch then
		return 0
	end
	if placed and hatch > placed then
		return clamp((now - placed) / (hatch - placed), 0, 1)
	end
	return 1 - clamp((hatch - now) / 60, 0, 1) -- no PlacedAt: the last minute builds up
end

-- the heartbeat light, in the front gem (or the shell), tinted like the gem
local function heartLight(model)
	local gem = model:FindFirstChild("Gem", true) or model.PrimaryPart
	local light = Instance.new("PointLight")
	light.Name = "_AnimHeart"
	light.Color = gem.Color
	light.Shadows = false
	light.Brightness = 0
	light.Parent = gem
	return light
end

-- The pose of an incubating egg: pitch, yaw, roll (radians, about its base) and y (studs up). st: KaijuFX's egg record
-- (seed, half); t: KaijuFX's clock; now: server time.
function Eggs.Incubate(model, st, t, now)
	local s = st.incubate
	if not s then
		s = { rng = Random.new(), next = t + (st.seed % 1) * 2, at = -1e9, side = 1, kick = false, light = heartLight(model) }
		st.incubate = s
	end
	local p = progress(model, now)
	local half = st.half

	-- always a little alive: a slow sway on two out-of-step rhythms
	local rock = lerp(E.Rock, p)
	local roll = sin(t * 1.1 + st.seed) * rock
	local pitch = sin(t * 0.83 + st.seed * 1.7) * rock * 0.6
	local yaw, y = 0, 0

	-- wobble bursts, closer together and stronger as it nears hatching; late on some are kicks from inside
	if t >= s.next then
		s.at = t
		s.side = s.rng:NextNumber() < 0.5 and -1 or 1
		s.kick = p >= E.KickFrom and s.rng:NextNumber() < E.KickChance
		s.next = t + lerp(E.Every, p) * s.rng:NextNumber(0.75, 1.25)
	end
	local w = t - s.at
	if w < 0.6 then
		local env = 1 - w / 0.6
		roll += sin(w * 26) * lerp(E.Wobble, p) * env * s.side
		if s.kick then
			if w < 0.18 then
				y += sin(pi * w / 0.18) * half * 2 * E.Hop
			end
			pitch += sin(w * 34) * E.Knock * env * env
			yaw += sin(w * 20) * 0.05 * env * s.side
		end
	end

	-- heartbeat: lub-dub, quicker and brighter as it nears hatching
	local light = s.light
	if light.Parent then
		local ph = (t * lerp(E.Heart, p) + st.seed) % 1
		local beat = exp(-(ph / 0.06) ^ 2) + 0.6 * exp(-((ph - 0.2) / 0.06) ^ 2)
		local size = half / 2.2
		light.Brightness = beat * lerp(E.HeartGlow, p ^ 1.5)
		light.Range = lerp(E.HeartRange, p) * math.max(size, 0.5)
	end
	return pitch, yaw, roll, y
end

-- The egg stopped incubating (ready, hatching, gone): its heartbeat light goes.
function Eggs.Stop(st)
	local s = st.incubate
	if s then
		st.incubate = nil
		s.light:Destroy()
	end
end

return Eggs
