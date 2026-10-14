local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Frostfang Peaks guardian: the Frost Titan, Brrrilla grown into a monster. A towering, top-heavy yeti hunched
-- forward on short thick legs, a great hump of shaggy frost-white fur, long arms ending in huge hands of ice claws
-- (it carries stolen eggs home in them), glacier armour on the shoulders and forearms, ice crystals erupting from its
-- back, glowing cyan veins across a bare blue-grey chest round a crystal core. Face: huge curling ram horns of ice, a
-- frosted brow hung with icicles over burning cyan eyes, a flat nose, a roaring jaw with jutting ice tusks, a mouth
-- glowing with frost, an icicle beard.
local HEAD = CFrame.new(0, 5.62, -1.3) * CFrame.Angles(rad(-4), 0, 0)
local HS = 1.38

return {
	Seed = 251,
	Vary = 0.04,
	Scale = 3.0,
	RootSize = { 8.5, 7.5, 7.5 },
	HipHeight = 2.4,
	Palette = {
		Fur = "C9D4DF",
		FurDark = "97A8BA",
		FurLight = "E8EEF5",
		Skin = "5E6F88",
		SkinDark = "3E4B60",
		Nose = "2C3648",
		Frost = "BCD6EA",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Tooth = { "E0F3FF", Material = "Ice" },
		Mouth = { "3FC8F0", Neon = true },
		Eye = { "3FE6FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = { "D6EEFF", Material = "Ice" },
	},
	Joints = {
		Head = { 0, 5.5, -0.82 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.GHEAD_HINGE),
		LegL = { 0.8, 2.45, 0.3 },
		LegR = { -0.8, 2.45, 0.3 },
		ArmL = { 1.75, 5.6, -0.35 },
		ArmR = { -1.75, 5.6, -0.35 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local function shaggy(w, n, l)
			return { w = w, n = n, l = l, t = 0.14, lift = 20, jitter = 3, sink = 0.4, overlap = 1.16 }
		end
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 52 then
				return nil -- the bare chest (front = theta 0)
			end
			return ring % 2 == 0 and "Fur" or (a > 140 and "FurDark" or "FurLight")
		end
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		local VEIN = { lift = 0.12, wander = 16, width = 0.1, height = 0.12, step = 0.4, forks = 2, forkSteps = 2 }
		-- a towering, top-heavy torso hunched forward
		local torso = K:tube("Body", {
			{ 0, 5.62, -0.36, rx = 1.55, ru = 1.05, rd = 1.2 },
			{ 0, 4.82, -0.1, rx = 1.62, ru = 1.1, rd = 1.2 },
			{ 0, 3.82, 0.16, rx = 1.3, ru = 0.95, rd = 1.0 },
			{ 0, 2.86, 0.3, rx = 0.95, ru = 0.75, rd = 0.8 },
		}, { step = 0.46, ref = Vector3.xAxis, core = "Fur", coreScale = 0.86, tile = shaggy(1.0, 8, 0.96), color = fur })
		local hump = K:tube("Body", {
			{ -1.55, 5.78, -0.22, rx = 0.86, ru = 0.86, rd = 0.7 },
			{ 0, 6.18, -0.12, rx = 1.02, ru = 0.96, rd = 0.76 },
			{ 1.55, 5.78, -0.22, rx = 0.86, ru = 0.86, rd = 0.7 },
		}, { step = 0.46, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = shaggy(1.0, 7, 0.96), color = function(th, ring)
			return th > rad(-110) and (ring % 2 == 0 and "FurLight" or "Fur") or nil
		end })
		-- a thick neck of fur hunched down into the head
		for _, o in { { 0, 6.0, -0.86, 1.5, 0.92, 1.1, 30, "Fur" }, { 0, 5.72, -1.1, 1.24, 0.76, 0.76, 22, "FurLight" } } do
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, 0), Vector3.new(o[4], o[5], o[6]))
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, rad(45)), Vector3.new(o[5] * 1.15, o[5] * 1.15, o[6] * 0.96))
		end
		-- the bare chest: blue-grey plates, glowing veins, a crystal core
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.5), rad(26) * x, 1.2, 1.1, 0.18, 6, 0.5, 0.4)
			H.vein(K, "Body", "IceGlow", torso, rad(30) * x, 0.3, torso.total - 0.5, VEIN)
		end
		for i, f in { 1.5, 1.95, 2.4 } do
			for _, x in { 1, -1 } do
				K:tile("Body", "SkinDark", K:at(torso, f), rad(15) * x, 0.66 - i * 0.06, 0.4, 0.14, 6, 0.5, 0.4)
			end
		end
		local core, cn = K:surface(K:at(torso, 1.05), 0, -0.05)
		H.crystal(K, "Body", { "IceGlow", "Ice", "IceDeep" }, core, cn, 0.7, 4, 34)
		-- ice crystals erupting from the hump and back
		for _, o in { { 0.5, 0, 1.5, 5 }, { 0.3, 30, 1.0, 4 }, { 0.7, -30, 1.0, 4 } } do
			local pos, nrm = K:surface(K:at(hump, hump.total * o[1]), rad(o[2]), 0.06)
			H.crystal(K, "Body", ICE, pos, (nrm + Vector3.new(0, 0.4, 0.5)).Unit, o[3], o[4], 26)
		end
		local back, bn = K:surface(K:at(torso, 1.6), math.pi, 0.06)
		H.crystal(K, "Body", ICE, back, (bn + Vector3.new(0, 0.6, 0)).Unit, 1.1, 4, 24)
		-- shaggy strands with icicle tips hanging off the flanks
		for s = 0.6, torso.total - 0.4, 0.6 do
			local smp = K:at(torso, s)
			for _, th in { rad(100), rad(-100) } do
				local pos, nrm = K:surface(smp, th, 0.04)
				local d = (nrm * 0.25 + Vector3.new(0, -1, 0)).Unit
				K:chain("Body", { "Fur", "FurDark" }, pos, d, Vector3.xAxis, { n = 2, len = 0.8, w0 = 0.3, w1 = 0.2, bend = 0, tip = false, depth = 1.4 })
				H.point(K, "Body", "Ice", pos + d * 0.98, d, 0.2)
			end
		end
		for _, x in { 1, -1 } do
			-- short thick legs, big feet with ice claws
			local g = x == 1 and "LegL" or "LegR"
			local leg = H.limb(K, g, {
				{ 0.8 * x, 2.5, 0.3, 0.7 },
				{ 0.98 * x, 1.42, 0.04, 0.58 },
				{ 0.92 * x, 0.46, 0.3, 0.42 },
			}, { step = 0.46, cores = { "Fur", "FurDark" }, tiles = { shaggy(0.96, 6, 0.9), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end })
			local foot = CFrame.new(0.94 * x, 0.2, 0.1) * CFrame.Angles(0, rad(-10 * x), 0)
			K:block(g, "SkinDark", foot, Vector3.new(0.96, 0.4, 1.2))
			for t = -1, 1 do
				local dirT = CFrame.Angles(0, rad(t * 20 - 10 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
				local base = foot * Vector3.new(t * 0.3, 0, -0.5)
				K:chain(g, { "Claw", "ClawTip" }, base, (dirT - Vector3.new(0, 0.3, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 2, len = 0.4, w0 = 0.15, w1 = 0.09, bend = -30 })
			end
			-- long arms ending in huge hands of ice claws
			local ga = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, ga, {
				{ 1.75 * x, 5.6, -0.35, 0.66 },
				{ 2.34 * x, 4.0, -0.42, 0.6 },
				{ 2.22 * x, 2.3, -0.7, 0.58 },
			}, { step = 0.46, cores = { "Fur", "Fur" }, tiles = { shaggy(0.96, 6, 0.92), shaggy(0.94, 6, 0.9) }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end })
			H.vein(K, ga, "IceGlow", arm[1], rad(-60) * x, 0.2, arm[1].total - 0.1, VEIN)
			-- glacier pauldron shingled over the shoulder, an ice bracer on the forearm
			for i, o in { { 80, 0.95, 1.1, 1.3 }, { 46, 0.9, 0.96, 1.2 }, { 14, 0.86, 0.84, 1.1 } } do
				local an = rad(o[1])
				local P = CFrame.new(1.6 * x + math.cos(an) * o[2] * x, 5.62 + math.sin(an) * o[2], -0.32) * CFrame.Angles(0, 0, (an - math.pi / 2) * x)
				K:block(ga, i == 2 and "IceDeep" or "Ice", P, Vector3.new(o[3], 0.24, o[4]))
				H.point(K, ga, "ClawTip", P * Vector3.new(0, 0.34, 0), P:VectorToWorldSpace(Vector3.new(0.3 * x, 1, 0)).Unit, 0.26)
			end
			local fore = arm[2]
			for r = 0, 5 do
				K:tile(ga, r % 2 == 0 and "Ice" or "IceDeep", K:at(fore, fore.total * 0.55), rad(r * 60 + 15), 0.84, 0.7, 0.2, 0, 0, -0.9)
			end
			H.point(K, ga, "ClawTip", K:at(fore, fore.total * 0.5).p + Vector3.new(0.75 * x, 0.1, 0), Vector3.new(x, 0.4, 0).Unit, 0.3)
			local hand = CFrame.new(2.2 * x, 1.86, -0.78) * CFrame.Angles(rad(-8), rad(-8 * x), 0)
			K:block(ga, "SkinDark", hand, Vector3.new(0.84, 0.66, 0.72))
			for f = 1, 4 do
				local base = hand * Vector3.new((f - 2.5) * 0.2, -0.28, -0.28)
				local d = hand:VectorToWorldSpace(Vector3.new((f - 2.5) * 0.12, -1, -0.5)).Unit
				K:chain(ga, { "SkinDark", "Ice", "ClawTip" }, base, d, hand.RightVector, { n = 3, len = 0.62, w0 = 0.16, w1 = 0.08, bend = 22 })
			end
			K:chain(ga, { "SkinDark", "ClawTip" }, hand * Vector3.new(-0.42 * x, -0.1, -0.2), hand:VectorToWorldSpace(Vector3.new(-0.5 * x, -0.6, -0.7)).Unit, hand.LookVector, { n = 2, len = 0.44, w0 = 0.15, w1 = 0.08, bend = 20 })
		end
		H.gorillaHead(K, {
			frame = HEAD,
			scale = HS,
			keys = { fur = "Fur", furDark = "FurDark", face = "Skin", faceDark = "SkinDark", brow = "Frost", nose = "Nose" },
			crest = { "Fur", "FurLight", "Fur", "Ice" },
			crestH = 0.9,
			open = 24,
			browTilt = 14,
			muzzleW = 1.1,
			eye = { w = 0.16, h = 0.065, y = 0.25 },
			fangs = { upper = 0.22, lower = 0.14, tusks = 0.42 },
			extras = function(K, cf, p, v, JAW)
				-- huge curling ram horns of ice
				for _, x in { 1, -1 } do
					H.curve(K, "Head", { "IceDeep", "Ice", "Ice", "ClawTip" }, {
						p(0.4 * x, 0.6, -0.2),
						p(0.82 * x, 0.92, 0.02),
						p(1.12 * x, 0.66, 0.24),
						p(1.08 * x, 0.24, -0.04),
						p(0.86 * x, 0.12, -0.42),
						p(0.82 * x, 0.34, -0.74),
					}, 0.32, 0.09, 0.16)
					K:block("Head", "Ice", cf(0.22 * x, 0.56, -0.68, -12, -6 * x, 14 * x), Vector3.new(0.5, 0.08, 0.22))
				end
				-- icicles hanging from the brow and a beard of icicles under the jaw
				for _, o in { { 0.42, 0.16 }, { -0.42, 0.16 }, { 0.0, 0.18 }, { 0.5, 0.11 }, { -0.5, 0.11 } } do
					H.fang(K, "Head", "Ice", p(o[1], 0.36, -0.8), v(0, -1, -0.15), o[2], 0.07)
				end
				for _, o in { { 0.0, 0.34 }, { 0.15, 0.26 }, { -0.15, 0.26 }, { 0.28, 0.18 }, { -0.28, 0.18 } } do
					H.fang(K, "Jaw", "Ice", JAW * Vector3.new(o[1], -0.26, -0.48), JAW:VectorToWorldSpace(Vector3.new(0, -1, -0.1)).Unit, o[2], 0.09)
				end
			end,
		})
		GK.lids(K, Color3.fromHex("2C3648"))
	end,
}
