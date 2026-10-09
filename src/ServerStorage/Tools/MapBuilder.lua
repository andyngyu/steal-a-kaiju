-- Edit-time map generator. Rebuilds Workspace.Map from MapConfig + BiomeConfig.
-- Run from the command bar: require(game.ServerStorage.Tools.MapBuilder:Clone()).Build()
-- (Clone + fresh config loads bypass Studio's module cache so edits take effect without restarting.)
--
-- Runtime contract (attributes are the API):
--   Map                          attribute SafeZoneX (bases side is x < SafeZoneX)
--   Map.Plots.Plot<n>            Model, PlotId=n, Side=-1|1. Children: Zone (invisible volume, PlotId), EntranceMat (Attachment "Entrance"),
--                                NestPads/Pad<i> (PadIndex, PlotId), Arch/Board/SurfaceGui/OwnerLabel
--   Map.Lane.<BiomeId>           Model, BiomeId, Order, RecommendedSpeed. Children: Zone (invisible volume, BiomeId),
--                                NestSite (Model; Center part has GuardianSpawn + EggSpawn<i> attachments)
--   Map.Spawn.SpawnLocation, Map.Treadmill (Model, Treadmill=true, Belt)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = ReplicatedStorage.Shared.Config

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local MapConfig = fresh(Config.MapConfig)
local BiomeConfig = fresh(Config.BiomeConfig)
local C = MapConfig.Palette

local MapBuilder = {}

local TOP = { Enum.NormalId.Top }
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function darken(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function studs(part, faces, transparency)
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = MapConfig.StudTexture
		t.Face = face
		t.StudsPerTileU = 4
		t.StudsPerTileV = 4
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = transparency or 0.82
		t.Parent = part
	end
end

local function block(name, parent, size, cframe, color, faces, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if faces then
		studs(p, faces)
	end
	p.Parent = parent
	return p
end

local function cylinder(name, parent, height, diameter, pos, color, material)
	local p = block(name, parent, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, nil, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function invisible(name, parent, size, cframe, collide)
	local p = block(name, parent, size, cframe, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = collide
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function textGui(part, face, text, color, ppu)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 40
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

-- Checkerboard ground over a rectangle, tiles aligned to a global grid so neighbouring areas line up.
local function checker(parent, x0, x1, z0, z1, colorA, colorB)
	local T = MapConfig.TileSize
	local ix0, ix1 = math.floor(x0 / T), math.ceil(x1 / T) - 1
	local iz0, iz1 = math.floor(z0 / T), math.ceil(z1 / T) - 1
	for ix = ix0, ix1 do
		local ax, bx = math.max(ix * T, x0), math.min((ix + 1) * T, x1)
		for iz = iz0, iz1 do
			local az, bz = math.max(iz * T, z0), math.min((iz + 1) * T, z1)
			if bx - ax > 0.01 and bz - az > 0.01 then
				local color = ((ix + iz) % 2 == 0) and colorA or colorB
				block("Tile", parent, Vector3.new(bx - ax, 2, bz - az), CFrame.new((ax + bx) / 2, -1, (az + bz) / 2), color, TOP)
			end
		end
	end
end

-- Dirt cliff wall with a grass cap, like the reference lanes.
local function cliff(name, parent, size, center, wallColor, capColor)
	local m = Instance.new("Model")
	m.Name = name
	block("Dirt", m, size, CFrame.new(center), wallColor, SIDES)
	block("Band", m, Vector3.new(size.X + 0.2, 2, size.Z + 0.2), CFrame.new(center + Vector3.new(0, -size.Y / 2 + 1, 0)), darken(wallColor, 0.8))
	block("Cap", m, Vector3.new(size.X + 2, 2, size.Z + 2), CFrame.new(center + Vector3.new(0, size.Y / 2 + 1, 0)), capColor, { Enum.NormalId.Top, unpack(SIDES) })
	m.Parent = parent
	return m
end

local function signpost(parent, name, pos, face, boardSize, text)
	local model = Instance.new("Model")
	model.Name = name
	local h = 4 + boardSize.Y
	block("Post", model, Vector3.new(1, h, 1), CFrame.new(pos + Vector3.new(0, h / 2, 0)), C.WoodDark)
	local board = block("Board", model, boardSize, CFrame.new(pos + Vector3.new(0, 4 + boardSize.Y / 2, 0)), C.Wood, SIDES)
	textGui(board, face, text)
	model.Parent = parent
	return model
end

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 175)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local cc = Lighting:FindFirstChild("KaijuColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "KaijuColor"
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.22
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(205, 230, 255)
	atm.Decay = Color3.fromRGB(120, 170, 230)
	atm.Glare = 0.1
	atm.Haze = 0.6
	atm.Parent = Lighting
end

-- ---------- decorations ----------

local function bush(parent, rng, pos, color)
	local m = Instance.new("Model")
	m.Name = "Bush"
	local w, d, h = rng:NextInteger(6, 10), rng:NextInteger(5, 8), rng:NextInteger(3, 4)
	block("Base", m, Vector3.new(w, h, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)), color, { Enum.NormalId.Top, unpack(SIDES) })
	block("Top", m, Vector3.new(w - 3, h - 1, d - 2), CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), h + (h - 1) / 2, rng:NextNumber(-1, 1))), darken(color, 1.08), { Enum.NormalId.Top, unpack(SIDES) })
	m.Parent = parent
end

local function rocks(parent, rng, pos, color, count, maxSize)
	for _ = 1, count do
		local s = rng:NextNumber(1, maxSize)
		local off = Vector3.new(rng:NextNumber(-3, 3), s * 0.35, rng:NextNumber(-3, 3))
		block("Rock", parent, Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(pos + off) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), color, TOP)
	end
