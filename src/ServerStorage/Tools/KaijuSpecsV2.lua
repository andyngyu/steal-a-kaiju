-- Redesigned kaiju (quality pass, 2026-10): same format, joints, gaits and group names as Tools.KaijuSpecs, built at
-- 0.2-stud voxels (twice as fine) with the stud texture kept as a voxel grid, ambient-occlusion creases (AO) and
-- skin-only merging (SkinMerge). A species here replaces its Tools.KaijuSpecs entry once approved.
local specs = {}

local function pebble(shapes, group, c, r, base, light, dark)
	table.insert(shapes, { Group = group, Color = base, Kind = "Ellipsoid", C = c, R = { r, r * 0.78, r } })
	table.insert(shapes, { Group = group, Color = light, Kind = "Ellipsoid", Paint = true, C = { c[1], c[2] + r * 0.45, c[3] }, R = { r * 0.82, r * 0.42, r * 0.82 } })
	if dark then
		table.insert(shapes, { Group = group, Color = dark, Kind = "Ellipsoid", Paint = true, C = { c[1], c[2] - r * 0.55, c[3] }, R = { r * 1.05, r * 0.32, r * 1.05 } })
	end
end

-- big cartoon eyes as face details: white (set a little into the face), coloured iris, pupil, a big and a small glint
local function eyes(t, group, x, y, w, h, iris)
	table.insert(t, { Name = "Eye", Group = group, Color = "White", X = x, Y = y, W = w, H = h, D = 0.12, Sink = 0.04, Mirror = true })
	table.insert(t, { Name = "Iris", Group = group, Color = iris, X = x - w * 0.05, Y = y - h * 0.06, W = w * 0.72, H = h * 0.76, D = 0.14, Mirror = true })
	table.insert(t, { Name = "Pupil", Group = group, Color = "Ink", X = x - w * 0.06, Y = y - h * 0.08, W = w * 0.5, H = h * 0.57, D = 0.16, Mirror = true })
	table.insert(t, { Name = "Glint", Group = group, Color = "White", X = x - w * 0.19, Y = y + h * 0.11, W = w * 0.22, H = w * 0.22, D = 0.2, Mirror = true })
	table.insert(t, { Name = "Glint", Group = group, Color = "White", X = x + w * 0.05, Y = y - h * 0.25, W = w * 0.1, H = w * 0.1, D = 0.2, Mirror = true })
	return t
end

-- the shared build settings of the redesigned kaiju
local function fine(spec)
	spec.Voxel = 0.2
	spec.StudScale = 0.4
	spec.SkinMerge = true
	spec.AO = true
	return spec
end

-- Euler angles (degrees, for a shape's Rot) that stand a shape's +Y along `up`, spun `spin` degrees about it
local function upRot(up, spin)
	up = up.Unit
	local ref = math.abs(up.Z) < 0.9 and Vector3.zAxis or Vector3.xAxis
	local right = up:Cross(ref).Unit
	local back = right:Cross(up)
	local cf = CFrame.fromMatrix(Vector3.zero, right, up, back) * CFrame.Angles(0, math.rad(spin or 0), 0)
	local x, y, z = cf:ToOrientation()
	return { math.deg(x), math.deg(y), math.deg(z) }
end

-- a voxel crystal growing from `base` along `dir`: a square column with a pointed (lighter) tip
local function crystal(shapes, group, base, dir, w, h, color, tip)
	local up = dir.Unit
	table.insert(shapes, { Group = group, Color = color, Kind = "Box", C = base + up * (h * 0.35), S = { w, h * 0.7, w }, Rot = upRot(up, 45) })
	table.insert(shapes, { Group = group, Color = tip or color, Kind = "Capsule", A = base + up * (h * 0.66), B = base + up * h, RA = w * 0.62, RB = 0.04 })
end

-- a diamond dorsal plate on the centre line, pointing along `dir` (in the Y-Z plane), with a brighter tip
local function plate(shapes, group, base, dir, size, deep, tip)
	dir = dir.Unit
	local rot = { math.deg(math.atan2(dir.Z, dir.Y)) - 45, 0, 0 }
	table.insert(shapes, { Group = group, Color = deep, Kind = "Box", C = base + dir * (size * 0.25), S = { 0.4, size, size }, Rot = rot })
	table.insert(shapes, { Group = group, Color = tip, Kind = "Box", C = base + dir * (size * 0.64), S = { 0.42, size * 0.45, size * 0.45 }, Rot = rot })
end

-- a glowing crack cut into a top surface: surf(x, z) gives the surface height; pts = { {x, z}, ... }. Carved `w` deep,
-- lined with `glow`, `core` along the bottom.
local function crack(shapes, group, surf, pts, w, glow, core)
	local segs = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local m = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }
		table.insert(segs, { a, m })
		table.insert(segs, { m, b })
	end
	local function at(p, dy)
		return Vector3.new(p[1], surf(p[1], p[2]) + dy, p[2])
	end
	for _, sg in segs do
		table.insert(shapes, { Group = group, Kind = "Capsule", Carve = true, A = at(sg[1], 0.06), B = at(sg[2], 0.06), R = w })
	end
	for _, sg in segs do
		table.insert(shapes, { Group = group, Color = glow, Kind = "Capsule", Paint = true, A = at(sg[1], -0.02), B = at(sg[2], -0.02), R = w + 0.14 })
		table.insert(shapes, { Group = group, Color = core, Kind = "Capsule", Paint = true, A = at(sg[1], -w), B = at(sg[2], -w), R = 0.13 })
	end
end

-- top surface of an ellipsoid (centre c, radii r) at (x, z)
local function dome(c, r)
	return function(x, z)
		return c[2] + r[2] * math.sqrt(math.max(0, 1 - ((x - c[1]) / r[1]) ^ 2 - ((z - c[3]) / r[3]) ^ 2))
	end
end

-- a flame tongue rising from `base`: `lean` tips it sideways, hot towards the tip
local function flame(shapes, group, base, h, r, lean, cool, hot)
	local mid = base + Vector3.new(lean.X * 0.4, h * 0.55, lean.Z * 0.4)
	local tip = base + Vector3.new(lean.X, h, lean.Z)
	table.insert(shapes, { Group = group, Color = cool, Kind = "Capsule", A = base, B = mid, RA = r, RB = r * 0.62 })
	table.insert(shapes, { Group = group, Color = hot, Kind = "Capsule", A = mid, B = tip, RA = r * 0.62, RB = 0.04 })
end

-- a glowing crack cut into the surface of an ellipsoid (centre c, radii r) through points pts (projected onto it)
local function crackOn(shapes, group, c, r, pts, w, glow, core)
	c, r = Vector3.new(c[1], c[2], c[3]), Vector3.new(r[1], r[2], r[3])
	local function onSurface(p, out)
		local d = p - c
		local k = (d / r).Magnitude
		local q = c + d / k
		return q + (q - c).Unit * out
	end
	local list = {}
	for i, p in pts do
		list[i] = Vector3.new(p[1], p[2], p[3])
	end
	local segs = {}
	for i = 1, #list - 1 do
		local m = (list[i] + list[i + 1]) / 2
		table.insert(segs, { list[i], m })
		table.insert(segs, { m, list[i + 1] })
	end
	for _, sg in segs do
		table.insert(shapes, { Group = group, Kind = "Capsule", Carve = true, A = onSurface(sg[1], 0.06), B = onSurface(sg[2], 0.06), R = w })
	end
	for _, sg in segs do
		table.insert(shapes, { Group = group, Color = glow, Kind = "Capsule", Paint = true, A = onSurface(sg[1], -0.02), B = onSurface(sg[2], -0.02), R = w + 0.09 })
		table.insert(shapes, { Group = group, Color = core, Kind = "Capsule", Paint = true, A = onSurface(sg[1], -w), B = onSurface(sg[2], -w), R = 0.13 })
	end
end

-- Pebble Plains / Common / lizard on two legs: chunky moss-green baby with a ridge of pebbles from crown to tail tip.
do
	local S = {
		-- body: round, darker down the back, segmented cream belly
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.45, 0.15 }, R = { 1.05, 1.05, 0.95 } },
		{ Group = "Body", Color = "BodyDark", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, 0.95 }, R = { 0.95, 1.1, 0.62 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.3, -0.47 }, R = { 0.78, 0.86, 0.5 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.7, -0.85 }, S = { 2, 0.2, 0.8 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.1, -0.85 }, S = { 2, 0.2, 0.8 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.5, -0.85 }, S = { 2, 0.2, 0.8 } },
		{ Group = "Body", Color = "BodyDark", Kind = "Ellipsoid", Paint = true, C = { 1.0, 1.25, 0.3 }, R = { 0.2, 0.2, 0.2 }, Mirror = true },
		{ Group = "Body", Color = "BodyDark", Kind = "Ellipsoid", Paint = true, C = { 0.95, 1.85, 0.1 }, R = { 0.16, 0.16, 0.16 }, Mirror = true },
		-- head: big round skull, chubby cheeks, rounded snout, lighter crown, cream jaw
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.95, -0.25 }, R = { 1.1, 0.95, 0.95 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.52, -0.95 }, R = { 0.78, 0.44, 0.55 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.72, 2.62, -0.58 }, R = { 0.42, 0.36, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "BodyLight", Kind = "Ellipsoid", Paint = true, C = { 0, 3.72, -0.35 }, R = { 0.85, 0.32, 0.75 } },
		{ Group = "Head", Color = "BodyDark", Kind = "Ellipsoid", Paint = true, C = { 0, 3.2, 0.6 }, R = { 0.9, 0.7, 0.42 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Ellipsoid", C = { 0, 2.3, -0.9 }, R = { 0.66, 0.2, 0.56 } },
		-- legs: thick thighs, rounded darker feet
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.6, 0.95, 0.15 }, B = { 0.62, 0.42, 0 }, RA = 0.48, RB = 0.4, Mirror = true },
		{ Group = "LegL", Color = "BodyDark", Kind = "Ellipsoid", C = { 0.62, 0.2, -0.22 }, R = { 0.48, 0.22, 0.62 }, Mirror = true },
		-- little arms with paws
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 0.95, 1.75, -0.25 }, B = { 1.05, 1.38, -0.68 }, RA = 0.28, RB = 0.22, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Ellipsoid", C = { 1.06, 1.3, -0.84 }, R = { 0.24, 0.2, 0.22 }, Mirror = true },
		-- tail curling up at the tip, darker on top
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.0, 0.8 }, B = { 0, 0.65, 1.7 }, RA = 0.55, RB = 0.42 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.65, 1.7 }, B = { 0, 0.6, 2.45 }, RA = 0.42, RB = 0.26 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 2.45 }, B = { 0, 0.95, 2.82 }, RA = 0.26, RB = 0.16 },
		{ Group = "Tail", Color = "BodyDark", Kind = "Box", Paint = true, C = { 0, 1.15, 1.9 }, S = { 1.4, 0.5, 2.4 } },
	}
	-- the pebble ridge: crown, spine, tail
	for _, p in {
		{ "Head", { 0, 3.92, -0.1 }, 0.36 },
		{ "Head", { 0.4, 3.74, 0.2 }, 0.28 },
		{ "Head", { -0.38, 3.7, 0.26 }, 0.27 },
		{ "Head", { 0.05, 3.55, 0.62 }, 0.3 },
		{ "Body", { 0, 2.6, 0.82 }, 0.4 },
		{ "Body", { 0.32, 2.15, 1.02 }, 0.38 },
		{ "Body", { -0.32, 1.72, 1.08 }, 0.37 },
		{ "Body", { 0.24, 1.3, 1.1 }, 0.32 },
		{ "Body", { 0.86, 1.95, 0.62 }, 0.22 },
		{ "Body", { -0.86, 1.55, 0.7 }, 0.22 },
		{ "Tail", { 0, 1.2, 1.65 }, 0.32 },
		{ "Tail", { 0, 1.02, 2.24 }, 0.25 },
		{ "Tail", { 0, 1.08, 2.74 }, 0.18 },
	} do
		pebble(S, p[1], p[2], p[3], "Rock1", "Rock3", "Rock2")
	end
	specs.Pebblesaur = {
		Voxel = 0.2,
		StudScale = 0.4,
		SkinMerge = true,
		AO = true,
		Gait = "Biped",
		Emotes = { "Look", "Hop", "HopSpin", "Roar" },
		Palette = {
			Body = "7DC24B",
			BodyDark = "579B35",
			BodyLight = "96D262",
			Belly = "FFE6A8",
			BellyLine = "EDCB86",
			Rock1 = "A4A8B8",
			Rock2 = "777B8E",
			Rock3 = "D6D9E2",
			Claw = "FFF4D6",
			White = "FFFFFF",
			Iris = "2C6E46",
			Ink = "1A1033",
			Mouth = "4A2A3A",
			Blush = "FF9DBB",
		},
		Joints = {
			Head = { 0, 2.3, -0.2 },
			Jaw = { 0, 2.42, -0.45 },
			LegL = { 0.6, 0.95, 0.15 },
			LegR = { -0.6, 0.95, 0.15 },
			ArmL = { 0.95, 1.75, -0.25 },
			ArmR = { -0.95, 1.75, -0.25 },
			Tail = { 0, 1.0, 0.8 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = {
			{ Name = "Eye", Group = "Head", Color = "White", X = 0.44, Y = 3.15, W = 0.8, H = 0.84, D = 0.12, Sink = 0.05, Mirror = true },
			{ Name = "Iris", Group = "Head", Color = "Iris", X = 0.4, Y = 3.1, W = 0.58, H = 0.64, D = 0.14, Mirror = true },
			{ Name = "Pupil", Group = "Head", Color = "Ink", X = 0.39, Y = 3.08, W = 0.4, H = 0.48, D = 0.16, Mirror = true },
			{ Name = "Glint", Group = "Head", Color = "White", X = 0.29, Y = 3.24, W = 0.18, H = 0.18, D = 0.2, Mirror = true },
			{ Name = "Glint", Group = "Head", Color = "White", X = 0.48, Y = 2.94, W = 0.08, H = 0.08, D = 0.2, Mirror = true },
			{ Name = "Blush", Group = "Head", Color = "Blush", X = 0.84, Y = 2.74, W = 0.36, H = 0.18, D = 0.1, Mirror = true },
			{ Name = "Nostril", Group = "Head", Color = "Ink", X = 0.2, Y = 2.72, W = 0.1, H = 0.1, D = 0.1, Mirror = true },
			{ Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.46, W = 0.6, H = 0.1, D = 0.07 },
			{ Name = "Mouth", Group = "Head", Color = "Mouth", X = 0.34, Y = 2.52, W = 0.12, H = 0.1, D = 0.07, Mirror = true },
			{ Name = "Tooth", Group = "Head", Color = "White", X = 0.17, Y = 2.37, W = 0.14, H = 0.16, D = 0.12 },
		},
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.34, 0.12, -0.86 }, S = { 0.2, 0.24, 0.24 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.62, 0.12, -0.9 }, S = { 0.2, 0.24, 0.26 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.9, 0.12, -0.86 }, S = { 0.2, 0.24, 0.24 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 0.94, 1.22, -1.02 }, S = { 0.1, 0.14, 0.14 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.08, 1.2, -1.04 }, S = { 0.1, 0.14, 0.14 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.22, 1.22, -1.0 }, S = { 0.1, 0.14, 0.14 }, Mirror = true },
		},
	}
end

