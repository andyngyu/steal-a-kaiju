-- Kaiju locomotion and emotes, matched to each kaiju's real animal. Brick kaiju carry Gait / Emotes / Wag attributes
-- from ServerStorage.Tools.KaijuSpecs; placeholder models without a Gait keep the original hop-and-waddle.
-- Gameplay.KaijuFX drives it every frame for kaiju near the camera:
--   KaijuMotion.Setup(st, model)      once, after the rig is built (st.rig, st.scale, st.seed already set)
--   KaijuMotion.FaceOffset(st)        yaw added to the walking direction (crabs walk sideways)
--   KaijuMotion.PhaseRate(st)         stride-speed multiplier
--   KaijuMotion.UpdateEmote(st, rng, moving)   starts / advances / ends idle emotes
--   KaijuMotion.Force(st, name)       plays an emote right away, even mid-walk ("Eat" when food lands: EatAt attribute)
--   KaijuMotion.Body(st, t)           -> y, pitch, roll, yaw for the whole body
--   KaijuMotion.Limbs(st, t)          sets group.anim for every body group of the rig
--
-- Gaits:
--   Biped    the rexes: two-legged stomp, little arms tucked in, the tail counter-swings the hips,
--            the head bobs; Roar opens the jaw
--   Knuckle  apes: knuckle-walk with arms and legs in diagonal pairs, body leaning forward, shoulders rolling; ChestBeat
--   Trot     Snowpup (wolf), Frostrhino, Prismling (winged crystal drake: WingL / WingR sway, beat and flare);
--            diagonal-pair trot; PlayBow / Paw
--   Amble    Tuskit (mammoth): elephant lateral-sequence walk (back-left, front-left, back-right, front-right), slow
--            and heavy, ears fanning, trunk swinging; Trumpet raises the trunk
--   Crawl    Chompling (croc), Scorchback (ankylosaur): low sprawling walk, the spine bends side to side and the tail
--            swings the other way; Chomp / TailSwing
--   Hop      Cinder Toad: travels in hops, back legs kick out and front legs reach to land; BigHop
--   Scuttle  crabs: walk sideways with a fast tripod leg gait, claws held up; ClawSnap
--   Slither  serpents: an S-wave travels down the body chain (Seg1..Seg4, Tail) while the head stays on course,
--            the forked tongue flicks; RearUp lifts the neck like a cobra
local KaijuMotion = {}

-- Fires (model, emoteName) whenever a kaiju starts an emote; Gameplay.GameAudio plays the matching sound.
local emoteStarted = Instance.new("BindableEvent")
KaijuMotion.EmoteStarted = emoteStarted.Event

local PI = math.pi

local GAITS = {
	Biped = { rate = 1.0, bob = 0.35, lean = -0.06, roll = 0.06, sway = 0.05, emotes = { "Look", "Roar", "Hop", "Wiggle" } },
	Knuckle = { rate = 0.9, bob = 0.3, lean = -0.16, roll = 0.08, sway = 0.04, emotes = { "Look", "ChestBeat", "Hop" } },
	Trot = { rate = 1.2, bob = 0.4, lean = -0.03, roll = 0.03, sway = 0, emotes = { "Look", "HopSpin", "Wiggle" } },
	Amble = { rate = 0.7, bob = 0.15, lean = 0, roll = 0.06, sway = 0.02, emotes = { "Look", "Trumpet", "Wiggle" } },
	Crawl = { rate = 1.1, bob = 0.1, lean = 0, roll = 0.02, sway = 0.12, emotes = { "Look", "Wiggle" } },
	Hop = { rate = 0.8, bob = 0, lean = 0, roll = 0, sway = 0, emotes = { "BigHop", "Look" } },
	Scuttle = { rate = 1.3, bob = 0.08, lean = 0, roll = 0.05, sway = 0, emotes = { "ClawSnap", "Look", "Wiggle" } },
	Slither = { rate = 0.8, bob = 0, lean = 0, roll = 0, sway = 0, emotes = { "RearUp", "Look" } },
	Legacy = { rate = 1.0, bob = 1, lean = -0.08, roll = 0.14, sway = 0, emotes = { "HopSpin", "Look", "Wiggle", "Hop" } },
}

