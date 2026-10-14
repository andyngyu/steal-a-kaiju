-- The citadel's curtain walls and towers (CitadelBuilder sections "Walls" and "Towers"), at the Grand Gate's scale and
-- in the same kit: patch stone with a dark blue-grey foot, tan trim (merlon caps, sills, window frames, parapet rail),
-- deep red and navy banners, torches with real fire.
--   Walls   98 tall and 16 thick (the old ones were 45 and 8), grown outwards so the courtyard is unchanged: inner faces
--           at z +-158, x -116 (west) and x 292 (east; the plots end at x 288). Inner face: pilasters with torches, a
--           string course, banners and arrow loops in alternate bays, moss, vines and carved cracks; a wall-walk with a
--           low inner parapet and capped battlements on the outer edge. Outer face: two-stage buttresses and claw gouges.
--   Towers  four massive cross-plan corner towers (150 tall, 78-tall roofs), eight medium square towers along the walls
--           (118-134 tall, 54-tall roofs, all different heights) and ten small corbelled turrets on the walls' inner edge.
-- The walls run into the Keep's front corner towers (z +-83) and the Grand Gate's towers (z +-115).
local M = {}

local WH = 98 -- wall-walk height
local WT = 16 -- wall thickness

local function designs(P)
	return {
		{ cloth = P.Red, trim = P.Gold, emblem = "claw", mark = P.Gold },
		{ cloth = P.Navy, trim = P.Red, emblem = "egg", mark = P.Gold, tail = "point" },
		{ cloth = P.Red, trim = P.Gold, emblem = "skull", mark = P.Bone },
		{ cloth = P.Navy, trim = P.Gold, emblem = "chevron", mark = P.Gold },
		{ cloth = P.Red, trim = P.Bronze, emblem = "diamond", mark = P.Gold, tail = "point" },
	}
end

