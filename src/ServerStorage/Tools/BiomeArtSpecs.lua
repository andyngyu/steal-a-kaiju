-- Brick-built art for the biomes (eggs, nests, guardians), in the same spec format as Tools.KaijuSpecs and built with
-- Tools.KaijuBuilder.BuildModel by Tools.BiomeArtBuilder. Studs; models face -Z with the ground at y = 0.
local specs = {}

local function deg(r)
	return math.deg(r)
end

-- ---------- Pebble Plains egg ----------
-- Cream shell with pebble and moss speckles and a zigzag crack band (group "Band", tinted per rarity by Lib.EggModel).
-- Exactly EggConfig.Size (2.2 x 2.8 x 2.2) so the invisible hit box matches gameplay.
do
	local shapes = {
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.3, 0 }, R = { 1.1, 1.3, 1.1 } },
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.55, 0 }, R = { 0.92, 1.25, 0.92 } },
		{ Group = "Shell", Color = "CreamShade", Kind = "Box", C = { 0, 0.25, 0 }, S = { 3, 0.5, 3 }, Paint = true },
	}
	-- radius of the shell (union of the two ellipsoids) at height y
	local function surface(y)
		local r1 = 1.1 * math.sqrt(math.max(0, 1 - ((y - 1.3) / 1.3) ^ 2))
		local r2 = 0.92 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.25) ^ 2))
		return math.max(r1, r2)
	end
	-- small moss and pebble speckles on the top cap and the base, clear of the crack band (golden-angle spread)
	local spotColors = { "MossDark", "Moss", "Pebble", "MossDark", "Moss", "PebbleDark" }
	local rng = Random.new(5)
	for k = 0, 17 do
		local a = k * 2.39996 + 0.3
		local y = k % 3 == 2 and rng:NextNumber(0.3, 0.55) or rng:NextNumber(2.05, 2.62)
		local r = surface(y) - 0.04
		local size = rng:NextNumber(0.13, 0.17)
		table.insert(shapes, { Group = "Shell", Color = spotColors[k % #spotColors + 1], Kind = "Ellipsoid", C = { math.cos(a) * r, y, math.sin(a) * r }, R = { size, size, size }, Paint = true })
	end
	-- zigzag crack ribbon round the middle: 5 peaks and 5 valleys, one column wide and two voxels tall
	local POINTS, AMP = 10, 0.45
	for k = 0, POINTS - 1 do
		local a0, a1 = k / POINTS * math.pi * 2, (k + 1) / POINTS * math.pi * 2
		local y0 = 1.3 + (k % 2 == 0 and AMP or -AMP)
		local y1 = 1.3 + (k % 2 == 0 and -AMP or AMP)
		for s = 0, 7 do
			local f = s / 8
			local a, y = a0 + (a1 - a0) * f, y0 + (y1 - y0) * f
			local r = surface(y) - 0.08
			table.insert(shapes, { Group = "Band", Color = "Band", Kind = "Ellipsoid", C = { math.cos(a) * r, y, math.sin(a) * r }, R = { 0.14, 0.2, 0.14 }, Paint = true, Regroup = true })
		end
	end
	table.insert(shapes, { Group = "Shell", Color = "Shine", Kind = "Ellipsoid", C = { -0.45, 2.2, -0.62 }, R = { 0.17, 0.27, 0.17 }, Paint = true })

	specs.Egg_PebblePlains = {
		Voxel = 0.2,
		StudScale = 0.8,
		Palette = {
			Cream = "F7EBCB",
			CreamShade = "E6D5A8",
			Pebble = "A8957A",
			PebbleDark = "7E6F5C",
			Moss = "79BE47",
			MossDark = "4F8F2E",
			Band = "B8C0CC",
			Shine = "FFFFFF",
		},
		Shapes = shapes,
	}
end

-- ---------- Pebble Plains nest ----------
-- A woven twig ring (two layers plus a rim) round a straw bed, pebbles round the outside, leaves and flowers tucked in.
-- Centre at the origin; eggs sit on the straw (EggSpawn attachments are at radius ~5, y 1.1).
do
	local shapes = {
		{ Group = "Bed", Color = "Straw", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 7.4, 0.75, 7.4 } },
	}
	local rng = Random.new(11)
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 6.5)
		table.insert(shapes, { Group = "Bed", Color = "StrawDark", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.9, math.sin(a) * r }, R = { 0.8, 0.4, 0.5 }, Paint = true })
	end
	local function ring(n, radius, y, rad, colors, offset)
		for k = 0, n - 1 do
			local a0 = (k + offset) / n * math.pi * 2
			local a1 = (k + 1 + offset) / n * math.pi * 2
			table.insert(shapes, {
				Group = "Ring",
				Color = colors[k % #colors + 1],
				Kind = "Capsule",
				A = { math.cos(a0) * radius, y, math.sin(a0) * radius },
				B = { math.cos(a1) * radius, y + (k % 2 == 0 and 0.25 or -0.25), math.sin(a1) * radius },
				R = rad,
			})
		end
	end
	ring(18, 8.0, 0.9, 1.35, { "Twig", "TwigLight", "Twig", "TwigDark" }, 0)
	ring(18, 7.6, 1.95, 1.0, { "TwigDark", "Twig", "TwigLight" }, 0.5)
	ring(18, 7.3, 2.65, 0.6, { "TwigLight", "Twig" }, 0.25)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.2
		local r = 10.1 + (k % 2) * 0.5
		table.insert(shapes, { Group = "Pebbles", Color = k % 3 == 0 and "PebbleDark" or "Pebble", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.35, math.sin(a) * r }, R = { 0.75, 0.55, 0.65 } })
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.5
		table.insert(shapes, { Group = "Ring", Color = k % 2 == 0 and "Leaf" or "LeafDark", Kind = "Ellipsoid", C = { math.cos(a) * 7.6, 2.9, math.sin(a) * 7.6 }, R = { 1.0, 0.28, 1.0 } })
	end
	local bits = {}
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.13
		local r = 8.9
		table.insert(bits, {
			Name = "Stick",
			Group = "Ring",
			Color = k % 2 == 0 and "TwigDark" or "TwigLight",
			C = { math.cos(a) * r, 2.0 + (k % 3) * 0.3, math.sin(a) * r },
			S = { 0.3, 0.3, 2.6 },
			Rot = { 20 + (k % 3) * 8, deg(-a) + 90 + (k % 2 == 0 and 25 or -25), 0 },
		})
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 1.0
		local c = { math.cos(a) * 7.4, 3.25, math.sin(a) * 7.4 }
		table.insert(bits, { Name = "Petal", Group = "Ring", Color = "Flower", C = c, S = { 0.9, 0.22, 0.32 } })
		table.insert(bits, { Name = "Petal", Group = "Ring", Color = "Flower", C = c, S = { 0.32, 0.22, 0.9 } })
		table.insert(bits, { Name = "FlowerCentre", Group = "Ring", Color = "FlowerCentre", C = { c[1], c[2] + 0.06, c[3] }, S = { 0.34, 0.24, 0.34 } })
	end
	specs.Nest_PebblePlains = {
		Voxel = 0.8,
		StudScale = 1.6,
		Palette = {
			Straw = "EBCB7A",
			StrawDark = "D1AC58",
			Twig = "8B5A2B",
			TwigLight = "A97A45",
			TwigDark = "6B4423",
			Leaf = "6CC73F",
			LeafDark = "4BA32E",
			Pebble = "B9BCC8",
			PebbleDark = "8E91A0",
			Flower = "FF8FB1",
			FlowerCentre = "FFE066",
		},
		Shapes = shapes,
		Bits = bits,
	}
