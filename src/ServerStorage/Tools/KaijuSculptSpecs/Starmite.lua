local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Common / void: the starmite, an alien hopper. Squat and broad on heavy folded hind legs, a void-black
-- hide flecked with tiny stars, a back of cracked lilac crystal shards with magenta void light leaking out of the cracks
-- between them, glowing seams down its flanks. Face: a wide flat head split by a huge fanged grin, a cluster of six
-- glowing magenta eyes on the brow, two antennae ending in starlight bulbs.
local HEAD = CFrame.new(0, 1.4, -0.92) * CFrame.Angles(rad(-4), 0, 0)

return {
	Seed = 701,
	Vary = 0.05,
	Scale = 1.0,
	Gait = "Hop",
	Emotes = { "BigHop", "Look" },
	Palette = {
		Hide = { "2A2040", Material = "Slate" },
		HideDark = { "17121F", Material = "Slate" },
		HideLight = { "463860", Material = "Slate" },
		Back = { "0E0B14", Material = "Slate" },
		Belly = { "3A2C58", Material = "Slate" },
		Belly2 = { "30244A", Material = "Slate" },
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		Star = { "FFF4FF", Neon = true },
		Void = { "E040FF", Neon = true },
		Tooth = "E8E2F0",
		Mouth = { "9A22C8", Neon = true },
		Eye = { "FF40E0", Neon = true },
		Socket = "07050C",
		Claw = "100C16",
		ClawTip = "C8B8E8",
	},
	Joints = {
		Head = { 0, 1.4, -0.62 },
		LegFL = { 0.8, 1.02, -0.52 },
		LegFR = { -0.8, 1.02, -0.52 },
		LegBL = { 0.86, 1.04, 0.56 },
		LegBR = { -0.86, 1.04, 0.56 },
	},
	Build = function(K)
		local body = K:tube("Body", {
			{ 0, 1.36, -0.66, rx = 0.96, ru = 0.74, rd = 0.6 },
			{ 0, 1.52, 0.08, rx = 1.14, ru = 0.9, rd = 0.68 },
			{ 0, 1.36, 0.78, rx = 0.94, ru = 0.76, rd = 0.6 },
			{ 0, 1.16, 1.08, rx = 0.6, ru = 0.5, rd = 0.42 },
		}, { step = 0.4, core = "HideDark", coreScale = 0.76, tile = H.plates(0.56, nil, 0.12), belly = { key = "Belly", key2 = "Belly2", arc = 56, t = 0.12, wide = 1.1 }, color = H.skin({ stripe = 40, band = 86, flank = 112, every = 2 }) })
		-- the cracked crystal back: shards breaking out along the top with void light glowing between them
		local SHARDS = { "Crystal", "CrystalDark", "CrystalLight", "Crystal" }
		for s = 0.25, body.total - 0.3, 0.32 do
			local smp = K:at(body, s)
			for _, th in { 0, rad(34), rad(-34) } do
				local pos, nrm = K:surface(smp, th + rad(K:rand(-6, 6)), 0.04)
				local size = (th == 0 and 0.66 or 0.48) * (1 - math.abs(s / body.total - 0.45) * 0.6)
				H.crystal(K, "Body", SHARDS, pos, (nrm + smp.T * 0.3).Unit, size, 3, 26)
			end
		end
		-- thick glowing void seams down the flanks, tiny stars flecked over the dark hide
		H.cracks(K, "Body", "Void", body, { rad(70), rad(-70), rad(100), rad(-100) }, 0.2, body.total - 0.2, 0.26, 0.1, 0.08)
		for i = 1, 18 do
			local smp = K:at(body, K:rand(0.2, body.total - 0.2))
			local pos = K:surface(smp, rad(K:rand(50, 130)) * (i % 2 == 0 and 1 or -1), -0.06)
			K:block("Body", "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.07, 0.07, 0.07))
		end
		-- front legs short with elbows out; hind legs folded, ready to spring
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.8 * x, 1.06, -0.52, 0.3 },
				{ 1.12 * x, 0.66, -0.62, 0.24 },
				{ 1.08 * x, 0.24, -0.78, 0.2 },
			}, { step = 0.26, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.5, 0.18, 0.5), key = "HideDark" }, yaw = 24, toes = 4, claw = { len = 0.2, w = 0.07, curl = 30 } })
			local g = x == 1 and "LegBL" or "LegBR"
			local leg = H.limb(K, g, {
				{ 0.86 * x, 1.12, 0.56, 0.46 },
				{ 1.3 * x, 0.74, -0.08, 0.38 },
				{ 1.26 * x, 0.32, 0.66, 0.26 },
			}, { step = 0.3, cores = { "Hide", "HideDark" } })
			H.cracks(K, g, "Void", leg[1], { rad(80) * x }, 0.1, leg[1].total - 0.1, 0.24, 0.08, 0.06)
			H.crystal(K, g, SHARDS, K:surface(K:at(leg[1], leg[1].total * 0.5), rad(20) * x, 0.04), Vector3.new(0.3 * x, 1, 0.3), 0.28, 2, 20)
			K:block(g, "HideDark", CFrame.new(1.28 * x, 0.1, 0.28) * CFrame.Angles(0, rad(-16 * x), 0), Vector3.new(0.5, 0.18, 0.86))
			H.claws(K, g, Vector3.new(1.18 * x, 0.08, -0.14), CFrame.Angles(0, rad(-16 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1)), Vector3.xAxis, { n = 4, spread = 0.4, fan = 40, droop = 0.4, len = 0.22, w = 0.07, curl = 24 })
		end

		-- head: wide and flat, a huge fanged grin, six eyes clustered on the brow
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.12, -0.3), Vector3.new(1.6, 0.56, 0.84))
		K:block("Head", "Hide", hcf(0, 0.06, -0.68), Vector3.new(1.3, 0.46, 0.42))
		K:block("Head", "Back", hcf(0, 0.38, -0.36, -6, 0, 0), Vector3.new(1.0, 0.12, 0.6))
		K:block("Head", "Belly", hcf(0, -0.2, -0.36), Vector3.new(1.46, 0.16, 0.84))
		-- the gaping grin, glowing deep inside, rows of long needle fangs
		K:block("Head", "Mouth", hcf(0, -0.1, -0.6), Vector3.new(1.2, 0.14, 0.36))
		K:block("Head", "Back", hcf(0, -0.1, -0.88), Vector3.new(1.24, 0.16, 0.06))
		H.teeth(K, "Head", "Tooth", hp(-0.54, -0.04, -0.86), hp(0.54, -0.04, -0.86), 10, hv(0, -1, -0.15), hv(1, 0, 0), 0.14, 0.05)
		H.teeth(K, "Head", "Tooth", hp(-0.5, -0.17, -0.84), hp(0.5, -0.17, -0.84), 9, hv(0, 1, -0.15), hv(1, 0, 0), 0.12, 0.05)
		for _, x in { 1, -1 } do
			H.fang(K, "Head", "Tooth", hp(0.42 * x, -0.04, -0.82), hv(0.05 * x, -1, -0.2), 0.3, 0.07)
			-- three eyes a side, the biggest at the front, under a heavy brow
			K:block("Head", "HideDark", hcf(0.34 * x, 0.42, -0.62, -10, -8 * x, 14 * x), Vector3.new(0.56, 0.14, 0.24))
			for k, o in { { 0.2, 0.28, -0.86, 0.24 }, { 0.48, 0.3, -0.8, 0.2 }, { 0.34, 0.16, -0.88, 0.15 } } do
				H.eye(K, "Head", hcf(o[1] * x, o[2], o[3], 0, -12 * x * k, 0), o[4], o[4] * 0.6)
			end
			-- antennae ending in starlight bulbs
			local base = hp(0.28 * x, 0.44, -0.3)
			local d = hv(0.4 * x, 1, 0.5)
			K:chain("Head", { "HideDark", "Hide", "HideLight" }, base, d, hv(0, 0, 1), { n = 3, len = 0.7, w0 = 0.08, w1 = 0.05, bend = -18, tip = false })
			local tip = base + d * 0.66 + hv(0, 0, 1) * 0.12
			K:block("Head", "Void", CFrame.new(tip) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.13, 0.13, 0.13))
		end
		-- a shard crown cracking out of the skull
		H.crystal(K, "Head", SHARDS, hp(0, 0.42, -0.2), hv(0, 1, 0.5), 0.36, 3, 24)
	end,
}
