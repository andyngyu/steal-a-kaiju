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

local PROPS = { "Bush", "BerryBush", "Boulder", "Tree", "FlowersPink", "FlowersMixed", "FlowersRed", "Grass", "Mushroom", "VineShort", "VineLong", "NestSign" }

-- Builds every Prop_* spec into ServerStorage.Assets.Props (pivot = centre of the base, facing -Z).
function BiomeArtBuilder.BuildProps()
	local B, specs = tools()
	local folder = assetFolder("Props")
	local out = {}
	for _, name in PROPS do
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
		store(folder, model)
		table.insert(out, name .. " " .. tostring(model:GetAttribute("Bricks")))
		task.wait()
	end
	return "props: " .. table.concat(out, ", ")
end

-- Replaces the biome's old blocky Decor with brick props: trees along the walls, bushes and boulders in the side bands,
-- flowers / grass / mushrooms everywhere off the centre line, vines down both cliff faces and a NEST sign. Keeps clear of
-- the nest, the guardian's bed and the middle of the path.
local function dressProps(laneModel)
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
	local center = laneModel.NestSite.Center
	local nest = Vector3.new(center.Position.X, 0, center.Position.Z)
	local bed = center.GuardianSpawn.WorldPosition
	bed = Vector3.new(bed.X, 0, bed.Z)
	local rng = Random.new(9)
	local taken = {}
	local function free(pos, r)
		if (pos - nest).Magnitude < 12.5 + r or (pos - bed).Magnitude < 10 + r then
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
				d.CanCollide = collide
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
	-- trees along both walls
	for _, s in { -1, 1 } do
		local x = x0 + 14 + rng:NextNumber(0, 6)
		while x < x1 - 8 do
			local pos = Vector3.new(x, 0, s * (halfZ - 6.5))
			if free(pos, 5) then
				put("Tree", CFrame.new(pos) * yaw(), rng:NextNumber(0.9, 1.15), true, 5)
			end
			x += rng:NextNumber(24, 32)
		end
	end
	-- bushes and boulders in the side bands
	local placed, tries = 0, 0
	while placed < 14 and tries < 300 do
		tries += 1
		local s = rng:NextInteger(0, 1) == 0 and -1 or 1
		local pos = Vector3.new(rng:NextNumber(x0 + 6, x1 - 6), 0, s * rng:NextNumber(17, halfZ - 3))
		local roll = rng:NextNumber()
		local name = roll < 0.38 and "Bush" or roll < 0.6 and "BerryBush" or "Boulder"
		local scale = rng:NextNumber(0.8, 1.25)
		if free(pos, 3 * scale) then
			put(name, CFrame.new(pos) * yaw(), scale, name == "Boulder", 3 * scale)
			placed += 1
		end
	end
	-- flowers, grass and mushrooms everywhere off the centre line
	local small = { "FlowersPink", "FlowersMixed", "FlowersRed", "Grass", "Grass", "Mushroom" }
	placed, tries = 0, 0
	while placed < 26 and tries < 500 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(x0 + 3, x1 - 3), 0, rng:NextNumber(-halfZ + 3, halfZ - 3))
		if math.abs(pos.Z) > 4 and free(pos, 1.2) then
			put(small[rng:NextInteger(1, #small)], CFrame.new(pos) * yaw(), rng:NextNumber(0.9, 1.3), false, 1.2)
			placed += 1
		end
	end
	-- vines hanging down both cliff faces (leaves point into the lane)
	local wallTop = MapConfig.Lane.WallHeight
	for _, s in { -1, 1 } do
		local x = x0 + 4
		while x < x1 - 2 do
			local name = rng:NextInteger(0, 1) == 0 and "VineShort" or "VineLong"
			local len = props[name]:GetAttribute("Length") or 6
			put(name, CFrame.new(x, wallTop - len, s * halfZ) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), 1, false, nil)
			x += rng:NextNumber(13, 19)
		end
	end
	-- NEST sign beside the path near the entrance, arrow pointing into the biome
	put("NestSign", CFrame.new(x0 + 10, 0, 9), 1.5, true, 2)
	return "props " .. laneModel.Name .. ": " .. count
end

function BiomeArtBuilder.DressLane()
	local B, specs = tools()
	local lane = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lane")
	assert(lane, "no Workspace.Map.Lane - run MapBuilder first")
	local out = {}
	for _, biome in { "PebblePlains" } do
		local m = lane:FindFirstChild(biome)
		if m then
			table.insert(out, dressNest(B, specs, biome, m))
			task.wait()
			table.insert(out, dressProps(m))
			task.wait()
		end
	end
	return table.concat(out, "\n")
end

function BiomeArtBuilder.Build()
	local out = {}
	table.insert(out, BiomeArtBuilder.BuildEgg("PebblePlains"))
	task.wait()
	table.insert(out, BiomeArtBuilder.BuildGuardian("PebblePlains"))
	task.wait()
	table.insert(out, BiomeArtBuilder.BuildProps())
	task.wait()
	table.insert(out, BiomeArtBuilder.DressLane())
	return table.concat(out, "\n")
end

return BiomeArtBuilder
