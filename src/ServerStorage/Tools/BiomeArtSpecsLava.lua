-- Lava Lagoon art specs (merged into Tools.BiomeArtSpecs; built by Tools.BiomeArtBuilder): egg, nest, the guardian
-- "Magmaw", props and the lane dressing. Same spec format as Tools.KaijuBuilder; prop Fx entries are added by
-- BiomeArtBuilder.BuildProps (particles / lights at a point in prop space).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end
local MapConfig = fresh(ReplicatedStorage.Shared.Config.MapConfig)
local WALL = MapConfig.Lane.WallHeight

local specs = {}

local function deg(r)
	return math.deg(r)
end

-- ---------- egg ----------
-- Dark basalt shell with glowing magma veins on the cap and the base, ash speckles and the zigzag crack band (group
-- "Band", tinted per rarity by Lib.EggModel). Exactly EggConfig.Size (2.2 x 2.8 x 2.2).
do
	local shapes = {
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.3, 0 }, R = { 1.1, 1.3, 1.1 } },
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.55, 0 }, R = { 0.92, 1.25, 0.92 } },
		{ Group = "Shell", Color = "CreamShade", Kind = "Box", C = { 0, 0.25, 0 }, S = { 3, 0.5, 3 }, Paint = true },
	}
	local function surface(y)
		local r1 = 1.1 * math.sqrt(math.max(0, 1 - ((y - 1.3) / 1.3) ^ 2))
		local r2 = 0.92 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.25) ^ 2))
		return math.max(r1, r2)
	end
	-- ash speckles
	local rng = Random.new(41)
	for k = 0, 13 do
		local a = k * 2.39996 + 0.7
		local y = k % 3 == 2 and rng:NextNumber(0.3, 0.55) or rng:NextNumber(2.05, 2.6)
		local r = surface(y) - 0.04
		local size = rng:NextNumber(0.13, 0.17)
		table.insert(shapes, { Group = "Shell", Color = k % 2 == 0 and "Ash" or "AshLight", Kind = "Ellipsoid", C = { math.cos(a) * r, y, math.sin(a) * r }, R = { size, size, size }, Paint = true })
	end
	-- glowing magma veins: little zigzags running up from the band and down from it
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.35
		local up = k % 2 == 0
		for s = 0, 3 do
			local y = up and (2.0 + s * 0.15) or (0.62 - s * 0.12)
			local aa = a + (s % 2 == 0 and 0 or 0.13)
			local r = surface(y) - 0.04
			table.insert(shapes, { Group = "Shell", Color = "Vein", Kind = "Ellipsoid", C = { math.cos(aa) * r, y, math.sin(aa) * r }, R = { 0.15, 0.15, 0.15 }, Paint = true })
		end
	end
	-- zigzag crack ribbon round the middle (5 peaks)
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
	specs.Egg_LavaLagoon = {
		Voxel = 0.2,
		StudScale = 0.8,
		Palette = {
			Cream = "3E3436",
			CreamShade = "2E2628",
			Ash = "6E5F5C",
			AshLight = "8C7C78",
			Vein = { "FF7A1F", Neon = true },
			Band = "B8C0CC",
			Shine = "8A7C7A",
		},
		Shapes = shapes,
	}
end

