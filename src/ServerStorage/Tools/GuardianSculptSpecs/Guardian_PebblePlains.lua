local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Pebble Plains guardian: the Pebble Behemoth, the green dinosaur grown into a titan. A heavy tyrant lizard four times
-- the size of a Pebblesaur: olive hide banded dark down the back, a pale belly, a towering ridge of stepped stone
-- plates over a seam of glowing amber down the spine, boulder armour on the shoulders and thighs, a crown of stone
-- frills behind the skull, three great stone horns, amber eyes under a stone brow, a jaw full of teeth, and a spiked
-- stone club on the end of its tail.
return {
	Seed = 211,
	Vary = 0.06,
	Scale = 4.0,
	RootSize = { 7.5, 6, 9.5 },
	HipHeight = 1.6,
	Palette = {
		Hide = "4E5A34",
		HideDark = "37402A",
		HideLight = "7A7F4E",
		Back = "262D1A",
		Belly = "BCB28A",
		Belly2 = "A39A72",
		Armour = { "6E6A5C", Material = "Slate" },
		ArmourLight = { "948E7C", Material = "Slate" },
		Stone = { "6E6A5C", Material = "Slate" },
		StoneLight = { "948E7C", Material = "Slate" },
		StoneDark = { "4C4A40", Material = "Slate" },
		Amber = { "FF9A1A", Neon = true },
		Tooth = "EDE5CF",
		Mouth = "5C2020",
		Eye = { "FFB21A", Neon = true },
		Socket = "10130B",
		Claw = "24221C",
		ClawTip = "CFC5AA",
	},
	Joints = H.REX_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		local PLATE = { "StoneDark", "Stone", "StoneLight" }
		H.rex(K, {
			color = H.skin({ stripe = 30, band = 80, flank = 100, every = 3 }),
			tiles = { torso = H.plates(0.66), neck = H.plates(0.6), tail = H.plates(0.52, 5) },
			thighArmour = "Stone",
			brow = "StoneDark",
			tailTip = { "Stone", "StoneLight" },
			crest = function(K, torso, neck, tail)
				-- a glowing amber seam down the spine under a towering ridge of stepped stone plates
				for _, seg in { { "Head", neck, 0.66 }, { "Body", torso, 1.0 }, { "Tail", tail, 0.62 } } do
					local g, samples = seg[1], seg[2]
					H.vein(K, g, "Amber", samples, 0, 0.05, samples.total - (g == "Tail" and 0.4 or 0.05), { lift = 0.02, wander = 4, width = 0.12, height = 0.1, step = 0.3 })
				end
				for s = 0.15, neck.total - 0.05, 0.32 do
					local smp = K:at(neck, s)
					local pos, nrm = K:surface(smp, 0, 0.04)
					K:plate("Head", PLATE, pos, nrm, smp.T, { h = 0.5, w = 0.46, t = 0.15, n = 3, lean = 18 })
				end
				for s = 0.2, torso.total - 0.1, 0.36 do
					local u = s / torso.total
					local smp = K:at(torso, s)
					local pos, nrm = K:surface(smp, 0, 0.04)
					K:plate("Body", PLATE, pos, nrm, smp.T, { h = 0.95 - u * 0.25, w = 0.66, t = 0.17, n = 3, lean = 16 })
					for _, x in { 1, -1 } do
						local p2, n2 = K:surface(smp, rad(38) * x, 0.04)
						K:plate("Body", PLATE, p2, n2, smp.T, { h = 0.34, w = 0.36, t = 0.13, n = 2, lean = 14 })
					end
				end
				for s = 0.12, tail.total - 0.5, 0.34 do
					local u = s / tail.total
					local smp = K:at(tail, s)
					local pos, nrm = K:surface(smp, 0, 0.04)
					K:plate("Tail", PLATE, pos, nrm, smp.T, { h = 0.66 * (1 - u) + 0.14, w = 0.5 * (1 - u) + 0.18, t = 0.14, n = 3, lean = 20 })
				end
			end,
			head = function(K, hcf, hp, hv)
				-- three great stone horns: two over the brows sweeping forward, one on the nose
				for _, x in { 1, -1 } do
					H.curve(K, "Head", PLATE, { hp(0.36 * x, 0.62, -0.6), hp(0.52 * x, 1.0, -0.78), hp(0.52 * x, 1.3, -1.1), hp(0.42 * x, 1.42, -1.46) }, 0.26, 0.08, 0.16)
				end
				H.curve(K, "Head", PLATE, { hp(0, 0.36, -1.42), hp(0, 0.64, -1.6), hp(0, 0.86, -1.6) }, 0.22, 0.07, 0.14)
				-- a crown of stone frills fanning back from the skull
				for k = -2, 2 do
					local a = rad(k * 24)
					local base = hp(math.sin(a) * 0.42, 0.52 - math.abs(k) * 0.06, 0.02)
					K:plate("Head", PLATE, base, hv(math.sin(a) * 1.2, 0.8, 0.5), hv(0, 0, 1), { h = 0.62 - math.abs(k) * 0.1, w = 0.4, t = 0.13, n = 3, lean = 24 })
				end
			end,
			extras = function(K, parts)
				-- shingles of stone armour over the shoulders, big hooked claws on the feet
				for _, x in { 1, -1 } do
					for i, o in { { 0.12, 58, 0.62 }, { 0.42, 70, 0.56 }, { 0.3, 84, 0.5 }, { 0.68, 64, 0.48 } } do
						local smp = K:at(parts.torso, o[1])
						K:tile("Body", i % 2 == 0 and "StoneDark" or "Stone", smp, rad(o[2]) * x, o[3], o[3] * 0.9, 0.16, 14, 3, -0.3)
					end
					local g = x == 1 and "LegL" or "LegR"
					local fz = (x == 1 and -0.14 or 0.18) - 0.04
					for t = -1, 1 do
						local dirT = CFrame.Angles(0, rad(t * 20 - 6 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
						local base = Vector3.new(1.14 * x + t * 0.2, 0.16, fz - 0.42) + dirT * 0.2
						K:chain(g, { "Claw", "Claw", "ClawTip" }, base, (dirT - Vector3.new(0, 0.2, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 3, len = 0.42, w0 = 0.15, w1 = 0.08, bend = -30 })
					end
				end
				-- a spiked stone club on the end of the tail
				local tip = K:at(parts.tail, parts.tail.total - 0.18)
				local club = CFrame.fromMatrix(tip.p, tip.R, tip.U)
				K:block("Tail", "Stone", club, Vector3.new(0.7, 0.52, 0.66))
				K:block("Tail", "StoneDark", club * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.5, 0.5, 0.6))
				K:block("Tail", "Amber", club, Vector3.new(0.74, 0.08, 0.5))
				for _, d in { Vector3.new(1, 0.3, 0), Vector3.new(-1, 0.3, 0), Vector3.new(0, 1, 0.2), Vector3.new(0.6, -0.4, 0.4), Vector3.new(-0.6, -0.4, 0.4) } do
					local dir = club:VectorToWorldSpace(d.Unit)
					H.point(K, "Tail", "StoneLight", tip.p + dir * 0.55, dir, 0.24)
				end
			end,
		})
		GK.lids(K, Color3.fromHex("262D1A"))
	end,
}
