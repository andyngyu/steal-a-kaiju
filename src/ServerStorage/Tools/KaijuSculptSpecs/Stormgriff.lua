local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Epic / storm: the stormgriff, a griffin. The front an eagle: a white chest, a storm-grey head and neck
-- with a dark crown, a hooked gold beak, a heavy dark brow over glowing yellow eyes, a crest swept back off the skull,
-- scaly gold forelegs on black talons. The back a lion: tawny fur, cream belly, big paws, a long tail ending in a
-- tuft of storm cloud with a bolt dropping from it. Two great slate storm wings raised high over the back: long
-- primaries fanned up and out, each edged with yellow lightning, secondaries hanging behind, storm-cloud coverts along
-- the leading edge with bolts dropping out of them and a bolt running down each wing arm.
local HEAD = CFrame.new(0, 2.74, -1.54) * CFrame.Angles(rad(-8), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.4)
local HS = 1.12

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 631,
	Vary = 0.05,
	Scale = 1.2,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = { "C08A4A", Material = "Slate" },
		HideDark = { "8A5E30", Material = "Slate" },
		HideLight = { "D8A868", Material = "Slate" },
		Back = { "6A4626", Material = "Slate" },
		Lion = "C08A4A",
		LionDark = "8A5E30",
		LionLight = "D8A868",
		Belly = "E8DCC0",
		Belly2 = "D4C6A6",
		Feather = "E8ECF0",
		FeatherGrey = "B4BCC8",
		FeatherDark = "5A6272",
		Wing = "5A6070",
		WingDark = "3A3F4A",
		WingLight = "7E8694",
		HeadGrey = "7E8694",
		HeadDark = "3E434E",
		Bolt = { "FFC93A", Neon = true },
		BoltHot = { "FFEFA8", Neon = true },
		Cloud = "9AA2B0",
		CloudDark = "5A6070",
		CloudLight = "C8CED8",
		Beak = "D49A28",
		BeakDark = "4E360C",
		Cere = "D8B040",
		Scale = { "C49A34", Material = "Slate" },
		ScaleDark = { "8A6A1E", Material = "Slate" },
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Mouth = "5A1A2A",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0C10",
		Claw = "16161A",
		ClawTip = "3A3A40",
	},
	Joints = {
		Head = { 0, 1.9, -0.86 },
		Jaw = hj(HINGE),
		LegFL = { 0.42, 1.8, -0.86 },
		LegFR = { -0.42, 1.8, -0.86 },
		LegBL = { 0.42, 1.74, 0.86 },
		LegBR = { -0.42, 1.74, 0.86 },
		Tail = { 0, 1.7, 1.0 },
		WingL = { 0.5, 2.24, -0.6 },
		WingR = { -0.5, 2.24, -0.6 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- eagle feathers over the shoulders and chest, lion fur from the waist back
		local function coat(th, ring, smp)
			local a = math.deg(math.abs(th))
			if smp.p.Z < -0.3 then
				if a < 34 then
					return "FeatherDark"
				elseif a < 80 then
					return ring % 2 == 0 and "FeatherGrey" or "Feather"
				end
				return "Feather"
			end
			if a < 24 then
				return "Back"
			elseif a < 100 then
				return ring % 3 == 0 and "LionDark" or "Lion"
			end
			return "LionLight"
		end
		local belly = { key = "Belly", key2 = "Belly2", arc = 38, t = 0.09, wide = 1.05 }
		local body = K:tube("Body", {
			{ 0, 1.82, -0.92, rx = 0.58, ru = 0.6, rd = 0.64 },
			{ 0, 1.8, -0.3, rx = 0.62, ru = 0.6, rd = 0.62 },
			{ 0, 1.72, 0.4, rx = 0.54, ru = 0.52, rd = 0.5 },
			{ 0, 1.68, 0.96, rx = 0.46, ru = 0.46, rd = 0.44 },
		}, { step = 0.26, core = "HideDark", coreScale = 0.86, tile = { w = 0.32, l = 0.34, t = 0.09, lift = 8, jitter = 2, sink = 0.45, overlap = 1.12 }, belly = belly, color = coat })
		local neck = K:tube("Head", {
			{ 0, 2.7, -1.48, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 2.4, -1.36, rx = 0.36, ru = 0.36, rd = 0.4 },
			{ 0, 2.06, -1.1, rx = 0.46, ru = 0.46, rd = 0.5 },
			{ 0, 1.86, -0.82, rx = 0.56, ru = 0.56, rd = 0.6 },
		}, { step = 0.2, core = "FeatherGrey", coreScale = 0.86, tile = { w = 0.26, l = 0.3, t = 0.08, lift = 10, jitter = 2, sink = 0.45, overlap = 1.15 }, color = function(th, ring)
			local a = math.deg(math.abs(th))
			return a < 40 and "HeadDark" or (a > 120 and "Feather" or (ring % 2 == 0 and "HeadGrey" or "FeatherGrey"))
		end })
		-- hackles raised down the back of the neck
		for s = 0.1, neck.total - 0.08, 0.16 do
			local smp = K:at(neck, s)
			for _, th in { 0, rad(36), rad(-36) } do
				local pos, nrm = K:surface(smp, th, 0.02)
				K:chain("Head", { "HeadGrey", "HeadDark" }, pos, (nrm + smp.T * 1.3).Unit, smp.R, { n = 2, len = 0.32, w0 = 0.14, w1 = 0.09, bend = 0, depth = 0.4 })
			end
		end

		-- the lion tail, a storm-cloud tuft at its end with a bolt hanging from it
		local tail = K:tube("Tail", {
			{ 0, 1.72, 0.96, rx = 0.17, ru = 0.17 },
			{ 0, 1.62, 1.6, rx = 0.13, ru = 0.13 },
			{ 0.1, 1.86, 2.2, rx = 0.11, ru = 0.11 },
			{ 0.18, 2.36, 2.5, rx = 0.1, ru = 0.1 },
		}, { step = 0.22, core = "Lion", coreScale = 0.95, tile = H.plates(0.2, 5, 0.07), color = function(_, ring)
			return ring % 2 == 0 and "Lion" or "LionDark"
		end })
		local tip = K:at(tail, tail.total)
		H.cloud(K, "Tail", { "CloudDark", "Cloud", "CloudLight" }, tip.p + tip.T * 0.12, Vector3.new(0.24, 0.2, 0.24), 8)
		H.zap(K, "Tail", { "Bolt", "BoltHot" }, tip.p + Vector3.new(0, -0.1, 0.14), tip.p + Vector3.new(0.05, -0.72, 0.24), Vector3.xAxis, 3, 0.08, 0.08)

		-- scaly gold eagle forelegs on black talons, white feather trousers; tawny lion hind legs on big paws
		for _, x in { 1, -1 } do
			local fl = x == 1 and "LegFL" or "LegFR"
			H.quadLeg(K, fl, {
				{ 0.42 * x, 1.8, -0.86, 0.3 },
				{ 0.48 * x, 1.08, -0.8, 0.17 },
				{ 0.46 * x, 0.3, -0.96, 0.13 },
			}, { step = 0.22, cores = { "Feather", "Scale" }, tiles = { { w = 0.22, l = 0.3, t = 0.08, lift = 14, jitter = 3, sink = 0.45, overlap = 1.2 }, nil }, color = function(_, ring)
				return ring % 2 == 0 and "Feather" or "FeatherGrey"
			end, foot = { size = Vector3.new(0.3, 0.14, 0.34), key = "ScaleDark" }, toes = 4, claw = { len = 0.34, w = 0.07, curl = 52 } })
			for k = 0, 3 do
				local y = 0.4 + k * 0.16
				K:block(fl, "ScaleDark", CFrame.new(0.465 * x, y, -0.96 + (y - 0.3) * 0.08 - 0.12) * CFrame.Angles(rad(-6), 0, 0), Vector3.new(0.22, 0.06, 0.08))
			end
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.42 * x, 1.74, 0.86, 0.36 },
				{ 0.48 * x, 1.16, 0.6, 0.26 },
				{ 0.48 * x, 0.6, 1.0, 0.17 },
				{ 0.48 * x, 0.2, 0.9, 0.15 },
			}, { step = 0.22, cores = { "Lion", "LionDark", "LionDark" }, tiles = { H.plates(0.3, 5, 0.08), nil, nil }, color = function(_, ring)
				return ring % 2 == 0 and "Lion" or "LionLight"
			end, foot = { size = Vector3.new(0.42, 0.2, 0.46), key = "LionDark" }, toes = 4, claw = { len = 0.18, w = 0.06, curl = 40 } })
		end

		-- the great storm wings, raised high over the back
		for _, x in { 1, -1 } do
			local g = x == 1 and "WingL" or "WingR"
			local sh = Vector3.new(0.5 * x, 2.24, -0.6)
			local el = sh + Vector3.new(0.6 * x, 0.72, 0.3)
			local wr = el + Vector3.new(0.42 * x, 0.86, 0.22)
			H.limb(K, g, { { sh.X, sh.Y, sh.Z, 0.2 }, { el.X, el.Y, el.Z, 0.15 }, { wr.X, wr.Y, wr.Z, 0.1 } }, { step = 0.2, core = "WingDark" })
			-- primaries fanned from the wrist, up and out to back and out, tipped yellow-white
			for i = 0, 6 do
				local f = i / 6
				local d = Vector3.new((0.32 + 0.08 * f) * x, 1 - 0.85 * f, 0.15 + 0.95 * f).Unit
				local len = 1.35 - f * 0.25
				local across = d:Cross(Vector3.new(x, 0, 0)).Unit
				K:chain(g, { "WingDark", "Wing", "Wing", "WingLight" }, wr + d * 0.04, d, across, { n = 4, len = len, w0 = 0.2, w1 = 0.13, bend = 0, depth = 0.28 })
				-- yellow lightning running along the feather's edge
				H.zap(K, g, { "Bolt", "BoltHot" }, wr + d * 0.3 + across * 0.1, wr + d * len * 0.98 + across * 0.07, Vector3.new(x, 0, 0), 3, 0.07, 0.03)
			end
			-- secondaries hanging back from the forearm and the arm, closing the wing
			for i = 0, 7 do
				local f = i / 7
				local base = wr:Lerp(sh, f)
				local d = Vector3.new(0.12 * x, -0.25 - f * 0.25, 1).Unit
				local len = 1.25 - f * 0.4
				K:chain(g, { "Wing", "WingDark", "WingLight" }, base + Vector3.new(0, -0.04, 0.06), d, Vector3.new(x, 0, 0), { n = 3, len = len, w0 = 0.26, w1 = 0.18, bend = 0, depth = 0.26 })
			end
			-- storm-cloud coverts along the leading edge, lightning forking out of them
			local c1, c2 = sh:Lerp(el, 0.6) + Vector3.new(0, 0.08, 0.14), el:Lerp(wr, 0.5) + Vector3.new(0, 0.04, 0.16)
			H.cloud(K, g, { "Cloud", "CloudLight", "CloudDark" }, c1, Vector3.new(0.28, 0.2, 0.28), 8)
			H.cloud(K, g, { "CloudLight", "Cloud", "CloudDark" }, c2, Vector3.new(0.24, 0.18, 0.26), 7)
			H.zap(K, g, { "Bolt", "BoltHot" }, c1 + Vector3.new(0.1 * x, -0.14, 0.1), c1 + Vector3.new(0.24 * x, -0.7, 0.3), Vector3.zAxis, 3, 0.08, 0.08)
			H.zap(K, g, { "BoltHot", "Bolt" }, sh + Vector3.new(0.06 * x, 0.14, -0.12), wr + Vector3.new(0, 0.08, -0.1), Vector3.new(0, 0, 1), 4, 0.08, 0.07)
		end

		-- head: an eagle's, a heavy scowling brow, a hooked gold beak
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
			K:block("Head", "HeadGrey", hcf(0, 0.12, -0.24), Vector3.new(0.54, 0.5, 0.58))
			K:block("Head", "HeadGrey", hcf(0, 0.1, -0.24, 0, 0, 45), Vector3.new(0.42, 0.42, 0.54))
			K:block("Head", "HeadDark", hcf(0, 0.36, -0.18, -6, 0, 0), Vector3.new(0.42, 0.12, 0.52))
			-- the hooked gold beak with a yellow cere
			K:block("Head", "Cere", hcf(0, 0.1, -0.56), Vector3.new(0.34, 0.3, 0.14))
			K:block("Head", "Beak", hcf(0, 0.06, -0.74, -4, 0, 0), Vector3.new(0.3, 0.32, 0.3))
			K:block("Head", "Beak", hcf(0, 0.0, -0.94, -30, 0, 0), Vector3.new(0.24, 0.28, 0.24))
			K:chain("Head", { "Beak", "BeakDark", "BeakDark" }, hp(0, -0.02, -1.04), hv(0, -0.9, -0.45), hv(1, 0, 0), { n = 3, len = 0.36, w0 = 0.2, w1 = 0.08, bend = 36, depth = 1.1 })
			K:block("Head", "Mouth", hcf(0, -0.12, -0.72), Vector3.new(0.24, 0.04, 0.4))
			for _, x in { 1, -1 } do
				K:block("Head", "BeakDark", hcf(0.12 * x, 0.14, -0.6), Vector3.new(0.04, 0.05, 0.08))
				-- the heavy brow ridge and a fierce eye under it
				K:block("Head", "HeadDark", hcf(0.2 * x, 0.33, -0.42, -4, -16 * x, 20 * x), Vector3.new(0.3, 0.13, 0.38))
				H.eye(K, "Head", hcf(0.27 * x, 0.2, -0.43, 0, -44 * x, 10 * x), 0.19, 0.07)
				-- a dark streak back from the eye
				K:block("Head", "HeadDark", hcf(0.28 * x, 0.18, -0.1, 0, -8 * x, 0), Vector3.new(0.06, 0.1, 0.4))
			end
			-- a crest of dark feathers swept back off the skull
			for k = -1, 1 do
				K:chain("Head", { "HeadDark", "FeatherDark", "FeatherDark" }, hp(k * 0.1, 0.36, -0.2), hv(k * 0.3, 0.35, 1), hv(1, 0, 0), { n = 3, len = 0.62 - math.abs(k) * 0.1, w0 = 0.12, w1 = 0.07, bend = -6, depth = 0.5 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-18), 0, 0)
			K:block("Jaw", "Beak", JAW * CFrame.new(0, -0.06, -0.3), Vector3.new(0.24, 0.13, 0.5))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.02, -0.3), Vector3.new(0.18, 0.04, 0.44))
			K:block("Jaw", "HeadGrey", JAW * CFrame.new(0, -0.1, 0.0), Vector3.new(0.34, 0.14, 0.26))
		end)
	end,
}