-- ---------- nest ----------
-- Rings of basalt round a bed of ash with glowing embers, obsidian shards jutting out, magma crystals on the rim and
-- boulders outside. Centre at the origin; the walk-in gap facing the bases is cut by BiomeArtBuilder.
do
	local shapes = {
		{ Group = "Bed", Color = "Ash", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 7.4, 0.75, 7.4 } },
	}
	local rng = Random.new(43)
	for k = 1, 16 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 6.4)
		local color = k % 3 == 0 and "EmberHot" or (k % 3 == 1 and "Ember" or "Coal")
		table.insert(shapes, { Group = "Bed", Color = color, Kind = "Ellipsoid", C = { math.cos(a) * r, 0.45, math.sin(a) * r }, R = { 0.9, 0.5, 0.7 }, Paint = true })
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
				B = { math.cos(a1) * radius, y + (k % 2 == 0 and 0.3 or -0.3), math.sin(a1) * radius },
				R = rad,
			})
		end
	end
	ring(18, 8.0, 0.9, 1.45, { "Basalt", "BasaltDark", "Basalt", "Rock" }, 0)
	ring(18, 7.6, 2.0, 1.05, { "BasaltDark", "Basalt", "Rock" }, 0.5)
	ring(18, 7.3, 2.75, 0.6, { "Seam", "Basalt", "BasaltDark" }, 0.25)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.2
		if math.abs(math.abs(a) - math.pi) > 0.45 and math.abs(math.abs(a - math.pi * 2) - math.pi) > 0.45 then
			local r = 10.2 + (k % 2) * 0.5
			table.insert(shapes, { Group = "Pebbles", Color = k % 3 == 0 and "BasaltDark" or "Rock", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.4, math.sin(a) * r }, R = { 0.85, 0.6, 0.7 } })
		end
	end
	local bits = {}
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.13
		local r = 8.9
		table.insert(bits, {
			Name = "Shard",
			Group = "Ring",
			Color = k % 2 == 0 and "Obsidian" or "ObsidianLight",
			C = { math.cos(a) * r, 2.4 + (k % 3) * 0.3, math.sin(a) * r },
			S = { 0.55, 2.6 + (k % 2) * 0.8, 0.55 },
			Rot = { 22 + (k % 3) * 6, deg(math.pi / 2 - a), 0 },
		})
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 1.0
		local c = { math.cos(a) * 7.4, 3.4, math.sin(a) * 7.4 }
		table.insert(bits, { Name = "Magma", Group = "Ring", Color = "Magma", C = c, S = { 0.5, 1.4, 0.5 }, Rot = { 12, deg(a), 0 } })
		table.insert(bits, { Name = "Magma", Group = "Ring", Color = "MagmaHot", C = { c[1] * 1.04, 3.1, c[3] * 1.04 }, S = { 0.4, 0.9, 0.4 }, Rot = { -18, deg(a) + 40, 0 } })
	end
	specs.Nest_LavaLagoon = {
		Voxel = 0.8,
		StudScale = 1.6,
		Palette = {
			Ash = "6B5B57",
			Coal = "2A2223",
			Ember = { "FF6A1F", Neon = true },
			EmberHot = { "FFB21F", Neon = true },
			Basalt = "4A3D3B",
			BasaltDark = "332A29",
			Rock = "5E4E4A",
			Seam = { "FF7A2A", Neon = true },
			Obsidian = "2A1F33",
			ObsidianLight = "45355A",
			Magma = { "FF8A2A", Neon = true },
			MagmaHot = { "FFD050", Neon = true },
		},
		Shapes = shapes,
		Bits = bits,
	}
end

