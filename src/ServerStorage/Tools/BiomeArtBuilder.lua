-- Edit-time tool: builds the brick biome art from Tools.BiomeArtSpecs with Tools.KaijuBuilder.BuildModel.
-- Command bar:
--   local A = require(game.ServerStorage.Tools.BiomeArtBuilder:Clone())
--   A.BuildEgg("PebblePlains")       -> ServerStorage.Assets.Eggs.PebblePlains (Lib.EggModel uses it, tints "Band" parts)
--   A.BuildGuardian("PebblePlains")  -> ServerStorage.Assets.Kaiju.Guardian_PebblePlains (GuardianService uses it)
--   A.BuildProps()                    -> ServerStorage.Assets.Props (bushes, boulders, trees, flowers, grass, vines...)
--   A.DressLane()                     nest art + props on Workspace.Map.Lane (run after MapBuilder rebuilds the map)
--   A.Build()                         all of the above (MapBuilder.Build calls it at the end)
--
-- Guardian rig: invisible HumanoidRootPart (spec.RootSize, bottom at spec.HipHeight) + Humanoid. Every body group gets an
-- invisible "<Group>Joint" part at its joint, driven by a Motor6D named after the group (LegL, Head, Jaw...) so clients
-- can set Motor6D.Transform (Gameplay.KaijuFX). Group parts are welded to their joint part, Body parts to the root.
-- A small invisible "Head" part carries the Sleep (Z Z) and Alert (!) billboards. Model attribute Rigged = true.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeArtBuilder = {}

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local function tools()
	return fresh(ServerStorage.Tools.KaijuBuilder), fresh(ServerStorage.Tools.BiomeArtSpecs)
end

local function assetFolder(name)
	local assets = ServerStorage:FindFirstChild("Assets")
	local f = assets:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = assets
	end
	return f
end

local function store(folder, model)
	local old = folder:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = folder
end

