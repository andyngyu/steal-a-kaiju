local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Epic / poison: a sabre-toothed jungle cat. A long, low, heavy-shouldered jaguar stalking with its
-- head down: thick forelegs, a deep chest, a long lean waist, a long tail ending in a thorned club. Jungle-green hide
-- shading from a near-black back to a pale belly, irregular dark rosettes down the flanks each with a faint lime glow
-- at its heart, a ridge of purple thorns along the spine, bold purple thorn armour on the shoulders. Face: a big
-- domed cat skull with flared cheekbones, a heavy scowling brow over small lime eyes, a broad muzzle with whisker pads
-- and a dark nose, flattened ears, a heavy jaw on a visible hinge, and two huge sabre fangs rooted in the muzzle
-- reaching below the chin, dripping lime venom.
local HEAD = CFrame.new(0, 1.66, -1.72) * CFrame.Angles(rad(-10), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.12)
local HS = 1.3

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 421,
	Vary = 0.05,
	Scale = 1.22,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = { "3E6A34", Material = "Slate" },
		HideDark = { "2A4A26", Material = "Slate" },
		HideLight = { "6E9652", Material = "Slate" },
		Back = { "18281A", Material = "Slate" },
		Belly = "CCC89A",
		Belly2 = "B4B082",
		Spot = { "142014", Material = "Slate" },
		SpotCore = { "2C4A26", Material = "Slate" },
		SpotGlow = { "48B828", Neon = true },
		SeamLip = { "142014", Material = "Slate" },
		Thorn = "6A2AA8",
		ThornTip = { "B04CFF", Neon = true },
		Armour = "5A2A8A",
		ArmourLight = "7A3AB8",
		Fang = "F0E8D0",
		Venom = { "58D22E", Neon = true },
		Tooth = "E8E0C8",
		Mouth = "3A1424",
		Eye = { "6FE83A", Neon = true },
		Socket = "060806",
		Claw = "1A1418",
		ClawTip = "D8D0C0",
		Nose = "141010",
		Muzzle = { "8AA868", Material = "Slate" },
	},
	Joints = {
		Head = { 0, 1.76, -1.1 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.3, 0.34, 0.02)),
		EarR = hj(Vector3.new(-0.3, 0.34, 0.02)),
		LegFL = { 0.5, 1.62, -0.86 },
		LegFR = { -0.5, 1.62, -0.86 },
		LegBL = { 0.46, 1.56, 1.36 },
		LegBR = { -0.46, 1.56, 1.36 },
		Tail = { 0, 1.62, 1.6 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 64, flank = 104, every = 3, bandKey = "Back", upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.1, wide = 1.1 }
		-- heavy shoulders, deep chest, a long lean waist stretched out low like a stalking big cat
		local body = K:tube("Body", {
			{ 0, 1.76, -1.02, rx = 0.7, ru = 0.7, rd = 0.76 },
			{ 0, 1.72, -0.36, rx = 0.74, ru = 0.64, rd = 0.7 },
			{ 0, 1.64, 0.5, rx = 0.6, ru = 0.52, rd = 0.48 },
			{ 0, 1.62, 1.48, rx = 0.62, ru = 0.56, rd = 0.52 },
		}, { step = 0.3, core = "HideDark", coreScale = 0.85, tile = { w = 0.44, l = 0.32, t = 0.11, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 }, belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 1.72, -1.6, rx = 0.42, ru = 0.42, rd = 0.46 },
			{ 0, 1.78, -1.32, rx = 0.54, ru = 0.54, rd = 0.58 },
			{ 0, 1.76, -1.0, rx = 0.64, ru = 0.66, rd = 0.7 },
		}, { step = 0.22, core = "Hide", coreScale = 0.9, tile = H.plates(0.32, nil, 0.1), color = skin })
		-- jaguar rosettes: a broken ring of irregular dark spots round a darker heart with a faint lime glow, scattered
		-- unevenly down the flanks
		local function rosette(g, smp, th, s)
			local pos, nrm = K:surface(smp, th, -0.045)
			local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
			local n = K:rand(0, 1) < 0.5 and 3 or 4
			local a0 = K:rand(0, 6.28)
			for k = 0, n - 1 do
				local a = a0 + k * math.pi * 2 / n + K:rand(-0.3, 0.3)
				local r = s * K:rand(0.34, 0.46)
				K:block(g, "Spot", F * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, -a + K:rand(-0.4, 0.4), 0), Vector3.new(s * K:rand(0.16, 0.24), 0.04, s * K:rand(0.32, 0.5)))
			end
			K:block(g, "SpotCore", F * CFrame.Angles(0, K:rand(0, 1.5), 0), Vector3.new(s * 0.36, 0.03, s * 0.3))
			K:block(g, "SpotGlow", F * CFrame.new(0, 0.012, 0) * CFrame.Angles(0, K:rand(0, 1.5), 0), Vector3.new(s * 0.12, 0.03, s * 0.1))
		end
		local k = 0
		for s = 0.24, body.total - 0.2, 0.42 do
			for _, x in { 1, -1 } do
				rosette("Body", K:at(body, s + K:rand(-0.08, 0.08)), rad((k % 2 == 0 and 62 or 92) + K:rand(-10, 10)) * x, 0.62 * K:rand(0.85, 1.15))
			end
			k += 1
		end
		-- a few lone spots between them
		for s = 0.5, body.total - 0.3, 0.62 do
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(K:at(body, s), rad(K:rand(40, 110)) * x, -0.045)
				K:block("Body", "Spot", CFrame.fromMatrix(pos, nrm:Cross(Vector3.zAxis).Unit, nrm) * CFrame.Angles(0, K:rand(0, 3), 0), Vector3.new(0.1, 0.04, 0.14))
			end
		end
		-- thorns down the spine, thorned armour plates over the shoulders
		K:ridge("Body", body, { from = 0.1, to = body.total - 0.1, every = 0.24, height = function(u) return 0.42 - u * 0.16 end, thick = 0.11, key = "Thorn", tip = "ThornTip", lean = 40, sink = 0.9 })
		for _, x in { 1, -1 } do
			H.vein(K, "Head", "Venom", neck, rad(72) * x, 0.06, neck.total - 0.06, { width = 0.05, height = 0.09, lift = 0.04, wander = 12, lip = "SeamLip", lipW = 0.05 })
		end
		for _, x in { 1, -1 } do
			for i, o in { { 0.14, 54, 0.52 }, { 0.4, 66, 0.48 }, { 0.26, 80, 0.44 } } do
				local smp = K:at(body, o[1])
				K:tile("Body", i % 2 == 0 and "ArmourLight" or "Armour", smp, rad(o[2]) * x, o[3], o[3] * 0.9, 0.13, 14, 3, -0.3)
				local pos, nrm = K:surface(smp, rad(o[2]) * x, -0.1)
				K:chain("Body", { "Thorn", "ThornTip" }, pos, (nrm + Vector3.yAxis * 0.4).Unit, smp.T, { n = 2, len = 0.32, w0 = 0.1, w1 = 0.06, bend = -14 })
			end
		end
		-- the long tail, a thorned club at its end
		local tail = K:tube("Tail", {
			{ 0, 1.62, 1.56, rx = 0.22, ru = 0.22 },
			{ 0, 1.5, 2.2, rx = 0.18, ru = 0.18 },
			{ 0.1, 1.16, 2.74, rx = 0.16, ru = 0.16 },
			{ 0.3, 0.86, 3.08, rx = 0.17, ru = 0.17 },
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
				{ 0.52 * x, 1.66, -0.86, 0.44 },
				{ 0.6 * x, 0.96, -0.8, 0.32 },
				{ 0.58 * x, 0.32, -0.96, 0.24 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.32, 5, 0.1), nil }, color = limb, foot = { size = Vector3.new(0.5, 0.24, 0.54), key = "HideDark" }, toes = 4, claw = { len = 0.26, w = 0.07, curl = 40 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.5 * x, 1.62, 1.36, 0.48 },
				{ 0.56 * x, 1.06, 1.06, 0.36 },
				{ 0.56 * x, 0.56, 1.54, 0.23 },
				{ 0.56 * x, 0.2, 1.44, 0.19 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, tiles = { H.plates(0.34, 5, 0.1), nil, nil }, color = limb, foot = { size = Vector3.new(0.46, 0.22, 0.52), key = "HideDark" }, toes = 4, claw = { len = 0.24, w = 0.065, curl = 40 } })
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
			-- a domed cranium, rounded by a turned block, sloping down into a broad muzzle
			K:block("Head", "Hide", hcf(0, 0.14, -0.22), Vector3.new(0.86, 0.56, 0.64))
			K:block("Head", "Hide", hcf(0, 0.16, -0.24, 0, 0, 45), Vector3.new(0.6, 0.6, 0.58))
			K:block("Head", "HideDark", hcf(0, 0.42, -0.34, -18, 0, 0), Vector3.new(0.6, 0.12, 0.5))
			K:block("Head", "Hide", hcf(0, -0.04, -0.66), Vector3.new(0.66, 0.4, 0.46))
			K:block("Head", "HideDark", hcf(0, 0.14, -0.66, -10, 0, 0), Vector3.new(0.3, 0.16, 0.5))
			K:block("Head", "Nose", hcf(0, 0.08, -0.92, -10, 0, 0), Vector3.new(0.24, 0.12, 0.1))
			K:block("Head", "Mouth", hcf(0, -0.22, -0.6), Vector3.new(0.5, 0.04, 0.5))
			-- a heavy scowling brow bar across the face
			K:block("Head", "HideDark", hcf(0, 0.33, -0.53, -6, 0, 0), Vector3.new(0.72, 0.12, 0.16))
			for _, x in { 1, -1 } do
				K:block("Head", "Back", hcf(0.2 * x, 0.35, -0.52, -6, -10 * x, 18 * x), Vector3.new(0.38, 0.16, 0.32))
				H.eye(K, "Head", hcf(0.24 * x, 0.2, -0.58, 0, -24 * x, 18 * x), 0.14, 0.045)
				-- whisker pads bulging either side of the muzzle, the sabres rooted under them
				K:block("Head", "Muzzle", hcf(0.17 * x, -0.1, -0.78), Vector3.new(0.3, 0.3, 0.34))
				K:block("Head", "Muzzle", hcf(0.17 * x, -0.1, -0.78, 0, 0, 45), Vector3.new(0.24, 0.24, 0.3))
				K:block("Head", "HideDark", hcf(0.17 * x, -0.2, -0.74), Vector3.new(0.16, 0.12, 0.18))
				-- flared cheekbones and the heavy jaw muscle down to a visible hinge knob
				K:block("Head", "HideLight", hcf(0.44 * x, 0.02, -0.3, 0, -16 * x, 8 * x), Vector3.new(0.18, 0.36, 0.48))
				K:block("Head", "Hide", hcf(0.4 * x, -0.16, -0.18, 0, -8 * x, 0), Vector3.new(0.2, 0.34, 0.36))
				K:block("Head", "HideDark", hcf(0.42 * x, -0.16, -0.1, 45, 0, 0), Vector3.new(0.16, 0.18, 0.18))
				-- the sabre fangs reaching down past the chin, venom at their tips
				H.curve(K, "Head", { "Fang", "Fang", "Fang", "Fang" }, { hp(0.17 * x, -0.18, -0.76), hp(0.2 * x, -0.5, -0.84), hp(0.2 * x, -0.88, -0.8), hp(0.17 * x, -1.16, -0.66) }, 0.16, 0.05, 0.1)
				K:block("Head", "Venom", CFrame.new(hp(0.17 * x, -1.26, -0.62)), Vector3.new(0.06, 0.14, 0.06))
				K:block("Head", "Venom", CFrame.new(hp(0.2 * x, -0.72, -0.88)), Vector3.new(0.03, 0.2, 0.03))
				-- ears flattened back, thorn-tipped
				local g = x == 1 and "EarL" or "EarR"
				K:chain(g, { "HideDark", "Thorn" }, hp(0.3 * x, 0.34, 0.02), hv(0.7 * x, 0.4, 0.6), hv(0, 0, 1), { n = 2, len = 0.34, w0 = 0.2, w1 = 0.1, depth = 0.5, bend = 0 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-18), 0, 0)
			-- a heavy lower jaw: a broad chin, sides running back to the hinge
			K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.38), Vector3.new(0.52, 0.18, 0.66))
			K:block("Jaw", "HideDark", JAW * CFrame.new(0, -0.12, -0.7), Vector3.new(0.42, 0.22, 0.18))
			for _, x in { 1, -1 } do
				K:block("Jaw", "Hide", JAW * CFrame.new(0.27 * x, -0.06, -0.24), Vector3.new(0.1, 0.22, 0.6))
			end
			K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.18, -0.36), Vector3.new(0.42, 0.04, 0.56))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.4), Vector3.new(0.42, 0.04, 0.56))
			for _, x in { 1, -1 } do
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.16 * x, 0, -0.18), JAW * Vector3.new(0.14 * x, 0, -0.56), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.04)
			end
		end)
	end,
}
