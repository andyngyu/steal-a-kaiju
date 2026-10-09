-- Frostfang Peaks art specs (merged into Tools.BiomeArtSpecs; built by Tools.BiomeArtBuilder): egg, nest, the guardian
-- "Old Frostfang" (a giant yeti), props and the lane dressing. Same spec format as Tools.KaijuBuilder.
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
-- Frosty white-blue shell with ice-blue speckles, a frosted cap and the zigzag crack band (group "Band", tinted per
-- rarity by Lib.EggModel). Exactly EggConfig.Size (2.2 x 2.8 x 2.2).
do
	local shapes = {
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.3, 0 }, R = { 1.1, 1.3, 1.1 } },
		{ Group = "Shell", Color = "Cream", Kind = "Ellipsoid", C = { 0, 1.55, 0 }, R = { 0.92, 1.25, 0.92 } },
		{ Group = "Shell", Color = "CreamShade", Kind = "Box", C = { 0, 0.25, 0 }, S = { 3, 0.5, 3 }, Paint = true },
		{ Group = "Shell", Color = "Frost", Kind = "Ellipsoid", C = { 0, 2.75, 0 }, R = { 0.8, 0.3, 0.8 }, Paint = true },
	}
	local function surface(y)
		local r1 = 1.1 * math.sqrt(math.max(0, 1 - ((y - 1.3) / 1.3) ^ 2))
		local r2 = 0.92 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.25) ^ 2))
		return math.max(r1, r2)
	end
	local colors = { "Ice", "IceDeep", "Ice", "Snow" }
	local rng = Random.new(51)
	for k = 0, 17 do
		local a = k * 2.39996 + 0.2
		local y = k % 3 == 2 and rng:NextNumber(0.3, 0.55) or rng:NextNumber(1.95, 2.5)
		local r = surface(y) - 0.04
		local size = rng:NextNumber(0.13, 0.17)
		table.insert(shapes, { Group = "Shell", Color = colors[k % #colors + 1], Kind = "Ellipsoid", C = { math.cos(a) * r, y, math.sin(a) * r }, R = { size, size, size }, Paint = true })
	end
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
	specs.Egg_FrostfangPeaks = {
		Voxel = 0.2,
		StudScale = 0.8,
		Palette = {
			Cream = "E6F4FF",
			CreamShade = "C8E2F5",
			Frost = "FFFFFF",
			Snow = "FFFFFF",
			Ice = "8FD0FF",
			IceDeep = "4F9FE6",
			Band = "B8C0CC",
			Shine = "FFFFFF",
		},
		Shapes = shapes,
	}
end

-- ---------- nest ----------
-- Rings of packed snow round a bed of white fur, ice shards jutting out, glowing ice crystals on the rim and snowy
-- ice chunks outside. Centre at the origin; the walk-in gap facing the bases is cut by BiomeArtBuilder.
do
	local shapes = {
		{ Group = "Bed", Color = "Fur", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 7.4, 0.75, 7.4 } },
	}
	local rng = Random.new(53)
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 6.4)
		table.insert(shapes, { Group = "Bed", Color = "FurShade", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.45, math.sin(a) * r }, R = { 0.9, 0.5, 0.6 }, Paint = true })
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
	ring(18, 8.0, 0.9, 1.45, { "Snow", "SnowShade", "Snow", "Ice" }, 0)
	ring(18, 7.6, 2.0, 1.05, { "SnowShade", "Snow", "Ice" }, 0.5)
	ring(18, 7.3, 2.75, 0.6, { "Snow", "IceDeep" }, 0.25)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.2
		if math.abs(math.abs(a) - math.pi) > 0.45 and math.abs(math.abs(a - math.pi * 2) - math.pi) > 0.45 then
			local r = 10.2 + (k % 2) * 0.5
			table.insert(shapes, { Group = "Pebbles", Color = k % 3 == 0 and "IceDeep" or "Ice", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.4, math.sin(a) * r }, R = { 0.85, 0.6, 0.7 } })
			table.insert(shapes, { Group = "Pebbles", Color = "Snow", Kind = "Ellipsoid", C = { math.cos(a) * r, 0.95, math.sin(a) * r }, R = { 0.75, 0.3, 0.6 }, Paint = true })
		end
	end
	local bits = {}
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.13
		local r = 8.9
		table.insert(bits, {
			Name = "Shard",
			Group = "Ring",
			Color = k % 2 == 0 and "Ice" or "IceDeep",
			C = { math.cos(a) * r, 2.4 + (k % 3) * 0.3, math.sin(a) * r },
			S = { 0.55, 2.6 + (k % 2) * 0.8, 0.55 },
			Rot = { 22 + (k % 3) * 6, deg(math.pi / 2 - a), 0 },
		})
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 1.0
		local c = { math.cos(a) * 7.4, 3.4, math.sin(a) * 7.4 }
		table.insert(bits, { Name = "Crystal", Group = "Ring", Color = "Glow", C = c, S = { 0.5, 1.4, 0.5 }, Rot = { 12, deg(a), 0 } })
		table.insert(bits, { Name = "Crystal", Group = "Ring", Color = "Ice", C = { c[1] * 1.04, 3.1, c[3] * 1.04 }, S = { 0.4, 0.9, 0.4 }, Rot = { -18, deg(a) + 40, 0 } })
	end
	specs.Nest_FrostfangPeaks = {
		Voxel = 0.8,
		StudScale = 1.6,
		Palette = {
			Fur = "F4F1EA",
			FurShade = "DDD8CC",
			Snow = "FFFFFF",
			SnowShade = "E2EEF8",
			Ice = "A8DEFF",
			IceDeep = "6EB8EE",
			Glow = { "BFF0FF", Neon = true },
		},
		Shapes = shapes,
		Bits = bits,
	}
