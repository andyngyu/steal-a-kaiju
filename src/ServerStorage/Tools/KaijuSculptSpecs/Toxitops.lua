local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Legendary / poison: a venom ceratopsian. A massive horned dinosaur on pillar legs, its head carried
-- low behind a huge blooming frill: a fan of poison petals (purple and magenta, glowing lime veins and edges) over a
-- ring of bony spikes, glowing venom sacs at the petals' roots. Three great horns (two over the brows, one on the nose)
-- stained purple at the tips. Moss-green scaled hide, bark-brown armour scutes down the back and tail, glowing lime
-- venom veins, a pale belly. Face: a hooked beak dripping venom, a heavy brow over small lime eyes.
local HEAD = CFrame.new(0, 1.8, -1.86) * CFrame.Angles(rad(-14), 0, 0)
local HINGE = Vector3.new(0, -0.24, -0.4)

return {
	Seed = 433,
	Vary = 0.05,
	Scale = 1.1,
	Gait = "Amble",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Hide = { "5E7E40", Material = "Slate" },
		HideDark = { "40582E", Material = "Slate" },
		HideLight = { "82A258", Material = "Slate" },
		Back = { "5A4630", Material = "Wood" },
		Belly = "C2BC88",
		Belly2 = "A8A270",
		Scute = { "6A5A40", Material = "Slate" },
		ScuteLight = { "8E7C58", Material = "Slate" },
		Petal = "7A2CC0",
		PetalDark = "52208A",
		Petal2 = "B8308A",
		VeinGlow = { "B4FF3A", Neon = true },
		Horn = "E2D8B4",
		HornBase = "9A8C66",
		HornTip = "8A3CC0",
		Sac = { "9A3CE0", Neon = true },
		SacCore = { "B4FF3A", Neon = true },
		Drip = { "9DFF3A", Neon = true },
		Beak = "2E2620",
		Tooth = "E2DAC0",
		Mouth = { "7CF03A", Neon = true },
		Eye = { "C6FF3A", Neon = true },
		Socket = "0C1008",
		Claw = "262018",
		ClawTip = "8A8068",
	},
	Joints = {
		Head = { 0, 1.84, -1.24 },
		Jaw = HEAD * HINGE,
		LegFL = { 0.78, 1.52, -0.72 },
		LegFR = { -0.78, 1.52, -0.72 },
		LegBL = { 0.8, 1.66, 1.0 },
		LegBR = { -0.8, 1.66, 1.0 },
		Tail = { 0, 1.9, 1.5 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 40, band = 84, flank = 110, every = 2 })
		local crust = { w = 0.56, l = 0.38, t = 0.13, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }
		-- a massive body, the hips higher than the shoulders
		local body = K:tube("Body", {
			{ 0, 1.76, -1.08, rx = 0.94, ru = 0.86, rd = 0.88 },
			{ 0, 1.96, -0.3, rx = 1.1, ru = 1.04, rd = 0.98 },
			{ 0, 2.06, 0.52, rx = 1.08, ru = 1.02, rd = 0.94 },
			{ 0, 1.98, 1.26, rx = 0.82, ru = 0.76, rd = 0.68 },
		}, { step = 0.36, core = "HideDark", coreScale = 0.8, tile = crust, belly = belly, color = skin })
		-- bark armour scutes down the back in three rows, glowing venom veins down the flanks
		for s = 0.2, body.total - 0.1, 0.34 do
			local smp = K:at(body, s)
			for _, th in { 0, -32, 32 } do
				local pos, nrm = K:surface(smp, rad(th), 0.02)
				K:plate("Body", { "Scute", "ScuteLight", "HornTip" }, pos, nrm, smp.T, { h = th == 0 and 0.44 or 0.28, w = 0.46, t = 0.13, n = 3, lean = 24 })
			end
		end
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "VeinGlow", body, rad(80) * x, 0.1, body.total - 0.1, { width = 0.07, height = 0.08, lift = 0.02, wander = 16, forks = 2 })
		end
		-- a thick armoured tail
		local tail = K:tube("Tail", {
			{ 0, 1.92, 1.44, rx = 0.62, ru = 0.58, rd = 0.52 },
			{ 0, 1.7, 2.06, rx = 0.44, ru = 0.4, rd = 0.36 },
			{ -0.12, 1.32, 2.58, rx = 0.26, ru = 0.24, rd = 0.22 },
			{ -0.3, 0.96, 2.9, rx = 0.12, ru = 0.12, rd = 0.11 },
		}, { step = 0.3, core = "HideDark", coreScale = 0.84, tile = { w = 0.42, n = 5, l = 0.32, t = 0.12, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 }, belly = belly, color = skin, trim = 0.08 })
		K:ridge("Tail", tail, { to = tail.total - 0.2, every = 0.26, height = function(u) return 0.32 - u * 0.18 end, thick = 0.13, key = "Scute", tip = "HornTip", lean = 36, sink = 0.85 })
		-- the short thick neck
		K:tube("Head", {
			{ 0, 1.84, -1.76, rx = 0.56, ru = 0.56, rd = 0.56 },
			{ 0, 1.8, -1.36, rx = 0.74, ru = 0.72, rd = 0.74 },
			{ 0, 1.76, -0.96, rx = 0.86, ru = 0.82, rd = 0.84 },
		}, { step = 0.26, core = "HideDark", coreScale = 0.82, tile = crust, color = skin })
		-- pillar legs, broad feet, blunt hoof-claws
		local function limb(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.78 * x, 1.54, -0.72, 0.5 },
				{ 0.9 * x, 0.92, -0.82, 0.4 },
				{ 0.88 * x, 0.3, -0.74, 0.36 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, tiles = { crust, nil }, color = limb, foot = { size = Vector3.new(0.68, 0.28, 0.64), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.14, curl = 12 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.8 * x, 1.68, 1.0, 0.58 },
				{ 0.9 * x, 1.0, 0.84, 0.46 },
				{ 0.88 * x, 0.3, 1.02, 0.38 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, tiles = { crust, nil }, color = limb, foot = { size = Vector3.new(0.7, 0.28, 0.66), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.14, curl = 12 } })
		end

		-- head: a long skull with a hooked beak, three great horns, the blooming frill behind
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.12, -0.3), Vector3.new(0.9, 0.66, 0.74))
		K:block("Head", "Hide", hcf(0, 0.0, -0.86), Vector3.new(0.66, 0.54, 0.64))
		K:block("Head", "Hide", hcf(0, 0.0, -0.86, 0, 0, 45), Vector3.new(0.48, 0.48, 0.6))
		K:block("Head", "Back", hcf(0, 0.3, -0.62, -12, 0, 0), Vector3.new(0.6, 0.14, 0.72))
		K:block("Head", "Beak", hcf(0, -0.08, -1.3), Vector3.new(0.44, 0.42, 0.38))
		K:block("Head", "Beak", hcf(0, -0.26, -1.48, 30, 0, 0), Vector3.new(0.32, 0.24, 0.22))
		K:block("Head", "Mouth", hcf(0, -0.28, -0.9), Vector3.new(0.46, 0.04, 0.64))
		-- venom dripping from the beak
		for _, d in { { 0.12, 0.24 }, { -0.1, 0.32 }, { 0.02, 0.18 } } do
			K:block("Head", "Drip", CFrame.new(hp(d[1], -0.4 - d[2] / 2, -1.5)), Vector3.new(0.05, d[2], 0.05))
			K:block("Head", "Drip", CFrame.new(hp(d[1], -0.44 - d[2], -1.5)), Vector3.new(0.08, 0.08, 0.08))
		end
		for _, x in { 1, -1 } do
			K:block("Head", "HideLight", hcf(0.44 * x, -0.04, -0.34, 0, -10 * x, 6 * x), Vector3.new(0.2, 0.54, 0.6))
			-- a heavy brow ridge over small eyes
			K:block("Head", "Back", hcf(0.3 * x, 0.4, -0.56, -6, -14 * x, 22 * x), Vector3.new(0.36, 0.18, 0.36))
			H.eye(K, "Head", hcf(0.38 * x, 0.24, -0.62, 0, -36 * x, 14 * x), 0.14, 0.045)
			-- the great brow horns, sweeping forward
			H.curve(K, "Head", { "HornBase", "Horn", "Horn", "HornTip" }, { hp(0.32 * x, 0.44, -0.42), hp(0.48 * x, 1.04, -0.66), hp(0.54 * x, 1.56, -1.12), hp(0.44 * x, 1.82, -1.78) }, 0.3, 0.07, 0.14)
			K:spike("Head", "Horn", hp(0.5 * x, -0.1, -0.2), hv(1 * x, -0.2, 0.2), hv(0, 1, 0), 0.34, 0.12)
		end
		H.curve(K, "Head", { "HornBase", "Horn", "Horn", "HornTip" }, { hp(0, 0.24, -1.16), hp(0, 0.7, -1.36), hp(0, 1.08, -1.36), hp(0, 1.3, -1.2) }, 0.26, 0.07, 0.12)
		-- the frill: a ring of bony spikes, then a fan of poison petals over it, glowing veins and edges, venom sacs
		local N = 13
		for i = 0, N - 1 do
			local a = rad(-112 + 224 * i / (N - 1))
			local dir = hv(math.sin(a) * 1.15, math.cos(a) * 1.0 + 0.35, 0.42)
			local base = hp(math.sin(a) * 0.36, 0.24 + math.cos(a) * 0.24, 0.04)
			local len = 1.75 + math.cos(a) * 0.35
			local across = dir:Cross(hv(0, 0, -1)).Unit
			local nrm = across:Cross(dir).Unit
			if nrm:Dot(hv(0, 0, -1)) < 0 then
				nrm = -nrm
			end
			local key = i % 3 == 1 and "Petal2" or (i % 2 == 0 and "Petal" or "PetalDark")
			for k, seg in { { 0.18, 0.34 }, { 0.42, 0.62 }, { 0.68, 0.56 }, { 0.88, 0.3 } } do
				local c = base + dir * len * seg[1]
				K:block("Head", key, CFrame.fromMatrix(c, across, nrm), Vector3.new(seg[2], 0.08, len * 0.3))
			end
			-- the glowing vein down the middle and the glowing tip
			K:block("Head", "VeinGlow", CFrame.fromMatrix(base + dir * len * 0.5 + nrm * 0.045, across, nrm), Vector3.new(0.05, 0.03, len * 0.72))
			K:spike("Head", "VeinGlow", base + dir * len * 0.96, (dir + nrm * 0.3).Unit, across, 0.16, 0.06)
			-- bony spike behind it
			K:chain("Head", { "HornBase", "Horn" }, base - nrm * 0.06, (dir - nrm * 0.15).Unit, across, { n = 2, len = len * 0.62, w0 = 0.14, w1 = 0.08, bend = 0 })
			-- the venom sacs at the petals' roots
			if i % 2 == 1 then
				local c = base + dir * len * 0.2 + nrm * 0.1
				K:block("Head", "Sac", CFrame.fromMatrix(c, across, nrm) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.26, 0.14, 0.26))
				K:block("Head", "SacCore", CFrame.fromMatrix(c + nrm * 0.07, across, nrm), Vector3.new(0.12, 0.07, 0.12))
			end
		end
		-- the lower beak
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-14), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.1, -0.48), Vector3.new(0.56, 0.22, 0.84))
		K:block("Jaw", "Beak", JAW * CFrame.new(0, -0.08, -0.98), Vector3.new(0.36, 0.2, 0.26))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.21, -0.44), Vector3.new(0.44, 0.04, 0.7))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.52), Vector3.new(0.42, 0.04, 0.74))
		K:block("Jaw", "Drip", JAW * CFrame.new(0.08, -0.34, -1.02), Vector3.new(0.05, 0.22, 0.05))
	end,
}
