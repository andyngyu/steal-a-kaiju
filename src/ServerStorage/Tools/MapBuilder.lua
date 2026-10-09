-- Edit-time map generator. Rebuilds Workspace.Map from MapConfig + BiomeConfig.
-- Run from the command bar: require(game.ServerStorage.Tools.MapBuilder:Clone()).Build()
-- (Clone + fresh config loads bypass Studio's module cache so edits take effect without restarting.)
--
-- Runtime contract (attributes are the API):
--   Map                          attribute SafeZoneX (bases side is x < SafeZoneX)
--   Map.Plots.Plot<n>            Model, PlotId, Side (-1|1), Color, PenOrigin (front-centre of the pen, see Shared.Util.PenGeometry).
--                                Children: Zone (invisible, whole lot), EntranceMat (Attachment "Entrance"),
--                                Arch/Board (owner TextLabels), UpgradeSign (Board/SurfaceGui Title|Levels|PriceFrame.Price, Board.UpgradePrompt),
--                                TreadmillSpot (invisible; LookVector = runner facing), TreadmillSign (same layout as UpgradeSign, Board.TreadmillPrompt).
--                                The pen fence ("Pen") is built at runtime by BaseService for the owner's level.
--   Map.Lane.<BiomeId>           Model, BiomeId, Order, RecommendedSpeed. Children: Zone (invisible volume, BiomeId),
--                                NestSite (Model; Center part has GuardianSpawn + EggSpawn<i> attachments),
--                                Sign (Board/SurfaceGui Title|Rec|Status; clients fill Status with the viewer's speed)
--   Map.Spawn.SpawnLocation
--   Map.Market: the Kaiju Market around the spawn plaza, built by Tools.MarketBuilder (see its header)
--   Map.Lane decoration: Tools.BiomeArtBuilder runs after the rebuild when it exists
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local MapConfig = fresh(Shared.Config.MapConfig)
local BiomeConfig = fresh(Shared.Config.BiomeConfig)
local PenGeometry = fresh(Shared.Util.PenGeometry)
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

local function label(parent, name, text, color, sizeY)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = UDim2.new(1, 0, sizeY, 0)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = parent
	return l
end

local function textGui(part, face, text, color, ppu)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 40
	local l = label(gui, "Label", text, color, 1)
	gui.Parent = part
	return l
end

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
	for _ = 1, math.floor((x1 - x0) / 9) do
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

-- Navy shop board (reference: Steal An Egg's "Upgrade Pen" sign). `cf` is the base; the Front face looks along its LookVector.
local function shopSign(parent, name, cf, title, middleName, middleText, priceText, promptName, promptAction, scale)
	scale = scale or 1
	local sign = Instance.new("Model")
	sign.Name = name
	local facePath = cf
	local navy = Color3.fromHex("1F2A44")
	for _, sx in { -3.5, 3.5 } do
		block("Post", sign, Vector3.new(1, 5, 1) * scale, facePath * CFrame.new(sx * scale, 2.5 * scale, 0.3 * scale), navy)
	end
	local board = block("Board", sign, Vector3.new(10, 6, 0.8) * scale, facePath * CFrame.new(0, 7 * scale, 0), navy, SIDES)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.03, 0)
	list.Parent = gui
	label(gui, "Title", title, Color3.new(1, 1, 1), 0.3).LayoutOrder = 1
	label(gui, middleName, middleText, Color3.fromHex("6BE04A"), 0.22).LayoutOrder = 2
	local priceFrame = Instance.new("Frame")
	priceFrame.Name = "PriceFrame"
	priceFrame.Size = UDim2.new(1, 0, 0.36, 0)
	priceFrame.LayoutOrder = 3
	priceFrame.BackgroundColor3 = Color3.fromHex("E02B2B")
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = priceFrame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromHex("1A1033")
	stroke.Parent = priceFrame
	label(priceFrame, "Price", priceText, Color3.new(1, 1, 1), 1)
	priceFrame.Parent = gui
	gui.Parent = board
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ActionText = promptAction
	prompt.ObjectText = title
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	sign.PrimaryPart = board
	sign.Parent = parent
	return sign
end

local function upgradeSign(model, frame, x, d)
	local facePath = frame * CFrame.new(x, 0, -d) * CFrame.Angles(0, math.rad(180), 0) -- Front face looks at the path
	shopSign(model, "UpgradeSign", facePath, "Upgrade Pen", "Levels", "Level 1 > Level 2", "$0", "UpgradePrompt", "Upgrade Pen")
end

-- Biome entrance sign: name, recommended speed, and a Status line each client fills in with the viewer's own speed.
local function biomeSign(parent, b, pos)
	local model = Instance.new("Model")
	model.Name = "Sign"
	model:SetAttribute("RecommendedSpeed", b.RecommendedSpeed)
	for _, dz in { -5, 5 } do
		block("Post", model, Vector3.new(1.2, 10, 1.2), CFrame.new(pos + Vector3.new(0.4, 5, dz)), C.WoodDark)
	end
	local board = block("Board", model, Vector3.new(0.8, 7, 15), CFrame.new(pos + Vector3.new(0, 8.5, 0)), C.Wood, SIDES)
	block("Lamp", model, Vector3.new(1, 1.4, 1.4), CFrame.new(pos + Vector3.new(0, 12.8, 0)), Color3.fromHex("FFD23F"), nil, Enum.Material.Neon)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.02, 0)
	list.Parent = gui
	label(gui, "Title", b.DisplayName, Color3.new(1, 1, 1), 0.36).LayoutOrder = 1
	label(gui, "Rec", "Recommended Speed: " .. b.RecommendedSpeed, Color3.fromHex("FFD23F"), 0.26).LayoutOrder = 2
	label(gui, "Status", "", Color3.new(1, 1, 1), 0.26).LayoutOrder = 3
	gui.Parent = board
	model.PrimaryPart = board
	model.Parent = parent
	return model
end

local function buildPlot(plots, id, side, cx, frontZ)
	local P = MapConfig.Plots
	local color = P.Colors[id] or Color3.fromHex("CCCCCC")
	local model = Instance.new("Model")
	model.Name = "Plot" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("Side", side)
	model:SetAttribute("Color", color)
	model:SetAttribute("PenOrigin", Vector3.new(cx, 0, frontZ))
	local frame = PenGeometry.Frame(model)
	local function at(x, d, y)
		return frame * CFrame.new(x, y or 0, -d)
	end
	local eh = P.EntranceWidth / 2

	local zone = invisible("Zone", model, Vector3.new(P.LotWidth, 24, P.LotDepth), at(0, P.LotDepth / 2, 12), false)
	zone:SetAttribute("PlotId", id)
	model.PrimaryPart = zone

	local mat = block("EntranceMat", model, Vector3.new(P.EntranceWidth, 0.2, 6), at(0, 3, 0.1), color, TOP)
	local entrance = Instance.new("Attachment")
	entrance.Name = "Entrance"
	entrance.Position = Vector3.new(0, 0.1, 0)
	entrance.Parent = mat

	-- arch with owner board + coloured flags
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	for _, sx in { -1, 1 } do
		block("Pillar", arch, Vector3.new(1.4, 11, 1.4), at(sx * (eh + 0.2), 0, 5.5), C.WoodDark)
		block("Flag", arch, Vector3.new(0.2, 2.2, 3), at(sx * (eh + 0.2), 0, 12.1) * CFrame.new(0, 0, 1.6), color)
	end
	local board = block("Board", arch, Vector3.new(P.EntranceWidth + 2, 3, 0.8), at(0, 0, 9), color, SIDES)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		textGui(board, face, "PLOT " .. id)
	end
	arch.Parent = model

	upgradeSign(model, frame, eh + 9, -4)

	-- personal treadmill spot (front-left, outside the pen); TreadmillService builds the treadmill here
	local tx, td = -(eh + 11), -7
	local spot = invisible("TreadmillSpot", model, Vector3.new(5, 1, 10), at(tx, td, 0.5) * CFrame.Angles(0, math.rad(180), 0), false)
	spot:SetAttribute("PlotId", id)
	local tSign = shopSign(model, "TreadmillSign", at(tx - 7.5, td + 2, 0) * CFrame.Angles(0, math.rad(180), 0), "Treadmill", "Levels", "Unlock", "$0", "TreadmillPrompt", "Unlock Treadmill", 0.6)
	-- F / Y so it never competes with the treadmill's Run prompt (E) for the same key
	tSign.Board.TreadmillPrompt.KeyboardKeyCode = Enum.KeyCode.F
	tSign.Board.TreadmillPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
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

	local plotsEnd = P.FirstOffset + P.PerSide * P.LotWidth + (P.PerSide - 1) * P.Gap
	local laneStart = plotsEnd + L.GapAfterPlots
	local laneLength = 0
	for _, b in BiomeConfig.List do
		laneLength += b.Length
	end
	local laneEnd = laneStart + laneLength
	local plotFarZ = pathW / 2 + P.Setback + P.LotDepth
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

	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map
	checker(ground, westX, laneStart, -hubHalfZ, -pathW / 2, C.GrassA, C.GrassB)
	checker(ground, westX, laneStart, -pathW / 2, pathW / 2, C.PathA, C.PathB)
	checker(ground, westX, laneStart, pathW / 2, hubHalfZ, C.GrassA, C.GrassB)
	task.wait()

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

	local hubDecor = Instance.new("Folder")
	hubDecor.Name = "HubDecor"
	hubDecor.Parent = map
	for i = 0, 9 do
		local x = westX + 20 + i * ((laneStart - westX - 40) / 9)
		for _, s in { -1, 1 } do
			bush(hubDecor, rng, Vector3.new(x + rng:NextNumber(-6, 6), 0, s * (hubHalfZ - 7)), Color3.fromHex("3FB52A"))
		end
	end

	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "Spawn"
	spawnFolder.Parent = map
	block("Plaza", spawnFolder, Vector3.new(S, 0.3, S), CFrame.new(-S / 2, 0.15, 0), MapConfig.SpawnPlaza.Color, TOP)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	local spawnPos = Vector3.new(-S / 2, 0.8, 0)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.xAxis)
	spawn.Parent = spawnFolder
	local stray = workspace:FindFirstChild("SpawnLocation")
	if stray then
		stray:Destroy()
	end


	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	local entrances = {}
	local id = 0
	for _, side in { -1, 1 } do
		for i = 0, P.PerSide - 1 do
			id += 1
			local cx = P.FirstOffset + P.LotWidth / 2 + i * (P.LotWidth + P.Gap)
			local frontZ = side * (pathW / 2 + P.Setback)
			buildPlot(plots, id, side, cx, frontZ)
			entrances[id] = Vector3.new(cx, 0, frontZ)
		end
		task.wait()
	end

	local safe = block("SafeZoneLine", map, Vector3.new(4, 0.3, L.Width), CFrame.new(laneStart - 2, 0.15, 0), C.Cream)
	local safeLabel = textGui(safe, Enum.NormalId.Top, "SAFE ZONE", Color3.fromHex("3FA9FF"), 20)
	safeLabel.Rotation = -90

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

		biomeSign(m, b, Vector3.new(x0 + 4, 0, laneHalf - 10))
		decorateBiome(m, b, x0, x1, nestX, rng)
		x0 = x1
		task.wait()
	end
	local last = BiomeConfig.List[#BiomeConfig.List]
	cliff("EndWall", lane, Vector3.new(L.WallThickness, L.WallHeight, L.Width + L.WallThickness * 2), Vector3.new(laneEnd + L.WallThickness / 2, L.WallHeight / 2, 0), last.Wall, last.WallCap)

	local speed = MapConfig.StartingWalkSpeed
	local timings = {}
	for pid, e in entrances do
		timings["Plot" .. pid] = math.round((math.abs(e.Z) + (firstNestX - e.X)) / speed * 10) / 10
	end
	-- Kaiju Market (stalls around the spawn plaza) and the biome art pass
	local tools = game:GetService("ServerStorage").Tools
	require(tools.MarketBuilder:Clone()).Build(map)
	local art = tools:FindFirstChild("BiomeArtBuilder")
	if art then
		require(art:Clone()).Build()
	end

	local count = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return { laneStart = laneStart, firstNestX = firstNestX, secondsToFirstNest = timings, partCount = count }
end

return MapBuilder