end

local function reeds(parent, rng, pos)
	for _ = 1, 3 do
		local h = rng:NextNumber(4, 7)
		block("Reed", parent, Vector3.new(0.4, h, 0.4), CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), h / 2, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color3.fromHex("2E8B3E"))
	end
end

local function lavaPool(parent, rng, pos)
	local d = rng:NextInteger(9, 15)
	cylinder("LavaRim", parent, 0.5, d + 3, pos + Vector3.new(0, 0.25, 0), Color3.fromHex("4A3B3B"))
	local lava = cylinder("Lava", parent, 0.4, d, pos + Vector3.new(0, 0.35, 0), Color3.fromHex("FF6A1F"), Enum.Material.Neon)
	lava.CanCollide = false
end

local function crystal(parent, rng, pos)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(3, 7)
		local p = block("Ice", parent, Vector3.new(1.4, h, 1.4), CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), h / 2 - 0.3, rng:NextNumber(-2, 2))) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)), Color3.fromHex("9FE3FF"), nil, Enum.Material.Glass)
		p.Transparency = 0.25
	end
end

local function pine(parent, rng, pos)
	local m = Instance.new("Model")
	m.Name = "Pine"
	block("Trunk", m, Vector3.new(1.5, 3, 1.5), CFrame.new(pos + Vector3.new(0, 1.5, 0)), C.WoodDark)
	local y = 3
	for i, w in { 9, 7, 5, 3 } do
		block("Leaves" .. i, m, Vector3.new(w, 2.5, w), CFrame.new(pos + Vector3.new(0, y + 1.25, 0)), Color3.fromHex("2E7D4F"), TOP)
		block("Snow" .. i, m, Vector3.new(w - 1, 0.4, w - 1), CFrame.new(pos + Vector3.new(0, y + 2.7, 0)), Color3.new(1, 1, 1))
		y += 2.5
	end
	m.Parent = parent
end

