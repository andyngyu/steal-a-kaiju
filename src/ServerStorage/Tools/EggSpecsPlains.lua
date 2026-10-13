-- Pebble Plains egg family (merged into Tools.BiomeArtSpecs; built by Tools.BiomeArtBuilder.BuildEgg(biome, rarity) into
-- ServerStorage.Assets.Eggs.PebblePlains_<Rarity>). One design per rarity, themed on the kaiju that hatches at it and
-- more ornate as rarity rises:
--   Common     Pebblesaur egg: green with spots, a cream belly, a ridge of pebbles over the top
--   Uncommon   Bonkey egg: fur with a hair cap and tuft, heart face and muzzle, cupped ears, a bonked bump, a banana
--   Rare       Tuskit egg: huge pink-lined ears, ringed trunk, tusks, blue war paint, a leafy crown, a vine
--   Epic       Rumblerex egg: a jaw seam full of teeth, angry brows and horns, a crest of glowing plates, scratches
--   Legendary  Thunderback egg: storm fur, chest shield, glowing lightning cracks, a thundercloud crown with bolts
--   Mythic     Boulderback egg (the guardian): boulders, glowing violet cracks, a mossy cap, a crystal cluster
--   Secret     Prismling egg: rainbow pearl, a rainbow crystal crown and crystal wings, flowers in the leaves
-- Family look (Tools.EggKit): a cup of pointed leaves at the base and a faceted glowing yellow gem on the front in a
-- frame of parts named "Band" (Lib.EggModel tints them with the rarity colour; Legendary+ frames grow rays), a gem
-- light and twinkles. Clean voxels, 0.1 studs. Budget ~550-800 bricks: colour edges that run round the egg
-- (horizontal) are nearly free, edges that run up and down it and thin diagonal lines cost the most.
local Kit = require(game:GetService("ServerStorage").Tools.EggKit:Clone())
local V = Kit.V
local at, dir, surface, lean = Kit.at, Kit.dir, Kit.surface, Kit.lean
local rad, deg = math.rad, math.deg
local PI = math.pi
local specs = {}

local FAMILY = {
	Leaf = "58AE36",
	LeafDark = "3A8F2A",
	LeafLight = "8ACF5A",
	Stem = "4A8A2A",
	Vine = "3E8A2A",
	Gem = { "FFD83A", Neon = true },
	GemDeep = { "F59A10", Neon = true },
	GemLight = { "FFEB70", Neon = true },
	GemCore = { "FFFFF0", Neon = true },
	Socket = "4A3612",
	Band = "B8C0CC",
}

local function egg(own, shellKey, shapes, opts)
	opts = opts or {}
	local palette = table.clone(FAMILY)
	for k, v in own do
		palette[k] = v
	end
	Kit.leafCollar(shapes, opts.LeafTop or 0.34, opts.Lobes or 9)
	local fx = { Kit.twinkle({ "FFF8C0", "FFD83A" }, 1.2) }
	for _, f in opts.FX or {} do
		table.insert(fx, f)
	end
	return {
		Voxel = V,
		NoStuds = true,
		SkinMerge = true,
		AO = true,
		ShellColor = own[shellKey],
		Palette = palette,
		Shapes = shapes,
		Light = { Color = opts.LightColor or "FFD84A", Range = 5, Brightness = 1.4 },
		FX = fx,
	}
end

local function band(color, y0, y1)
	return Kit.paint(color, function(s, y)
		return y >= y0 and y < y1
	end)
end

