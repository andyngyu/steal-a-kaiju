-- Edit-time tool: builds brick-built (studded voxel) kaiju from ServerStorage.Tools.KaijuSpecs (overridden per species by
-- the redesigned Tools.KaijuSpecsV2) into ServerStorage.Assets.Kaiju.
-- Command bar:  require(game.ServerStorage.Tools.KaijuBuilder:Clone()).Build("Pebblesaur")   or   .BuildAll()
--
-- Shapes are filled with voxels (spec.Voxel studs), later shapes paint over earlier ones, Carve shapes remove voxels,
-- Paint shapes only recolour voxels that already exist (stripes, spots); Paint + Regroup also moves them to the shape's
-- Group (e.g. an egg's rarity band). spec.StudScale sets the stud tile size (default 2 x Voxel); spec.NoStuds skips the
-- stud textures (small props, where they'd only cost draw calls); spec.StudFaces = "Top" studs only the top faces.
-- Same-coloured voxels in a body group are merged into as few bricks as possible (3D greedy merge). spec.SkinMerge:
-- voxels buried inside their group (all six neighbours in the same group) are wildcards that any brick of that group
-- may cover and are otherwise left out, so only the visible skin's colours split bricks (far fewer parts).
-- Shape kinds: Ellipsoid (C, R, optional Rot), Box (C, S, Rot), Capsule (A, B, RA/RB or R), Custom (Inside = fn(p) -> bool,
-- Lo, Hi bounds). Any shape may carry Within = another shape: it then only applies where that shape also contains the
-- point (raised panels, masked paint). spec.AO = true darkens visible voxels in creases (ambient occlusion: many
-- filled neighbours), in two steps, so carved grooves and the roots of horns read like the voxel renders it copies.
-- Face details (eyes, mouths, teeth) are placed on the front surface of the bricks after voxelising.
-- Bits are exact small parts (claws) placed as given.
-- Output: Model facing -Z, PrimaryPart "Root" at the centre of the feet, parts grouped into sub-Models per body
-- group (Body, Head, LegL, ...) with attribute Joint (Vector3, build space) for limb animation. spec.Parents nests a
-- group inside another ({ Jaw = "Head" }) so it follows that group's motion. Model attribute RootOffset = Root's
-- build-space position (joints relative to the pivot = Joint - RootOffset, times the model's scale).
-- Motion attributes: Gait (spec.Gait; ReplicatedStorage.KaijuAnimation picks a profile from it for a species it has no
-- entry for), Emotes (spec.Emotes joined with commas), Wag (spec.Wag).
local ServerStorage = game:GetService("ServerStorage")

local KaijuBuilder = {}

local STUD_TEXTURE = "rbxassetid://6372755229"
local STUD_FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local function v3(t)
	return typeof(t) == "Vector3" and t or Vector3.new(t[1], t[2], t[3])
end

local function swapSide(name)
	if name:sub(-1) == "L" then
		return name:sub(1, -2) .. "R"
	elseif name:sub(-1) == "R" then
		return name:sub(1, -2) .. "L"
	end
	return name
end

local function mirrorX(v)
	return Vector3.new(-v.X, v.Y, v.Z)
end

-- Normalises a shape spec and returns { inside = fn(p) -> bool, lo, hi }
local compile
local function compileBase(s)
	local kind = s.Kind
	if kind == "Ellipsoid" then
		local c, r = v3(s.C), v3(s.R)
		if s.Rot then
			local rot = CFrame.fromOrientation(math.rad(s.Rot[1]), math.rad(s.Rot[2]), math.rad(s.Rot[3]))
			local reach = math.max(r.X, r.Y, r.Z)
			return {
				inside = function(p)
					local d = rot:PointToObjectSpace(p - c) / r
					return d:Dot(d) <= 1
				end,
				lo = c - Vector3.one * reach,
				hi = c + Vector3.one * reach,
			}
		end
		return {
			inside = function(p)
				local d = (p - c) / r
				return d:Dot(d) <= 1
			end,
			lo = c - r,
			hi = c + r,
		}
	elseif kind == "Custom" then
		return { inside = s.Inside, lo = v3(s.Lo), hi = v3(s.Hi) }
	elseif kind == "Box" then
		local c, half = v3(s.C), v3(s.S) / 2
		local rot = s.Rot and CFrame.fromOrientation(math.rad(s.Rot[1]), math.rad(s.Rot[2]), math.rad(s.Rot[3])) or CFrame.identity
		local reach = half.Magnitude
		return {
			inside = function(p)
				local l = rot:PointToObjectSpace(p - c)
				return math.abs(l.X) <= half.X and math.abs(l.Y) <= half.Y and math.abs(l.Z) <= half.Z
			end,
			lo = c - Vector3.one * reach,
			hi = c + Vector3.one * reach,
		}
	elseif kind == "Capsule" then
		local a, b = v3(s.A), v3(s.B)
		local ra, rb = s.RA or s.R, s.RB or s.R
		local ab = b - a
		local len2 = math.max(ab:Dot(ab), 1e-6)
		local rmax = math.max(ra, rb)
		return {
			inside = function(p)
				local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
				local r = ra + (rb - ra) * t
				return (p - (a + ab * t)).Magnitude <= r
			end,
			lo = a:Min(b) - Vector3.one * rmax,
			hi = a:Max(b) + Vector3.one * rmax,
		}
	end
	error("unknown shape kind " .. tostring(kind))
end

compile = function(s)
	local c = compileBase(s)
	if s.Within then
		local w = compile(s.Within)
		local inner = c.inside
		c.inside = function(p)
			return inner(p) and w.inside(p)
		end
		c.lo, c.hi = c.lo:Max(w.lo), c.hi:Min(w.hi)
	end
	return c
end

-- A left/right mirror image of a shape (positions, rotations, custom functions and masks).
local function mirrorShape(s)
	local m = table.clone(s)
	m.Mirror = nil
	if s.Group then
		m.Group = swapSide(s.Group)
	end
	for _, key in { "C", "A", "B" } do
		if m[key] then
			m[key] = mirrorX(v3(m[key]))
		end
	end
	if m.Rot then
		m.Rot = { m.Rot[1], -m.Rot[2], -m.Rot[3] }
	end
	if s.Kind == "Custom" then
		local inside, lo, hi = s.Inside, v3(s.Lo), v3(s.Hi)
		m.Inside = function(p)
			return inside(mirrorX(p))
		end
		m.Lo, m.Hi = Vector3.new(-hi.X, lo.Y, lo.Z), Vector3.new(-lo.X, hi.Y, hi.Z)
	end
	if s.Within then
		m.Within = mirrorShape(s.Within)
	end
	return m
end

-- Expands Mirror = true shapes into a left and a right copy.
local function expand(shapes)
	local out = {}
	for _, s in shapes do
		table.insert(out, s)
		if s.Mirror then
			table.insert(out, mirrorShape(s))
		end
	end
	return out
end

-- a darker shade of a colour for creases (keeps the hue, a touch more saturated)
local function shade(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * (1 + amount * 0.6)), v * (1 - amount))
end

local TOP_ONLY = { Enum.NormalId.Top }

local function newPart(parent, name, size, cf, color, neon, studs, studScale, faces)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if studs and not neon then
		for _, face in faces or STUD_FACES do
			local t = Instance.new("Texture")
			t.Texture = STUD_TEXTURE
			t.Face = face
			t.StudsPerTileU = studScale
			t.StudsPerTileV = studScale
			t.Color3 = Color3.new(0, 0, 0)
			t.Transparency = 0.7
			t.Parent = p
		end
	end
	p.Parent = parent
	return p
end

function KaijuBuilder.BuildModel(name, spec)
	local v = spec.Voxel
	local palette = {}
	for key, value in spec.Palette do
		if type(value) == "table" then
			palette[key] = { color = Color3.fromHex(value[1]), neon = value.Neon == true }
		else
			palette[key] = { color = Color3.fromHex(value), neon = false }
		end
	end

	-- 1) voxelise
	local shapes = expand(spec.Shapes)
	local compiled = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for i, s in shapes do
		local c = compile(s)
		c.spec = s
		compiled[i] = c
		lo, hi = lo:Min(c.lo), hi:Max(c.hi)
	end
	local i0 = Vector3.new(math.floor(lo.X / v), math.max(0, math.floor(lo.Y / v)), math.floor(lo.Z / v))
	local i1 = Vector3.new(math.ceil(hi.X / v), math.ceil(hi.Y / v), math.ceil(hi.Z / v))
	local cells = {} -- [x][y][z] = { group, color, buried }
	local count = 0
	for ix = i0.X, i1.X do
		local px = ix * v
		local column = {}
		for _, c in compiled do
			if px >= c.lo.X - v and px <= c.hi.X + v then
				table.insert(column, c)
			end
		end
		for iy = i0.Y, i1.Y do
			local py = iy * v + v / 2
			local row = {}
			for _, c in column do
				if py >= c.lo.Y - v and py <= c.hi.Y + v then
					table.insert(row, c)
				end
			end
			for iz = i0.Z, i1.Z do
				local pz = iz * v
				local p = Vector3.new(px, py, pz)
				local cell
				for _, c in row do
					if pz >= c.lo.Z - v and pz <= c.hi.Z + v and c.inside(p) then
						if c.spec.Carve then
							cell = nil
						elseif c.spec.Paint then
							if cell then
								cell = { c.spec.Regroup and c.spec.Group or cell[1], c.spec.Color }
							end
						else
							cell = { c.spec.Group, c.spec.Color }
						end
					end
				end
				if cell then
					cells[ix] = cells[ix] or {}
					cells[ix][iy] = cells[ix][iy] or {}
					cells[ix][iy][iz] = cell
					count += 1
				end
			end
		end
		if ix % 8 == 0 then
			task.wait()
		end
	end
	local function get(x, y, z)
		local a = cells[x]
		local b = a and a[y]
		return b and b[z]
	end

	-- 2) model + groups
	local model = Instance.new("Model")
	model.Name = name
	local root = newPart(model, "Root", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1), false, false)
	root.Transparency = 1
	root.CanQuery = false
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
	local groups = {}
	local function group(gname)
		if not groups[gname] then
			local g = Instance.new("Model")
			g.Name = gname
			local joint = spec.Joints and spec.Joints[gname]
			if joint then
				g:SetAttribute("Joint", v3(joint))
			end
			groups[gname] = g
			local parentName = spec.Parents and spec.Parents[gname]
			g.Parent = parentName and group(parentName) or model
		end
		return groups[gname]
	end

	-- 3) greedy merge into bricks
	local used = {}
	local function isUsed(x, y, z)
		return used[x .. "," .. y .. "," .. z]
	end
	-- ambient occlusion: visible voxels sitting in creases get darker shades of their colour (keys "<Color>~ao1/2";
	-- the bricks are still named after the plain colour)
	if spec.AO then
		local ao = type(spec.AO) == "table" and spec.AO or {}
		local soft, hard = ao.Soft or 22, ao.Hard or 24 -- (19-21 also catches every terrace step of a curved surface)
		local marks = {}
		for x, a in cells do
			for y, b in a do
				for z, c in b do
					local pal = palette[c[2]]
					if pal and not pal.neon and c[2] ~= "Band" then
						local open = not (get(x + 1, y, z) and get(x - 1, y, z) and get(x, y + 1, z) and get(x, y - 1, z) and get(x, y, z + 1) and get(x, y, z - 1))
						if open then
							local n = 0
							for dx = -1, 1 do
								for dy = -1, 1 do
									for dz = -1, 1 do
										if (dx ~= 0 or dy ~= 0 or dz ~= 0) and get(x + dx, y + dy, z + dz) then
											n += 1
										end
									end
								end
							end
							if n >= soft then
								table.insert(marks, { c, n >= hard and 2 or 1 })
							end
						end
					end
				end
			end
		end
		for _, m in marks do
			local c, level = m[1], m[2]
			local key = c[2] .. "~ao" .. level
			if not palette[key] then
				palette[key] = { color = shade(palette[c[2]].color, level == 2 and (ao.HardAmount or 0.26) or (ao.SoftAmount or 0.13)), neon = false }
			end
			c[2] = key
		end
		task.wait()
	end

	local skin = spec.SkinMerge
	local function buried(x, y, z, g)
		for _, d in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
			local n = get(x + d[1], y + d[2], z + d[3])
			if not n or n[1] ~= g then
				return false
			end
		end
		return true
	end
	if skin then
		for x, a in cells do
			for y, b in a do
				for z, c in b do
					c[3] = buried(x, y, z, c[1])
				end
			end
		end
	end
	local function same(x, y, z, g, col)
		local c = get(x, y, z)
		return c and c[1] == g and (c[2] == col or c[3] == true) and not isUsed(x, y, z)
	end
	-- each brick grows from its first free voxel along the axis order (of all six) that covers the most visible
	-- (not buried) voxels
	local ORDERS = { { 1, 3, 2 }, { 3, 1, 2 }, { 1, 2, 3 }, { 2, 1, 3 }, { 3, 2, 1 }, { 2, 3, 1 } }
	local function slabFree(lo, hi, axis, n, g, col)
		local a, b = { lo[1], lo[2], lo[3] }, { hi[1], hi[2], hi[3] }
		a[axis], b[axis] = n, n
		local seen = 0
		for x = a[1], b[1] do
			for y = a[2], b[2] do
				for z = a[3], b[3] do
					if not same(x, y, z, g, col) then
						return false
					end
					if not cells[x][y][z][3] then
						seen += 1
					end
				end
			end
		end
		return true, seen
	end
	local function grow(ix, iy, iz, g, col, order)
		local lo, hi = { ix, iy, iz }, { ix, iy, iz }
		local seen = 1
		for _, axis in order do
			while true do
				local ok, n = slabFree(lo, hi, axis, hi[axis] + 1, g, col)
				if not ok then
					break
				end
				hi[axis] += 1
				seen += n
			end
		end
		return hi, seen
	end
	local bricks = 0
	for iy = i0.Y, i1.Y do
		for iz = i0.Z, i1.Z do
			for ix = i0.X, i1.X do
				local c = get(ix, iy, iz)
				if c and not c[3] and not isUsed(ix, iy, iz) then
					local g, col = c[1], c[2]
					local best, bestVol
					for _, order in ORDERS do
						local hi, seen = grow(ix, iy, iz, g, col, order)
						if not bestVol or seen > bestVol then
							best, bestVol = hi, seen
						end
					end
					local x1, y1, z1 = best[1], best[2], best[3]
					for x = ix, x1 do
						for y = iy, y1 do
							for z = iz, z1 do
								used[x .. "," .. y .. "," .. z] = true
							end
						end
					end
					local size = Vector3.new(x1 - ix + 1, y1 - iy + 1, z1 - iz + 1) * v
					local center = Vector3.new((ix + x1) / 2 * v, (iy + y1) / 2 * v + v / 2, (iz + z1) / 2 * v)
					local pal = palette[col] or { color = Color3.new(1, 0, 1), neon = false }
					-- stud textures only on faces that can be seen (not covered by voxels all the way across)
					local faces = {}
					if not spec.NoStuds and not pal.neon then
						local function open(ax, ay, az, bx, by, bz)
							for x = ax, bx do
								for y = ay, by do
									for z = az, bz do
										if not get(x, y, z) then
											return true
										end
									end
								end
							end
							return false
						end
						if open(ix, y1 + 1, iz, x1, y1 + 1, z1) then
							table.insert(faces, Enum.NormalId.Top)
						end
						if spec.StudFaces ~= "Top" then
							if open(ix, iy, iz - 1, x1, y1, iz - 1) then
								table.insert(faces, Enum.NormalId.Front)
							end
							if open(ix, iy, z1 + 1, x1, y1, z1 + 1) then
								table.insert(faces, Enum.NormalId.Back)
							end
							if open(ix - 1, iy, iz, ix - 1, y1, z1) then
								table.insert(faces, Enum.NormalId.Left)
							end
							if open(x1 + 1, iy, iz, x1 + 1, y1, z1) then
								table.insert(faces, Enum.NormalId.Right)
							end
						end
					end
					newPart(group(g), col:match("^[^~]+"), size, CFrame.new(center), pal.color, pal.neon, #faces > 0, spec.StudScale or v * 2, faces)
					bricks += 1
				end
			end
		end
		if iy % 6 == 0 then
			task.wait()
		end
	end

	-- 4) face details on the front surface: find the frontmost voxel under the detail's footprint
	for _, d in spec.Details or {} do
		local list = { d }
		if d.Mirror then
			local m = table.clone(d)
			m.X = -d.X
			m.Group = swapSide(d.Group)
			table.insert(list, m)
		end
		for _, dd in list do
			local w, h = dd.W, dd.H
			local minZ = math.huge
			-- voxel columns whose centres fall inside the detail's footprint (at least the nearest one). RefY / RefH
			-- measure the depth from another footprint (an eyelid sits at the depth of the eye it covers, not of the
			-- brow above, which curves away)
			local fy, fh = dd.RefY or dd.Y, dd.RefH or h
			local ixa, ixb = math.ceil((dd.X - w / 2) / v), math.floor((dd.X + w / 2) / v)
			if ixa > ixb then
				ixa = math.floor(dd.X / v + 0.5)
				ixb = ixa
			end
			local iya, iyb = math.ceil((fy - fh / 2 - v / 2) / v), math.floor((fy + fh / 2 - v / 2) / v)
			if iya > iyb then
				iya = math.floor((fy - v / 2) / v + 0.5)
				iyb = iya
			end
			for ix = ixa, ixb do
				for iy = iya, iyb do
					local col = cells[ix] and cells[ix][iy]
					if col then
						for iz, _ in col do
							minZ = math.min(minZ, iz)
						end
					end
				end
			end
			if minZ < math.huge then
				local depth = dd.D or 0.12
				local frontZ = minZ * v - v / 2 - (dd.Inset and -dd.Inset or 0)
				local z = frontZ - depth / 2 + (dd.Sink or 0) + (dd.Offset or 0)
				local pal = palette[dd.Color]
				local cf = CFrame.new(dd.X, dd.Y, z)
				-- Yaw turns the outer end back (a brow following the curve of the head), Pitch leans the top edge back (a
				-- ridge sloping into the forehead instead of a shelf); Studs gives it the voxel texture
				if dd.Yaw then
					cf *= CFrame.Angles(0, math.rad(-dd.Yaw * (dd.X < 0 and -1 or 1)), 0)
				end
				if dd.Tilt then
					cf *= CFrame.Angles(0, 0, math.rad(dd.Tilt * (dd.X < 0 and -1 or 1)))
				end
				if dd.Pitch then
					cf *= CFrame.Angles(math.rad(dd.Pitch), 0, 0)
				end
				newPart(group(dd.Group or "Head"), dd.Name or dd.Color, Vector3.new(w, h, depth), cf, pal.color, pal.neon, dd.Studs == true, spec.StudScale or v * 2)
			end
		end
	end

	-- 5) exact small pieces (claws, horns) that are too fine for the voxel grid
	for _, b in spec.Bits or {} do
		local list = { b }
		if b.Mirror then
			local m = table.clone(b)
			m.C = mirrorX(v3(b.C))
			m.Group = swapSide(b.Group)
			table.insert(list, m)
		end
		for _, bb in list do
			local pal = palette[bb.Color]
			local cf = CFrame.new(v3(bb.C))
			if bb.Rot then
				cf *= CFrame.fromOrientation(math.rad(bb.Rot[1]), math.rad(bb.Rot[2]), math.rad(bb.Rot[3]))
			end
			newPart(group(bb.Group), bb.Name or bb.Color, v3(bb.S), cf, pal.color, pal.neon, false)
		end
	end

	model:SetAttribute("Bricks", bricks)
	model:SetAttribute("Voxels", count)
	return model
