-- Storm Spires (x 1302..1577), built by CanyonBuilder.NewBiome: a slate canyon under a pale, wheeling storm.
-- Palette: charcoal and slate greys (no blue cast), pale storm-cloud greys overhead, bright yellow-white lightning,
-- small touches of electric blue.
--   Ground     slate in four greys, cracked into plates (dark crack lines, tilted plates, rubble), wet patches, lichen,
--              scorched strike marks with glowing fulgurite; Abyss sand giving way to slate at the border; puddles
--   Rock       charcoal strata cliffs, rugged crags behind (T.massif), the far ranges paler so the spires stand out
--   Spires     lightning-rod spires behind the cliffs, the tallest behind the nest, arcs leaping between them, key-lit
--   Islands    rock islands floating over the canyon, chained to the cliffs, lit from below, storm-glass under them
--   Sky        pale storm-cloud banks over the far ranges, the vortex wheeling over the far end (dark core, pale rim)
--   Coils      Tesla coils in the pockets
--   Nest       a ring of standing stones with copper rods arcing up to the tallest spire; storm-glass round the eggs
--   Gate       the Tesla Gate; while locked: a crackling energy field between two emitter posts, a kaiju's silhouette
--              looming behind it with glowing eyes, hazard-striped COMING SOON plates
-- Lights: key lights (WorldCuller keeps them on from afar) only on what reads from the gate; nothing deep inside.
local hex = Color3.fromHex