-- ---------- Common: Pebblesaur egg ----------
do
	local S = Kit.shell("Body")
	table.insert(S, band("BodyLight", 2.5, 9))
	for _, sp in { { 1.2, 2.05, 0.15 }, { 2.0, 1.5, 0.17 }, { 2.8, 2.15, 0.14 }, { -1.25, 1.95, 0.16 }, { -2.1, 1.35, 0.14 }, { -2.85, 2.0, 0.15 }, { 1.45, 0.95, 0.12 }, { -1.5, 0.9, 0.13 } } do
		table.insert(S, { Group = "Shell", Color = "Spot", Kind = "Ellipsoid", Paint = true, C = at(sp[1], sp[2]), R = { sp[3], sp[3], sp[3] } })
	end
	local function belly(s, y)
		return (s / 0.6) ^ 2 + ((y - 0.86) / 0.55) ^ 2 <= 1
	end
	table.insert(S, Kit.panel("Belly", V, belly))
	for _, ly in { 0.66, 0.88, 1.1 } do
		table.insert(S, Kit.paint("BellyDark", function(s, y)
			return math.abs(y - ly) < V * 0.5 and belly(s, y)
		end))
	end
	-- Pebblesaur's pebbles: a ridge over the top from the brow to the back, two on each flank
	local ridge = { { -0.62, 0.17 }, { -0.25, 0.23 }, { 0.15, 0.27 }, { 0.55, 0.25 }, { 0.95, 0.22 }, { 1.32, 0.18 } }
	for _, r in ridge do
		local t, rr = r[1], r[2]
		local c = Vector3.new(0, 1.55 + 1.25 * math.cos(t), 0.92 * math.sin(t))
		table.insert(S, { Group = "Rocks", Color = "Rock", Kind = "Ellipsoid", C = c, R = { rr, rr * 0.8, rr } })
		table.insert(S, { Group = "Rocks", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, rr * 0.5, 0), R = { rr * 0.8, rr * 0.4, rr * 0.8 } })
	end
	-- a pile of pebbles on the crown
	for _, r in { { Vector3.new(0, 2.84, 0.06), 0.3 }, { Vector3.new(0.26, 2.72, -0.12), 0.22 }, { Vector3.new(-0.25, 2.7, 0.16), 0.24 }, { Vector3.new(0.05, 2.66, -0.3), 0.18 } } do
		local c, rr = r[1], r[2]
		table.insert(S, { Group = "Rocks", Color = "Rock", Kind = "Ellipsoid", C = c, R = { rr, rr * 0.8, rr } })
		table.insert(S, { Group = "Rocks", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, rr * 0.5, 0), R = { rr * 0.8, rr * 0.4, rr * 0.8 } })
	end
	for _, r in { { 1.75, 1.85, 0.18 }, { 2.35, 1.3, 0.15 }, { -1.8, 1.75, 0.18 }, { -2.4, 1.25, 0.15 } } do
		local c, rr = at(r[1], r[2], 0.02), r[3]
		table.insert(S, { Group = "Rocks", Color = "Rock", Kind = "Ellipsoid", C = c, R = { rr, rr * 0.8, rr } })
		table.insert(S, { Group = "Rocks", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, rr * 0.5, 0), R = { rr * 0.8, rr * 0.4, rr * 0.8 } })
	end
	Kit.gem(S, 1.8, 0.3)
	specs.Egg_PebblePlains_Common = egg({
		Body = "62A844",
		BodyLight = "78BA55",
		Spot = "4E8F34",
		Belly = "FFE6A8",
		BellyDark = "EBC57E",
		Rock = "9EA1AF",
		RockLight = "CDD0DA",
	}, "Body", S)
end

