-- One-shot (re-runnable) restyle of StarterGui.KaijuUI in the Daily Rewards look:
--   coloured header per panel, an orange info banner under it, list rows turned into glossy grey cards in a grid
--   (same child names as before, so the controllers keep working), shop / trail cards in the same grey card style,
--   and left-rail buttons rebuilt as Daily-style tiles around bare icon art (UIConfig.Images.Rail*).
-- Run from the command bar (Edit mode):  require(game.ServerStorage.Tools.UIRedesign).Apply()
-- Backup of the UI from before the first run: ServerStorage.Backups.KaijuUI_PreRedesign_2026-10-15
local R = {}

local DOTS = "rbxassetid://87047735731431"
local GLOSS = "rbxassetid://76123755798356"
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local function hex(h)
	return Color3.fromHex(h)
end

local function seq(a, b, c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, hex(a)),
		ColorSequenceKeypoint.new(0.5, hex(b)),
		ColorSequenceKeypoint.new(1, hex(c)),
	})
end

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function child(o, class, name)
	local c = o:FindFirstChild(name)
	if c and c.ClassName ~= class then
		c:Destroy()
		c = nil
	end
	if not c then
		c = Instance.new(class)
		c.Name = name
		c.Parent = o
	end
	return c
end

-- the Daily tile look on any frame: gradient + rim + dots + gloss
function R.Skin(f, colors, rim, opts)
	opts = opts or {}
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0
	child(f, "UICorner", "UICorner").CornerRadius = UDim.new(0, opts.corner or 4)
	local g = child(f, "UIGradient", "UIGradient")
	g.Color = seq(colors[1], colors[2], colors[3])
	g.Rotation = opts.rotation or 90
	local s = child(f, "UIStroke", opts.strokeName or "UIStroke")
	s.Color = hex(rim)
	s.Thickness = opts.stroke or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local z = f.ZIndex
	local d = child(f, "ImageLabel", "Dots")
	d.BackgroundTransparency = 1
	d.Image = DOTS
	d.ScaleType = Enum.ScaleType.Tile
	d.TileSize = UDim2.fromOffset(opts.dots or 14, opts.dots or 14)
	d.ImageTransparency = opts.dotsT or 0.72
	d.Size = UDim2.fromScale(1, 1)
	d.Position = UDim2.new()
	if d.ZIndex < z then
		d.ZIndex = z
	end
	local gl = child(f, "ImageLabel", "Gloss")
	gl.BackgroundTransparency = 1
	gl.Image = GLOSS
	gl.ScaleType = Enum.ScaleType.Stretch
	gl.ImageTransparency = 0.75
	gl.Size = UDim2.new(0, opts.gloss or 220, 1, 0)
	gl.Position = UDim2.fromOffset(20, 0)
	if gl.ZIndex < z then
		gl.ZIndex = z
	end
	return f
end

