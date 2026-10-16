-- Edit-time tool: splits kaiju body groups into finer groups for the animation engine (ReplicatedStorage.KaijuAnimation)
-- WITHOUT moving a single brick. Parts are only reparented into new sub-Models, and every new group is nested inside the
-- group its parts came from, so the old engine (Gameplay.KaijuFX / KaijuMotion) still moves them exactly as before.
-- Each new group gets a Joint attribute (build space, like KaijuSculpt's groups); spinner groups (rings, halos) also get
-- SpinAxis, the unit normal of their plane.
--   local R = require(game.ServerStorage.Tools.KaijuRegroup:Clone())
--   R.Apply(model)            the rules for model.Name (safe to run twice: a rule whose groups exist is skipped)
--   R.ApplyAsset(name)        the same on ServerStorage.Assets.Kaiju.<name>
--   R.Fingerprint(model)      a checksum of every brick's CFrame, size and colour (to prove nothing moved)
-- KaijuSculpt.Build calls Apply, so a rebuilt model keeps its grouping.
local R = {}

R.Version = 1

local function scaled(list, s)
	local out = {}
	for i, t in list do
		out[i] = Vector3.new(t[1], t[2], t[3]) * s
	end
	return out
end

local function mirrored(list)
	local out = {}
	for i, p in list do
		out[i] = Vector3.new(-p.X, p.Y, p.Z)
	end
	return out
end

-- parameter (0 at the first point, 1 at the last, by arc length) of the point on a polyline nearest to p, and the
-- distance to it
local function project(poly, p)
	local total, lens = 0, {}
	for i = 1, #poly - 1 do
		lens[i] = (poly[i + 1] - poly[i]).Magnitude
		total += lens[i]
	end
	local best, bestT, acc = math.huge, 0, 0
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		local ab = b - a
		local l2 = ab:Dot(ab)
		local u = l2 > 0 and math.clamp((p - a):Dot(ab) / l2, 0, 1) or 0
		local d = (p - (a + ab * u)).Magnitude
		if d < best then
			best, bestT = d, (acc + lens[i] * u) / total
		end
		acc += lens[i]
	end
	return bestT, best
end

local function pointAt(poly, t)
	local total = 0
	for i = 1, #poly - 1 do
		total += (poly[i + 1] - poly[i]).Magnitude
	end
	local want, acc = t * total, 0
	for i = 1, #poly - 1 do
		local l = (poly[i + 1] - poly[i]).Magnitude
		if acc + l >= want then
			return poly[i]:Lerp(poly[i + 1], l > 0 and (want - acc) / l or 0)
		end
		acc += l
	end
	return poly[#poly]
end

local function directParts(group)
	local out = {}
	for _, c in group:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(out, c)
		end
	end
	return out
end

local function findGroup(model, name)
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
	return nil
end

local function newGroup(parent, name, joint)
	local g = Instance.new("Model")
	g.Name = name
	g:SetAttribute("Joint", joint)
	g.Parent = parent
	return g
end

local function centroid(parts)
	local s = Vector3.zero
	for _, p in parts do
		s += p.Position
	end
	return #parts > 0 and s / #parts or Vector3.zero
end

-- unit normal of the plane that best fits the parts' centres (smallest eigenvector of their covariance, Jacobi)
local function planeNormal(parts)
	local c = centroid(parts)
	local a = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
	for _, p in parts do
		local d = p.Position - c
		local v = { d.X, d.Y, d.Z }
		for i = 1, 3 do
			for j = 1, 3 do
				a[i][j] += v[i] * v[j]
			end
		end
	end
	local vecs = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	for _ = 1, 30 do
		local p, q, off = 1, 2, 0
		for i = 1, 2 do
			for j = i + 1, 3 do
				if math.abs(a[i][j]) > off then
					off, p, q = math.abs(a[i][j]), i, j
				end
			end
		end
		if off < 1e-9 then
			break
		end
		local theta = 0.5 * math.atan2(2 * a[p][q], a[q][q] - a[p][p])
		local cs, sn = math.cos(theta), math.sin(theta)
		for k = 1, 3 do
			local akp, akq = a[k][p], a[k][q]
			a[k][p], a[k][q] = cs * akp - sn * akq, sn * akp + cs * akq
		end
		for k = 1, 3 do
			local apk, aqk = a[p][k], a[q][k]
			a[p][k], a[q][k] = cs * apk - sn * aqk, sn * apk + cs * aqk
		end
		for k = 1, 3 do
			local vkp, vkq = vecs[k][p], vecs[k][q]
			vecs[k][p], vecs[k][q] = cs * vkp - sn * vkq, sn * vkp + cs * vkq
		end
	end
	local best = 1
	for i = 2, 3 do
		if a[i][i] < a[best][best] then
			best = i
		end
	end
	local n = Vector3.new(vecs[1][best], vecs[2][best], vecs[3][best]).Unit
	-- a consistent sign: the axis points up, or back (+Z) when the plane stands upright
	if n.Y < -0.2 or (math.abs(n.Y) <= 0.2 and n.Z < 0) then
		n = -n
	end
	return n, c
end

-- Splits `group` into a chain of `#names` links (the first keeps the group itself), nested link in link. A part goes to
-- the link its position falls in along the chain: by `path` (a polyline from the root to the tip) when given, else by
-- its distance from the group's joint. cuts = the link boundaries as fractions of the chain's length.
local function chain(model, group, names, cuts, path)
	if not group or findGroup(model, names[2]) then
		return false
	end
	local joint = group:GetAttribute("Joint")
	local parts = directParts(group)
	if #parts < 6 or not joint then
		return false
	end
	local ts = {}
	if path then
		for i, p in parts do
			ts[i] = project(path, p.Position)
		end
	else
		local ds, maxD = {}, 0
		for i, p in parts do
			ds[i] = (p.Position - joint).Magnitude
		end
		local sorted = table.clone(ds)
		table.sort(sorted)
		maxD = sorted[math.max(1, math.floor(#sorted * 0.97))] -- ignore the odd outlier
		for i, d in ds do
			ts[i] = math.clamp(d / maxD, 0, 1)
		end
	end
	local links, parent = { group }, group
	for k = 2, #names do
		local cut = cuts[k - 1]
		local j
		if path then
			j = pointAt(path, cut)
		else
			local near = {}
			for i, p in parts do
				if math.abs(ts[i] - cut) < 0.07 then
					table.insert(near, p)
				end
			end
			if #near == 0 then
				local bestI, bestD = 1, math.huge
				for i in parts do
					if math.abs(ts[i] - cut) < bestD then
						bestI, bestD = i, math.abs(ts[i] - cut)
					end
				end
				near = { parts[bestI] }
			end
			j = centroid(near)
		end
		local g = newGroup(parent, names[k], j)
		table.insert(links, g)
		parent = g
	end
	for i, p in parts do
		local k = 1
		for c = 1, #cuts do
			if ts[i] >= cuts[c] then
				k = c + 1
			end
		end
		if k > 1 then
			p.Parent = links[k]
		end
	end
	return true
end

-- Moves the parts of `from` that pass `test` into a new group `name` (nested in `from`, or in `parentName`'s group).
-- spin = true: the joint is the parts' centre and SpinAxis the normal of their plane (or axisFrom's SpinAxis).
local function move(model, from, name, test, opts)
	if not from or findGroup(model, name) then
		return false
	end
	local picked = {}
	for _, p in directParts(from) do
		if test(p) then
			table.insert(picked, p)
		end
	end
	if #picked == 0 then
		return false
	end
	local joint, axis
	if opts.axisFrom then
		local src = findGroup(model, opts.axisFrom)
		joint = src and src:GetAttribute("Joint")
		axis = src and src:GetAttribute("SpinAxis")
	end
	if not joint then
		if opts.spin then
			axis, joint = planeNormal(picked)
		else
			joint = opts.joint or centroid(picked)
		end
	end
	local parent = opts.parentName and findGroup(model, opts.parentName) or from
	local g = newGroup(parent, name, joint)
	if axis then
		g:SetAttribute("SpinAxis", axis)
	end
	for _, p in picked do
		p.Parent = g
	end
	return true
end

local function named(keys)
	local set = {}
	for _, k in keys do
		set[k] = true
	end
	return function(p)
		return set[p.Name] == true
	end
end

-- three-link tails etc.: the base link keeps the group, the tip link is the shortest
local TAIL_CUTS = { 0.36, 0.68 }

local function tail3(model, name)
	return chain(model, findGroup(model, name), { name, name .. "2", name .. "3" }, TAIL_CUTS)
end

-- Krakling's tentacles: the spec's paths (x Scale 1.15), base to tip; R is the mirror of L
local KRAK = 1.15
local KRAK_PATHS = {
	LegFL = scaled({ { 0.5, 1.5, -0.5 }, { 1.3, 1.2, -1.1 }, { 1.9, 0.5, -1.5 }, { 2.3, 0.14, -1.9 }, { 2.56, 0.3, -2.22 }, { 2.46, 0.5, -2.36 } }, KRAK),
	LegBL = scaled({ { 0.55, 1.45, 0.4 }, { 1.4, 1.1, 0.9 }, { 2.0, 0.4, 1.3 }, { 2.4, 0.14, 1.75 }, { 2.66, 0.3, 2.06 }, { 2.56, 0.5, 2.2 } }, KRAK),
	ArmL = scaled({ { 0.6, 1.8, -0.56 }, { 1.5, 2.36, -0.96 }, { 1.92, 3.3, -0.96 }, { 1.84, 4.2, -0.66 }, { 1.44, 4.52, -0.36 }, { 1.16, 4.32, -0.24 } }, KRAK),
	TailL = scaled({ { 0.3, 1.4, 0.7 }, { 0.62, 0.9, 1.6 }, { 0.86, 0.32, 2.5 }, { 1.24, 0.14, 3.2 }, { 1.56, 0.34, 3.56 } }, KRAK),
}
KRAK_PATHS.LegFR = mirrored(KRAK_PATHS.LegFL)
KRAK_PATHS.LegBR = mirrored(KRAK_PATHS.LegBL)
KRAK_PATHS.ArmR = mirrored(KRAK_PATHS.ArmL)
KRAK_PATHS.TailR = mirrored(KRAK_PATHS.TailL)
local TENTACLE_CUTS = { 0.4, 0.72 }

-- Hydravine's three necks (spec x Scale 1.25), base to head: the middle one stays the Neck group (its head is Head);
-- the side necks become NeckLeft / NeckRight, each with its head as HeadLeft / HeadRight
local HYD = 1.25
local HYD_MID = scaled({ { 0, 0.86, 0.12 }, { 0, 1.38, -0.42 }, { 0, 2.2, -0.86 }, { 0, 3.0, -1.14 }, { 0, 3.62, -1.22 }, { 0, 3.72, -1.34 } }, HYD)
local HYD_SIDE = {
	[1] = scaled({ { 0.2, 0.74, 0.42 }, { 0.7, 1.0, -0.1 }, { 1.3, 1.5, -0.66 }, { 1.7, 2.2, -1.2 }, { 1.72, 2.92, -1.66 } }, HYD),
	[-1] = scaled({ { -0.2, 0.74, 0.42 }, { -0.9, 1.3, 0.2 }, { -1.6, 2.4, 0.08 }, { -2.0, 3.5, -0.12 }, { -1.94, 4.5, -0.36 } }, HYD),
}
local HYD_HEAD_AT = 0.8 -- along a side neck, from here on it is the head

local function hydra(model)
	local neck = findGroup(model, "Neck")
	if not neck or findGroup(model, "NeckLeft") then
		return false
	end
	local sides = {}
	for _, x in { 1, -1 } do
		local suffix = x == 1 and "Left" or "Right"
		local path = HYD_SIDE[x]
		local ng = newGroup(neck, "Neck" .. suffix, path[1])
		local hg = newGroup(ng, "Head" .. suffix, pointAt(path, HYD_HEAD_AT))
		sides[x] = { path = path, neck = ng, head = hg }
	end
	for _, p in directParts(neck) do
		local pos = p.Position
		local _, dm = project(HYD_MID, pos)
		local best, bestX, bestT = dm, 0, 0
		for _, x in { 1, -1 } do
			local t, d = project(sides[x].path, pos)
			-- the side heads are built big round their neck ends: count anything near the head as that head's
			local headEnd = sides[x].path[#sides[x].path]
			if (pos - headEnd).Magnitude < 1.9 then
				d = math.min(d, 0.2)
				t = math.max(t, HYD_HEAD_AT + 0.01)
			end
			if d < best then
				best, bestX, bestT = d, x, t
			end
		end
		if bestX ~= 0 then
			p.Parent = bestT >= HYD_HEAD_AT and sides[bestX].head or sides[bestX].neck
		end
	end
	return true
end

-- Raijin Wyrm's drum halo (in the Tail group, with the coils wound round it). The drums only cover three quarters of
-- the ring, so their centre is off: the joint is the ring's real centre from the spec, (C0 + LIFT) x Scale.
local RAIJIN_HALO_KEYS = named({ "Drum", "DrumDark", "DrumRim", "DrumHead", "Tomoe" })
local RAIJIN_HALO_CENTRE = Vector3.new(0, 3.05 + 0.9, 2.4) * 1.65

R.Rules = {
	Rumblerex = function(m) return tail3(m, "Tail") end,
	Pebblesaur = function(m) return tail3(m, "Tail") end,
	Chompling = function(m) return tail3(m, "Tail") end,
	Scorchback = function(m) return tail3(m, "Tail") end,
	BlazeBonkey = function(m) return tail3(m, "Tail") end,
	MoltenRex = function(m) return tail3(m, "Tail") end,
	Snowpup = function(m) return tail3(m, "Tail") end,
	IcebreakerRex = function(m) return tail3(m, "Tail") end,
	Mantisaur = function(m) return tail3(m, "Tail") end,
	Hammerjaw = function(m) return tail3(m, "Tail") end,
	Sparkit = function(m) return tail3(m, "Tail") end,
	Voltbeak = function(m) return tail3(m, "Tail") end,
	Voltkirin = function(m) return tail3(m, "Tail") end,
	-- Tidewyrm: the manta wings (inside Seg1) become WingL / WingR, each with an outer link (WingL2 / WingR2) from 3 studs
	-- out, so they can ripple from root to tip. Body bricks within 0.85 studs of the middle stay in Seg1.
	Tidewyrm = function(m)
		local seg = findGroup(m, "Seg1")
		if not seg or findGroup(m, "WingL") then
			return false
		end
		local WING = { Wing = true, WingDark = true, WingUnder = true, Glow = true }
		local inner, outer = { [1] = {}, [-1] = {} }, { [1] = {}, [-1] = {} }
		for _, p in directParts(seg) do
			local x = p.Position.X
			if WING[p.Name] and math.abs(x) > 0.85 then
				local s = x > 0 and 1 or -1
				table.insert(math.abs(x) >= 3 and outer[s] or inner[s], p)
			end
		end
		-- a joint on the wing's centre line at a given distance out (average height and depth of the bricks near it)
		local function jointAt(parts, s, x)
			local sum, n = Vector3.zero, 0
			for _, p in parts do
				if math.abs(math.abs(p.Position.X) - x) < 0.6 then
					sum += p.Position
					n += 1
				end
			end
			local c = n > 0 and sum / n or centroid(parts)
			return Vector3.new(s * x, c.Y, c.Z)
		end
		local any = false
		for _, s in { 1, -1 } do
			local suffix = s == 1 and "L" or "R"
			if #inner[s] > 0 then
				local g = newGroup(seg, "Wing" .. suffix, jointAt(inner[s], s, 1.1))
				for _, p in inner[s] do
					p.Parent = g
				end
				if #outer[s] > 0 then
					local all = table.clone(inner[s])
					for _, p in outer[s] do
						table.insert(all, p)
					end
					local g2 = newGroup(g, "Wing" .. suffix .. "2", jointAt(all, s, 3))
					for _, p in outer[s] do
						p.Parent = g2
					end
				end
				any = true
			end
		end
		return any
	end,
	-- Toxitops: the petal frill fanned behind its head becomes its own group, hinged at its base, so it can flare
	Toxitops = function(m)
		local a = tail3(m, "Tail")
		local b = move(m, findGroup(m, "Head"), "Frill", named({ "Petal", "Petal2", "PetalDark", "VeinGlow", "Groove", "Sac", "SacCore" }), { joint = Vector3.new(0, 2.2, -1.8) })
		return a or b
	end,
	Vinewhip = function(m) return tail3(m, "Tail") end,
	Sabrejag = function(m) return tail3(m, "Tail") end,
	Lurkfin = function(m) return tail3(m, "Tail") end,
	Stormgriff = function(m) return tail3(m, "Tail") end,
	Megajaw = function(m) return tail3(m, "Tail") end,
	Prismling = function(m) return tail3(m, "Tail") end,
	Cometshell = function(m)
		return chain(m, findGroup(m, "Tail"), { "Tail", "Tail2" }, { 0.5 })
	end,
	Tuskit = function(m) return tail3(m, "Trunk") end,
	Astrodon = function(m)
		local a = tail3(m, "Tail")
		local b = chain(m, findGroup(m, "Head"), { "Head", "Neck2", "Neck3", "HeadTop" }, { 0.3, 0.56, 0.78 })
		local body = findGroup(m, "Body")
		local c = move(m, body, "Ring", named({ "Ring", "RingDark", "RingLight" }), { spin = true })
		local d = move(m, body, "Moons", named({ "Moon", "MoonDark", "Rock", "RockDark" }), { axisFrom = "Ring", parentName = "Body" })
		return a or b or c or d
	end,
	RaijinWyrm = function(m)
		local tail = findGroup(m, "Tail")
		if not tail then
			return false
		end
		-- the drums first (they define the ring), then the bolts that jump between them (on the ring's radius, in its
		-- plane; the bolt at the tail's tip sits well inside the ring)
		local ok = move(m, tail, "Halo", RAIJIN_HALO_KEYS, { spin = true })
		local halo = findGroup(m, "Halo")
		if ok and halo then
			halo:SetAttribute("Joint", RAIJIN_HALO_CENTRE)
			local axis, c = halo:GetAttribute("SpinAxis"), halo:GetAttribute("Joint")
			for _, p in directParts(tail) do
				if p.Name == "Bolt" or p.Name == "BoltHot" then
					local d = p.Position - c
					local off = d:Dot(axis)
					local r = (d - axis * off).Magnitude
					if r > 1.9 and r < 3.1 and math.abs(off) < 0.5 then
						p.Parent = halo
					end
				end
			end
		end
		return ok
	end,
	Krakling = function(m)
		local any = false
		-- the two trailing tentacles share Tail: give each its own group first (Tail keeps its joint, now empty)
		local tail = findGroup(m, "Tail")
		if tail and not findGroup(m, "TailL") then
			move(m, tail, "TailL", function(p) return p.Position.X >= 0 end, { joint = KRAK_PATHS.TailL[1] })
			move(m, tail, "TailR", function(p) return p.Position.X < 0 end, { joint = KRAK_PATHS.TailR[1] })
			any = true
		end
		for name, path in KRAK_PATHS do
			local g = findGroup(m, name)
			if g and chain(m, g, { name, name .. "2", name .. "3" }, TENTACLE_CUTS, path) then
				any = true
			end
		end
		return any
	end,
	Hydravine = function(m) return hydra(m) end,
}

function R.Apply(model)
	local rule = R.Rules[model.Name]
	if not rule then
		return false
	end
	local changed = rule(model)
	model:SetAttribute("Regrouped", R.Version)
	return changed
end

function R.ApplyAsset(name)
	local m = game:GetService("ServerStorage").Assets.Kaiju:FindFirstChild(name)
	assert(m, "no asset " .. name)
	return R.Apply(m)
end

-- order-independent checksum of every brick's look and place (sum of rounded values, so reparenting can't change it)
function R.Fingerprint(model)
	local n, sum = 0, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			n += 1
			local cf, s, c = p.CFrame, p.Size, p.Color
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local v = x * 1.3 + y * 2.7 + z * 3.1 + r00 + r01 * 2 + r02 * 3 + r10 * 5 + r11 * 7 + r12 * 11 + r20 * 13 + r21 * 17 + r22 * 19
			v += s.X * 23 + s.Y * 29 + s.Z * 31 + c.R * 37 + c.G * 41 + c.B * 43 + p.Transparency * 47
			sum += math.floor(v * 1000 + 0.5)
		end
	end
	return n, sum
end

return R
