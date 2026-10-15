local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Common / storm: the sparkit, a static-charged weasel-lizard. A long, low, quick body on four short
-- legs, bristling with amber fur that stands on end down the back and neck, yellow-white sparks crackling between the
-- tufts. Charcoal stripe down the spine, slate scales on the legs, belly and face. The tail is a lightning bolt:
-- kinked charcoal segments edged in yellow-white, ending in a glowing bolt blade. Face: a narrow scaly snout, swept-back
-- bristling ears, a heavy brow over yellow eyes, needle teeth and two long fangs sparking at the tips, an arc of
-- electric blue between them, and static whiskers crackling off the muzzle.
local HEAD = CFrame.new(0, 1.44, -1.36) * CFrame.Angles(rad(-8), 0, 0)
local SKULL = { 0.58, 0.4, 0.5 }
local TAIL = {
	Vector3.new(0, 1.16, 0.9),
	Vector3.new(0, 1.74, 1.34),
	Vector3.new(0, 1.4, 1.7),
	Vector3.new(0, 2.1, 2.08),
	Vector3.new(0, 1.82, 2.4),
	Vector3.new(0, 2.64, 2.78),
}

return {
	Seed = 601,
	Vary = 0.05,
	Scale = 1.05,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = { "4A5262", Material = "Slate" },
		HideDark = { "2C323E", Material = "Slate" },
		HideLight = { "7A8496", Material = "Slate" },
		Back = { "1C2028", Material = "Slate" },
		Belly = "C8CCD4",
		Belly2 = "B0B6C0",
		Fur = "D88A24",
		FurDark = "9A5A16",
		FurLight = "F0B448",
		FurTip = "FFE2A0",
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Bolt = { "2A2E38", Material = "Slate" },
		Tooth = "EDE8DA",
		Mouth = "3A1A2A",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0C10",
		Claw = "1A1C22",
		ClawTip = "D8D4C8",
	},
	Joints = {
		Head = { 0, 1.32, -0.94 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		EarL = HEAD * Vector3.new(0.2, 0.44, -0.14),
		EarR = HEAD * Vector3.new(-0.2, 0.44, -0.14),
		LegFL = { 0.36, 1.12, -0.68 },
		LegFR = { -0.36, 1.12, -0.68 },
		LegBL = { 0.34, 1.08, 0.64 },
		LegBR = { -0.34, 1.08, 0.64 },
		Tail = { 0, 1.16, 0.9 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		-- amber fur over the back and flanks, a charcoal stripe down the spine, slate fur low on the flanks
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 18 then
				return "Back"
			elseif a < 96 then
				return ring % 3 == 0 and "FurDark" or (ring % 2 == 0 and "FurLight" or "Fur")
			elseif a < 120 then
				return "Hide"
			end
			return "HideLight"
		end
		local belly = { key = "Belly", key2 = "Belly2", arc = 34, t = 0.08, wide = 1.05 }
		-- a long, low, quick weasel body
		local body = K:tube("Body", {
			{ 0, 1.2, -0.92, rx = 0.36, ru = 0.36, rd = 0.38 },
			{ 0, 1.24, -0.36, rx = 0.42, ru = 0.42, rd = 0.42 },
			{ 0, 1.2, 0.3, rx = 0.4, ru = 0.4, rd = 0.38 },
			{ 0, 1.14, 0.88, rx = 0.34, ru = 0.34, rd = 0.32 },
		}, { step = 0.24, core = "HideDark", coreScale = 0.86, tile = H.fur(0.28, nil, 0.34, 22), belly = belly, color = fur })
		local neck = K:tube("Head", {
			{ 0, 1.44, -1.38, rx = 0.24, ru = 0.24, rd = 0.26 },
			{ 0, 1.4, -1.14, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 1.3, -0.86, rx = 0.36, ru = 0.36, rd = 0.38 },
		}, { step = 0.2, core = "HideDark", coreScale = 0.86, tile = H.fur(0.26, nil, 0.3, 26), belly = belly, color = fur })
		-- the fur stands on end down the spine in bristling tufts, sparks jumping between their tips
		local tips = {}
		for _, seg in { { "Head", neck, 0.08, 0.2 }, { "Body", body, 0.06, 0.22 } } do
			local g, smps, from, every = seg[1], seg[2], seg[3], seg[4]
			for s = from, smps.total - 0.08, every do
				local smp = K:at(smps, s)
				for _, th in { 0, rad(46), rad(-46) } do
					local pos, nrm = K:surface(smp, th + rad(K:rand(-6, 6)), 0.03)
					local len = (th == 0 and 0.46 or 0.3) * K:rand(0.85, 1.1)
					local d = (nrm + smp.T * 0.75).Unit
					K:chain(g, { "FurDark", "Fur", "FurTip" }, pos, d, smp.R, { n = 3, len = len, w0 = 0.13, w1 = 0.07, bend = 10, depth = 0.6 })
					if th == 0 then
						table.insert(tips, { g = g, p = pos + d * len * 0.95, R = smp.R })
					end
				end
			end
		end
		for i = 1, #tips - 1, 2 do
			local a, b = tips[i], tips[i + 1]
			if a.g == b.g then
				H.bolt(K, a.g, "Spark", a.p, b.p, a.R, 3, 0.035, 0.06)
			end
		end
		-- static streaks of electric blue down the lower flanks
		for _, x in { 1, -1 } do
			H.cracks(K, "Body", "Arc", body, { rad(98) * x }, 0.2, body.total - 0.2, 0.22, 0.04, 0.06)
		end

		-- the lightning-bolt tail: kinked charcoal boards edged in yellow-white, a glowing blade at the end
		K:tube("Tail", {
			{ 0, 1.16, 0.84, rx = 0.24, ru = 0.24, rd = 0.22 },
			{ 0, 1.3, 1.08, rx = 0.17, ru = 0.17, rd = 0.16 },
		}, { step = 0.12, core = "HideDark", coreScale = 0.9, tile = H.fur(0.22, 6, 0.24, 30), color = fur })
		for i = 1, #TAIL - 1 do
			local a, b = TAIL[i], TAIL[i + 1]
			local along = (b - a).Unit
			local perp = along:Cross(Vector3.xAxis).Unit
			local f = (i - 1) / (#TAIL - 2)
			local h = 0.32 - f * 0.12
			local len = (b - a).Magnitude + h * 0.5
			local mid = (a + b) / 2
			K:block("Tail", "Bolt", CFrame.fromMatrix(mid, Vector3.xAxis, perp), Vector3.new(0.16, h, len))
			K:block("Tail", "Spark", CFrame.fromMatrix(mid + perp * (h / 2 - 0.02), Vector3.xAxis, perp), Vector3.new(0.18, 0.06, len))
			K:block("Tail", "Arc", CFrame.fromMatrix(mid - perp * (h / 2 - 0.02), Vector3.xAxis, perp), Vector3.new(0.17, 0.04, len * 0.8))
		end
		local last = (TAIL[#TAIL] - TAIL[#TAIL - 1]).Unit
		K:chain("Tail", { "Spark", "Spark" }, TAIL[#TAIL] - last * 0.1, last, Vector3.xAxis, { n = 2, len = 0.5, w0 = 0.2, w1 = 0.12, bend = 0, depth = 0.8 })

		-- four short quick legs, slate below the fur
		local function legFur(th, ring)
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.36 * x, 1.14, -0.68, 0.24 },
				{ 0.42 * x, 0.66, -0.6, 0.17 },
				{ 0.4 * x, 0.22, -0.74, 0.12 },
			}, { step = 0.2, cores = { "HideDark", "Hide" }, tiles = { H.fur(0.16, 6, 0.2, 20), nil }, color = legFur, foot = { size = Vector3.new(0.3, 0.16, 0.36), key = "HideDark" }, toes = 4, claw = { len = 0.18, w = 0.05, curl = 34 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.34 * x, 1.1, 0.64, 0.28 },
				{ 0.4 * x, 0.74, 0.44, 0.2 },
				{ 0.4 * x, 0.4, 0.8, 0.14 },
				{ 0.4 * x, 0.16, 0.72, 0.11 },
			}, { step = 0.2, cores = { "HideDark", "Hide", "Hide" }, tiles = { H.fur(0.17, 6, 0.22, 20), nil, nil }, color = legFur, foot = { size = Vector3.new(0.3, 0.16, 0.38), key = "HideDark" }, toes = 4, claw = { len = 0.18, w = 0.05, curl = 34 } })
		end

		-- head: a narrow scaly snout, needle teeth, two long sparking fangs
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.42, 0.3, 0.42 },
			tip = { 0.3, 0.22, 0.24 },
			open = 26,
			teeth = { 0.07, 0.04 },
			brow = "Back",
			browSize = { 0.26, 0.12, 0.3 },
			eye = { 0.12, 0.04 },
			cheek = 0.18,
		})
		local fangTips = {}
		for _, x in { 1, -1 } do
			local base = R.p(0.12 * x, -0.02, R.zEnd + 0.2)
			K:chain("Head", { "Tooth", "Tooth", "Spark" }, base, R.v(0, -1, -0.12), R.v(1, 0, 0), { n = 3, len = 0.28, w0 = 0.06, w1 = 0.04, bend = 0 })
			fangTips[x] = base + R.v(0, -1, -0.12) * 0.28
			-- static whiskers crackling off the muzzle
			for k = 0, 1 do
				local p0 = R.p(0.15 * x, 0.06 - k * 0.07, R.zEnd + 0.3)
				H.bolt(K, "Head", k == 0 and "Spark" or "Arc", p0, p0 + R.v(0.9 * x, 0.15 - k * 0.3, 0.45) * 0.5, R.v(0, 1, 0), 3, 0.03, 0.05)
			end
			-- a fur ruff swept back off the cheeks, a bristling crest over the skull
			for k = 0, 2 do
				K:chain("Head", { "FurDark", "Fur", "FurTip" }, R.p(0.3 * x, 0.12 - k * 0.1, -0.12 + k * 0.04), R.v(0.75 * x, 0.15 - k * 0.2, 0.8), R.v(0, 1, 0), { n = 3, len = 0.32 - k * 0.04, w0 = 0.12, w1 = 0.06, bend = 0, depth = 0.6 })
			end
			local g = x == 1 and "EarL" or "EarR"
			K:chain(g, { "HideDark", "FurDark", "FurTip" }, R.p(0.2 * x, R.top - 0.04, -0.14), R.v(0.55 * x, 0.6, 0.9), R.v(0, 0, 1), { n = 3, len = 0.42, w0 = 0.18, w1 = 0.08, bend = 0, depth = 0.45 })
			K:chain(g, { "Fur", "FurTip" }, R.p(0.24 * x, R.top - 0.08, -0.04), R.v(0.8 * x, 0.35, 0.9), R.v(0, 0, 1), { n = 2, len = 0.26, w0 = 0.12, w1 = 0.06, bend = 0, depth = 0.5 })
			-- a glowing static gland under each eye
			K:block("Head", "Arc", R.cf(0.25 * x, R.eyeY - 0.13, -0.3, 0, -24 * x, 0), Vector3.new(0.05, 0.08, 0.16))
		end
		H.bolt(K, "Head", "Arc", fangTips[1], fangTips[-1], R.v(0, 0, 1), 3, 0.03, 0.04)
		for k = -1, 1 do
			K:chain("Head", { "FurDark", "FurTip" }, R.p(k * 0.1, R.top - 0.02, -0.2), R.v(k * 0.25, 0.7, 1), R.v(1, 0, 0), { n = 2, len = 0.3, w0 = 0.1, w1 = 0.06, bend = 0, depth = 0.6 })
		end
	end,
}
