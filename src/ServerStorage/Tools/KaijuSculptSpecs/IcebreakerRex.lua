local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Legendary / ice: a tyrant rex that rams through glaciers. Steel-blue hide banded in deep blue, a
-- crest of jagged ice crystals down its back and tail, a massive ice ram over the snout (the "icebreaker") and ice
-- horns over the brow, cyan eyes.
return {
	Seed = 41,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = "4F6884",
		HideDark = "3A4F68",
		HideLight = "8BA6BE",
		Back = "202D3E",
		Belly = "DCE6EE",
		Belly2 = "BCCBD8",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Armour = { "B5DCF0", Material = "Ice" },
		ArmourLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Claw = "22303E",
		ClawTip = "D6EEFF",
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
	},
	Joints = H.REX_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		H.rex(K, {
			core = "HideDark",
			footCore = "Back",
			color = H.skin({ stripe = 42, band = 92, every = 3 }),
			crest = function(K, torso, neck, tail)
				local keys = { "Ice", "IceDeep", "Ice", "IceGlow" }
				H.crystalRidge(K, "Head", neck, { from = 0.15, to = neck.total - 0.1, every = 0.34, size = function(u) return 0.46 + 0.2 * u end, count = 3, keys = keys, lean = 26 })
				H.crystalRidge(K, "Body", torso, { from = 0.2, to = torso.total - 0.2, every = 0.42, size = function(u) return 0.9 + 0.3 * math.sin(u * math.pi) - 0.2 * u end, count = 4, keys = keys, lean = 24, thetas = { 0, rad(55), rad(-55) }, sideScale = 0.42 })
				H.crystalRidge(K, "Tail", tail, { from = 0.2, to = tail.total - 0.3, every = 0.4, size = function(u) return 0.6 * (1 - u) + 0.16 end, count = 3, keys = keys, lean = 30 })
			end,
			head = function(K, hcf, hp, hv)
				-- the ram: a thick ice prow over the snout rising into a swept nose horn
				K:block("Head", "Armour", hcf(0, 0.46, -1.2, -12, 0, 0), Vector3.new(0.46, 0.2, 0.9))
				K:block("Head", "ArmourLight", hcf(0, 0.58, -1.0, -20, 0, 0), Vector3.new(0.3, 0.2, 0.6))
				K:chain("Head", { "Ice", "IceDeep", "Ice" }, hp(0, 0.6, -1.4), hv(0, 1, -0.55), hv(1, 0, 0), { n = 3, len = 0.62, w0 = 0.3, w1 = 0.14, bend = 20 })
				for _, x in { 1, -1 } do
					H.crystal(K, "Head", { "Ice", "IceGlow", "IceDeep" }, hp(0.36 * x, 0.68, -0.4), hv(0.5 * x, 0.7, 0.5), 0.6, 3, 22)
				end
			end,
			extras = function(K, parts)
				H.studs(K, "Body", parts.torso, { rad(84), rad(-84) }, 0.6, 0.22, 0.4, parts.torso.total - 0.3, { "Ice", "IceDeep" })
			end,
			tailTip = { "IceDeep", "Ice" },
		})
	end,
}
