local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Epic / earth: a tyrant rex whose stomps split the ground. Deep jungle-green hide in bold dark tiger
-- bands, a crest of amethyst crystal clusters erupting along its spine (its purple "rumble"), crystal horns behind the
-- brow, violet eyes and a jaw full of teeth.
return {
	Seed = 23,
	Vary = 0.07,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = "3B4E31",
		HideDark = "2A3A23",
		HideLight = "68764E",
		Back = "182115",
		Belly = "BDB18C",
		Belly2 = "A0956F",
		Armour = { "4A4652", Material = "Slate" },
		ArmourLight = { "6E6878", Material = "Slate" },
		Crystal = { "7B4BE0", Material = "Glass" },
		CrystalLight = { "A684FF", Material = "Glass" },
		CrystalGlow = { "6250FF", Neon = true },
		Tooth = "EDE6D2",
		Claw = "2E2A30",
		ClawTip = "CFC5AA",
		Mouth = "541C1C",
		Eye = { "7C6BFF", Neon = true },
		Socket = "120E18",
	},
	Joints = H.REX_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		H.rex(K, {
			color = H.skin({ stripe = 40, band = 96, every = 2 }),
			crest = function(K, torso, neck, tail)
				local keys = { "Crystal", "CrystalLight", "CrystalGlow", "Crystal" }
				H.crystalRidge(K, "Head", neck, { from = 0.15, to = neck.total - 0.1, every = 0.36, size = function(u) return 0.42 + 0.18 * u end, count = 3, keys = keys })
				H.crystalRidge(K, "Body", torso, { from = 0.2, to = torso.total - 0.2, every = 0.48, size = function(u) return 0.78 + 0.25 * math.sin(u * math.pi) end, count = 4, keys = keys, thetas = { 0, rad(52), rad(-52) }, sideScale = 0.45 })
				H.crystalRidge(K, "Tail", tail, { from = 0.2, to = tail.total - 0.3, every = 0.42, size = function(u) return 0.55 * (1 - u) + 0.16 end, count = 3, keys = keys })
			end,
			head = function(K, hcf, hp, hv)
				for _, x in { 1, -1 } do
					H.crystal(K, "Head", { "Crystal", "CrystalGlow", "CrystalLight" }, hp(0.36 * x, 0.66, -0.38), hv(0.45 * x, 0.8, 0.45), 0.5, 3, 24)
				end
			end,
			extras = function(K, parts)
				H.studs(K, "Body", parts.torso, { rad(80), rad(-80) }, 0.55, 0.22, 0.4, parts.torso.total - 0.3, { "Armour", "ArmourLight" })
			end,
		})
	end,
}