end

-- ---------- guardian: "Old Frostfang" ----------
-- A huge shaggy yeti: white fur with icy blue tips, blue-grey face, hands and feet, curling horns, a crown of glowing
-- icicles, big lower fangs and long arms. Rig groups: Head / Jaw / LegL / LegR / ArmL / ArmR / Tail (a stubby tail).
do
	local K = 2.9
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
		-- shaggy body with a pale chest and icy blue fur on the shoulders and back
		sh("Body", "Fur", "Ellipsoid", { C = { 0, 2.3, 0.2 }, R = { 1.5, 1.55, 1.25 } }),
		sh("Body", "FurShade", "Ellipsoid", { C = { 0, 2.15, -0.75 }, R = { 0.95, 1.1, 0.5 }, Paint = true }),
		sh("Body", "FurBlue", "Ellipsoid", { C = { 0, 3.45, 0.6 }, R = { 1.5, 0.55, 1.0 }, Paint = true }),
		sh("Body", "FurBlue", "Box", { C = { 0, 2.5, 1.35 }, S = { 2.4, 0.25, 0.6 }, Paint = true }),
		sh("Body", "FurBlue", "Box", { C = { 0, 1.9, 1.35 }, S = { 2.4, 0.25, 0.6 }, Paint = true }),
		-- head: fur dome, blue-grey face, brow ridge, heavy jaw
		sh("Head", "Fur", "Ellipsoid", { C = { 0, 4.15, -0.25 }, R = { 1.05, 0.95, 0.95 } }),
		sh("Head", "Skin", "Ellipsoid", { C = { 0, 3.95, -1.05 }, R = { 0.78, 0.72, 0.4 }, Paint = true }),
		sh("Head", "FurShade", "Box", { C = { 0, 4.48, -1.0 }, S = { 1.8, 0.3, 0.45 } }),
		sh("Head", "FurBlue", "Ellipsoid", { C = { 0, 4.95, 0 }, R = { 0.9, 0.3, 0.8 }, Paint = true }),
		sh("Jaw", "Skin", "Box", { C = { 0, 3.42, -0.95 }, S = { 1.15, 0.45, 0.65 } }),
		sh("Jaw", "Fur", "Box", { C = { 0, 3.2, -0.75 }, S = { 1.35, 0.35, 0.7 } }),
		-- long arms with big blue-grey hands
		sh("ArmL", "Fur", "Capsule", { A = { 1.4, 3.2, 0.0 }, B = { 1.85, 1.6, -0.35 }, RA = 0.62, RB = 0.55, Mirror = true }),
		sh("ArmL", "FurBlue", "Box", { C = { 1.82, 1.85, -0.3 }, S = { 1.6, 0.3, 1.6 }, Paint = true, Mirror = true }),
		sh("ArmL", "Skin", "Ellipsoid", { C = { 1.92, 1.2, -0.42 }, R = { 0.58, 0.5, 0.56 }, Mirror = true }),
		-- short legs, wide feet
		sh("LegL", "Fur", "Capsule", { A = { 0.75, 1.05, 0.25 }, B = { 0.8, 0.5, 0.1 }, R = 0.65, Mirror = true }),
		sh("LegL", "Skin", "Box", { C = { 0.82, 0.22, -0.2 }, S = { 1.3, 0.45, 1.5 }, Mirror = true }),
		-- stubby fluffy tail
		sh("Tail", "Fur", "Ellipsoid", { C = { 0, 1.5, 1.4 }, R = { 0.48, 0.45, 0.42 } }),
		sh("Tail", "FurBlue", "Ellipsoid", { C = { 0, 1.7, 1.6 }, R = { 0.4, 0.25, 0.3 }, Paint = true }),
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
		d({ Name = "EyeOpen", Group = "Head", Color = "Eye", X = 0.38, Y = 4.12, W = 0.5, H = 0.42, D = 0.05, Mirror = true }),
		d({ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.36, Y = 4.1, W = 0.2, H = 0.3, D = 0.07, Mirror = true }),
		d({ Name = "EyeClosed", Group = "Head", Color = "Ink", X = 0.38, Y = 4.05, W = 0.5, H = 0.1, D = 0.06, Tilt = -6, Mirror = true }),
		d({ Name = "Nostril", Group = "Head", Color = "Ink", X = 0.14, Y = 3.78, W = 0.13, H = 0.11, D = 0.05, Mirror = true }),
		d({ Name = "Mouth", Group = "Head", Color = "Ink", X = 0, Y = 3.62, W = 0.9, H = 0.1, D = 0.03 }),
		d({ Name = "Fang", Group = "Jaw", Color = "Claw", X = 0.34, Y = 3.68, W = 0.2, H = 0.36, D = 0.06, Mirror = true }),
	}
	local function b(t)
		t.C = v(t.C[1], t.C[2], t.C[3])
		t.S = v(t.S[1], t.S[2], t.S[3])
		return t
	end
	local bits = {
		-- curling horns (explicit pairs: mirrored bits don't mirror their rotation)
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { 0.82, 4.7, -0.1 }, S = { 0.3, 0.85, 0.3 }, Rot = { -30, 0, -40 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { -0.82, 4.7, -0.1 }, S = { 0.3, 0.85, 0.3 }, Rot = { -30, 0, 40 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { 1.15, 5.1, 0.25 }, S = { 0.24, 0.6, 0.24 }, Rot = { -75, 0, -30 } }),
		b({ Name = "Horn", Group = "Head", Color = "Horn", C = { -1.15, 5.1, 0.25 }, S = { 0.24, 0.6, 0.24 }, Rot = { -75, 0, 30 } }),
		-- crown of glowing icicles
		b({ Name = "Crown", Group = "Head", Color = "IceGlow", C = { 0, 5.25, -0.2 }, S = { 0.24, 0.7, 0.24 }, Rot = { -8, 45, 0 } }),
		b({ Name = "Crown", Group = "Head", Color = "Ice", C = { 0.35, 5.12, -0.1 }, S = { 0.2, 0.5, 0.2 }, Rot = { -5, 45, -15 } }),
		b({ Name = "Crown", Group = "Head", Color = "Ice", C = { -0.35, 5.12, -0.1 }, S = { 0.2, 0.5, 0.2 }, Rot = { -5, 45, 15 } }),
		-- ice spikes on the back and shoulders
		b({ Name = "Spike", Group = "Body", Color = "IceGlow", C = { 0, 3.95, 0.85 }, S = { 0.3, 0.9, 0.3 }, Rot = { 25, 45, 0 } }),
		b({ Name = "Spike", Group = "Body", Color = "Ice", C = { 0.55, 3.75, 1.0 }, S = { 0.26, 0.75, 0.26 }, Rot = { 30, 45, -20 } }),
		b({ Name = "Spike", Group = "Body", Color = "Ice", C = { -0.55, 3.75, 1.0 }, S = { 0.26, 0.75, 0.26 }, Rot = { 30, 45, 20 } }),
		b({ Name = "Spike", Group = "Body", Color = "IceGlow", C = { 0, 3.3, 1.35 }, S = { 0.26, 0.7, 0.26 }, Rot = { 45, 45, 0 } }),
		b({ Name = "Spike", Group = "Body", Color = "Ice", C = { 1.25, 3.7, 0.2 }, S = { 0.24, 0.6, 0.24 }, Rot = { 10, 45, -40 } }),
		b({ Name = "Spike", Group = "Body", Color = "Ice", C = { -1.25, 3.7, 0.2 }, S = { 0.24, 0.6, 0.24 }, Rot = { 10, 45, 40 } }),
		-- claws on hands and feet
		b({ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.75, 0.8, -0.85 }, S = { 0.16, 0.3, 0.16 }, Mirror = true }),
		b({ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 2.0, 0.8, -0.85 }, S = { 0.16, 0.3, 0.16 }, Mirror = true }),
		b({ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 2.25, 0.85, -0.75 }, S = { 0.16, 0.3, 0.16 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.45, 0.15, -0.98 }, S = { 0.25, 0.28, 0.28 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.82, 0.15, -1.0 }, S = { 0.25, 0.28, 0.3 }, Mirror = true }),
		b({ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.2, 0.15, -0.98 }, S = { 0.25, 0.28, 0.28 }, Mirror = true }),
	}
	local joints = {}
	for name, j in {
		Head = { 0, 3.35, -0.2 },
		Jaw = { 0, 3.5, -0.6 },
		LegL = { 0.75, 1.05, 0.25 },
		LegR = { -0.75, 1.05, 0.25 },
		ArmL = { 1.4, 3.2, 0.0 },
		ArmR = { -1.4, 3.2, 0.0 },
		Tail = { 0, 1.5, 1.1 },
	} do
		joints[name] = v(j[1], j[2], j[3])
	end
	specs.Guardian_FrostfangPeaks = {
		Voxel = 0.7,
		StudScale = 1.4,
		Palette = {
			Fur = "F2F6FA",
			FurShade = "D3E0EC",
			FurBlue = "A9D2F5",
			Skin = "6F8FB8",
			Ice = "A8DEFF",
			IceGlow = { "C8F2FF", Neon = true },
			Horn = "E9EEF3",
			Claw = "F7F7F2",
			Eye = { "7FE6FF", Neon = true },
			Ink = "13213A",
		},
		Joints = joints,
		Parents = { Jaw = "Head" },
		Shapes = shapes,
		Details = details,
		Bits = bits,
		RootSize = { 8.5, 7.5, 7.5 },
		HipHeight = 2.4,
	}