end

-- ---------- Pebble Plains guardian: "Old Boulderback" ----------
-- A huge, sleepy mossy-green mama Pebblesaur covered in grey boulders, with glowing purple crystals down its spine. Designed at
-- Rumblerex proportions and scaled by K. Eyes: EyeOpen / Pupil (shown awake) and EyeClosed (shown asleep), toggled by
-- GuardianService. Groups get Motor6Ds in Tools.BiomeArtBuilder so clients can animate them.
do
	local K = 2.6
	local function v(x, y, z)
		return { x * K, y * K, z * K }
	end
	local function sh(group, color, kind, t)
		t.Group, t.Color, t.Kind = group, color, kind
		for _, key in { "C", "R", "S", "A", "B" } do
			if type(t[key]) == "table" then
				t[key] = v(t[key][1], t[key][2], t[key][3])
			end
		end
		for _, key in { "RA", "RB" } do
			if t[key] then
				t[key] *= K
			end
		end
		if type(t.R) == "number" then
			t.R *= K
		end
		return t
	end
	local shapes = {
		sh("Body", "Stone", "Ellipsoid", { C = { 0, 1.75, 0.3 }, R = { 1.35, 1.3, 1.25 } }),
		sh("Body", "Belly", "Ellipsoid", { C = { 0, 1.6, -0.4 }, R = { 0.95, 1.0, 0.6 } }),
		sh("Body", "BellyLine", "Box", { C = { 0, 1.05, -0.95 }, S = { 2.2, 0.16, 1.0 }, Paint = true }),
		sh("Body", "BellyLine", "Box", { C = { 0, 1.6, -0.95 }, S = { 2.2, 0.16, 1.0 }, Paint = true }),
		sh("Body", "BellyLine", "Box", { C = { 0, 2.15, -0.95 }, S = { 2.2, 0.16, 1.0 }, Paint = true }),
		sh("Body", "Moss", "Ellipsoid", { C = { 0, 2.65, 0.6 }, R = { 1.45, 0.6, 1.25 }, Paint = true }),
		sh("Body", "MossDark", "Ellipsoid", { C = { 0.7, 2.5, 0.2 }, R = { 0.35, 0.3, 0.35 }, Paint = true }),
		sh("Body", "MossDark", "Ellipsoid", { C = { -0.6, 2.75, 0.9 }, R = { 0.35, 0.3, 0.35 }, Paint = true }),
		-- boulders on the back
		sh("Body", "Pebble", "Ellipsoid", { C = { 0.6, 2.85, 0.9 }, R = { 0.5, 0.42, 0.46 } }),
		sh("Body", "PebbleDark", "Ellipsoid", { C = { -0.55, 2.65, 1.25 }, R = { 0.48, 0.4, 0.44 } }),
		sh("Body", "PebbleLight", "Ellipsoid", { C = { 0.05, 3.1, 0.35 }, R = { 0.44, 0.34, 0.4 } }),
		sh("Body", "Pebble", "Ellipsoid", { C = { 0.8, 2.1, 1.4 }, R = { 0.4, 0.36, 0.38 } }),
		sh("Body", "PebbleLight", "Ellipsoid", { C = { -0.85, 2.05, 0.95 }, R = { 0.38, 0.34, 0.36 } }),
		sh("Body", "PebbleDark", "Ellipsoid", { C = { 1.05, 2.5, 0.35 }, R = { 0.34, 0.32, 0.34 } }),
		sh("Body", "Pebble", "Ellipsoid", { C = { -1.0, 2.6, 0.2 }, R = { 0.34, 0.32, 0.34 } }),
		sh("Body", "PebbleLight", "Ellipsoid", { C = { -0.2, 2.2, 1.6 }, R = { 0.36, 0.3, 0.34 } }),
		-- head: heavy brow, boxy snout, mossy cap, cream lower jaw
		sh("Head", "Stone", "Ellipsoid", { C = { 0, 3.6, -0.4 }, R = { 1.2, 1.0, 1.05 } }),
		sh("Head", "Stone", "Box", { C = { 0, 3.05, -1.5 }, S = { 1.45, 0.75, 1.5 } }),
		sh("Jaw", "Belly", "Box", { C = { 0, 2.62, -1.4 }, S = { 1.3, 0.42, 1.3 } }),
		sh("Head", "Moss", "Ellipsoid", { C = { 0, 4.45, -0.3 }, R = { 1.15, 0.38, 1.0 }, Paint = true }),
		sh("Head", "StoneDark", "Box", { C = { 0, 4.08, -1.3 }, S = { 2.0, 0.3, 0.45 } }),
		sh("Head", "PebbleLight", "Ellipsoid", { C = { 0.55, 4.55, -0.05 }, R = { 0.34, 0.27, 0.34 } }),
		sh("Head", "Pebble", "Ellipsoid", { C = { -0.6, 4.45, 0.15 }, R = { 0.32, 0.26, 0.32 } }),
		-- legs, feet
		sh("LegL", "Stone", "Capsule", { A = { 0.85, 1.15, 0.3 }, B = { 0.9, 0.5, 0.1 }, RA = 0.72, RB = 0.58, Mirror = true }),
		sh("LegL", "StoneDark", "Box", { C = { 0.9, 0.22, -0.15 }, S = { 1.35, 0.45, 1.6 }, Mirror = true }),
		-- little arms
		sh("ArmL", "Stone", "Capsule", { A = { 1.2, 2.15, -0.3 }, B = { 1.32, 1.65, -0.85 }, R = 0.34, Mirror = true }),
		sh("ArmL", "Claw", "Box", { C = { 1.32, 1.5, -1.15 }, S = { 0.55, 0.36, 0.32 }, Mirror = true }),
		-- thick mossy tail with boulders
		sh("Tail", "Stone", "Capsule", { A = { 0, 1.15, 1.15 }, B = { 0, 0.75, 2.3 }, RA = 0.78, RB = 0.55 }),
		sh("Tail", "Stone", "Capsule", { A = { 0, 0.75, 2.3 }, B = { 0, 0.6, 3.3 }, RA = 0.55, RB = 0.32 }),
		sh("Tail", "Stone", "Capsule", { A = { 0, 0.6, 3.3 }, B = { 0, 0.85, 3.8 }, RA = 0.32, RB = 0.2 }),
		sh("Tail", "Moss", "Box", { C = { 0, 1.45, 2.3 }, S = { 2, 0.5, 2.6 }, Paint = true }),
		sh("Tail", "PebbleDark", "Ellipsoid", { C = { 0.25, 1.45, 2.0 }, R = { 0.36, 0.3, 0.34 } }),
		sh("Tail", "PebbleLight", "Ellipsoid", { C = { -0.2, 1.15, 2.75 }, R = { 0.3, 0.26, 0.3 } }),
		sh("Tail", "Pebble", "Ellipsoid", { C = { 0.1, 0.95, 3.45 }, R = { 0.24, 0.2, 0.24 } }),
	}
	local function d(t)
		for _, key in { "X", "Y", "W", "H", "D" } do
			if t[key] then
				t[key] *= K
			end
		end
		return t
	end
	local details = {
		d({ Name = "EyeOpen", Group = "Head", Color = "White", X = 0.55, Y = 3.8, W = 0.8, H = 0.72, D = 0.05, Mirror = true }),
		d({ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.47, Y = 3.74, W = 0.4, H = 0.5, D = 0.07, Mirror = true }),
		d({ Name = "Pupil", Group = "Head", Color = "White", X = 0.38, Y = 3.9, W = 0.15, H = 0.15, D = 0.09, Mirror = true }),
		d({ Name = "EyeClosed", Group = "Head", Color = "Ink", X = 0.55, Y = 3.72, W = 0.78, H = 0.13, D = 0.06, Tilt = -6, Mirror = true }),
		d({ Name = "Brow", Group = "Head", Color = "StoneDark", X = 0.55, Y = 4.24, W = 0.9, H = 0.2, D = 0.07, Tilt = 10, Mirror = true }),
		d({ Name = "Nostril", Group = "Head", Color = "Ink", X = 0.32, Y = 3.25, W = 0.14, H = 0.14, D = 0.05, Mirror = true }),
		d({ Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.85, W = 1.0, H = 0.1, D = 0.03 }),
		d({ Name = "Fang", Group = "Head", Color = "Claw", X = 0.42, Y = 2.72, W = 0.2, H = 0.26, D = 0.05, Mirror = true }),
	}
	local function b(t)
		t.C = v(t.C[1], t.C[2], t.C[3])
		t.S = v(t.S[1], t.S[2], t.S[3])
		return t
	end
	local bits = {
		-- glowing crystals down the spine
		b({ Name = "Crystal", Group = "Head", Color = "Crystal", C = { 0, 4.75, -0.2 }, S = { 0.32, 0.85, 0.5 }, Rot = { -10, 0, 0 } }),
		b({ Name = "Crystal", Group = "Head", Color = "CrystalDeep", C = { 0, 5.15, 0.15 }, S = { 0.24, 0.5, 0.3 }, Rot = { 10, 0, 0 } }),
		b({ Name = "Crystal", Group = "Body", Color = "Crystal", C = { 0, 3.55, 1.2 }, S = { 0.34, 1.0, 0.55 }, Rot = { 15, 0, 0 } }),
		b({ Name = "Crystal", Group = "Body", Color = "CrystalDeep", C = { 0.42, 3.3, 1.1 }, S = { 0.24, 0.6, 0.3 }, Rot = { 15, 0, -25 }, Mirror = true }),
		b({ Name = "Crystal", Group = "Tail", Color = "Crystal", C = { 0, 2.0, 2.35 }, S = { 0.3, 0.8, 0.5 }, Rot = { 25, 0, 0 } }),
		b({ Name = "Crystal", Group = "Tail", Color = "CrystalDeep", C = { 0, 1.45, 3.25 }, S = { 0.24, 0.6, 0.4 }, Rot = { 30, 0, 0 } }),
		-- toe claws
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.5, 0.15, -1.0 }, S = { 0.28, 0.3, 0.3 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.9, 0.15, -1.02 }, S = { 0.28, 0.3, 0.32 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.3, 0.15, -1.0 }, S = { 0.28, 0.3, 0.3 }, Mirror = true }),
	}
	local joints = {}
	for name, j in {
		Head = { 0, 2.8, -0.3 },
		Jaw = { 0, 2.82, -0.75 },
		LegL = { 0.85, 1.15, 0.3 },
		LegR = { -0.85, 1.15, 0.3 },
		ArmL = { 1.2, 2.15, -0.3 },
		ArmR = { -1.2, 2.15, -0.3 },
		Tail = { 0, 1.15, 1.1 },
	} do
		joints[name] = v(j[1], j[2], j[3])
	end
	specs.Guardian_PebblePlains = {
		Voxel = 0.65,
		StudScale = 1.3,
		Palette = {
			Stone = "6FB04A",
			StoneDark = "4F8A33",
			Belly = "FFE6A8",
			BellyLine = "F0CC80",
			Moss = "8FCB5A",
			MossDark = "5C9C3A",
			Pebble = "B7B9C4",
			PebbleDark = "8E91A0",
			PebbleLight = "DCDEE6",
			Crystal = { "B05CFF", Neon = true },
			CrystalDeep = { "7B2CFF", Neon = true },
			Claw = "F2EAD8",
			White = "FFFFFF",
			Ink = "1A1033",
			Mouth = "3B1A33",
		},
		Joints = joints,
		Parents = { Jaw = "Head" },
		Shapes = shapes,
		Details = details,
		Bits = bits,
		-- rig numbers for Tools.BiomeArtBuilder (studs)
		RootSize = { 7.5, 6, 9.5 },
		HipHeight = 1.6,
	}
