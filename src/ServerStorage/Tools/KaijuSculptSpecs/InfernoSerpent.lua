local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Mythic / fire: a fire dragon-serpent. Scorched blood-red and obsidian scales cracked over a molten
-- core, a mane of living flame running from the crown of its head down the whole length of its spine, swept obsidian
-- horns, a glowing maw with long fangs, a tongue of fire, ember eyes.
return {
	Seed = 113,
	Vary = 0.05,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "4A1E18", Material = "Basalt" },
		HideDark = { "2C110E", Material = "Basalt" },
		HideLight = { "7A3424", Material = "Basalt" },
		Back = { "180908", Material = "Basalt" },
		Belly = { "9A5226", Material = "Basalt" },
		Belly2 = { "7A3E1C", Material = "Basalt" },
		Magma = { "E2470F", Neon = true },
		MagmaHot = { "FF7A1A", Neon = true },
		Flame = { "FFB233", Neon = true },
		Horn = { "1E1716", Material = "Basalt" },
		HornLight = { "3E3230", Material = "Basalt" },
		Tooth = "EFE2C6",
		Mouth = { "C8380C", Neon = true },
		Tongue = { "FF7A1A", Neon = true },
		Eye = { "FFC233", Neon = true },
		Socket = "0C0909",
	},
	Joints = H.SERPENT_JOINTS,
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		local FLAME = { "Magma", "MagmaHot", "Flame" }
		H.serpent(K, {
			core = "Magma",
			coreCap = "HideDark",
			coreScale = 0.62,
			overlap = 0.92,
			crest = function(K, segs)
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3", "Seg4", "Tail" } do
					local smp0 = segs[g]
					local size = ({ Neck = 0.62, Seg1 = 0.72, Seg2 = 0.66, Seg3 = 0.56, Seg4 = 0.44, Tail = 0.32 })[g]
					for s = 0.12, smp0.total - 0.12, 0.3 do
						local smp = K:at(smp0, s)
						local pos = K:surface(smp, 0, 0.08)
						H.flame(K, g, FLAME, pos, (smp.U + smp.T * 0.45).Unit, smp.R, size * K:rand(0.8, 1.15), 0.2, 22)
					end
				end
			end,
			head = function(K, hcf, hp, hv)
				for i = -1, 1 do
					H.flame(K, "Head", FLAME, hp(i * 0.16, 0.42, -0.1), hv(i * 0.3, 1, 0.7), hv(1, 0, 0), 0.7 - math.abs(i) * 0.15, 0.2, 20)
				end
			end,
		})
	end,
}