-- one straight curtain wall on the centre line a -> b (ground level); inward = unit vector towards the courtyard
local function wall(f, K, rng, name, a, b, inward, o)
	o = o or {}
	local P = K.P
	local D = designs(P)
	local m = K.model(f, name)
	local L = (b - a).Magnitude
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(mid, mid - inward) -- local +Z faces the courtyard, local X runs along the wall
	local function W(x, y, z)
		return frame:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function lp(nm, size, pos, color, opt)
		return K.part(m, nm, size, frame * CFrame.new(pos), color, opt)
	end
	local inF = K.face(W(0, 0, WT / 2), inward)
	local outF = K.face(W(0, 0, -WT / 2), -inward)
	-- footing and the masonry body (stones run along the wall)
	lp("Footing", Vector3.new(L, 10, WT + 3), Vector3.new(0, -4, 0), P.Base, { studs = K.SIDES })
	K.masonry(m, "Stone", frame, Vector3.new(L, WH, WT), rng, { t0 = 0, t1 = 0.92, axis = "X", courseMin = 8, courseMax = 12, stoneMin = 16, stoneMax = 36, faces = { K.N.Front, K.N.Back }, topStuds = true })
	lp("Course", Vector3.new(L, 2.4, 1.2), Vector3.new(0, 63.2, WT / 2 + 0.6), P.Mid, { studs = { K.N.Back, K.N.Top }, solid = false })
	-- inner face: pilasters (torches on every other one), then banners or arrow loops in alternate bays
	local bays = math.max(1, math.floor(L / 42 + 0.5))
	local bay = L / bays
	for i = 1, bays - 1 do
		local x = -L / 2 + i * bay
		local at = W(x, 46, WT / 2 + 0.9)
		lp("Pilaster", Vector3.new(5, 92, 1.8), Vector3.new(x, 46, WT / 2 + 0.9), K.stone(at, 0.4, rng), { studs = { K.N.Back, K.N.Left, K.N.Right } })
		if i % 2 == 1 then
			K.torch(m, K.face(W(x, 0, WT / 2 + 1.8), inward), 0, 24)
		end
	end
	local k = o.phase or 0
	for i = 0, bays - 1 do
		local x = -L / 2 + (i + 0.5) * bay
		if (i + (o.phase or 0)) % 2 == 0 then
			k += 1
			local top = W(x, WH - 5, WT / 2 + 1.4)
			K.banner(m, CFrame.lookAt(top, top + inward), 10, 40, D[(k - 1) % #D + 1])
		else
			for _, dx in { -6, 6 } do
				local p = W(x + dx, 0, WT / 2)
				K.slit(m, inF, K.lx(inF, p.X, p.Z), 76, 2, 9, rng)
			end
		end
	end
	K.accents(m, inF, L, WH, math.floor(L / 18), rng, 0, 0.92, { yMin = 4 })
	K.weather(m, inF, L, WH, rng, { moss = math.floor(L / 16), vines = math.max(1, math.floor(L / 100)), vineTop = WH - 1, cracks = math.max(1, math.floor(L / 140)), holes = math.max(1, math.floor(L / 200)), yMin = 4 })
	-- the wall-walk: low inner parapet with a tan rail, capped battlements along the outer edge
	lp("WalkParapet", Vector3.new(L, 3, 1.6), Vector3.new(0, WH + 1.5, WT / 2 - 0.8), P.Light, { studs = K.SIDES })
	lp("WalkRail", Vector3.new(L, 0.7, 2), Vector3.new(0, WH + 3.35, WT / 2 - 0.8), P.Tan, { studs = K.TOP, solid = false })
	K.merlonLine(m, W(-L / 2, 0, -WT / 2 + 1.6), W(L / 2, 0, -WT / 2 + 1.6), WH, 4.5, 6.5, 3.2, rng, 4.5, 0.95)
	-- outer face: two-stage buttresses between the bays, claw gouges, moss and vines
	for i = 0, bays - 1 do
		local x = -L / 2 + (i + 0.5) * bay
		lp("Buttress", Vector3.new(8, 60, 9), Vector3.new(x, 30, -WT / 2 - 4.5), K.stone(W(x, 30, -WT / 2), 0.25, rng), { studs = K.ALL })
		lp("Buttress", Vector3.new(6, 32, 5), Vector3.new(x, 76, -WT / 2 - 2.5), K.stone(W(x, 76, -WT / 2), 0.7, rng), { studs = K.ALL })
		lp("Buttress", Vector3.new(5, 4, 2.4), Vector3.new(x, 94, -WT / 2 - 1.2), P.Light, { studs = K.ALL })
	end
	for j = 1, (o.claws or 0) do
		local x = -L / 2 + (math.floor((j - 0.5) * bays / o.claws) + 1) * bay -- on a pilaster line, clear of the buttresses
		local p = W(x, 0, -WT / 2)
		K.claws(m, outF, K.lx(outF, p.X, p.Z), 62, 44, rng)
	end
	K.weather(m, outF, L, WH, rng, { moss = math.floor(L / 30), vines = math.max(1, math.floor(L / 140)), vineTop = WH - 1, cracks = 1, holes = 1, yMin = 4 })
	return m
end

function M.Walls(root, map, ctx, K)
	local f = K.model(root, "Walls")
	local rng = Random.new(1660)
	local X, Z = Vector3.xAxis, Vector3.zAxis
	wall(f, K, rng, "WallNorth", Vector3.new(-124, 0, 166), Vector3.new(300, 0, 166), -Z, { phase = 0, claws = 2 })
	wall(f, K, rng, "WallSouth", Vector3.new(-124, 0, -166), Vector3.new(300, 0, -166), Z, { phase = 1, claws = 2 })
	wall(f, K, rng, "WallWestN", Vector3.new(-124, 0, 82), Vector3.new(-124, 0, 166), X, { phase = 0, claws = 1 })
	wall(f, K, rng, "WallWestS", Vector3.new(-124, 0, -166), Vector3.new(-124, 0, -82), X, { phase = 1, claws = 1 })
	wall(f, K, rng, "WallEastN", Vector3.new(300, 0, 115), Vector3.new(300, 0, 166), -X, { phase = 0 })
	wall(f, K, rng, "WallEastS", Vector3.new(300, 0, -166), Vector3.new(300, 0, -115), -X, { phase = 1 })
	return f
end

-- a medium square tower on the wall line, its window face turned to the courtyard
local function mediumTower(f, K, rng, cx, cz, H, inward, n)
	local P = K.P
	local D = designs(P)
	local m = K.model(f, "Tower")
	local S = 30
	K.box(m, "Footing", cx - S / 2 - 1.5, cx + S / 2 + 1.5, -10, 6, cz - S / 2 - 1.5, cz + S / 2 + 1.5, P.Base, { studs = K.SIDES })
	K.masonry(m, "Stone", CFrame.new(cx, 6, cz), Vector3.new(S, H - 6, S), rng, { t0 = 0.04, t1 = 0.92, courseMin = 8, courseMax = 10, stoneMin = 12, stoneMax = 24 })
	local by = math.floor(H * 0.45)
	K.box(m, "Band", cx - S / 2 - 0.7, cx + S / 2 + 0.7, by, by + 2.4, cz - S / 2 - 0.7, cz + S / 2 + 0.7, P.Mid, { studs = K.SIDES, solid = false })
	local inF = K.face(Vector3.new(cx + inward.X * S / 2, 0, cz + inward.Z * S / 2), inward)
	K.window(m, inF, 0, H * 0.6, 5, 15, true)
	K.window(m, inF, 0, H * 0.8, 4, 12, true)
	local bt = Vector3.new(cx, by - 2, cz) + inward * (S / 2 + 1.4)
	K.banner(m, CFrame.lookAt(bt, bt + inward), 9, H * 0.26, D[(n - 1) % #D + 1])
	local along = Vector3.new(inward.Z, 0, -inward.X)
	for _, sg in { -1, 1 } do
		local nrm = along * sg
		K.slit(m, K.face(Vector3.new(cx + nrm.X * S / 2, 0, cz + nrm.Z * S / 2), nrm), 0, H * 0.55, 2, 9, rng)
	end
	K.weather(m, inF, S, H, rng, { moss = 2, vines = 1, vineTop = H - 1, cracks = 1, holes = 0, yMin = 6 })
	local c0 = Vector3.new(cx, 0, cz) + inward * (S / 2) - along * (S / 2 - 2)
	local c1 = Vector3.new(cx, 0, cz) + inward * (S / 2) + along * (S / 2 - 2)
	K.corbels(m, c0, c1, H, inward, 5, rng)
	K.masonry(m, "Parapet", CFrame.new(cx, H, cz), Vector3.new(S + 5, 6, S + 5), rng, { t0 = 0.95, t1 = 0.97, courseMin = 6, courseMax = 6, stoneMin = 12, stoneMax = 22, topStuds = true })
	K.merlonRect(m, cx, cz, (S + 5) / 2, (S + 5) / 2, H + 6, 3.5, 5.5, 2.5, rng, 0.97)
	local top = K.spire(m, cx, cz, H + 6, S - 2, S - 2, 54, 10, n % 2 == 0 and P.Red or P.Bronze)
	local _, eggTop = K.egg(m, Vector3.new(cx, top, cz), 4.5, P.Gold, P.Red)
	K.flagPole(m, Vector3.new(cx, eggTop, cz), 16, 10, 6, n % 2 == 0 and P.Navy or P.Red, P.Gold)
	return m
end

function M.Towers(root, map, ctx, K)
	local P = K.P
	local f = K.model(root, "Towers")
	local rng = Random.new(1661)
	local X, Z = Vector3.xAxis, Vector3.zAxis
	-- the four massive corner towers
	local corners = {
		{ -124, 166, { X, -Z } },
		{ -124, -166, { X, Z } },
		{ 300, 166, { -X, -Z } },
		{ 300, -166, { -X, Z } },
	}
	for i, c in corners do
		K.crossTower(f, c[1], c[2], 44, 150, rng, {
			name = "CornerTower",
			t0 = 0,
			t1 = 0.9,
			windows = c[3],
			glow = true,
			roofH = 78,
			roofN = 13,
			trim = i % 2 == 0 and P.Red or P.Bronze,
			egg = 6,
			flag = i % 2 == 0 and P.Navy or P.Red,
		})
	end
	-- medium towers along the walls, each a different height
	local medium = {
		{ -20, 166, 122, -Z },
		{ 90, 166, 134, -Z },
		{ 195, 166, 126, -Z },
		{ -20, -166, 128, Z },
		{ 90, -166, 118, Z },
		{ 195, -166, 132, Z },
		{ -124, 124, 120, X },
		{ -124, -124, 124, X },
	}
	for n, t in medium do
		mediumTower(f, K, rng, t[1], t[2], t[3], t[4], n)
	end
	-- small corbelled turrets on the walls' inner edge, between the towers
	local turrets = {
		{ -72, 158, -Z }, { 35, 158, -Z }, { 142, 158, -Z }, { 247, 158, -Z },
		{ -72, -158, Z }, { 35, -158, Z }, { 142, -158, Z }, { 247, -158, Z },
		{ -116, 103, X }, { -116, -103, X },
	}
	for i, t in turrets do
		local at = Vector3.new(t[1], WH - 14, t[2]) + t[3] * 2.5
		K.bartizan(f, at, rng, { w = 10, h = 26, roofH = 22, trim = i % 2 == 0 and P.Red or P.Bronze })
	end
	return f
end

return M
