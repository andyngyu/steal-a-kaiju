local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Uncommon / poison: a fungus boar. A heavy wild boar, the shoulders a high bristling hump, the head
-- slung low, short stout legs on cloven hooves, and a grove of poison mushrooms growing out of its back (purple and
-- magenta caps, glowing gills, pale spots) in a carpet of moss. Face: a long wedge head under a heavy brow, small lime
-- eyes, a broad snout, and two pairs of curved tusks (the uppers sweeping up past the eyes).
local HEAD = CFrame.new(0, 1.18, -1.42) * CFrame.Angles(rad(-18), 0, 0)
local HINGE = Vector3.new(0, -0.16, -0.2)

return {
	Seed = 409,
	Vary = 0.06,
	Gait = "Trot",
	Emotes = { "Look", "Paw", "Wiggle" },
	Palette = {
		Hide = "5A4232",
		HideDark = "3E2C20",
		HideLight = "7A5E46",
		Back = "241812",
		Belly = "8E785E",
		Belly2 = "7A664E",
		Bristle = "1E1610",
		Moss = "3E6A2A",
		MossLight = "5A8A34",
		Stem = "E2D6B8",
		Cap = "7A2C96",
		CapDark = "5A1E74",
		Cap2 = "A8306E",
		Cap2Dark = "7E2052",
		CapSpot = "F2DEFF",
		Gill = { "C77DFF", Neon = true },
		Gill2 = { "FF6FC8", Neon = true },
		Tusk = "EDE2C4",
		TuskBase = "B8A888",
		Tooth = "E8DFC4",
		Mouth = "4A1A20",
		Eye = { "C6FF3A", Neon = true },
		Socket = "100C08",
		Claw = "1E1612",
		ClawTip = "4A3A2C",
	},
	Joints = {
		Head = { 0, 1.32, -0.98 },
		Jaw = HEAD * HINGE,
		EarL = HEAD * Vector3.new(0.3, 0.36, 0.0),
		EarR = HEAD * Vector3.new(-0.3, 0.36, 0.0),
		LegFL = { 0.5, 1.2, -0.56 },
		LegFR = { -0.5, 1.2, -0.56 },
		LegBL = { 0.5, 1.2, 0.78 },
		LegBR = { -0.5, 1.2, 0.78 },
		Tail = { 0, 1.42, 1.18 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 36, band = 82, flank = 112, every = 3 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }
		-- a barrel body rising to a high hump over the shoulders
		local body = K:tube("Body", {
			{ 0, 1.42, -0.86, rx = 0.66, ru = 0.82, rd = 0.62 },
			{ 0, 1.5, -0.2, rx = 0.78, ru = 0.84, rd = 0.7 },
			{ 0, 1.42, 0.52, rx = 0.74, ru = 0.66, rd = 0.68 },
			{ 0, 1.36, 1.08, rx = 0.58, ru = 0.52, rd = 0.52 },
		}, { step = 0.32, core = "Hide", coreScale = 0.8, tile = H.fur(0.42, nil, 0.44, 14), belly = belly, color = skin })
		K:tube("Body", {
			{ 0, 1.42, -0.62, rx = 0.62, ru = 0.72, rd = 0.6 },
			{ 0, 1.24, -1.12, rx = 0.46, ru = 0.5, rd = 0.48 },
		}, { step = 0.26, core = "Hide", coreScale = 0.85, tile = H.fur(0.38, nil, 0.4, 14), color = skin })
		-- a bristling mane down the hump
		K:ridge("Body", body, { from = 0.0, to = body.total * 0.55, every = 0.14, height = function(u) return 0.36 - u * 0.18 end, thick = 0.09, key = "Bristle", lean = 50, jitter = 14, sink = 0.92 })
		-- moss over the back and the mushroom grove growing out of it
		for s = 0.3, body.total - 0.2, 0.32 do
			local smp = K:at(body, s)
			for _, th in { -24, 0, 24 } do
				K:tile("Body", (math.floor(s * 10) + th) % 2 == 0 and "Moss" or "MossLight", smp, rad(th + K:rand(-6, 6)), 0.4, 0.4, 0.08, 4, 6, 0.2)
			end
		end
		local function shroom(base, nrm, h, r, cap, capDark, gill)
			local tilt = (nrm + Vector3.new(K:rand(-0.2, 0.2), 0, K:rand(-0.2, 0.2))).Unit
			local X = tilt:Cross(Vector3.zAxis).Unit
			K:block("Body", "Stem", CFrame.fromMatrix(base + tilt * h / 2, X, tilt), Vector3.new(r * 0.36, h, r * 0.36))
			local top = base + tilt * h
			local F = CFrame.fromMatrix(top, X, tilt)
			K:block("Body", gill, F * CFrame.new(0, -0.02, 0), Vector3.new(r * 1.8, 0.05, r * 1.8))
			K:block("Body", capDark, F * CFrame.new(0, r * 0.12, 0), Vector3.new(r * 2, r * 0.26, r * 2))
			K:block("Body", capDark, F * CFrame.new(0, r * 0.12, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(r * 1.8, r * 0.24, r * 1.8))
			K:block("Body", cap, F * CFrame.new(0, r * 0.34, 0) * CFrame.Angles(0, rad(22), 0), Vector3.new(r * 1.5, r * 0.26, r * 1.5))
			K:block("Body", cap, F * CFrame.new(0, r * 0.52, 0) * CFrame.Angles(0, rad(67), 0), Vector3.new(r * 0.9, r * 0.2, r * 0.9))
			for k = 0, 2 do
				local a = k / 3 * math.pi * 2 + K:rand(0, 1)
				K:block("Body", "CapSpot", F * CFrame.new(math.cos(a) * r * 0.55, r * 0.38, math.sin(a) * r * 0.55) * CFrame.Angles(0, a, 0), Vector3.new(r * 0.22, r * 0.06, r * 0.22))
			end
		end
		for i, m in { { 0.32, -18, 0.62, 0.3 }, { 0.5, 22, 0.86, 0.42 }, { 0.8, -6, 1.06, 0.5 }, { 1.06, 26, 0.6, 0.3 }, { 1.22, -26, 0.74, 0.36 }, { 1.5, 4, 0.5, 0.26 }, { 0.98, 52, 0.36, 0.2 }, { 0.66, -50, 0.4, 0.22 } } do
			local smp = K:at(body, m[1])
			local pos, nrm = K:surface(smp, rad(m[2]), 0.05)
			local pink = i % 3 == 0
			shroom(pos, (nrm + Vector3.yAxis * 0.6).Unit, m[3], m[4], pink and "Cap2" or "Cap", pink and "Cap2Dark" or "CapDark", pink and "Gill2" or "Gill")
		end
		-- a short tail with a bristle tuft
		K:tube("Tail", { { 0, 1.5, 1.14, rx = 0.08 }, { 0, 1.2, 1.36, rx = 0.06 } }, { step = 0.16, core = "HideDark", coreScale = 0.95 })
		K:chain("Tail", { "Bristle", "Bristle" }, Vector3.new(0, 1.18, 1.38), Vector3.new(0, -0.8, 0.5).Unit, Vector3.xAxis, { n = 2, len = 0.26, w0 = 0.12, w1 = 0.07, tip = false, depth = 1.6, bend = 0 })
		-- short stout legs on cloven hooves
		local function limb(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			for _, L in { { "LegF", -0.56, -0.62, 0.36 }, { "LegB", 0.78, 0.66, 0.42 } } do
				local g = L[1] .. (x == 1 and "L" or "R")
				H.quadLeg(K, g, {
					{ 0.5 * x, 1.24, L[2], L[4] },
					{ 0.56 * x, 0.7, L[3], L[4] * 0.74 },
					{ 0.56 * x, 0.24, L[2] - 0.02, L[4] * 0.6 },
				}, { step = 0.26, cores = { "Hide", "HideDark" }, tiles = { H.fur(0.3, 5, 0.34, 14), nil }, color = limb, foot = { size = Vector3.new(0.34, 0.22, 0.36), key = "Back" }, toes = 2, claw = { len = 0.14, w = 0.12, curl = 10 } })
			end
		end

		-- the head: a long wedge under a heavy brow, small eyes, a broad snout, two pairs of curved tusks
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.14, -0.2), Vector3.new(0.72, 0.62, 0.62))
		K:block("Head", "Hide", hcf(0, 0.04, -0.7), Vector3.new(0.56, 0.48, 0.62))
		K:block("Head", "Hide", hcf(0, 0.04, -0.7, 0, 0, 45), Vector3.new(0.42, 0.42, 0.56))
		K:block("Head", "HideDark", hcf(0, -0.04, -1.06), Vector3.new(0.42, 0.34, 0.3))
		K:block("Head", "HideDark", hcf(0, 0.1, -1.0, -20, 0, 0), Vector3.new(0.38, 0.12, 0.34))
		-- a small hard snout tip angled down, slit nostrils
		K:block("Head", "Back", hcf(0, -0.08, -1.22, 24, 0, 0), Vector3.new(0.3, 0.22, 0.08))
		for _, x in { 1, -1 } do
			K:block("Head", "Socket", hcf(0.07 * x, -0.06, -1.26, 24, 0, 30 * x), Vector3.new(0.03, 0.1, 0.04))
		end
		K:block("Head", "Mouth", hcf(0, -0.2, -0.72), Vector3.new(0.44, 0.04, 0.64))
		-- a heavy brow and bristles over the skull
		K:block("Head", "Back", hcf(0, 0.44, -0.36, -14, 0, 0), Vector3.new(0.66, 0.14, 0.36))
		K:ridge("Head", K:path({ { 0, 0.62 + 1.18, -1.32 + 0.0, rx = 0.2 }, { 0, 0.5 + 1.18, -0.92, rx = 0.2 } }, 0.12), { every = 0.1, height = 0.24, thick = 0.08, key = "Bristle", lean = 60, jitter = 12, sink = 0 })
		for _, x in { 1, -1 } do
			K:block("Head", "Back", hcf(0.26 * x, 0.34, -0.5, -6, -16 * x, 22 * x), Vector3.new(0.3, 0.13, 0.32))
			H.eye(K, "Head", hcf(0.31 * x, 0.22, -0.56, 0, -34 * x, 16 * x), 0.18, 0.05)
			K:block("Head", "HideLight", hcf(0.32 * x, -0.04, -0.32, 0, -10 * x, 6 * x), Vector3.new(0.16, 0.4, 0.42))
			-- upper tusks sweeping up and back past the eyes, lower tusks hooking up from the jaw
			H.curve(K, "Head", { "TuskBase", "Tusk", "Tusk" }, { hp(0.24 * x, -0.12, -0.96), hp(0.44 * x, 0.0, -1.1), hp(0.56 * x, 0.32, -1.02), hp(0.52 * x, 0.58, -0.78) }, 0.13, 0.05, 0.12)
			-- small ears laid back
			local g = x == 1 and "EarL" or "EarR"
			K:chain(g, { "HideDark", "Bristle" }, hp(0.3 * x, 0.36, 0.0), hv(0.6 * x, 0.6, 0.6), hv(0, 0, 1), { n = 2, len = 0.32, w0 = 0.2, w1 = 0.1, depth = 0.5, bend = 0 })
		end
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-14), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.46), Vector3.new(0.48, 0.18, 0.84))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.17, -0.42), Vector3.new(0.38, 0.04, 0.7))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.48), Vector3.new(0.38, 0.04, 0.72))
		for _, x in { 1, -1 } do
			H.curve(K, "Jaw", { "TuskBase", "Tusk" }, { JAW * Vector3.new(0.18 * x, 0, -0.76), JAW * Vector3.new(0.3 * x, 0.24, -0.86), JAW * Vector3.new(0.34 * x, 0.46, -0.74) }, 0.1, 0.04, 0.1)
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.18 * x, 0, -0.2), JAW * Vector3.new(0.17 * x, 0, -0.6), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.04)
		end
	end,
}
