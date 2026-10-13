-- Pebble Plains egg family (merged into Tools.BiomeArtSpecs; built by Tools.BiomeArtBuilder.BuildEgg(biome, rarity)).
-- One design per rarity, themed on the kaiju that hatches at that rarity, more ornate as rarity rises:
--   Common     Pebble egg (Pebblesaur / Chompling): cream shell, mossy cap, pebbles, a sprout
--   Uncommon   Bonkey egg: brown fur, heart face, round ears, hair tuft, a bonked bump with a bandage
--   Rare       Tuskit egg: big floppy ears, trunk, tusks, blue stripes
--   Epic       Rumblerex egg: green scales, a chomping lid of teeth, horns, a crest of glowing purple plates
--   Legendary  Thunderback egg: storm fur, glowing lightning cracks, a thundercloud crown that throws bolts
--   Mythic     Boulderback egg (the biome's guardian): rocky shell with glowing purple cracks, crystal cluster
--   Secret     Prismling egg: pearl shell, a crown of rainbow crystals, sparkles, flowers in the leaves
-- Family look: a cradle of leaves round the base and a glowing yellow diamond gem on the front, framed by parts named
-- "Band" that Lib.EggModel tints with the rarity colour (Legendary+ frames grow rays). Clean voxels (no studs), 0.1 studs.
-- The shell fills EggConfig.Size (2.2 x 2.8 x 2.2); ornaments may stick out. Front = -Z, bottom at y = 0.
-- Angles round the egg: a = 0 is the front, + towards +X (the egg's left, the viewer's left).
local specs = {}

local VOXEL = 0.1
local rad, deg = math.rad, math.deg

-- radius of the shell (union of two ellipsoids) at height y
local function radii(y)
	local r1 = 1.1 * math.sqrt(math.max(0, 1 - ((y - 1.3) / 1.3) ^ 2))
	local r2 = 0.92 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.25) ^ 2))
	return r1, r2
end

local function surface(y)
	return math.max(radii(y))
end

-- point on (or `out` studs off) the shell at height y and angle a
local function at(a, y, out)
	local r = surface(y) + (out or 0)
	return Vector3.new(math.sin(a) * r, y, -math.cos(a) * r)
end

-- degrees the shell's normal leans away from straight up at height y (0 = top, 90 = sideways, >90 = underside)
local function normalTilt(y)
	local r1, r2 = radii(y)
	local h, v
	if r1 >= r2 then
		h, v = r1 / 1.21, (y - 1.3) / 1.69
	else
		h, v = r2 / 0.8464, (y - 1.55) / 1.5625
	end
	return deg(math.atan2(h, v))
end

local function eul(cf)
	local x, y, z = cf:ToOrientation()
	return { deg(x), deg(y), deg(z) }
end

-- orientation whose +Y leans `tilt` degrees outwards at angle a, spun `spin` degrees about itself, then `extra`
local function lean(a, tilt, spin, extra)
	return eul(CFrame.Angles(0, -a, 0) * CFrame.Angles(rad(-tilt), 0, 0) * CFrame.Angles(0, rad(spin or 0), 0) * (extra or CFrame.identity))
end

-- the up axis of lean(a, tilt)
local function leanUp(a, tilt)
	local o = Vector3.new(math.sin(a), 0, -math.cos(a))
	return Vector3.yAxis * math.cos(rad(tilt)) + o * math.sin(rad(tilt))
end

-- shell + baked shading: darker base, a soft highlight up on the viewer's left
local function shellShapes(base, dark, light)
	return {
		{ Group = "Shell", Color = base, Kind = "Ellipsoid", C = { 0, 1.3, 0 }, R = { 1.1, 1.3, 1.1 } },
		{ Group = "Shell", Color = base, Kind = "Ellipsoid", C = { 0, 1.55, 0 }, R = { 0.92, 1.25, 0.92 } },
		{ Group = "Shell", Color = dark, Kind = "Box", C = { 0, 0.22, 0 }, S = { 3, 0.44, 3 }, Paint = true },
		{ Group = "Shell", Color = light, Kind = "Ellipsoid", C = at(0.75, 2.05, 0.05), R = { 0.34, 0.42, 0.34 }, Paint = true },
	}
end

local function add(list, items)
	for _, i in items do
		table.insert(list, i)
	end
end

-- a neon (or plain) crack painted along the shell through {a, y} points
local function crack(shapes, points, color, width)
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		table.insert(shapes, { Group = "Shell", Color = color, Kind = "Capsule", A = at(p[1], p[2], 0.03), B = at(q[1], q[2], 0.03), R = width or 0.075, Paint = true })
	end
