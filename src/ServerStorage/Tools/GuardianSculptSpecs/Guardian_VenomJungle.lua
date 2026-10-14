local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Venom Jungle guardian: Thornmaw, a tyrant grown out of the jungle floor. A towering rex in deep jungle green, banded
-- dark down the back, its jaws turned into a flytrap: a magenta maw rimmed with long pale cilia, lime nectar dripping
-- from the lips. A ruff of poison-purple petals with glowing tips fans behind the skull under two thorn horns. Bark
-- armour on the shoulders and thighs, moss on the back, big thorns down the spine over a glowing lime seam, vines wound
-- round the limbs and tail, and a thorned seed pod for a tail club.
return {
	Seed = 431,
	Vary = 0.06,
	Scale = 4.2,
	RootSize = { 7.9, 6.3, 10 },
	HipHeight = 1.7,
	Palette = {
		Hide = "2F4C22",
		HideDark = "1F3317",
		HideLight = "4E6C30",
		Back = "16240F",
		Belly = "A9A060",
		Belly2 = "8F8850",
		Armour = { "4A3420", Material = "Wood" },
		ArmourLight = { "6B4E30", Material = "Wood" },
		Bark = { "4A3420", Material = "Wood" },
		BarkDark = { "2E2014", Material = "Wood" },
		Moss = "5E8C2E",
		Maw = "B0245E",
		MawDeep = "5A1030",
		Cilia = "D6DC8A",
		Nectar = { "B6FF3A", Neon = true },
		Petal = "6B2E8A",
		PetalDark = "4A1F62",
		Thorn = "3A2410",
		ThornTip = "C9B98A",
		Vine = "3E6024",
		Leaf = "6FAA38",
		Pod = "5A2A6E",
		PodDark = "3A1A48",
		Tooth = "E8E2B8",
		Mouth = "5A1030",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0E140A",
		Claw = "2A2016",
		ClawTip = "D8CFA8",
	},
	Joints = H.REX_JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- vines wound round a tube, with leaves and thorns on them
		local function wind(g, samples, from, to, turns, n)
			for i = 0, n do
				local s = from + (to - from) * i / n
				local smp = K:at(samples, s)
				local th = i / n * math.pi * 2 * turns
				local pos, nrm = K:surface(smp, th, -0.05)
				local dir = (smp.T + smp.U * math.cos(th + math.pi / 2) * 0.7 + smp.R * math.sin(th + math.pi / 2) * 0.7).Unit
				K:block(g, "Vine", CFrame.lookAt(pos, pos + dir), Vector3.new(0.13, 0.13, 0.3))
				if i % 3 == 0 then
					K:block(g, "Leaf", CFrame.fromMatrix(pos + nrm * 0.08, dir, nrm) * CFrame.Angles(0, rad(30), 0), Vector3.new(0.3, 0.04, 0.18))
				elseif i % 3 == 1 then
					K:spike(g, "ThornTip", pos, nrm, dir, 0.16, 0.06)
				end
			end
		end

		H.rex(K, {
			color = H.skin({ stripe = 34, band = 86, flank = 106, every = 3 }),
			tiles = { torso = H.plates(0.66), neck = H.plates(0.6), tail = H.plates(0.52, 5) },
			thighArmour = "Bark",
			brow = "BarkDark",
			mouthGlow = "Maw",
			tailTip = { "Pod", "Thorn" },
			headScale = 1.12,
			crest = function(K, torso, neck, tail)
				-- a glowing lime seam down the spine under big hooked thorns
				for _, seg in { { "Head", neck }, { "Body", torso }, { "Tail", tail } } do
					local g, samples = seg[1], seg[2]
					H.vein(K, g, "Nectar", samples, 0, 0.05, samples.total - (g == "Tail" and 0.5 or 0.05), { lift = 0.02, wander = 6, width = 0.1, height = 0.08, step = 0.3 })
				end
				K:ridge("Head", neck, { every = 0.3, height = 0.46, thick = 0.13, key = "Thorn", tip = "ThornTip", lean = 28, sink = 0.85 })
				K:ridge("Body", torso, { every = 0.34, height = function(u) return 0.86 - u * 0.22 end, thick = 0.16, key = "Thorn", tip = "ThornTip", lean = 22, sink = 0.85 })
				K:ridge("Tail", tail, { to = tail.total * 0.75, every = 0.34, height = function(u) return 0.6 - u * 0.36 end, thick = 0.13, key = "Thorn", tip = "ThornTip", lean = 30, sink = 0.85 })
				-- moss over the back and shoulders
				for s = 0.15, torso.total - 0.2, 0.3 do
					local smp = K:at(torso, s)
					for _, x in { 1, -1 } do
						K:tile("Body", "Moss", smp, rad(K:rand(22, 44)) * x, K:rand(0.36, 0.5), K:rand(0.3, 0.44), 0.08, 6, 8, 0.1)
					end
				end
			end,
			head = function(K, hcf, hp, hv)
				-- the flytrap: a magenta lining inside the upper jaw, long pale cilia down both lips, nectar drips
				for _, x in { 1, -1 } do
					K:block("Head", "Maw", hcf(0.3 * x, -0.13, -1.0), Vector3.new(0.06, 0.16, 1.4))
					for z = -0.32, -1.74, -0.17 do
						local len = 0.34 + 0.12 * math.sin((z + 0.3) * 2.2) ^ 2
						K:chain("Head", { "Cilia", "Cilia" }, hp(0.44 * x, -0.12, z), hv(0.32 * x, -1, -0.06), hv(0, 0, 1), { n = 2, len = len, w0 = 0.07, w1 = 0.045 })
					end
					K:block("Head", "Nectar", hcf(0.24 * x, -0.34, -1.36), Vector3.new(0.05, 0.24, 0.05))
					K:block("Head", "Nectar", hcf(0.3 * x, -0.3, -0.7), Vector3.new(0.04, 0.16, 0.04))
					-- two thorn horns sweeping back over the skull
					H.curve(K, "Head", { "Bark", "Thorn", "ThornTip" }, { hp(0.34 * x, 0.62, -0.5), hp(0.56 * x, 0.98, -0.4), hp(0.66 * x, 1.24, -0.1), hp(0.6 * x, 1.38, 0.26) }, 0.2, 0.06, 0.14)
				end
				-- a ruff of poison-purple petals with glowing tips fanned behind the skull
				local N = 9
				for i = 0, N - 1 do
					local a = rad(-104 + 208 * i / (N - 1))
					local base = hp(math.sin(a) * 0.42, 0.42 + math.cos(a) * 0.22, 0.14)
					local d = hv(math.sin(a) * 1.1, math.cos(a) * 0.95, 0.5)
					local L = 1.0 + (math.cos(a) > 0.4 and 0.16 or 0)
					local key = i % 2 == 0 and "Petal" or "PetalDark"
					K:block("Head", key, CFrame.lookAt(base + d * L * 0.5, base + d * 2, hv(0, 0, 1)), Vector3.new(0.48, 0.06, L))
					K:block("Head", key, CFrame.lookAt(base + d * L * 0.86, base + d * 2, hv(0, 0, 1)), Vector3.new(0.3, 0.06, L * 0.3))
					K:block("Head", "Thorn", CFrame.lookAt(base + d * L * 0.45 + hv(0, 0, 1) * 0.04, base + d * 2, hv(0, 0, 1)), Vector3.new(0.07, 0.05, L * 0.8))
					K:block("Head", "Nectar", CFrame.lookAt(base + d * (L + 0.02), base + d * 2, hv(0, 0, 1)), Vector3.new(0.1, 0.07, 0.1))
				end
				-- vines hanging from the cheeks
				for _, x in { 1, -1 } do
					H.curve(K, "Head", { "Vine", "Vine", "Leaf" }, { hp(0.52 * x, -0.02, -0.2), hp(0.6 * x, -0.4, -0.12), hp(0.56 * x, -0.78, -0.02) }, 0.1, 0.06, 0.12)
				end
			end,
			jawExtra = function(K, jcf)
				local J = jcf(0, 0, 0)
				for _, x in { 1, -1 } do
					K:block("Jaw", "Maw", jcf(0.36 * x, 0.04, -0.9), Vector3.new(0.06, 0.16, 1.3))
					for z = -0.4, -1.6, -0.17 do
						K:chain("Jaw", { "Cilia", "Cilia" }, J * Vector3.new(0.42 * x, 0.0, z), J:VectorToWorldSpace(Vector3.new(0.32 * x, 1, 0.04)), J:VectorToWorldSpace(Vector3.zAxis), { n = 2, len = 0.38, w0 = 0.07, w1 = 0.045 })
					end
				end
				K:block("Jaw", "MawDeep", jcf(0, 0.02, -0.7), Vector3.new(0.5, 0.04, 0.9))
				K:block("Jaw", "Nectar", jcf(0.12, -0.42, -1.48), Vector3.new(0.06, 0.28, 0.06))
				K:block("Jaw", "Nectar", jcf(-0.18, -0.38, -1.1), Vector3.new(0.05, 0.2, 0.05))
			end,
			extras = function(K, parts)
				for _, x in { 1, -1 } do
					-- bark shingles over the shoulders
					for i, o in { { 0.12, 58, 0.62 }, { 0.42, 70, 0.56 }, { 0.3, 84, 0.5 }, { 0.68, 64, 0.48 } } do
						local smp = K:at(parts.torso, o[1])
						K:tile("Body", i % 2 == 0 and "BarkDark" or "Bark", smp, rad(o[2]) * x, o[3], o[3] * 0.9, 0.16, 14, 3, -0.3)
					end
					-- vines wound round the thighs
					local g = x == 1 and "LegL" or "LegR"
					local thigh = parts.thighs[g]
					wind(g, thigh, 0.05, thigh.total - 0.05, 1.3, 8)
				end
				wind("Tail", parts.tail, 0.3, parts.tail.total * 0.8, 2.4, 22)
				-- a thorned seed pod for a tail club, glowing seams between its husks
				local tip = K:at(parts.tail, parts.tail.total - 0.2)
				local pod = CFrame.fromMatrix(tip.p, tip.R, tip.U)
				K:block("Tail", "Pod", pod, Vector3.new(0.78, 0.7, 0.92))
				K:block("Tail", "PodDark", pod * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.62, 0.62, 0.84))
				K:block("Tail", "Nectar", pod, Vector3.new(0.82, 0.06, 0.6))
				K:block("Tail", "Nectar", pod, Vector3.new(0.06, 0.74, 0.6))
				for _, d in { Vector3.new(1, 0.3, 0), Vector3.new(-1, 0.3, 0), Vector3.new(0, 1, 0.2), Vector3.new(0.6, -0.5, 0.3), Vector3.new(-0.6, -0.5, 0.3), Vector3.new(0.4, 0.7, -0.4), Vector3.new(-0.4, 0.7, -0.4) } do
					local dir = pod:VectorToWorldSpace(d.Unit)
					H.point(K, "Tail", "ThornTip", tip.p + dir * 0.5, dir, 0.26)
				end
			end,
		})
		GK.lids(K, Color3.fromHex("16240F"))
	end,
}
