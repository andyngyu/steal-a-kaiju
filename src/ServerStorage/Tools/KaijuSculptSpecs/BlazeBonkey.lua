local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Epic / fire: a hulking volcanic gorilla. Charcoal basalt fur over a molten core that glows through
-- every crack, a flame mane licking up from its crest and along its shoulders, glowing knuckles, a tail that ends in
-- fire, ember eyes and a furnace of a mouth.
return {
	Seed = 67,
	Vary = 0.06,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = { "2E2523", Material = "Basalt" },
		FurDark = { "1C1716", Material = "Basalt" },
		FurLight = { "4A3A33", Material = "Basalt" },
		Ash = { "3E3532", Material = "Basalt" },
		Skin = { "3A2A24", Material = "Basalt" },
		SkinDark = { "241A17", Material = "Basalt" },
		Magma = { "E2470F", Neon = true },
		MagmaHot = { "FF7A1A", Neon = true },
		Flame = { "FFB233", Neon = true },
		Armour = { "302A29", Material = "Basalt" },
		ArmourLight = { "4D4440", Material = "Basalt" },
		Tooth = "E2D2B4",
		Mouth = { "C8380C", Neon = true },
		Eye = { "FFC233", Neon = true },
		Socket = "0C0909",
		Claw = "151214",
		ClawTip = { "E8601A", Neon = true },
	},
	Joints = H.APE_JOINTS,
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local FLAME = { "Magma", "MagmaHot", "Flame" }
		H.ape(K, {
			back = "Ash",
			ears = true,
			tail = true,
			overlap = 0.96,
			crest = { "Armour", "MagmaHot", "Armour" },
			head = function(K, hcf, hp, hv)
				for i = -1, 1 do
					H.flame(K, "Head", FLAME, hp(i * 0.24, 0.62, -0.08 + math.abs(i) * 0.12), hv(i * 0.4, 1, 0.6), hv(1, 0, 0), 1.0 - math.abs(i) * 0.25, 0.26, 20)
				end
			end,
			armour = function(K, parts)
				for _, x in { 1, -1 } do
					local ga = x == 1 and "ArmL" or "ArmR"
					local up, fore = parts.arms[ga][1], parts.arms[ga][2]
					-- molten seams down the arms, basalt gauntlets, glowing knuckles
					K:tile(ga, "Magma", K:at(up, up.total * 0.5), rad(20) * x, 0.07, up.total * 0.8, 0.06, 0, 0, 0)
					K:tile(ga, "Magma", K:at(fore, fore.total * 0.45), rad(-25) * x, 0.07, fore.total * 0.7, 0.06, 0, 0, 0)
					for i, f in { 0.5, 0.78 } do
						K:tile(ga, i == 1 and "Armour" or "ArmourLight", K:at(fore, fore.total * f), rad(-10) * x, 0.7, 0.5, 0.16, 10, 4, 0.25)
					end
					K:block(ga, "MagmaHot", CFrame.new(1.44 * x, 0.42, -1.14) * CFrame.Angles(rad(-10), rad(-8 * x), 0), Vector3.new(0.64, 0.1, 0.08))
				end
				-- flames licking up along the shoulders
				for i = 1, 5 do
					local smp = K:at(parts.mantle, parts.mantle.total * (i / 6))
					local pos = K:surface(smp, 0, 0.1)
					H.flame(K, "Body", FLAME, pos, (smp.U + smp.R * 0.7).Unit, smp.T, 0.8 + (i == 3 and 0.3 or 0) - math.abs(i - 3) * 0.08, 0.26, 22)
				end
			end,
			extras = function(K, parts)
				-- molten cracks running over the body, mantle and limbs
				H.cracks(K, "Body", "Magma", parts.torso, { rad(55), rad(-55), rad(150), rad(-150) }, 0.2, parts.torso.total - 0.15, 0.28, 0.08, 0.1)
				H.cracks(K, "Body", "Magma", parts.mantle, { rad(35), rad(-35) }, 0.25, parts.mantle.total - 0.25, 0.3, 0.08, 0.12)
				for _, x in { 1, -1 } do
					local g = x == 1 and "LegL" or "LegR"
					H.cracks(K, g, "Magma", parts.legs[g][1], { rad(40) * x }, 0.1, parts.legs[g][1].total - 0.1, 0.26, 0.08, 0.1)
				end
				local tip = K:at(parts.tail, parts.tail.total)
				H.flame(K, "Tail", FLAME, tip.p, (tip.T + Vector3.new(0, 0.6, 0)).Unit, tip.R, 0.8, 0.26, 24)
			end,
		})
	end,
}