-- ---------- guardian: "Magmaw" ----------
-- A huge obsidian mama Molten Rex: glowing lava cracks down its sides, molten belly seams, a row of blazing back
-- plates, bone horns and a glowing mouth. Rig groups as Old Boulderback (Head / Jaw / LegL / LegR / ArmL / ArmR / Tail).
do
	local K = 2.85
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
		sh("Body", "Obsidian", "Ellipsoid", { C = { 0, 1.8, 0.3 }, R = { 1.3, 1.3, 1.3 } }),
		sh("Body", "Belly", "Ellipsoid", { C = { 0, 1.65, -0.4 }, R = { 0.95, 1.0, 0.6 } }),
		sh("Body", "Crust", "Ellipsoid", { C = { 0, 2.75, 0.6 }, R = { 1.45, 0.55, 1.25 }, Paint = true }),
		-- molten seams between the belly plates
		sh("Body", "Lava", "Box", { C = { 0, 1.15, -0.95 }, S = { 2.2, 0.13, 1.0 }, Paint = true }),
		sh("Body", "Lava", "Box", { C = { 0, 1.65, -0.95 }, S = { 2.2, 0.13, 1.0 }, Paint = true }),
		sh("Body", "Lava", "Box", { C = { 0, 2.15, -0.95 }, S = { 2.2, 0.13, 1.0 }, Paint = true }),
		-- lava cracks down both sides
		sh("Body", "Lava", "Box", { C = { 1.25, 2.0, 0.4 }, S = { 0.6, 0.14, 2.4 }, Rot = { 0, 0, 25 }, Paint = true }),
		sh("Body", "Lava", "Box", { C = { -1.25, 2.0, 0.4 }, S = { 0.6, 0.14, 2.4 }, Rot = { 0, 0, -25 }, Paint = true }),
		sh("Body", "LavaHot", "Box", { C = { 1.2, 1.4, 0.7 }, S = { 0.6, 0.14, 1.6 }, Rot = { 20, 0, -15 }, Paint = true }),
		sh("Body", "LavaHot", "Box", { C = { -1.2, 1.4, 0.7 }, S = { 0.6, 0.14, 1.6 }, Rot = { 20, 0, 15 }, Paint = true }),
		-- head: heavy brow, boxy snout, crusty cap, dark lower jaw
		sh("Head", "Obsidian", "Ellipsoid", { C = { 0, 3.6, -0.45 }, R = { 1.1, 0.95, 1.0 } }),
		sh("Head", "Obsidian", "Box", { C = { 0, 3.1, -1.55 }, S = { 1.4, 0.75, 1.5 } }),
		sh("Jaw", "Belly", "Box", { C = { 0, 2.65, -1.45 }, S = { 1.25, 0.42, 1.3 } }),
		sh("Head", "Crust", "Ellipsoid", { C = { 0, 4.35, -0.35 }, R = { 1.1, 0.35, 1.0 }, Paint = true }),
		sh("Head", "ObsidianDark", "Box", { C = { 0, 4.08, -1.25 }, S = { 2.0, 0.3, 0.45 } }),
		sh("Head", "Lava", "Box", { C = { 0, 3.5, -1.55 }, S = { 0.14, 0.4, 1.5 }, Paint = true }),
		-- legs and feet
		sh("LegL", "Obsidian", "Capsule", { A = { 0.9, 1.2, 0.3 }, B = { 0.95, 0.5, 0.1 }, RA = 0.75, RB = 0.6, Mirror = true }),
		sh("LegL", "ObsidianDark", "Box", { C = { 0.95, 0.22, -0.15 }, S = { 1.4, 0.45, 1.6 }, Mirror = true }),
		sh("LegL", "Lava", "Box", { C = { 1.5, 0.9, 0.25 }, S = { 0.4, 0.13, 1.4 }, Rot = { 0, 0, 20 }, Paint = true, Mirror = true }),
		-- little arms
		sh("ArmL", "Obsidian", "Capsule", { A = { 1.2, 2.2, -0.3 }, B = { 1.35, 1.7, -0.85 }, R = 0.36, Mirror = true }),
		sh("ArmL", "Claw", "Box", { C = { 1.35, 1.55, -1.15 }, S = { 0.55, 0.36, 0.32 }, Mirror = true }),
		-- tail with lava stripes and a glowing tip
		sh("Tail", "Obsidian", "Capsule", { A = { 0, 1.2, 1.15 }, B = { 0, 0.8, 2.35 }, RA = 0.8, RB = 0.56 }),
		sh("Tail", "Obsidian", "Capsule", { A = { 0, 0.8, 2.35 }, B = { 0, 0.62, 3.35 }, RA = 0.56, RB = 0.33 }),
		sh("Tail", "Obsidian", "Capsule", { A = { 0, 0.62, 3.35 }, B = { 0, 0.85, 3.9 }, RA = 0.33, RB = 0.2 }),
		sh("Tail", "Crust", "Box", { C = { 0, 1.5, 2.3 }, S = { 2, 0.5, 2.6 }, Paint = true }),
		sh("Tail", "Lava", "Box", { C = { 0, 0.9, 1.9 }, S = { 2, 1.6, 0.14 }, Paint = true }),
		sh("Tail", "Lava", "Box", { C = { 0, 0.7, 2.8 }, S = { 2, 1.2, 0.14 }, Paint = true }),
		sh("Tail", "LavaHot", "Ellipsoid", { C = { 0, 0.85, 3.95 }, R = { 0.3, 0.3, 0.3 }, Paint = true }),
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
		d({ Name = "EyeOpen", Group = "Head", Color = "Eye", X = 0.5, Y = 3.78, W = 0.5, H = 0.4, D = 0.05, Mirror = true }),
		d({ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.48, Y = 3.77, W = 0.13, H = 0.36, D = 0.07, Mirror = true }),
		d({ Name = "EyeClosed", Group = "Head", Color = "Ink", X = 0.55, Y = 3.72, W = 0.78, H = 0.13, D = 0.06, Tilt = -6, Mirror = true }),
		d({ Name = "Brow", Group = "Head", Color = "ObsidianDark", X = 0.55, Y = 4.22, W = 0.95, H = 0.22, D = 0.07, Tilt = 14, Mirror = true }),
		d({ Name = "Nostril", Group = "Head", Color = "Lava", X = 0.32, Y = 3.25, W = 0.14, H = 0.14, D = 0.05, Mirror = true }),
		d({ Name = "Mouth", Group = "Head", Color = "Lava", X = 0, Y = 2.85, W = 1.05, H = 0.12, D = 0.03 }),
		d({ Name = "Fang", Group = "Head", Color = "Claw", X = 0.42, Y = 2.72, W = 0.2, H = 0.28, D = 0.05, Mirror = true }),
	}
	local function b(t)
		t.C = v(t.C[1], t.C[2], t.C[3])
		t.S = v(t.S[1], t.S[2], t.S[3])
		return t
	end
	local bits = {
		-- blazing back plates from the head to the tail
		b({ Name = "Plate", Group = "Head", Color = "LavaHot", C = { 0, 4.75, -0.15 }, S = { 0.3, 0.8, 0.55 }, Rot = { -10, 0, 0 } }),
		b({ Name = "Plate", Group = "Body", Color = "Lava", C = { 0, 3.7, 0.6 }, S = { 0.34, 1.1, 0.7 }, Rot = { 15, 0, 0 } }),
		b({ Name = "Plate", Group = "Body", Color = "LavaHot", C = { 0, 3.35, 1.25 }, S = { 0.32, 0.95, 0.6 }, Rot = { 25, 0, 0 } }),
		b({ Name = "Plate", Group = "Body", Color = "Lava", C = { 0, 2.65, 1.75 }, S = { 0.3, 0.8, 0.55 }, Rot = { 35, 0, 0 } }),
		b({ Name = "Plate", Group = "Tail", Color = "LavaHot", C = { 0, 1.95, 2.4 }, S = { 0.28, 0.7, 0.5 }, Rot = { 40, 0, 0 } }),
		b({ Name = "Plate", Group = "Tail", Color = "Lava", C = { 0, 1.5, 3.1 }, S = { 0.24, 0.55, 0.4 }, Rot = { 45, 0, 0 } }),
		-- bone horns sweeping back (explicit pairs: mirrored bits don't mirror their rotation)
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { 0.62, 4.45, -0.2 }, S = { 0.28, 1.0, 0.28 }, Rot = { -35, 0, -25 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { -0.62, 4.45, -0.2 }, S = { 0.28, 1.0, 0.28 }, Rot = { -35, 0, 25 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { 0.88, 4.95, 0.12 }, S = { 0.2, 0.55, 0.2 }, Rot = { -70, 0, -25 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { -0.88, 4.95, 0.12 }, S = { 0.2, 0.55, 0.2 }, Rot = { -70, 0, 25 } }),
		-- toe claws
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.55, 0.15, -1.0 }, S = { 0.28, 0.3, 0.3 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.95, 0.15, -1.02 }, S = { 0.28, 0.3, 0.32 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.35, 0.15, -1.0 }, S = { 0.28, 0.3, 0.3 }, Mirror = true }),
	}
	local joints = {}
	for name, j in {
		Head = { 0, 2.85, -0.35 },
		Jaw = { 0, 2.85, -0.8 },
		LegL = { 0.9, 1.2, 0.3 },
		LegR = { -0.9, 1.2, 0.3 },
		ArmL = { 1.2, 2.2, -0.3 },
		ArmR = { -1.2, 2.2, -0.3 },
		Tail = { 0, 1.2, 1.1 },
	} do
		joints[name] = v(j[1], j[2], j[3])
	 end
	specs.Guardian_LavaLagoon = {
		Voxel = 0.7,
		StudScale = 1.4,
		Palette = {
			Obsidian = "2E2530",
			ObsidianDark = "1E1820",
			Crust = "3B2D2B",
			Belly = "4E2822",
			Lava = { "FF6A1F", Neon = true },
			LavaHot = { "FFB21F", Neon = true },
			Eye = { "FFD23F", Neon = true },
			Claw = "EDE2D2",
			Horn = "E8DCC8",
			Ink = "140A0A",
		},
		Joints = joints,
		Parents = { Jaw = "Head" },
		Shapes = shapes,
		Details = details,
		Bits = bits,
		RootSize = { 8.2, 6.6, 10.4 },
		HipHeight = 1.75,
	}
