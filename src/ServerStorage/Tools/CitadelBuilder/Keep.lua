-- The Kaiju Keep, built by CitadelBuilder section "Keep": the citadel's landmark at the far (west) end of the avenue,
-- straight behind the Hall of Champions and on the line through the Grand Gate, so it closes the view down the avenue
-- and is the first thing seen when coming home from the Wildlands. Four tiers of irregular studded masonry, four
-- corner towers with pointed roofs, corner turrets, glowing windows, banners, braziers and the tallest spire in the
-- citadel (golden egg finial at about y 334). Footprint x -242..-109, z -71..71: outside the old west wall line,
-- clear of the plots, the market and the leaderboards (which stay exactly where they are).
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
	K.box(f, "Footing", -242, -120, -40, 6, -62, 62, P.Base, { studs = K.SIDES })
	K.box(f, "Footing", -240, -122, 6, 12, -60, 60, P.BaseWarm, { studs = K.ALL })
	local X0, X1, Z = -236, -124, 56
	local xc = (X0 + X1) / 2
	K.masonry(f, "Stone", CFrame.new(xc, 12, 0), Vector3.new(X1 - X0, 66, 2 * Z), rng, { t0 = 0, t1 = 0.55, courseMin = 6, courseMax = 10, stoneMin = 14, stoneMax = 34 })
	local F1 = face(X1, 0, 0, EAST)
	-- front buttresses carrying torches and carved eggs
	for _, bz in { -22, 22 } do
		K.box(f, "Buttress", X1, X1 + 6, 12, 56, bz - 3, bz + 3, K.tone(rng, 0.1), { studs = K.ALL })
		K.box(f, "Buttress", X1, X1 + 4, 56, 72, bz - 2.5, bz + 2.5, K.tone(rng, 0.4), { studs = K.ALL })
		K.box(f, "Buttress", X1, X1 + 2, 72, 76, bz - 2, bz + 2, K.tone(rng, 0.6), { studs = K.ALL })
		local bF = face(X1 + 6, 0, bz, EAST)
		K.eggRelief(f, bF, 0, 18, 4.6, P.Tan, P.Gold)
		K.torch(f, bF, 0, 40)
	end
	K.window(f, F1, 0, 58, 8, 16, true)
	for _, wz in { -31.5, 31.5 } do
		K.window(f, F1, K.lx(F1, X1, wz), 44, 6, 16, true)
	end
	K.accents(f, F1, 2 * Z, 66, 12, rng, 0, 0.55, { yMin = 14 })
	K.weather(f, F1, 2 * Z, 78, rng, { moss = 6, mossY = 12, vines = 3, vineTop = 76, cracks = 2, holes = 1, yMin = 14 })
	for _, s in { -1, 1 } do
		local sF = face(xc, 0, s * Z, Vector3.new(0, 0, s))
		for _, wx in { -200, -180, -160 } do
			K.slit(f, sF, K.lx(sF, wx, s * Z), 46, 2, 9, rng)
		end
		K.accents(f, sF, 80, 66, 8, rng, 0, 0.55, { yMin = 14 })
		K.weather(f, sF, 80, 78, rng, { moss = 4, mossY = 12, vines = 2, vineTop = 76, cracks = 1, holes = 1, yMin = 14 })
	end
	-- tier 1 roof: machicolated parapet, battlements
	K.masonry(f, "Parapet", CFrame.new(xc, 78, 0), Vector3.new(X1 - X0 + 6, 5, 2 * Z + 6), rng, { t0 = 0.6, t1 = 0.62, courseMin = 6, courseMax = 6, stoneMin = 16, stoneMax = 30, topStuds = true })
	K.corbels(f, Vector3.new(X1, 0, -38), Vector3.new(X1, 0, 38), 78, EAST, 6, rng)
	K.merlonRect(f, xc, 0, (X1 - X0) / 2 + 3, Z + 3, 83, 3.5, 5, 2.5, rng, 0.65)
	for _, s in { -1, 1 } do
		K.brazier(f, Vector3.new(X1 - 4, 83, s * 34), 1.2)
	end

	---------------------------------------------------------------- the four corner towers
	local corners = {
		{ X1, Z, { EAST, NORTH } },
		{ X1, -Z, { EAST, SOUTH } },
		{ X0, Z, { WEST, NORTH } },
		{ X0, -Z, { WEST, SOUTH } },
	}
	for i, c in corners do
		K.crossTower(f, c[1], c[2], 30, 132, rng, {
			name = "CornerTower",
			t0 = 0,
			t1 = 0.8,
			windows = c[3],
			glow = i <= 2,
			roofH = 62,
			roofN = 11,
			egg = 4.5,
			flag = i % 2 == 0 and P.Navy or P.Red,
		})
	end

	---------------------------------------------------------------- tier 2
	local A0, A1, AZ, AY0, AY1 = -226, -134, 44, 83, 142
	local axc = (A0 + A1) / 2
	K.masonry(f, "Stone", CFrame.new(axc, AY0, 0), Vector3.new(A1 - A0, AY1 - AY0, 2 * AZ), rng, { t0 = 0.35, t1 = 0.78, courseMin = 6, courseMax = 9, stoneMin = 14, stoneMax = 30 })
	local F2 = face(A1, 0, 0, EAST)
	-- the plaque sits high enough to clear tier 1's battlements when seen from the avenue
	K.sign(f, "HallPlaque", CFrame.lookAt(Vector3.new(A1 + 0.6, 98, 0), Vector3.new(A1 + 20, 98, 0)), 46, 8.5, "HALL OF CHAMPIONS")
	for _, wz in { -24, 0, 24 } do
		K.window(f, F2, K.lx(F2, A1, wz), 108, 7, 22, true)
	end
	K.banner(f, CFrame.lookAt(Vector3.new(A1 + 0.8, 138, 38), Vector3.new(A1 + 20, 138, 38)), 9, 42, { cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold })
	K.banner(f, CFrame.lookAt(Vector3.new(A1 + 0.8, 138, -38), Vector3.new(A1 + 20, 138, -38)), 9, 42, { cloth = P.Navy, trim = P.Bronze, emblem = "egg", mark = P.Gold, tail = "point" })
	K.accents(f, F2, 2 * AZ, AY1 - AY0, 10, rng, 0.35, 0.78)
	K.weather(f, face(A1, AY0, 0, EAST), 2 * AZ, AY1 - AY0, rng, { moss = 2, vines = 2, cracks = 1, holes = 1 })
	for _, s in { -1, 1 } do
		local sF = face(axc, AY0, s * AZ, Vector3.new(0, 0, s))
		for _, wx in { -200, -160 } do
			K.window(f, sF, K.lx(sF, wx, s * AZ), 18, 6, 18, true)
		end
		K.weather(f, sF, A1 - A0, AY1 - AY0, rng, { moss = 2, vines = 2, cracks = 1, holes = 1 })
	end
	K.masonry(f, "Parapet", CFrame.new(axc, AY1, 0), Vector3.new(A1 - A0 + 6, 5, 2 * AZ + 6), rng, { t0 = 0.8, t1 = 0.82, courseMin = 6, courseMax = 6, stoneMin = 16, stoneMax = 30, topStuds = true })
	K.corbels(f, Vector3.new(A1, 0, -41), Vector3.new(A1, 0, 41), AY1, EAST, 6, rng)
	K.merlonRect(f, axc, 0, (A1 - A0) / 2 + 3, AZ + 3, AY1 + 5, 3.5, 5, 2.5, rng, 0.85)
	for _, cx in { A0 - 1, A1 + 1 } do
		for _, s in { -1, 1 } do
			K.bartizan(f, Vector3.new(cx, AY1 - 12, s * (AZ + 1)), rng, { w = 9, h = 24, roofH = 20 })
		end
	end
	for _, s in { -1, 1 } do
		K.brazier(f, Vector3.new(A1 - 4, AY1 + 5, s * 30), 1.15)
	end

	---------------------------------------------------------------- tier 3
	local B0, B1, BZ, BY0, BY1 = -212, -148, 32, AY1 + 5, 198
	local bxc = (B0 + B1) / 2
	K.masonry(f, "Stone", CFrame.new(bxc, BY0, 0), Vector3.new(B1 - B0, BY1 - BY0, 2 * BZ), rng, { t0 = 0.6, t1 = 0.92, courseMin = 6, courseMax = 8, stoneMin = 12, stoneMax = 26 })
	local F3 = face(B1, BY0, 0, EAST)
	K.banner(f, CFrame.lookAt(Vector3.new(B1 + 0.8, BY1 - 3, 0), Vector3.new(B1 + 20, BY1 - 3, 0)), 14, 36, { cloth = P.RedDark, trim = P.Gold, emblem = "skull", mark = P.Bone })
	for _, wz in { -20, 20 } do
		K.window(f, F3, K.lx(F3, B1, wz), 12, 6, 18, true)
	end
	K.accents(f, F3, 2 * BZ, BY1 - BY0, 6, rng, 0.6, 0.92)
	for _, s in { -1, 1 } do
		local sF = face(bxc, BY0, s * BZ, Vector3.new(0, 0, s))
		for _, wx in { -192, -168 } do
			K.window(f, sF, K.lx(sF, wx, s * BZ), 14, 5, 16, true)
		end
		K.weather(f, sF, B1 - B0, BY1 - BY0, rng, { moss = 0, vines = 1, cracks = 1, holes = 0 })
	end
	K.masonry(f, "Parapet", CFrame.new(bxc, BY1, 0), Vector3.new(B1 - B0 + 6, 5, 2 * BZ + 6), rng, { t0 = 0.94, t1 = 0.95, courseMin = 6, courseMax = 6, stoneMin = 14, stoneMax = 26, topStuds = true })
	K.corbels(f, Vector3.new(B1, 0, -29), Vector3.new(B1, 0, 29), BY1, EAST, 6, rng)
	K.merlonRect(f, bxc, 0, (B1 - B0) / 2 + 3, BZ + 3, BY1 + 5, 3.5, 5, 2.5, rng, 0.95)

	---------------------------------------------------------------- tier 4: the spire tower
	local C0, C1, CZ, CY0, CY1 = -196, -164, 16, BY1 + 5, 252
	local cxc = (C0 + C1) / 2
	K.masonry(f, "Stone", CFrame.new(cxc, CY0, 0), Vector3.new(C1 - C0, CY1 - CY0, 2 * CZ), rng, { t0 = 0.8, t1 = 1, courseMin = 6, courseMax = 8, stoneMin = 10, stoneMax = 20 })
	for _, n in { EAST, WEST, NORTH, SOUTH } do
		local F = face(cxc + n.X * 16, CY0, n.Z * 16, n)
		for _, wx in { -7, 7 } do
			K.window(f, F, wx, 16, 5, 18, true)
		end
	end
	K.box(f, "Corbel", C0 - 3, C1 + 3, CY1, CY1 + 3, -CZ - 3, CZ + 3, K.tone(rng, 0.98), { studs = K.ALLB })
	K.merlonRect(f, cxc, 0, 19, 19, CY1 + 3, 3, 4.5, 2.4, rng, 1)
	local top = K.spire(f, cxc, 0, CY1 + 3, 34, 34, 74, 12, P.Gold)
	local _, eggTop = K.egg(f, Vector3.new(cxc, top, 0), 8, P.Gold, P.Red)
	K.flagPole(f, Vector3.new(cxc, eggTop, 0), 24, 18, 11, P.Red, P.Gold)
	return f
end
