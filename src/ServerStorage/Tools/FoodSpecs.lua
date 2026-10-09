-- Brick-built kaiju food for the Food stall and the feeding effect (same format as KaijuSpecs, built by
-- MarketBuilder.BuildFood into ReplicatedStorage.Assets.Food). Studs; front faces -Z; bottom at y = 0; about 1.2 studs big.
local specs = {}

specs.Kibble = {
	Voxel = 0.15,
	Palette = {
		Bag = "D9B27A",
		BagDark = "B88A4E",
		Kib1 = "8B4A2B",
		Kib2 = "C2603A",
		Kib3 = "6E3A20",
		Label = "4DBB45",
		White = "FFFFFF",
	},
	Shapes = {
		{ Group = "Body", Color = "Bag", Kind = "Box", C = { 0, 0.5, 0 }, S = { 0.9, 1.0, 0.62 } },
		{ Group = "Body", Color = "BagDark", Kind = "Box", C = { 0, 1.06, 0 }, S = { 0.96, 0.14, 0.68 } },
		{ Group = "Body", Color = "BagDark", Kind = "Box", C = { 0, 0.08, 0 }, S = { 1, 0.16, 0.7 }, Paint = true },
		{ Group = "Body", Color = "Label", Kind = "Box", C = { 0, 0.55, -0.3 }, S = { 0.62, 0.5, 0.1 }, Paint = true },
		{ Group = "Body", Color = "Kib1", Kind = "Ellipsoid", C = { -0.2, 1.2, 0.05 }, R = { 0.17, 0.11, 0.17 } },
		{ Group = "Body", Color = "Kib2", Kind = "Ellipsoid", C = { 0.15, 1.22, -0.08 }, R = { 0.16, 0.11, 0.16 } },
		{ Group = "Body", Color = "Kib3", Kind = "Ellipsoid", C = { 0.02, 1.32, 0.1 }, R = { 0.14, 0.1, 0.14 } },
		{ Group = "Body", Color = "Kib1", Kind = "Ellipsoid", C = { 0.27, 1.19, 0.15 }, R = { 0.12, 0.09, 0.12 } },
	},
	Details = {
		{ Name = "Paw", Group = "Body", Color = "White", X = 0, Y = 0.5, W = 0.22, H = 0.17, D = 0.05 },
		{ Name = "Toe", Group = "Body", Color = "White", X = -0.13, Y = 0.66, W = 0.08, H = 0.08, D = 0.05 },
		{ Name = "Toe", Group = "Body", Color = "White", X = 0, Y = 0.71, W = 0.08, H = 0.08, D = 0.05 },
		{ Name = "Toe", Group = "Body", Color = "White", X = 0.13, Y = 0.66, W = 0.08, H = 0.08, D = 0.05 },
	},
}

specs.Drumstick = {
	Voxel = 0.15,
	Palette = {
		Meat = "B5532B",
		MeatLight = "D9743F",
		MeatDark = "8E3B1E",
		Bone = "FFF1D6",
		BoneShade = "E8D9BC",
	},
	Shapes = {
		{ Group = "Body", Color = "Meat", Kind = "Ellipsoid", C = { -0.12, 0.62, 0 }, R = { 0.44, 0.48, 0.4 } },
		{ Group = "Body", Color = "MeatLight", Kind = "Ellipsoid", C = { -0.25, 0.85, -0.2 }, R = { 0.26, 0.2, 0.26 }, Paint = true },
		{ Group = "Body", Color = "MeatDark", Kind = "Box", C = { -0.12, 0.22, 0 }, S = { 1, 0.2, 1 }, Paint = true },
	},
	Bits = {
		{ Name = "Bone", Group = "Body", Color = "Bone", C = { 0.38, 0.32, 0 }, S = { 0.6, 0.17, 0.17 }, Rot = { 0, 0, -28 } },
		{ Name = "Knob", Group = "Body", Color = "Bone", C = { 0.66, 0.2, 0.08 }, S = { 0.2, 0.2, 0.2 } },
		{ Name = "Knob", Group = "Body", Color = "BoneShade", C = { 0.68, 0.14, -0.08 }, S = { 0.19, 0.19, 0.19 } },
	},
}

specs.LavaPepper = {
	Voxel = 0.15,
	Palette = {
		Pepper = "FF3B1F",
		Hot = { "FF8A1F", Neon = true },
		Shine = "FF9A8A",
		Stem = "3FAE38",
		StemDark = "2E8A2A",
	},
	Shapes = {
		{ Group = "Body", Color = "Pepper", Kind = "Capsule", A = { 0, 0.95, 0 }, B = { 0.05, 0.45, 0 }, RA = 0.28, RB = 0.22 },
		{ Group = "Body", Color = "Pepper", Kind = "Capsule", A = { 0.05, 0.45, 0 }, B = { 0.28, 0.15, 0 }, RA = 0.22, RB = 0.1 },
		{ Group = "Body", Color = "Hot", Kind = "Ellipsoid", C = { 0.28, 0.15, 0 }, R = { 0.2, 0.2, 0.2 }, Paint = true },
		{ Group = "Body", Color = "Shine", Kind = "Box", C = { -0.12, 0.85, -0.22 }, S = { 0.12, 0.3, 0.12 }, Paint = true },
		{ Group = "Body", Color = "Stem", Kind = "Ellipsoid", C = { 0, 1.17, 0 }, R = { 0.23, 0.08, 0.23 } },
		{ Group = "Body", Color = "StemDark", Kind = "Box", C = { 0, 1.3, 0 }, S = { 0.15, 0.22, 0.15 } },
	},
	Bits = {
		{ Name = "Leaf", Group = "Body", Color = "Stem", C = { 0.14, 1.32, 0 }, S = { 0.24, 0.05, 0.13 }, Rot = { 0, 0, 22 } },
	},
}

