-- Lava Lagoon, refined (CanyonBuilder section "Refine"). Rebuilds the biome's ground and surroundings in place, keeping
-- its contracts: Zone (now 176 wide), NestSite, Sign, Border, Decor's NestSignLava, the Obsidian Maw gate. The layout
-- below was drawn for x 452..627 and is laid onto the lane with T.stretch (X() places, U() reads back).
--   Ground     basalt in four dark tones with ash patches, an ash-gravel path with obsidian flagstones, a lava river
--              (sunk below the ground, walkable) from a pool in the north pocket to one in the south, a stone bridge where
--              the path crosses it, glowing crust round the lava, and towards Frostfang cooling obsidian, then frost
--   Cliffs     layered basalt/obsidian strata with irregular glowing cracks and three lava cascades stepping down the
--              ledges into puddles; ash caps; low in the south so the volcano shows; ridges behind
--   Scatter    obsidian spires, a natural rock arch over the river, smoking cracks, embers rising off the lava, the
--              biome's own crystals / spires / charred trees on the heights
--   Volcano    an irregular cone of lobes (no even tiers) with a jagged crater, fire, smoke and embers, and three lava
--              channels winding down the side facing the lane
--   Transition cooling obsidian and steam vents, then frost creeping over the dark rock, then snow before the Frozen Fangs
local hex = Color3.fromHex

