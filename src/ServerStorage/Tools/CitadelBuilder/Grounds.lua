-- The Kaiju Citadel's grounds (CitadelBuilder sections "Gardens", "Avenue", "Frames", "Stalls"), in the citadel kit's
-- studded style (Kit: patch stone, tan trim, navy / deep red / gold, real fire):
--   Gardens  hedge-bordered beds with trees and flowers, small stone kaiju statues on carved plinths, stone benches,
--            lamp posts, armouries (weapon racks, crates, barrels) at the feet of the towers - beside the market,
--            behind the plots, in the gaps between plots and along the walls. Nothing is placed inside a plot's lot
--            (pens grow to fill the whole lot), on the avenue, or in front of the plot signs.
--   Avenue   curbs and inlaid paving, kaiju ribcage arches over the avenue at the gaps between plots, stone planters,
--            braziers, banner poles of different heights
--   Frames   carved stone frames with gold trim and an egg crest round every leaderboard, torches between them (the
--            boards themselves are not touched)
--   Stalls   the market stalls recoloured in a medieval style: timber frames, canvas awnings (food gold, sell deep red,
--            trails navy) with trim, no candy stripes; the bunting in red, navy and gold. Only colours / materials
--            change: pads, prompts, the food and the trail wheel are left alone (MarketFX uses them)
local M = {}

local hex = Color3.fromHex
local G = {
	Leaf = hex("5FC23A"),
	LeafDark = hex("4EA52F"),
	LeafLight = hex("74D24B"),
	Hedge = hex("4A9A2E"),
	HedgeTop = hex("57AD35"),
	Trunk = hex("8B5A2B"),
	TrunkDark = hex("6B4423"),
	Soil = hex("7A5232"),
	Flowers = { hex("E8434A"), hex("F2C14E"), hex("F07AB0"), hex("F4F1E6"), hex("9B6CF0") },
	Wood = hex("7A5434"),
	WoodDark = hex("4A3020"),
	WoodLight = hex("A8784A"),
	Lantern = hex("FFB04A"),
}
M.Colors = G

local K, P
local function setup(kit)
	K, P = kit, kit.P
end

-- a frame at ground point (x, y, z) whose look vector is `face` flattened
local function facing(x, y, z, face)
	local d = Vector3.new(face.X, 0, face.Z)
	d = d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, -1)
	local p = Vector3.new(x, y, z)
	return CFrame.lookAt(p, p + d)
end

------------------------------------------------------------------------------- plants
-- broad voxel tree, about 20 x s tall (trunk solid, canopy walk-through)
local function oak(f, x, z, s, rng)
	local m = K.model(f, "Tree")
	local F = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local function tp(name, size, pos, color, o, roll)
		local c = F * CFrame.new(pos * s)
		if roll then
			c = c * CFrame.Angles(0, 0, math.rad(roll))
		end
		return K.part(m, name, size * s, c, color, o)
	end
	tp("Trunk", Vector3.new(2.6, 10, 2.6), Vector3.new(0, 5, 0), G.Trunk, { studs = K.SIDES })
	tp("Root", Vector3.new(4.6, 1.4, 1.6), Vector3.new(0, 0.7, 0), G.TrunkDark, { studs = K.ALL, solid = false })
	tp("Root", Vector3.new(1.6, 1.4, 4.6), Vector3.new(0, 0.7, 0), G.TrunkDark, { studs = K.ALL, solid = false })
	tp("Branch", Vector3.new(1.2, 4.4, 1.2), Vector3.new(1.8, 9.4, 0), G.Trunk, { solid = false }, -35)
	tp("Canopy", Vector3.new(11, 3, 9), Vector3.new(-1, 10.2, 1.2), G.LeafDark, { studs = K.ALL, solid = false })
	tp("Canopy", Vector3.new(14, 5, 13), Vector3.new(0, 12.5, 0), G.Leaf, { studs = K.ALL, solid = false })
	tp("Canopy", Vector3.new(10, 4, 10), Vector3.new(1.2, 16.5, -0.8), G.LeafLight, { studs = K.ALL, solid = false })
	tp("Canopy", Vector3.new(6, 3, 6), Vector3.new(-0.6, 19.5, 0.6), G.Leaf, { studs = K.ALL, solid = false })
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.4, 0.4)
		tp("Leaves", Vector3.new(4, 4, 4), Vector3.new(math.cos(a) * 6.8, 13 + rng:NextNumber(-1.5, 1.5), math.sin(a) * 6.2), i % 2 == 0 and G.LeafLight or G.LeafDark, { studs = K.ALL, solid = false })
	end
	return m
end

