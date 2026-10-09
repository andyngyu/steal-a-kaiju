-- Edit-time tool: builds the Kaiju Market around the spawn plaza and the food art. MapBuilder.Build() calls Build(map)
-- at the end of a full map rebuild; on its own (replaces Map.Market only; also clears the old Map.SpeedShop):
--   require(game.ServerStorage.Tools.MarketBuilder:Clone()).Build()
--   require(game.ServerStorage.Tools.MarketBuilder:Clone()).BuildFood()   -- ReplicatedStorage.Assets.Food from Tools.FoodSpecs
--
-- Runtime contract (attributes are the API):
--   Map.Market.ShopTeleport          invisible part; Remotes.TeleportToShop puts players here
--   Map.Market.FoodStall / TrailStall / SellStall, each with:
--     Pad        part with attributes Shop ("Food" | "Trails" | "Sell"), Panel (UI panel name), Radius
--     SignAnchor part holding the BillboardGui "Sign"
--     OpenPrompt on the counter (attribute Panel)
--   Map.Market.Keepers               shopkeeper kaiju (Assets.Kaiju clones) idling on crates: VisualScale, RootOffset,
--                                    WanderFrom = WanderTo = standing spot, MoveStart = MoveEnd = 0 (animated by KaijuFX)
--   FoodStall.Items.<FoodId>         display Model, attribute FoodId; PrimaryPart.Tag billboard (Price, XP). Food is
--                                    bought in the UI's FoodShopPanel (pad / OpenPrompt), not off the counter.
--   TrailStall.Wheel                 Center part + Orb parts (attributes TrailId, Index); clients spin them with trails
--   OpenPrompt (any stall)           ProximityPrompt with attribute Panel; the client opens that UI panel
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

local TOP = { Enum.NormalId.Top }
local FRONT = { Enum.NormalId.Front }
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local ALL = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local CYLINDER = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) upright

-- Plaza: S x S square centred at (-S/2, 0, 0); stalls sit on its north and south edges facing the spawn.
local THEMES = {
	Food = {
		Name = "FoodStall", Shop = "Food", Title = "KAIJU FOOD", Panel = "FoodShopPanel", SignWidth = 15,
		Color = hex("43C93A"), Dark = hex("2A8A25"), Light = hex("E4FFD9"), Plate = hex("8CFF5A"),
		Pad = hex("A8F28E"), PadGlow = hex("5CFF3B"), TitleTop = hex("D9FFB8"), TitleBottom = hex("5CE63B"),
		Keeper = "Chompling", KeeperScale = 1.15, KeeperSide = -1,
	},
	Trails = {
		Name = "TrailStall", Shop = "Trails", Title = "TRAILS", Panel = "TrailShopPanel", SignWidth = 10,
		Color = hex("FFC92E"), Dark = hex("D99A00"), Light = hex("FFF6CC"), Plate = hex("FFE24A"),
		Pad = hex("FFEC7A"), PadGlow = hex("FFD21F"), TitleTop = hex("FFF7B8"), TitleBottom = hex("FFC21F"),
		Keeper = "Prismling", KeeperScale = 0.85, KeeperSide = 1,
	},
	Sell = {
		Name = "SellStall", Shop = "Sell", Title = "SELL", Panel = "SellPanel", SignWidth = 8,
		Color = hex("FF3B3B"), Dark = hex("B81E1E"), Light = hex("FFE3E3"), Plate = hex("FF4D6D"),
		Pad = hex("8CF5A8"), PadGlow = hex("2BEA6B"), TitleTop = hex("FF9C9C"), TitleBottom = hex("FF1F1F"),
		Keeper = "Bonkey", KeeperScale = 1.0, KeeperSide = 1,
	},
}

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

