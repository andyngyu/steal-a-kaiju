-- Brick-built kaiju designs for KaijuBuilder. Studs; model faces -Z; feet at y = 0; x = 0 is the centre line.
-- Shapes: Ellipsoid {C, R}, Box {C, S, Rot?}, Capsule {A, B, RA, RB} (tapered). Flags: Mirror (also build the -X copy,
-- swapping L/R in the group name), Paint (recolour existing bricks only), Carve (remove bricks).
-- Details: flat face pieces placed on the front surface: {Name?, Group, Color, X, Y, W, H, D?, Offset?, Tilt?, Mirror?}.
-- Bits: exact small parts placed as given: {Name?, Group, Color, C, S, Rot?, Mirror?}.
-- Palette entries: "RRGGBB" or { "RRGGBB", Neon = true }.
local specs = {}

-- Pebble Plains / Common / lizard on two legs: chunky moss-green baby with a pebble-covered back.
specs.Pebblesaur = {
	Voxel = 0.4,
	Palette = {
		Body = "7DC24B",
		BodyDark = "5A9E36",
		Belly = "FFE6A8",
		BellyLine = "F0CC80",
		Rock1 = "B7B9C4",
		Rock2 = "8E91A0",
		Rock3 = "D9DBE3",
		Claw = "FFF4D6",
		White = "FFFFFF",
		Ink = "1A1033",
		Mouth = "4A2A3A",
		Blush = "FF9DBB",
	},
	Joints = {
		Head = { 0, 2.3, -0.2 },
		LegL = { 0.6, 0.95, 0.15 },
		LegR = { -0.6, 0.95, 0.15 },
		ArmL = { 0.95, 1.75, -0.25 },
		ArmR = { -0.95, 1.75, -0.25 },
		Tail = { 0, 1.0, 0.8 },
	},
	Shapes = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.45, 0.15 }, R = { 1.05, 1.05, 0.95 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.3, -0.45 }, R = { 0.8, 0.85, 0.5 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", C = { 0, 1.0, -0.8 }, S = { 2, 0.38, 0.8 }, Paint = true },
		-- head + snout
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.95, -0.25 }, R = { 1.1, 0.95, 0.95 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.55, -0.95 }, R = { 0.8, 0.45, 0.55 } },
		{ Group = "Head", Color = "Belly", Kind = "Box", C = { 0, 2.3, -0.95 }, S = { 1.3, 0.3, 1.0 } },
		-- legs, feet, toes
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.6, 0.95, 0.15 }, B = { 0.62, 0.4, 0 }, RA = 0.48, RB = 0.42, Mirror = true },
		{ Group = "LegL", Color = "BodyDark", Kind = "Box", C = { 0.62, 0.2, -0.2 }, S = { 1.0, 0.4, 1.2 }, Mirror = true },
		-- little arms with claws
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 0.95, 1.75, -0.25 }, B = { 1.05, 1.35, -0.7 }, R = 0.28, Mirror = true },
		{ Group = "ArmL", Color = "Claw", Kind = "Box", C = { 1.05, 1.25, -0.95 }, S = { 0.45, 0.3, 0.3 }, Mirror = true },
		-- tail curling up at the tip
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.0, 0.8 }, B = { 0, 0.65, 1.7 }, RA = 0.55, RB = 0.42 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.65, 1.7 }, B = { 0, 0.6, 2.45 }, RA = 0.42, RB = 0.26 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 2.45 }, B = { 0, 0.95, 2.8 }, RA = 0.26, RB = 0.18 },
		-- pebbles on the back, head and tail
		{ Group = "Body", Color = "Rock1", Kind = "Ellipsoid", C = { 0.35, 2.05, 0.85 }, R = { 0.42, 0.36, 0.32 } },
		{ Group = "Body", Color = "Rock2", Kind = "Ellipsoid", C = { -0.4, 1.7, 0.95 }, R = { 0.42, 0.38, 0.32 } },
		{ Group = "Body", Color = "Rock3", Kind = "Ellipsoid", C = { 0.3, 1.25, 1.0 }, R = { 0.36, 0.3, 0.3 } },
		{ Group = "Body", Color = "Rock3", Kind = "Ellipsoid", C = { -0.15, 2.4, 0.65 }, R = { 0.36, 0.3, 0.3 } },
		{ Group = "Head", Color = "Rock2", Kind = "Ellipsoid", C = { 0.3, 3.8, -0.05 }, R = { 0.36, 0.26, 0.36 } },
		{ Group = "Head", Color = "Rock1", Kind = "Ellipsoid", C = { -0.35, 3.72, 0.15 }, R = { 0.32, 0.24, 0.32 } },
		{ Group = "Tail", Color = "Rock1", Kind = "Ellipsoid", C = { 0, 1.2, 1.55 }, R = { 0.32, 0.26, 0.32 } },
	},
	Details = {
		{ Name = "Eye", Group = "Head", Color = "White", X = 0.44, Y = 3.15, W = 0.8, H = 0.8, D = 0.12, Mirror = true },
		{ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.38, Y = 3.08, W = 0.44, H = 0.56, D = 0.16, Mirror = true },
		{ Name = "Glint", Group = "Head", Color = "White", X = 0.3, Y = 3.24, W = 0.16, H = 0.16, D = 0.2, Mirror = true },
		{ Name = "Blush", Group = "Head", Color = "Blush", X = 0.82, Y = 2.75, W = 0.36, H = 0.2, D = 0.1, Mirror = true },
		{ Name = "Nostril", Group = "Head", Color = "Ink", X = 0.2, Y = 2.7, W = 0.12, H = 0.12, D = 0.1, Mirror = true },
		{ Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.46, W = 0.72, H = 0.12, D = 0.07 },
		{ Name = "Tooth", Group = "Head", Color = "White", X = 0.2, Y = 2.35, W = 0.18, H = 0.2, D = 0.12 },
	},
	Bits = {
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.32, 0.13, -0.86 }, S = { 0.22, 0.26, 0.26 }, Mirror = true },
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.62, 0.13, -0.88 }, S = { 0.22, 0.26, 0.28 }, Mirror = true },
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.92, 0.13, -0.86 }, S = { 0.22, 0.26, 0.26 }, Mirror = true },
	},
}