-- Pebble Plains / Common / four legs: lime pup-croc that is mostly mouth. Big underbite, eyes on lidded bumps, a row of
-- scutes down the back.
do
	local S = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.2, 0.35 }, R = { 0.95, 0.8, 1.15 } },
		{ Group = "Body", Color = "Belly", Kind = "Box", Paint = true, C = { 0, 0.62, 0.35 }, S = { 2.2, 0.44, 2.6 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 1.98, 0.4 }, R = { 0.7, 0.3, 1.2 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0.82, 1.45, 0.75 }, R = { 0.24, 0.22, 0.26 }, Mirror = true },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0.88, 1.15, 0.15 }, R = { 0.2, 0.18, 0.2 }, Mirror = true },
		-- head: wide skull, flat upper snout with nostril bumps, eye bumps with heavy lids, cream underbite jaw
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.75, -0.95 }, R = { 1.05, 0.8, 0.8 } },
		{ Group = "Head", Color = "Body", Kind = "Box", C = { 0, 1.6, -1.65 }, S = { 1.8, 0.5, 0.8 } },
		{ Group = "Head", Color = "Light", Kind = "Ellipsoid", Paint = true, C = { 0, 1.95, -1.55 }, R = { 0.8, 0.16, 0.6 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.3, 1.9, -1.85 }, R = { 0.14, 0.1, 0.14 }, Mirror = true },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.5, 2.45, -1.05 }, R = { 0.4, 0.4, 0.38 }, Mirror = true },
		{ Group = "Head", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0.5, 2.78, -1.0 }, R = { 0.44, 0.16, 0.42 }, Mirror = true },
		{ Group = "Jaw", Color = "Belly", Kind = "Box", C = { 0, 1.05, -1.6 }, S = { 1.7, 0.4, 1.1 } },
		{ Group = "Jaw", Color = "BellyDark", Kind = "Box", Paint = true, C = { 0, 0.9, -1.6 }, S = { 1.8, 0.2, 1.2 } },
		-- legs with rounded feet
		{ Group = "LegFL", Color = "Body", Kind = "Capsule", A = { 0.6, 0.85, -0.35 }, B = { 0.62, 0.35, -0.42 }, RA = 0.34, RB = 0.3, Mirror = true },
		{ Group = "LegFL", Color = "Dark", Kind = "Ellipsoid", C = { 0.62, 0.17, -0.55 }, R = { 0.36, 0.18, 0.44 }, Mirror = true },
		{ Group = "LegBL", Color = "Body", Kind = "Capsule", A = { 0.6, 0.85, 0.95 }, B = { 0.62, 0.35, 1.0 }, RA = 0.36, RB = 0.32, Mirror = true },
		{ Group = "LegBL", Color = "Dark", Kind = "Ellipsoid", C = { 0.62, 0.17, 0.82 }, R = { 0.36, 0.18, 0.44 }, Mirror = true },
		-- stubby tail
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.15, 1.35 }, B = { 0, 0.9, 2.0 }, RA = 0.38, RB = 0.26 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.9, 2.0 }, B = { 0, 1.15, 2.4 }, RA = 0.26, RB = 0.16 },
		{ Group = "Tail", Color = "Dark", Kind = "Box", Paint = true, C = { 0, 1.35, 1.9 }, S = { 1, 0.3, 1.4 } },
	}
	-- scutes: two rows of bumps down the back, onto the tail
	for _, z in { 0.02, 0.42, 0.82, 1.18 } do
		local y = 1.2 + 0.8 * math.sqrt(math.max(0, 1 - (0.26 / 0.95) ^ 2 - ((z - 0.35) / 1.15) ^ 2))
		table.insert(S, { Group = "Body", Color = "Scute", Kind = "Ellipsoid", C = { 0.26, y, z }, R = { 0.15, 0.13, 0.16 }, Mirror = true })
	end
	table.insert(S, { Group = "Tail", Color = "Scute", Kind = "Ellipsoid", C = { 0, 1.42, 1.62 }, R = { 0.13, 0.12, 0.15 } })
	table.insert(S, { Group = "Tail", Color = "Scute", Kind = "Ellipsoid", C = { 0, 1.18, 2.0 }, R = { 0.1, 0.1, 0.12 } })
	local D = eyes({}, "Head", 0.5, 2.45, 0.64, 0.64, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.3, Y = 1.92, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 1.32, W = 1.5, H = 0.14, D = 0.07 })
	specs.Chompling = fine({
		Gait = "Crawl",
		Emotes = { "Look", "Chomp", "Wiggle" },
		Palette = {
			Body = "8FD43F",
			Dark = "66AE2C",
			Light = "A8E35E",
			Scute = "559A26",
			Belly = "FFEBC2",
			BellyDark = "EDCF96",
			Claw = "FFF4D6",
			White = "FFFFFF",
			Iris = "E9A62E",
			Ink = "1A1033",
			Mouth = "6E1E3A",
			Blush = "FF9DBB",
		},
		Joints = {
			Head = { 0, 1.55, -0.5 },
			Jaw = { 0, 1.25, -1.05 },
			LegFL = { 0.6, 0.85, -0.35 },
			LegFR = { -0.6, 0.85, -0.35 },
			LegBL = { 0.6, 0.85, 0.95 },
			LegBR = { -0.6, 0.85, 0.95 },
			Tail = { 0, 1.15, 1.3 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Tooth", Group = "Jaw", Color = "White", C = { 0.62, 1.44, -2.1 }, S = { 0.24, 0.3, 0.16 }, Mirror = true },
			{ Name = "Tooth", Group = "Jaw", Color = "White", C = { 0.3, 1.38, -2.12 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Tooth", Group = "Head", Color = "White", C = { 0.45, 1.3, -2.02 }, S = { 0.12, 0.14, 0.12 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 0.42, 0.1, -0.96 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 0.62, 0.1, -0.98 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 0.82, 0.1, -0.96 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegBL", Color = "Claw", C = { 0.5, 0.1, 0.38 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegBL", Color = "Claw", C = { 0.74, 0.1, 0.38 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
		},
	})
end

-- Pebble Plains / Uncommon / ape: cheeky brown monkey-ape with huge knuckle-walking fists, a heart-shaped face, a
-- spiky hair tuft, a bandaged bump and a curly tail.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.85, 0.15 }, R = { 1.2, 1.1, 0.95 } },
		{ Group = "Body", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.3, 0.8 }, R = { 1.15, 0.95, 0.45 } },
		{ Group = "Body", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, -0.7 }, R = { 0.75, 0.8, 0.5 } },
		{ Group = "Body", Color = "FaceDark", Kind = "Ellipsoid", Paint = true, C = { 0, 1.15, -0.72 }, R = { 0.6, 0.18, 0.4 } },
		-- curly tail (static)
		{ Group = "Body", Color = "Fur", Kind = "Capsule", A = { 0, 1.2, 0.95 }, B = { 0, 0.95, 1.45 }, RA = 0.16, RB = 0.14 },
		{ Group = "Body", Color = "Fur", Kind = "Capsule", A = { 0, 0.95, 1.45 }, B = { 0, 1.35, 1.85 }, RA = 0.14, RB = 0.12 },
		{ Group = "Body", Color = "FurDark", Kind = "Capsule", A = { 0, 1.35, 1.85 }, B = { 0, 1.75, 1.7 }, RA = 0.12, RB = 0.1 },
		-- head: heart-shaped face, protruding muzzle, a heavy brow, darker back of the head
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 3.35, -0.15 }, R = { 1.0, 0.9, 0.9 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 3.55, 0.55 }, R = { 0.95, 0.8, 0.42 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0.3, 3.48, -0.85 }, R = { 0.42, 0.42, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0, 3.1, -0.9 }, R = { 0.64, 0.5, 0.45 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", C = { 0, 2.95, -0.98 }, R = { 0.6, 0.42, 0.42 } },
		{ Group = "Head", Color = "FaceLight", Kind = "Ellipsoid", Paint = true, C = { 0, 3.15, -1.25 }, R = { 0.42, 0.14, 0.22 } },
		{ Group = "Head", Color = "FaceDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.62, -1.0 }, R = { 0.5, 0.12, 0.4 } },
		{ Group = "Head", Color = "Hair", Kind = "Ellipsoid", C = { 0, 3.9, -0.72 }, R = { 0.72, 0.13, 0.26 } },
		-- spiky hair tuft and the bump
		{ Group = "Head", Color = "Hair", Kind = "Capsule", A = { 0.05, 4.1, -0.1 }, B = { 0.12, 4.6, -0.18 }, RA = 0.22, RB = 0.13 },
		{ Group = "Head", Color = "HairLight", Kind = "Capsule", A = { 0.12, 4.6, -0.18 }, B = { 0.34, 4.82, -0.36 }, RA = 0.13, RB = 0.06 },
		{ Group = "Head", Color = "Hair", Kind = "Capsule", A = { 0.35, 4.1, 0.05 }, B = { 0.55, 4.4, 0.12 }, RA = 0.15, RB = 0.06 },
		{ Group = "Head", Color = "Hair", Kind = "Capsule", A = { -0.1, 4.15, 0.3 }, B = { -0.15, 4.45, 0.5 }, RA = 0.15, RB = 0.06 },
		{ Group = "Head", Color = "Bump", Kind = "Ellipsoid", C = { -0.42, 4.15, -0.35 }, R = { 0.34, 0.32, 0.34 } },
		{ Group = "Head", Color = "BumpLight", Kind = "Ellipsoid", Paint = true, C = { -0.42, 4.38, -0.42 }, R = { 0.24, 0.12, 0.24 } },
		-- cupped ears
		{ Group = "EarL", Color = "Fur", Kind = "Ellipsoid", C = { 1.05, 3.4, -0.15 }, R = { 0.26, 0.42, 0.42 }, Mirror = true },
		{ Group = "EarL", Color = "FaceDark", Kind = "Ellipsoid", Paint = true, C = { 1.2, 3.4, -0.2 }, R = { 0.16, 0.3, 0.3 }, Mirror = true },
		{ Group = "EarL", Kind = "Ellipsoid", Carve = true, C = { 1.34, 3.4, -0.2 }, R = { 0.1, 0.24, 0.24 }, Mirror = true },
		-- long arms ending in big fists with knuckle grooves
		{ Group = "ArmL", Color = "Fur", Kind = "Capsule", A = { 1.1, 2.45, 0 }, B = { 1.4, 1.35, -0.25 }, RA = 0.42, RB = 0.36, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Capsule", Paint = true, A = { 1.3, 2.45, 0.25 }, B = { 1.6, 1.35, 0.0 }, R = 0.3, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Ellipsoid", C = { 1.45, 0.78, -0.35 }, R = { 0.56, 0.54, 0.56 }, Mirror = true },
		{ Group = "ArmL", Color = "Face", Kind = "Box", Paint = true, C = { 1.45, 0.9, -0.85 }, S = { 1.2, 0.45, 0.35 }, Mirror = true },
		{ Group = "ArmL", Color = "Knuckle", Kind = "Box", Paint = true, C = { 1.3, 0.9, -0.85 }, S = { 0.2, 0.45, 0.4 }, Mirror = true },
		{ Group = "ArmL", Color = "Knuckle", Kind = "Box", Paint = true, C = { 1.62, 0.9, -0.85 }, S = { 0.2, 0.45, 0.4 }, Mirror = true },
		-- short legs, tan feet
		{ Group = "LegL", Color = "Fur", Kind = "Capsule", A = { 0.55, 1.0, 0.25 }, B = { 0.6, 0.45, 0.2 }, R = 0.42, Mirror = true },
		{ Group = "LegL", Color = "Face", Kind = "Ellipsoid", C = { 0.6, 0.2, -0.05 }, R = { 0.44, 0.2, 0.56 }, Mirror = true },
	}
	local D = eyes({}, "Head", 0.32, 3.5, 0.58, 0.62, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "FurDark", X = 0.14, Y = 3.08, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.6, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0.34, Y = 2.88, W = 0.12, H = 0.1, D = 0.07, Mirror = true })
	table.insert(D, { Name = "Tooth", Group = "Head", Color = "White", X = 0.15, Y = 2.72, W = 0.14, H = 0.15, D = 0.12 })
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.62, Y = 3.12, W = 0.26, H = 0.14, D = 0.1, Mirror = true })
	specs.Bonkey = fine({
		Gait = "Knuckle",
		Emotes = { "Look", "ChestBeat", "Hop" },
		Palette = {
			Fur = "A0703F",
			FurDark = "84592F",
			Hair = "5E3D22",
			HairLight = "7A5232",
			Face = "FFD9A0",
			FaceLight = "FFE9C6",
			FaceDark = "E2AE6E",
			Knuckle = "E2AE6E",
			Bump = "FF9DBB",
			BumpLight = "FFC2D5",
			Bandage = "FFF6E6",
			White = "FFFFFF",
			Iris = "6B4423",
			Ink = "1A1033",
			Mouth = "4A2A3A",
			Blush = "FF9DBB",
		},
		Joints = {
			Head = { 0, 2.75, -0.1 },
			EarL = { 0.95, 3.4, -0.15 },
			EarR = { -0.95, 3.4, -0.15 },
			ArmL = { 1.1, 2.5, 0 },
			ArmR = { -1.1, 2.5, 0 },
			LegL = { 0.55, 1.0, 0.2 },
			LegR = { -0.55, 1.0, 0.2 },
		},
		Parents = { EarL = "Head", EarR = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Bandage", Group = "Head", Color = "Bandage", C = { -0.42, 4.47, -0.35 }, S = { 0.8, 0.1, 0.2 }, Rot = { 0, 40, 0 } },
			{ Name = "Bandage", Group = "Head", Color = "Bandage", C = { -0.42, 4.48, -0.35 }, S = { 0.8, 0.1, 0.2 }, Rot = { 0, -40, 0 } },
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.42, 0.1, -0.56 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.62, 0.1, -0.6 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.82, 0.1, -0.56 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
		},
	})
end

