-- KaijuAnimation.Rig: builds a Motor6D rig on the CLIENT's own copy of a kaiju (never on the server, never on assets).
-- Kaiju models are bricks in sub-Models that carry a Joint attribute (ServerStorage.Tools.KaijuSculpt / KaijuRegroup),
-- every brick anchored. The rig adds a folder "_AnimRig" inside the model with one invisible pivot part per body group
-- at its joint, Motor6Ds chaining the pivots (Root > Body > groups; a nested group hangs off its parent group) and a
-- WeldConstraint from every brick to its group's pivot. Then every part except the PrimaryPart is unanchored, so the
-- engine moves groups by writing Motor6D.Transform. The PrimaryPart stays anchored and is never touched.
-- Building is a job that does a slice of work per call (Rig.Step with a deadline), so kaiju arriving together never cause
-- a hitch. The species analysis (joint names, chains, feet, eyes) is cached by the model's group structure.
-- Guardians are Motor6D rigs already (GuardianService adds a Body motor): Rig.FromMotors reads their motors as they are.
--   map = Rig.Analyze(model, spec, profileName, profile)    cached per species + group structure
--   job = Rig.Begin(model, map)                               pivots and motors (fast)
--   done = Rig.Step(job, deadline)                            welds, then unanchoring, in slices; true when finished
local Rig = {}
Rig.FolderName = "_AnimRig"

local cache = {}

local SERPENTINE = { Serpent = true, VerticalCoil = true, Hydra = true }

local function roleOf(name, profileName)
	if profileName == "Tentacled" and (name:match("^Leg") or name:match("^Arm") or name:match("^Tail")) then
		return "Tentacle"
	end
	if name == "Head" or name == "HeadLeft" or name == "HeadRight" then
		return "Head"
	end
	if name == "Jaw" then
		return "Jaw"
	end
	if name:match("^Neck") then
		return "Neck"
	end
	if name:match("^Seg%d") then
		return "Seg"
	end
	if name:match("^Tail") then
		return SERPENTINE[profileName] and "Seg" or "Tail"
	end
	if name:match("^Trunk") then
		return "Trunk"
	end
	if name:match("^Leg") then
		return "Leg"
	end
	if name:match("^Arm") then
		return "Arm"
	end
	if name:match("^Wing") then
		return "Wing"
	end
	if name:match("^Ear") then
		return "Ear"
	end
	if name:match("^Eye") then
		return "EyeStalk"
	end
	if name:match("^Claw") then
		return "Claw"
	end
	if name == "Tongue" then
		return "Tongue"
	end
	if name == "Cloud" then
		return "Cloud"
	end
	if name == "Frill" then
		return "Frill"
	end
	if name == "Ring" or name == "Moons" or name == "Halo" then
		return "Orbit"
	end
	return "Other"
end
Rig.RoleOf = roleOf

-- lowest world Y of a part's box
local function bottomOf(p)
	local cf, s = p.CFrame, p.Size
	local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
	return cf.Position.Y - 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
end

-- ground contact point of a set of parts (root space, divided by scale): the centre of the lowest bricks
local function footOf(parts, rootCF, scale)
	local low = math.huge
	for _, p in parts do
		low = math.min(low, bottomOf(p))
	end
	local sum, n = Vector3.zero, 0
	for _, p in parts do
		if bottomOf(p) <= low + 0.15 * scale then
			sum += p.Position
			n += 1
		end
	end
	if n == 0 then
		return nil
	end
	local at = Vector3.new(sum.X / n, low, sum.Z / n)
	return rootCF:PointToObjectSpace(at) / scale
end

local function directParts(inst)
	local list = {}
	for _, c in inst:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(list, c)
		end
	end
	return list
end

local function pathOf(model, inst)
	local names = {}
	local a = inst
	while a and a ~= model do
		table.insert(names, 1, a.Name)
		a = a.Parent
	end
	return table.concat(names, "/")
end