local function invisiblePart(name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- ---------- eggs ----------

function BiomeArtBuilder.BuildEgg(biomeId)
	local B, specs = tools()
	local EggConfig = fresh(ReplicatedStorage.Shared.Config.EggConfig)
	local spec = assert(specs["Egg_" .. biomeId], "no egg spec for " .. biomeId)
	local model = B.BuildModel(biomeId, spec)
	local bricks = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			table.insert(bricks, d)
		end
	end
	local size = EggConfig.Size
	local shell = invisiblePart("Shell", size, CFrame.new(0, size.Y / 2, 0))
	shell.Color = Color3.fromHex(spec.Palette.Cream) -- shell shards on hatch use this colour
	shell.Anchored = true
	shell.Parent = model
	for _, p in bricks do
		p.Parent = model
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		weld(shell, p)
	end
	for _, c in model:GetChildren() do
		if c:IsA("Model") or c.Name == "Root" then
			c:Destroy()
		end
	end
	model.PrimaryPart = shell
	model.Name = biomeId
	model:SetAttribute("Bricks", #bricks)
	store(assetFolder("Eggs"), model)
	return string.format("Egg %s: %d bricks", biomeId, #bricks)
end

-- ---------- guardians ----------

local function billboard(parent, name, text, color, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromOffset(160, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = bb
	bb.Parent = parent
	return bb
end

function BiomeArtBuilder.BuildGuardian(biomeId)
	local B, specs = tools()
	local name = "Guardian_" .. biomeId
	local spec = assert(specs[name], "no guardian spec for " .. biomeId)
	local model = B.BuildModel(name, spec)
	local oldRoot = model:FindFirstChild("Root")

	-- root: body-sized, bottom at the hip height, centred under the body
	local bodyCf, bodySize = model.Body:GetBoundingBox()
	local rootSize = Vector3.new(spec.RootSize[1], spec.RootSize[2], spec.RootSize[3])
	local hrp = invisiblePart("HumanoidRootPart", rootSize, CFrame.new(0, spec.HipHeight + rootSize.Y / 2, bodyCf.Position.Z))
	hrp.Parent = model

	-- one joint part + Motor6D per animated group (parents first)
	local jointParts = {}
	local groups = {}
	for _, g in model:GetDescendants() do
		if g:IsA("Model") and g:GetAttribute("Joint") then
			table.insert(groups, g)
		end
	end
	local function depth(g)
		local n, p = 0, g.Parent
		while p and p ~= model do
			n += 1
			p = p.Parent
		end
		return n
	end
	table.sort(groups, function(a, b)
		return depth(a) < depth(b)
	end)
	for _, g in groups do
		local jointCf = CFrame.new(g:GetAttribute("Joint"))
		local jp = invisiblePart(g.Name .. "Joint", Vector3.new(0.4, 0.4, 0.4), jointCf)
		jp.Parent = model
		local parentPart = jointParts[g.Parent] or hrp
		local motor = Instance.new("Motor6D")
		motor.Name = g.Name
		motor.Part0 = parentPart
		motor.Part1 = jp
		motor.C0 = parentPart.CFrame:ToObjectSpace(jointCf)
		motor.C1 = CFrame.identity
		motor.Parent = parentPart
		jointParts[g] = jp
	end

	-- weld every brick to its group's joint part (Body and loose parts to the root)
	local bricks = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp and d ~= oldRoot and not d.Name:match("Joint$") then
			local owner = d.Parent
			local target = jointParts[owner] or hrp
			weld(target, d)
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			bricks += 1
		end
	end

	-- billboard anchor above the head
	local headTop = model.Head:GetBoundingBox().Position + Vector3.new(0, 0, 0)
	local _, headSize = model.Head:GetBoundingBox()
	local anchor = invisiblePart("Head", Vector3.new(0.4, 0.4, 0.4), CFrame.new(headTop + Vector3.new(0, headSize.Y / 2, 0)))
	anchor.Parent = model
	weld(jointParts[model.Head], anchor)
	billboard(anchor, "Sleep", "Z Z", Color3.fromHex("BFE6FF"), 2.5)
	local alert = billboard(anchor, "Alert", "!", Color3.fromHex("FF4D5E"), 2.5)
	alert.Enabled = false

	-- groups become plain containers named <Group>Group so model.Head is the billboard anchor
	for _, g in groups do
		g.Name ..= "Group"
	end
	if oldRoot then
		oldRoot:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	hrp.Massless = false
	model.PrimaryPart = hrp
	hrp.PivotOffset = hrp.CFrame:ToObjectSpace(CFrame.new(0, 0, hrp.Position.Z)) -- pivot at the feet

	local hum = Instance.new("Humanoid")
	hum.HipHeight = spec.HipHeight
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = model

	model.Name = name
	model:SetAttribute("Rigged", true)
	model:SetAttribute("Bricks", bricks)
	store(assetFolder("Kaiju"), model)
	local _, ext = model:GetBoundingBox()
	return string.format("%s: %d bricks, %d joints, size %.1f x %.1f x %.1f", name, bricks, #groups, ext.X, ext.Y, ext.Z)
end

-- ---------- lane dressing ----------

-- Brick nest in place of MapBuilder's plain NestRing / NestBed (NestSite.Center and its attachments stay).
local function dressNest(B, specs, biome, laneModel)
	local spec = specs["Nest_" .. biome]
	local site = laneModel:FindFirstChild("NestSite")
	if not (spec and site) then
		return "no nest for " .. biome
	end
	for _, n in { "NestRing", "NestBed", "NestArt" } do
		local old = site:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	-- leave a gap in the woven ring facing the bases (-X) so players can walk in
	local shapes = {}
	for _, s in spec.Shapes do
		local keep = true
		if s.Group == "Ring" and s.Kind == "Capsule" then
			local mid = (Vector3.new(s.A[1], 0, s.A[3]) + Vector3.new(s.B[1], 0, s.B[3])) / 2
			local angle = math.atan2(mid.Z, mid.X)
			keep = math.abs(math.abs(angle) - math.pi) > math.rad(22)
		end
		if keep then
			table.insert(shapes, s)
		end
	end
	local bits = {}
	for _, b in spec.Bits or {} do
		local angle = math.atan2(b.C[3], b.C[1])
		if math.abs(math.abs(angle) - math.pi) > math.rad(26) then
			table.insert(bits, b)
		end
	end
	local trimmed = table.clone(spec)
	trimmed.Shapes = shapes
	trimmed.Bits = bits
	local nest = B.BuildModel("NestArt", trimmed)
	local center = site.Center.Position
	nest:PivotTo(CFrame.new(center.X, 0.1, center.Z))
	local root = nest:FindFirstChild("Root")
	if root then
		root:Destroy()
	end
	for _, d in nest:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = d.Parent.Name ~= "Pebbles" and d.Size.Magnitude > 0.8
			d.CanTouch = false
		end
	end
	nest.Parent = site
	return "nest " .. biome .. ": " .. nest:GetAttribute("Bricks") .. " bricks"
end

-- ---------- props ----------

local FX_TEX = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Blob = "rbxassetid://1084962479",
}

local function seq(a, b)
	return NumberSequence.new(a, b)
end

-- Prop effects (spec.Fx): an invisible anchored "FxAnchor" part at At (prop space; Area = its size for box-shaped
-- emitters) carrying the emitter or light. Kinds: Smoke, Embers, Bubbles, Sparkle, Glow (PointLight: Color, Range,
-- Brightness). Rate overrides the emitter rate. They travel with the prop (PivotTo / ScaleTo).
local function addFx(model, list)
	for _, f in list do
		local size = f.Area and Vector3.new(f.Area[1], f.Area[2], f.Area[3]) or Vector3.new(0.4, 0.4, 0.4)
		local p = invisiblePart("FxAnchor", size, CFrame.new(f.At[1], f.At[2], f.At[3]))
		p.Anchored = true
		p.Parent = model
		if f.Kind == "Glow" then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex(f.Color or "FFFFFF")
			light.Range = f.Range or 10
			light.Brightness = f.Brightness or 1
			light.Shadows = false
			light.Parent = p
		else
			local pe = Instance.new("ParticleEmitter")
			pe.LightInfluence = 0
			if f.Kind == "Smoke" then
				pe.Texture = FX_TEX.Smoke
				pe.Color = ColorSequence.new(Color3.fromHex("3A3232"), Color3.fromHex("6E6464"))
				pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(1, 1) })
				pe.Size = seq(1.4, 4.5)
				pe.Lifetime = NumberRange.new(2.5, 3.5)
				pe.Speed = NumberRange.new(2, 4)
				pe.SpreadAngle = Vector2.new(12, 12)
				pe.Acceleration = Vector3.new(0, 1, 0)
				pe.Rotation = NumberRange.new(0, 360)
				pe.RotSpeed = NumberRange.new(-20, 20)
				pe.Rate = f.Rate or 4
			elseif f.Kind == "Embers" then
				pe.Texture = FX_TEX.Sparks
				pe.Color = ColorSequence.new(Color3.fromHex("FFE24A"), Color3.fromHex("FF4A1A"))
				pe.LightEmission = 1
				pe.Size = seq(0.35, 0)
				pe.Lifetime = NumberRange.new(1, 1.8)
				pe.Speed = NumberRange.new(4, 9)
				pe.SpreadAngle = Vector2.new(25, 25)
				pe.Acceleration = Vector3.new(0, 3, 0)
				pe.Drag = 0.6
				pe.Rate = f.Rate or 5
			elseif f.Kind == "Bubbles" then
				pe.Texture = FX_TEX.Blob
				pe.Color = ColorSequence.new(Color3.fromHex("FFE070"), Color3.fromHex("FF6A1F"))
				pe.LightEmission = 1
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.8), NumberSequenceKeypoint.new(1, 0) })
				pe.Lifetime = NumberRange.new(0.4, 0.7)
				pe.Speed = NumberRange.new(0.5, 1.5)
				pe.Shape = Enum.ParticleEmitterShape.Box
				pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				pe.EmissionDirection = Enum.NormalId.Top
				pe.Rate = f.Rate or 6
			elseif f.Kind == "Sparkle" then
				pe.Texture = FX_TEX.Sparkle
				pe.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("9FDCFF"))
				pe.LightEmission = 1
				pe.Size = seq(0.45, 0)
				pe.Lifetime = NumberRange.new(0.6, 1)
				pe.Speed = NumberRange.new(0, 0.5)
				pe.Shape = Enum.ParticleEmitterShape.Box
				pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				pe.Rate = f.Rate or 3
			end
			pe.Parent = p
		end
	end