-- ---------- Uncommon: Bonkey egg ----------
do
	local S = Kit.shell("Fur")
	table.insert(S, band("FurDark", 0, 0.62))
	-- hair cap with a tufty edge
	table.insert(S, Kit.panel("Hair", V, function(s, y, a)
		return y > 2.36 + 0.09 * math.sin(a * 8)
	end))
	table.insert(S, band("HairLight", 2.66, 9))
	-- heart-shaped face
	local function face(s, y, g)
		return ((s - 0.3) / (0.38 + g)) ^ 2 + ((y - 1.85) / (0.36 + g)) ^ 2 <= 1 or ((s + 0.3) / (0.38 + g)) ^ 2 + ((y - 1.85) / (0.36 + g)) ^ 2 <= 1 or (s / (0.64 + g)) ^ 2 + ((y - 1.38) / (0.56 + g)) ^ 2 <= 1
	end
	table.insert(S, Kit.panel("FaceRim", V, function(s, y)
		return face(s, y, 0.1)
	end))
	table.insert(S, Kit.panel("Face", V * 2, function(s, y)
		return face(s, y, 0)
	end))
	-- muzzle: sticks out, lit on top, shadowed under, two nostrils
	table.insert(S, { Group = "Shell", Color = "Face", Kind = "Ellipsoid", C = { 0, 0.98, -0.98 }, R = { 0.5, 0.29, 0.33 } })
	table.insert(S, { Group = "Shell", Color = "FaceLight", Kind = "Box", Paint = true, C = { 0, 1.17, -1.2 }, S = { 1, 0.12, 0.5 } })
	table.insert(S, { Group = "Shell", Color = "FaceDark", Kind = "Box", Paint = true, C = { 0, 0.76, -1.2 }, S = { 1, 0.12, 0.5 } })
	for _, x in { 0.11, -0.11 } do
		table.insert(S, { Group = "Shell", Color = "Nose", Kind = "Ellipsoid", Paint = true, C = { x, 1.04, -1.31 }, R = { 0.06, 0.05, 0.08 } })
	end
	-- round ears facing forwards, cupped, pale inside
	for _, side in { 1, -1 } do
		local a = 1.3 * side
		local c = at(a, 1.95, 0.2)
		local n = dir(a * 0.3)
		local rot = { 0, deg(-a * 0.3), 0 }
		table.insert(S, { Group = "Ears", Color = "Fur", Kind = "Ellipsoid", C = c, R = { 0.36, 0.36, 0.14 }, Rot = rot })
		table.insert(S, { Group = "Ears", Color = "Face", Kind = "Ellipsoid", Paint = true, C = c + n * 0.08, R = { 0.25, 0.25, 0.1 }, Rot = rot })
		table.insert(S, { Group = "Ears", Kind = "Ellipsoid", Carve = true, C = c + n * 0.16, R = { 0.21, 0.21, 0.07 }, Rot = rot })
	end
	-- hair tuft curling forwards, two side licks
	Kit.chain(S, "Hair", { { Vector3.new(0, 2.7, 0), 0.15, "Hair" }, { Vector3.new(0, 2.98, -0.08), 0.12, "Hair" }, { Vector3.new(0, 3.14, -0.26), 0.09, "HairLight" }, { Vector3.new(0, 3.08, -0.42), 0.06, "HairLight" } })
	for _, side in { 1, -1 } do
		Kit.chain(S, "Hair", { { Vector3.new(side * 0.2, 2.68, 0.05), 0.11, "Hair" }, { Vector3.new(side * 0.36, 2.9, 0.1), 0.08, "Hair" }, { Vector3.new(side * 0.46, 2.98, 0.2), 0.05, "HairLight" } })
	end
	-- the bonked bump with a bandage cross
	local bumpA, bumpY = -0.72, 2.3
	table.insert(S, { Group = "Shell", Color = "Bump", Kind = "Ellipsoid", C = at(bumpA, bumpY, -0.05), R = { 0.21, 0.21, 0.21 } })
	local tilt = Kit.normalTilt(bumpY)
	for _, spin in { 40, -40 } do
		table.insert(S, { Group = "Shell", Color = "Bandage", Kind = "Box", C = at(bumpA, bumpY, 0.13), S = { 0.5, 0.07, 0.13 }, Rot = lean(bumpA, tilt, spin) })
	end
	-- a banana propped against the egg
	local bpts = {}
	for k = 0, 5 do
		local t = k / 5
		local a = 0.5 + t * 0.55
		local y = 0.36 + math.sin(t * PI) * 0.14 + t * 0.2
		table.insert(bpts, { dir(a) * (surface(y) + 0.2) + Vector3.new(0, y, 0), 0.05 + 0.07 * math.sin(t * PI), (k == 0 or k == 5) and "BananaTip" or "Banana" })
	end
	Kit.chain(S, "Banana", bpts)
	Kit.gem(S, 1.7, 0.26)
	specs.Egg_PebblePlains_Uncommon = egg({
		Fur = "A0703F",
		FurDark = "86592F",
		Face = "FFD9A0",
		FaceRim = "6E4A28",
		FaceLight = "FFE8C4",
		FaceDark = "E2AE6C",
		Nose = "5E3D22",
		Hair = "5E3D22",
		HairLight = "7A5232",
		Bump = "FF8FB2",
		Bandage = "FFF6E6",
		Banana = "FFDD3C",
		BananaTip = "6B4A1E",
	}, "Fur", S)
end