end

local function store(model)
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets:FindFirstChild("Kaiju")
	local old = folder:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	return model
end

-- the redesigned specs (Tools.KaijuSpecsV2) win over the originals (Tools.KaijuSpecs)
local function allSpecs()
	local specs = fresh(ServerStorage.Tools.KaijuSpecs)
	local v2 = ServerStorage.Tools:FindFirstChild("KaijuSpecsV2")
	if v2 then
		for name, spec in fresh(v2) do
			specs[name] = spec
		end
	end
	return specs
end

-- species rebuilt in the sculpted style (Tools.KaijuSculptSpecs) are built by Tools.KaijuSculpt instead
local function sculpted(name)
	local tools = ServerStorage.Tools
	return tools:FindFirstChild("KaijuSculptSpecs") and tools:FindFirstChild("KaijuSculpt") and fresh(tools.KaijuSculptSpecs)[name] ~= nil
end

function KaijuBuilder.Build(name)
	if sculpted(name) then
		return fresh(ServerStorage.Tools.KaijuSculpt).Build(name)
	end
	local specs = allSpecs()
	local spec = specs[name]
	assert(spec, "no spec for " .. name)
	local model = KaijuBuilder.BuildModel(name, spec)
	store(model)
	local _, size = model:GetBoundingBox()
	return string.format("%s: %d bricks from %d voxels, size %.1f x %.1f x %.1f", name, model:GetAttribute("Bricks"), model:GetAttribute("Voxels"), size.X, size.Y, size.Z)
end

function KaijuBuilder.BuildAll()
	local specs = allSpecs()
	local out = {}
	for name in specs do
		table.insert(out, KaijuBuilder.Build(name))
		task.wait()
	end
	return table.concat(out, "\n")
end

return KaijuBuilder
