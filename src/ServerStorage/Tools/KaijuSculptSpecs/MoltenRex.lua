local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Legendary / lava: a tyrant rex of cooled basalt over a molten core. Plates are left out in bands down
-- its flanks so the magma glows through like cracks; volcanic vent spikes with molten tips down the spine, a glowing
-- furnace of a mouth, ember eyes, obsidian claws with hot tips.
return {
	Seed = 37,
	Vary = 0.06,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = { "2C2523", Material = "Basalt" },
		HideDark = { "1E1918", Material = "Basalt" },
		HideLight = { "4A3B34", Material = "Basalt" },
		Back = { "141010", Material = "Basalt" },
		Belly = { "6B3018", Material = "Basalt" },
		Belly2 = { "4F2414", Material = "Basalt" },
		Magma = { "E2470F", Neon = true },
		MagmaHot = { "FF7A1A", Neon = true },
		Armour = { "2F2A2C", Material = "Basalt" },
		ArmourLight = { "4F4643", Material = "Basalt" },
		Tooth = "E2D2B4",
		Claw = "151214",
		ClawTip = { "E8601A", Neon = true },
		Mouth = { "C8380C", Neon = true },
		Eye = { "FFAA22", Neon = true },
		Socket = "0C0909",
	},
	Joints = H.REX_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		local base = H.skin({ stripe = 40, band = 100, every = 2 })
		H.rex(K, {
			core = "Magma",
			coreScale = 0.72,
			coreCap = "HideDark",
			mouthGlow = "Mouth",
			-- a cooled crust: plates a little smaller than their spacing, so thin seams of the molten core glow between
			-- every plate
			tiles = {
				torso = { w = 0.7, l = 0.38, t = 0.15, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.86 },
				neck = { w = 0.62, l = 0.32, t = 0.14, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.86 },
				tail = { w = 0.54, n = 5, l = 0.32, t = 0.13, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.86 },
			},
			belly = { key = "Belly", key2 = "Belly2", arc = 48, t = 0.14, wide = 1.0 },
			color = base,
			crest = function(K, torso, neck, tail)
				local keys = { "Armour", "ArmourLight", "MagmaHot" }
				K:ridge("Head", neck, { style = "plate", keys = keys, from = 0.1, to = neck.total - 0.12, every = 0.36, height = function(u) return 0.46 + 0.22 * u end, thick = 0.17, lean = 16 })
				K:ridge("Body", torso, { style = "plate", keys = keys, from = 0.18, to = torso.total - 0.2, every = 0.44, height = function(u) return 0.86 + 0.26 * math.sin(u * math.pi) - 0.22 * u end, thick = 0.19, lean = 14 })
				K:ridge("Tail", tail, { style = "plate", keys = keys, from = 0.18, to = tail.total - 0.24, every = 0.38, height = function(u) return 0.16 + 0.56 * (1 - u) ^ 1.15 end, thick = function(u) return 0.17 - 0.07 * u end, lean = 22 })
			end,
			head = function(K, hcf, hp, hv)
				-- horns sweeping back from the brow, glowing seams along the cheeks
				for _, x in { 1, -1 } do
					K:chain("Head", { "Armour", "Armour", "ArmourLight", "MagmaHot" }, hp(0.36 * x, 0.66, -0.46), hv(0.35 * x, 0.6, 0.72), hv(1, 0, 0), { n = 4, len = 0.78, w0 = 0.22, w1 = 0.1, bend = 14 })
					K:block("Head", "Magma", hcf(0.52 * x, -0.06, -0.38, 0, -10 * x, 6 * x), Vector3.new(0.3, 0.05, 0.6))
				end
			end,
			extras = function(K, parts)
				H.studs(K, "Body", parts.torso, { rad(84), rad(-84) }, 0.6, 0.24, 0.4, parts.torso.total - 0.3, { "Armour", "ArmourLight" })
				-- molten seams running down the legs
				for _, g in { "LegL", "LegR" } do
					local x = g == "LegL" and 1 or -1
					for i, th in { 60, 115, -150 } do
						local leg = i == 3 and parts.thighs[g .. "Shin"] or parts.thighs[g]
						K:tile(g, "Magma", K:at(leg, leg.total * 0.5), rad(th) * x, 0.07, leg.total * 0.8, 0.06, 0, 0, 0.0)
					end
				end
			end,
			tailTip = { "Armour", "MagmaHot" },
		})
	end,
}
