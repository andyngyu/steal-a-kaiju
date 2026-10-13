local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Legendary / ice: a hulking glacier-smasher. A bulky hunched body, long arms ending in huge ice-
-- sheathed claws, giant ice shards erupting from the shoulders, a battering ram of ice over the skull with curled ram
-- horns, a short deep jaw, cyan eyes.
local HEAD = CFrame.new(0, 3.78, -1.44) * CFrame.Angles(rad(-14), 0, 0)
local SKULL = { 1.06, 0.78, 0.78 }

return {
	Seed = 41,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = "4F6884",
		HideDark = "3A4F68",
		HideLight = "8BA6BE",
		Back = "202D3E",
		Belly = "DCE6EE",
		Belly2 = "BCCBD8",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Armour = { "B5DCF0", Material = "Ice" },
		ArmourLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Claw = { "CFEFFF", Material = "Ice" },
		ClawTip = { "E8F8FF", Material = "Ice" },
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
	},
	Joints = {
		Head = { 0, 3.66, -0.76 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegL = { 0.92, 2.94, 0.5 },
		LegR = { -0.92, 2.94, 0.5 },
		ArmL = { 1.02, 3.44, -0.82 },
		ArmR = { -1.02, 3.44, -0.82 },
		Tail = { 0, 2.82, 0.92 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 42, band = 92, every = 3 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 48, t = 0.14, wide = 1.15 }
		local plates = H.plates(0.74, nil, 0.14)
		local torso = K:tube("Body", {
			{ 0, 3.62, -0.72, rx = 1.12, ru = 0.98, rd = 1.04 },
			{ 0, 3.28, -0.1, rx = 1.22, ru = 1.02, rd = 1.12 },
			{ 0, 2.92, 0.52, rx = 1.06, ru = 0.9, rd = 0.92 },
			{ 0, 2.78, 0.98, rx = 0.84, ru = 0.72, rd = 0.66 },
		}, { step = 0.44, core = "HideDark", coreScale = 0.76, tile = plates, belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 3.82, -1.42, rx = 0.66, ru = 0.62, rd = 0.7 },
			{ 0, 3.78, -1.12, rx = 0.78, ru = 0.74, rd = 0.84 },
			{ 0, 3.66, -0.74, rx = 0.92, ru = 0.88, rd = 0.96 },
		}, { step = 0.36, core = "HideDark", coreScale = 0.76, tile = H.plates(0.66, nil, 0.13), belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 2.84, 0.88, rx = 0.74, ru = 0.68, rd = 0.62 },
			{ -0.04, 2.62, 1.58, rx = 0.54, ru = 0.5, rd = 0.46 },
			{ -0.24, 2.32, 2.18, rx = 0.38, ru = 0.35, rd = 0.32 },
			{ -0.6, 2.06, 2.6, rx = 0.24, ru = 0.22, rd = 0.2 },
			{ -1.0, 1.92, 2.8, rx = 0.12, ru = 0.12, rd = 0.11 },
		}, { step = 0.38, core = "HideDark", coreScale = 0.76, tile = H.plates(0.56, 5), belly = belly, color = skin, trim = 0.1 })
		local ICE = { "Ice", "IceDeep", "Ice", "IceGlow", "Ice", "IceDeep" }
		-- giant ice shards erupting from the shoulders, a jagged run of them down the back, an ice club on the tail
		for _, x in { 1, -1 } do
			local smp = K:at(torso, 0.35)
			local pos, nrm = K:surface(smp, rad(50) * x, 0.12)
			H.crystal(K, "Body", ICE, pos, (nrm + smp.U * 0.5 + smp.T * 0.3).Unit, 1.7, 6, 28)
		end
		H.crystalRidge(K, "Body", torso, { from = 0.75, to = torso.total - 0.2, every = 0.46, size = function(u) return 0.9 - 0.3 * u end, count = 3, keys = ICE, lean = 28 })
		H.crystalRidge(K, "Tail", tail, { from = 0.2, to = tail.total - 0.4, every = 0.42, size = function(u) return 0.6 * (1 - u) + 0.2 end, count = 3, keys = ICE, lean = 32 })
		local tip = K:at(tail, tail.total)
		H.crystal(K, "Tail", ICE, tip.p, (tip.T + tip.U * 0.3).Unit, 0.7, 5, 40)
		H.studs(K, "Body", torso, { rad(86), rad(-86) }, 0.55, 0.22, 0.4, torso.total - 0.3, { "Ice", "IceDeep" })

		-- long arms that reach down to the knees, ice gauntlets, huge claws
		local arms = H.bipedArms(K, {
			pts = { { 1.02, 3.46, -0.82, 0.42 }, { 1.52, 2.62, -1.0, 0.34 }, { 1.44, 1.64, -1.36, 0.28 } },
			hand = Vector3.new(0.5, 0.32, 0.48),
			fwd = Vector3.new(0, -0.55, -1),
			claws = { n = 3, len = 0.66, w = 0.14, spread = 0.36, fan = 24, curl = 34 },
		})
		for g, arm in arms do
			local x = g == "ArmL" and 1 or -1
			for i, f in { 0.45, 0.78 } do
				K:tile(g, i == 1 and "Armour" or "ArmourLight", K:at(arm[2], arm[2].total * f), rad(-10) * x, 0.62, 0.5, 0.15, 10, 3, 0.25)
			end
			local el = K:at(arm[1], arm[1].total)
			local pos, nrm = K:surface(el, rad(160) * x, 0.05)
			H.crystal(K, g, { "Ice", "IceDeep" }, pos, (nrm + Vector3.new(0, 0.3, 0.6)).Unit, 0.55, 3, 20)
		end
		H.bipedLegs(K, {
			pts = {
				{ 0.92, 2.96, 0.5, 0.72, 0.78 },
				{ 1.12, 2.3, 0.22, 0.62, 0.66 },
				{ 1.18, 1.78, 0.0, 0.46 },
				{ 1.18, 0.72, 0.52, 0.3 },
				{ 1.18, 0.22, 0.16, 0.24 },
			},
			stance = { -0.1, 0.16 },
			foot = Vector3.new(0.7, 0.3, 0.78),
			toe = { 0.2, 0.42 },
			claw = { 0.36, 0.1 },
			footCore = "Back",
			armour = "Armour",
			scutes = "HideDark",
		})

		-- head: short and deep under a battering ram of ice, curled ram horns of ice
		local hd = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.84, 0.58, 0.5 },
			tip = { 0.74, 0.5, 0.3 },
			open = 16,
			teeth = { 0.13, 0.07 },
			brow = "Armour",
			browSize = { 0.48, 0.2, 0.42 },
			eye = { 0.19, 0.055 },
			cheek = 0.34,
		})
		local top = hd.top
		K:block("Head", "Armour", hd.cf(0, top + 0.12, -0.42, -8, 0, 0), Vector3.new(1.14, 0.42, 0.92))
		K:block("Head", "ArmourLight", hd.cf(0, top + 0.02, -0.98, -34, 0, 0), Vector3.new(0.92, 0.36, 0.52))
		K:block("Head", "IceDeep", hd.cf(0, top + 0.36, -0.3, -12, 0, 0), Vector3.new(0.62, 0.22, 0.6))
		for _, x in { 1, -1 } do
			H.curve(K, "Head", { "IceDeep", "Ice", "Ice", "ArmourLight" }, {
				hd.p(0.48 * x, top + 0.14, -0.2),
				hd.p(0.86 * x, top + 0.2, 0.08),
				hd.p(1.08 * x, top - 0.22, 0.06),
				hd.p(1.0 * x, top - 0.56, -0.28),
				hd.p(0.76 * x, top - 0.56, -0.52),
			}, 0.28, 0.1, 0.18)
		end
	end,
}