-- Pebble Plains / Rare / four legs: woolly baby mammoth with a ringed swinging trunk, curved tusks, a woolly tuft and
-- blue tribal stripes dotted white.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.55, 0.4 }, R = { 1.15, 1.0, 1.35 } },
		{ Group = "Body", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.4, 0.4 }, R = { 1.2, 0.45, 1.4 } },
		{ Group = "Body", Color = "FurDark", Kind = "Box", Paint = true, C = { 0, 0.72, 0.4 }, S = { 2.6, 0.24, 3 } },
		{ Group = "Body", Color = "Stripe", Kind = "Box", Paint = true, C = { 0, 2.3, -0.1 }, S = { 2.6, 0.9, 0.4 } },
		{ Group = "Body", Color = "Stripe", Kind = "Box", Paint = true, C = { 0, 2.3, 0.7 }, S = { 2.6, 0.9, 0.4 } },
		{ Group = "Body", Color = "Dot", Kind = "Ellipsoid", Paint = true, C = { 1.0, 2.05, -0.1 }, R = { 0.12, 0.12, 0.14 }, Mirror = true },
		{ Group = "Body", Color = "Dot", Kind = "Ellipsoid", Paint = true, C = { 1.0, 2.05, 0.7 }, R = { 0.12, 0.12, 0.14 }, Mirror = true },
		{ Group = "Body", Color = "Dot", Kind = "Ellipsoid", Paint = true, C = { 0.0, 2.55, 0.3 }, R = { 0.14, 0.12, 0.14 } },
		-- head with a woolly tuft and a stripe down the brow
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.95, -1.15 }, R = { 0.88, 0.82, 0.72 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", C = { 0, 2.62, -1.05 }, R = { 0.72, 0.28, 0.55 } },
		{ Group = "Head", Color = "FurDark", Kind = "Capsule", A = { 0, 2.72, -1.0 }, B = { 0.04, 2.92, -1.18 }, RA = 0.16, RB = 0.1 },
		{ Group = "Head", Color = "FurDark", Kind = "Capsule", A = { 0.04, 2.92, -1.18 }, B = { -0.02, 2.88, -1.36 }, RA = 0.1, RB = 0.06 },
		{ Group = "Head", Color = "Stripe", Kind = "Box", Paint = true, C = { 0, 2.4, -1.6 }, S = { 0.4, 0.4, 0.8 } },
		{ Group = "Head", Color = "FurLight", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, -1.6 }, R = { 0.55, 0.42, 0.3 } },
		-- tusks curving up and out
		{ Group = "Head", Color = "Tusk", Kind = "Capsule", A = { 0.42, 1.42, -1.72 }, B = { 0.5, 1.22, -2.08 }, RA = 0.13, RB = 0.11, Mirror = true },
		{ Group = "Head", Color = "Tusk", Kind = "Capsule", A = { 0.5, 1.22, -2.08 }, B = { 0.57, 1.34, -2.4 }, RA = 0.11, RB = 0.085, Mirror = true },
		{ Group = "Head", Color = "TuskLight", Kind = "Capsule", A = { 0.57, 1.34, -2.4 }, B = { 0.53, 1.66, -2.56 }, RA = 0.085, RB = 0.05, Mirror = true },
		-- trunk: hangs down then curls forward, wrinkle rings, pink tip
		{ Group = "Trunk", Color = "Fur", Kind = "Capsule", A = { 0, 1.6, -1.75 }, B = { 0, 1.15, -2.1 }, RA = 0.36, RB = 0.3 },
		{ Group = "Trunk", Color = "Fur", Kind = "Capsule", A = { 0, 1.15, -2.1 }, B = { 0, 1.3, -2.55 }, RA = 0.3, RB = 0.26 },
		{ Group = "Trunk", Color = "FurDark", Kind = "Box", Paint = true, C = { 0, 1.5, -2.0 }, S = { 1, 0.2, 1 } },
		{ Group = "Trunk", Color = "FurDark", Kind = "Box", Paint = true, C = { 0, 1.3, -2.1 }, S = { 1, 0.2, 1 } },
		{ Group = "Trunk", Color = "FurDark", Kind = "Box", Paint = true, C = { 0, 1.2, -2.35 }, S = { 1, 1, 0.2 } },
		{ Group = "Trunk", Color = "Pink", Kind = "Box", Paint = true, C = { 0, 1.3, -2.7 }, S = { 1, 1, 0.4 } },
		-- big floppy ears, cupped pink insides
		{ Group = "EarL", Color = "Fur", Kind = "Ellipsoid", C = { 1.1, 1.95, -0.9 }, R = { 0.22, 0.62, 0.55 }, Mirror = true },
		{ Group = "EarL", Color = "Pink", Kind = "Ellipsoid", Paint = true, C = { 1.22, 1.95, -0.95 }, R = { 0.14, 0.46, 0.4 }, Mirror = true },
		{ Group = "EarL", Kind = "Ellipsoid", Carve = true, C = { 1.32, 1.95, -0.95 }, R = { 0.08, 0.4, 0.34 }, Mirror = true },
		-- legs with woolly cuffs and hooves
		{ Group = "LegFL", Color = "Fur", Kind = "Capsule", A = { 0.62, 1.05, -0.45 }, B = { 0.65, 0.35, -0.5 }, R = 0.38, Mirror = true },
		{ Group = "LegFL", Color = "FurDark", Kind = "Ellipsoid", C = { 0.65, 0.5, -0.5 }, R = { 0.44, 0.14, 0.44 }, Mirror = true },
		{ Group = "LegFL", Color = "Hoof", Kind = "Box", C = { 0.65, 0.18, -0.55 }, S = { 0.8, 0.36, 0.8 }, Mirror = true },
		{ Group = "LegBL", Color = "Fur", Kind = "Capsule", A = { 0.62, 1.05, 1.25 }, B = { 0.65, 0.35, 1.25 }, R = 0.4, Mirror = true },
		{ Group = "LegBL", Color = "FurDark", Kind = "Ellipsoid", C = { 0.65, 0.5, 1.25 }, R = { 0.46, 0.14, 0.46 }, Mirror = true },
		{ Group = "LegBL", Color = "Hoof", Kind = "Box", C = { 0.65, 0.18, 1.2 }, S = { 0.8, 0.36, 0.8 }, Mirror = true },
		-- tail with a tuft
		{ Group = "Tail", Color = "Fur", Kind = "Capsule", A = { 0, 1.85, 1.7 }, B = { 0, 1.4, 2.0 }, R = 0.2 },
		{ Group = "Tail", Color = "FurDark", Kind = "Ellipsoid", C = { 0, 1.25, 2.1 }, R = { 0.28, 0.32, 0.28 } },
	}
	local D = eyes({}, "Head", 0.36, 2.15, 0.54, 0.58, "Iris")
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.62, Y = 1.82, W = 0.3, H = 0.16, D = 0.1, Mirror = true })
	specs.Tuskit = fine({
		Gait = "Amble",
		Emotes = { "Look", "Trumpet", "Wiggle" },
		Palette = {
			Fur = "9C7B6A",
			FurDark = "7C5E50",
			FurLight = "B39486",
			Tusk = "FFF4D6",
			TuskLight = "FFFDF4",
			Hoof = "5C4339",
			Stripe = "3FA9FF",
			Dot = "FFFFFF",
			Pink = "F2A5A5",
			White = "FFFFFF",
			Iris = "4A3428",
			Ink = "1A1033",
			Blush = "FF9DBB",
		},
		Joints = {
			Head = { 0, 1.85, -0.6 },
			Trunk = { 0, 1.6, -1.65 },
			EarL = { 0.8, 2.2, -0.95 },
			EarR = { -0.8, 2.2, -0.95 },
			LegFL = { 0.62, 1.05, -0.45 },
			LegFR = { -0.62, 1.05, -0.45 },
			LegBL = { 0.62, 1.05, 1.25 },
			LegBR = { -0.62, 1.05, 1.25 },
			Tail = { 0, 1.85, 1.65 },
		},
		Parents = { Trunk = "Head", EarL = "Head", EarR = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Nail", Group = "LegFL", Color = "Tusk", C = { 0.45, 0.12, -0.96 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegFL", Color = "Tusk", C = { 0.85, 0.12, -0.96 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegBL", Color = "Tusk", C = { 0.45, 0.12, 0.79 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegBL", Color = "Tusk", C = { 0.85, 0.12, 0.79 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
		},
	})
end

-- Pebble Plains / Epic / lizard: the hero. Green rex with a big head, long rounded snout, fangs and a row of layered
-- glowing purple plates from crown to tail tip.
do
	local S = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.7, 0.25 }, R = { 1.25, 1.25, 1.1 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.25, 0.98 }, R = { 1.2, 1.15, 0.5 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.55, -0.42 }, R = { 0.9, 1.0, 0.6 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.9, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.3, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.7, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.1, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 1.08, 1.55, 0.55 }, R = { 0.26, 0.24, 0.26 }, Mirror = true },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0.95, 2.35, 0.3 }, R = { 0.2, 0.18, 0.2 }, Mirror = true },
		-- head: rounded skull, long snout with a rounded tip and nostril bumps, cheeks, darker crown, cream jaw
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.55, -0.35 }, R = { 1.15, 0.95, 1.0 } },
		{ Group = "Head", Color = "Body", Kind = "Box", C = { 0, 3.0, -1.4 }, S = { 1.35, 0.7, 1.4 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.0, -2.05 }, R = { 0.66, 0.36, 0.32 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.3, 3.38, -1.95 }, R = { 0.13, 0.09, 0.13 }, Mirror = true },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.88, 3.15, -0.7 }, R = { 0.32, 0.3, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 4.15, 0.1 }, R = { 0.95, 0.42, 0.85 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Box", C = { 0, 2.6, -1.3 }, S = { 1.2, 0.4, 1.2 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Ellipsoid", C = { 0, 2.62, -1.88 }, R = { 0.55, 0.2, 0.26 } },
		{ Group = "Jaw", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.5, -1.5 }, S = { 1.4, 0.2, 1.4 } },
		-- chunky legs with rounded feet, arms with hands
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.78, 1.05, 0.25 }, B = { 0.8, 0.45, 0.05 }, RA = 0.64, RB = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Dark", Kind = "Ellipsoid", C = { 0.8, 0.2, -0.25 }, R = { 0.6, 0.2, 0.76 }, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 1.15, 2.05, -0.25 }, B = { 1.25, 1.6, -0.8 }, RA = 0.34, RB = 0.28, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Ellipsoid", C = { 1.27, 1.5, -0.98 }, R = { 0.26, 0.22, 0.24 }, Mirror = true },
		-- tail with stripes over the top
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.1, 1.0 }, B = { 0, 0.7, 2.1 }, RA = 0.7, RB = 0.5 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.7, 2.1 }, B = { 0, 0.6, 3.0 }, RA = 0.5, RB = 0.3 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 3.0 }, B = { 0, 0.9, 3.4 }, RA = 0.3, RB = 0.2 },
		{ Group = "Tail", Color = "Dark", Kind = "Box", Paint = true, C = { 0, 1.4, 1.75 }, S = { 1.8, 0.9, 0.2 } },
		{ Group = "Tail", Color = "Dark", Kind = "Box", Paint = true, C = { 0, 1.2, 2.35 }, S = { 1.6, 0.9, 0.2 } },
		{ Group = "Tail", Color = "Dark", Kind = "Box", Paint = true, C = { 0, 1.0, 2.9 }, S = { 1.4, 0.8, 0.2 } },
	}
	for _, p in {
		{ "Head", Vector3.new(0, 4.4, -0.4), Vector3.new(0, 1, 0.12), 0.72 },
		{ "Head", Vector3.new(0, 4.3, 0.22), Vector3.new(0, 0.9, 0.45), 0.56 },
		{ "Body", Vector3.new(0, 2.85, 0.95), Vector3.new(0, 0.8, 0.6), 0.95 },
		{ "Body", Vector3.new(0, 2.3, 1.25), Vector3.new(0, 0.6, 0.8), 0.8 },
		{ "Tail", Vector3.new(0, 1.5, 1.95), Vector3.new(0, 0.85, 0.5), 0.75 },
		{ "Tail", Vector3.new(0, 1.2, 2.6), Vector3.new(0, 0.8, 0.6), 0.6 },
		{ "Tail", Vector3.new(0, 1.02, 3.15), Vector3.new(0, 0.75, 0.65), 0.45 },
	} do
		plate(S, p[1], p[2], p[3], p[4], "Plate", "PlateTip")
	end
	local D = eyes({}, "Head", 0.52, 3.8, 0.78, 0.72, "Iris")
	table.insert(D, { Name = "Brow", Group = "Head", Color = "Brow", X = 0.52, Y = 4.27, W = 0.85, H = 0.18, D = 0.16, Tilt = 12, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.3, Y = 3.32, W = 0.12, H = 0.12, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.95, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.4, Y = 2.68, W = 0.2, H = 0.26, D = 0.12, Mirror = true })
	specs.Rumblerex = fine({
		Gait = "Biped",
		Emotes = { "Look", "Roar", "Wiggle" },
		Palette = {
			Body = "4DBB45",
			Dark = "389C3E",
			Belly = "FFEBC2",
			BellyLine = "EFCF95",
			Plate = { "6A22D8", Neon = true },
			PlateTip = { "8C4BFF", Neon = true },
			Claw = "FFF4D6",
			White = "FFFFFF",
			Iris = "E8A22E",
			Ink = "1A1033",
			Mouth = "3B1A33",
			Brow = "1F5E2B",
		},
		Joints = {
			Head = { 0, 2.7, -0.3 },
			Jaw = { 0, 2.75, -0.7 },
			LegL = { 0.75, 1.0, 0.25 },
			LegR = { -0.75, 1.0, 0.25 },
			ArmL = { 1.15, 2.05, -0.25 },
			ArmR = { -1.15, 2.05, -0.25 },
			Tail = { 0, 1.1, 1.0 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.45, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.8, 0.13, -1.02 }, S = { 0.24, 0.26, 0.32 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.15, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.16, 1.4, -1.2 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.36, 1.4, -1.18 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
		},
	})
end

-- Pebble Plains / Legendary / ape: storm gorilla with a big thundercloud on its back, shaggy shoulders, a lightning
-- crest, a lightning chest and glowing knuckles.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 2.0, 0.15 }, R = { 1.35, 1.25, 1.05 } },
		{ Group = "Body", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.5, 0.9 }, R = { 1.3, 1.1, 0.45 } },
		{ Group = "Body", Color = "Chest", Kind = "Ellipsoid", Paint = true, C = { 0, 1.9, -0.75 }, R = { 0.95, 0.95, 0.55 } },
		{ Group = "Body", Color = "ChestDark", Kind = "Box", Paint = true, C = { 0, 1.1, -0.9 }, S = { 2, 0.2, 0.7 } },
		{ Group = "Body", Color = "FurLight", Kind = "Capsule", A = { 1.0, 2.9, 0.2 }, B = { 1.4, 3.15, 0.35 }, RA = 0.22, RB = 0.06, Mirror = true },
		{ Group = "Body", Color = "Fur", Kind = "Capsule", A = { 1.2, 2.6, 0.4 }, B = { 1.62, 2.7, 0.55 }, RA = 0.2, RB = 0.05, Mirror = true },
		{ Group = "Body", Color = "FurLight", Kind = "Capsule", A = { 1.25, 2.25, 0.5 }, B = { 1.68, 2.2, 0.68 }, RA = 0.17, RB = 0.04, Mirror = true },
		-- head: face mask, muzzle, heavy brow, crest ending in a glowing bolt
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 3.75, -0.3 }, R = { 1.05, 0.95, 0.95 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 4.1, 0.35 }, R = { 1.0, 0.7, 0.5 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0, 3.6, -1.05 }, R = { 0.8, 0.75, 0.5 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", C = { 0, 3.3, -1.1 }, R = { 0.62, 0.42, 0.38 } },
		{ Group = "Head", Color = "FaceLight", Kind = "Ellipsoid", Paint = true, C = { 0, 3.48, -1.42 }, R = { 0.4, 0.12, 0.2 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", C = { 0, 4.18, -1.0 }, R = { 0.85, 0.17, 0.26 } },
		{ Group = "Head", Color = "FurDark", Kind = "Capsule", A = { 0, 4.5, -0.45 }, B = { 0, 4.92, -0.25 }, RA = 0.26, RB = 0.16 },
		{ Group = "Head", Color = "Bolt", Kind = "Capsule", A = { 0, 4.92, -0.25 }, B = { 0.12, 5.18, -0.12 }, RA = 0.16, RB = 0.08 },
		{ Group = "Head", Color = "Bolt", Kind = "Capsule", A = { 0.12, 5.18, -0.12 }, B = { -0.06, 5.42, -0.02 }, RA = 0.08, RB = 0.04 },
		-- huge arms: darker forearms, glowing knuckles with grooves
		{ Group = "ArmL", Color = "Fur", Kind = "Capsule", A = { 1.3, 2.75, 0 }, B = { 1.65, 1.45, -0.3 }, RA = 0.52, RB = 0.45, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Capsule", Paint = true, A = { 1.55, 2.2, 0.3 }, B = { 1.85, 1.4, 0.05 }, R = 0.35, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Ellipsoid", C = { 1.7, 0.82, -0.45 }, R = { 0.62, 0.56, 0.62 }, Mirror = true },
		{ Group = "ArmL", Color = "Bolt", Kind = "Box", Paint = true, C = { 1.7, 0.95, -0.9 }, S = { 1.3, 0.45, 0.6 }, Mirror = true },
		{ Group = "ArmL", Color = "BoltDeep", Kind = "Box", Paint = true, C = { 1.5, 0.95, -0.95 }, S = { 0.2, 0.45, 0.5 }, Mirror = true },
		{ Group = "ArmL", Color = "BoltDeep", Kind = "Box", Paint = true, C = { 1.9, 0.95, -0.95 }, S = { 0.2, 0.45, 0.5 }, Mirror = true },
		-- legs, pale feet
		{ Group = "LegL", Color = "Fur", Kind = "Capsule", A = { 0.62, 1.15, 0.3 }, B = { 0.66, 0.5, 0.25 }, R = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Face", Kind = "Ellipsoid", C = { 0.66, 0.2, -0.02 }, R = { 0.5, 0.2, 0.64 }, Mirror = true },
	}
	-- thundercloud riding on the back: lit tops, dark undersides
	for _, p in {
		{ 0, 3.7, 1.15, 1.1, 0.6, 0.62 },
		{ 1.3, 3.5, 0.95, 0.68, 0.56, 0.56 },
		{ -1.3, 3.55, 0.95, 0.68, 0.56, 0.56 },
		{ 0.65, 4.25, 1.15, 0.58, 0.48, 0.5 },
		{ -0.6, 4.2, 1.05, 0.54, 0.46, 0.48 },
		{ 0, 4.5, 1.45, 0.5, 0.42, 0.42 },
		{ 1.78, 3.2, 1.0, 0.4, 0.36, 0.38 },
		{ -1.78, 3.25, 1.0, 0.4, 0.36, 0.38 },
	} do
		table.insert(S, { Group = "Cloud", Color = "Cloud", Kind = "Ellipsoid", C = { p[1], p[2], p[3] }, R = { p[4], p[5], p[6] } })
	end
	for _, p in {
		{ 0, 3.7, 1.15, 1.1, 0.6, 0.62 },
		{ 1.3, 3.5, 0.95, 0.68, 0.56, 0.56 },
		{ -1.3, 3.55, 0.95, 0.68, 0.56, 0.56 },
		{ 0.65, 4.25, 1.15, 0.58, 0.48, 0.5 },
		{ -0.6, 4.2, 1.05, 0.54, 0.46, 0.48 },
		{ 0, 4.5, 1.45, 0.5, 0.42, 0.42 },
		{ 1.78, 3.2, 1.0, 0.4, 0.36, 0.38 },
		{ -1.78, 3.25, 1.0, 0.4, 0.36, 0.38 },
	} do
		table.insert(S, { Group = "Cloud", Color = "CloudLight", Kind = "Ellipsoid", Paint = true, C = { p[1], p[2] + p[5] * 0.5, p[3] }, R = { p[4] * 0.75, p[5] * 0.4, p[6] * 0.75 } })
		table.insert(S, { Group = "Cloud", Color = "CloudDark", Kind = "Ellipsoid", Paint = true, C = { p[1], p[2] - p[5] * 0.6, p[3] + 0.05 }, R = { p[4] * 1.02, p[5] * 0.32, p[6] * 1.02 } })
	end
	local D = eyes({}, "Head", 0.36, 3.8, 0.58, 0.58, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "FurDark", X = 0.16, Y = 3.45, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 3.12, W = 0.8, H = 0.14, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.25, Y = 3.0, W = 0.16, H = 0.2, D = 0.12, Mirror = true })
	table.insert(D, { Name = "ChestBolt", Group = "Body", Color = "Bolt", X = 0.22, Y = 2.45, W = 0.24, H = 0.8, D = 0.12, Tilt = 28 })
	table.insert(D, { Name = "ChestBolt", Group = "Body", Color = "Bolt", X = 0.02, Y = 2.06, W = 0.6, H = 0.22, D = 0.12 })
	table.insert(D, { Name = "ChestBolt", Group = "Body", Color = "Bolt", X = -0.18, Y = 1.65, W = 0.24, H = 0.85, D = 0.12, Tilt = -28 })
	specs.Thunderback = fine({
		Gait = "Knuckle",
		Emotes = { "Look", "ChestBeat", "Hop" },
		Palette = {
			Fur = "3A4A8C",
			FurDark = "2C3974",
			FurLight = "5466B0",
			Chest = "8C9BD9",
			ChestDark = "7383C6",
			Face = "A9B5E8",
			FaceLight = "C7D0F2",
			Bolt = { "FFD23F", Neon = true },
			BoltDeep = { "E89A16", Neon = true },
			Cloud = "E4E9F5",
			CloudLight = "FFFFFF",
			CloudDark = "AEB7D2",
			White = "FFFFFF",
			Iris = "E8B92A",
			Ink = "1A1033",
			Mouth = "1E1838",
		},
		Joints = {
			Head = { 0, 3.0, -0.2 },
			ArmL = { 1.3, 2.8, 0 },
			ArmR = { -1.3, 2.8, 0 },
			LegL = { 0.62, 1.15, 0.25 },
			LegR = { -0.62, 1.15, 0.25 },
			Cloud = { 0, 3.2, 1.0 },
		},
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Lightning", Group = "Cloud", Color = "Bolt", C = { 1.85, 2.75, 1.0 }, S = { 0.22, 0.62, 0.22 }, Rot = { 0, 0, -25 }, Mirror = true },
			{ Name = "Lightning", Group = "Cloud", Color = "Bolt", C = { 1.88, 2.22, 1.0 }, S = { 0.22, 0.58, 0.22 }, Rot = { 0, 0, 25 }, Mirror = true },
			{ Name = "Lightning", Group = "Cloud", Color = "Bolt", C = { 1.84, 1.75, 1.0 }, S = { 0.2, 0.42, 0.2 }, Rot = { 0, 0, -25 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Chest", C = { 0.42, 0.1, -0.64 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Chest", C = { 0.66, 0.1, -0.68 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Chest", C = { 0.9, 0.1, -0.64 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
		},
	})
end

-- Secret / Any / lizard: pearl-white crystal lizard with a rainbow of glowing voxel crystals down its back and
-- shoulders, a lavender back, violet eyes and a forehead gem.
do
	local S = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.45, 0.15 }, R = { 1.05, 1.05, 0.95 } },
		{ Group = "Body", Color = "Shade", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, 0.95 }, R = { 0.95, 1.1, 0.62 } },
		{ Group = "Body", Color = "Shade", Kind = "Box", Paint = true, C = { 0, 0.5, 0.15 }, S = { 2.4, 0.2, 2.2 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.3, -0.47 }, R = { 0.78, 0.86, 0.5 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.7, -0.85 }, S = { 2, 0.2, 0.8 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.1, -0.85 }, S = { 2, 0.2, 0.8 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.5, -0.85 }, S = { 2, 0.2, 0.8 } },
		-- head: round skull, cheeks, snout, a pearly pink crown, lavender back of the head
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.95, -0.25 }, R = { 1.1, 0.95, 0.95 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 2.52, -0.95 }, R = { 0.78, 0.44, 0.55 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.72, 2.62, -0.58 }, R = { 0.42, 0.36, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Tint", Kind = "Ellipsoid", Paint = true, C = { 0, 3.72, -0.35 }, R = { 0.85, 0.32, 0.75 } },
		{ Group = "Head", Color = "Shade", Kind = "Ellipsoid", Paint = true, C = { 0, 3.2, 0.6 }, R = { 0.9, 0.7, 0.42 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Ellipsoid", C = { 0, 2.3, -0.9 }, R = { 0.66, 0.2, 0.56 } },
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.6, 0.95, 0.15 }, B = { 0.62, 0.42, 0 }, RA = 0.48, RB = 0.4, Mirror = true },
		{ Group = "LegL", Color = "Shade", Kind = "Ellipsoid", C = { 0.62, 0.2, -0.22 }, R = { 0.48, 0.22, 0.62 }, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 0.95, 1.75, -0.25 }, B = { 1.05, 1.38, -0.68 }, RA = 0.28, RB = 0.22, Mirror = true },
		{ Group = "ArmL", Color = "Shade", Kind = "Ellipsoid", C = { 1.06, 1.3, -0.84 }, R = { 0.24, 0.2, 0.22 }, Mirror = true },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.0, 0.8 }, B = { 0, 0.65, 1.7 }, RA = 0.55, RB = 0.42 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.65, 1.7 }, B = { 0, 0.6, 2.45 }, RA = 0.42, RB = 0.26 },
		{ Group = "Tail", Color = "Shade", Kind = "Capsule", A = { 0, 0.6, 2.45 }, B = { 0, 0.95, 2.82 }, RA = 0.26, RB = 0.16 },
	}
	for _, c in {
		{ "Head", Vector3.new(0, 3.78, -0.2), Vector3.new(0, 1, -0.08), 0.3, 0.72, "Gem1" },
		{ "Head", Vector3.new(0, 3.66, 0.32), Vector3.new(0, 0.9, 0.45), 0.28, 0.6, "Gem2" },
		{ "Body", Vector3.new(0, 2.45, 0.78), Vector3.new(0, 0.8, 0.6), 0.34, 0.82, "Gem3" },
		{ "Body", Vector3.new(0, 1.95, 1.02), Vector3.new(0, 0.6, 0.8), 0.32, 0.72, "Gem4" },
		{ "Tail", Vector3.new(0, 1.22, 1.62), Vector3.new(0, 0.8, 0.6), 0.3, 0.62, "Gem5" },
		{ "Tail", Vector3.new(0, 0.95, 2.25), Vector3.new(0, 0.75, 0.66), 0.26, 0.52, "Gem6" },
		{ "Tail", Vector3.new(0, 1.02, 2.72), Vector3.new(0, 0.7, 0.7), 0.22, 0.42, "Gem1" },
		{ "Body", Vector3.new(0.7, 2.15, 0.45), Vector3.new(0.6, 0.8, 0.2), 0.26, 0.55, "Gem5" },
		{ "Body", Vector3.new(-0.7, 2.15, 0.45), Vector3.new(-0.6, 0.8, 0.2), 0.26, 0.55, "Gem5" },
	} do
		crystal(S, c[1], c[2], c[3], c[4] * 1.35, c[5] * 1.35, c[6], c[6])
	end
	local D = eyes({}, "Head", 0.44, 3.15, 0.8, 0.84, "Iris")
	table.insert(D, { Name = "Gem", Group = "Head", Color = "Gem6", X = 0, Y = 3.68, W = 0.3, H = 0.3, D = 0.14, Tilt = 45 })
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.84, Y = 2.74, W = 0.36, H = 0.18, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Shade", X = 0.2, Y = 2.72, W = 0.1, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.46, W = 0.6, H = 0.1, D = 0.07 })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0.34, Y = 2.52, W = 0.12, H = 0.1, D = 0.07, Mirror = true })
	specs.Prismling = fine({
		Gait = "Biped",
		Emotes = { "Look", "Hop", "HopSpin", "Roar" },
		Palette = {
			Body = "F4F1FF",
			Shade = "DCD4FF",
			Tint = "FFE3F2",
			Belly = "FFFFFF",
			BellyLine = "EDE8FF",
			Gem1 = { "FF5A7A", Neon = true },
			Gem2 = { "FFB347", Neon = true },
			Gem3 = { "FFF04D", Neon = true },
			Gem4 = { "5CFF9D", Neon = true },
			Gem5 = { "4DC3FF", Neon = true },
			Gem6 = { "B266FF", Neon = true },
			Gem1Tip = { "FF8FA6", Neon = true },
			Gem2Tip = { "FFCB7A", Neon = true },
			Gem3Tip = { "FFF68A", Neon = true },
			Gem4Tip = { "8FFFBC", Neon = true },
			Gem5Tip = { "85D8FF", Neon = true },
			Gem6Tip = { "CB94FF", Neon = true },
			Claw = "FFFFFF",
			White = "FFFFFF",
			Iris = "8A6BFF",
			Ink = "2A1A55",
			Mouth = "5A3A7A",
			Blush = "FFB3D9",
		},
		Joints = {
			Head = { 0, 2.3, -0.2 },
			Jaw = { 0, 2.42, -0.45 },
			LegL = { 0.6, 0.95, 0.15 },
			LegR = { -0.6, 0.95, 0.15 },
			ArmL = { 0.95, 1.75, -0.25 },
			ArmR = { -0.95, 1.75, -0.25 },
			Tail = { 0, 1.0, 0.8 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.34, 0.12, -0.86 }, S = { 0.2, 0.24, 0.24 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.62, 0.12, -0.9 }, S = { 0.2, 0.24, 0.26 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.9, 0.12, -0.86 }, S = { 0.2, 0.24, 0.24 }, Mirror = true },
		},
	})