-- ---------- Rare: Tuskit egg ----------
do
	local S = Kit.shell("Fur")
	table.insert(S, band("FurDark", 0, 0.62))
	table.insert(S, Kit.paint("FurLight", function(s, y)
		return (s / 0.62) ^ 2 + ((y - 1.62) / 0.8) ^ 2 <= 1
	end))
	-- blue war paint: stripes over the back and a chevron on the brow
	for _, yy in { 2.0, 2.3 } do
		table.insert(S, Kit.panel("Stripe", V, function(s, y, a)
			return math.abs(a) > 0.95 and math.abs(y - (yy + 0.14 * math.cos(a))) < 0.06
		end))
	end
	table.insert(S, Kit.panel("Stripe", V, function(s, y)
		return math.abs(s) < 0.42 and math.abs(y - (2.48 - 0.42 * math.abs(s))) < 0.06
	end))
	-- huge ears: dark backs, pink cupped insides
	for _, side in { 1, -1 } do
		local a = 1.05 * side
		local c = at(a, 1.55, 0.15)
		local face = a * 0.45
		local n = dir(face)
		local rot = { 0, deg(-face), 0 }
		table.insert(S, { Group = "Ears", Color = "Fur", Kind = "Ellipsoid", C = c, R = { 0.6, 0.72, 0.12 }, Rot = rot })
		table.insert(S, { Group = "Ears", Color = "FurDark", Kind = "Ellipsoid", Paint = true, C = c - n * 0.06, R = { 0.62, 0.74, 0.08 }, Rot = rot })
		table.insert(S, { Group = "Ears", Color = "Pink", Kind = "Ellipsoid", Paint = true, C = c + n * 0.06, R = { 0.44, 0.55, 0.09 }, Rot = rot })
		table.insert(S, { Group = "Ears", Kind = "Ellipsoid", Carve = true, C = c + n * 0.14, R = { 0.38, 0.49, 0.07 }, Rot = rot })
		table.insert(S, { Group = "Ears", Color = "PinkDark", Kind = "Ellipsoid", Paint = true, C = c + n * 0.02, R = { 0.3, 0.38, 0.06 }, Rot = rot })
	end
	-- trunk with wrinkle rings, curling out at a pink tip
	Kit.chain(S, "Trunk", {
		{ Vector3.new(0, 1.3, -1.02), 0.21, "FurLight" },
		{ Vector3.new(0, 1.06, -1.15), 0.19, "FurLight" },
		{ Vector3.new(0, 0.82, -1.21), 0.17, "FurLight" },
		{ Vector3.new(0, 0.6, -1.28), 0.15, "FurLight" },
		{ Vector3.new(0, 0.46, -1.42), 0.13, "FurLight" },
		{ Vector3.new(0, 0.45, -1.6), 0.12, "FurLight" },
		{ Vector3.new(0, 0.57, -1.73), 0.1, "Pink" },
	})
	for _, ry in { 1.14, 0.96, 0.78, 0.62 } do
		table.insert(S, { Group = "Trunk", Color = "FurDark", Kind = "Box", Paint = true, C = { 0, ry, -1.38 }, S = { 0.5, V * 0.9, 0.4 } })
	end
	-- tusks
	for _, side in { 1, -1 } do
		Kit.chain(S, "Tusks", {
			{ Vector3.new(side * 0.3, 1.0, -1.02), 0.1, "Tusk" },
			{ Vector3.new(side * 0.4, 0.78, -1.22), 0.09, "Tusk" },
			{ Vector3.new(side * 0.47, 0.7, -1.42), 0.075, "Tusk" },
			{ Vector3.new(side * 0.5, 0.8, -1.6), 0.06, "TuskLight" },
			{ Vector3.new(side * 0.49, 0.96, -1.68), 0.035, "TuskLight" },
		})
	end
	-- a leafy crown
	Kit.bush(S, Vector3.new(0, 2.82, 0.05), 0.24, "LeafDark", "Leaf", "LeafLight", "Crown")
	for k = 0, 3 do
		local a = k * PI / 2 + PI / 4
		local c = Vector3.new(0, 2.86, 0) + dir(a) * 0.3
		table.insert(S, { Group = "Crown", Color = k % 2 == 0 and "Leaf" or "LeafDark", Kind = "Ellipsoid", C = c, R = { 0.16, 0.07, 0.27 }, Rot = { -18, deg(-a), 0 } })
	end
	Kit.vine(S, 0.98, 0.06, 3, 0.7, function(a)
		return math.abs(Kit.da(a, 0)) < 0.3
	end)
	Kit.gem(S, 1.92, 0.26)
	specs.Egg_PebblePlains_Rare = egg({
		Fur = "9C7B6A",
		FurDark = "7E6052",
		FurLight = "B39486",
		Pink = "F2A5A5",
		PinkDark = "D98A8A",
		Stripe = "2F9BFF",
		Tusk = "FFF4D6",
		TuskLight = "FFFDF5",
	}, "Fur", S)
end