-- tall narrow conifer, h tall
local function cypress(f, x, z, h)
	local m = K.model(f, "Cypress")
	K.box(m, "Trunk", x - 0.9, x + 0.9, 0, 3, z - 0.9, z + 0.9, G.TrunkDark, { studs = K.SIDES })
	local tiers, w0 = 5, h * 0.34
	for i = 0, tiers - 1 do
		local t = i / tiers
		local w = w0 * (1 - t * 0.72)
		local y0 = 2 + (h - 2) * t
		local y1 = math.min(h, 2 + (h - 2) * (t + 1 / tiers) + 0.6)
		K.box(m, "Leaves", x - w / 2, x + w / 2, y0, y1, z - w / 2, z + w / 2, i % 2 == 0 and G.LeafDark or G.Leaf, { studs = K.ALL, solid = i == 0 })
	end
	return m
end

local function hedge(f, x0, x1, z0, z1, h)
	return K.box(f, "Hedge", x0, x1, 0, h or 3.4, z0, z1, G.Hedge, { studs = K.ALL })
end

-- soil bed with n flowers (a green tuft and a bloom each)
local function bed(f, x0, x1, z0, z1, n, rng)
	local m = K.model(f, "FlowerBed")
	K.box(m, "Soil", x0, x1, 0, 0.45, z0, z1, G.Soil, { studs = K.TOP, solid = false })
	local ax, bx = math.min(x0, x1) + 1, math.max(x0, x1) - 1
	local az, bz = math.min(z0, z1) + 1, math.max(z0, z1) - 1
	for _ = 1, n do
		local x, z = rng:NextNumber(ax, bx), rng:NextNumber(az, bz)
		local h = rng:NextNumber(1.2, 2.2)
		K.box(m, "Tuft", x - 0.6, x + 0.6, 0.45, 0.45 + h, z - 0.6, z + 0.6, G.LeafDark, { solid = false })
		K.box(m, "Bloom", x - 0.8, x + 0.8, 0.45 + h, 1.45 + h, z - 0.8, z + 0.8, G.Flowers[rng:NextInteger(1, #G.Flowers)], { studs = K.TOP, solid = false })
	end
	return m
end

------------------------------------------------------------------------------- furniture
local function lamp(f, x, z, h)
	h = h or 11
	local m = K.model(f, "Lamp")
	K.box(m, "LampBase", x - 1.2, x + 1.2, 0, 1, z - 1.2, z + 1.2, P.Base, { studs = K.ALL })
	K.box(m, "LampPost", x - 0.45, x + 0.45, 1, h, z - 0.45, z + 0.45, P.Iron, { studs = K.SIDES })
	K.box(m, "LampPan", x - 1.1, x + 1.1, h - 0.4, h, z - 1.1, z + 1.1, P.Iron, { solid = false })
	local glow = K.box(m, "LampGlow", x - 0.8, x + 0.8, h, h + 1.8, z - 0.8, z + 0.8, G.Lantern, { neon = true, solid = false })
	K.box(m, "LampCap", x - 1.3, x + 1.3, h + 1.8, h + 2.5, z - 1.3, z + 1.3, P.Iron, { solid = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 176, 90)
	l.Range = 16
	l.Brightness = 1.3
	l.Shadows = false
	l.Parent = glow
	return m
end

-- stone bench, its seat running along "x" or "z"
local function bench(f, x, z, along)
	local m = K.model(f, "Bench")
	local ax = along == "x"
	local dx, dz = ax and 3.2 or 1.3, ax and 1.3 or 3.2
	K.box(m, "BenchSeat", x - dx, x + dx, 1.6, 2.3, z - dz, z + dz, P.Light, { studs = K.ALL })
	for _, t in { -1, 1 } do
		local lx, lz = ax and x + t * 2.2 or x, ax and z or z + t * 2.2
		K.box(m, "BenchLeg", lx - 0.8, lx + 0.8, 0, 1.6, lz - 0.9, lz + 0.9, P.Mid, { studs = K.SIDES })
	end
	return m
end

local function crate(f, x, y, z, s)
	local m = K.model(f, "Crate")
	K.box(m, "Crate", x - s / 2, x + s / 2, y, y + s, z - s / 2, z + s / 2, G.Wood, { studs = K.ALL })
	for _, k in { 0.18, 0.72 } do
		K.box(m, "CrateBand", x - s / 2 - 0.1, x + s / 2 + 0.1, y + s * k, y + s * k + s * 0.12, z - s / 2 - 0.1, z + s / 2 + 0.1, G.WoodDark, { solid = false })
	end
	return m
end

local function barrel(f, x, z)
	local m = K.model(f, "Barrel")
	K.box(m, "Barrel", x - 1.5, x + 1.5, 0, 4, z - 1.5, z + 1.5, G.Wood, { studs = K.SIDES })
	K.box(m, "BarrelBulge", x - 1.7, x + 1.7, 1, 3, z - 1.7, z + 1.7, G.Wood, { studs = K.SIDES, solid = false })
	for _, y in { 0.9, 2.6 } do
		K.box(m, "Hoop", x - 1.8, x + 1.8, y, y + 0.5, z - 1.8, z + 1.8, P.Iron, { solid = false })
	end
	K.box(m, "Lid", x - 1.3, x + 1.3, 4, 4.3, z - 1.3, z + 1.3, G.WoodDark, { solid = false })
	return m
end

-- weapon rack (spears, an axe, a shield) facing `face`
local function rack(f, x, z, face)
	local m = K.model(f, "WeaponRack")
	local F = facing(x, 0, z, face)
	local function rp(name, size, cf, color, o)
		return K.part(m, name, size, cf, color, o or { solid = false })
	end
	rp("RackBase", Vector3.new(9, 0.8, 2), F * CFrame.new(0, 0.4, 0), G.WoodDark, { studs = K.ALL })
	for _, sx in { -1, 1 } do
		rp("RackPost", Vector3.new(0.8, 6, 0.8), F * CFrame.new(sx * 4, 3.8, 0.5), G.Wood, { studs = K.SIDES })
	end
	for _, y in { 2.2, 5.6 } do
		rp("RackRail", Vector3.new(9, 0.6, 0.8), F * CFrame.new(0, y, 0.5), G.WoodDark)
	end
	-- spears leaning back on the rails (top towards the back, +Z)
	for _, sx in { -2.8, -1.2, 0.4 } do
		local shaft = F * CFrame.new(sx, 4.9, -0.1) * CFrame.Angles(math.rad(7), 0, 0)
		rp("SpearShaft", Vector3.new(0.4, 9, 0.4), shaft, G.WoodLight)
		rp("SpearTip", Vector3.new(0.7, 1.8, 0.3), shaft * CFrame.new(0, 5.3, 0), P.IronLight)
	end
	local haft = F * CFrame.new(2.6, 3.6, -0.1) * CFrame.Angles(math.rad(6), 0, 0)
	rp("AxeHaft", Vector3.new(0.5, 6.4, 0.5), haft, G.WoodDark)
	rp("AxeHead", Vector3.new(1.8, 1.6, 0.4), haft * CFrame.new(0.7, 2.6, 0), P.IronLight)
	local shield = F * CFrame.new(-5.6, 2.2, -0.2) * CFrame.Angles(math.rad(12), 0, 0)
	rp("Shield", Vector3.new(3.4, 4, 0.5), shield, P.Red, { studs = { K.N.Front }, solid = false })
	rp("ShieldRim", Vector3.new(3.6, 0.5, 0.6), shield * CFrame.new(0, 1.9, 0), P.Gold)
	rp("ShieldBoss", Vector3.new(1, 1, 0.4), shield * CFrame.new(0, 0.1, -0.4), P.Gold)
	return m
end

-- stone planter with a shrub or flowers
local function planter(f, x, z, rng, kind)
	local m = K.model(f, "Planter")
	K.box(m, "PlanterBox", x - 3.5, x + 3.5, 0, 2.2, z - 2, z + 2, K.stone(Vector3.new(x, 1, z), 0.35, rng), { studs = K.SIDES })
	K.box(m, "PlanterRim", x - 3.8, x + 3.8, 2.2, 2.7, z - 2.3, z + 2.3, P.Tan, { studs = K.ALL })
	K.box(m, "Soil", x - 3.2, x + 3.2, 2.7, 2.9, z - 1.7, z + 1.7, G.Soil, { solid = false })
	if kind == "shrub" then
		K.box(m, "Shrub", x - 2.8, x + 2.8, 2.9, 5.4, z - 1.5, z + 1.5, G.Hedge, { studs = K.ALL, solid = false })
		K.box(m, "Shrub", x - 1.6, x + 1.8, 5.4, 6.6, z - 1, z + 1, G.HedgeTop, { studs = K.ALL, solid = false })
	else
		for i = 0, 3 do
			local fx = x - 2.4 + i * 1.6
			K.box(m, "Tuft", fx - 0.6, fx + 0.6, 2.9, 4.2, z - 0.6, z + 0.6, G.LeafDark, { solid = false })
			K.box(m, "Bloom", fx - 0.75, fx + 0.75, 4.2, 5.1, z - 0.75, z + 0.75, G.Flowers[rng:NextInteger(1, #G.Flowers)], { studs = K.TOP, solid = false })
		end
	end
	return m
end

------------------------------------------------------------------------------- small stone kaiju statues
-- { name, size, position, rotation (degrees: X tips +Y towards +Z / lifts a -Z front, Z rolls), tone, mirrored }
-- in the statue's frame: standing on y 0, facing -Z; k scales it (k = 1: the rex is about 22 tall, the horned one 13)
local REX = { -- upright and roaring, arms out (reads best from the front, the way players see it)
	{ "Foot", { 2.4, 1, 3.6 }, { 2.4, 0.5, -0.4 }, nil, "d", true },
	{ "Shin", { 2, 3.6, 2 }, { 2.4, 2.8, 0.4 }, nil, "d", true },
	{ "Thigh", { 2.8, 4, 3.4 }, { 2.4, 6, 0.8 }, { 10 }, "m", true },
	{ "Hips", { 5.6, 5, 4.6 }, { 0, 8.6, 0.8 }, nil, "m" },
	{ "Torso", { 5, 5.6, 4.2 }, { 0, 13.2, 0.2 }, { -8 }, "m" },
	{ "Belly", { 3.6, 8, 0.6 }, { 0, 10.8, -1.7 }, { -4 }, "l" },
	{ "Shoulders", { 6.4, 2.2, 3.4 }, { 0, 15.4, 0 }, nil, "m" },
	{ "Neck", { 3.2, 3, 3.2 }, { 0, 17.2, -0.8 }, { -15 }, "m" },
	{ "Head", { 3.4, 3, 4.8 }, { 0, 18.8, -2.6 }, { 25 }, "l" },
	{ "Jaw", { 3, 1, 4.2 }, { 0, 17.1, -3.3 }, { -10 }, "m" },
	{ "Brow", { 1.3, 0.8, 1.6 }, { 1.1, 20.5, -2.4 }, { 25 }, "l", true },
	{ "Eye", { 0.3, 0.5, 0.7 }, { 1.72, 19.4, -3.3 }, { 25 }, "socket", true },
	{ "Horn", { 0.7, 2.4, 0.7 }, { 1.1, 21.4, -1.2 }, { 40 }, "l", true },
	{ "UpperArm", { 1.3, 3.4, 1.3 }, { 3.6, 13.6, -0.6 }, { 0, 0, 25 }, "m", true },
	{ "Forearm", { 1.1, 3, 1.1 }, { 4.6, 11.8, -2.2 }, { -55 }, "m", true },
	{ "Claw", { 1.4, 0.9, 1.4 }, { 4.6, 11.2, -3.8 }, nil, "d", true },
	{ "Tail", { 3.6, 3.6, 4.4 }, { 0, 7, 4.2 }, { 20 }, "m" },
	{ "Tail", { 2.6, 2.6, 4.4 }, { 0, 5, 7.8 }, { 25 }, "d" },
	{ "Tail", { 1.6, 1.6, 4.2 }, { 0, 3.2, 11.2 }, { 20 }, "d" },
	{ "Plate", { 0.7, 2.6, 1.8 }, { 0, 16.6, 2.4 }, { -8 }, "l" },
	{ "Plate", { 0.7, 2.4, 1.8 }, { 0, 14.2, 2.8 }, { -8 }, "l" },
	{ "Plate", { 0.7, 2.2, 1.6 }, { 0, 11.6, 3.4 }, nil, "l" },
	{ "Plate", { 0.7, 2, 1.6 }, { 0, 8.8, 3.6 }, nil, "l" },
}
local HORNED = {
	{ "Leg", { 2, 4.4, 2 }, { 2.4, 2.2, -3.2 }, nil, "d", true },
	{ "Leg", { 2, 4.4, 2 }, { 2.4, 2.2, 3.2 }, nil, "d", true },
	{ "Body", { 5.8, 4.8, 9.4 }, { 0, 6.6, 0.4 }, nil, "m" },
	{ "Hump", { 4.8, 2.2, 5.2 }, { 0, 9.6, -0.6 }, nil, "m" },
	{ "Head", { 4, 3.6, 4.2 }, { 0, 6.8, -6.4 }, { 8 }, "l" },
	{ "Beak", { 2.6, 2.2, 1.8 }, { 0, 5.8, -9 }, nil, "d" },
	{ "Frill", { 6.8, 5.2, 1.1 }, { 0, 9.2, -4.6 }, { 20 }, "l" },
	{ "FrillSpike", { 0.8, 1.6, 0.8 }, { 2.4, 12, -4 }, { 20 }, "l", true },
	{ "FrillSpike", { 0.8, 1.8, 0.8 }, { 0, 12.3, -4 }, { 20 }, "l" },
	{ "BrowHorn", { 0.8, 0.8, 4.4 }, { 1.3, 8.6, -9.2 }, { 25 }, "l", true },
	{ "NoseHorn", { 0.9, 2.4, 0.9 }, { 0, 8.2, -8.8 }, { -20 }, "l" },
	{ "Eye", { 0.6, 0.5, 0.3 }, { 1.5, 7.6, -8.55 }, nil, "socket", true },
	{ "Tail", { 2.2, 2.2, 4.4 }, { 0, 6.2, 6.8 }, { 15 }, "m" },
	{ "Tail", { 1.3, 1.3, 3.6 }, { 0, 4.8, 10.4 }, { 20 }, "d" },
	{ "Spike", { 0.9, 1.8, 0.9 }, { 0, 11.4, -2.2 }, nil, "l" },
	{ "Spike", { 0.9, 1.8, 0.9 }, { 0, 11.4, -0.2 }, nil, "l" },
	{ "Spike", { 0.9, 1.6, 0.9 }, { 0, 11.2, 1.8 }, nil, "l" },
}

-- a weathered stone kaiju ("rex" or "horned") on a carved plinth with an egg relief, facing `face`
local function stoneStatue(f, x, z, face, kind, k, rng)
	local m = K.model(f, "KaijuStatue")
	local F0 = facing(x, 0, z, face)
	local function pp(name, size, y, color, o)
		return K.part(m, name, size, F0 * CFrame.new(0, y, 0), color, o)
	end
	pp("Plinth", Vector3.new(9, 2.4, 9), 1.2, P.Base, { studs = K.ALL })
	pp("Plinth", Vector3.new(7.4, 3.8, 7.4), 4.3, K.stone(Vector3.new(x, 4, z), 0.4, rng), { studs = K.ALL })
	pp("PlinthCap", Vector3.new(8.2, 0.9, 8.2), 6.65, P.Tan, { studs = K.ALL })
	K.eggRelief(m, F0 * CFrame.new(0, 2.4, -3.7), 0, 0.3, 2.4, P.Light, P.Gold)
	K.part(m, "Moss", Vector3.new(6, 1, 0.9), F0 * CFrame.new(rng:NextNumber(-1, 1), 0.5, -4.6), P.Moss, { studs = K.FRONT, solid = false })
	local FS = F0 * CFrame.new(0, 7.1, 0)
	for _, e in kind == "horned" and HORNED or REX do
		for _, sx in e[6] and { -1, 1 } or { 1 } do
			local pos = Vector3.new(e[3][1] * sx, e[3][2], e[3][3]) * k
			local c = FS * CFrame.new(pos)
			if e[4] then
				c = c * CFrame.Angles(math.rad(e[4][1] or 0), 0, math.rad((e[4][3] or 0) * sx))
			end
			local base = e[5] == "l" and P.Light or (e[5] == "d" and P.Blue or P.Mid)
			local color = e[5] == "socket" and P.Socket or K.shade(base, rng:NextNumber(-0.04, 0.04))
			K.part(m, e[1], Vector3.new(e[2][1], e[2][2], e[2][3]) * k, c, color, { studs = e[5] ~= "socket" and K.SIDES or nil, solid = false })
		end
	end
	return m
end

------------------------------------------------------------------------------- the gardens
function M.Gardens(root, map, ctx, kit)
	setup(kit)
	local f = K.model(root, "Gardens")
	local rng = Random.new(2024)
	for _, s in { 1, -1 } do
		local function Z(z)
			return s * z
		end
		local toAvenue = Vector3.new(0, 0, -s)
		local east = Vector3.new(1, 0, 0)
		-- 1) beside the market: a hedged bed with a tree, a big stone kaiju, lamps and a bench
		hedge(f, -40, -8, Z(62), Z(64.2))
		hedge(f, -40, -27, Z(42), Z(44.2))
		hedge(f, -21, -8, Z(42), Z(44.2))
		hedge(f, -40, -37.8, Z(44.2), Z(62))
		hedge(f, -10.2, -8, Z(44.2), Z(50))
		hedge(f, -10.2, -8, Z(56), Z(62))
		bed(f, -37.8, -10.2, Z(44.2), Z(62), 10, rng)
		oak(f, -24, Z(53), 0.9, rng)
		stoneStatue(f, 8, Z(54), toAvenue, s > 0 and "rex" or "horned", s > 0 and 1 or 1.3, rng)
		lamp(f, -44, Z(40))
		lamp(f, -4, Z(38))
		bench(f, -24, Z(69), "x")
		-- 2) between the fountain and the first plot
		oak(f, 8, Z(88), 1.1, rng)
		hedge(f, -10, 22, Z(98), Z(100.2))
		hedge(f, -10, 22, Z(122), Z(124.2))
		hedge(f, 19.8, 22, Z(100.2), Z(122))
		hedge(f, -10, -7.8, Z(100.2), Z(108))
		hedge(f, -10, -7.8, Z(114), Z(122))
		bed(f, -7.8, 19.8, Z(100.2), Z(122), 12, rng)
		cypress(f, 6, Z(111), 16)
		bench(f, -13, Z(111), "z")
		oak(f, 8, Z(136), 1, rng)
		lamp(f, -12, Z(90))
		lamp(f, -12, Z(132))
		-- armoury at the foot of the tower at x -20
		rack(f, -20, Z(146), toAvenue)
		crate(f, -31, 0, Z(146), 4)
		crate(f, -27, 0, Z(147), 3.4)
		crate(f, -30.5, 4, Z(146.2), 3)
		barrel(f, -9, Z(146))
		barrel(f, -5.6, Z(144.4))
		-- 3) behind the fountain, along the wall
		hedge(f, -104, -40, Z(150), Z(152.6), 4)
		cypress(f, -97, Z(144), 18)
		cypress(f, -80, Z(146), 15)
		bench(f, -60, Z(145), "x")
		-- 4) the armoury by the west wall, between the Keep and the west tower
		rack(f, -102.5, Z(95), east)
		rack(f, -102.5, Z(146), east)
		crate(f, -101, 0, Z(104), 4)
		crate(f, -100.6, 4, Z(104.4), 3)
		barrel(f, -95, Z(89))
		barrel(f, -92, Z(91.6))
		cypress(f, -95, Z(124), 16)
		-- 5) behind each plot: a hedged bed with a tree, two cypresses, benches and lamps
		for _, cx in { 61, 157, 253 } do
			hedge(f, cx - 14, cx + 14, Z(140), Z(142.2))
			hedge(f, cx - 14, cx - 2, Z(124), Z(126.2))
			hedge(f, cx + 2, cx + 14, Z(124), Z(126.2))
			hedge(f, cx - 14, cx - 11.8, Z(126.2), Z(140))
			hedge(f, cx + 11.8, cx + 14, Z(126.2), Z(140))
			bed(f, cx - 11.8, cx + 11.8, Z(126.2), Z(140), 10, rng)
			oak(f, cx, Z(133), 0.85, rng)
			cypress(f, cx - 26, Z(132), 17)
			cypress(f, cx + 26, Z(132), 17)
			bench(f, cx - 8, Z(120), "x")
			bench(f, cx + 8, Z(120), "x")
			lamp(f, cx - 20, Z(119))
			lamp(f, cx + 20, Z(119))
		end
		-- 6) armouries at the feet of the towers at x 90 and 195
		for _, tx in { 90, 195 } do
			rack(f, tx, Z(146), toAvenue)
			crate(f, tx - 10, 0, Z(146), 4)
			crate(f, tx - 10.2, 4, Z(146.3), 3)
			barrel(f, tx + 9, Z(146))
			barrel(f, tx + 12.4, Z(144.6))
		end
		-- 7) the gaps between the plots: a stone path to a kaiju statue, hedges, flower strips, lamps
		for _, gx in { 109, 205 } do
			for z0 = 22, 110, 8 do
				K.box(f, "Path", gx - 2.5, gx + 2.5, 0, 0.14, Z(z0), Z(z0 + 8), (z0 / 8) % 2 == 0 and P.Light or P.Mid, { studs = K.TOP, solid = false })
			end
			hedge(f, gx - 10.5, gx - 8.5, Z(38), Z(112))
			hedge(f, gx + 8.5, gx + 10.5, Z(38), Z(112))
			for _, zr in { { 38, 66 }, { 82, 112 } } do
				bed(f, gx - 8.5, gx - 3, Z(zr[1]), Z(zr[2]), 5, rng)
				bed(f, gx + 3, gx + 8.5, Z(zr[1]), Z(zr[2]), 5, rng)
			end
			local horned = (gx == 109) == (s > 0)
			stoneStatue(f, gx, Z(74), toAvenue, horned and "horned" or "rex", horned and 1.15 or 0.85, rng)
			lamp(f, gx - 6, Z(68))
			lamp(f, gx + 6, Z(80))
		end
	end
	return f
