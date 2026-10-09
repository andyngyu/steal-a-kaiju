--!strict
-- Edit-time greybox generator. Rebuilds Workspace.Map from MapConfig + BiomeConfig.
-- Run from the command bar: require(game.ServerStorage.Tools.MapBuilder:Clone()).Build()
-- (Clone + fresh config loads bypass Studio's module cache so edits take effect without restarting.)
--
-- Contract for runtime services (attributes are the API, not part names alone):
--   Map.Plots.Plot<n>            Model, PlotId=n, Side=-1|1. Children: Floor, Zone (invisible volume), NestPads/Pad<i> (PadIndex=i), Entrance (Attachment on Floor)
--   Map.Lane.<BiomeId>           Model, BiomeId, Order. Children: Floor, Zone (invisible volume), NestSite (Model: Center part with GuardianSpawn + EggSpawn<i> attachments), Sign
--   Map.Spawn.SpawnLocation, Map.Treadmill (Model with Belt, Treadmill=true)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config

local function fresh(module: ModuleScript): any
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local MapConfig = fresh(Config.MapConfig)
local BiomeConfig = fresh(Config.BiomeConfig)

local MapBuilder = {}

local function darken(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function studs(part: BasePart, faces: { Enum.NormalId })
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = MapConfig.StudTexture
		t.Face = face
		t.StudsPerTileU = 8
		t.StudsPerTileV = 8
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.8
		t.Parent = part
	end
end

local TOP = { Enum.NormalId.Top }
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top }

local function block(name: string, parent: Instance, size: Vector3, cframe: CFrame, color: Color3, faces: { Enum.NormalId }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if faces then
		studs(p, faces)
	end
	p.Parent = parent
	return p
end

local function zone(name: string, parent: Instance, size: Vector3, cframe: CFrame): Part
	local p = block(name, parent, size, cframe, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function invisibleWall(name: string, parent: Instance, size: Vector3, cframe: CFrame): Part
	local p = block(name, parent, size, cframe, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function sign(parent: Instance, name: string, pos: Vector3, face: Enum.NormalId, boardSize: Vector3, text: string)
	local model = Instance.new("Model")
	model.Name = name
	local wood = Color3.fromHex("8B5A2B")
	block("Post", model, Vector3.new(1, boardSize.Y + 4, 1), CFrame.new(pos + Vector3.new(0, (boardSize.Y + 4) / 2, 0)), darken(wood, 0.8))
	local board = block("Board", model, boardSize, CFrame.new(pos + Vector3.new(0, 4 + boardSize.Y / 2, 0)), wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = board
	model.Parent = parent
	return model
end

export type Summary = {
	laneStart: number,
	laneEnd: number,
	firstNestX: number,
	plotToFirstNest: { [string]: { studs: number, seconds: number } },
	partCount: number,
}

function MapBuilder.Build(): Summary
	local P = MapConfig.Plots
	local L = MapConfig.Lane
	local S = MapConfig.SpawnPlaza.Size
	local roadW = MapConfig.Road.Width
	local margin = MapConfig.BoundaryMargin

	local plotsEnd = P.FirstOffset + P.PerSide * P.Width + (P.PerSide - 1) * P.Gap
	local laneStart = plotsEnd + L.GapAfterPlots
	local laneLength = 0
	for _, b in BiomeConfig.List do
		laneLength += b.Length
	end
	local laneEnd = laneStart + laneLength
	local plotFarZ = roadW / 2 + P.Setback + P.Depth
	local hubHalfZ = math.max(plotFarZ, S / 2) + margin
	local westX = -S - margin

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"

	-- Ground under everything
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map
	local gx0, gx1 = westX, laneEnd + L.WallThickness
	block("Hub", ground, Vector3.new(laneStart - gx0, 2, hubHalfZ * 2), CFrame.new((gx0 + laneStart) / 2, -1, 0), Color3.fromHex("9BD47A"), TOP)
	block("LaneBase", ground, Vector3.new(gx1 - laneStart, 2, L.Width + L.WallThickness * 2), CFrame.new((laneStart + gx1) / 2, -1, 0), Color3.fromHex("9BD47A"))

	-- Hub boundary (invisible)
	local bounds = Instance.new("Folder")
	bounds.Name = "Bounds"
	bounds.Parent = map
	invisibleWall("West", bounds, Vector3.new(2, 60, hubHalfZ * 2), CFrame.new(westX - 1, 30, 0))
	invisibleWall("North", bounds, Vector3.new(laneStart - westX, 60, 2), CFrame.new((westX + laneStart) / 2, 30, hubHalfZ + 1))
	invisibleWall("South", bounds, Vector3.new(laneStart - westX, 60, 2), CFrame.new((westX + laneStart) / 2, 30, -hubHalfZ - 1))

	-- Spawn plaza
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "Spawn"
	spawnFolder.Parent = map
	block("Plaza", spawnFolder, Vector3.new(S, 0.2, S), CFrame.new(-S / 2, 0.1, 0), MapConfig.SpawnPlaza.Color, TOP)
	local spawn = workspace:FindFirstChild("SpawnLocation") :: SpawnLocation?
	if not spawn then
		spawn = Instance.new("SpawnLocation")
	end
	assert(spawn)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	local spawnPos = Vector3.new(-S / 2, 0.7, 0)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.xAxis)
	spawn.Parent = spawnFolder

	-- Treadmill spot (placeholder) on the plaza's north side
	local tm = Instance.new("Model")
	tm.Name = "Treadmill"
	tm:SetAttribute("Treadmill", true)
	local ts = MapConfig.Treadmill.Size
	local tmPos = Vector3.new(-S / 2, 0, S / 2 - ts.X / 2 - 4)
	block("Frame", tm, Vector3.new(ts.Z + 2, ts.Y, ts.X + 2), CFrame.new(tmPos + Vector3.new(0, 0.2 + ts.Y / 2, 0)), Color3.fromHex("2B1B4D"))
	local belt = block("Belt", tm, Vector3.new(ts.Z, 0.2, ts.X), CFrame.new(tmPos + Vector3.new(0, 0.3 + ts.Y, 0)), Color3.fromHex("1A1033"))
	belt.Material = Enum.Material.Fabric
	tm.PrimaryPart = belt
	sign(tm, "Sign", tmPos + Vector3.new(0, 0, -(ts.X / 2 + 3)), Enum.NormalId.Front, Vector3.new(10, 3, 0.5), "TREADMILL")
	tm.Parent = map

	-- Main road
	block("Road", map, Vector3.new(laneStart, 0.2, roadW), CFrame.new(laneStart / 2, 0.1, 0), MapConfig.Road.Color, TOP)

	-- Plots
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	local entrances: { [number]: Vector3 } = {}
	local id = 0
	for _, side in { -1, 1 } do
		for i = 0, P.PerSide - 1 do
			id += 1
			local color = P.Colors[id] or Color3.fromHex("CCCCCC")
			local cx = P.FirstOffset + P.Width / 2 + i * (P.Width + P.Gap)
			local cz = side * (roadW / 2 + P.Setback + P.Depth / 2)
			local model = Instance.new("Model")
			model.Name = `Plot{id}`
			model:SetAttribute("PlotId", id)
			model:SetAttribute("Side", side)

			local floor = block("Floor", model, Vector3.new(P.Width, P.FloorHeight, P.Depth), CFrame.new(cx, P.FloorHeight / 2, cz), color, TOP)
			model.PrimaryPart = floor
			local entrance = Instance.new("Attachment")
			entrance.Name = "Entrance"
			entrance.Position = Vector3.new(0, P.FloorHeight / 2, -side * (P.Depth / 2 - 2))
			entrance.Parent = floor
			entrances[id] = Vector3.new(cx, 0, cz - side * P.Depth / 2)

			local wallColor = darken(color, 0.7)
			local wh = P.WallHeight
			local backZ = cz + side * (P.Depth / 2 - 0.5)
			block("WallBack", model, Vector3.new(P.Width, wh, 1), CFrame.new(cx, P.FloorHeight + wh / 2, backZ), wallColor, SIDES)
			for _, sx in { -1, 1 } do
				block(sx < 0 and "WallLeft" or "WallRight", model, Vector3.new(1, wh, P.Depth), CFrame.new(cx + sx * (P.Width / 2 - 0.5), P.FloorHeight + wh / 2, cz), wallColor, SIDES)
			end

			local z = zone("Zone", model, Vector3.new(P.Width, 20, P.Depth), CFrame.new(cx, 10, cz))
			z:SetAttribute("PlotId", id)

			local padsFolder = Instance.new("Folder")
			padsFolder.Name = "NestPads"
			padsFolder.Parent = model
			local np = P.NestPads
			local padIndex = 0
			for r = 0, np.Rows - 1 do
				for c = 0, np.Columns - 1 do
					padIndex += 1
					local px = cx + (c - (np.Columns - 1) / 2) * np.Spacing
					local pz = cz + side * (P.Depth / 2 - 6 - r * np.Spacing)
					local pad = block(`Pad{padIndex}`, padsFolder, Vector3.new(np.Size, 0.4, np.Size), CFrame.new(px, P.FloorHeight + 0.2, pz), Color3.fromHex("FFF4D6"))
					pad:SetAttribute("PadIndex", padIndex)
					pad:SetAttribute("PlotId", id)
				end
			end

			local signFace = side < 0 and Enum.NormalId.Back or Enum.NormalId.Front
			sign(model, "Sign", Vector3.new(cx + P.Width / 2 - 3, P.FloorHeight, cz - side * (P.Depth / 2 - 1.5)), signFace, Vector3.new(8, 3, 0.5), `PLOT {id}`)
			model.Parent = plots
		end
	end

	-- Biome lane
	local lane = Instance.new("Folder")
	lane.Name = "Lane"
	lane.Parent = map
	local T = L.WallThickness
	local halfW = L.Width / 2
	for _, side in { -1, 1 } do
		block(side < 0 and "SideWallSouth" or "SideWallNorth", lane, Vector3.new(laneEnd - laneStart, L.SideWallHeight, T), CFrame.new((laneStart + laneEnd) / 2, L.SideWallHeight / 2, side * (halfW + T / 2)), Color3.fromHex("8A9A7B"), SIDES)
	end
	block("EndWall", lane, Vector3.new(T, L.CrossWallHeight, L.Width + T * 2), CFrame.new(laneEnd + T / 2, L.CrossWallHeight / 2, 0), Color3.fromHex("5A7A99"), SIDES)

	local function crossWall(name: string, x: number, halfSpan: number, color: Color3)
		local gateHalf = L.GateWidth / 2
		local segLen = halfSpan - gateHalf
		for _, side in { -1, 1 } do
			block(`{name}_{side < 0 and "S" or "N"}`, lane, Vector3.new(T, L.CrossWallHeight, segLen), CFrame.new(x, L.CrossWallHeight / 2, side * (gateHalf + segLen / 2)), color, SIDES)
		end
		block(`{name}_Lintel`, lane, Vector3.new(T, 6, L.GateWidth), CFrame.new(x, L.CrossWallHeight - 3, 0), darken(color, 0.85), SIDES)
	end

	local x0 = laneStart
	local firstNestX = 0
	for _, b in BiomeConfig.List do
		local m = Instance.new("Model")
		m.Name = b.Id
		m:SetAttribute("BiomeId", b.Id)
		m:SetAttribute("Order", b.Order)
		m:SetAttribute("RecommendedSpeed", b.RecommendedSpeed)
		local cx = x0 + b.Length / 2
		local floor = block("Floor", m, Vector3.new(b.Length, 0.2, L.Width), CFrame.new(cx, 0.1, 0), b.GroundColor, TOP)
		m.PrimaryPart = floor
		local z = zone("Zone", m, Vector3.new(b.Length, 40, L.Width), CFrame.new(cx, 20, 0))
		z:SetAttribute("BiomeId", b.Id)

		-- Entrance wall: the first one spans the whole hub width so it also closes off the base district.
		crossWall(`Gate{b.Order}`, x0, b.Order == 1 and hubHalfZ or halfW + T, b.WallColor)

		local nestX = x0 + b.NestAt * b.Length
		if b.Order == 1 then
			firstNestX = nestX
		end
		local site = Instance.new("Model")
		site.Name = "NestSite"
		local center = zone("Center", site, Vector3.new(1, 1, 1), CFrame.new(nestX, 0.5, 0))
		site.PrimaryPart = center
		local disc = block("Nest", site, Vector3.new(1, L.NestRadius * 2, L.NestRadius * 2), CFrame.new(nestX, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("8B5A2B"))
		disc.Shape = Enum.PartType.Cylinder
		local guardian = Instance.new("Attachment")
		guardian.Name = "GuardianSpawn"
		guardian.Position = Vector3.new(L.NestRadius + 8, 0, 0)
		guardian.Parent = center
		for k = 1, L.EggSpawnsPerNest do
			local a = (k - 1) / L.EggSpawnsPerNest * math.pi * 2
			local egg = Instance.new("Attachment")
			egg.Name = `EggSpawn{k}`
			egg.Position = Vector3.new(math.cos(a) * L.NestRadius * 0.6, 1, math.sin(a) * L.NestRadius * 0.6)
			egg.Parent = center
		end
		-- Placeholder guardian marker so the nest reads in greybox
		local gm = block("GuardianPlaceholder", site, Vector3.new(10, 12, 14), CFrame.new(nestX + L.NestRadius + 8, 6, 0), darken(b.GroundColor, 0.55))
		gm.Transparency = 0.4
		gm.CanCollide = false
		site.Parent = m

		sign(m, "Sign", Vector3.new(x0 - 6, 0, L.GateWidth / 2 + 7), Enum.NormalId.Left, Vector3.new(0.5, 5, 12), `{b.DisplayName}\nRecommended Speed: {b.RecommendedSpeed}`)
		m.Parent = lane
		x0 += b.Length
	end

	-- Summary: path = out of the plot to the road centre, along the road, through the gate to the nest.
	local speed = MapConfig.StartingWalkSpeed
	local timings = {}
	for pid, e in entrances do
		local d = math.abs(e.Z) + (firstNestX - e.X)
		timings[`Plot{pid}`] = { studs = math.round(d), seconds = math.round(d / speed * 10) / 10 }
	end

	local old2 = workspace:FindFirstChild("Baseplate")
	if old2 then
		old2:Destroy()
	end
	map.Parent = workspace

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
		plotToFirstNest = timings,
		partCount = count,
	}
end

return MapBuilder
