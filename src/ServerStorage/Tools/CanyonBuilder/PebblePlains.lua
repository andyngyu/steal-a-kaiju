-- Pebble Plains, refined (CanyonBuilder section "Refine"). Rebuilds the biome's open ground past the Grand Gate tunnel
-- (x 350..452) in place, keeping its contracts: Zone (now 170 wide), NestSite, Sign, Decor's NestSign, the old floor
-- inside the tunnel.
--   Ground     grass in irregular patches of four greens (no checker), a dirt path with flagstones (finer studs) that
--              forks round the nest and curves away, a pebble beach at the lake, and towards Lava Lagoon the grass
--              turning patchy and dry, then scorched and ashy
--   Cliffs     an uneven edge with pockets, spurs, a raised ledge and the lake clearing; layered strata cliffs in four
--              stone tones (dark at the foot, light at the top, the old orange dirt as a strata accent) with grassy
--              ledges, overhangs, hanging moss and boulders at the foot; low enough in places to see out; hills and far
--              ridges behind; invisible walls follow the rock fronts exactly
--   Scatter    rounded boulders, pebble stacks, a balanced rock, wildflowers, a line of giant kaiju footprints, half-
--              buried fossil bones, trees and bushes on the cliff tops
--   Landmark   the Colossus: a huge moss-covered stone statue of the Pebble Plains guardian rising behind a lake, a
--              waterfall pouring from its open jaws
--   Transition dry grass, ash, charred bushes and smoking cracks before the Obsidian Maw
-- Inside the walkable area everything is non-colliding except a few boulders at the edges and the ledge (with a ramp).
local ServerStorage = game:GetService("ServerStorage")
local hex = Color3.fromHex