end

------------------------------------------------------------------------------- the avenue
-- a kaiju ribcage arching over the avenue at x = gx: four ribs and a spine of vertebrae, sockets of stone at the feet
local function ribArch(f, gx, rng)
	local m = K.model(f, "RibArch")
	local SPAN, H, N = 26, 44, 7
	for _, rx in { gx - 11, gx - 4.5, gx + 4.5, gx + 11 } do
		for _, s in { -1, 1 } do
			K.box(m, "RibSocket", rx - 2, rx + 2, 0, 3, s * (SPAN - 2), s * (SPAN + 2), K.stone(Vector3.new(rx, 1, s * SPAN), 0.2, rng), { studs = K.ALL })
			K.box(m, "RibBand", rx - 2.2, rx + 2.2, 2.4, 3.2, s * (SPAN - 2.2), s * (SPAN + 2.2), P.Iron, { solid = false })
			local pts = {}
			for i = 0, N do
				local t = i / N * math.pi / 2
				pts[i + 1] = Vector3.new(rx, 1.5 + (H - 1.5) * math.sin(t), s * (2 + (SPAN - 2) * math.cos(t)))
			end
			for i = 1, N do
				local a, b = pts[i], pts[i + 1]
				local d = b - a
				local w = 3.2 - (i - 1) * 0.2
				local mid = (a + b) / 2
				K.part(m, "Rib", Vector3.new(w, d.Magnitude + w * 0.6, w * 0.9), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.rad(90), 0, 0), i % 2 == 0 and P.BoneShade or P.Bone, { studs = K.SIDES, solid = false })
			end
		end
	end
	for x = gx - 13, gx + 13.01, 3.25 do
		K.box(m, "Vertebra", x - 1.2, x + 1.2, H - 1, H + 2.2, -2.4, 2.4, P.Bone, { studs = K.ALL, solid = false })
		K.box(m, "Spinous", x - 0.6, x + 0.6, H + 2.2, H + 4.6, -0.8, 0.8, P.BoneShade, { solid = false })
	end
	return m