end

-- Lava Lagoon / Common / crab: basalt mite with glowing cracks cut into its shell, lit rock lumps, round eyes on
-- stalks and hot pincer tips.
do
	local SC, SR = { 0, 1.15, 0.15 }, { 1.35, 0.75, 1.1 }
	local S = {
		{ Group = "Body", Color = "Rock", Kind = "Ellipsoid", C = SC, R = SR },
		{ Group = "Body", Color = "Under", Kind = "Box", Paint = true, C = { 0, 0.6, 0.15 }, S = { 3, 0.4, 2.6 } },
		{ Group = "Body", Color = "RockDark", Kind = "Box", Paint = true, C = { 0, 0.9, 0.15 }, S = { 3, 0.2, 2.6 } },
		-- claws: rock arm, a pincer that opens, glowing hot tips
		{ Group = "ClawL", Color = "Rock", Kind = "Capsule", A = { 1.0, 0.95, -0.55 }, B = { 1.45, 0.85, -1.05 }, RA = 0.28, RB = 0.24, Mirror = true },
		{ Group = "ClawL", Color = "Rock", Kind = "Ellipsoid", C = { 1.55, 0.88, -1.38 }, R = { 0.4, 0.34, 0.38 }, Mirror = true },
		{ Group = "ClawL", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = { 1.55, 1.12, -1.38 }, R = { 0.3, 0.12, 0.3 }, Mirror = true },
		{ Group = "ClawL", Color = "Rock", Kind = "Capsule", A = { 1.55, 1.02, -1.65 }, B = { 1.52, 1.12, -2.05 }, RA = 0.2, RB = 0.12, Mirror = true },
		{ Group = "ClawL", Color = "Rock", Kind = "Capsule", A = { 1.55, 0.72, -1.65 }, B = { 1.56, 0.66, -1.98 }, RA = 0.17, RB = 0.1, Mirror = true },
		{ Group = "ClawL", Color = "Lava", Kind = "Box", Paint = true, C = { 1.55, 0.9, -1.95 }, S = { 0.8, 1.0, 0.3 }, Mirror = true },
		{ Group = "ClawL", Color = "Hot", Kind = "Box", Paint = true, C = { 1.55, 0.9, -2.1 }, S = { 0.8, 1.0, 0.2 }, Mirror = true },
		-- eyes on stalks
		{ Group = "EyeL", Color = "Rock", Kind = "Capsule", A = { 0.45, 1.65, -0.62 }, B = { 0.47, 2.2, -0.68 }, RA = 0.12, RB = 0.1, Mirror = true },
		{ Group = "EyeL", Color = "White", Kind = "Ellipsoid", C = { 0.47, 2.42, -0.7 }, R = { 0.3, 0.3, 0.28 }, Mirror = true },
		-- six legs: out from the shell, down to a pointed foot
	}
	for _, l in { { "LegAL", -0.35, -0.5 }, { "LegBL", 0.2, 0.2 }, { "LegCL", 0.75, 0.9 } } do
		table.insert(S, { Group = l[1], Color = "Rock", Kind = "Capsule", A = { 1.15, 0.8, l[2] }, B = { 1.72, 0.62, l[3] }, RA = 0.15, RB = 0.12, Mirror = true })
		table.insert(S, { Group = l[1], Color = "RockLight", Kind = "Capsule", A = { 1.72, 0.62, l[3] }, B = { 1.86, 0.08, l[3] }, RA = 0.12, RB = 0.06, Mirror = true })
	end
	-- lit rock lumps on the shell
	local surf = dome(SC, SR)
	for _, b in { { 0.7, 0.62, 0.3 }, { -0.75, -0.22, 0.28 }, { 0.55, -0.55, 0.22 }, { -0.5, 0.85, 0.24 }, { 0.95, 0.05, 0.2 }, { -1.0, 0.4, 0.2 } } do
		local c = Vector3.new(b[1], surf(b[1], b[2]) - 0.05, b[2])
		table.insert(S, { Group = "Body", Color = "Rock", Kind = "Ellipsoid", C = c, R = { b[3], b[3] * 0.75, b[3] } })
		table.insert(S, { Group = "Body", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, b[3] * 0.5, 0), R = { b[3] * 0.8, b[3] * 0.4, b[3] * 0.8 } })
	end
	-- glowing cracks across the top
	crack(S, "Body", surf, { { 0.0, -0.8 }, { 0.14, -0.35 }, { -0.08, 0.12 }, { 0.12, 0.58 }, { -0.04, 1.05 } }, 0.13, "Lava", "Hot")
	crack(S, "Body", surf, { { 0.14, -0.35 }, { 0.55, -0.42 }, { 0.98, -0.25 } }, 0.12, "Lava", "Hot")
	crack(S, "Body", surf, { { -0.08, 0.12 }, { -0.55, 0.28 }, { -1.0, 0.12 } }, 0.12, "Lava", "Hot")
	crack(S, "Body", surf, { { 0.12, 0.58 }, { 0.5, 0.86 }, { 0.82, 1.02 } }, 0.12, "Lava", "Hot")
	local D = {
		{ Name = "Iris", Group = "EyeL", Color = "Iris", X = 0.45, Y = 2.4, W = 0.38, H = 0.4, D = 0.12, Mirror = true },
		{ Name = "Pupil", Group = "EyeL", Color = "Ink", X = 0.44, Y = 2.38, W = 0.26, H = 0.3, D = 0.14, Mirror = true },
		{ Name = "Glint", Group = "EyeL", Color = "White", X = 0.38, Y = 2.48, W = 0.1, H = 0.1, D = 0.18, Mirror = true },
		{ Name = "Mouth", Group = "Body", Color = "Mouth", X = 0, Y = 1.05, W = 0.6, H = 0.12, D = 0.07 },
		{ Name = "Fang", Group = "Body", Color = "Hot", X = 0.2, Y = 0.94, W = 0.13, H = 0.16, D = 0.1, Mirror = true },
	}
	specs.Magmite = fine({
		Gait = "Scuttle",
		Emotes = { "ClawSnap", "Look", "Wiggle" },
		Palette = {
			Rock = "3B2A2A",
			RockDark = "2C1F1F",
			RockLight = "5E4540",
			Under = "7A5244",
			Lava = { "FF5A14", Neon = true },
			Hot = { "FFB23F", Neon = true },
			White = "FFFFFF",
			Iris = "FF7A2A",
			Ink = "1A1033",
			Mouth = "1E0E0E",
		},
		Joints = {
			EyeL = { 0.45, 1.7, -0.65 },
			EyeR = { -0.45, 1.7, -0.65 },
			ClawL = { 1.0, 0.95, -0.55 },
			ClawR = { -1.0, 0.95, -0.55 },
			LegAL = { 1.15, 0.75, -0.35 },
			LegAR = { -1.15, 0.75, -0.35 },
			LegBL = { 1.15, 0.75, 0.2 },
			LegBR = { -1.15, 0.75, 0.2 },
			LegCL = { 1.15, 0.75, 0.75 },
			LegCR = { -1.15, 0.75, 0.75 },
		},
		Shapes = S,
		Details = D,
	})
end

-- Lava Lagoon / Uncommon / four legs: squat toad with raised glowing ember warts, lidded eyes on top, webbed feet.
do
	local BC, BR = { 0, 1.1, 0.25 }, { 1.3, 0.85, 1.2 }
	local S = {
		{ Group = "Body", Color = "Skin", Kind = "Ellipsoid", C = BC, R = BR },
		{ Group = "Body", Color = "SkinDark", Kind = "Box", Paint = true, C = { 0, 0.55, 0.25 }, S = { 3, 0.4, 2.6 } },
		{ Group = "Body", Color = "SkinLight", Kind = "Ellipsoid", Paint = true, C = { 0, 1.95, 0.4 }, R = { 0.9, 0.2, 0.9 } },
		-- head: wide, cream throat, eye bumps with heavy lids
		{ Group = "Head", Color = "Skin", Kind = "Ellipsoid", C = { 0, 1.35, -0.75 }, R = { 1.2, 0.72, 0.75 } },
		{ Group = "Head", Color = "Belly", Kind = "Ellipsoid", C = { 0, 0.85, -0.95 }, R = { 0.85, 0.45, 0.45 } },
		{ Group = "Head", Color = "BellyDark", Kind = "Box", Paint = true, C = { 0, 0.7, -1.1 }, S = { 2, 0.2, 0.6 } },
		{ Group = "Head", Color = "Skin", Kind = "Ellipsoid", C = { 0.62, 2.0, -0.8 }, R = { 0.42, 0.42, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "SkinDark", Kind = "Ellipsoid", Paint = true, C = { 0.62, 2.36, -0.76 }, R = { 0.46, 0.16, 0.44 }, Mirror = true },
		-- legs: straight front legs, big folded back legs, webbed feet
		{ Group = "LegFL", Color = "Skin", Kind = "Capsule", A = { 0.85, 0.9, -0.55 }, B = { 0.95, 0.3, -0.8 }, RA = 0.29, RB = 0.24, Mirror = true },
		{ Group = "LegFL", Color = "SkinDark", Kind = "Ellipsoid", C = { 0.98, 0.1, -0.98 }, R = { 0.4, 0.1, 0.36 }, Mirror = true },
		{ Group = "LegBL", Color = "Skin", Kind = "Ellipsoid", C = { 1.1, 0.65, 0.7 }, R = { 0.5, 0.52, 0.72 }, Mirror = true },
		{ Group = "LegBL", Color = "SkinDark", Kind = "Ellipsoid", C = { 1.25, 0.1, 0.12 }, R = { 0.46, 0.1, 0.46 }, Mirror = true },
	}
	-- ember warts: raised, glowing, hot in the middle
	local surf = dome(BC, BR)
	for i, w in { { 0.55, 0.35, 0.22 }, { -0.45, 0.65, 0.22 }, { 0.05, 1.0, 0.2 }, { -0.75, 0.05, 0.2 }, { 0.85, 0.9, 0.2 }, { 0.1, 0.2, 0.17 }, { -0.95, 0.85, 0.16 }, { 0.95, -0.1, 0.16 }, { -0.2, 1.3, 0.15 }, { 0.5, 1.25, 0.15 } } do
		local c = Vector3.new(w[1], surf(w[1], w[2]) - 0.06, w[2])
		table.insert(S, { Group = "Body", Color = i % 3 == 0 and "EmberHot" or "Ember", Kind = "Ellipsoid", C = c, R = { w[3], w[3] * 0.75, w[3] } })
		table.insert(S, { Group = "Body", Color = "EmberHot", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, w[3] * 0.55, 0), R = { w[3] * 0.5, w[3] * 0.3, w[3] * 0.5 } })
	end
	for _, side in { 1, -1 } do
		table.insert(S, { Group = side > 0 and "LegBL" or "LegBR", Color = "Ember", Kind = "Ellipsoid", C = { 1.4 * side, 0.95, 0.85 }, R = { 0.18, 0.18, 0.18 } })
	end
	local D = eyes({}, "Head", 0.62, 2.05, 0.56, 0.56, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.22, Y = 1.6, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.82, Y = 1.32, W = 0.3, H = 0.16, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 1.08, W = 1.5, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0.8, Y = 1.16, W = 0.14, H = 0.12, D = 0.07, Mirror = true })
	specs.CinderToad = fine({
		Gait = "Hop",
		Emotes = { "BigHop", "Look" },
		Palette = {
			Skin = "7A4A3A",
			SkinDark = "5C3328",
			SkinLight = "8E5A47",
			Belly = "F2C08A",
			BellyDark = "E0A672",
			Ember = { "FF7A1A", Neon = true },
			EmberHot = { "FFC93C", Neon = true },
			White = "FFFFFF",
			Iris = "FF9A2E",
			Ink = "1A1033",
			Mouth = "3A1A14",
			Blush = "FF9D7A",
		},
		Joints = {
			Head = { 0, 1.2, -0.3 },
			LegFL = { 0.85, 0.9, -0.55 },
			LegFR = { -0.85, 0.9, -0.55 },
			LegBL = { 0.95, 0.85, 0.6 },
			LegBR = { -0.95, 0.85, 0.6 },
		},
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegFL", Color = "Belly", C = { 0.74, 0.08, -1.3 }, S = { 0.14, 0.14, 0.18 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Belly", C = { 0.98, 0.08, -1.34 }, S = { 0.14, 0.14, 0.18 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Belly", C = { 1.22, 0.08, -1.3 }, S = { 0.14, 0.14, 0.18 }, Mirror = true },
		},
	})
end

-- Lava Lagoon / Rare / four legs: low armoured lizard with rows of stone spikes with glowing tips, a glowing vent down
-- its spine, a horned snout and a spiked lava club tail.
do
	local BC, BR = { 0, 1.3, 0.45 }, { 1.25, 0.9, 1.55 }
	local S = {
		{ Group = "Body", Color = "Hide", Kind = "Ellipsoid", C = BC, R = BR },
		{ Group = "Body", Color = "Under", Kind = "Box", Paint = true, C = { 0, 0.6, 0.45 }, S = { 3, 0.5, 3.4 } },
		{ Group = "Body", Color = "HideDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.0, 0.45 }, R = { 0.9, 0.3, 1.4 } },
		{ Group = "Body", Color = "Lava", Kind = "Box", Paint = true, C = { 1.15, 1.35, 0.45 }, S = { 0.5, 0.2, 1.9 }, Rot = { 15, 0, 0 }, Mirror = true },
		-- head with a heavy brow and a nose horn
		{ Group = "Head", Color = "Hide", Kind = "Ellipsoid", C = { 0, 1.55, -1.5 }, R = { 0.9, 0.72, 0.75 } },
		{ Group = "Head", Color = "Hide", Kind = "Box", C = { 0, 1.25, -2.1 }, S = { 1.1, 0.55, 0.65 } },
		{ Group = "Head", Color = "Hide", Kind = "Ellipsoid", C = { 0, 1.28, -2.42 }, R = { 0.5, 0.26, 0.2 } },
		{ Group = "Head", Color = "Under", Kind = "Box", C = { 0, 0.95, -1.9 }, S = { 1.0, 0.3, 0.9 } },
		{ Group = "Head", Color = "Stone", Kind = "Ellipsoid", C = { 0.42, 2.12, -1.62 }, R = { 0.26, 0.14, 0.28 }, Mirror = true },
		{ Group = "Head", Color = "HideDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.15, -1.2 }, R = { 0.6, 0.18, 0.5 } },
		-- legs and clawed feet
		{ Group = "LegFL", Color = "Hide", Kind = "Capsule", A = { 0.78, 1.0, -0.65 }, B = { 0.82, 0.3, -0.7 }, RA = 0.36, RB = 0.3, Mirror = true },
		{ Group = "LegFL", Color = "HideDark", Kind = "Ellipsoid", C = { 0.82, 0.15, -0.85 }, R = { 0.38, 0.15, 0.44 }, Mirror = true },
		{ Group = "LegBL", Color = "Hide", Kind = "Capsule", A = { 0.78, 1.0, 1.45 }, B = { 0.82, 0.3, 1.5 }, RA = 0.38, RB = 0.32, Mirror = true },
		{ Group = "LegBL", Color = "HideDark", Kind = "Ellipsoid", C = { 0.82, 0.15, 1.35 }, R = { 0.38, 0.15, 0.44 }, Mirror = true },
		-- club tail: stone club with a glowing band and spikes
		{ Group = "Tail", Color = "Hide", Kind = "Capsule", A = { 0, 1.25, 1.95 }, B = { 0, 0.95, 2.85 }, RA = 0.48, RB = 0.3 },
		{ Group = "Tail", Color = "Stone", Kind = "Ellipsoid", C = { 0, 0.95, 3.25 }, R = { 0.58, 0.46, 0.52 } },
		{ Group = "Tail", Color = "StoneLight", Kind = "Ellipsoid", Paint = true, C = { 0, 1.22, 3.25 }, R = { 0.42, 0.16, 0.38 } },
		{ Group = "Tail", Color = "Lava", Kind = "Box", Paint = true, C = { 0, 0.95, 3.25 }, S = { 1.4, 0.2, 1.2 } },
		{ Group = "Tail", Color = "HideDark", Kind = "Box", Paint = true, C = { 0, 1.5, 2.35 }, S = { 1.2, 0.5, 0.2 } },
	}
	-- the glowing vent down the spine
	crack(S, "Body", dome(BC, BR), { { 0, -0.75 }, { 0, -0.2 }, { 0, 0.45 }, { 0, 1.1 }, { 0, 1.6 } }, 0.15, "Lava", "Hot")
	-- stone spikes either side of the vent, each with a glowing tip
	local surf = dome(BC, BR)
	for _, sp in { { 0.58, -0.4, 0.62 }, { 0.62, 0.45, 0.82 }, { 0.58, 1.25, 0.62 }, { 0.98, 0.05, 0.42 }, { 0.98, 0.85, 0.42 } } do
		for _, side in { 1, -1 } do
			local x, z, h = sp[1] * side, sp[2], sp[3]
			local base = Vector3.new(x, surf(x, z) - 0.1, z)
			local up = Vector3.new(0.25 * side, 1, 0).Unit
			table.insert(S, { Group = "Body", Color = "Stone", Kind = "Capsule", A = base, B = base + up * (h * 0.65), RA = 0.2, RB = 0.12 })
			table.insert(S, { Group = "Body", Color = "Lava", Kind = "Capsule", A = base + up * (h * 0.65), B = base + up * h, RA = 0.12, RB = 0.04 })
		end
	end
	-- nose horn, club spikes
	table.insert(S, { Group = "Head", Color = "Stone", Kind = "Capsule", A = { 0, 1.75, -2.2 }, B = { 0, 2.2, -2.35 }, RA = 0.18, RB = 0.1 })
	table.insert(S, { Group = "Head", Color = "Lava", Kind = "Capsule", A = { 0, 2.2, -2.35 }, B = { 0, 2.5, -2.4 }, RA = 0.1, RB = 0.04 })
	for _, d in { { 0, 1, 0 }, { 1, 0.2, 0 }, { -1, 0.2, 0 }, { 0, 0.3, 1 } } do
		local dir = Vector3.new(d[1], d[2], d[3]).Unit
		local base = Vector3.new(0, 0.95, 3.25) + dir * 0.4
		table.insert(S, { Group = "Tail", Color = "Stone", Kind = "Capsule", A = base, B = base + dir * 0.3, RA = 0.15, RB = 0.08 })
		table.insert(S, { Group = "Tail", Color = "Hot", Kind = "Capsule", A = base + dir * 0.3, B = base + dir * 0.44, RA = 0.08, RB = 0.03 })
	end
	local D = eyes({}, "Head", 0.36, 1.82, 0.58, 0.58, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Lava", X = 0.22, Y = 1.4, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 1.08, W = 0.95, H = 0.1, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "Claw", X = 0.3, Y = 0.98, W = 0.12, H = 0.14, D = 0.1, Mirror = true })
	specs.Scorchback = fine({
		Gait = "Crawl",
		Emotes = { "Look", "TailSwing" },
		Palette = {
			Hide = "6B4F3C",
			HideDark = "54402F",
			Under = "C9A27E",
			Stone = "3A302B",
			StoneLight = "564A42",
			Lava = { "FF7A1A", Neon = true },
			Hot = { "FFD23F", Neon = true },
			Claw = "E8D9C0",
			White = "FFFFFF",
			Iris = "FFB23F",
			Ink = "1A1033",
			Mouth = "2A1A14",
		},
		Joints = {
			Head = { 0, 1.4, -0.9 },
			LegFL = { 0.78, 1.0, -0.65 },
			LegFR = { -0.78, 1.0, -0.65 },
			LegBL = { 0.78, 1.0, 1.45 },
			LegBR = { -0.78, 1.0, 1.45 },
			Tail = { 0, 1.25, 1.9 },
		},
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 0.62, 0.1, -1.24 }, S = { 0.16, 0.18, 0.18 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 0.82, 0.1, -1.28 }, S = { 0.16, 0.18, 0.18 }, Mirror = true },
			{ Name = "Toe", Group = "LegFL", Color = "Claw", C = { 1.02, 0.1, -1.24 }, S = { 0.16, 0.18, 0.18 }, Mirror = true },
		},
	})
