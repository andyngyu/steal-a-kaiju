local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Epic / ice: a yeti gorilla. Frost-white fur with a pale saddle, slate-blue leathery face and
-- chest, clusters of ice crystals bursting from its shoulders and back, ice gauntlets with icicle knuckles, cyan eyes.
return {
	Seed = 73,
	Vary = 0.05,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "B3C1CF",
		FurDark = "8899AC",
		FurLight = "D6E0EA",
		Frost = "E4EDF5",
		Skin = "34404F",
		SkinDark = "222B37",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Armour = { "B5DCF0", Material = "Ice" },
		ArmourLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = "D6EEFF",
	},
	Joints = H.APE_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		H.ape(K, {
			back = "Frost",
			crest = { "Ice", "IceDeep", "Ice" },
			head = function(K, hcf, hp, hv)
				H.crystal(K, "Head", ICE, hp(0, 0.7, -0.1), hv(0, 1, 0.5), 0.5, 3, 24)
			end,
			armour = function(K, parts)
				for _, x in { 1, -1 } do
					local ga = x == 1 and "ArmL" or "ArmR"
					local up, fore = parts.arms[ga][1], parts.arms[ga][2]
					-- crystals bursting from the shoulders, ice gauntlets, icicle knuckles
					local pos, nrm = K:surface(K:at(up, 0.12), rad(60) * x, 0.05)
					H.crystal(K, ga, ICE, pos, (nrm + Vector3.new(0, 0.9, 0.3)).Unit, 0.85, 4, 30)
					for i, f in { 0.5, 0.78 } do
						K:tile(ga, i == 1 and "Armour" or "ArmourLight", K:at(fore, fore.total * f), rad(-10) * x, 0.7, 0.5, 0.16, 10, 4, 0.25)
					end
					for k = -1, 1 do
						H.crystal(K, ga, { "Ice", "IceDeep" }, Vector3.new((1.44 + k * 0.18) * x, 0.6, -1.08), Vector3.new(0, 0.5, -1), 0.3, 2, 16)
					end
				end
				H.crystalRidge(K, "Body", parts.torso, { from = 0.3, to = parts.torso.total - 0.4, every = 0.5, size = function(u) return 0.7 * (1 - u) + 0.3 end, count = 3, keys = ICE, lean = 30 })
			end,
		})
	end,
}
