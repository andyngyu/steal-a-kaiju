-- The Grand Gate on the safe line (Map attribute SafeZoneX = 302), built by CitadelBuilder section "GrandGate":
--   * a 60-deep gatehouse tunnel over x 290..350 (the plots end at x 288; the lane starts at 302), passage 110 wide and
--     60 tall under a stepped vault, so DayNightService's NightBarrier (60 tall, 114 wide, at x 302) still seals it
--   * the raised portcullis just west of the barrier, its spikes hanging at y 56
--   * two huge flanking towers (body 140, belfry, 62-tall pointed spires with golden egg finials, corner turrets)
--   * the iron-banded gate leaves folded back flat against the towers' citadel faces
--   * a kaiju skull trophy on a red shield over THE WILDLANDS; claw gouges on the faces towards the Wildlands
--   * the seven biome flags on the gatehouse, torches in the tunnel, braziers on the towers
-- Nothing here is used by scripts; the Pebble Plains Sign (x 306, z 45) and NestSign stand inside the tunnel untouched.
return function(root, map, ctx, K)
	local P = K.P
	local rng = Random.new(3021)
	local f = K.model(root, "GrandGate")
	local X0, X1 = 290, 350
	local XC = (X0 + X1) / 2
	local DEPTH = X1 - X0
	local O = 55 -- passage half-width
	local TZ = 115 -- towers' outer faces
	local TH = 140 -- tower body height
	local VAULT = 80 -- crown of the stepped vault
	local GH = 152 -- gatehouse wall top (its overhanging parapet sits on it)
	local WEST, EAST = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)
	local function face(x, y, z, n)
		return K.face(Vector3.new(x, y, z), n)
	end

	---------------------------------------------------------------- the flanking towers
	for _, s in { 1, -1 } do
		local t = K.model(f, s > 0 and "TowerN" or "TowerS")
		local z0, z1 = s * O, s * TZ
		local zc = (z0 + z1) / 2
		local ZW = TZ - O
		local OUT = Vector3.new(0, 0, s)
		-- stepped footing on the outer and Wildlands sides (the citadel side carries the gate leaf)
		K.box(t, "Footing", X0, X1, -6, 6, z1, z1 + s * 3, P.Base, { studs = K.ALL })
		K.box(t, "Footing", X1, X1 + 3, -6, 6, z0, z1 + s * 3, P.Base, { studs = K.ALL })
		K.box(t, "Footing", X0, X1, 6, 10, z1, z1 + s * 1.5, P.BaseWarm, { studs = K.ALL })
		K.box(t, "Footing", X1, X1 + 1.5, 6, 10, z0, z1 + s * 1.5, P.BaseWarm, { studs = K.ALL })
		K.masonry(t, "Stone", CFrame.new(XC, 0, zc), Vector3.new(DEPTH, TH, ZW), rng, { t0 = 0, t1 = 0.86, courseMin = 6, courseMax = 10, stoneMin = 12, stoneMax = 30 })
		for _, y in { 64, 104 } do
			K.box(t, "Band", X0 - 0.8, X1 + 0.8, y, y + 2.4, z0 - s * 0.8, z1 + s * 0.8, P.Blue, { studs = K.ALL, solid = false })
		end
		-- buttresses: three on the outer face, two at the edges of the Wildlands face
		for _, bx in { X0 + 5, XC, X1 - 5 } do
			K.box(t, "Buttress", bx - 4, bx + 4, 0, 52, z1, z1 + s * 6, K.tone(rng, 0.08), { studs = K.ALL })
			K.box(t, "Buttress", bx - 3.5, bx + 3.5, 52, 112, z1, z1 + s * 4, K.tone(rng, 0.45), { studs = K.ALL })
			K.box(t, "Buttress", bx - 3, bx + 3, 112, 118, z1, z1 + s * 2, K.tone(rng, 0.8), { studs = K.ALL })
		end
		for _, bz in { s * 61, s * 109 } do
			K.box(t, "Buttress", X1, X1 + 6, 0, 52, bz - 4, bz + 4, K.tone(rng, 0.08), { studs = K.ALL })
			K.box(t, "Buttress", X1, X1 + 4, 52, 112, bz - 3.5, bz + 3.5, K.tone(rng, 0.45), { studs = K.ALL })
			K.box(t, "Buttress", X1, X1 + 2, 112, 118, bz - 3, bz + 3, K.tone(rng, 0.8), { studs = K.ALL })
		end
		-- faces: slits, proud stones, weathering, the claw gouges facing the Wildlands
		local westF = face(X0, 0, zc, WEST)
		local eastF = face(X1, 0, zc, EAST)
		local outF = face(XC, 0, z1, OUT)
		local tunF = face(XC, 0, z0, -OUT)
		for _, wz in { s * 64, s * 106 } do
			for _, y in { 76, 112 } do
				K.slit(t, westF, K.lx(westF, X0, wz), y, 1.8, 8, rng)
			end
		end
		for _, wx in { 307, 333 } do
			for _, y in { 30, 72, 116 } do
				K.slit(t, outF, K.lx(outF, wx, z1), y, 1.8, 8, rng)
			end
		end
		for _, y in { 30, 112 } do
			K.slit(t, eastF, K.lx(eastF, X1, s * 85), y, 1.8, 8, rng)
		end
		K.accents(t, westF, ZW, TH, 8, rng, 0, 0.86, { yMin = 60 })
		K.accents(t, outF, DEPTH, TH, 14, rng, 0, 0.86)
		K.accents(t, eastF, ZW, TH, 10, rng, 0, 0.86)
		K.weather(t, outF, DEPTH, TH, rng, { moss = 6, vines = 3, vineTop = TH - 2, cracks = 2, holes = 1 })
		K.weather(t, eastF, ZW, TH, rng, { moss = 4, vines = 2, vineTop = TH - 2, cracks = 1, holes = 1 })
		K.weather(t, westF, ZW, TH, rng, { moss = 0, vines = 2, vineTop = TH - 2, cracks = 1, holes = 1, yMin = 62 })
		K.weather(t, tunF, DEPTH, 60, rng, { moss = 3, vines = 0, cracks = 1, holes = 0 })
		K.claws(t, eastF, 0, 74, 48, rng)
		-- the gate leaf, folded back flat against the citadel face (x 288.6..290, clear of the plots at x < 288)
		K.gateLeaf(t, face(X0, 0, s * 84.75, WEST), 50.5, 58)
		for _, wz in { s * 61.5, s * 108 } do
			K.torch(t, westF, K.lx(westF, X0, wz), 60.5)
		end
		K.banner(t, CFrame.lookAt(Vector3.new(X0 - 1.4, 130, s * 83), Vector3.new(X0 - 20, 130, s * 83)), 16, 62,
			s > 0 and { cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold }
				or { cloth = P.Navy, trim = P.Bronze, emblem = "egg", mark = P.Gold, tail = "point" })
		-- machicolated parapet, battlements, corner turrets, a brazier over the gateway
		K.masonry(t, "Parapet", CFrame.new(XC, TH, zc + s * 1.5), Vector3.new(DEPTH + 6, 6, ZW + 3), rng, { t0 = 0.92, t1 = 0.95, courseMin = 6, courseMax = 6, stoneMin = 12, stoneMax = 24, topStuds = true })
		K.corbels(t, Vector3.new(X0, 0, s * 58), Vector3.new(X0, 0, s * 112), TH, WEST, 6, rng)
		K.corbels(t, Vector3.new(X1, 0, s * 58), Vector3.new(X1, 0, s * 112), TH, EAST, 6, rng)
		K.corbels(t, Vector3.new(X0 + 3, 0, z1), Vector3.new(X1 - 3, 0, z1), TH, OUT, 6, rng)
		K.merlonRect(t, XC, zc + s * 1.5, DEPTH / 2 + 3, ZW / 2 + 1.5, TH + 6, 3.5, 5.5, 2.5, rng, 0.92)
		for _, cx in { X0 - 1, X1 + 1 } do
			K.bartizan(t, Vector3.new(cx, TH - 10, z1 + s * 1), rng, { w = 9, h = 24, roofH = 18 })
		end
		K.brazier(t, Vector3.new(X0 + 4, TH + 6, s * 61), 1.3)
		-- the belfry and its spire
		local BX0, BX1 = 300, 340
		local bxc = (BX0 + BX1) / 2
		local bzc = s * 85
		local BY0, BY1 = TH + 6, TH + 46
		K.masonry(t, "Stone", CFrame.new(bxc, BY0, bzc), Vector3.new(40, BY1 - BY0, 40), rng, { t0 = 0.85, t1 = 1, courseMin = 6, courseMax = 8, stoneMin = 12, stoneMax = 24 })
		for _, F in { face(BX0, BY0, bzc, WEST), face(BX1, BY0, bzc, EAST), face(bxc, BY0, bzc + s * 20, OUT) } do
			for _, wx in { -9, 9 } do
				K.window(t, F, wx, 12, 5, 16, false)
			end
		end
		K.box(t, "Corbel", BX0 - 2, BX1 + 2, BY1, BY1 + 3, bzc - 22, bzc + 22, K.tone(rng, 0.95), { studs = K.ALLB })
		K.merlonRect(t, bxc, bzc, 22, 22, BY1 + 3, 3, 4.5, 2.4, rng, 0.97)
		local top = K.spire(t, bxc, bzc, BY1 + 3, 37, 37, 62, 12, P.Bronze)
		local _, eggTop = K.egg(t, Vector3.new(bxc, top, bzc), 6, P.Gold, P.Red)
		K.flagPole(t, Vector3.new(bxc, eggTop, bzc), 20, 14, 8, s > 0 and P.Red or P.Navy, P.Gold)
	end

	---------------------------------------------------------------- the gatehouse over the tunnel
	K.masonry(f, "Stone", CFrame.new(XC, VAULT, 0), Vector3.new(DEPTH, GH - VAULT, 2 * O), rng, { t0 = 0.5, t1 = 0.88, axis = "Z", courseMin = 6, courseMax = 10, stoneMin = 12, stoneMax = 28 })
	local steps = { { 50, 60 }, { 44, 65 }, { 36, 70 }, { 25, 75 } } -- { half-width, bottom }
	local prev = O
	for i, st in steps do
		for _, s in { -1, 1 } do
			K.box(f, "Vault", X0, X1, st[2], VAULT, s * st[1], s * prev, i % 2 == 1 and P.Mid or P.Blue, { studs = K.ALLB })
		end
		prev = st[1]
	end
	K.portcullis(f, 300, O, 56, VAULT)
	-- both mouths: tan voussoirs lining the vault, a keystone, carved jambs
	for _, mouth in { { X0, -1 }, { X1, 1 } } do
		local x, dir = mouth[1], mouth[2]
		local prevHalf = O
		for _, st in steps do
			for _, s in { -1, 1 } do
				K.box(f, "Voussoir", x, x + dir * 1, st[2], st[2] + 2, s * st[1], s * prevHalf, P.Tan, { studs = K.ALLB, solid = false })
			end
			prevHalf = st[1]
		end
		K.box(f, "Keystone", x, x + dir * 1.6, VAULT - 9, VAULT + 1, -5, 5, P.Tan, { studs = K.ALL, solid = false })
		for _, s in { -1, 1 } do
			K.box(f, "Jamb", x, x + dir * 1.2, 0, 60, s * O, s * (O + 5), P.Tan, { studs = K.ALL })
			local jF = face(x + dir * 1.2, 0, s * (O + 2.5), Vector3.new(dir, 0, 0))
			K.eggRelief(f, jF, 0, 30, 4, P.Light, P.Gold)
		end
	end
	-- carved plaques (Antique) and the skull trophy over the citadel side
	K.sign(f, "SignWest", CFrame.lookAt(Vector3.new(X0 - 0.6, 88.5, 0), Vector3.new(X0 - 20, 88.5, 0)), 88, 12, "THE WILDLANDS")
	K.sign(f, "SignEast", CFrame.lookAt(Vector3.new(X1 + 0.6, 88.5, 0), Vector3.new(X1 + 20, 88.5, 0)), 88, 12, "KAIJU CITADEL")
	K.skull(f, CFrame.lookAt(Vector3.new(X0, 121, 0), Vector3.new(X0 - 20, 121, 0)), 1.2)
	local gwF = face(X0, 0, 0, WEST)
	local geF = face(X1, 0, 0, EAST)
	for _, z in { -42, 42 } do
		K.eggRelief(f, gwF, K.lx(gwF, X0, z), 108, 12, P.Tan, P.Gold)
	end
	K.accents(f, gwF, 2 * O, GH, 10, rng, 0.5, 0.88, { yMin = 98 })
	K.accents(f, geF, 2 * O, GH, 12, rng, 0.5, 0.88, { yMin = 98 })
	K.weather(f, geF, 2 * O, GH, rng, { moss = 0, vines = 2, vineTop = GH - 1, cracks = 2, holes = 1, yMin = 98 })
	K.claws(f, geF, 30, 120, 34, rng)
	-- machicolated parapet and battlements on both faces
	K.masonry(f, "Parapet", CFrame.new(XC, GH, 0), Vector3.new(DEPTH + 6, 6, 2 * O), rng, { t0 = 0.92, t1 = 0.95, axis = "Z", courseMin = 6, courseMax = 6, stoneMin = 12, stoneMax = 24, topStuds = true })
	K.corbels(f, Vector3.new(X0, 0, -52), Vector3.new(X0, 0, 52), GH, WEST, 6, rng)
	K.corbels(f, Vector3.new(X1, 0, -52), Vector3.new(X1, 0, 52), GH, EAST, 6, rng)
	K.merlonLine(f, Vector3.new(X0 - 1.75, 0, -O), Vector3.new(X0 - 1.75, 0, O), GH + 6, 3.5, 5.5, 2.5, rng, 3, 0.92)
	K.merlonLine(f, Vector3.new(X1 + 1.75, 0, -O), Vector3.new(X1 + 1.75, 0, O), GH + 6, 3.5, 5.5, 2.5, rng, 3, 0.92)
	-- the seven biome flags along the gatehouse, in lane order
	for i, acc in ctx.accents do
		local z = (i - (#ctx.accents + 1) / 2) * 13
		K.flagPole(f, Vector3.new(XC, GH + 6, z), 22, 9, 6, acc, P.Navy)
	end
	-- the tunnel: flagstone floor (a thin skin over the ground) and torches on both walls
	for x = X0, X1 - 1, 10 do
		local z = -O
		while z < O - 0.01 do
			local l = math.min(O - z, rng:NextInteger(5, 12) * 2)
			if O - z - l < 6 then
				l = O - z
			end
			K.box(f, "Paving", x, x + 10, 0, 0.12, z, z + l, K.tone(rng, 0.9), { studs = K.TOP })
			z += l
		end
	end
	for _, s in { -1, 1 } do
		local tf = face(XC, 0, s * O, Vector3.new(0, 0, -s))
		for _, x in { 296, 344 } do
			K.torch(f, tf, K.lx(tf, x, s * O), 30)
		end
	end
	return f
end