end

-- ---------- props ----------
-- Pivot = centre of the base, facing -Z. Wall props are built upward from y = 0 with their back at z = 0 (the wall).
local FROST = {
	Snow = "FFFFFF",
	SnowShade = "E2EEF8",
	Ice = "A8DEFF",
	IceDeep = "6EB8EE",
	IceGlow = { "C8F2FF", Neon = true },
	PondIce = "BFE6FA",
	Rock = "8FA9C6",
	RockDark = "7690B0",
	RockLight = "A9BFD8",
	Pine = "2F8A5A",
	PineDark = "23704A",
	Wood = "6B4A33",
	Coal = "222222",
	Carrot = "FF8A2A",
	Scarf = "E8434F",
	Berry = "5AA8FF",
	Twig = "6B4A33",
}
local function palette(keys)
	local p = {}
	for _, k in keys do
		p[k] = FROST[k]
	end
	return p
end

-- snowy pine: stacked skirts of needles, each with snow on top
specs.Prop_SnowPine = {
	Voxel = 0.8,
	StudScale = 1.6,
	StudFaces = "Top",
	Palette = palette({ "Pine", "PineDark", "Wood", "Snow", "SnowShade" }),
	Shapes = (function()
		local s = {
			{ Group = "Tree", Color = "Wood", Kind = "Capsule", A = { 0, 0, 0 }, B = { 0, 3.0, 0 }, R = 0.55 },
		}
		local tiers = { { 2.6, 3.2, "Pine" }, { 4.1, 2.5, "PineDark" }, { 5.5, 1.85, "Pine" }, { 6.8, 1.15, "PineDark" } }
		for _, t in tiers do
			table.insert(s, { Group = "Tree", Color = t[3], Kind = "Ellipsoid", C = { 0, t[1], 0 }, R = { t[2], 0.95, t[2] } })
		end
		for _, t in tiers do
			table.insert(s, { Group = "Tree", Color = "Snow", Kind = "Ellipsoid", C = { 0, t[1] + 0.55, 0 }, R = { t[2] * 0.85, 0.5, t[2] * 0.85 }, Paint = true })
		end
		table.insert(s, { Group = "Tree", Color = "Snow", Kind = "Ellipsoid", C = { 0, 7.7, 0 }, R = { 0.6, 0.6, 0.6 } })
		table.insert(s, { Group = "Tree", Color = "SnowShade", Kind = "Ellipsoid", C = { 0, 0.15, 0 }, R = { 2.4, 0.4, 2.4 } })
		return s
	end)(),
}