end

-- ---------- props ----------
-- Pivot = centre of the base, facing -Z. Wall props are built upward from y = 0 with their back at z = 0 (the wall)
-- and their front towards -Z (into the lane).
local LAVA = {
	Basalt = "4A3D3B",
	BasaltDark = "332A29",
	BasaltLight = "6A5A56",
	Crust = "2E2422",
	Char = "2A2226",
	Obsidian = "2A1F33",
	ObsidianLight = "4A3866",
	Bone = "E8DCC8",
	BoneDark = "C4B49C",
	Stalk = "3A2A26",
	Lava = { "FF6A1F", Neon = true },
	LavaHot = { "FFB21F", Neon = true },
	LavaSurface = { "FF7A22", Neon = true },
	LavaFlow = { "FF6A1F", Neon = true },
	Magma = { "FF8A2A", Neon = true },
	MagmaHot = { "FFD050", Neon = true },
	EmberTip = { "FFB21F", Neon = true },
}
local function palette(keys)
	local p = {}
	for _, k in keys do
		p[k] = LAVA[k]
	end
	return p
end

specs.Prop_LavaRock = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Basalt", "BasaltDark", "BasaltLight", "Lava", "LavaHot" }),
	Shapes = {
		{ Group = "Rock", Color = "Basalt", Kind = "Ellipsoid", C = { 0, 1.0, 0 }, R = { 2.0, 1.45, 1.7 } },
		{ Group = "Rock", Color = "BasaltDark", Kind = "Ellipsoid", C = { 1.45, 0.6, 0.8 }, R = { 1.1, 0.85, 0.95 } },
		{ Group = "Rock", Color = "BasaltLight", Kind = "Ellipsoid", C = { -1.3, 0.55, -0.7 }, R = { 0.9, 0.7, 0.8 } },
		{ Group = "Rock", Color = "Lava", Kind = "Box", C = { 0, 1.3, 0 }, S = { 5, 0.3, 0.3 }, Rot = { 0, 30, 18 }, Paint = true },
		{ Group = "Rock", Color = "LavaHot", Kind = "Box", C = { 0.3, 0.9, 0 }, S = { 0.3, 1.6, 4.2 }, Rot = { 20, 0, 10 }, Paint = true },
		{ Group = "Rock", Color = "Lava", Kind = "Box", C = { -0.4, 1.7, 0.2 }, S = { 3.5, 0.3, 0.3 }, Rot = { 0, -40, -10 }, Paint = true },
	},
}