end

-- a cradle of pointed leaves round the base: tall leaves with a light vein, short dark ones between
local function leafCradle(bits, n)
	n = n or 9
	local r = surface(0.2)
	for k = 0, n * 2 - 1 do
		local a = (k + 0.5) / (n * 2) * math.pi * 2
		local o = Vector3.new(math.sin(a), 0, -math.cos(a))
		local tall = k % 2 == 0
		local tilt = tall and (36 + (k % 4) * 3) or 58
		local up = leanUp(a, tilt)
		local base = Vector3.new(0, 0.05, 0) + o * (r - 0.08)
		local w, h, tip = 0.36, 0.34, 0.25
		local color = (k % 4 == 0) and "Leaf" or "LeafDark"
		if not tall then
			w, h, tip, color = 0.28, 0.22, 0.2, "LeafDeep"
		end
		table.insert(bits, { Name = "Leaf", Group = "Leaves", Color = color, C = base + up * (h / 2), S = { w, h, 0.07 }, Rot = lean(a, tilt) })
		table.insert(bits, { Name = "Leaf", Group = "Leaves", Color = color, C = base + up * (h + tip * 0.12), S = { tip, tip, 0.07 }, Rot = lean(a, tilt, 0, CFrame.Angles(0, 0, rad(45))) })
		if tall then
			table.insert(bits, { Name = "Leaf", Group = "Leaves", Color = "LeafLight", C = base + up * (h * 0.6) + o * 0.012, S = { 0.06, h * 0.9, 0.08 }, Rot = lean(a, tilt) })
		end
	end
end

-- sprout on the top: a stem and two leaves
local function sprout(bits, top)
	table.insert(bits, { Name = "Stem", Group = "Sprout", Color = "Stem", C = { 0, top + 0.1, 0 }, S = { 0.09, 0.26, 0.09 } })
	table.insert(bits, { Name = "Leaf", Group = "Sprout", Color = "Leaf", C = { 0.17, top + 0.25, 0 }, S = { 0.32, 0.06, 0.2 }, Rot = { 0, 0, 25 } })
	table.insert(bits, { Name = "Leaf", Group = "Sprout", Color = "LeafLight", C = { 0.17, top + 0.28, 0 }, S = { 0.2, 0.06, 0.08 }, Rot = { 0, 0, 25 } })
	table.insert(bits, { Name = "Leaf", Group = "Sprout", Color = "LeafDark", C = { -0.15, top + 0.21, 0.02 }, S = { 0.28, 0.06, 0.18 }, Rot = { 0, 0, -30 } })
end

-- z of the shell's front at (x, y)
local function frontZ(x, y)
	return -math.sqrt(math.max(0, surface(y) ^ 2 - x * x))
end

-- the glowing diamond gem on the front, framed by a rarity-tinted "Band" diamond (+ four rays for the top rarities)
local function gem(bits, y, s, rays)
	local z = frontZ(0, y)
	table.insert(bits, { Name = "Band", Group = "Gem", Color = "Band", C = { 0, y, z - 0.02 }, S = { 0.58 * s, 0.58 * s, 0.1 }, Rot = { 0, 0, 45 } })
	table.insert(bits, { Name = "Gem", Group = "Gem", Color = "Gem", C = { 0, y, z - 0.07 }, S = { 0.42 * s, 0.42 * s, 0.1 }, Rot = { 0, 0, 45 } })
	table.insert(bits, { Name = "Gem", Group = "Gem", Color = "GemDeep", C = { 0, y - 0.07 * s, z - 0.1 }, S = { 0.2 * s, 0.2 * s, 0.06 }, Rot = { 0, 0, 45 } })
	table.insert(bits, { Name = "GemCore", Group = "Gem", Color = "GemCore", C = { 0.05 * s, y + 0.07 * s, z - 0.12 }, S = { 0.12 * s, 0.12 * s, 0.05 }, Rot = { 0, 0, 45 } })
	if rays then
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local x, yy = d[1] * 0.5 * s, y + d[2] * 0.5 * s
			table.insert(bits, { Name = "Band", Group = "Gem", Color = "Band", C = { x, yy, frontZ(x, yy) - 0.02 }, S = { 0.17 * s, 0.17 * s, 0.1 }, Rot = { 0, 0, 45 } })
		end
	end
end

local FAMILY = {
	Leaf = "62C23C",
	LeafDark = "48A52E",
	LeafDeep = "37862A",
	LeafLight = "9BE36A",
	Stem = "4A8A2A",
	Gem = { "FFE14D", Neon = true },
	GemDeep = { "FFB21F", Neon = true },
	GemCore = { "FFFDF0", Neon = true },
	Band = "B8C0CC",
}