function Rig.Signature(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Joint") ~= nil then
			table.insert(list, pathOf(model, d))
		end
	end
	table.sort(list)
	return (model:GetAttribute("Species") or model.Name) .. "|" .. table.concat(list, ",")
end

local function setOf(list)
	local s = {}
	for _, v in list or {} do
		s[v] = true
	end
	return s
end

-- +1 for the L side (+X), -1 for R: from the name (EarL, LegFL2, HeadLeft), else from where the joint sits
local function sideOf(name, x)
	local base = name:gsub("%d+$", "")
	if base:match("Left$") then
		return 1
	elseif base:match("Right$") then
		return -1
	end
	local last = base:sub(-1)
	if #base > 1 and last == "L" then
		return 1
	elseif #base > 1 and last == "R" then
		return -1
	end
	return x > 0.05 and 1 or x < -0.05 and -1 or 0
end

-- Shared tail of Analyze and FromMotors: chain indices, sides, planted feet, hips / shoulders and the body pivot.
local function finish(map, profileName, profile)
	local planted = setOf(profile.Planted)
	local byName = {}
	for i, j in map.joints do
		byName[j.name] = i
	end
	local segCount = 0
	for _, j in map.joints do
		if j.name:match("^Seg%d+$") then
			segCount += 1
		end
	end
	for _, j in map.joints do
		j.role = roleOf(j.name, profileName)
		local base, num = string.match(j.name, "^(.-)(%d+)$")
		if j.role == "Seg" then
			j.chainId = "Spine"
			j.chain = num and tonumber(num) or segCount + 1
		elseif base then
			j.chainId = base
			j.chain = tonumber(num)
		else
			j.chainId = j.name
			j.chain = 1
		end
		j.side = sideOf(j.name, j.pos.X)
		j.planted = planted[j.name] == true
	end
	-- tentacle curl axis: horizontal, perpendicular to the tentacle's reach (positive curl lifts the tip)
	local chainBase, chainTip = {}, {}
	for _, j in map.joints do
		if j.role == "Tentacle" then
			if not chainBase[j.chainId] or j.chain < chainBase[j.chainId].chain then
				chainBase[j.chainId] = j
			end
			if not chainTip[j.chainId] or j.chain > chainTip[j.chainId].chain then
				chainTip[j.chainId] = j
			end
		end
	end
	local tentacleIndex, nextIndex = {}, 0
	for _, j in map.joints do
		if j.role == "Tentacle" then
			local b, t = chainBase[j.chainId], chainTip[j.chainId]
			local reach = (t.tipPos or t.pos) - b.pos
			reach = Vector3.new(reach.X, 0, reach.Z)
			if reach.Magnitude < 1e-3 then
				reach = Vector3.new(b.pos.X, 0, b.pos.Z)
			end
			if reach.Magnitude < 1e-3 then
				reach = Vector3.xAxis
			end
			j.curl = reach.Unit:Cross(Vector3.yAxis)
			if not tentacleIndex[j.chainId] then
				tentacleIndex[j.chainId] = nextIndex
				nextIndex += 1
			end
			j.tentacle = tentacleIndex[j.chainId]
		end
	end
	-- hips, shoulders and the body pivot from the planted limbs
	local hips, nh, shoulders, ns, all, na = Vector3.zero, 0, Vector3.zero, 0, Vector3.zero, 0
	for _, j in map.joints do
		if j.planted then
			all += j.pos
			na += 1
			local n = j.name
			if n == "LegL" or n == "LegR" or n:match("^LegB") or n:match("^LegC") then
				hips += j.pos
				nh += 1
			elseif n:match("^LegF") or n:match("^Arm") or n:match("^LegA") then
				shoulders += j.pos
				ns += 1
			end
		end
	end
	local centre = map.body.pos
	if na > 0 then
		local c = all / na
		centre = Vector3.new(0, c.Y, c.Z)
	end
	map.body.pos = map.body.pos or centre
	map.centre = centre
	map.hips = nh > 0 and Vector3.new(0, (hips / nh).Y, (hips / nh).Z) or centre
	map.shoulders = ns > 0 and Vector3.new(0, (shoulders / ns).Y, (shoulders / ns).Z) or centre
	map.byName = byName
	return map
end

-- Analysis of a brick kaiju (cached). spec: Config.Creatures entry; profile: the merged profile table.
function Rig.Analyze(model, spec, profileName, profile)
	local key = Rig.Signature(model) .. "|" .. profileName
	if cache[key] then
		return cache[key]
	end
	local root = model.PrimaryPart
	local rootCF = root.CFrame
	local scale = model:GetAttribute("VisualScale") or 1
	local rootOffset = model:GetAttribute("RootOffset") or Vector3.new(0, 0.1, 0)
	local rename = spec.Rename or {}
	local parentsOverride = spec.Parents or {}
	local bodyGroup = model:FindFirstChild("Body")
	if bodyGroup and not (bodyGroup:IsA("Model") and bodyGroup:GetAttribute("Joint") == nil) then
		bodyGroup = nil
	end

	local groups, byInst, exists = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Joint") ~= nil then
			local parts = directParts(d)
			local g = { inst = d, group = d.Name, pos = d:GetAttribute("Joint") - rootOffset, parts = parts, axis = d:GetAttribute("SpinAxis") }
			g.skip = #parts == 0 -- an empty container (Krakling's Tail): its children hang off its parent instead
			table.insert(groups, g)
			byInst[d] = g
			exists[d.Name] = true
		end
	end
	for _, g in groups do
		if rename[g.group] then
			g.name = rename[g.group]
		elseif exists[g.group .. "2"] then
			g.name = g.group .. "1"
		else
			g.name = g.group
		end
	end
	-- parent group: nearest ancestor that is a real joint
	local function parentOf(g)
		local a = g.inst.Parent
		while a and a ~= model do
			local pg = byInst[a]
			if pg and not pg.skip then
				return pg
			end
			a = a.Parent
		end
		return nil
	end
	local list = {}
	for _, g in groups do
		if not g.skip then
			g.parentGroup = parentOf(g)
			table.insert(list, g)
		end
	end
	local byJointName = {}
	for _, g in list do
		byJointName[g.name] = g
	end
	for _, g in list do
		local o = parentsOverride[g.name]
		if o == "Body" then
			g.parentGroup = nil
		elseif o and byJointName[o] then
			g.parentGroup = byJointName[o]
		end
	end
	for _, g in list do
		local depth, p = 0, g.parentGroup
		while p do
			depth += 1
			p = p.parentGroup
		end
		g.depth = depth
	end
	local order = {}
	for i, g in list do
		order[g] = i
	end
	table.sort(list, function(a, b)
		if a.depth ~= b.depth then
			return a.depth < b.depth
		end
		return order[a] < order[b]
	end)
	local index = {}
	for i, g in list do
		index[g] = i
	end

	local map = { joints = {}, body = {} }
	for i, g in list do
		local j = {
			name = g.name,
			group = g.group,
			path = pathOf(model, g.inst),
			parent = g.parentGroup and index[g.parentGroup] or 0,
			pos = g.pos,
			axis = g.axis,
			parts = #g.parts,
		}
		-- farthest brick from the joint (tentacle reach)
		local far, farPos = -1, nil
		for _, p in g.parts do
			local lp = rootCF:PointToObjectSpace(p.Position) / scale
			local d = (lp - g.pos).Magnitude
			if d > far then
				far, farPos = d, lp
			end
		end
		j.tipPos = farPos
		for _, p in g.parts do
			if p.Name == "Eye" then
				j.eyes = true
				break
			end
		end
		map.joints[i] = j
	end
	if bodyGroup then
		local parts = directParts(bodyGroup)
		map.body.path = "Body"
		map.body.parts = #parts
		if #parts > 0 then
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, p in parts do
				local lp = rootCF:PointToObjectSpace(p.Position) / scale
				lo, hi = lo:Min(lp), hi:Max(lp)
			end
			local c = (lo + hi) / 2
			map.body.pos = Vector3.new(0, c.Y, c.Z)
		end
	end
	if not map.body.pos then
		local sum, n = Vector3.zero, 0
		for _, j in map.joints do
			if j.parent == 0 then
				sum += j.pos
				n += 1
			end
		end
		map.body.pos = n > 0 and Vector3.new(0, sum.Y / n, sum.Z / n) or Vector3.zero
	end
	local _, size = model:GetBoundingBox()
	map.size = size / scale
	finish(map, profileName, profile)
	-- planted limbs pivot about their feet; the body pivots at the centre of the planted limbs
	for _, j in map.joints do
		if j.planted then
			local g = byJointName[j.name]
			j.foot = g and footOf(g.parts, rootCF, scale)
			if not j.foot then
				j.planted = false
			end
		end
	end
	if map.centre and map.body.path then
		map.body.pos = map.centre ~= map.body.pos and map.centre or map.body.pos
	end
	cache[key] = map
	return map
end

local function newPivot(folder, name, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = true
	p.CFrame = cf
	p.Parent = folder
	return p
end

-- Pivots and motors for a brick kaiju; the welds and unanchoring happen in Rig.Step.
function Rig.Begin(model, map)
	local root = model.PrimaryPart
	local rootCF = root.CFrame
	local scale = model:GetAttribute("VisualScale") or 1
	local byPath = {}
	local function walk(parent, prefix)
		for _, c in parent:GetChildren() do
			if c:IsA("Model") then
				local p = prefix == "" and c.Name or prefix .. "/" .. c.Name
				byPath[p] = c
				walk(c, p)
			end
		end
	end
	walk(model, "")

	-- every brick and the pivot it will hang from (collected before the rig folder exists)
	local folder = Instance.new("Folder")
	folder.Name = Rig.FolderName
	local bodyPivot = newPivot(folder, "Body", rootCF * CFrame.new(map.body.pos * scale))
	local pivots = table.create(#map.joints)
	local ownerOf = {}
	if map.body.path and byPath[map.body.path] then
		ownerOf[byPath[map.body.path]] = bodyPivot
	end
	local eyes = {}
	for i, j in map.joints do
		local pv = newPivot(folder, j.name, rootCF * CFrame.new(j.pos * scale))
		pivots[i] = pv
		local g = byPath[j.path]
		if g then
			ownerOf[g] = pv
			if j.eyes then
				local list = {}
				for _, c in g:GetChildren() do
					if c:IsA("BasePart") and c.Name == "Eye" then
						table.insert(list, c)
					end
				end
				eyes[i] = list
			end
		end
	end
	local parts, owners = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local a = d.Parent
			local owner
			while a and a ~= model do
				owner = ownerOf[a]
				if owner then
					break
				end
				a = a.Parent
			end
			table.insert(parts, d)
			table.insert(owners, owner or root) -- loose parts (no body group) stay with the root
		end
	end

	local motors = table.create(#map.joints)
	local bodyMotor = Instance.new("Motor6D")
	bodyMotor.Name = "Body"
	bodyMotor.Part0 = root
	bodyMotor.Part1 = bodyPivot
	bodyMotor.C0 = CFrame.new(map.body.pos * scale)
	bodyMotor.Parent = folder
	for i, j in map.joints do
		local parentPivot = j.parent == 0 and bodyPivot or pivots[j.parent]
		local parentPos = j.parent == 0 and map.body.pos or map.joints[j.parent].pos
		local m = Instance.new("Motor6D")
		m.Name = j.name
		m.Part0 = parentPivot
		m.Part1 = pivots[i]
		m.C0 = CFrame.new((j.pos - parentPos) * scale)
		m.Parent = folder
		motors[i] = m
	end
	folder.Parent = model
	return {
		model = model,
		root = root,
		folder = folder,
		map = map,
		scale = scale,
		bodyPivot = bodyPivot,
		bodyMotor = bodyMotor,
		pivots = pivots,
		motors = motors,
		eyes = eyes,
		parts = parts,
		owners = owners,
		stage = 1,
		i = 1,
	}
end

-- One slice of the build. Returns true once the rig is live.
function Rig.Step(job, deadline)
	if job.stage == 4 then
		return true -- already live (guardians use their existing motors)
	end
	local parts, owners = job.parts, job.owners
	local n = #parts
	if job.stage == 1 then
		-- welds (both ends still anchored, so nothing moves)
		local folder, i = job.folder, job.i
		while i <= n do
			local w = Instance.new("WeldConstraint")
			w.Part0 = owners[i]
			w.Part1 = parts[i]
			w.Parent = folder
			i += 1
			if i % 24 == 0 and os.clock() > deadline then
				break
			end
		end
		job.i = i
		if i > n then
			job.stage, job.i = 2, 1
		end
		return false
	elseif job.stage == 2 then
		-- bricks: unanchored, each still held by its weld to an anchored pivot
		local i = job.i
		while i <= n do
			local p = parts[i]
			p.Massless = true
			p.Anchored = false
			i += 1
			if i % 48 == 0 and os.clock() > deadline then
				break
			end
		end
		job.i = i
		if i > n then
			job.stage = 3
		end
		return false
	elseif job.stage == 3 then
		-- pivots last: from here the whole rig hangs off the anchored root through the motors
		job.bodyPivot.Anchored = false
		for _, p in job.pivots do
			p.Anchored = false
		end
		job.stage = 4
	end
	return job.stage == 4
end

-- A guardian's existing motors (Humanoid rig from GuardianService, Body motor included). Groups are found by the
-- builder's naming: motor "LegL" carries the bricks of Model "LegLGroup".
function Rig.FromMotors(model, spec, profileName, profile)
	local root = model.PrimaryPart
	local rootCF = root.CFrame
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local body = motors.Body
	if not body then
		return nil
	end
	-- rest frames in root space: a motor's joint frame is Part0's rest frame x C0; Part1's rest frame is that x C1^-1
	local partRest = { [root] = CFrame.identity }
	local jointRest = {}
	local pending = {}
	for name, m in motors do
		table.insert(pending, m)
	end
	local guard = 0
	while #pending > 0 and guard < 50 do
		guard += 1
		for i = #pending, 1, -1 do
			local m = pending[i]
			local p0 = partRest[m.Part0]
			if p0 then
				jointRest[m] = p0 * m.C0
				partRest[m.Part1] = jointRest[m] * m.C1:Inverse()
				table.remove(pending, i)
			end
		end
	end
	local list = {}
	for name, m in motors do
		if m ~= body and jointRest[m] then
			table.insert(list, { name = name, motor = m })
		end
	end
	-- parents before children
	local parentMotor = {}
	for _, e in list do
		for _, f in list do
			if f.motor.Part1 == e.motor.Part0 then
				parentMotor[e] = f
			end
		end
	end
	local function depth(e)
		local d, p = 0, parentMotor[e]
		while p do
			d += 1
			p = parentMotor[p]
		end
		return d
	end
	table.sort(list, function(a, b)
		local da, db = depth(a), depth(b)
		if da ~= db then
			return da < db
		end
		return a.name < b.name
	end)
	local index = {}
	for i, e in list do
		index[e] = i
	end
	local map = { joints = {}, body = { pos = jointRest[body].Position }, guardian = true }
	for i, e in list do
		map.joints[i] = {
			name = e.name,
			group = e.name .. "Group",
			parent = parentMotor[e] and index[parentMotor[e]] or 0,
			pos = jointRest[e.motor].Position,
			parts = 0,
		}
	end
	local _, size = model:GetBoundingBox()
	map.size = size
	finish(map, profileName, profile)
	for i, j in map.joints do
		if j.planted then
			local g = model:FindFirstChild(j.group)
			local parts = {}
			if g then
				for _, d in g:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(parts, d)
					end
				end
			end
			j.foot = #parts > 0 and footOf(parts, rootCF, 1) or nil
			j.planted = j.foot ~= nil
		end
	end
	local job = {
		model = model,
		root = root,
		map = map,
		scale = 1,
		bodyMotor = body,
		motors = {},
		eyes = {},
		stage = 4,
		guardian = true,
	}
	for i, e in list do
		job.motors[i] = e.motor
	end
	return job
end

return Rig
