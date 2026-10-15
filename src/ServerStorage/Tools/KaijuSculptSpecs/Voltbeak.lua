local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Uncommon / storm: the voltbeak, a terror bird. A heavy flightless predator striding on thick scaly
-- legs with big hooked talons and a raised killing claw, its body hunched forward under slate storm-blue feathers barred
-- in dark bands, a white chest, a fan of long tail feathers. Two stubby wings of storm cloud, lightning dropping out of
-- their undersides. Head: dark feathers, a heavy scowling brow over glowing yellow eyes, a short, deep, sharply hooked
-- dark beak, and a crest of long feathers swept back off the skull, charged yellow at the tips with sparks between.
local HEAD = CFrame.new(0, 3.46, -1.6) * CFrame.Angles(rad(-14), 0, 0)
local HINGE = Vector3.new(0, -0.16, -0.4)
local HS = 1.22

return {
	Seed = 611,
	Vary = 0.05,
	Scale = 0.95,
	Gait = "Biped",
	Emotes = { "Look", "Roar", "Hop" },
	Palette = {
		Hide = { "3E4A60", Material = "Slate" },
		HideDark = { "1E242F", Material = "Slate" },
		HideLight = { "5E6E88", Material = "Slate" },
		Feather = "3E4A60",
		FeatherDark = "1E242F",
		FeatherLight = "5E6E88",
		HeadDark = "181C24",
		Brow = "101216",
		Chest = "DCE0E6",
		Chest2 = "C4CAD2",
		Cloud = "C8D0DC",
		CloudDark = "8A94A6",
		CloudLight = "EEF1F6",
		Beak = "484A54",
		BeakDark = "121316",
		BeakMid = "26282E",
		Shin = { "4E525C", Material = "Slate" },
		ShinDark = { "34373E", Material = "Slate" },
		Spark = { "FFE680", Neon = true },
		Bolt = { "FFC93A", Neon = true },
		BoltHot = { "FFEFA8", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Mouth = "5A1A2A",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0C10",
		Claw = "141518",
		ClawTip = "C8C4B8",
	},
	Joints = {
		Head = { 0, 2.74, -0.78 },
		Jaw = HEAD.Position + (HEAD * HINGE - HEAD.Position) * HS,
		LegL = { 0.5, 2.36, 0.2 },
		LegR = { -0.5, 2.36, 0.2 },
		WingL = { 0.6, 2.74, -0.34 },
		WingR = { -0.6, 2.74, -0.34 },
		Tail = { 0, 2.5, 0.9 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- storm-blue feathers barred with dark bands, a white chest and throat
		local function plumage(th, ring)
			local a = math.deg(math.abs(th))
			if a < 26 then
				return "FeatherDark"
			elseif a < 112 then
				return ring % 3 == 0 and "FeatherDark" or (a > 84 and "FeatherLight" or "Feather")
			end
			return ring % 2 == 0 and "Chest" or "Chest2"
		end
		local feathers = { w = 0.3, l = 0.38, t = 0.08, lift = 9, jitter = 2, sink = 0.45, overlap = 1.15 }
		local body = K:tube("Body", {
			{ 0, 2.7, -0.72, rx = 0.56, ru = 0.56, rd = 0.64 },
			{ 0, 2.62, -0.12, rx = 0.66, ru = 0.62, rd = 0.72 },
			{ 0, 2.52, 0.5, rx = 0.58, ru = 0.54, rd = 0.56 },
			{ 0, 2.5, 0.92, rx = 0.4, ru = 0.4, rd = 0.36 },
		}, { step = 0.26, core = "FeatherDark", coreScale = 0.86, tile = feathers, color = plumage })
		-- a long neck rising forward to the head (runs head -> body so the feathers lie back)
		local neck = K:tube("Head", {
			{ 0, 3.42, -1.56, rx = 0.28, ru = 0.28, rd = 0.32 },
			{ 0, 3.22, -1.38, rx = 0.32, ru = 0.32, rd = 0.36 },
			{ 0, 2.98, -1.08, rx = 0.38, ru = 0.36, rd = 0.42 },
			{ 0, 2.72, -0.74, rx = 0.48, ru = 0.46, rd = 0.54 },
		}, { step = 0.22, core = "FeatherDark", coreScale = 0.86, tile = { w = 0.24, l = 0.3, t = 0.07, lift = 10, jitter = 2, sink = 0.45, overlap = 1.15 }, color = plumage })
		-- hackles: a ruff of longer feathers raised down the back of the neck
		for s = 0.1, neck.total - 0.1, 0.16 do
			local smp = K:at(neck, s)
			for _, th in { 0, rad(40), rad(-40) } do
				local pos, nrm = K:surface(smp, th, 0.02)
				K:chain("Head", { "FeatherDark", "Feather" }, pos, (nrm + smp.T * 1.4).Unit, smp.R, { n = 2, len = 0.34, w0 = 0.14, w1 = 0.09, bend = 0, depth = 0.4 })
			end
		end

		-- the tail: a fan of long feathers, the middle ones charged at the tips
		for k = -3, 3 do
			local d = CFrame.Angles(0, rad(k * 11), 0):VectorToWorldSpace(Vector3.new(0, -0.32, 1)).Unit
			local len = 1.15 - math.abs(k) * 0.1
			local keys = math.abs(k) <= 1 and { "FeatherDark", "Feather", "FeatherLight", "Spark" } or { "FeatherDark", "Feather", "FeatherLight" }
			K:chain("Tail", keys, Vector3.new(k * 0.06, 2.56 + math.abs(k) * 0.01, 0.82), d, Vector3.yAxis:Cross(d).Unit, { n = #keys, len = len, w0 = 0.22, w1 = 0.14, bend = 4, depth = 0.3 })
		end

		-- stubby wings of storm cloud on a feathered arm, little bolts crackling from their undersides
		for _, x in { 1, -1 } do
			local g = x == 1 and "WingL" or "WingR"
			local sh, el, wr = Vector3.new(0.6 * x, 2.74, -0.34), Vector3.new(1.02 * x, 2.6, -0.04), Vector3.new(1.06 * x, 2.4, 0.38)
			H.limb(K, g, { { sh.X, sh.Y, sh.Z, 0.17 }, { el.X, el.Y, el.Z, 0.13 }, { wr.X, wr.Y, wr.Z, 0.09 } }, { step = 0.2, core = "FeatherDark" })
			for i = 0, 4 do
				local base = el:Lerp(wr, i / 4) + Vector3.new(0.04 * x, 0, 0)
				local d = Vector3.new(0.12 * x, -0.55, 0.85).Unit
				K:chain(g, { i % 2 == 0 and "FeatherDark" or "Feather", "FeatherLight" }, base, d, Vector3.new(x, 0, 0), { n = 2, len = 0.62 + i * 0.07, w0 = 0.2, w1 = 0.13, bend = 0, depth = 0.3 })
			end
			H.cloud(K, g, { "Cloud", "CloudDark", "CloudLight" }, sh:Lerp(el, 0.6) + Vector3.new(0.16 * x, 0.08, 0.06), Vector3.new(0.26, 0.18, 0.36), 9)
			local c2 = el:Lerp(wr, 0.5) + Vector3.new(0.18 * x, 0.02, 0.0)
			H.cloud(K, g, { "CloudLight", "Cloud", "CloudDark" }, c2, Vector3.new(0.24, 0.16, 0.34), 8)
			H.zap(K, g, { "Bolt", "BoltHot" }, c2 + Vector3.new(0, -0.12, 0.04), c2 + Vector3.new(0.06 * x, -0.66, 0.16), Vector3.zAxis, 3, 0.08, 0.08)
		end

		-- long scaly legs under feathered thighs, hooked talons and a raised killing claw
		H.bipedLegs(K, {
			pts = {
				{ 0.5, 2.38, 0.2, 0.4, 0.44 },
				{ 0.62, 1.9, -0.02, 0.34, 0.36 },
				{ 0.62, 1.52, -0.14, 0.24 },
				{ 0.6, 0.52, 0.34, 0.17 },
				{ 0.6, 0.22, 0.08, 0.15 },
			},
			stance = { -0.24, 0.24 },
			foot = Vector3.new(0.5, 0.22, 0.56),
			toe = { 0.16, 0.48 },
			claw = { 0.44, 0.12 },
			core = "Shin",
			footCore = "ShinDark",
			toeKey = "Shin",
			muscle = false,
			scutes = "ShinDark",
		})
		for _, x in { 1, -1 } do
			local g = x == 1 and "LegL" or "LegR"
			local dz = x == 1 and -0.24 or 0.24
			-- feathered thighs
			H.limb(K, g, {
				{ 0.5 * x, 2.42, 0.2, 0.46 },
				{ 0.62 * x, 1.86, -0.04 + dz * 0.25, 0.38 },
				{ 0.62 * x, 1.62, -0.1 + dz * 0.4, 0.28 },
			}, { step = 0.18, core = "FeatherDark", tiles = { feathers, feathers }, color = function(_, ring)
				return ring % 2 == 0 and "Feather" or "FeatherDark"
			end })
			K:chain(g, { "Claw", "Claw", "ClawTip" }, Vector3.new(0.48 * x, 0.36, 0.0 + dz), Vector3.new(0, 0.75, -0.65).Unit, Vector3.xAxis, { n = 3, len = 0.62, w0 = 0.15, w1 = 0.08, bend = 34 })
		end

		-- head: dark feathers, a heavy scowling brow, a short deep sharply hooked dark beak
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
		K:block("Head", "HeadDark", hcf(0, 0.12, -0.22), Vector3.new(0.54, 0.5, 0.56))
		K:block("Head", "FeatherDark", hcf(0, 0.36, -0.2, -8, 0, 0), Vector3.new(0.42, 0.12, 0.5))
		K:block("Head", "FeatherDark", hcf(0, -0.12, -0.2), Vector3.new(0.46, 0.22, 0.46))
		-- the beak: short and deep, its ridge curving down into a sharp dark hook
		K:block("Head", "Beak", hcf(0, 0.06, -0.56), Vector3.new(0.3, 0.44, 0.36))
		K:block("Head", "Beak", hcf(0, 0.05, -0.84, -8, 0, 0), Vector3.new(0.22, 0.38, 0.32))
		K:block("Head", "BeakMid", hcf(0, -0.03, -1.06, -36, 0, 0), Vector3.new(0.16, 0.3, 0.26))
		K:block("Head", "BeakDark", hcf(0, 0.29, -0.6), Vector3.new(0.08, 0.05, 0.38))
		K:block("Head", "BeakDark", hcf(0, 0.24, -0.88, -8, 0, 0), Vector3.new(0.07, 0.05, 0.3))
		K:block("Head", "BeakDark", hcf(0, 0.08, -1.1, -36, 0, 0), Vector3.new(0.06, 0.05, 0.24))
		K:chain("Head", { "BeakMid", "BeakDark", "BeakDark" }, hp(0, -0.12, -1.16), hv(0, -1, -0.25), hv(1, 0, 0), { n = 3, len = 0.5, w0 = 0.16, w1 = 0.05, bend = 40, depth = 1.6 })
		K:block("Head", "Mouth", hcf(0, -0.17, -0.78), Vector3.new(0.24, 0.04, 0.56))
		-- the heavy scowling brow ridge
		K:block("Head", "Brow", hcf(0, 0.36, -0.42, -10, 0, 0), Vector3.new(0.3, 0.1, 0.24))
		for _, x in { 1, -1 } do
			K:block("Head", "BeakDark", hcf(0.15 * x, 0.1, -0.72, 0, -4 * x, 0), Vector3.new(0.02, 0.05, 0.1))
			K:block("Head", "Brow", hcf(0.2 * x, 0.34, -0.34, -6, -18 * x, 22 * x), Vector3.new(0.3, 0.14, 0.42))
			H.eye(K, "Head", hcf(0.27 * x, 0.2, -0.38, 0, -46 * x, 10 * x), 0.2, 0.08)
			-- cheek feathers swept back
			for k = 0, 1 do
				K:chain("Head", { "FeatherDark", "Feather" }, hp(0.24 * x, 0.06 - k * 0.14, -0.1), hv(0.5 * x, 0.05 - k * 0.2, 1), hv(0, 1, 0), { n = 2, len = 0.34, w0 = 0.14, w1 = 0.08, bend = 0, depth = 0.4 })
			end
		end
		-- the charged crest: long feathers swept back and up off the skull, sparks jumping between the tips
		local tips = {}
		for k = -2, 2 do
			local base = hp(k * 0.07, 0.38, -0.3 + math.abs(k) * 0.08)
			local d = hv(k * 0.28, 0.75 - math.abs(k) * 0.12, 0.9)
			local len = 0.86 - math.abs(k) * 0.12
			K:chain("Head", { "FeatherDark", "FeatherDark", "Feather", "Bolt" }, base, d, hv(1, 0, 0), { n = 4, len = len, w0 = 0.12, w1 = 0.07, bend = -8, depth = 0.5 })
			tips[k] = base + d * len * 0.92
		end
		for k = -2, 1, 3 do
			H.zap(K, "Head", { "BoltHot", "Bolt" }, tips[k], tips[k + 1], hv(0, 1, 0), 3, 0.06, 0.05)
		end
		-- the lower beak, open in a shriek
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-20), 0, 0)
		K:block("Jaw", "Beak", JAW * CFrame.new(0, -0.07, -0.3), Vector3.new(0.2, 0.14, 0.52))
		K:block("Jaw", "BeakDark", JAW * CFrame.new(0, -0.05, -0.6), Vector3.new(0.13, 0.12, 0.14))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.02, -0.3), Vector3.new(0.2, 0.04, 0.48))
		K:block("Jaw", "FeatherDark", JAW * CFrame.new(0, -0.12, -0.04), Vector3.new(0.34, 0.14, 0.28))
		end)
	end,
}