local function finish(shapes, bits, own, shellKey)
	leafCradle(bits)
	local p = table.clone(FAMILY)
	for k, v in own do
		p[k] = v
	end
	return {
		Voxel = VOXEL,
		NoStuds = true,
		ShellColor = own[shellKey],
		Palette = p,
		Shapes = shapes,
		Bits = bits,
	}
end

-- golden-angle scatter over a height range, skipping the gem's patch on the front
local function scatter(n, y0, y1, avoid)
	local out = {}
	local k = 0
	while #out < n and k < n * 4 do
		local a = (k * 2.39996) % (math.pi * 2)
		local y = y0 + ((k * 0.618034) % 1) * (y1 - y0)
		local da = math.abs(((a + math.pi) % (math.pi * 2)) - math.pi)
		if not (avoid and da < avoid[1] and math.abs(y - avoid[2]) < avoid[3]) then
			table.insert(out, { a, y, k })
		end
		k += 1
	end
	return out
end

-- ---------- Common: Pebble egg ----------
do
	local shapes = shellShapes("Cream", "CreamShade", "CreamLight")
	add(shapes, {
		{ Group = "Shell", Color = "Moss", Kind = "Ellipsoid", C = { 0, 2.8, 0 }, R = { 1.0, 0.46, 1.0 }, Paint = true },
		{ Group = "Shell", Color = "MossLight", Kind = "Ellipsoid", C = at(0.7, 2.55, 0.02), R = { 0.2, 0.14, 0.2 }, Paint = true },
	})
	for k = 0, 8 do
		local a = k / 9 * math.pi * 2 + 0.3
		table.insert(shapes, { Group = "Shell", Color = "Moss", Kind = "Ellipsoid", C = at(a, 2.3 - (k % 3) * 0.1), R = { 0.17, 0.26 + (k % 2) * 0.06, 0.17 }, Paint = true })
	end
	local tones = { "Pebble", "PebbleDark", "PebbleLight" }
	for i, p in scatter(12, 0.55, 2.0, { 0.55, 1.25, 0.45 }) do
		local s = 0.14 + (i % 3) * 0.03
		table.insert(shapes, { Group = "Shell", Color = tones[i % 3 + 1], Kind = "Ellipsoid", C = at(p[1], p[2], -0.03), R = { s, s * 0.8, s } })
	end
	local bits = {}
	gem(bits, 1.25, 0.9)
	sprout(bits, 2.8)
	specs.Egg_PebblePlains_Common = finish(shapes, bits, {
		Cream = "FFF1D2",
		CreamShade = "EAD6AA",
		CreamLight = "FFFAEC",
		Moss = "86C653",
		MossLight = "A9DD78",
		Pebble = "B7B9C4",
		PebbleDark = "8E91A0",
		PebbleLight = "DCDEE6",
	}, "Cream")
end