end

-- ---------- Pebble Plains props ----------
-- Built once into ServerStorage.Assets.Props by Tools.BiomeArtBuilder.BuildProps and scattered by DressLane.
local PLAINS = {
	Leaf = "5FC23A",
	LeafDark = "43A12A",
	LeafLight = "86DB57",
	Wood = "8B5A2B",
	WoodDark = "6B4423",
	Rock = "B9BCC8",
	RockDark = "8E91A0",
	RockLight = "DCDEE6",
	Moss = "7DC24B",
	Pink = "FF8FB1",
	Yellow = "FFE066",
	White = "FFFFFF",
	Purple = "C99BFF",
	Red = "FF5A6E",
	Orange = "FFA44D",
	Cream = "FFF1D6",
}
local function palette(keys)
	local p = {}
	for _, k in keys do
		p[k] = PLAINS[k]
	end
	return p
end

-- round bush; berries = true dots it with red berries instead of flowers
local function bushSpec(berries)
	local shapes = {
		{ Group = "Bush", Color = "Leaf", Kind = "Ellipsoid", C = { 0, 1.3, 0 }, R = { 2.2, 1.45, 1.9 } },
		{ Group = "Bush", Color = "LeafDark", Kind = "Ellipsoid", C = { 1.45, 1.0, 0.6 }, R = { 1.35, 1.05, 1.25 } },
		{ Group = "Bush", Color = "Leaf", Kind = "Ellipsoid", C = { -1.35, 1.1, -0.45 }, R = { 1.35, 1.15, 1.25 } },
		{ Group = "Bush", Color = "LeafLight", Kind = "Box", C = { 0, 2.55, 0 }, S = { 6, 0.6, 6 }, Paint = true },
	}
	local bits = {}
	local rng = Random.new(berries and 3 or 4)
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(1.2, 2.5)
		local r = 2.0 * math.sqrt(math.max(0.15, 1 - ((y - 1.3) / 1.5) ^ 2)) + 0.15
		local c = { math.cos(a) * r, y, math.sin(a) * r * 0.9 }
		if berries then
			table.insert(bits, { Name = "Berry", Group = "Bush", Color = "Red", C = c, S = { 0.36, 0.36, 0.36 } })
		else
			local col = ({ "Pink", "White", "Yellow" })[rng:NextInteger(1, 3)]
			table.insert(bits, { Name = "Petal", Group = "Bush", Color = col, C = c, S = { 0.6, 0.2, 0.2 }, Rot = { 0, math.deg(-a), 0 } })
			table.insert(bits, { Name = "Petal", Group = "Bush", Color = col, C = c, S = { 0.2, 0.6, 0.2 }, Rot = { 0, math.deg(-a), 0 } })
		end
	end
	return {
		Voxel = 0.6,
		StudScale = 1.2,
		Palette = palette({ "Leaf", "LeafDark", "LeafLight", "Red", "Pink", "White", "Yellow" }),
		Shapes = shapes,
		Bits = bits,
	}
