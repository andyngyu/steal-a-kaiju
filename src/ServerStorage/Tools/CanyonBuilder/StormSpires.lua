-- Storm Spires (x 1302..1577), built by CanyonBuilder.NewBiome: a slate canyon under a pale, wheeling storm.
-- Palette: charcoal and slate greys (no blue cast), pale storm-cloud greys overhead, bright yellow-white lightning,
-- small touches of electric blue.
--   Ground     slate in four greys, cracked into plates (dark crack lines, tilted plates, rubble), wet patches, lichen,
--              scorched strike marks with glowing fulgurite; Abyss sand giving way to slate at the border; puddles
--   Rock       charcoal strata cliffs, rugged crags behind (T.massif), the far ranges paler so the spires stand out
--   Spires     lightning-rod spires behind the cliffs, the tallest behind the nest, arcs leaping between them, key-lit
--   Islands    rock islands floating over the canyon, chained to the cliffs, lit from below, storm-glass under them
--   Sky        a dark storm cloud swirling over the far end (spiral arms of cloud, a funnel under its eye, lightning
--              flickering inside, turning slowly: BiomeFX SpinCloud) and broken cloud over the gate end; the overcast
--              sky and grey light come from VFXConfig.Weather.StormSpires
--   Bolts      every bolt is its own model tagged FlickerBolt: dark until it strikes now and then (BiomeFX)
--   Coils      dark iron Tesla coils with copper rings and an electric glow on top, in the pockets and on the gate
--   Nest       a ring of standing stones with copper rods arcing up to the tallest spire; storm-glass round the eggs
--   Gate       the Tesla Gate; while locked: a faint energy field between two emitter posts that a few thick bolts
--              strike across, a kaiju's silhouette looming behind it with glowing eyes, a riveted dark-metal COMING
--              SOON plate with an electric-blue edge (the name stays only on the girder)
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
	local DEAD = hex("4A4540")
	local KEY = hex("FFF2D0")
	local CORE, CORE2 = hex("2A2C31"), hex("34373D") -- the coils' dark iron
	local CLOUDD = { hex("23252A"), hex("2B2D33"), hex("32353B") } -- storm cloud, inner
	local CLOUDM = { hex("3C3F46"), hex("464950"), hex("50535B") } -- storm cloud, outer
	local CS = game:GetService("CollectionService")

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
	-- a bolt that strikes now and then: its own model tagged FlickerBolt (BiomeFX keeps it dark between strikes), a
	-- flash light at its middle if o.light (range). o: blue, light, min / max gap (s), name
	local function bolt(parent, a, c, n, jitter, w, o)
		o = o or {}
		local m = K.model(parent, o.name or "Bolt")
		local pts = zap(m, a, c, n, jitter, w, o.blue)
		if o.light then
			C.light(C.anchor(m, pts[math.ceil(#pts / 2)]), o.blue and ELEC2 or BOLT2, o.light, 4)
		end
		m:SetAttribute("MinGap", o.min or 2.5)
		m:SetAttribute("MaxGap", o.max or 7)
		CS:AddTag(m, "FlickerBolt")
		return m, pts
	end
	-- a dark storm-cloud puff: three overlapping blocks of different sizes, turned, stacked a little
	local function puff(parent, p, s, inner, shade)
		local pal = inner and CLOUDD or CLOUDM
		for j = 1, 3 do
			local size = Vector3.new(s * rng:NextNumber(0.8, 1.3), s * rng:NextNumber(0.32, 0.52), s * rng:NextNumber(0.7, 1.1))
			local off = Vector3.new(rng:NextNumber(-0.4, 0.4) * s, (j - 2) * s * 0.16, rng:NextNumber(-0.4, 0.4) * s)
			K.part(parent, "StormCloud", size, CFrame.new(p + off) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), pal[rng:NextInteger(1, 3)], { solid = false, shadow = shade == true and nil or false })
		end
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
	-- a thick bolt striking across the plane x = a.X: jagged in y and z only, a short fork; it flickers (FlickerBolt)
	local function crackle(parent, a, c, n, jy, jz, w, blue, gap)
		local m = K.model(parent, "FieldBolt")
		m:SetAttribute("MinGap", gap and gap[1] or 1.5)
		m:SetAttribute("MaxGap", gap and gap[2] or 4.5)
		CS:AddTag(m, "FlickerBolt")
		parent = m
		local pts = { a }
		for i = 1, n - 1 do
			local p = a:Lerp(c, i / n)
			table.insert(pts, p + Vector3.new(0, rng:NextNumber(-jy, jy), rng:NextNumber(-jz, jz)))
		end
		table.insert(pts, c)
		local cols = blue and { ELEC2, ELEC } or { BOLT2, BOLT }
		T.chain(parent, "Arc", pts, { w }, cols, { neon = true, solid = false, shadow = false })
		local k = rng:NextInteger(2, #pts - 1)
		local q = pts[k]
		local e = q + Vector3.new(0, rng:NextNumber(-8, 8), rng:NextNumber(-7, 7))
		T.chain(parent, "ArcFork", { q, (q + e) / 2 + Vector3.new(0, rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)), e }, { w * 0.55 }, cols, { neon = true, solid = false, shadow = false })
		if w >= 0.9 then
			C.light(C.anchor(parent, pts[math.ceil(#pts / 2)]), blue and ELEC2 or BOLT2, 50, 4)
		end
		return m
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
	-- a Tesla coil: a dark iron core in segments narrowing upwards, thin copper rings standing proud of it, a dark
	-- torus with a glowing electric-blue rim, a white-blue sphere; o.solid (the gate's), o.studs, o.light, o.bolts
	local function teslaCoil(parent, base, h, r, o)
		o = o or {}
		local m = K.model(parent, "TeslaCoil")
		local solid = o.solid == true
		local n = math.max(4, math.floor(h / (r * 0.75)))
		for i = 0, n - 1 do
			local t = i / n
			local rr = r * (1 - t * 0.4)
			local y0 = base.Y + h * t
			local y1 = base.Y + h * (t + 1 / n)
			C.octagon(m, "CoilCore", base, rr, y0, y1, i % 2 == 0 and CORE or CORE2, { studs = o.studs and K.SIDES or nil, solid = solid })
			if i % 2 == 1 or n < 6 then
				C.octagon(m, "CopperRing", base, rr + r * 0.16, y0 + (y1 - y0) * 0.3, y0 + (y1 - y0) * 0.62, COPPER2, { solid = false })
			end
		end
		local top = base.Y + h
		C.octagon(m, "Torus", base, r * 1.25, top, top + r * 0.5, IRON, { studs = o.studs and K.ALL or nil, solid = solid })
		C.octagon(m, "TorusGlow", base, r * 1.33, top + r * 0.14, top + r * 0.36, ELEC, { neon = true, solid = false, shadow = false })
		local sc = Vector3.new(base.X, top + r * 0.5 + r * 0.62, base.Z)
		C.sphere(m, "Sphere", sc, r * 0.68, function(t)
			return t > 0.5 and Color3.new(1, 1, 1) or ELEC2
		end, { neon = true, solid = false, shadow = false })
		if o.light then
			C.keyLight(C.anchor(m, sc), ELEC2, o.light, 2.5)
		end
		for k = 1, (o.bolts or 1) do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = r * rng:NextNumber(2.2, 3.4)
			bolt(m, sc, Vector3.new(base.X + math.cos(a) * d, base.Y + rng:NextNumber(0, h * 0.4), base.Z + math.sin(a) * d), 6, r * 0.35, math.max(0.35, r * 0.09), { blue = k % 2 == 0, min = 2, max = 5 })
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
	-- the COMING SOON plate: dark riveted metal, an electric-blue glowing edge, the Antique lettering in pale gold
	local function stormPlate(parent, cf, w, h, text)
		local s = C.plaque(parent, cf, w, h, text, { board = hex("23252A"), frame = hex("3A3D44"), line = ELEC, text = hex("FFF4D8"), neon = true })
		local fw = math.max(0.8, h * 0.1)
		local W = w + fw * 2
		local n = math.floor(W / 4.5)
		for _, sy in { -1, 1 } do
			for i = 0, n do
				K.part(s, "Rivet", Vector3.new(0.55, 0.55, 0.3), cf * CFrame.new(-W / 2 + 0.9 + i * (W - 1.8) / n, sy * (h / 2 + fw / 2), -1.05), IRON2, { solid = false, shadow = false })
			end
		end
		for _, sx in { -1, 1 } do
			for j = -1, 1 do
				K.part(s, "Rivet", Vector3.new(0.55, 0.55, 0.3), cf * CFrame.new(sx * (w / 2 + fw / 2), j * h * 0.3, -1.05), IRON2, { solid = false, shadow = false })
			end
		end
		-- the glowing edge round the outside of the frame
		for _, e in { { 0, h / 2 + fw + 0.15, W + 0.6, 0.3 }, { 0, -(h / 2 + fw + 0.15), W + 0.6, 0.3 }, { W / 2 + 0.15, 0, 0.3, h + fw * 2 }, { -(W / 2 + 0.15), 0, 0.3, h + fw * 2 } } do
			K.part(s, "EdgeGlow", Vector3.new(e[3], e[4], 1.2), cf * CFrame.new(e[1], e[2], -0.2), ELEC, { neon = true, solid = false, shadow = false })
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
			return ROAD[n < 0.5 and 1 or 2]
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
		return SLATE[n < 0.36 and 2 or (n < 0.68 and 1 or 3)]
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
				bolt(sky, a, c, 9, 5, 0.6, { blue = i == 4, light = (i == 1 or i == 4) and 60 or nil, min = 3, max = 9 })
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
			teslaCoil(coils, Vector3.new(cp[1], 0, cp[2]), cp[3], cp[4], { light = cp[5] and 36 or nil })
		end
		-- the storm: a dark cloud swirling over the far end (spiral arms, a dark mass between them, a funnel under its
		-- eye), turned slowly by BiomeFX, lightning flickering inside it, a bolt now and then down to a spire
		local vx, vy = 1520, 206
		local vortex = K.model(sky, "StormVortex")
		vortex:SetAttribute("SpinSpeed", 3.5)
		CS:AddTag(vortex, "SpinCloud")
		for arm = 0, 2 do
			for k = 0, 12 do
				local t = k / 12
				local r = 14 + t * 124
				local a = arm * math.pi * 2 / 3 + t * 2.8
				puff(vortex, Vector3.new(vx + math.cos(a) * r, vy + 7 * t + rng:NextNumber(-3, 3), math.sin(a) * r), 12 + t * 22, t < 0.45)
			end
		end
		for _ = 1, 10 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(18, 90)
			puff(vortex, Vector3.new(vx + math.cos(a) * r, vy + rng:NextNumber(2, 8), math.sin(a) * r), rng:NextNumber(22, 32), true)
		end
		for i = 0, 5 do
			C.octagon(vortex, "Funnel", Vector3.new(vx, 0, 0), 20 - i * 3, vy - 6 - (i + 1) * 6, vy - 5.5 - i * 6, CLOUDD[i % 3 + 1], { solid = false, shadow = false })
		end
		local eye = K.box(vortex, "FunnelGlow", vx - 3, vx + 3, vy - 43.5, vy - 41.5, -3, 3, ELEC2, { neon = true, solid = false, shadow = false })
		ctx.keyLight(eye, ELEC2, 50, 2)
		for i = 1, 5 do
			local a0, a1 = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, math.pi * 2)
			local r0, r1 = rng:NextNumber(15, 70), rng:NextNumber(30, 110)
			local pa = Vector3.new(vx + math.cos(a0) * r0, vy + rng:NextNumber(-4, 2), math.sin(a0) * r0)
			local pc = Vector3.new(vx + math.cos(a1) * r1, vy + rng:NextNumber(-6, 0), math.sin(a1) * r1)
			bolt(vortex, pa, pc, 7, 5, 0.8, { blue = i % 2 == 0, light = i <= 3 and 70 or nil, min = 1.2, max = 4.5, name = "CloudBolt" })
		end
		bolt(sky, Vector3.new(vx, vy - 42, 0), tips[6].p, 12, 8, 1.2, { light = 60, min = 4, max = 10, name = "StrikeBolt" })
		-- a low, dense cloud ceiling over the rest of the biome (the swirl covers the far end): from the lane the sky is
		-- overcast and dark, with a few gaps; the spires stay under it
		local deck = K.model(sky, "CloudDeck")
		for x = XA - 14, 1436, 24 do
			for z = -156, 156, 26 do
				if rng:NextNumber() < 0.8 then
					puff(deck, Vector3.new(x + rng:NextNumber(-8, 8), rng:NextNumber(176, 196), z + rng:NextNumber(-8, 8)), rng:NextNumber(26, 38), rng:NextNumber() < 0.45, true)
				end
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
				bolt(ring, top + Vector3.new(0, 5, 0), heroTip, 12, 5, 0.45, { min = 3, max = 8 })
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
			local _, sc = teslaCoil(g, b0 + Vector3.new(0, 3, 0), 57 - y, 8.4, { solid = true, studs = true, light = 60, bolts = 1 })
			table.insert(spheres, sc)
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
		local arc = K.model(g, "GateArc")
		T.chain(arc, "Arc", pts, { 1.6 }, { BOLT2, BOLT }, { neon = true, solid = false, shadow = false })
		C.light(C.anchor(arc, pts[8]), BOLT2, 60, 4)
		arc:SetAttribute("MinGap", 2)
		arc:SetAttribute("MaxGap", 5)
		CS:AddTag(arc, "FlickerBolt")
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
		-- the field: a faint electric sheet; a few thick bolts strike across it now and then (FlickerBolt), low, so
		-- the kaiju behind stays clear
		local field = K.box(cs, "Field", gx - 0.2, gx + 0.2, 0, H, -56.4, 56.4, ELEC2, { neon = true, transparency = 0.92, solid = false, shadow = false })
		crackle(cs, Vector3.new(gx - 0.5, 8, -56), Vector3.new(gx - 0.5, 14, 56), 14, 4.5, 3, 0.95, false, { 2.5, 6 })
		crackle(cs, Vector3.new(gx - 0.5, 30, 56), Vector3.new(gx - 0.5, 22, 18), 7, 3.5, 2.5, 0.65, true, { 1.5, 4 })
		crackle(cs, Vector3.new(gx - 0.5, 40, -56), Vector3.new(gx - 0.5, 33, -20), 7, 3.5, 2.5, 0.65, false, { 1.5, 4 })
		ctx.emit(field, { name = "FieldSparks", colors = { BOLT2, ELEC2 }, size = { 0.5, 0.1 }, rate = 24, speed = { 1, 3 }, life = { 0.4, 0.9 }, spread = 180, light = 1, dir = Enum.NormalId.Left })
		-- the kaiju that waits beyond it: a hulking storm brute, black against the field, eyes burning
		local k = ctx.silhouette(cs, "Thunderback", Vector3.new(gx + 52, 0, 4), Vector3.new(-1, 0, -0.1), 58, { eye = BOLT2, body = hex("07080A"), lift = hex("16181C") })
		if k then
			ctx.keyLight(ctx.anchor(cs, Vector3.new(gx + 74, 40, 0)), ELEC2, 60, 3) -- the storm behind it, rimming its shape
		end
		-- the COMING SOON plate low in the opening, both ways, so the kaiju shows above it (the name is on the girder)
		for _, f in { -1, 1 } do
			local x = gx + f * 1.3
			local s1 = stormPlate(cs, CFrame.lookAt(Vector3.new(x, 10.5, 0), Vector3.new(x + f * 20, 10.5, 0)), 40, 8.4, "COMING SOON")
			s1.Name = "ComingSoon"
		end
	end

	return require(script.Parent.NewBiome)(b, K, T, th)
end
