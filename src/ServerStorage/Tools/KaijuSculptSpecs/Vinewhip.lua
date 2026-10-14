local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Common / poison: a vine raptor. Lean and quick, built like a small dilophosaur: a slim body pitched
-- forward on long digitigrade legs with a sickle claw on each foot, raptor arms with three hooked claws, a long whip of
-- a tail wound with thorned vines and ending in a barbed lash. Jungle-green hide striped dark down the back, a pale
-- yellow belly, toxic lime spots down the flanks, thorns down the spine. Face: a narrow snout full of teeth, twin
-- blade crests, lime slit eyes under a dark brow, and a poison frill (purple membrane on dark spines, lime eyespots)
-- fanned round its neck.
local HEAD = CFrame.new(0, 3.22, -1.42) * CFrame.Angles(rad(-10), 0, 0)
local SKULL = { 0.58, 0.44, 0.6 }

return {
	Seed = 401,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar", "Wiggle" },
	Palette = {
		Hide = "3F6A28",
		HideDark = "2A4A1C",
		HideLight = "6A8E3C",
		Back = "1C2E14",
		Belly = "B8B06A",
		Belly2 = "9E9656",
		Frill = "6B2E8A",
		FrillDark = "4A1F62",
		FrillSpine = "2A1A30",
		Crest = "8A2E5A",
		Spot = { "8AF03A", Neon = true },
		Thorn = "3A2410",
		ThornTip = "C9B98A",
		Vine = "3E6024",
		Leaf = "6FAA38",
		Tooth = "EFE8C8",
		Mouth = "5A1E2A",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0E140A",
		Claw = "2A2016",
		ClawTip = "D8CFA8",
	},
	Joints = {
		Head = { 0, 2.56, -0.78 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegL = { 0.42, 2.12, 0.42 },
		LegR = { -0.42, 2.12, 0.42 },
		ArmL = { 0.4, 2.32, -0.72 },
		ArmR = { -0.4, 2.32, -0.72 },
		Tail = { 0, 2.18, 0.7 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 34, band = 86, flank = 106, every = 2 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 44, t = 0.1, wide = 1.1 }
		local body = K:tube("Body", {
			{ 0, 2.42, -0.78, rx = 0.44, ru = 0.42, rd = 0.5 },
			{ 0, 2.34, -0.3, rx = 0.52, ru = 0.48, rd = 0.56 },
			{ 0, 2.22, 0.2, rx = 0.5, ru = 0.46, rd = 0.48 },
			{ 0, 2.16, 0.62, rx = 0.44, ru = 0.42, rd = 0.38 },
		}, { step = 0.3, core = "Hide", coreScale = 0.9, tile = H.plates(0.4, nil, 0.1), belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 3.12, -1.32, rx = 0.25, ru = 0.25, rd = 0.27 },
			{ 0, 2.94, -1.12, rx = 0.29, ru = 0.29, rd = 0.31 },
			{ 0, 2.68, -0.9, rx = 0.35, ru = 0.35, rd = 0.39 },
			{ 0, 2.46, -0.7, rx = 0.42, ru = 0.4, rd = 0.46 },
		}, { step = 0.24, core = "Hide", coreScale = 0.9, tile = H.plates(0.32, nil, 0.09), belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 2.18, 0.66, rx = 0.4, ru = 0.38, rd = 0.34 },
			{ 0, 2.12, 1.3, rx = 0.3, ru = 0.28, rd = 0.26 },
			{ 0.08, 1.98, 2.0, rx = 0.2, ru = 0.19, rd = 0.17 },
			{ 0.3, 1.8, 2.7, rx = 0.12, ru = 0.11, rd = 0.1 },
			{ 0.62, 1.7, 3.3, rx = 0.07, ru = 0.07, rd = 0.06 },
		}, { step = 0.3, core = "Hide", coreScale = 0.9, tile = H.plates(0.3, 5, 0.09), belly = belly, color = skin, trim = 0.1 })
		-- thorns down the spine, neck to tail
		K:ridge("Head", neck, { every = 0.2, height = 0.16, thick = 0.06, key = "Thorn", lean = 40, sink = 0.85 })
		K:ridge("Body", body, { every = 0.22, height = function(u) return 0.26 - u * 0.08 end, thick = 0.07, key = "Thorn", tip = "ThornTip", lean = 38, sink = 0.85 })
		K:ridge("Tail", tail, { to = tail.total * 0.7, every = 0.26, height = function(u) return 0.2 - u * 0.12 end, thick = 0.06, key = "Thorn", lean = 44, sink = 0.85 })
		-- toxic spots down the flanks
		for _, seg in { { "Body", body, 0.08 }, { "Tail", tail, 0.1 } } do
			local g, smps = seg[1], seg[2]
			local s, k = seg[3], 0
			while s < smps.total * (g == "Tail" and 0.55 or 0.92) do
				local smp = K:at(smps, s)
				for _, x in { 1, -1 } do
					local pos, nrm = K:surface(smp, rad(72 + (k % 2) * 16) * x, -0.03)
					K:block(g, "Spot", CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm), Vector3.new(0.12, 0.04, 0.15))
				end
				s += 0.3
				k += 1
			end
		end
		-- thorned vines wound round the tail, leaves on them
		local n = 22
		for i = 0, n do
			local s = 0.2 + (tail.total * 0.82 - 0.2) * i / n
			local smp = K:at(tail, s)
			local th = i / n * math.pi * 2 * 2.2
			local pos, nrm = K:surface(smp, th, -0.04)
			local dir = (smp.T + smp.U * math.cos(th + math.pi / 2) * 0.6 + smp.R * math.sin(th + math.pi / 2) * 0.6).Unit
			K:block("Tail", "Vine", CFrame.lookAt(pos, pos + dir), Vector3.new(0.09, 0.09, 0.2))
			if i % 3 == 0 then
				K:block("Tail", "Leaf", CFrame.fromMatrix(pos + nrm * 0.06, dir, nrm) * CFrame.Angles(0, rad(30), 0), Vector3.new(0.22, 0.03, 0.13))
			elseif i % 3 == 1 then
				K:spike("Tail", "ThornTip", pos, nrm, dir, 0.1, 0.04)
			end
		end
		-- the barbed lash at the end of the tail
		local tip = K:at(tail, tail.total)
		local lash = { tip.p - tip.T * 0.05, tip.p + tip.T * 0.35 + Vector3.new(0.12, 0.12, 0), tip.p + tip.T * 0.62 + Vector3.new(0.12, 0.36, 0), tip.p + tip.T * 0.7 + Vector3.new(-0.04, 0.6, 0) }
		H.curve(K, "Tail", { "Vine", "Vine", "Thorn" }, lash, 0.12, 0.05, 0.14)
		for i = 2, 3 do
			local p = lash[i]
			K:spike("Tail", "ThornTip", p, Vector3.new(0.3, -0.2, 0.8).Unit, Vector3.yAxis, 0.12, 0.04)
			K:spike("Tail", "ThornTip", p, Vector3.new(-0.6, 0.2, 0.6).Unit, Vector3.yAxis, 0.11, 0.04)
		end
		-- long digitigrade legs, a raised sickle claw on each inner toe
		H.bipedLegs(K, {
			pts = { { 0.42, 2.12, 0.42, 0.38, 0.42 }, { 0.52, 1.5, 0.0, 0.28 }, { 0.52, 0.64, 0.52, 0.15 }, { 0.52, 0.22, 0.3, 0.12 } },
			stance = { -0.14, 0.18 },
			foot = Vector3.new(0.38, 0.2, 0.5),
			toe = { 0.12, 0.3 },
			claw = { 0.24, 0.07 },
			scutes = "HideDark",
		})
		for _, x in { 1, -1 } do
			local dz = x == 1 and -0.14 or 0.18
			local base = Vector3.new(0.4 * x, 0.32, 0.12 + dz)
			K:chain(x == 1 and "LegL" or "LegR", { "Claw", "Claw", "ClawTip" }, base, Vector3.new(0, 0.7, -0.7).Unit, Vector3.xAxis, { n = 3, len = 0.42, w0 = 0.08, w1 = 0.05, bend = 34 })
		end
		-- raptor arms held forward, three long hooked claws
		H.bipedArms(K, {
			pts = { { 0.4, 2.32, -0.72, 0.15 }, { 0.56, 2.0, -0.6, 0.12 }, { 0.5, 1.8, -1.0, 0.09 } },
			hand = Vector3.new(0.18, 0.1, 0.2),
			fwd = Vector3.new(0, -0.45, -1),
			claws = { n = 3, len = 0.3, w = 0.05, curl = 36 },
		})

		-- the head: a narrow toothy snout, twin blade crests, lime slit eyes
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.42, 0.32, 0.5 },
			tip = { 0.32, 0.24, 0.3 },
			open = 20,
			teeth = { 0.09, 0.05 },
			brow = "Back",
			eye = { 0.16, 0.045 },
			cheek = 0.18,
		})
		for _, x in { 1, -1 } do
			local top = R.top
			K:block("Head", "Crest", R.cf(0.1 * x, top + 0.08, -0.36, -6, 0, 8 * x), Vector3.new(0.05, 0.2, 0.5))
			K:block("Head", "Crest", R.cf(0.1 * x, top + 0.18, -0.2, -14, 0, 8 * x), Vector3.new(0.05, 0.22, 0.34))
			K:spike("Head", "Crest", R.p(0.1 * x, top + 0.24, -0.06), R.v(0.1 * x, 0.6, 1), R.v(1, 0, 0), 0.22, 0.05)
			K:block("Head", "Back", R.cf(0.1 * x, top + 0.02, -0.7, -4, 0, 8 * x), Vector3.new(0.05, 0.12, 0.42))
		end
		-- the poison frill fanned round the neck: dark spines, purple membrane, lime eyespots
		local spines = {}
		local N = 9
		for i = 0, N - 1 do
			local a = rad(-110 + 220 * i / (N - 1))
			local dir = R.v(math.sin(a), math.cos(a) * 0.9, 0.6)
			local base = R.p(math.sin(a) * 0.2, 0.18 + math.cos(a) * 0.16, 0.1)
			local len = 0.72 + (math.cos(a) > 0.3 and 0.1 or 0)
			K:chain("Head", { "FrillSpine", "FrillSpine", "ThornTip" }, base, dir, R.v(0, 0, 1), { n = 3, len = len, w0 = 0.07, w1 = 0.045, bend = 8 })
			spines[i + 1] = { base = base, dir = dir, len = len }
		end
		for i = 1, N - 1 do
			local a, b = spines[i], spines[i + 1]
			for k, f in { 0.38, 0.72 } do
				local pa = a.base + a.dir * a.len * f
				local pb = b.base + b.dir * b.len * f
				local across = pb - pa
				local nrm = across:Cross(a.dir).Unit
				K:block("Head", (i + k) % 2 == 0 and "Frill" or "FrillDark", CFrame.fromMatrix((pa + pb) / 2, across.Unit, nrm), Vector3.new(across.Magnitude + 0.06, 0.035, a.len * 0.4))
				if k == 2 and i % 2 == 0 then
					K:block("Head", "Spot", CFrame.fromMatrix((pa + pb) / 2 + nrm * 0.03, across.Unit, nrm), Vector3.new(0.13, 0.04, 0.13))
				end
			end
		end
	end,
}
