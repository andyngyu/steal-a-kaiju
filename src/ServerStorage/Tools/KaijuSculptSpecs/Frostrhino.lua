local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Rare / ice: a glacier rhino, built like a woolly rhino. A massive barrel body rising to a shoulder
-- hump, the head carried low, short pillar legs. Its hide is armoured in great shields of glacier ice split by deep
-- folds (a shoulder shield, a saddle, a hip shield), ice crystals breaking out along the hump, a shaggy frost skirt.
-- Face: a long sloping head, a heavy ice brow plate over small cyan eyes, a hooked upper lip, a huge curved ice horn
-- on the nose with a second horn behind it, tubular ears.
local HEAD = CFrame.new(0, 1.6, -1.48) * CFrame.Angles(rad(-16), 0, 0)

return {
	Seed = 97,
	Vary = 0.05,
	Gait = "Trot",
	Emotes = { "Look", "Paw" },
	Palette = {
		Hide = "56657A",
		HideDark = "3C4859",
		HideLight = "7E8EA2",
		Back = "2A3442",
		Belly = "A9B5C1",
		Belly2 = "8E9BA8",
		Fur = "D2DCE6",
		FurDark = "A3B2C2",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Armour = { "B5DCF0", Material = "Ice" },
		ArmourLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "2B3542",
		ClawTip = "C9D7E4",
	},
	Joints = {
		Head = { 0, 1.74, -1.02 },
		EarL = HEAD * Vector3.new(0.32, 0.5, 0.02),
		EarR = HEAD * Vector3.new(-0.32, 0.5, 0.02),
		LegFL = { 0.6, 1.6, -0.62 },
		LegFR = { -0.6, 1.6, -0.62 },
		LegBL = { 0.6, 1.6, 0.94 },
		LegBR = { -0.6, 1.6, 0.94 },
		Tail = { 0, 1.98, 1.42 },
	},
	Parents = { EarL = "Head", EarR = "Head" },
	Build = function(K)
		local body = K:tube("Body", {
			{ 0, 1.98, -0.92, rx = 0.86, ru = 0.96, rd = 0.8 },
			{ 0, 2.04, -0.16, rx = 1.02, ru = 0.92, rd = 0.88 },
			{ 0, 1.92, 0.72, rx = 0.98, ru = 0.82, rd = 0.86 },
			{ 0, 1.82, 1.32, rx = 0.76, ru = 0.66, rd = 0.62 },
		}, { step = 0.36, core = "Hide", coreScale = 0.74, tile = H.plates(0.5, nil, 0.13), belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }, color = H.skin({ stripe = 36, band = 84, flank = 108, every = 3 }) })
		-- great shields of glacier ice: shoulder, saddle and hip, split by deep dark folds
		for _, sh in { { 0.28, 0.42 }, { 1.02, 0.36 }, { 1.72, 0.4 } } do
			local smp = K:at(body, sh[1])
			for k = -3, 3 do
				local th = rad(k * 28)
				K:tile("Body", (k % 2 == 0) and "Armour" or "ArmourLight", smp, th, 0.56, sh[2] * 2, 0.16, 6, 1, -0.6)
			end
			for _, sgn in { -1, 1 } do
				local edge = K:at(body, sh[1] + sgn * sh[2] * 1.06)
				for k = -3, 3 do
					K:tile("Body", "Back", edge, rad(k * 28), 0.58, 0.13, 0.12, 0, 0, -0.4)
				end
			end
		end
		-- a thick neck closing the front of the body, the head slung low off it
		K:tube("Body", {
			{ 0, 1.98, -0.62, rx = 0.82, ru = 0.88, rd = 0.78 },
			{ 0, 1.78, -1.14, rx = 0.62, ru = 0.62, rd = 0.6 },
		}, { step = 0.3, core = "Hide", coreScale = 0.8, tile = H.plates(0.5, nil, 0.13), color = H.skin({ stripe = 36, band = 84, flank = 108, every = 3 }) })
		H.crystalRidge(K, "Body", body, { from = 0.1, to = body.total * 0.42, every = 0.3, size = function(u) return 0.75 - u * 0.4 end, count = 4, keys = { "Ice", "IceDeep", "IceGlow", "Ice" }, lean = 30 })
		-- a shaggy frost skirt hanging off the flanks
		for s = 0.2, body.total - 0.2, 0.3 do
			local smp = K:at(body, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(116) * x, 0.05)
				K:chain("Body", { "Fur", "FurDark" }, pos, (nrm * 0.3 + Vector3.new(0, -1, 0)).Unit, smp.T, { n = 2, len = 0.56, w0 = 0.22, w1 = 0.14, bend = 0, tip = false, depth = 1.8 })
			end
		end
		K:tube("Tail", {
			{ 0, 1.98, 1.36, rx = 0.15, ru = 0.15 },
			{ 0, 1.7, 1.7, rx = 0.1, ru = 0.1 },
		}, { step = 0.2, core = "HideDark", coreScale = 0.95 })
		K:chain("Tail", { "Fur", "FurDark" }, Vector3.new(0, 1.66, 1.72), Vector3.new(0, -1, 0.3).Unit, Vector3.xAxis, { n = 2, len = 0.36, w0 = 0.16, w1 = 0.1, tip = false, depth = 1.4, bend = 0 })
		-- short pillar legs, ice greaves down the fronts of the forelegs
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.6 * x, 1.66, -0.62, 0.46 },
				{ 0.68 * x, 0.94, -0.66, 0.38 },
				{ 0.66 * x, 0.3, -0.64, 0.34 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.6, 0.26, 0.56), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.12, curl = 14 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.6 * x, 1.66, 0.94, 0.52 },
				{ 0.68 * x, 1.04, 0.76, 0.42 },
				{ 0.66 * x, 0.3, 0.94, 0.34 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.6, 0.26, 0.56), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.12, curl = 14 } })
			local g = x == 1 and "LegFL" or "LegFR"
			K:block(g, "Armour", CFrame.new(0.7 * x, 1.0, -1.06) * CFrame.Angles(rad(-4), rad(-8 * x), 0), Vector3.new(0.5, 0.86, 0.14))
			K:block(g, "ArmourLight", CFrame.new(0.7 * x, 1.42, -1.04) * CFrame.Angles(rad(-4), rad(-8 * x), 0), Vector3.new(0.54, 0.1, 0.18))
		end

		-- head: long and sloping, an ice brow plate over small eyes, a hooked lip, two ice horns, tubular ears
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.12, -0.26), Vector3.new(0.86, 0.74, 0.68))
		K:block("Head", "Hide", hcf(0, 0.0, -0.84), Vector3.new(0.7, 0.58, 0.62))
		K:block("Head", "Hide", hcf(0, 0.0, -0.84, 0, 0, 45), Vector3.new(0.5, 0.5, 0.6))
		K:block("Head", "HideDark", hcf(0, -0.08, -1.28), Vector3.new(0.62, 0.48, 0.34))
		K:block("Head", "HideDark", hcf(0, -0.08, -1.28, 0, 0, 45), Vector3.new(0.42, 0.42, 0.32))
		-- the hooked upper lip and the lower lip under it
		K:block("Head", "HideDark", hcf(0, -0.32, -1.44, 24, 0, 0), Vector3.new(0.34, 0.16, 0.16))
		K:block("Head", "Hide", hcf(0, -0.36, -1.1), Vector3.new(0.48, 0.16, 0.5))
		K:block("Head", "Mouth", hcf(0, -0.28, -1.12), Vector3.new(0.42, 0.04, 0.44))
		-- a heavy plate of ice over the brow, ridged down the middle
		K:block("Head", "Armour", hcf(0, 0.44, -0.5, -18, 0, 0), Vector3.new(0.78, 0.14, 0.56))
		K:block("Head", "ArmourLight", hcf(0, 0.36, -0.78, -18, 0, 0), Vector3.new(0.8, 0.1, 0.1))
		for _, x in { 1, -1 } do
			-- small eyes on the sides of the head under heavy lids
			K:block("Head", "Back", hcf(0.38 * x, 0.3, -0.68, -8, -20 * x, 18 * x), Vector3.new(0.24, 0.12, 0.3))
			H.eye(K, "Head", hcf(0.42 * x, 0.2, -0.7, 0, -50 * x, 14 * x), 0.18, 0.055)
			-- nostrils on the sides of the nose, a grim mouth line
			K:block("Head", "Socket", hcf(0.27 * x, -0.06, -1.38, 0, -30 * x, 0), Vector3.new(0.08, 0.1, 0.04))
			K:block("Head", "Socket", hcf(0.27 * x, -0.27, -0.98, 0, -6 * x, 0), Vector3.new(0.04, 0.05, 0.56))
			-- shield plates fanning up behind the skull
			K:block("Head", x == 1 and "Armour" or "ArmourLight", hcf(0.32 * x, 0.42, 0.06, 30, -20 * x, -24 * x), Vector3.new(0.44, 0.1, 0.5))
			-- tubular ears
			local g = x == 1 and "EarL" or "EarR"
			K:chain(g, { "HideDark", "Hide" }, hp(0.32 * x, 0.5, 0.02), hv(0.5 * x, 0.9, 0.3), hv(0, 0, 1), { n = 2, len = 0.3, w0 = 0.17, w1 = 0.11, depth = 0.9, bend = 0, tip = false })
		end
		K:block("Head", "ArmourLight", hcf(0, 0.54, 0.06, 32, 0, 0), Vector3.new(0.5, 0.1, 0.52))
		-- the horns: a huge front horn curving back over the face, a shorter one behind it, cores of glowing ice
		H.curve(K, "Head", { "Armour", "Ice", "IceDeep", "ArmourLight" }, { hp(0, 0.1, -1.24), hp(0, 0.62, -1.46), hp(0, 1.14, -1.4), hp(0, 1.56, -1.12) }, 0.46, 0.14, 0.2)
		H.curve(K, "Head", { "IceGlow" }, { hp(0, 0.3, -1.42), hp(0, 0.7, -1.6), hp(0, 1.04, -1.56) }, 0.1, 0.06, 0.24)
		H.curve(K, "Head", { "Armour", "Ice", "ArmourLight" }, { hp(0, 0.3, -0.74), hp(0, 0.66, -0.82), hp(0, 0.9, -0.66) }, 0.3, 0.1, 0.2)
	end,
}