local function decorateBiome(parent, b, x0, x1, nestX, rng)
	local L = MapConfig.Lane
	local half = L.Width / 2 - 5
	local clear = L.ClearPathWidth / 2
	local function spot()
		for _ = 1, 30 do
			local x = rng:NextNumber(x0 + 6, x1 - 6)
			local side = rng:NextInteger(0, 1) == 0 and -1 or 1
			local z = side * rng:NextNumber(clear, half)
			if math.abs(x - nestX) > L.NestRadius + 18 or math.abs(z) > L.NestRadius + 14 then
				return Vector3.new(x, 0, z)
			end
		end
		return nil
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = parent
	local n = math.floor((x1 - x0) / 9)
	for _ = 1, n do
		local p = spot()
		if not p then
			continue
		end
		local roll = rng:NextNumber()
		if b.Decor == "Plains" then
			if roll < 0.45 then
				bush(decor, rng, p, Color3.fromHex("3FB52A"))
			elseif roll < 0.75 then
				rocks(decor, rng, p, Color3.fromHex("B9B9C4"), 3, 2.5)
			else
				reeds(decor, rng, p)
			end
		elseif b.Decor == "Lava" then
			if roll < 0.4 then
				lavaPool(decor, rng, p)
			else
				rocks(decor, rng, p, Color3.fromHex("4A3B3B"), 3, 4)
			end
		else
			if roll < 0.4 then
				pine(decor, rng, p)
			elseif roll < 0.8 then
				crystal(decor, rng, p)
			else
				rocks(decor, rng, p, Color3.new(1, 1, 1), 2, 4)
			end
		end
	end
end

-- ---------- plots ----------

local function fenceLine(parent, a, b, y, color)
	-- rails between two ground points
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	for _, h in { 1.2, 2.6 } do
		block("Rail", parent, Vector3.new(0.35, 0.45, len), cf + Vector3.new(0, y + h, 0), color)
	end
end

