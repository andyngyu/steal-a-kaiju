local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Legendary / void: the astrodon, a sauropod the size of a moon. A towering long-necked giant on four
-- pillar legs, its hide deep violet speckled with stars like a night sky, darker down the back, a pale lavender belly.
-- A row of tall crystal plates runs up its spine and neck. A wide planetary ring of gold bands floats round it, tilted
-- steeply and well clear of the body, three small moons and chunks of rock riding on it. A long sweeping tail. Head: a
-- small heavy skull held high, a brow ridge over glowing gold eyes, peg teeth, crystal spikes on the crown.
local HEAD = CFrame.new(0, 5.52, -2.86) * CFrame.Angles(rad(-12), 0, 0)
local RING_C = Vector3.new(0, 3.0, 0.4)
-- tilted 28 degrees (the back of the ring up, the front down under the neck) and rolled a little
local RING_TILT = CFrame.new(RING_C) * CFrame.Angles(rad(-28), 0, rad(8))
local RING_R = 3.4

return {
	Seed = 741,
	Vary = 0.04,
	Scale = 1.0,
	Gait = "Amble",
	Emotes = { "Look", "Trumpet", "Wiggle" },
	Palette = {
		Hide = { "4E3A86", Material = "Slate" },
		HideDark = { "36286A", Material = "Slate" },
		HideLight = { "6E5AAE", Material = "Slate" },
		Back = { "28205A", Material = "Slate" },
		Belly = "B0A2DA",
		Belly2 = "9C8ECA",
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		CrystalGlow = { "C870FF", Neon = true },
		Ring = "D8AC4C",
		RingLight = "F2D690",
		RingDark = "9A7428",
		Moon = { "A8A2B8", Material = "Basalt" },
		MoonDark = { "5E5872", Material = "Basalt" },
		Rock = { "6A6088", Material = "Basalt" },
		RockDark = { "443C5E", Material = "Basalt" },
		Star = { "FFF4FF", Neon = true },
		Tooth = "E8E2F0",
		Mouth = "3A1238",
		Eye = { "FFD86A", Neon = true },
		Socket = "07050C",
		Claw = "141018",
		ClawTip = "8A82A0",
	},
	Joints = {
		Head = { 0, 3.1, -1.1 },
		LegFL = { 0.76, 2.3, -0.8 },
		LegFR = { -0.76, 2.3, -0.8 },
		LegBL = { 0.74, 2.3, 1.0 },
		LegBR = { -0.74, 2.3, 1.0 },
		Tail = { 0, 2.6, 1.5 },
	},
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 70, flank = 106, every = 3, upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 44, t = 0.12, wide = 1.1 }
		local body = K:tube("Body", {
			{ 0, 2.9, -1.04, rx = 0.92, ru = 0.86, rd = 0.9 },
			{ 0, 2.86, -0.4, rx = 1.12, ru = 1.02, rd = 1.06 },
			{ 0, 2.8, 0.4, rx = 1.14, ru = 1.04, rd = 1.04 },
			{ 0, 2.7, 1.2, rx = 0.96, ru = 0.86, rd = 0.84 },
			{ 0, 2.6, 1.6, rx = 0.7, ru = 0.62, rd = 0.6 },
		}, { step = 0.4, core = "Hide", coreScale = 0.88, tile = H.plates(0.62, nil, 0.13), belly = belly, color = skin })
		-- the long neck sweeping up and forward to the head (runs head -> body so its scales lie back)
		local neck = K:tube("Head", {
			{ 0, 5.42, -2.72, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 4.9, -2.42, rx = 0.36, ru = 0.36, rd = 0.38 },
			{ 0, 4.2, -1.92, rx = 0.46, ru = 0.46, rd = 0.48 },
			{ 0, 3.5, -1.42, rx = 0.62, ru = 0.62, rd = 0.66 },
			{ 0, 3.0, -0.96, rx = 0.8, ru = 0.78, rd = 0.82 },
		}, { step = 0.32, core = "Hide", coreScale = 0.88, tile = H.plates(0.42, nil, 0.11), belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 2.62, 1.46, rx = 0.62, ru = 0.56, rd = 0.52 },
			{ 0.06, 2.3, 2.3, rx = 0.44, ru = 0.4, rd = 0.38 },
			{ 0.3, 1.84, 3.1, rx = 0.3, ru = 0.28, rd = 0.26 },
			{ 0.74, 1.4, 3.74, rx = 0.18, ru = 0.17, rd = 0.16 },
			{ 1.24, 1.16, 4.1, rx = 0.08, ru = 0.08, rd = 0.07 },
		}, { step = 0.34, core = "Hide", coreScale = 0.88, tile = H.plates(0.4, 6, 0.1), belly = belly, color = skin, trim = 0.1 })
		-- a night-sky hide: star specks scattered over the back and flanks
		for _, seg in { { "Body", body, 40 }, { "Head", neck, 16 }, { "Tail", tail, 12 } } do
			local g, smps, n = seg[1], seg[2], seg[3]
			for i = 1, n do
				local smp = K:at(smps, K:rand(0.1, smps.total - 0.1))
				local pos = K:surface(smp, rad(K:rand(-110, 110)), -0.14)
				local s = i % 6 == 0 and 0.13 or 0.08
				K:block(g, "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s, s, s))
			end
		end
		-- tall crystal plates up the spine and the neck, glowing at their roots
		local SHARDS = { "Crystal", "CrystalDark", "CrystalLight", "Crystal" }
		for _, seg in { { "Body", body, 0.3, body.total - 0.3, 0.42, 0.86 }, { "Head", neck, 0.4, neck.total - 0.4, 0.36, 0.6 }, { "Tail", tail, 0.2, tail.total * 0.55, 0.42, 0.54 } } do
			local g, smps, from, to, every, size = seg[1], seg[2], seg[3], seg[4], seg[5], seg[6]
			for s = from, to, every do
				local smp = K:at(smps, s)
				local pos, nrm = K:surface(smp, 0, 0.06)
				local f = g == "Tail" and (1 - s / smps.total) or 1
				H.crystal(K, g, SHARDS, pos, (nrm + smp.T * 0.25).Unit, size * f, 3, 20)
				K:block(g, "CrystalGlow", CFrame.new(pos) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.22, 0.1, 0.22) * f)
			end
		end
		-- the planetary ring: wide gold bands floating well clear of the body, tilted steeply, three moons and chunks
		-- of rock riding on it
		local function ringAt(a, r, h)
			return RING_TILT * Vector3.new(math.cos(a) * r, h or 0, math.sin(a) * r)
		end
		local up = RING_TILT:VectorToWorldSpace(Vector3.yAxis)
		for band, o in { { RING_R - 0.22, 0.4, "Ring", "RingDark" }, { RING_R + 0.22, 0.26, "RingLight", "Ring" } } do
			local R, w, k1, k2 = o[1], o[2], o[3], o[4]
			local N = 44
			for i = 0, N - 1 do
				local p0 = ringAt(i / N * math.pi * 2, R)
				local p1 = ringAt((i + 1) / N * math.pi * 2, R)
				K:block("Body", i % 3 == band % 2 and k2 or k1, CFrame.lookAt((p0 + p1) / 2, p1, up), Vector3.new(w, 0.1, (p1 - p0).Magnitude + 0.04))
			end
		end
		for i, o in { { 20, 0.95 }, { 150, 0.78 }, { 262, 0.62 } } do
			local m = ringAt(rad(o[1]), RING_R, 0.2)
			local s = o[2]
			K:block("Body", "Moon", CFrame.new(m) * CFrame.Angles(rad(20), rad(30), 0), Vector3.new(s, s, s))
			K:block("Body", "Moon", CFrame.new(m) * CFrame.Angles(rad(65), rad(75), rad(20)), Vector3.new(s * 0.9, s * 0.9, s * 0.9))
			K:block("Body", "MoonDark", CFrame.new(m + Vector3.new(s * 0.25, s * 0.25, -s * 0.36)), Vector3.new(s * 0.28, s * 0.16, s * 0.28))
			K:block("Body", "MoonDark", CFrame.new(m + Vector3.new(-s * 0.3, -s * 0.1, -s * 0.38)), Vector3.new(s * 0.2, s * 0.14, s * 0.2))
		end
		for i = 0, 9 do
			local a = rad(55 + i * 31 + K:rand(-8, 8))
			local r = RING_R + K:rand(-0.3, 0.3)
			local p = ringAt(a, r, K:rand(-0.05, 0.25))
			local s = K:rand(0.18, 0.32)
			K:block("Body", i % 2 == 0 and "Rock" or "RockDark", CFrame.new(p) * CFrame.Angles(rad(K:rand(0, 90)), rad(K:rand(0, 90)), rad(K:rand(0, 90))), Vector3.new(s, s * 0.8, s))
		end

		-- four huge pillar legs on round feet
		local function legSkin(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			for _, leg in { { x == 1 and "LegFL" or "LegFR", -0.8, 0.76 }, { x == 1 and "LegBL" or "LegBR", 1.0, 0.74 } } do
				local g, z, lx = leg[1], leg[2], leg[3]
				H.quadLeg(K, g, {
					{ lx * x, 2.36, z, 0.56 },
					{ (lx + 0.12) * x, 1.3, z - 0.04, 0.46 },
					{ (lx + 0.12) * x, 0.36, z - 0.06, 0.42 },
				}, { step = 0.3, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.4, 7, 0.1), H.plates(0.36, 7, 0.1) }, color = legSkin, foot = { size = Vector3.new(0.96, 0.3, 0.96), key = "HideDark" }, toes = 4, claw = { len = 0.16, w = 0.12, curl = 10 } })
				K:block(g, "Star", CFrame.new((lx + 0.12) * x + 0.3 * x, 1.0, z - 0.1) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.08, 0.08, 0.08))
			end
		end

		-- head: a small heavy skull held high, a brow ridge, glowing eyes, peg teeth
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, 1.3, function()
			K:block("Head", "Hide", hcf(0, 0.1, -0.24), Vector3.new(0.56, 0.44, 0.56))
			K:block("Head", "Hide", hcf(0, 0.08, -0.24, 0, 0, 45), Vector3.new(0.42, 0.42, 0.52))
			K:block("Head", "Back", hcf(0, 0.32, -0.3, -10, 0, 0), Vector3.new(0.42, 0.1, 0.46))
			K:block("Head", "Hide", hcf(0, -0.02, -0.6), Vector3.new(0.46, 0.3, 0.42))
			K:block("Head", "HideDark", hcf(0, 0.1, -0.62, -8, 0, 0), Vector3.new(0.3, 0.1, 0.4))
			K:block("Head", "Mouth", hcf(0, -0.15, -0.56), Vector3.new(0.4, 0.04, 0.4))
			K:block("Head", "Belly", hcf(0, -0.22, -0.48), Vector3.new(0.4, 0.1, 0.48))
			H.teeth(K, "Head", "Tooth", hp(-0.18, -0.14, -0.8), hp(0.18, -0.14, -0.8), 5, hv(0, -1, 0), hv(0, 0, 1), 0.08, 0.05)
			for _, x in { 1, -1 } do
				K:block("Head", "Back", hcf(0.18 * x, 0.3, -0.46, -8, -14 * x, 22 * x), Vector3.new(0.28, 0.12, 0.3))
				H.eye(K, "Head", hcf(0.26 * x, 0.16, -0.48, 0, -40 * x, 10 * x), 0.15, 0.055)
				K:block("Head", "Socket", hcf(0.1 * x, 0.06, -0.82), Vector3.new(0.06, 0.06, 0.04))
			end
			H.crystal(K, "Head", SHARDS, hp(0, 0.34, -0.14), hv(0, 1, 0.6), 0.34, 3, 22)
		end)
	end,
}
