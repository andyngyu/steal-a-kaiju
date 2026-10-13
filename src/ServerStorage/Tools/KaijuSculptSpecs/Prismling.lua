local rad = math.rad
local H = require(script.Parent.Helpers)

-- Any biome / Secret / crystal: something from beyond the sky: a sleek winged crystal drake on four slender legs. A
-- body of iridescent violet glass traced with glowing neon facets, a long neck and a whip tail curling up into a fan
-- of crystal blades, wings of stained-glass crystal panes sweeping magenta to cyan to gold, a crown of rainbow
-- crystal horns, glowing eyes.
local HEAD = CFrame.new(0, 3.02, -1.42) * CFrame.Angles(rad(-8), 0, 0)
local SKULL = { 0.46, 0.34, 0.44 }

return {
	Seed = 53,
	Vary = 0.04,
	Scale = 1.12,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow" },
	Palette = {
		Hide = { "3B3263", Material = "Glass" },
		HideDark = { "262046", Material = "Glass" },
		HideLight = { "5E5596", Material = "Glass" },
		Back = { "17122E", Material = "Glass" },
		Belly = { "B8B0E6", Material = "Glass" },
		Belly2 = { "9A90D2", Material = "Glass" },
		Magenta = { "D94CFF", Material = "Glass" },
		Violet = { "7A5CFF", Material = "Glass" },
		Cyan = { "3CD8FF", Material = "Glass" },
		Mint = { "3CFFC2", Material = "Glass" },
		Gold = { "FFD24C", Material = "Glass" },
		FacetM = { "FF4CF0", Neon = true },
		FacetC = { "4CEBFF", Neon = true },
		Tooth = "F4F2FF",
		Claw = "1A1430",
		ClawTip = { "9CF2FF", Neon = true },
		Mouth = "3C1838",
		Eye = { "7CF6FF", Neon = true },
		Socket = "0C0818",
	},
	Joints = {
		Head = { 0, 1.92, -0.7 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegFL = { 0.32, 1.78, -0.6 },
		LegFR = { -0.32, 1.78, -0.6 },
		LegBL = { 0.32, 1.74, 0.62 },
		LegBR = { -0.32, 1.74, 0.62 },
		Tail = { 0, 1.72, 0.82 },
		WingL = { 0.3, 2.14, -0.46 },
		WingR = { -0.3, 2.14, -0.46 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 34, band = 90, flank = 112, every = 2 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.08, wide = 1.1 }
		local tile = { w = 0.34, t = 0.08, lift = 6, jitter = 1, sink = 0.5, overlap = 1.1 }
		local PRISM = { "Magenta", "Violet", "Cyan", "Mint", "Gold" }
		local function prism(i)
			return { PRISM[(i - 1) % 5 + 1], PRISM[i % 5 + 1], i % 2 == 0 and "FacetC" or "FacetM", PRISM[(i + 1) % 5 + 1] }
		end
		local torso = K:tube("Body", {
			{ 0, 1.82, -0.66, rx = 0.4, ru = 0.4, rd = 0.44 },
			{ 0, 1.78, -0.06, rx = 0.46, ru = 0.42, rd = 0.46 },
			{ 0, 1.74, 0.5, rx = 0.4, ru = 0.38, rd = 0.38 },
			{ 0, 1.72, 0.86, rx = 0.3, ru = 0.3, rd = 0.28 },
		}, { step = 0.3, core = "Hide", coreScale = 0.76, tile = tile, belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 2.98, -1.38, rx = 0.2, ru = 0.2, rd = 0.22 },
			{ 0, 2.62, -1.24, rx = 0.24, ru = 0.24, rd = 0.26 },
			{ 0, 2.2, -0.98, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 1.9, -0.68, rx = 0.38, ru = 0.38, rd = 0.4 },
		}, { step = 0.26, core = "Hide", coreScale = 0.76, tile = { w = 0.3, t = 0.07, lift = 6, jitter = 1, sink = 0.5, overlap = 1.1 }, belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 1.72, 0.78, rx = 0.28, ru = 0.27, rd = 0.26 },
			{ -0.04, 1.76, 1.5, rx = 0.2, ru = 0.2, rd = 0.19 },
			{ -0.18, 1.92, 2.2, rx = 0.14, ru = 0.14, rd = 0.13 },
			{ -0.42, 2.24, 2.8, rx = 0.1, ru = 0.1, rd = 0.09 },
			{ -0.66, 2.66, 3.16, rx = 0.07, ru = 0.07, rd = 0.06 },
			{ -0.8, 3.06, 3.24, rx = 0.05, ru = 0.05, rd = 0.05 },
		}, { step = 0.3, core = "Hide", coreScale = 0.78, tile = { w = 0.24, n = 4, t = 0.06, lift = 6, jitter = 1, sink = 0.5, overlap = 1.12 }, color = skin, trim = 0.08 })
		-- glowing neon facets traced over the body
		H.cracks(K, "Body", "FacetC", torso, { rad(70), rad(-70) }, 0.1, torso.total - 0.1, 0.24, 0.045, 0.05)
		H.cracks(K, "Body", "FacetM", torso, { rad(118), rad(-118) }, 0.1, torso.total - 0.15, 0.26, 0.045, 0.05)
		H.cracks(K, "Head", "FacetC", neck, { rad(80), rad(-80) }, 0.1, neck.total - 0.1, 0.22, 0.04, 0.04)
		H.cracks(K, "Tail", "FacetM", tail, { rad(70), rad(-70) }, 0.05, tail.total * 0.6, 0.3, 0.04, 0.04)
		-- rainbow crystal growths down the spine, a blazing gem on the chest, a fan of blades at the tail tip
		local i = 0
		for _, part in { { "Head", neck, 0.36 }, { "Body", torso, 0.5 }, { "Tail", tail, 0.3 } } do
			local samples = part[2]
			for s = 0.14, samples.total - 0.16, (part[1] == "Tail" and 0.5 or 0.34) do
				i += 1
				local smp = K:at(samples, s)
				H.crystal(K, part[1], prism(i), K:surface(smp, 0, 0.03), (smp.U + smp.T * 0.4).Unit, part[3] * (part[1] == "Tail" and (1 - s / samples.total * 0.6) or 1), 3, 26)
			end
		end
		local chest = K:at(torso, 0.12)
		local cpos, cn = K:surface(chest, math.pi, 0.02)
		H.crystal(K, "Body", { "FacetM", "Magenta", "Violet" }, cpos, (cn + chest.T * -0.6).Unit, 0.36, 3, 30)
		local tip = K:at(tail, tail.total)
		for j = 1, 5 do
			local d = CFrame.fromAxisAngle(tip.R, rad((j - 3) * 22)) * tip.T
			K:chain("Tail", { PRISM[j], PRISM[j % 5 + 1], j % 2 == 0 and "FacetC" or "FacetM" }, tip.p - tip.T * 0.06, (d + tip.U * 0.1).Unit, tip.R, { n = 3, len = 0.62 - math.abs(j - 3) * 0.1, w0 = 0.11, w1 = 0.06, bend = 0 })
		end
		-- the wings: stained-glass crystal panes on glowing spars
		for _, x in { 1, -1 } do
			local g = x == 1 and "WingL" or "WingR"
			H.wing(K, g, Vector3.new(0.3 * x, 2.14, -0.46), Vector3.new(x, 1.15, 0.05), Vector3.new(0, 0.2, 1), {
				span = 2.6,
				spars = 4,
				spread = 66,
				keys = { "Magenta", "Violet", "Cyan", "Mint", "Gold" },
				spar = "HideDark",
				edge = x == 1 and "FacetC" or "FacetM",
			})
			H.crystal(K, g, prism(x == 1 and 2 or 4), Vector3.new(0.34 * x, 2.18, -0.46), Vector3.new(0.3 * x, 1, 0.2), 0.36, 3, 24)
		end
		-- four slender legs, crystal-tipped claws
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.32 * x, 1.8, -0.6, 0.2 },
				{ 0.4 * x, 1.12, -0.5, 0.14 },
				{ 0.38 * x, 0.34, -0.64, 0.1 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.22, 0.14, 0.3), key = "HideDark" }, toes = 3, claw = { len = 0.16, w = 0.045 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.32 * x, 1.76, 0.62, 0.24 },
				{ 0.42 * x, 1.22, 0.36, 0.16 },
				{ 0.42 * x, 0.62, 0.82, 0.11 },
				{ 0.42 * x, 0.2, 0.74, 0.09 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, foot = { size = Vector3.new(0.22, 0.14, 0.32), key = "HideDark" }, toes = 3, claw = { len = 0.16, w = 0.045 } })
		end
		-- head: a sleek dragon head, a crown of rainbow crystal horns
		local hd = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.32, 0.22, 0.5 },
			tip = { 0.24, 0.18, 0.22 },
			open = 10,
			teeth = { 0.06, 0.035 },
			brow = "Back",
			browSize = { 0.2, 0.1, 0.24 },
			eye = { 0.12, 0.04 },
			cheek = 0.14,
		})
		for _, x in { 1, -1 } do
			K:chain("Head", { "Violet", "Magenta", "FacetM" }, hd.p(0.14 * x, hd.top - 0.02, -0.24), hd.v(0.25 * x, 0.55, 0.8), hd.v(1, 0, 0), { n = 3, len = 0.7, w0 = 0.09, w1 = 0.05, bend = 10 })
			K:chain("Head", { "Cyan", "FacetC" }, hd.p(0.2 * x, hd.top - 0.08, -0.1), hd.v(0.6 * x, 0.35, 0.7), hd.v(0, 0, 1), { n = 2, len = 0.4, w0 = 0.07, w1 = 0.04, bend = 0 })
		end
		H.crystal(K, "Head", prism(3), hd.p(0, hd.top, -0.3), hd.v(0, 1, 0.4), 0.34, 3, 20)
	end,
}