specs.Prop_IceSpire = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Snow", "SnowShade", "Ice", "IceDeep", "IceGlow" }),
	Shapes = {
		{ Group = "Spire", Color = "Snow", Kind = "Ellipsoid", C = { 0, 0.4, 0 }, R = { 2.6, 0.9, 2.2 } },
		{ Group = "Spire", Color = "Ice", Kind = "Box", C = { 0, 3.8, 0 }, S = { 1.5, 7.6, 1.5 }, Rot = { 4, 45, 5 } },
		{ Group = "Spire", Color = "IceDeep", Kind = "Box", C = { 1.3, 2.4, 0.6 }, S = { 1.0, 4.8, 1.0 }, Rot = { -8, 20, -18 } },
		{ Group = "Spire", Color = "Ice", Kind = "Box", C = { -1.2, 2.0, -0.7 }, S = { 0.9, 4.0, 0.9 }, Rot = { 10, 60, 16 } },
		{ Group = "Spire", Color = "IceGlow", Kind = "Box", C = { 0.3, 1.4, -1.4 }, S = { 0.8, 2.8, 0.8 }, Rot = { 22, 10, 6 } },
		{ Group = "Spire", Color = "Snow", Kind = "Box", C = { 0, 1.0, 0 }, S = { 6, 0.6, 6 }, Paint = true },
	},
	Fx = { { Kind = "Sparkle", At = { 0, 4, 0 }, Area = { 2, 6, 2 } } },
}

