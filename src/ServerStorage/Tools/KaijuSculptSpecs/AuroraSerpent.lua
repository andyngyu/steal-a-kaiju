local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Mythic / ice: an aurora sea-dragon. Deep midnight-blue scales banded in black, a pale frost belly,
-- great sail-fins along its spine shimmering through aurora green, cyan and violet, ice horns and frills, a crown of
-- ice crystals, mint-glowing eyes, long fangs.
return {
	Seed = 127,
	Vary = 0.05,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = "2A3B6A",
		HideDark = "1C284C",
		HideLight = "45639C",
		Back = "121A33",
		Belly = "C4D8EC",
		Belly2 = "A2BAD4",
		AuroraA = { "3CF0A8", Material = "Glass" },
		AuroraB = { "3CC4FF", Material = "Glass" },
		AuroraC = { "7A5CFF", Material = "Glass" },
		Glow = { "4DFFC4", Neon = true },
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		Horn = { "8FD3F5", Material = "Ice" },
		HornLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Mouth = "2A1E3A",
		Tongue = "6A2A5A",
		Eye = { "4DFFC4", Neon = true },
		Socket = "0A1020",
	},
	Joints = H.SERPENT_JOINTS,
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		local AURORA = { "AuroraA", "AuroraB", "AuroraC" }
		H.serpent(K, {
			crest = function(K, segs)
				local i = 0
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3", "Seg4", "Tail" } do
					local smp0 = segs[g]
					local size = ({ Neck = 0.6, Seg1 = 0.86, Seg2 = 0.8, Seg3 = 0.68, Seg4 = 0.52, Tail = 0.36 })[g]
					for s = 0.12, smp0.total - 0.12, 0.3 do
						i += 1
						local smp = K:at(smp0, s)
						local pos = K:surface(smp, 0, 0.06)
						local a = AURORA[i % 3 + 1]
						local b = AURORA[(i + 1) % 3 + 1]
						K:plate(g, { "HideDark", a, b, "Glow" }, pos, smp.U, smp.T, { h = size * K:rand(0.85, 1.1), w = size * 0.7, t = 0.08, n = 3, lean = 22, shift = 0.16 })
					end
				end
			end,
			head = function(K, hcf, hp, hv)
				H.crystal(K, "Head", { "Ice", "IceDeep", "Glow" }, hp(0, 0.42, -0.12), hv(0, 1, 0.7), 0.5, 3, 22)
			end,
		})
	end,
}