specs.Prop_ObsidianSpire = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Basalt", "BasaltDark", "Obsidian", "ObsidianLight", "Lava" }),
	Shapes = {
		{ Group = "Spire", Color = "Basalt", Kind = "Ellipsoid", C = { 0, 0.4, 0 }, R = { 2.6, 0.9, 2.2 } },
		{ Group = "Spire", Color = "Obsidian", Kind = "Box", C = { 0, 3.6, 0 }, S = { 1.5, 7.2, 1.5 }, Rot = { 4, 45, 5 } },
		{ Group = "Spire", Color = "ObsidianLight", Kind = "Box", C = { 1.3, 2.4, 0.6 }, S = { 1.0, 4.8, 1.0 }, Rot = { -8, 20, -18 } },
		{ Group = "Spire", Color = "Obsidian", Kind = "Box", C = { -1.2, 2.0, -0.7 }, S = { 0.9, 4.0, 0.9 }, Rot = { 10, 60, 16 } },
		{ Group = "Spire", Color = "ObsidianLight", Kind = "Box", C = { 0.3, 1.4, -1.4 }, S = { 0.8, 2.8, 0.8 }, Rot = { 22, 10, 6 } },
		{ Group = "Spire", Color = "Lava", Kind = "Box", C = { 0, 0.85, 0 }, S = { 6, 0.25, 0.25 }, Rot = { 0, 70, 0 }, Paint = true },
	},
}

specs.Prop_MagmaCrystal = {
	Voxel = 0.4,
	StudScale = 0.8,
	StudFaces = "Top",
	Palette = palette({ "Basalt", "BasaltDark", "Magma", "MagmaHot" }),
	Shapes = {
		{ Group = "Crystal", Color = "Basalt", Kind = "Ellipsoid", C = { 0, 0.35, 0 }, R = { 1.5, 0.55, 1.3 } },
		{ Group = "Crystal", Color = "BasaltDark", Kind = "Ellipsoid", C = { 0.9, 0.3, 0.6 }, R = { 0.7, 0.45, 0.6 } },
		{ Group = "Crystal", Color = "Magma", Kind = "Box", C = { 0, 1.6, 0 }, S = { 0.75, 2.8, 0.75 }, Rot = { 0, 45, 8 } },
		{ Group = "Crystal", Color = "MagmaHot", Kind = "Box", C = { 0.75, 1.1, 0.3 }, S = { 0.55, 1.8, 0.55 }, Rot = { 0, 10, -25 } },
		{ Group = "Crystal", Color = "Magma", Kind = "Box", C = { -0.65, 1.0, -0.3 }, S = { 0.55, 1.6, 0.55 }, Rot = { 15, 30, 22 } },
		{ Group = "Crystal", Color = "MagmaHot", Kind = "Box", C = { 0.1, 0.8, -0.8 }, S = { 0.45, 1.1, 0.45 }, Rot = { -25, 0, 5 } },
	},
	Fx = { { Kind = "Glow", At = { 0, 1.6, 0 }, Color = "FF8A2A", Range = 10, Brightness = 1.2 } },
}