end

-- Builds every Prop_* spec into ServerStorage.Assets.Props (pivot = centre of the base, facing -Z).
function BiomeArtBuilder.BuildProps()
	local B, specs = tools()
	local folder = assetFolder("Props")
	local out = {}
	local names = {}
	for key in specs do
		if key:sub(1, 5) == "Prop_" then
			table.insert(names, key:sub(6))
		end
	end
	table.sort(names)
	for _, name in names do
		local spec = specs["Prop_" .. name]
		local model = B.BuildModel(name, spec)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			end
		end
		if spec.Length then
			model:SetAttribute("Length", spec.Length)
		end
		if spec.Board then
			-- text on the arrow board: the widest brick at the board's height
			local best
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and math.abs(p.Position.Y - spec.Board.C[2]) < 0.3 and (not best or p.Size.X > best.Size.X) then
					best = p
				end
			end
			if best then
				best.Name = "Board"
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 60
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.FredokaOne
				l.TextScaled = true
				l.TextColor3 = Color3.fromHex("FFF4D6")
				l.TextStrokeTransparency = 0.2
				l.Text = "NEST >"
				l.Parent = gui
				gui.Parent = best
			end
		end
		if spec.Fx then
			addFx(model, spec.Fx)
		end
		store(folder, model)
		table.insert(out, name .. " " .. tostring(model:GetAttribute("Bricks")))
		task.wait()
	end
	return "props: " .. table.concat(out, ", ")