specs.Prop_IceCrystal = {
	Voxel = 0.4,
	StudScale = 0.8,
	StudFaces = "Top",
	Palette = palette({ "Snow", "SnowShade", "Ice", "IceDeep", "IceGlow" }),
	Shapes = {
		{ Group = "Crystal", Color = "Snow", Kind = "Ellipsoid", C = { 0, 0.35, 0 }, R = { 1.5, 0.55, 1.3 } },
		{ Group = "Crystal", Color = "SnowShade", Kind = "Ellipsoid", C = { 0.9, 0.3, 0.6 }, R = { 0.7, 0.45, 0.6 } },
		{ Group = "Crystal", Color = "Ice", Kind = "Box", C = { 0, 1.6, 0 }, S = { 0.75, 2.8, 0.75 }, Rot = { 0, 45, 8 } },
		{ Group = "Crystal", Color = "IceGlow", Kind = "Box", C = { 0.75, 1.1, 0.3 }, S = { 0.55, 1.8, 0.55 }, Rot = { 0, 10, -25 } },
		{ Group = "Crystal", Color = "IceDeep", Kind = "Box", C = { -0.65, 1.0, -0.3 }, S = { 0.55, 1.6, 0.55 }, Rot = { 15, 30, 22 } },
		{ Group = "Crystal", Color = "Ice", Kind = "Box", C = { 0.1, 0.8, -0.8 }, S = { 0.45, 1.1, 0.45 }, Rot = { -25, 0, 5 } },
	},
	Fx = { { Kind = "Glow", At = { 0, 1.6, 0 }, Color = "9FDCFF", Range = 8, Brightness = 0.8 } },
}

specs.Prop_IceRock = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Rock", "RockDark", "RockLight", "Snow", "Ice" }),
	Shapes = {
		{ Group = "Rock", Color = "Rock", Kind = "Ellipsoid", C = { 0, 1.0, 0 }, R = { 2.0, 1.4, 1.7 } },
		{ Group = "Rock", Color = "RockDark", Kind = "Ellipsoid", C = { 1.45, 0.6, 0.8 }, R = { 1.1, 0.85, 0.95 } },
		{ Group = "Rock", Color = "RockLight", Kind = "Ellipsoid", C = { -1.3, 0.55, -0.7 }, R = { 0.9, 0.7, 0.8 } },
		{ Group = "Rock", Color = "Snow", Kind = "Ellipsoid", C = { -0.2, 2.1, -0.1 }, R = { 1.9, 0.6, 1.6 }, Paint = true },
		{ Group = "Rock", Color = "Ice", Kind = "Box", C = { 1.4, 0.4, -0.9 }, S = { 0.7, 1.6, 0.7 }, Rot = { 0, 45, -15 } },
	},
}