-- Shadow + Label text holder (the game's standard)
function R.Text(parent, name, text, maxSize, z, props)
	local h = parent:FindFirstChild(name) or new("Frame", { Name = name, BackgroundTransparency = 1 }, parent)
	for k, v in props or {} do
		if k ~= "align" then
			h[k] = v
		end
	end
	h.ZIndex = z -- the holder itself must sit above the tile's Dots / Gloss (ZIndexBehavior is Sibling)
	local drop = math.clamp(math.floor(maxSize * 0.08 + 0.5), 2, 4) -- shadow drop scales with the text
	for _, n in { "Shadow", "Label" } do
		local l = h:FindFirstChild(n) or new("TextLabel", { Name = n }, h)
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.RichText = true
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = n == "Shadow" and Color3.new(0, 0, 0) or WHITE
		l.TextXAlignment = (props and props.align) or Enum.TextXAlignment.Left
		l.Size = UDim2.fromScale(1, 1)
		l.Position = n == "Shadow" and UDim2.fromOffset(0, drop) or UDim2.new()
		l.ZIndex = n == "Shadow" and z or z + 1
		child(l, "UITextSizeConstraint", "UITextSizeConstraint").MaxTextSize = maxSize
		local s = child(l, "UIStroke", "UIStroke")
		s.Thickness = math.max(2, maxSize / 10)
		s.LineJoinMode = Enum.LineJoinMode.Round
	end
	return h
end

local function setAlign(holder, align, maxSize)
	for _, l in holder:GetChildren() do
		if l:IsA("TextLabel") then
			l.TextXAlignment = align
			l.TextYAlignment = Enum.TextYAlignment.Center
			l:SetAttribute("FitMax", nil)
			local c = l:FindFirstChildOfClass("UITextSizeConstraint")
			if c and maxSize then
				c.MaxTextSize = maxSize
				c.MinTextSize = math.min(c.MinTextSize, 10)
				l.TextSize = maxSize
			end
		end
	end
end

---------------------------------------------------------------- palette
R.CARD = { "a4a4a4", "7c7c7c", "5e5e5e" }
R.CARD_RIM = "3a3a3a"
R.BANNER = { "ffd27a", "ff9a1f", "e0560b" }
R.BANNER_RIM = "7a2e00"
R.HEADERS = {
	EggsPanel = { { "b8f5a0", "5fd94a", "1f9e2a" }, "0e4a14" },
	PetsPanel = { { "d9a8ff", "a55cf0", "6a2cc0" }, "3a1475" },
	SellPanel = { { "ffb0a8", "ff5a4a", "c41a1a" }, "5e0a0a" },
	SettingsPanel = { { "9ccbff", "5db8ff", "0a9afe" }, "0b3a75" },
	IndexPanel = { { "8fe8ff", "2ec4e8", "0e86b8" }, "07405a" },
	ShopPanel = { { "ffb3e6", "ff5fb8", "d6247f" }, "7a0f45" },
	TrailShopPanel = { { "ffe28a", "ffbf2e", "e08a00" }, "6a3c00" },
	FoodShopPanel = { { "c8ffc2", "5cff52", "1fb51a" }, "0e5a0a" },
	GroupRewardPanel = { { "fff1a0", "ffd23f", "f0a000" }, "6a4500" },
	AdminPanel = { { "a8e4ff", "4fb2ff", "1e7be0" }, "0b3a75" },
	DailyPanel = { { "ffb3e6", "ff5fb8", "d6247f" }, "7a0f45" },
}

-- each panel's banner has its own colour (designer: not all orange)
R.BANNER_COLORS = {
	EggsPanel = { { "b8ecff", "3fb8ff", "1a6fd0" }, "0b3a75" },
	PetsPanel = { { "ffc2f2", "f05cd0", "a8209a" }, "5a0a52" },
	SellPanel = { { "fff3a0", "ffd23f", "d99a00" }, "6a4500" },
	SettingsPanel = { { "b8fff0", "3fe0c0", "10907a" }, "064a40" },
	AdminPanel = { { "ffb0a8", "ff5a4a", "c41a1a" }, "5e0a0a" },
}

-- banner under the header: icon, title, hint (the value on the right is filled at runtime by UIThemeController)
R.BANNERS = {
	EggsPanel = { "RailEggs", "Your Eggs", "Tap HATCH when an egg is ready!" },
	PetsPanel = { "RailPets", "Your Kaiju", "Equipped kaiju earn cash in your pen." },
	SellPanel = { "Money", "Sell Kaiju", "Tap SELL twice to trade a kaiju for cash." },
	SettingsPanel = { "RailSettings", "Game Settings", "Tap a setting to switch it ON or OFF." },
}

---------------------------------------------------------------- list rows -> cards
R.CELL = UDim2.fromOffset(220, 262)

local function cardBase(row)
	row.Size = R.CELL
	R.Skin(row, R.CARD, R.CARD_RIM, { gloss = 300 })
	local slot = row:FindFirstChild("IconSlot")
	if slot then
		slot.AnchorPoint = Vector2.new(0.5, 0)
		slot.Position = UDim2.new(0.5, 0, 0, 10)
		slot.Size = UDim2.fromOffset(120, 120)
		child(slot, "UICorner", "UICorner").CornerRadius = UDim.new(0, 4)
	end
	local name = row:FindFirstChild("ItemName")
	if name then
		name.Position = UDim2.fromOffset(8, 134)
		name.Size = UDim2.new(1, -16, 0, 32)
		setAlign(name, Enum.TextXAlignment.Center, 28)
	end
	local action = row:FindFirstChild("Action")
	if action then
		action.AnchorPoint = Vector2.new(0.5, 1)
		action.Position = UDim2.new(0.5, 0, 1, -10)
		action.Size = UDim2.new(1, -24, 0, 46)
	end
end

function R.Cards(T)
	-- keep the old wide row for lists that are not grids (Admin's player list)
	if not T:FindFirstChild("ListRow") and T:FindFirstChild("PetRow") then
		local wide = T.PetRow:Clone()
		wide.Name = "ListRow"
		wide.Parent = T
	end
	local egg = T.EggRow
	cardBase(egg)
	egg.Bar.Position = UDim2.fromOffset(12, 170)
	egg.Bar.Size = UDim2.new(1, -24, 0, 30)
	setAlign(egg.Bar.Time, Enum.TextXAlignment.Center, 22)

	local pet = T.PetRow
	cardBase(pet)
	pet.Rate.Position = UDim2.fromOffset(8, 166)
	pet.Rate.Size = UDim2.new(1, -16, 0, 34)
	setAlign(pet.Rate, Enum.TextXAlignment.Center, 22)
	-- FEED: a square button sharing the bottom row with the action button (same height and style family);
	-- KaijuController shows it on equipped kaiju, narrows the action button beside it and drops a drumstick in it
	local feed = pet:FindFirstChild("Feed")
	if feed then
		feed:Destroy()
	end
	feed = pet.Action:Clone()
	feed.Name = "Feed"
	feed.AnchorPoint = Vector2.new(1, 1)
	feed.Position = UDim2.new(1, -12, 1, -10)
	feed.Size = UDim2.fromOffset(54, 46)
	local fl = feed.Face:FindFirstChild("Label")
	if fl then
		fl.Visible = false
	end
	local gl = feed.Face:FindFirstChild("Gloss")
	if gl then
		gl.Size = UDim2.new(1.4, 0, 1, 0)
	end
	local ic = new("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 44), ZIndex = feed.Face.ZIndex + 3 }, feed.Face)
	ic:SetAttribute("Note", "drumstick viewport added at runtime")
	feed.Visible = false
	feed.Parent = pet

	-- the wide row (Admin's player and command cards) in the same grey card look
	local wide = T:FindFirstChild("ListRow")
	if wide then
		R.Skin(wide, R.CARD, R.CARD_RIM, { gloss = 420 })
	end

	local sell = T.SellRow
	cardBase(sell)
	sell.Info.Position = UDim2.fromOffset(8, 164)
	sell.Info.Size = UDim2.new(1, -16, 0, 22)
	sell.Price.Position = UDim2.fromOffset(8, 184)
	sell.Price.Size = UDim2.new(1, -16, 0, 22)
	setAlign(sell.Info, Enum.TextXAlignment.Center, 20)
	setAlign(sell.Price, Enum.TextXAlignment.Center, 20)

	for _, n in { "StoreCard", "TrailCard" } do
		local c = T:FindFirstChild(n)
		if c then
			R.Skin(c, R.CARD, R.CARD_RIM, { gloss = 360, stroke = 3 })
		end
	end
end

local function gridList(list, top, bottomGap)
	list.Position = UDim2.fromOffset(0, top)
	list.Size = UDim2.new(1, 0, 1, -(top + bottomGap))
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = WHITE
	for _, c in list:GetChildren() do
		if c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local grid = child(list, "UIGridLayout", "UIGridLayout")
	grid.CellSize = R.CELL
	grid.CellPadding = UDim2.fromOffset(14, 14)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local pad = child(list, "UIPadding", "UIPadding")
	pad.PaddingLeft = UDim.new(0, 0)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 12)
end

function R.Banner(window, spec, images, y, z, colors)
	local b = window:FindFirstChild("Banner") or new("Frame", { Name = "Banner" }, window)
	b.Position = UDim2.fromOffset(24, y)
	b.Size = UDim2.new(1, -48, 0, 70)
	b.ZIndex = z
	R.Skin(b, colors and colors[1] or R.BANNER, colors and colors[2] or R.BANNER_RIM, { gloss = 600 })
	local icon = b:FindFirstChild("Icon") or new("ImageLabel", { Name = "Icon" }, b)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = images[spec[1]] or ""
	icon.Size = UDim2.fromOffset(60, 60)
	icon.Position = UDim2.fromOffset(10, 5)
	icon.ZIndex = z + 2
	R.Text(b, "Title", spec[2], 34, z + 3, { Position = UDim2.fromOffset(82, 4), Size = UDim2.new(0.62, -82, 0, 38) })
	R.Text(b, "Hint", spec[3], 18, z + 3, { Position = UDim2.fromOffset(84, 42), Size = UDim2.new(0.66, -84, 0, 22) })
	R.Text(b, "Value", "", 38, z + 3, { Position = UDim2.new(0.6, 0, 0, 8), Size = UDim2.new(0.4, -18, 0, 54), align = Enum.TextXAlignment.Right })
	return b
end

---------------------------------------------------------------- left rail tiles
R.RAIL = {
	Shop = { "RailShop", "Shop", { "ffe08a", "ffae2e", "d9620e" }, "6a2c00" },
	Index = { "RailIndex", "Index", { "b8f5a0", "4fd14a", "1e8a2e" }, "0e4a14" },
	Eggs = { "RailEggs", "Eggs", { "9fe6ff", "36a9f5", "1a6fd0" }, "0b3a75" },
	Pets = { "RailPets", "Pets", { "e2b8ff", "a55cf0", "6a2cc0" }, "3a1475" },
	Settings = { "RailSettings", "Settings", { "9ff0e0", "2ec4b0", "14857a" }, "0a4a44" },
	Admin = { "RailAdmin", "Admin", { "ffb0a8", "ff5a4a", "c41a1a" }, "5e0a0a" },
}

function R.Rail(rail, images)
	for name, spec in R.RAIL do
		local b = rail:FindFirstChild(name)
		if b and b:IsA("ImageButton") then
			b.Image = ""
			b.BackgroundTransparency = 1
			local tile = b:FindFirstChild("Tile") or new("Frame", { Name = "Tile" }, b)
			tile.Size = UDim2.fromScale(1, 1)
			tile.ZIndex = 2
			R.Skin(tile, spec[3], spec[4], { corner = 8, gloss = 140 })
			local icon = tile:FindFirstChild("Icon") or new("ImageLabel", { Name = "Icon" }, tile)
			icon.BackgroundTransparency = 1
			icon.Image = images[spec[1]] or ""
			icon.ScaleType = Enum.ScaleType.Fit
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 4)
			icon.Size = UDim2.fromOffset(70, 70)
			icon.ZIndex = 5
			R.Text(tile, "Label", spec[2], 26, 6, { Position = UDim2.new(0, 4, 1, -32), Size = UDim2.new(1, -8, 0, 30), align = Enum.TextXAlignment.Center })
		end
	end
end

---------------------------------------------------------------- top bar (POWERS / BUY / SELL / BASE)
R.TOP = { Powers = true, Buy = true, Sell = true, Base = true } -- text only (the designer turned the icons down)

function R.TopBar(bar, images)
	for name, img in R.TOP do
		local b = bar:FindFirstChild(name)
		if b then
			local rim = child(b, "UIStroke", "Rim")
			rim.Color = b.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.6)
			rim.Thickness = 3
			rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			child(b, "UICorner", "UICorner").CornerRadius = UDim.new(0, 8)
			child(b.Face, "UICorner", "UICorner").CornerRadius = UDim.new(0, 8)
			local dots = b.Face:FindFirstChild("Dots")
			if dots then
				dots.Image = DOTS
				dots.ScaleType = Enum.ScaleType.Tile
				dots.TileSize = UDim2.fromOffset(14, 14)
				dots.ImageTransparency = 0.72
			end
			local icon = b:FindFirstChild("Icon")
			if icon then
				icon:Destroy()
			end
			local label = b.Face:FindFirstChild("Label")
			if label then
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Position = UDim2.new(0.5, 0, 0.5, 0)
				label.Size = UDim2.new(1, -24, 0.84, 0)
			end
		end
	end
end

---------------------------------------------------------------- admin panel
function R.Admin(p, images)
	p.Size = UDim2.fromOffset(1060, 782)
	local w = p.Window
	R.Banner(w, { "RailAdmin", "Admin Tools", "Pick a player on the left, then run a command." }, images, 112, 53, R.BANNER_COLORS.AdminPanel)
	for _, n in { "Players", "Commands" } do
		local box = w:FindFirstChild(n)
		if box then
			box.Position = UDim2.fromOffset(box.Position.X.Offset, 194)
			box.Size = UDim2.fromOffset(box.Size.X.Offset, 500)
		end
	end
	for _, n in { "Players", "Commands", "Status" } do
		local box = w:FindFirstChild(n)
		if box then
			box.BackgroundColor3 = hex("161616")
			child(box, "UICorner", "UICorner").CornerRadius = UDim.new(0, 6)
			local s = child(box, "UIStroke", "UIStroke")
			s.Color = hex(R.CARD_RIM)
			s.Thickness = 3
		end
	end
end

---------------------------------------------------------------- text shadows (static pass; UIThemeController does the same live)
-- shadow drop ~8% of the text size (1-4 px), the shadow's outline fades with its fill, and every text holder sits
-- above its tile's Dots / Gloss / Halftone overlays
local OVERLAYS = { Dots = true, Gloss = true, Halftone = true }
function R.FixShadows(ui)
	local n = 0
	for _, c in ui:GetDescendants() do
		if c:IsA("UITextSizeConstraint") and c.MinTextSize > 6 then
			c.MinTextSize = 6 -- shrink to fit rather than spill out of the box
		end
	end
	for _, shadow in ui:GetDescendants() do
		if shadow.Name == "Shadow" and shadow:IsA("TextLabel") then
			local holder = shadow.Parent
			local label = holder:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				local c = label:FindFirstChildOfClass("UITextSizeConstraint")
				local size = label.TextScaled and (c and c.MaxTextSize or 40) or label.TextSize
				if holder:IsA("GuiObject") and holder.AbsoluteSize.Y > 0 then
					size = math.min(size, holder.AbsoluteSize.Y)
				end
				local drop = math.clamp(math.floor(size * 0.08 + 0.5), 1, 4)
				shadow.Position = label.Position + UDim2.fromOffset(0, drop)
				if not shadow.Text:find("<") then
					shadow.RichText = label.RichText -- rich vs plain layout differs a few px
				end
				-- crisp solid drop (a half-see-through shadow read as a grey smear)
				if shadow.TextTransparency > 0 and shadow.TextTransparency < 0.6 then
					shadow.TextTransparency = 0
				end
				shadow.TextColor3 = Color3.new(0, 0, 0)
				local s = shadow:FindFirstChildOfClass("UIStroke")
				local ls = label:FindFirstChildOfClass("UIStroke")
				if s then
					s.Transparency = 0
					s.Color = Color3.new(0, 0, 0)
					if ls then
						s.Thickness = ls.Thickness
					end
				end
				if holder:IsA("GuiObject") and holder.Parent then
					local top
					for _, sib in holder.Parent:GetChildren() do
						if OVERLAYS[sib.Name] and sib:IsA("GuiObject") then
							top = math.max(top or -math.huge, sib.ZIndex)
						end
					end
					if top and holder.ZIndex <= top then
						holder.ZIndex = top + 1
					end
				end
				n += 1
			end
		end
	end
	return n
end

---------------------------------------------------------------- apply
function R.Apply()
	local ui = game:GetService("StarterGui").KaijuUI
	local images = require(ui.UIConfig:Clone()).Images -- a fresh copy: require() caches the module from earlier runs
	local P = ui.Panels
	for name, h in R.HEADERS do
		local p = P:FindFirstChild(name)
		local header = p and p.Window:FindFirstChild("Header")
		if header then
			R.Skin(header, h[1], h[2], { rotation = 0, dots = 26, dotsT = 0.55, gloss = 400, stroke = 2.5 })
		end
	end
	-- list panels: taller window, banner, grid of cards
	for name, spec in R.BANNERS do
		local p = P[name]
		p.Size = UDim2.fromOffset(760, 740)
		local w = p.Window
		R.Banner(w, spec, images, 112, 53, R.BANNER_COLORS[name])
		gridList(w.List, 192, w:FindFirstChild("Footer") and 70 or 10)
		local empty = w:FindFirstChild("Empty")
		if empty then
			empty.Position = UDim2.fromOffset(60, 300)
		end
		for _, c in w.List:GetChildren() do
			if c.Name:match("_Sample$") then
				local t = ui.Templates:FindFirstChild((c.Name:gsub("_Sample$", "")))
				if t then
					c:Destroy()
				end
			end
		end
	end
	R.Cards(ui.Templates)
	-- no preview cards and no open panels in Studio's edit view (the designer asked for a clean screen)
	for _, d in ui:GetDescendants() do
		if d.Name:match("_Sample$") then
			d:Destroy()
		end
	end
	for _, p in P:GetChildren() do
		if p:IsA("GuiObject") then
			p.Visible = false
		end
	end
	R.Rail(ui.HUD.LeftRail, images)
	R.TopBar(ui.HUD.BottomBar, images)
	R.FixShadows(ui)
	-- edit-view preview at the size the game will use for this Studio window (UIApi rescales every AutoScale at runtime)
	local cfg = require(ui.UIConfig:Clone())
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(vp.Y / cfg.DesignHeight, cfg.MinScale, cfg.MaxScale)
	s = math.min(s, (vp.X - 24) / cfg.BottomBarDesignWidth)
	for _, d in ui:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "AutoScale" then
			d.Scale = s
		end
	end
	if P:FindFirstChild("AdminPanel") then
		R.Admin(P.AdminPanel, images)
	end
	return "ok"
end

return R