-- ---------- Uncommon: Bonkey egg ----------
do
	local shapes = shellShapes("Fur", "FurDark", "FurLight")
	add(shapes, {
		-- heart-shaped face with a muzzle
		{ Group = "Shell", Color = "Face", Kind = "Ellipsoid", C = { 0.3, 1.66, -0.9 }, R = { 0.4, 0.4, 0.4 }, Paint = true },
		{ Group = "Shell", Color = "Face", Kind = "Ellipsoid", C = { -0.3, 1.66, -0.9 }, R = { 0.4, 0.4, 0.4 }, Paint = true },
		{ Group = "Shell", Color = "Face", Kind = "Ellipsoid", C = { 0, 1.14, -0.95 }, R = { 0.54, 0.6, 0.4 }, Paint = true },
		{ Group = "Shell", Color = "FaceDark", Kind = "Ellipsoid", C = { 0, 0.82, -1.0 }, R = { 0.34, 0.16, 0.3 }, Paint = true },
		-- round ears facing forwards, pale insides
		{ Group = "Ears", Color = "Fur", Kind = "Ellipsoid", C = { 1.0, 2.05, 0.08 }, R = { 0.37, 0.37, 0.17 }, Mirror = true },
		{ Group = "Ears", Color = "Face", Kind = "Ellipsoid", C = { 1.03, 2.03, -0.07 }, R = { 0.22, 0.22, 0.06 }, Paint = true, Mirror = true },
		-- the bonked bump
		{ Group = "Shell", Color = "Bump", Kind = "Ellipsoid", C = at(-0.62, 2.25, -0.06), R = { 0.21, 0.21, 0.21 } },
	})
	local bits = {}
	gem(bits, 1.3, 0.85)
	-- hair tuft
	for _, t in { { 0, 0, 0.42 }, { 0, 32, 0.32 }, { math.pi / 2, 34, 0.3 }, { -math.pi / 2, 34, 0.3 }, { math.pi, 32, 0.3 } } do
		local up = leanUp(t[1], t[2])
		table.insert(bits, { Name = "Hair", Group = "Hair", Color = t[2] == 0 and "Hair" or "HairDark", C = Vector3.new(0, 2.74, 0) + up * (t[3] / 2), S = { 0.15, t[3], 0.15 }, Rot = lean(t[1], t[2], 45) })
	end
	-- bandage cross over the bump
	local tilt = normalTilt(2.25)
	local bump = at(-0.62, 2.25, 0.12)
	table.insert(bits, { Name = "Bandage", Group = "Hair", Color = "Bandage", C = bump, S = { 0.46, 0.05, 0.12 }, Rot = lean(-0.62, tilt, 45) })
	table.insert(bits, { Name = "Bandage", Group = "Hair", Color = "Bandage", C = bump + leanUp(-0.62, tilt) * 0.01, S = { 0.46, 0.05, 0.12 }, Rot = lean(-0.62, tilt, -45) })
	specs.Egg_PebblePlains_Uncommon = finish(shapes, bits, {
		Fur = "A0703F",
		FurDark = "7A5230",
		FurLight = "B88752",
		Face = "FFD9A0",
		FaceDark = "E8B878",
		Hair = "5E3D22",
		HairDark = "4A2F1A",
		Bump = "FF9DBB",
		Bandage = "FFF6E6",
	}, "Fur")
end

-- ---------- Rare: Tuskit egg ----------
do
	local shapes = shellShapes("Fur", "FurDark", "FurLight")
	add(shapes, {
		{ Group = "Shell", Color = "Stripe", Kind = "Box", C = { 0, 2.36, 0 }, S = { 3, 0.1, 3 }, Paint = true },
		{ Group = "Shell", Color = "Stripe", Kind = "Box", C = { 0, 2.6, 0 }, S = { 3, 0.1, 3 }, Paint = true },
		{ Group = "Shell", Color = "Face", Kind = "Ellipsoid", C = { 0, 1.35, -0.95 }, R = { 0.5, 0.62, 0.35 }, Paint = true },
		-- big floppy ears with pink insides
		{ Group = "Ears", Color = "Fur", Kind = "Ellipsoid", C = { 1.02, 1.6, 0.12 }, R = { 0.56, 0.68, 0.16 }, Mirror = true },
		{ Group = "Ears", Color = "FurDark", Kind = "Ellipsoid", C = { 1.12, 1.6, 0.12 }, R = { 0.5, 0.64, 0.2 }, Carve = false, Paint = true, Mirror = true },
		{ Group = "Ears", Color = "Pink", Kind = "Ellipsoid", C = { 1.06, 1.6, -0.04 }, R = { 0.4, 0.52, 0.06 }, Paint = true, Mirror = true },
		-- trunk hanging down the front and curling out at the tip
		{ Group = "Trunk", Color = "Face", Kind = "Capsule", A = { 0, 1.12, -1.0 }, B = { 0, 0.78, -1.14 }, RA = 0.17, RB = 0.15 },
		{ Group = "Trunk", Color = "Face", Kind = "Capsule", A = { 0, 0.78, -1.14 }, B = { 0, 0.52, -1.24 }, RA = 0.15, RB = 0.13 },
		{ Group = "Trunk", Color = "Face", Kind = "Capsule", A = { 0, 0.52, -1.24 }, B = { 0, 0.5, -1.44 }, RA = 0.13, RB = 0.12 },
		{ Group = "Trunk", Color = "FurDark", Kind = "Box", C = { 0, 0.88, -1.2 }, S = { 0.4, 0.05, 0.3 }, Paint = true },
		{ Group = "Trunk", Color = "FurDark", Kind = "Box", C = { 0, 0.66, -1.28 }, S = { 0.4, 0.05, 0.3 }, Paint = true },
		{ Group = "Trunk", Color = "Pink", Kind = "Box", C = { 0, 0.5, -1.55 }, S = { 0.3, 0.3, 0.06 }, Paint = true },
	})
	local bits = {}
	gem(bits, 1.62, 0.78)
	-- tusks curving down and forwards beside the trunk
	for _, side in { 1, -1 } do
		local a = 0.36 * side
		local base = at(a, 0.86, -0.04)
		local up1, up2 = leanUp(a, 125), leanUp(a, 150)
		table.insert(bits, { Name = "Tusk", Group = "Trunk", Color = "Tusk", C = base + up1 * 0.16, S = { 0.13, 0.34, 0.13 }, Rot = lean(a, 125, 45) })
		table.insert(bits, { Name = "Tusk", Group = "Trunk", Color = "TuskTip", C = base + up1 * 0.3 + up2 * 0.1, S = { 0.09, 0.2, 0.09 }, Rot = lean(a, 150, 45) })
	end
	sprout(bits, 2.8)
	specs.Egg_PebblePlains_Rare = finish(shapes, bits, {
		Fur = "9C7B6A",
		FurDark = "76594C",
		FurLight = "B4958A",
		Face = "AE8E7E",
		Pink = "F2A5A5",
		Stripe = "3FA9FF",
		Tusk = "FFF4D6",
		TuskTip = "F0E2BC",
	}, "Fur")