end
specs.Prop_Bush = bushSpec(false)
specs.Prop_BerryBush = bushSpec(true)

specs.Prop_Boulder = {
	Voxel = 0.6,
	StudScale = 1.2,
	Palette = palette({ "Rock", "RockDark", "RockLight", "Moss", "Leaf" }),
	Shapes = {
		{ Group = "Rock", Color = "Rock", Kind = "Ellipsoid", C = { 0, 1.0, 0 }, R = { 1.9, 1.35, 1.6 } },
		{ Group = "Rock", Color = "RockDark", Kind = "Ellipsoid", C = { 1.4, 0.6, 0.8 }, R = { 1.0, 0.8, 0.9 } },
		{ Group = "Rock", Color = "RockLight", Kind = "Ellipsoid", C = { -1.3, 0.5, -0.7 }, R = { 0.85, 0.65, 0.75 } },
		{ Group = "Rock", Color = "RockLight", Kind = "Box", C = { 0, 1.85, 0 }, S = { 5, 0.6, 5 }, Paint = true },
		{ Group = "Rock", Color = "Moss", Kind = "Ellipsoid", C = { -0.4, 2.1, -0.3 }, R = { 1.5, 0.55, 1.25 }, Paint = true },
	},
	Bits = {
		{ Name = "Blade", Group = "Rock", Color = "Leaf", C = { 1.9, 0.4, -0.6 }, S = { 0.2, 0.8, 0.2 }, Rot = { 0, 0, -15 } },
		{ Name = "Blade", Group = "Rock", Color = "Leaf", C = { 2.1, 0.3, -0.3 }, S = { 0.2, 0.6, 0.2 }, Rot = { 10, 0, -25 } },
		{ Name = "Blade", Group = "Rock", Color = "Leaf", C = { -1.7, 0.35, 0.9 }, S = { 0.2, 0.7, 0.2 }, Rot = { 0, 0, 20 } },
	},
}

