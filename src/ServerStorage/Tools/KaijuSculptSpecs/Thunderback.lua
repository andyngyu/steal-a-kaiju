local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Legendary / storm: a storm titan. Massive shoulders over a narrow waist, slate-navy fur split by
-- glowing storm-blue veins, a fan of zigzag lightning rods crackling off its back, storm-iron bull horns, electric
-- eyes, storm-iron gauntlets, and its own black thundercloud riding over its shoulders.
local HEAD = CFrame.new(0, 3.24, -1.34) * CFrame.Angles(rad(-6), 0, 0)
local HS = 1.1

return {
	Seed = 71,
	Vary = 0.04,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "2C3344",
		FurDark = "1C2130",
		FurLight = "47506A",
		Skin = "5A6680",
		SkinDark = "3A4458",
		Iron = { "3E4656", Material = "Slate" },
		IronLight = { "5E6878", Material = "Slate" },
		Vein = { "3FA6FF", Neon = true },
		Bolt = { "FFE04A", Neon = true },
		Cloud1 = "3E4352",
		Cloud2 = "2C303C",
		Cloud3 = "555B6A",
		Tooth = "ECE8DC",
		Mouth = "4A1A22",
		Eye = { "8FE0FF", Neon = true },
		Socket = "0A0C12",
		Claw = "1A1E26",
		ClawTip = "D6DCE6",
	},
	Joints = {
		Head = { 0, 3.06, -0.86 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.APEHEAD_HINGE),
		ArmL = { 1.5, 3.32, -0.42 },
		ArmR = { -1.5, 3.32, -0.42 },
		LegL = { 0.56, 1.9, 0.56 },
		LegR = { -0.56, 1.9, 0.56 },
		Cloud = { 0, 5.55, 0.5 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local function fur(th)
			local a = math.deg(math.abs(th))
			if a < 40 then
				return "FurDark"
			elseif a < 120 then
				return "Fur"
			end
			return nil
		end
		-- a V-shaped torso: huge chest and shoulders tapering to a narrow waist
		local torso = K:tube("Body", {
			{ 0, 3.2, -0.52, rx = 1.36, ru = 1.0, rd = 1.0 },
			{ 0, 2.8, 0.04, rx = 1.16, ru = 0.95, rd = 1.0 },
			{ 0, 2.26, 0.44, rx = 0.84, ru = 0.8, rd = 0.8 },
			{ 0, 1.9, 0.64, rx = 0.66, ru = 0.6, rd = 0.6 },
		}, { step = 0.42, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.7, 7, 0.62), color = fur })
		local mantle = K:tube("Body", {
			{ -1.42, 3.44, -0.42, rx = 0.68, ru = 0.74, rd = 0.6 },
			{ 0, 3.7, -0.36, rx = 0.82, ru = 0.82, rd = 0.68 },
			{ 1.42, 3.44, -0.42, rx = 0.68, ru = 0.74, rd = 0.6 },
		}, { step = 0.44, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.7, 6, 0.64), color = function(th)
			local a = math.deg(math.abs(th))
			return a < 48 and "FurDark" or (a < 130 and "Fur" or nil)
		end })
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.2), rad(180 - 34) * x, 1.0, 0.9, 0.16, 6, 0.5, 0.4)
		end
		for i, f in { 0.68, 1.02 } do
			for _, x in { 1, -1 } do
				K:tile("Body", "SkinDark", K:at(torso, f), rad(180 - 15) * x, 0.44 - i * 0.04, 0.34, 0.12, 6, 0.5, 0.4)
			end
		end
		-- storm-blue veins crackling over the body
		H.cracks(K, "Body", "Vein", torso, { rad(56), rad(-56), rad(108), rad(-108) }, 0.15, torso.total - 0.1, 0.26, 0.07, 0.1)
		H.cracks(K, "Body", "Vein", mantle, { rad(28), rad(-28) }, 0.3, mantle.total - 0.3, 0.3, 0.07, 0.1)
		-- a fan of zigzag lightning rods crackling off the upper back
		for k = -2, 2 do
			local smp = K:at(mantle, mantle.total * (0.5 + k * 0.17))
			local base = K:surface(smp, rad(-20), 0.1)
			local dir = (Vector3.new(k * 0.32, 1, 0.55)).Unit
			local len = 1.15 - math.abs(k) * 0.18
			local side = dir:Cross(Vector3.zAxis).Unit
			H.bolt(K, "Body", "Iron", base, base + dir * len, side, 4, 0.17, 0.13)
			H.point(K, "Body", "Bolt", base + dir * (len + 0.2), dir, 0.18)
			H.bolt(K, "Body", "Bolt", base + dir * len * 0.4, base + dir * (len + 0.05), side, 3, 0.05, 0.1)
		end
		for _, x in { 1, -1 } do
			local g = x == 1 and "ArmL" or "ArmR"
			local arm = H.apeArm(K, g, x, {
				pts = { { 1.5, 3.32, -0.42, 0.58 }, { 1.92, 2.08, -0.56, 0.52 }, { 1.76, 0.98, -0.86, 0.5 } },
				fist = Vector3.new(0.84, 0.72, 0.84),
				fistKey = "Skin",
				knuckleKey = "SkinDark",
				fur = H.cleanFur(0.64, 6, 0.6),
				foreFur = H.cleanFur(0.62, 6, 0.6),
				color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end,
			})
			local up, fore = arm[1], arm[2]
			for i, f in { 0.36, 0.7 } do
				K:tile(g, i == 1 and "Iron" or "IronLight", K:at(fore, fore.total * f), rad(-30) * x, 0.86, 0.46, 0.15, 3, 0, 0.35)
			end
			H.cracks(K, g, "Vein", up, { rad(100) * x }, 0.1, up.total - 0.1, 0.26, 0.06, 0.1)
			H.cracks(K, g, "Vein", fore, { rad(110) * x }, 0.1, fore.total - 0.2, 0.26, 0.06, 0.1)
			local lg = x == 1 and "LegL" or "LegR"
			local leg = H.limb(K, lg, {
				{ 0.56 * x, 1.9, 0.56, 0.46 },
				{ 0.8 * x, 1.1, 0.22, 0.4 },
				{ 0.76 * x, 0.36, 0.6, 0.3 },
			}, { step = 0.42, cores = { "Fur", "FurDark" }, tiles = { H.cleanFur(0.52, 6, 0.52), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			H.cracks(K, lg, "Vein", leg[1], { rad(80) * x }, 0.1, leg[1].total - 0.1, 0.26, 0.06, 0.1)
			K:block(lg, "SkinDark", CFrame.new(0.78 * x, 0.14, 0.42) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.54, 0.28, 0.82))
		end
		H.apeHead(K, {
			frame = HEAD,
			scale = HS,
			face = "Skin",
			faceDark = "SkinDark",
			brow = "Iron",
			crest = { "Iron", "IronLight", "Iron" },
			open = 12,
			extras = function(K, cf, p, v)
				-- storm-iron bull horns sweeping out and forward, crackling at the tips
				for _, x in { 1, -1 } do
					H.curve(K, "Head", { "Iron", "Iron", "IronLight", "Bolt" }, {
						p(0.44 * x, 0.56, -0.36),
						p(0.86 * x, 0.66, -0.3),
						p(1.08 * x, 0.94, -0.5),
						p(1.0 * x, 1.2, -0.8),
					}, 0.2, 0.08, 0.16)
				end
			end,
		})
		H.cloud(K, "Cloud", { "Cloud2", "Cloud1", "Cloud3", "Cloud2" }, Vector3.new(0, 5.55, 0.5), Vector3.new(1.5, 0.36, 0.84), 18, "Bolt", 3)
	end,
}
