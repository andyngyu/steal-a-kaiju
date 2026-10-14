-- Cosmic Rift (x 1577..1877), built by CanyonBuilder.NewBiome: the world's last canyon, where the sky has torn open.
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
	local NX = XA + (b.NestAt or 0.55) * (XB - XA)
	local C, rng

	---------------------------------------------------------------- colours
	local ROCK = { hex("140E24"), hex("1F1838"), hex("2B2250"), hex("3E3270"), accent = hex("4A2A78") }
	local SAND = { hex("1C1435"), hex("221A40"), hex("181030"), hex("2A2050") }
	local NEBULA = { hex("3A1A4A"), hex("1A2A5A"), hex("2E1A55") }
	local GLINT = hex("6A5AB0")
	local EDGE = hex("2F2650")
	local ROAD = { hex("3A2F5C"), hex("2F2650"), hex("443870") }
	local SLABS = { hex("5A4A8A"), hex("4A3D78"), hex("6A5AA0") }
	local SLATED = { hex("4B5363"), hex("3A3550"), hex("2A2245") } -- Storm's slate fading out
	local STARMAP = { hex("140E24"), hex("4A3D78") }
	local VOID = { hex("5A2BC8"), hex("4A22B0"), hex("6E3CE0") }
	local CAPS = { hex("2E2450"), hex("3A2E63"), hex("251C42") }
	local VIOLET, PINK, CYAN, WHITE = hex("B45CFF"), hex("FF5CC8"), hex("5CE1FF"), hex("F0D8FF")
	local LOOKS = {
		{ body = hex("8A3CE0"), tip = hex("D8B0FF"), light = VIOLET },
		{ body = hex("E04CA8"), tip = hex("FFC2E8"), light = PINK },
		{ body = hex("3CB8E0"), tip = hex("C2F4FF"), light = CYAN },
	}
	local DARK = hex("221A40")

	---------------------------------------------------------------- layout
	local POOLS = { { 1616, -70, 8 }, { 1690, 62, 7 }, { 1806, -48, 7 }, { 1642, 42, 6 } }
	local function liquidGap(x, z)
		local g = math.huge
		for _, p in POOLS do
			local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
			g = math.min(g, d - p[3] * (0.85 + 0.3 * T.n01(x / 5 + p[1], z / 5, 8.8)))
		end
		return g
	end
	local RING = { x = 1859, y = 44, R = 50 } -- the Void Gate
	local DAIS0 = 1834

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
		if o.light ~= false then
			C.light(C.anchor(m, at + Vector3.new(0, 2.5 * s, 0)), look.light, 10 + 6 * s, 1.3)
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
		slabs = SLABS,
		slabChance = 0.5,
		edgeN = { { 1577, 65 }, { 1588, 66 }, { 1600, 76 }, { 1616, 88 }, { 1634, 90 }, { 1648, 76 }, { 1662, 66 }, { 1676, 70 }, { 1690, 82 }, { 1706, 92 }, { 1778, 92 }, { 1792, 80 }, { 1806, 70 }, { 1820, 76 }, { 1834, 84 }, { 1850, 80 }, { 1866, 74 }, { 1877, 72 } },
		edgeS = { { 1577, 65 }, { 1590, 64 }, { 1604, 72 }, { 1620, 84 }, { 1636, 86 }, { 1650, 72 }, { 1664, 64 }, { 1678, 68 }, { 1694, 80 }, { 1710, 90 }, { 1774, 90 }, { 1790, 76 }, { 1804, 66 }, { 1818, 72 }, { 1834, 82 }, { 1850, 78 }, { 1866, 74 }, { 1877, 72 } },
		paths = {
			{ { 1577, 0, 14 }, { 1594, 6, 12 }, { 1612, 10, 12 }, { 1630, 2, 12 }, { 1648, -8, 12 }, { 1666, -10, 12 }, { 1684, -4, 12 }, { 1702, 2, 12 }, { 1725, 0, 12 } },
			{ { 1725, 0, 8 }, { 1728, 14, 7 }, { 1735, 26, 7 }, { 1750, 26, 7 }, { 1757, 14, 7 }, { 1760, 0, 8 } },
			{ { 1725, 0, 8 }, { 1728, -14, 7 }, { 1735, -26, 7 }, { 1750, -26, 7 }, { 1757, -14, 7 }, { 1760, 0, 8 } },
			{ { 1760, 0, 12 }, { 1776, 8, 12 }, { 1792, 10, 12 }, { 1808, 2, 12 }, { 1822, -2, 13 }, { 1836, 0, 16 } },
			{ { 1612, 10, 6 }, { 1616, 44, 6 }, { 1620, 68, 6 } }, -- to the giant crystals
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
		if x < 1595 then
			h = math.max(h, 66 + n * 10)
		elseif x > 1838 then
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
			T.faceCrack(ctx.sub("Heights"), c, side, rng, ({ VIOLET, PINK, CYAN })[rng:NextInteger(1, 3)], { neon = true, width = 0.4 })
		end
	end

	---------------------------------------------------------------- features
	function th.features(ctx)
		local sky, scatter, heights = ctx.sub("Sky"), ctx.sub("Scatter"), ctx.sub("Heights")
		-- the planets
		planet(sky, Vector3.new(1760, 250, -470), 80, { hex("C98A5A"), hex("E0B07A"), hex("A86A48"), hex("F0D0A0") })
		local tilt = CFrame.new(1760, 250, -470) * CFrame.Angles(math.rad(18), 0, math.rad(-14))
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			K.part(sky, "PlanetRing", Vector3.new(50, 1.6, 26), tilt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 128), i % 2 == 0 and hex("E8D2A8") or hex("BFA684"), { solid = false, shadow = false, transparency = 0.15 })
		end
		planet(sky, Vector3.new(1960, 210, 430), 50, { hex("6A9AE0"), hex("4A7AC8"), hex("8AB8F0") })
		planet(sky, Vector3.new(1650, 330, 300), 24, { hex("A8A4B8"), hex("8E8AA0") })
		-- the Rift: a glowing tear in the sky beyond the end of the canyon, debris tumbling round it
		local rift = ctx.sub("Rift")
		local rx = 1975
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
		ctx.light(rc, hex("D070FF"), 60, 3)
		ctx.emit(rc, { name = "RiftDust", colors = { WHITE, VIOLET }, size = { 1.2, 0.2 }, rate = 12, speed = { 6, 14 }, life = { 4, 7 }, spread = 180, light = 1 })
		for _ = 1, 12 do
			asteroid(rift, Vector3.new(rx + rng:NextNumber(-30, 20), rng:NextNumber(50, 300), rng:NextNumber(-80, 80)), rng:NextNumber(3, 8))
		end
		-- asteroids drifting over the canyon's edges
		for _ = 1, 10 do
			local side = rng:NextNumber() < 0.5 and 1 or -1
			local x = rng:NextNumber(XA + 20, XB - 30)
			asteroid(sky, Vector3.new(x, rng:NextNumber(36, 90), side * rng:NextNumber(50, 110)), rng:NextNumber(2.5, 6))
		end
		-- the giant crystal grove in the north pocket, clusters in the others
		for _, g in { { 1622, 82, 2.6, 1 }, { 1612, 80, 2, 2 }, { 1630, 86, 2.2, 3 } } do
			crystals(heights, Vector3.new(g[1], 0, g[2]), g[3] * 2.4, 4, LOOKS[g[4]])
		end
		local function spot(margin, nestR)
			for _ = 1, 40 do
				local x, z = rng:NextNumber(XA + 6, DAIS0 - 8), rng:NextNumber(-90, 90)
				if ctx.inside(x, z, margin) and ctx.pathGap(x, z) > 2.5 and ctx.liquidGap(x, z) > 2 and not ctx.nearNest(x, z, nestR or 22) then
					return x, z
				end
			end
		end
		for i = 1, 18 do
			local x, z = spot(3)
			if x then
				crystals(scatter, Vector3.new(x, 0, z), rng:NextNumber(0.7, 1.4), rng:NextInteger(2, 4), nil, { light = i % 2 == 0 })
			end
			if i <= 10 then
				x, z = spot(4)
				if x then
					local r = rng:NextNumber(1.4, 3)
					T.boulder(scatter, Vector3.new(x, 0, z), r, ctx.rockAt, rng, { solid = r > 2.2 })
				end
			end
		end
		-- glinting specks of stardust on the ground
		for _ = 1, 60 do
			local x, z = spot(1, 18)
			if x then
				local s = rng:NextNumber(0.2, 0.35)
				K.box(scatter, "Stardust", x - s, x + s, 0, 0.12, z - s, z + s, ({ WHITE, VIOLET, CYAN })[rng:NextInteger(1, 3)], { neon = true, solid = false, shadow = false })
			end
		end
		-- obelisks along the path
		for i, o in { { 1600, -14 }, { 1640, 18 }, { 1676, -22 }, { 1700, 20 }, { 1784, -16 }, { 1814, 18 } } do
			if ctx.pathGap(o[1], o[2]) > 2 then
				obelisk(scatter, Vector3.new(o[1], 0, o[2]), rng:NextNumber(12, 18), LOOKS[(i - 1) % 3 + 1])
			end
		end
		-- starlight pools glow
		for _, p in POOLS do
			local a = ctx.anchor(scatter, Vector3.new(p[1], 0, p[2]), Vector3.new(p[3] * 1.3, 0.4, p[3] * 1.3))
			ctx.light(a, VIOLET, 18, 1.2)
			ctx.emit(a, { name = "Starlight", colors = { WHITE, VIOLET }, size = { 0.35, 0.1 }, rate = 4, speed = { 0.5, 1.5 }, life = { 2, 3.5 }, spread = 60, light = 1 })
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
		ctx.light(heart, VIOLET, 60, 3)
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
		ctx.light(ctx.anchor(art, Vector3.new(c.X, 3, c.Z)), VIOLET, 16, 1)
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
			ctx.light(ctx.anchor(g, Vector3.new(gx, 88, s * 74)), look.light, 40, 2)
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

	return require(script.Parent.NewBiome)(b, K, T, th)
end