specs.Prop_Tree = {
	Voxel = 0.8,
	StudScale = 1.6,
	Palette = palette({ "Wood", "WoodDark", "Leaf", "LeafDark", "LeafLight", "Orange", "Red" }),
	Shapes = {
		{ Group = "Tree", Color = "Wood", Kind = "Capsule", A = { 0, 0, 0 }, B = { 0, 5, 0 }, R = 0.95 },
		{ Group = "Tree", Color = "WoodDark", Kind = "Box", C = { 0, 0.4, 0 }, S = { 3.2, 0.8, 3.2 } },
		{ Group = "Tree", Color = "Leaf", Kind = "Ellipsoid", C = { 0, 7.2, 0 }, R = { 3.8, 3.0, 3.8 } },
		{ Group = "Tree", Color = "LeafDark", Kind = "Ellipsoid", C = { 2.4, 6.0, 1.0 }, R = { 2.3, 1.9, 2.1 } },
		{ Group = "Tree", Color = "Leaf", Kind = "Ellipsoid", C = { -2.2, 6.2, -1.3 }, R = { 2.3, 2.1, 2.1 } },
		{ Group = "Tree", Color = "LeafLight", Kind = "Box", C = { 0, 9.6, 0 }, S = { 8, 1.4, 8 }, Paint = true },
	},
	Bits = {
		{ Name = "Fruit", Group = "Tree", Color = "Orange", C = { 2.6, 6.6, -2.0 }, S = { 0.6, 0.6, 0.6 } },
		{ Name = "Fruit", Group = "Tree", Color = "Red", C = { -3.0, 7.4, 1.4 }, S = { 0.6, 0.6, 0.6 } },
		{ Name = "Fruit", Group = "Tree", Color = "Orange", C = { 0.6, 6.2, 3.4 }, S = { 0.6, 0.6, 0.6 } },
		{ Name = "Fruit", Group = "Tree", Color = "Red", C = { -1.2, 5.6, -3.2 }, S = { 0.6, 0.6, 0.6 } },
	},
}