local function buildPlot(plots, id, side, cx, cz)
	local P = MapConfig.Plots
	local color = P.Colors[id] or Color3.fromHex("CCCCCC")
	local model = Instance.new("Model")
	model.Name = "Plot" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("Side", side)

	local W, D = P.Width, P.Depth
	local frontZ = cz - side * D / 2 -- edge facing the path
	local backZ = cz + side * D / 2
	local x0, x1 = cx - W / 2, cx + W / 2
	local eh = P.EntranceWidth / 2

	-- fence posts along the perimeter, skipping the entrance
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model
	local function post(x, z)
		block("Post", fence, Vector3.new(0.9, P.FenceHeight + 0.4, 0.9), CFrame.new(x, (P.FenceHeight + 0.4) / 2, z), C.WoodDark)
		block("Cap", fence, Vector3.new(1.2, 0.5, 1.2), CFrame.new(x, P.FenceHeight + 0.65, z), color)
	end
	local nx = math.max(1, math.round(W / P.PostSpacing))
	local nz = math.max(1, math.round(D / P.PostSpacing))
	for i = 0, nx do
		local x = x0 + W * i / nx
		post(x, backZ)
		if math.abs(x - cx) > eh + 0.1 then
			post(x, frontZ)
		end
	end
	for j = 1, nz - 1 do
		local z = frontZ + (backZ - frontZ) * j / nz
		post(x0, z)
		post(x1, z)
	end
	post(cx - eh, frontZ)
	post(cx + eh, frontZ)
	fenceLine(fence, Vector3.new(x0, 0, backZ), Vector3.new(x1, 0, backZ), 0, C.Wood)
	fenceLine(fence, Vector3.new(x0, 0, frontZ), Vector3.new(x0, 0, backZ), 0, C.Wood)
	fenceLine(fence, Vector3.new(x1, 0, frontZ), Vector3.new(x1, 0, backZ), 0, C.Wood)
	fenceLine(fence, Vector3.new(x0, 0, frontZ), Vector3.new(cx - eh, 0, frontZ), 0, C.Wood)
	fenceLine(fence, Vector3.new(cx + eh, 0, frontZ), Vector3.new(x1, 0, frontZ), 0, C.Wood)

	-- entrance mat + arch with owner board
	local mat = block("EntranceMat", model, Vector3.new(P.EntranceWidth, 0.2, 6), CFrame.new(cx, 0.1, frontZ + side * 3), color, TOP)
	local entrance = Instance.new("Attachment")
	entrance.Name = "Entrance"
	entrance.Position = Vector3.new(0, 0.1, 0)
	entrance.Parent = mat
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	for _, sx in { -1, 1 } do
		block("Pillar", arch, Vector3.new(1.4, 10, 1.4), CFrame.new(cx + sx * (eh + 0.2), 5, frontZ), C.WoodDark)
	end
	local board = block("Board", arch, Vector3.new(P.EntranceWidth + 2, 3, 0.8), CFrame.new(cx, 9, frontZ), color, SIDES)
	local label = textGui(board, side < 0 and Enum.NormalId.Back or Enum.NormalId.Front, "PLOT " .. id)
	label.Name = "OwnerLabel"
	label.Parent.Name = "OwnerGui"
	local inner = textGui(board, side < 0 and Enum.NormalId.Front or Enum.NormalId.Back, "PLOT " .. id)
	inner.Name = "OwnerLabelInner"
	arch.Parent = model

	-- banner at the back corner
	local bx = x1 - 2
	block("BannerPole", model, Vector3.new(0.8, 18, 0.8), CFrame.new(bx, 9, backZ - side * 2), C.WoodDark)
	block("Banner", model, Vector3.new(0.3, 5, 7), CFrame.new(bx, 15, backZ - side * 2 - side * 3.8), color)

	-- zone for delivery / ownership checks
	local zone = invisible("Zone", model, Vector3.new(W, 24, D), CFrame.new(cx, 12, cz), false)
	zone:SetAttribute("PlotId", id)

	-- nest pads
	local pads = Instance.new("Folder")
	pads.Name = "NestPads"
	pads.Parent = model
	local np = P.NestPads
	local padIndex = 0
	for r = 0, np.Rows - 1 do
		for c = 0, np.Columns - 1 do
			padIndex += 1
			local px = cx + (c - (np.Columns - 1) / 2) * np.Spacing
			local pz = cz + side * (D / 2 - np.BackInset - r * np.Spacing)
			block("PadRim", model, Vector3.new(np.Size + 1.2, 0.4, np.Size + 1.2), CFrame.new(px, 0.2, pz), color)
			local pad = block("Pad" .. padIndex, pads, Vector3.new(np.Size, 0.6, np.Size), CFrame.new(px, 0.3, pz), C.Cream, TOP)
			pad:SetAttribute("PadIndex", padIndex)
			pad:SetAttribute("PlotId", id)
		end
	end

	model.PrimaryPart = zone
	model.Parent = plots
end

-- ---------- build ----------