end

-- Lava Lagoon / Epic / ape: fire monkey with a crown of flame tongues for hair, burning fists and a flaming tail tip.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.85, 0.15 }, R = { 1.2, 1.1, 0.95 } },
		{ Group = "Body", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.3, 0.8 }, R = { 1.15, 0.95, 0.45 } },
		{ Group = "Body", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, -0.7 }, R = { 0.75, 0.8, 0.5 } },
		{ Group = "Body", Color = "FaceDark", Kind = "Ellipsoid", Paint = true, C = { 0, 1.15, -0.72 }, R = { 0.6, 0.18, 0.4 } },
		-- head: heart-shaped face, muzzle, heavy brow
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 3.35, -0.15 }, R = { 1.0, 0.9, 0.9 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = { 0, 3.55, 0.55 }, R = { 0.95, 0.8, 0.42 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0.3, 3.48, -0.85 }, R = { 0.42, 0.42, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", Paint = true, C = { 0, 3.1, -0.9 }, R = { 0.64, 0.5, 0.45 } },
		{ Group = "Head", Color = "Face", Kind = "Ellipsoid", C = { 0, 2.95, -0.98 }, R = { 0.6, 0.42, 0.42 } },
		{ Group = "Head", Color = "FaceLight", Kind = "Ellipsoid", Paint = true, C = { 0, 3.15, -1.25 }, R = { 0.42, 0.14, 0.22 } },
		{ Group = "Head", Color = "FurDark", Kind = "Ellipsoid", C = { 0, 3.9, -0.72 }, R = { 0.72, 0.13, 0.26 } },
		-- cupped ears
		{ Group = "EarL", Color = "Fur", Kind = "Ellipsoid", C = { 1.05, 3.4, -0.15 }, R = { 0.26, 0.42, 0.42 }, Mirror = true },
		{ Group = "EarL", Color = "FaceDark", Kind = "Ellipsoid", Paint = true, C = { 1.2, 3.4, -0.2 }, R = { 0.16, 0.3, 0.3 }, Mirror = true },
		{ Group = "EarL", Kind = "Ellipsoid", Carve = true, C = { 1.34, 3.4, -0.2 }, R = { 0.1, 0.24, 0.24 }, Mirror = true },
		-- arms with burning fists
		{ Group = "ArmL", Color = "Fur", Kind = "Capsule", A = { 1.1, 2.45, 0 }, B = { 1.4, 1.35, -0.25 }, RA = 0.42, RB = 0.36, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Capsule", Paint = true, A = { 1.3, 2.45, 0.25 }, B = { 1.6, 1.35, 0.0 }, R = 0.3, Mirror = true },
		{ Group = "ArmL", Color = "FurDark", Kind = "Ellipsoid", C = { 1.45, 0.78, -0.35 }, R = { 0.56, 0.54, 0.56 }, Mirror = true },
		{ Group = "ArmL", Color = "Flame", Kind = "Box", Paint = true, C = { 1.45, 0.9, -0.8 }, S = { 1.2, 0.45, 0.5 }, Mirror = true },
		{ Group = "ArmL", Color = "FlameHot", Kind = "Box", Paint = true, C = { 1.45, 0.9, -0.95 }, S = { 1.2, 0.25, 0.3 }, Mirror = true },
		-- legs, tan feet
		{ Group = "LegL", Color = "Fur", Kind = "Capsule", A = { 0.55, 1.0, 0.25 }, B = { 0.6, 0.45, 0.2 }, R = 0.42, Mirror = true },
		{ Group = "LegL", Color = "Face", Kind = "Ellipsoid", C = { 0.6, 0.2, -0.05 }, R = { 0.44, 0.2, 0.56 }, Mirror = true },
		-- curly tail
		{ Group = "Tail", Color = "Fur", Kind = "Capsule", A = { 0, 1.2, 0.95 }, B = { 0, 0.85, 1.6 }, RA = 0.22, RB = 0.2 },
		{ Group = "Tail", Color = "Fur", Kind = "Capsule", A = { 0, 0.85, 1.6 }, B = { 0, 1.75, 2.05 }, RA = 0.2, RB = 0.18 },
		{ Group = "Tail", Color = "Flame", Kind = "Ellipsoid", C = { 0, 2.05, 2.08 }, R = { 0.3, 0.32, 0.3 } },
	}
	-- a crown of flame tongues for hair
	for _, f in {
		{ Vector3.new(0, 4.05, -0.2), 1.05, 0.34, Vector3.new(0.05, 0, 0.12) },
		{ Vector3.new(0.45, 3.95, -0.1), 0.8, 0.27, Vector3.new(0.25, 0, 0.1) },
		{ Vector3.new(-0.45, 3.95, -0.05), 0.85, 0.27, Vector3.new(-0.25, 0, 0.12) },
		{ Vector3.new(0.2, 3.95, 0.35), 0.75, 0.25, Vector3.new(0.1, 0, 0.3) },
		{ Vector3.new(-0.25, 3.9, 0.4), 0.7, 0.24, Vector3.new(-0.12, 0, 0.3) },
		{ Vector3.new(0.75, 3.7, 0.15), 0.55, 0.2, Vector3.new(0.25, 0, 0.1) },
		{ Vector3.new(-0.75, 3.7, 0.15), 0.55, 0.2, Vector3.new(-0.25, 0, 0.1) },
	} do
		flame(S, "Head", f[1], f[2], f[3], f[4], "Flame", "FlameHot")
	end
	-- flames licking up off the fists and the tail tip
	for _, side in { 1, -1 } do
		local g = side > 0 and "ArmL" or "ArmR"
		flame(S, g, Vector3.new(1.45 * side, 1.15, -0.45), 0.55, 0.2, Vector3.new(0.05 * side, 0, 0.1), "Flame", "FlameHot")
		flame(S, g, Vector3.new(1.75 * side, 1.05, -0.2), 0.4, 0.15, Vector3.new(0.12 * side, 0, 0.1), "Flame", "FlameHot")
	end
	flame(S, "Tail", Vector3.new(0, 2.2, 2.08), 0.6, 0.24, Vector3.new(0, 0, -0.15), "Flame", "FlameHot")
	local D = eyes({}, "Head", 0.32, 3.5, 0.58, 0.62, "Iris")
	table.insert(D, { Name = "Brow", Group = "Head", Color = "FurDark", X = 0.36, Y = 3.92, W = 0.6, H = 0.16, D = 0.14, Tilt = 12, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "FurDark", X = 0.14, Y = 3.08, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.66, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.22, Y = 2.71, W = 0.15, H = 0.17, D = 0.12, Mirror = true })
	specs.BlazeBonkey = fine({
		Gait = "Knuckle",
		Emotes = { "Look", "ChestBeat", "Hop" },
		Palette = {
			Fur = "B5452A",
			FurDark = "8E321E",
			Face = "FFC98A",
			FaceLight = "FFDDB0",
			FaceDark = "EDA45C",
			Flame = { "FF6A14", Neon = true },
			FlameHot = { "FFC23A", Neon = true },
			White = "FFFFFF",
			Iris = "FF9A2E",
			Ink = "1A1033",
			Mouth = "4A1A14",
		},
		Joints = {
			Head = { 0, 2.75, -0.1 },
			EarL = { 0.95, 3.4, -0.15 },
			EarR = { -0.95, 3.4, -0.15 },
			ArmL = { 1.1, 2.5, 0 },
			ArmR = { -1.1, 2.5, 0 },
			LegL = { 0.55, 1.0, 0.2 },
			LegR = { -0.55, 1.0, 0.2 },
			Tail = { 0, 1.2, 0.9 },
		},
		Parents = { EarL = "Head", EarR = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.42, 0.1, -0.56 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.62, 0.1, -0.6 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "FaceDark", C = { 0.82, 0.1, -0.56 }, S = { 0.16, 0.2, 0.14 }, Mirror = true },
		},
	})
end

-- Lava Lagoon / Legendary / rex: obsidian tyrant with glowing lava cracks cut into its hide, curved horns, a molten
-- belly and blazing plates with white-hot tips.
do
	local BC, BR = { 0, 1.7, 0.25 }, { 1.25, 1.25, 1.1 }
	local HC, HR = { 0, 3.55, -0.35 }, { 1.15, 0.95, 1.0 }
	local S = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = BC, R = BR },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.25, 0.98 }, R = { 1.2, 1.15, 0.5 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.55, -0.42 }, R = { 0.9, 1.0, 0.6 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.9, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.3, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.7, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.1, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		-- head: long snout with a rounded tip, cheeks, molten jaw
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = HC, R = HR },
		{ Group = "Head", Color = "Body", Kind = "Box", C = { 0, 3.0, -1.4 }, S = { 1.35, 0.7, 1.4 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.0, -2.05 }, R = { 0.66, 0.36, 0.32 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.88, 3.15, -0.7 }, R = { 0.32, 0.3, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 4.15, 0.1 }, R = { 0.95, 0.42, 0.85 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Box", C = { 0, 2.6, -1.3 }, S = { 1.2, 0.4, 1.2 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Ellipsoid", C = { 0, 2.62, -1.88 }, R = { 0.55, 0.2, 0.26 } },
		{ Group = "Jaw", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.5, -1.5 }, S = { 1.4, 0.2, 1.4 } },
		-- curved horns sweeping back
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.62, 4.2, -0.35 }, B = { 0.85, 4.6, -0.1 }, RA = 0.2, RB = 0.15, Mirror = true },
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.85, 4.6, -0.1 }, B = { 1.02, 4.82, 0.3 }, RA = 0.15, RB = 0.1, Mirror = true },
		{ Group = "Head", Color = "HornTip", Kind = "Capsule", A = { 1.02, 4.82, 0.3 }, B = { 1.08, 4.85, 0.65 }, RA = 0.1, RB = 0.04, Mirror = true },
		-- legs, arms
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.78, 1.05, 0.25 }, B = { 0.8, 0.45, 0.05 }, RA = 0.64, RB = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Dark", Kind = "Ellipsoid", C = { 0.8, 0.2, -0.25 }, R = { 0.6, 0.2, 0.76 }, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 1.15, 2.05, -0.25 }, B = { 1.25, 1.6, -0.8 }, RA = 0.34, RB = 0.28, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Ellipsoid", C = { 1.27, 1.5, -0.98 }, R = { 0.26, 0.22, 0.24 }, Mirror = true },
		-- tail
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.1, 1.0 }, B = { 0, 0.7, 2.1 }, RA = 0.7, RB = 0.5 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.7, 2.1 }, B = { 0, 0.6, 3.0 }, RA = 0.5, RB = 0.3 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 3.0 }, B = { 0, 0.9, 3.4 }, RA = 0.3, RB = 0.2 },
	}
	-- lava cracks cut into the flanks, cheeks, thighs and tail
	for _, side in { 1, -1 } do
		crackOn(S, "Body", BC, BR, { { 1.0 * side, 2.55, 0.0 }, { 1.2 * side, 2.15, 0.35 }, { 1.1 * side, 1.75, 0.15 }, { 1.25 * side, 1.35, 0.5 }, { 1.0 * side, 0.95, 0.75 } }, 0.12, "Crack", "CrackHot")
		crackOn(S, "Body", BC, BR, { { 1.2 * side, 2.15, 0.35 }, { 0.9 * side, 2.3, 0.85 } }, 0.11, "Crack", "CrackHot")
		crackOn(S, "Head", HC, HR, { { 0.8 * side, 3.95, -0.9 }, { 1.05 * side, 3.55, -0.55 }, { 0.95 * side, 3.25, -0.2 } }, 0.11, "Crack", "CrackHot")
		local g = side > 0 and "LegL" or "LegR"
		crackOn(S, g, { 0.8 * side, 0.8, 0.15 }, { 0.62, 0.62, 0.62 }, { { 1.3 * side, 1.2, 0.0 }, { 1.4 * side, 0.85, 0.3 }, { 1.3 * side, 0.55, 0.1 } }, 0.1, "Crack", "CrackHot")
	end
	crackOn(S, "Tail", { 0, 0.85, 2.3 }, { 0.6, 0.6, 1.2 }, { { 0.0, 1.45, 1.6 }, { 0.25, 1.3, 2.1 }, { -0.1, 1.15, 2.6 }, { 0.1, 0.95, 3.1 } }, 0.11, "Crack", "CrackHot")
	-- blazing plates
	for _, p in {
		{ "Head", Vector3.new(0, 4.4, -0.4), Vector3.new(0, 1, 0.12), 0.72 },
		{ "Head", Vector3.new(0, 4.3, 0.22), Vector3.new(0, 0.9, 0.45), 0.56 },
		{ "Body", Vector3.new(0, 2.85, 0.95), Vector3.new(0, 0.8, 0.6), 0.95 },
		{ "Body", Vector3.new(0, 2.3, 1.25), Vector3.new(0, 0.6, 0.8), 0.8 },
		{ "Tail", Vector3.new(0, 1.5, 1.95), Vector3.new(0, 0.85, 0.5), 0.75 },
		{ "Tail", Vector3.new(0, 1.2, 2.6), Vector3.new(0, 0.8, 0.6), 0.6 },
		{ "Tail", Vector3.new(0, 1.02, 3.15), Vector3.new(0, 0.75, 0.65), 0.45 },
	} do
		plate(S, p[1], p[2], p[3], p[4], "Plate", "PlateHot")
	end
	local D = eyes({}, "Head", 0.52, 3.8, 0.78, 0.72, "Iris")
	table.insert(D, { Name = "Brow", Group = "Head", Color = "Brow", X = 0.52, Y = 4.27, W = 0.85, H = 0.2, D = 0.16, Tilt = 14, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Crack", X = 0.3, Y = 3.32, W = 0.12, H = 0.12, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.95, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.4, Y = 2.68, W = 0.2, H = 0.26, D = 0.12, Mirror = true })
	specs.MoltenRex = fine({
		Gait = "Biped",
		Emotes = { "Look", "Roar", "Wiggle" },
		Palette = {
			Body = "2E2424",
			Dark = "221B1B",
			Belly = "D9541E",
			BellyLine = "B5401A",
			Plate = { "FF5A1F", Neon = true },
			PlateHot = { "FFC93C", Neon = true },
			Crack = { "FF5A14", Neon = true },
			CrackHot = { "FFC23A", Neon = true },
			Horn = "E8D9C0",
			HornTip = "FFF6E6",
			Claw = "F2E6D0",
			White = "FFFFFF",
			Iris = "FF7A1A",
			Ink = "1A1033",
			Mouth = "120808",
			Brow = "120C0C",
		},
		Joints = {
			Head = { 0, 2.7, -0.3 },
			Jaw = { 0, 2.75, -0.7 },
			LegL = { 0.75, 1.0, 0.25 },
			LegR = { -0.75, 1.0, 0.25 },
			ArmL = { 1.15, 2.05, -0.25 },
			ArmR = { -1.15, 2.05, -0.25 },
			Tail = { 0, 1.1, 1.0 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.45, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.8, 0.13, -1.02 }, S = { 0.24, 0.26, 0.32 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.15, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.16, 1.4, -1.2 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.36, 1.4, -1.18 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
		},
	})
end

-- Lava Lagoon / Mythic / serpent: fire dragon on a jointed body chain (like the long dragons it's modelled on): banded
-- scales, a gold plated belly, two pairs of little clawed legs, a flame mane and spine, curved horns, glowing whiskers.
do
	local S = {
		-- body chain lying on the ground, thinning towards the tail
		{ Group = "Seg1", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 0.15 }, B = { 0, 0.6, 1.15 }, R = 0.6 },
		{ Group = "Seg2", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 1.15 }, B = { 0, 0.6, 2.15 }, RA = 0.58, RB = 0.52 },
		{ Group = "Seg3", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 2.15 }, B = { 0, 0.6, 3.1 }, RA = 0.52, RB = 0.45 },
		{ Group = "Seg4", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 3.1 }, B = { 0, 0.6, 3.95 }, RA = 0.45, RB = 0.38 },
		{ Group = "Tail", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 3.95 }, B = { 0, 0.5, 4.85 }, RA = 0.38, RB = 0.2 },
		-- neck rising at the front, gold belly scales down its front
		{ Group = "Neck", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 0 }, B = { 0, 1.45, -0.55 }, RA = 0.55, RB = 0.5 },
		{ Group = "Neck", Color = "Scale", Kind = "Capsule", A = { 0, 1.45, -0.55 }, B = { 0, 2.15, -1.0 }, RA = 0.5, RB = 0.45 },
		{ Group = "Neck", Color = "Belly", Kind = "Capsule", A = { 0, 0.7, -0.4 }, B = { 0, 1.4, -0.85 }, R = 0.32 },
		{ Group = "Neck", Color = "Belly", Kind = "Capsule", A = { 0, 1.4, -0.85 }, B = { 0, 1.95, -1.25 }, R = 0.3 },
		-- dragon head: skull, long snout with a rounded tip, gold jaw, brow ridges
		{ Group = "Head", Color = "Scale", Kind = "Ellipsoid", C = { 0, 2.55, -1.35 }, R = { 0.75, 0.62, 0.72 } },
		{ Group = "Head", Color = "Scale", Kind = "Box", C = { 0, 2.3, -2.0 }, S = { 0.95, 0.7, 0.8 } },
		{ Group = "Head", Color = "Scale", Kind = "Ellipsoid", C = { 0, 2.32, -2.42 }, R = { 0.48, 0.34, 0.24 } },
		{ Group = "Head", Color = "Belly", Kind = "Box", C = { 0, 1.85, -1.9 }, S = { 0.85, 0.3, 0.72 } },
		{ Group = "Head", Color = "ScaleDark", Kind = "Ellipsoid", C = { 0.32, 3.0, -1.55 }, R = { 0.28, 0.1, 0.24 }, Mirror = true },
		{ Group = "Head", Color = "ScaleDark", Kind = "Ellipsoid", Paint = true, C = { 0, 3.05, -1.1 }, R = { 0.6, 0.25, 0.5 } },
		-- curved horns
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.3, 3.0, -1.1 }, B = { 0.38, 3.4, -0.85 }, RA = 0.13, RB = 0.1, Mirror = true },
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.38, 3.4, -0.85 }, B = { 0.42, 3.55, -0.45 }, RA = 0.1, RB = 0.04, Mirror = true },
		-- glowing whiskers trailing from the snout
		{ Group = "Head", Color = "Whisker", Kind = "Capsule", A = { 0.42, 2.2, -2.4 }, B = { 0.85, 2.1, -2.2 }, R = 0.06, Mirror = true },
		{ Group = "Head", Color = "Whisker", Kind = "Capsule", A = { 0.85, 2.1, -2.2 }, B = { 1.15, 1.8, -1.85 }, R = 0.05, Mirror = true },
	}
	-- banded scales over the back, gold belly plates, the belly strip
	for _, z in { 0.35, 0.75, 1.15, 1.55, 1.95, 2.35, 2.75, 3.15, 3.55, 3.95, 4.35 } do
		local g = z < 1.15 and "Seg1" or z < 2.15 and "Seg2" or z < 3.1 and "Seg3" or z < 3.95 and "Seg4" or "Tail"
		table.insert(S, { Group = g, Color = "ScaleDark", Kind = "Box", Paint = true, C = { 0, 1.05, z }, S = { 1.6, 0.6, 0.2 } })
	end
	table.insert(S, { Group = "Seg1", Color = "Belly", Kind = "Box", Paint = true, C = { 0, 0.15, 2.6 }, S = { 1.6, 0.3, 5.8 } })
	for _, z in { 0.55, 1.35, 2.15, 2.95, 3.75 } do
		local g = z < 1.15 and "Seg1" or z < 2.15 and "Seg2" or z < 3.1 and "Seg3" or z < 3.95 and "Seg4" or "Tail"
		table.insert(S, { Group = g, Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.2, z }, S = { 1.6, 0.4, 0.2 } })
	end
	-- two pairs of little clawed legs that ride the wave
	for _, l in { { "Seg1", 0.75 }, { "Seg3", 2.6 } } do
		for _, side in { 1, -1 } do
			table.insert(S, { Group = l[1], Color = "Scale", Kind = "Capsule", A = { 0.4 * side, 0.55, l[2] }, B = { 0.78 * side, 0.3, l[2] - 0.15 }, RA = 0.17, RB = 0.13 })
			table.insert(S, { Group = l[1], Color = "Belly", Kind = "Ellipsoid", C = { 0.84 * side, 0.12, l[2] - 0.25 }, R = { 0.17, 0.12, 0.22 } })
		end
	end
	-- flame mane down the neck and a flame along the spine of every segment, a flaming tail tip
	for _, f in {
		{ "Head", Vector3.new(0, 3.0, -0.85), 0.62, 0.22, Vector3.new(0, 0, 0.3) },
		{ "Head", Vector3.new(0.3, 2.85, -0.75), 0.45, 0.17, Vector3.new(0.2, 0, 0.3) },
		{ "Head", Vector3.new(-0.3, 2.85, -0.75), 0.45, 0.17, Vector3.new(-0.2, 0, 0.3) },
		{ "Neck", Vector3.new(0, 2.25, -0.55), 0.55, 0.2, Vector3.new(0, 0, 0.35) },
		{ "Neck", Vector3.new(0, 1.65, -0.1), 0.5, 0.2, Vector3.new(0, 0, 0.35) },
		{ "Seg1", Vector3.new(0, 1.1, 0.65), 0.5, 0.2, Vector3.new(0, 0, 0.3) },
		{ "Seg2", Vector3.new(0, 1.05, 1.65), 0.48, 0.19, Vector3.new(0, 0, 0.3) },
		{ "Seg3", Vector3.new(0, 1.0, 2.6), 0.44, 0.18, Vector3.new(0, 0, 0.28) },
		{ "Seg4", Vector3.new(0, 0.92, 3.5), 0.4, 0.16, Vector3.new(0, 0, 0.25) },
		{ "Tail", Vector3.new(0, 0.55, 4.85), 0.6, 0.22, Vector3.new(0, 0.1, 0.35) },
	} do
		flame(S, f[1], f[2], f[3], f[4], f[5], "Flame", "FlameHot")
	end
	local D = eyes({}, "Head", 0.33, 2.95, 0.56, 0.48, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.22, Y = 2.5, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.0, W = 0.8, H = 0.1, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.28, Y = 1.9, W = 0.12, H = 0.16, D = 0.1, Mirror = true })
	specs.InfernoSerpent = fine({
		Gait = "Slither",
		Emotes = { "RearUp", "Look" },
		Palette = {
			Scale = "C2361F",
			ScaleDark = "9A2716",
			Belly = "F5B83D",
			BellyLine = "DB9A28",
			Flame = { "FF6A14", Neon = true },
			FlameHot = { "FFC23A", Neon = true },
			Whisker = { "FFB23F", Neon = true },
			Horn = "FFE9A8",
			Tongue = "FF3B5C",
			White = "FFFFFF",
			Iris = "FFB23F",
			Ink = "1A1033",
			Mouth = "3A0A0A",
		},
		Joints = {
			Neck = { 0, 0.6, -0.05 },
			Head = { 0, 2.15, -1.0 },
			Tongue = { 0, 2.0, -2.4 },
			Seg1 = { 0, 0.6, 0.15 },
			Seg2 = { 0, 0.6, 1.15 },
			Seg3 = { 0, 0.6, 2.15 },
			Seg4 = { 0, 0.6, 3.1 },
			Tail = { 0, 0.6, 3.95 },
		},
		Parents = { Head = "Neck", Tongue = "Head", Seg2 = "Seg1", Seg3 = "Seg2", Seg4 = "Seg3", Tail = "Seg4" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Tongue", Group = "Tongue", Color = "Tongue", C = { 0, 2.0, -2.35 }, S = { 0.12, 0.06, 0.5 } },
			{ Name = "Fork", Group = "Tongue", Color = "Tongue", C = { 0.07, 2.0, -2.62 }, S = { 0.06, 0.05, 0.16 }, Rot = { 0, -30, 0 } },
			{ Name = "Fork", Group = "Tongue", Color = "Tongue", C = { -0.07, 2.0, -2.62 }, S = { 0.06, 0.05, 0.16 }, Rot = { 0, 30, 0 } },
			{ Name = "Claw", Group = "Seg1", Color = "Horn", C = { 0.84, 0.06, 0.32 }, S = { 0.2, 0.12, 0.1 }, Mirror = true },
			{ Name = "Claw", Group = "Seg3", Color = "Horn", C = { 0.84, 0.06, 2.17 }, S = { 0.2, 0.12, 0.1 }, Mirror = true },
		},
	})
