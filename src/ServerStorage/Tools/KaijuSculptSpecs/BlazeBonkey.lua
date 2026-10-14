local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Epic / fire (accent: flame orange-yellow): a volcanic brawler. A lean rust-and-ember gorilla body dwarfed by two gigantic fists of
-- lava rock split with glowing magma, molten cracks across its fur, a mane of fire ringing its face, ember eyes, a
-- glowing mouth, and a tail that ends in flame.
local HEAD = CFrame.new(0, 3.08, -1.06) * CFrame.Angles(rad(-6), 0, 0)
local HS = 1.05

return {
	Seed = 67,
	Vary = 0.04,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = { "7E4028", Material = "Basalt" },
		FurDark = { "582C1C", Material = "Basalt" },
		FurLight = { "A45A36", Material = "Basalt" },
		Skin = { "9E5636", Material = "Basalt" },
		SkinDark = { "6E3822", Material = "Basalt" },
		Rock = { "70503F", Material = "Basalt" },
		RockLight = { "927060", Material = "Basalt" },
		RockDark = { "4A3028", Material = "Basalt" },
		Magma = { "FF5A14", Neon = true },
		MagmaHot = { "FF8C1A", Neon = true },
		Flame = { "FFD23A", Neon = true },
		Tooth = "F0DCC0",
		Mouth = { "FF6A1A", Neon = true },
		Eye = { "FFD23A", Neon = true },
		Socket = "120A08",
		Claw = "201612",
		ClawTip = { "FFB43A", Neon = true },
	},
	Joints = {
		Head = { 0, 2.86, -0.66 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.APEHEAD_HINGE),
		EarL = H.apeHeadJoint(HEAD, HS, H.APEHEAD_EAR),
		EarR = H.apeHeadJoint(HEAD, HS, H.APEHEAD_EAR * Vector3.new(-1, 1, 1)),
		ArmL = { 1.0, 2.96, -0.46 },
		ArmR = { -1.0, 2.96, -0.46 },
		LegL = { 0.52, 1.8, 0.56 },
		LegR = { -0.52, 1.8, 0.56 },
		Tail = { 0, 1.8, 0.9 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
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
		local FLAME = { "Magma", "MagmaHot", "Flame" }
		local torso = K:tube("Body", {
			{ 0, 2.9, -0.46, rx = 0.9, ru = 0.8, rd = 0.86 },
			{ 0, 2.56, 0.04, rx = 0.88, ru = 0.78, rd = 0.86 },
			{ 0, 2.1, 0.42, rx = 0.76, ru = 0.7, rd = 0.7 },
			{ 0, 1.78, 0.62, rx = 0.64, ru = 0.58, rd = 0.58 },
		}, { step = 0.4, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.6, 7, 0.58), color = fur })
		local mantle = K:tube("Body", {
			{ -0.86, 3.12, -0.42, rx = 0.46, ru = 0.52, rd = 0.42 },
			{ 0, 3.28, -0.36, rx = 0.56, ru = 0.56, rd = 0.48 },
			{ 0.86, 3.12, -0.42, rx = 0.46, ru = 0.52, rd = 0.42 },
		}, { step = 0.4, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.56, 6, 0.54), color = function(th)
			local a = math.deg(math.abs(th))
			return a < 48 and "FurDark" or (a < 130 and "Fur" or nil)
		end })
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.2), rad(180 - 34) * x, 0.8, 0.76, 0.15, 6, 0.5, 0.4)
		end
		-- glowing seams over the chest and molten cracks through the fur
		K:block("Body", "Magma", CFrame.lookAt(K:surface(K:at(torso, 0.2), math.pi, -0.05), K:surface(K:at(torso, 0.9), math.pi, -0.05)), Vector3.new(0.07, 0.07, 0.8))
		H.cracks(K, "Body", "MagmaHot", torso, { rad(20), rad(-20), rad(55), rad(-55), rad(100), rad(-100) }, 0.15, torso.total - 0.1, 0.24, 0.09, 0.12)
		H.cracks(K, "Body", "MagmaHot", mantle, { rad(30), rad(-30) }, 0.2, mantle.total - 0.2, 0.28, 0.07, 0.1)
		for _, x in { 1, -1 } do
			-- arms swelling into gigantic fists of lava rock
			local g = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, g, {
				{ 1.0 * x, 2.96, -0.46, 0.38 },
				{ 1.36 * x, 1.96, -0.62, 0.42 },
				{ 1.42 * x, 1.42, -0.92, 0.56 },
			}, { step = 0.4, cores = { "Fur", "Rock" }, tiles = { H.cleanFur(0.5, 6, 0.5), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			H.cracks(K, g, "Magma", arm[2], { rad(0), rad(120) * x, rad(-120) * x }, 0.05, arm[2].total, 0.2, 0.07, 0.04)
			local fc = CFrame.new(1.46 * x, 0.72, -1.06) * CFrame.Angles(0, rad(-10 * x), 0)
			K:block(g, "Magma", fc, Vector3.new(1.0, 0.96, 1.0))
			for i, o in {
				{ 0, 0.2, 0.06, 1.24, 0.8, 1.16, 0 },
				{ 0.34, -0.22, -0.3, 0.6, 0.62, 0.62, 18 },
				{ -0.34, -0.22, -0.3, 0.6, 0.62, 0.62, -14 },
				{ 0, -0.24, 0.32, 0.86, 0.6, 0.6, 8 },
				{ 0.44, 0.1, 0.32, 0.5, 0.7, 0.66, -10 },
				{ -0.44, 0.1, 0.3, 0.5, 0.7, 0.66, 12 },
			} do
				K:block(g, ({ "Rock", "RockLight", "Rock", "RockDark", "RockLight", "Rock" })[i], fc * CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7] * 0.5), rad(o[7]), rad(-o[7] * 0.4)), Vector3.new(o[4], o[5], o[6]))
			end
			K:block(g, "Rock", fc * CFrame.new(0, 0.0, -0.5) * CFrame.Angles(rad(-6), 0, 0), Vector3.new(1.1, 0.7, 0.3))
			H.cracks(K, g, "MagmaHot", arm[1], { rad(100) * x, rad(-80) * x }, 0.1, arm[1].total - 0.1, 0.26, 0.07, 0.08)
			for k, o in { { -0.3, 0.18, -0.66, 30 }, { 0.26, -0.06, -0.66, -40 }, { 0.6, 0.2, 0.0, 70 }, { -0.62, 0.1, 0.1, -60 }, { 0.0, 0.44, -0.2, 10 }, { 0.3, 0.3, -0.66, 80 }, { -0.62, -0.2, -0.3, 20 }, { 0.62, -0.18, -0.3, -30 } } do
				K:block(g, k % 2 == 0 and "MagmaHot" or "Magma", fc * CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(0, 0, rad(o[4])), Vector3.new(0.52, 0.08, 0.08))
			end
			-- knuckles burning white-hot where they meet the ground
			for f = 1, 4 do
				K:block(g, f % 2 == 0 and "MagmaHot" or "Flame", fc * CFrame.new((f - 2.5) * 0.28, -0.46, -0.6), Vector3.new(0.22, 0.2, 0.08))
			end
			local lg = x == 1 and "LegL" or "LegR"
			H.limb(K, lg, {
				{ 0.52 * x, 1.8, 0.56, 0.44 },
				{ 0.76 * x, 1.06, 0.22, 0.38 },
				{ 0.72 * x, 0.36, 0.6, 0.28 },
			}, { step = 0.4, cores = { "Fur", "FurDark" }, tiles = { H.cleanFur(0.5, 6, 0.5), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			K:block(lg, "SkinDark", CFrame.new(0.74 * x, 0.14, 0.42) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.5, 0.28, 0.8))
		end
		-- head with a mane of fire ringing the face
		H.apeHead(K, {
			frame = HEAD,
			scale = HS,
			face = "Skin",
			faceDark = "SkinDark",
			brow = "RockDark",
			crest = { "RockDark", "MagmaHot", "RockDark" },
			ears = true,
			open = 14,
			extras = function(K, cf, p, v)
				for k = 0, 8 do
					local a = rad(-120 + k * 30)
					local d = Vector3.new(math.sin(a), math.cos(a), 0)
					local base = p(d.X * 0.5, 0.2 + d.Y * 0.46, -0.36)
					H.flame(K, "Head", FLAME, base, v(d.X, d.Y + 0.15, 0.55), v(0, 0, 1), 0.72 - math.abs(k - 4) * 0.05, 0.2, 22)
				end
			end,
		})
		local tail = K:tube("Tail", {
			{ 0, 1.82, 0.86, rx = 0.18 },
			{ 0, 1.92, 1.42, rx = 0.15 },
			{ -0.1, 2.46, 1.8, rx = 0.12 },
			{ -0.06, 2.92, 1.6, rx = 0.09 },
		}, { step = 0.26, core = "Fur", coreScale = 0.95, tile = H.cleanFur(0.28, 4, 0.32), color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
		local tip = K:at(tail, tail.total)
		H.flame(K, "Tail", FLAME, tip.p, (tip.T + Vector3.new(0, 0.6, 0)).Unit, tip.R, 0.8, 0.26, 24)
	end,
}
