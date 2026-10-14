-- Cosmic Rift, built by CanyonBuilder.NewBiome: the world's last canyon, where the sky has torn open. The layout below
-- was drawn for x 1577..1877 and is laid onto the lane with T.stretch; the Void Gate end is placed from the lane's end.
--   Ground     violet-black crystal sand with nebula stains and glinting specks; Storm slate fading out at the border; a
--              path of dark glowing tiles; pools of liquid starlight
--   Crystals   neon crystal clusters (violet, pink, cyan) in the pockets, a grove of giant ones in the north, crystals on
--              the cliff caps; obelisks with glowing runes along the path; asteroids drifting over the edges
--   Sky        a ringed gas giant, an ice-blue planet and a moon hanging over the canyon
--   End        the Void Gate: a ring of dark stone and crystal standing on a stepped dais, a portal swirling in it; the
--              canyon ends at a low lip behind it and the Rift itself, a glowing tear in the sky, hangs beyond
--   Nest       hovering crystal shards over a star-map floor, crystal plinths round it
--   Gate       the Star Gate: two obelisks and an arch of floating stones, an eight-point star at its keystone, a
--              constellation across its face
local hex = Color3.fromHex

return function(b, K, T)
	local P = K.P
	local XA, XB = b.x0, b.x1
	local X, U, KX = T.stretch(1577, 1877, XA, XB)
	local NX = XA + (b.NestAt or 0.55) * (XB - XA)
	local C, rng

	---------------------------------------------------------------- colours
	local ROCK = { hex("120C1E"), hex("1E1632"), hex("2C2148"), hex("40305E"), accent = hex("6A1E5E") }
	local FARROCK = { hex("6A5888"), hex("786698"), hex("8674A6"), hex("9482B4") }
	local SAND = { hex("2A2046"), hex("30264E"), hex("251C40"), hex("382C58") }
	local NEBULA = { hex("4A1E56"), hex("3A1A5E"), hex("5A2266") }
	local GLINT = hex("8A78C8")
	local EDGE = hex("1E1632")
	local ROAD = { hex("4A3D74"), hex("40346A"), hex("54467E") }
	local SLABS = { hex("6A5A9A"), hex("5A4A88"), hex("7A6AAA") }
	local SLATED = { hex("4B5363"), hex("3A3550"), hex("2A2245") } -- Storm's slate fading out
	local STARMAP = { hex("140E24"), hex("4A3D78") }
	local VOID = { hex("7A2BD8"), hex("9A2FD0"), hex("C040E0") }
	local CAPS = { hex("2E2450"), hex("3A2E63"), hex("251C42") }
	local VIOLET, PINK, WHITE = hex("B45CFF"), hex("FF4FD8"), hex("F6EEFF")
	local MAGENTA = hex("E030C0")
	local LOOKS = { -- violet, magenta, and starlight white
		{ body = hex("8A3CE0"), tip = hex("D8B0FF"), light = VIOLET },
		{ body = hex("D83AB8"), tip = hex("FFC2EE"), light = PINK },
		{ body = hex("D8CCF0"), tip = hex("FFFFFF"), light = WHITE },
	}
	local DARK = hex("221A40")

	---------------------------------------------------------------- layout
	local POOLS = T.at({ { 1616, -70, 8 }, { 1690, 62, 7 }, { 1806, -48, 7 }, { 1642, 42, 6 }, { 1764, 58, 6 }, { 1704, -56, 7 } }, X)
	local function liquidGap(x, z)
		local g = math.huge
		for _, p in POOLS do
			local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
			g = math.min(g, d - p[3] * (0.85 + 0.3 * T.n01(x / 5 + p[1], z / 5, 8.8)))
		end
		return g
	end
	local RING = { x = XB - 18, y = 44, R = 50 } -- the Void Gate
	local DAIS0 = XB - 43

	---------------------------------------------------------------- shapes
	local function crystals(parent, at, s, n, look, o)
		o = o or {}
		look = look or LOOKS[rng:NextInteger(1, #LOOKS)]
		local m = K.model(parent, "CrystalCluster")
		for i = 1, n do
			local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * s
			local h = (i == 1 and rng:NextNumber(5, 7) or rng:NextNumber(2.4, 4.6)) * s
			C.crystal(m, at + off - Vector3.new(0, 0.4, 0), h, h * 0.24, look.body, look.tip, true)
		end
		if o.light then
			C.light(C.anchor(m, at + Vector3.new(0, 2.5 * s, 0)), look.light, 10 + 6 * s, 1.3)
		end
		return m
	end
	-- a plate of cracked void rock pushed up out of the sand, magenta light glowing in its cracks
	local function voidPlate(parent, at, s)
		local m = K.model(parent, "VoidRock")
		local yaw = rng:NextNumber(0, math.pi)
		local F = CFrame.new(at) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), yaw, math.rad(rng:NextNumber(-6, 6)))
		local w, d = rng:NextNumber(5, 8) * s, rng:NextNumber(4, 6) * s
		K.part(m, "VoidSlab", Vector3.new(w, 0.9 * s, d), F * CFrame.new(0, 0.2, 0), ROCK[2], { studs = K.TOP, solid = false })
		K.part(m, "VoidSlab", Vector3.new(w * 0.45, 0.7 * s, d * 0.5), F * CFrame.new(w * 0.2, 0.75 * s, -d * 0.15) * CFrame.Angles(0, 0.4, 0), ROCK[1], { studs = K.TOP, solid = false })
		local p = Vector3.new(-w / 2 + 0.6, 0, rng:NextNumber(-d / 4, d / 4))
		for _ = 1, 3 do
			local q = Vector3.new(p.X + w / 3, 0, math.clamp(p.Z + rng:NextNumber(-d / 3, d / 3), -d / 2 + 0.4, d / 2 - 0.4))
			local mid, len = (p + q) / 2, (q - p).Magnitude
			K.part(m, "VoidCrack", Vector3.new(len + 0.3, 0.12, 0.35), F * CFrame.lookAt(mid + Vector3.new(0, 0.2 + 0.46 * s, 0), q + Vector3.new(0, 0.2 + 0.46 * s, 0)) * CFrame.Angles(0, math.pi / 2, 0), MAGENTA, { neon = true, solid = false, shadow = false })
			p = q
		end
		return m
	end
	local function obelisk(parent, base, h, look)
		local m = K.model(parent, "Obelisk")
		local w = h * 0.16
		K.box(m, "ObeliskBase", base.X - w, base.X + w, base.Y - 0.4, base.Y + 1.2, base.Z - w, base.Z + w, ROCK[3], { studs = K.ALL, solid = false })
		K.box(m, "Obelisk", base.X - w * 0.6, base.X + w * 0.6, base.Y + 1.2, base.Y + h, base.Z - w * 0.6, base.Z + w * 0.6, ROCK[2], { studs = K.SIDES, solid = false })
		K.box(m, "ObeliskTip", base.X - w * 0.35, base.X + w * 0.35, base.Y + h, base.Y + h + w, base.Z - w * 0.35, base.Z + w * 0.35, ROCK[4], { solid = false })
		for _, f in { -1, 1 } do
			K.box(m, "Rune", base.X - 0.25, base.X + 0.25, base.Y + 3, base.Y + h - 2, base.Z + f * w * 0.6 - 0.1, base.Z + f * w * 0.6 + 0.1, look.light, { neon = true, solid = false, shadow = false })
			K.box(m, "Rune", base.X + f * w * 0.6 - 0.1, base.X + f * w * 0.6 + 0.1, base.Y + h * 0.5, base.Y + h * 0.5 + 0.5, base.Z - w * 0.4, base.Z + w * 0.4, look.light, { neon = true, solid = false, shadow = false })
		end
		local fc = Vector3.new(base.X, base.Y + h + w + 3.5, base.Z)
		C.crystal(m, fc, 4, 1.2, look.body, look.tip, true, CFrame.Angles(0, math.rad(45), 0))
		return m
	end
	local function asteroid(parent, c, r)
		local m = K.model(parent, "Asteroid")
		for i = 1, 3 do
			local s = r * (i == 1 and 1 or rng:NextNumber(0.5, 0.75))
			local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-1, 1)) * r * 0.7
			K.part(m, "Rock", Vector3.new(s * 1.6, s * 1.2, s * 1.4), CFrame.new(c + off) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), ROCK[rng:NextInteger(2, 4)], { studs = K.ALL, solid = false, shadow = false })
		end
		if rng:NextNumber() < 0.5 then
			local look = LOOKS[rng:NextInteger(1, #LOOKS)]
			C.crystal(m, c + Vector3.new(0, r * 0.5, 0), r * 1.2, r * 0.3, look.body, look.tip, true)
		end
		return m
	end
	local function planet(parent, c, R, bands)
		C.sphere(parent, "Planet", c, R, function(t)
			return bands[math.clamp(math.floor(t * #bands * 2) % #bands + 1, 1, #bands)]
		end, { solid = false, shadow = false })
	end

	---------------------------------------------------------------- the theme
	local th = {
		seed = 7741,
		half = 92,
		accent = VIOLET,
		gateOpenH = 60,
		blendLen = 26,
		rock = ROCK,
		farRock = FARROCK,
		rugged = true,
		slabs = SLABS,
		slabChance = 0.5,
		edgeN = T.at({ { 1577, 65 }, { 1588, 66 }, { 1600, 76 }, { 1616, 88 }, { 1634, 90 }, { 1648, 76 }, { 1662, 66 }, { 1676, 70 }, { 1690, 82 }, { 1706, 92 }, { 1778, 92 }, { 1792, 80 }, { 1806, 70 }, { 1820, 76 }, { 1834, 84 }, { 1850, 80 }, { 1866, 74 }, { 1877, 72 } }, X),
		edgeS = T.at({ { 1577, 65 }, { 1590, 64 }, { 1604, 72 }, { 1620, 84 }, { 1636, 86 }, { 1650, 72 }, { 1664, 64 }, { 1678, 68 }, { 1694, 80 }, { 1710, 90 }, { 1774, 90 }, { 1790, 76 }, { 1804, 66 }, { 1818, 72 }, { 1834, 82 }, { 1850, 78 }, { 1866, 74 }, { 1877, 72 } }, X),
		paths = {
			T.at({ { 1577, 0, 14 }, { 1594, 6, 12 }, { 1612, 10, 12 }, { 1630, 2, 12 }, { 1648, -8, 12 }, { 1666, -10, 12 }, { 1684, -4, 12 }, { 1702, 2, 12 }, { 1725, 0, 12 } }, X),
			T.at({ { 1725, 0, 8 }, { 1728, 14, 7 }, { 1735, 26, 7 }, { 1750, 26, 7 }, { 1757, 14, 7 }, { 1760, 0, 8 } }, X),
			T.at({ { 1725, 0, 8 }, { 1728, -14, 7 }, { 1735, -26, 7 }, { 1750, -26, 7 }, { 1757, -14, 7 }, { 1760, 0, 8 } }, X),
			T.at({ { 1760, 0, 12 }, { 1776, 8, 12 }, { 1792, 10, 12 }, { 1808, 2, 12 }, { 1824, -2, 13 } }, X), -- on to the dais
			{ { X(1824), -2, 13 }, { XB - 55, -2, 13 }, { XB - 41, 0, 16 } },
			T.at({ { 1612, 10, 6 }, { 1616, 44, 6 }, { 1620, 68, 6 } }, X), -- to the giant crystals
		},
		liquid = {
			gap = liquidGap,
			neon = true,
			top = -0.6,
			color = function(_, _, _, n)
				return VOID[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end,
		},
	}

	function th.init(ctx)
		C, rng = ctx, ctx.rng
	end

	function th.ground(ctx, x, z, n, n2)
		local dn = math.sqrt((x - NX) ^ 2 + z * z)
		if dn < 17.5 then
			-- the star map: dark, with lighter rings
			local r = dn % 5
			return (r > 3.6 and dn > 7) and STARMAP[2] or STARMAP[1]
		end
		if x > DAIS0 - 2 then
			return ROAD[2]
		end
		if ctx.pathGap(x, z) <= 0 then
			return ROAD[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		local f = ctx.blend(x)
		if f > 0 and n2 < f * 1.3 - 0.1 then
			return SLATED[n2 < f * 0.6 - 0.2 and 1 or (n < 0.5 and 2 or 3)]
		end
		if ctx.liquidGap(x, z) < 2 then
			return GLINT
		end
		local side = z >= 0 and 1 or -1
		if math.abs(z) > ctx.edge[side](x) - 8 and n2 < 0.4 then
			return EDGE
		end
		if n2 > 0.9 then
			return GLINT
		end
		if n2 < 0.3 then
			return NEBULA[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		return SAND[math.clamp(math.floor(n * 4) + 1, 1, 4)]
	end

	function th.cap(ctx, x, r)
		local f = ctx.blend(x)
		if r:NextNumber() < f * f * 1.6 then
			return hex("394050") -- Storm's slate caps
		end
		return CAPS[r:NextInteger(1, #CAPS)]
	end

	function th.tint(x, c)
		local f = math.clamp(1 - (x - XA) / 34, 0, 1)
		return f > 0 and c:Lerp(hex("343B4A"), f * 0.5) or c
	end

	function th.height(_, _, x, n)
		local h = 46 + n * 30
		if x < XA + 18 then
			h = math.max(h, 66 + n * 10)
		elseif x > XB - 39 then
			h = math.max(h, 76 + n * 16) -- tall either side of the Void Gate
		end
		return math.floor(h / 2 + 0.5) * 2
	end

	function th.ridge(_, _, _, n)
		return math.floor(60 + n * 40)
	end

	function th.farHeight(_, _, _, n)
		return math.floor(130 + n * 80)
	end

	function th.column(ctx, c, side)
		if rng:NextNumber() < 0.26 then
			local at = Vector3.new(rng:NextNumber(c.x0 + 1.5, c.x1 - 1.5), c.top + 1.4, side * rng:NextNumber(c.lastFront + 2, math.max(c.lastFront + 2.1, c.back - 4)))
			crystals(ctx.sub("Heights"), at, rng:NextNumber(1, 1.8), rng:NextInteger(1, 3), nil, { light = false })
		end
		if c.h > 26 and rng:NextNumber() < 0.22 then
			T.faceCrack(ctx.sub("Heights"), c, side, rng, ({ VIOLET, MAGENTA, WHITE })[rng:NextInteger(1, 3)], { neon = true, width = 0.4 })
		end
	end

	---------------------------------------------------------------- features
	function th.features(ctx)
		local sky, scatter, heights = ctx.sub("Sky"), ctx.sub("Scatter"), ctx.sub("Heights")
		-- the planets
		-- a magenta-violet gas giant with pale rings, a pale lavender ice world, a grey moon
		planet(sky, Vector3.new(X(1760), 250, -470), 80, { hex("7A2A9A"), hex("B048B8"), hex("5A2088"), hex("D070C8") })
		local tilt = CFrame.new(X(1760), 250, -470) * CFrame.Angles(math.rad(18), 0, math.rad(-14))
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			K.part(sky, "PlanetRing", Vector3.new(50, 1.6, 26), tilt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 128), i % 2 == 0 and hex("F0E0FF") or hex("C8B4E8"), { solid = false, shadow = false, transparency = 0.15 })
		end
		planet(sky, Vector3.new(XB + 83, 210, 430), 50, { hex("D8D0F0"), hex("B8ACE0"), hex("ECE6FF") })
		planet(sky, Vector3.new(X(1650), 330, 300), 24, { hex("A8A4B8"), hex("8E8AA0") })
		-- stars: white specks scattered over a dome above the biome
		for i = 1, math.floor(140 * KX) do
			local a, e = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.35, 1.3)
			local d = rng:NextNumber(330, 420)
			local cx = i % 2 == 0 and X(1660) or X(1790) -- two domes over the longer canyon
			local p = Vector3.new(cx + math.cos(a) * math.cos(e) * d, 40 + math.sin(e) * d, math.sin(a) * math.cos(e) * d)
			local s = rng:NextNumber(1.2, 2.6)
			K.part(sky, "Star", Vector3.new(s, s, s), CFrame.new(p) * CFrame.Angles(0, math.rad(45), math.rad(45)), rng:NextNumber() < 0.8 and WHITE or PINK, { neon = true, solid = false, shadow = false })
		end
		-- the Rift: a glowing tear in the sky beyond the end of the canyon, debris tumbling round it
		local rift = ctx.sub("Rift")
		local rx = XB + 98
		local y, z = 30, 0
		local n = 16
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local sh = 300 / n
			local w = 6 + 30 * math.sin(math.pi * t) ^ 1.4
			local nz = z + rng:NextNumber(-7, 7)
			local mid = Vector3.new(rx, y + sh / 2, (z + nz) / 2)
			local ang = math.atan2(nz - z, sh)
			K.part(rift, "RiftGlow", Vector3.new(3, sh + 2, w), CFrame.new(mid) * CFrame.Angles(ang, 0, 0), hex("B040FF"), { neon = true, transparency = 0.35, solid = false, shadow = false })
			K.part(rift, "RiftCore", Vector3.new(3.6, sh + 2, w * 0.32), CFrame.new(mid) * CFrame.Angles(ang, 0, 0), WHITE, { neon = true, solid = false, shadow = false })
			z, y = nz, y + sh
		end
		local rc = K.part(rift, "RiftHeart", Vector3.new(1, 1, 1), CFrame.new(rx - 6, 180, 0), WHITE, { transparency = 1, solid = false, shadow = false })
		ctx.keyLight(rc, hex("E070FF"), 60, 3.5)
		ctx.emit(rc, { name = "RiftDust", colors = { WHITE, VIOLET }, size = { 1.2, 0.2 }, rate = 12, speed = { 6, 14 }, life = { 4, 7 }, spread = 180, light = 1 })
		for _ = 1, 12 do
			asteroid(rift, Vector3.new(rx + rng:NextNumber(-30, 20), rng:NextNumber(50, 300), rng:NextNumber(-80, 80)), rng:NextNumber(3, 8))
		end
		-- asteroids drifting over the canyon's edges
		for _ = 1, math.floor(10 * KX) do
			local side = rng:NextNumber() < 0.5 and 1 or -1
			local x = rng:NextNumber(XA + 20, XB - 30)
			asteroid(sky, Vector3.new(x, rng:NextNumber(36, 90), side * rng:NextNumber(50, 110)), rng:NextNumber(2.5, 6))
		end
		-- the giant crystal grove in the north pocket, clusters in the others
		for i, g in { { 1622, 82, 2.6, 1 }, { 1612, 80, 2, 2 }, { 1630, 86, 2.2, 3 } } do
			local m = crystals(heights, Vector3.new(X(g[1]), 0, g[2]), g[3] * 2.4, 4, LOOKS[g[4]])
			if i == 1 then
				ctx.keyLight(ctx.anchor(m, Vector3.new(X(g[1]), 14, g[2] - 12)), VIOLET, 50, 2.4)
			end
		end
		local function spot(margin, nestR)
			for _ = 1, 40 do
				local x, z = rng:NextNumber(XA + 6, DAIS0 - 8), rng:NextNumber(-90, 90)
				if ctx.inside(x, z, margin) and ctx.pathGap(x, z) > 2.5 and ctx.liquidGap(x, z) > 2 and not ctx.nearNest(x, z, nestR or 22) then
					return x, z
				end
			end
		end
		for i = 1, math.floor(18 * KX) do
			local x, z = spot(3)
			if x then
				crystals(scatter, Vector3.new(x, 0, z), rng:NextNumber(0.7, 1.4), rng:NextInteger(2, 4), nil, { light = i % 2 == 0 and x < XA + 90 })
			end
			if i <= 10 * KX then
				x, z = spot(4)
				if x then
					local r = rng:NextNumber(1.4, 3)
					T.boulder(scatter, Vector3.new(x, 0, z), r, ctx.rockAt, rng, { solid = r > 2.2 })
				end
			end
		end
		-- glinting specks of stardust on the ground
		for _ = 1, math.floor(60 * KX) do
			local x, z = spot(1, 18)
			if x then
				local s = rng:NextNumber(0.2, 0.35)
				K.box(scatter, "Stardust", x - s, x + s, 0, 0.12, z - s, z + s, ({ WHITE, WHITE, VIOLET, PINK })[rng:NextInteger(1, 4)], { neon = true, solid = false, shadow = false })
			end
		end
		-- plates of cracked void rock pushed up through the sand
		for _ = 1, math.floor(22 * KX) do
			local x, z = spot(3)
			if x then
				voidPlate(scatter, Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.3))
			end
		end
		-- obelisks along the path
		for i, o in { { 1600, -14 }, { 1640, 18 }, { 1676, -22 }, { 1700, 20 }, { 1784, -16 }, { 1814, 18 }, { 1620, -20 }, { 1658, 20 }, { 1798, 18 } } do
			local ox = X(o[1])
			if ctx.pathGap(ox, o[2]) > 2 then
				obelisk(scatter, Vector3.new(ox, 0, o[2]), rng:NextNumber(12, 18), LOOKS[(i - 1) % 3 + 1])
			end
		end
		-- starlight pools glow
		for _, p in POOLS do
			if p[1] < XA + 90 then -- only the pools seen from the gate are lit
				local a = ctx.anchor(scatter, Vector3.new(p[1], 0, p[2]), Vector3.new(p[3] * 1.3, 0.4, p[3] * 1.3))
				ctx.light(a, VIOLET, 18, 1.2)
				ctx.emit(a, { name = "Starlight", colors = { WHITE, PINK }, size = { 0.35, 0.1 }, rate = 4, speed = { 0.5, 1.5 }, life = { 2, 3.5 }, spread = 60, light = 1 })
			end
		end
		-- crystals and tall spikes up on the heights
		for _, t in ctx.tops do
			if t.big and t.z1 > t.z0 and rng:NextNumber() < 0.35 then
				crystals(heights, Vector3.new(t.x, t.y, t.side * rng:NextNumber(t.z0, t.z1)), rng:NextNumber(2, 3.6), rng:NextInteger(2, 4), nil, { light = false })
			end
		end

		---------------------------------------------------------------- the Void Gate and the end of the world
		local vg = ctx.sub("VoidGate")
		-- the dais: three walkable steps up to the ring, glowing edges
		for k, st in { { DAIS0, 26 }, { DAIS0 + 6, 21 }, { DAIS0 + 12, 16 } } do
			K.box(vg, "DaisStep", st[1], RING.x + 4, (k - 1) * 0.8, k * 0.8, -st[2], st[2], ROCK[3], { studs = K.TOP })
			K.box(vg, "DaisEdge", st[1] - 0.1, st[1] + 0.3, (k - 1) * 0.8 + 0.2, k * 0.8 - 0.2, -st[2], st[2], VIOLET, { neon = true, solid = false, shadow = false })
		end
		-- the ring: dark stone segments, a neon inner edge, crystals on the outside
		local segs = 22
		for i = 0, segs - 1 do
			local a = (i + 0.5) / segs * math.pi * 2
			local p = Vector3.new(RING.x, RING.y + math.sin(a) * RING.R, math.cos(a) * RING.R)
			if p.Y > -6 then
				-- X across the ring's thickness, Y outward, Z along the ring
				local out = Vector3.new(0, math.sin(a), math.cos(a))
				local len = 2 * math.pi * RING.R / segs * 1.08
				K.part(vg, "RingStone", Vector3.new(7, 8, len), CFrame.fromMatrix(p, Vector3.xAxis, out), i % 2 == 0 and ROCK[2] or ROCK[3], { studs = K.SIDES, solid = false })
				local inner = Vector3.new(RING.x, RING.y + math.sin(a) * (RING.R - 4.4), math.cos(a) * (RING.R - 4.4))
				K.part(vg, "RingGlow", Vector3.new(7.4, 1, len * 0.94), CFrame.fromMatrix(inner, Vector3.xAxis, out), VIOLET, { neon = true, solid = false, shadow = false })
				if i % 2 == 0 and p.Y > 8 then
					local look = LOOKS[(i / 2) % 3 + 1]
					local base = p + out * 3.6
					local h = rng:NextNumber(7, 13)
					local ccf = CFrame.fromMatrix(base, Vector3.xAxis, out)
					K.part(vg, "RingCrystal", Vector3.new(2.4, h, 2.4), ccf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), look.body, { neon = true, solid = false, shadow = false })
					K.part(vg, "RingCrystalTip", Vector3.new(1.4, 3, 1.4), ccf * CFrame.new(0, h + 1.2, 0) * CFrame.Angles(0, math.rad(45), 0), look.tip, { neon = true, solid = false, shadow = false })
				end
			end
		end
		-- the portal: discs of light inside the ring, brightest at the heart
		local pc = Vector3.new(RING.x + 0.6, RING.y, 0)
		for k, d in { { 45, hex("5A22C8"), 0.66 }, { 32, hex("A040F0"), 0.62 }, { 18, hex("E070FF"), 0.5 }, { 7, WHITE, 0.25 } } do
			for _, rot in { 0, 45 } do
				K.part(vg, "Portal", Vector3.new(0.3, d[1] * 1.8, d[1] * 1.8), CFrame.new(pc + Vector3.new((5 - k) * 0.25, 0, 0)) * CFrame.Angles(math.rad(rot), 0, 0), d[2], { neon = true, transparency = d[3], solid = false, shadow = false })
			end
		end
		local heart = ctx.anchor(vg, pc - Vector3.new(2, 0, 0), Vector3.new(1, 60, 60))
		ctx.keyLight(heart, PINK, 60, 3.5)
		ctx.emit(heart, { name = "PortalSwirl", colors = { WHITE, VIOLET }, size = { 0.8, 0.1 }, rate = 25, speed = { 1, 3 }, life = { 2, 4 }, spread = 180, light = 1, dir = Enum.NormalId.Left })
		-- the canyon stops here: an invisible wall in front of the portal
		local wall = K.box(vg, "EndBarrier", RING.x - 3.5, RING.x - 2.5, -2, 120, -100, 100, DARK, { transparency = 1 })
		wall.CanQuery, wall.CastShadow = false, false
		-- obelisks flanking the dais
		for _, s in { -1, 1 } do
			obelisk(vg, Vector3.new(DAIS0 + 4, 0, s * 34), 26, LOOKS[s > 0 and 2 or 3])
		end
		-- behind the ring the ground ends at a low lip; tall rock either side
		local z = -100
		while z < 100 do
			local z1 = math.min(z + rng:NextInteger(8, 12), 100)
			local zm = (z + z1) / 2
			local open = math.abs(zm) < 46
			local H = open and math.floor(4 + T.n01(zm / 9, 2.2, 0.4) * 5) or math.floor(78 + T.n01(zm / 17 + 3.3, 9.1, 0.5) * 34)
			local yy, f = -2, XB - 0.5
			while yy < H - 0.5 do
				local lh = math.min(H - yy, rng:NextInteger(7, 12))
				K.box(vg, "EndRock", f, XB + (open and 10 or 34), yy, yy + lh, z, z1, ctx.rockAt(Vector3.new(f, yy + lh / 2, zm), (yy + lh / 2) / 100), { studs = K.SIDES, solid = yy + lh <= 24 })
				yy += lh
				f += rng:NextNumber(0, 4)
			end
			K.box(vg, "EndCap", f - 0.6, XB + (open and 10 or 34), H, H + 1.4, z, z1, CAPS[rng:NextInteger(1, #CAPS)], { studs = K.ALL, solid = false })
			if not open and rng:NextNumber() < 0.5 then
				crystals(vg, Vector3.new(f + 6, H + 1.4, zm), rng:NextNumber(1.6, 2.6), rng:NextInteger(2, 3), nil, { light = false })
			end
			z = z1
		end
	end

	---------------------------------------------------------------- the nest: crystal shards hovering over a star map
	function th.nest(ctx, art, c)
		ctx.octagon(art, "Bed", c, 6.4, -0.05, 0.25, hex("0E0A1C"), { studs = K.TOP, solid = false })
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			K.part(art, "StarRing", Vector3.new(0.4, 0.1, 5.4), CFrame.new(c.X + math.cos(a) * 6.6, 0.3, c.Z + math.sin(a) * 6.6) * CFrame.Angles(0, -a, 0), VIOLET, { neon = true, solid = false, shadow = false })
		end
		for k = 0, 5 do
			local a = (k + 0.5) / 6 * math.pi * 2
			local look = LOOKS[k % 3 + 1]
			local p = Vector3.new(c.X + math.cos(a) * 8.4, rng:NextNumber(2.2, 3.6), c.Z + math.sin(a) * 8.4)
			ctx.crystal(art, p, rng:NextNumber(3, 4.6), 0.9, look.body, look.tip, true, CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), a, math.rad(rng:NextNumber(-20, 20))))
		end
		-- crystal plinths round the star map
		local ring = ctx.sub("Plinths")
		for k, deg in { 60, 90, 120, 240, 270, 300 } do
			local a = math.rad(deg)
			local px, pz = NX + math.cos(a) * 15.6, math.sin(a) * 15.6
			local h = (k % 2 == 0) and 5 or 3.4
			K.box(ring, "Plinth", px - 1.8, px + 1.8, 0, h, pz - 1.8, pz + 1.8, ROCK[3], { studs = K.SIDES, solid = false })
			K.box(ring, "PlinthTop", px - 2.1, px + 2.1, h, h + 0.6, pz - 2.1, pz + 2.1, ROCK[4], { studs = K.TOP, solid = false })
			local look = LOOKS[k % 3 + 1]
			ctx.crystal(ring, Vector3.new(px, h + 2.4, pz), rng:NextNumber(4, 6), 1.3, look.body, look.tip, true, CFrame.Angles(0, math.rad(45), 0))
		end
	end

	---------------------------------------------------------------- the Star Gate
	function th.gate(ctx, g)
		local gx = XA
		for _, s in { -1, 1 } do
			local levels = { { -2, 22, 13, 62, 96 }, { 22, 44, 10.5, 63, 92 }, { 44, 62, 8.5, 64, 88 }, { 62, 76, 6.5, 65, 84 } }
			for i, l in levels do
				K.box(g, "Pylon", gx - l[3], gx + l[3], l[1], l[2], s * l[4], s * l[5], ROCK[i % 2 + 2], { studs = K.SIDES })
				K.box(g, "PylonRune", gx - l[3] - 0.25, gx - l[3] + 0.1, l[1] + 3, l[2] - 3, s * (l[4] + 4), s * (l[4] + 5), VIOLET, { neon = true, solid = false, shadow = false })
				K.box(g, "PylonRune", gx - l[3] - 0.25, gx - l[3] + 0.1, (l[1] + l[2]) / 2, (l[1] + l[2]) / 2 + 0.8, s * (l[4] + 5), s * (l[5] - 5), VIOLET, { neon = true, solid = false, shadow = false })
			end
			local look = LOOKS[s > 0 and 2 or 3]
			ctx.crystal(g, Vector3.new(gx, 82, s * 74), 12, 3.4, look.body, look.tip, true, CFrame.Angles(0, math.rad(45), 0))
			ctx.keyLight(ctx.anchor(g, Vector3.new(gx, 88, s * 74)), look.light, 40, 2)
		end
		-- the arch of floating stones
		local R, cy = 62, 38
		local n = 9
		local a0, a1 = 22, 158
		for i = 0, n - 1 do
			local a = math.rad(a0 + (a1 - a0) * (i + 0.5) / n)
			local p = Vector3.new(gx, cy + math.sin(a) * R, math.cos(a) * R)
			local tang = Vector3.new(0, math.cos(a), -math.sin(a))
			local len = math.rad(a1 - a0) / n * R - 2
			K.part(g, "FloatingStone", Vector3.new(8, 9, len), CFrame.lookAt(p, p + tang), ROCK[i % 2 + 2], { studs = K.ALL, solid = false })
			local inner = Vector3.new(gx - 4.2, cy + math.sin(a) * (R - 3), math.cos(a) * (R - 3))
			K.part(g, "StoneRune", Vector3.new(0.3, 0.8, len * 0.7), CFrame.lookAt(inner, inner + tang), VIOLET, { neon = true, solid = false, shadow = false })
		end
		-- the eight-point star at the keystone
		local sc = Vector3.new(gx - 4.8, cy + R + 9, 0)
		for _, rot in { 0, 45 } do
			K.part(g, "Star", Vector3.new(0.6, 11, 11), CFrame.new(sc) * CFrame.Angles(math.rad(rot), 0, 0), WHITE, { neon = true, solid = false, shadow = false })
		end
		K.part(g, "StarCore", Vector3.new(1, 5, 5), CFrame.new(sc - Vector3.new(0.4, 0, 0)) * CFrame.Angles(math.rad(45), 0, 0), VIOLET, { neon = true, solid = false, shadow = false })
		ctx.light(ctx.anchor(g, sc - Vector3.new(3, 0, 0)), WHITE, 40, 2)
		-- a constellation across the arch's face: stars joined by thin lines
		local stars = { { -40, 62 }, { -28, 74 }, { -14, 82 }, { -4, 86 }, { 10, 80 }, { 22, 88 }, { 36, 78 }, { 44, 66 } }
		local prev
		for _, st in stars do
			local p = Vector3.new(gx - 5, st[2], st[1])
			local r = math.sqrt((st[2] - cy) ^ 2 + st[1] ^ 2)
			if r < R - 6 then
				K.box(g, "ConstStar", p.X - 0.4, p.X + 0.4, p.Y - 0.7, p.Y + 0.7, p.Z - 0.7, p.Z + 0.7, WHITE, { neon = true, solid = false, shadow = false })
				if prev then
					T.chain(g, "ConstLine", { prev, p }, { 0.18 }, { hex("C8A8FF") }, { neon = true, solid = false, shadow = false })
				end
				prev = p
			end
		end
		ctx.plaque(g, CFrame.lookAt(Vector3.new(gx - 4, 70, 0), Vector3.new(gx - 30, 70, 0)), 40, 6.4, "COSMIC RIFT", { board = hex("120C22"), frame = ROCK[4], line = VIOLET, text = hex("EAD8FF"), neon = true })
		K.box(g, "PlaqueStone", gx - 3.4, gx + 3.4, 64.6, 75.4, -23, 23, ROCK[2], { studs = K.ALL, solid = false })
	end

	---------------------------------------------------------------- the lock: a swirling void seal, a crystal drake beyond it
	-- one ring of the seal: segments round c in the gate's plane, every other one glowing; turns (BiomeFX SpinCloud,
	-- SpinAxis X) at `spin` deg/s
	local function sealRing(parent, c, R, thick, n, colA, colB, spin, gap)
		local m = K.model(parent, "SealRing")
		for i = 0, n - 1 do
			if not gap or i % gap ~= 0 then
				local a = (i + 0.5) / n * math.pi * 2
				local out = Vector3.new(0, math.sin(a), math.cos(a))
				local len = 2 * math.pi * R / n * 0.86
				local glow = i % 2 == 0
				K.part(m, glow and "SealGlow" or "SealStone", Vector3.new(glow and 0.8 or 1.6, thick, len), CFrame.fromMatrix(c + out * R, Vector3.xAxis, out), glow and colA or colB, { neon = glow, transparency = glow and 0.3 or nil, solid = false, shadow = false })
			end
		end
		m:SetAttribute("SpinSpeed", spin)
		m:SetAttribute("SpinAxis", "X")
		game:GetService("CollectionService"):AddTag(m, "SpinCloud")
		return m
	end
	-- the COMING SOON slab: polished obsidian strewn with stars, a magenta glowing edge, crystal shards on its corners
	local function starSlab(parent, cf, w, h, text)
		local s = C.plaque(parent, cf, w, h, text, { board = hex("0E0818"), frame = hex("2C2148"), line = PINK, text = hex("F4EAFF"), neon = true })
		for _ = 1, 22 do
			local x, y = rng:NextNumber(-w / 2 + 0.8, w / 2 - 0.8), rng:NextNumber(-h / 2 + 0.6, h / 2 - 0.6)
			if math.abs(y) > h * 0.3 or math.abs(x) > w * 0.42 then -- round the lettering, not over it
				local sz = rng:NextNumber(0.15, 0.3)
				K.part(s, "Star", Vector3.new(sz, sz, 0.1), cf * CFrame.new(x, y, -0.56), WHITE, { neon = true, solid = false, shadow = false })
			end
		end
		local fw = math.max(0.8, h * 0.1)
		local W = w + fw * 2
		for _, e in { { 0, h / 2 + fw + 0.15, W + 0.6, 0.3 }, { 0, -(h / 2 + fw + 0.15), W + 0.6, 0.3 }, { W / 2 + 0.15, 0, 0.3, h + fw * 2 }, { -(W / 2 + 0.15), 0, 0.3, h + fw * 2 } } do
			K.part(s, "EdgeGlow", Vector3.new(e[3], e[4], 1.2), cf * CFrame.new(e[1], e[2], -0.2), MAGENTA, { neon = true, solid = false, shadow = false })
		end
		for _, sx in { -1, 1 } do
			local base = (cf * CFrame.new(sx * (W / 2 - 1), h / 2 + fw, 0)).Position
			C.crystal(s, base, 4, 1, LOOKS[sx > 0 and 2 or 1].body, LOOKS[sx > 0 and 2 or 1].tip, true, CFrame.Angles(0, 0, math.rad(-sx * 18)))
		end
		return s
	end
	function th.lock(ctx, cs, gx)
		local H = th.gateOpenH
		-- a faint violet veil across the opening, motes drifting in it
		local field = K.box(cs, "Field", gx - 0.2, gx + 0.2, 0, H, -60, 60, VIOLET, { neon = true, transparency = 0.94, solid = false, shadow = false })
		ctx.emit(field, { name = "VoidMotes", colors = { WHITE, PINK }, size = { 0.4, 0.1 }, rate = 16, speed = { 0.3, 1.2 }, life = { 3, 5 }, spread = 180, light = 1, dir = Enum.NormalId.Left })
		-- the seal: rings of dark stone and glowing violet / magenta / white turning against each other round a black
		-- core with a white star in it (open between the rings, so the drake shows through)
		-- (low in the opening, so the drake's head and wings rise clear above it)
		local c = Vector3.new(gx - 1.5, 24, 0)
		sealRing(cs, c, 15, 1.2, 24, VIOLET, ROCK[3], 8)
		sealRing(cs, c, 10.5, 1, 18, MAGENTA, ROCK[2], -14, 5)
		sealRing(cs, c, 6.5, 0.9, 12, WHITE, ROCK[3], 22)
		for _, rot in { 0, 45 } do
			K.part(cs, "VoidCore", Vector3.new(0.6, 6.4, 6.4), CFrame.new(c) * CFrame.Angles(math.rad(rot), 0, 0), hex("06030C"), { solid = false, shadow = false })
			K.part(cs, "CoreStar", Vector3.new(0.4, 3.6, 0.7), CFrame.new(c - Vector3.new(0.45, 0, 0)) * CFrame.Angles(math.rad(rot), 0, 0), WHITE, { neon = true, solid = false, shadow = false })
			K.part(cs, "CoreStar", Vector3.new(0.4, 0.7, 3.6), CFrame.new(c - Vector3.new(0.45, 0, 0)) * CFrame.Angles(math.rad(rot), 0, 0), WHITE, { neon = true, solid = false, shadow = false })
		end
		-- spiral arms of white motes winding into the core
		for arm = 0, 1 do
			for k = 0, 6 do
				local t = k / 6
				local a = arm * math.pi + t * 3.4
				local r = 3.6 + t * 14
				local s = 0.35 + t * 0.4
				K.part(cs, "SealMote", Vector3.new(0.3, s, s), CFrame.new(c + Vector3.new(-0.3, math.sin(a) * r, math.cos(a) * r)) * CFrame.Angles(math.rad(45), 0, 0), k % 3 == 0 and PINK or WHITE, { neon = true, solid = false, shadow = false })
			end
		end
		ctx.keyLight(ctx.anchor(cs, c - Vector3.new(3, 0, 0)), PINK, 30, 1.8)
		-- the kaiju beyond: a crystal drake, wings raised over the seal, eyes white-hot
		-- (in line with the Void Gate's portal far behind, so it stands black against that glow down the lane)
		local k = ctx.silhouette(cs, "Prismling", Vector3.new(gx + 52, 0, 3), Vector3.new(-1, 0, 0.25), 66, { eye = WHITE, body = hex("050309"), lift = hex("120C22") })
		if k then
			ctx.keyLight(ctx.anchor(cs, Vector3.new(gx + 72, 34, 0)), PINK, 60, 3.5)
		end
		for _, f in { -1, 1 } do
			local x = gx + f * 1.3
			starSlab(cs, CFrame.lookAt(Vector3.new(x, 4.6, 0), Vector3.new(x + f * 20, 4.6, 0)), 36, 6.6, "COMING SOON").Name = "ComingSoon"
		end
	end

	return require(script.Parent.NewBiome)(b, K, T, th)
end