end

-- Frostfang Peaks / Common / four legs: fluffy snow puppy with floppy two-tone ears, blue paws, a striped scarf and fluff.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.15, 0.35 }, R = { 0.9, 0.8, 1.1 } },
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.2, -0.5 }, R = { 0.72, 0.62, 0.42 } },
		{ Group = "Body", Color = "FurShade", Kind = "Box", Paint = true, C = { 0, 0.55, 0.35 }, S = { 2.2, 0.4, 2.6 } },
		{ Group = "Body", Color = "FurShade", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, 0.85 }, R = { 0.7, 0.3, 0.7 } },
		-- chest fluff
		{ Group = "Body", Color = "Fluff", Kind = "Ellipsoid", C = { 0, 1.08, -0.82 }, R = { 0.42, 0.36, 0.2 } },
		{ Group = "Body", Color = "Fluff", Kind = "Ellipsoid", C = { 0.22, 0.88, -0.8 }, R = { 0.2, 0.2, 0.16 }, Mirror = true },
		-- a raised striped scarf
		{ Group = "Body", Color = "Scarf", Kind = "Ellipsoid", C = { 0, 1.52, -0.45 }, R = { 0.82, 0.2, 0.6 } },
		{ Group = "Body", Color = "ScarfDark", Kind = "Box", Paint = true, C = { 0, 1.52, -0.45 }, S = { 2, 0.2, 0.2 } },
		{ Group = "Body", Color = "ScarfDark", Kind = "Box", Paint = true, C = { 0, 1.52, -0.05 }, S = { 2, 0.2, 0.2 } },
		-- head: round, white muzzle, cheek fluff, floppy ears
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 2.2, -0.7 }, R = { 0.95, 0.85, 0.85 } },
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.9, -1.45 }, R = { 0.45, 0.34, 0.32 } },
		{ Group = "Head", Color = "Fluff", Kind = "Ellipsoid", C = { 0.62, 1.85, -1.05 }, R = { 0.3, 0.26, 0.28 }, Mirror = true },
		{ Group = "Head", Color = "FurShade", Kind = "Ellipsoid", Paint = true, C = { 0, 2.8, -0.3 }, R = { 0.75, 0.3, 0.55 } },
		{ Group = "Head", Color = "Fluff", Kind = "Capsule", A = { 0, 2.95, -0.75 }, B = { 0.05, 3.15, -0.9 }, RA = 0.16, RB = 0.07 },
		{ Group = "EarL", Color = "Blue", Kind = "Ellipsoid", C = { 0.86, 2.2, -0.55 }, R = { 0.2, 0.5, 0.32 }, Rot = { 0, 0, 14 }, Mirror = true },
		{ Group = "EarL", Color = "BlueLight", Kind = "Ellipsoid", Paint = true, C = { 0.86, 2.05, -0.78 }, R = { 0.22, 0.34, 0.12 }, Rot = { 0, 0, 14 }, Mirror = true },
		{ Group = "EarL", Color = "BlueDark", Kind = "Ellipsoid", Paint = true, C = { 0.9, 1.75, -0.55 }, R = { 0.24, 0.14, 0.34 }, Mirror = true },
		-- legs, round blue paws with toe lines
		{ Group = "LegFL", Color = "Fur", Kind = "Capsule", A = { 0.55, 0.8, -0.25 }, B = { 0.58, 0.3, -0.3 }, RA = 0.3, RB = 0.26, Mirror = true },
		{ Group = "LegFL", Color = "Blue", Kind = "Ellipsoid", C = { 0.58, 0.16, -0.42 }, R = { 0.3, 0.16, 0.36 }, Mirror = true },
		{ Group = "LegFL", Color = "BlueDark", Kind = "Box", Paint = true, C = { 0.58, 0.16, -0.72 }, S = { 0.2, 0.4, 0.2 }, Mirror = true },
		{ Group = "LegBL", Color = "Fur", Kind = "Capsule", A = { 0.55, 0.8, 0.95 }, B = { 0.58, 0.3, 1.0 }, RA = 0.32, RB = 0.28, Mirror = true },
		{ Group = "LegBL", Color = "Blue", Kind = "Ellipsoid", C = { 0.58, 0.16, 0.88 }, R = { 0.3, 0.16, 0.36 }, Mirror = true },
		-- fluffy tail with a blue tip
		{ Group = "Tail", Color = "Fur", Kind = "Ellipsoid", C = { 0, 1.75, 1.45 }, R = { 0.38, 0.5, 0.38 } },
		{ Group = "Tail", Color = "Blue", Kind = "Ellipsoid", C = { 0, 2.2, 1.25 }, R = { 0.32, 0.32, 0.32 } },
		{ Group = "Tail", Color = "BlueLight", Kind = "Ellipsoid", Paint = true, C = { 0, 2.42, 1.2 }, R = { 0.22, 0.12, 0.22 } },
	}
	local D = eyes({}, "Head", 0.38, 2.47, 0.6, 0.62, "Iris")
	table.insert(D, { Name = "Nose", Group = "Head", Color = "Nose", X = 0, Y = 2.02, W = 0.3, H = 0.2, D = 0.12 })
	table.insert(D, { Name = "Glint", Group = "Head", Color = "White", X = -0.06, Y = 2.07, W = 0.08, H = 0.06, D = 0.16 })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0.1, Y = 1.8, W = 0.2, H = 0.08, D = 0.07, Mirror = true })
	table.insert(D, { Name = "Tongue", Group = "Head", Color = "Tongue", X = 0.08, Y = 1.7, W = 0.16, H = 0.14, D = 0.1 })
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.66, Y = 2.02, W = 0.28, H = 0.16, D = 0.1, Mirror = true })
	specs.Snowpup = fine({
		Gait = "Trot",
		Emotes = { "Look", "PlayBow", "HopSpin" },
		Wag = true,
		Palette = {
			Fur = "F4FAFF",
			Fluff = "FFFFFF",
			FurShade = "D6E4F2",
			Blue = "8FD3FF",
			BlueLight = "B8E4FF",
			BlueDark = "6CB8EA",
			Scarf = "FF5A6E",
			ScarfDark = "D93A50",
			Nose = "2B3A6B",
			White = "FFFFFF",
			Iris = "4FA8FF",
			Ink = "1A1033",
			Mouth = "3A2A4A",
			Tongue = "FF8FAB",
			Blush = "FFB3C7",
		},
		Joints = {
			Head = { 0, 1.85, -0.4 },
			EarL = { 0.72, 2.7, -0.55 },
			EarR = { -0.72, 2.7, -0.55 },
			LegFL = { 0.55, 0.8, -0.25 },
			LegFR = { -0.55, 0.8, -0.25 },
			LegBL = { 0.55, 0.8, 0.95 },
			LegBR = { -0.55, 0.8, 0.95 },
			Tail = { 0, 1.5, 1.3 },
		},
		Parents = { EarL = "Head", EarR = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "ScarfEnd", Group = "Body", Color = "Scarf", C = { 0.42, 1.12, -1.0 }, S = { 0.3, 0.6, 0.12 }, Rot = { 0, 0, 8 } },
			{ Name = "ScarfEnd", Group = "Body", Color = "ScarfDark", C = { 0.42, 1.05, -1.01 }, S = { 0.31, 0.1, 0.13 }, Rot = { 0, 0, 8 } },
			{ Name = "ScarfEnd", Group = "Body", Color = "Scarf", C = { 0.62, 1.2, -0.95 }, S = { 0.26, 0.48, 0.12 }, Rot = { 0, 0, 22 } },
		},
	})
end

-- Frostfang Peaks / Uncommon / crab: ice-blue crab with a frosty rim, frost speckles and a big ice crystal cluster.
do
	local SC, SR = { 0, 1.1, 0.15 }, { 1.45, 0.68, 1.15 }
	local S = {
		{ Group = "Body", Color = "Shell", Kind = "Ellipsoid", C = SC, R = SR },
		{ Group = "Body", Color = "Rim", Kind = "Box", Paint = true, C = { 0, 0.95, 0.15 }, S = { 3.2, 0.2, 2.6 } },
		{ Group = "Body", Color = "ShellDark", Kind = "Box", Paint = true, C = { 0, 0.6, 0.15 }, S = { 3.2, 0.5, 2.6 } },
		{ Group = "Body", Color = "ShellLight", Kind = "Ellipsoid", Paint = true, C = { 0, 1.75, 0.15 }, R = { 1.0, 0.12, 0.8 } },
		-- claws: shell arm, a pincer that opens, frosty tips
		{ Group = "ClawL", Color = "Shell", Kind = "Capsule", A = { 1.05, 0.95, -0.55 }, B = { 1.5, 0.85, -1.05 }, RA = 0.28, RB = 0.24, Mirror = true },
		{ Group = "ClawL", Color = "Claw", Kind = "Ellipsoid", C = { 1.6, 0.88, -1.4 }, R = { 0.42, 0.36, 0.4 }, Mirror = true },
		{ Group = "ClawL", Color = "ShellLight", Kind = "Ellipsoid", Paint = true, C = { 1.6, 1.14, -1.4 }, R = { 0.3, 0.12, 0.3 }, Mirror = true },
		{ Group = "ClawL", Color = "Claw", Kind = "Capsule", A = { 1.6, 1.04, -1.68 }, B = { 1.57, 1.14, -2.08 }, RA = 0.21, RB = 0.12, Mirror = true },
		{ Group = "ClawL", Color = "Claw", Kind = "Capsule", A = { 1.6, 0.72, -1.68 }, B = { 1.61, 0.66, -2.0 }, RA = 0.18, RB = 0.1, Mirror = true },
		{ Group = "ClawL", Color = "Rim", Kind = "Box", Paint = true, C = { 1.6, 0.9, -2.05 }, S = { 0.8, 1.0, 0.3 }, Mirror = true },
		-- eyes on stalks
		{ Group = "EyeL", Color = "Shell", Kind = "Capsule", A = { 0.45, 1.6, -0.68 }, B = { 0.47, 2.12, -0.72 }, RA = 0.12, RB = 0.1, Mirror = true },
		{ Group = "EyeL", Color = "White", Kind = "Ellipsoid", C = { 0.47, 2.35, -0.74 }, R = { 0.3, 0.3, 0.28 }, Mirror = true },
	}
	for _, l in { { "LegAL", -0.35, -0.5 }, { "LegBL", 0.2, 0.2 }, { "LegCL", 0.75, 0.9 } } do
		table.insert(S, { Group = l[1], Color = "Shell", Kind = "Capsule", A = { 1.2, 0.8, l[2] }, B = { 1.78, 0.62, l[3] }, RA = 0.15, RB = 0.12, Mirror = true })
		table.insert(S, { Group = l[1], Color = "Rim", Kind = "Capsule", A = { 1.78, 0.62, l[3] }, B = { 1.92, 0.08, l[3] }, RA = 0.12, RB = 0.06, Mirror = true })
	end
	-- frost speckles
	local surf = dome(SC, SR)
	for _, p in { { 0.75, -0.25 }, { -0.85, 0.65 }, { 0.95, 0.75 }, { -0.6, -0.4 }, { 0.2, 1.0 }, { -1.15, 0.05 } } do
		table.insert(S, { Group = "Body", Color = "Rim", Kind = "Ellipsoid", Paint = true, C = { p[1], surf(p[1], p[2]), p[2] }, R = { 0.17, 0.12, 0.17 } })
	end
	-- the ice crystal cluster
	for _, c in {
		{ Vector3.new(0.12, 1.6, 0.35), Vector3.new(-0.08, 1, 0), 0.42, 1.25, "Crystal" },
		{ Vector3.new(-0.32, 1.55, 0.55), Vector3.new(-0.35, 1, 0.15), 0.34, 0.95, "CrystalDeep" },
		{ Vector3.new(0.5, 1.5, 0.72), Vector3.new(0.5, 1, 0.15), 0.3, 0.8, "Crystal" },
		{ Vector3.new(-0.08, 1.55, -0.08), Vector3.new(-0.3, 1, -0.3), 0.28, 0.65, "CrystalDeep" },
		{ Vector3.new(0.5, 1.5, 0.0), Vector3.new(0.55, 1, -0.2), 0.24, 0.5, "CrystalDeep" },
		{ Vector3.new(-0.55, 1.45, 0.95), Vector3.new(-0.4, 1, 0.4), 0.24, 0.5, "Crystal" },
	} do
		crystal(S, "Body", c[1], c[2], c[3], c[4], c[5], "Crystal")
	end
	local D = {
		{ Name = "Iris", Group = "EyeL", Color = "Iris", X = 0.45, Y = 2.33, W = 0.38, H = 0.4, D = 0.12, Mirror = true },
		{ Name = "Pupil", Group = "EyeL", Color = "Ink", X = 0.44, Y = 2.31, W = 0.26, H = 0.3, D = 0.14, Mirror = true },
		{ Name = "Glint", Group = "EyeL", Color = "White", X = 0.38, Y = 2.41, W = 0.1, H = 0.1, D = 0.18, Mirror = true },
		{ Name = "Mouth", Group = "Body", Color = "Mouth", X = 0, Y = 1.02, W = 0.5, H = 0.1, D = 0.07 },
		{ Name = "Blush", Group = "Body", Color = "Blush", X = 0.55, Y = 1.18, W = 0.28, H = 0.14, D = 0.1, Mirror = true },
	}
	specs.GlacierCrab = fine({
		Gait = "Scuttle",
		Emotes = { "ClawSnap", "Look", "Wiggle" },
		Palette = {
			Shell = "5DB6F0",
			ShellDark = "438FD0",
			ShellLight = "86CBF6",
			Rim = "E6F7FF",
			Crystal = "E8FBFF",
			CrystalDeep = "A8ECFF",
			Claw = "3F8FEA",
			White = "FFFFFF",
			Iris = "2F7FD6",
			Ink = "1A1033",
			Mouth = "2B3A6B",
			Blush = "FFB3C7",
		},
		Joints = {
			EyeL = { 0.45, 1.65, -0.7 },
			EyeR = { -0.45, 1.65, -0.7 },
			ClawL = { 1.05, 0.95, -0.55 },
			ClawR = { -1.05, 0.95, -0.55 },
			LegAL = { 1.2, 0.75, -0.35 },
			LegAR = { -1.2, 0.75, -0.35 },
			LegBL = { 1.2, 0.75, 0.2 },
			LegBR = { -1.2, 0.75, 0.2 },
			LegCL = { 1.2, 0.75, 0.75 },
			LegCR = { -1.2, 0.75, 0.75 },
		},
		Shapes = S,
		Details = D,
	})
