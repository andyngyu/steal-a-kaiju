-- Frostfang Peaks, refined (CanyonBuilder section "Refine"). Rebuilds the biome's ground and surroundings (x 627..827)
-- in place, keeping its contracts: Zone (now 188 wide), NestSite, Sign, Border, Decor's NestSignFrost, the Frozen Fangs.
--   Ground     snow in four whites with ice patches and exposed dark rock near the cliffs; a trodden path with blue-grey
--              slabs; frost over dark rock where it meets Lava Lagoon
--   Cliffs     dark grey-blue strata (snow on every ledge and cap, icy blue bands, deep-blue crevices, icicles), lower
--              round the glacier; frozen waterfalls; ridges and peaks behind
--   Glacier    the Frozen Titan: a giant kaiju in clear ice, dark against a glowing cyan back wall and lit from behind,
--              with a raised viewing ledge (ramp, rail, plaque) in front of it
--   Scatter    dark green pines with snow on their tiers, snowdrifts, ice-spike clusters, boulders
--   End        a rock wall closing the canyon (replaces the old EndCap until the next biome opens)
local ServerStorage = game:GetService("ServerStorage")
local hex = Color3.fromHex

return function(b, K, T)
	local P = K.P
	local model = b.model
	local rng = Random.new(9091)
	local XA, XB = 627, b.x1
	local HALF = 94
	local report = {}

	---------------------------------------------------------------- layout
	local GX0, GX1 = 738, 806 -- the glacier clearing
	local edge = {
		[1] = T.edge({ { 627, 65 }, { 636, 65 }, { 644, 72 }, { 652, 84 }, { 668, 86 }, { 676, 70 }, { 684, 64 }, { 694, 66 }, { 704, 74 }, { 716, 72 }, { 726, 70 }, { 734, 80 }, { 740, 92 }, { 804, 92 }, { 810, 80 }, { 816, 68 }, { 827, 65 } }),
		[-1] = T.edge({ { 627, 65 }, { 638, 64 }, { 646, 70 }, { 656, 82 }, { 676, 82 }, { 684, 68 }, { 692, 62 }, { 702, 66 }, { 714, 78 }, { 732, 80 }, { 740, 70 }, { 750, 64 }, { 762, 66 }, { 772, 76 }, { 790, 84 }, { 804, 84 }, { 812, 70 }, { 820, 65 }, { 827, 65 } }),
	}
	local function inGlacier(x)
		return x > GX0 + 1 and x < GX1 - 1
	end
	local function height(side, x)
		local n = T.n01(x / 18 + (side > 0 and 2.2 or 7.4), side * 4.3, 0.6)
		if side > 0 and inGlacier(x) then
			return 0 -- the glacier clearing
		end
		local h = 52 + n * 34
		if side > 0 and ((x > 724 and x <= GX0 + 1) or (x >= GX1 - 1 and x < 818)) then
			h = 30 + n * 12 -- low either side of the glacier
		end
		if x < 642 or x > 814 then
			h = math.max(h, 66 + n * 12)
		end
		return math.floor(h / 2 + 0.5) * 2
	end
	local PATHS = {
		{ { 627, 0, 14 }, { 642, 8, 12 }, { 660, 13, 11 }, { 678, 6, 12 }, { 696, -6, 12 }, { 714, -8, 12 }, { 723, -2, 12 } },
		{ { 723, -2, 8 }, { 729, 9, 7 }, { 738, 14, 7 }, { 748, 10, 7 }, { 754, 2, 8 } },
		{ { 723, -2, 8 }, { 729, -11, 7 }, { 738, -15, 7 }, { 748, -11, 7 }, { 754, -2, 8 } },
		{ { 754, 0, 12 }, { 770, 8, 12 }, { 788, 4, 12 }, { 804, -6, 12 }, { 818, -4, 12 }, { 827, 0, 13 } },
		{ { 770, 8, 7 }, { 771, 40, 7 }, { 771, 62, 7 } }, -- to the glacier's viewing ledge
		{ { 660, 13, 6 }, { 662, 44, 6 }, { 660, 74, 6 } }, -- into the north pocket
	}
	local function pathGap(x, z)
		local best = math.huge
		for _, p in PATHS do
			local d, half = T.polyDistance(p, x, z)
			best = math.min(best, d - half)
		end
		return best
	end
	local nest = model:FindFirstChild("NestSite")
	local NEST = nest and nest:GetPivot().Position or Vector3.new(737, 0, 0)
	local function nearNest(x, z, r)
		return (Vector3.new(x, 0, z) - Vector3.new(NEST.X, 0, NEST.Z)).Magnitude < r
	end
	local LEDGE = { x0 = 752, x1 = 790, z0 = 70, z1 = 88, h = 4 }
	local function onLedge(x, z, m)
		m = m or 0
		return x > LEDGE.x0 - m and x < LEDGE.x1 + m and z > LEDGE.z0 - 8 - m and z < LEDGE.z1 + m
	end

	---------------------------------------------------------------- colours
	local ROCK = { hex("2A3342"), hex("3E4A5E"), hex("5A6880"), hex("7E8DA4"), accent = hex("A3C6E6") }
	local SNOW = { hex("F4FAFF"), hex("E6F1FA"), hex("DCEAF6"), hex("EEF6FC") }
	local ICE = { hex("C4E4F6"), hex("B4D8EE") }
	local BARE = { hex("5A6578"), hex("4A5466") }
	local TROD = { hex("C8D6E4"), hex("B8C8D8"), hex("D2DEEA") }
	local SLABS = { hex("7D8CA0"), hex("6A7A8E"), hex("8E9CB0") }
	local FROSTY = { hex("34323D"), hex("B8CCDC"), hex("C9DAE8") }
	local CAPS = { hex("FFFFFF"), hex("F2F8FD"), hex("E6F0F8") }
	local PINE = { hex("1F4D33"), hex("255A3B"), hex("2C6644") }
	local GLOW = hex("8FE8FF")
	local CREVICE = hex("1E3A66")
	local function capColor(_, r)
		return CAPS[r:NextInteger(1, #CAPS)]
	end
	local function rockAt(pos, t)
		return T.tone(ROCK, pos, 0.2 + t * 0.6, rng)
	end
	local function snowAt()
		return SNOW[rng:NextInteger(1, #SNOW)]
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

	---------------------------------------------------------------- clear the old version
	for _, n in { "Cliffs", "Landmark", "Dress", "Refined" } do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local endCap = workspace.Map.Lane:FindFirstChild("EndCap")
	if endCap then
		endCap:Destroy()
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
	local REMOVE = { Trail = true, Pebble = true, WallRock = true, Cap = true, IceFall = true, Icicles = true }
	local removed, kept = 0, 0
	for _, d in decor:GetChildren() do
		local pos
		if d:IsA("Model") then
			pos = d:GetBoundingBox().Position
		elseif d:IsA("BasePart") then
			pos = d.Position
		end
		if pos and d.Name ~= "NestSignFrost" then
			local side = pos.Z >= 0 and 1 or -1
			if REMOVE[d.Name] or math.abs(pos.Z) > edge[side](pos.X) - 3 or pathGap(pos.X, pos.Z) < 1 or onLedge(pos.X, pos.Z, 3) then
				d:Destroy()
				removed += 1
			else
				kept += 1
			end
		end
	end
	table.insert(report, string.format("decor: %d removed, %d kept", removed, kept))
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
		z0 = -100,
		z1 = 100,
		keep = function(x, z)
			local side = z >= 0 and 1 or -1
			return math.abs(z) < edge[side](x) + 8
		end,
		color = function(x, z)
			local n = T.n01(x / 13 + 6.1, z / 13 + 2.3, 0.4)
			local n2 = T.n01(x / 9 + 1.9, z / 9 + 8.8, 0.1)
			local side = z >= 0 and 1 or -1
			if pathGap(x, z) <= 0 and not nearNest(x, z, 11) then
				return TROD[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end
			-- where it meets Lava Lagoon: frost over dark rock
			local f = math.clamp((650 - x) / 23, 0, 1)
			if f > 0 and n2 < f * 1.3 - 0.1 then
				return FROSTY[n2 < f * 0.6 - 0.2 and 1 or (n < 0.5 and 2 or 3)]
			end
			if math.abs(z) > edge[side](x) - 9 and n2 < 0.42 then
				return BARE[n < 0.5 and 1 or 2]
			end
			if n2 > 0.8 and not nearNest(x, z, 16) then
				return ICE[n < 0.5 and 1 or 2]
			end
			return SNOW[math.clamp(math.floor(n * 4) + 1, 1, 4)]
		end,
		fine = function(x, z)
			return pathGap(x, z) <= 0 and not nearNest(x, z, 11)
		end,
	})
	table.insert(report, nGround .. " ground pieces")
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
				if rng:NextNumber() < 0.65 and not nearNest(at.X, at.Z, 13) then
					local sz = Vector3.new(rng:NextNumber(2.4, 3.8), 0.26, rng:NextNumber(2.2, 3.2))
					local s = K.part(path, "Flagstone", sz, CFrame.new(at.X, 0.07, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), SLABS[rng:NextInteger(1, 3)], { studs = K.TOP, solid = false })
					for _, tx in s:GetChildren() do
						tx.StudsPerTileU, tx.StudsPerTileV = 2, 2
					end
				end
				t += pi >= 5 and 3.6 or 4.4
			end
		end
	end

	---------------------------------------------------------------- pines
	local function pine(parent, at, h, solidTrunk)
		local m = K.model(parent, "Pine")
		local tw = math.max(0.8, h * 0.09)
		K.box(m, "Trunk", at.X - tw, at.X + tw, at.Y - 0.5, at.Y + h * 0.3, at.Z - tw, at.Z + tw, hex("4A3424"), { studs = K.SIDES, solid = solidTrunk == true })
		local tiers = h > 14 and 4 or 3
		local y = at.Y + h * 0.2
		for i = 0, tiers - 1 do
			local t = i / tiers
			local w = h * 0.5 * (1 - t * 0.68)
			local th = h * 0.8 / tiers + 0.6
			local yaw = CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
			K.part(m, "Needles", Vector3.new(w, th, w), CFrame.new(at.X, y + th / 2, at.Z) * yaw, PINE[(i % #PINE) + 1], { studs = K.SIDES, solid = false })
			K.part(m, "Snow", Vector3.new(w * 0.86, 0.6, w * 0.86), CFrame.new(at.X, y + th + 0.25, at.Z) * yaw, SNOW[1], { studs = K.TOP, solid = false })
			K.part(m, "SnowDrip", Vector3.new(w * 0.4, th * 0.35, 0.4), CFrame.new(at.X, y + th * 0.85, at.Z) * yaw * CFrame.new(w * 0.15, 0, w / 2 + 0.05), SNOW[2], { solid = false })
			y += th * 0.72
		end
		K.box(m, "Tip", at.X - h * 0.05, at.X + h * 0.05, y, y + h * 0.12, at.Z - h * 0.05, at.Z + h * 0.05, SNOW[1], { solid = false })
		return m
	end

	---------------------------------------------------------------- cliffs, walls, ridges
	local cliffs, walls, back = sub("Cliffs"), sub("Walls"), sub("Back")
	local scatter = sub("Scatter")
	local ice = sub("Ice")
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
			rng = rng,
			href = 100,
		})
		T.walls(walls, cols, side, 100)
		allCols[side] = cols
		for _, c in cols do
			if c.h > 0 then
				local xm = (c.x0 + c.x1) / 2
				table.insert(tops, { side = side, x = xm, y = c.top + 1.4, z0 = c.lastFront + 3, z1 = c.back - 3 })
				if c.h > 26 and rng:NextNumber() < 0.45 then
					T.faceCrack(ice, c, side, rng, CREVICE, { width = rng:NextNumber(0.8, 1.3) })
				end
				-- icicles off the cap
				for _ = 1, rng:NextInteger(1, 3) do
					local ix = rng:NextNumber(c.x0 + 0.6, c.x1 - 0.6)
					local len = rng:NextNumber(2, 5.5)
					local f = c.lastFront - 0.3
					K.box(ice, "Icicle", ix - 0.55, ix + 0.55, c.top - len, c.top + 0.2, side * (f - 0.5), side * (f + 0.6), ICE[1], { solid = false, shadow = false })
					K.box(ice, "IcicleTip", ix - 0.25, ix + 0.25, c.top - len - 1.6, c.top - len, side * (f - 0.25), side * (f + 0.25), SNOW[1], { solid = false, shadow = false })
				end
				-- a snowdrift or a boulder at the foot
				local r = rng:NextNumber()
				if r < 0.35 then
					local rr = rng:NextNumber(1.6, 3)
					local bm, top = T.boulder(scatter, Vector3.new(rng:NextNumber(c.x0 + 1, c.x1 - 1), 0, side * (c.front - rr * 0.45)), rr, rockAt, rng, { solid = rr > 2.2 })
					local bp = bm:GetBoundingBox().Position
					K.box(scatter, "SnowCap", bp.X - rr * 0.6, bp.X + rr * 0.6, top - 0.3, top + 0.5, bp.Z - rr * 0.5, bp.Z + rr * 0.5, SNOW[1], { studs = K.TOP, solid = false })
				elseif r < 0.75 then
					local x = rng:NextNumber(c.x0 + 1, c.x1 - 1)
					T.boulder(scatter, Vector3.new(x, -0.3, side * (c.front - 1.2)), rng:NextNumber(1.8, 3.2), snowAt, rng, { name = "Snowdrift" })
				end
			end
		end
		-- ridges behind (the glacier fills the north behind its clearing)
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
				if side > 0 and x > GX0 - 8 and x < GX1 + 8 then
					return 0
				end
				return math.floor(76 + T.n01(x / 25 + side * 6.3, 3.3, side) * 40)
			end,
			layers = 2,
			pal = ROCK,
			capColor = capColor,
			rng = rng,
			href = 150,
		})
		for _, c in row2 do
			table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top, z0 = c.front + 4, z1 = math.min(c.back - 4, c.front + 30), big = true })
		end
		T.ridgeRow(back, {
			side = side,
			xa = XA,
			xb = XB + 60,
			minW = 22,
			maxW = 36,
			front = function()
				return 204
			end,
			back = function()
				return 330
			end,
			height = function(x)
				return math.floor(130 + T.n01(x / 37 + side * 1.9, 8.2, side) * 70)
			end,
			layers = 3,
			far = true,
			pal = ROCK,
			capColor = capColor,
			rng = rng,
			href = 200,
		})
	end

	---------------------------------------------------------------- frozen waterfalls
	local function nearestCol(side, x)
		local best, bd
		for _, c in allCols[side] do
			local d = math.abs((c.x0 + c.x1) / 2 - x)
			if c.h > 34 and c.layers and #c.layers >= 3 and (not bd or d < bd) then
				best, bd = c, d
			end
		end
		return best
	end
	local nFalls = 0
	for _, f in { { 1, 690 }, { -1, 664 }, { -1, 726 }, { -1, 798 } } do
		local c = nearestCol(f[1], f[2])
		if c then
			local foot = T.cascade(ice, c, f[1], { x = (c.x0 + c.x1) / 2, w = rng:NextNumber(3, 4.2), colors = { hex("D6F0FF"), hex("BFE6FF"), hex("E8F7FF") }, transparency = 0.12, rng = rng, name = "FrozenFall" })
			if foot then
				local s = f[1]
				K.box(ice, "FrozenPool", foot.X - 4.5, foot.X + 4.5, 0, 0.16, foot.Z, foot.Z - s * 6, hex("C4E8FA"), { studs = K.TOP, solid = false })
				for k = 0, 2 do
					local cx = foot.X + (k - 1) * 2.6
					K.part(ice, "IceSpike", Vector3.new(1, rng:NextNumber(2.5, 4.5), 1), CFrame.new(cx, 1.4, foot.Z - s * rng:NextNumber(1.5, 3.5)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, math.rad(rng:NextNumber(-15, 15))), hex("E8F7FF"), { solid = false })
				end
				nFalls += 1
			end
		end
	end
	table.insert(report, nFalls .. " frozen waterfalls")

	---------------------------------------------------------------- ice-spike clusters, drifts, pines in the pockets
	local function spikes(at, n, big)
		local m = K.model(scatter, "IceSpikes")
		for i = 1, n do
			local h = rng:NextNumber(big and 7 or 3.5, big and 16 or 8)
			local w = h * rng:NextNumber(0.16, 0.24)
			local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5)) * (i == 1 and 0 or 1)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-22, 22)))
			local base = CFrame.new(at + off) * tilt
			local glow = rng:NextNumber() < 0.35
			K.part(m, "Spike", Vector3.new(w, h * 0.65, w), base * CFrame.new(0, h * 0.32, 0), glow and GLOW or ICE[rng:NextInteger(1, 2)], { neon = glow, solid = false })
			K.part(m, "SpikeTip", Vector3.new(w * 0.55, h * 0.4, w * 0.55), base * CFrame.new(0, h * 0.78, 0), glow and hex("CFF6FF") or SNOW[1], { neon = glow, solid = false })
		end
		return m
	end
	for _, s in { { 664, 78, true }, { 668, -76, true }, { 706, 66 }, { 716, -72, true }, { 796, -78, true }, { 640, -58 }, { 812, 62 }, { 690, -40 } } do
		if pathGap(s[1], s[2]) > 3 and not nearNest(s[1], s[2], 18) then
			spikes(Vector3.new(s[1], 0, s[2]), s[3] and 5 or 3, s[3])
		end
	end
	local placed = 0
	for _ = 1, 80 do
		if placed >= 12 then
			break
		end
		local x, z = rng:NextNumber(640, 820), rng:NextNumber(-82, 84)
		local side = z >= 0 and 1 or -1
		if math.abs(z) < edge[side](x) - 6 and pathGap(x, z) > 4 and not nearNest(x, z, 18) and not onLedge(x, z, 4) then
			T.boulder(scatter, Vector3.new(x, -0.4, z), rng:NextNumber(1.6, 3.2), snowAt, rng, { name = "Snowdrift" })
			placed += 1
		end
	end
	local greens = sub("Pines")
	for _, p in { { 652, 80, 16 }, { 674, 80, 13 }, { 662, -78, 15 }, { 678, -77, 12 }, { 708, -74, 14 }, { 790, -80, 17 }, { 800, -80, 13 }, { 726, 68, 12 }, { 644, -66, 12 } } do
		if pathGap(p[1], p[2]) > 3 then
			pine(greens, Vector3.new(p[1], 0, p[2]), p[3], true)
		end
	end
	local nTop = 0
	for _, t in tops do
		if t.z1 > t.z0 and rng:NextNumber() < (t.big and 0.6 or 0.45) then
			for _ = 1, (t.big and rng:NextInteger(1, 2) or 1) do
				pine(greens, Vector3.new(t.x + rng:NextNumber(-3, 3), t.y, t.side * rng:NextNumber(t.z0, t.z1)), (t.big and rng:NextNumber(18, 28) or rng:NextNumber(11, 17)))
				nTop += 1
			end
		end
	end
	table.insert(report, nTop .. " pines on the heights")

	---------------------------------------------------------------- the glacier and the Frozen Titan
	local gl = sub("Glacier")
	local ICEW, ICEB, DEEP = hex("A3C6E6"), hex("BFE6FF"), hex("7FA6CC")
	local Z0, Z1, GH = 96, 168, 112
	-- the ice mass: side walls, back, top (layered, studded), the glowing back wall behind the kaiju
	for _, s in { { GX0 - 4, GX0 + 8 }, { GX1 - 8, GX1 + 4 } } do
		local y = -2
		while y < GH do
			local lh = math.min(GH - y, rng:NextInteger(9, 14))
			K.box(gl, "GlacierIce", s[1] - rng:NextNumber(0, 1.5), s[2] + rng:NextNumber(0, 1.5), y, y + lh, Z0 - rng:NextNumber(0, 2), Z1, ({ ICEW, ICEB, DEEP })[rng:NextInteger(1, 3)], { studs = K.SIDES })
			y += lh
		end
	end
	K.box(gl, "GlacierBack", GX0 + 8, GX1 - 8, -2, GH, Z1 - 14, Z1, DEEP, { studs = K.SIDES })
	local backGlow = K.box(gl, "BackGlow", GX0 + 8, GX1 - 8, 4, GH - 8, Z1 - 15, Z1 - 14, hex("6FD8FF"), { neon = true, solid = false, shadow = false })
	-- streaks of deeper blue across the glow, like cracks in the ice behind it
	for _ = 1, 7 do
		local sx, sy = rng:NextNumber(GX0 + 12, GX1 - 12), rng:NextNumber(10, GH - 14)
		K.part(gl, "IceVein", Vector3.new(rng:NextNumber(6, 14), 0.8, 0.3), CFrame.new(sx, sy, Z1 - 15.2) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-35, 35))), hex("3F9FD6"), { solid = false, shadow = false })
	end
	K.box(gl, "GlacierFloor", GX0 + 8, GX1 - 8, -2, 6, Z0, Z1 - 14, ICEW, { studs = K.TOP })
	local y = GH
	for i = 0, 2 do
		local inset = i * 6 + rng:NextNumber(0, 3)
		local lh = rng:NextInteger(6, 9)
		K.box(gl, "GlacierTop", GX0 - 4 + inset, GX1 + 4 - inset, y, y + lh, Z0 - 1 + inset * 0.6, Z1 - inset * 0.3, i == 2 and SNOW[1] or ICEB, { studs = K.ALL })
		K.box(gl, "GlacierSnow", GX0 - 4 + inset, GX1 + 4 - inset, y + lh, y + lh + 1.4, Z0 - 1 + inset * 0.6, Z1 - inset * 0.3, SNOW[1], { studs = K.TOP, solid = false })
		y += lh + 1.4
	end
	-- the kaiju: Icebreaker Rex, huge, dark ice-blue so it stands out against the glow; eyes glowing
	local src = ServerStorage.Assets.Kaiju:FindFirstChild("IcebreakerRex")
	if src then
		local k = src:Clone()
		for a in k:GetAttributes() do
			k:SetAttribute(a, nil)
		end
		local rootPart = k.PrimaryPart
		local DARK, MID = hex("0C1626"), hex("2A4468")
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
				if d == rootPart then
					d.Transparency = 1
				elseif d.Material == Enum.Material.Neon then
					d.Color = d.Name:find("Eye") and hex("BFF6FF") or MID
					if not d.Name:find("Eye") then
						d.Material = Enum.Material.SmoothPlastic
					end
				else
					local c = d.Color
					d.Color = DARK:Lerp(MID, math.clamp(0.299 * c.R + 0.587 * c.G + 0.114 * c.B, 0, 1))
				end
			elseif d:IsA("JointInstance") or d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			end
		end
		k:ScaleTo(k:GetScale() * 11)
		for _, t in k:GetDescendants() do
			if t:IsA("Texture") then
				t.StudsPerTileU *= 11
				t.StudsPerTileV *= 11
			end
		end
		local cx = (GX0 + GX1) / 2
		k:PivotTo(CFrame.lookAt(Vector3.new(cx, 6, 130), Vector3.new(cx - 14, 6, 0)) * CFrame.Angles(0, 0, math.rad(-6)))
		local kcf, ks = k:GetBoundingBox()
		k:PivotTo(k:GetPivot() + Vector3.new(cx - kcf.X, 6 - (kcf.Y - ks.Y / 2), (Z0 + 6) - (kcf.Z - ks.Z / 2)))
		k.Name = "FrozenTitan"
		k.Parent = gl
		table.insert(report, string.format("frozen titan %.0f tall", ks.Y))
	end
	-- light from behind and within
	light(backGlow, GLOW, 60, 5)
	local inner = K.part(gl, "InnerLight", Vector3.new(1, 1, 1), CFrame.new((GX0 + GX1) / 2, 60, Z1 - 24), GLOW, { solid = false, transparency = 1, shadow = false })
	light(inner, GLOW, 50, 3)
	-- the clear ice in front (solid), frost at its edges, icicles off the top
	K.box(gl, "ClearIce", GX0 + 8, GX1 - 8, -2, GH, Z0, Z0 + 4, hex("DFF4FF"), { transparency = 0.84, shadow = false })
	for _, e in { { GX0 + 8, GX0 + 14 }, { GX1 - 14, GX1 - 8 } } do
		K.box(gl, "FrostEdge", e[1], e[2], -2, GH, Z0 - 0.4, Z0 + 0.2, SNOW[2], { transparency = 0.35, solid = false, shadow = false })
	end
	K.box(gl, "FrostFoot", GX0 + 8, GX1 - 8, -2, 8, Z0 - 0.4, Z0 + 0.2, SNOW[2], { transparency = 0.3, solid = false, shadow = false })
	for ix = GX0 + 10, GX1 - 10, 4.5 do
		local len = rng:NextNumber(3, 10)
		K.box(gl, "Icicle", ix - 0.8, ix + 0.8, GH - len, GH, Z0 - 0.6, Z0 + 1, ICEB, { solid = false, shadow = false })
	end
	for i = 0, 5 do
		local cx = GX0 + 4 + i * 12
		local c = K.part(gl, "Crystal", Vector3.new(3, 9 + (i % 2) * 6, 3), CFrame.new(cx, y + 3 + (i % 2) * 3, Z0 + 10 + (i % 3) * 14) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, math.rad(rng:NextNumber(-15, 15))), GLOW, { neon = true, solid = false })
	end

	---------------------------------------------------------------- the viewing ledge
	local L = LEDGE
	K.box(gl, "ViewingLedge", L.x0, L.x1, -2, L.h, L.z0, L.z1, rockAt(Vector3.new(771, 2, 79), 0.2), { studs = K.SIDES })
	K.box(gl, "LedgeSnow", L.x0, L.x1, L.h, L.h + 0.5, L.z0, L.z1, SNOW[1], { studs = K.TOP })
	local ramp = Instance.new("WedgePart")
	ramp.Name = "LedgeRamp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(14, L.h + 0.5, 9)
	ramp.CFrame = CFrame.new(771, (L.h + 0.5) / 2, L.z0 - 4.5) -- rises towards +Z, onto the ledge
	ramp.Color = SNOW[2]
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.TopSurface = Enum.SurfaceType.Smooth
	K.studs(ramp, { K.N.Top })
	ramp.Parent = gl
	for _, rx in { { L.x0, 764 }, { 778, L.x1 } } do
		K.box(gl, "Rail", rx[1], rx[2], L.h + 0.5, L.h + 2.6, L.z0, L.z0 + 1.4, rockAt(Vector3.new(rx[1], 6, L.z0), 0.5), { studs = K.SIDES })
		K.box(gl, "RailSnow", rx[1], rx[2], L.h + 2.6, L.h + 3.1, L.z0 - 0.2, L.z0 + 1.6, SNOW[1], { solid = false })
	end
	K.box(gl, "Rail", L.x0, L.x1, L.h + 0.5, L.h + 2.2, L.z1 - 1.2, L.z1, rockAt(Vector3.new(771, 6, L.z1), 0.5), { studs = K.SIDES })
	K.box(gl, "RailSnow", L.x0, L.x1, L.h + 2.2, L.h + 2.7, L.z1 - 1.4, L.z1 + 0.2, SNOW[1], { solid = false })
	for _, lx in { L.x0 + 1.5, L.x1 - 1.5 } do
		K.box(gl, "LampPost", lx - 0.5, lx + 0.5, L.h + 0.5, L.h + 8, L.z1 - 1.5, L.z1 - 0.5, P.Iron, { solid = false })
		local lamp = K.box(gl, "Lamp", lx - 0.9, lx + 0.9, L.h + 8, L.h + 10, L.z1 - 1.9, L.z1 - 0.1, GLOW, { neon = true, solid = false })
		light(lamp, GLOW, 16, 1.2)
	end
	local plaque = K.sign(gl, "TitanPlaque", CFrame.lookAt(Vector3.new(771, L.h + 4.6, L.z1 - 1.8), Vector3.new(771, L.h + 4.6, 0)), 16, 3.2, "THE FROZEN TITAN", { cream = true })

	---------------------------------------------------------------- the end of the canyon
	local endW = sub("EndWall")
	local z = -100
	while z < 100 do
		local z1 = math.min(z + rng:NextInteger(8, 12), 100)
		local zm = (z + z1) / 2
		local H = math.floor(64 + T.n01(zm / 17 + 3.3, 9.1, 0.5) * 34)
		local yy, f = -2, XB + rng:NextNumber(0.3, 1.5)
		while yy < H - 0.5 do
			local lh = math.min(H - yy, rng:NextInteger(7, 12))
			K.box(endW, "Rock", f, XB + 34, yy, yy + lh, z, z1, rockAt(Vector3.new(f, yy + lh / 2, zm), (yy + lh / 2) / 100), { studs = K.SIDES, solid = yy + lh <= 24 })
			yy += lh
			f += rng:NextNumber(0, 4)
		end
		K.box(endW, "Cap", f - 0.6, XB + 34, H, H + 1.4, z, z1, CAPS[rng:NextInteger(1, 3)], { studs = K.ALL, solid = false })
		z = z1
	end
	local ew = K.box(endW, "InvisibleWall", XB, XB + 1, -2, 100, -100, 100, ROCK[1], { transparency = 1 })
	for _, t in ew:GetChildren() do
		t:Destroy()
	end
	ew.CanQuery, ew.CastShadow = false, false
	for _, p in { { XB - 6, 30, 15 }, { XB - 6, -40, 13 }, { XB - 5, 70, 12 }, { XB - 5, -72, 14 } } do
		pine(greens, Vector3.new(p[1], 0, p[2]), p[3], true)
	end

	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(report, "Frostfang Peaks now " .. n .. " parts")
	return table.concat(report, "; ")
end
