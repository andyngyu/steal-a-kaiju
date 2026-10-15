local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Legendary / storm: the voltkirin, a dragon-headed kirin. A tall, proud stag-like body on long slender
-- legs, covered in indigo scales banded with gold across the back, a gold-scaled belly. A white mane streams back like
-- flame down the neck and spine, its tips flickering electric blue; tufts of the same at the fetlocks; it walks on
-- gold hooves wrapped in little storm clouds. A long tail ending in a streaming tuft. Head: an eastern dragon's, a gold
-- brow over yellow eyes, long whiskers trailing from the snout, a cloud beard, and antlers of lightning branching up
-- from gold burrs on the skull.
local HEAD = CFrame.new(0, 3.36, -1.62) * CFrame.Angles(rad(-12), 0, 0)
local SKULL = { 0.56, 0.44, 0.52 }

return {
	Seed = 641,
	Vary = 0.04,
	Scale = 1.3,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = { "2E2A60", Material = "Slate" },
		HideDark = { "1C1A3E", Material = "Slate" },
		HideLight = { "4A4688", Material = "Slate" },
		Back = { "121028", Material = "Slate" },
		Belly = "E8D8A0",
		Belly2 = "D4C080",
		Gold = "E0B040",
		GoldDark = "A07A20",
		GoldLight = "F4D474",
		Mane = "EEF0F6",
		ManeLight = "C8D0E0",
		Cloud = "DCE2EC",
		CloudLight = "F4F6FA",
		CloudDark = "A8B2C4",
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Tooth = "F0ECDC",
		Mouth = "4A1A3A",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0C10",
		Claw = "A07A20",
		ClawTip = "E0B040",
	},
	Joints = {
		Head = { 0, 2.34, -0.86 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegFL = { 0.36, 2.16, -0.82 },
		LegFR = { -0.36, 2.16, -0.82 },
		LegBL = { 0.36, 2.12, 0.8 },
		LegBR = { -0.36, 2.12, 0.8 },
		Tail = { 0, 2.16, 1.0 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 26, band = 72, flank = 104, every = 3, bandKey = "Gold", upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.09, wide = 1.1 }
		local scales = { w = 0.3, t = 0.09, lift = 7, jitter = 1, sink = 0.5, overlap = 1.12 }
		local body = K:tube("Body", {
			{ 0, 2.22, -0.88, rx = 0.5, ru = 0.52, rd = 0.56 },
			{ 0, 2.22, -0.26, rx = 0.54, ru = 0.52, rd = 0.56 },
			{ 0, 2.16, 0.36, rx = 0.5, ru = 0.48, rd = 0.5 },
			{ 0, 2.14, 0.88, rx = 0.44, ru = 0.42, rd = 0.42 },
		}, { step = 0.26, core = "HideDark", coreScale = 0.86, tile = scales, belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 3.32, -1.56, rx = 0.26, ru = 0.26, rd = 0.28 },
			{ 0, 3.02, -1.4, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 2.66, -1.14, rx = 0.38, ru = 0.38, rd = 0.42 },
			{ 0, 2.32, -0.82, rx = 0.48, ru = 0.48, rd = 0.52 },
		}, { step = 0.2, core = "HideDark", coreScale = 0.86, tile = { w = 0.26, t = 0.08, lift = 7, jitter = 1, sink = 0.5, overlap = 1.12 }, belly = belly, color = skin })
		-- the flame mane: white locks streaming back off the neck and spine, flickering blue at the tips
		local function mane(g, smps, from, to, every, len)
			for s = from, to, every do
				local smp = K:at(smps, s)
				for _, th in { 0, rad(24), rad(-24) } do
					local pos, nrm = K:surface(smp, th, 0.02)
					local l = (th == 0 and len or len * 0.7) * K:rand(0.85, 1.15)
					local d = (nrm * 1.1 + smp.T * 0.8 + Vector3.yAxis * 0.35).Unit
					K:chain(g, { "ManeLight", "Mane", "Mane", "Arc" }, pos, d, smp.R, { n = 4, len = l, w0 = 0.2, w1 = 0.1, bend = K:rand(-18, -4), depth = 0.5 })
				end
			end
		end
		mane("Head", neck, 0.06, neck.total - 0.04, 0.13, 0.86)
		mane("Body", body, 0.06, body.total * 0.75, 0.2, 0.62)

		-- the long tail and its streaming tuft
		local tail = K:tube("Tail", {
			{ 0, 2.18, 0.96, rx = 0.16, ru = 0.16 },
			{ 0, 2.0, 1.56, rx = 0.13, ru = 0.13 },
			{ 0.08, 1.6, 2.0, rx = 0.11, ru = 0.11 },
			{ 0.14, 1.3, 2.26, rx = 0.09, ru = 0.09 },
		}, { step = 0.2, core = "HideDark", coreScale = 0.95, tile = { w = 0.2, n = 5, t = 0.07, lift = 6, jitter = 1, sink = 0.5, overlap = 1.12 }, color = function(_, ring)
			return ring % 3 == 0 and "Gold" or "Hide"
		end })
		local tip = K:at(tail, tail.total)
		for k = 0, 6 do
			local a = rad(k * 51)
			local d = (tip.T * 1.2 + tip.R * math.cos(a) * 0.5 + tip.U * math.sin(a) * 0.5).Unit
			K:chain("Tail", { "ManeLight", "Mane", "Arc" }, tip.p - tip.T * 0.1, d, tip.R, { n = 3, len = 0.6, w0 = 0.15, w1 = 0.08, bend = 8, depth = 0.6 })
		end

		-- long slender legs, gold scutes down the shins, gold hooves wrapped in little storm clouds
		for _, x in { 1, -1 } do
			local fl, bl = x == 1 and "LegFL" or "LegFR", x == 1 and "LegBL" or "LegBR"
			local f = H.quadLeg(K, fl, {
				{ 0.36 * x, 2.18, -0.82, 0.26 },
				{ 0.4 * x, 1.36, -0.76, 0.17 },
				{ 0.38 * x, 0.34, -0.86, 0.12 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, tiles = { scales, nil }, color = skin, foot = { size = Vector3.new(0.28, 0.24, 0.32), key = "Gold" }, toes = 2, claw = { len = 0.08, w = 0.13, curl = 0 } })
			local b = H.quadLeg(K, bl, {
				{ 0.36 * x, 2.14, 0.8, 0.32 },
				{ 0.4 * x, 1.5, 0.56, 0.22 },
				{ 0.4 * x, 0.8, 0.98, 0.14 },
				{ 0.4 * x, 0.32, 0.9, 0.12 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, tiles = { scales, nil, nil }, color = skin, foot = { size = Vector3.new(0.28, 0.24, 0.32), key = "Gold" }, toes = 2, claw = { len = 0.08, w = 0.13, curl = 0 } })
			for _, leg in { { fl, Vector3.new(0.38 * x, 0.2, -0.82), Vector3.new(0.38 * x, 0.5, -0.8) }, { bl, Vector3.new(0.4 * x, 0.2, 0.86), Vector3.new(0.4 * x, 0.5, 0.92) } } do
				H.cloud(K, leg[1], { "Cloud", "CloudLight", "CloudDark" }, leg[2], Vector3.new(0.26, 0.12, 0.26), 7)
				-- a fetlock tuft streaming back
				K:chain(leg[1], { "Mane", "ManeLight", "Arc" }, leg[3], Vector3.new(0.1 * x, 0.2, 1).Unit, Vector3.xAxis, { n = 3, len = 0.42, w0 = 0.12, w1 = 0.07, bend = -10, depth = 0.6 })
			end
			for k = 0, 3 do
				K:block(fl, k % 2 == 0 and "Gold" or "GoldDark", CFrame.new(0.385 * x, 0.56 + k * 0.2, -0.95 + k * 0.006) * CFrame.Angles(rad(-4), 0, 0), Vector3.new(0.2, 0.1, 0.06))
			end
		end

		-- head: an eastern dragon's, gold brow, whiskers, a cloud beard and antlers of lightning
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.44, 0.34, 0.5 },
			tip = { 0.38, 0.3, 0.26 },
			open = 18,
			teeth = { 0.08, 0.05 },
			brow = "Gold",
			browSize = { 0.26, 0.13, 0.34 },
			eye = { 0.14, 0.05 },
			cheek = 0.2,
		})
		for _, x in { 1, -1 } do
			-- whiskers trailing back from the snout
			K:chain("Head", { "GoldLight", "Mane", "Mane", "Arc" }, R.p(0.2 * x, 0.08, R.zEnd + 0.2), R.v(0.55 * x, -0.3, 0.8), R.v(0, 1, 0), { n = 4, len = 1.2, w0 = 0.07, w1 = 0.045, bend = -12 * x, tip = false })
			-- gold scales over the cheeks, a gold crest line over the skull
			K:block("Head", "GoldDark", R.cf(0.28 * x, 0.12, -0.26, 0, -12 * x, 0), Vector3.new(0.08, 0.24, 0.36))
			-- gold burrs on the skull, and the lightning antlers branching up from them
			local burr = R.p(0.15 * x, R.top + 0.02, -0.16)
			K:chain("Head", { "GoldDark", "Gold" }, burr, R.v(0.35 * x, 1, 0.35), R.v(0, 0, 1), { n = 2, len = 0.24, w0 = 0.15, w1 = 0.1, bend = 0, tip = false })
			local a0 = burr + R.v(0.35 * x, 1, 0.35) * 0.22
			local a1 = a0 + R.v(0.45 * x, 1, 0.55) * 0.62
			local a2 = a1 + R.v(0.3 * x, 0.8, 0.9) * 0.5
			H.bolt(K, "Head", "Spark", a0, a1, R.v(0, 0, 1), 3, 0.07, 0.07)
			H.bolt(K, "Head", "Spark", a1, a2, R.v(0, 0, 1), 3, 0.06, 0.06)
			H.bolt(K, "Head", "Spark", a0:Lerp(a1, 0.5), a0:Lerp(a1, 0.5) + R.v(0.7 * x, 0.6, -0.4) * 0.34, R.v(0, 1, 0), 2, 0.05, 0.04)
			H.bolt(K, "Head", "Arc", a1, a1 + R.v(0.6 * x, 0.7, -0.2) * 0.36, R.v(0, 1, 0), 2, 0.05, 0.04)
			H.bolt(K, "Head", "Spark", a1:Lerp(a2, 0.55), a1:Lerp(a2, 0.55) + R.v(0.2 * x, 1, -0.1) * 0.3, R.v(0, 0, 1), 2, 0.045, 0.04)
		end
		K:block("Head", "Gold", R.cf(0, R.top + 0.02, -0.3, -8, 0, 0), Vector3.new(0.1, 0.06, 0.44))
		H.cloud(K, "Jaw", { "Cloud", "CloudLight" }, R.JAW * Vector3.new(0, -0.18, -0.36), Vector3.new(0.14, 0.1, 0.18), 5)
	end,
}