specs.Prop_SnowMound = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "Snow", "SnowShade", "Ice" }),
	Shapes = {
		{ Group = "Mound", Color = "Snow", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 2.6, 1.1, 2.0 } },
		{ Group = "Mound", Color = "Snow", Kind = "Ellipsoid", C = { 1.7, 0.2, 0.9 }, R = { 1.4, 0.8, 1.2 } },
		{ Group = "Mound", Color = "SnowShade", Kind = "Ellipsoid", C = { -1.6, 0.15, -0.6 }, R = { 1.3, 0.7, 1.1 } },
		{ Group = "Mound", Color = "SnowShade", Kind = "Box", C = { 0, 0.3, 0 }, S = { 7, 0.6, 7 }, Paint = true },
	},
}

specs.Prop_Snowman = {
	Voxel = 0.3,
	StudScale = 0.6,
	StudFaces = "Top",
	Palette = palette({ "Snow", "SnowShade", "Coal", "Carrot", "Scarf", "Twig" }),
	Shapes = {
		{ Group = "Snowman", Color = "Snow", Kind = "Ellipsoid", C = { 0, 1.1, 0 }, R = { 1.3, 1.15, 1.3 } },
		{ Group = "Snowman", Color = "SnowShade", Kind = "Box", C = { 0, 0.25, 0 }, S = { 3, 0.5, 3 }, Paint = true },
		{ Group = "Snowman", Color = "Snow", Kind = "Ellipsoid", C = { 0, 2.75, 0 }, R = { 0.95, 0.85, 0.95 } },
		{ Group = "Snowman", Color = "Snow", Kind = "Ellipsoid", C = { 0, 4.0, 0 }, R = { 0.7, 0.65, 0.7 } },
		{ Group = "Snowman", Color = "Scarf", Kind = "Box", C = { 0, 3.45, 0 }, S = { 1.7, 0.3, 1.7 } },
		{ Group = "Snowman", Color = "Coal", Kind = "Box", C = { 0, 4.65, 0 }, S = { 1.6, 0.15, 1.6 } },
		{ Group = "Snowman", Color = "Coal", Kind = "Box", C = { 0, 5.05, 0 }, S = { 1.0, 0.75, 1.0 } },
	},
	Bits = {
		{ Name = "Eye", Group = "Snowman", Color = "Coal", C = { 0.25, 4.15, -0.6 }, S = { 0.16, 0.16, 0.1 } },
		{ Name = "Eye", Group = "Snowman", Color = "Coal", C = { -0.25, 4.15, -0.6 }, S = { 0.16, 0.16, 0.1 } },
		{ Name = "Nose", Group = "Snowman", Color = "Carrot", C = { 0, 3.95, -0.85 }, S = { 0.16, 0.16, 0.6 }, Rot = { -8, 0, 0 } },
		{ Name = "Button", Group = "Snowman", Color = "Coal", C = { 0, 2.95, -0.92 }, S = { 0.16, 0.16, 0.1 } },
		{ Name = "Button", Group = "Snowman", Color = "Coal", C = { 0, 2.55, -0.93 }, S = { 0.16, 0.16, 0.1 } },
		{ Name = "Scarf", Group = "Snowman", Color = "Scarf", C = { 0.55, 3.0, -0.75 }, S = { 0.35, 0.9, 0.12 }, Rot = { 0, 0, -10 } },
		{ Name = "Arm", Group = "Snowman", Color = "Twig", C = { 1.45, 3.2, 0 }, S = { 1.4, 0.14, 0.14 }, Rot = { 0, 0, 25 } },
		{ Name = "Arm", Group = "Snowman", Color = "Twig", C = { -1.45, 3.2, 0 }, S = { 1.4, 0.14, 0.14 }, Rot = { 0, 0, -25 } },
	},
}

