local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Uncommon / earth: a stone-knuckled brawler gorilla. Clean, deliberate plates of dark brown fur, a tan
-- chest and face, slabs of grey stone only on the shoulders and forearms, huge forearms and fists planted on the
-- knuckles, a heavy brow ridge over small amber eyes, a strong muzzle and jaw with fangs.
local HEAD = CFrame.new(0, 3.34, -1.2) * CFrame.Angles(rad(-4), 0, 0)
local HS = 1.2

return {
	Seed = 61,
	Vary = 0.03,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "3E2A1F",
		FurDark = "2B1D15",
		FurLight = "553A2B",
		Tan = "8E6B4B",
		TanDark = "6E5139",
		Skin = "4A3528",
		SkinDark = "33241B",
		Stone = { "7C786E", Material = "Slate" },
		StoneLight = { "A29C8E", Material = "Slate" },
		Tooth = "EFE6D0",
		Mouth = "4E1A1A",
		Eye = { "FF9A1A", Neon = true },
		Socket = "100C0A",
		Claw = "2A2420",
		ClawTip = "CFC5AA",
	},
	Joints = {
		Head = { 0, 3.04, -0.74 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.APEHEAD_HINGE),
		EarL = H.apeHeadJoint(HEAD, HS, H.APEHEAD_EAR),
		EarR = H.apeHeadJoint(HEAD, HS, H.APEHEAD_EAR * Vector3.new(-1, 1, 1)),
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
			{ 0, 3.06, -0.56, rx = 1.1, ru = 0.92, rd = 1.0 },
			{ 0, 2.72, 0.0, rx = 1.08, ru = 0.92, rd = 1.02 },
			{ 0, 2.22, 0.45, rx = 0.94, ru = 0.84, rd = 0.84 },
			{ 0, 1.82, 0.7, rx = 0.78, ru = 0.7, rd = 0.68 },
		}, { step = 0.42, core = "Fur", coreScale = 0.86, tile = H.cleanFur(0.68, 7, 0.62), color = fur })
		local mantle = K:tube("Body", {
			{ -1.0, 3.34, -0.46, rx = 0.56, ru = 0.62, rd = 0.5 },
			{ 0, 3.52, -0.4, rx = 0.66, ru = 0.66, rd = 0.56 },
			{ 1.0, 3.34, -0.46, rx = 0.56, ru = 0.62, rd = 0.5 },
		}, { step = 0.42, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = H.cleanFur(0.64, 6, 0.6), color = function(th)
			local a = math.deg(math.abs(th))
			return a < 48 and "FurDark" or (a < 130 and "Fur" or nil)
		end })
		-- the bare tan chest: two heavy pecs over three rows of abdominal plates
		for _, x in { 1, -1 } do
			K:tile("Body", "Tan", K:at(torso, 0.2), rad(180 - 34) * x, 0.92, 0.86, 0.16, 6, 0.5, 0.4)
		end
		for i, f in { 0.66, 1.0, 1.34 } do
			for _, x in { 1, -1 } do
				K:tile("Body", "TanDark", K:at(torso, f), rad(180 - 15) * x, 0.5 - i * 0.04, 0.34, 0.12, 6, 0.5, 0.4)
			end
		end
		for _, x in { 1, -1 } do
			-- huge forearms and fists; stone pauldrons on the shoulders and stone guards on the forearms only
			local g = x == 1 and "ArmL" or "ArmR"
			local arm, fist = H.apeArm(K, g, x, {
				pts = { { 1.2, 3.12, -0.5, 0.5 }, { 1.56, 1.98, -0.6, 0.5 }, { 1.48, 0.94, -0.8, 0.58 } },
				fist = Vector3.new(0.9, 0.78, 0.9),
				fistKey = "Skin",
				knuckleKey = "SkinDark",
				fur = H.cleanFur(0.6, 6, 0.6),
				foreFur = H.cleanFur(0.66, 6, 0.6),
				color = function(th, ring)
					return ring % 2 == 0 and "Fur" or "FurDark"
				end,
			})
			local up, fore = arm[1], arm[2]
			-- layered stone pauldron over the shoulder cap, stone guards along the forearm
			local cap = K:at(mantle, x == 1 and mantle.total - 0.12 or 0.12)
			K:tile(g, "Stone", cap, 0, 1.0, 0.86, 0.2, 4, 0, 0.3)
			K:tile(g, "StoneLight", cap, rad(42) * x, 0.8, 0.7, 0.18, 4, 0, 0.3)
			K:tile(g, "Stone", K:at(up, 0.3), rad(80) * x, 0.66, 0.5, 0.15, 4, 0, 0.35)
			for i, f in { 0.38, 0.7 } do
				K:tile(g, i == 1 and "Stone" or "StoneLight", K:at(fore, fore.total * f), rad(-30) * x, 0.86, 0.46, 0.15, 3, 0, 0.35)
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
		H.apeHead(K, {
			frame = HEAD,
			scale = HS,
			fur = "Fur",
			furDark = "FurDark",
			face = "Tan",
			faceDark = "TanDark",
			brow = "Skin",
			ears = true,
			open = 10,
		})
	end,
}
