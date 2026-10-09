-- Edit-time tool: builds the Kaiju Market around the spawn plaza and the food art. MapBuilder.Build() calls Build(map)
-- at the end of a full map rebuild; on its own (replaces Map.Market only; also clears the old Map.SpeedShop):
--   require(game.ServerStorage.Tools.MarketBuilder:Clone()).Build()
--   require(game.ServerStorage.Tools.MarketBuilder:Clone()).BuildFood()   -- ReplicatedStorage.Assets.Food from Tools.FoodSpecs
--
-- Every stall is the same booth in its own colours, built as one connected frame so it looks finished from every side:
-- studded deck and front step, four posts carrying beams, a striped canopy resting on the beams and sloping down to the
-- front (kaiju-teeth valance), half side walls, a full back wall (the stall's light colour inside, wood planks and a
-- colour band outside), a counter, the shopkeeper kaiju on a stand behind the counter, and the shop's name on a dark
-- board above the ridge (the KAIJU MARKET arch's style) crowned with glowing dorsal plates. A stone hub with a gold ring
-- replaces the bare spawn pad look, paths in each stall's colour lead from the hub to its pad, and bunting hangs
-- between the stalls.
--
-- Runtime contract (attributes are the API):
--   Map.Market.ShopTeleport          invisible part; Remotes.TeleportToShop puts players here
--   Map.Market.FoodStall / TrailStall / SellStall, each with:
--     Pad        part with attributes Shop ("Food" | "Trails" | "Sell"), Panel (UI panel name), Radius; PadRing beside it
--     SignAnchor part at the centre of the name board
--     OpenPrompt on the counter (attribute Panel)
--   Map.Market.Keepers               shopkeeper kaiju (Assets.Kaiju clones) standing behind the counters: VisualScale,
--                                    WanderFrom = WanderTo = standing spot, MoveStart = MoveEnd = 0 (animated by KaijuFX)
--   FoodStall.Items.<FoodId>         display Model, attribute FoodId; PrimaryPart.Tag billboard (Price, XP). Food is
--                                    bought in the UI's FoodShopPanel (pad / OpenPrompt), not off the counter.
--   FoodStall.RestockBoard           chalkboard by the pad; Board.Gui (SurfaceGui) with TextLabel "Time" (MarketFX fills it)
--   TrailStall.Wheel                 Center part + Orb parts (attributes TrailId, Index); clients spin them with trails
--   Market.Decor.KaijuStatue         golden Rumblerex on a plinth in the fourth corner (decor only)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local Shared = ReplicatedStorage.Shared
local MapConfig = fresh(Shared.Config.MapConfig)
local FoodConfig = fresh(Shared.Config.FoodConfig)
local TrailConfig = fresh(Shared.Config.TrailConfig)
local Format = fresh(Shared.Util.Format)

local MarketBuilder = {}

local hex = Color3.fromHex
local WHITE = hex("FFFFFF")
local INK = hex("1A1033")
local WOOD = hex("B8682E")
local WOOD_DARK = hex("6B4226")
local WOOD_LIGHT = hex("E3A562")
local BONE = hex("F4EBD3")
local BONE_SHADE = hex("DDCFAE")
local GOLD = hex("FFD23F")
local BOARD = hex("2B1B4D") -- the KAIJU MARKET arch's board colour, shared by every name board
local STONE = hex("D9CBB0")
local STONE_DARK = hex("BBA98A")

local TOP = { Enum.NormalId.Top }
local FRONT = { Enum.NormalId.Front }
local BACK = { Enum.NormalId.Back }
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local ALL = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local CYLINDER = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) upright

-- Plaza: S x S square centred at (-S/2, 0, 0); stalls sit on its north and south edges facing the spawn.
local THEMES = {
	Food = {
		Name = "FoodStall", Shop = "Food", Title = "KAIJU FOOD", Panel = "FoodShopPanel",
		Color = hex("43C93A"), Dark = hex("2A8A25"), Light = hex("E4FFD9"), Plate = hex("8CFF5A"),
		Pad = hex("A8F28E"), PadGlow = hex("5CFF3B"), TitleTop = hex("D9FFB8"), TitleBottom = hex("5CE63B"),
		Keeper = "Chompling", KeeperScale = 1.1, KeeperSide = -1, Filling = hex("C98A4B"),
	},
	Trails = {
		Name = "TrailStall", Shop = "Trails", Title = "TRAILS", Panel = "TrailShopPanel",
		Color = hex("FFC92E"), Dark = hex("D99A00"), Light = hex("FFF6CC"), Plate = hex("FFE24A"),
		Pad = hex("FFEC7A"), PadGlow = hex("FFD21F"), TitleTop = hex("FFF7B8"), TitleBottom = hex("FFC21F"),
		Keeper = "Prismling", KeeperScale = 0.85, KeeperSide = 1, Filling = hex("C77DFF"),
	},
	Sell = {
		Name = "SellStall", Shop = "Sell", Title = "SELL", Panel = "SellPanel",
		Color = hex("FF3B3B"), Dark = hex("B81E1E"), Light = hex("FFE3E3"), Plate = hex("FF4D6D"),
		Pad = hex("FFA8A8"), PadGlow = hex("FF3B3B"), TitleTop = hex("FF9C9C"), TitleBottom = hex("FF1F1F"),
		Keeper = "Bonkey", KeeperScale = 0.95, KeeperSide = 1, Filling = GOLD,
	},
}

