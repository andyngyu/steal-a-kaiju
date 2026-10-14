-- Shared shapes for the refined biomes (CanyonBuilder.<BiomeId> modules), in the game's studded-voxel look:
--   T.edge(points)        a smooth lane edge through { {x, distance}, ... } control points (pockets, spurs, clearings)
--   T.tone(pal, pos, t)   a rock colour from a 4-tone palette in large patches, darker low (t = height fraction), lighter high
--   T.ground(parent, o)   the floor as a 4-stud cell grid coloured per cell, merged into as few rectangles as possible
--   T.cliffRow(parent, o) the first row of cliffs along one side: columns of stacked strata with ledges, overhangs, caps
--   T.walls(parent, cols, side)  invisible walls along the exact rock fronts (the lane stays closed; no climbing out)
--   T.ridgeRow(parent, o) coarse rock masses further back (hills, ridges, far ranges)
--   T.massif(parent, o)   the same, rugged: sliced front to back, strata per slice, a crest profile, crags on top
--   T.boulder / T.cairn   rounded boulders and stacks;  T.arcBone / T.chain  bones and other bent shapes
--   T.wildflowers, T.footprint, T.crack, T.cloneProp
-- Everything inside the walkable area is non-colliding unless stated (guardians chase in straight lines).
local T = {}
local K

function T.init(kit)
	K = kit
	return T
end

local function smooth(t)
	return t * t * (3 - 2 * t)
end

