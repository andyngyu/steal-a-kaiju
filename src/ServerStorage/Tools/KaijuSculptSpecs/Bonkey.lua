local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Uncommon / earth: the base brawler. A classic knuckle-walking gorilla: a high back sloping down to
-- the hips, a thick neck sunk between massive shoulders, huge forearms planted on the knuckles. Dark brown fur in
-- clean plates, a light tan face and chest, and deliberate grey stone armour on the shoulders, forearms and knuckles
-- only. Face: a tall sagittal crest, a heavy brow over small amber eyes, a wide flat nose, a broad muzzle, four fangs.
local HEAD = CFrame.new(0, 2.9, -1.26) * CFrame.Angles(rad(-4), 0, 0)
local HS = 1.22

return {
	Seed = 61,
	Vary = 0.03,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "3E2A1F",
		FurDark = "2B1D15",
		FurLight = "553A2B",
		Tan = "A8845E",
		TanDark = "866448",
		Brow = "4A3426",
		Nose = "2C2018",
		Skin = "4A3528",
		SkinDark = "33241B",
		Stone = { "7A766C", Material = "Slate" },
		StoneLight = { "A39D90", Material = "Slate" },
		StoneDark = { "5A574F", Material = "Slate" },
		Tooth = "EFE6D0",
		Mouth = "4E1A1A",
		Eye = { "FF9A1A", Neon = true },
		Socket = "100C0A",
		Claw = "2A2420",
		ClawTip = "CFC5AA",
	},
	Joints = {
		Head = { 0, 2.86, -0.8 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.GHEAD_HINGE),
		EarL = H.apeHeadJoint(HEAD, HS, H.GHEAD_EAR),
		EarR = H.apeHeadJoint(HEAD, HS, H.GHEAD_EAR * Vector3.new(-1, 1, 1)),
		ArmL = { 1.2, 3.12, -0.5 },
		ArmR = { -1.2, 3.12, -0.5 },
		LegL = { 0.62, 1.86, 0.58 },
		LegR = { -0.62, 1.86, 0.58 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		-- fur: darker down the back, plain on the flanks, the chest left bare for the tan plates
		local function fur(th)
			local a = math.deg(math.abs(th))
			if a < 42 then
				return "FurDark"
			elseif a < 120 then
				return "Fur"
			end
			return nil
		end
		local torso = K:tube("Body", {
			{ 0, 3.1, -0.52, rx = 1.12, ru = 0.94, rd = 1.0 },
			{ 0, 2.74, 0.02, rx = 1.08, ru = 0.92, rd = 1.0 },
			{ 0, 2.22, 0.46, rx = 0.92, ru = 0.82, rd = 0.82 },
			{ 0, 1.82, 0.7, rx = 0.76, ru = 0.68, rd = 0.66 },
		}, { step = 0.42, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.68, 7, 0.62), color = fur })
		local mantle = K:tube("Body", {
			{ -1.0, 3.36, -0.46, rx = 0.58, ru = 0.64, rd = 0.5 },
			{ 0, 3.56, -0.38, rx = 0.68, ru = 0.68, rd = 0.56 },
			{ 1.0, 3.36, -0.46, rx = 0.58, ru = 0.64, rd = 0.5 },
		}, { step = 0.42, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.64, 6, 0.6), color = function(th)
			local a = math.deg(math.abs(th))
			return a < 48 and "FurDark" or (a < 130 and "Fur" or nil)
		end })
		-- a thick neck sloping from the shoulders down into the back of the head
		for i, o in { { 0, 3.52, -0.72, 1.06, 0.66, 0.9, 34, "FurDark" }, { 0, 3.3, -0.92, 0.9, 0.56, 0.7, 30, "Fur" } } do
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, 0), Vector3.new(o[4], o[5], o[6]))
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, rad(45)), Vector3.new(o[5] * 1.15, o[5] * 1.15, o[6] * 0.96))
		end
		-- the bare tan chest: two heavy pecs over three rows of abdominal plates
		for _, x in { 1, -1 } do
			K:tile("Body", "Tan", K:at(torso, 0.2), rad(180 - 34) * x, 0.94, 0.88, 0.16, 6, 0.5, 0.4)
		end
		for i, f in { 0.66, 1.0, 1.34 } do
			for _, x in { 1, -1 } do
				K:tile("Body", "TanDark", K:at(torso, f), rad(180 - 15) * x, 0.5 - i * 0.04, 0.34, 0.12, 6, 0.5, 0.4)
			end
		end
		for _, x in { 1, -1 } do
			local g = x == 1 and "ArmL" or "ArmR"
			-- huge forearms on short upper arms, fists planted on the knuckles
			local arm, fc = H.apeArm(K, g, x, {
				pts = { { 1.2, 3.12, -0.5, 0.5 }, { 1.58, 2.02, -0.62, 0.54 }, { 1.5, 0.98, -0.84, 0.64 } },
				fist = Vector3.new(0.96, 0.8, 0.94),
				fistKey = "Skin",
				knuckleKey = "SkinDark",
				fur = H.cleanFur(0.6, 6, 0.6),
				foreFur = H.cleanFur(0.7, 6, 0.6),
				color = function(_, ring)
					return ring % 2 == 0 and "Fur" or "FurDark"
				end,
			})
			local fore = arm[2]
			-- stone pauldron: three plates shingled round the shoulder into a domed shell, each with a pale lower rim
			for i, o in { { 82, 0.76, 0.7, 1.08 }, { 46, 0.72, 0.64, 1.0 }, { 12, 0.68, 0.56, 0.92 } } do
				local an = rad(o[1])
				local P = CFrame.new(1.12 * x + math.cos(an) * o[2] * x, 3.36 + math.sin(an) * o[2], -0.5) * CFrame.Angles(0, 0, (an - math.pi / 2) * x)
				K:block(g, i == 2 and "StoneDark" or "Stone", P, Vector3.new(o[3], 0.18, o[4]))
				K:block(g, "StoneLight", P * CFrame.new(o[3] * 0.46 * x, 0.02, 0), Vector3.new(0.1, 0.23, o[4] + 0.04))
			end
			-- a stone bracer wrapping the forearm, pale rims at both ends
			local mid = fore.total * 0.56
			for r = 0, 5 do
				local th = rad(r * 60 + 15 * x)
				K:tile(g, r % 2 == 0 and "Stone" or "StoneDark", K:at(fore, mid), th, 0.66, 0.5, 0.17, 0, 0, -0.9)
				for _, sgn in { -1, 1 } do
					K:tile(g, "StoneLight", K:at(fore, mid + sgn * 0.3), th, 0.64, 0.1, 0.2, 0, 0, -0.9)
				end
			end
			-- stone knuckle-dusters over the planted fist and a slab over the back of the hand
			local fs = Vector3.new(0.96, 0.8, 0.94)
			K:block(g, "Stone", fc * CFrame.new(0, fs.Y * 0.44, 0.02) * CFrame.Angles(rad(-8), 0, 0), Vector3.new(fs.X * 1.06, 0.16, fs.Z * 0.84))
			for f = 1, 4 do
				K:block(g, f % 2 == 0 and "StoneLight" or "Stone", fc * CFrame.new((f - 2.5) / 4 * fs.X, -fs.Y * 0.1, -fs.Z * 0.6), Vector3.new(fs.X * 0.22, fs.Y * 0.36, 0.14))
			end
			-- short bowed legs, leathery feet
			local lg = x == 1 and "LegL" or "LegR"
			H.limb(K, lg, {
				{ 0.62 * x, 1.86, 0.58, 0.5 },
				{ 0.88 * x, 1.08, 0.2, 0.42 },
				{ 0.82 * x, 0.36, 0.62, 0.32 },
			}, { step = 0.42, cores = { "Fur", "FurDark" }, tiles = { H.cleanFur(0.56, 6, 0.56), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurDark" end })
			K:block(lg, "SkinDark", CFrame.new(0.84 * x, 0.14, 0.42) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.58, 0.28, 0.86))
			for f = -1, 1 do
				K:block(lg, "Skin", CFrame.new(0.84 * x + f * 0.17 - 0.05 * x, 0.12, 0.0) * CFrame.Angles(0, rad(-10 * x + f * 8), 0), Vector3.new(0.16, 0.2, 0.22))
			end
		end
		H.gorillaHead(K, {
			frame = HEAD,
			scale = HS,
			keys = { fur = "Fur", furDark = "FurDark", face = "Tan", faceDark = "TanDark", brow = "Brow", nose = "Nose" },
			open = 20,
			ears = true,
			fangs = { upper = 0.21, lower = 0.15 },
		})
	end,
}