-- ---------- Epic: Rumblerex egg ----------
do
	local S = Kit.shell("Body")
	table.insert(S, band("Light", 2.45, 9))
	local function belly(s, y)
		return (s / 0.68) ^ 2 + ((y - 0.55) / 0.5) ^ 2 <= 1
	end
	table.insert(S, Kit.panel("Belly", V, belly))
	for _, ly in { 0.52, 0.74 } do
		table.insert(S, Kit.paint("BellyDark", function(s, y)
			return math.abs(y - ly) < V * 0.5 and belly(s, y)
		end))
	end
	for _, sp in { { 1.05, 1.75 }, { 1.45, 2.2 }, { 1.9, 1.5 }, { 2.5, 2.0 }, { -1.05, 1.8 }, { -1.5, 2.25 }, { -1.95, 1.5 }, { -2.55, 2.05 } } do
		table.insert(S, { Group = "Shell", Color = "Scale", Kind = "Ellipsoid", Paint = true, C = at(sp[1], sp[2]), R = { 0.14, 0.11, 0.14 } })
	end
	-- the jaw: a dark seam round the egg, teeth hanging over it
	local JY = 1.12
	table.insert(S, { Group = "Shell", Kind = "Custom", Carve = true, Lo = Kit.LO, Hi = Kit.HI, Inside = function(p)
		return math.abs(p.Y - JY) < 0.07 and not Kit.inEgg(p, -0.13)
	end })
	table.insert(S, { Group = "Shell", Color = "Mouth", Kind = "Custom", Paint = true, Lo = Kit.LO, Hi = Kit.HI, Inside = function(p)
		return math.abs(p.Y - JY) < 0.07 + V * 0.5 and Kit.inEgg(p, -0.12) and not Kit.inEgg(p, -0.13 - V * 1.3)
	end })
	for k = -6, 6 do
		local a = k * 0.25
		table.insert(S, { Group = "Teeth", Color = "Tooth", Kind = "Capsule", A = at(a, JY + 0.12, -0.06), B = at(a, JY - 0.05, 0.02), RA = 0.075, RB = 0.02 })
	end
	for k = -5, 4 do
		local a = (k + 0.5) * 0.25
		table.insert(S, { Group = "Teeth", Color = "ToothShade", Kind = "Capsule", A = at(a, JY - 0.13, -0.06), B = at(a, JY + 0.02, 0.0), RA = 0.06, RB = 0.02 })
	end
	-- angry brows and horns
	for _, side in { 1, -1 } do
		Kit.ridge(S, { { side * 0.12, 2.12 }, { side * 0.35, 2.24 }, { side * 0.58, 2.33 } }, 0.075, "Brow", 0.1)
		Kit.horn(S, "Horns", side * 0.62, 2.36, 0.38, 0.11, 25, 20, { "Horn", "Horn", "HornTip" }, side)
	end
	-- a crest of glowing plates from the brow over the top to the back, brighter towards the tips
	for _, pl in { { -0.42, 0.6 }, { 0.0, 0.82 }, { 0.42, 0.8 }, { 0.84, 0.66 }, { 1.24, 0.5 } } do
		local t, s = pl[1], pl[2]
		local y = 1.55 + 1.25 * math.cos(t)
		local z = 0.92 * math.sin(t)
		local n = Vector3.new(0, (y - 1.55) / 1.5625, z / 0.8464).Unit
		local tilt = deg(math.atan2(-n.Z, n.Y))
		table.insert(S, { Group = "Crest", Color = "PlateDeep", Kind = "Box", C = Vector3.new(0, y, z) + n * (s * 0.16), S = { 0.16, s, s }, Rot = lean(0, tilt, 0, CFrame.Angles(rad(45), 0, 0)) })
	end
	table.insert(S, { Group = "Crest", Color = "Plate", Kind = "Custom", Paint = true, Lo = Vector3.new(-0.2, 1.0, -1.6), Hi = Vector3.new(0.2, 3.8, 1.6), Inside = function(p)
		return not Kit.inEgg(p, 0.26)
	end })
	-- claw scratches
	for k = 0, 2 do
		local a0 = -1.25 - k * 0.17
		Kit.groove(S, { { a0, 2.0 }, { a0 - 0.3, 1.55 } }, 0.06, "Scratch")
	end
	Kit.gem(S, 1.68, 0.28)
	specs.Egg_PebblePlains_Epic = egg({
		Body = "3FA142",
		Light = "52B24F",
		Scale = "2E8336",
		Belly = "FFEBC2",
		BellyDark = "E8C68A",
		Mouth = "2A1420",
		Tooth = "FFF8E6",
		ToothShade = "EDE0C0",
		Brow = "1F5E2B",
		Horn = "EDE0C0",
		HornTip = "FFFBF0",
		Scratch = "1F5E2B",
		PlateDeep = { "4A16C8", Neon = true },
		Plate = { "7A3CFF", Neon = true },
	}, "Body", S, {
		FX = { { Texture = Kit.MOTE, Colors = { "9A6BFF", "5A2BE0" }, Rate = 2, Size = { 0.3, 0 }, Lifetime = { 0.8, 1.4 }, Speed = { 0.1, 0.3 }, Acceleration = Vector3.new(0, 0.6, 0), LightEmission = 1 } },
	})
