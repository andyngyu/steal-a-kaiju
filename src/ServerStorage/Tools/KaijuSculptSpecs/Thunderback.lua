local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Legendary / storm: a storm gorilla that drags its own thundercloud. Slate-navy fur with a silver
-- saddle, storm-iron pauldrons, lightning crackling down its arms and spine, yellow eyes, and a black cloud riding
-- over its shoulders spitting bolts.
return {
	Seed = 71,
	Vary = 0.06,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "2F3442",
		FurDark = "1D2029",
		FurLight = "4B5263",
		Silver = "7C8292",
		Skin = "2C3140",
		SkinDark = "1C2029",
		Armour = { "3A4250", Material = "Slate" },
		ArmourLight = { "5C6678", Material = "Slate" },
		Bolt = { "FFD23F", Neon = true },
		Cloud1 = "3E4352",
		Cloud2 = "2C303C",
		Cloud3 = "555B6A",
		Tooth = "ECE8DC",
		Mouth = "4A1A22",
		Eye = { "FFD23F", Neon = true },
		Socket = "0A0C12",
		Claw = "1A1E26",
		ClawTip = "D6DCE6",
	},
	Joints = H.APE_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		H.ape(K, {
			back = "Silver",
			crest = { "Armour", "ArmourLight", "Armour" },
			head = function(K, hcf, hp, hv)
				-- swept storm-iron horns with crackling tips
				for _, x in { 1, -1 } do
					K:chain("Head", { "Armour", "Armour", "ArmourLight", "Bolt" }, hp(0.36 * x, 0.56, -0.4), hv(0.85 * x, 0.55, -0.05), hv(0, 0, 1), { n = 4, len = 1.0, w0 = 0.22, w1 = 0.09, bend = 20 * x })
				end
			end,
			armour = function(K, parts)
				for _, x in { 1, -1 } do
					local ga = x == 1 and "ArmL" or "ArmR"
					local up, fore = parts.arms[ga][1], parts.arms[ga][2]
					for i, f in { 0.08, 0.3 } do
						K:tile(ga, i == 1 and "ArmourLight" or "Armour", K:at(up, up.total * f), rad(70) * x, 0.9 - i * 0.12, 0.6, 0.17, 14, 4, 0.2)
					end
					K:tile(ga, "Armour", K:at(fore, fore.total * 0.62), rad(-10) * x, 0.7, 0.6, 0.16, 10, 4, 0.25)
					-- lightning down the outside of each arm
					local a0 = K:surface(K:at(up, up.total * 0.42), rad(100) * x, -0.04)
					local a1 = K:surface(K:at(fore, fore.total * 0.35), rad(100) * x, -0.04)
					H.bolt(K, ga, "Bolt", a0, a1, Vector3.zAxis, 5, 0.07, 0.12)
				end
				-- lightning crackling down the spine
				local s0 = K:surface(K:at(parts.torso, 0.3), 0, -0.04)
				local s1 = K:surface(K:at(parts.torso, parts.torso.total - 0.2), 0, -0.04)
				H.bolt(K, "Body", "Bolt", s0, s1, Vector3.xAxis, 6, 0.08, 0.16)
			end,
			extras = function(K)
				H.cloud(K, "Cloud", { "Cloud2", "Cloud1", "Cloud3", "Cloud2" }, Vector3.new(0, 4.62, 0.36), Vector3.new(1.35, 0.36, 0.78), 18, "Bolt", 4)
			end,
		})
	end,
}
