local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Legendary / storm: the storm titan. It stands upright and roars: chest thrown out, its left fist
-- raised to the sky, tall jagged lightning-bolt crystal spines bursting from its back and shoulders, electric cyan
-- veins branching over its arms and chest. Dark navy fur, steel-blue armour plates, bright cyan glow. Face: a
-- steel-blue mask under a heavy plated brow, a crown of crackling crystal spines for a crest, white-cyan eyes, and a
-- wide roaring mouth full of fangs, glowing with charge.
local HEAD = CFrame.new(0, 4.46, -1.04) * CFrame.Angles(rad(16), 0, 0)
local HS = 1.26

return {
	Seed = 71,
	Vary = 0.04,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Fur = "1F2742",
		FurDark = "141A2E",
		FurLight = "2E3A5C",
		Skin = "34425E",
		SkinDark = "222C42",
		Plate = { "6E87AA", Material = "Slate" },
		PlateLight = { "95ADCC", Material = "Slate" },
		PlateDark = { "4C5F80", Material = "Slate" },
		Crystal = { "5CCBFF", Material = "Glass" },
		Bolt = { "22E2FF", Neon = true },
		Spark = { "B4F8FF", Neon = true },
		Vein = { "22E2FF", Neon = true },
		Tooth = "EEF2F6",
		Mouth = { "1EB4E6", Neon = true },
		Eye = { "B4F8FF", Neon = true },
		Socket = "080A12",
		Claw = "141A26",
		ClawTip = "D6DCE6",
	},
	Joints = {
		Head = { 0, 4.3, -0.62 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.GHEAD_HINGE),
		ArmL = { 1.5, 4.12, 0.02 },
		ArmR = { -1.5, 4.12, 0.02 },
		LegL = { 0.66, 2.3, 0.2 },
		LegR = { -0.66, 2.3, 0.2 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- a lightning-bolt crystal spine: a jagged crystal blade kinking side to side round a glowing core, a sparking tip
		local function spine(g, base, dir, side, len, w)
			dir = dir.Unit
			side = (side - dir * side:Dot(dir)).Unit
			local n = dir:Cross(side).Unit
			local pts = { base }
			for i = 1, 3 do
				table.insert(pts, base + dir * len * i / 4 + side * (i % 2 == 1 and 1 or -1) * len * 0.14)
			end
			table.insert(pts, base + dir * len)
			for i = 1, 4 do
				local a, b = pts[i], pts[i + 1]
				local d = b - a
				local cf = CFrame.fromMatrix((a + b) / 2, n:Cross(d.Unit).Unit, n)
				local ww = w * (1 - (i - 1) * 0.17)
				K:block(g, "Crystal", cf, Vector3.new(ww, 0.22, d.Magnitude + ww * 0.55))
				if i <= 3 then
					K:block(g, i == 2 and "Spark" or "Bolt", cf, Vector3.new(ww * 0.34, 0.27, d.Magnitude + ww * 0.3))
				end
			end
			H.point(K, g, "Spark", base + dir * (len + 0.16), dir, w * 0.42)
		end
		-- an upright torso, chest thrown out over a narrower waist (front = theta 0)
		local torso = K:tube("Body", {
			{ 0, 4.08, 0.02, rx = 1.34, ru = 0.9, rd = 0.86 },
			{ 0, 3.46, -0.06, rx = 1.26, ru = 1.0, rd = 0.82 },
			{ 0, 2.76, 0.14, rx = 0.96, ru = 0.78, rd = 0.7 },
			{ 0, 2.06, 0.26, rx = 0.8, ru = 0.62, rd = 0.62 },
		}, { step = 0.42, ref = Vector3.xAxis, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.76, 6, 0.64), color = function(th)
			local a = math.deg(math.abs(th))
			if a < 62 then
				return nil
			end
			return a < 140 and "Fur" or "FurDark"
		end })
		local mantle = K:tube("Body", {
			{ -1.5, 4.06, 0.02, rx = 0.72, ru = 0.74, rd = 0.6 },
			{ 0, 4.32, 0.08, rx = 0.84, ru = 0.8, rd = 0.66 },
			{ 1.5, 4.06, 0.02, rx = 0.72, ru = 0.74, rd = 0.6 },
		}, { step = 0.44, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.78, 5, 0.66), color = function(th)
			if th < rad(-100) then
				return nil
			end
			return math.abs(th) < rad(50) and "FurDark" or "Fur"
		end })
		-- a thick neck sloping from the shoulders into the back of the head
		for _, o in { { 0, 4.66, -0.36, 1.04, 0.7, 0.9, -28, "FurDark" }, { 0, 4.42, -0.6, 0.88, 0.58, 0.66, -18, "Fur" } } do
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, 0), Vector3.new(o[4], o[5], o[6]))
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, rad(45)), Vector3.new(o[5] * 1.15, o[5] * 1.15, o[6] * 0.96))
		end
		-- steel-blue pec plates and ab plates on the bare chest
		for _, x in { 1, -1 } do
			K:tile("Body", "Plate", K:at(torso, 0.42), rad(27) * x, 1.04, 0.98, 0.18, 4, 0.5, 0.3)
			K:tile("Body", "PlateLight", K:at(torso, 0.06), rad(27) * x, 0.96, 0.16, 0.2, 2, 0.5, 0.2)
		end
		for i, f in { 1.18, 1.5, 1.82 } do
			for _, x in { 1, -1 } do
				K:tile("Body", i == 2 and "Plate" or "PlateDark", K:at(torso, f), rad(15) * x, 0.5 - i * 0.04, 0.3, 0.13, 4, 0.5, 0.35)
			end
		end
		-- electric veins branching over the chest
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "Vein", torso, rad(46) * x, 0.2, 1.95, { lift = 0.16, wander = 16, forks = 2, width = 0.08, height = 0.12, step = 0.26 })
		end
		H.vein(K, "Body", "Vein", mantle, rad(-40), 0.5, mantle.total - 0.5, { lift = 0.16, wander = 12, forks = 2, width = 0.08, step = 0.26 })
		-- tall lightning-bolt crystal spines bursting from the back and the shoulders
		for _, o in { { 0.5, rad(38), 2.2, 0.52, 0 }, { 0.33, rad(42), 1.7, 0.44, -1 }, { 0.67, rad(42), 1.7, 0.44, 1 }, { 0.12, rad(8), 1.35, 0.4, -1 }, { 0.88, rad(8), 1.35, 0.4, 1 } } do
			local smp = K:at(mantle, mantle.total * o[1])
			local base, nrm = K:surface(smp, o[2], 0.05)
			local dir = (nrm + Vector3.new(o[5] * 0.25, 0.7, 0.1)).Unit
			spine("Body", base, dir, Vector3.zAxis + Vector3.xAxis * (o[5] == 0 and 0.6 or o[5] * 0.6), o[3], o[4])
		end
		for _, o in { { 0.62, 1.35, 0.4 }, { 1.12, 1.05, 0.34 } } do
			local base, nrm = K:surface(K:at(torso, o[1]), math.pi, 0.05)
			spine("Body", base, (nrm + Vector3.new(0, 0.55, 0)).Unit, Vector3.xAxis, o[2], o[3])
		end
		local armFur = function(_, ring)
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		-- the left arm thrust up, fist raised to the sky
		local armL = H.limb(K, "ArmL", {
			{ 1.5, 4.12, 0.02, 0.56 },
			{ 2.16, 4.66, -0.06, 0.5 },
			{ 2.06, 5.7, -0.28, 0.56 },
		}, { step = 0.38, cores = { "Fur", "Fur" }, tiles = { H.cleanFur(0.72, 5, 0.6), H.cleanFur(0.74, 5, 0.6) }, color = armFur })
		local fcL = CFrame.new(2.04, 6.1, -0.34) * CFrame.Angles(rad(-12), 0, rad(-6))
		K:block("ArmL", "Skin", fcL, Vector3.new(0.84, 0.76, 0.8))
		for f = 1, 4 do
			K:block("ArmL", "SkinDark", fcL * CFrame.new((f - 2.5) * 0.2, 0.2, -0.36), Vector3.new(0.18, 0.32, 0.2))
		end
		K:block("ArmL", "SkinDark", fcL * CFrame.new(-0.4, -0.04, -0.22), Vector3.new(0.18, 0.3, 0.22))
		K:block("ArmL", "Plate", fcL * CFrame.new(0, 0.3, -0.04) * CFrame.Angles(rad(-8), 0, 0), Vector3.new(0.9, 0.14, 0.66))
		-- the charge crackling off the raised fist
		for k = 1, 2 do
			local a = rad(k * 180 + 30)
			local p0 = fcL * Vector3.new(math.cos(a) * 0.3, 0.38, math.sin(a) * 0.3)
			H.bolt(K, "ArmL", "Spark", p0, p0 + Vector3.new(math.cos(a) * 0.35, 0.55, math.sin(a) * 0.35), Vector3.new(-math.sin(a), 0, math.cos(a)), 3, 0.05, 0.08)
		end
		-- the right arm hanging, fist clenched
		local armR = H.limb(K, "ArmR", {
			{ -1.5, 4.12, 0.02, 0.56 },
			{ -1.98, 3.02, 0.12, 0.5 },
			{ -1.92, 1.94, -0.18, 0.56 },
		}, { step = 0.38, cores = { "Fur", "Fur" }, tiles = { H.cleanFur(0.72, 5, 0.6), H.cleanFur(0.74, 5, 0.6) }, color = armFur })
		local fcR = CFrame.new(-1.9, 1.52, -0.26) * CFrame.Angles(rad(8), 0, rad(4))
		K:block("ArmR", "Skin", fcR, Vector3.new(0.84, 0.8, 0.82))
		for f = 1, 4 do
			K:block("ArmR", "SkinDark", fcR * CFrame.new((f - 2.5) * 0.2, -0.22, -0.36), Vector3.new(0.18, 0.32, 0.2))
		end
		K:block("ArmR", "Plate", fcR * CFrame.new(0, 0.06, -0.38), Vector3.new(0.86, 0.3, 0.12))
		-- steel gauntlets and shoulder plates, veins down both arms
		for _, a in { { "ArmL", armL, 1 }, { "ArmR", armR, -1 } } do
			local g, arm, x = a[1], a[2], a[3]
			local fore = arm[2]
			local mid = fore.total * 0.56
			for r = 0, 5 do
				local th = rad(r * 60 + 15)
				K:tile(g, r % 2 == 0 and "Plate" or "PlateDark", K:at(fore, mid), th, 0.6, 0.46, 0.16, 0, 0, -0.9)
				K:tile(g, "PlateLight", K:at(fore, mid + 0.28), th, 0.58, 0.09, 0.19, 0, 0, -0.9)
			end
			for _, sgm in arm do
				H.vein(K, g, "Vein", sgm, rad(70), 0.08, sgm.total - 0.08, { lift = 0.15, wander = 18, forks = 1, width = 0.07, step = 0.26 })
			end
			-- a steel plate capping the shoulder
			for i, o in { { 70, 0.82, 0.66, 1.0 }, { 30, 0.78, 0.56, 0.9 } } do
				local an = rad(o[1])
				local P = CFrame.new(1.42 * x + math.cos(an) * o[2] * x, 4.12 + math.sin(an) * o[2], 0.02) * CFrame.Angles(0, 0, (an - math.pi / 2) * x)
				K:block(g, i == 1 and "Plate" or "PlateDark", P, Vector3.new(o[3], 0.17, o[4]))
				K:block(g, "PlateLight", P * CFrame.new(o[3] * 0.46 * x, 0.02, 0), Vector3.new(0.1, 0.22, o[4] + 0.04))
			end
		end
		-- thick legs planted wide, steel knee plates, veins down the thighs
		for _, x in { 1, -1 } do
			local lg = x == 1 and "LegL" or "LegR"
			local leg = H.limb(K, lg, {
				{ 0.66 * x, 2.3, 0.2, 0.56 },
				{ 0.86 * x, 1.32, -0.12, 0.48 },
				{ 0.8 * x, 0.42, 0.14, 0.38 },
			}, { step = 0.42, cores = { "Fur", "FurDark" }, tiles = { H.cleanFur(0.62, 6, 0.58), nil }, color = armFur })
			H.vein(K, lg, "Vein", leg[1], rad(-40 * x), 0.1, leg[1].total - 0.15, { lift = 0.15, wander = 14, width = 0.07, step = 0.26 })
			K:block(lg, "Plate", CFrame.new(0.86 * x, 1.36, -0.62) * CFrame.Angles(rad(-10), 0, 0), Vector3.new(0.62, 0.56, 0.16))
			K:block(lg, "PlateLight", CFrame.new(0.86 * x, 1.64, -0.6) * CFrame.Angles(rad(-10), 0, 0), Vector3.new(0.64, 0.1, 0.2))
			K:block(lg, "SkinDark", CFrame.new(0.82 * x, 0.15, -0.04) * CFrame.Angles(0, rad(-8 * x), 0), Vector3.new(0.66, 0.3, 1.0))
			for f = -1, 2 do
				K:block(lg, "Skin", CFrame.new(0.82 * x + f * 0.15 - 0.06 * x, 0.12, -0.56) * CFrame.Angles(0, rad(-8 * x), 0), Vector3.new(0.14, 0.2, 0.2))
			end
		end
		H.gorillaHead(K, {
			frame = HEAD,
			scale = HS,
			keys = { fur = "Fur", furDark = "FurDark", face = "Plate", faceDark = "PlateDark", brow = "Skin", nose = "SkinDark" },
			crest = false,
			open = 34,
			browTilt = 16,
			muzzleW = 1.06,
			fangs = { upper = 0.27, lower = 0.19, extra = 0.13 },
			eye = { w = 0.14, h = 0.05 },
			extras = function(K, cf, p, v, JAW)
				-- a crown of crackling crystal spines along the skull for a crest
				K:block("Head", "PlateDark", cf(0, 0.64, -0.06, -10, 0, 0), Vector3.new(0.5, 0.14, 0.78))
				spine("Head", p(0, 0.68, -0.14), v(0, 1, 0.4), v(1, 0, 0.6), 0.9, 0.28)
				for _, x in { 1, -1 } do
					spine("Head", p(0.22 * x, 0.62, 0.08), v(0.4 * x, 1, 0.55), v(0, 0, 1), 0.62, 0.22)
				end
				-- lightning marks running down the cheeks from the eyes
				for _, x in { 1, -1 } do
					H.bolt(K, "Head", "Vein", p(0.3 * x, 0.17, -0.67), p(0.36 * x, -0.05, -0.66), v(1, 0, 0), 3, 0.045, 0.04)
				end
			end,
		})
	end,
}
