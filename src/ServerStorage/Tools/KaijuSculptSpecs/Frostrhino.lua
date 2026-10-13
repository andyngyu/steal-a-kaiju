local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Rare / ice: a glacier rhino. A massive slate-blue body cased in plates of glacier ice along its
-- back and shoulders, a shaggy frost skirt, a shield of ice plates behind the head, two huge ice horns, small cyan
-- eyes buried under a heavy brow, pillar legs.
local HEAD = CFrame.new(0, 1.86, -1.34) * CFrame.Angles(rad(-14), 0, 0)

return {
	Seed = 97,
	Vary = 0.05,
	Gait = "Trot",
	Emotes = { "Look", "Paw" },
	Palette = {
		Hide = "617081",
		HideDark = "45515F",
		HideLight = "8C9BAB",
		Back = "2F3A47",
		Belly = "A9B5C1",
		Belly2 = "8E9BA8",
		Fur = "C9D4DE",
		FurDark = "9FAEBE",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Armour = { "B5DCF0", Material = "Ice" },
		ArmourLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "2B3542",
		ClawTip = "C9D7E4",
	},
	Joints = {
		Head = { 0, 1.92, -0.92 },
		EarL = HEAD * Vector3.new(0.34, 0.46, 0.02),
		EarR = HEAD * Vector3.new(-0.34, 0.46, 0.02),
		LegFL = { 0.58, 1.6, -0.58 },
		LegFR = { -0.58, 1.6, -0.58 },
		LegBL = { 0.58, 1.6, 0.92 },
		LegBR = { -0.58, 1.6, 0.92 },
		Tail = { 0, 1.96, 1.38 },
	},
	Parents = { EarL = "Head", EarR = "Head" },
	Build = function(K)
		local body = K:tube("Body", {
			{ 0, 1.96, -0.86, rx = 0.82, ru = 0.86, rd = 0.78 },
			{ 0, 2.06, -0.12, rx = 1.0, ru = 0.94, rd = 0.86 },
			{ 0, 1.96, 0.72, rx = 0.96, ru = 0.86, rd = 0.84 },
			{ 0, 1.86, 1.3, rx = 0.74, ru = 0.7, rd = 0.62 },
		}, { step = 0.36, core = "Hide", coreScale = 0.74, tile = H.plates(0.5, nil, 0.13), belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }, color = H.skin({ stripe = 36, band = 84, flank = 108, every = 3 }) })
		-- glacier plates along the back and shoulders, a hump of ice over the withers
		for i, s in { 0.2, 0.52, 0.84 } do
			local smp = K:at(body, s)
			for _, th in { 38, -38, 70, -70 } do
				K:tile("Body", (i + math.abs(th)) % 2 == 0 and "ArmourLight" or "Armour", smp, rad(th), 0.6 - i * 0.06, 0.56, 0.16, 16, 4, 0.25)
			end
		end
		H.crystalRidge(K, "Body", body, { from = 0.2, to = body.total * 0.45, every = 0.36, size = function(u) return 0.65 - u * 0.3 end, count = 4, keys = { "Ice", "IceDeep", "IceGlow", "Ice" }, lean = 30 })
		-- a shaggy frost skirt hanging off the flanks
		for s = 0.2, body.total - 0.2, 0.3 do
			local smp = K:at(body, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(112) * x, 0.05)
				K:chain("Body", { "Fur", "FurDark" }, pos, (nrm * 0.3 + Vector3.new(0, -1, 0)).Unit, smp.T, { n = 2, len = 0.5, w0 = 0.22, w1 = 0.14, bend = 0, tip = false, depth = 1.8 })
			end
		end
		local tail = K:tube("Tail", {
			{ 0, 1.98, 1.32, rx = 0.16, ru = 0.16 },
			{ 0, 1.7, 1.66, rx = 0.1, ru = 0.1 },
		}, { step = 0.2, core = "HideDark", coreScale = 0.95 })
		K:chain("Tail", { "Fur", "FurDark" }, Vector3.new(0, 1.66, 1.68), Vector3.new(0, -1, 0.3).Unit, Vector3.xAxis, { n = 2, len = 0.36, w0 = 0.16, w1 = 0.1, tip = false, depth = 1.4, bend = 0 })
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.58 * x, 1.66, -0.58, 0.44 },
				{ 0.66 * x, 0.94, -0.62, 0.36 },
				{ 0.64 * x, 0.3, -0.62, 0.32 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.54, 0.24, 0.5), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.11, curl = 14 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.58 * x, 1.66, 0.92, 0.5 },
				{ 0.66 * x, 1.04, 0.74, 0.4 },
				{ 0.64 * x, 0.3, 0.92, 0.32 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.54, 0.24, 0.5), key = "Back" }, toes = 3, claw = { len = 0.16, w = 0.11, curl = 14 } })
			K:tile(x == 1 and "LegFL" or "LegFR", "Armour", K:at(K:path({ { 0.58 * x, 1.66, -0.58, rx = 0.44 }, { 0.66 * x, 0.94, -0.62, rx = 0.36 } }, 0.3, Vector3.xAxis), 0.2), rad(80) * x, 0.56, 0.5, 0.15, 10, 3, 0.2)
		end

		-- head: long and low, two great ice horns on the nose, an ice shield behind the skull, eyes under the brow
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.1, -0.3), Vector3.new(0.8, 0.66, 0.66))
		K:block("Head", "Hide", hcf(0, -0.02, -0.86), Vector3.new(0.62, 0.52, 0.6))
		K:block("Head", "HideDark", hcf(0, -0.08, -1.2, 6, 0, 0), Vector3.new(0.52, 0.42, 0.24))
		K:block("Head", "Socket", hcf(0, -0.24, -1.28), Vector3.new(0.36, 0.04, 0.06))
		K:block("Head", "Back", hcf(0, 0.44, -0.42, -12, 0, 0), Vector3.new(0.56, 0.1, 0.5))
		for _, x in { 1, -1 } do
			K:block("Head", "Back", hcf(0.27 * x, 0.4, -0.68, -10, -12 * x, 18 * x), Vector3.new(0.4, 0.17, 0.36))
			H.eye(K, "Head", hcf(0.38 * x, 0.25, -0.68, 0, -36 * x, 14 * x), 0.16, 0.045)
			-- a grim mouth line and short ice tusks at its corners
			K:block("Head", "Socket", hcf(0.27 * x, -0.2, -0.98, 0, -6 * x, 0), Vector3.new(0.04, 0.05, 0.56))
			K:chain("Head", { "Armour", "ArmourLight" }, hp(0.28 * x, -0.22, -1.12), hv(0.3 * x, 1, -0.3), hv(0, 0, 1), { n = 2, len = 0.3, w0 = 0.1, w1 = 0.06, bend = 0 })
			K:block("Head", "Socket", hcf(0.16 * x, -0.04, -1.32), Vector3.new(0.08, 0.06, 0.04))
			-- shield plates fanning up behind the skull
			K:block("Head", x == 1 and "Armour" or "ArmourLight", hcf(0.32 * x, 0.42, 0.06, 30, -20 * x, -24 * x), Vector3.new(0.44, 0.1, 0.5))
			local g = x == 1 and "EarL" or "EarR"
			K:chain(g, { "HideDark", "Hide" }, hp(0.34 * x, 0.46, 0.02), hv(0.6 * x, 0.8, 0.3), hv(0, 0, 1), { n = 2, len = 0.26, w0 = 0.16, w1 = 0.09, depth = 0.6, bend = 0 })
		end
		K:block("Head", "ArmourLight", hcf(0, 0.54, 0.06, 32, 0, 0), Vector3.new(0.5, 0.1, 0.52))
		-- the horns: a great curved front horn and a shorter one behind it
		K:chain("Head", { "Armour", "Ice", "IceDeep", "ArmourLight" }, hp(0, 0.24, -1.08), hv(0, 1, -0.45), hv(1, 0, 0), { n = 4, len = 1.1, w0 = 0.32, w1 = 0.12, bend = 14 })
		K:chain("Head", { "Armour", "Ice", "ArmourLight" }, hp(0, 0.3, -0.7), hv(0, 1, -0.15), hv(1, 0, 0), { n = 3, len = 0.56, w0 = 0.24, w1 = 0.1, bend = 12 })
	end,
}
