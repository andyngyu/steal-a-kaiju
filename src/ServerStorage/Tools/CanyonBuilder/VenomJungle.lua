-- Venom Jungle (x 827..1052), built by CanyonBuilder.NewBiome: a steaming jungle canyon in mossy dark stone.
-- Palette: jungle greens, with toxic lime (the falls, pools, glyphs) and poison purple (strata veins, mushrooms,
-- thorns, flowers) as the accents; a green humid haze for a sky (VFXConfig.Weather.VenomJungle).
--   Ground     jungle floor (grass, moss, mud, fallen leaves) broken up by gnarled roots, raised moss carpets, murky
--              puddles and poison flowers; meltwater, slush and snow where it meets Frostfang; a packed-earth path that
--              forks round the nest's temple courtyard
--   Rock       dark mossy strata with poison-purple veins, rugged crags behind (T.massif), the far ranges paler sage
--   Toxic      four toxic falls pouring off the cliffs in translucent layers (a dark body, a glowing lime sheet,
--              wandering bright streaks, lips over every ledge, foam at the foot) into glowing pools; the two seen from
--              the gate also stream, splash and steam (particles). A creek runs from the north pool to the south one
--              that the path crosses on a plank bridge
--   Temple     a stepped temple at the back of the north clearing: glyph bands, a shrine with eyes glowing in its door,
--              serpent heads, green fire; the nest sits in its paved courtyard ringed with broken pillars
--   Mushrooms  a grove of giant glowing mushrooms behind lowered cliffs in the south, more in the pockets and up top
--   Bridges    two rope-and-plank vine bridges strung between the cliff tops high over the path
--   Gate       the Temple Gate: stepped stone pylons, a glyph-carved lintel, a great serpent over the way in; while
--              locked: thorned vines strung from the pylons to a stone serpent coiled round an eye seal, a toxic haze
--              with spores, a giant serpent's silhouette rearing behind with lime eyes, a mossy carved-stone COMING SOON
-- Lights: only what reads from the gate (the gate fires, the near falls and pools, the near mushrooms; key lights on
-- the temple's eyes, the two biggest mushrooms and the serpent); nothing lit deep inside.
local hex = Color3.fromHex
local TEX = require(game:GetService("ReplicatedStorage").Shared.Config.VFXConfig).Textures

return function(b, K, T)
	local P = K.P
	local XA, XB = b.x0, b.x1
	local NX = XA + (b.NestAt or 0.55) * (XB - XA)
	local C, rng

	---------------------------------------------------------------- colours
	local ROCK = { hex("2B3326"), hex("3B4434"), hex("525C44"), hex("67704F"), accent = hex("4A3060") }
	local FARROCK = { hex("5E7A58"), hex("6C8864"), hex("7A9670"), hex("88A47C") }
	local GRASS = { hex("3D7B31"), hex("36702B"), hex("2F6627"), hex("467F35") }
	local MUD = { hex("5A4630"), hex("4A3A28") }
	local BANK = hex("3A2E20")
	local MOSS, MOSS2 = hex("2E5E2A"), hex("3F7A34")
	local LITTER = { hex("6B7A2E"), hex("7E7A34") }
	local TROD = { hex("7A6A48"), hex("6E5F40"), hex("85744F") }
	local PAVE = { hex("8A8C78"), hex("7E8070"), hex("95967F") }
	local MELT = { hex("E6F1FA"), hex("C8D6E4"), hex("6B6A5C") } -- snow, slush, wet mud (by Frostfang)
	local SLABS = { hex("8A8C78"), hex("767A66"), hex("9A9C86") }
	local CAPS = { hex("2F7A36"), hex("2A6B30"), hex("358A3C"), hex("276030") }
	local SNOW = hex("F4FAFF")
	local TOXIC = { hex("7CF03A"), hex("6AE02E"), hex("94FF4A") }
	local GLOW = hex("7DFF4A")
	local LIME, POISON = hex("B4FF3A"), hex("B04CFF")
	local FALLB, FOAMC = hex("4CC834"), hex("E6FFB8") -- a fall's body, its foam and streaks
	local VINE2, THORN = hex("254C1F"), hex("3A1F4A")
	local PUDDLE = hex("2E4430")
	local STONE = { hex("6E7560"), hex("616853"), hex("7A806A"), hex("575E4A") } -- temple stone
	local TRIM = hex("3A4032")
	local BARK = { hex("5A3F28"), hex("4A3322"), hex("3E2B1C") }
	local LEAF = { hex("2E5A26"), hex("3B6E2C"), hex("25502A"), hex("467F35") }
	local VINE, VLEAF = hex("2F5E26"), hex("4C8A34")
	local FERN = { hex("3E8A35"), hex("2F7A2C") }
	local STEM = { hex("E8E0C8"), hex("D6CCB2") }
	local TIMBER = { hex("6B4A2C"), hex("5C3F25") }
	local ROPE = hex("8A7448")
	local SCALE, SCALE2, BELLY = hex("2F6E33"), hex("245A29"), hex("B9C46A")
	local LOOKS = { -- mushroom caps and their glow
		{ cap = { hex("5A2794"), hex("6E33B0"), hex("8A4FD6") }, glow = hex("C77DFF"), gill = hex("7A35C8"), spot = hex("D9B8FF") },
		{ cap = { hex("9A2266"), hex("B5337E"), hex("D2509C") }, glow = hex("FF6FC8"), gill = hex("C02A80"), spot = hex("FFC2E4") },
		{ cap = { hex("2E7A3A"), hex("3C9446"), hex("52B05A") }, glow = GLOW, gill = hex("4CB82A"), spot = hex("C8FF9E") },
	}

	---------------------------------------------------------------- layout
	local TX, TZ = math.floor(NX + 0.5), 90 -- the temple: centre x, front z
	local POOLS = { { 888, 66, 8 }, { 874, -70, 8 }, { 1016, -70, 9 }, { 1005, 64, 7 } }
	local CREEK = { { 1005, 64, 6 }, { 999, 46, 5 }, { 993, 26, 4.5 }, { 995, 6, 4.5 }, { 1003, -20, 5 }, { 1010, -46, 6 }, { 1016, -70, 7 } }
	local BRIDGE = { x = 1000.5, z = -12 } -- where the path crosses the creek
	local function liquidGap(x, z)
		local g = math.huge
		for _, p in POOLS do
			local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
			g = math.min(g, d - p[3] * (0.85 + 0.3 * T.n01(x / 5 + p[1], z / 5, 3.3)))
		end
		local d, half = T.polyDistance(CREEK, x, z)
		return math.min(g, d - half)
	end
	local function inTemple(x)
		return x > TX - 40 and x < TX + 40
	end
	local function inGrove(x)
		return x > 928 and x < 976
	end

	---------------------------------------------------------------- shapes
	local function fern(parent, at, s)
		local m = K.model(parent, "Fern")
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			K.part(m, "Frond", Vector3.new(0.8 * s, 0.25, 3.4 * s), CFrame.new(at) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.9 * s, -1.5 * s) * CFrame.Angles(math.rad(-24), 0, 0), FERN[i % 2 + 1], { solid = false, shadow = false })
		end
		return m
	end
	local function bush(parent, at, s)
		local m = K.model(parent, "Bush")
		K.part(m, "Leaves", Vector3.new(3.2, 2.2, 2.8) * s, CFrame.new(at + Vector3.new(0, 1.0 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), LEAF[rng:NextInteger(1, 4)], { studs = K.ALL, solid = false })
		K.part(m, "Leaves", Vector3.new(2.2, 1.6, 2.4) * s, CFrame.new(at + Vector3.new(0.6 * s, 2.0 * s, 0.3 * s)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), LEAF[rng:NextInteger(1, 4)], { studs = K.ALL, solid = false })
		if rng:NextNumber() < 0.4 then
			for _ = 1, 3 do
				local p = at + Vector3.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(0.8, 2.2), rng:NextNumber(-1.3, 1.3)) * s
				K.box(m, "Berry", p.X - 0.3, p.X + 0.3, p.Y - 0.3, p.Y + 0.3, p.Z - 0.3, p.Z + 0.3, hex("C77DFF"), { neon = true, solid = false, shadow = false })
			end
		end
		return m
	end
	local function tree(parent, at, h, o)
		o = o or {}
		local m = K.model(parent, "JungleTree")
		local tw = math.max(0.9, h * 0.07)
		local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * h * 0.07
		local mid = at + Vector3.new(0, h * 0.42, 0) + lean * 0.5
		local top = at + Vector3.new(0, h * 0.74, 0) + lean
		T.chain(m, "Trunk", { at - Vector3.new(0, 0.6, 0), mid, top }, { tw * 2, tw * 1.6 }, { BARK[1], BARK[2] }, { studs = K.SIDES, solid = o.solid == true })
		if not o.small then
			for k = 0, 2 do
				local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
				K.part(m, "Root", Vector3.new(tw * 0.9, tw * 2.4, tw * 2.6), CFrame.new(at) * CFrame.Angles(0, a, 0) * CFrame.new(0, tw * 0.7, tw * 1.5) * CFrame.Angles(math.rad(30), 0, 0), BARK[3], { solid = false })
			end
		end
		for k = 0, (o.small and 1 or 2) do
			local w = h * (0.62 - k * 0.14) * rng:NextNumber(0.9, 1.1)
			local d = h * (0.56 - k * 0.12) * rng:NextNumber(0.9, 1.1)
			local ch = h * 0.11
			local off = Vector3.new(rng:NextNumber(-1, 1) * h * 0.06, h * 0.72 + k * ch * 0.9, rng:NextNumber(-1, 1) * h * 0.06) + lean
			K.part(m, "Canopy", Vector3.new(w, ch, d), CFrame.new(at + off) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), LEAF[rng:NextInteger(1, #LEAF)], { studs = K.ALL, solid = false })
		end
		if not o.small then
			for _ = 1, rng:NextInteger(1, 3) do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = h * rng:NextNumber(0.18, 0.26)
				C.strand(m, at + lean + Vector3.new(math.cos(a) * r, h * 0.7, math.sin(a) * r), h * rng:NextNumber(0.2, 0.4), VINE, VLEAF, 0.6)
			end
		end
		return m
	end
	-- a glowing mushroom: a pale stem, a stepped dome cap, glowing gills under it, pale spots on it
	local function mushroom(parent, base, h, r, look, o)
		o = o or {}
		local m = K.model(parent, "GlowMushroom")
		local sw = math.max(0.6, r * 0.3)
		local F = CFrame.new(base) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-6, 6)))
		local segs = h > 24 and 3 or (h > 6 and 2 or 1)
		for i = 0, segs - 1 do
			local w = sw * (1.2 - i * 0.12)
			K.part(m, "Stem", Vector3.new(w, h / segs + 0.3, w), F * CFrame.new(0, (i + 0.5) * h / segs, 0) * CFrame.Angles(0, math.rad(i * 25), 0), STEM[i % 2 + 1], { studs = r > 4 and K.SIDES or nil, solid = o.solid == true and i == 0 })
		end
		local c = (F * CFrame.new(0, h, 0)).Position
		local steps = r < 3 and 1 or (r < 9 and 2 or 3)
		local ch = r * 0.55
		C.dome(m, "Cap", c, r, ch, steps, function(t)
			return look.cap[math.clamp(math.floor(t * #look.cap) + 1, 1, #look.cap)]
		end, { studs = r > 4 and K.ALL or nil, solid = false, shadow = r > 4 and nil or false })
		local gills
		if r >= 3 then
			gills = C.octagon(m, "Gills", c, r * 0.86, c.Y - 0.6, c.Y + 0.05, look.gill, { neon = true, solid = false, shadow = false })
			for _ = 1, math.min(9, math.floor(r * 0.6)) do
				local a = rng:NextNumber(0, math.pi * 2)
				local rho = r * rng:NextNumber(0.2, 0.72)
				local t = math.sqrt(1 - (rho / r) ^ 2)
				local k = math.min(steps - 1, math.floor(t * steps))
				local y = c.Y + ch * (k + 1) / steps
				local ss = r * rng:NextNumber(0.1, 0.16)
				local sx, sz = c.X + math.cos(a) * rho, c.Z + math.sin(a) * rho
				K.box(m, "Spot", sx - ss, sx + ss, y - 0.05, y + 0.3, sz - ss, sz + ss, look.spot, { neon = true, solid = false, shadow = false })
			end
		else
			gills = K.box(m, "Gills", c.X - r * 0.6, c.X + r * 0.6, c.Y - 0.35, c.Y + 0.02, c.Z - r * 0.6, c.Z + r * 0.6, look.gill, { neon = true, solid = false, shadow = false })
		end
		if o.key then
			C.keyLight(gills, look.glow, math.min(60, r * 2.4 + 8), r > 8 and 2.2 or 1.3)
		elseif o.light then
			C.light(gills, look.glow, math.min(60, r * 2.4 + 8), r > 8 and 2 or 1.3)
		end
		return m
	end
	local function shroomCluster(parent, at, n)
		local look = LOOKS[rng:NextInteger(1, #LOOKS)]
		local m = K.model(parent, "ShroomCluster")
		for i = 1, n do
			local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-2.4, 2.4))
			mushroom(m, at + off, rng:NextNumber(1.2, 3.6), rng:NextNumber(0.7, 1.6), look)
		end
		if at.X < 900 then -- lit only where the gate sees them
			C.light(C.anchor(m, at + Vector3.new(0, 2, 0)), look.glow, 12, 1)
		end
		return m
	end
	-- a toxic fall down a cliff column's faces: per layer a dark see-through body, a lime glowing sheet in front and a
	-- few short bright streaks (staggered, so it reads as flowing, not as a stripe); it runs across each ledge and lips
	-- over its edge; foam at the foot. fx (the falls seen from the gate): a stream of drops pouring off the lip, mist
	-- and splashing drops at the foot, a light. Returns the foot.
	local function toxicFall(parent, col, side, x, w, fx)
		local m = K.model(parent, "ToxicFall")
		local L = col.layers
		local top = col.top or L[#L].yt
		local lo, hi = col.x0 + w / 2 + 0.3, col.x1 - w / 2 - 0.3
		x = math.clamp(x, lo, math.max(lo, hi))
		for i = #L, 1, -1 do
			local l = L[i]
			local yt = i == #L and top + 1.4 or l.yt
			local f = l.f
			local ww = w * (1 + (#L - i) * 0.07)
			-- short segments that wander and change width, the glowing sheet narrower and off-centre on each
			local y = yt
			while y > l.yb + 0.01 do
				local seg = math.min(y - l.yb, rng:NextNumber(2.4, 4.4))
				local sw = ww * rng:NextNumber(0.78, 1.08)
				local sx = math.clamp(x + rng:NextNumber(-0.6, 0.6), col.x0 + sw / 2 + 0.2, math.max(col.x0 + sw / 2 + 0.2, col.x1 - sw / 2 - 0.2))
				K.box(m, "FallBody", sx - sw / 2, sx + sw / 2, y - seg, y, side * (f - 0.9), side * (f + 0.05), FALLB, { transparency = 0.3, solid = false, shadow = false })
				local gw = sw * rng:NextNumber(0.35, 0.6)
				local gx = sx + rng:NextNumber(-(sw - gw) / 2, (sw - gw) / 2)
				K.box(m, "FallSheet", gx - gw / 2, gx + gw / 2, y - seg, y, side * (f - 1.25), side * (f - 0.9), LIME, { neon = true, transparency = 0.72, solid = false, shadow = false })
				y -= seg
			end
			for _ = 1, 3 do
				local sx = x + rng:NextNumber(-ww * 0.4, ww * 0.4)
				local len = math.min(yt - l.yb, rng:NextNumber(2.5, 6))
				local sy = rng:NextNumber(l.yb, math.max(l.yb, yt - len))
				K.box(m, "FallStreak", sx - 0.18, sx + 0.18, sy, sy + len, side * (f - 1.45), side * (f - 1.2), FOAMC, { neon = true, transparency = 0.3, solid = false, shadow = false })
			end
			local nxt = L[i - 1]
			if nxt and nxt.f < f - 0.3 then
				K.box(m, "FallLip", x - ww / 2, x + ww / 2, l.yb - 0.2, l.yb + 0.5, side * (nxt.f - 1.2), side * (f - 0.9), FALLB, { transparency = 0.25, solid = false, shadow = false })
				K.box(m, "FallLipGlow", x - ww * 0.4, x + ww * 0.4, l.yb + 0.3, l.yb + 0.65, side * (nxt.f - 1.3), side * (f - 0.9), LIME, { neon = true, transparency = 0.4, solid = false, shadow = false })
			end
		end
		local foot = Vector3.new(x, 0, side * (L[1].f - 1.2))
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local p = foot + Vector3.new(math.cos(a) * w * 0.6, 0, math.sin(a) * w * 0.45 - side * 1.6)
			K.box(m, "Foam", p.X - 0.9, p.X + 0.9, -0.5, rng:NextNumber(0.2, 0.9), p.Z - 0.9, p.Z + 0.9, FOAMC, { transparency = 0.35, solid = false, shadow = false })
		end
		if fx then
			local h = top + 1.4
			local tFall = (-6 + math.sqrt(36 + 4 * 15 * h)) / 30 -- h = 6 t + 15 t^2 (speed 6, accel 30)
			local lip = C.anchor(m, Vector3.new(x, h, side * (L[#L].f - 1.1)), Vector3.new(w * 0.8, 0.2, 0.4))
			C.emit(lip, { name = "Stream", texture = TEX.Soft, colors = { LIME, FALLB }, size = { 1, 0.7 }, rate = 30, speed = { 5, 7 }, life = { tFall * 0.92, tFall }, spread = 2, accel = Vector3.new(0, -30, 0), light = 0.6, dir = Enum.NormalId.Bottom, transparency = { 0.35, 0.55 }, squash = 1.2, orientation = Enum.ParticleOrientation.VelocityParallel })
			local pool = C.anchor(m, foot + Vector3.new(0, 0.8, -side * 2.5), Vector3.new(w * 1.4, 0.4, 4))
			C.emit(pool, { name = "Mist", texture = TEX.Soft, colors = { hex("DFFFC8"), hex("9BE07A") }, size = { 3, 9 }, rate = 5, speed = { 0.5, 2 }, life = { 3, 5 }, spread = 60, accel = Vector3.new(0, 0.9, 0), light = 0.2, transparency = { 0.72, 1 }, rotSpeed = { -20, 20 } })
			C.emit(pool, { name = "Splash", texture = TEX.Soft, colors = { FOAMC, LIME }, size = { 0.45, 0.2 }, rate = 14, speed = { 5, 9 }, life = { 0.5, 0.9 }, spread = 45, accel = Vector3.new(0, -32, 0), light = 0.5, transparency = { 0.1, 0.5 } })
			C.keyLight(pool, LIME, 28, 1.6)
		end
		return foot
	end
	-- a thick vine strung from a to c, sagging, leaves and purple thorns along it, now and then a poison bloom
	local function heavyVine(parent, a, c, sag, w)
		local n = math.max(4, math.floor((c - a).Magnitude / 6))
		local pts = {}
		for i = 0, n do
			local t = i / n
			local p = a:Lerp(c, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
			if i > 0 and i < n then
				p += Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8))
			end
			table.insert(pts, p)
		end
		T.chain(parent, "Vine", pts, { w or 1.4 }, { VINE, VINE2 }, { studs = K.SIDES, solid = false, shadow = false })
		for i = 1, n do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			local a2 = rng:NextNumber(0, math.pi * 2)
			K.part(parent, "Leaf", Vector3.new(2, 0.25, 1.1), CFrame.new(p) * CFrame.Angles(a2, rng:NextNumber(0, 3), 0) * CFrame.new(1.2, 0, 0), i % 2 == 0 and VLEAF or LEAF[2], { solid = false, shadow = false })
			K.part(parent, "Thorn", Vector3.new(0.35, 1.3, 0.35), CFrame.new(p) * CFrame.Angles(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * CFrame.new(0, 0.9, 0), THORN, { solid = false, shadow = false })
			if i % 3 == 0 then
				K.box(parent, "Bloom", p.X - 0.6, p.X + 0.6, p.Y + 0.5, p.Y + 1.5, p.Z - 0.6, p.Z + 0.6, i % 2 == 0 and POISON or LIME, { neon = true, solid = false, shadow = false })
			end
		end
		return pts
	end
	-- a gnarled root snaking along the ground from `at`, half buried
	local function root(parent, at, yaw, len)
		local pts = { at + Vector3.new(0, 0.8, 0) }
		local p, a = at, yaw
		local n = math.max(3, math.floor(len / 3.5))
		for i = 1, n do
			a += rng:NextNumber(-0.5, 0.5)
			p += Vector3.new(math.cos(a), 0, math.sin(a)) * len / n
			table.insert(pts, Vector3.new(p.X, i == n and -0.2 or rng:NextNumber(0.15, 0.7), p.Z))
		end
		local widths = {}
		for i = 1, n do
			widths[i] = 1.6 - 1.0 * (i - 1) / math.max(1, n - 1)
		end
		T.chain(parent, "Root", pts, widths, { BARK[2], BARK[3] }, { studs = K.SIDES, solid = false })
	end
	local function log(parent, at, len, yaw)
		local m = K.model(parent, "FallenLog")
		local d = rng:NextNumber(1.8, 2.6)
		local F = CFrame.new(at + Vector3.new(0, d / 2 - 0.3, 0)) * CFrame.Angles(0, yaw, 0)
		K.part(m, "Log", Vector3.new(d, d, len), F, BARK[2], { studs = K.SIDES, solid = false })
		K.part(m, "LogEnd", Vector3.new(d * 0.8, d * 0.8, 0.2), F * CFrame.new(0, 0, len / 2 + 0.05), hex("8A6A44"), { solid = false })
		K.part(m, "Moss", Vector3.new(d * 0.8, 0.3, len * 0.6), F * CFrame.new(0, d / 2 + 0.1, rng:NextNumber(-len * 0.15, len * 0.15)), MOSS2, { studs = K.TOP, solid = false })
		for _ = 1, 2 do
			K.part(m, "Fungus", Vector3.new(0.6, 0.3, 1.2), F * CFrame.new(d / 2 + 0.2, rng:NextNumber(-0.3, 0.4), rng:NextNumber(-len * 0.4, len * 0.4)), hex("E8C27A"), { solid = false })
		end
		return m
	end
	-- a serpent head (a cobra's hood behind it, jaws open, fangs, glowing eyes); cf at the back of its neck, facing out
	local function serpentHead(parent, cf, s)
		local m = K.model(parent, "SerpentHead")
		local function p(name, size, off, color, rot, o)
			local c = cf * CFrame.new(off * s)
			if rot then
				c = c * rot
			end
			return K.part(m, name, size * s, c, color, o or { studs = K.SIDES, solid = false })
		end
		p("Hood", Vector3.new(10, 7, 1.6), Vector3.new(0, 3.6, 2), SCALE2)
		p("HoodMark", Vector3.new(5, 3.4, 0.4), Vector3.new(0, 3.8, 1.05), BELLY, nil, { solid = false })
		p("Skull", Vector3.new(6, 4.2, 7), Vector3.new(0, 2.4, -1.5), SCALE)
		p("Brow", Vector3.new(6.8, 1.2, 2.6), Vector3.new(0, 4.6, -3.6), SCALE2)
		p("Snout", Vector3.new(4.8, 2.2, 5), Vector3.new(0, 2.6, -6.6), SCALE)
		p("Nostrils", Vector3.new(3, 0.6, 0.6), Vector3.new(0, 3.1, -9.15), TRIM, nil, { solid = false })
		p("Mouth", Vector3.new(4.2, 1.4, 4.6), Vector3.new(0, 1.2, -6), hex("5A1A2A"), nil, { solid = false })
		p("Jaw", Vector3.new(4.4, 1.3, 6.4), Vector3.new(0, 0.3, -5.2), BELLY, CFrame.Angles(math.rad(-16), 0, 0))
		for _, sx in { -1, 1 } do
			p("Fang", Vector3.new(0.7, 2.6, 0.7), Vector3.new(sx * 1.6, 0.6, -8.4), P.Tooth, nil, { solid = false })
			p("Eye", Vector3.new(1.4, 0.9, 0.4), Vector3.new(sx * 2.2, 3.7, -5.1), GLOW, nil, { neon = true, solid = false, shadow = false })
		end
		p("Tongue", Vector3.new(0.5, 0.25, 3.2), Vector3.new(0, 0.9, -9.6), hex("C2283A"), nil, { solid = false })
		return m
	end
	-- a rope-and-plank bridge strung across the canyon at x, sagging in the middle, vines hanging off it
	local function vineBridge(parent, x, zA, zB, y0, sag)
		local m = K.model(parent, "VineBridge")
		local L = zB - zA
		local function yAt(z)
			local t = (z - zA) / L * 2 - 1
			return y0 - sag * (1 - t * t)
		end
		local z = zA
		while z < zB do
			if rng:NextNumber() > 0.07 then
				local t = (z - zA) / L * 2 - 1
				local slope = 4 * sag * t / L
				K.part(m, "Plank", Vector3.new(5.2, 0.35, 1.7), CFrame.new(x + rng:NextNumber(-0.25, 0.25), yAt(z), z) * CFrame.Angles(-math.atan(slope), rng:NextNumber(-0.05, 0.05), 0), TIMBER[rng:NextInteger(1, 2)], { solid = false })
			end
			z += 2.1
		end
		for _, sx in { -1, 1 } do
			local pts = {}
			for i = 0, 12 do
				local zz = zA + L * i / 12
				table.insert(pts, Vector3.new(x + sx * 2.8, yAt(zz) + 2.6, zz))
			end
			T.chain(m, "Rope", pts, { 0.35 }, { ROPE }, { solid = false, shadow = false })
			for i = 2, #pts - 1, 2 do
				local q = pts[i]
				K.box(m, "Tie", q.X - 0.12, q.X + 0.12, q.Y - 2.6, q.Y, q.Z - 0.12, q.Z + 0.12, ROPE, { solid = false, shadow = false })
			end
		end
		local zz = zA + 10
		while zz < zB - 10 do
			C.strand(m, Vector3.new(x + rng:NextNumber(-2.4, 2.4), yAt(zz) - 0.2, zz), rng:NextNumber(3, 12), VINE, VLEAF, 0.6)
			zz += rng:NextNumber(6, 11)
		end
		return m
	end

	---------------------------------------------------------------- the theme
	local th = {
		seed = 4417,
		half = 90,
		accent = GLOW,
		gateOpenH = 60,
		blendLen = 26,
		rock = ROCK,
		farRock = FARROCK,
		rugged = true,
		slabs = SLABS,
		slabChance = 0.55,
		edgeN = { { 827, 65 }, { 836, 66 }, { 846, 74 }, { 858, 86 }, { 876, 88 }, { 886, 74 }, { 896, 66 }, { 903, 74 }, { 910, 90 }, { 992, 90 }, { 999, 80 }, { 1006, 72 }, { 1016, 84 }, { 1030, 84 }, { 1040, 70 }, { 1047, 66 }, { 1052, 65 } },
		edgeS = { { 827, 65 }, { 838, 64 }, { 848, 70 }, { 860, 80 }, { 874, 82 }, { 884, 70 }, { 894, 62 }, { 906, 64 }, { 918, 72 }, { 930, 84 }, { 944, 88 }, { 960, 88 }, { 972, 76 }, { 984, 64 }, { 996, 66 }, { 1010, 78 }, { 1024, 80 }, { 1036, 70 }, { 1046, 66 }, { 1052, 65 } },
		paths = {
			{ { 827, 0, 14 }, { 842, -6, 12 }, { 858, -10, 12 }, { 874, -4, 12 }, { 890, 8, 12 }, { 906, 12, 12 }, { 922, 6, 12 }, { 934, 0, 12 } },
			{ { 934, 0, 8 }, { 937, 14, 7 }, { 944, 26, 7 }, { 958, 26, 7 }, { 965, 14, 7 }, { 968, 0, 8 } },
			{ { 934, 0, 8 }, { 937, -14, 7 }, { 944, -26, 7 }, { 958, -26, 7 }, { 965, -14, 7 }, { 968, 0, 8 } },
			{ { 968, 0, 12 }, { 984, -8, 12 }, { 1000, -12, 12 }, { 1016, -4, 12 }, { 1032, 6, 12 }, { 1044, 2, 12 }, { 1052, 0, 13 } },
			{ { 951, 26, 6 }, { 951, 56, 6 }, { 951, 84, 6 } }, -- to the temple stair
			{ { 874, -4, 6 }, { 870, -34, 6 }, { 868, -56, 6 } }, -- into the south pocket, by the pool
		},
		liquid = {
			gap = liquidGap,
			neon = true,
			top = -0.6,
			overPath = true,
			color = function(_, _, _, n)
				return TOXIC[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end,
		},
	}

	function th.init(ctx)
		C, rng = ctx, ctx.rng
	end

	function th.ground(ctx, x, z, n, n2)
		local dn = math.sqrt((x - NX) ^ 2 + z * z)
		if dn < 17.5 then
			if dn > 15 then
				return STONE[4]
			end
			return PAVE[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		if ctx.pathGap(x, z) <= 0 then
			return TROD[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		local f = ctx.blend(x)
		if f > 0 and n2 < f * 1.3 - 0.1 then
			return MELT[n2 < f * 0.6 - 0.2 and 1 or (n < 0.5 and 2 or 3)]
		end
		if ctx.liquidGap(x, z) < 2.5 then
			return BANK
		end
		local side = z >= 0 and 1 or -1
		if math.abs(z) > ctx.edge[side](x) - 10 and n2 < 0.45 then
			return MUD[n < 0.5 and 1 or 2]
		end
		if n2 > 0.8 then
			return LITTER[n < 0.5 and 1 or 2]
		end
		if n2 < 0.16 then
			return MOSS
		end
		return GRASS[math.clamp(math.floor(n * 4) + 1, 1, 4)]
	end

	function th.cap(ctx, x, r)
		local f = ctx.blend(x)
		if r:NextNumber() < f * f * 1.6 then
			return SNOW
		end
		return CAPS[r:NextInteger(1, #CAPS)]
	end

	function th.tint(x, c)
		local f = math.clamp(1 - (x - XA) / 34, 0, 1)
		return f > 0 and c:Lerp(hex("4A5466"), f * 0.5) or c
	end

	function th.height(_, side, x, n)
		if side > 0 and x > TX - 40 and x < TX + 40 then
			return 0 -- the temple stands here
		end
		local h = 44 + n * 30
		if side < 0 and inGrove(x) then
			h = 24 + n * 10 -- low in front of the giant mushrooms
		end
		if math.abs(x - 880) < 9 or math.abs(x - 1026) < 9 then
			h = math.max(h, 54 + n * 4) -- the vine bridges' anchors
		end
		if x < 846 then
			h = math.max(h, 70 + n * 10) -- as tall as Frostfang's last cliffs beside the gate
		elseif x > 1036 then
			h = math.max(h, 64 + n * 10)
		end
		return math.floor(h / 2 + 0.5) * 2
	end

	function th.ridge(_, side, x, n)
		if side > 0 and x > TX - 36 and x < TX + 36 then
			return 0 -- the temple fills it
		end
		if side < 0 and x > 922 and x < 982 then
			return math.floor(34 + n * 12) -- the mushrooms show against the sky
		end
		return math.floor(62 + n * 40)
	end

	function th.farHeight(_, _, _, n)
		return math.floor(118 + n * 70)
	end

	function th.column(ctx, c, side)
		local top = c.layers[#c.layers]
		if rng:NextNumber() < 0.5 and top then
			local vx = rng:NextNumber(c.x0 + 0.8, c.x1 - 0.8)
			ctx.strand(ctx.sub("Vines"), Vector3.new(vx, c.top + 0.6, side * (c.lastFront - 0.4)), math.min(c.top - top.yb + 2, rng:NextNumber(5, 14)), VINE, VLEAF)
		end
		if rng:NextNumber() < 0.14 and #c.layers >= 2 then
			local L = c.layers[rng:NextInteger(1, #c.layers - 1)]
			local fx = rng:NextNumber(c.x0 + 1.5, c.x1 - 1.5)
			local fy = rng:NextNumber(L.yb + 1.5, math.max(L.yb + 1.6, L.yt - 2))
			for k = 0, rng:NextInteger(1, 2) do
				local w = rng:NextNumber(1.6, 2.8)
				K.box(ctx.sub("Fungi"), "BracketFungus", fx - w / 2 + k * 1.2, fx + w / 2 + k * 1.2, fy + k * 1.6, fy + k * 1.6 + 0.45, side * (L.f - w * 0.55), side * (L.f + 0.1), k % 2 == 0 and GLOW or hex("C77DFF"), { neon = true, solid = false, shadow = false })
			end
		end
		if c.h > 26 and rng:NextNumber() < 0.3 then
			T.faceCrack(ctx.sub("Vines"), c, side, rng, hex("1A2216"), { width = rng:NextNumber(0.7, 1.1) })
		end
	end

	---------------------------------------------------------------- features
	function th.features(ctx)
		local flows, scatter, greens = ctx.sub("Flows"), ctx.sub("Scatter"), ctx.sub("Greenery")
		-- toxic falls into the pools (the two seen from the gate stream, splash and steam); those pools glow and bubble
		local nFalls = 0
		for _, f in { { 1, 888 }, { -1, 874 }, { 1, 1005 }, { -1, 1016 } } do
			local col = ctx.nearestCol(f[1], f[2], 34)
			if col then
				toxicFall(flows, col, f[1], (col.x0 + col.x1) / 2, rng:NextNumber(4, 5.2), f[2] < 900)
				nFalls += 1
			end
		end
		for _, p in POOLS do
			if p[1] < 900 then
				local a = ctx.anchor(flows, Vector3.new(p[1], 0, p[2]), Vector3.new(p[3] * 1.3, 0.4, p[3] * 1.3))
				ctx.light(a, GLOW, 18, 1.1)
				ctx.emit(a, { name = "ToxicBubbles", texture = TEX.Soft, colors = { hex("D8FFB8"), LIME }, size = { 0.45, 0.15 }, rate = 5, speed = { 1, 2.5 }, life = { 1.2, 2.2 }, spread = 35, light = 0.7 })
			end
		end
		table.insert(ctx.report, nFalls .. " toxic falls")

		-- the plank bridge where the path crosses the creek (walkable, a step up from the ground)
		local br = ctx.sub("Bridge")
		local F = CFrame.lookAt(Vector3.new(BRIDGE.x, 0.17, BRIDGE.z), Vector3.new(BRIDGE.x + 16, 0.17, BRIDGE.z - 1))
		for zz = -9, 9, 1.5 do
			K.part(br, "Plank", Vector3.new(8, 0.34, 1.3), F * CFrame.new(rng:NextNumber(-0.2, 0.2), 0, zz), TIMBER[rng:NextInteger(1, 2)], { studs = K.TOP })
		end
		for _, sx in { -1, 1 } do
			for zz = -9, 9, 6 do
				K.part(br, "Post", Vector3.new(0.6, 3.4, 0.6), F * CFrame.new(sx * 4.2, 1.6, zz), TIMBER[2], { solid = false })
			end
			K.part(br, "Rope", Vector3.new(0.3, 0.3, 19), F * CFrame.new(sx * 4.2, 3, 0), ROPE, { solid = false, shadow = false })
			ctx.strand(br, (F * CFrame.new(sx * 4.2, 3, rng:NextNumber(-5, 5))).Position, 2.6, VINE, VLEAF, 0.5)
		end

		-- the temple at the back of the north clearing
		local tm = ctx.sub("Temple")
		for i = 0, 4 do
			local inset = i * 7
			local y0, y1 = (i == 0) and -2 or i * 10, (i + 1) * 10
			local x0, x1 = TX - 42 + inset, TX + 42 - inset
			local z0 = TZ + inset
			K.box(tm, "Tier", x0, x1, y0, y1, z0, 212, STONE[i % 4 + 1], { studs = K.SIDES })
			K.box(tm, "TierTop", x0 - 0.3, x1 + 0.3, y1, y1 + 0.8, z0 - 0.3, 212, STONE[(i + 2) % 4 + 1], { studs = K.TOP, solid = false })
			K.box(tm, "Band", x0 - 0.2, x1 + 0.2, y1 - 4, y1 - 2, z0 - 0.4, z0 + 0.2, TRIM, { solid = false })
			local gx = x0 + 3
			while gx < x1 - 3 do
				if math.abs(gx - TX) > 7.5 then
					K.box(tm, "Glyph", gx - 0.7, gx + 0.7, y1 - 3.6, y1 - 2.4, z0 - 0.6, z0 - 0.35, GLOW, { neon = true, solid = false, shadow = false })
				end
				gx += rng:NextNumber(5, 8)
			end
			-- moss along the tier's edge, vines hanging down its face
			for _ = 1, 2 do
				local mx = rng:NextNumber(x0 + 4, x1 - 14)
				if math.abs(mx + 5 - TX) > 12 then
					K.box(tm, "Moss", mx, mx + rng:NextNumber(5, 10), y1 + 0.8, y1 + 1.3, z0 - 0.5, z0 + rng:NextNumber(2, 5), MOSS2, { studs = K.TOP, solid = false })
				end
			end
			for _ = 1, 3 do
				local vx = rng:NextNumber(x0 + 2, x1 - 2)
				if math.abs(vx - TX) > 8 then
					ctx.strand(tm, Vector3.new(vx, y1 + 0.6, z0 - 0.5), rng:NextNumber(3, 8), VINE, VLEAF)
				end
			end
		end
		-- the stair: walkable from the clearing up to the first tier (the lane's wall stops you there), then on up
		for k = 1, 10 do
			local z0 = TZ - 7 + (k - 1) * 0.7
			K.box(tm, "Step", TX - 6, TX + 6, -2, k, z0, z0 + 0.7, STONE[k % 2 + 1], { studs = K.TOP })
		end
		for i = 0, 3 do
			for k = 1, 5 do
				local z0 = TZ + 7 * i + (k - 1) * 1.4
				K.box(tm, "Step", TX - 6, TX + 6, 10 * (i + 1), 10 * (i + 1) + 2 * k + 0.8, z0, z0 + 1.4, STONE[k % 2 + 1], { studs = K.TOP, solid = false })
			end
		end
		for _, sx in { -1, 1 } do
			-- serpent idols flanking the foot of the stair
			K.box(tm, "Plinth", TX + sx * 10 - 2.5, TX + sx * 10 + 2.5, 0, 4, TZ - 6, TZ - 1, STONE[3], { studs = K.ALL, solid = false })
			serpentHead(tm, CFrame.lookAt(Vector3.new(TX + sx * 10, 4, TZ - 1.5), Vector3.new(TX + sx * 10, 4, 0)), 0.6)
		end
		-- the shrine on top: a dark door with eyes glowing in it, a roof comb with glyphs, serpent heads, green fire
		local sy, sz = 50.8, TZ + 34
		K.box(tm, "Shrine", TX - 11, TX + 11, sy, sy + 13, sz, sz + 22, STONE[3], { studs = K.SIDES })
		K.box(tm, "ShrineRoof", TX - 12.5, TX + 12.5, sy + 13, sy + 15.5, sz - 1.5, sz + 23.5, STONE[2], { studs = K.ALL })
		K.box(tm, "RoofComb", TX - 8, TX + 8, sy + 15.5, sy + 25, sz + 8, sz + 11, STONE[4], { studs = K.SIDES })
		for i = -2, 2 do
			K.box(tm, "Glyph", TX + i * 3 - 0.7, TX + i * 3 + 0.7, sy + 18, sy + 21.5, sz + 7.6, sz + 7.9, GLOW, { neon = true, solid = false, shadow = false })
		end
		K.box(tm, "Doorway", TX - 4, TX + 4, sy, sy + 9, sz - 0.25, sz + 0.1, P.Socket, { solid = false })
		local eye
		for _, ex in { -1.7, 1.7 } do
			eye = K.box(tm, "Eye", TX + ex - 0.7, TX + ex + 0.7, sy + 5.4, sy + 6.2, sz - 0.4, sz - 0.25, GLOW, { neon = true, solid = false, shadow = false })
		end
		ctx.keyLight(eye, GLOW, 30, 2.2)
		for _, sx in { -1, 1 } do
			K.box(tm, "DoorPillar", TX + sx * 5.6 - 1.2, TX + sx * 5.6 + 1.2, sy, sy + 13, sz - 1.2, sz + 0.5, STONE[1], { studs = K.SIDES, solid = false })
			serpentHead(tm, CFrame.lookAt(Vector3.new(TX + sx * 13.5, sy + 0.6, sz + 3), Vector3.new(TX + sx * 13.5, sy + 0.6, 0)), 0.85)
			local bp = Vector3.new(TX + sx * 7.5, sy, TZ + 30)
			ctx.octagon(tm, "Brazier", bp, 1.8, sy, sy + 1.6, P.Iron, { solid = false })
			ctx.octagon(tm, "BrazierBowl", bp, 2.4, sy + 1.6, sy + 2.6, TRIM, { solid = false })
			ctx.fire(tm, bp + Vector3.new(0, 2.8, 0), 5, GLOW, hex("2E9E22"), GLOW, 0)
		end
		-- trees growing on the tiers' ends
		for _, t in { { TX - 31, 1, 13 }, { TX + 31, 1, 15 }, { TX - 18, 3, 11 }, { TX + 22, 2, 12 } } do
			tree(tm, Vector3.new(t[1], (t[2] + 1) * 10 + 0.8, TZ + t[2] * 7 + 8), t[3], { small = true })
		end

		-- the courtyard round the nest: a low kerb, broken pillars, rune stones
		local cy = ctx.sub("Courtyard")
		for k = 0, 7 do
			if k ~= 0 and k ~= 4 then
				local a = k * math.pi / 4
				K.part(cy, "Kerb", Vector3.new(1.4, 0.7, 13.7), CFrame.new(NX + math.cos(a) * 16.5, 0.35, math.sin(a) * 16.5) * CFrame.Angles(0, -a, 0), STONE[4], { studs = K.TOP, solid = false })
			end
		end
		-- colonnades either side (clear of the paths forking round it and the entrances east and west)
		local heights = { 15, 6, 12, 5, 17, 9 }
		for k, deg in { 60, 90, 120, 240, 270, 300 } do
			local a = math.rad(deg)
			local px, pz = NX + math.cos(a) * 15.6, math.sin(a) * 15.6
			local h = heights[k]
			K.box(cy, "PillarBase", px - 1.9, px + 1.9, 0, 1.2, pz - 1.9, pz + 1.9, STONE[2], { studs = K.ALL, solid = false })
			K.box(cy, "Pillar", px - 1.3, px + 1.3, 1.2, 1.2 + h, pz - 1.3, pz + 1.3, STONE[k % 2 == 0 and 1 or 3], { studs = K.SIDES, solid = false })
			K.box(cy, "Glyph", px - 0.5, px + 0.5, 3.4, 4.6, pz - 1.4, pz + 1.4, GLOW, { neon = true, solid = false, shadow = false })
			if h >= 11 then
				K.box(cy, "Capital", px - 1.9, px + 1.9, 1.2 + h, 2.4 + h, pz - 1.9, pz + 1.9, STONE[2], { studs = K.ALL, solid = false })
				K.box(cy, "Moss", px - 1.6, px + 1.2, 2.4 + h, 2.8 + h, pz - 1.4, pz + 1.6, MOSS2, { studs = K.TOP, solid = false })
				if h >= 15 then
					serpentHead(cy, CFrame.lookAt(Vector3.new(px, 2.4 + h, pz), Vector3.new(NX, 2.4 + h, 0)), 0.42)
				else
					ctx.strand(cy, Vector3.new(px + 1.35, 2.2 + h, pz), h * 0.6, VINE, VLEAF, 0.6)
				end
			else
				-- the broken-off drum lies beside it
				local ra = a + rng:NextNumber(-0.5, 0.5)
				K.part(cy, "Drum", Vector3.new(2.6, 2.6, 5), CFrame.new(px + math.cos(ra) * 4, 1.1, pz + math.sin(ra) * 4) * CFrame.Angles(0, -ra + math.pi / 2, math.rad(rng:NextNumber(-10, 10))), STONE[3], { studs = K.SIDES, solid = false })
			end
		end

		-- the giant mushroom grove (south, behind lowered cliffs) and more in the pockets
		local grove = ctx.sub("Mushrooms")
		for _, g in { { 942, -104, 52, 17, 1, true }, { 963, -99, 42, 13, 2 }, { 929, -97, 38, 10, 3 }, { 976, -110, 60, 15, 1, true }, { 953, -93, 36, 8, 2 } } do
			mushroom(grove, Vector3.new(g[1], 0, g[2]), g[3], g[4], LOOKS[g[5]], { key = g[6] })
		end
		for _, g in { { 864, 80, 14, 5, 2 }, { 1021, 76, 12, 4.5, 1 }, { 1030, -67, 16, 6, 3 }, { 852, -64, 10, 4, 1 }, { 905, -58, 8, 3.4, 3 }, { 990, 70, 9, 3.6, 2 } } do
			if ctx.pathGap(g[1], g[2]) > 3 and ctx.liquidGap(g[1], g[2]) > 3 then
				mushroom(grove, Vector3.new(g[1], 0, g[2]), g[3], g[4], LOOKS[g[5]], { light = g[1] < 900 })
			end
		end

		-- vine bridges between the cliff tops
		local hi = ctx.sub("Bridges")
		for _, bx in { 880, 1026 } do
			vineBridge(hi, bx, -(ctx.edge[-1](bx) + 14), ctx.edge[1](bx) + 14, 54, 9)
		end

		-- trees in the pockets, down the margins
		local nTrees = 0
		for _, side in { 1, -1 } do
			local x = XA + 18
			while x < XB - 14 do
				local e = ctx.edge[side](x)
				local z = side * (e - rng:NextNumber(5, 9))
				if e >= 72 and not (side > 0 and inTemple(x)) and not (side < 0 and inGrove(x)) and ctx.liquidGap(x, z) > 5 and ctx.pathGap(x, z) > 4 then
					tree(greens, Vector3.new(x, 0, z), rng:NextNumber(16, 26), { solid = ctx.pathGap(x, z) > 7 })
					nTrees += 1
				end
				x += rng:NextNumber(11, 16)
			end
		end
		for _, p in { { TX - 38, 82 }, { TX + 37, 80 } } do
			tree(greens, Vector3.new(p[1], 0, p[2]), 24, { solid = true })
			nTrees += 1
		end
		-- and up on the heights: small trees, now and then a mushroom
		for _, t in ctx.tops do
			if t.z1 > t.z0 and rng:NextNumber() < (t.big and 0.5 or 0.32) then
				local at = Vector3.new(t.x + rng:NextNumber(-3, 3), t.y, t.side * rng:NextNumber(t.z0, t.z1))
				if rng:NextNumber() < 0.16 then
					mushroom(greens, at, rng:NextNumber(8, 16), rng:NextNumber(3.5, 6.5), LOOKS[rng:NextInteger(1, #LOOKS)])
				else
					tree(greens, at, t.big and rng:NextNumber(18, 28) or rng:NextNumber(12, 18), { small = true })
				end
				nTrees += 1
			end
		end
		table.insert(ctx.report, nTrees .. " trees")

		-- the undergrowth
		local function spot(margin)
			for _ = 1, 40 do
				local x, z = rng:NextNumber(XA + 6, XB - 6), rng:NextNumber(-88, 88)
				if ctx.inside(x, z, margin) and ctx.pathGap(x, z) > 2.5 and ctx.liquidGap(x, z) > 2 and not ctx.nearNest(x, z, 22) then
					return x, z
				end
			end
		end
		for i = 1, 34 do
			local x, z = spot(2)
			if x then
				fern(scatter, Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.4))
			end
			if i <= 16 then
				x, z = spot(3)
				if x then
					bush(scatter, Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.3))
				end
			end
			if i <= 10 then
				x, z = spot(3)
				if x then
					shroomCluster(scatter, Vector3.new(x, 0, z), rng:NextInteger(3, 5))
				end
			end
			if i <= 12 then
				x, z = spot(2)
				if x then
					T.wildflowers(scatter, Vector3.new(x, 0, z), 3, 6, { POISON, hex("8A3CE0"), LIME, hex("D070FF") }, hex("2F6E2A"), rng)
				end
			end
			if i <= 5 then
				x, z = spot(6)
				if x then
					log(scatter, Vector3.new(x, 0, z), rng:NextNumber(9, 15), rng:NextNumber(0, math.pi))
				end
			end
			if i <= 10 then
				x, z = spot(4)
				if x then
					local r = rng:NextNumber(1.4, 3)
					T.boulder(scatter, Vector3.new(x, 0, z), r, ctx.rockAt, rng, { solid = r > 2.2, moss = MOSS2 })
				end
			end
		end
		-- the floor broken up: gnarled roots out from the margins, raised moss carpets, murky puddles
		local floor = ctx.sub("Floor")
		for _ = 1, 18 do
			local side = rng:NextNumber() < 0.5 and 1 or -1
			local x = rng:NextNumber(XA + 24, XB - 10)
			local z = side * (ctx.edge[side](x) - rng:NextNumber(1, 4))
			if not (side > 0 and inTemple(x)) and ctx.liquidGap(x, z) > 3 then
				root(floor, Vector3.new(x, 0, z), side > 0 and -math.pi / 2 + rng:NextNumber(-0.7, 0.7) or math.pi / 2 + rng:NextNumber(-0.7, 0.7), rng:NextNumber(8, 16))
			end
		end
		for _ = 1, 20 do
			local x, z = spot(2)
			if x then
				for k = 1, rng:NextInteger(2, 3) do
					local w, d = rng:NextNumber(2.5, 5), rng:NextNumber(2, 4)
					local cx, cz = x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2)
					K.part(floor, "MossCarpet", Vector3.new(w, 0.3 + k * 0.08, d), CFrame.new(cx, 0.12, cz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), k == 1 and MOSS or MOSS2, { studs = K.TOP, solid = false, shadow = false })
				end
			end
		end
		for _ = 1, 14 do
			local x, z = spot(3)
			if x then
				local pd = K.part(floor, "Puddle", Vector3.new(rng:NextNumber(3, 6), 0.12, rng:NextNumber(2.4, 4.5)), CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), PUDDLE, { transparency = 0.12, solid = false, shadow = false })
				pd.Reflectance = 0.25
				if rng:NextNumber() < 0.3 then
					K.part(floor, "PuddleGlint", Vector3.new(pd.Size.X * 0.5, 0.13, pd.Size.Z * 0.4), pd.CFrame, LIME, { neon = true, transparency = 0.6, solid = false, shadow = false })
				end
			end
		end
		-- the last of the snow, by the gate
		for _ = 1, 6 do
			local side = rng:NextNumber() < 0.5 and 1 or -1
			local x = rng:NextNumber(XA + 3, XA + 22)
			local z = side * (ctx.edge[side](x) - rng:NextNumber(2, 9))
			if ctx.pathGap(x, z) > 2 then
				T.boulder(scatter, Vector3.new(x, -0.4, z), rng:NextNumber(1.4, 2.6), function()
					return MELT[rng:NextInteger(1, 2)]
				end, rng, { name = "Snowdrift" })
			end
		end
	end

	---------------------------------------------------------------- the nest: woven vines on a mossy bed, toxic petals
	function th.nest(ctx, art, c)
		ctx.octagon(art, "Bed", c, 6.4, -0.05, 0.3, MOSS, { studs = K.TOP, solid = false })
		for k = 0, 7 do
			local a = k * math.pi / 4
			K.part(art, "Ring", Vector3.new(1.6, 1.1, 5.9), CFrame.new(c.X + math.cos(a) * 6.9, 0.55, c.Z + math.sin(a) * 6.9) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-8, 8))), k % 2 == 0 and BARK[1] or VINE, { studs = K.SIDES, solid = false })
		end
		for k = 0, 5 do
			local a = (k + 0.5) / 6 * math.pi * 2
			K.part(art, "Leaf", Vector3.new(1.8, 0.2, 3.6), CFrame.new(c.X + math.cos(a) * 8.8, 0.12, c.Z + math.sin(a) * 8.8) * CFrame.Angles(0, -a + math.pi / 2, 0), LEAF[k % 4 + 1], { solid = false })
		end
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.4
			local px, pz = c.X + math.cos(a) * 10.4, c.Z + math.sin(a) * 10.4
			K.box(art, "Petal", px - 0.5, px + 0.5, 0, 0.6, pz - 0.5, pz + 0.5, k % 2 == 0 and GLOW or hex("C77DFF"), { neon = true, solid = false, shadow = false })
		end
	end

	---------------------------------------------------------------- the Temple Gate
	function th.gate(ctx, g)
		local gx = XA
		local steps = { { -2, 27, 60, 106, 28 }, { 27, 40, 61, 102, 23 }, { 40, 52, 62, 98, 19 }, { 52, 62, 63, 95, 16 } }
		for _, s in { -1, 1 } do
			for i, st in steps do
				local w = st[5] / 2
				K.box(g, "Pylon", gx - w, gx + w, st[1], st[2], s * st[3], s * st[4], STONE[i % 4 + 1], { studs = K.ALL })
				K.box(g, "PylonBand", gx - w - 0.25, gx + w + 0.25, st[2] - 3.4, st[2] - 1.6, s * (st[3] - 0.25), s * (st[4] + 0.25), TRIM, { solid = false })
				local z = st[3] + 3
				while z < st[4] - 3 do
					K.box(g, "Glyph", gx - w - 0.45, gx - w - 0.2, st[2] - 3.1, st[2] - 1.9, s * (z - 0.6), s * (z + 0.6), GLOW, { neon = true, solid = false, shadow = false })
					z += rng:NextNumber(5, 8)
				end
			end
			-- green fire on the lintel's ends
			local bp = Vector3.new(gx, 78, s * 94)
			ctx.octagon(g, "Brazier", bp, 2.4, 78, 79.6, P.Iron, { solid = false })
			ctx.octagon(g, "BrazierBowl", bp, 3.2, 79.6, 81, TRIM, { solid = false })
			ctx.fire(g, bp + Vector3.new(0, 3.2, 0), 7, GLOW, hex("2E9E22"), GLOW, 32)
			-- the serpent's body coiling along the lintel to its head in the middle
			T.chain(g, "SerpentBody", {
				Vector3.new(gx + 1, 79, s * 86),
				Vector3.new(gx + 2, 82.5, s * 72),
				Vector3.new(gx + 1, 80, s * 58),
				Vector3.new(gx + 2, 84, s * 44),
				Vector3.new(gx + 1, 87, s * 30),
				Vector3.new(gx + 1, 91, s * 16),
				Vector3.new(gx + 0.5, 93, s * 4),
			}, { 3.4, 4, 4.4, 4.8, 5.2, 5.6 }, { SCALE, SCALE2 })
		end
		K.box(g, "Lintel", gx - 8, gx + 8, 62, 76, -106, 106, STONE[2], { studs = K.ALL })
		K.box(g, "LintelBand", gx - 8.25, gx + 8.25, 72.4, 74.4, -106.25, 106.25, TRIM, { solid = false })
		K.box(g, "LintelTop", gx - 9, gx + 9, 76, 78, -108, 108, STONE[3], { studs = K.ALL, solid = false })
		for _, fx in { -1, 1 } do
			local z = -102
			while z < 102 do
				if fx > 0 or math.abs(z) > 36 then
					K.box(g, "Glyph", gx + fx * 8.3 - 0.12, gx + fx * 8.3 + 0.12, 72.8, 74, z - 0.6, z + 0.6, GLOW, { neon = true, solid = false, shadow = false })
				end
				z += rng:NextNumber(5, 8)
			end
		end
		K.box(g, "Crown", gx - 7, gx + 7, 78, 84, -30, 30, STONE[1], { studs = K.ALL, solid = false })
		K.box(g, "Crown", gx - 6, gx + 6, 84, 88, -18, 18, STONE[4], { studs = K.ALL, solid = false })
		serpentHead(g, CFrame.lookAt(Vector3.new(gx, 88, 0), Vector3.new(gx - 40, 80, 0)), 2.9)
		-- a crest of stepped teeth along the lintel top
		for _, s in { -1, 1 } do
			for z = 36, 100, 8 do
				K.box(g, "Crest", gx - 3, gx + 3, 78, 81 + (z % 16 == 4 and 2 or 0), s * (z - 2), s * (z + 2), STONE[4], { studs = K.ALL, solid = false })
			end
		end
		-- an idol mask carved into each pylon's inner face, glaring across the way through: a recessed panel, a heavy
		-- brow, glowing eyes, bared teeth
		for _, s in { -1, 1 } do
			local F = CFrame.lookAt(Vector3.new(gx, 0, s * 60), Vector3.new(gx, 0, 0))
			local function mp(name, w, y0, y1, lx, d, color, o)
				return K.part(g, name, Vector3.new(w, y1 - y0, d), F * CFrame.new(lx, (y0 + y1) / 2, -d / 2), color, o or { solid = false })
			end
			mp("MaskPanel", 22, 2, 23, 0, 0.3, TRIM)
			mp("MaskBrow", 18, 17.5, 21, 0, 2.2, STONE[3], { studs = K.ALL, solid = false })
			for _, ex in { -4.5, 4.5 } do
				mp("MaskSocket", 5.2, 13, 17.5, ex, 0.9, P.Socket)
				mp("MaskEye", 2.6, 14.2, 16.2, ex, 1.1, GLOW, { neon = true, solid = false, shadow = false })
			end
			mp("MaskNose", 4, 9, 14, 0, 2.4, STONE[1], { studs = K.ALL, solid = false })
			mp("MaskMouth", 14, 3.5, 8, 0, 0.9, P.Socket)
			for tx = -6, 6, 2.4 do
				mp("MaskTooth", 1.2, 6, 8, tx, 1.4, P.Tooth)
				mp("MaskTooth", 1, 3.5, 5.2, tx + 1.1, 1.4, P.Tooth)
			end
		end
		-- vines hanging from the lintel over the way through, moss on top
		for _, fx in { -1, 1 } do
			for z = -54, 54, 9 do
				if rng:NextNumber() < 0.7 then
					ctx.strand(g, Vector3.new(gx + fx * 8.4, 62.3, z + rng:NextNumber(-2, 2)), rng:NextNumber(4, 13), VINE, VLEAF)
				end
			end
		end
		for _, mz in { -84, -50, 46, 80 } do
			K.box(g, "Moss", gx - 8.5, gx + 8.5, 78, 78.6, mz - rng:NextNumber(4, 8), mz + rng:NextNumber(4, 8), MOSS2, { studs = K.TOP, solid = false })
		end
		ctx.plaque(g, CFrame.lookAt(Vector3.new(gx - 8.6, 66.6, 0), Vector3.new(gx - 30, 66.6, 0)), 58, 7.6, "VENOM JUNGLE", { board = hex("1F2E1A"), frame = STONE[3], line = GLOW, text = hex("D8FFB8"), neon = true })
	end

	---------------------------------------------------------------- the lock: vines, a serpent-coiled seal, the serpent behind
	-- the seal: a stone serpent coiled in a ring round an eye carved in stone, its head reared over the top
	local function seal(parent, c)
		local m = K.model(parent, "SerpentSeal")
		local R, n = 7, 14
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi * 2 + math.pi / 2
			if i ~= 0 then -- the gap at the top, where the head rears out
				local p = c + Vector3.new(0, math.sin(a) * R, math.cos(a) * R)
				local out = Vector3.new(0, math.sin(a), math.cos(a))
				local len = 2 * math.pi * R / n * 1.12
				K.part(m, "Coil", Vector3.new(3, 3, len), CFrame.fromMatrix(p, Vector3.xAxis, out), i % 2 == 0 and SCALE or SCALE2, { studs = K.SIDES, solid = false })
				K.part(m, "CoilBelly", Vector3.new(0.4, 1.4, len * 0.9), CFrame.fromMatrix(p - Vector3.new(1.55, 0, 0), Vector3.xAxis, out), BELLY, { solid = false })
			end
		end
		for _, rot in { 0, 45 } do
			K.part(m, "SealStone", Vector3.new(1.2, 9.4, 9.4), CFrame.new(c) * CFrame.Angles(math.rad(rot), 0, 0), STONE[4], { studs = K.SIDES, solid = false })
		end
		for _, rot in { 0, 45 } do
			K.part(m, "SealIris", Vector3.new(0.3, 5.6, 5.6), CFrame.new(c - Vector3.new(0.7, 0, 0)) * CFrame.Angles(math.rad(rot), 0, 0), POISON, { neon = true, solid = false, shadow = false })
		end
		K.part(m, "SealPupil", Vector3.new(0.3, 4.6, 1), CFrame.new(c - Vector3.new(0.9, 0, 0)), LIME, { neon = true, solid = false, shadow = false })
		serpentHead(m, CFrame.lookAt(c + Vector3.new(0.5, R + 1, 0), c + Vector3.new(-30, R - 1, 0)), 0.8)
		T.chain(m, "CoilTail", { c + Vector3.new(0, -R + 0.8, 1.8), c + Vector3.new(-0.5, -R - 1.5, 5), c + Vector3.new(-0.8, -R - 2.2, 8) }, { 1.6, 0.9 }, { SCALE2 }, { solid = false })
		return m
	end
	-- the COMING SOON tablet: carved mossy stone, lime glyph edge, moss on top, vines over its corners, poison blooms
	local function stoneTablet(parent, cf, w, h, text)
		local s = C.plaque(parent, cf, w, h, text, { board = hex("26331F"), frame = STONE[3], line = LIME, text = hex("ECFFD8"), neon = true })
		local fw = math.max(0.8, h * 0.1)
		local W = w + fw * 2
		K.part(s, "Moss", Vector3.new(W * 0.7, 0.6, 2.2), cf * CFrame.new(-W * 0.1, h / 2 + fw + 0.2, 0), MOSS2, { studs = K.TOP, solid = false })
		K.part(s, "Moss", Vector3.new(W * 0.3, 0.5, 2), cf * CFrame.new(W * 0.3, h / 2 + fw + 0.15, 0), MOSS, { studs = K.TOP, solid = false })
		for _, sx in { -1, 1 } do
			local top = (cf * CFrame.new(sx * (W / 2 - 1.5), h / 2 + fw, -1.2)).Position
			C.strand(s, top, h + fw * 2 - 0.5, VINE, VLEAF, 0.6)
			K.part(s, "Bloom", Vector3.new(1, 1, 0.5), cf * CFrame.new(sx * (W / 2 - 1.5), h / 2 - 1, -1.5), sx > 0 and POISON or LIME, { neon = true, solid = false, shadow = false })
		end
		return s
	end
	function th.lock(ctx, cs, gx)
		local H = th.gateOpenH
		-- a faint toxic haze across the opening, spores drifting in it
		local field = K.box(cs, "Field", gx - 0.2, gx + 0.2, 0, H, -59, 59, LIME, { neon = true, transparency = 0.94, solid = false, shadow = false })
		ctx.emit(field, { name = "Spores", texture = TEX.Soft, colors = { LIME, POISON }, size = { 0.5, 0.2 }, rate = 14, speed = { 0.3, 1 }, life = { 3, 5 }, spread = 180, light = 0.8, dir = Enum.NormalId.Left })
		-- the seal high in the opening, thorned vines strung to it from the pylons (the serpent shows below it)
		local sc = Vector3.new(gx - 1.8, 49, 0)
		for _, s in { -1, 1 } do
			for _, e in { { 59, 4, 1.6 }, { 34, -4, 3.2 } } do
				heavyVine(cs, Vector3.new(gx - 1.2, e[1], s * 60), sc + Vector3.new(0, e[2], s * 6.5), e[3], 1.5)
			end
			-- and a loose one draped low across the corner
			heavyVine(cs, Vector3.new(gx - 1.2, 18, s * 60), Vector3.new(gx - 1.2, 3, s * 34), 2, 1.1)
		end
		seal(cs, sc)
		-- the kaiju beyond: a giant serpent rearing, black against the haze, lime eyes
		local k = ctx.silhouette(cs, "InfernoSerpent", Vector3.new(gx + 50, 0, -22), Vector3.new(-1, 0, 0.75), 48, { eye = LIME, body = hex("060A06"), lift = hex("142012") })
		if k then
			ctx.keyLight(ctx.anchor(cs, Vector3.new(gx + 76, 32, 0)), LIME, 60, 2.6)
		end
		for _, f in { -1, 1 } do
			local x = gx + f * 1.3
			stoneTablet(cs, CFrame.lookAt(Vector3.new(x, 10.5, 0), Vector3.new(x + f * 20, 10.5, 0)), 40, 8.4, "COMING SOON").Name = "ComingSoon"
		end
	end

	return require(script.Parent.NewBiome)(b, K, T, th)
end