local EMOTE_SECONDS = {
	Look = 1.6,
	Hop = 0.45,
	HopSpin = 0.7,
	Wiggle = 0.8,
	Roar = 1.8,
	ChestBeat = 1.6,
	PlayBow = 1.6,
	Paw = 1.4,
	Trumpet = 1.8,
	Chomp = 1.2,
	TailSwing = 1.4,
	BigHop = 0.9,
	ClawSnap = 1.2,
	RearUp = 2.2,
	Eat = 1.1,
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- 0 -> 1 -> 0 over an emote, holding in the middle
local function envelope(e)
	return math.clamp(math.min(e / 0.2, (1 - e) / 0.25), 0, 1)
end

-- Lets the new animation engine (ReplicatedStorage.KaijuAnimation) voice its actions through the same sound hooks.
function KaijuMotion.FireEmote(model, name)
	emoteStarted:Fire(model, name)
end

function KaijuMotion.Setup(st, model)
	local gait = model:GetAttribute("Gait")
	if not (gait and GAITS[gait] and st.limbs) then
		gait = "Legacy"
	end
	st.gait = gait
	st.gaitInfo = GAITS[gait]
	st.wag = model:GetAttribute("Wag") == true
	local list = {}
	for name in string.gmatch(model:GetAttribute("Emotes") or "", "[^,]+") do
		if EMOTE_SECONDS[name] then
			table.insert(list, name)
		end
	end
	st.emotes = #list > 0 and list or st.gaitInfo.emotes
	st.headYaw = 0
	local height = st.rig.size.Y
	if gait == "Hop" then
		st.hopHeight = 0.5 + height * 0.3
	else
		st.hopHeight = 0.25 + height * 0.07
	end
	st.hasHead = false
	for _, g in st.rig.groups do
		st.hasHead = st.hasHead or g.name == "Head" or g.name == "Neck"
	end
end

function KaijuMotion.FaceOffset(st)
	return st.gait == "Scuttle" and PI / 2 or 0
end

function KaijuMotion.PhaseRate(st)
	return st.gaitInfo.rate
end

function KaijuMotion.Force(st, name)
	if EMOTE_SECONDS[name] then
		st.emote = name
		st.emoteStart = os.clock()
		st.emoteProgress = 0
		st.forced = true
		emoteStarted:Fire(st.model, name)
	end
end

function KaijuMotion.UpdateEmote(st, rng, moving)
	local now = os.clock()
	if moving and not st.forced then
		st.emote = nil
	elseif not st.emote and st.moveBlend < 0.1 and now > st.nextEmote then
		local name = st.emotes[rng:NextInteger(1, #st.emotes)]
		st.emote = name
		st.emoteStart = now
		emoteStarted:Fire(st.model, name)
	end
	if st.emote then
		st.emoteProgress = (now - st.emoteStart) / EMOTE_SECONDS[st.emote]
		if st.emoteProgress >= 1 then
			st.emote = nil
			st.forced = nil
			st.nextEmote = now + rng:NextNumber(4, 10)
		end
	end
	if not st.emote then
		st.emoteProgress = 0
	end
end

function KaijuMotion.Body(st, t)
	local g = st.gaitInfo
	local mb, ph = st.moveBlend, st.phase
	local y = math.abs(math.sin(ph)) * st.hopHeight * g.bob * mb
	local pitch = g.lean * mb
	local roll = math.sin(ph) * g.roll * mb
	local yaw = math.sin(ph) * g.sway * mb
	if st.gait ~= "Slither" then
		y += math.sin(t * 2.2 + st.seed) * 0.06 * (1 - mb) -- breathing
	end
	if st.gait == "Hop" then
		local air = math.max(0, math.sin(ph))
		y += air ^ 0.8 * st.hopHeight * mb
		pitch += math.cos(ph) * air * 0.22 * mb -- nose up on take-off, down to land
	elseif st.gait == "Trot" then
		pitch += math.sin(ph * 2) * 0.03 * mb
	end

	local emote, e = st.emote, st.emoteProgress
	if emote then
		local env = envelope(e)
		if emote == "Hop" then
			y += math.sin(e * PI) * (0.6 + st.hopHeight)
		elseif emote == "HopSpin" then
			y += math.sin(e * PI) * (1 + st.hopHeight * 2)
			yaw += e * PI * 2
		elseif emote == "Wiggle" then
			roll += math.sin(e * PI * 6) * 0.22 * (1 - e)
		elseif emote == "Look" then
			if st.hasHead then
				st.headYaw = math.sin(e * PI * 2) * 0.65 -- turns its head, the body follows a little
				yaw += math.sin(e * PI * 2) * 0.2
			else
				yaw += math.sin(e * PI * 2) * 0.7
			end
		elseif emote == "Roar" or emote == "Trumpet" then
			pitch += 0.15 * env -- rears back
		elseif emote == "ChestBeat" then
			pitch += 0.14 * env
			y += math.abs(math.sin(e * PI * 10)) * 0.05 * env
		elseif emote == "PlayBow" then
			pitch -= 0.28 * env -- front down, tail up
			if e > 0.7 then
				y += math.sin((e - 0.7) / 0.3 * PI) * (0.4 + st.hopHeight)
			end
		elseif emote == "Paw" then
			pitch -= 0.08 * env
		elseif emote == "BigHop" then
			y += math.sin(e * PI) * (1.2 + st.hopHeight)
			pitch += math.cos(e * PI) * math.sin(e * PI) * 0.3
		elseif emote == "ClawSnap" then
			roll += math.sin(e * PI * 6) * 0.08 * (1 - e)
		elseif emote == "TailSwing" then
			yaw -= math.sin(e * PI * 4) * 0.12 * env
		elseif emote == "Eat" then
			pitch -= 0.12 * env -- leans in to the food
		end
	end
	return y, pitch, roll, yaw
end

-- LegML / LegMR: a six-legged bug's middle legs (Quasarab); in the diagonal gaits they step with the opposite pair,
-- so the legs move in two alternating tripods
local LATERAL = { LegBL = 0, LegFL = PI / 2, LegBR = PI, LegFR = PI * 1.5, LegMR = PI * 0.25, LegML = PI * 1.25 }

function KaijuMotion.Limbs(st, t)
	local gait, mb, ph, seed, s = st.gait, st.moveBlend, st.phase, st.seed, st.scale
	local emote, e = st.emote, st.emoteProgress
	local env = emote and envelope(e) or 0
	for _, g in st.rig.groups do
		local n = g.name
		local side = n:sub(-1) == "R" and -1 or 1
		local a = CFrame.identity
		if n == "LegL" or n == "LegR" then
			local amp = gait == "Knuckle" and 0.5 or 0.55
			a = CFrame.Angles(math.sin(ph + (side == 1 and 0 or PI)) * amp * mb, 0, 0)
		elseif n == "ArmL" or n == "ArmR" then
			-- arms move with the opposite leg (diagonal pairs); a rex keeps its little arms tucked
			local amp = gait == "Knuckle" and 0.6 or 0.12
			local pitch = math.sin(ph + (side == 1 and PI or 0)) * amp * mb + math.sin(t * 2 + seed) * 0.05
			local roll = side * (0.04 + 0.03 * math.sin(t * 1.7 + seed))
			if emote == "ChestBeat" then
				local beat = math.max(0, math.sin(e * PI * 10 + (side == 1 and 0 or PI)))
				pitch = lerp(pitch, 1.15 + beat * 0.45, env)
				roll = lerp(roll, -side * 0.5, env)
			elseif emote == "Roar" then
				pitch = lerp(pitch, 0.7, env)
				roll = lerp(roll, side * 0.35, env)
			elseif emote == "Eat" and side == -1 and gait == "Knuckle" then
				pitch = lerp(pitch, 1.35, env) -- apes lift the food to their mouth with one hand
				roll = lerp(roll, 0.45, env)
			end
			a = CFrame.Angles(pitch, 0, roll)
		elseif LATERAL[n] then
			local front = n:sub(4, 4) == "F"
			local pitch
			if gait == "Amble" then
				pitch = math.sin(ph + LATERAL[n]) * 0.38 * mb
			elseif gait == "Hop" then
				local air = math.max(0, math.sin(ph)) * mb
				pitch = front and air * 0.55 or -air * 0.9 -- front legs reach to land, back legs kick out
			else
				local pair = (n == "LegFL" or n == "LegBR" or n == "LegMR") and 0 or PI -- diagonal pairs move together
				pitch = math.sin(ph + pair) * (gait == "Crawl" and 0.45 or 0.5) * mb
			end
			if emote == "PlayBow" and front then
				pitch += 0.5 * env -- front paws stretch forward
			elseif emote == "Paw" and n == "LegFR" then
				pitch += math.sin(e * PI * 6) * 0.6 * env
			elseif emote == "BigHop" then
				local air = math.sin(e * PI)
				pitch += front and air * 0.55 or -air * 0.9
			end
			a = CFrame.Angles(pitch, 0, 0)
		elseif n:match("^Leg[ABC][LR]$") then
			-- tripod gait: front + back legs on one side step with the middle leg on the other
			local tripod = ((n:sub(4, 4) == "B") == (side == 1)) and PI or 0
			local p = ph * 1.6 + tripod
			a = CFrame.Angles(0, math.sin(p) * 0.4 * mb, side * math.max(0, math.cos(p)) * 0.35 * mb)
		elseif n == "ClawL" or n == "ClawR" then
			local snap = math.max(0, math.sin(t * 2.3 + seed + (side == 1 and 0 or 1.3))) ^ 8
			local pitch = 0.2 * mb + snap * 0.3 + math.sin(t * 1.5 + seed) * 0.04
			if emote == "ClawSnap" then
				pitch = lerp(pitch, 0.7 + math.max(0, math.sin(e * PI * 8 + (side == 1 and 0 or 1))) * 0.25, env)
			elseif emote == "Eat" then
				pitch = lerp(pitch, 0.55 + math.max(0, math.sin(e * PI * 6 + (side == 1 and 0 or PI))) * 0.3, env) -- claws to mouth
			end
			a = CFrame.Angles(pitch, 0, 0)
		elseif n == "Head" then
			local pitch = math.sin(ph * 2) * 0.06 * mb + math.sin(t * 1.4 + seed) * 0.035
			local yaw = st.headYaw
			if gait == "Knuckle" then
				pitch += 0.12 * mb -- keeps looking ahead while the body leans forward
			elseif gait == "Amble" then
				pitch = math.sin(ph) * 0.07 * mb + math.sin(t * 1.2 + seed) * 0.03
			elseif gait == "Crawl" then
				yaw -= math.sin(ph) * st.gaitInfo.sway * mb -- holds the head straight while the spine bends
			elseif gait == "Slither" then
				pitch = math.sin(t * 1.3 + seed) * 0.04
			end
			if emote == "Roar" then
				pitch += 0.45 * env -- nose up
			elseif emote == "ChestBeat" or emote == "Trumpet" then
				pitch += 0.25 * env
			elseif emote == "Paw" then
				pitch -= 0.3 * env
			elseif emote == "Chomp" then
				pitch += math.max(0, math.sin(e * PI * 6)) * 0.2 * env
			elseif emote == "RearUp" then
				pitch -= 0.3 * env -- keeps the face level while the neck rises
				yaw += math.sin(e * PI * 4) * 0.25 * env
			elseif emote == "Eat" then
				pitch += (-0.35 + math.max(0, math.sin(e * PI * 6)) * 0.12) * env -- dips to the food, chewing nods
			end
			a = CFrame.Angles(pitch, yaw, 0)
		elseif n == "Jaw" then
			local open = math.max(0, math.sin(t * 1.3 + seed)) ^ 14 * 0.6 -- the odd yawn
			if emote == "Roar" then
				open = math.max(open, env)
			elseif emote == "Chomp" or emote == "Eat" then
				open = math.max(0, math.sin(e * PI * 6)) * env
			end
			a = CFrame.Angles(-open * 0.55, 0, 0)
		elseif n == "Tongue" then
			-- snakes smell with their tongue: a quick flick every couple of seconds
			local w = (t * 0.8 + seed) % 2.2
			local out = w < 0.45 and math.sin(w / 0.45 * PI) or 0
			if emote == "RearUp" then
				out = math.max(out, math.abs(math.sin(e * PI * 5)) * env)
			end
			a = CFrame.new(0, 0, -out * 0.45 * s)
		elseif gait == "Slither" and (n == "Tail" or n:match("^Seg%d$")) then
			-- lateral undulation: the wave travels from head to tail; at rest the body lies in a lazy S
			local i = n == "Tail" and 5 or tonumber(n:sub(4))
			local wave = math.sin(ph - i * 1.05) * 0.42 * mb
			local rest = (math.sin(i * 1.3 + 0.6) * 0.3 + math.sin(t * 0.9 + seed - i) * 0.08) * (1 - mb)
			a = CFrame.Angles(0, wave + rest, 0)
		elseif n == "Tail" then
			local yaw = math.sin(t * 1.8 + seed) * 0.14
			if gait == "Biped" or gait == "Crawl" then
				yaw -= math.sin(ph) * (gait == "Crawl" and 0.35 or 0.22) * mb -- counter-swings the hips
			elseif st.wag then
				yaw = math.sin(t * 14 + seed) * 0.35 -- happy dog
			else
				yaw += math.sin(ph) * 0.2 * mb
			end
			if emote == "TailSwing" then
				yaw += math.sin(e * PI * 4) * 0.8 * env
			elseif emote == "PlayBow" then
				yaw += math.sin(t * 20) * 0.2 * env
			end
			a = CFrame.Angles(0, yaw, 0)
		elseif n == "Neck" then
			local yaw = math.sin(t * 1.6 + seed) * 0.12 * (1 - mb)
			local pitch = math.sin(t * 1.2 + seed) * 0.04
			if gait == "Slither" then
				yaw -= math.sin(ph) * 0.3 * mb -- cancels the body wave so the head keeps pointing where it goes
			end
			if emote == "RearUp" then
				pitch += 0.35 * env
			elseif emote == "Eat" then
				pitch -= 0.25 * env -- strikes down at the food
			end
			a = CFrame.Angles(pitch, yaw, math.sin(t * 1.9 + seed) * 0.05)
		elseif n == "EarL" or n == "EarR" then
			local flick = math.max(0, math.sin(t * 1.1 + seed + (side == 1 and 0 or 0.7))) ^ 10
			local roll = flick * 0.35 + math.sin(ph * 2) * 0.1 * mb
			if gait == "Amble" then
				roll = math.sin(t * 1.6 + seed) * 0.18 + math.sin(ph) * 0.1 * mb -- elephants fan their ears
			end
			if emote == "Trumpet" then
				roll += 0.5 * env
			end
			a = CFrame.Angles(0, 0, side * roll)
		elseif n == "Trunk" then
			local pitch = math.sin(t * 2.1 + seed) * 0.16 + math.sin(ph) * 0.25 * mb
			if emote == "Trumpet" then
				pitch = lerp(pitch, 1.7, env)
			elseif emote == "Eat" then
				pitch = lerp(pitch, 1.2 + math.sin(e * PI * 4) * 0.15, env) -- curls food up to its mouth
			end
			a = CFrame.Angles(pitch, 0, math.sin(t * 1.3 + seed) * 0.1)
		elseif n == "WingL" or n == "WingR" then
			-- wings: a slow breathing sway at rest, beating while it moves, flared wide on emotes
			local roll = math.sin(t * 1.3 + seed) * 0.07 + math.sin(ph * 2) * 0.32 * mb
			if emote then
				roll += 0.35 * env
			end
			a = CFrame.Angles(0, 0, side * roll)
		elseif n == "Fins" then
			a = CFrame.Angles(0, 0, math.sin(t * 4 + seed) * 0.08)
		elseif n == "Cloud" then
			a = CFrame.new(0, math.sin(t * 1.5 + seed) * 0.15 * s, 0) * CFrame.Angles(0, math.sin(t * 0.7 + seed) * 0.08, 0)
		elseif n == "EyeL" or n == "EyeR" then
			a = CFrame.Angles(math.sin(t * 2.2 + seed + side) * 0.1, 0, side * math.sin(t * 1.7 + seed) * 0.15)
		end
		g.anim = a
	end
end

return KaijuMotion
