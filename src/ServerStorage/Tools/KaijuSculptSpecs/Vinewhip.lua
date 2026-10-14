local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Common / poison: a vine raptor. A thick-set dilophosaur pitched forward on heavy digitigrade legs with
-- a raised sickle claw, raptor arms, and a long muscular tail wound with thorned vines that ends in a barbed vine lash.
-- Mid jungle-green crusted scales, bark-brown down the back, a pale belly, glowing lime venom veins down the flanks, a
-- row of bold purple spines from neck to tail. Face: a heavy bark brow over small lime eyes, a toothy snout, twin purple
-- blade crests and a big poison frill (purple membrane on dark spines, lime eyespots) fanned round its neck.
local HEAD = CFrame.new(0, 3.5, -1.86) * CFrame.Angles(rad(-10), 0, 0)
local SKULL = { 0.74, 0.52, 0.66 }

return {
	Seed = 401,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar", "Wiggle" },
	Palette = {
		Hide = { "4A7438", Material = "Slate" },
		HideDark = { "30502A", Material = "Slate" },
		HideLight = { "6C9248", Material = "Slate" },
		Back = { "5A3E26", Material = "Wood" },
		Belly = "D2C88A",
		Belly2 = "B8AE70",
		Bark = { "6A4A2E", Material = "Wood" },
		Frill = "8A34C8",
		FrillDark = "5E2392",
		FrillSpine = "2E1A24",
		Spine = "7A2CB8",
		SpineTip = "C9A8F0",
		Spot = { "A8FF3A", Neon = true },
		Venom = { "A8FF3A", Neon = true },
		Thorn = "3A2410",
		ThornTip = "D8C8A0",
		Vine = "3E6024",
		Leaf = "7ABA44",
		Tooth = "EFE8C8",
		Mouth = "6A1A3A",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0E140A",
		Claw = "2A2016",
		ClawTip = "D8CFA8",
	},
	Joints = {
		Head = { 0, 3.06, -0.94 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegL = { 0.62, 2.86, 0.44 },
		LegR = { -0.62, 2.86, 0.44 },
		ArmL = { 0.56, 2.86, -0.9 },
		ArmR = { -0.56, 2.86, -0.9 },
		Tail = { 0, 2.7, 0.76 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 34, band = 88, flank = 108, every = 2 })
		local crust = { w = 0.5, l = 0.34, t = 0.12, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.12, wide = 1.05 }
		local function tube(group, nodes, tile)
			return K:tube(group, nodes, { step = 0.34, core = "HideDark", coreScale = 0.86, tile = tile or crust, belly = belly, color = skin })
		end
		local body = tube("Body", {
			{ 0, 3.0, -0.92, rx = 0.62, ru = 0.58, rd = 0.66 },
			{ 0, 2.88, -0.3, rx = 0.74, ru = 0.66, rd = 0.74 },
			{ 0, 2.76, 0.3, rx = 0.7, ru = 0.62, rd = 0.64 },
			{ 0, 2.7, 0.8, rx = 0.58, ru = 0.52, rd = 0.5 },
		})
		local neck = tube("Head", {
			{ 0, 3.46, -1.84, rx = 0.38, ru = 0.36, rd = 0.42 },
			{ 0, 3.32, -1.44, rx = 0.47, ru = 0.44, rd = 0.5 },
			{ 0, 3.06, -0.92, rx = 0.6, ru = 0.56, rd = 0.64 },
		})
		local tail = tube("Tail", {
			{ 0, 2.7, 0.74, rx = 0.54, ru = 0.5, rd = 0.46 },
			{ 0, 2.6, 1.5, rx = 0.43, ru = 0.4, rd = 0.36 },
			{ 0.06, 2.42, 2.24, rx = 0.32, ru = 0.3, rd = 0.27 },
			{ 0.26, 2.2, 2.9, rx = 0.22, ru = 0.2, rd = 0.18 },
			{ 0.6, 2.04, 3.42, rx = 0.13, ru = 0.12, rd = 0.11 },
		}, { w = 0.42, n = 5, l = 0.3, t = 0.11, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 })
		-- bark-brown saddle plates down the back
		for _, seg in { { "Head", neck, 0.3 }, { "Body", body, 0.36 }, { "Tail", tail, 0.4 } } do
			local g, smps, every = seg[1], seg[2], seg[3]
			for s = 0.1, smps.total * (g == "Tail" and 0.7 or 0.95), every do
				local smp = K:at(smps, s)
				for _, x in { 1, -1 } do
					K:tile(g, "Back", smp, rad(24) * x, smp.rx * 0.6, 0.32, 0.1, 6, 3, 0.3)
				end
			end
		end
		-- bold purple spines from the neck to the tail
		K:ridge("Head", neck, { every = 0.26, height = function(u) return 0.3 + u * 0.12 end, thick = 0.1, key = "Spine", tip = "SpineTip", lean = 34, sink = 0.85 })
		K:ridge("Body", body, { every = 0.28, height = function(u) return 0.48 - u * 0.12 end, thick = 0.12, key = "Spine", tip = "SpineTip", lean = 30, sink = 0.85 })
		K:ridge("Tail", tail, { to = tail.total * 0.75, every = 0.3, height = function(u) return 0.34 - u * 0.2 end, thick = 0.1, key = "Spine", tip = "SpineTip", lean = 38, sink = 0.85 })
		-- glowing lime venom veins down the flanks and the neck
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "Venom", body, rad(72) * x, 0.1, body.total - 0.1, { width = 0.07, height = 0.08, lift = 0.02, wander = 18, forks = 2 })
			H.vein(K, "Head", "Venom", neck, rad(70) * x, 0.1, neck.total - 0.1, { width = 0.06, height = 0.07, lift = 0.02, wander = 14 })
			H.vein(K, "Tail", "Venom", tail, rad(76) * x, 0.1, tail.total * 0.6, { width = 0.06, height = 0.07, lift = 0.02, wander = 14, taper = true })
		end
		-- thorned vines wound round the tail
		local n = 26
		for i = 0, n do
			local s = 0.25 + (tail.total * 0.9 - 0.25) * i / n
			local smp = K:at(tail, s)
			local th = i / n * math.pi * 2 * 2.4
			local pos, nrm = K:surface(smp, th, -0.05)
			local dir = (smp.T + smp.U * math.cos(th + math.pi / 2) * 0.6 + smp.R * math.sin(th + math.pi / 2) * 0.6).Unit
			K:block("Tail", "Vine", CFrame.lookAt(pos, pos + dir), Vector3.new(0.13, 0.13, 0.26))
			if i % 3 == 0 then
				K:block("Tail", "Leaf", CFrame.fromMatrix(pos + nrm * 0.07, dir, nrm) * CFrame.Angles(0, rad(30), 0), Vector3.new(0.3, 0.04, 0.17))
			elseif i % 3 == 1 then
				K:spike("Tail", "ThornTip", pos, nrm, dir, 0.14, 0.05)
			end
		end
		-- the barbed vine lash trailing from the tail: a thick whip of vine curling up, hooked purple barbs, a glowing tip
		local tip = K:at(tail, tail.total)
		local up = Vector3.yAxis
		local lash = { tip.p - tip.T * 0.06, tip.p + tip.T * 0.6 + tip.R * 0.14, tip.p + tip.T * 1.2 + tip.R * 0.26 + up * 0.24, tip.p + tip.T * 1.66 + tip.R * 0.14 + up * 0.72, tip.p + tip.T * 1.72 - tip.R * 0.1 + up * 1.24 }
		H.curve(K, "Tail", { "Vine", "Vine", "Vine", "Thorn" }, lash, 0.3, 0.12, 0.12)
		H.curve(K, "Tail", { "Venom" }, { lash[2] + up * 0.14, lash[3] + up * 0.14, lash[4] + up * 0.1 - tip.T * 0.1 }, 0.06, 0.04, 0.12)
		for i = 2, #lash - 1 do
			local p = lash[i]
			for _, d in { (tip.R + up * 0.3 - tip.T * 0.3).Unit, (-tip.R + up * 0.2 - tip.T * 0.3).Unit } do
				K:chain("Tail", { "Spine", "SpineTip" }, p, d, tip.T, { n = 2, len = 0.38, w0 = 0.11, w1 = 0.06, bend = -24 })
			end
			K:block("Tail", "Leaf", CFrame.lookAt(p + up * 0.08, p + tip.T), Vector3.new(0.26, 0.04, 0.16))
		end
		K:chain("Tail", { "Spine", "Spine", "SpineTip" }, lash[#lash], (lash[#lash] - lash[#lash - 1]).Unit, tip.R, { n = 3, len = 0.42, w0 = 0.16, w1 = 0.08, bend = -30 })

		-- heavy digitigrade legs, a raised sickle claw on each inner toe
		H.bipedLegs(K, {
			pts = {
				{ 0.62, 2.88, 0.44, 0.5, 0.56 },
				{ 0.8, 2.26, 0.12, 0.42, 0.46 },
				{ 0.82, 1.72, -0.08, 0.32 },
				{ 0.82, 0.68, 0.46, 0.21 },
				{ 0.82, 0.22, 0.16, 0.17 },
			},
			stance = { -0.3, 0.3 },
			foot = Vector3.new(0.52, 0.26, 0.62),
			toe = { 0.16, 0.34 },
			claw = { 0.3, 0.085 },
			muscle = "HideLight",
			armour = "Bark",
			scutes = "Back",
		})
		for _, x in { 1, -1 } do
			local dz = x == 1 and -0.3 or 0.3
			local base = Vector3.new(0.64 * x, 0.36, 0.06 + dz)
			K:chain(x == 1 and "LegL" or "LegR", { "Claw", "Claw", "ClawTip" }, base, Vector3.new(0, 0.7, -0.7).Unit, Vector3.xAxis, { n = 3, len = 0.5, w0 = 0.11, w1 = 0.07, bend = 34 })
		end
		H.bipedArms(K, {
			pts = { { 0.56, 2.88, -0.9, 0.2 }, { 0.74, 2.5, -1.1, 0.16 }, { 0.68, 2.3, -1.48, 0.12 } },
			hand = Vector3.new(0.22, 0.14, 0.24),
			fwd = Vector3.new(0, -0.4, -1),
			claws = { n = 3, len = 0.32, w = 0.065, curl = 36 },
		})

		-- head: a heavy bark brow over small lime eyes, a toothy snout, twin purple blade crests
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.56, 0.4, 0.6 },
			tip = { 0.44, 0.32, 0.34 },
			open = 22,
			teeth = { 0.11, 0.06 },
			brow = "Bark",
			browSize = { 0.4, 0.2, 0.48 },
			eye = { 0.14, 0.045 },
			cheek = 0.26,
		})
		for _, x in { 1, -1 } do
			local top = R.top
			K:plate("Head", { "FrillDark", "Spine", "SpineTip" }, R.p(0.13 * x, top - 0.02, -0.66), R.v(0.12 * x, 1, 0), R.v(0, 0, 1), { h = 0.5, w = 0.6, t = 0.07, n = 3, lean = 28 })
			K:block("Head", "Bark", R.cf(0.2 * x, top + 0.02, -0.2, -6, 0, 10 * x), Vector3.new(0.3, 0.12, 0.46))
		end
		-- the poison frill fanned round the neck: dark spines, purple membrane, lime eyespots
		local spines = {}
		local N = 11
		for i = 0, N - 1 do
			local a = rad(-115 + 230 * i / (N - 1))
			local dir = R.v(math.sin(a), math.cos(a) * 0.9, 0.55)
			local base = R.p(math.sin(a) * 0.26, 0.2 + math.cos(a) * 0.2, 0.12)
			local len = 0.95 + (math.cos(a) > 0.3 and 0.15 or 0)
			K:chain("Head", { "FrillSpine", "FrillSpine", "SpineTip" }, base, dir, R.v(0, 0, 1), { n = 3, len = len, w0 = 0.09, w1 = 0.06, bend = 8 })
			spines[i + 1] = { base = base, dir = dir, len = len }
		end
		for i = 1, N - 1 do
			local a, b = spines[i], spines[i + 1]
			for k, f in { 0.36, 0.7 } do
				local pa = a.base + a.dir * a.len * f
				local pb = b.base + b.dir * b.len * f
				local across = pb - pa
				local nrm = across:Cross(a.dir).Unit
				K:block("Head", (i + k) % 2 == 0 and "Frill" or "FrillDark", CFrame.fromMatrix((pa + pb) / 2, across.Unit, nrm), Vector3.new(across.Magnitude + 0.08, 0.05, a.len * 0.42))
				if k == 2 and i % 2 == 0 then
					K:block("Head", "Spot", CFrame.fromMatrix((pa + pb) / 2 + nrm * 0.035, across.Unit, nrm), Vector3.new(0.18, 0.05, 0.18))
				end
			end
		end
	end,
}
