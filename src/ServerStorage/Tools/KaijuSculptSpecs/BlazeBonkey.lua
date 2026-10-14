local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Epic / fire (accent: flame orange-yellow): the volcanic brawler. A lean, hunched rust-and-ember body
-- dwarfed by two gigantic fists of lava rock, continuous glowing magma veins flowing down its arms and over its chest,
-- a mane of fire ringing its head and running along its shoulders, a flame-tipped tail. Face: a slab of rock for a
-- brow over ember eyes, a rock crest split by a glowing seam, a wide flat nose, a broad muzzle, an underbite with
-- jutting tusks, and a mouth glowing like a furnace.
local HEAD = CFrame.new(0, 2.8, -1.12) * CFrame.Angles(rad(-6), 0, 0)
local HS = 1.16

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
		Face = { "5E3A2C", Material = "Basalt" },
		FaceDark = { "43291F", Material = "Basalt" },
		Rock = { "786050", Material = "Basalt" },
		RockLight = { "9A7E6C", Material = "Basalt" },
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
		Head = { 0, 2.76, -0.72 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.GHEAD_HINGE),
		EarL = H.apeHeadJoint(HEAD, HS, H.GHEAD_EAR),
		EarR = H.apeHeadJoint(HEAD, HS, H.GHEAD_EAR * Vector3.new(-1, 1, 1)),
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
		local VEIN = { lift = 0.15, wander = 16, width = 0.12, height = 0.14, step = 0.24 }
		local function vein(o)
			local t = table.clone(VEIN)
			for k, v in o or {} do
				t[k] = v
			end
			return t
		end
		local torso = K:tube("Body", {
			{ 0, 2.9, -0.46, rx = 0.9, ru = 0.8, rd = 0.86 },
			{ 0, 2.56, 0.04, rx = 0.88, ru = 0.78, rd = 0.86 },
			{ 0, 2.1, 0.42, rx = 0.76, ru = 0.7, rd = 0.7 },
			{ 0, 1.78, 0.62, rx = 0.64, ru = 0.58, rd = 0.58 },
		}, { step = 0.42, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.66, 6, 0.6), color = fur })
		local mantle = K:tube("Body", {
			{ -0.86, 3.12, -0.42, rx = 0.46, ru = 0.52, rd = 0.42 },
			{ 0, 3.28, -0.36, rx = 0.56, ru = 0.56, rd = 0.48 },
			{ 0.86, 3.12, -0.42, rx = 0.46, ru = 0.52, rd = 0.42 },
		}, { step = 0.4, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.6, 5, 0.56), color = function(th)
			local a = math.deg(math.abs(th))
			return a < 48 and "FurDark" or (a < 130 and "Fur" or nil)
		end })
		-- a thick neck sunk between the shoulders
		for _, o in { { 0, 3.22, -0.66, 0.86, 0.56, 0.76, 30, "FurDark" }, { 0, 3.02, -0.84, 0.74, 0.48, 0.6, 26, "Fur" } } do
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, 0), Vector3.new(o[4], o[5], o[6]))
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, rad(45)), Vector3.new(o[5] * 1.15, o[5] * 1.15, o[6] * 0.96))
		end
		-- ember-skinned chest plates, magma veins flowing down over them and along the back
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.2), rad(180 - 34) * x, 0.82, 0.78, 0.15, 6, 0.5, 0.4)
			H.vein(K, "Body", "MagmaHot", torso, rad(180 - 46) * x, 0.05, 1.4, vein({ forks = 2 }))
			H.vein(K, "Body", "MagmaHot", torso, rad(78) * x, 0.1, torso.total - 0.1, vein({ forks = 2, forkSteps = 2 }))
		end
		H.vein(K, "Body", "MagmaHot", torso, math.pi, 0.0, 1.0, vein({ wander = 8 }))
		-- a vein running across the shoulders like a yoke
		H.vein(K, "Body", "MagmaHot", mantle, rad(-50), 0.15, mantle.total - 0.15, vein({ forks = 4, forkSteps = 2 }))
		-- the mane of fire running along the shoulders behind the head
		for k = 0, 6 do
			local u = 0.12 + k / 6 * 0.76
			local smp = K:at(mantle, mantle.total * u)
			local base, nrm = K:surface(smp, rad(20), 0.08)
			local side = (u - 0.5) * 2
			H.flame(K, "Body", FLAME, base, (nrm + Vector3.new(side * 0.4, 0.5, 0.45)).Unit, Vector3.xAxis, 0.95 - math.abs(side) * 0.3, 0.26, 22)
		end
		for _, x in { 1, -1 } do
			-- arms swelling into gigantic fists of lava rock
			local g = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, g, {
				{ 1.0 * x, 2.96, -0.46, 0.38 },
				{ 1.36 * x, 1.96, -0.62, 0.44 },
				{ 1.42 * x, 1.42, -0.92, 0.58 },
			}, { step = 0.4, cores = { "Fur", "Rock" }, tiles = { H.cleanFur(0.5, 6, 0.5), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			-- one continuous vein from the shoulder down the arm into the fist
			H.vein(K, g, "MagmaHot", arm[1], rad(60) * x, 0.0, arm[1].total, vein({ forks = 2, forkSteps = 2 }))
			H.vein(K, g, "MagmaHot", arm[2], rad(60) * x, 0.0, arm[2].total, vein({ lift = 0.05, forks = 1, forkSteps = 2 }))
			local fc = CFrame.new(1.46 * x, 0.72, -1.06) * CFrame.Angles(0, rad(-10 * x), 0)
			K:block(g, "Magma", fc, Vector3.new(1.08, 1.02, 1.08))
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
			-- knuckles burning white-hot where they meet the ground
			for f = 1, 4 do
				K:block(g, f % 2 == 0 and "MagmaHot" or "Flame", fc * CFrame.new((f - 2.5) * 0.28, -0.46, -0.6), Vector3.new(0.22, 0.2, 0.08))
			end
			local lg = x == 1 and "LegL" or "LegR"
			local leg = H.limb(K, lg, {
				{ 0.52 * x, 1.8, 0.56, 0.44 },
				{ 0.76 * x, 1.06, 0.22, 0.38 },
				{ 0.72 * x, 0.36, 0.6, 0.28 },
			}, { step = 0.4, cores = { "Fur", "FurDark" }, tiles = { H.cleanFur(0.5, 6, 0.5), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			H.vein(K, lg, "Magma", leg[1], rad(-60) * x, 0.05, leg[1].total - 0.1, vein({ width = 0.07 }))
			K:block(lg, "SkinDark", CFrame.new(0.74 * x, 0.14, 0.42) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.5, 0.28, 0.8))
		end
		H.gorillaHead(K, {
			frame = HEAD,
			scale = HS,
			keys = { fur = "Fur", furDark = "FurDark", face = "Face", faceDark = "FaceDark", brow = "Rock", nose = "RockDark" },
			crest = { "RockDark", "Rock", "RockDark", "MagmaHot" },
			crestH = 0.8,
			open = 26,
			browTilt = 14,
			muzzleW = 1.1,
			fangs = { upper = 0.15, lower = 0.1, tusks = 0.3 },
			ears = true,
			extras = function(K, cf, p, v, JAW)
				-- a glowing seam under the rock brow, magma cracks running down the cheeks
				K:block("Head", "Magma", cf(0, 0.33, -0.7), Vector3.new(0.62, 0.04, 0.1))
				for _, x in { 1, -1 } do
					H.bolt(K, "Head", "MagmaHot", p(0.3 * x, 0.17, -0.68), p(0.34 * x, -0.06, -0.69), v(1, 0, 0), 3, 0.055, 0.04)
				end
				-- a mane of fire ringing the face
				for k = 0, 8 do
					local a = rad(-120 + k * 30)
					local d = Vector3.new(math.sin(a), math.cos(a), 0)
					local base = p(d.X * 0.52, 0.22 + d.Y * 0.5, -0.3)
					H.flame(K, "Head", FLAME, base, v(d.X, d.Y + 0.2, 0.5), v(0, 0, 1), 0.78 - math.abs(k - 4) * 0.05, 0.22, 22)
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