return function(b, K, T)
	local P = K.P
	local model = b.model
	local rng = Random.new(7071)
	local XA, XB = 350, b.x1
	local HALF = 85
	local report = {}

	---------------------------------------------------------------- layout
	local edge = {
		[1] = T.edge({ { 350, 63 }, { 358, 63 }, { 366, 70 }, { 374, 74 }, { 380, 66 }, { 385, 70 }, { 390, 85 }, { 432, 85 }, { 437, 72 }, { 442, 65 }, { 452, 65 } }),
		[-1] = T.edge({ { 350, 63 }, { 358, 60 }, { 364, 58 }, { 370, 70 }, { 376, 82 }, { 390, 82 }, { 396, 62 }, { 402, 60 }, { 408, 70 }, { 414, 84 }, { 426, 84 }, { 432, 72 }, { 440, 65 }, { 452, 65 } }),
	}
	local function inClearing(x)
		return x > 388 and x < 434
	end
	local function height(side, x)
		local n = T.n01(x / 19 + (side > 0 and 3.3 or 8.1), side * 2.3, 0.5)
		if side > 0 and inClearing(x) then
			return 0 -- the lake clearing: open
		end
		if side < 0 and x > 409 and x < 431 then
			return math.floor((14 + n * 6) / 2) * 2 -- low: the view out to the south
		end
		local h = 44 + n * 36
		if x < 364 then
			h = math.max(h, 64 + n * 14) -- up against the Grand Gate's towers
		end
		if side > 0 and ((x > 375 and x <= 388) or (x >= 434 and x < 443)) then
			h = 18 + n * 8 -- low grassy knolls either side of the lake
		end
		if x > 440 then
			h = 50 + n * 10
		end
		return math.floor(h / 2 + 0.5) * 2
	end
	local PATHS = {
		{ { 350, 4, 10 }, { 356, 12, 9 }, { 366, 16, 8 }, { 378, 13, 9 }, { 388, 6, 11 } },
		{ { 350, -4, 10 }, { 356, -12, 9 }, { 366, -16, 8 }, { 378, -13, 9 }, { 388, -6, 11 } },
		{ { 386, 0, 13 }, { 396, 10, 15 }, { 408, 15, 17 }, { 420, 10, 14 }, { 430, -4, 12 }, { 440, -8, 14 }, { 452, 0, 18 } },
		{ { 408, 15, 7 }, { 410, 40, 6 }, { 412, 62, 6 }, { 414, 84, 7 } }, -- to the lake
		{ { 378, -13, 6 }, { 382, -34, 6 }, { 384, -56, 6 } }, -- to the ledge
	}
	local function pathGap(x, z) -- < 0 on the path
		local best = math.huge
		for _, p in PATHS do
			local d, half = T.polyDistance(p, x, z)
			best = math.min(best, d - half)
		end
		return best
	end
	local nest = model:FindFirstChild("NestSite")
	local NEST = nest and nest:GetPivot().Position or Vector3.new(362, 0, 0)
	local function nearNest(x, z, r)
		return (Vector3.new(x, 0, z) - Vector3.new(NEST.X, 0, NEST.Z)).Magnitude < r
	end

	---------------------------------------------------------------- colours
	local ROCK = { hex("6E5B4B"), hex("8E7863"), hex("A9927A"), hex("C7B79C"), accent = hex("C98A4B") }
	local CHAR = hex("43392F")
	local GRASS = { hex("63D93C"), hex("55CB30"), hex("4DBA2C"), hex("72D84A") }
	local DRY = { hex("B8B25A"), hex("A39A4E"), hex("9C8A55") }
	local ASH = { hex("5C5650"), hex("4C4743"), hex("6B635B") }
	local DIRT = { hex("A8774A"), hex("9A6A3E"), hex("B5855A") }
	local BEACH = { hex("CFC4AC"), hex("BDB29A") }
	local CAPS = { hex("4FC22A"), hex("5BBF35"), hex("58B83A") }
	local MOSS = { hex("5E8B3A"), hex("47702D"), hex("6E9E45") }
	local BONE = { hex("D8CCAE"), hex("BBAE8C") }
	local BONE_DARK = hex("8C7F62")
	local function capColor(x, r)
		local c = CAPS[r:NextInteger(1, #CAPS)]
		if x > 426 then
			c = c:Lerp(hex("A79E52"), math.clamp((x - 426) / 14, 0, 1))
		end
		if x > 440 then
			c = c:Lerp(hex("6A625B"), math.clamp((x - 440) / 10, 0, 1))
		end
		return c
	end
	local function tint(x, c)
		if x > 428 then
			return c:Lerp(CHAR, math.clamp((x - 428) / 24, 0, 1) * 0.6)
		end
		return c
	end
	local function rockAt(pos, t)
		return tint(pos.X, T.tone(ROCK, pos, 0.25 + t * 0.55, rng))
	end

	---------------------------------------------------------------- clear the old version
	for _, n in { "Cliffs", "Landmark", "Dress", "Refined" } do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local floor = model:FindFirstChild("Floor")
	local gone = 0
	for _, t in floor:GetDescendants() do
		if t:IsA("BasePart") and (t.Position.X > XA or t.Name == "Ground") then
			t:Destroy()
			gone += 1
		end
	end
	table.insert(report, gone .. " old floor tiles removed")
	local decor = model:FindFirstChild("Decor")
	local REMOVE = { Trail = true, Pebble = true, WallRock = true, Cap = true, VineLong = true, VineShort = true }
	local removed, kept = 0, 0
	for _, d in decor:GetChildren() do
		local pos
		if d:IsA("Model") then
			pos = d:GetBoundingBox().Position
		elseif d:IsA("BasePart") then
			pos = d.Position
		end
		if pos and d.Name ~= "NestSign" then
			local side = pos.Z >= 0 and 1 or -1
			local lim = (side > 0 and inClearing(pos.X)) and 80 or edge[side](pos.X) - 3
			if REMOVE[d.Name] or (pos.X > XA and (math.abs(pos.Z) > lim or pathGap(pos.X, pos.Z) < 1)) then
				d:Destroy()
				removed += 1
			else
				kept += 1
			end
		end
	end
	table.insert(report, string.format("decor: %d removed (old trail, wall rocks, vines, anything now in rock or on the path), %d kept", removed, kept))
	local zone = model:FindFirstChild("Zone")
	zone.Size = Vector3.new(zone.Size.X, zone.Size.Y, HALF * 2)
	model:SetAttribute("Refined", true)

	local root = K.model(model, "Refined")
	local function sub(name)
		return K.model(root, name)
	end

	---------------------------------------------------------------- ground
	local nGround = T.ground(floor, {
		x0 = XA,
		x1 = XB,
		z0 = -96,
		z1 = 96,
		keep = function(x, z)
			local side = z >= 0 and 1 or -1
			if side > 0 and inClearing(x) then
				return z < 86
			end
			return math.abs(z) < edge[side](x) + 8
		end,
		color = function(x, z)
			local n = T.n01(x / 15 + 1.7, z / 15 + 4.2, 0.3)
			if pathGap(x, z) <= 0 and not nearNest(x, z, 11) then
				return DIRT[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end
			if z > 79 and inClearing(x) then
				return BEACH[n < 0.5 and 1 or 2]
			end
			local tb = math.clamp((x - 416) / 36, 0, 1)
			local n2 = T.n01(x / 9 + 7.7, z / 9 - 2.2, 0.8)
			if n2 < tb * 1.9 - 1.0 then
				return ASH[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			elseif n2 < tb * 1.5 - 0.15 then
				return DRY[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end
			return GRASS[math.clamp(math.floor(n * 4) + 1, 1, 4)]
		end,
		fine = function(x, z)
			return (pathGap(x, z) <= 0 and not nearNest(x, z, 11)) or (z > 79 and inClearing(x))
		end,
	})
	table.insert(report, nGround .. " ground pieces")

	---------------------------------------------------------------- the path's flagstones
	local path = sub("Path")
	local STONES = { hex("A5A39D"), hex("8F8B84"), hex("BDB7AB") }
	for pi, p in PATHS do
		for i = 1, #p - 1 do
			local a, c = Vector3.new(p[i][1], 0, p[i][2]), Vector3.new(p[i + 1][1], 0, p[i + 1][2])
			local d = c - a
			local L = d.Magnitude
			local across = Vector3.new(-d.Z, 0, d.X).Unit
			local t = rng:NextNumber(0, 2)
			while t < L do
				local half = (p[i][3] + (p[i + 1][3] - p[i][3]) * t / L) / 2
				local at = a + d.Unit * t + across * rng:NextNumber(-(half - 2.2), half - 2.2)
				if rng:NextNumber() < (pi >= 4 and 0.95 or 0.8) and not nearNest(at.X, at.Z, 13) then
					local sz = Vector3.new(rng:NextNumber(2.6, 4), 0.26, rng:NextNumber(2.4, 3.4))
					local s = K.part(path, "Flagstone", sz, CFrame.new(at.X, 0.07, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), STONES[rng:NextInteger(1, 3)], { studs = K.TOP, solid = false })
					for _, tx in s:GetChildren() do
						tx.StudsPerTileU, tx.StudsPerTileV = 2, 2
					end
				end
				t += pi >= 4 and 3.6 or 4.4
			end
		end
	end

	---------------------------------------------------------------- cliffs, walls, ridges
	local cliffs, walls, back = sub("Cliffs"), sub("Walls"), sub("Back")
	local scatter = sub("Scatter")
	local tops = {}
	for _, side in { 1, -1 } do
		local cols = T.cliffRow(cliffs, {
			side = side,
			xa = XA,
			xb = XB,
			edge = edge[side],
			height = function(x)
				return height(side, x)
			end,
			pal = ROCK,
			capColor = capColor,
			tint = tint,
			rng = rng,
			href = 110,
		})
		T.walls(walls, cols, side, 100)
		for _, c in cols do
			if c.h > 0 then
				table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top + 1.4, z0 = c.lastFront + 3, z1 = c.back - 3 })
				-- a boulder at the foot
				if rng:NextNumber() < 0.55 then
					local r = rng:NextNumber(1.6, 3.4)
					local x = rng:NextNumber(c.x0 + 1, c.x1 - 1)
					T.boulder(scatter, Vector3.new(x, 0, side * (c.front - r * 0.45)), r, rockAt, rng, { solid = r > 2.2, moss = rng:NextNumber() < 0.5 and MOSS[1] or nil })
				end
				-- hanging vines
				if c.x0 < 430 and rng:NextNumber() < 0.3 then
					local vx = rng:NextNumber(c.x0 + 1, c.x1 - 1)
					local f = c.lastFront - 0.7
					for j = 0, rng:NextInteger(3, 6) do
						local y = c.top + 0.6 - (j + 1) * 2.6
						K.box(cliffs, "Vine", vx - 0.45, vx + 0.45, y, y + 2.8, side * f, side * (f + 0.5), P.Vine, { solid = false })
						if j % 2 == 1 then
							K.box(cliffs, "Leaf", vx - 1.3, vx + 1.3, y + 0.6, y + 2, side * (f - 0.3), side * (f + 0.4), P.Leaf, { solid = false })
						end
					end
				end
			end
		end
		-- hills behind (lower behind the view out to the south and the statue's clearing)
		local row2 = T.ridgeRow(back, {
			side = side,
			xa = 302,
			xb = XB,
			minW = 12,
			maxW = 20,
			front = function(x)
				if side > 0 and inClearing(x) then
					return 188
				end
				return edge[side](x) + 22
			end,
			back = function()
				return 214
			end,
			height = function(x)
				local n = T.n01(x / 27 + side * 5.7, 1.9, side)
				if side > 0 and x > 372 and x < 446 then
					return math.floor(36 + n * 12) -- low behind the lake: the statue stands against the sky
				end
				if side < 0 and x > 404 and x < 436 then
					return math.floor(24 + n * 10)
				end
				return math.floor(74 + n * 36)
			end,
			layers = 2,
			pal = ROCK,
			capColor = capColor,
			tint = tint,
			rng = rng,
			href = 150,
		})
		for _, c in row2 do
			table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top, z0 = c.front + 4, z1 = math.min(c.back - 4, c.front + 30), big = true })
		end
		T.ridgeRow(back, {
			side = side,
			xa = 302,
			xb = XB,
			minW = 26,
			maxW = 40,
			front = function()
				return 204
			end,
			back = function()
				return 330
			end,
			height = function(x)
				local n = T.n01(x / 41 + side * 2.9, 6.1, side)
				if side < 0 and x > 400 and x < 440 then
					return math.floor(46 + n * 16)
				end
				if side > 0 and x > 368 and x < 452 then
					return math.floor(62 + n * 20)
				end
				return math.floor(118 + n * 52)
			end,
			layers = 2,
			far = true,
			pal = ROCK,
			capColor = capColor,
			tint = tint,
			rng = rng,
			href = 180,
		})
	end

	---------------------------------------------------------------- trees and bushes on the cliff tops (the biome's own)
	local pool = {}
	for _, d in decor:GetChildren() do
		if d:IsA("Model") and (d.Name == "Tree" or d.Name == "Bush" or d.Name == "BerryBush") then
			pool[d.Name] = pool[d.Name] or {}
			table.insert(pool[d.Name], d)
		end
	end
	local greens = sub("Greenery")
	local nTrees = 0
	for _, t in tops do
		if t.x < 432 and t.z1 > t.z0 then
			local r = rng:NextNumber()
			local kind = r < (t.big and 0.35 or 0.28) and "Tree" or (r < 0.55 and (rng:NextNumber() < 0.5 and "Bush" or "BerryBush") or nil)
			local list = kind and pool[kind]
			if list then
				local scale = kind == "Tree" and (t.big and rng:NextNumber(2.2, 2.8) or rng:NextNumber(1.5, 2)) or rng:NextNumber(1.4, 1.9)
				local z = t.side * rng:NextNumber(t.z0, t.z1)
				T.cloneProp(list[rng:NextInteger(1, #list)], scale, CFrame.new(t.x, t.y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)).Parent = greens
				nTrees += 1
			end
		end
	end
	table.insert(report, nTrees .. " trees / bushes on the heights")

	---------------------------------------------------------------- the raised ledge in the south pocket (a ramp up from the lane)
	local LX0, LX1 = 378, 392
	K.box(scatter, "LedgeRock", LX0, LX1, -2, 4, -64, -80, rockAt(Vector3.new(385, 2, -72), 0.2), { studs = K.SIDES })
	K.box(scatter, "LedgeTop", LX0, LX1, 4, 4.6, -64, -80, CAPS[2], { studs = K.TOP })
	local ramp = Instance.new("WedgePart")
	ramp.Name = "LedgeRamp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(LX1 - LX0, 4.6, 7)
	ramp.CFrame = CFrame.new((LX0 + LX1) / 2, 2.3, -60.5) * CFrame.Angles(0, math.pi, 0) -- the slope faces the lane
	ramp.Color = CAPS[1]
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.TopSurface = Enum.SurfaceType.Smooth
	K.studs(ramp, { K.N.Top })
	ramp.Parent = scatter
	T.cairn(scatter, Vector3.new(389, 4.6, -76), { 2.4, 1.6 }, rockAt, rng, { moss = MOSS[3] })
	for _ = 1, 3 do
		T.boulder(scatter, Vector3.new(rng:NextNumber(LX0 + 2, LX1 - 2), 4.6, rng:NextNumber(-78, -70)), rng:NextNumber(0.8, 1.3), rockAt, rng)
	end

	---------------------------------------------------------------- pebble formations and boulders
	T.cairn(scatter, Vector3.new(372, 0, 66), { 4.6, 3.5, 2.7, 1.8 }, rockAt, rng, { solid = true, moss = MOSS[1] })
	local base, top = T.boulder(scatter, Vector3.new(419, 0, -74), 2.4, rockAt, rng, { solid = true })
	T.boulder(base, Vector3.new(420.2, top - 0.4, -74), 5.4, rockAt, rng, { solid = true, moss = MOSS[2] })
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		T.boulder(scatter, Vector3.new(419 + math.cos(a) * 8, 0, -74 + math.sin(a) * 6.5), rng:NextNumber(0.8, 1.3), rockAt, rng)
	end
	-- pebble clusters about the grass
	local placed = 0
	for _ = 1, 60 do
		if placed >= 9 then
			break
		end
		local x, z = rng:NextNumber(358, 434), rng:NextNumber(-70, 70)
		local side = z >= 0 and 1 or -1
		if math.abs(z) < edge[side](x) - 8 and pathGap(x, z) > 4 and not nearNest(x, z, 18) then
			for _ = 1, rng:NextInteger(2, 4) do
				T.boulder(scatter, Vector3.new(x + rng:NextNumber(-3, 3), 0, z + rng:NextNumber(-3, 3)), rng:NextNumber(0.7, 1.6), rockAt, rng, { moss = rng:NextNumber() < 0.3 and MOSS[3] or nil })
			end
			placed += 1
		end
	end

	---------------------------------------------------------------- wildflowers
	local FLOWERS = { hex("F4F1E6"), hex("F2C14E"), hex("9B6CF0"), hex("F07AB0"), hex("E8434A"), hex("6FA8F5") }
	placed = 0
	for _ = 1, 80 do
		if placed >= 11 then
			break
		end
		local x, z = rng:NextNumber(356, 426), rng:NextNumber(-80, 84)
		local side = z >= 0 and 1 or -1
		local lim = (side > 0 and inClearing(x)) and 76 or edge[side](x) - 5
		if math.abs(z) < lim and pathGap(x, z) > 3 and not nearNest(x, z, 15) then
			T.wildflowers(scatter, Vector3.new(x, 0, z), rng:NextNumber(3.5, 6), rng:NextInteger(7, 11), FLOWERS, hex("3E8E2A"), rng)
			placed += 1
		end
	end

	---------------------------------------------------------------- a giant's footprints, crossing the plain
	local walk = Vector3.new(16, 0, -24).Unit
	local acrossW = Vector3.new(-walk.Z, 0, walk.X)
	for i, at in { Vector3.new(380, 0, 40), Vector3.new(396, 0, 16), Vector3.new(412, 0, -8), Vector3.new(428, 0, -32) } do
		T.footprint(scatter, at + acrossW * (i % 2 == 0 and 4 or -4), walk, 22, { mud = hex("6B4A2F"), deep = hex("4E3521"), rim = hex("8C7A45") })
	end

	---------------------------------------------------------------- fossils, half buried
	local bones = sub("Fossils")
	for k = 0, 3 do
		local x = 398 + k * 4
		T.arcBone(bones, Vector3.new(x, -2.5, -34), math.rad(90), 8 - k * 0.6, 10, 128, 1.9, 1.0, BONE, 5)
	end
	for k = 0, 4 do
		local x = 396 + k * 4
		local w = 2.6 - k * 0.15
		K.box(bones, "Vertebra", x - w / 2, x + w / 2, -0.6, 1.2, -43.5, -40.5, BONE[(k % 2) + 1], { studs = K.ALL, solid = false })
		K.box(bones, "Spinous", x - 0.4, x + 0.4, 1.2, 2.6, -42.4, -41.6, BONE[2], { solid = false })
	end
	-- a femur and two ribs on the ledge
	T.chain(bones, "Femur", { Vector3.new(380.5, 5.3, -76.5), Vector3.new(386, 5.5, -74), Vector3.new(391, 5.6, -71.5) }, { 1.9, 1.7 }, BONE)
	for _, e in { Vector3.new(380.5, 5.3, -76.5), Vector3.new(391, 5.6, -71.5) } do
		K.part(bones, "Knob", Vector3.new(3.2, 2.4, 3), CFrame.new(e), BONE[1], { studs = K.ALL, solid = false })
		K.part(bones, "Knob", Vector3.new(2.2, 1.6, 2.2), CFrame.new(e + Vector3.new(0, 1.2, 0)), BONE[2], { solid = false })
	end
	T.arcBone(bones, Vector3.new(384, 1.8, -78), 0, 6, 25, 135, 1.6, 0.9, BONE, 4)
	T.arcBone(bones, Vector3.new(389, 1.8, -79), 0, 5.4, 25, 135, 1.5, 0.9, BONE, 4)
	-- a great claw and a run of vertebrae in the north alcove
	T.chain(bones, "Claw", { Vector3.new(379, -0.6, 52), Vector3.new(379.4, 4.2, 53.5), Vector3.new(380, 7.8, 56.2), Vector3.new(380.6, 9.6, 59.6) }, { 2.8, 2.1, 1.3 }, { BONE[1], BONE[2], BONE_DARK })
	for k = 0, 2 do
		local x = 366 + k * 3.6
		K.box(bones, "Vertebra", x - 1.2, x + 1.2, -0.5, 1.1, 54.5, 57.5, BONE[(k % 2) + 1], { studs = K.ALL, solid = false })
	end

	---------------------------------------------------------------- the transition: dry grass, ash, charred bushes, smoking cracks
	local trans = sub("Transition")
	for _, c in { { 436, 26, 80 }, { 442, -20, 100 }, { 434, -48, 70 }, { 445, 44, 95 } } do
		T.crack(trans, Vector3.new(c[1], 0, c[2]), math.rad(c[3]), 4, rng, { dark = hex("2B2522"), glow = hex("FF5A1F") })
	end
	local DRYLEAF, CHARLEAF = hex("A08F4A"), hex("3A332E")
	for _, d in decor:GetChildren() do
		if d:IsA("Model") and d.Name ~= "NestSign" and not d:GetAttribute("Weathered") then
			local x = d:GetBoundingBox().X
			if x > 420 then
				local f1 = math.clamp((x - 420) / 16, 0, 1)
				local f2 = math.clamp((x - 438) / 12, 0, 1)
				for _, p in d:GetDescendants() do
					if p:IsA("BasePart") then
						local c = p.Color
						local c2 = c:Lerp(DRYLEAF, f1 * ((c.G > c.R and c.G > c.B) and 0.8 or 0.35))
						p.Color = c2:Lerp(CHARLEAF, f2 * 0.8)
					end
				end
				d:SetAttribute("Weathered", true)
			end
		end
	end

	---------------------------------------------------------------- the Colossus: a stone guardian behind a lake
	local land = sub("Landmark")
	local WATER, WATER2, FOAM = hex("4DB3E6"), hex("6BC6EE"), hex("EAF8FF")
	K.box(land, "LakeBed", 388, 434, -4, -1.6, 86, 130, hex("3E5A50"), { studs = K.TOP })
	K.box(land, "Lake", 388, 434, -1.6, 0.15, 86, 130, WATER, { transparency = 0.25, solid = false, shadow = false })
	for x = 390, 432, 3.7 do
		T.boulder(land, Vector3.new(x + rng:NextNumber(-0.8, 0.8), 0, 87.4), rng:NextNumber(1.1, 1.9), rockAt, rng, { moss = rng:NextNumber() < 0.45 and MOSS[1] or nil })
	end
	for _, sx in { 389.5, 432.5 } do
		for z = 92, 126, 6 do
			T.boulder(land, Vector3.new(sx + rng:NextNumber(-0.6, 0.6), 0, z), rng:NextNumber(1.2, 2), rockAt, rng, { moss = MOSS[2] })
		end
	end
	for _ = 1, 6 do
		local x, z = rng:NextNumber(390, 430), rng:NextNumber(90, 104)
		local pad = rng:NextNumber(2, 3)
		K.part(land, "LilyPad", Vector3.new(pad, 0.12, pad), CFrame.new(x, 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), hex("4E9E36"), { solid = false })
		if rng:NextNumber() < 0.4 then
			K.box(land, "LilyFlower", x - 0.5, x + 0.5, 0.26, 0.9, z - 0.5, z + 0.5, hex("F4C6DA"), { solid = false })
		end
	end
	for _, at in { Vector3.new(389, 0, 89), Vector3.new(431, 0, 90), Vector3.new(392, 0, 120), Vector3.new(428, 0, 121) } do
		for k = 0, 2 do
			local x, z = at.X + rng:NextNumber(-1.2, 1.2), at.Z + rng:NextNumber(-1.2, 1.2)
			local h = rng:NextNumber(3.5, 6)
			K.box(land, "Reed", x - 0.22, x + 0.22, -0.5, h, z - 0.22, z + 0.22, hex("4B7F2A"), { solid = false })
			K.box(land, "ReedHead", x - 0.32, x + 0.32, h - 1.2, h, z - 0.32, z + 0.32, hex("7A5434"), { solid = false })
		end
	end
	-- the rock the statue stands on
	K.box(land, "StatueRock", 388, 434, -2, 2.6, 126, 196, rockAt(Vector3.new(411, 0, 160), 0.1), { studs = K.ALL })
	K.box(land, "StatueMoss", 390, 432, 2.6, 3.2, 128, 194, MOSS[1], { studs = K.TOP, solid = false })
	local src = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets.Kaiju:FindFirstChild("Guardian_PebblePlains")
	if src then
		local s = src:Clone()
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		-- the pose: head raised, jaws wide open
		local pivot = s:GetPivot()
		local offset = s:GetAttribute("RootOffset") or Vector3.zero
		local right = pivot.RightVector
		local function partsOf(g)
			local t = {}
			for _, d in g:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(t, d)
				end
			end
			return t
		end
		local function turn(hinge, deg)
			return CFrame.new(hinge) * CFrame.fromAxisAngle(right, math.rad(deg)) * CFrame.new(-hinge)
		end
		local head = s:FindFirstChild("HeadGroup")
		local jaw = head and head:FindFirstChild("JawGroup")
		local headTurn = CFrame.identity
		if head and typeof(head:GetAttribute("Joint")) == "Vector3" then
			headTurn = turn(pivot:PointToWorldSpace(head:GetAttribute("Joint") - offset), 14)
			for _, p in partsOf(head) do
				p.CFrame = headTurn * p.CFrame
			end
		end
		if jaw and typeof(jaw:GetAttribute("Joint")) == "Vector3" then
			local jt = turn(headTurn * pivot:PointToWorldSpace(jaw:GetAttribute("Joint") - offset), -36)
			for _, p in partsOf(jaw) do
				p.CFrame = jt * p.CFrame
			end
		end
		-- weathered stone and moss
		local STONE = { hex("7C786F"), hex("989389"), hex("B2ADA1"), hex("C8C3B5") }
		local srng = Random.new(91)
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				local n = d.Name
				if d.Transparency >= 0.99 or n == "EyeClosed" then
					d:Destroy()
				else
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = 0
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					if n == "Socket" or n == "EyeOpen" or n == "Mouth" then
						d.Color = hex("2D2B27")
					elseif n == "Tooth" or n:find("Claw") then
						d.Color = hex("CFC9BA")
					else
						local c = d.Color
						local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
						local t = math.clamp(l * 0.9 + math.noise(d.Position.X / 5 + 1.3, d.Position.Y / 5, d.Position.Z / 5) * 0.5, 0, 0.999)
						local mossy = (d.CFrame.UpVector.Y > 0.55 and srng:NextNumber() < 0.42) or ((n == "Back" or n:find("Stone") or n:find("Armour")) and srng:NextNumber() < 0.5)
						d.Color = mossy and MOSS[srng:NextInteger(1, 3)] or K.shade(STONE[math.floor(t * 4) + 1], srng:NextNumber(-0.03, 0.03))
					end
				end
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			end
		end
		local hum = s:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:Destroy()
		end
		for k in s:GetAttributes() do
			s:SetAttribute(k, nil)
		end
		local SCALE = 3.9
		s:ScaleTo(SCALE)
		for _, t in s:GetDescendants() do
			if t:IsA("Texture") then
				t.StudsPerTileU *= SCALE
				t.StudsPerTileV *= SCALE
			end
		end
		s:PivotTo(CFrame.lookAt(Vector3.new(411, 0, 150), Vector3.new(396, 0, 0)))
		-- front of the head at z 99, feet on the rock
		local minY, minZ = math.huge, math.huge
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				minY = math.min(minY, d.Position.Y - d.Size.Y / 2)
				minZ = math.min(minZ, d.Position.Z - math.max(d.Size.X, d.Size.Z) / 2)
			end
		end
		s:PivotTo(s:GetPivot() + Vector3.new(0, 3.1 - minY, 100 - minZ))
		s.Name = "Colossus"
		s.Parent = land
		-- vines hanging off it
		local hangs = {}
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") and d.Position.Y > 24 and d.Position.Z < 130 then
				table.insert(hangs, d)
			end
		end
		for _ = 1, math.min(6, #hangs) do
			local d = hangs[srng:NextInteger(1, #hangs)]
			local p = d.Position - Vector3.new(0, d.Size.Y / 2, 0)
			for j = 0, srng:NextInteger(3, 6) do
				local y = p.Y - j * 2.6
				K.box(land, "Vine", p.X - 0.5, p.X + 0.5, y - 2.8, y, p.Z - 0.5, p.Z + 0.5, P.Vine, { solid = false })
				if j % 2 == 0 then
					K.box(land, "Leaf", p.X - 1.4, p.X + 1.4, y - 2, y - 0.6, p.Z - 0.7, p.Z + 0.7, MOSS[3], { solid = false })
				end
			end
		end
		-- the waterfall: out over the lower jaw, an arc, then straight down into the lake
		local look = s:GetPivot().LookVector
		look = Vector3.new(look.X, 0, look.Z).Unit
		local jawParts = {}
		local mouth
		local hg = s:FindFirstChild("HeadGroup")
		if hg then
			local jg = hg:FindFirstChild("JawGroup")
			jawParts = jg and partsOf(jg) or {}
			for _, d in hg:GetChildren() do
				if d:IsA("BasePart") and d.Name == "Mouth" then
					mouth = d
				end
			end
		end
		local lip, lipD = nil, -math.huge
		for _, d in jawParts do
			local dd = d.Position:Dot(look)
			if dd > lipD then
				lip, lipD = d, dd
			end
		end
		if lip then
			local O = lip.Position + Vector3.new(0, lip.Size.Y / 2 + 0.8, 0) + look * 0.8
			local M = mouth and mouth.Position or (O - look * 6 + Vector3.new(0, 1.5, 0))
			local A = O + look * 3.6 + Vector3.new(0, -7, 0)
			local G = Vector3.new(A.X, 0.1, A.Z)
			local wo = { transparency = 0.28, solid = false, shadow = false }
			local function sheet(name, a, c, w, color)
				local d = c - a
				local mid = (a + c) / 2
				K.part(land, name, Vector3.new(w, d.Magnitude + 0.6, 0.9), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.rad(90), 0, 0), color, wo)
			end
			sheet("Waterfall", M, O, 5.2, WATER2)
			sheet("Waterfall", O, A, 5.6, WATER2)
			sheet("Waterfall", A, G, 6, WATER)
			sheet("Waterfall", A + Vector3.new(0, -2, 0) + look * 0.5, G + look * 0.5, 3.4, FOAM)
			for k = 0, 3 do
				local a = k / 4 * math.pi * 2
				K.part(land, "Foam", Vector3.new(3.2, 0.7, 2.4), CFrame.new(G + Vector3.new(math.cos(a) * 3, 0.3, math.sin(a) * 3)) * CFrame.Angles(0, -a, 0), FOAM, { solid = false, shadow = false })
			end
			-- spray where it lands and drops falling from the jaws
			local splash = K.part(land, "Splash", Vector3.new(1, 1, 1), CFrame.new(G + Vector3.new(0, 1, 0)), FOAM, { solid = false, transparency = 1, shadow = false })
			local mist = Instance.new("ParticleEmitter")
			mist.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
			mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
			mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			mist.Lifetime = NumberRange.new(1.4, 2.4)
			mist.Rate = 22
			mist.Speed = NumberRange.new(3, 7)
			mist.SpreadAngle = Vector2.new(60, 60)
			mist.Acceleration = Vector3.new(0, 2, 0)
			mist.EmissionDirection = Enum.NormalId.Top
			mist.Parent = splash
			local spout = K.part(land, "Spout", Vector3.new(4, 1, 1), CFrame.lookAt(O, O + look), WATER2, { solid = false, transparency = 1, shadow = false })
			local drops = Instance.new("ParticleEmitter")
			drops.Color = ColorSequence.new(Color3.fromRGB(150, 215, 245))
			drops.Size = NumberSequence.new(0.7)
			drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
			drops.Lifetime = NumberRange.new(1.5, 1.9)
			drops.Rate = 45
			drops.Speed = NumberRange.new(5, 8)
			drops.SpreadAngle = Vector2.new(14, 14)
			drops.Acceleration = Vector3.new(0, -55, 0)
			drops.EmissionDirection = Enum.NormalId.Front
			drops.Parent = spout
			table.insert(report, string.format("waterfall from y %.0f into the lake at z %.0f", O.Y, G.Z))
		end
	end

	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(report, "Pebble Plains now " .. n .. " parts")
	return table.concat(report, "; ")
end