-- Booth dimensions (stall-local; -Z is the front where customers stand).
local W, D = 14, 9 -- deck
local PX, PZ = 6.5, 4 -- post offsets from the centre
local DECK = 0.6
local FRONT_TOP, BACK_TOP = 8.6, 10.6 -- post tops; the canopy slopes down to the front
local BEAM = 0.8
local SLOPE = (BACK_TOP - FRONT_TOP) / (2 * PZ)
local TILT = math.atan(SLOPE)
local CANOPY_FRONT, CANOPY_BACK = -PZ - 1.4, PZ + 0.8
local CANOPY_W = 2 * PX + 2.2
local COUNTER_Z = -PZ + 0.8
local COUNTER_TOP = DECK + 3.35
local SHELF_Z = PZ - 1.05

-- Centre height of a 0.4-thick canopy slab resting on the beams at stall-local z.
local function roofY(z)
	return FRONT_TOP + BEAM + 0.2 + (z + PZ) * SLOPE
end

-- ---------- helpers ----------

local function studs(p, faces, tile)
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = MapConfig.StudTexture
		t.Face = face
		t.StudsPerTileU = tile or 2
		t.StudsPerTileV = tile or 2
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.75
		t.Parent = p
	end
end

-- opts: studs (faces), tile, neon, material, shape, collide (default true), shadow (default true), transparency
local function part(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.neon and Enum.Material.Neon or (opts.material or Enum.Material.SmoothPlastic)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.studs and not opts.neon then
		studs(p, opts.studs, opts.tile)
	end
	p.Parent = parent
	return p
end

local function textLabel(parent, name, text, color, font, sizeY, stroke)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, sizeY or 1, 0)
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	if stroke then
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = INK
		s.Parent = l
	else
		l.TextStrokeTransparency = 0.2
	end
	l.Parent = parent
	return l
end

-- Gradient title on a board face; the size cap keeps every shop name the same letter height.
local function boardTitle(board, face, text, top, bottom)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Title" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local l = textLabel(gui, "Label", text, WHITE, Enum.Font.LuckiestGuy, 0.8, 4)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.52)
	l.Size = UDim2.fromScale(0.92, 0.8)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 80
	cap.Parent = l
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = l
	gui.Parent = board
end

-- Stepped neon plates like Rumblerex's back.
local function plate(parent, cf, w, h, color)
	part(parent, "Plate", Vector3.new(w, h, 0.32), cf * CFrame.new(0, h / 2, 0), color, { neon = true, collide = false })
	part(parent, "Plate", Vector3.new(w * 0.5, h * 0.45, 0.32), cf * CFrame.new(0, h + h * 0.225, 0), color, { neon = true, collide = false })
end

-- Hanging lantern; cf = bottom of its chain (the chain runs 0.9 studs up from there).
local function lantern(parent, cf, color)
	part(parent, "Chain", Vector3.new(0.12, 0.9, 0.12), cf * CFrame.new(0, 0.45, 0), INK, { collide = false })
	part(parent, "LanternCap", Vector3.new(0.9, 0.25, 0.9), cf * CFrame.new(0, -0.1, 0), INK, { collide = false })
	local glow = part(parent, "Lantern", Vector3.new(0.7, 0.8, 0.7), cf * CFrame.new(0, -0.62, 0), color, { neon = true, collide = false })
	part(parent, "LanternCap", Vector3.new(0.9, 0.2, 0.9), cf * CFrame.new(0, -1.1, 0), INK, { collide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = 0.8
	light.Parent = glow
end

-- Shopkeeper: a real brick kaiju idling behind the counter (KaijuFX animates Map.Market.Keepers).
local function keeper(keepers, stallModel, theme, standCF, facePos)
	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Kaiju") and assets.Kaiju:FindFirstChild(theme.Keeper)
	if not art then
		warn("[MarketBuilder] no art for keeper " .. theme.Keeper)
		return
	end
	local m = art:Clone()
	m.Name = theme.Keeper
	m:ScaleTo(theme.KeeperScale)
	local pos = standCF.Position
	local look = Vector3.new(facePos.X, pos.Y, facePos.Z)
	m:PivotTo(CFrame.lookAt(pos, look))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	m:SetAttribute("Keeper", stallModel.Name)
	m:SetAttribute("Species", theme.Keeper)
	m:SetAttribute("VisualScale", theme.KeeperScale)
	m:SetAttribute("WanderFrom", pos)
	m:SetAttribute("WanderTo", pos)
	m:SetAttribute("MoveStart", 0)
	m:SetAttribute("MoveEnd", 0)
	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	m:SetAttribute("PartCount", parts)
	m.Parent = keepers
end

local function barrel(parent, pos, filling)
	part(parent, "Barrel", Vector3.new(2.2, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 1.1, 0)) * UP, WOOD, { shape = CYLINDER })
	for _, y in { 0.45, 1.75 } do
		part(parent, "Hoop", Vector3.new(0.18, 1.9, 1.9), CFrame.new(pos + Vector3.new(0, y, 0)) * UP, WOOD_DARK, { shape = CYLINDER, collide = false })
	end
	if filling then
		part(parent, "Filling", Vector3.new(0.3, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 2.25, 0)) * UP, filling, { shape = CYLINDER, collide = false, neon = filling == GOLD })
	end
end

-- ---------- stalls ----------