function MapBuilder.Build()
	local P = MapConfig.Plots
	local L = MapConfig.Lane
	local H = MapConfig.Hub
	local S = MapConfig.SpawnPlaza.Size
	local pathW = MapConfig.Path.Width
	local rng = Random.new(MapConfig.DecorSeed)

	local plotsEnd = P.FirstOffset + P.PerSide * P.Width + (P.PerSide - 1) * P.Gap
	local laneStart = plotsEnd + L.GapAfterPlots
	local laneLength = 0
	for _, b in BiomeConfig.List do
		laneLength += b.Length
	end
	local laneEnd = laneStart + laneLength
	local plotFarZ = pathW / 2 + P.Setback + P.Depth
	local hubHalfZ = math.max(plotFarZ, S / 2) + H.Margin
	local westX = -S - H.Margin
	local laneHalf = L.Width / 2

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local oldBase = workspace:FindFirstChild("Baseplate")
	if oldBase then
		oldBase:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map:SetAttribute("SafeZoneX", laneStart)
	map.Parent = workspace

	setupLighting()

	-- ground
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map
	checker(ground, westX, laneStart, -hubHalfZ, -pathW / 2, C.GrassA, C.GrassB)
	checker(ground, westX, laneStart, -pathW / 2, pathW / 2, C.PathA, C.PathB)
	checker(ground, westX, laneStart, pathW / 2, hubHalfZ, C.GrassA, C.GrassB)
	task.wait()

	-- hub cliffs
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map
	local wt, wh = H.WallThickness, H.WallHeight
	cliff("HubWest", walls, Vector3.new(wt, wh, hubHalfZ * 2 + wt * 2), Vector3.new(westX - wt / 2, wh / 2, 0), C.Dirt, C.GrassCap)
	for _, s in { -1, 1 } do
		cliff(s < 0 and "HubSouth" or "HubNorth", walls, Vector3.new(laneStart - westX, wh, wt), Vector3.new((westX + laneStart) / 2, wh / 2, s * (hubHalfZ + wt / 2)), C.Dirt, C.GrassCap)
		local span = hubHalfZ - laneHalf
		cliff(s < 0 and "HubEastS" or "HubEastN", walls, Vector3.new(wt, wh, span + wt), Vector3.new(laneStart + wt / 2, wh / 2, s * (laneHalf + (span + wt) / 2)), C.Dirt, C.GrassCap)
	end

	-- bushes along the hub cliffs
	local hubDecor = Instance.new("Folder")
	hubDecor.Name = "HubDecor"
	hubDecor.Parent = map
	for i = 0, 7 do
		local x = westX + 20 + i * ((laneStart - westX - 40) / 7)
		for _, s in { -1, 1 } do
			bush(hubDecor, rng, Vector3.new(x + rng:NextNumber(-6, 6), 0, s * (hubHalfZ - 6)), Color3.fromHex("3FB52A"))
		end
	end

	-- spawn plaza + treadmill
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "Spawn"
	spawnFolder.Parent = map
	block("Plaza", spawnFolder, Vector3.new(S, 0.3, S), CFrame.new(-S / 2, 0.15, 0), MapConfig.SpawnPlaza.Color, TOP)
	local spawn = workspace:FindFirstChild("SpawnLocation") or Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Transparency = 0
	local spawnPos = Vector3.new(-S / 2, 0.8, 0)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.xAxis)
	spawn.Parent = spawnFolder

	local tm = Instance.new("Model")
	tm.Name = "Treadmill"
	tm:SetAttribute("Treadmill", true)
	local ts = MapConfig.Treadmill.Size
	local tmPos = Vector3.new(-S / 2, 0.3, S / 2 - ts.X / 2 - 4)
	block("Frame", tm, Vector3.new(ts.Z + 2, ts.Y, ts.X + 2), CFrame.new(tmPos + Vector3.new(0, ts.Y / 2, 0)), Color3.fromHex("2B1B4D"))
	local belt = block("Belt", tm, Vector3.new(ts.Z, 0.2, ts.X), CFrame.new(tmPos + Vector3.new(0, ts.Y + 0.1, 0)), Color3.fromHex("1A1033"), nil, Enum.Material.Fabric)
	tm.PrimaryPart = belt
	signpost(tm, "Sign", tmPos + Vector3.new(0, 0, -(ts.X / 2 + 3)), Enum.NormalId.Front, Vector3.new(10, 3, 0.6), "TREADMILL")
	tm.Parent = map
	task.wait()

	-- plots
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	local entrances = {}
	local id = 0
	for _, side in { -1, 1 } do
		for i = 0, P.PerSide - 1 do
			id += 1
			local cx = P.FirstOffset + P.Width / 2 + i * (P.Width + P.Gap)
			local cz = side * (pathW / 2 + P.Setback + P.Depth / 2)
			buildPlot(plots, id, side, cx, cz)
			entrances[id] = Vector3.new(cx, 0, cz - side * P.Depth / 2)
		end
		task.wait()
	end

	-- safe zone line
	local safe = block("SafeZoneLine", map, Vector3.new(4, 0.3, L.Width), CFrame.new(laneStart - 2, 0.15, 0), MapConfig.Palette.Cream)
	local safeLabel = textGui(safe, Enum.NormalId.Top, "SAFE ZONE", Color3.fromHex("3FA9FF"), 20)
	safeLabel.Rotation = -90

	-- biome lane
	local lane = Instance.new("Folder")
	lane.Name = "Lane"
	lane.Parent = map
	local x0 = laneStart
	local firstNestX = 0
	for _, b in BiomeConfig.List do
		local x1 = x0 + b.Length
		local m = Instance.new("Model")
		m.Name = b.Id
		m:SetAttribute("BiomeId", b.Id)
		m:SetAttribute("Order", b.Order)
		m:SetAttribute("RecommendedSpeed", b.RecommendedSpeed)
		m.Parent = lane

		local floor = Instance.new("Folder")
		floor.Name = "Floor"
		floor.Parent = m
		checker(floor, x0, x1, -laneHalf, laneHalf, b.GroundA, b.GroundB)
		local zone = invisible("Zone", m, Vector3.new(b.Length, 50, L.Width), CFrame.new((x0 + x1) / 2, 25, 0), false)
		zone:SetAttribute("BiomeId", b.Id)
		m.PrimaryPart = zone

		for _, s in { -1, 1 } do
			cliff(s < 0 and "WallS" or "WallN", m, Vector3.new(b.Length, L.WallHeight, L.WallThickness), Vector3.new((x0 + x1) / 2, L.WallHeight / 2, s * (laneHalf + L.WallThickness / 2)), b.Wall, b.WallCap)
		end
		if b.Order > 1 then
			block("Border", m, Vector3.new(L.BorderWidth, 0.3, L.Width), CFrame.new(x0, 0.15, 0), b.Border, TOP)
		end

		local nestX = x0 + b.NestAt * b.Length
		if b.Order == 1 then
			firstNestX = nestX
		end
		local site = Instance.new("Model")
		site.Name = "NestSite"
		local center = invisible("Center", site, Vector3.new(1, 1, 1), CFrame.new(nestX, 0.5, 0), false)
		site.PrimaryPart = center
		cylinder("NestRing", site, 1.4, L.NestRadius * 2, Vector3.new(nestX, 0.7, 0), Color3.fromHex("8B5A2B"), Enum.Material.Wood)
		cylinder("NestBed", site, 1.5, L.NestRadius * 2 - 3, Vector3.new(nestX, 0.8, 0), Color3.fromHex("D9B26A"), Enum.Material.Fabric)
		local g = Instance.new("Attachment")
		g.Name = "GuardianSpawn"
		g.Position = Vector3.new(L.NestRadius + L.GuardianOffset, 0, 0)
		g.Parent = center
		for k = 1, L.EggSpawnsPerNest do
			local a = (k - 1) / L.EggSpawnsPerNest * math.pi * 2
			local e = Instance.new("Attachment")
			e.Name = "EggSpawn" .. k
			e.Position = Vector3.new(math.cos(a) * L.NestRadius * 0.55, 1.1, math.sin(a) * L.NestRadius * 0.55)
			e.Parent = center
		end
		site.Parent = m

		signpost(m, "Sign", Vector3.new(x0 + 4, 0, laneHalf - 8), Enum.NormalId.Left, Vector3.new(0.6, 5, 12), b.DisplayName .. "\nRecommended Speed: " .. b.RecommendedSpeed)
		decorateBiome(m, b, x0, x1, nestX, rng)
		x0 = x1
		task.wait()
	end
	local last = BiomeConfig.List[#BiomeConfig.List]
	cliff("EndWall", lane, Vector3.new(L.WallThickness, L.WallHeight, L.Width + L.WallThickness * 2), Vector3.new(laneEnd + L.WallThickness / 2, L.WallHeight / 2, 0), last.Wall, last.WallCap)

	local speed = MapConfig.StartingWalkSpeed
	local timings = {}
	for pid, e in entrances do
		local d = math.abs(e.Z) + (firstNestX - e.X)
		timings["Plot" .. pid] = math.round(d / speed * 10) / 10
	end
	local count = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return {
		laneStart = laneStart,
		laneEnd = laneEnd,
		firstNestX = firstNestX,
		secondsToFirstNest = timings,
		partCount = count,
	}
end

return MapBuilder