specs.Prop_Vent = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Basalt", "BasaltDark", "BasaltLight", "Lava", "LavaHot" }),
	Shapes = {
		{ Group = "Vent", Color = "Basalt", Kind = "Ellipsoid", C = { 0, 0.8, 0 }, R = { 2.6, 1.1, 2.6 } },
		{ Group = "Vent", Color = "BasaltDark", Kind = "Ellipsoid", C = { 0, 2.0, 0 }, R = { 1.75, 1.0, 1.75 } },
		{ Group = "Vent", Color = "Basalt", Kind = "Ellipsoid", C = { 0, 2.95, 0 }, R = { 1.15, 0.7, 1.15 } },
		{ Group = "Vent", Color = "BasaltLight", Kind = "Ellipsoid", C = { 1.9, 0.5, -0.8 }, R = { 0.8, 0.6, 0.7 } },
		{ Group = "Vent", Color = "Lava", Kind = "Box", C = { 0, 1.6, 0 }, S = { 0.3, 3.0, 6 }, Rot = { 0, 25, 0 }, Paint = true },
		{ Group = "Vent", Color = "Lava", Kind = "Box", C = { 0, 1.2, 0 }, S = { 6, 2.0, 0.3 }, Rot = { 0, -35, 0 }, Paint = true },
		{ Group = "Vent", Kind = "Ellipsoid", Color = "Basalt", C = { 0, 3.55, 0 }, R = { 0.75, 0.9, 0.75 }, Carve = true },
	},
	Bits = {
		{ Name = "VentGlow", Group = "Vent", Color = "LavaHot", C = { 0, 3.0, 0 }, S = { 1.2, 0.25, 1.2 } },
	},
	Fx = {
		{ Kind = "Smoke", At = { 0, 3.3, 0 } },
		{ Kind = "Embers", At = { 0, 3.2, 0 } },
		{ Kind = "Glow", At = { 0, 3.4, 0 }, Color = "FF7A22", Range = 9, Brightness = 1 },
	},
}

specs.Prop_CharredTree = {
	Voxel = 0.5,
	StudScale = 1.0,
	StudFaces = "Top",
	Palette = palette({ "Char", "Crust", "Lava", "EmberTip" }),
	Shapes = {
		{ Group = "Tree", Color = "Char", Kind = "Capsule", A = { 0, 0, 0 }, B = { 0.2, 6.0, 0 }, RA = 0.8, RB = 0.4 },
		{ Group = "Tree", Color = "Crust", Kind = "Box", C = { 0, 0.35, 0 }, S = { 2.6, 0.7, 2.6 } },
		{ Group = "Tree", Color = "Char", Kind = "Capsule", A = { 0.1, 3.6, 0 }, B = { 2.0, 5.4, 0.4 }, R = 0.32 },
		{ Group = "Tree", Color = "Char", Kind = "Capsule", A = { 0.15, 4.4, 0 }, B = { -1.8, 6.2, -0.3 }, R = 0.3 },
		{ Group = "Tree", Color = "Char", Kind = "Capsule", A = { 0.2, 5.2, 0 }, B = { 0.6, 7.2, 1.3 }, R = 0.24 },
		{ Group = "Tree", Color = "Char", Kind = "Capsule", A = { 2.0, 5.4, 0.4 }, B = { 2.6, 6.5, 0.2 }, R = 0.2 },
		{ Group = "Tree", Color = "Lava", Kind = "Box", C = { 0, 2.5, -0.5 }, S = { 0.25, 4.0, 1.0 }, Rot = { 0, 0, 8 }, Paint = true },
		{ Group = "Tree", Color = "Lava", Kind = "Box", C = { 0.4, 1.5, 0.4 }, S = { 1.0, 2.4, 0.25 }, Rot = { 0, 30, -10 }, Paint = true },
	},
	Bits = {
		{ Name = "EmberTip", Group = "Tree", Color = "EmberTip", C = { 2.65, 6.7, 0.2 }, S = { 0.35, 0.35, 0.35 } },
		{ Name = "EmberTip", Group = "Tree", Color = "EmberTip", C = { -1.9, 6.4, -0.3 }, S = { 0.35, 0.35, 0.35 } },
		{ Name = "EmberTip", Group = "Tree", Color = "EmberTip", C = { 0.65, 7.4, 1.35 }, S = { 0.3, 0.3, 0.3 } },
	},
	Fx = { { Kind = "Embers", At = { 0.3, 6.2, 0.3 }, Rate = 3 } },
}

specs.Prop_LavaPool = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Basalt", "BasaltDark", "BasaltLight", "LavaSurface", "LavaHot" }),
	Shapes = (function()
		local s = {
			{ Group = "Pool", Color = "LavaSurface", Kind = "Ellipsoid", C = { 0, 0.1, 0 }, R = { 3.6, 0.4, 3.0 } },
			{ Group = "Pool", Color = "LavaHot", Kind = "Ellipsoid", C = { 0.8, 0.3, 0.4 }, R = { 1.4, 0.5, 1.0 }, Paint = true },
			{ Group = "Pool", Color = "LavaHot", Kind = "Ellipsoid", C = { -1.2, 0.3, -0.6 }, R = { 0.8, 0.5, 0.7 }, Paint = true },
		}
		local colors = { "Basalt", "BasaltDark", "BasaltLight" }
		for k = 0, 13 do
			local a = k / 14 * math.pi * 2
			local r = k % 2 == 0 and 1.0 or 0.75
			table.insert(s, { Group = "Pool", Color = colors[k % 3 + 1], Kind = "Ellipsoid", C = { math.cos(a) * 4.0, 0.35, math.sin(a) * 3.4 }, R = { r, 0.6 + (k % 3) * 0.12, r * 0.9 } })
		end
		return s
	end)(),
	Fx = {
		{ Kind = "Bubbles", At = { 0, 0.5, 0 }, Area = { 5, 0.2, 4 } },
		{ Kind = "Glow", At = { 0, 1.5, 0 }, Color = "FF7A22", Range = 14, Brightness = 1.4 },
	},
}