specs.Prop_FrozenPond = {
	Voxel = 0.6,
	StudScale = 1.2,
	StudFaces = "Top",
	Palette = palette({ "PondIce", "Ice", "Snow", "SnowShade" }),
	Shapes = (function()
		local s = {
			{ Group = "Pond", Color = "PondIce", Kind = "Ellipsoid", C = { 0, 0.1, 0 }, R = { 4.0, 0.4, 3.3 } },
			{ Group = "Pond", Color = "Ice", Kind = "Ellipsoid", C = { -0.8, 0.3, 0.5 }, R = { 1.8, 0.5, 1.2 }, Paint = true },
		}
		for k = 0, 13 do
			local a = k / 14 * math.pi * 2
			local r = k % 2 == 0 and 1.0 or 0.75
			table.insert(s, { Group = "Pond", Color = k % 3 == 0 and "SnowShade" or "Snow", Kind = "Ellipsoid", C = { math.cos(a) * 4.3, 0.25, math.sin(a) * 3.6 }, R = { r, 0.5, r * 0.9 } })
		end
		return s
	end)(),
	Bits = {
		{ Name = "Crack", Group = "Pond", Color = "Snow", C = { 0.6, 0.62, -0.3 }, S = { 2.4, 0.06, 0.12 }, Rot = { 0, 30, 0 } },
		{ Name = "Crack", Group = "Pond", Color = "Snow", C = { -0.3, 0.62, 0.6 }, S = { 1.6, 0.06, 0.12 }, Rot = { 0, -50, 0 } },
	},
	Fx = { { Kind = "Sparkle", At = { 0, 0.8, 0 }, Area = { 6, 0.2, 5 } } },
}

specs.Prop_FrostBush = {
	Voxel = 0.5,
	StudScale = 1.0,
	StudFaces = "Top",
	Palette = palette({ "PineDark", "Pine", "Snow", "Berry" }),
	Shapes = {
		{ Group = "Bush", Color = "PineDark", Kind = "Ellipsoid", C = { 0, 0.9, 0 }, R = { 1.6, 1.0, 1.4 } },
		{ Group = "Bush", Color = "Pine", Kind = "Ellipsoid", C = { 1.0, 0.7, 0.5 }, R = { 0.95, 0.75, 0.9 } },
		{ Group = "Bush", Color = "Snow", Kind = "Ellipsoid", C = { 0, 1.75, 0 }, R = { 1.5, 0.5, 1.3 }, Paint = true },
	},
	Bits = (function()
		local bits = {}
		local rng = Random.new(57)
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(bits, { Name = "Berry", Group = "Bush", Color = "Berry", C = { math.cos(a) * 1.5, rng:NextNumber(0.6, 1.3), math.sin(a) * 1.3 }, S = { 0.3, 0.3, 0.3 } })
		end
		return bits
	end)(),
}

-- a row of icicles hanging under a snow lip (hung from the wall top)
specs.Prop_Icicles = {
	Voxel = 0.3,
	NoStuds = true,
	Length = 4,
	Palette = palette({ "Snow", "Ice", "IceDeep" }),
	Shapes = {
		{ Group = "Icicles", Color = "Snow", Kind = "Box", C = { 0, 3.75, -0.35 }, S = { 5.4, 0.5, 1.0 } },
	},
	Bits = (function()
		local bits = {}
		local rng = Random.new(59)
		for k = 0, 7 do
			local x = -2.4 + k * 0.68 + rng:NextNumber(-0.1, 0.1)
			local len = rng:NextNumber(0.8, 2.8)
			local color = k % 3 == 0 and "IceDeep" or "Ice"
			table.insert(bits, { Name = "Icicle", Group = "Icicles", Color = color, C = { x, 3.5 - len / 2, -0.4 }, S = { 0.3, len, 0.3 } })
		end
		return bits
	end)(),
}