end

local BANNERS
local function bannerPole(f, x, z, h, armDir, n)
	local m = K.model(f, "BannerPole")
	K.box(m, "PoleBase", x - 1.6, x + 1.6, 0, 1.4, z - 1.6, z + 1.6, P.Base, { studs = K.ALL })
	K.box(m, "Pole", x - 0.6, x + 0.6, 1.4, h, z - 0.6, z + 0.6, P.Iron, { studs = K.SIDES })
	K.box(m, "PoleCap", x - 1.1, x + 1.1, h, h + 1.6, z - 1.1, z + 1.1, P.Gold, { studs = K.ALL })
	K.egg(m, Vector3.new(x, h + 1.6, z), 2.2, P.Gold)
	K.box(m, "Arm", x, x + armDir * 9, h - 2.8, h - 1.8, z - 0.4, z + 0.4, P.Bronze, { solid = false })
	local bx = x + armDir * 5.2
	local side = z > 0 and 1 or -1
	K.banner(m, CFrame.lookAt(Vector3.new(bx, h - 3.4, z), Vector3.new(bx, h - 3.4, z - side * 10)), 7, math.floor(h * 0.48), BANNERS[(n - 1) % #BANNERS + 1])
	return m
end

function M.Avenue(root, map, ctx, kit)
	setup(kit)
	BANNERS = {
		{ cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold },
		{ cloth = P.Navy, trim = P.Gold, emblem = "egg", mark = P.Gold, tail = "point" },
		{ cloth = P.Red, trim = P.Bronze, emblem = "skull", mark = P.Bone },
		{ cloth = P.Navy, trim = P.Red, emblem = "chevron", mark = P.Gold },
	}
	local f = K.model(root, "Avenue")
	local rng = Random.new(808)
	-- curbs and inlays: tan border lines, gold-centred diamonds down the middle
	for _, s in { -1, 1 } do
		K.box(f, "Curb", 0, 289, 0, 0.35, s * 20, s * 21.6, P.Base, { studs = K.TOP, solid = false })
		K.box(f, "Inlay", 0, 289, 0, 0.14, s * 11.4, s * 12.6, P.Tan, { studs = K.TOP, solid = false })
	end
	for x = 30, 279, 24 do
		K.part(f, "Inlay", Vector3.new(5, 0.14, 5), CFrame.new(x, 0.07, 0) * CFrame.Angles(0, math.rad(45), 0), P.Tan, { studs = K.TOP, solid = false })
		K.part(f, "InlayGold", Vector3.new(2.2, 0.2, 2.2), CFrame.new(x, 0.1, 0) * CFrame.Angles(0, math.rad(45), 0), P.Gold, { solid = false })
	end
	ribArch(f, 109, rng)
	ribArch(f, 205, rng)
	local n = 0
	for _, s in { 1, -1 } do
		for _, x in { 14, 93, 125, 189, 221 } do
			K.brazier(f, Vector3.new(x, 0, s * 24.5), 1)
		end
		for _, cx in { 61, 157, 253 } do
			planter(f, cx - 18, s * 25, rng, "shrub")
			planter(f, cx + 25, s * 25, rng, "flowers")
		end
		-- banner poles of different heights: at both ends of the avenue and at the mouths of the gaps
		local tall, short = s > 0 and 38 or 28, s > 0 and 28 or 38
		for _, p in { { 20, 34, 1 }, { 97.5, tall, -1 }, { 120.5, short, 1 }, { 193.5, tall, -1 }, { 216.5, short, 1 }, { 284, 30, -1 } } do
			n += 1
			bannerPole(f, p[1], s * (p[1] > 30 and p[1] < 280 and 33 or 31), p[2], p[3], n)
		end
	end
	return f
end

------------------------------------------------------------------------------- leaderboard frames
function M.Frames(root, map, ctx, kit)
	setup(kit)
	local f = K.model(root, "Frames")
	local rng = Random.new(5150)
	local boards = map:FindFirstChild("Leaderboards")
	local torches = {}
	for _, b in boards and boards:GetChildren() or {} do
		if b:IsA("Model") then
			local cf, size = b:GetBoundingBox()
			local W, H, D = size.X, size.Y, size.Z
			local m = K.model(f, "Frame_" .. b.Name)
			local back = 0.4 -- the frame sits a little behind the board's face
			local fd = D + 1.2
			local function fp(name, sz, pos, color, o)
				return K.part(m, name, sz, cf * CFrame.new(pos), color, o)
			end
			local sw = 1.6
			for _, sx in { -1, 1 } do
				local x = sx * (W / 2 + sw / 2)
				fp("FrameSide", Vector3.new(sw, H + 0.6, fd), Vector3.new(x, -0.3, back), K.stone(cf * Vector3.new(x, 0, 0), 0.55, rng), { studs = K.ALL })
				fp("FrameGold", Vector3.new(0.35, H - 1, 0.3), Vector3.new(x - sx * 0.3, -0.3, back - fd / 2 - 0.12), P.Gold, { solid = false })
				-- a torch on each side; where two boards meet they share one
				local at = cf * Vector3.new(x, 0, -D / 2)
				local shared = false
				for _, q in torches do
					if (q - at).Magnitude < 5 then
						shared = true
					end
				end
				if not shared then
					table.insert(torches, at)
					K.torch(m, cf * CFrame.new(x, -H / 2, back - fd / 2), 0, H * 0.5)
				end
			end
			local LW = W + sw * 2 + 1.2
			fp("Lintel", Vector3.new(LW, 2.6, fd + 0.4), Vector3.new(0, H / 2 + 1.3, back), K.stone(cf * Vector3.new(0, H / 2, 0), 0.85, rng), { studs = K.ALL })
			fp("LintelGold", Vector3.new(LW, 0.5, fd + 0.6), Vector3.new(0, H / 2 + 0.25, back), P.Gold, { solid = false })
			fp("LintelCap", Vector3.new(LW + 0.6, 0.9, fd + 0.8), Vector3.new(0, H / 2 + 3.05, back), P.Tan, { studs = K.ALL, solid = false })
			for _, sx in { -1, 1 } do
				fp("LintelStud", Vector3.new(1.2, 1.2, 0.5), Vector3.new(sx * (LW / 2 - 1.4), H / 2 + 1.4, back - (fd + 0.4) / 2 - 0.2), P.Gold, { solid = false })
			end
			K.egg(m, (cf * CFrame.new(0, H / 2 + 3.5, back)).Position, 2.8, P.Gold, P.Red)
		end
	end
	return f
end

------------------------------------------------------------------------------- the market stalls
function M.Stalls(map, kit)
	setup(kit)
	local changed = {}
	local market = map:FindFirstChild("Market")
	if not market then
		return changed
	end
	local STYLE = {
		FoodStall = { main = hex("C9952B"), shade = hex("A67A1F"), trim = P.Red, label = "gold canvas, deep red trim" },
		SellStall = { main = P.Red, shade = P.RedDark, trim = P.Gold, label = "deep red canvas, gold trim" },
		TrailStall = { main = P.Navy, shade = hex("1C1B3A"), trim = P.Gold, label = "navy canvas, gold trim" },
	}
	local WOOD = {
		Post = G.Wood, BackWall = G.Wood, Step = G.Wood, KeeperStand = G.Wood, Barrel = G.Wood,
		PostFoot = G.WoodDark, Beam = G.WoodDark, Seam = G.WoodDark, Deck = G.WoodDark, ShelfBracket = G.WoodDark, SignPost = G.WoodDark,
		CounterBase = P.TimberDark, Skirt = P.TimberDark, Scratch = P.TimberDark,
		CounterTop = G.WoodLight, SideRail = G.WoodLight, Shelf = G.WoodLight,
		Counter = P.Timber, SideWall = P.Timber,
		Hoop = P.Iron, LanternCap = P.Iron, Chain = P.Iron,
	}
	local streamers = { P.Red, P.Navy, P.Gold }
	for name, st in STYLE do
		local stall = market:FindFirstChild(name)
		if stall then
			local k = 0
			for _, d in stall:GetChildren() do
				if d:IsA("BasePart") then
					local n = d.Name
					if n == "Canopy" then
						-- remember which stripes were white the first time, so re-runs keep the same two tones
						if d:GetAttribute("CanvasShade") == nil then
							d:SetAttribute("CanvasShade", d.Color:ToHex() == "ffffff")
						end
						d.Color = d:GetAttribute("CanvasShade") and st.shade or st.main
					elseif n == "Valance" or n == "Ridge" then
						d.Color = st.shade
					elseif n == "Tooth" or n == "Fascia" or n == "Band" or n == "SignCap" or n == "KeeperStandTrim" then
						d.Color = st.trim
					elseif n == "Inside" then
						d.Color = st.shade:Lerp(Color3.new(0, 0, 0), 0.35)
					elseif n == "Plate" then -- the carnival bulbs on the awning's edge become gold rivets
						d.Color = P.Gold
						d.Material = Enum.Material.SmoothPlastic
					elseif n == "Lantern" then
						d.Color = G.Lantern
					elseif n == "Streamer" then
						k += 1
						d.Color = streamers[(k - 1) % #streamers + 1]
					elseif WOOD[n] then
						d.Color = WOOD[n]
					end
				end
			end
			table.insert(changed, name .. ": " .. st.label .. ", timber frame")
		end
	end
	-- the bunting: pennants in red / navy / gold on dark cords
	local decor = market:FindFirstChild("Decor")
	for _, b in decor and decor:GetChildren() or {} do
		if b.Name == "Bunting" then
			local k = 0
			for _, d in b:GetDescendants() do
				if d:IsA("BasePart") then
					if math.max(d.Size.X, d.Size.Y, d.Size.Z) > 5 then
						d.Color = P.TimberDark
					else
						k += 1
						d.Color = streamers[(k - 1) % #streamers + 1]
						d.Material = Enum.Material.SmoothPlastic
					end
				end
			end
		end
	end
	table.insert(changed, "Bunting: red / navy / gold pennants")
	return changed
end

return M