-- Pebble Plains / Epic / lizard: the hero. Green rex with a big head, long snout, small fangs and glowing purple plates.
specs.Rumblerex = {
	Voxel = 0.4,
	Palette = {
		Body = "4DBB45",
		Dark = "2E8B3E",
		Belly = "FFEBC2",
		BellyLine = "EFCF95",
		Plate = { "6A22D8", Neon = true },
		Claw = "FFF4D6",
		White = "FFFFFF",
		Ink = "1A1033",
		Mouth = "3B1A33",
		Brow = "1F5E2B",
	},
	Joints = {
		Head = { 0, 2.7, -0.3 },
		LegL = { 0.75, 1.0, 0.25 },
		LegR = { -0.75, 1.0, 0.25 },
		ArmL = { 1.15, 2.05, -0.25 },
		ArmR = { -1.15, 2.05, -0.25 },
		Tail = { 0, 1.1, 1.0 },
	},
	Shapes = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.7, 0.25 }, R = { 1.25, 1.25, 1.1 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.55, -0.4 }, R = { 0.9, 1.0, 0.6 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", C = { 0, 1.0, -0.9 }, S = { 2.2, 0.38, 1.0 }, Paint = true },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", C = { 0, 1.8, -0.9 }, S = { 2.2, 0.38, 1.0 }, Paint = true },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", C = { 1.0, 2.0, 0.55 }, R = { 0.45, 0.42, 0.45 }, Paint = true, Mirror = true },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", C = { 0.9, 1.2, 0.85 }, R = { 0.35, 0.32, 0.35 }, Paint = true, Mirror = true },
		-- head: rounded skull, boxy rex snout, cream lower jaw (snout kept below y 3.35 so the eyes sit on the skull)
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.55, -0.35 }, R = { 1.15, 0.95, 1.0 } },
		{ Group = "Head", Color = "Body", Kind = "Box", C = { 0, 3.0, -1.4 }, S = { 1.35, 0.7, 1.4 } },
		{ Group = "Head", Color = "Belly", Kind = "Box", C = { 0, 2.6, -1.3 }, S = { 1.2, 0.4, 1.2 } },
		{ Group = "Head", Color = "Dark", Kind = "Ellipsoid", C = { 0.65, 4.05, 0.1 }, R = { 0.36, 0.3, 0.36 }, Paint = true, Mirror = true },
		-- legs (chunky thighs), feet
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.78, 1.05, 0.25 }, B = { 0.8, 0.45, 0.05 }, RA = 0.64, RB = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Dark", Kind = "Box", C = { 0.8, 0.2, -0.2 }, S = { 1.2, 0.4, 1.4 }, Mirror = true },
		-- arms with claws
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 1.15, 2.05, -0.25 }, B = { 1.25, 1.6, -0.8 }, R = 0.32, Mirror = true },
		{ Group = "ArmL", Color = "Claw", Kind = "Box", C = { 1.25, 1.45, -1.1 }, S = { 0.5, 0.34, 0.3 }, Mirror = true },
		-- tail
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.1, 1.0 }, B = { 0, 0.7, 2.1 }, RA = 0.7, RB = 0.5 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.7, 2.1 }, B = { 0, 0.6, 3.0 }, RA = 0.5, RB = 0.3 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 3.0 }, B = { 0, 0.9, 3.4 }, RA = 0.3, RB = 0.2 },
		-- glowing dorsal plates: separate stepped spikes on the centre line, one brick thick, a brick of gap between each
		{ Group = "Head", Color = "Plate", Kind = "Box", C = { 0, 4.45, -0.2 }, S = { 0.3, 0.8, 0.8 } },
		{ Group = "Head", Color = "Plate", Kind = "Box", C = { 0, 5.0, -0.0 }, S = { 0.3, 0.4, 0.4 } },
		{ Group = "Body", Color = "Plate", Kind = "Box", C = { 0, 2.95, 1.0 }, S = { 0.3, 1.1, 0.8 } },
		{ Group = "Body", Color = "Plate", Kind = "Box", C = { 0, 3.7, 1.2 }, S = { 0.3, 0.45, 0.4 } },
		{ Group = "Tail", Color = "Plate", Kind = "Box", C = { 0, 1.55, 2.2 }, S = { 0.3, 1.0, 0.8 } },
		{ Group = "Tail", Color = "Plate", Kind = "Box", C = { 0, 2.2, 2.4 }, S = { 0.3, 0.4, 0.4 } },
		{ Group = "Tail", Color = "Plate", Kind = "Box", C = { 0, 1.2, 3.2 }, S = { 0.3, 0.7, 0.4 } },
	},
	Details = {
		{ Name = "Eye", Group = "Head", Color = "White", X = 0.52, Y = 3.8, W = 0.78, H = 0.72, D = 0.12, Mirror = true },
		{ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.44, Y = 3.74, W = 0.38, H = 0.5, D = 0.16, Mirror = true },
		{ Name = "Glint", Group = "Head", Color = "White", X = 0.36, Y = 3.9, W = 0.15, H = 0.15, D = 0.2, Mirror = true },
		{ Name = "Brow", Group = "Head", Color = "Brow", X = 0.52, Y = 4.27, W = 0.85, H = 0.18, D = 0.16, Tilt = 12, Mirror = true },
		{ Name = "Nostril", Group = "Head", Color = "Ink", X = 0.3, Y = 3.2, W = 0.14, H = 0.14, D = 0.1, Mirror = true },
		{ Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.95, H = 0.12, D = 0.07 },
		{ Name = "Fang", Group = "Head", Color = "White", X = 0.4, Y = 2.68, W = 0.2, H = 0.26, D = 0.12, Mirror = true },
	},
	Bits = {
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.45, 0.14, -0.96 }, S = { 0.26, 0.28, 0.3 }, Mirror = true },
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.8, 0.14, -0.98 }, S = { 0.26, 0.28, 0.32 }, Mirror = true },
		{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.15, 0.14, -0.96 }, S = { 0.26, 0.28, 0.3 }, Mirror = true },
	},
}

return specs
