local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Legendary / lava: a lean volcanic hunter charging low and level, head thrust forward. Cracked rust and
-- dark-red rock armour split by glowing magma seams, a glowing segmented belly, tall flame-shaped fins burning along
-- its spine, a long jagged tail, swept black horns, a molten maw, gold eyes.
local HEAD = CFrame.new(0, 3.0, -1.86) * CFrame.Angles(rad(-12), 0, 0)
local SKULL = { 0.74, 0.5, 0.64 }

return {
	Seed = 37,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = { "6E3523", Material = "Basalt" },
		HideDark = { "4C2418", Material = "Basalt" },
		HideLight = { "9C5432", Material = "Basalt" },
		Back = { "2E1A14", Material = "Basalt" },
		Belly = { "E8661E", Neon = true },
		Belly2 = { "A8461A", Material = "Basalt" },
		Magma = { "FF5A14", Neon = true },
		MagmaHot = { "FF8A1E", Neon = true },
		Flame = { "FFC23A", Neon = true },
		Rock = { "5A4038", Material = "Basalt" },
		RockLight = { "7E5A48", Material = "Basalt" },
		Horn = { "241712", Material = "Basalt" },
		Tooth = "F0DCC0",
		Claw = "201612",
		ClawTip = { "FFB43A", Neon = true },
		Mouth = { "FF6A1A", Neon = true },
		Eye = { "FFD04A", Neon = true },
		Socket = "120A08",
	},
	Joints = {
		Head = { 0, 2.94, -0.94 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegL = { 0.68, 2.98, 0.42 },
		LegR = { -0.68, 2.98, 0.42 },
		ArmL = { 0.6, 2.84, -0.98 },
		ArmR = { -0.6, 2.84, -0.98 },
		Tail = { 0, 2.86, 0.72 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 36, band = 92, flank = 112, every = 2 })
		local crust = { w = 0.56, l = 0.36, t = 0.14, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.88 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 36, t = 0.12, wide = 1.0 }
		local function tube(group, nodes, tile)
			return K:tube(group, nodes, { step = 0.36, core = "Magma", coreCap = "HideDark", coreScale = 0.62, tile = tile or crust, belly = belly, color = skin })
		end
		local torso = tube("Body", {
			{ 0, 2.92, -0.92, rx = 0.7, ru = 0.62, rd = 0.74 },
			{ 0, 2.88, -0.3, rx = 0.8, ru = 0.68, rd = 0.8 },
			{ 0, 2.86, 0.32, rx = 0.74, ru = 0.64, rd = 0.68 },
			{ 0, 2.84, 0.78, rx = 0.62, ru = 0.56, rd = 0.5 },
		})
		local neck = tube("Head", {
			{ 0, 3.0, -1.86, rx = 0.4, ru = 0.38, rd = 0.44 },
			{ 0, 2.98, -1.44, rx = 0.5, ru = 0.46, rd = 0.54 },
			{ 0, 2.94, -0.92, rx = 0.64, ru = 0.6, rd = 0.7 },
		})
		local tail = tube("Tail", {
			{ 0, 2.86, 0.7, rx = 0.6, ru = 0.56, rd = 0.5 },
			{ -0.04, 2.78, 1.5, rx = 0.46, ru = 0.42, rd = 0.38 },
			{ -0.2, 2.58, 2.3, rx = 0.34, ru = 0.32, rd = 0.28 },
			{ -0.5, 2.3, 3.04, rx = 0.24, ru = 0.22, rd = 0.2 },
			{ -0.94, 2.06, 3.64, rx = 0.15, ru = 0.14, rd = 0.13 },
			{ -1.4, 1.96, 3.98, rx = 0.08, ru = 0.08, rd = 0.07 },
		}, { w = 0.46, n = 5, l = 0.32, t = 0.12, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.88 })

		-- flame fins: tall stepped rock fins burning up into molten tips, tallest over the shoulders
		local FIN = { "Rock", "RockLight", "MagmaHot", "Flame" }
		local function fins(group, samples, from, to, every, hgt, lean)
			local n = math.max(0, math.floor((to - from) / every + 0.5))
			for k = 0, n do
				local u = n > 0 and k / n or 0
				local smp = K:at(samples, from + (to - from) * u)
				local h = hgt(u) * K:rand(0.9, 1.1)
				K:plate(group, FIN, smp.p + smp.U * smp.ru * 0.8, smp.U, smp.T, { h = h, w = h * 0.62, t = 0.15, n = 4, lean = lean + (k % 2 == 0 and 6 or -4), shift = 0.18 })
			end
		end
		fins("Head", neck, 0.1, neck.total - 0.1, 0.36, function(u) return 0.8 + 0.45 * u end, 30)
		fins("Body", torso, 0.15, torso.total - 0.15, 0.42, function(u) return 1.6 + 0.35 * math.sin(u * math.pi) - 0.4 * u end, 24)
		fins("Tail", tail, 0.15, tail.total - 0.6, 0.5, function(u) return 0.75 * (1 - u) + 0.2 end, 32)
		-- the jagged tail: rock spikes with molten tips jutting from both sides all the way down, a blade at the end
		for s = 0.3, tail.total - 0.25, 0.48 do
			local smp = K:at(tail, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(78) * x, 0.04)
				K:chain("Tail", { "Rock", "MagmaHot" }, pos, (nrm + smp.T * 0.6).Unit, smp.T, { n = 2, len = 0.5 * (1 - s / tail.total) + 0.18, w0 = 0.13, w1 = 0.08, bend = 0, tipH = 0.1 })
			end
		end
		local tip = K:at(tail, tail.total)
		K:chain("Tail", { "Rock", "Rock", "Flame" }, tip.p - tip.T * 0.1, tip.T, tip.U, { n = 3, len = 0.6, w0 = 0.16, w1 = 0.08, bend = 0 })
		-- molten seams over the flanks, neck and tail
		H.cracks(K, "Body", "Magma", torso, { rad(58), rad(-58), rad(118), rad(-118) }, 0.15, torso.total - 0.15, 0.26, 0.07, 0.09)
		H.cracks(K, "Head", "Magma", neck, { rad(62), rad(-62) }, 0.1, neck.total - 0.1, 0.24, 0.06, 0.08)
		H.cracks(K, "Tail", "Magma", tail, { rad(48), rad(-48) }, 0.15, tail.total * 0.55, 0.32, 0.06, 0.08)

		-- long legs in a charging stride, small hooked arms held tight
		local legs = H.bipedLegs(K, {
			pts = {
				{ 0.68, 3.0, 0.42, 0.58, 0.64 },
				{ 0.86, 2.36, 0.16, 0.5, 0.54 },
				{ 0.9, 1.86, -0.06, 0.38 },
				{ 0.9, 0.72, 0.5, 0.24 },
				{ 0.9, 0.22, 0.14, 0.2 },
			},
			stance = { -0.44, 0.44 },
			foot = Vector3.new(0.54, 0.26, 0.66),
			claw = { 0.34, 0.09 },
			muscle = "HideLight",
			armour = "Rock",
			scutes = "HideDark",
		})
		for g, leg in legs do
			local x = g == "LegL" and 1 or -1
			H.cracks(K, g, "Magma", leg[1], { rad(60) * x, rad(140) * x }, 0.1, leg[1].total - 0.1, 0.24, 0.06, 0.1)
			H.cracks(K, g, "MagmaHot", leg[3], { rad(100) * x }, 0.1, leg[3].total - 0.1, 0.26, 0.06, 0.08)
		end
		H.bipedArms(K, {
			pts = { { 0.6, 2.86, -0.98, 0.22 }, { 0.8, 2.46, -1.2, 0.17 }, { 0.72, 2.32, -1.6, 0.13 } },
			hand = Vector3.new(0.22, 0.14, 0.24),
			fwd = Vector3.new(0, -0.3, -1),
			claws = { n = 3, len = 0.3, w = 0.06 },
		})

		-- head: long and narrow, swept black horns, a molten maw
		local hd = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.52, 0.36, 0.82 },
			tip = { 0.42, 0.3, 0.34 },
			open = 20,
			teeth = { 0.11, 0.06 },
			brow = "Horn",
			browSize = { 0.34, 0.15, 0.4 },
			eye = { 0.17, 0.05 },
			cheek = 0.24,
		})
		for _, x in { 1, -1 } do
			K:chain("Head", { "Horn", "Horn", "Rock", "MagmaHot" }, hd.p(0.24 * x, hd.top - 0.04, -0.36), hd.v(0.3 * x, 0.35, 0.9), hd.v(1, 0, 0), { n = 4, len = 1.15, w0 = 0.17, w1 = 0.07, bend = 8 })
			K:block("Head", "Magma", hd.cf(0.4 * x, 0.18, -0.34, 0, -10 * x, 0), Vector3.new(0.04, 0.05, 0.5))
		end
	end,
}