end

-- ---------- Epic: Rumblerex egg ----------
do
	local shapes = shellShapes("Body", "Dark", "Light")
	add(shapes, {
		{ Group = "Shell", Color = "Belly", Kind = "Ellipsoid", C = { 0, 0.55, -0.9 }, R = { 0.64, 0.5, 0.4 }, Paint = true },
		{ Group = "Shell", Color = "BellyLine", Kind = "Box", C = { 0, 0.62, -1.0 }, S = { 1.4, 0.05, 0.5 }, Paint = true },
		{ Group = "Shell", Color = "Mouth", Kind = "Box", C = { 0, 1.02, 0 }, S = { 3, 0.1, 3 }, Paint = true },
	})
	for _, p in scatter(9, 1.3, 2.35, { 0.6, 1.55, 0.4 }) do
		table.insert(shapes, { Group = "Shell", Color = "Dark", Kind = "Ellipsoid", C = at(p[1], p[2]), R = { 0.13, 0.13, 0.13 }, Paint = true })
	end
	local bits = {}
	gem(bits, 1.55, 0.82)
	-- a chomping lid: stepped teeth hanging over the mouth line, all the way round the front
	for k = -5, 5 do
		local a = k * 0.27
		local c = at(a, 0.92, -0.03)
		table.insert(bits, { Name = "Tooth", Group = "Teeth", Color = "Claw", C = c, S = { 0.15, 0.1, 0.09 }, Rot = { 0, deg(-a), 0 } })
		table.insert(bits, { Name = "Tooth", Group = "Teeth", Color = "Claw", C = c - Vector3.new(0, 0.08, 0), S = { 0.07, 0.08, 0.09 }, Rot = { 0, deg(-a), 0 } })
	end
	-- a crest of glowing plates from the forehead over the top to the back
	for i, p in { { -0.75, 0.36 }, { -0.4, 0.46 }, { -0.05, 0.54 }, { 0.3, 0.5 }, { 0.65, 0.42 }, { 1.0, 0.34 } } do
		local t, s = p[1], p[2]
		local y = 1.55 + 1.25 * math.cos(t)
		local z = 0.92 * math.sin(t)
		local n = Vector3.new(0, (y - 1.55) / 1.5625, z / 0.8464).Unit
		local tilt = deg(math.atan2(-n.Z, n.Y)) -- + leans to the front
		table.insert(bits, { Name = "Plate", Group = "Plates", Color = i % 2 == 0 and "PlateDeep" or "Plate", C = Vector3.new(0, y, z) + n * (s * 0.22), S = { 0.13, s, s }, Rot = lean(0, tilt, 0, CFrame.Angles(rad(45), 0, 0)) })
	end
	-- horns
	for _, a in { 0.58, -0.58 } do
		local base = at(a, 2.15, -0.04)
		local up = leanUp(a, 40)
		table.insert(bits, { Name = "Horn", Group = "Plates", Color = "Claw", C = base + up * 0.13, S = { 0.15, 0.26, 0.15 }, Rot = lean(a, 40, 45) })
		table.insert(bits, { Name = "Horn", Group = "Plates", Color = "ClawTip", C = base + up * 0.3, S = { 0.08, 0.14, 0.08 }, Rot = lean(a, 40, 45) })
	end
	specs.Egg_PebblePlains_Epic = finish(shapes, bits, {
		Body = "4DBB45",
		Dark = "2E8B3E",
		Light = "6CD25F",
		Mouth = "1F5E2B",
		Belly = "FFEBC2",
		BellyLine = "EFCF95",
		Plate = { "9A4DFF", Neon = true },
		PlateDeep = { "6A22D8", Neon = true },
		Claw = "FFF4D6",
		ClawTip = "EAD9B0",
	}, "Body")