-- lava pouring down a cliff face into a little pool (WALL studs tall)
specs.Prop_LavaFall = {
	Voxel = 0.8,
	StudScale = 1.6,
	StudFaces = "Top",
	Length = WALL,
	Palette = palette({ "Basalt", "BasaltDark", "Crust", "LavaFlow", "LavaHot" }),
	Shapes = {
		{ Group = "Fall", Color = "LavaFlow", Kind = "Box", C = { 0, WALL / 2, -0.4 }, S = { 3.2, WALL, 0.9 } },
		{ Group = "Fall", Color = "LavaHot", Kind = "Box", C = { 0, WALL / 2, -0.85 }, S = { 1.0, WALL, 0.3 }, Paint = true },
		{ Group = "Fall", Color = "Crust", Kind = "Box", C = { 2.1, WALL / 2, -0.35 }, S = { 1.0, WALL, 1.0 } },
		{ Group = "Fall", Color = "BasaltDark", Kind = "Box", C = { -2.1, WALL / 2, -0.35 }, S = { 1.0, WALL, 1.0 } },
		{ Group = "Fall", Color = "Crust", Kind = "Box", C = { 0, WALL - 0.5, -0.8 }, S = { 5.2, 1.0, 1.8 } },
		{ Group = "Fall", Color = "LavaFlow", Kind = "Ellipsoid", C = { 0, 0.15, -2.0 }, R = { 2.8, 0.45, 2.0 } },
		{ Group = "Fall", Color = "Basalt", Kind = "Ellipsoid", C = { 2.9, 0.4, -2.2 }, R = { 0.9, 0.6, 0.8 } },
		{ Group = "Fall", Color = "BasaltDark", Kind = "Ellipsoid", C = { -2.8, 0.35, -2.4 }, R = { 0.8, 0.55, 0.8 } },
		{ Group = "Fall", Color = "Basalt", Kind = "Ellipsoid", C = { 0.6, 0.3, -3.9 }, R = { 0.8, 0.5, 0.6 } },
	},
	Fx = {
		{ Kind = "Embers", At = { 0, 0.8, -2.0 }, Rate = 6 },
		{ Kind = "Smoke", At = { 0, 0.8, -2.0 }, Rate = 2 },
		{ Kind = "Glow", At = { 0, 4, -3 }, Color = "FF7A22", Range = 18, Brightness = 1.6 },
	},
}

-- a short glowing zigzag crack for the cliff faces
specs.Prop_LavaVein = {
	Voxel = 0.4,
	NoStuds = true,
	Length = 6,
	Palette = palette({ "Lava", "LavaHot" }),
	Shapes = {},
	Bits = (function()
		local bits = {}
		local x = 0
		for k = 0, 4 do
			local dir = k % 2 == 0 and 1 or -1
			table.insert(bits, { Name = "Vein", Group = "Vein", Color = k % 2 == 0 and "Lava" or "LavaHot", C = { x + dir * 0.3, 0.6 + k * 1.15, -0.1 }, S = { 0.35, 1.45, 0.3 }, Rot = { 0, 0, -dir * 28 } })
			x += dir * 0.6
		end
		table.insert(bits, { Name = "Vein", Group = "Vein", Color = "Lava", C = { 0.9, 2.4, -0.1 }, S = { 0.25, 1.0, 0.25 }, Rot = { 0, 0, 55 } })
		return bits
	end)(),
}