return function(b, K, T)
	local P = K.P
	local XA, XB = b.x0, b.x1
	local NX = XA + (b.NestAt or 0.55) * (XB - XA)
	local C, rng
	local heroTip

	---------------------------------------------------------------- colours
	local ROCK = { hex("25262A"), hex("34363B"), hex("4A4C52"), hex("62656B"), accent = hex("55575C") }
	local FARROCK = { hex("5E6066"), hex("6B6D73"), hex("7A7C82"), hex("888A90") }
	local SLATE = { hex("54565C"), hex("4B4D53"), hex("5C5E64"), hex("46484E") }
	local WET, SCORCH, LICHEN, TUFT = hex("3A3C42"), hex("232427"), hex("6C6A58"), hex("5D615A")
	local CRACK = hex("1C1D20")
	local ROAD = { hex("7A7C82"), hex("707278"), hex("84868C") }
	local SLABS = { hex("9A9CA2"), hex("8A8C92"), hex("A8AAB0") }
	local SANDY = { hex("5E8590"), hex("566A70"), hex("50555C") } -- Abyss sand turning to slate
	local PUDDLE = { hex("3C4048"), hex("444952") }
	local CAPS = { hex("3A3C42"), hex("44464C"), hex("303237") }
	local CRESTS = { hex("6E7076"), hex("7C7E84"), hex("62646A") }
	local BOLT, BOLT2 = hex("FFE85A"), hex("FFFBE0")
	local ELEC, ELEC2 = hex("5CC0FF"), hex("C8ECFF")
	local COPPER, COPPER2 = hex("B87333"), hex("8E5426")
	local IRON, IRON2 = P.Iron, P.IronLight
	local PALE = { hex("9A9EA6"), hex("AEB2B9"), hex("8A8E96") }
	local DARK = { hex("4A4D54"), hex("3C3F45"), hex("55585F") }
	local DEAD = hex("4A4540")
	local HAZARD, HAZARD2 = hex("FFC21A"), hex("1B1C1F")
	local KEY = hex("FFF2D0")

	---------------------------------------------------------------- layout
	local POOLS = { { 1330, 66, 6 }, { 1392, -40, 5 }, { 1426, 50, 6 }, { 1512, -42, 6 }, { 1548, 58, 5 }, { 1362, -70, 6 } }
	local function liquidGap(x, z)
		local g = math.huge
		for _, p in POOLS do
			local d = math.sqrt((x - p[1]) ^ 2 + ((z - p[2]) * 1.3) ^ 2)
			g = math.min(g, d - p[3] * (0.8 + 0.4 * T.n01(x / 4 + p[1], z / 4, 2.2)))
		end
		return g
	end
	local STRIKES = { { 1346, 30 }, { 1410, -30 }, { 1494, 36 }, { 1540, -20 }, { 1386, 44 } }
	local function nearStrike(x, z)
		for _, s in STRIKES do
			if (x - s[1]) ^ 2 + (z - s[2]) ^ 2 < 36 then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------- shapes
	-- a jagged line of neon between two points (an arc of lightning); blue = one of the electric-blue touches
	local function zap(parent, a, c, n, jitter, w, blue)
		local pts = { a }
		for i = 1, n - 1 do
			local p = a:Lerp(c, i / n)
			table.insert(pts, p + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * jitter)
		end
		table.insert(pts, c)
		T.chain(parent, "Arc", pts, { w or 0.45 }, blue and { ELEC2, ELEC } or { BOLT2, BOLT }, { neon = true, solid = false, shadow = false })
		return pts
	end
	-- a spire of stacked, tapering charcoal blocks with a lightning rod, an electric-blue collar and a glowing tip;
	-- key = light its lane-facing side from the front. Returns the tip.
	local function spire(parent, base, h, w, key)
		local m = K.model(parent, "LightningSpire")
		local y, x, z = base.Y - 2, base.X, base.Z
		local n = math.max(4, math.floor(h / 14))
		for i = 0, n - 1 do
			local t = i / n
			local lh = h / n
			local ww = w * (1 - t * 0.68)
			x += rng:NextNumber(-0.12, 0.12) * ww
			z += rng:NextNumber(-0.12, 0.12) * ww
			K.box(m, "SpireRock", x - ww / 2, x + ww / 2, y, y + lh + 0.4, z - ww / 2, z + ww / 2, T.tone(ROCK, Vector3.new(x, y + lh / 2, z), 0.1 + t * 0.55, rng), { studs = K.SIDES, solid = false })
			if i % 2 == 1 then
				K.box(m, "SpireBand", x - ww / 2 - 0.2, x + ww / 2 + 0.2, y + lh * 0.4, y + lh * 0.4 + 1, z - ww / 2 - 0.2, z + ww / 2 + 0.2, ROCK.accent, { solid = false })
			end
			if key and i == math.floor(n * 0.55) then
				local side = base.Z > 0 and -1 or 1
				local a = C.anchor(m, Vector3.new(x, y + lh / 2, z + side * (ww / 2 + 10)))
				C.keyLight(a, KEY, 60, 2.2)
			end
			y += lh
		end
		K.box(m, "RodCollar", x - 1.7, x + 1.7, y, y + 1.4, z - 1.7, z + 1.7, COPPER, { solid = false })
		K.box(m, "CollarGlow", x - 1.9, x + 1.9, y + 0.5, y + 0.9, z - 1.9, z + 1.9, ELEC, { neon = true, solid = false, shadow = false })
		K.box(m, "Rod", x - 0.45, x + 0.45, y + 1.4, y + 13, z - 0.45, z + 0.45, IRON2, { solid = false })
		for k = 0, 2 do
			K.box(m, "RodCoil", x - 0.9, x + 0.9, y + 3 + k * 2.2, y + 3.8 + k * 2.2, z - 0.9, z + 0.9, COPPER, { solid = false })
		end
		K.box(m, "Tip", x - 1, x + 1, y + 13, y + 15, z - 1, z + 1, BOLT2, { neon = true, solid = false, shadow = false })
		return Vector3.new(x, y + 14, z), m
	end
	-- a rock island floating at c (top surface at c.Y): an inverted cone of strata, storm-glass hanging under it, a rod
	-- and a dead tree on top; key = lit from below
	local function island(parent, c, r, key)
		local m = K.model(parent, "FloatingIsland")
		K.box(m, "IslandTop", c.X - r, c.X + r, c.Y - 1.2, c.Y, c.Z - r * 0.85, c.Z + r * 0.85, SLATE[1], { studs = K.TOP, solid = false })
		local y, rr = c.Y - 1.2, r
		local i = 0
		while rr > r * 0.18 do
			local lh = rng:NextNumber(3, 5)
			local ox, oz = rng:NextNumber(-0.1, 0.1) * rr, rng:NextNumber(-0.1, 0.1) * rr
			K.box(m, "IslandRock", c.X + ox - rr, c.X + ox + rr, y - lh, y, c.Z + oz - rr * 0.85, c.Z + oz + rr * 0.85, T.tone(ROCK, Vector3.new(c.X, y, c.Z), 0.75 - i * 0.12, rng), { studs = K.SIDES, solid = false })
			y -= lh
			rr *= rng:NextNumber(0.68, 0.8)
			i += 1
		end
		for k = 1, 3 do
			local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local p = Vector3.new(c.X + math.cos(a) * r * 0.35, y + (c.Y - y) * 0.35, c.Z + math.sin(a) * r * 0.3)
			C.crystal(m, p, rng:NextNumber(3, 6), 0.9, ELEC, ELEC2, true, CFrame.Angles(math.pi + rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)))
		end
		local px, pz = c.X + rng:NextNumber(-r * 0.5, r * 0.5), c.Z + rng:NextNumber(-r * 0.4, r * 0.4)
		K.box(m, "Pillar", px - 1.2, px + 1.2, c.Y, c.Y + rng:NextNumber(4, 8), pz - 1.2, pz + 1.2, SLABS[2], { studs = K.SIDES, solid = false })
		local tx, tz = c.X - (px - c.X) * 0.8, c.Z - (pz - c.Z) * 0.8
		T.chain(m, "DeadTree", { Vector3.new(tx, c.Y - 0.5, tz), Vector3.new(tx + 1, c.Y + 5, tz + 0.5), Vector3.new(tx + 3.5, c.Y + 8, tz - 0.5) }, { 1.1, 0.7 }, { DEAD }, { solid = false })
		K.box(m, "Rod", c.X - 0.35, c.X + 0.35, c.Y, c.Y + 9, c.Z - 0.35, c.Z + 0.35, IRON2, { solid = false })
		K.box(m, "RodTip", c.X - 0.7, c.X + 0.7, c.Y + 9, c.Y + 10.4, c.Z - 0.7, c.Z + 0.7, BOLT2, { neon = true, solid = false, shadow = false })
		if key then
			C.keyLight(C.anchor(m, Vector3.new(c.X, y - 6, c.Z)), ELEC2, 50, 2.4)
		end
		return m, Vector3.new(c.X, y, c.Z)
	end
	-- an iron chain from a to c (alternating links)
	local function chain(parent, a, c)
		local d = c - a
		local L = d.Magnitude
		local n = math.floor(L / 2.6)
		local F = CFrame.lookAt(a, c)
		for i = 0, n - 1 do
			local cf = F * CFrame.new(0, 0, -(i + 0.5) * L / n) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2)
			K.part(parent, "ChainLink", Vector3.new(0.5, 1.3, 2.9), cf, i % 2 == 0 and IRON or IRON2, { solid = false, shadow = false })
		end
	end
	-- a Tesla coil: an iron plinth, copper rings stacked and narrowing, a torus, a glowing sphere, arcs to the ground
	local function coil(parent, base, h, r, lit)
		local m = K.model(parent, "TeslaCoil")
		C.octagon(m, "Plinth", base, r * 1.4, base.Y - 1, base.Y + 2, IRON, { studs = K.ALL, solid = false })
		local n = math.max(4, math.floor(h / 3))
		for i = 0, n - 1 do
			local t = i / n
			local rr = r * (1 - t * 0.45)
			local y0 = base.Y + 2 + h * t
			C.octagon(m, i % 2 == 0 and "Coil" or "CoilBand", base, rr, y0, y0 + h / n, i % 2 == 0 and COPPER or COPPER2, { solid = false })
		end
		local top = base.Y + 2 + h
		C.octagon(m, "Torus", base, r * 1.15, top, top + r * 0.5, IRON2, { studs = K.ALL, solid = false })
		local sc = Vector3.new(base.X, top + r * 0.5 + r * 0.55, base.Z)
		C.sphere(m, "Sphere", sc, r * 0.6, function()
			return BOLT2
		end, { neon = true, solid = false, shadow = false })
		if lit then
			C.light(C.anchor(m, sc), BOLT, r * 6 + 14, 2)
		end
		for k = 1, 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = r * rng:NextNumber(2.2, 3.4)
			zap(m, sc, Vector3.new(base.X + math.cos(a) * d, base.Y + rng:NextNumber(0, h * 0.4), base.Z + math.sin(a) * d), 5, r * 0.35, 0.3, k == 2)
		end
		return m, sc
	end
	-- a crack across the slate: a zigzag of thin dark lines; glow = a fulgurite still glowing in it
	local function crackLine(parent, start, yaw, n, glow)
		local p = Vector3.new(start.X, 0, start.Z)
		for _ = 1, n do
			local a = yaw + rng:NextNumber(-0.8, 0.8)
			local len = rng:NextNumber(2.5, 5)
			local d = Vector3.new(math.sin(a), 0, math.cos(a)) * len
			local cf = CFrame.lookAt(p + d / 2, p + d)
			K.part(parent, "SlateCrack", Vector3.new(glow and 1 or 0.55, 0.1, len + 0.4), cf + Vector3.new(0, 0.05, 0), CRACK, { solid = false, shadow = false })
			if glow then
				K.part(parent, "Fulgurite", Vector3.new(0.35, 0.12, len), cf + Vector3.new(0, 0.07, 0), BOLT, { neon = true, solid = false, shadow = false })
			end
			p += d
		end
	end
	-- a hazard-striped iron plate in the Antique lettering (the Coming Soon signs)
	local function stormPlate(parent, cf, w, h, text, striped)
		local s = C.plaque(parent, cf, w, h, text, { board = hex("1E1F23"), frame = hex("6A6C72"), line = BOLT, text = hex("FFF2B0"), neon = true })
		local fw = math.max(0.8, h * 0.1)
		if striped then
			local W = w + fw * 2
			local n = math.floor(W / 3)
			for _, sy in { -1, 1 } do
				for i = 0, n - 1 do
					local x = -W / 2 + (i + 0.5) * W / n
					K.part(s, "Hazard", Vector3.new(W / n, fw * 0.9, 0.3), cf * CFrame.new(x, sy * (h / 2 + fw / 2), -1.05), i % 2 == 0 and HAZARD or HAZARD2, { solid = false, shadow = false })
				end
			end
		end
		return s
	end

	---------------------------------------------------------------- the theme
	local th = {
		seed = 6637,
		half = 92,
		accent = BOLT,
		gateOpenH = 54,
		blendLen = 26,
		rock = ROCK,
		farRock = FARROCK,
		rugged = true,
		slabs = SLABS,
		slabChance = 0.62,
		edgeN = { { 1302, 65 }, { 1312, 66 }, { 1324, 76 }, { 1340, 88 }, { 1358, 90 }, { 1372, 76 }, { 1386, 66 }, { 1400, 70 }, { 1414, 82 }, { 1430, 92 }, { 1476, 92 }, { 1490, 80 }, { 1504, 70 }, { 1518, 74 }, { 1534, 88 }, { 1552, 88 }, { 1564, 72 }, { 1572, 66 }, { 1577, 65 } },
		edgeS = { { 1302, 65 }, { 1314, 64 }, { 1328, 72 }, { 1344, 84 }, { 1360, 86 }, { 1374, 72 }, { 1388, 64 }, { 1402, 68 }, { 1418, 80 }, { 1434, 90 }, { 1472, 90 }, { 1488, 76 }, { 1502, 66 }, { 1516, 70 }, { 1532, 86 }, { 1550, 90 }, { 1564, 74 }, { 1572, 66 }, { 1577, 65 } },
		paths = {
			{ { 1302, 0, 14 }, { 1318, -6, 12 }, { 1336, -10, 12 }, { 1352, -2, 12 }, { 1368, 8, 12 }, { 1384, 10, 12 }, { 1400, 4, 12 }, { 1418, -4, 12 }, { 1436, 0, 12 } },
			{ { 1436, 0, 8 }, { 1439, 14, 7 }, { 1446, 26, 7 }, { 1461, 26, 7 }, { 1468, 14, 7 }, { 1471, 0, 8 } },
			{ { 1436, 0, 8 }, { 1439, -14, 7 }, { 1446, -26, 7 }, { 1461, -26, 7 }, { 1468, -14, 7 }, { 1471, 0, 8 } },
			{ { 1471, 0, 12 }, { 1486, 8, 12 }, { 1502, 10, 12 }, { 1518, 2, 12 }, { 1534, -8, 12 }, { 1550, -6, 12 }, { 1566, 0, 12 }, { 1577, 0, 13 } },
			{ { 1368, 8, 6 }, { 1366, 40, 6 }, { 1362, 62, 6 } }, -- to the north pocket's coil
			{ { 1534, -8, 6 }, { 1537, -40, 6 }, { 1540, -64, 6 } }, -- to the south pocket's coil
		},
		liquid = {
			gap = liquidGap,
			transparency = 0.25,
			top = -0.3,
			bed = hex("25272C"),
			color = function(_, _, _, n)
				return PUDDLE[n < 0.5 and 1 or 2]
			end,
		},
	}

	function th.init(ctx)
		C, rng = ctx, ctx.rng
	end

	function th.ground(ctx, x, z, n, n2)
		local dn = math.sqrt((x - NX) ^ 2 + z * z)
		if dn < 17.5 then
			return dn > 15 and ROCK[2] or SLABS[(math.floor(dn / 4) % 2) + 1]
		end
		if ctx.pathGap(x, z) <= 0 then
			return ROAD[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		local f = ctx.blend(x)
		if f > 0 and n2 < f * 1.3 - 0.1 then
			return SANDY[n2 < f * 0.6 - 0.2 and 1 or (n < 0.5 and 2 or 3)]
		end
		if nearStrike(x, z) then
			return SCORCH
		end
		if ctx.liquidGap(x, z) < 2 then
			return WET
		end
		local side = z >= 0 and 1 or -1
		if math.abs(z) > ctx.edge[side](x) - 9 and n2 < 0.35 then
			return n < 0.75 and TUFT or LICHEN
		end
		if n2 < 0.15 then
			return WET
		end
		if n2 > 0.93 then
			return LICHEN
		end
		return SLATE[math.clamp(math.floor(n * 4) + 1, 1, 4)]
	end

	function th.cap(ctx, x, r)
		local f = ctx.blend(x)
		if r:NextNumber() < f * f * 1.6 then
			return hex("2F8C78") -- the Abyss's last coral
		end
		return CAPS[r:NextInteger(1, #CAPS)]
	end

	function th.ridgeCap(_, _, r)
		return CRESTS[r:NextInteger(1, #CRESTS)]
	end

	function th.tint(x, c)
		local f = math.clamp(1 - (x - XA) / 34, 0, 1)
		return f > 0 and c:Lerp(hex("23405A"), f * 0.5) or c
	end

	function th.height(_, _, x, n)
		local h = 48 + n * 32
		if x < 1320 or x > 1560 then
			h = math.max(h, 66 + n * 10)
		end
		return math.floor(h / 2 + 0.5) * 2
	end

	function th.ridge(_, _, _, n)
		return math.floor(48 + n * 26) -- low crags, so the spires stand clear of them
	end

	function th.farHeight(_, _, _, n)
		return math.floor(92 + n * 56) -- paler and lower than the spires
	end

	function th.column(ctx, c, side)
		if c.h > 26 and rng:NextNumber() < 0.14 then
			T.faceCrack(ctx.sub("Scorch"), c, side, rng, BOLT, { neon = true, width = 0.45 })
		elseif c.h > 26 and rng:NextNumber() < 0.3 then
			T.faceCrack(ctx.sub("Scorch"), c, side, rng, SCORCH, { width = rng:NextNumber(0.8, 1.2) })
		end
		if rng:NextNumber() < 0.12 then
			local sx = rng:NextNumber(c.x0 + 1, c.x1 - 1)
			local sz = side * rng:NextNumber(c.lastFront + 2, math.max(c.lastFront + 2.1, c.back - 3))
			K.box(ctx.sub("Scorch"), "IronSpike", sx - 0.4, sx + 0.4, c.top + 1, c.top + rng:NextNumber(5, 9), sz - 0.4, sz + 0.4, IRON2, { solid = false })
		end
	end

	---------------------------------------------------------------- features
	function th.features(ctx)
		local sky, scatter = ctx.sub("Sky"), ctx.sub("Scatter")
		local spires = ctx.sub("Spires")
		-- the lightning spires (the ones that read from the gate are key-lit), arcs between neighbours
		local tips = {}
		local spots = { { 1334, 1, 112, 104, true }, { 1372, -1, 108, 116, true }, { 1412, 1, 116, 128, true }, { NX, 1, 124, 170, true }, { 1478, -1, 112, 132, true }, { 1520, 1, 110, 110 }, { 1556, -1, 114, 124 }, { 1346, -1, 120, 96 }, { 1540, 1, 126, 100 } }
		for _, s in spots do
			local tip = spire(spires, Vector3.new(s[1], 0, s[2] * s[3]), s[4], s[4] > 150 and 24 or 15, s[5])
			table.insert(tips, { p = tip, side = s[2] })
		end
		heroTip = tips[4].p
		for i, pair in { { 1, 3 }, { 3, 4 }, { 4, 6 }, { 2, 5 }, { 5, 7 } } do
			local a, c = tips[pair[1]].p, tips[pair[2]].p
			if (a - c).Magnitude < 160 then
				zap(sky, a, c, 9, 5, 0.5, i == 4)
			end
		end
		-- floating islands chained to the cliff tops, the big one over the nest
		local isl = ctx.sub("Islands")
		for _, d in { { 1342, 66, 58, 11, true }, { 1398, 84, -52, 13, true }, { 1500, 92, 50, 15 }, { 1546, 72, -64, 10 }, { NX - 6, 118, -18, 17, true } } do
			local _, bottom = island(isl, Vector3.new(d[1], d[2], d[3]), d[4], d[5])
			local ends
			if math.abs(d[3]) < 30 then
				ends = { Vector3.new(d[1] - 8, 50, 102), Vector3.new(d[1] + 8, 50, -102) }
			else
				local s = d[3] > 0 and 1 or -1
				ends = { Vector3.new(d[1] + rng:NextNumber(-10, 10), 46, s * 106) }
			end
			for _, e in ends do
				chain(isl, bottom + Vector3.new(0, 3, 0), e)
			end
		end
		-- Tesla coils in the pockets (only the one near the gate carries a light)
		local coils = ctx.sub("Coils")
		for _, cp in { { 1360, 70, 18, 3.2, true }, { 1541, -72, 20, 3.4 }, { 1528, 70, 14, 2.6 } } do
			coil(coils, Vector3.new(cp[1], 0, cp[2]), cp[3], cp[4], cp[5])
		end
		-- the storm vortex over the far end: a dark core, pale rims, a glowing eye, a bolt down to a spire
		local vx, vy = 1520, 236
		for ri, R in { 34, 62, 92, 124 } do
			local n = 8 + ri * 3
			for i = 0, n - 1 do
				local a = i / n * math.pi * 2 + ri * 0.4
				local p = Vector3.new(vx + math.cos(a) * R, vy - ri * 6 + math.sin(a * 3) * 3, math.sin(a) * R)
				local len = 2 * math.pi * R / n * 1.25
				local pal = ri <= 2 and DARK or PALE
				K.part(sky, "StormCloud", Vector3.new(len, rng:NextNumber(6, 12) + ri * 2, 10 + ri * 4), CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, math.rad(rng:NextNumber(-8, 8))), pal[(i + ri) % 3 + 1], { solid = false, shadow = false, transparency = ri > 2 and 0.1 * (ri - 2) or nil })
			end
		end
		local eye = K.box(sky, "VortexEye", vx - 12, vx + 12, vy + 2, vy + 4, -12, 12, BOLT2, { neon = true, transparency = 0.2, solid = false, shadow = false })
		K.box(sky, "VortexEye", vx - 20, vx + 20, vy + 1, vy + 2.4, -20, 20, ELEC2, { neon = true, transparency = 0.5, solid = false, shadow = false })
		ctx.keyLight(eye, BOLT2, 60, 2.5)
		zap(sky, Vector3.new(vx, vy, 0), tips[6].p, 12, 8, 0.9)
		-- pale storm-cloud banks over the far ranges either side
		for _, side in { 1, -1 } do
			local x = XA - 10
			while x < XB + 20 do
				for _ = 1, rng:NextInteger(1, 3) do
					local w, h, d = rng:NextNumber(30, 56), rng:NextNumber(10, 20), rng:NextNumber(34, 70)
					local cy = rng:NextNumber(150, 200)
					local cz = side * rng:NextNumber(170, 320)
					K.part(sky, "CloudBank", Vector3.new(w, h, d), CFrame.new(x + rng:NextNumber(-10, 10), cy, cz) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), (rng:NextNumber() < 0.7 and PALE or DARK)[rng:NextInteger(1, 3)], { solid = false, shadow = false, transparency = rng:NextNumber(0.05, 0.25) })
					K.part(sky, "CloudBank", Vector3.new(w * 0.6, h * 0.7, d * 0.6), CFrame.new(x + rng:NextNumber(-6, 6), cy - h * 0.6, cz - side * d * 0.25), DARK[rng:NextInteger(1, 3)], { solid = false, shadow = false, transparency = 0.1 })
				end
				x += rng:NextNumber(26, 40)
			end
		end
		-- strike marks: scorched patches with glowing fulgurite (smoke only near the gate, where it can be seen)
		for _, s in STRIKES do
			if s[1] < 1400 then
				T.crack(scatter, Vector3.new(s[1], 0, s[2]), rng:NextNumber(0, math.pi * 2), 3, rng, { dark = SCORCH, glow = BOLT, smoke = hex("8A8C92"), smokeSize = 1.5, smokeOpacity = 0.06 })
			else
				crackLine(scatter, Vector3.new(s[1], 0, s[2]), rng:NextNumber(0, math.pi * 2), 4, true)
			end
		end
		local function spot(margin, nestR)
			for _ = 1, 40 do
				local x, z = rng:NextNumber(XA + 6, XB - 6), rng:NextNumber(-90, 90)
				if ctx.inside(x, z, margin) and ctx.pathGap(x, z) > 2.5 and ctx.liquidGap(x, z) > 2 and not ctx.nearNest(x, z, nestR or 22) and not nearStrike(x, z) then
					return x, z
				end
			end
		end
		-- the slate floor broken up: crack networks, tilted plates, rubble
		local floor = ctx.sub("Slate")
		for _ = 1, 34 do
			local x, z = spot(2, 18)
			if x then
				local yaw = rng:NextNumber(0, math.pi * 2)
				crackLine(floor, Vector3.new(x, 0, z), yaw, rng:NextInteger(3, 5), false)
				if rng:NextNumber() < 0.5 then
					crackLine(floor, Vector3.new(x, 0, z), yaw + math.pi * rng:NextNumber(0.4, 0.7), rng:NextInteger(2, 3), false)
				end
			end
		end
		for _ = 1, 26 do
			local x, z = spot(3, 20)
			if x then
				local w, d = rng:NextNumber(3, 5.5), rng:NextNumber(2.4, 4)
				K.part(floor, "SlatePlate", Vector3.new(w, 0.5, d), CFrame.new(x, 0.12, z) * CFrame.Angles(math.rad(rng:NextNumber(-7, 7)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-7, 7))), SLATE[rng:NextInteger(1, 4)]:Lerp(Color3.new(1, 1, 1), 0.08), { studs = K.TOP, solid = false })
			end
		end
		for i = 1, 18 do
			local x, z = spot(3)
			if x then
				local r = rng:NextNumber(1.4, 3.2)
				T.boulder(scatter, Vector3.new(x, 0, z), r, ctx.rockAt, rng, { solid = r > 2.2 })
				for _ = 1, 2 do
					local q = Vector3.new(x + rng:NextNumber(-3.5, 3.5), 0, z + rng:NextNumber(-3.5, 3.5))
					local s = rng:NextNumber(0.5, 1)
					K.part(floor, "Rubble", Vector3.new(s * 1.4, s, s * 1.2), CFrame.new(q + Vector3.new(0, s * 0.35, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), ROCK[rng:NextInteger(2, 4)], { solid = false })
				end
			end
			if i <= 8 then
				x, z = spot(4)
				if x then
					local h = rng:NextNumber(6, 12)
					local m = K.model(scatter, "StandingStone")
					K.part(m, "Stone", Vector3.new(2.6, h, 1.8), CFrame.new(x, h / 2 - 0.3, z) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-6, 6))), ctx.rockAt(Vector3.new(x, h / 2, z), 0.5), { studs = K.SIDES, solid = false })
					K.box(m, "CopperBand", x - 1.5, x + 1.5, h * 0.6, h * 0.6 + 0.6, z - 1.1, z + 1.1, COPPER, { solid = false })
				end
			end
			if i <= 6 then
				x, z = spot(4)
				if x then
					local m = K.model(scatter, "DeadTree")
					local h = rng:NextNumber(7, 12)
					local lean = Vector3.new(rng:NextNumber(2, 4), 0, rng:NextNumber(-1, 1))
					T.chain(m, "Trunk", { Vector3.new(x, -0.4, z), Vector3.new(x, h * 0.5, z) + lean * 0.4, Vector3.new(x, h, z) + lean }, { 1.2, 0.8 }, { DEAD }, { studs = K.SIDES, solid = false })
					T.chain(m, "Branch", { Vector3.new(x, h * 0.6, z) + lean * 0.5, Vector3.new(x - 2, h * 0.85, z + 1.5) + lean * 0.5 }, { 0.5 }, { DEAD }, { solid = false })
				end
			end
		end
		-- lightning rods along the path (neon tips, no lights) and up on the crags
		for _ = 1, 7 do
			local x, z = spot(5, 24)
			if x then
				local m = K.model(scatter, "Rod")
				K.box(m, "RodBase", x - 1, x + 1, 0, 1, z - 1, z + 1, ctx.rockAt(Vector3.new(x, 0, z), 0.2), { studs = K.TOP, solid = false })
				K.box(m, "Rod", x - 0.3, x + 0.3, 1, 8, z - 0.3, z + 0.3, IRON2, { solid = false })
				K.box(m, "Tip", x - 0.6, x + 0.6, 8, 9.2, z - 0.6, z + 0.6, BOLT2, { neon = true, solid = false, shadow = false })
			end
		end
		for _, t in ctx.tops do
			if t.big and t.z1 > t.z0 and rng:NextNumber() < 0.3 then
				local x, z = t.x + rng:NextNumber(-2, 2), t.side * rng:NextNumber(t.z0, t.z1)
				local h = rng:NextNumber(8, 16)
				K.box(sky, "CragRod", x - 0.4, x + 0.4, t.y, t.y + h, z - 0.4, z + 0.4, IRON2, { solid = false })
				K.box(sky, "CragRodTip", x - 0.8, x + 0.8, t.y + h, t.y + h + 1.4, z - 0.8, z + 0.8, BOLT2, { neon = true, solid = false, shadow = false })
			end
		end
	end

	---------------------------------------------------------------- the nest: storm-glass round the eggs, standing stones round the altar
	function th.nest(ctx, art, c)
		ctx.octagon(art, "Bed", c, 6.4, -0.05, 0.28, hex("2C2D32"), { studs = K.TOP, solid = false })
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + 0.2
			local p = Vector3.new(c.X + math.cos(a) * 7.2, 0, c.Z + math.sin(a) * 7.2)
			local h = rng:NextNumber(2.2, 4.2)
			local cf = CFrame.new(p) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-22))
			K.part(art, "StormGlass", Vector3.new(1.2, h, 1.2), cf * CFrame.new(0, h / 2, 0), hex("4A4E58"), { solid = false })
			K.part(art, "StormGlassTip", Vector3.new(0.7, 1.1, 0.7), cf * CFrame.new(0, h + 0.5, 0), k % 3 == 0 and ELEC or BOLT2, { neon = true, solid = false, shadow = false })
		end
		for _, seg in { { -12, -9, 0.6 }, { -9, -12.5, 2.4 }, { -12.5, -8.5, 0.6 } } do
			local x0 = c.X + seg[1]
			K.box(art, "BoltInlay", x0 - 0.5, x0 + 0.5, 0, 0.08, c.Z + seg[2], c.Z + seg[2] + seg[3], BOLT, { neon = true, solid = false, shadow = false })
		end
		local ring = ctx.sub("Altar")
		local heights = { 14, 9, 16, 8, 15, 10 }
		for k, deg in { 60, 90, 120, 240, 270, 300 } do
			local a = math.rad(deg)
			local px, pz = NX + math.cos(a) * 15.6, math.sin(a) * 15.6
			local h = heights[k]
			local cf = CFrame.new(px, h / 2 - 0.4, pz) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-4, 4)))
			K.part(ring, "Megalith", Vector3.new(2.4, h, 4.2), cf, ctx.rockAt(Vector3.new(px, h / 2, pz), 0.6), { studs = K.SIDES, solid = false })
			K.part(ring, "CopperBand", Vector3.new(2.7, 0.7, 4.5), cf * CFrame.new(0, h * 0.2, 0), COPPER, { solid = false })
			local top = (cf * CFrame.new(0, h / 2, 0)).Position
			K.box(ring, "Rod", top.X - 0.3, top.X + 0.3, top.Y, top.Y + 4, top.Z - 0.3, top.Z + 0.3, IRON2, { solid = false })
			K.box(ring, "RodTip", top.X - 0.55, top.X + 0.55, top.Y + 4, top.Y + 5, top.Z - 0.55, top.Z + 0.55, BOLT2, { neon = true, solid = false, shadow = false })
			if h >= 15 then
				zap(ring, top + Vector3.new(0, 5, 0), heroTip, 12, 5, 0.35)
			end
		end
	end

	---------------------------------------------------------------- the Tesla Gate
	function th.gate(ctx, g)
		local gx = XA
		local spheres = {}
		for _, s in { -1, 1 } do
			local y = -2
			for i = 0, 2 do
				local lh = rng:NextInteger(5, 7)
				local hw = 15 - i * 1.5
				K.box(g, "Plinth", gx - hw, gx + hw, y, y + lh, s * (63 + i), s * (98 - i), T.tone(ROCK, Vector3.new(gx, y, s * 80), 0.2 + i * 0.2, rng), { studs = K.SIDES })
				y += lh
			end
			local b0 = Vector3.new(gx, y, s * 80)
			C.octagon(g, "CoilFoot", b0, 11, y, y + 3, IRON, { studs = K.ALL })
			local h = 60 - y
			local n = 12
			for i = 0, n - 1 do
				local t = i / n
				local rr = 9 * (1 - t * 0.4)
				local y0 = y + 3 + (h - 3) * t
				C.octagon(g, i % 2 == 0 and "Coil" or "CoilBand", b0, rr, y0, y0 + (h - 3) / n, i % 2 == 0 and COPPER or COPPER2, { studs = i % 2 == 0 and K.SIDES or nil })
			end
			C.octagon(g, "Torus", b0, 10, 60, 64, IRON2, { studs = K.ALL })
			C.octagon(g, "TorusRim", b0, 11, 61, 63, ELEC, { neon = true, solid = false, shadow = false })
			local sc = Vector3.new(gx, 72, s * 80)
			C.sphere(g, "Sphere", sc, 7, function(t)
				return t > 0.5 and BOLT2 or BOLT
			end, { neon = true, solid = false, shadow = false })
			ctx.keyLight(ctx.anchor(g, sc), BOLT2, 60, 2.5)
			table.insert(spheres, sc)
			for k = 1, 2 do
				zap(g, sc, Vector3.new(gx + rng:NextNumber(-14, 14), rng:NextNumber(10, 18), s * rng:NextNumber(66, 96)), 6, 3, 0.35, k == 2)
			end
		end
		K.box(g, "Girder", gx - 4, gx + 4, 56, 62, -72, 72, IRON, { studs = K.SIDES })
		K.box(g, "GirderFlange", gx - 5, gx + 5, 61.6, 62.8, -72, 72, IRON2, { solid = false })
		K.box(g, "GirderFlange", gx - 5, gx + 5, 55.2, 56.4, -72, 72, IRON2, { solid = false })
		for z = -66, 66, 6 do
			for _, fx in { -1, 1 } do
				K.box(g, "Rivet", gx + fx * 4 - 0.25, gx + fx * 4 + 0.25, 60.2, 60.9, z - 0.35, z + 0.35, IRON2, { solid = false, shadow = false })
			end
		end
		T.chain(g, "BoltEmblem", { Vector3.new(gx, 83, -6), Vector3.new(gx, 74, 4.5), Vector3.new(gx, 74, -4.5), Vector3.new(gx, 63.5, 6) }, { 2.6, 2, 2.6 }, { BOLT }, { neon = true, solid = false, shadow = false })
		local a, c = spheres[1], spheres[2]
		local pts = { a }
		for i = 1, 13 do
			local t = i / 14
			local p = a:Lerp(c, t) + Vector3.new(rng:NextNumber(-2.5, 2.5), 17 * math.sin(math.pi * t) + rng:NextNumber(-2.5, 2.5), 0)
			table.insert(pts, p)
		end
		table.insert(pts, c)
		T.chain(g, "GateArc", pts, { 1.1 }, { BOLT2, BOLT }, { neon = true, solid = false, shadow = false })
		ctx.plaque(g, CFrame.lookAt(Vector3.new(gx - 5.6, 59, 0), Vector3.new(gx - 30, 59, 0)), 44, 5.4, "STORM SPIRES", { board = hex("1E1F23"), frame = IRON2, line = BOLT, text = hex("FFF2B0"), neon = true })
	end

	---------------------------------------------------------------- the lock: a crackling energy field, a kaiju looming behind it
	function th.lock(ctx, cs, gx)
		local H = th.gateOpenH
		-- the emitter posts either side, ringed in copper, glowing blue at the top
		for _, s in { -1, 1 } do
			local z = s * 58
			K.box(cs, "EmitterPost", gx - 1.6, gx + 1.6, -1, H + 1, z - 1.6, z + 1.6, IRON, { studs = K.SIDES, solid = false })
			for y = 4, H - 4, 7 do
				K.box(cs, "EmitterCoil", gx - 2.1, gx + 2.1, y, y + 1.4, z - 2.1, z + 2.1, COPPER, { solid = false })
			end
			K.box(cs, "EmitterCap", gx - 2.4, gx + 2.4, H + 1, H + 2.6, z - 2.4, z + 2.4, ELEC, { neon = true, solid = false, shadow = false })
		end
		-- the field: a faint electric sheet, crackling arcs across it
		local field = K.box(cs, "Field", gx - 0.2, gx + 0.2, 0, H, -56.4, 56.4, ELEC2, { neon = true, transparency = 0.9, solid = false, shadow = false })
		for i = 1, 7 do
			local y0 = 4 + (i - 1) * (H - 8) / 6
			local y1 = math.clamp(y0 + rng:NextNumber(-8, 8), 3, H - 3)
			zap(cs, Vector3.new(gx - 0.5, y0, -56), Vector3.new(gx - 0.5, y1, 56), 11, 2.4, i % 3 == 0 and 0.5 or 0.35, i % 2 == 0)
		end
		ctx.emit(field, { name = "FieldSparks", colors = { BOLT2, ELEC2 }, size = { 0.5, 0.1 }, rate = 24, speed = { 1, 3 }, life = { 0.4, 0.9 }, spread = 180, light = 1, dir = Enum.NormalId.Left })
		-- the kaiju that waits beyond it: a hulking storm brute, black against the field, eyes burning
		local k = ctx.silhouette(cs, "Thunderback", Vector3.new(gx + 46, 0, 6), Vector3.new(-1, 0, -0.12), 46, { eye = BOLT2 })
		if k then
			ctx.keyLight(ctx.anchor(cs, Vector3.new(gx + 66, 34, 0)), ELEC2, 60, 3) -- the storm behind it, rimming its shape
		end
		-- hazard-striped plates, both ways
		for _, f in { -1, 1 } do
			local x = gx + f * 1.3
			local s1 = stormPlate(cs, CFrame.lookAt(Vector3.new(x, 24, 0), Vector3.new(x + f * 20, 24, 0)), 40, 8.4, "COMING SOON", true)
			s1.Name = "ComingSoon"
			local s2 = stormPlate(cs, CFrame.lookAt(Vector3.new(x, 14.5, 0), Vector3.new(x + f * 20, 14.5, 0)), 30, 4.6, "STORM SPIRES", false)
			s2.Name = "ComingSoonName"
		end
	end

	return require(script.Parent.NewBiome)(b, K, T, th)
end
