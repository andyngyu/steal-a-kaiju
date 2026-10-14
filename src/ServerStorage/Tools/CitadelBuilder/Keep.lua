-- The Kaiju Keep, built by CitadelBuilder section "Keep": the citadel's landmark at the far (west) end of the avenue,
-- straight behind the Hall of Champions and on the line through the Grand Gate, so it closes the view down the avenue
-- and is the first thing seen when coming home from the Wildlands. Four tiers of studded masonry (patch stone, tan trim),
-- four corner towers with pointed roofs, corner turrets, glowing windows, deep red banners and spire bands, braziers,
-- and the tallest spire in the citadel (golden egg finial at about y 400). The front has depth: half-towers either side,
-- a recessed entrance under a stepped arch with a balcony above, and the citadel's crest high on tier 2.
-- Footprint x -250..-102 (the entrance steps), z -84..84: outside
-- the old west wall line, clear of the plots, the market and the leaderboards (which stay exactly where they are).
return function(root, map, ctx, K)
	local P = K.P
	local rng = Random.new(4242)
	local f = K.model(root, "Keep")
	local EAST, WEST = Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
	local NORTH, SOUTH = Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)
	local function face(x, y, z, n)
		return K.face(Vector3.new(x, y, z), n)
	end

	---------------------------------------------------------------- footing and tier 1 (the great hall)
	K.box(f, "Footing", -250, -116, -40, 6, -72, 72, P.Base, { studs = K.SIDES })
	K.box(f, "Footing", -248, -118, 6, 12, -70, 70, P.Blue, { studs = K.ALL })
	local X0, X1, Z, Y0, Y1 = -244, -124, 66, 12, 96
	local xc = (X0 + X1) / 2
	K.masonry(f, "Stone", CFrame.new(xc, Y0, 0), Vector3.new(X1 - X0, Y1 - Y0, 2 * Z), rng, { t0 = 0, t1 = 0.34, courseMin = 6, courseMax = 10, stoneMin = 14, stoneMax = 34 })
	local F1 = face(X1, 0, 0, EAST)

	---------------------------------------------------------------- the facade
	-- half-towers either side, standing out 14 from the front and rising past tier 1's battlements
	for _, s in { -1, 1 } do
		local hz = s * 34
		local hx0, hx1 = X1, X1 + 14
		local hxc = (hx0 + hx1) / 2
		K.box(f, "Footing", hx0, hx1 + 1.5, -10, 4, hz - 9.5, hz + 9.5, P.Base, { studs = K.SIDES })
		K.masonry(f, "Stone", CFrame.new(hxc, 0, hz), Vector3.new(14, 114, 16), rng, { t0 = 0, t1 = 0.42, courseMin = 6, courseMax = 9, stoneMin = 8, stoneMax = 16 })
		local hF = face(hx1, 0, hz, EAST)
		K.eggRelief(f, hF, 0, 14, 5, P.Light, P.Gold)
		K.slit(f, hF, 0, 34, 2, 9, rng)
		K.torch(f, hF, 0, 52)
		K.banner(f, CFrame.lookAt(Vector3.new(hx1 + 0.8, 104, hz), Vector3.new(hx1 + 20, 104, hz)), 9, 38,
			s > 0 and { cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold }
				or { cloth = P.Red, trim = P.Gold, emblem = "egg", mark = P.Gold, tail = "point" })
		K.weather(f, hF, 16, 114, rng, { moss = 2, vines = 1, vineTop = 112, cracks = 1, holes = 0, yMin = 4 })
		K.box(f, "Corbel", hx0 - 1, hx1 + 1.5, 114, 117, hz - 9.5, hz + 9.5, P.Light, { studs = K.ALLB })
		K.merlonRect(f, hxc + 0.25, hz, 8.25, 9.5, 117, 3, 4.5, 2.2, rng, 0.98)
		local top = K.spire(f, hxc, hz, 117, 10, 12, 26, 7, P.Red)
		K.egg(f, Vector3.new(hxc, top, hz), 3, P.Gold, P.Red)
	end
	-- the recessed main entrance: two piers standing out 10 from the front, a stepped arch with tan voussoirs, the
	-- iron-banded doors set back on the keep's face in deep shadow, a landing and steps down to the courtyard
	local PX0, PX1 = X1, X1 + 10
	local pxc = (PX0 + PX1) / 2
	for _, s in { -1, 1 } do
		K.masonry(f, "Stone", CFrame.new(pxc, 0, s * 16.5), Vector3.new(10, 54, 7), rng, { t0 = 0, t1 = 0.3, courseMin = 6, courseMax = 8, stoneMin = 6, stoneMax = 10 })
		K.eggRelief(f, face(PX1, 0, s * 16.5, EAST), 0, 20, 4, P.Light, P.Gold)
	end
	local arch = { { 10.5, 42 }, { 7.5, 46 }, { 4, 50 } } -- { half-width of the opening above, bottom }
	local prev = 13
	for _, st in arch do
		for _, s in { -1, 1 } do
			K.box(f, "Arch", PX0, PX1, st[2], 54, s * st[1], s * prev, K.stone(Vector3.new(pxc, st[2], s * prev), 0.3, rng), { studs = K.ALLB })
			K.box(f, "Voussoir", PX1, PX1 + 0.8, st[2], st[2] + 1.2, s * st[1], s * prev, P.Tan, { studs = K.ALLB, solid = false })
		end
		prev = st[1]
	end
	K.box(f, "Voussoir", PX1, PX1 + 0.8, 54, 55.2, -4, 4, P.Tan, { studs = K.ALLB, solid = false })
	K.masonry(f, "Stone", CFrame.new(pxc, 54, 0), Vector3.new(10, 8, 40), rng, { t0 = 0.3, t1 = 0.34, axis = "Z", courseMin = 8, courseMax = 8, stoneMin = 8, stoneMax = 16 })
	K.box(f, "Keystone", PX1, PX1 + 1.4, 53, 60, -2.5, 2.5, P.Tan, { studs = K.ALL, solid = false })
	K.box(f, "DoorShadow", X1, X1 + 0.15, 42, 54, -13, 13, P.Socket, { solid = false, shadow = false })
	for _, s in { -1, 1 } do
		K.gateLeaf(f, face(X1, 12, s * 6.5, EAST), 13, 30)
	end
	K.box(f, "Landing", X1, PX1, 0, 12, -13, 13, P.Mid, { studs = K.ALL })
	for i = 0, 3 do
		K.box(f, "Step", PX1 + i * 3, PX1 + (i + 1) * 3, 0, 12 - i * 3, -16, 16, i % 2 == 0 and P.Light or P.Mid, { studs = K.ALL })
	end
	-- the balcony over the entrance: a slab on corbels, a low balustrade with a tan rail, a glowing doorway behind
	K.box(f, "Balcony", X1, X1 + 16, 62, 64.5, -18, 18, P.Light, { studs = K.ALLB })
	K.corbels(f, Vector3.new(PX1, 0, -14), Vector3.new(PX1, 0, 14), 62, EAST, 7, rng, 0.35)
	K.box(f, "Balustrade", X1 + 14.4, X1 + 16, 64.5, 68, -18, 18, P.Light, { studs = K.SIDES })
	K.box(f, "Rail", X1 + 14.2, X1 + 16.2, 68, 68.8, -18.2, 18.2, P.Tan, { studs = K.TOP, solid = false })
	for _, s in { -1, 1 } do
		K.box(f, "Balustrade", X1, X1 + 14.4, 64.5, 68, s * 16.4, s * 18, P.Light, { studs = K.SIDES })
		K.box(f, "Rail", X1, X1 + 14.2, 68, 68.8, s * 16.2, s * 18.2, P.Tan, { studs = K.TOP, solid = false })
	end
	K.window(f, F1, 0, 64.5, 9, 22, true)
	K.accents(f, F1, 2 * Z, Y1, 10, rng, 0, 0.34, { yMin = 14 })
	K.weather(f, F1, 2 * Z, Y1, rng, { moss = 6, mossY = 12, vines = 3, vineTop = Y1 - 2, cracks = 2, holes = 1, yMin = 14 })
	for _, s in { -1, 1 } do
		local sF = face(xc, 0, s * Z, Vector3.new(0, 0, s))
		for _, wx in { -214, -184, -154 } do
			K.slit(f, sF, K.lx(sF, wx, s * Z), 56, 2, 10, rng)
		end
		K.accents(f, sF, 84, Y1, 8, rng, 0, 0.34, { yMin = 14 })
		K.weather(f, sF, 84, Y1, rng, { moss = 4, mossY = 12, vines = 2, vineTop = Y1 - 2, cracks = 1, holes = 1, yMin = 14 })
	end
	-- tier 1 roof: machicolated parapet, battlements, braziers
	K.masonry(f, "Parapet", CFrame.new(xc, Y1, 0), Vector3.new(X1 - X0 + 6, 5, 2 * Z + 6), rng, { t0 = 0.36, t1 = 0.37, courseMin = 6, courseMax = 6, stoneMin = 16, stoneMax = 30, topStuds = true })
	K.corbels(f, Vector3.new(X1, 0, -46), Vector3.new(X1, 0, 46), Y1, EAST, 6, rng, 0.36)
	K.merlonRect(f, xc, 0, (X1 - X0) / 2 + 3, Z + 3, Y1 + 5, 3.5, 5.5, 2.5, rng, 0.4)
	for _, s in { -1, 1 } do
		K.brazier(f, Vector3.new(X1 - 4, Y1 + 5, s * 12), 1.25)
	end

	---------------------------------------------------------------- the four corner towers
	local corners = {
		{ X1, Z, { EAST, NORTH } },
		{ X1, -Z, { EAST, SOUTH } },
		{ X0, Z, { WEST, NORTH } },
		{ X0, -Z, { WEST, SOUTH } },
	}
	for i, c in corners do
		K.crossTower(f, c[1], c[2], 34, 160, rng, {
			name = "CornerTower",
			t0 = 0,
			t1 = 0.85,
			windows = c[3],
			glow = i <= 2,
			roofH = 70,
			roofN = 12,
			trim = P.Red,
			egg = 5,
			flag = i % 2 == 0 and P.Navy or P.Red,
		})
	end

	---------------------------------------------------------------- tier 2
	local A0, A1, AZ, AY0, AY1 = -232, -134, 52, Y1 + 5, 176
	local axc = (A0 + A1) / 2
	K.masonry(f, "Stone", CFrame.new(axc, AY0, 0), Vector3.new(A1 - A0, AY1 - AY0, 2 * AZ), rng, { t0 = 0.38, t1 = 0.62, courseMin = 6, courseMax = 9, stoneMin = 14, stoneMax = 30 })
	local F2 = face(A1, 0, 0, EAST)
	-- the citadel's crest: a golden kaiju head on a deep red shield, high enough to clear the Rewards board from the spawn
	K.crest(f, CFrame.lookAt(Vector3.new(A1, 140, 0), Vector3.new(A1 + 20, 140, 0)), 1.3)
	for _, wz in { -28, 28 } do
		K.window(f, F2, K.lx(F2, A1, wz), 128, 7, 24, true)
	end
	K.banner(f, CFrame.lookAt(Vector3.new(A1 + 0.8, 172, 42), Vector3.new(A1 + 20, 172, 42)), 9, 44, { cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold })
	K.banner(f, CFrame.lookAt(Vector3.new(A1 + 0.8, 172, -42), Vector3.new(A1 + 20, 172, -42)), 9, 44, { cloth = P.Navy, trim = P.Red, emblem = "egg", mark = P.Gold, tail = "point" })
	K.accents(f, F2, 2 * AZ, AY1 - AY0, 8, rng, 0.38, 0.62)
	K.weather(f, face(A1, AY0, 0, EAST), 2 * AZ, AY1 - AY0, rng, { moss = 2, vines = 2, cracks = 1, holes = 1 })
	for _, s in { -1, 1 } do
		local sF = face(axc, AY0, s * AZ, Vector3.new(0, 0, s))
		for _, wx in { -210, -156 } do
			K.window(f, sF, K.lx(sF, wx, s * AZ), 24, 6, 20, true)
		end
		K.weather(f, sF, A1 - A0, AY1 - AY0, rng, { moss = 2, vines = 2, cracks = 1, holes = 1 })
	end
	K.masonry(f, "Parapet", CFrame.new(axc, AY1, 0), Vector3.new(A1 - A0 + 6, 5, 2 * AZ + 6), rng, { t0 = 0.64, t1 = 0.65, courseMin = 6, courseMax = 6, stoneMin = 16, stoneMax = 30, topStuds = true })
	K.corbels(f, Vector3.new(A1, 0, -49), Vector3.new(A1, 0, 49), AY1, EAST, 6, rng, 0.64)
	K.merlonRect(f, axc, 0, (A1 - A0) / 2 + 3, AZ + 3, AY1 + 5, 3.5, 5, 2.5, rng, 0.66)
	for _, cx in { A0 - 1, A1 + 1 } do
		for _, s in { -1, 1 } do
			K.bartizan(f, Vector3.new(cx, AY1 - 12, s * (AZ + 1)), rng, { w = 10, h = 26, roofH = 22, trim = P.Red })
		end
	end
	for _, s in { -1, 1 } do
		K.brazier(f, Vector3.new(A1 - 4, AY1 + 5, s * 34), 1.15)
	end

	---------------------------------------------------------------- tier 3
	local B0, B1, BZ, BY0, BY1 = -216, -150, 36, AY1 + 5, 244
	local bxc = (B0 + B1) / 2
	K.masonry(f, "Stone", CFrame.new(bxc, BY0, 0), Vector3.new(B1 - B0, BY1 - BY0, 2 * BZ), rng, { t0 = 0.66, t1 = 0.84, courseMin = 6, courseMax = 8, stoneMin = 12, stoneMax = 26 })
	local F3 = face(B1, BY0, 0, EAST)
	K.banner(f, CFrame.lookAt(Vector3.new(B1 + 0.8, BY1 - 3, 0), Vector3.new(B1 + 20, BY1 - 3, 0)), 15, 40, { cloth = P.Red, trim = P.Gold, emblem = "skull", mark = P.Bone })
	for _, wz in { -22, 22 } do
		K.window(f, F3, K.lx(F3, B1, wz), 14, 6, 20, true)
	end
	K.accents(f, F3, 2 * BZ, BY1 - BY0, 6, rng, 0.66, 0.84)
	for _, s in { -1, 1 } do
		local sF = face(bxc, BY0, s * BZ, Vector3.new(0, 0, s))
		for _, wx in { -196, -170 } do
			K.window(f, sF, K.lx(sF, wx, s * BZ), 16, 5, 18, true)
		end
		K.weather(f, sF, B1 - B0, BY1 - BY0, rng, { moss = 0, vines = 1, cracks = 1, holes = 0 })
	end
	K.masonry(f, "Parapet", CFrame.new(bxc, BY1, 0), Vector3.new(B1 - B0 + 6, 5, 2 * BZ + 6), rng, { t0 = 0.86, t1 = 0.87, courseMin = 6, courseMax = 6, stoneMin = 14, stoneMax = 26, topStuds = true })
	K.corbels(f, Vector3.new(B1, 0, -33), Vector3.new(B1, 0, 33), BY1, EAST, 6, rng, 0.86)
	K.merlonRect(f, bxc, 0, (B1 - B0) / 2 + 3, BZ + 3, BY1 + 5, 3.5, 5, 2.5, rng, 0.88)

	---------------------------------------------------------------- tier 4: the spire tower
	local C0, C1, CZ, CY0, CY1 = -200, -166, 17, BY1 + 5, 306
	local cxc = (C0 + C1) / 2
	K.masonry(f, "Stone", CFrame.new(cxc, CY0, 0), Vector3.new(C1 - C0, CY1 - CY0, 2 * CZ), rng, { t0 = 0.88, t1 = 1, courseMin = 6, courseMax = 8, stoneMin = 10, stoneMax = 20 })
	for _, n in { EAST, WEST, NORTH, SOUTH } do
		local F = face(cxc + n.X * 17, CY0, n.Z * 17, n)
		for _, wx in { -7.5, 7.5 } do
			K.window(f, F, wx, 18, 5, 20, true)
		end
	end
	K.box(f, "Corbel", C0 - 3, C1 + 3, CY1, CY1 + 3, -CZ - 3, CZ + 3, P.Light, { studs = K.ALLB })
	K.merlonRect(f, cxc, 0, 20, 20, CY1 + 3, 3, 4.5, 2.4, rng, 1)
	local top = K.spire(f, cxc, 0, CY1 + 3, 36, 36, 82, 13, P.Gold)
	local _, eggTop = K.egg(f, Vector3.new(cxc, top, 0), 9, P.Gold, P.Red)
	K.flagPole(f, Vector3.new(cxc, eggTop, 0), 26, 20, 12, P.Red, P.Gold)
	return f
end