return function(b, K, T)
	local model = b.model
	local rng = Random.new(8081)
	local XA, XB = b.x0, b.x1
	local X, U = T.stretch(452, 627, XA, XB)
	local HALF = 88
	local report = {}

	---------------------------------------------------------------- layout
	local edge = {
		[1] = T.edge(T.at({ { 452, 65 }, { 460, 65 }, { 467, 70 }, { 474, 84 }, { 500, 86 }, { 507, 70 }, { 514, 62 }, { 522, 64 }, { 532, 72 }, { 544, 72 }, { 552, 66 }, { 560, 64 }, { 568, 76 }, { 576, 86 }, { 594, 86 }, { 600, 72 }, { 608, 65 }, { 627, 65 } }, X)),
		[-1] = T.edge(T.at({ { 452, 65 }, { 460, 63 }, { 466, 68 }, { 474, 82 }, { 498, 84 }, { 505, 68 }, { 512, 62 }, { 520, 64 }, { 528, 74 }, { 586, 74 }, { 594, 66 }, { 602, 62 }, { 612, 64 }, { 627, 65 } }, X)),
	}
	local function inWindow(x)
		local xo = U(x)
		return xo > 527 and xo < 589
	end
	local function height(side, x)
		local n = T.n01(x / 18 + (side > 0 and 5.3 or 1.1), side * 3.7, 0.25)
		if side < 0 and inWindow(x) then
			return math.floor((14 + n * 10) / 2) * 2 -- the view out to the volcano
		end
		local h = 50 + n * 34
		if x < XA + 16 or x > XB - 21 then
			h = math.max(h, 64 + n * 12) -- either side of the gates
		end
		return math.floor(h / 2 + 0.5) * 2
	end
	local PATHS = {
		{ { 452, 0, 14 }, { 466, -8, 12 }, { 484, -14, 11 }, { 502, -6, 12 }, { 518, 6, 12 }, { 534, 3, 12 } },
		{ { 534, 3, 8 }, { 540, 12, 7 }, { 550, 15, 7 }, { 560, 10, 7 }, { 566, 2, 8 } },
		{ { 534, 3, 8 }, { 540, -8, 7 }, { 550, -14, 7 }, { 560, -10, 7 }, { 566, -2, 8 } },
		{ { 566, 0, 12 }, { 580, 9, 12 }, { 594, 12, 11 }, { 608, 4, 12 }, { 627, 0, 14 } },
		{ { 504, -4, 6 }, { 506, 30, 6 }, { 500, 60, 6 }, { 494, 72, 6 } }, -- to the lava pool in the north pocket
		{ { 580, 9, 6 }, { 584, 40, 6 }, { 584, 70, 6 } }, -- to the second north pocket
	}
	for i, p in PATHS do
		PATHS[i] = T.at(p, X)
	end
	local function pathGap(x, z)
		local best = math.huge
		for _, p in PATHS do
			local d, half = T.polyDistance(p, x, z)
			best = math.min(best, d - half)
		end
		return best
	end
	local RIVER = T.at({ { 486, 80, 7 }, { 489, 60, 6 }, { 485, 38, 6 }, { 489, 14, 6 }, { 484, -12, 6 }, { 487, -40, 6 }, { 485, -62, 6 }, { 486, -76, 7 } }, X)
	local POOLS = T.at({ { 486, 78, 10, 6.5 }, { 486, -77, 10, 6 }, { 588, 79, 7, 4.5 }, { 540, -44, 4.5, 3.2 } }, X)
	local function lavaGap(x, z) -- < 0 in the lava
		local d, half = T.polyDistance(RIVER, x, z)
		local best = d - half
		for _, p in POOLS do
			local e = math.sqrt(((x - p[1]) / p[3]) ^ 2 + ((z - p[2]) / p[4]) ^ 2)
			best = math.min(best, (e - 1) * math.min(p[3], p[4]))
		end
		return best
	end
	local function isLava(x, z)
		return lavaGap(x, z) < 0 and pathGap(x, z) > 0
	end
	local nest = model:FindFirstChild("NestSite")
	local NEST = nest and nest:GetPivot().Position or Vector3.new(X(548), 0, 0)
	local function nearNest(x, z, r)
		return (Vector3.new(x, 0, z) - Vector3.new(NEST.X, 0, NEST.Z)).Magnitude < r
	end

	---------------------------------------------------------------- colours
	local ROCK = { hex("1E181C"), hex("2E2426"), hex("45363A"), hex("5E4B47"), accent = hex("6E4A3C") }
	local BASALT = { hex("2E2624"), hex("3A302E"), hex("463A36"), hex("524540") }
	local ASH = { hex("5E554F"), hex("6B625B"), hex("57504A") }
	local GRAVEL = { hex("7A6F67"), hex("6E645D"), hex("857A71") }
	local CRUST = { hex("4A2418"), hex("3B1F17") }
	local COOL = { hex("2C2A33"), hex("34323D") }
	local FROST = { hex("B8CCDC"), hex("C9DAE8") }
	local SNOW = { hex("F4FAFF"), hex("E6F1FA") }
	local OBSIDIAN = { hex("2A2230"), hex("3A3042"), hex("231C28") }
	local CAPS = { hex("4A403C"), hex("554943"), hex("3F3634") }
	local MAG = { hex("FF5A12"), hex("FF8C1F"), hex("FFB347") }
	local FLOW = { hex("FF5A12"), hex("F2470C"), hex("FF7418") } -- deep orange: bright yellow neon reads as a stripe
	local LAVA = { hex("FF6A1A"), hex("FF7A1E"), hex("FF5414") }
	local function cooling(x)
		return math.clamp((U(x) - 588) / 30, 0, 1)
	end
	local function capColor(x, r)
		local c = CAPS[r:NextInteger(1, #CAPS)]
		local f = cooling(x)
		if f > 0 then
			c = c:Lerp(SNOW[1], f * 0.9)
		end
		return c
	end
	local function tint(x, c)
		local f = cooling(x)
		if f > 0 then
			return c:Lerp(hex("3C4555"), f * 0.55)
		end
		return c
	end
	local function rockAt(pos, t)
		return tint(pos.X, T.tone(ROCK, pos, 0.2 + t * 0.6, rng))
	end
	local function light(part, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1.5
		l.Shadows = false
		l.Parent = part
		return l
	end
	local function embers(part, rate, spread)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Embers"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 80, 20))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1.8, 3.2)
		e.Rate = rate
		e.Speed = NumberRange.new(3, 7)
		e.SpreadAngle = Vector2.new(spread or 25, spread or 25)
		e.Acceleration = Vector3.new(0.6, 2, 0.4)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = part
		return e
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
		if t:IsA("BasePart") then
			t:Destroy()
			gone += 1
		end
	end
	table.insert(report, gone .. " old floor tiles removed")
	local decor = model:FindFirstChild("Decor")
	local REMOVE = { Trail = true, Pebble = true, WallRock = true, Cap = true, LavaVein = true, LavaFall = true }
	local removed, kept = 0, 0
	for _, d in decor:GetChildren() do
		local pos
		if d:IsA("Model") then
			pos = d:GetBoundingBox().Position
		elseif d:IsA("BasePart") then
			pos = d.Position
		end
		if pos and d.Name ~= "NestSignLava" then
			local side = pos.Z >= 0 and 1 or -1
			if REMOVE[d.Name] or math.abs(pos.Z) > edge[side](pos.X) - 3 or pathGap(pos.X, pos.Z) < 1 or lavaGap(pos.X, pos.Z) < 2 then
				d:Destroy()
				removed += 1
			else
				kept += 1
			end
		end
	end
	table.insert(report, string.format("decor: %d removed (old trail, wall rocks, straight lava stripes, anything in rock / path / lava), %d kept", removed, kept))
	local zone = model:FindFirstChild("Zone")
	zone.Size = Vector3.new(zone.Size.X, zone.Size.Y, HALF * 2)
	model:SetAttribute("Refined", true)
	local root = K.model(model, "Refined")
	local function sub(name)
		return K.model(root, name)
	end

	---------------------------------------------------------------- ground
	local function keep(x, z)
		local side = z >= 0 and 1 or -1
		return math.abs(z) < edge[side](x) + 8
	end
	local nGround = T.ground(floor, {
		x0 = XA,
		x1 = XB,
		z0 = -96,
		z1 = 96,
		keep = function(x, z)
			return keep(x, z) and not isLava(x, z)
		end,
		color = function(x, z)
			local n = T.n01(x / 14 + 2.9, z / 14 + 0.6, 0.7)
			local f = cooling(x)
			local n2 = T.n01(x / 9 + 4.4, z / 9 - 1.2, 0.2)
			if pathGap(x, z) <= 0 and not nearNest(x, z, 11) then
				local c = GRAVEL[math.clamp(math.floor(n * 3) + 1, 1, 3)]
				return f > 0.55 and c:Lerp(SNOW[2], (f - 0.55) * 1.6) or c
			end
			if f > 0 then
				if n2 < f * 2.1 - 1.15 then
					return SNOW[n < 0.5 and 1 or 2]
				elseif n2 < f * 1.7 - 0.35 then
					return FROST[n < 0.5 and 1 or 2]
				elseif n2 < f * 1.4 + 0.1 then
					return COOL[n < 0.5 and 1 or 2]
				end
			end
			if lavaGap(x, z) < 2.6 then
				return CRUST[n < 0.5 and 1 or 2]
			end
			local ash = U(x) < 474 and 0.55 or 0.28
			if n2 < ash then
				return ASH[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end
			return BASALT[math.clamp(math.floor(n * 4) + 1, 1, 4)]
		end,
		fine = function(x, z)
			return pathGap(x, z) <= 0 and not nearNest(x, z, 11)
		end,
	})
	-- the lava itself: sunk 0.6 into the ground, glowing, still walkable (no damage)
	local lavaFolder = sub("Lava")
	local nLava = T.ground(lavaFolder, {
		name = "Lava",
		x0 = XA,
		x1 = XB,
		z0 = -96,
		z1 = 96,
		top = -0.6,
		keep = function(x, z)
			return keep(x, z) and isLava(x, z)
		end,
		color = function(x, z)
			local n = T.n01(x / 6 + 1.3, z / 6 + 7.1, 0.9)
			return LAVA[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end,
	})
	for _, p in lavaFolder:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.Neon
			p.CastShadow = false
			for _, t in p:GetChildren() do
				t:Destroy()
			end
		end
	end
	table.insert(report, nGround .. " ground pieces, " .. nLava .. " lava pieces")
	-- light and embers off the lava
	for i, p in POOLS do
		local a = K.part(lavaFolder, "Glow", Vector3.new(1, 1, 1), CFrame.new(p[1], 1.5, p[2]), LAVA[1], { solid = false, transparency = 1, shadow = false })
		light(a, Color3.fromRGB(255, 120, 40), 22 + p[3], 1.8)
		embers(a, 4 + p[3] * 0.8, 40)
	end
	for _, at in { { 488, 30 }, { 486, -48 } } do
		local a = K.part(lavaFolder, "Glow", Vector3.new(1, 1, 1), CFrame.new(X(at[1]), 1.5, at[2]), LAVA[1], { solid = false, transparency = 1, shadow = false })
		light(a, Color3.fromRGB(255, 120, 40), 18, 1.4)
		embers(a, 4, 30)
	end

	---------------------------------------------------------------- the path's obsidian flagstones, the bridge
	local path = sub("Path")
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
				if rng:NextNumber() < 0.6 and not nearNest(at.X, at.Z, 13) and lavaGap(at.X, at.Z) > 1 then
					local sz = Vector3.new(rng:NextNumber(2.4, 3.8), 0.26, rng:NextNumber(2.2, 3.2))
					local c0 = OBSIDIAN[rng:NextInteger(1, 3)]
					if cooling(at.X) > 0.5 then
						c0 = c0:Lerp(FROST[2], 0.5)
					end
					local s = K.part(path, "Flagstone", sz, CFrame.new(at.X, 0.07, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), c0, { studs = K.TOP, solid = false })
					for _, tx in s:GetChildren() do
						tx.StudsPerTileU, tx.StudsPerTileV = 2, 2
					end
				end
				t += pi >= 5 and 3.6 or 4.4
			end
		end
	end
	-- the bridge where the path crosses the river: a stone slab with rough rock kerbs along both banks
	local bridge = sub("Bridge")
	local BXc = X(484.5) -- where the path crosses the river
	K.box(bridge, "BridgeSlab", BXc - 6, BXc + 6, 0, 0.35, -21, -7, hex("5E4B47"), { studs = K.TOP, solid = false })
	for _, bx in { BXc - 6, BXc + 6 } do
		for z = -21, -8, 2.6 do
			T.boulder(bridge, Vector3.new(bx + rng:NextNumber(-0.4, 0.4), 0, z + 1.3), rng:NextNumber(0.6, 0.95), rockAt, rng)
		end
	end
	for _, c in { { -6, -22 }, { 6, -22 }, { -6, -6 }, { 6, -6 } } do
		T.boulder(bridge, Vector3.new(BXc + c[1], 0, c[2]), 1.3, rockAt, rng)
	end

	---------------------------------------------------------------- cliffs, walls, ridges
	local cliffs, walls, back = sub("Cliffs"), sub("Walls"), sub("Back")
	local scatter = sub("Scatter")
	local flows = sub("Flows")
	local tops, allCols = {}, {}
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
			href = 100,
		})
		T.walls(walls, cols, side, 100)
		allCols[side] = cols
		for _, c in cols do
			if c.h > 0 then
				local xm = (c.x0 + c.x1) / 2
				table.insert(tops, { side = side, x = xm, y = c.top + 1.4, z0 = c.lastFront + 3, z1 = c.back - 3 })
				-- glowing cracks in the rock (none once it has cooled)
				if cooling(xm) < 0.2 and c.h > 26 and rng:NextNumber() < 0.42 then
					T.faceCrack(flows, c, side, rng, MAG[rng:NextInteger(1, 2)], { neon = true, width = rng:NextNumber(0.45, 0.75) })
				end
				if cooling(xm) > 0.4 and rng:NextNumber() < 0.3 then
					T.faceCrack(flows, c, side, rng, hex("A9C6DE"), { width = 0.6 }) -- frost veins
				end
				if rng:NextNumber() < 0.4 then
					local r = rng:NextNumber(1.4, 3)
					T.boulder(scatter, Vector3.new(rng:NextNumber(c.x0 + 1, c.x1 - 1), 0, side * (c.front - r * 0.45)), r, rockAt, rng, { solid = r > 2.2 })
				end
			end
		end
		local row2 = T.ridgeRow(back, {
			side = side,
			xa = XA,
			xb = XB,
			minW = 12,
			maxW = 20,
			front = function(x)
				return edge[side](x) + 22
			end,
			back = function()
				return 214
			end,
			height = function(x)
				local n = T.n01(x / 25 + side * 4.1, 2.7, side)
				local xo = U(x)
				if side < 0 and xo > 518 and xo < 598 then
					return math.floor(22 + n * 10)
				end
				return math.floor(72 + n * 36)
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
		if side > 0 then -- the volcano fills the far south
			T.ridgeRow(back, {
				side = side,
				xa = XA,
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
					return math.floor(120 + T.n01(x / 41 + 2.9, 6.1, side) * 50)
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
	end

	---------------------------------------------------------------- lava cascades stepping down the ledges
	local function nearestCol(side, x)
		local best, bd
		for _, c in allCols[side] do
			local d = math.abs((c.x0 + c.x1) / 2 - x)
			if c.h > 30 and c.layers and #c.layers >= 3 and (not bd or d < bd) then
				best, bd = c, d
			end
		end
		return best
	end
	local nFalls = 0
	for _, f in { { 1, 522 }, { -1, 490 }, { 1, 556 }, { -1, 514 }, { 1, 478 }, { -1, 572 } } do
		local c = nearestCol(f[1], X(f[2]))
		if c then
			local foot = T.cascade(flows, c, f[1], { x = (c.x0 + c.x1) / 2, w = rng:NextNumber(1.3, 1.8), colors = FLOW, neon = true, rng = rng, name = "LavaFall" })
			if foot then
				local s = f[1]
				local puddle = K.box(flows, "LavaPuddle", foot.X - 3.5, foot.X + 3.5, 0, 0.12, foot.Z, foot.Z - s * 5, MAG[1], { neon = true, solid = false, shadow = false })
				K.box(flows, "LavaPuddle", foot.X - 2, foot.X + 2.6, 0, 0.14, foot.Z - s * 4.6, foot.Z - s * 7, MAG[2], { neon = true, solid = false, shadow = false })
				light(puddle, Color3.fromRGB(255, 120, 40), 18, 1.5)
				embers(puddle, 5, 35)
				nFalls += 1
			end
		end
	end
	table.insert(report, nFalls .. " lava cascades")

	---------------------------------------------------------------- obsidian spires
	local function spire(at, h, w, tilt, solidBase)
		local m = K.model(scatter, "ObsidianSpire")
		local a = rng:NextNumber(0, math.pi * 2)
		local lean = Vector3.new(math.cos(a), 0, math.sin(a)) * tilt
		local pts, widths = {}, {}
		local n = 4
		for i = 0, n do
			local t = i / n
			pts[i + 1] = at + Vector3.new(0, -1 + h * t, 0) + lean * h * t * t + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)) * (i > 0 and 1 or 0)
			if i < n then
				widths[i + 1] = w * (1 - t * 0.78)
			end
		end
		T.chain(m, "Obsidian", pts, widths, OBSIDIAN)
		if rng:NextNumber() < 0.6 then
			local y = h * rng:NextNumber(0.25, 0.55)
			K.part(m, "MagmaSeam", Vector3.new(0.5, h * 0.3, w * 0.55), CFrame.new(at + Vector3.new(0, y, 0) + lean * y * y / h) * CFrame.Angles(0, a, 0) * CFrame.new(w * 0.42, 0, 0), MAG[1], { neon = true, solid = false })
		end
		if solidBase then
			K.box(m, "SpireBase", at.X - w * 0.45, at.X + w * 0.45, -1, h * 0.35, at.Z - w * 0.45, at.Z + w * 0.45, OBSIDIAN[3], { transparency = 1 })
		end
		return m
	end
	for _, s in { { 497, 81, 26, 5.5 }, { 477, -79, 22, 5 }, { 592, 81, 30, 6 }, { 560, -70, 20, 4.5 }, { 522, 59, 16, 4 }, { 470, 70, 14, 3.5 }, { 532, -69, 14, 3.5 }, { 548, 72, 18, 4 }, { 508, -74, 16, 4 } } do
		spire(Vector3.new(X(s[1]), 0, s[2]), s[3], s[4], rng:NextNumber(0.05, 0.22), true)
	end

	---------------------------------------------------------------- a natural rock arch over the river, smoking cracks
	local arch = sub("RockArch")
	local APTS, AW = {}, {}
	local AXc = X(486) -- over the river
	for i = 0, 8 do
		local a = math.rad(8 + 164 * i / 8)
		APTS[i + 1] = Vector3.new(AXc + math.cos(a) * 13, -3 + math.sin(a) * 17, -54 + math.sin(a * 2) * 1.5)
		if i < 8 then
			AW[i + 1] = 5.2 - math.sin(math.pi * (i + 0.5) / 8) * 2.2
		end
	end
	local ARCH = {}
	for i = 1, 8 do
		ARCH[i] = tint(AXc, T.tone(ROCK, APTS[i], 0.35 + i * 0.03, rng))
	end
	T.chain(arch, "Arch", APTS, AW, ARCH)
	for _, e in { APTS[1], APTS[9] } do
		T.boulder(arch, Vector3.new(e.X, 0, e.Z), 3, rockAt, rng, { solid = true })
	end
	for _, c in { { 466, 36, 70 }, { 528, -36, 20 }, { 516, 44, 160 }, { 572, -40, 120 }, { 500, 30, 40 }, { 556, 40, 140 } } do
		local cx = X(c[1])
		if lavaGap(cx, c[2]) > 6 and pathGap(cx, c[2]) > 4 then
			T.crack(scatter, Vector3.new(cx, 0, c[2]), math.rad(c[3]), 4, rng, { dark = hex("201A1A"), glow = MAG[1] })
		end
	end

	---------------------------------------------------------------- the transition into Frostfang: steam vents, frosted rocks, cooled decor
	local trans = sub("Transition")
	for _, c in { { 600, 30, 40 }, { 606, -36, 100 }, { 614, 46, 160 }, { 596, -12, 70 } } do
		local cx = X(c[1])
		if pathGap(cx, c[2]) > 3 then
			T.crack(trans, Vector3.new(cx, 0, c[2]), math.rad(c[3]), 3, rng, { dark = hex("1F2128"), glow = hex("C25A2A"), smoke = Color3.fromRGB(235, 242, 250), smokeSize = 3, smokeOpacity = 0.22 })
		end
	end
	for _, at in { { 604, 52 }, { 612, -48 }, { 620, 30 }, { 618, -22 } } do
		local ax = X(at[1])
		local _, top = T.boulder(trans, Vector3.new(ax, 0, at[2]), rng:NextNumber(1.6, 2.4), rockAt, rng, { solid = true })
		K.box(trans, "SnowCap", ax - 1.8, ax + 1.8, top - 0.4, top + 0.5, at[2] - 1.6, at[2] + 1.6, SNOW[1], { studs = K.TOP, solid = false })
	end
	for _, d in decor:GetChildren() do
		if d:IsA("Model") and d.Name ~= "NestSignLava" and not d:GetAttribute("Weathered") then
			local f = cooling(d:GetBoundingBox().X)
			if f > 0 then
				for _, p in d:GetDescendants() do
					if p:IsA("BasePart") then
						if p.Material == Enum.Material.Neon then
							p.Material = Enum.Material.SmoothPlastic
							p.Color = p.Color:Lerp(hex("6A3A2A"), 0.7)
						end
						p.Color = p.Color:Lerp(FROST[2], f * 0.45)
					end
				end
				d:SetAttribute("Weathered", true)
			end
		end
	end

	---------------------------------------------------------------- the heights: spires, crystals, charred trees from the biome's own decor
	local pool = {}
	for _, d in decor:GetChildren() do
		if d:IsA("Model") and (d.Name == "CharredTree" or d.Name == "ObsidianSpire" or d.Name == "MagmaCrystal") then
			pool[d.Name] = pool[d.Name] or {}
			table.insert(pool[d.Name], d)
		end
	end
	local heights = sub("Heights")
	local nTop = 0
	for _, t in tops do
		if t.z1 > t.z0 and cooling(t.x) < 0.5 and not (t.side < 0 and U(t.x) > 524 and U(t.x) < 594) then
			local r = rng:NextNumber()
			local kind = r < 0.22 and "CharredTree" or (r < 0.4 and "ObsidianSpire" or (r < 0.5 and "MagmaCrystal" or nil))
			local list = kind and pool[kind]
			if list then
				local scale = (t.big and 2.4 or 1.7) * rng:NextNumber(0.85, 1.2)
				T.cloneProp(list[rng:NextInteger(1, #list)], scale, CFrame.new(t.x, t.y, t.side * rng:NextNumber(t.z0, t.z1)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)).Parent = heights
				nTop += 1
			end
		end
	end
	table.insert(report, nTop .. " props on the heights")

	---------------------------------------------------------------- the volcano
	local vol = sub("Volcano")
	local C = Vector3.new(X(556), 0, -330)
	local HT, R0, RT, NB, M = 290, 172, 32, 15, 9
	local VROCK = { hex("231B1D"), hex("2F2426"), hex("3B2D2B"), hex("4A3833") }
	local function R(y)
		return RT + (R0 - RT) * (1 - math.clamp(y / HT, 0, 1)) ^ 1.3
	end
	local CH = { { a0 = 72, amp = 10, ph = 0.3 }, { a0 = 98, amp = 13, ph = 2.1 }, { a0 = 122, amp = 9, ph = 4.0 } }
	local function chanAngle(c, k)
		return math.rad(c.a0 + math.sin(k * 0.75 + c.ph) * c.amp)
	end
	local function dirOf(a)
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local chanR = {}
	for k = 0, NB - 1 do
		local y0 = k == 0 and -40 or k * HT / NB
		local y1 = (k + 1) * HT / NB
		local ym = (math.max(y0, 0) + y1) / 2
		local Rk = R(ym)
		local phase = rng:NextNumber(0, math.pi * 2)
		for j = 0, M - 1 do
			local a = phase + j * math.pi * 2 / M + rng:NextNumber(-0.12, 0.12)
			local near = false
			for _, c in CH do
				local d = math.abs(((a - chanAngle(c, k)) + math.pi) % (math.pi * 2) - math.pi)
				if d < math.rad(30) then
					near = true
				end
			end
			local r = Rk * (near and rng:NextNumber(0.86, 0.98) or (1 + math.noise(a * 1.7, k * 0.5, 3.3) * 0.36))
			local top = y1 + (k < NB - 1 and rng:NextNumber(-5, 5) or 0)
			local w = 2 * r * math.tan(math.pi / M) * 1.18
			local d = dirOf(a)
			local ctr = C + d * (r / 2) + Vector3.new(0, (y0 + top) / 2, 0)
			local tone = VROCK[math.clamp(math.floor((ym / HT) * 3 + rng:NextNumber(0, 1.4)) + 1, 1, 4)]
			K.part(vol, "Slope", Vector3.new(w, top - y0, r), CFrame.lookAt(ctr, ctr + d), tone, { studs = K.SIDES, solid = false, shadow = false })
		end
		-- the ridge each lava channel runs down
		chanR[k] = {}
		for ci, c in CH do
			local a = chanAngle(c, k)
			local r = Rk * 1.08
			local d = dirOf(a)
			local ctr = C + d * (r / 2) + Vector3.new(0, (y0 + y1) / 2, 0)
			K.part(vol, "Slope", Vector3.new(r * 0.3, y1 - y0, r), CFrame.lookAt(ctr, ctr + d), VROCK[2], { studs = K.SIDES, solid = false, shadow = false })
			chanR[k][ci] = { a = a, r = r, y0 = math.max(y0, 0), y1 = y1 }
		end
	end
	-- each channel drapes over the slope from one ledge's outer edge to the next: a winding diagonal, not stairs
	for ci in CH do
		local pts, widths, cols = {}, {}, {}
		for k = NB - 1, 0, -1 do
			local e = chanR[k][ci]
			local d = dirOf(e.a)
			table.insert(pts, C + d * (e.r + 1.2) + Vector3.new(0, e.y1 + 0.6, 0))
		end
		local last = chanR[0][ci]
		table.insert(pts, C + dirOf(last.a) * (last.r + 10) + Vector3.new(0, -2, 0))
		for i = 1, #pts - 1 do
			widths[i] = 3 + (i / #pts) * 4.5
			cols[i] = FLOW[(i % 3) + 1]
		end
		T.chain(vol, "LavaChannel", pts, widths, cols, { neon = true, solid = false, shadow = false })
	end
	-- the jagged crater, fire, smoke, embers
	local rimN = 14
	for i = 0, rimN - 1 do
		local a = i / rimN * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local d = dirOf(a)
		local h = rng:NextNumber(5, 22)
		local w = 2 * RT * math.sin(math.pi / rimN) * 1.35
		local ctr = C + d * (RT * 0.9) + Vector3.new(0, HT + h / 2 - 1, 0)
		K.part(vol, "CraterRim", Vector3.new(w, h, rng:NextNumber(7, 11)), CFrame.lookAt(ctr, ctr + d) * CFrame.Angles(math.rad(rng:NextNumber(-12, 4)), 0, math.rad(rng:NextNumber(-8, 8))), VROCK[rng:NextInteger(1, 3)], { studs = K.SIDES, solid = false, shadow = false })
	end
	local core = K.part(vol, "CraterLava", Vector3.new(RT * 1.6, 3, RT * 1.6), CFrame.new(C + Vector3.new(0, HT - 0.5, 0)) * CFrame.Angles(0, math.rad(20), 0), MAG[1], { neon = true, solid = false, shadow = false })
	K.part(vol, "CraterLava", Vector3.new(RT * 1.2, 3.2, RT * 1.2), CFrame.new(C + Vector3.new(0, HT - 0.4, 0)) * CFrame.Angles(0, math.rad(55), 0), MAG[2], { neon = true, solid = false, shadow = false })
	light(core, Color3.fromRGB(255, 110, 30), 60, 3)
	local fire = Instance.new("Fire")
	fire.Size = 30
	fire.Heat = 25
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 10)
	fire.Parent = core
	local smoke = Instance.new("Smoke")
	smoke.Size = 80
	smoke.RiseVelocity = 25
	smoke.Opacity = 0.22
	smoke.Color = Color3.fromRGB(70, 60, 60)
	smoke.Parent = core
	local e = embers(core, 30, 50)
	e.Speed = NumberRange.new(20, 40)
	e.Lifetime = NumberRange.new(4, 6)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.6) })
	e.Acceleration = Vector3.new(0, -6, 0)

	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(report, "Lava Lagoon now " .. n .. " parts")
	return table.concat(report, "; ")
end