end

-- ---------- Legendary: Thunderback egg ----------
do
	local S = Kit.shell("Fur")
	table.insert(S, band("FurDark", 0, 0.62))
	-- chest shield
	local function shield(s, y)
		if y < 0.42 or y > 2.0 - 0.3 * (s / 0.62) ^ 2 then
			return false
		end
		local half = y > 1.25 and 0.62 or 0.62 * (y - 0.42) / 0.83
		return math.abs(s) <= half
	end
	table.insert(S, Kit.panel("ChestDark", V, shield))
	table.insert(S, Kit.panel("Chest", V, function(s, y)
		return shield(s * 1.2, y) and shield(s, y - 0.1) and shield(s, y + 0.1)
	end))
	-- lightning cracks down both sides and the back
	for _, side in { 1, -1 } do
		Kit.groove(S, { { side * 0.95, 2.45 }, { side * 1.2, 2.05 }, { side * 0.98, 1.8 }, { side * 1.32, 1.35 }, { side * 1.08, 1.05 }, { side * 1.42, 0.62 } }, 0.075, "BoltGlow", "Bolt")
	end
	Kit.groove(S, { { PI - 0.3, 2.45 }, { PI + 0.1, 2.0 }, { PI - 0.2, 1.6 }, { PI + 0.2, 1.1 }, { PI - 0.1, 0.65 } }, 0.075, "BoltGlow", "Bolt")
	-- shaggy shoulder tufts
	for _, side in { 1, -1 } do
		for j, t in { { 1.62, 2.15 }, { 1.85, 1.92 }, { 1.45, 1.88 } } do
			local a = side * t[1]
			local base = at(a, t[2], -0.05)
			table.insert(S, { Group = "Fur", Color = j == 1 and "FurLight" or "Fur", Kind = "Capsule", A = base, B = base + Kit.leanUp(a, 115) * 0.28, RA = 0.11, RB = 0.02 })
		end
	end
	-- thundercloud crown: lit top, dark underside
	local puffs = { { 0, 3.0, 0.05, 0.44 } }
	for k = 0, 5 do
		local a = k / 6 * PI * 2 + 0.25
		table.insert(puffs, { math.sin(a) * 0.6, 2.78 + (k % 2) * 0.06, -math.cos(a) * 0.6, 0.35 + (k % 2) * 0.04 })
	end
	for _, p in puffs do
		table.insert(S, { Group = "Cloud", Color = "Cloud", Kind = "Ellipsoid", C = { p[1], p[2], p[3] }, R = { p[4], p[4] * 0.8, p[4] } })
	end
	table.insert(S, { Group = "Cloud", Color = "CloudLight", Kind = "Box", Paint = true, C = { 0, 3.4, 0 }, S = { 4, 0.5, 4 } })
	table.insert(S, { Group = "Cloud", Color = "CloudDark", Kind = "Box", Paint = true, C = { 0, 2.55, 0 }, S = { 4, 0.14, 4 } })
	-- bolts dangling from the cloud
	for _, b in { { 0.85, 1 }, { -0.85, -1 } } do
		local a, sd = b[1], b[2]
		local p0 = at(a, 2.52, 0.38)
		Kit.chain(S, "Cloud", {
			{ p0, 0.055, "Bolt" },
			{ p0 + Vector3.new(0.1 * sd, -0.18, 0), 0.05, "Bolt" },
			{ p0 + Vector3.new(-0.02 * sd, -0.3, 0), 0.05, "Bolt" },
			{ p0 + Vector3.new(0.08 * sd, -0.5, 0), 0.03, "BoltCore" },
		})
	end
	Kit.gem(S, 1.42, 0.33, true)
	specs.Egg_PebblePlains_Legendary = egg({
		Fur = "3A4A8C",
		FurDark = "2B386E",
		FurLight = "5568B5",
		Chest = "9AA8E2",
		ChestDark = "6F80C4",
		Cloud = "D3D9E8",
		CloudLight = "F2F5FB",
		CloudDark = "8590B0",
		Bolt = { "FFD83A", Neon = true },
		BoltGlow = { "E8890E", Neon = true },
		BoltCore = { "FFF2A0", Neon = true },
	}, "Fur", S, {
		LightColor = "FFD23F",
		FX = { { Texture = Kit.SPARK, Colors = { "FFF27A", "FFD23F" }, Rate = 3, Size = { 0.6, 0.1 }, Lifetime = { 0.15, 0.3 }, RotSpeed = { -200, 200 }, LightEmission = 1 } },
	})