end

-- ---------- lane ground: dirt trail + wall trim ----------

local STUD_TEXTURE = "rbxassetid://6372755229"

local function colors(list)
	local out = {}
	for _, hex in list do
		table.insert(out, Color3.fromHex(hex))
	end
	return out
end

-- Anchored decor brick with studs on the given faces. Solid ones block players like the boulders do.
local function brick(parent, name, size, cf, color, faces, studScale, solid)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = STUD_TEXTURE
		t.Face = face
		t.StudsPerTileU = studScale
		t.StudsPerTileV = studScale
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.8
		t.Parent = p
	end
	p.Parent = parent
	return p
end

-- Catmull-Rom through the control points (Vector2 x, z), a point about every stud.
local function smoothPath(points)
	local out = {}
	for i = 1, #points - 1 do
		local p0, p1, p2, p3 = points[math.max(1, i - 1)], points[i], points[i + 1], points[math.min(#points, i + 2)]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude))
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			table.insert(out, (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5)
		end
	end
	table.insert(out, points[#points])
	return out
end

local function distToPolyline(p, pts)
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, ab = pts[i], pts[i + 1] - pts[i]
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end

-- Worn dirt trail: one branch from the entrance into the nest's walk-in gap, one round the nest and the guardian's bed
-- to the far end. Blocky 2-stud cells (merged into runs) with pebbles along the edges. Visual only (no collision /
-- queries), its top is 0.06 above the grass. Returns the trail's distance function for keeping props off it.
local function dressTrail(decor, x0, x1, halfZ, nest, rng, dress)
	local TRAIL_COLORS = colors(dress.Trail)
	local PEBBLE_COLORS = colors(dress.TrailPebbles)
	local V = Vector2.new
	local n = V(nest.X, nest.Z)
	local trails = {
		smoothPath({ V(x0 - 1, 2), V(x0 + 12, -3), V(x0 + 24, 2.5), V(n.X - 11.5, n.Y) }),
		smoothPath({
			V(x0 + 26, 1.5),
			V(n.X - 12, n.Y - 8),
			V(n.X - 2, n.Y - 14),
			V(n.X + 12, n.Y - 16),
			V(n.X + 28, n.Y - 13),
			V(n.X + 44, n.Y - 6),
			V(x1 - 12, -1),
			V(x1 + 1, 0),
		}),
	}
	local function trailDist(p)
		return math.min(distToPolyline(p, trails[1]), distToPolyline(p, trails[2]))
	end
	local function halfWidth(x)
		return 2.7 + 0.45 * math.sin(x * 0.41) + 0.3 * math.sin(x * 0.13 + 1)
	end
	local count = 0
	for gz = -halfZ + 2, halfZ - 4, 2 do
		local runStart, runColor = nil, nil
		local function flush(xEnd)
			if runStart then
				local len = xEnd - runStart
				brick(decor, "Trail", Vector3.new(len, 0.12, 2), CFrame.new(runStart + len / 2, 0, gz + 1), TRAIL_COLORS[runColor], { Enum.NormalId.Top }, 4, false)
				count += 1
			end
			runStart, runColor = nil, nil
		end
		for gx = x0, x1 - 2, 2 do
			local c = V(gx + 1, gz + 1)
			local on = trailDist(c) < halfWidth(c.X) and (c - n).Magnitude > 11
			local color = on and (math.noise(c.X / 7, c.Y / 7, 3.1) > 0.05 and 2 or 1) or nil
			if color ~= runColor then
				flush(gx)
				if color then
					runStart, runColor = gx, color
				end
			end
		end
		flush(x1)
	end
	-- pebbles along both edges, alternating sides
	for _, pts in trails do
		local side = 1
		for i = 3, #pts - 1, 3 do
			local dir = (pts[i + 1] - pts[i - 1]).Unit
			local normal = V(-dir.Y, dir.X)
			local p = pts[i] + normal * side * (halfWidth(pts[i].X) + 0.6)
			side = -side
			if p.X > x0 + 1 and p.X < x1 - 1 and math.abs(p.Y) < halfZ - 3 and (p - n).Magnitude > 11.5 and trailDist(p) > halfWidth(p.X) then
				local s = rng:NextNumber(0.7, 1.15)
				local h = rng:NextNumber(0.35, 0.55)
				brick(decor, "Pebble", Vector3.new(s, h, s * rng:NextNumber(0.75, 1)), CFrame.new(p.X, h / 2, p.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), PEBBLE_COLORS[rng:NextInteger(1, #PEBBLE_COLORS)], { Enum.NormalId.Top }, 1, false)
				count += 1
			end
		end
	end
	return count, function(pos)
		local p = V(pos.X, pos.Z)
		return trailDist(p) - halfWidth(p.X)
	end
end

-- Skirting along the foot of both cliffs: rocks of mixed size tucked into the wall, some capped (moss, snow, or a
-- glowing crust when trim.CapNeon) and the odd taller boulder. Solid, like the boulders. gaps[side] = { {xa, xb}, ... }
-- leaves room for props standing against the wall.
local function dressWallTrim(decor, x0, x1, halfZ, rng, trim, gaps)
	local ROCK_COLORS = colors(trim.Rocks)
	local CAP_COLORS = colors(trim.Caps)
	local count = 0
	for _, s in { -1, 1 } do
		local face = s > 0 and Enum.NormalId.Front or Enum.NormalId.Back -- the side facing into the lane
		local x = x0
		while x < x1 - 0.5 do
			local len = math.min(rng:NextNumber(3, 7), x1 - x)
			local blocked = false
			for _, g in gaps[s] or {} do
				if x + len > g[1] and x < g[2] then
					blocked = true
				end
			end
			local h = rng:NextNumber() < 0.15 and rng:NextNumber(3.6, 5) or rng:NextNumber(1.3, 3)
			local depth = rng:NextNumber(1.3, 2.4)
			local z = s * (halfZ - depth / 2 + 0.2)
			local rockColor = ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)]
			local capped = rng:NextNumber() < (trim.CapChance or 0.45)
			local capColor = CAP_COLORS[rng:NextInteger(1, #CAP_COLORS)]
			if not blocked then
				brick(decor, "WallRock", Vector3.new(len, h, depth + 0.4), CFrame.new(x + len / 2, h / 2, z), rockColor, { Enum.NormalId.Top, face }, 2, true)
				count += 1
				if capped then
					local cap = brick(decor, "Cap", Vector3.new(len - 0.3, 0.3, depth + 0.1), CFrame.new(x + len / 2, h + 0.15, z), capColor, trim.CapNeon and {} or { Enum.NormalId.Top }, 2, false)
					if trim.CapNeon then
						cap.Material = Enum.Material.Neon
					end
					count += 1
				end
			end
			x += len
		end
	end
	return count
end

local function pickWeighted(rng, picks)
	local total = 0
	for _, p in picks do
		total += p[2]
	end
	local roll = rng:NextNumber() * total
	for _, p in picks do
		roll -= p[2]
		if roll <= 0 then
			return p
		end
	end
	return picks[#picks]
end

-- Replaces the biome's old blocky Decor with brick art from specs.Dress_<BiomeId> (see the Pebble Plains entry in
-- Tools.BiomeArtSpecs for the format): a trail to the nest, trim along both cliffs, props against the cliffs, along
-- them, in the side bands and scattered off the path, and a NEST sign. Keeps clear of the nest, the guardian's bed and
-- the trail. Counts scale with the biome's floor area (they're given for 120 x 80).
local function dressProps(laneModel, dress)
	local props = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Props")
	if not props then
		return "no Assets.Props - run BuildProps"
	end
	local MapConfig = fresh(ReplicatedStorage.Shared.Config.MapConfig)
	local decor = laneModel:FindFirstChild("Decor")
	if decor then
		decor:ClearAllChildren()
	else
		decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = laneModel
	end
	local zone = laneModel.Zone
	local x0, x1 = zone.Position.X - zone.Size.X / 2, zone.Position.X + zone.Size.X / 2
	local halfZ = zone.Size.Z / 2
	local area = (x1 - x0) * halfZ * 2 / (120 * 80)
	local center = laneModel.NestSite.Center
	local nest = Vector3.new(center.Position.X, 0, center.Position.Z)
	local bed = center.GuardianSpawn.WorldPosition
	bed = Vector3.new(bed.X, 0, bed.Z)
	local rng = Random.new(9)
	local wallTop = MapConfig.Lane.WallHeight

	-- props standing against the cliffs are planned first so the trim leaves room for them; floor-standing ones go first
	-- and the rest skip the cliff above them
	local wallPlan, gaps = {}, { [-1] = {}, [1] = {} }
	local walls = table.clone(dress.Walls or {})
	table.sort(walls, function(a, b)
		return (a.Mode == "Floor" and 0 or 1) < (b.Mode == "Floor" and 0 or 1)
	end)
	local function inGap(s, x)
		for _, g in gaps[s] do
			if x > g[1] - 1 and x < g[2] + 1 then
				return true
			end
		end
		return false
	end
	for _, w in walls do
		for _, s in { -1, 1 } do
			local x = x0 + rng:NextNumber(2, 6) + (w.Mode == "Floor" and 10 or 0)
			while x < x1 - (w.Mode == "Floor" and 10 or 2) do
				local name = (w.Alt and rng:NextInteger(0, 1) == 1) and w.Alt or w.Name
				local model = props:FindFirstChild(name)
				if model and (w.Mode == "Floor" or not inGap(s, x)) then
					local len = model:GetAttribute("Length") or 6
					local y = w.Mode == "Hang" and wallTop - len or (w.Mode == "Band" and rng:NextNumber(w.Y[1], w.Y[2]) or 0)
					table.insert(wallPlan, { name = name, x = x, y = y, s = s, floor = w.Mode == "Floor" })
					if w.Mode == "Floor" then
						table.insert(gaps[s], { x - 4, x + 4 })
					end
				end
				x += rng:NextNumber(w.Every[1], w.Every[2])
			end
		end
	end

	local ground, offTrail = dressTrail(decor, x0, x1, halfZ, nest, rng, dress)
	ground += dressWallTrim(decor, x0, x1, halfZ, rng, dress.Trim, gaps)
	local taken = {}
	local function free(pos, r)
		if (pos - nest).Magnitude < 12.5 + r or (pos - bed).Magnitude < 10 + r or offTrail(pos) < r then
			return false
		end
		for _, t in taken do
			if (t[1] - pos).Magnitude < t[2] + r then
				return false
			end
		end
		return true
	end
	local count = 0
	local function put(name, cf, scale, collide, radius)
		local m = props[name]:Clone()
		if scale ~= 1 then
			m:ScaleTo(scale)
		end
		m:PivotTo(cf)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local fx = d.Name == "FxAnchor"
				d.CanCollide = collide and not fx
				d.CanQuery = collide and not fx
			end
		end
		m.Parent = decor
		if radius then
			table.insert(taken, { Vector3.new(cf.Position.X, 0, cf.Position.Z), radius })
		end
		count += 1
	end
	local function yaw()
		return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	local function scaleIn(range)
		return rng:NextNumber(range[1], range[2])
	end

	-- NEST sign on the right of the trail just inside the entrance, turned towards players coming in so its arrow points
	-- into the biome
	local sign = dress.Sign or "NestSign"
	if props:FindFirstChild(sign) then
		put(sign, CFrame.new(x0 + 12, 0, -10) * CFrame.Angles(0, 2.53, 0), 1.5, true, 2)
	end
	-- on the cliff faces (faces point into the lane)
	for _, p in wallPlan do
		local cf = CFrame.new(p.x, p.y, p.s * halfZ) * CFrame.Angles(0, p.s > 0 and 0 or math.pi, 0)
		if p.floor then
			put(p.name, cf, 1, false, nil)
			table.insert(taken, { Vector3.new(p.x, 0, p.s * (halfZ - 3)), 4 })
		else
			put(p.name, cf, 1, false, nil)
		end
	end
	-- along both cliffs
	local E = dress.Edge
	if E then
		for _, s in { -1, 1 } do
			local x = x0 + 14 + rng:NextNumber(0, 6)
			while x < x1 - 8 do
				local pick = pickWeighted(rng, E.Picks)
				local pos = Vector3.new(x, 0, s * (halfZ - (E.Inset or 6.5)))
				if props:FindFirstChild(pick[1]) and free(pos, E.Radius) then
					put(pick[1], CFrame.new(pos) * yaw(), scaleIn(E.Scale), pick[3] == true, E.Radius)
				end
				x += rng:NextNumber(E.Every[1], E.Every[2])
			end
		end
	end
	-- side bands
	local Bd = dress.Bands
	if Bd then
		local want = math.floor(Bd.Count * area + 0.5)
		local placed, tries = 0, 0
		while placed < want and tries < want * 25 do
			tries += 1
			local s = rng:NextInteger(0, 1) == 0 and -1 or 1
			local pos = Vector3.new(rng:NextNumber(x0 + 6, x1 - 6), 0, s * rng:NextNumber(17, halfZ - 3))
			local pick = pickWeighted(rng, Bd.Picks)
			local scale = scaleIn(Bd.Scale)
			local r = Bd.Radius * scale
			if props:FindFirstChild(pick[1]) and free(pos, r) then
				put(pick[1], CFrame.new(pos) * yaw(), scale, pick[3] == true, r)
				placed += 1
			end
		end
	end
	-- small things everywhere off the centre line
	local Sm = dress.Small
	if Sm then
		local want = math.floor(Sm.Count * area + 0.5)
		local placed, tries = 0, 0
		while placed < want and tries < want * 25 do
			tries += 1
			local pos = Vector3.new(rng:NextNumber(x0 + 3, x1 - 3), 0, rng:NextNumber(-halfZ + 3, halfZ - 3))
			local pick = pickWeighted(rng, Sm.Picks)
			local scale = pick[3] and rng:NextNumber(pick[3], pick[4]) or scaleIn(Sm.Scale)
			if math.abs(pos.Z) > 4 and props:FindFirstChild(pick[1]) and free(pos, 1.2) then
				put(pick[1], CFrame.new(pos) * yaw(), scale, false, 1.2)
				placed += 1
			end
		end
	end
	return "props " .. laneModel.Name .. ": " .. count .. ", trail + trim parts: " .. ground
end

-- Nest art + props for every lane biome that has specs.Dress_<BiomeId>.
function BiomeArtBuilder.DressLane()
	local B, specs = tools()
	local lane = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lane")
	assert(lane, "no Workspace.Map.Lane - run MapBuilder first")
	local out = {}
	local biomes = {}
	for _, m in lane:GetChildren() do
		if m:IsA("Model") and m:FindFirstChild("Zone") then
			table.insert(biomes, m)
		end
	end
	table.sort(biomes, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	for _, m in biomes do
		local dress = specs["Dress_" .. m.Name]
		if dress then
			table.insert(out, dressNest(B, specs, m.Name, m))
			task.wait()
			table.insert(out, dressProps(m, dress))
			task.wait()
		end
	end
	return table.concat(out, "\n")
end

-- Every biome's egg + guardian (when it has specs), all props, then the lane dressing.
function BiomeArtBuilder.Build()
	local _, specs = tools()
	local BiomeConfig = fresh(ReplicatedStorage.Shared.Config.BiomeConfig)
	local out = {}
	for _, biome in BiomeConfig.List do
		if specs["Egg_" .. biome.Id] then
			table.insert(out, BiomeArtBuilder.BuildEgg(biome.Id))
			task.wait()
		end
		if specs["Guardian_" .. biome.Id] then
			table.insert(out, BiomeArtBuilder.BuildGuardian(biome.Id))
			task.wait()
		end
	end
	table.insert(out, BiomeArtBuilder.BuildProps())
	task.wait()
	table.insert(out, BiomeArtBuilder.DressLane())
	return table.concat(out, "\n")
end

return BiomeArtBuilder