-- cf = ground centre of the stall; its LookVector points at the customers (local -Z is the front).
local function buildStall(parent, keepers, cf, theme)
	local m = Instance.new("Model")
	m.Name = theme.Name
	m:SetAttribute("Shop", theme.Shop)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	-- deck with a colour skirt, and a step at the front
	part(m, "Deck", Vector3.new(W, DECK, D), at(0, DECK / 2, 0), WOOD_DARK, { studs = TOP })
	part(m, "Skirt", Vector3.new(W + 0.3, 0.3, D + 0.3), at(0, 0.15, 0), theme.Dark, { collide = false })
	part(m, "Step", Vector3.new(W - 2, 0.3, 1.2), at(0, 0.15, -D / 2 - 0.6), WOOD, { studs = TOP })

	-- frame: four posts carrying four beams
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local top = sz < 0 and FRONT_TOP or BACK_TOP
			local h = top - DECK
			part(m, "Post", Vector3.new(1, h, 1), at(sx * PX, DECK + h / 2, sz * PZ), WOOD, { studs = SIDES })
			part(m, "PostFoot", Vector3.new(1.4, 0.5, 1.4), at(sx * PX, DECK + 0.25, sz * PZ), WOOD_DARK, { studs = TOP })
		end
	end
	part(m, "Beam", Vector3.new(2 * PX + 1.4, BEAM, 1.1), at(0, FRONT_TOP + BEAM / 2, -PZ), WOOD_DARK, { studs = SIDES })
	part(m, "Beam", Vector3.new(2 * PX + 1.4, BEAM, 1.1), at(0, BACK_TOP + BEAM / 2, PZ), WOOD_DARK, { studs = SIDES })
	local sideLen = math.sqrt((2 * PZ) ^ 2 + (BACK_TOP - FRONT_TOP) ^ 2)
	for _, sx in { -1, 1 } do
		part(m, "Beam", Vector3.new(1.1, BEAM, sideLen + 1.1), at(sx * PX, (FRONT_TOP + BACK_TOP) / 2 + BEAM / 2, 0) * CFrame.Angles(-TILT, 0, 0), WOOD_DARK, { studs = SIDES })
	end

	-- striped canopy lying on the beams
	local len = (CANOPY_BACK - CANOPY_FRONT) / math.cos(TILT)
	local midZ = (CANOPY_FRONT + CANOPY_BACK) / 2
	local stripes = 8
	for i = 0, stripes - 1 do
		local x = -CANOPY_W / 2 + CANOPY_W / stripes * (i + 0.5)
		part(m, "Canopy", Vector3.new(CANOPY_W / stripes + 0.02, 0.4, len), at(x, roofY(midZ), midZ) * CFrame.Angles(-TILT, 0, 0), i % 2 == 0 and theme.Color or WHITE, { studs = TOP })
	end
	local vy = roofY(CANOPY_FRONT) - 0.55
	part(m, "Valance", Vector3.new(CANOPY_W + 0.1, 0.9, 0.3), at(0, vy, CANOPY_FRONT), theme.Color, { studs = FRONT, collide = false })
	for i = 0, 12 do
		local x = -CANOPY_W / 2 + 0.55 + i * ((CANOPY_W - 1.1) / 12)
		part(m, "Tooth", Vector3.new(0.7, 0.7, 0.22), at(x, vy - 0.5, CANOPY_FRONT) * CFrame.Angles(0, 0, math.rad(45)), WHITE, { collide = false })
	end
	for _, sx in { -1, 1 } do
		part(m, "Fascia", Vector3.new(0.3, 0.9, len), at(sx * (CANOPY_W / 2 + 0.1), roofY(midZ) - 0.4, midZ) * CFrame.Angles(-TILT, 0, 0), theme.Color, { studs = { Enum.NormalId.Left, Enum.NormalId.Right }, collide = false })
	end
	local ridgeY = roofY(CANOPY_BACK) + 0.3
	part(m, "Ridge", Vector3.new(CANOPY_W + 0.4, 0.6, 1.0), at(0, ridgeY, CANOPY_BACK - 0.3), theme.Dark, { studs = TOP, collide = false })

	-- back wall: the stall's light colour inside; wood planks with a colour band outside
	local wallH = BACK_TOP - DECK
	part(m, "BackWall", Vector3.new(2 * PX, wallH, 0.5), at(0, DECK + wallH / 2, PZ), WOOD, { studs = BACK })
	for y = DECK + 1.1, BACK_TOP - 0.4, 1.25 do
		part(m, "Seam", Vector3.new(2 * PX - 0.2, 0.12, 0.08), at(0, y, PZ + 0.27), WOOD_DARK, { collide = false, shadow = false })
	end
	part(m, "Band", Vector3.new(2 * PX + 0.2, 1.4, 0.24), at(0, BACK_TOP - 2.6, PZ + 0.34), theme.Color, { studs = BACK, collide = false })
	part(m, "Inside", Vector3.new(2 * PX - 1, wallH - 0.2, 0.2), at(0, DECK + (wallH - 0.2) / 2, PZ - 0.35), theme.Light, { studs = FRONT })

	-- half side walls with a rail
	for _, sx in { -1, 1 } do
		part(m, "SideWall", Vector3.new(0.5, 3.0, 2 * PZ - 1), at(sx * PX, DECK + 1.5, 0), theme.Color, { studs = { Enum.NormalId.Left, Enum.NormalId.Right } })
		part(m, "SideRail", Vector3.new(0.8, 0.3, 2 * PZ + 0.2), at(sx * PX, DECK + 3.15, 0), WOOD_LIGHT, { studs = TOP })
	end

	-- counter between the front posts, kaiju claw scratches on its front
	part(m, "Counter", Vector3.new(2 * PX - 1, 3.0, 1.4), at(0, DECK + 1.5, COUNTER_Z), theme.Color, { studs = FRONT })
	part(m, "CounterBase", Vector3.new(2 * PX - 0.8, 0.35, 1.6), at(0, DECK + 0.175, COUNTER_Z), theme.Dark)
	part(m, "CounterTop", Vector3.new(2 * PX - 0.4, 0.35, 2.0), at(0, COUNTER_TOP - 0.175, COUNTER_Z), WOOD_LIGHT, { studs = TOP })
	for i = -1, 1 do
		part(m, "Scratch", Vector3.new(0.24, 1.9, 0.08), at(3.6 + i * 0.6, DECK + 1.6, COUNTER_Z - 0.72) * CFrame.Angles(0, 0, math.rad(-22)), theme.Dark, { collide = false })
	end

	-- name board above the ridge, crowned with dorsal plates
	local boardSize = Vector3.new(11, 3.2, 0.5)
	local boardY = ridgeY + 0.3 + 0.9 + boardSize.Y / 2
	local boardZ = CANOPY_BACK - 0.3
	for _, sx in { -1, 1 } do
		part(m, "SignPost", Vector3.new(0.5, 1.4, 0.5), at(sx * 3.6, ridgeY + 0.3 + 0.7, boardZ), WOOD_DARK, { collide = false })
	end
	local board = part(m, "SignBoard", boardSize, at(0, boardY, boardZ), BOARD, { collide = false })
	for _, dy in { -1, 1 } do
		part(m, "SignTrim", Vector3.new(boardSize.X + 0.3, 0.25, boardSize.Z + 0.1), at(0, boardY + dy * (boardSize.Y / 2 + 0.1), boardZ), GOLD, { neon = true, collide = false })
	end
	for _, sx in { -1, 1 } do
		part(m, "SignCap", Vector3.new(0.45, boardSize.Y + 0.7, boardSize.Z + 0.25), at(sx * (boardSize.X / 2 + 0.25), boardY, boardZ), theme.Color, { studs = SIDES, collide = false })
	end
	boardTitle(board, Enum.NormalId.Front, theme.Title, theme.TitleTop, theme.TitleBottom)
	boardTitle(board, Enum.NormalId.Back, theme.Title, theme.TitleTop, theme.TitleBottom)
	for _, p in { { 0, 1.5, 1.4 }, { -2.6, 1.15, 1.05 }, { 2.6, 1.15, 1.05 }, { -4.6, 0.8, 0.75 }, { 4.6, 0.8, 0.75 } } do
		plate(m, at(p[1], boardY + boardSize.Y / 2 + 0.2, boardZ), p[2], p[3], theme.Plate)
	end
	local anchor = part(m, "SignAnchor", Vector3.new(0.2, 0.2, 0.2), at(0, boardY, boardZ), WHITE, { transparency = 1, collide = false, shadow = false })
	anchor.CanQuery = false

	-- lanterns hanging from the front beam
	for _, sx in { -1, 1 } do
		lantern(m, at(sx * (PX - 1.3), FRONT_TOP - 0.9, -PZ), theme.Plate)
	end

	-- glowing studded pad in front of the step (stepping on it opens the shop's UI panel); plaza floor is 0.3 thick
	local padCF = at(0, 0.3, -D / 2 - 1.2 - 4.4)
	local ring = part(m, "PadRing", Vector3.new(0.16, 10.4, 10.4), padCF * CFrame.new(0, 0.08, 0) * UP, theme.PadGlow, { neon = true, shape = CYLINDER, collide = false })
	ring.CanQuery = false
	local pad = part(m, "Pad", Vector3.new(0.26, 9.2, 9.2), padCF * CFrame.new(0, 0.13, 0) * UP, theme.Pad, { shape = CYLINDER, studs = { Enum.NormalId.Right }, tile = 1.5, collide = false })
	pad:SetAttribute("Shop", theme.Shop)
	pad:SetAttribute("Radius", 4.6)
	pad:SetAttribute("Panel", theme.Panel)
	local padLight = Instance.new("PointLight")
	padLight.Color = theme.PadGlow
	padLight.Range = 12
	padLight.Brightness = 1.1
	padLight.Parent = pad

	-- shopkeeper on a stand behind the counter, looking at the pad
	local kx = theme.KeeperSide * 3.9
	local standH = 1.8
	part(m, "KeeperStand", Vector3.new(2.6, standH, 2.4), at(kx, DECK + standH / 2, 0.6), WOOD, { studs = ALL })
	part(m, "KeeperStandTrim", Vector3.new(2.7, 0.2, 2.5), at(kx, DECK + standH - 0.1, 0.6), theme.Dark, { collide = false })
	keeper(keepers, m, theme, at(kx, DECK + standH + 0.1 * theme.KeeperScale, 0.6), padCF.Position)

	-- a barrel against each side wall
	for _, sx in { -1, 1 } do
		barrel(m, at(sx * (PX + 1.9), 0, 1.6).Position, sx > 0 and theme.Filling or nil)
	end

	m.PrimaryPart = pad
	m.Parent = parent
	return m, at, padCF
end

-- An E prompt on the counter that opens a UI panel on the client (Gameplay.MarketFX).
local function openPrompt(m, at, action, panel)
	local holder = part(m, "PromptSpot", Vector3.new(0.2, 0.2, 0.2), at(0, COUNTER_TOP + 0.6, COUNTER_Z), WHITE, { transparency = 1, collide = false, shadow = false })
	holder.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = action
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Panel", panel)
	prompt.Parent = holder
end

local function shelves(m, at)
	for _, y in { 3.7, 5.6 } do
		part(m, "Shelf", Vector3.new(10.6, 0.25, 1.1), at(0, y, SHELF_Z), WOOD_LIGHT, { studs = TOP })
		for _, sx in { -1, 1 } do
			part(m, "ShelfBracket", Vector3.new(0.25, 0.6, 0.9), at(sx * 4.6, y - 0.4, SHELF_Z + 0.05), WOOD_DARK, { collide = false })
		end
	end
end

local function foodItems(m, at)
	local folder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Food")
	if not folder then
		warn("[MarketBuilder] no ReplicatedStorage.Assets.Food - run BuildFood() first")
		return
	end
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = m
	local xs = { 4.75, 2.85, 0.95, -0.95, -2.85, -4.75 } -- local +X is the customer's left: cheapest first
	for i, food in FoodConfig.Foods do
		local art = folder:FindFirstChild(food.Id)
		if art and xs[i] then
			local x = xs[i]
			part(m, "FoodPlate", Vector3.new(0.12, 1.55, 1.55), at(x, COUNTER_TOP + 0.06, COUNTER_Z) * UP, hex("F4F1FF"), { shape = CYLINDER, collide = false })
			local item = art:Clone()
			item.Name = food.Id
			item:SetAttribute("FoodId", food.Id)
			item:PivotTo(at(x, COUNTER_TOP + 0.22, COUNTER_Z) * CFrame.Angles(0, math.rad((i % 2 == 0) and 12 or -12), 0))
			local root = item.PrimaryPart
			local tag = Instance.new("BillboardGui")
			tag.Name = "Tag"
			tag.Size = UDim2.new(1.8, 0, 0.95, 0)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 1.85, 0)
			tag.MaxDistance = 45
			tag.LightInfluence = 0
			local list = Instance.new("UIListLayout")
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.Parent = tag
			textLabel(tag, "Price", Format.Money(food.Price), hex("6BE04A"), Enum.Font.FredokaOne, 0.56, 2).LayoutOrder = 1
			textLabel(tag, "XP", "+" .. Format.Short(food.XP) .. " XP", hex("5AD1FF"), Enum.Font.FredokaOne, 0.44, 2).LayoutOrder = 2
			tag.Parent = root
			item.Parent = items
		end
	end
	-- stock on the shelves
	shelves(m, at)
	local stock = Instance.new("Folder")
	stock.Name = "Stock"
	stock.Parent = m
	local shelfItems = { "Kibble", "Kibble", "Drumstick", "LavaPepper", "Kibble", "FrostFish", "Drumstick", "Kibble", "LavaPepper", "Drumstick" }
	for i, id in shelfItems do
		local art = folder:FindFirstChild(id)
		if art then
			local row = i <= 5 and 0 or 1
			local col = (i - 1) % 5
			local s = art:Clone()
			s:PivotTo(at(-4 + col * 2, 3.85 + row * 1.9, SHELF_Z) * CFrame.Angles(0, math.rad(15 - col * 7), 0))
			s.Parent = stock
		end
	end