specs.FrostFish = {
	Voxel = 0.15,
	Palette = {
		Fish = "6FC8FF",
		Belly = "D6F6FF",
		Fin = "3F8FEA",
		Frost = "F4FBFF",
		White = "FFFFFF",
		Ink = "1A1033",
	},
	Shapes = {
		{ Group = "Body", Color = "Fish", Kind = "Ellipsoid", C = { -0.05, 0.36, 0 }, R = { 0.52, 0.32, 0.21 } },
		{ Group = "Body", Color = "Belly", Kind = "Box", C = { -0.05, 0.14, 0 }, S = { 1.2, 0.15, 0.6 }, Paint = true },
		{ Group = "Body", Color = "Frost", Kind = "Ellipsoid", C = { -0.05, 0.62, 0 }, R = { 0.36, 0.08, 0.26 }, Paint = true },
	},
	Details = {
		{ Name = "Eye", Group = "Body", Color = "White", X = -0.33, Y = 0.43, W = 0.13, H = 0.13, D = 0.05 },
		{ Name = "Pupil", Group = "Body", Color = "Ink", X = -0.35, Y = 0.42, W = 0.07, H = 0.08, D = 0.07 },
		{ Name = "Mouth", Group = "Body", Color = "Ink", X = -0.5, Y = 0.31, W = 0.07, H = 0.03, D = 0.05 },
	},
	Bits = {
		{ Name = "Tail", Group = "Body", Color = "Fin", C = { 0.56, 0.48, 0 }, S = { 0.13, 0.32, 0.06 }, Rot = { 0, 0, 35 } },
		{ Name = "Tail", Group = "Body", Color = "Fin", C = { 0.56, 0.24, 0 }, S = { 0.13, 0.32, 0.06 }, Rot = { 0, 0, -35 } },
		{ Name = "Dorsal", Group = "Body", Color = "Fin", C = { -0.05, 0.72, 0 }, S = { 0.32, 0.13, 0.05 } },
	},
}

specs.GoldenSteak = {
	Voxel = 0.15,
	Palette = {
		Fat = "FFF0B8",
		Steak = "FFC93C",
		SteakDark = "E09A2A",
		Bone = "FFFFFF",
		Shine = { "FFF7C2", Neon = true },
	},
	Shapes = {
		{ Group = "Body", Color = "Fat", Kind = "Ellipsoid", C = { 0, 0.62, 0 }, R = { 0.62, 0.56, 0.15 } },
		{ Group = "Body", Color = "Steak", Kind = "Ellipsoid", C = { 0, 0.62, 0 }, R = { 0.5, 0.46, 0.16 } },
		{ Group = "Body", Color = "SteakDark", Kind = "Ellipsoid", C = { -0.22, 0.45, 0 }, R = { 0.18, 0.14, 0.2 }, Paint = true },
	},
	Details = {
		{ Name = "Bone", Group = "Body", Color = "Bone", X = 0.08, Y = 0.6, W = 0.1, H = 0.52, D = 0.06 },
		{ Name = "Bone", Group = "Body", Color = "Bone", X = 0.08, Y = 0.84, W = 0.4, H = 0.09, D = 0.06 },
		{ Name = "Shine", Group = "Body", Color = "Shine", X = -0.26, Y = 0.82, W = 0.12, H = 0.12, D = 0.07 },
	},
}

specs.CosmicCandy = {
	Voxel = 0.15,
	Palette = {
		Candy = "B266FF",
		Swirl = { "FF5ABF", Neon = true },
		Swirl2 = { "4DC3FF", Neon = true },
		Wrap = "FF9DE0",
		WrapDark = "E85AC0",
		Star = { "FFF04D", Neon = true },
	},
	Shapes = {
		{ Group = "Body", Color = "Candy", Kind = "Ellipsoid", C = { 0, 0.5, 0 }, R = { 0.42, 0.42, 0.38 } },
		{ Group = "Body", Color = "Swirl", Kind = "Box", C = { 0, 0.5, 0 }, S = { 0.15, 1.1, 0.9 }, Rot = { 0, 0, 35 }, Paint = true },
		{ Group = "Body", Color = "Swirl2", Kind = "Box", C = { 0.24, 0.5, 0 }, S = { 0.15, 1.1, 0.9 }, Rot = { 0, 0, 35 }, Paint = true },
		{ Group = "Body", Color = "Swirl2", Kind = "Box", C = { -0.24, 0.5, 0 }, S = { 0.15, 1.1, 0.9 }, Rot = { 0, 0, 35 }, Paint = true },
		{ Group = "Body", Color = "Wrap", Kind = "Box", C = { 0.5, 0.5, 0 }, S = { 0.2, 0.36, 0.3 }, Mirror = true },
		{ Group = "Body", Color = "WrapDark", Kind = "Box", C = { 0.68, 0.5, 0 }, S = { 0.16, 0.62, 0.46 }, Mirror = true },
	},
	Bits = {
		{ Name = "Star", Group = "Body", Color = "Star", C = { 0.16, 1.06, 0 }, S = { 0.15, 0.15, 0.05 }, Rot = { 0, 0, 45 } },
		{ Name = "Star", Group = "Body", Color = "Star", C = { -0.3, 0.99, 0 }, S = { 0.1, 0.1, 0.04 }, Rot = { 0, 0, 45 } },
	},
}

return specs