specs.Prop_Bones = {
	Voxel = 0.4,
	StudScale = 0.8,
	StudFaces = "Top",
	Palette = palette({ "Bone", "BoneDark" }),
	Shapes = (function()
		local s = {
			{ Group = "Bones", Color = "Bone", Kind = "Ellipsoid", C = { 0, 0.95, -1.2 }, R = { 1.25, 0.95, 1.15 } },
			{ Group = "Bones", Color = "Bone", Kind = "Box", C = { 0, 0.6, -2.35 }, S = { 1.3, 0.75, 1.3 } },
			{ Group = "Bones", Color = "BoneDark", Kind = "Ellipsoid", C = { 0.5, 1.2, -2.1 }, R = { 0.35, 0.35, 0.45 }, Carve = true },
			{ Group = "Bones", Color = "BoneDark", Kind = "Ellipsoid", C = { -0.5, 1.2, -2.1 }, R = { 0.35, 0.35, 0.45 }, Carve = true },
			{ Group = "Bones", Color = "BoneDark", Kind = "Capsule", A = { 0, 1.7, 0.1 }, B = { 0, 0.35, 4.3 }, R = 0.28 },
		}
		for i = 0, 3 do
			local z = 0.6 + i * 0.95
			local top = 1.75 - i * 0.3
			table.insert(s, { Group = "Bones", Color = "Bone", Kind = "Capsule", A = { 0, top, z }, B = { 1.5 - i * 0.15, 0.15, z }, R = 0.22, Mirror = true })
		end
		return s
	end)(),
}

specs.Prop_EmberPlant = {
	Voxel = 0.25,
	NoStuds = true,
	Palette = palette({ "Stalk", "Magma", "MagmaHot", "Lava" }),
	Shapes = {},
	Bits = (function()
		local bits = {}
		local rng = Random.new(47)
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + rng:NextNumber(0, 0.6)
			local r = k == 0 and 0 or 0.55
			local h = rng:NextNumber(0.9, 1.6)
			local x, z = math.cos(a) * r, math.sin(a) * r
			table.insert(bits, { Name = "Stalk", Group = "Plant", Color = "Stalk", C = { x, h / 2, z }, S = { 0.16, h, 0.16 } })
			table.insert(bits, { Name = "Bulb", Group = "Plant", Color = k % 2 == 0 and "Magma" or "MagmaHot", C = { x, h + 0.2, z }, S = { 0.42, 0.42, 0.42 }, Rot = { 0, 45, 0 } })
			table.insert(bits, { Name = "Leaf", Group = "Plant", Color = "Lava", C = { x + 0.15, h * 0.45, z }, S = { 0.4, 0.1, 0.18 }, Rot = { 0, deg(a), 30 } })
		end
		return bits
	end)(),
}

-- NEST > signpost: basalt post, charred board, glowing ember at its foot
specs.Prop_NestSignLava = {
	Voxel = 0.25,
	StudScale = 1.0,
	StudFaces = "Top",
	Palette = { Post = "2E2422", Board = "4A3A34", Base = "3B3133", Glow = { "FF7A22", Neon = true } },
	Shapes = {
		{ Group = "Sign", Color = "Post", Kind = "Box", C = { 0, 2.0, 0 }, S = { 0.5, 4.0, 0.5 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 0.25, 3.3, -0.3 }, S = { 3.5, 1.0, 0.25 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 2.15, 3.3, -0.3 }, S = { 0.5, 0.75, 0.25 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 2.4, 3.3, -0.3 }, S = { 0.25, 0.5, 0.25 } },
		{ Group = "Sign", Color = "Base", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 0.9, 0.4, 0.9 } },
		{ Group = "Sign", Color = "Glow", Kind = "Box", C = { 0.5, 0.7, -0.3 }, S = { 0.25, 0.25, 0.25 } },
	},
	Board = { C = { 0.25, 3.3, -0.3 } },
}

-- ---------- lane dressing (Tools.BiomeArtBuilder.DressLane) ----------
-- Counts are for a 120 x 80 biome and scale with the biome's floor area.
specs.Dress_LavaLagoon = {
	Sign = "NestSignLava",
	Trail = { "7C6A64", "6E5C57" }, -- ash path
	TrailPebbles = { "3B3133", "4E4240", "2C2426" },
	Trim = { Rocks = { "3B3133", "4A3D3B", "2C2426" }, Caps = { "FF6A1F", "FFA12E" }, CapNeon = true, CapChance = 0.3 },
	Edge = { Picks = { { "ObsidianSpire", 4, true }, { "CharredTree", 3, true }, { "Vent", 3, true } }, Every = { 20, 28 }, Inset = 6.5, Scale = { 0.9, 1.2 }, Radius = 5 },
	Bands = { Count = 14, Picks = { { "LavaRock", 4, true }, { "MagmaCrystal", 3, false }, { "LavaPool", 3, false }, { "Bones", 1, false } }, Scale = { 0.85, 1.25 }, Radius = 3.5 },
	Small = { Count = 22, Picks = { { "EmberPlant", 3 }, { "MagmaCrystal", 1, 0.45, 0.6 } }, Scale = { 0.9, 1.3 } },
	Walls = {
		{ Name = "LavaFall", Mode = "Floor", Every = { 40, 60 } },
		{ Name = "LavaVein", Mode = "Band", Every = { 9, 15 }, Y = { 6, WALL - 12 } },
	},
}

return specs