end

-- Chalkboard on an easel beside the food pad: "RESTOCK IN 3:12" (MarketFX keeps the time current).
local function restockBoard(m, at)
	local folder = Instance.new("Model")
	folder.Name = "RestockBoard"
	local base = at(8.4, 0, -8.2) * CFrame.Angles(0, math.rad(-25), 0)
	for _, sx in { -1, 1 } do
		part(folder, "Leg", Vector3.new(0.3, 4.4, 0.3), base * CFrame.new(sx * 1.35, 2.2, 0.35) * CFrame.Angles(math.rad(-10), 0, 0), WOOD_DARK)
	end
	part(folder, "BackLeg", Vector3.new(0.3, 4.2, 0.3), base * CFrame.new(0, 2.0, 0.9) * CFrame.Angles(math.rad(18), 0, 0), WOOD_DARK)
	local boardCF = base * CFrame.new(0, 2.9, 0.2) * CFrame.Angles(math.rad(-10), 0, 0)
	part(folder, "Frame", Vector3.new(3.1, 2.5, 0.2), boardCF * CFrame.new(0, 0, 0.05), WOOD)
	local board = part(folder, "Board", Vector3.new(2.8, 2.2, 0.12), boardCF * CFrame.new(0, 0, -0.07), hex("2E4A35"), { collide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = gui
	local header = textLabel(gui, "Header", "FRESH FOOD IN", hex("E8F5E0"), Enum.Font.FredokaOne, 0.3)
	header.LayoutOrder = 1
	header.TextStrokeTransparency = 1
	local time = textLabel(gui, "Time", "5:00", hex("FFE600"), Enum.Font.FredokaOne, 0.45)
	time.LayoutOrder = 2
	time.TextStrokeTransparency = 1
	local foot = textLabel(gui, "Footer", "rare food sells out fast!", hex("B8D8B0"), Enum.Font.FredokaOne, 0.18)
	foot.LayoutOrder = 3
	foot.TextStrokeTransparency = 1
	gui.Parent = board
	folder.Parent = m
end

local function trailWheel(m, at)
	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	local center = part(wheel, "Center", Vector3.new(0.4, 0.4, 0.4), at(0, 6.0, PZ - 0.75), WHITE, { transparency = 1, collide = false, shadow = false })
	center.CanQuery = false
	local radius = 2.3
	local segments = 20
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local pos = center.CFrame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		part(wheel, "Rim", Vector3.new(0.75, 0.32, 0.32), pos * CFrame.Angles(0, 0, a + math.pi / 2), i % 2 == 0 and INK or hex("3A2A6B"), { collide = false })
	end
	part(wheel, "Hub", Vector3.new(0.3, 1.0, 1.0), center.CFrame * CFrame.Angles(0, math.rad(90), 0), GOLD, { neon = true, shape = CYLINDER, collide = false })
	for i, trail in TrailConfig.List do
		local a = (i - 1) / #TrailConfig.List * math.pi * 2
		local orb = part(wheel, "Orb", Vector3.new(0.55, 0.55, 0.55), center.CFrame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, -0.35), hex(trail.Colors[math.ceil(#trail.Colors / 2)]:gsub("#", "")), { neon = true, shape = Enum.PartType.Ball, collide = false })
		orb.CanQuery = false
		orb:SetAttribute("TrailId", trail.Id)
		orb:SetAttribute("Index", i)
	end
	wheel.PrimaryPart = center
	wheel.Parent = m
	-- streamer ribbons in every trail colour hanging from the front beam
	for i, trail in TrailConfig.List do
		local x = -5.1 + (i - 1) * (10.2 / (#TrailConfig.List - 1))
		local c = hex(trail.Colors[1]:gsub("#", ""))
		local h = 1.4 + (i % 2) * 0.5
		part(m, "Streamer", Vector3.new(0.3, h, 0.08), at(x, FRONT_TOP - h / 2, -PZ - 0.6), c, { neon = trail.LightEmission >= 0.9, collide = false })
	end
end

local function sellDecor(m, at)
	shelves(m, at)
	-- cash register
	local reg = at(-3.6, COUNTER_TOP, COUNTER_Z + 0.05)
	part(m, "Register", Vector3.new(1.8, 1.0, 1.3), reg * CFrame.new(0, 0.5, 0), hex("2B2F3A"), { studs = TOP })
	part(m, "RegisterScreen", Vector3.new(1.2, 0.55, 0.12), reg * CFrame.new(0, 1.35, 0.2) * CFrame.Angles(math.rad(-15), 0, 0), hex("6BE04A"), { neon = true, collide = false })
	for kx = -1, 1 do
		for kz = 0, 1 do
			part(m, "Key", Vector3.new(0.26, 0.12, 0.22), reg * CFrame.new(kx * 0.42, 1.04, -0.15 - kz * 0.32), GOLD, { collide = false })
		end
	end
	-- coin piles
	for p, n in { [-1.2] = 3, [0.2] = 5, [1.4] = 2 } do
		for c = 1, n do
			part(m, "Coin", Vector3.new(0.18, 0.8, 0.8), at(p, COUNTER_TOP + 0.09 + (c - 1) * 0.18, COUNTER_Z - 0.1) * UP * CFrame.Angles(math.rad(c * 23), 0, 0), GOLD, { shape = CYLINDER, collide = false })
		end
	end
	-- money bag with a $
	local bag = part(m, "MoneyBag", Vector3.new(1.4, 1.4, 1.4), at(3.4, COUNTER_TOP + 0.65, COUNTER_Z + 0.1), hex("C9A27E"), { shape = Enum.PartType.Ball, collide = false })
	part(m, "BagTie", Vector3.new(0.6, 0.3, 0.6), at(3.4, COUNTER_TOP + 1.4, COUNTER_Z + 0.1), hex("8B5A2B"), { collide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	textLabel(gui, "Dollar", "$", hex("2BA84A"), Enum.Font.LuckiestGuy, 1, 3)
	gui.Parent = bag
	-- gold bars and bags on the shelves
	for row = 0, 1 do
		for col = 0, 4 do
			local x = -4 + col * 2
			local y = 3.85 + row * 1.9
			if (row + col) % 2 == 0 then
				part(m, "GoldBar", Vector3.new(1.0, 0.35, 0.5), at(x, y + 0.18, SHELF_Z), GOLD, { studs = TOP, tile = 1, collide = false })
				part(m, "GoldBar", Vector3.new(0.9, 0.35, 0.45), at(x + 0.05, y + 0.53, SHELF_Z), GOLD, { studs = TOP, tile = 1, collide = false })
			else
				part(m, "Bag", Vector3.new(0.9, 0.9, 0.9), at(x, y + 0.45, SHELF_Z), hex("C9A27E"), { shape = Enum.PartType.Ball, collide = false })
			end
		end
	end
end

-- A golden Rumblerex on a studded plinth, facing the spawn (fills the corner where the Speed stall stood).
local function kaijuStatue(parent, pos, facePos)
	local m = Instance.new("Model")
	m.Name = "KaijuStatue"
	local PLINTH, PLINTH_LIGHT, PLINTH_DARK = hex("6E5A4A"), hex("8A7460"), hex("54443A")
	local look = CFrame.lookAt(pos, Vector3.new(facePos.X, pos.Y, facePos.Z))
	part(m, "PlinthBase", Vector3.new(10.4, 0.5, 10.4), look * CFrame.new(0, 0.55, 0), PLINTH_DARK, { studs = TOP })
	part(m, "Plinth", Vector3.new(8.8, 2.2, 8.8), look * CFrame.new(0, 1.9, 0), PLINTH, { studs = ALL })
	part(m, "PlinthTop", Vector3.new(9.4, 0.5, 9.4), look * CFrame.new(0, 3.25, 0), PLINTH_LIGHT, { studs = TOP })
	for _, y in { 1.05, 2.75 } do
		part(m, "Trim", Vector3.new(9.0, 0.22, 9.0), look * CFrame.new(0, y, 0), GOLD, { neon = true, collide = false })
	end
	local plaque = part(m, "Plaque", Vector3.new(5.2, 1.2, 0.2), look * CFrame.new(0, 1.9, -4.5), BOARD, { collide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local l = textLabel(gui, "Label", "RUMBLEREX", WHITE, Enum.Font.LuckiestGuy, 1, 3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(hex("FFF3A8"), hex("FFB21F"))
	g.Parent = l
	gui.Parent = plaque

	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Kaiju") and assets.Kaiju:FindFirstChild("Rumblerex")
	if art then
		local statue = art:Clone()
		statue.Name = "Statue"
		statue:ScaleTo(1.9)
		statue:PivotTo(look + Vector3.new(0, 3.5, 0))
		-- gold by brightness: dark details (eyes, mouth) stay deep bronze so the face still reads
		local dark, mid, bright = hex("3D2600"), hex("C98A12"), hex("FFD64A")
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d.Color
				local lum = math.clamp(0.3 * c.R + 0.59 * c.G + 0.11 * c.B, 0, 1)
				d.Color = lum < 0.5 and dark:Lerp(mid, lum * 2) or mid:Lerp(bright, (lum - 0.5) * 2)
				if d.Material ~= Enum.Material.Neon then
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = 0.05
				end
				d.Anchored = true
				d.CanTouch = false
			end
		end
		for name in statue:GetAttributes() do
			statue:SetAttribute(name, nil)
		end
		statue.Parent = m
	else
		warn("[MarketBuilder] no Assets.Kaiju.Rumblerex for the statue")
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local glow = part(m, "Spot", Vector3.new(0.6, 0.3, 0.6), look * CFrame.new(corner[1] * 4.1, 3.55, corner[2] * 4.1), GOLD, { neon = true, collide = false })
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 10
		light.Brightness = 0.9
		light.Parent = glow
	end
	m.Parent = parent
	return m
end

-- ---------- plaza dressing ----------

-- Two giant bone tusks curving over the path into a "KAIJU MARKET" arch.
local function tuskArch(parent, x)
	local arch = Instance.new("Model")
	arch.Name = "MarketArch"
	local R = 15.5
	for _, side in { -1, 1 } do
		part(arch, "Socket", Vector3.new(5, 2.2, 5), CFrame.new(x, 1.1, side * R), hex("6E5A4A"), { studs = ALL })
		part(arch, "SocketTop", Vector3.new(4.2, 0.6, 4.2), CFrame.new(x, 2.5, side * R), hex("8A7460"), { studs = TOP })
		local segments = 10
		local prev
		for i = 0, segments do
			local a = math.rad(i * (80 / segments))
			local p = Vector3.new(x, 2.2 + R * math.sin(a), side * R * math.cos(a))
			if prev then
				local thick = 3.1 - (i - 1) * 0.22
				local mid = (prev + p) / 2
				part(arch, "Tusk", Vector3.new(thick, thick, (p - prev).Magnitude + 0.5), CFrame.lookAt(mid, p), i % 2 == 0 and BONE or BONE_SHADE, { studs = SIDES })
			end
			prev = p
		end
	end
	local board = part(arch, "Board", Vector3.new(1, 3.6, 15), CFrame.new(x, 13.4, 0), BOARD, { studs = { Enum.NormalId.Top } })
	for _, dy in { -1.95, 1.95 } do
		part(arch, "Trim", Vector3.new(1.2, 0.35, 15.4), CFrame.new(x, 13.4 + dy, 0), GOLD, { neon = true, collide = false })
	end
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local l = textLabel(gui, "Label", "KAIJU MARKET", WHITE, Enum.Font.LuckiestGuy, 1, 4)
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(hex("FFF3A8"), hex("FFB21F"))
		g.Parent = l
		gui.Parent = board
	end
	arch.Parent = parent
end

local function bunting(parent, a, b, colors)
	local folder = Instance.new("Folder")
	folder.Name = "Bunting"
	local n = math.floor((b - a).Magnitude / 1.15)
	local function point(t)
		return a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.4, 0)
	end
	for i = 0, n - 1 do
		local p0, p1 = point(i / n), point((i + 1) / n)
		part(folder, "Rope", Vector3.new(0.1, 0.1, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), INK, { collide = false, shadow = false })
		local mid = point((i + 0.5) / n)
		local dir = (p1 - p0).Unit
		part(folder, "Flag", Vector3.new(0.75, 0.75, 0.06), CFrame.lookAt(mid - Vector3.new(0, 0.5, 0), mid - Vector3.new(0, 0.5, 0) + dir:Cross(Vector3.yAxis)) * CFrame.Angles(0, 0, math.rad(45)), colors[i % #colors + 1], { collide = false, shadow = false })
	end
	folder.Parent = parent
end

-- A stone path from the hub to a stall's pad, edged in the stall's colour.
local function path(parent, from, to, edge)
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local len = dir.Magnitude
	local mid = Vector3.new((from.X + to.X) / 2, 0.33, (from.Z + to.Z) / 2)
	local cf = CFrame.lookAt(mid, mid + dir)
	part(parent, "Path", Vector3.new(4, 0.06, len), cf, STONE, { studs = TOP, collide = false, shadow = false })
	for _, sx in { -1, 1 } do
		part(parent, "PathEdge", Vector3.new(0.4, 0.08, len), cf * CFrame.new(sx * 2.2, 0.01, 0), edge, { collide = false, shadow = false })
	end
end

-- Lamp post with a glowing lantern on top (also anchors bunting).
local function lampPost(parent, pos, color)
	part(parent, "LampBase", Vector3.new(1.4, 0.6, 1.4), CFrame.new(pos + Vector3.new(0, 0.6, 0)), WOOD_DARK, { studs = TOP })
	part(parent, "LampPost", Vector3.new(0.6, 9, 0.6), CFrame.new(pos + Vector3.new(0, 5.4, 0)), WOOD, { studs = SIDES })
	part(parent, "LampArm", Vector3.new(0.4, 0.4, 1.6), CFrame.new(pos + Vector3.new(0, 9.6, -0.6)), WOOD_DARK, { collide = false })
	lantern(parent, CFrame.new(pos + Vector3.new(0, 8.6, -1.2)), color)
end

-- The spawn pad dressed as the market's stone hub with a gold ring.
local function hub(parent, map, center)
	local spawn = map:FindFirstChild("Spawn") and map.Spawn:FindFirstChild("SpawnLocation")
	if spawn then
		spawn.Color = STONE
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Size = Vector3.new(12, 0.5, 12)
		spawn.CFrame = CFrame.new(center.X, 0.55, center.Z) * spawn.CFrame.Rotation
		for _, d in spawn:GetChildren() do
			if d:IsA("Texture") or d:IsA("Decal") then
				d:Destroy()
			end
		end
		studs(spawn, TOP)
	end
	part(parent, "HubRing", Vector3.new(0.08, 15.2, 15.2), CFrame.new(center.X, 0.34, center.Z) * UP, GOLD, { neon = true, shape = CYLINDER, collide = false, shadow = false })
	part(parent, "HubStone", Vector3.new(0.1, 14.4, 14.4), CFrame.new(center.X, 0.35, center.Z) * UP, STONE_DARK, { shape = CYLINDER, collide = false, shadow = false })
end

-- ---------- build ----------

function MarketBuilder.BuildFood()
	local KaijuBuilder = fresh(ServerStorage.Tools.KaijuBuilder)
	local specs = fresh(ServerStorage.Tools.FoodSpecs)
	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local folder = assets:FindFirstChild("Food") or Instance.new("Folder")
	folder.Name = "Food"
	folder.Parent = assets
	local out = {}
	for name, spec in specs do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local m = KaijuBuilder.BuildModel(name, spec)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		m.Parent = folder
		table.insert(out, name .. ": " .. m:GetAttribute("Bricks") .. " bricks")
	end
	return table.concat(out, "\n")
end

function MarketBuilder.Build(map)
	map = map or workspace:FindFirstChild("Map")
	assert(map, "no Workspace.Map - run MapBuilder first")
	for _, name in { "Market", "SpeedShop" } do
		local old = map:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local S = MapConfig.SpawnPlaza.Size
	local cx = -S / 2
	local center = Vector3.new(cx, 0, 0)
	local market = Instance.new("Folder")
	market.Name = "Market"
	market.Parent = map
	local keepers = Instance.new("Folder")
	keepers.Name = "Keepers"
	keepers.Parent = market
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = market

	local north, south = S / 2 - 7, -(S / 2 - 7)
	local left, right = cx - 15, cx + 15
	local function facing(pos, dz)
		return CFrame.lookAt(pos, pos + Vector3.new(0, 0, dz))
	end

	local food, foodAt, foodPad = buildStall(market, keepers, facing(Vector3.new(left, 0, north), -1), THEMES.Food)
	foodItems(food, foodAt)
	restockBoard(food, foodAt)
	openPrompt(food, foodAt, "Open Food Shop", "FoodShopPanel")
	task.wait()
	local trails, trailsAt, trailsPad = buildStall(market, keepers, facing(Vector3.new(right, 0, north), -1), THEMES.Trails)
	trailWheel(trails, trailsAt)
	openPrompt(trails, trailsAt, "Open Trail Shop", "TrailShopPanel")
	task.wait()
	local sell, sellAt, sellPad = buildStall(market, keepers, facing(Vector3.new(left, 0, south), 1), THEMES.Sell)
	sellDecor(sell, sellAt)
	openPrompt(sell, sellAt, "Sell Kaiju", "SellPanel")
	task.wait()

	local spot = part(market, "ShopTeleport", Vector3.new(4, 0.2, 4), CFrame.lookAt(Vector3.new(cx, 0.4, 4), Vector3.new(cx, 0.4, north)), WHITE, { transparency = 1, collide = false, shadow = false })
	spot.CanQuery = false

	-- the hub, and a coloured path from it to every pad (and to the statue)
	hub(decor, map, center)
	local statuePos = Vector3.new(right, 0, south + 2)
	kaijuStatue(decor, statuePos, center)
	for _, entry in { { foodPad, THEMES.Food.Color }, { trailsPad, THEMES.Trails.Color }, { sellPad, THEMES.Sell.Color } } do
		local padPos = entry[1].Position
		local dir = Vector3.new(padPos.X - cx, 0, padPos.Z).Unit
		path(decor, center + dir * 7.6, Vector3.new(padPos.X, 0, padPos.Z) - dir * 4.4, entry[2])
	end
	local statueDir = Vector3.new(statuePos.X - cx, 0, statuePos.Z).Unit
	path(decor, center + statueDir * 7.6, statuePos - statueDir * 5.6, GOLD)

	tuskArch(decor, 2)

	-- bunting strung between the stalls' front beams, and from the SELL stall to a lamp by the statue
	local flagColors = { THEMES.Food.Color, THEMES.Trails.Color, THEMES.Sell.Color, hex("3FA9FF"), WHITE }
	local beamY = FRONT_TOP + BEAM / 2
	bunting(decor, foodAt(PX + 0.7, beamY, -PZ).Position, trailsAt(-(PX + 0.7), beamY, -PZ).Position, flagColors)
	local lampPos = Vector3.new(right - 9, 0, south + 9)
	lampPost(decor, lampPos, GOLD)
	bunting(decor, sellAt(-(PX + 0.7), beamY, -PZ).Position, lampPos + Vector3.new(0, 9.6, 0), flagColors)

	local count = 0
	for _, d in market:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return "Kaiju Market built: " .. count .. " parts"
end

return MarketBuilder