-- a frozen waterfall down a cliff face into an icy pool (WALL studs tall)
specs.Prop_IceFall = {
	Voxel = 0.8,
	StudScale = 1.6,
	StudFaces = "Top",
	Length = WALL,
	Palette = palette({ "Ice", "IceDeep", "Snow", "SnowShade", "PondIce" }),
	Shapes = {
		{ Group = "Fall", Color = "Ice", Kind = "Box", C = { 0, WALL / 2, -0.5 }, S = { 3.8, WALL, 1.1 } },
		{ Group = "Fall", Color = "IceDeep", Kind = "Box", C = { -0.8, WALL / 2, -1.0 }, S = { 0.9, WALL, 0.3 }, Paint = true },
		{ Group = "Fall", Color = "Snow", Kind = "Box", C = { 1.0, WALL / 2, -1.0 }, S = { 0.6, WALL, 0.3 }, Paint = true },
		{ Group = "Fall", Color = "Ice", Kind = "Box", C = { 0, WALL * 0.3, -1.1 }, S = { 4.6, 1.6, 1.2 } },
		{ Group = "Fall", Color = "Ice", Kind = "Box", C = { 0, WALL * 0.62, -1.1 }, S = { 4.4, 1.4, 1.2 } },
		{ Group = "Fall", Color = "Snow", Kind = "Box", C = { 0, WALL - 0.5, -0.9 }, S = { 5.8, 1.0, 2.0 } },
		{ Group = "Fall", Color = "PondIce", Kind = "Ellipsoid", C = { 0, 0.15, -2.1 }, R = { 3.1, 0.45, 2.2 } },
		{ Group = "Fall", Color = "Snow", Kind = "Ellipsoid", C = { 3.1, 0.35, -2.2 }, R = { 1.0, 0.6, 0.9 } },
		{ Group = "Fall", Color = "SnowShade", Kind = "Ellipsoid", C = { -3.0, 0.3, -2.4 }, R = { 0.9, 0.55, 0.85 } },
		{ Group = "Fall", Color = "Snow", Kind = "Ellipsoid", C = { 0.7, 0.3, -4.1 }, R = { 0.9, 0.5, 0.6 } },
	},
	Fx = { { Kind = "Sparkle", At = { 0, WALL / 2, -1.5 }, Area = { 3, WALL * 0.8, 1 }, Rate = 4 } },
}

-- NEST > signpost: wooden post and board with snow on top, standing in a snow drift
specs.Prop_NestSignFrost = {
	Voxel = 0.25,
	StudScale = 1.0,
	StudFaces = "Top",
	Palette = { Post = "5A3E2B", Board = "8B5A2B", Snow = "FFFFFF", Ice = "A8DEFF" },
	Shapes = {
		{ Group = "Sign", Color = "Post", Kind = "Box", C = { 0, 2.0, 0 }, S = { 0.5, 4.0, 0.5 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 0.25, 3.3, -0.3 }, S = { 3.5, 1.0, 0.25 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 2.15, 3.3, -0.3 }, S = { 0.5, 0.75, 0.25 } },
		{ Group = "Sign", Color = "Board", Kind = "Box", C = { 2.4, 3.3, -0.3 }, S = { 0.25, 0.5, 0.25 } },
		{ Group = "Sign", Color = "Snow", Kind = "Box", C = { 0.3, 3.92, -0.3 }, S = { 3.7, 0.25, 0.4 } },
		{ Group = "Sign", Color = "Snow", Kind = "Box", C = { 0, 4.12, 0 }, S = { 0.6, 0.25, 0.6 } },
		{ Group = "Sign", Color = "Snow", Kind = "Ellipsoid", C = { 0, 0.3, 0 }, R = { 1.0, 0.45, 1.0 } },
		{ Group = "Sign", Color = "Ice", Kind = "Box", C = { 0.55, 0.7, -0.3 }, S = { 0.25, 0.4, 0.25 } },
	},
	Board = { C = { 0.25, 3.3, -0.3 } },
}

-- ---------- lane dressing (Tools.BiomeArtBuilder.DressLane) ----------
-- Counts are for a 120 x 80 biome and scale with the biome's floor area.
specs.Dress_FrostfangPeaks = {
	Sign = "NestSignFrost",
	Trail = { "D4E6F3", "C3DBEC" }, -- packed snow path
	TrailPebbles = { "FFFFFF", "E6F3FC", "CFE6F7" },
	Trim = { Rocks = { "9FB8D2", "8AA6C4", "B4C9DD" }, Caps = { "FFFFFF", "F2F8FF" }, CapChance = 0.75 },
	Edge = { Picks = { { "SnowPine", 7, true }, { "IceSpire", 3, true } }, Every = { 16, 24 }, Inset = 6.5, Scale = { 0.9, 1.25 }, Radius = 5 },
	Bands = { Count = 14, Picks = { { "IceRock", 3, true }, { "IceCrystal", 3, false }, { "SnowMound", 3, false }, { "FrozenPond", 2, false }, { "Snowman", 1, true } }, Scale = { 0.85, 1.25 }, Radius = 3.5 },
	Small = { Count = 20, Picks = { { "FrostBush", 3 }, { "IceCrystal", 2, 0.45, 0.6 }, { "SnowMound", 1, 0.35, 0.5 } }, Scale = { 0.8, 1.2 } },
	Walls = {
		{ Name = "IceFall", Mode = "Floor", Every = { 45, 65 } },
		{ Name = "Icicles", Mode = "Hang", Every = { 9, 14 } },
	},
}

return specs