end

-- ---------- Legendary: Thunderback egg ----------
do
	local shapes = shellShapes("Fur", "FurDark", "FurLight")
	add(shapes, {
		{ Group = "Shell", Color = "Chest", Kind = "Ellipsoid", C = { 0, 1.1, -0.95 }, R = { 0.58, 0.68, 0.35 }, Paint = true },
	})
	-- lightning cracks down both sides and the back
	for _, side in { 1, -1 } do
		crack(shapes, { { 0.5 * side, 2.6 }, { 0.85 * side, 2.2 }, { 0.6 * side, 1.9 }, { 1.0 * side, 1.5 }, { 0.75 * side, 1.15 }, { 1.1 * side, 0.75 }, { 0.95 * side, 0.45 } }, "Bolt")
	end
	crack(shapes, { { 2.9, 2.5 }, { 3.25, 2.05 }, { 2.95, 1.7 }, { 3.35, 1.2 }, { 3.05, 0.8 } }, "Bolt")
	-- thundercloud crown, dark underneath
	local puffs = { { 0, 2.98, 0.05, 0.42 } }
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2 + 0.2
		table.insert(puffs, { math.sin(a) * 0.55, 2.74 + (k % 2) * 0.06, -math.cos(a) * 0.55, 0.33 + (k % 3) * 0.03 })
	end
	for _, p in puffs do
		table.insert(shapes, { Group = "Cloud", Color = "Cloud", Kind = "Ellipsoid", C = { p[1], p[2], p[3] }, R = { p[4], p[4] * 0.78, p[4] } })
	end
	for _, p in puffs do
		table.insert(shapes, { Group = "Cloud", Color = "CloudMid", Kind = "Ellipsoid", C = { p[1], p[2] - p[4] * 0.5, p[3] }, R = { p[4] * 1.1, p[4] * 0.36, p[4] * 1.1 }, Paint = true })
	end
	table.insert(shapes, { Group = "Cloud", Color = "CloudDark", Kind = "Box", C = { 0, 2.5, 0 }, S = { 3, 0.16, 3 }, Paint = true })
	local bits = {}
	gem(bits, 1.32, 1.0, true)
	-- bolts striking out from under the cloud
	for _, b in { { 0.95, -0.25, 1 }, { -0.95, -0.2, -1 }, { 0.2, 0.9, 1 }, { -0.45, 0.8, -1 } } do
		local x, z, s = b[1], b[2], b[3]
		table.insert(bits, { Name = "Bolt", Group = "Cloud", Color = "Bolt", C = { x, 2.42, z }, S = { 0.08, 0.26, 0.08 }, Rot = { 0, 0, -28 * s } })
		table.insert(bits, { Name = "Bolt", Group = "Cloud", Color = "Bolt", C = { x + 0.05 * s, 2.22, z }, S = { 0.08, 0.2, 0.08 }, Rot = { 0, 0, 30 * s } })
		table.insert(bits, { Name = "Bolt", Group = "Cloud", Color = "Bolt", C = { x + 0.02 * s, 2.05, z }, S = { 0.07, 0.18, 0.07 }, Rot = { 0, 0, -25 * s } })
	end
	specs.Egg_PebblePlains_Legendary = finish(shapes, bits, {
		Fur = "3A4A8C",
		FurDark = "27326A",
		FurLight = "4F62AE",
		Chest = "7F8FD2",
		Bolt = { "FFD23F", Neon = true },
		Cloud = "F4F6FB",
		CloudMid = "D2D9EA",
		CloudDark = "9DA7C6",
	}, "Fur")
end

