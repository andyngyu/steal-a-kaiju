local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Common / water: the lurkfin, an axolotl grown into a predator. Long, low and sprawling on webbed
-- feet: a deep navy back fading through teal flanks to a pale belly, a cyan lateral line glowing from a sunk seam and a
-- row of photophores below it, a coral fin running from the neck to a tall paddle tail. Face: a wide flat skull, a
-- grin of needle teeth, small cyan eyes under heavy brows, and three feathery gill fronds a side glowing pink at the tips.
local HEAD = CFrame.new(0, 1.12, -1.22) * CFrame.Angles(rad(-4), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.1)

return {
	Seed = 501,
	Vary = 0.05,
	Scale = 1.2,
	Gait = "Crawl",
	Emotes = { "Look", "Chomp", "Wiggle" },
	Palette = {
		Hide = { "2A5E6C", Material = "Slate" },
		HideDark = { "1A3E4E", Material = "Slate" },
		HideLight = { "5C9AA0", Material = "Slate" },
		Back = { "10263A", Material = "Slate" },
		Belly = "D8E2D0",
		Belly2 = "BCCAB8",
		Fin = "E8607E",
		FinDark = "A83A5A",
		Gill = "C04A6A",
		GillDark = "7E2A46",
		GillTip = { "FF5A82", Neon = true },
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Tooth = "EAF2EC",
		Mouth = "2A0E18",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
		Claw = "1A2A30",
		ClawTip = "C8D8D4",
	},
	Joints = {
		Head = { 0, 1.1, -0.92 },
		Jaw = HEAD * HINGE,
		LegFL = { 0.6, 0.96, -0.52 },
		LegFR = { -0.6, 0.96, -0.52 },
		LegBL = { 0.58, 0.94, 0.74 },
		LegBR = { -0.58, 0.94, 0.74 },
		Tail = { 0, 1.0, 1.1 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 64, flank = 102, every = 3, upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 52, t = 0.1, wide = 1.15 }
		local scales = { w = 0.4, n = 8, t = 0.1, lift = 4, jitter = 1.5, sink = 0.5, overlap = 1.1 }
		-- a long low body, broadest at the shoulders
		local body = K:tube("Body", {
			{ 0, 1.1, -0.98, rx = 0.66, ru = 0.42, rd = 0.44 },
			{ 0, 1.14, -0.3, rx = 0.86, ru = 0.5, rd = 0.54 },
			{ 0, 1.1, 0.5, rx = 0.82, ru = 0.48, rd = 0.5 },
			{ 0, 1.02, 1.14, rx = 0.6, ru = 0.4, rd = 0.4 },
		}, { step = 0.34, core = "Hide", coreScale = 0.92, tile = scales, belly = belly, color = skin })
		-- the tail: long, flattened side to side into a paddle
		local tail = K:tube("Tail", {
			{ 0, 1.04, 1.0, rx = 0.56, ru = 0.4, rd = 0.4 },
			{ 0.04, 0.98, 1.8, rx = 0.38, ru = 0.36, rd = 0.34 },
			{ 0.2, 0.9, 2.5, rx = 0.24, ru = 0.3, rd = 0.28 },
			{ 0.5, 0.82, 3.1, rx = 0.12, ru = 0.22, rd = 0.2 },
		}, { step = 0.32, core = "Hide", coreScale = 0.92, tile = { w = 0.34, n = 6, t = 0.09, lift = 4, jitter = 1.5, sink = 0.5, overlap = 1.1 }, belly = belly, color = skin, trim = 0.08 })
		-- the coral fin from the neck to the tail tip, taller over the tail, and a fin under the tail
		K:ridge("Body", body, { from = 0.1, every = 0.2, height = function(u) return 0.26 + u * 0.12 end, thick = 0.05, key = "Fin", tip = "FinDark", lean = 26, sink = 0.9, style = "plate", width = 0.9 })
		K:ridge("Tail", tail, { every = 0.2, height = function(u) return 0.42 + math.sin(u * math.pi) * 0.3 end, thick = 0.05, key = "Fin", tip = "FinDark", lean = 22, sink = 0.9, style = "plate", width = 0.9 })
		for s = 0.6, tail.total - 0.1, 0.22 do
			local smp = K:at(tail, s)
			local pos, nrm = K:surface(smp, math.pi, 0.02)
			local u = s / tail.total
			K:plate("Tail", { "FinDark", "Fin" }, pos, nrm, smp.T, { h = 0.22 + math.sin(u * math.pi) * 0.18, w = 0.26, t = 0.05, n = 2, lean = 18 })
		end
		-- the glowing lateral line, sunk in a dark seam, and a row of photophores below it
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "Glow", body, rad(84) * x, 0.1, body.total - 0.05, { width = 0.05, height = 0.1, lift = 0.04, wander = 6, step = 0.24, lip = "SeamLip", lipW = 0.05 })
			H.vein(K, "Tail", "Glow", tail, rad(86) * x, 0.05, tail.total * 0.7, { width = 0.045, height = 0.09, lift = 0.04, wander = 6, step = 0.22, taper = true, lip = "SeamLip", lipW = 0.045 })
			for s = 0.3, body.total - 0.2, 0.3 do
				local smp = K:at(body, s)
				local pos, nrm = K:surface(smp, rad(112) * x, -0.03)
				local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
				K:block("Body", "SeamLip", F, Vector3.new(0.13, 0.05, 0.13))
				K:block("Body", "Glow", F * CFrame.new(0, 0.01, 0), Vector3.new(0.065, 0.05, 0.065))
			end
		end
		-- sprawled legs on broad webbed feet
		for _, x in { 1, -1 } do
			for _, L in { { "LegF", -0.52, -0.6, 0.32, 0.26 }, { "LegB", 0.74, 0.62, 0.36, 0.3 } } do
				local g = L[1] .. (x == 1 and "L" or "R")
				H.quadLeg(K, g, {
					{ 0.6 * x, 1.0, L[2], L[4] },
					{ 1.12 * x, 0.82, L[3], L[5] },
					{ 1.18 * x, 0.24, L[2] - 0.12, L[5] * 0.8 },
				}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.58, 0.14, 0.58), key = "HideDark" }, yaw = 22, toes = 4, claw = { len = 0.2, w = 0.06, curl = 20 } })
				-- the web between the toes
				local fz = L[2] - 0.12 - 0.58 * 0.1
				K:block(g, "Fin", CFrame.new(1.18 * x, 0.08, fz - 0.3) * CFrame.Angles(0, rad(-22 * x), 0), Vector3.new(0.5, 0.03, 0.26))
			end
		end

		-- head (origin at the back of the skull, facing -Z): wide and flat, rounded at the front
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.08, -0.34), Vector3.new(1.12, 0.42, 0.8))
		K:block("Head", "Hide", hcf(0, 0.03, -0.9), Vector3.new(1.0, 0.32, 0.52))
		K:block("Head", "Hide", hcf(0, 0.02, -1.14, 0, 0, 0), Vector3.new(0.78, 0.28, 0.26))
		for _, x in { 1, -1 } do
			K:block("Head", "Hide", hcf(0.4 * x, 0.02, -1.06, 0, 30 * x, 0), Vector3.new(0.3, 0.28, 0.34))
		end
		K:block("Head", "Back", hcf(0, 0.3, -0.4, -4, 0, 0), Vector3.new(0.84, 0.06, 0.72))
		K:block("Head", "HideDark", hcf(0, 0.2, -0.92, -6, 0, 0), Vector3.new(0.7, 0.06, 0.44))
		K:block("Head", "Mouth", hcf(0, -0.14, -0.74), Vector3.new(0.94, 0.04, 0.8))
		for _, x in { 1, -1 } do
			-- heavy scowling brows over small eyes set wide on top of the skull
			K:block("Head", "Back", hcf(0.34 * x, 0.34, -0.66, -10, -12 * x, 18 * x), Vector3.new(0.36, 0.13, 0.32))
			H.eye(K, "Head", hcf(0.4 * x, 0.23, -0.76, 0, -24 * x, 12 * x), 0.13, 0.045)
			-- needle teeth round the front and down the sides
			H.teeth(K, "Head", "Tooth", hp(0.46 * x, -0.13, -0.6), hp(0.36 * x, -0.13, -1.14), 5, hv(0, -1, 0), hv(1, 0, 0), 0.12, 0.035)
			-- three feathery gill fronds a side, sweeping back and up, glowing at the tips
			for k = 0, 2 do
				local base = hp(0.5 * x, 0.18 - k * 0.12, -0.14 + k * 0.05)
				local d = hv(0.65 * x, 0.55 - k * 0.42, 0.55)
				local len = 0.78 - k * 0.1
				K:chain("Head", { "GillDark", "Gill", "Gill" }, base, d, hv(0, 0, 1), { n = 3, len = len, w0 = 0.12, w1 = 0.07, bend = 8, tip = false })
				for f = 1, 4 do
					local p = base + d * len * (0.25 + f * 0.17)
					for _, sd in { 1, -1 } do
						K:spike("Head", f == 4 and "GillTip" or "Gill", p, (d + hv(0, sd * 0.9, 0)).Unit, d, 0.16 - f * 0.015, 0.035)
					end
				end
				H.point(K, "Head", "GillTip", base + d * (len + 0.05), d, 0.09)
			end
		end
		H.teeth(K, "Head", "Tooth", hp(-0.28, -0.12, -1.26), hp(0.28, -0.12, -1.26), 6, hv(0, -1, 0), hv(0, 0, 1), 0.11, 0.035)
		-- the lower jaw: wide, a little open, needle teeth all round
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-16), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.56), Vector3.new(1.0, 0.18, 0.96))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.17, -0.52), Vector3.new(0.84, 0.04, 0.86))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.6), Vector3.new(0.86, 0.04, 0.86))
		local up = JAW:VectorToWorldSpace(Vector3.yAxis)
		for _, x in { 1, -1 } do
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.44 * x, 0, -0.4), JAW * Vector3.new(0.34 * x, 0, -0.98), 5, up, JAW:VectorToWorldSpace(Vector3.xAxis), 0.11, 0.035)
		end
		H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(-0.26, 0, -1.04), JAW * Vector3.new(0.26, 0, -1.04), 5, up, JAW:VectorToWorldSpace(Vector3.zAxis), 0.1, 0.035)
	end,
}