end

-- Frostfang Peaks / Rare / four legs: armoured rhino with raised frost plates, a glowing ice horn and ice spikes.
do
	local BC, BR = { 0, 1.5, 0.4 }, { 1.2, 1.0, 1.45 }
	local S = {
		{ Group = "Body", Color = "Hide", Kind = "Ellipsoid", C = BC, R = BR },
		{ Group = "Body", Color = "HideDark", Kind = "Box", Paint = true, C = { 0, 0.75, 0.4 }, S = { 2.6, 0.4, 3 } },
		-- raised armour bands
		{ Group = "Body", Color = "Plate", Kind = "Ellipsoid", C = BC, R = { 1.3, 1.1, 1.55 }, Within = { Kind = "Box", C = { 0, 2.0, -0.1 }, S = { 3, 1.6, 0.6 } } },
		{ Group = "Body", Color = "Plate", Kind = "Ellipsoid", C = BC, R = { 1.3, 1.1, 1.55 }, Within = { Kind = "Box", C = { 0, 2.0, 0.8 }, S = { 3, 1.6, 0.6 } } },
		{ Group = "Body", Color = "PlateShade", Kind = "Box", Paint = true, C = { 0, 1.3, 0.35 }, S = { 3, 0.2, 2.2 } },
		-- head: snout, forehead plate, ears
		{ Group = "Head", Color = "Hide", Kind = "Ellipsoid", C = { 0, 1.65, -1.3 }, R = { 0.82, 0.75, 0.72 } },
		{ Group = "Head", Color = "Hide", Kind = "Box", C = { 0, 1.35, -1.95 }, S = { 1.05, 0.7, 0.6 } },
		{ Group = "Head", Color = "Hide", Kind = "Ellipsoid", C = { 0, 1.35, -2.24 }, R = { 0.5, 0.34, 0.2 } },
		{ Group = "Head", Color = "Plate", Kind = "Ellipsoid", C = { 0, 1.65, -1.3 }, R = { 0.9, 0.83, 0.8 }, Within = { Kind = "Box", C = { 0, 2.4, -1.3 }, S = { 1.4, 0.5, 1.0 } } },
		{ Group = "EarL", Color = "Hide", Kind = "Ellipsoid", C = { 0.62, 2.4, -1.1 }, R = { 0.16, 0.24, 0.13 }, Rot = { 0, 0, -20 }, Mirror = true },
		{ Group = "EarL", Color = "Pink", Kind = "Ellipsoid", Paint = true, C = { 0.62, 2.4, -1.2 }, R = { 0.1, 0.16, 0.06 }, Rot = { 0, 0, -20 }, Mirror = true },
		-- ice horn, glowing
		{ Group = "Head", Color = "Ice", Kind = "Capsule", A = { 0, 1.85, -2.05 }, B = { 0, 2.45, -2.3 }, RA = 0.22, RB = 0.12 },
		{ Group = "Head", Color = "IceHot", Kind = "Capsule", A = { 0, 2.45, -2.3 }, B = { 0, 2.78, -2.36 }, RA = 0.12, RB = 0.04 },
		{ Group = "Head", Color = "IceSoft", Kind = "Capsule", A = { 0, 2.0, -1.6 }, B = { 0, 2.35, -1.7 }, RA = 0.16, RB = 0.05 },
		-- legs with plate cuffs and hooves
		{ Group = "LegFL", Color = "Hide", Kind = "Capsule", A = { 0.65, 1.05, -0.45 }, B = { 0.68, 0.35, -0.5 }, RA = 0.42, RB = 0.38, Mirror = true },
		{ Group = "LegFL", Color = "Plate", Kind = "Ellipsoid", C = { 0.68, 0.52, -0.5 }, R = { 0.46, 0.12, 0.46 }, Mirror = true },
		{ Group = "LegFL", Color = "Hoof", Kind = "Box", C = { 0.68, 0.18, -0.55 }, S = { 0.82, 0.36, 0.82 }, Mirror = true },
		{ Group = "LegBL", Color = "Hide", Kind = "Capsule", A = { 0.65, 1.05, 1.25 }, B = { 0.68, 0.35, 1.25 }, RA = 0.44, RB = 0.4, Mirror = true },
		{ Group = "LegBL", Color = "Plate", Kind = "Ellipsoid", C = { 0.68, 0.52, 1.25 }, R = { 0.48, 0.12, 0.48 }, Mirror = true },
		{ Group = "LegBL", Color = "Hoof", Kind = "Box", C = { 0.68, 0.18, 1.2 }, S = { 0.82, 0.36, 0.82 }, Mirror = true },
		{ Group = "Tail", Color = "Hide", Kind = "Capsule", A = { 0, 1.7, 1.8 }, B = { 0, 1.3, 2.1 }, R = 0.2 },
		{ Group = "Tail", Color = "IceSoft", Kind = "Ellipsoid", C = { 0, 1.15, 2.2 }, R = { 0.26, 0.3, 0.26 } },
	}
	-- ice spikes along the back
	for _, sp in { { -0.05, 0.65 }, { 0.8, 0.75 }, { 1.5, 0.5 } } do
		local z = sp[1]
		local y = BC[2] + BR[2] * math.sqrt(math.max(0, 1 - ((z - BC[3]) / BR[3]) ^ 2)) + 0.05
		crystal(S, "Body", Vector3.new(0, y - 0.12, z), Vector3.new(0, 1, 0.15), 0.3, sp[2], "IceSoft", "Ice")
	end
	local D = eyes({}, "Head", 0.36, 1.95, 0.52, 0.55, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "HideDark", X = 0.25, Y = 1.5, W = 0.14, H = 0.12, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 1.15, W = 0.7, H = 0.1, D = 0.07 })
	table.insert(D, { Name = "Blush", Group = "Head", Color = "Blush", X = 0.6, Y = 1.62, W = 0.26, H = 0.15, D = 0.1, Mirror = true })
	specs.Frostrhino = fine({
		Gait = "Trot",
		Emotes = { "Look", "Paw", "Wiggle" },
		Palette = {
			Hide = "B8C8D8",
			HideDark = "93A6BA",
			Plate = "EEF7FF",
			PlateShade = "D2E2F0",
			Ice = { "5AD4FF", Neon = true },
			IceHot = { "A8F0FF", Neon = true },
			IceSoft = "BDEFFF",
			Hoof = "5C6B80",
			Pink = "F2B8C6",
			White = "FFFFFF",
			Iris = "4FA8E8",
			Ink = "1A1033",
			Mouth = "2B3A6B",
			Blush = "FFB3C7",
		},
		Joints = {
			Head = { 0, 1.6, -0.7 },
			EarL = { 0.55, 2.2, -1.1 },
			EarR = { -0.55, 2.2, -1.1 },
			LegFL = { 0.65, 1.05, -0.45 },
			LegFR = { -0.65, 1.05, -0.45 },
			LegBL = { 0.65, 1.05, 1.25 },
			LegBR = { -0.65, 1.05, 1.25 },
			Tail = { 0, 1.7, 1.75 },
		},
		Parents = { EarL = "Head", EarR = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Nail", Group = "LegFL", Color = "Plate", C = { 0.48, 0.12, -0.98 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegFL", Color = "Plate", C = { 0.88, 0.12, -0.98 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegBL", Color = "Plate", C = { 0.48, 0.12, 0.78 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
			{ Name = "Nail", Group = "LegBL", Color = "Plate", C = { 0.88, 0.12, 0.78 }, S = { 0.2, 0.2, 0.1 }, Mirror = true },
		},
	})
end

-- Frostfang Peaks / Epic / ape: shaggy white yeti gorilla with a blue face and chest, an icicle crown, ice shards on
-- its shoulders and frozen fists.
do
	local S = {
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 0, 2.0, 0.15 }, R = { 1.35, 1.25, 1.05 } },
		{ Group = "Body", Color = "Skin", Kind = "Ellipsoid", Paint = true, C = { 0, 1.9, -0.75 }, R = { 0.9, 0.9, 0.55 } },
		{ Group = "Body", Color = "SkinDark", Kind = "Box", Paint = true, C = { 0, 1.3, -0.9 }, S = { 1.6, 0.2, 0.6 } },
		{ Group = "Body", Color = "FurShade", Kind = "Box", Paint = true, C = { 0, 0.95, 0.15 }, S = { 3, 0.4, 2.4 } },
		{ Group = "Body", Color = "FurShade", Kind = "Ellipsoid", Paint = true, C = { 0, 2.5, 0.9 }, R = { 1.2, 1.0, 0.42 } },
		{ Group = "Body", Color = "Fur", Kind = "Ellipsoid", C = { 1.15, 2.9, 0.1 }, R = { 0.45, 0.4, 0.5 }, Mirror = true },
		-- shaggy tufts on the shoulders and flanks
		{ Group = "Body", Color = "Fluff", Kind = "Capsule", A = { 1.0, 2.6, 0.45 }, B = { 1.45, 2.5, 0.75 }, RA = 0.22, RB = 0.05, Mirror = true },
		{ Group = "Body", Color = "Fur", Kind = "Capsule", A = { 1.15, 2.05, 0.45 }, B = { 1.55, 1.85, 0.7 }, RA = 0.2, RB = 0.05, Mirror = true },
		{ Group = "Body", Color = "Fluff", Kind = "Capsule", A = { 1.1, 1.5, 0.35 }, B = { 1.45, 1.25, 0.55 }, RA = 0.18, RB = 0.04, Mirror = true },
		-- head: blue face, muzzle, heavy white brow
		{ Group = "Head", Color = "Fur", Kind = "Ellipsoid", C = { 0, 3.75, -0.3 }, R = { 1.05, 0.95, 0.95 } },
		{ Group = "Head", Color = "FurShade", Kind = "Ellipsoid", Paint = true, C = { 0, 4.05, 0.4 }, R = { 1.0, 0.7, 0.45 } },
		{ Group = "Head", Color = "Skin", Kind = "Ellipsoid", Paint = true, C = { 0, 3.6, -1.05 }, R = { 0.78, 0.72, 0.5 } },
		{ Group = "Head", Color = "SkinLight", Kind = "Ellipsoid", C = { 0, 3.3, -1.1 }, R = { 0.6, 0.42, 0.38 } },
		{ Group = "Head", Color = "SkinPale", Kind = "Ellipsoid", Paint = true, C = { 0, 3.48, -1.42 }, R = { 0.4, 0.12, 0.2 } },
		{ Group = "Head", Color = "Fluff", Kind = "Ellipsoid", C = { 0, 4.2, -1.0 }, R = { 0.88, 0.18, 0.26 } },
		{ Group = "Head", Color = "Fluff", Kind = "Ellipsoid", C = { 0.82, 3.35, -0.75 }, R = { 0.26, 0.32, 0.3 }, Mirror = true },
		-- arms with frozen fists
		{ Group = "ArmL", Color = "Fur", Kind = "Capsule", A = { 1.3, 2.75, 0 }, B = { 1.65, 1.45, -0.3 }, RA = 0.52, RB = 0.45, Mirror = true },
		{ Group = "ArmL", Color = "Fluff", Kind = "Ellipsoid", C = { 1.8, 1.85, 0.05 }, R = { 0.36, 0.32, 0.36 }, Mirror = true },
		{ Group = "ArmL", Color = "Skin", Kind = "Ellipsoid", C = { 1.7, 0.82, -0.45 }, R = { 0.62, 0.56, 0.62 }, Mirror = true },
		{ Group = "ArmL", Color = "Ice", Kind = "Box", Paint = true, C = { 1.7, 0.95, -0.9 }, S = { 1.3, 0.45, 0.6 }, Mirror = true },
		{ Group = "ArmL", Color = "IceDeep", Kind = "Box", Paint = true, C = { 1.5, 0.95, -0.95 }, S = { 0.2, 0.45, 0.5 }, Mirror = true },
		{ Group = "ArmL", Color = "IceDeep", Kind = "Box", Paint = true, C = { 1.9, 0.95, -0.95 }, S = { 0.2, 0.45, 0.5 }, Mirror = true },
		{ Group = "LegL", Color = "Fur", Kind = "Capsule", A = { 0.62, 1.15, 0.3 }, B = { 0.66, 0.5, 0.25 }, R = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Skin", Kind = "Ellipsoid", C = { 0.66, 0.2, -0.02 }, R = { 0.5, 0.2, 0.64 }, Mirror = true },
	}
	-- an icicle crown, ice shards on the shoulders and the fists
	for _, c in {
		{ "Head", Vector3.new(0, 4.5, -0.35), Vector3.new(0, 1, 0.05), 0.32, 0.85, "Ice" },
		{ "Head", Vector3.new(0.42, 4.4, -0.3), Vector3.new(0.4, 1, 0), 0.26, 0.65, "IceDeep" },
		{ "Head", Vector3.new(-0.42, 4.4, -0.3), Vector3.new(-0.4, 1, 0), 0.26, 0.65, "IceDeep" },
		{ "Head", Vector3.new(0.75, 4.2, -0.2), Vector3.new(0.8, 1, 0), 0.22, 0.48, "Ice" },
		{ "Head", Vector3.new(-0.75, 4.2, -0.2), Vector3.new(-0.8, 1, 0), 0.22, 0.48, "Ice" },
		{ "Body", Vector3.new(1.25, 3.15, 0.15), Vector3.new(0.6, 1, 0), 0.26, 0.6, "IceDeep" },
		{ "Body", Vector3.new(-1.25, 3.15, 0.15), Vector3.new(-0.6, 1, 0), 0.26, 0.6, "IceDeep" },
		{ "Body", Vector3.new(1.0, 3.2, 0.5), Vector3.new(0.4, 1, 0.3), 0.22, 0.48, "Ice" },
		{ "Body", Vector3.new(-1.0, 3.2, 0.5), Vector3.new(-0.4, 1, 0.3), 0.22, 0.48, "Ice" },
		{ "ArmL", Vector3.new(1.7, 1.2, -0.3), Vector3.new(0.3, 1, 0.2), 0.2, 0.42, "Ice" },
		{ "ArmR", Vector3.new(-1.7, 1.2, -0.3), Vector3.new(-0.3, 1, 0.2), 0.2, 0.42, "Ice" },
	} do
		crystal(S, c[1], c[2], c[3], c[4], c[5], c[6], c[6])
	end
	local D = eyes({}, "Head", 0.36, 3.8, 0.58, 0.58, "Iris")
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Skin", X = 0.16, Y = 3.45, W = 0.12, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 3.12, W = 0.8, H = 0.14, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.25, Y = 3.0, W = 0.16, H = 0.2, D = 0.12, Mirror = true })
	specs.Brrrilla = fine({
		Gait = "Knuckle",
		Emotes = { "Look", "ChestBeat", "Hop" },
		Palette = {
			Fur = "EAF2FA",
			Fluff = "FFFFFF",
			FurShade = "CCDBEC",
			Skin = "5AA9FF",
			SkinDark = "4893E6",
			SkinLight = "8CC4FF",
			SkinPale = "B3D8FF",
			Ice = { "7ADCFF", Neon = true },
			IceDeep = { "3EBCF2", Neon = true },
			White = "FFFFFF",
			Iris = "3E9BEA",
			Ink = "1A1033",
			Mouth = "1E2A55",
		},
		Joints = {
			Head = { 0, 3.0, -0.2 },
			ArmL = { 1.3, 2.8, 0 },
			ArmR = { -1.3, 2.8, 0 },
			LegL = { 0.62, 1.15, 0.25 },
			LegR = { -0.62, 1.15, 0.25 },
		},
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "SkinLight", C = { 0.42, 0.1, -0.64 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "SkinLight", C = { 0.66, 0.1, -0.68 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "SkinLight", C = { 0.9, 0.1, -0.64 }, S = { 0.18, 0.2, 0.16 }, Mirror = true },
		},
	})
end

