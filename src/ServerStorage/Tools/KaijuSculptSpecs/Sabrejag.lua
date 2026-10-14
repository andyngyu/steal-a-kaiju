local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Epic / poison: a sabre-toothed jungle cat. A long, low, heavy-shouldered jaguar stalking with its
-- head down: thick forelegs, a deep chest, a lean waist, a long tail ending in a thorned club. Near-black hide with
-- glowing toxic rosettes (lime rings round purple centres) down the flanks, a ridge of thorns along the spine, thorned
-- armour on the shoulders. Face: a broad cat skull, a heavy scowling brow over slanted lime eyes, flattened ears, and
-- two huge sabre fangs dripping venom below the jaw.
local HEAD = CFrame.new(0, 1.66, -1.72) * CFrame.Angles(rad(-10), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.12)
local HS = 1.15

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 421,
	Vary = 0.05,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = "323A2A",
		HideDark = "20261A",
		HideLight = "4E5A40",
		Back = "14180F",
		Belly = "76805E",
		Belly2 = "646E4E",
		Ring = { "9DFF3A", Neon = true },
		RingCore = { "9A3CE0", Neon = true },
		Thorn = "2E1E3A",
		ThornTip = { "B04CFF", Neon = true },
		Armour = "3A2A48",
		ArmourLight = "54406A",
		Fang = "F0E8D0",
		Venom = { "9DFF3A", Neon = true },
		Tooth = "E8E0C8",
		Mouth = "3A1424",
		Eye = { "C6FF3A", Neon = true },
		Socket = "060806",
		Claw = "1A1418",
		ClawTip = "D8D0C0",
	},
	Joints = {
		Head = { 0, 1.76, -1.1 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.3, 0.34, 0.02)),
		EarR = hj(Vector3.new(-0.3, 0.34, 0.02)),
		LegFL = { 0.5, 1.62, -0.86 },
		LegFR = { -0.5, 1.62, -0.86 },
		LegBL = { 0.46, 1.56, 0.86 },
		LegBR = { -0.46, 1.56, 0.86 },
		Tail = { 0, 1.62, 1.1 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 32, band = 86, flank = 112, every = 3, bandKey = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.1, wide = 1.1 }
		-- heavy shoulders, deep chest, lean waist
		local body = K:tube("Body", {
			{ 0, 1.74, -1.02, rx = 0.56, ru = 0.62, rd = 0.68 },
			{ 0, 1.7, -0.36, rx = 0.6, ru = 0.56, rd = 0.62 },
			{ 0, 1.6, 0.36, rx = 0.46, ru = 0.42, rd = 0.38 },
			{ 0, 1.6, 0.98, rx = 0.48, ru = 0.46, rd = 0.42 },
		}, { step = 0.3, core = "Hide", coreScale = 0.85, tile = H.plates(0.36, nil, 0.1), belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 1.72, -1.6, rx = 0.36, ru = 0.36, rd = 0.4 },
			{ 0, 1.78, -1.32, rx = 0.46, ru = 0.46, rd = 0.5 },
			{ 0, 1.76, -1.0, rx = 0.54, ru = 0.56, rd = 0.6 },
		}, { step = 0.22, core = "Hide", coreScale = 0.9, tile = H.plates(0.32, nil, 0.1), color = skin })
		-- toxic rosettes down the flanks: a lime ring round a purple core
		local function rosette(g, smp, th, s)
			local pos, nrm = K:surface(smp, th, -0.035)
			local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
			for k = 0, 3 do
				local a = k * math.pi / 2
				K:block(g, "Ring", F * CFrame.new(math.cos(a) * s * 0.42, 0, math.sin(a) * s * 0.42) * CFrame.Angles(0, -a, 0), Vector3.new(s * 0.18, 0.035, s * 0.62))
			end
			K:block(g, "RingCore", F * CFrame.new(0, 0.005, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(s * 0.36, 0.035, s * 0.36))
		end
		local k = 0
		for s = 0.2, body.total - 0.15, 0.34 do
			local smp = K:at(body, s)
			for _, x in { 1, -1 } do
				rosette("Body", smp, rad(58 + (k % 2) * 30) * x, 0.36)
			end
			k += 1
		end
		-- thorns down the spine, thorned armour plates over the shoulders
		K:ridge("Body", body, { from = 0.1, to = body.total - 0.1, every = 0.22, height = function(u) return 0.3 - u * 0.12 end, thick = 0.08, key = "Thorn", tip = "ThornTip", lean = 42, sink = 0.9 })
		for _, x in { 1, -1 } do
			for i, o in { { 0.14, 54, 0.44 }, { 0.4, 66, 0.4 }, { 0.26, 80, 0.36 } } do
				local smp = K:at(body, o[1])
				K:tile("Body", i % 2 == 0 and "ArmourLight" or "Armour", smp, rad(o[2]) * x, o[3], o[3] * 0.9, 0.12, 14, 3, -0.3)
				local pos, nrm = K:surface(smp, rad(o[2]) * x, -0.1)
				K:spike("Body", "ThornTip", pos, (nrm + Vector3.yAxis * 0.4).Unit, smp.T, 0.16, 0.06)
			end
		end
		-- the long tail, a thorned club at its end
		local tail = K:tube("Tail", {
			{ 0, 1.62, 1.06, rx = 0.2, ru = 0.2 },
			{ 0, 1.5, 1.7, rx = 0.17, ru = 0.17 },
			{ 0.1, 1.16, 2.24, rx = 0.15, ru = 0.15 },
			{ 0.3, 0.86, 2.58, rx = 0.16, ru = 0.16 },
		}, { step = 0.22, core = "Hide", coreScale = 0.92, tile = H.plates(0.24, 5, 0.08), color = skin })
		local tip = K:at(tail, tail.total)
		K:block("Tail", "Armour", CFrame.fromMatrix(tip.p, tip.R, tip.U), Vector3.new(0.36, 0.34, 0.42))
		K:block("Tail", "ArmourLight", CFrame.fromMatrix(tip.p, tip.R, tip.U) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.3, 0.3, 0.36))
		for _, d in { Vector3.new(1, 0.3, 0), Vector3.new(-1, 0.3, 0), Vector3.new(0, 1, 0.2), Vector3.new(0, -0.6, 0.6), Vector3.new(0, 0.2, 1) } do
			local dir = CFrame.fromMatrix(Vector3.zero, tip.R, tip.U):VectorToWorldSpace(d.Unit)
			H.point(K, "Tail", "ThornTip", tip.p + dir * 0.36, dir, 0.12)
		end
		-- thick forelegs, long hind legs, big paws with hooked claws
		local function limb(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.5 * x, 1.64, -0.86, 0.36 },
				{ 0.56 * x, 0.96, -0.8, 0.26 },
				{ 0.54 * x, 0.32, -0.96, 0.2 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.28, 5, 0.09), nil }, color = limb, foot = { size = Vector3.new(0.42, 0.22, 0.46), key = "HideDark" }, toes = 4, claw = { len = 0.22, w = 0.06, curl = 40 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.46 * x, 1.6, 0.86, 0.38 },
				{ 0.5 * x, 1.06, 0.56, 0.28 },
				{ 0.5 * x, 0.56, 1.04, 0.18 },
				{ 0.5 * x, 0.2, 0.94, 0.15 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, tiles = { H.plates(0.3, 5, 0.09), nil, nil }, color = limb, foot = { size = Vector3.new(0.38, 0.2, 0.44), key = "HideDark" }, toes = 4, claw = { len = 0.2, w = 0.055, curl = 40 } })
		end

		-- head: a broad cat skull, scowling brow, slanted eyes, flattened ears, sabre fangs
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, HS, function()
			K:block("Head", "Hide", hcf(0, 0.1, -0.24), Vector3.new(0.74, 0.5, 0.58))
			K:block("Head", "Hide", hcf(0, 0.0, -0.62), Vector3.new(0.56, 0.36, 0.42))
			K:block("Head", "HideDark", hcf(0, -0.02, -0.88), Vector3.new(0.4, 0.28, 0.2))
			K:block("Head", "Back", hcf(0, 0.08, -0.98), Vector3.new(0.16, 0.1, 0.06))
			K:block("Head", "HideDark", hcf(0, 0.32, -0.3, -6, 0, 0), Vector3.new(0.5, 0.1, 0.46))
			K:block("Head", "Mouth", hcf(0, -0.18, -0.6), Vector3.new(0.42, 0.04, 0.42))
			for _, x in { 1, -1 } do
				-- cheek ruffs and a scowling brow
				K:block("Head", "HideLight", hcf(0.36 * x, -0.04, -0.24, 0, -14 * x, 10 * x), Vector3.new(0.16, 0.42, 0.46))
				K:block("Head", "Back", hcf(0.2 * x, 0.25, -0.54, -4, -16 * x, 24 * x), Vector3.new(0.26, 0.09, 0.2))
				H.eye(K, "Head", hcf(0.22 * x, 0.16, -0.58, 0, -24 * x, 20 * x), 0.16, 0.05)
				K:block("Head", "Socket", hcf(0.1 * x, 0.04, -0.98), Vector3.new(0.06, 0.05, 0.03))
				-- the sabre fangs reaching down past the chin, venom at their tips
				H.curve(K, "Head", { "Fang", "Fang", "Fang" }, { hp(0.17 * x, -0.16, -0.76), hp(0.19 * x, -0.42, -0.8), hp(0.18 * x, -0.66, -0.74) }, 0.1, 0.05, 0.1)
				K:block("Head", "Venom", CFrame.new(hp(0.18 * x, -0.76, -0.72)), Vector3.new(0.05, 0.08, 0.05))
				-- ears flattened back, thorn-tipped
				local g = x == 1 and "EarL" or "EarR"
				K:chain(g, { "HideDark", "Thorn" }, hp(0.3 * x, 0.34, 0.02), hv(0.7 * x, 0.4, 0.6), hv(0, 0, 1), { n = 2, len = 0.34, w0 = 0.2, w1 = 0.1, depth = 0.5, bend = 0 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-18), 0, 0)
			K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.36), Vector3.new(0.42, 0.16, 0.62))
			K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.16, -0.32), Vector3.new(0.34, 0.04, 0.5))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.38), Vector3.new(0.34, 0.04, 0.52))
			for _, x in { 1, -1 } do
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.16 * x, 0, -0.18), JAW * Vector3.new(0.14 * x, 0, -0.56), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.04)
			end
		end)
	end,
}
