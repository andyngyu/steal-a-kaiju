local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Epic / earth: the heavyweight. A bigger, heavier tyrant than anything else in the plains, with a
-- massive head and jaw on a thick neck, deep jungle-green hide in bold tiger bands, giant amethyst crystal spines
-- erupting from its shoulders and down its back, crystal horns, violet eyes.
local HEAD_SCALE = 1.24
local JAW = H.REX_HEAD.Position + (H.REX_HEAD * H.REX_HINGE - H.REX_HEAD.Position) * HEAD_SCALE

return {
	Seed = 23,
	Vary = 0.07,
	Scale = 1.08,
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
	Joints = {
		Head = H.REX_JOINTS.Head,
		Jaw = JAW,
		LegL = H.REX_JOINTS.LegL,
		LegR = H.REX_JOINTS.LegR,
		ArmL = H.REX_JOINTS.ArmL,
		ArmR = H.REX_JOINTS.ArmR,
		Tail = H.REX_JOINTS.Tail,
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local KEYS = { "Crystal", "CrystalLight", "CrystalGlow", "Crystal", "CrystalLight", "Crystal" }
		H.rex(K, {
			headScale = HEAD_SCALE,
			neckScale = 1.2,
			color = H.skin({ stripe = 40, band = 96, every = 2 }),
			crest = function(K, torso, neck, tail)
				-- giant crystal spines bursting from each shoulder
				for _, x in { 1, -1 } do
					local smp = K:at(torso, 0.4)
					local pos, nrm = K:surface(smp, rad(46) * x, 0.12)
					H.crystal(K, "Body", KEYS, pos, (nrm + smp.U * 0.7 + smp.T * 0.25).Unit, 1.55, 6, 24)
				end
				-- tall single spines down the back and the neck, shrinking down the tail
				for s = 0.9, torso.total - 0.15, 0.42 do
					local smp = K:at(torso, s)
					local pos = K:surface(smp, 0, 0.1)
					H.crystal(K, "Body", KEYS, pos, (smp.U + smp.T * 0.35).Unit, 1.2 - (s / torso.total) * 0.35, 3, 14)
				end
				for s = 0.2, neck.total - 0.15, 0.36 do
					local smp = K:at(neck, s)
					H.crystal(K, "Head", KEYS, K:surface(smp, 0, 0.1), (smp.U + smp.T * 0.4).Unit, 0.7, 3, 16)
				end
				H.crystalRidge(K, "Tail", tail, { from = 0.2, to = tail.total - 0.3, every = 0.42, size = function(u) return 0.75 * (1 - u) + 0.18 end, count = 3, keys = KEYS })
			end,
			head = function(K, hcf, hp, hv)
				for _, x in { 1, -1 } do
					H.crystal(K, "Head", { "Crystal", "CrystalGlow", "CrystalLight" }, hp(0.36 * x, 0.66, -0.38), hv(0.45 * x, 0.8, 0.45), 0.62, 4, 24)
				end
			end,
			extras = function(K, parts)
				H.studs(K, "Body", parts.torso, { rad(84), rad(-84) }, 0.55, 0.24, 0.4, parts.torso.total - 0.3, { "Armour", "ArmourLight" })
			end,
		})
	end,
}