-- ---------- Mythic: Boulderback egg (the guardian) ----------
do
	local shapes = shellShapes("Stone", "StoneDark", "StoneLight")
	add(shapes, {
		{ Group = "Shell", Color = "Belly", Kind = "Ellipsoid", C = { 0, 0.72, -0.95 }, R = { 0.56, 0.56, 0.35 }, Paint = true },
		{ Group = "Shell", Color = "BellyLine", Kind = "Box", C = { 0, 0.62, -1.0 }, S = { 1.4, 0.05, 0.5 }, Paint = true },
		{ Group = "Shell", Color = "BellyLine", Kind = "Box", C = { 0, 0.86, -1.0 }, S = { 1.4, 0.05, 0.5 }, Paint = true },
		-- a rocky shell over the top half with a scalloped edge
		{ Group = "Shell", Color = "Rock", Kind = "Ellipsoid", C = { 0, 2.45, 0 }, R = { 1.3, 0.92, 1.3 }, Paint = true },
	})
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		table.insert(shapes, { Group = "Shell", Color = "Rock", Kind = "Ellipsoid", C = at(a, 1.58), R = { 0.24, 0.16, 0.24 }, Paint = true })
	end
	table.insert(shapes, { Group = "Shell", Color = "RockLight", Kind = "Ellipsoid", C = at(0.75, 2.2, 0.05), R = { 0.3, 0.3, 0.3 }, Paint = true })
	-- glowing cracks through the rock
	crack(shapes, { { 0.1, 2.7 }, { 0.4, 2.35 }, { 0.2, 2.0 }, { 0.5, 1.72 } }, "Glow", 0.06)
	crack(shapes, { { 0.4, 2.35 }, { 0.9, 2.2 }, { 1.3, 1.9 } }, "Glow", 0.06)
	crack(shapes, { { -0.25, 2.55 }, { -0.7, 2.25 }, { -0.55, 1.9 }, { -0.95, 1.65 } }, "Glow", 0.06)
	crack(shapes, { { 2.2, 2.4 }, { 2.6, 2.0 }, { 2.4, 1.7 } }, "Glow", 0.06)
	crack(shapes, { { 3.6, 2.6 }, { 3.9, 2.15 }, { 4.4, 1.9 } }, "Glow", 0.06)
	local bits = {}
	gem(bits, 1.12, 0.9, true)
	-- chunky boulders sitting on the rocky shell
	local tones = { "Pebble", "PebbleDark", "PebbleLight" }
	for i, p in scatter(12, 1.75, 2.55, { 0.45, 2.1, 0.3 }) do
		local s = 0.3 - (p[2] - 1.75) * 0.1
		local tilt = normalTilt(p[2])
		table.insert(bits, { Name = "Boulder", Group = "Rocks", Color = tones[i % 3 + 1], C = at(p[1], p[2], 0.02), S = { s, s * 0.7, s }, Rot = lean(p[1], tilt, 20 + i * 37, CFrame.Angles(rad(12), 0, rad(-8))) })
	end
	-- a cluster of glowing crystals bursting out of the top, a few more out of the sides
	for i, c in { { 0, 0, 0.26, 0.9 }, { 0.6, 28, 0.2, 0.62 }, { 2.4, 30, 0.19, 0.58 }, { 4.3, 26, 0.18, 0.56 }, { 1.5, 40, 0.14, 0.42 }, { 5.3, 42, 0.14, 0.4 } } do
		local up = leanUp(c[1], c[2])
		local base = Vector3.new(math.sin(c[1]) * 0.18, 2.66, -math.cos(c[1]) * 0.18)
		table.insert(bits, { Name = "Crystal", Group = "Crystals", Color = i % 2 == 1 and "Crystal" or "CrystalDeep", C = base + up * (c[4] * 0.42), S = { c[3], c[4], c[3] }, Rot = lean(c[1], c[2], 45) })
		table.insert(bits, { Name = "Crystal", Group = "Crystals", Color = "CrystalTip", C = base + up * (c[4] * 0.86), S = { c[3] * 0.62, c[3] * 0.62, c[3] * 0.62 }, Rot = lean(c[1], c[2], 45, CFrame.Angles(rad(45), 0, 0)) })
	end
	for _, c in { { 1.35, 1.95 }, { -1.4, 1.85 }, { 3.0, 2.0 } } do
		local tilt = normalTilt(c[2]) - 25
		local up = leanUp(c[1], tilt)
		table.insert(bits, { Name = "Crystal", Group = "Crystals", Color = "Crystal", C = at(c[1], c[2], -0.02) + up * 0.18, S = { 0.15, 0.42, 0.15 }, Rot = lean(c[1], tilt, 45) })
	end
	specs.Egg_PebblePlains_Mythic = finish(shapes, bits, {
		Stone = "6FB04A",
		StoneDark = "4F8A33",
		StoneLight = "86C35E",
		Belly = "FFE6A8",
		BellyLine = "F0CC80",
		Rock = "A3A6B4",
		RockLight = "C2C5D0",
		Pebble = "B7B9C4",
		PebbleDark = "8E91A0",
		PebbleLight = "DCDEE6",
		Glow = { "B05CFF", Neon = true },
		Crystal = { "B05CFF", Neon = true },
		CrystalDeep = { "7B2CFF", Neon = true },
		CrystalTip = { "E3C2FF", Neon = true },
	}, "Rock")
end