function T.edge(points)
	return function(x)
		if x <= points[1][1] then
			return points[1][2]
		end
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			if x <= b[1] then
				return a[2] + (b[2] - a[2]) * smooth((x - a[1]) / (b[1] - a[1]))
			end
		end
		return points[#points][2]
	end
end

-- 0..1 noise
function T.n01(x, y, z)
	return math.clamp(math.noise(x, y, z) * 1.6 + 0.5, 0, 1)
end

function T.tone(pal, pos, t, rng)
	local n = math.clamp(math.noise(pos.X / 22 + 3.1, pos.Y / 16 + 0.7, pos.Z / 22 + 9.4) * 1.7, -0.5, 0.5)
	local score = t * 0.9 + n * 0.55
	local c
	if t < 0.03 or score < 0.16 then
		c = pal[1]
	elseif score < 0.42 then
		c = pal[2]
	elseif score < 0.68 then
		c = pal[3]
	else
		c = pal[4]
	end
	return K.shade(c, rng and rng:NextNumber(-0.03, 0.03) or 0)
end

local function clean(p)
	for _, t in p:GetChildren() do
		t:Destroy()
	end
	p.CanQuery = false
	p.CastShadow = false
	return p
end

------------------------------------------------------------------------------- ground
-- o: x0, x1, z0, z1, cell (4), keep(x, z) -> bool, color(x, z) -> Color3, fine(x, z) -> bool (2-stud studs), top (0)
function T.ground(parent, o)
	local cell = o.cell or 4
	local nx = math.ceil((o.x1 - o.x0) / cell - 1e-6)
	local nz = math.ceil((o.z1 - o.z0) / cell - 1e-6)
	local key, col, fin = {}, {}, {}
	for i = 1, nx do
		key[i] = {}
		for j = 1, nz do
			local x = o.x0 + (i - 0.5) * cell
			local z = o.z0 + (j - 0.5) * cell
			if o.keep(x, z) then
				local c = o.color(x, z)
				local f = o.fine and o.fine(x, z) or false
				local k = c:ToHex() .. (f and "f" or "")
				key[i][j] = k
				col[k], fin[k] = c, f
			end
		end
	end
	local used = {}
	local function isUsed(i, j)
		return used[i] and used[i][j]
	end
	local n = 0
	for j = 1, nz do
		for i = 1, nx do
			local k = key[i][j]
			if k and not isUsed(i, j) then
				local w = 1
				while i + w <= nx and key[i + w][j] == k and not isUsed(i + w, j) do
					w += 1
				end
				local h, grow = 1, true
				while grow and j + h <= nz do
					for ii = i, i + w - 1 do
						if key[ii][j + h] ~= k or isUsed(ii, j + h) then
							grow = false
							break
						end
					end
					if grow then
						h += 1
					end
				end
				for ii = i, i + w - 1 do
					used[ii] = used[ii] or {}
					for jj = j, j + h - 1 do
						used[ii][jj] = true
					end
				end
				local x0 = o.x0 + (i - 1) * cell
				local x1 = math.min(o.x1, o.x0 + (i - 1 + w) * cell)
				local z0 = o.z0 + (j - 1) * cell
				local z1 = math.min(o.z1, o.z0 + (j - 1 + h) * cell)
				local top = o.top or 0
				local p = K.box(parent, o.name or "Ground", x0, x1, top - 2, top, z0, z1, col[k], { studs = K.TOP })
				if fin[k] then
					for _, t in p:GetChildren() do
						if t:IsA("Texture") then
							t.StudsPerTileU, t.StudsPerTileV = 2, 2
						end
					end
				end
				n += 1
			end
		end
	end
	return n
end

------------------------------------------------------------------------------- cliffs
-- o: side, xa, xb, edge(x), height(x) (0 = open: no rock), depth(x), pal (+ pal.accent strata), capColor(x, rng),
--    tint(x, color) (optional), rng, minW / maxW, href (height for t = 1), solidTo (rock collides below this height)
function T.cliffRow(parent, o)
	local s, rng, pal = o.side, o.rng, o.pal
	local cols = {}
	local x = o.xa
	while x < o.xb - 0.01 do
		local x1 = math.min(x + rng:NextInteger(o.minW or 6, o.maxW or 10), o.xb)
		if o.xb - x1 < 4 then
			x1 = o.xb
		end
		local xm = (x + x1) / 2
		local e = o.edge(xm)
		local H = o.height(xm)
		local col = { x0 = x, x1 = x1, e = e, front = e, h = H, layers = {} }
		if H > 0 then
			local back = e + (o.depth and o.depth(xm) or 26)
			local y, prevF, top = -2, nil, nil
			while y < H - 0.5 do
				local lh = rng:NextInteger(7, 12)
				if H - (y + lh) < 4 then
					lh = H - y
				end
				local yb, yt = y, y + lh
				local nf
				if not prevF then
					nf = e + rng:NextNumber(0.5, 2)
				else
					local r = rng:NextNumber()
					if yb >= 12 and r < 0.22 then
						nf = math.max(e - 3.5, prevF - rng:NextNumber(2, 3.5)) -- overhang
					elseif r < 0.55 then
						nf = prevF + rng:NextNumber(0, 1.2)
					else
						nf = prevF + rng:NextNumber(3, 6.5) -- a ledge
					end
					nf = math.min(nf, back - 6)
				end
				local mid = (yb + yt) / 2
				local color
				if pal.accent and rng:NextNumber() < 0.13 then
					color = K.shade(pal.accent, rng:NextNumber(-0.04, 0.03))
				else
					color = T.tone(pal, Vector3.new(xm, mid, s * nf), mid / (o.href or 110), rng)
				end
				if o.tint then
					color = o.tint(xm, color)
				end
				K.box(parent, "Rock", x, x1, yb, yt, s * nf, s * back, color, { studs = K.SIDES, solid = yt <= (o.solidTo or 24) })
				table.insert(col.layers, { yb = yb, yt = yt, f = nf })
				if prevF and nf - prevF >= 2.5 then
					K.box(parent, "Ledge", x, x1, yb, yb + 0.9, s * (prevF - 0.3), s * nf, o.capColor(xm, rng), { studs = K.TOP, solid = false })
				end
				if not prevF then
					col.front = nf
				end
				prevF, top, y = nf, yt, yt
			end
			local capC = o.capColor(xm, rng)
			K.box(parent, "Cap", x - 0.3, x1 + 0.3, top, top + 1.4, s * (prevF - 0.6), s * back, capC, { studs = K.ALL, solid = false })
			for _ = 1, rng:NextInteger(0, 2) do
				local dw = rng:NextNumber(1.6, 3.2)
				local dx = rng:NextNumber(x + 0.3, math.max(x + 0.4, x1 - dw - 0.3))
				local dh = rng:NextNumber(1.5, 4.5)
				K.box(parent, "Drip", dx, dx + dw, top + 0.4 - dh, top + 1.4, s * (prevF - 0.7), s * (prevF + 0.2), capC, { studs = K.SIDES, solid = false })
			end
			col.top, col.lastFront, col.back = top, prevF, back
		end
		table.insert(cols, col)
		x = x1
	end
	return cols
end

-- a flow down a cliff column's face (lava, ice, water): a strip hugging each layer's face from the top down, running
-- across the ledges, wandering a little sideways, a little wider at the foot. o: x (centre), w, colors, neon,
-- transparency, rng, name. Returns the foot point (on the ground, in front of the column).
function T.cascade(parent, col, side, o)
	local rng = o.rng
	local L = col.layers
	if not L or #L == 0 then
		return nil
	end
	local x = o.x
	local lo, hi = col.x0 + 0.8, col.x1 - 0.8
	local opts = { neon = o.neon, transparency = o.transparency, solid = false, shadow = false }
	local top = col.top or L[#L].yt
	for i = #L, 1, -1 do
		local l = L[i]
		local yt = i == #L and top + 1.2 or l.yt
		-- short pieces that wander sideways and change width: a rivulet, not a stripe
		local y = yt
		while y > l.yb + 0.01 do
			local seg = math.min(y - l.yb, rng:NextNumber(2.4, 4.6))
			local w = math.min(o.w * rng:NextNumber(0.6, 1.15) * (1 + (#L - i) * 0.06), hi - lo)
			x = math.clamp(x + rng:NextNumber(-0.9, 0.9), lo + w / 2, hi - w / 2)
			local c = o.colors[rng:NextInteger(1, #o.colors)]
			K.box(parent, o.name or "Flow", x - w / 2, x + w / 2, y - seg, y, side * (l.f - 0.5), side * (l.f + 0.1), c, opts)
			y -= seg
		end
		local w = o.w
		-- the step down to the next layer's face (a ledge sticks out under it: run across its top)
		local nxt = L[i - 1]
		if nxt and nxt.f < l.f - 0.3 then
			K.box(parent, o.name or "Flow", x - w / 2, x + w / 2, l.yb - 0.1, l.yb + 0.45, side * (nxt.f - 0.5), side * (l.f + 0.1), o.colors[1], opts)
		end
	end
	return Vector3.new(x, 0, side * (L[1].f - 0.5))
end

-- a thin zigzag crack (glowing or dark) down a cliff column's face, over a few layers from near the top
function T.faceCrack(parent, col, side, rng, color, o)
	o = o or {}
	local L = col.layers
	if not L or #L < 2 then
		return
	end
	local x = rng:NextNumber(col.x0 + 1.2, col.x1 - 1.2)
	local start = math.max(1, #L - rng:NextInteger(0, 1))
	local stop = math.max(1, start - rng:NextInteger(1, 3))
	for i = start, stop, -1 do
		local l = L[i]
		local y = l.yt - 0.6
		while y > l.yb + 1 do
			local seg = math.min(rng:NextNumber(2, 3.6), y - l.yb)
			local a = rng:NextNumber(-0.55, 0.55)
			local dx = math.sin(a) * seg
			local nx = math.clamp(x + dx, col.x0 + 0.6, col.x1 - 0.6)
			local mid = Vector3.new((x + nx) / 2, y - seg / 2, side * (l.f - 0.08))
			K.part(parent, "Crack", Vector3.new(o.width or 0.55, seg + 0.3, 0.3), CFrame.new(mid) * CFrame.Angles(0, 0, -a), color, { neon = o.neon, solid = false, shadow = false })
			x, y = nx, y - seg
		end
	end
end

-- invisible walls along the rock fronts (and across the steps between columns), y -2 .. height
function T.walls(parent, cols, side, height)
	height = height or 100
	local W = Color3.new(1, 1, 1)
	for i, c in cols do
		clean(K.box(parent, "InvisibleWall", c.x0, c.x1, -2, height, side * c.front, side * (c.front + 1), W, { transparency = 1 }))
		local n = cols[i + 1]
		if n and math.abs(n.front - c.front) > 0.2 then
			local a, b = math.min(c.front, n.front), math.max(c.front, n.front)
			clean(K.box(parent, "InvisibleWall", c.x1 - 0.5, c.x1 + 0.5, -2, height, side * a, side * (b + 1), W, { transparency = 1 }))
		end
	end
end

-- coarse masses further back. o: side, xa, xb, minW, maxW, front(x), back(x), height(x), layers, pal, capColor, rng,
--    far (starts at y -40, no shadows), href, tint
function T.ridgeRow(parent, o)
	local s, rng = o.side, o.rng
	local cols = {}
	local x = o.xa
	while x < o.xb - 0.01 do
		local x1 = math.min(x + rng:NextInteger(o.minW or 12, o.maxW or 22), o.xb)
		if o.xb - x1 < 6 then
			x1 = o.xb
		end
		local xm = (x + x1) / 2
		local H = o.height(xm)
		if H > 0 then
			local f, b = o.front(xm) + rng:NextNumber(-2, 3), o.back(xm)
			local y = o.far and -40 or -2
			local L = o.layers or 2
			local fi = f
			for i = 1, L do
				local yt = i == L and H or (y + (H - y) * rng:NextNumber(0.4, 0.62))
				if i > 1 then
					fi = math.min(b - 6, fi + rng:NextNumber(2, 7))
				end
				local mid = (math.max(y, 0) + yt) / 2
				local color = T.tone(o.pal, Vector3.new(xm, mid, s * fi), mid / (o.href or 170), rng)
				if o.tint then
					color = o.tint(xm, color)
				end
				K.box(parent, "Ridge", x, x1, y, yt, s * fi, s * b, color, { studs = K.SIDES, solid = false, shadow = (not o.far) and nil or false })
				y = yt
			end
			K.box(parent, "RidgeCap", x - 0.4, x1 + 0.4, H, H + 1.8, s * (fi - 0.6), s * b, o.capColor(xm, rng), { studs = K.ALL, solid = false, shadow = (not o.far) and nil or false })
			table.insert(cols, { x0 = x, x1 = x1, top = H + 1.8, front = fi, back = b })
		end
		x = x1
	end
	return cols
end

-- rugged rock masses instead of flat-topped slabs: each column is cut into slices from front to back; every slice
-- rises in strata (patch tones, the sides nibbled so they aren't one plane), its height following a crest profile
-- (lower at the front and back, peaking somewhere in between), with crags now and then on the crest. Only the crest
-- slices get the cap colour. o: as ridgeRow, plus slice = { min, max } depth. Columns carry crestZ0 / crestZ1.
function T.massif(parent, o)
	local s, rng = o.side, o.rng
	local cols = {}
	local x = o.xa
	local shadow = (not o.far) and nil or false
	while x < o.xb - 0.01 do
		local x1 = math.min(x + rng:NextInteger(o.minW or 12, o.maxW or 22), o.xb)
		if o.xb - x1 < 6 then
			x1 = o.xb
		end
		local xm = (x + x1) / 2
		local H = o.height(xm)
		if H > 0 then
			local f, b = o.front(xm) + rng:NextNumber(-2, 3), o.back(xm)
			local D = math.max(b - f, 1)
			local y0 = o.far and -40 or -2
			local crestT = rng:NextNumber(0.25, 0.6)
			local z = f
			local best, c0, c1 = -math.huge, f, f
			while z < b - 0.01 do
				local dz = math.min(rng:NextNumber(o.slice and o.slice[1] or 10, o.slice and o.slice[2] or 18), b - z)
				if b - (z + dz) < 5 then
					dz = b - z
				end
				local t = (z + dz / 2 - f) / D
				local prof = 1 - math.abs(t - crestT) / math.max(crestT, 1 - crestT)
				local h = math.floor(H * (0.42 + 0.58 * prof) * rng:NextNumber(0.86, 1.08) / 2 + 0.5) * 2
				local L = h > 70 and 3 or 2
				local y = y0
				for i = 1, L do
					local yt = i == L and h or (y + (h - y) * rng:NextNumber(0.42, 0.62))
					local n0, n1 = rng:NextNumber(0, 1.8) * (i - 1), rng:NextNumber(0, 1.8) * (i - 1)
					local mid = (math.max(y, 0) + yt) / 2
					local color = T.tone(o.pal, Vector3.new(xm, mid, s * z), mid / (o.href or 170), rng)
					if o.tint then
						color = o.tint(xm, color)
					end
					K.box(parent, "Massif", x + n0, x1 - n1, y, yt, s * z, s * (z + dz), color, { studs = K.SIDES, solid = false, shadow = shadow })
					y = yt
				end
				if prof > 0.72 then
					K.box(parent, "MassifCap", x + 0.6, x1 - 0.6, h, h + 1.4, s * z, s * (z + dz), o.capColor(xm, rng), { studs = K.TOP, solid = false, shadow = false })
					if rng:NextNumber() < 0.35 then
						local cw = math.min(rng:NextNumber(3, 6), (x1 - x) - 1.4)
						local cx = rng:NextNumber(x + cw / 2 + 0.6, math.max(x + cw / 2 + 0.7, x1 - cw / 2 - 0.6))
						local ch = rng:NextNumber(6, 16)
						local crag = T.tone(o.pal, Vector3.new(cx, h + ch, s * z), 0.95, rng)
						K.box(parent, "Crag", cx - cw / 2, cx + cw / 2, h, h + ch, s * (z + dz * 0.2), s * (z + dz * 0.8), o.tint and o.tint(xm, crag) or crag, { studs = K.SIDES, solid = false, shadow = shadow })
					end
				end
				if h > best then
					best, c0, c1 = h, z, z + dz
				end
				z += dz
			end
			table.insert(cols, { x0 = x, x1 = x1, top = best + 1.4, front = f, back = b, crestZ0 = c0, crestZ1 = c1 })
		end
		x = x1
	end
	return cols
end

------------------------------------------------------------------------------- rocks
-- a rounded boulder on the ground at pos (sunk a little); returns the model and the height of its top above pos
function T.boulder(parent, pos, r, colorAt, rng, o)
	o = o or {}
	local m = K.model(parent, o.name or "Boulder")
	local F = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local sink = r * 0.25
	local function bp(size, off, t)
		local cf = F * CFrame.new(off)
		K.part(m, "Stone", size, cf, colorAt(cf.Position, t), { studs = K.ALL, solid = o.solid })
	end
	bp(Vector3.new(2 * r, 0.9 * r, 1.7 * r), Vector3.new(0, 0.45 * r - sink, 0), 0.15)
	bp(Vector3.new(1.6 * r, 0.9 * r, 2.05 * r), Vector3.new(0.05 * r, 0.75 * r - sink, 0), 0.35)
	bp(Vector3.new(1.45 * r, 0.7 * r, 1.3 * r), Vector3.new(-0.05 * r, 1.3 * r - sink, 0.05 * r), 0.7)
	if o.moss then
		K.part(m, "Moss", Vector3.new(1.15 * r, 0.3 * r, 1.0 * r), F * CFrame.new(-0.05 * r, 1.7 * r - sink, 0.05 * r), o.moss, { studs = K.TOP, solid = false })
	end
	return m, 1.65 * r - sink
end

-- a stack of rounded stones, biggest at the bottom
function T.cairn(parent, pos, radii, colorAt, rng, o)
	o = o or {}
	local m = K.model(parent, o.name or "PebbleStack")
	local at = pos
	for i, r in radii do
		local p = at + Vector3.new(rng:NextNumber(-0.2, 0.2) * r, 0, rng:NextNumber(-0.2, 0.2) * r)
		local _, top = T.boulder(m, p, r, colorAt, rng, { solid = o.solid and i <= (o.solidCount or 2), moss = i == #radii and o.moss or nil })
		at = Vector3.new(p.X, p.Y + top, p.Z)
	end
	return m
end

------------------------------------------------------------------------------- bent shapes
-- tapering blocks through points; widths per segment; colours cycle
function T.chain(parent, name, pts, widths, colors, o)
	o = o or { studs = K.SIDES, solid = false }
	for i = 1, #pts - 1 do
		local a, c = pts[i], pts[i + 1]
		local d = c - a
		local w = widths[math.min(i, #widths)]
		local mid = (a + c) / 2
		K.part(parent, name, Vector3.new(w, d.Magnitude + w * 0.45, w), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.rad(90), 0, 0), colors[(i - 1) % #colors + 1], o)
	end
end

-- a bone arching out of the ground: an arc of radius R in the vertical plane through `centre` (turned by yaw), from
-- angle a0 to a1 (degrees, 0 = along the plane's +X, 90 = up); put the centre below ground to bury the ends
function T.arcBone(parent, centre, yaw, R, a0, a1, w0, w1, colors, segs)
	segs = segs or 5
	local F = CFrame.new(centre) * CFrame.Angles(0, yaw, 0)
	local pts, widths = {}, {}
	for i = 0, segs do
		local a = math.rad(a0 + (a1 - a0) * i / segs)
		pts[i + 1] = F:PointToWorldSpace(Vector3.new(math.cos(a) * R, math.sin(a) * R, 0))
		if i < segs then
			widths[i + 1] = w0 + (w1 - w0) * i / math.max(1, segs - 1)
		end
	end
	T.chain(parent, "Bone", pts, widths, colors)
end

------------------------------------------------------------------------------- small things
function T.wildflowers(parent, centre, radius, n, colors, stem, rng)
	local m = K.model(parent, "Wildflowers")
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * radius
		local x, z = centre.X + math.cos(a) * d, centre.Z + math.sin(a) * d
		local h = rng:NextNumber(0.9, 2.1)
		K.box(m, "Stem", x - 0.22, x + 0.22, 0, h, z - 0.22, z + 0.22, stem, { solid = false })
		local b = rng:NextNumber(0.55, 0.8)
		K.box(m, "Bloom", x - b, x + b, h, h + 0.65, z - b, z + b, colors[rng:NextInteger(1, #colors)], { studs = K.TOP, solid = false })
	end
	return m
end

-- a giant three-toed footprint pressed into the ground, toes towards `dir` (a flat Vector3); L = its length
function T.footprint(parent, pos, dir, L, c)
	local m = K.model(parent, "Footprint")
	local F = CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(pos.X, 0, pos.Z) + dir)
	local function flat(name, w, len, at, yaw, color, y, h)
		K.part(m, name, Vector3.new(w, h or 0.12, len), F * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(at.X, y or 0.06, at.Y), color, { studs = K.TOP, solid = false })
	end
	-- the heel pad (looking down the toes: local -Z is forward)
	flat("Pad", L * 0.4, L * 0.32, Vector2.new(0, L * 0.2), 0, c.mud)
	flat("Pad", L * 0.28, L * 0.44, Vector2.new(0, L * 0.18), 0, c.mud)
	flat("PadDeep", L * 0.2, L * 0.22, Vector2.new(0, L * 0.2), 0, c.deep, 0.08, 0.13)
	for _, t in { { 0, 0.5 }, { -32, 0.4 }, { 32, 0.4 } } do
		local yaw = math.rad(t[1])
		local len = L * t[2]
		flat("Toe", L * 0.13, len, Vector2.new(0, -len / 2 + L * 0.02), yaw, c.mud)
		flat("Claw", L * 0.07, L * 0.12, Vector2.new(0, -len - L * 0.04), yaw, c.deep, 0.08, 0.13)
	end
	-- the soil pushed up round it
	for _, r in { { 0, L * 0.42, L * 0.36, L * 0.07 }, { -L * 0.25, L * 0.15, L * 0.07, L * 0.34 }, { L * 0.25, L * 0.15, L * 0.07, L * 0.34 } } do
		flat("Rim", r[3], r[4], Vector2.new(r[1], r[2]), 0, c.rim, 0.25, 0.5)
	end
	return m
end

-- a zigzag crack on the ground with a glowing core and smoke rising from it
function T.crack(parent, start, yaw, n, rng, c)
	local m = K.model(parent, "SmokingCrack")
	local p = Vector3.new(start.X, 0, start.Z)
	local mid
	for i = 1, n do
		local a = yaw + rng:NextNumber(-0.7, 0.7)
		local len = rng:NextNumber(3, 6)
		local d = Vector3.new(math.sin(a), 0, math.cos(a)) * len
		local cf = CFrame.lookAt(p + d / 2, p + d)
		K.part(m, "Crack", Vector3.new(1.3, 0.14, len + 0.5), cf + Vector3.new(0, 0.07, 0), c.dark, { solid = false })
		K.part(m, "Glow", Vector3.new(0.4, 0.16, len), cf + Vector3.new(0, 0.09, 0), c.glow, { neon = true, solid = false })
		if i == math.ceil(n / 2) then
			mid = p + d / 2
		end
		p += d
	end
	local a = K.part(m, "SmokeVent", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 0.5, 0)), c.dark, { solid = false, transparency = 1, shadow = false })
	local s = Instance.new("Smoke")
	s.Size = c.smokeSize or 2
	s.RiseVelocity = 4
	s.Opacity = c.smokeOpacity or 0.12
	s.Color = c.smoke or Color3.fromRGB(90, 82, 76)
	s.Parent = a
	return m
end

-- a copy of a decor model, scaled (stud textures too), standing on cf's point
function T.cloneProp(src, scale, cf)
	local c = src:Clone()
	if scale and scale ~= 1 then
		c:ScaleTo(c:GetScale() * scale)
		for _, t in c:GetDescendants() do
			if t:IsA("Texture") then
				t.StudsPerTileU *= scale
				t.StudsPerTileV *= scale
			end
		end
	end
	c:PivotTo(cf)
	local bb, size = c:GetBoundingBox()
	c:PivotTo(c:GetPivot() + Vector3.new(0, cf.Y - (bb.Y - size.Y / 2), 0))
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	return c
end

-- distance from (x, z) to the polyline pts { {x, z, width}, ... }; returns the distance and the half-width there
function T.polyDistance(pts, x, z)
	local best, half = math.huge, 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ax, az, bx, bz = a[1], a[2], b[1], b[2]
		local dx, dz = bx - ax, bz - az
		local L2 = dx * dx + dz * dz
		local t = L2 > 0 and math.clamp(((x - ax) * dx + (z - az) * dz) / L2, 0, 1) or 0
		local px, pz = ax + dx * t, az + dz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then
			best, half = d, (a[3] + (b[3] - a[3]) * t) / 2
		end
	end
	return best, half
end

return T