-- Frostfang Peaks / Legendary / rex: ice tyrant with a snow cap, clusters of glowing ice crystals along the spine and
-- tail, crystal horns and a frosty belly.
do
	local S = {
		{ Group = "Body", Color = "Body", Kind = "Ellipsoid", C = { 0, 1.7, 0.25 }, R = { 1.25, 1.25, 1.1 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 0, 2.2, 0.98 }, R = { 1.2, 1.1, 0.5 } },
		{ Group = "Body", Color = "Frost", Kind = "Ellipsoid", Paint = true, C = { 0, 2.95, 0.45 }, R = { 1.15, 0.36, 0.95 } },
		{ Group = "Body", Color = "Belly", Kind = "Ellipsoid", C = { 0, 1.55, -0.42 }, R = { 0.9, 1.0, 0.6 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.9, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.3, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 1.7, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.1, -0.95 }, S = { 2.2, 0.2, 1.0 } },
		{ Group = "Body", Color = "Dark", Kind = "Ellipsoid", Paint = true, C = { 1.05, 1.55, 0.6 }, R = { 0.28, 0.26, 0.28 }, Mirror = true },
		-- head: snow cap, long snout with nostril bumps, cheeks, frosty jaw
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.55, -0.35 }, R = { 1.15, 0.95, 1.0 } },
		{ Group = "Head", Color = "Body", Kind = "Box", C = { 0, 3.0, -1.4 }, S = { 1.35, 0.7, 1.4 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0, 3.0, -2.05 }, R = { 0.66, 0.36, 0.32 } },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.3, 3.38, -1.95 }, R = { 0.13, 0.09, 0.13 }, Mirror = true },
		{ Group = "Head", Color = "Body", Kind = "Ellipsoid", C = { 0.88, 3.15, -0.7 }, R = { 0.32, 0.3, 0.42 }, Mirror = true },
		{ Group = "Head", Color = "Frost", Kind = "Ellipsoid", C = { 0, 4.32, -0.3 }, R = { 1.08, 0.36, 0.98 } },
		{ Group = "Head", Color = "FrostShade", Kind = "Box", Paint = true, C = { 0, 4.05, -0.3 }, S = { 2.4, 0.2, 2.2 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Box", C = { 0, 2.6, -1.3 }, S = { 1.2, 0.4, 1.2 } },
		{ Group = "Jaw", Color = "Belly", Kind = "Ellipsoid", C = { 0, 2.62, -1.88 }, R = { 0.55, 0.2, 0.26 } },
		{ Group = "Jaw", Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 2.5, -1.5 }, S = { 1.4, 0.2, 1.4 } },
		-- legs, arms
		{ Group = "LegL", Color = "Body", Kind = "Capsule", A = { 0.78, 1.05, 0.25 }, B = { 0.8, 0.45, 0.05 }, RA = 0.64, RB = 0.5, Mirror = true },
		{ Group = "LegL", Color = "Dark", Kind = "Ellipsoid", C = { 0.8, 0.2, -0.25 }, R = { 0.6, 0.2, 0.76 }, Mirror = true },
		{ Group = "LegL", Color = "Frost", Kind = "Ellipsoid", Paint = true, C = { 0.8, 1.3, 0.25 }, R = { 0.6, 0.22, 0.6 }, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Capsule", A = { 1.15, 2.05, -0.25 }, B = { 1.25, 1.6, -0.8 }, RA = 0.34, RB = 0.28, Mirror = true },
		{ Group = "ArmL", Color = "Body", Kind = "Ellipsoid", C = { 1.27, 1.5, -0.98 }, R = { 0.26, 0.22, 0.24 }, Mirror = true },
		-- tail with frosty bands
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 1.1, 1.0 }, B = { 0, 0.7, 2.1 }, RA = 0.7, RB = 0.5 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.7, 2.1 }, B = { 0, 0.6, 3.0 }, RA = 0.5, RB = 0.3 },
		{ Group = "Tail", Color = "Body", Kind = "Capsule", A = { 0, 0.6, 3.0 }, B = { 0, 0.9, 3.4 }, RA = 0.3, RB = 0.2 },
		{ Group = "Tail", Color = "Frost", Kind = "Box", Paint = true, C = { 0, 1.35, 2.0 }, S = { 1.6, 0.4, 1.4 } },
		{ Group = "Tail", Color = "Frost", Kind = "Box", Paint = true, C = { 0, 1.05, 2.9 }, S = { 1.2, 0.3, 0.6 } },
	}
	for _, c in {
		{ "Head", Vector3.new(0, 4.5, -0.25), Vector3.new(0, 1, -0.05), 0.38, 1.0, "Crystal" },
		{ "Head", Vector3.new(0.32, 4.45, 0.05), Vector3.new(0.45, 1, 0.1), 0.28, 0.7, "CrystalDeep" },
		{ "Head", Vector3.new(-0.32, 4.45, 0.05), Vector3.new(-0.45, 1, 0.1), 0.28, 0.7, "CrystalDeep" },
		{ "Head", Vector3.new(0.72, 4.25, -0.35), Vector3.new(0.7, 1, 0.25), 0.22, 0.62, "Crystal" },
		{ "Head", Vector3.new(-0.72, 4.25, -0.35), Vector3.new(-0.7, 1, 0.25), 0.22, 0.62, "Crystal" },
		{ "Body", Vector3.new(0, 3.05, 0.9), Vector3.new(0, 1, 0.3), 0.44, 1.2, "Crystal" },
		{ "Body", Vector3.new(0.35, 2.95, 1.05), Vector3.new(0.45, 1, 0.3), 0.32, 0.82, "CrystalDeep" },
		{ "Body", Vector3.new(-0.35, 2.95, 1.05), Vector3.new(-0.45, 1, 0.3), 0.32, 0.82, "CrystalDeep" },
		{ "Body", Vector3.new(0, 2.55, 1.35), Vector3.new(0, 0.8, 0.6), 0.3, 0.7, "Crystal" },
		{ "Tail", Vector3.new(0, 1.55, 2.1), Vector3.new(0, 1, 0.4), 0.38, 0.95, "Crystal" },
		{ "Tail", Vector3.new(0.25, 1.45, 2.3), Vector3.new(0.45, 1, 0.3), 0.26, 0.6, "CrystalDeep" },
		{ "Tail", Vector3.new(-0.25, 1.45, 2.3), Vector3.new(-0.45, 1, 0.3), 0.26, 0.6, "CrystalDeep" },
		{ "Tail", Vector3.new(0, 1.12, 3.1), Vector3.new(0, 1, 0.5), 0.28, 0.62, "Crystal" },
	} do
		crystal(S, c[1], c[2], c[3], c[4], c[5], c[6], c[6])
	end
	local D = eyes({}, "Head", 0.52, 3.8, 0.78, 0.72, "Iris")
	table.insert(D, { Name = "Brow", Group = "Head", Color = "Brow", X = 0.52, Y = 4.27, W = 0.85, H = 0.18, D = 0.16, Tilt = 12, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.3, Y = 3.32, W = 0.12, H = 0.12, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.82, W = 0.95, H = 0.12, D = 0.07 })
	table.insert(D, { Name = "Fang", Group = "Head", Color = "White", X = 0.4, Y = 2.68, W = 0.2, H = 0.26, D = 0.12, Mirror = true })
	specs.IcebreakerRex = fine({
		Gait = "Biped",
		Emotes = { "Look", "Roar", "Wiggle" },
		Palette = {
			Body = "6FA8DC",
			Dark = "5A92C8",
			Belly = "DFF6FF",
			BellyLine = "BFE6F7",
			Frost = "F4FBFF",
			FrostShade = "D8ECFA",
			Crystal = { "6FE6FF", Neon = true },
			CrystalDeep = { "36B8F2", Neon = true },
			Claw = "E6F7FF",
			White = "FFFFFF",
			Iris = "3FB0F2",
			Ink = "1A1033",
			Mouth = "1E2A55",
			Brow = "2E5A8C",
		},
		Joints = {
			Head = { 0, 2.7, -0.3 },
			Jaw = { 0, 2.75, -0.7 },
			LegL = { 0.75, 1.0, 0.25 },
			LegR = { -0.75, 1.0, 0.25 },
			ArmL = { 1.15, 2.05, -0.25 },
			ArmR = { -1.15, 2.05, -0.25 },
			Tail = { 0, 1.1, 1.0 },
		},
		Parents = { Jaw = "Head" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.45, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 0.8, 0.13, -1.02 }, S = { 0.24, 0.26, 0.32 }, Mirror = true },
			{ Name = "Toe", Group = "LegL", Color = "Claw", C = { 1.15, 0.13, -0.98 }, S = { 0.24, 0.26, 0.3 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.16, 1.4, -1.2 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
			{ Name = "Claw", Group = "ArmL", Color = "Claw", C = { 1.36, 1.4, -1.18 }, S = { 0.12, 0.16, 0.16 }, Mirror = true },
		},
	})
end

-- Frostfang Peaks / Mythic / serpent: night-sky dragon on a jointed body chain: starry scales, a pale belly, glowing
-- aurora fins along the spine, antennae with glowing tips, aurora whiskers and two pairs of little legs.
do
	local S = {
		{ Group = "Seg1", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 0.15 }, B = { 0, 0.6, 1.15 }, R = 0.6 },
		{ Group = "Seg2", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 1.15 }, B = { 0, 0.6, 2.15 }, RA = 0.58, RB = 0.52 },
		{ Group = "Seg3", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 2.15 }, B = { 0, 0.6, 3.1 }, RA = 0.52, RB = 0.45 },
		{ Group = "Seg4", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 3.1 }, B = { 0, 0.6, 3.95 }, RA = 0.45, RB = 0.38 },
		{ Group = "Tail", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 3.95 }, B = { 0, 0.5, 4.85 }, RA = 0.38, RB = 0.2 },
		{ Group = "Neck", Color = "Scale", Kind = "Capsule", A = { 0, 0.6, 0 }, B = { 0, 1.45, -0.55 }, RA = 0.55, RB = 0.5 },
		{ Group = "Neck", Color = "Scale", Kind = "Capsule", A = { 0, 1.45, -0.55 }, B = { 0, 2.15, -1.0 }, RA = 0.5, RB = 0.45 },
		{ Group = "Neck", Color = "Belly", Kind = "Capsule", A = { 0, 0.7, -0.4 }, B = { 0, 1.4, -0.85 }, R = 0.32 },
		{ Group = "Neck", Color = "Belly", Kind = "Capsule", A = { 0, 1.4, -0.85 }, B = { 0, 1.95, -1.25 }, R = 0.3 },
		-- head: round skull, snout with a rounded tip, pale jaw, brow ridges
		{ Group = "Head", Color = "Scale", Kind = "Ellipsoid", C = { 0, 2.55, -1.3 }, R = { 0.78, 0.66, 0.74 } },
		{ Group = "Head", Color = "Scale", Kind = "Box", C = { 0, 2.3, -1.95 }, S = { 0.85, 0.7, 0.7 } },
		{ Group = "Head", Color = "Scale", Kind = "Ellipsoid", C = { 0, 2.32, -2.32 }, R = { 0.44, 0.34, 0.22 } },
		{ Group = "Head", Color = "Belly", Kind = "Box", C = { 0, 1.85, -1.85 }, S = { 0.8, 0.3, 0.66 } },
		{ Group = "Head", Color = "ScaleDark", Kind = "Ellipsoid", C = { 0.32, 3.02, -1.5 }, R = { 0.28, 0.1, 0.24 }, Mirror = true },
		{ Group = "Head", Color = "ScaleDark", Kind = "Ellipsoid", Paint = true, C = { 0, 3.05, -1.05 }, R = { 0.6, 0.25, 0.5 } },
		-- antennae with glowing tips, aurora whiskers
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.28, 3.0, -1.2 }, B = { 0.4, 3.45, -1.3 }, RA = 0.08, RB = 0.06, Mirror = true },
		{ Group = "Head", Color = "Horn", Kind = "Capsule", A = { 0.4, 3.45, -1.3 }, B = { 0.5, 3.62, -1.48 }, RA = 0.06, RB = 0.05, Mirror = true },
		{ Group = "Head", Color = "Aurora3", Kind = "Ellipsoid", C = { 0.52, 3.68, -1.52 }, R = { 0.13, 0.13, 0.13 }, Mirror = true },
		{ Group = "Head", Color = "Aurora2", Kind = "Capsule", A = { 0.4, 2.2, -2.3 }, B = { 0.82, 2.1, -2.1 }, R = 0.06, Mirror = true },
		{ Group = "Head", Color = "Aurora1", Kind = "Capsule", A = { 0.82, 2.1, -2.1 }, B = { 1.1, 1.8, -1.75 }, R = 0.05, Mirror = true },
		-- split tail fin
		{ Group = "Tail", Color = "Aurora1", Kind = "Capsule", A = { 0, 0.55, 4.8 }, B = { 0, 1.05, 5.15 }, RA = 0.16, RB = 0.05 },
		{ Group = "Tail", Color = "Aurora3", Kind = "Capsule", A = { 0, 0.5, 4.8 }, B = { 0, 0.2, 5.2 }, RA = 0.14, RB = 0.05 },
	}
	-- banded scales, the pale belly with plate lines, star speckles
	for _, z in { 0.35, 0.75, 1.15, 1.55, 1.95, 2.35, 2.75, 3.15, 3.55, 3.95, 4.35 } do
		local g = z < 1.15 and "Seg1" or z < 2.15 and "Seg2" or z < 3.1 and "Seg3" or z < 3.95 and "Seg4" or "Tail"
		table.insert(S, { Group = g, Color = "ScaleDark", Kind = "Box", Paint = true, C = { 0, 1.05, z }, S = { 1.6, 0.6, 0.2 } })
	end
	table.insert(S, { Group = "Seg1", Color = "Belly", Kind = "Box", Paint = true, C = { 0, 0.15, 2.6 }, S = { 1.6, 0.3, 5.8 } })
	for _, z in { 0.55, 1.35, 2.15, 2.95, 3.75 } do
		local g = z < 1.15 and "Seg1" or z < 2.15 and "Seg2" or z < 3.1 and "Seg3" or z < 3.95 and "Seg4" or "Tail"
		table.insert(S, { Group = g, Color = "BellyLine", Kind = "Box", Paint = true, C = { 0, 0.2, z }, S = { 1.6, 0.4, 0.2 } })
	end
	for _, st in { { 0.42, 0.95, 0.5 }, { -0.45, 0.85, 1.0 }, { 0.35, 1.05, 1.8 }, { -0.4, 0.95, 2.45 }, { 0.42, 0.85, 3.0 }, { -0.3, 0.95, 3.6 }, { 0.3, 0.85, 4.25 }, { 0.38, 1.55, -0.35 }, { -0.32, 1.9, -0.7 }, { 0.42, 2.85, -1.0 } } do
		local g = st[3] < 0 and (st[2] > 2.5 and "Head" or "Neck") or st[3] < 1.15 and "Seg1" or st[3] < 2.15 and "Seg2" or st[3] < 3.1 and "Seg3" or st[3] < 3.95 and "Seg4" or "Tail"
		table.insert(S, { Group = g, Color = "Star", Kind = "Ellipsoid", Paint = true, C = st, R = { 0.12, 0.12, 0.12 } })
	end
	-- two pairs of little legs that ride the wave
	for _, l in { { "Seg1", 0.75 }, { "Seg3", 2.6 } } do
		for _, side in { 1, -1 } do
			table.insert(S, { Group = l[1], Color = "Scale", Kind = "Capsule", A = { 0.4 * side, 0.55, l[2] }, B = { 0.78 * side, 0.3, l[2] - 0.15 }, RA = 0.17, RB = 0.13 })
			table.insert(S, { Group = l[1], Color = "Belly", Kind = "Ellipsoid", C = { 0.84 * side, 0.12, l[2] - 0.25 }, R = { 0.17, 0.12, 0.22 } })
		end
	end
	-- glowing aurora fins along the spine, one per segment so they ride the wave
	for i, p in {
		{ "Head", Vector3.new(0, 3.05, -0.95), Vector3.new(0, 1, 0.2), 0.62 },
		{ "Neck", Vector3.new(0, 2.25, -0.55), Vector3.new(0, 0.8, 0.6), 0.58 },
		{ "Neck", Vector3.new(0, 1.6, -0.1), Vector3.new(0, 0.85, 0.5), 0.58 },
		{ "Seg1", Vector3.new(0, 1.12, 0.65), Vector3.new(0, 1, 0.35), 0.6 },
		{ "Seg2", Vector3.new(0, 1.08, 1.65), Vector3.new(0, 1, 0.35), 0.58 },
		{ "Seg3", Vector3.new(0, 1.0, 2.6), Vector3.new(0, 1, 0.35), 0.52 },
		{ "Seg4", Vector3.new(0, 0.92, 3.5), Vector3.new(0, 1, 0.35), 0.45 },
	} do
		local deep = ({ "Aurora1", "Aurora2", "Aurora3" })[(i - 1) % 3 + 1]
		local tip = ({ "Aurora2", "Aurora3", "Aurora1" })[(i - 1) % 3 + 1]
		plate(S, p[1], p[2], p[3], p[4], deep, tip)
	end
	local D = eyes({}, "Head", 0.34, 2.95, 0.58, 0.52, "Iris")
	table.insert(D, { Name = "Cheek", Group = "Head", Color = "Aurora3", X = 0.44, Y = 2.5, W = 0.14, H = 0.14, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Nostril", Group = "Head", Color = "Ink", X = 0.2, Y = 2.5, W = 0.1, H = 0.1, D = 0.1, Mirror = true })
	table.insert(D, { Name = "Mouth", Group = "Head", Color = "Mouth", X = 0, Y = 2.0, W = 0.7, H = 0.1, D = 0.07 })
	specs.AuroraSerpent = fine({
		Gait = "Slither",
		Emotes = { "RearUp", "Look" },
		Palette = {
			Scale = "3B4FA8",
			ScaleDark = "2E3F8E",
			Belly = "9BB0FF",
			BellyLine = "8195EA",
			Star = "FFFFFF",
			Aurora1 = { "4BF0A0", Neon = true },
			Aurora2 = { "3EC2FF", Neon = true },
			Aurora3 = { "B866FF", Neon = true },
			Horn = "E6F0FF",
			Tongue = "FF8FD8",
			White = "FFFFFF",
			Iris = "4BD8C0",
			Ink = "1A1033",
			Mouth = "141A40",
		},
		Joints = {
			Neck = { 0, 0.6, -0.05 },
			Head = { 0, 2.15, -1.0 },
			Tongue = { 0, 2.0, -2.3 },
			Seg1 = { 0, 0.6, 0.15 },
			Seg2 = { 0, 0.6, 1.15 },
			Seg3 = { 0, 0.6, 2.15 },
			Seg4 = { 0, 0.6, 3.1 },
			Tail = { 0, 0.6, 3.95 },
		},
		Parents = { Head = "Neck", Tongue = "Head", Seg2 = "Seg1", Seg3 = "Seg2", Seg4 = "Seg3", Tail = "Seg4" },
		Shapes = S,
		Details = D,
		Bits = {
			{ Name = "Tongue", Group = "Tongue", Color = "Tongue", C = { 0, 2.0, -2.25 }, S = { 0.12, 0.06, 0.5 } },
			{ Name = "Fork", Group = "Tongue", Color = "Tongue", C = { 0.07, 2.0, -2.52 }, S = { 0.06, 0.05, 0.16 }, Rot = { 0, -30, 0 } },
			{ Name = "Fork", Group = "Tongue", Color = "Tongue", C = { -0.07, 2.0, -2.52 }, S = { 0.06, 0.05, 0.16 }, Rot = { 0, 30, 0 } },
			{ Name = "Claw", Group = "Seg1", Color = "Horn", C = { 0.84, 0.06, 0.32 }, S = { 0.2, 0.12, 0.1 }, Mirror = true },
			{ Name = "Claw", Group = "Seg3", Color = "Horn", C = { 0.84, 0.06, 2.17 }, S = { 0.2, 0.12, 0.1 }, Mirror = true },
		},
	})
end

return specs
