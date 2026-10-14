local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Rare / poison: a mantis lizard. Reared up on two long legs like a praying mantis, a lean body pitched
-- steeply upright, a long thin neck, and two huge raptorial forelimbs folded and raised to strike, each ending in a
-- serrated scythe blade. Leaf-green armour plates edged in lime, dark joints, a pale belly, a short thick tail for
-- balance with leaf-shaped plates. Face: a triangular head, mandibles flared open, narrow lime eyes set wide under a
-- spiked brow, two whip antennae swept back.
local HEAD = CFrame.new(0, 4.02, -0.82) * CFrame.Angles(rad(-22), 0, 0)

return {
	Seed = 417,
	Vary = 0.05,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = "4C7A2A",
		HideDark = "2E4C1A",
		HideLight = "7AA03C",
		Back = "1E3214",
		Belly = "C4CC86",
		Belly2 = "A8B06C",
		Armour = "5E8E30",
		ArmourLight = "88B048",
		Edge = { "A8FF3A", Neon = true },
		Joint = "2A2018",
		Blade = "D8D2B0",
		BladeDark = "8E8460",
		Venom = { "B04CFF", Neon = true },
		Tooth = "E8E4C8",
		Mouth = "4A1A28",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0E1408",
		Claw = "241C14",
		ClawTip = "D0C8A0",
	},
	Joints = {
		Head = { 0, 3.66, -0.62 },
		Jaw = HEAD * Vector3.new(0, -0.08, -0.24),
		LegL = { 0.44, 2.2, 0.36 },
		LegR = { -0.44, 2.2, 0.36 },
		ArmL = { 0.44, 3.24, -0.5 },
		ArmR = { -0.44, 3.24, -0.5 },
		Tail = { 0, 2.16, 0.62 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 84, flank = 104, every = 2, bandKey = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 44, t = 0.1, wide = 1.1 }
		-- a lean body pitched steeply upright, segmented into armour bands
		local body = K:tube("Body", {
			{ 0, 3.34, -0.54, rx = 0.4, ru = 0.38, rd = 0.42 },
			{ 0, 2.86, -0.28, rx = 0.5, ru = 0.46, rd = 0.5 },
			{ 0, 2.4, 0.08, rx = 0.52, ru = 0.48, rd = 0.5 },
			{ 0, 2.16, 0.5, rx = 0.46, ru = 0.42, rd = 0.42 },
		}, { step = 0.26, ref = Vector3.xAxis, core = "HideDark", coreScale = 0.86, tile = H.plates(0.36, nil, 0.11), belly = belly, color = skin })
		-- armour bands: a raised plate with a lime edge every few rings
		for s = 0.12, body.total - 0.1, 0.3 do
			local smp = K:at(body, s)
			for k = -2, 2 do
				K:tile("Body", k % 2 == 0 and "Armour" or "ArmourLight", smp, rad(k * 30), 0.34, 0.16, 0.08, 12, 2, -0.4)
			end
			local pos, nrm = K:surface(smp, 0, -0.18)
			K:block("Body", "Edge", CFrame.fromMatrix(pos, smp.R, nrm), Vector3.new(0.5, 0.03, 0.04))
		end
		-- the long thin neck up to the head
		local neck = K:tube("Head", {
			{ 0, 3.98, -0.8, rx = 0.17, ru = 0.17, rd = 0.17 },
			{ 0, 3.74, -0.68, rx = 0.2, ru = 0.2, rd = 0.2 },
			{ 0, 3.42, -0.58, rx = 0.26, ru = 0.26, rd = 0.26 },
		}, { step = 0.16, core = "HideDark", coreScale = 0.95, tile = H.plates(0.2, 4, 0.08), color = skin })
		K:ridge("Head", neck, { every = 0.14, height = 0.12, thick = 0.05, key = "Armour", lean = 50, sink = 0.8 })
		-- the tail: short and thick, leaf-shaped plates down it
		local tail = K:tube("Tail", {
			{ 0, 2.16, 0.56, rx = 0.36, ru = 0.34, rd = 0.32 },
			{ 0, 1.86, 1.1, rx = 0.26, ru = 0.24, rd = 0.22 },
			{ 0.1, 1.42, 1.56, rx = 0.15, ru = 0.14, rd = 0.13 },
			{ 0.24, 1.08, 1.86, rx = 0.07, ru = 0.07, rd = 0.06 },
		}, { step = 0.24, core = "HideDark", coreScale = 0.88, tile = H.plates(0.28, 5, 0.09), belly = belly, color = skin, trim = 0.08 })
		for s = 0.1, tail.total - 0.2, 0.22 do
			local smp = K:at(tail, s)
			local pos, nrm = K:surface(smp, 0, 0.02)
			K:plate("Tail", { "Armour", "ArmourLight" }, pos, nrm, smp.T, { h = 0.3 * (1 - s / tail.total) + 0.08, w = 0.3, t = 0.06, n = 2, lean = 40 })
		end
		-- long mantis legs: high knees, thin shins, spurred, three claws
		H.bipedLegs(K, {
			pts = { { 0.44, 2.2, 0.36, 0.32, 0.36 }, { 0.62, 1.7, -0.08, 0.22 }, { 0.6, 0.78, 0.42, 0.12 }, { 0.6, 0.22, 0.26, 0.1 } },
			stance = { -0.12, 0.16 },
			foot = Vector3.new(0.32, 0.16, 0.42),
			toe = { 0.1, 0.26 },
			claw = { 0.2, 0.06 },
			core = "HideDark",
			muscle = "Armour",
			scutes = "Armour",
		})
		for _, x in { 1, -1 } do
			local g = x == 1 and "LegL" or "LegR"
			K:spike(g, "Joint", Vector3.new(0.66 * x, 1.7, -0.14), Vector3.new(0.2 * x, 0.3, -1).Unit, Vector3.xAxis, 0.22, 0.07)
		end
		-- the raptorial forelimbs: upper arm reaching up and forward, forearm folded back down, a serrated scythe blade
		for _, x in { 1, -1 } do
			local g = x == 1 and "ArmL" or "ArmR"
			local sh = Vector3.new(0.44 * x, 3.24, -0.5)
			local el = Vector3.new(0.66 * x, 3.86, -1.2)
			local wr = Vector3.new(0.6 * x, 3.0, -1.36)
			H.limb(K, g, { { sh.X, sh.Y, sh.Z, 0.17 }, { el.X, el.Y, el.Z, 0.15 }, { wr.X, wr.Y, wr.Z, 0.12 } }, { step = 0.2, cores = { "Hide", "Armour" } })
			K:block(g, "Joint", CFrame.new(el), Vector3.new(0.26, 0.26, 0.26))
			-- spines along the inner edge of the forearm
			for k = 1, 4 do
				local p = el:Lerp(wr, k / 5)
				K:spike(g, "BladeDark", p, Vector3.new(-0.3 * x, 0, -1).Unit, Vector3.yAxis, 0.16, 0.05)
			end
			-- the scythe: a long curved blade from the wrist sweeping forward and up, serrated, a venom groove
			local pts = { wr, wr + Vector3.new(0.02 * x, -0.2, -0.36), wr + Vector3.new(0.04 * x, -0.08, -0.84), wr + Vector3.new(0.04 * x, 0.32, -1.18) }
			H.curve(K, g, { "BladeDark", "Blade", "Blade" }, pts, 0.16, 0.05, 0.12)
			H.curve(K, g, { "Venom" }, { pts[2] + Vector3.new(0, 0.08, 0), pts[3] + Vector3.new(0, 0.08, 0) }, 0.05, 0.04, 0.12)
			for k = 1, 5 do
				local f = 0.2 + k * 0.13
				local p = (k < 3 and pts[2]:Lerp(pts[3], f * 1.6) or pts[3]:Lerp(pts[4], (f - 0.45) * 1.6))
				K:spike(g, "Blade", p, Vector3.new(0, 1, -0.3).Unit, Vector3.zAxis, 0.1, 0.035)
			end
		end

		-- head: triangular, mandibles flared, wide-set narrow eyes under a spiked brow, antennae swept back
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.06, -0.12), Vector3.new(0.72, 0.36, 0.42))
		K:block("Head", "Hide", hcf(0, 0.0, -0.42), Vector3.new(0.48, 0.3, 0.4))
		K:block("Head", "HideDark", hcf(0, -0.04, -0.66), Vector3.new(0.3, 0.24, 0.26))
		K:block("Head", "Armour", hcf(0, 0.22, -0.2, -10, 0, 0), Vector3.new(0.62, 0.1, 0.46))
		K:block("Head", "Mouth", hcf(0, -0.16, -0.5), Vector3.new(0.3, 0.04, 0.3))
		for _, x in { 1, -1 } do
			-- wide-set eye mounds with narrow slits
			K:block("Head", "HideDark", hcf(0.38 * x, 0.12, -0.14, 0, 0, 20 * x), Vector3.new(0.18, 0.22, 0.28))
			H.eye(K, "Head", hcf(0.44 * x, 0.14, -0.22, 0, -55 * x, 18 * x), 0.17, 0.05)
			K:spike("Head", "Armour", hp(0.3 * x, 0.3, -0.18), hv(0.5 * x, 0.8, 0.2), hv(0, 0, 1), 0.2, 0.06)
			-- antennae
			H.curve(K, "Head", { "Joint", "HideDark" }, { hp(0.12 * x, 0.24, -0.26), hp(0.3 * x, 0.6, 0.0), hp(0.46 * x, 0.8, 0.46), hp(0.56 * x, 0.82, 0.9) }, 0.04, 0.025, 0.14)
		end
		-- mandibles flared open (they open further on Roar)
		local JAW = HEAD * CFrame.new(0, -0.08, -0.24)
		for _, x in { 1, -1 } do
			K:chain("Jaw", { "HideDark", "Blade", "Blade" }, JAW * Vector3.new(0.14 * x, -0.04, -0.36), JAW:VectorToWorldSpace(Vector3.new(0.5 * x, -0.2, -1)).Unit, JAW:VectorToWorldSpace(Vector3.yAxis), { n = 3, len = 0.4, w0 = 0.09, w1 = 0.05, bend = 30 * x })
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.16 * x, -0.06, -0.42), JAW * Vector3.new(0.24 * x, -0.08, -0.62), 3, JAW:VectorToWorldSpace(Vector3.new(-x, 0, 0)), JAW:VectorToWorldSpace(Vector3.zAxis), 0.06, 0.03)
		end
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.12, -0.38), Vector3.new(0.24, 0.06, 0.3))
	end,
}
