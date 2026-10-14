-- Edit-time tool: builds the sculpted kaiju (2026-10-13 art direction: powerful, a bit intimidating monsters, "voxel but
-- sculpted"). Specs live in ServerStorage.Tools.KaijuSculptSpecs: per species a table with Palette, Joints, Parents,
-- Gait, Emotes, Seed, Vary (random value variation per block, e.g. 0.06), Scale (the whole build and its joints scaled
-- about the origin) and Build(K), a function that places the blocks through the API below.
--   require(game.ServerStorage.Tools.KaijuSculpt:Clone()).Build("Pebblesaur")   -> ServerStorage.Assets.Kaiju.Pebblesaur
-- Output contract (same as KaijuBuilder, so KaijuModel / KaijuFX / KaijuMotion / MutationVisuals / GoldVariant keep
-- working): Model facing -Z, PrimaryPart "Root" at the centre of the feet, body groups as sub-Models with a Joint
-- attribute (build space), spec.Parents nests groups (Jaw inside Head), attributes RootOffset / Gait / Emotes / Wag.
-- Blocks are free Parts at any angle (anchored, no collision): big core blocks for the mass, overlapping scale / armour
-- tiles laid around body tubes that follow smooth paths, blocks turned on their corner for spikes, plates and teeth,
-- tapered block chains for horns and claws.
--
-- API (K = the builder state handed to spec.Build):
--   K:block(group, colour, cframe, size [, name])        one block
--   K:path(nodes, step [, ref]) -> samples               Catmull-Rom path through nodes { x, y, z, rx =, ru =, rd = }
--                                                        (rx = side radius, ru / rd = up / down radius); ref = the
--                                                        sideways axis for steep paths (legs)
--   K:tube(group, nodes, opts) -> samples                core blocks + overlapping tiles + belly plates on a path:
--        opts.step (ring spacing), core (colour), coreCap (colour of the end stretches), coreEvery, tile = { w, l, t, lift, jitter, arc, sink, overlap },
--        color = fn(theta, ring, sample) -> colour or nil (theta 0 = top, +pi/2 = the R side), belly = { key, key2,
--        arc, t }, from / trim (arc length left bare at the start / end), ref
--   K:at(samples, s) -> sample                           the frame at arc length s: p, T (along), R (side), U (up), radii
--   K:surface(sample, theta [, inset]) -> pos, normal    a point on a tube's skin
--   K:spike(group, colour, base, dir, across, h, thick)  a block on its corner: a point h from base along dir
--   K:ridge(group, samples, opts)                        jagged double-point plates along a tube's top
--   K:chain(group, colours, base, dir, axis, opts)       a tapered chain of blocks bending about axis (horns, claws)
--   K:plate(group, colours, base, up, along, opts)       a stepped plate: layers narrowing and stepping back to a point
--   K:rand(a, b)                                         seeded random (the same build every time)
--   K:scaled(origin, s, fn)                              everything fn builds is scaled by s about origin
local ServerStorage = game:GetService("ServerStorage")

local KaijuSculpt = {}

local K = {}
K.__index = K

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local function v3(t)
	return typeof(t) == "Vector3" and t or Vector3.new(t[1], t[2], t[3])
end

-- builds everything fn places scaled by s about `origin` (a bigger head on the same neck, a heavier variant)
function K:scaled(origin, s, fn)
	table.insert(self.scales, { origin, s })
	fn()
	table.remove(self.scales)
end

function K:rand(a, b)
	return a + (b - a) * self.rng:NextNumber()
end

function K:group(name)
	local g = self.groups[name]
	if not g then
		g = Instance.new("Model")
		g.Name = name
		local joint = self.spec.Joints and self.spec.Joints[name]
		if joint then
			g:SetAttribute("Joint", v3(joint) * (self.spec.Scale or 1))
		end
		self.groups[name] = g
		local parentName = self.spec.Parents and self.spec.Parents[name]
		g.Parent = parentName and self:group(parentName) or self.model
	end
	return g
end

function K:block(group, key, cf, size, name)
	local pal = self.palette[key]
	assert(pal, "no palette colour " .. tostring(key))
	local stack = self.scales
	for i = #stack, 1, -1 do
		local o, s = stack[i][1], stack[i][2]
		cf = CFrame.new(o + (cf.Position - o) * s) * cf.Rotation
		size *= s
	end
	local p = Instance.new("Part")
	p.Name = name or key
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = cf
	local color = pal.color
	local vary = self.spec.Vary
	if vary and pal.material ~= Enum.Material.Neon then
		local v = self:rand(-vary, vary)
		color = v < 0 and color:Lerp(Color3.new(0, 0, 0), -v) or color:Lerp(Color3.new(1, 1, 1), v * 0.6)
	end
	p.Color = color
	p.Material = pal.material
	p.Transparency = pal.transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = self:group(group)
	self.count += 1
	return p
end

-- side (R) and up (U) axes for a direction T; ref = preferred side axis (else T x worldUp)
local function frame(T, ref)
	local R
	if ref then
		R = ref - T * ref:Dot(T)
	else
		R = T:Cross(Vector3.yAxis)
	end
	if R.Magnitude < 0.05 then
		R = Vector3.xAxis - T * T.X
	end
	R = R.Unit
	return R, R:Cross(T).Unit
end

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

function K:path(nodes, step, ref)
	local pts = {}
	for i, n in nodes do
		pts[i] = Vector3.new(n[1], n[2], n[3])
	end
	local count = #pts
	local dense = {}
	for i = 1, count - 1 do
		local p0 = pts[i - 1] or (2 * pts[i] - pts[i + 1])
		local p3 = pts[i + 2] or (2 * pts[i + 1] - pts[i])
		for k = 0, 23 do
			local t = k / 24
			table.insert(dense, { p = catmull(p0, pts[i], pts[i + 1], p3, t), g = i - 1 + t })
		end
	end
	table.insert(dense, { p = pts[count], g = count - 1 })
	dense[1].s = 0
	for j = 2, #dense do
		dense[j].s = dense[j - 1].s + (dense[j].p - dense[j - 1].p).Magnitude
	end
	local total = dense[#dense].s
	local n = math.max(1, math.floor(total / step + 0.5))
	local samples = { total = total, ref = ref }
	local j = 1
	for k = 0, n do
		local s = total * k / n
		while j < #dense - 1 and dense[j + 1].s < s do
			j += 1
		end
		local a, b = dense[j], dense[j + 1]
		local f = b.s > a.s and math.clamp((s - a.s) / (b.s - a.s), 0, 1) or 0
		local g = a.g + (b.g - a.g) * f
		local seg = math.clamp(math.floor(g) + 1, 1, count - 1)
		local t = g - (seg - 1)
		local na, nb = nodes[seg], nodes[seg + 1]
		local rxa, rxb = na.rx or 0.5, nb.rx or 0.5
		local rua, rub = na.ru or rxa, nb.ru or rxb
		local rda, rdb = na.rd or rua, nb.rd or rub
		local T = (b.p - a.p).Unit
		local R, U = frame(T, ref)
		table.insert(samples, {
			p = a.p:Lerp(b.p, f),
			T = T,
			R = R,
			U = U,
			rx = rxa + (rxb - rxa) * t,
			ru = rua + (rub - rua) * t,
			rd = rda + (rdb - rda) * t,
			s = s,
			u = total > 0 and s / total or 0,
			i = k + 1,
		})
	end
	return samples
end

function K:at(samples, s)
	s = math.clamp(s, 0, samples.total)
	local i = 1
	while i < #samples - 1 and samples[i + 1].s < s do
		i += 1
	end
	local a, b = samples[i], samples[i + 1] or samples[i]
	local f = b.s > a.s and (s - a.s) / (b.s - a.s) or 0
	local T = (b.p - a.p).Magnitude > 1e-4 and (b.p - a.p).Unit or a.T
	local R, U = frame(T, samples.ref)
	return {
		p = a.p:Lerp(b.p, f),
		T = T,
		R = R,
		U = U,
		rx = a.rx + (b.rx - a.rx) * f,
		ru = a.ru + (b.ru - a.ru) * f,
		rd = a.rd + (b.rd - a.rd) * f,
		s = s,
		u = a.u + (b.u - a.u) * f,
		i = a.i,
	}
end

function K:surface(smp, theta, inset)
	local c, s = math.cos(theta), math.sin(theta)
	local ry = c >= 0 and smp.ru or smp.rd
	local pos = smp.p + smp.U * (c * ry) + smp.R * (s * smp.rx)
	local n = (smp.U * (c / ry) + smp.R * (s / smp.rx)).Unit
	return pos - n * (inset or 0), n
end

-- angles of n tiles spread evenly by arc length over [a0, a1]; `shift` (in tiles) staggers alternate rings, `wrap`
-- for full rings
local function spread(self, smp, a0, a1, n, shift, wrap)
	local steps = 48
	local cum = { 0 }
	local prev = self:surface(smp, a0)
	for k = 1, steps do
		local pt = self:surface(smp, a0 + (a1 - a0) * k / steps)
		cum[k + 1] = cum[k] + (pt - prev).Magnitude
		prev = pt
	end
	local perim = cum[steps + 1]
	local out = {}
	for k = 0, n - 1 do
		local target = (k + 0.5 + (shift or 0)) / n * perim
		if wrap then
			target %= perim
		else
			target = math.clamp(target, 0, perim)
		end
		local j = 1
		while j < steps and cum[j + 1] < target do
			j += 1
		end
		local f = (target - cum[j]) / math.max(cum[j + 1] - cum[j], 1e-6)
		table.insert(out, a0 + (a1 - a0) * (j - 1 + f) / steps)
	end
	return out, perim
end

-- a tile on the skin at angle theta: flat, tangent, its rear edge (towards the path's end) lifted like a shingle
function K:tile(group, key, smp, theta, w, l, t, lift, jitter, sink)
	local pos, nrm = self:surface(smp, theta, t * (sink or 0.3))
	local along = smp.T - nrm * smp.T:Dot(nrm)
	if along.Magnitude < 1e-3 then
		return nil
	end
	along = along.Unit
	local j = math.rad(jitter or 4)
	local cf = CFrame.fromMatrix(pos, nrm:Cross(along), nrm)
		* CFrame.Angles(-math.rad(lift or 10) + self:rand(-j, j), self:rand(-j, j), self:rand(-j, j))
	return self:block(group, key, cf, Vector3.new(w * self:rand(0.94, 1.06), t, l * self:rand(0.94, 1.08)))
end

function K:tube(group, nodes, opts)
	local step = opts.step or 0.35
	local samples = self:path(nodes, step, opts.ref)
	local total = samples.total
	-- 1) core: an octagonal log of two big blocks per stretch (shows between the tiles as dark creases)
	if opts.core then
		local every = opts.coreEvery or 1
		local i = 1
		while i < #samples do
			local j = math.min(i + every, #samples)
			local a, b = samples[i], samples[j]
			local d = b.p - a.p
			if d.Magnitude > 1e-3 then
				local T = d.Unit
				local R, U = frame(T, opts.ref)
				local rx, ru, rd = (a.rx + b.rx) / 2, (a.ru + b.ru) / 2, (a.rd + b.rd) / 2
				local h = ru + rd
				local r = math.min(rx, h / 2)
				local k = opts.coreScale or 0.82
				local cf = CFrame.fromMatrix((a.p + b.p) / 2 + U * (ru - rd) / 2, R, U)
				local len = d.Magnitude + r * 0.7
				-- coreCap: the end stretches use another colour (a glowing core would show at the open ends)
				local key = (opts.coreCap and (i == 1 or j == #samples)) and opts.coreCap or opts.core
				self:block(group, key, cf, Vector3.new(rx * 2 * k, h * k, len))
				self:block(group, key, cf * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(r * 1.45 * k, r * 1.45 * k, len))
			end
			i = j
		end
	end
	-- 2) rings of overlapping tiles, alternate rings staggered; 3) a wide plate across the belly per ring
	local tile = opts.tile
	if tile then
		local belly = opts.belly
		local bellyHalf = belly and math.rad(belly.arc or 32) or 0
		local arc = math.min(math.rad(tile.arc or 180), math.pi - bellyHalf)
		local full = not belly and arc >= math.pi - 1e-3
		local n = tile.n
		if not n then
			local widest = 0
			for _, smp in ipairs(samples) do
				local _, perim = spread(self, smp, -arc, arc, 1, 0, false)
				widest = math.max(widest, perim)
			end
			n = math.max(full and 3 or 2, math.floor(widest / tile.w + 0.5))
		end
		for ri, smp in ipairs(samples) do
			if smp.s >= (opts.from or 0) - 1e-3 and smp.s <= total - (opts.trim or 0) + 1e-3 then
				local thetas, perim
				if full then
					thetas, perim = spread(self, smp, -math.pi, math.pi, n, (tile.stagger and ri % 2 == 0) and 0.5 or 0, true)
				else
					thetas, perim = spread(self, smp, -arc, arc, n, 0, false)
				end
				local w = perim / n * (tile.overlap or 1.1)
				for row, th in thetas do
					local key = opts.color and opts.color(th, ri, smp, row, n) or opts.key
					if key then
						self:tile(group, key, smp, th, w, tile.l or step * 1.3, tile.t or 0.1, tile.lift, tile.jitter, tile.sink)
					end
				end
				if belly then
					local key = ri % 2 == 0 and belly.key or (belly.key2 or belly.key)
					local bw = 2 * smp.rx * math.sin(bellyHalf) * (belly.wide or 1.1)
					self:tile(group, key, smp, math.pi, bw, step * 1.2, belly.t or 0.1, belly.lift or 3, 1, 0.45)
				end
			end
		end
	end
	return samples
end

function K:spike(group, key, base, dir, across, h, thick, name)
	dir = dir.Unit
	local X = across - dir * across:Dot(dir)
	X = X.Magnitude > 1e-3 and X.Unit or frame(dir)
	local a1 = (dir + X:Cross(dir)).Unit
	local L = h * math.sqrt(2)
	return self:block(group, key, CFrame.fromMatrix(base, X, a1), Vector3.new(thick, L, L), name)
end

local function value(v, u)
	return type(v) == "function" and v(u) or v
end

function K:ridge(group, samples, opts)
	local from, to = opts.from or 0, opts.to or samples.total
	local count = math.max(0, math.floor((to - from) / opts.every + 0.5))
	for k = 0, count do
		local u = count > 0 and k / count or 0
		local smp = self:at(samples, from + (to - from) * u)
		local h, th = value(opts.height, u), value(opts.thick, u)
		local jit = opts.jitter or 5
		local lean = math.rad((opts.lean or 30) + self:rand(-jit, jit))
		local base = smp.p + smp.U * smp.ru * (opts.sink or 0.8)
		if opts.style == "plate" then
			local keys = opts.keys or { opts.key, opts.key, opts.tip or opts.key }
			self:plate(group, keys, base, smp.U, smp.T, { h = h, w = h * value(opts.width or 0.62, u), t = th, n = opts.layers or 3, lean = (opts.lean or 14) + self:rand(-jit, jit), shift = opts.shift or 0.14 })
		elseif opts.style == "spike" then
			local depth = value(opts.depth or 2.4, u)
			self:chain(group, { opts.key, opts.key, opts.tip or opts.key }, base, smp.U * math.cos(lean) + smp.T * math.sin(lean), smp.R, { n = 3, len = h, w0 = th, w1 = th * 0.65, depth = depth, bend = opts.bend or 12, tipH = th * 0.65 * depth * 0.55 })
		else
			self:spike(group, opts.key, base, smp.U * math.cos(lean) + smp.T * math.sin(lean), smp.R, h, th)
		end
		if opts.tip and opts.style ~= "spike" then
			local lean2 = lean + math.rad(opts.tipLean or 16)
			local base2 = base + smp.T * h * 0.45 + smp.U * h * 0.25
			self:spike(group, opts.tip, base2, smp.U * math.cos(lean2) + smp.T * math.sin(lean2), smp.R, h * 0.6, th * 0.85)
		end
	end
end

-- opts: n blocks, len (total), w0 / w1 (base / tip width), bend (degrees per block about axis), depth (block depth
-- factor), tip = false ends square instead of on a point
function K:chain(group, keys, base, dir, axis, opts)
	local n = opts.n or 3
	local seg = opts.len / n
	local p = base
	local d = dir.Unit
	for i = 1, n do
		local f = (i - 1) / math.max(n - 1, 1)
		local w = opts.w0 + (opts.w1 - opts.w0) * f
		local key = type(keys) == "table" and keys[math.min(i, #keys)] or keys
		local X = axis - d * axis:Dot(d)
		X = X.Magnitude > 1e-3 and X.Unit or frame(d)
		if i == n and opts.tip ~= false then
			self:spike(group, key, p - d * w * 0.25, d, X, opts.tipH or (seg * 0.6 + w * 0.5), w)
		else
			self:block(group, key, CFrame.fromMatrix(p + d * seg / 2, X, d), Vector3.new(w, seg * 1.12, w * (opts.depth or 1)))
			p += d * seg
		end
		d = (CFrame.fromAxisAngle(X, math.rad(opts.bend or 0)) * d).Unit
	end
end

-- opts: h (height), w (base width along the body), t (thickness), n (layers), lean (degrees back), shift (each layer
-- steps back by this fraction of w)
function K:plate(group, keys, base, up, along, opts)
	local n = opts.n or 3
	local lean = math.rad(opts.lean or 14)
	local U = (up * math.cos(lean) + along * math.sin(lean)).Unit
	local A = (along - U * along:Dot(U)).Unit
	local X = U:Cross(A)
	local lh = opts.h / (n + 0.45)
	local shift = (opts.shift or 0.14) * opts.w
	local top
	for i = 1, n do
		local f = (i - 1) / n
		local w = opts.w * (1 - f * 0.72)
		local c = base + U * (lh * (i - 0.5)) + A * shift * (i - 1)
		self:block(group, keys[math.min(i, #keys)], CFrame.fromMatrix(c, X, U), Vector3.new(opts.t * (1 - f * 0.35), lh * 1.04, w))
		top = { c = c, w = w }
	end
	self:spike(group, keys[#keys], top.c + U * lh * 0.4 + A * shift * 0.6, (U + A * 0.25).Unit, X, top.w * 0.48, opts.t * 0.6)
end

function KaijuSculpt.BuildModel(name, spec)
	local self = setmetatable({}, K)
	self.spec = spec
	self.rng = Random.new(spec.Seed or 1)
	self.groups = {}
	self.count = 0
	self.scales = { { Vector3.zero, spec.Scale or 1 } }
	self.palette = {}
	for key, value in spec.Palette do
		local hexv = type(value) == "table" and value[1] or value
		local mat = Enum.Material.SmoothPlastic
		if type(value) == "table" then
			if value.Neon then
				mat = Enum.Material.Neon
			elseif value.Material then
				mat = Enum.Material[value.Material]
			end
		end
		self.palette[key] = { color = Color3.fromHex(hexv), material = mat, transparency = type(value) == "table" and value.Transparency or 0 }
	end
	local model = Instance.new("Model")
	model.Name = name
	self.model = model
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("RootOffset", root.Position)
	if spec.Gait then
		model:SetAttribute("Gait", spec.Gait)
	end
	if spec.Emotes then
		model:SetAttribute("Emotes", table.concat(spec.Emotes, ","))
	end
	if spec.Wag then
		model:SetAttribute("Wag", true)
	end
	model:SetAttribute("Sculpted", true)
	spec.Build(self)
	model:SetAttribute("Bricks", self.count)
	return model
end

function KaijuSculpt.Has(name)
	local specs = fresh(ServerStorage.Tools.KaijuSculptSpecs)
	return specs[name] ~= nil
end

function KaijuSculpt.Build(name)
	local specs = fresh(ServerStorage.Tools.KaijuSculptSpecs)
	local spec = specs[name]
	assert(spec, "no sculpt spec for " .. name)
	local model = KaijuSculpt.BuildModel(name, spec)
	local folder = ServerStorage.Assets.Kaiju
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	local _, size = model:GetBoundingBox()
	return string.format("%s: %d parts, size %.1f x %.1f x %.1f", name, model:GetAttribute("Bricks"), size.X, size.Y, size.Z)
end

return KaijuSculpt
