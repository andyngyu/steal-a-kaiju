local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Venom Jungle guardian: Thornmaw, a tyrant grown out of the jungle floor. A towering rex shading from near-black down
-- the back through jungle green to a pale belly, its head one great flytrap: two leaf-shaped jaws lined with long
-- spines (green at the root, cream at the tips) around a recessed throat (dark maroon deep inside, magenta toward the lips, rows of inner spines, tendrils),
-- lime nectar dripping from them, hinged on a heavy bulb with small lime eyes under a bark brow and two thorn horns.
-- Jagged thorn petals frame the head, angled forward. Bark armour on the shoulders and thighs, moss on the back, big
-- thorns down the spine over a glowing lime seam sunk between dark lips, vines wound round the limbs and tail, a thorned seed-pod tail club.
return {
	Seed = 431,
	Vary = 0.06,
	Scale = 4.2,
	RootSize = { 7.9, 6.3, 10 },
	HipHeight = 1.7,
	Palette = {
		Hide = "3A5C2A",
		HideDark = "22361A",
		HideLight = "6A8C44",
		Back = "16240F",
		Belly = "C8C28E",
		Belly2 = "B0AA78",
		SeamLip = "0E160A",
		Armour = { "4A3420", Material = "Wood" },
		ArmourLight = { "6B4E30", Material = "Wood" },
		Bark = { "4A3420", Material = "Wood" },
		BarkDark = { "2E2014", Material = "Wood" },
		Moss = "5E8C2E",
		Maw = { "E0408A", Neon = true },
		MawDeep = "3A0A1E",
		MawMid = "7A1A44",
		MawLip = "B0306A",
		Cilia = "D6DC8A",
		CiliaMid = "8EA65E",
		CiliaBase = "3E6A2C",
		Nectar = { "58D22E", Neon = true },
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
		Eye = { "6FE83A", Neon = true },
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
			color = H.skin({ stripe = 32, band = 68, flank = 104, every = 3, upper = "HideDark" }),
			tiles = { torso = H.plates(0.66), neck = H.plates(0.6), tail = H.plates(0.52, 5) },
			thighArmour = "Bark",
			brow = "BarkDark",
			tailTip = { "Pod", "Thorn" },
			headScale = 1.12,
			crest = function(K, torso, neck, tail)
				-- a glowing lime seam sunk down the spine under big hooked thorns
				for _, seg in { { "Head", neck }, { "Body", torso }, { "Tail", tail } } do
					local g, samples = seg[1], seg[2]
					H.vein(K, g, "Nectar", samples, 0, 0.05, samples.total - (g == "Tail" and 0.5 or 0.05), { lift = 0.05, wander = 6, width = 0.08, height = 0.12, step = 0.3, lip = "SeamLip", lipW = 0.08 })
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
			headBuild = function(K, HEAD, hcf, hp, hv)
				-- the head is a flytrap: a heavy bulb under a bark brow (small lime eyes), two great leaf jaws hinged on it
				K:block("Head", "Hide", hcf(0, 0.12, -0.1), Vector3.new(1.04, 0.96, 0.8))
				K:block("Head", "HideDark", hcf(0, -0.1, 0.1), Vector3.new(0.9, 0.7, 0.6))
				K:block("Head", "Back", hcf(0, 0.6, -0.12, -10, 0, 0), Vector3.new(0.86, 0.16, 0.66))
				for _, x in { 1, -1 } do
					K:block("Head", "BarkDark", hcf(0.34 * x, 0.6, -0.42, -8, -14 * x, 24 * x), Vector3.new(0.42, 0.2, 0.42))
					H.eye(K, "Head", hcf(0.42 * x, 0.44, -0.46, 0, -34 * x, 12 * x), 0.16, 0.05)
					H.curve(K, "Head", { "Bark", "Thorn", "ThornTip" }, { hp(0.34 * x, 0.64, -0.2), hp(0.56 * x, 1.0, -0.1), hp(0.66 * x, 1.26, 0.2), hp(0.6 * x, 1.4, 0.56) }, 0.22, 0.06, 0.14)
				end
				local UF, LF = H.flytrap(K, { head = "Head", jaw = "Jaw", frame = HEAD * CFrame.new(0, -0.1, -0.36), size = 1.35, open = 28, keys = { shell = "Hide", shellDark = "HideDark", glow = "Maw", deep = "MawDeep", lining = "MawMid", lip = "MawLip", tooth = "Cilia", spineBase = "CiliaBase", spine = "CiliaMid", spineTip = "Cilia" } })
				-- nectar dripping from both jaws
				for _, d in { { 0.3, -0.9 }, { -0.36, -1.4 }, { 0.1, -1.8 } } do
					K:block("Head", "Nectar", UF * CFrame.new(d[1], -0.2, d[2]), Vector3.new(0.06, 0.32, 0.06))
					K:block("Jaw", "Nectar", LF * CFrame.new(-d[1], -0.14, d[2] + 0.2), Vector3.new(0.06, 0.24, 0.06))
				end
				-- jagged thorn petals framing the head, angled forward
				local N = 10
				for i = 0, N - 1 do
					local a = rad(-120 + 240 * i / (N - 1))
					local base = hp(math.sin(a) * 0.5, 0.16 + math.cos(a) * 0.46, 0.02)
					local d = hv(math.sin(a) * 1.0, math.cos(a) * 0.9, -0.55)
					local tangent = hv(math.cos(a), -math.sin(a), 0)
					local L = 1.2 + (math.cos(a) > 0.3 and 0.2 or 0)
					K:chain("Head", { "PetalDark", "Petal", "Petal", "ThornTip" }, base, d, tangent, { n = 4, len = L, w0 = 0.42, w1 = 0.12, bend = 12, depth = 0.25 })
					for k, f in { 0.35, 0.65 } do
						local p = base + d * L * f
						local side = tangent * (k == 1 and 1 or -1)
						K:spike("Head", "Thorn", p, (side + d * 0.5).Unit, d, 0.24, 0.07)
					end
				end
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
