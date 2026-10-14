local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Uncommon / fire (accent: bright orange): a volcanic toad. Squat and broad, rust-red warty hide studded
-- with glowing ember warts and split by magma seams, a glowing belly,
-- swollen glowing glands behind the eyes, ember eyes on raised turrets under horned brows, a huge wide jaw, heavy
-- folded hind legs ready to spring.
return {
	Seed = 103,
	Vary = 0.04,
	Gait = "Hop",
	Emotes = { "BigHop", "Look" },
	Palette = {
		Hide = { "8C3424", Material = "Basalt" },
		HideDark = { "622418", Material = "Basalt" },
		HideLight = { "B4523A", Material = "Basalt" },
		Back = { "44190F", Material = "Basalt" },
		Belly = { "FF6A10", Neon = true },
		Belly2 = { "B04A1C", Material = "Basalt" },
		Ember = { "FF6A10", Neon = true },
		Magma = { "FF4A0E", Neon = true },
		Armour = { "5A3428", Material = "Basalt" },
		ArmourLight = { "7A4A36", Material = "Basalt" },
		Tooth = "E2D2B4",
		Mouth = { "C8380C", Neon = true },
		Eye = { "FFC233", Neon = true },
		Socket = "0C0909",
		Claw = "151214",
		ClawTip = "6A5A50",
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
			{ 0, 1.34, -0.66, rx = 0.98, ru = 0.72, rd = 0.6 },
			{ 0, 1.46, 0.08, rx = 1.2, ru = 0.86, rd = 0.68 },
			{ 0, 1.3, 0.78, rx = 0.98, ru = 0.74, rd = 0.6 },
			{ 0, 1.14, 1.08, rx = 0.62, ru = 0.5, rd = 0.42 },
		}, { step = 0.4, core = "Hide", coreScale = 0.74, tile = H.plates(0.6, nil, 0.13), belly = { key = "Belly", key2 = "Belly2", arc = 56, t = 0.12, wide = 1.1 }, color = H.skin({ stripe = 36, band = 90, flank = 112, every = 2 }) })
		-- warts: basalt knobs and glowing embers all over the back
		H.studs(K, "Body", body, { 0, rad(34), rad(-34), rad(66), rad(-66) }, 0.42, 0.24, 0.25, body.total - 0.25, { "HideLight", "Ember", "Armour", "HideLight", "Ember" })
		H.cracks(K, "Body", "Ember", body, { rad(22), rad(-22), rad(58), rad(-58), rad(96), rad(-96) }, 0.15, body.total - 0.15, 0.24, 0.09, 0.09)
		-- front legs: short, elbows out
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.8 * x, 1.06, -0.52, 0.3 },
				{ 1.12 * x, 0.66, -0.62, 0.24 },
				{ 1.08 * x, 0.24, -0.78, 0.2 },
			}, { step = 0.26, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.5, 0.18, 0.5), key = "HideDark" }, yaw = 24, toes = 4, claw = { len = 0.14, w = 0.06 } })
			-- hind legs: a big thigh folded forward, shin folded back, a long webbed foot
			local g = x == 1 and "LegBL" or "LegBR"
			local leg = H.limb(K, g, {
				{ 0.86 * x, 1.1, 0.56, 0.46 },
				{ 1.3 * x, 0.72, -0.08, 0.38 },
				{ 1.26 * x, 0.32, 0.66, 0.26 },
			}, { step = 0.3, cores = { "Hide", "HideDark" } })
			H.studs(K, g, leg[1], { rad(60) * x, rad(110) * x }, 0.3, 0.2, 0.15, leg[1].total - 0.15, { "Ember", "HideLight" })
			K:block(g, "HideDark", CFrame.new(1.28 * x, 0.1, 0.28) * CFrame.Angles(0, rad(-16 * x), 0), Vector3.new(0.5, 0.18, 0.86))
			H.claws(K, g, Vector3.new(1.18 * x, 0.08, -0.14), CFrame.Angles(0, rad(-16 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1)), Vector3.xAxis, { n = 4, spread = 0.4, fan = 40, droop = 0.4, len = 0.18, w = 0.06, curl = 24 })
		end

		-- head: wide and flat, a huge mouth line, eye turrets with horned brows, glowing glands
		local HEAD = CFrame.new(0, 1.42, -0.92) * CFrame.Angles(rad(-4), 0, 0)
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.08, -0.3), Vector3.new(1.7, 0.54, 0.84))
		K:block("Head", "Hide", hcf(0, 0.02, -0.68), Vector3.new(1.36, 0.44, 0.42))
		K:block("Head", "Belly", hcf(0, -0.24, -0.36), Vector3.new(1.56, 0.16, 0.84))
		-- the glowing throat sac
		K:block("Head", "Ember", hcf(0, -0.42, -0.3), Vector3.new(0.9, 0.3, 0.6))
		K:block("Head", "Belly", hcf(0, -0.36, -0.3), Vector3.new(1.0, 0.3, 0.5))
		K:block("Head", "Mouth", hcf(0, -0.15, -0.6), Vector3.new(1.16, 0.06, 0.36))
		K:block("Head", "Back", hcf(0, 0.32, -0.34, -6, 0, 0), Vector3.new(0.7, 0.1, 0.6))
		for _, x in { 1, -1 } do
			K:block("Head", "HideDark", hcf(0.5 * x, 0.42, -0.42), Vector3.new(0.42, 0.42, 0.44))
			K:block("Head", "Armour", hcf(0.5 * x, 0.66, -0.48, -12, -10 * x, 18 * x), Vector3.new(0.52, 0.12, 0.5))
			H.eye(K, "Head", hcf(0.52 * x, 0.46, -0.65, 0, -18 * x, 12 * x), 0.22, 0.06)
			K:chain("Head", { "Armour", "ArmourLight", "Ember" }, hp(0.66 * x, 0.66, -0.3), hv(0.7 * x, 0.6, 0.5), hv(0, 0, 1), { n = 3, len = 0.6, w0 = 0.16, w1 = 0.08, bend = 0 })
			K:block("Head", "Ember", hcf(0.66 * x, 0.2, -0.06, 0, -20 * x, 0), Vector3.new(0.2, 0.26, 0.42))
			H.teeth(K, "Head", "Tooth", hp(0.52 * x, -0.14, -0.62), hp(0.18 * x, -0.14, -0.8), 4, hv(0, -1, 0), hv(0, 0, 1), 0.07, 0.04)
		end
		-- a sloped snout over a wide, grim mouth line; ember warts across the skull
		K:block("Head", "HideDark", hcf(0, 0.2, -0.8, 26, 0, 0), Vector3.new(1.14, 0.12, 0.34))
		K:block("Head", "Mouth", hcf(0, -0.12, -0.9), Vector3.new(1.2, 0.05, 0.04))
		H.teeth(K, "Head", "Tooth", hp(-0.46, -0.12, -0.9), hp(0.46, -0.12, -0.9), 8, hv(0, -1, 0), hv(0, 0, 1), 0.06, 0.04)
		for k, p in { { 0.18, 0.36, -0.3 }, { -0.22, 0.36, -0.18 }, { 0.0, 0.38, -0.06 }, { 0.3, 0.32, -0.6 }, { -0.32, 0.32, -0.62 } } do
			K:block("Head", k % 2 == 0 and "Ember" or "HideLight", hcf(p[1], p[2], p[3], K:rand(-20, 20), K:rand(0, 90), K:rand(-20, 20)), Vector3.new(0.16, 0.12, 0.16))
		end
		K:block("Head", "Socket", hcf(0.12, 0.12, -0.87), Vector3.new(0.06, 0.05, 0.04))
		K:block("Head", "Socket", hcf(-0.12, 0.12, -0.87), Vector3.new(0.06, 0.05, 0.04))
	end,
}