-- ---------- Secret: Prismling egg ----------
do
	local shapes = shellShapes("Pearl", "Shade", "PearlLight")
	add(shapes, {
		-- a soft iridescent wash: lavender low down, pink up top
		{ Group = "Shell", Color = "Tint6", Kind = "Box", C = { 0, 0.72, 0 }, S = { 3, 0.4, 3 }, Paint = true },
		{ Group = "Shell", Color = "Tint5", Kind = "Box", C = { 0, 1.02, 0 }, S = { 3, 0.2, 3 }, Paint = true },
		{ Group = "Shell", Color = "Tint1", Kind = "Ellipsoid", C = { 0, 2.8, 0 }, R = { 1.0, 0.55, 1.0 }, Paint = true },
		{ Group = "Shell", Color = "PearlLight", Kind = "Ellipsoid", C = at(0.75, 2.0, 0.05), R = { 0.3, 0.38, 0.3 }, Paint = true },
	})
	local bits = {}
	gem(bits, 1.42, 1.0, true)
	-- a crown of rainbow crystals round the top, a tall one in the middle
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local base = at(a, 2.5, -0.1)
		local up = leanUp(a, 24)
		local h = k % 2 == 0 and 0.62 or 0.5
		table.insert(bits, { Name = "Crystal", Group = "Crown", Color = "Gem" .. (k + 1), C = base + up * (h * 0.45), S = { 0.18, h, 0.18 }, Rot = lean(a, 24, 45) })
		table.insert(bits, { Name = "Crystal", Group = "Crown", Color = "Gem" .. (k + 1), C = base + up * (h * 0.92), S = { 0.13, 0.13, 0.13 }, Rot = lean(a, 24, 45, CFrame.Angles(rad(45), 0, 0)) })
	end
	table.insert(bits, { Name = "Crystal", Group = "Crown", Color = "CrownTop", C = { 0, 3.12, 0 }, S = { 0.24, 0.66, 0.24 }, Rot = { 0, 45, 0 } })
	table.insert(bits, { Name = "Crystal", Group = "Crown", Color = "CrownTop", C = { 0, 3.48, 0 }, S = { 0.17, 0.17, 0.17 }, Rot = { 45, 45, 0 } })
	-- sparkles painted into the shell and floating round it
	local tints = { "Gem1", "Gem2", "Gem3", "Gem4", "Gem5", "Gem6" }
	for i, p in scatter(10, 0.75, 2.2, { 0.6, 1.42, 0.5 }) do
		table.insert(bits, { Name = "Sparkle", Group = "Shell", Color = tints[i % 6 + 1], C = at(p[1], p[2], -0.01), S = { 0.08, 0.08, 0.08 }, Rot = lean(p[1], normalTilt(p[2]), 45) })
	end
	for i, s in { { 1.35, 2.5, -0.35 }, { -1.3, 2.2, -0.5 }, { -0.9, 3.0, 0.2 }, { 1.1, 1.0, -0.8 } } do
		table.insert(bits, { Name = "Sparkle", Group = "Shell", Color = tints[(i * 2) % 6 + 1], C = s, S = { 0.12, 0.12, 0.12 }, Rot = { 45, 45, 0 } })
	end
	-- flowers tucked into the leaves
	for k = 0, 5 do
		local a = (k + 0.25) / 6 * math.pi * 2
		local c = at(a, 0.4, 0.2)
		table.insert(bits, { Name = "Flower", Group = "Leaves", Color = tints[k + 1], C = c, S = { 0.16, 0.16, 0.16 }, Rot = { 0, 45 - deg(a), 0 } })
		table.insert(bits, { Name = "Flower", Group = "Leaves", Color = "GemCore", C = c + Vector3.new(0, 0.07, 0), S = { 0.07, 0.07, 0.07 }, Rot = { 0, 45 - deg(a), 0 } })
	end
	specs.Egg_PebblePlains_Secret = finish(shapes, bits, {
		Pearl = "F6F2FF",
		Shade = "D9CCF7",
		PearlLight = "FFFFFF",
		CrownTop = { "FFF6FF", Neon = true },
		Tint1 = "FFDDEB",
		Tint5 = "E2EEFF",
		Tint6 = "E6DBFF",
		Gem1 = { "FF5A7A", Neon = true },
		Gem2 = { "FFB347", Neon = true },
		Gem3 = { "FFF04D", Neon = true },
		Gem4 = { "5CFF9D", Neon = true },
		Gem5 = { "4DC3FF", Neon = true },
		Gem6 = { "B266FF", Neon = true },
	}, "Pearl")
end

return specs