end

-- ---------- Mythic: Boulderback egg (the guardian) ----------
do
	local S = Kit.shell("Rock")
	table.insert(S, band("RockDark", 0, 0.62))
	-- boulders bulging out of the shell, lit on top
	for _, b in { { 1.0, 0.8, 0.36 }, { -1.05, 0.85, 0.36 }, { 2.2, 1.0, 0.38 }, { -2.3, 1.05, 0.38 }, { PI, 0.95, 0.4 }, { 2.6, 2.0, 0.3 }, { -2.7, 2.05, 0.3 } } do
		local c, r = at(b[1], b[2], -0.14), b[3]
		table.insert(S, { Group = "Shell", Color = "Rock", Kind = "Ellipsoid", C = c, R = { r, r * 0.85, r } })
		table.insert(S, { Group = "Shell", Color = "RockLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, r * 0.55, 0), R = { r * 0.8, r * 0.4, r * 0.8 } })
	end
	-- mossy cap
	table.insert(S, Kit.panel("Moss", V, function(s, y, a)
		return y > 2.42 + 0.09 * math.sin(a * 5)
	end))
	table.insert(S, band("MossLight", 2.68, 9))
	-- glowing cracks: an X out of the gem, one down each side
	local G, C = "Glow", "GlowCore"
	for _, side in { 1, -1 } do
		Kit.groove(S, { { side * 0.35, 2.5 }, { side * 0.62, 2.2 }, { side * 0.55, 1.9 }, { side * 0.85, 1.6 }, { side * 0.75, 1.25 }, { side * 1.0, 0.85 } }, 0.075, G, C)
		Kit.groove(S, { { side * 0.62, 2.2 }, { side * 1.1, 2.05 }, { side * 1.35, 1.7 } }, 0.07, G, C)
		Kit.groove(S, { { side * 1.7, 2.4 }, { side * 1.95, 1.95 }, { side * 1.75, 1.5 }, { side * 2.0, 1.05 } }, 0.075, G, C)
	end
	Kit.groove(S, { { PI - 0.2, 2.45 }, { PI + 0.15, 2.0 }, { PI - 0.15, 1.55 }, { PI + 0.1, 1.05 } }, 0.075, G, C)
	-- a cluster of crystals bursting from the top, two breaking out of the sides
	local top = Vector3.new(0, 2.72, 0)
	Kit.crystal(S, "Crystals", top, 0, 0, 0.36, 1.3, "CrystalDeep", "Crystal", "CrystalTip")
	for _, c in { { 0.6, 30, 0.27, 0.9 }, { 2.7, 34, 0.26, 0.8 }, { 4.5, 30, 0.26, 0.85 } } do
		Kit.crystal(S, "Crystals", top + dir(c[1]) * 0.2, c[1], c[2], c[3], c[4], "CrystalDeep", "Crystal", "CrystalTip")
	end
	for _, c in { { 1.2, 1.42 }, { -1.2, 1.5 } } do
		Kit.crystal(S, "Crystals", at(c[1], c[2], -0.08), c[1], Kit.normalTilt(c[2]) - 30, 0.2, 0.64, "CrystalDeep", "Crystal", "CrystalTip")
	end
	Kit.gem(S, 1.45, 0.33, true)
	specs.Egg_PebblePlains_Mythic = egg({
		Rock = "5A5F75",
		RockDark = "4A4E62",
		RockLight = "767C92",
		Moss = "5FAA36",
		MossLight = "7FC24E",
		Glow = { "4A1FE0", Neon = true },
		GlowCore = { "8A5CFF", Neon = true },
		CrystalDeep = { "3A14C0", Neon = true },
		Crystal = { "5A2BFF", Neon = true },
		CrystalTip = { "7A4BFF", Neon = true },
	}, "Rock", S, {
		FX = { { Texture = Kit.MOTE, Colors = { "9A7BFF", "5A2BFF" }, Rate = 3, Size = { 0.35, 0 }, Lifetime = { 1, 1.6 }, Speed = { 0.1, 0.3 }, Acceleration = Vector3.new(0, 0.5, 0), LightEmission = 1 } },
	})
end

-- ---------- Secret: Prismling egg ----------
do
	local S = Kit.shell("Pearl")
	-- a rainbow pearl: pastel bands from rose at the bottom to lilac at the top, a pearly highlight
	table.insert(S, band("Lilac", 0, 0.95))
	table.insert(S, band("Blush", 2.35, 9))
	for k, tint in { "Tint1", "Tint3", "Tint5" } do
		local points = {}
		for j = 0, 12 do
			local t = j / 12
			table.insert(points, { (k - 1) / 3 * PI * 2 + t * PI * 1.1, 0.5 + t * 2.15 })
		end
		Kit.ridge(S, points, 0.1, tint, V * 1.2)
	end
	table.insert(S, { Group = "Shell", Color = "Pearl", Kind = "Ellipsoid", Paint = true, C = at(0.8, 2.0, 0.05), R = { 0.26, 0.34, 0.26 } })
	-- a rainbow crystal crown and a tall white one in the middle
	local top = Vector3.new(0, 2.66, 0)
	for k = 0, 5 do
		local a = k / 6 * PI * 2
		Kit.crystal(S, "Crown", top + dir(a) * 0.38, a, 26, 0.24, k % 2 == 0 and 0.9 or 0.72, "Gem" .. (k + 1) .. "Deep", "Gem" .. (k + 1), "Gem" .. (k + 1))
	end
	Kit.crystal(S, "Crown", top, 0, 0, 0.32, 1.25, "CrownDeep", "CrownMid", "CrownMid")
	-- crystal wings breaking out of the sides
	for _, side in { 1, -1 } do
		for _, c in { { 1.45, 1.8, 50, 0.22, 0.8 }, { 1.62, 1.42, 66, 0.17, 0.56 } } do
			local a = side * c[1]
			Kit.crystal(S, "Wings", at(a, c[2], -0.06), a, c[3], c[4], c[5], "Gem5Deep", "Gem5", "Gem5")
		end
	end
	-- flowers tucked into the leaves
	for k = 0, 5 do
		local a = k / 6 * PI * 2 + 0.25
		local c = dir(a) * (surface(0.45) + 0.16) + Vector3.new(0, 0.5, 0)
		table.insert(S, { Group = "Flowers", Color = "Petal" .. (k % 3 + 1), Kind = "Ellipsoid", C = c, R = { 0.13, 0.06, 0.13 } })
		table.insert(S, { Group = "Flowers", Color = "FlowerCore", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, 0.05, 0), R = { 0.05, 0.03, 0.05 } })
	end
	Kit.gem(S, 1.45, 0.33, true)
	specs.Egg_PebblePlains_Secret = egg({
		Pearl = "FBF8FF",
		Lilac = "E2D6FF",
		Blush = "FFE3F0",
		Tint1 = "FF8FBC",
		Tint3 = "FFE066",
		Tint5 = "7FC6FF",
		CrownDeep = { "C9A8FF", Neon = true },
		CrownMid = { "EADCFF", Neon = true },
		Gem1 = { "FF4D73", Neon = true },
		Gem1Deep = { "C8244C", Neon = true },
		Gem2 = { "FFA436", Neon = true },
		Gem2Deep = { "D07A12", Neon = true },
		Gem3 = { "FFE83A", Neon = true },
		Gem3Deep = { "C9B014", Neon = true },
		Gem4 = { "3EF08A", Neon = true },
		Gem4Deep = { "18B85A", Neon = true },
		Gem5 = { "36B4FF", Neon = true },
		Gem5Deep = { "1478D8", Neon = true },
		Gem6 = { "A452FF", Neon = true },
		Gem6Deep = { "6E24D8", Neon = true },
		Petal1 = "FF8FBE",
		Petal2 = "FFD95C",
		Petal3 = "8FCFFF",
		FlowerCore = "FFFFFF",
	}, "Pearl", S, {
		LightColor = "FFF0FF",
		FX = { { Texture = Kit.SPARKLE, Colors = { "FF4D73", "FFE83A", "3EF08A", "36B4FF", "A452FF" }, Rate = 5, Size = { 0.5, 0 }, Lifetime = { 0.6, 1.0 }, RotSpeed = { -120, 120 }, LightEmission = 1 } },
	})
end

return specs