-- Big floating shop name, like the reference stalls.
local function sign(parent, cf, theme)
	local anchor = part(parent, "SignAnchor", Vector3.new(0.2, 0.2, 0.2), cf, WHITE, { transparency = 1, collide = false, shadow = false })
	anchor.CanQuery = false
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"
	bb.Size = UDim2.new(theme.SignWidth, 0, 3.4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 320
	local l = textLabel(bb, "Label", theme.Title, WHITE, Enum.Font.LuckiestGuy, 1, 5)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(theme.TitleTop, theme.TitleBottom)
	g.Parent = l
	bb.Parent = anchor
	return anchor
end

-- Stepped neon plates like Rumblerex's back, standing on a ridge.
local function plate(parent, cf, w, h, color)
	part(parent, "Plate", Vector3.new(w, h, 0.32), cf * CFrame.new(0, h / 2, 0), color, { neon = true, collide = false })
	part(parent, "Plate", Vector3.new(w * 0.5, h * 0.45, 0.32), cf * CFrame.new(0, h + h * 0.225, 0), color, { neon = true, collide = false })
end

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

-- Shopkeeper: a real brick kaiju idling on a crate (KaijuFX animates Map.Market.Keepers).
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

-- ---------- stalls ----------

-- cf = ground centre of the stall; its LookVector points at the customers (local -Z is the front).
local function buildStall(parent, keepers, cf, theme)
	local m = Instance.new("Model")
	m.Name = theme.Name
	m:SetAttribute("Shop", theme.Shop)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local W = 13.6

	part(m, "Deck", Vector3.new(13, 0.6, 7.8), at(0, 0.3, 0.5), WOOD_DARK, { studs = TOP })
	for _, x in { -5.8, 5.8 } do
		for _, z in { -3.0, 3.8 } do
			part(m, "Post", Vector3.new(0.9, 8.6, 0.9), at(x, 0.6 + 4.3, z), WOOD, { studs = SIDES })
			part(m, "PostFoot", Vector3.new(1.3, 0.5, 1.3), at(x, 0.85, z), WOOD_DARK, { studs = TOP })
		end
	end
	part(m, "Back", Vector3.new(11.6, 6.6, 0.5), at(0, 0.6 + 3.3, 3.75), theme.Light, { studs = FRONT })
	part(m, "Counter", Vector3.new(11.6, 2.8, 1.6), at(0, 0.6 + 1.4, -2.3), theme.Color, { studs = FRONT })
	part(m, "CounterTop", Vector3.new(12.2, 0.35, 2.1), at(0, 3.575, -2.3), WOOD_LIGHT, { studs = TOP })
	part(m, "CounterBase", Vector3.new(11.8, 0.35, 1.8), at(0, 0.775, -2.3), theme.Dark)
	-- kaiju claw scratches on the counter front
	for i = -1, 1 do
		part(m, "Scratch", Vector3.new(0.24, 1.9, 0.08), at(3.7 + i * 0.6, 2.05, -3.12) * CFrame.Angles(0, 0, math.rad(-22)), theme.Dark, { collide = false })
	end

	-- striped awning sloping down to the front, a row of kaiju teeth along its edge, dorsal plates on the ridge
	local yB, zB, yF, zF = 10.9, 4.4, 8.9, -4.7
	local dz, dy = zB - zF, yB - yF
	local len = math.sqrt(dz * dz + dy * dy)
	local tilt = math.atan2(dy, dz)
	local stripes = 8
	for i = 0, stripes - 1 do
		local x = -W / 2 + W / stripes * (i + 0.5)
		part(m, "Awning", Vector3.new(W / stripes + 0.02, 0.4, len), at(x, (yB + yF) / 2, (zB + zF) / 2) * CFrame.Angles(-tilt, 0, 0), i % 2 == 0 and theme.Color or WHITE, { studs = TOP })
	end
	part(m, "Valance", Vector3.new(W + 0.2, 0.9, 0.3), at(0, yF - 0.45, zF), theme.Color, { studs = FRONT, collide = false })
	for i = 0, 11 do
		local x = -W / 2 + 0.55 + i * ((W - 1.1) / 11)
		part(m, "Tooth", Vector3.new(0.78, 0.78, 0.22), at(x, yF - 0.9, zF) * CFrame.Angles(0, 0, math.rad(45)), WHITE, { collide = false })
	end
	part(m, "Ridge", Vector3.new(W + 0.2, 0.5, 0.6), at(0, yB + 0.1, zB - 0.2), theme.Dark, { studs = TOP, collide = false })
	for _, p in { { 0, 1.6, 1.5 }, { -2.5, 1.2, 1.1 }, { 2.5, 1.2, 1.1 }, { -4.8, 0.8, 0.75 }, { 4.8, 0.8, 0.75 } } do
		plate(m, at(p[1], yB + 0.35, zB - 0.2), p[2], p[3], theme.Plate)
	end

	sign(m, at(0, yB + 4.0, 0), theme)
	for _, x in { -6.6, 6.6 } do
		lantern(m, at(x, yF - 0.4, -3.0), theme.Plate)
	end

	-- glowing studded pad in front (stepping on it opens the shop's UI panel); sits on the 0.3-stud plaza floor
	local padCF = at(0, 0.3, -9.4)
	local ring = part(m, "PadRing", Vector3.new(0.16, 10.4, 10.4), padCF * CFrame.new(0, 0.08, 0) * UP, theme.PadGlow, { neon = true, shape = CYLINDER, collide = false })
	ring.CanQuery = false
	local pad = part(m, "Pad", Vector3.new(0.26, 9.2, 9.2), padCF * CFrame.new(0, 0.13, 0) * UP, theme.Pad, { shape = CYLINDER, studs = { Enum.NormalId.Right }, tile = 1.5, collide = false })
	pad:SetAttribute("Shop", theme.Shop)
	pad:SetAttribute("Radius", 4.6)
	if theme.Panel then
		pad:SetAttribute("Panel", theme.Panel)
	end
	local padLight = Instance.new("PointLight")
	padLight.Color = theme.PadGlow
	padLight.Range = 12
	padLight.Brightness = 1.1
	padLight.Parent = pad

	-- shopkeeper on a crate at the outer side, looking at the pad
	local kx = theme.KeeperSide * 8.7
	part(m, "Crate", Vector3.new(2.8, 1.4, 2.8), at(kx, 0.7, 0.4), WOOD, { studs = ALL })
	for _, y in { 0.2, 1.2 } do
		part(m, "CrateBand", Vector3.new(2.9, 0.2, 2.9), at(kx, y, 0.4), WOOD_DARK, { collide = false })
	end
	keeper(keepers, m, theme, at(kx, 1.4 + 0.1 * theme.KeeperScale, 0.4), padCF.Position)

	m.PrimaryPart = pad
	m.Parent = parent
	return m, at
end

-- An E prompt on the counter that opens a UI panel on the client (Gameplay.MarketFX).
local function openPrompt(m, at, action, panel)
	local holder = part(m, "PromptSpot", Vector3.new(0.2, 0.2, 0.2), at(0, 4.4, -2.3), WHITE, { transparency = 1, collide = false, shadow = false })
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
			part(m, "FoodPlate", Vector3.new(0.12, 1.55, 1.55), at(x, 3.81, -2.3) * UP, hex("F4F1FF"), { shape = CYLINDER, collide = false })
			local item = art:Clone()
			item.Name = food.Id
			item:SetAttribute("FoodId", food.Id)
			item:PivotTo(at(x, 3.97, -2.3) * CFrame.Angles(0, math.rad((i % 2 == 0) and 12 or -12), 0))
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
	local stock = Instance.new("Folder")
	stock.Name = "Stock"
	stock.Parent = m
	for _, y in { 3.7, 5.6 } do
		part(m, "Shelf", Vector3.new(10.6, 0.25, 1.1), at(0, y, 3.0), WOOD_LIGHT, { studs = TOP })
	end
	local shelfItems = { "Kibble", "Kibble", "Drumstick", "LavaPepper", "Kibble", "FrostFish", "Drumstick", "Kibble", "LavaPepper", "Drumstick" }
	for i, id in shelfItems do
		local art = folder:FindFirstChild(id)
		if art then
			local row = i <= 5 and 0 or 1
			local col = (i - 1) % 5
			local s = art:Clone()
			s:PivotTo(at(-4 + col * 2, 3.85 + row * 1.9, 3.0) * CFrame.Angles(0, math.rad(15 - col * 7), 0))
			s.Parent = stock
		end
	end
end

local function trailWheel(m, at)
	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	local center = part(wheel, "Center", Vector3.new(0.4, 0.4, 0.4), at(0, 6.2, 3.3), WHITE, { transparency = 1, collide = false, shadow = false })
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
	-- streamer ribbons in every trail colour hanging under the awning
	for i, trail in TrailConfig.List do
		local x = -5.1 + (i - 1) * (10.2 / (#TrailConfig.List - 1))
		local c = hex(trail.Colors[1]:gsub("#", ""))
		part(m, "Streamer", Vector3.new(0.3, 1.4 + (i % 2) * 0.5, 0.08), at(x, 8.0 - (i % 2) * 0.25, -3.6), c, { neon = trail.LightEmission >= 0.9, collide = false })
	end
end

local function sellDecor(m, at)
	for _, y in { 3.7, 5.6 } do
		part(m, "Shelf", Vector3.new(10.6, 0.25, 1.1), at(0, y, 3.0), WOOD_LIGHT, { studs = TOP })
	end
	-- cash register
	local reg = at(-3.6, 3.75, -2.25)
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
			part(m, "Coin", Vector3.new(0.18, 0.8, 0.8), at(p, 3.75 + 0.09 + (c - 1) * 0.18, -2.4) * UP * CFrame.Angles(math.rad(c * 23), 0, 0), GOLD, { shape = CYLINDER, collide = false, material = Enum.Material.SmoothPlastic })
		end
	end
	-- money bag with a $
	local bag = part(m, "MoneyBag", Vector3.new(1.4, 1.4, 1.4), at(3.6, 4.4, -2.2), hex("C9A27E"), { shape = Enum.PartType.Ball, collide = false })
	part(m, "BagTie", Vector3.new(0.6, 0.3, 0.6), at(3.6, 5.15, -2.2), hex("8B5A2B"), { collide = false })
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
				part(m, "GoldBar", Vector3.new(1.0, 0.35, 0.5), at(x, y + 0.18, 3.0), GOLD, { studs = TOP, tile = 1, collide = false })
				part(m, "GoldBar", Vector3.new(0.9, 0.35, 0.45), at(x + 0.05, y + 0.53, 3.0), GOLD, { studs = TOP, tile = 1, collide = false })
			else
				part(m, "Bag", Vector3.new(0.9, 0.9, 0.9), at(x, y + 0.45, 3.0), hex("C9A27E"), { shape = Enum.PartType.Ball, collide = false })
			end
		end
	end
end

-- A golden Rumblerex on a studded plinth, facing the spawn (fills the corner where the Speed stall stood).
local function kaijuStatue(parent, pos, facePos)
	local m = Instance.new("Model")
	m.Name = "KaijuStatue"
	local STONE, STONE_LIGHT, STONE_DARK = hex("6E5A4A"), hex("8A7460"), hex("54443A")
	local look = CFrame.lookAt(pos, Vector3.new(facePos.X, pos.Y, facePos.Z))
	part(m, "PlinthBase", Vector3.new(10.4, 0.5, 10.4), look * CFrame.new(0, 0.55, 0), STONE_DARK, { studs = TOP })
	part(m, "Plinth", Vector3.new(8.8, 2.2, 8.8), look * CFrame.new(0, 1.9, 0), STONE, { studs = ALL })
	part(m, "PlinthTop", Vector3.new(9.4, 0.5, 9.4), look * CFrame.new(0, 3.25, 0), STONE_LIGHT, { studs = TOP })
	for _, y in { 1.05, 2.75 } do
		part(m, "Trim", Vector3.new(9.0, 0.22, 9.0), look * CFrame.new(0, y, 0), GOLD, { neon = true, collide = false })
	end
	-- plaque on the front
	local plaque = part(m, "Plaque", Vector3.new(5.2, 1.2, 0.2), look * CFrame.new(0, 1.9, -4.5), hex("2B1B4D"), { collide = false })
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
	local board = part(arch, "Board", Vector3.new(1, 3.6, 15), CFrame.new(x, 13.4, 0), hex("2B1B4D"), { studs = { Enum.NormalId.Top } })
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

-- Three-toed kaiju footprints from the spawn towards a stall's pad.
local function footprints(parent, from, to)
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = dir.Magnitude
	dir = dir.Unit
	local right = dir:Cross(Vector3.yAxis)
	local color = hex("CFC4A8")
	local count = math.floor(dist / 2.6)
	for i = 1, count - 1 do
		local p = from + dir * (i * 2.6) + right * ((i % 2 == 0) and 0.7 or -0.7)
		local cf = CFrame.lookAt(Vector3.new(p.X, 0.31, p.Z), Vector3.new(p.X, 0.31, p.Z) + dir)
		part(parent, "Print", Vector3.new(0.8, 0.04, 0.95), cf, color, { collide = false, shadow = false })
		for t = -1, 1 do
			part(parent, "Toe", Vector3.new(0.26, 0.04, 0.5), cf * CFrame.new(t * 0.36, 0, -0.75) * CFrame.Angles(0, math.rad(-t * 18), 0), color, { collide = false, shadow = false })
		end
	end
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
	local market = Instance.new("Folder")
	market.Name = "Market"
	market.Parent = map
	local keepers = Instance.new("Folder")
	keepers.Name = "Keepers"
	keepers.Parent = market

	local north, south = S / 2 - 9, -(S / 2 - 9)
	local left, right = cx - 15, cx + 15
	local function facing(pos, dz)
		return CFrame.lookAt(pos, pos + Vector3.new(0, 0, dz))
	end

	local food, foodAt = buildStall(market, keepers, facing(Vector3.new(left, 0, north), -1), THEMES.Food)
	foodItems(food, foodAt)
	openPrompt(food, foodAt, "Open Food Shop", "FoodShopPanel")
	task.wait()
	local trails, trailsAt = buildStall(market, keepers, facing(Vector3.new(right, 0, north), -1), THEMES.Trails)
	trailWheel(trails, trailsAt)
	openPrompt(trails, trailsAt, "Open Trail Shop", "TrailShopPanel")
	task.wait()
	local sell, sellAt = buildStall(market, keepers, facing(Vector3.new(left, 0, south), 1), THEMES.Sell)
	sellDecor(sell, sellAt)
	openPrompt(sell, sellAt, "Sell Kaiju", "SellPanel")
	task.wait()

	local spot = part(market, "ShopTeleport", Vector3.new(4, 0.2, 4), CFrame.lookAt(Vector3.new(cx, 0.4, 4), Vector3.new(cx, 0.4, north)), WHITE, { transparency = 1, collide = false, shadow = false })
	spot.CanQuery = false

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = market
	tuskArch(decor, 2)
	kaijuStatue(decor, Vector3.new(right, 0, south + 2), Vector3.new(cx, 0, 0))
	local flagColors = { THEMES.Food.Color, THEMES.Trails.Color, THEMES.Sell.Color, hex("3FA9FF"), WHITE }
	bunting(decor, Vector3.new(left + 5.8, 9.4, north - 3), Vector3.new(right - 5.8, 9.4, north - 3), flagColors)
	bunting(decor, Vector3.new(left + 5.8, 9.4, south + 3), Vector3.new(right - 9.5, 9.4, south + 3), flagColors)
	local spawnEdge = 7
	for _, target in { Vector3.new(left, 0, north - 9.4), Vector3.new(right, 0, north - 9.4), Vector3.new(left, 0, south + 9.4), Vector3.new(right, 0, south + 9.4) } do
		local from = Vector3.new(cx, 0, (target.Z > 0) and spawnEdge or -spawnEdge)
		local stop = target - (target - from).Unit * 5.2
		footprints(decor, from, stop)
	end
	barrel(decor, Vector3.new(cx - 2, 0, north + 3.5), hex("C98A4B"))
	barrel(decor, Vector3.new(cx + 2, 0, north + 3), nil)
	barrel(decor, Vector3.new(cx - 1.5, 0, south - 3.5), GOLD)
	barrel(decor, Vector3.new(cx + 2.2, 0, south - 3), GOLD)

	local count = 0
	for _, d in market:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return "Kaiju Market built: " .. count .. " parts"
end

return MarketBuilder
