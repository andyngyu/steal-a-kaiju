local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Uncommon / earth: a stone-armoured silverback. Dark brown fur with a grey saddle down the spine,
-- slabs of rock grown over its shoulders and knuckles like pauldrons and gauntlets, a stone-capped crest, sunken
-- amber eyes, bared fangs.
return {
	Seed = 61,
	Vary = 0.07,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "3E2F27",
		FurDark = "281E19",
		FurLight = "5C4639",
		Silver = "6F6862",
		Skin = "4C433E",
		SkinDark = "332C29",
		Armour = { "6A6458", Material = "Slate" },
		ArmourLight = { "8E8676", Material = "Slate" },
		Tooth = "EAE2CC",
		Mouth = "4E1A1A",
		Eye = { "FF9A1A", Neon = true },
		Socket = "100C0A",
		Claw = "2A2420",
		ClawTip = "CFC5AA",
	},
	Joints = H.APE_JOINTS,
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		H.ape(K, {
			back = "Silver",
			ears = true,
			crest = { "Armour", "ArmourLight", "Armour" },
			armour = function(K, parts)
				-- stone pauldrons layered over each shoulder, stone gauntlets on the forearms and knuckles
				for _, x in { 1, -1 } do
					local ga = x == 1 and "ArmL" or "ArmR"
					local up = parts.arms[ga][1]
					for i, f in { 0.08, 0.3 } do
						K:tile(ga, i == 1 and "ArmourLight" or "Armour", K:at(up, up.total * f), rad(70) * x, 0.92 - i * 0.12, 0.62, 0.17, 14, 4, 0.2)
					end
					local fore = parts.arms[ga][2]
					for i, f in { 0.45, 0.72 } do
						K:tile(ga, i == 1 and "Armour" or "ArmourLight", K:at(fore, fore.total * f), rad(-10) * x, 0.7, 0.5, 0.15, 10, 4, 0.25)
					end
					K:block(ga, "Armour", CFrame.new(1.44 * x, 0.56, -1.0) * CFrame.Angles(rad(-20), rad(-8 * x), 0), Vector3.new(0.7, 0.18, 0.4))
					for k = 1, 2 do
						K:spike(ga, "ArmourLight", Vector3.new((1.3 + k * 0.12) * x, 0.66, -1.1), Vector3.new(0, 0.6, -1).Unit, Vector3.xAxis, 0.14, 0.12)
					end
				end
				H.studs(K, "Body", parts.mantle, { 0, rad(40), rad(-40) }, 0.5, 0.3, 0.3, parts.mantle.total - 0.3, { "Armour", "ArmourLight" })
			end,
		})
	end,
}