-- a clump of brick flowers in the given colours
local function flowerSpec(colors, seed)
	local shapes = {
		{ Group = "Flowers", Color = "LeafDark", Kind = "Box", C = { 0, 0.1, 0 }, S = { 1.6, 0.2, 1.2 } },
	}
	local rng = Random.new(seed)
	for i = 1, 5 do
		local x, z = rng:NextNumber(-1.1, 1.1), rng:NextNumber(-0.8, 0.8)
		local h = rng:NextNumber(0.6, 1.2)
		local col = colors[(i - 1) % #colors + 1]
		table.insert(shapes, { Group = "Flowers", Color = "Leaf", Kind = "Box", C = { x, h / 2, z }, S = { 0.2, h, 0.2 } })
		table.insert(shapes, { Group = "Flowers", Color = "Leaf", Kind = "Box", C = { x + 0.2, h * 0.4, z }, S = { 0.4, 0.2, 0.2 } })
		table.insert(shapes, { Group = "Flowers", Color = col, Kind = "Box", C = { x, h + 0.1, z }, S = { 0.6, 0.2, 0.2 } })
		table.insert(shapes, { Group = "Flowers", Color = col, Kind = "Box", C = { x, h + 0.1, z }, S = { 0.2, 0.2, 0.6 } })
		table.insert(shapes, { Group = "Flowers", Color = "Yellow", Kind = "Box", C = { x, h + 0.3, z }, S = { 0.2, 0.2, 0.2 } })
	end
	return {
		Voxel = 0.2,
		NoStuds = true,
		Palette = palette({ "Leaf", "LeafDark", "Pink", "White", "Yellow", "Purple", "Red" }),
		Shapes = shapes,
	}
end
specs.Prop_FlowersPink = flowerSpec({ "Pink", "White", "Pink" }, 21)
specs.Prop_FlowersMixed = flowerSpec({ "Purple", "Yellow", "Red", "White" }, 22)
specs.Prop_FlowersRed = flowerSpec({ "Red", "Red", "White" }, 23)

specs.Prop_Grass = {
	Voxel = 0.2,
	NoStuds = true,
	Palette = palette({ "Leaf", "LeafDark", "LeafLight" }),
	Shapes = {
		{ Group = "Grass", Color = "LeafDark", Kind = "Box", C = { 0, 0.1, 0 }, S = { 1.0, 0.2, 0.8 } },
	},
	Bits = {
		{ Name = "Blade", Group = "Grass", Color = "Leaf", C = { 0, 0.6, 0 }, S = { 0.2, 1.1, 0.2 } },
		{ Name = "Blade", Group = "Grass", Color = "LeafLight", C = { 0.3, 0.45, 0.1 }, S = { 0.2, 0.8, 0.2 }, Rot = { 0, 0, -20 } },
		{ Name = "Blade", Group = "Grass", Color = "Leaf", C = { -0.3, 0.5, -0.1 }, S = { 0.2, 0.9, 0.2 }, Rot = { 0, 0, 18 } },
		{ Name = "Blade", Group = "Grass", Color = "LeafDark", C = { 0.1, 0.4, -0.3 }, S = { 0.2, 0.7, 0.2 }, Rot = { -18, 0, 0 } },
		{ Name = "Blade", Group = "Grass", Color = "LeafLight", C = { -0.1, 0.4, 0.3 }, S = { 0.2, 0.7, 0.2 }, Rot = { 18, 0, 0 } },
	},
}

specs.Prop_Mushroom = {
	Voxel = 0.25,
	StudScale = 1.0,
	Palette = palette({ "Cream", "Red", "White" }),
	Shapes = {
		{ Group = "Mushroom", Color = "Red", Kind = "Ellipsoid", C = { 0, 1.25, 0 }, R = { 1.0, 0.6, 1.0 } },
		{ Group = "Mushroom", Color = "Red", Kind = "Box", C = { 0, 0.85, 0 }, S = { 3, 0.45, 3 }, Carve = true },
		{ Group = "Mushroom", Color = "Cream", Kind = "Capsule", A = { 0, 0, 0 }, B = { 0, 1.1, 0 }, R = 0.32 },
		{ Group = "Mushroom", Color = "White", Kind = "Ellipsoid", C = { 0.45, 1.65, 0.2 }, R = { 0.2, 0.15, 0.2 }, Paint = true },
		{ Group = "Mushroom", Color = "White", Kind = "Ellipsoid", C = { -0.35, 1.6, -0.4 }, R = { 0.2, 0.15, 0.2 }, Paint = true },
		{ Group = "Mushroom", Color = "White", Kind = "Ellipsoid", C = { -0.1, 1.8, 0.35 }, R = { 0.18, 0.12, 0.18 }, Paint = true },
		{ Group = "Mushroom", Color = "White", Kind = "Ellipsoid", C = { 0.75, 1.3, -0.45 }, R = { 0.18, 0.18, 0.18 }, Paint = true },
	},
}

-- vine for a cliff face: built upward from y = 0 to Length (hang it with its top at the cliff edge); leaves point to -Z
local function vineSpec(length, seed)
	local shapes = {
		{ Group = "Vine", Color = "LeafDark", Kind = "Box", C = { 0, length / 2, -0.2 }, S = { 0.4, length, 0.4 } },
	}
	local rng = Random.new(seed)
	local y = length - 0.6
	while y > 0.4 do
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		table.insert(shapes, { Group = "Vine", Color = rng:NextInteger(0, 2) == 0 and "LeafLight" or "Leaf", Kind = "Ellipsoid", C = { side * 0.45, y, -0.45 }, R = { 0.55, 0.4, 0.35 } })
		if rng:NextNumber() < 0.3 then
			table.insert(shapes, { Group = "Vine", Color = rng:NextInteger(0, 1) == 0 and "Pink" or "White", Kind = "Box", C = { side * 0.7, y - 0.2, -0.7 }, S = { 0.4, 0.4, 0.2 } })
		end
		y -= rng:NextNumber(0.9, 1.4)
	end
	return {
		Voxel = 0.2,
		NoStuds = true,
		Palette = palette({ "Leaf", "LeafDark", "LeafLight", "Pink", "White" }),
		Shapes = shapes,
		Length = length,
	}
end
specs.Prop_VineShort = vineSpec(6, 31)
specs.Prop_VineLong = vineSpec(10, 32)

specs.Prop_NestSign = {
	Voxel = 0.25,
	StudScale = 1.0,
	Palette = palette({ "Wood", "WoodDark", "Leaf", "Pink" }),
	Shapes = {
		{ Group = "Sign", Color = "WoodDark", Kind = "Box", C = { 0, 2.0, 0 }, S = { 0.5, 4.0, 0.5 } },
		{ Group = "Sign", Color = "Wood", Kind = "Box", C = { 0.25, 3.3, -0.3 }, S = { 3.5, 1.0, 0.25 } },
		{ Group = "Sign", Color = "Wood", Kind = "Box", C = { 2.15, 3.3, -0.3 }, S = { 0.5, 0.75, 0.25 } },
		{ Group = "Sign", Color = "Wood", Kind = "Box", C = { 2.4, 3.3, -0.3 }, S = { 0.25, 0.5, 0.25 } },
		{ Group = "Sign", Color = "Leaf", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 0.9, 0.35, 0.9 } },
		{ Group = "Sign", Color = "Pink", Kind = "Box", C = { 0.5, 0.65, -0.3 }, S = { 0.25, 0.25, 0.25 } },
	},
	-- BuildProps puts the "NEST >" SurfaceGui on the widest brick at this height
	Board = { C = { 0.25, 3.3, -0.3 } },
}

return specs
