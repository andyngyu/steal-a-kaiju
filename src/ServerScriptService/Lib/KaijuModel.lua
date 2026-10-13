-- Builds a kaiju display model. Uses ServerStorage.Assets.Kaiju.<Model> when it exists (art pass), otherwise a blocky
-- placeholder per archetype. Origin = centre of the feet, facing -Z. Adds an "Info" billboard with TextLabels
-- [SizeTier] / Rarity / Title / LevelRow (Label "Lv 12" + Bar.Fill XP bar) / Cash.
-- Size and income come from Shared.Util.KaijuStats (species, size roll, level). Model attributes: Species, Rarity, Size,
-- SizeTier, VisualScale, Level, XP, XPToNext (nil at max level), PartCount.
-- Epic+ get a sparkle "Aura" part, Legendary+ also a light and coloured mist (Secret = rainbow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage.Shared.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local FoodConfig = require(Config.FoodConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)

local KaijuModel = {}

local INK = Color3.fromHex("1A1033")
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD84A")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local MIST = "rbxasset://textures/particles/smoke_main.dds"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D4D")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFB84D")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFF04D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4DFF88")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("4DB8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("C44DFF")),
})

local function part(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Parent = model
	return p
end

local function eyes(model, center, spacing, size)
	for _, sx in { -1, 1 } do
		part(model, "Eye", Vector3.new(size, size, 0.2), CFrame.new(center + Vector3.new(sx * spacing, 0, 0)), WHITE)
		part(model, "Pupil", Vector3.new(size * 0.55, size * 0.6, 0.2), CFrame.new(center + Vector3.new(sx * spacing * 0.95, -size * 0.05, -0.08)), INK)
	end
end

-- Each builder works in a 1-scale space with feet at y = 0, facing -Z.
local BUILDERS = {}

function BUILDERS.Lizard(m, c, a)
	part(m, "Body", Vector3.new(2, 2.2, 1.8), CFrame.new(0, 1.6, 0), c)
	part(m, "Belly", Vector3.new(1.4, 1.6, 0.2), CFrame.new(0, 1.5, -0.95), Color3.fromHex("FFEBC2"))
	part(m, "Head", Vector3.new(2, 1.7, 1.8), CFrame.new(0, 3.4, -0.3), c)
	part(m, "Snout", Vector3.new(1.4, 0.7, 0.8), CFrame.new(0, 3.05, -1.5), Color3.fromHex("FFEBC2"))
	eyes(m, Vector3.new(0, 3.7, -1.22), 0.5, 0.5)
	for _, sx in { -1, 1 } do
		part(m, "Leg", Vector3.new(0.7, 0.6, 0.9), CFrame.new(sx * 0.6, 0.3, -0.1), c:Lerp(INK, 0.15))
		part(m, "Arm", Vector3.new(0.4, 0.8, 0.4), CFrame.new(sx * 1.1, 1.8, -0.6), c)
	end
	part(m, "Tail", Vector3.new(0.8, 0.7, 2), CFrame.new(0, 0.7, 1.6) * CFrame.Angles(math.rad(15), 0, 0), c)
	for i = 0, 2 do
		part(m, "Plate", Vector3.new(0.25, 0.7 - i * 0.12, 0.6), CFrame.new(0, 3 - i * 0.7, 0.95 + i * 0.25), a, Enum.Material.Neon)
	end
end

function BUILDERS.Quadruped(m, c, a)
	part(m, "Body", Vector3.new(2, 1.6, 3), CFrame.new(0, 1.6, 0.2), c)
	part(m, "Head", Vector3.new(1.7, 1.5, 1.5), CFrame.new(0, 2.3, -1.7), c)
	part(m, "Snout", Vector3.new(1.1, 0.6, 0.5), CFrame.new(0, 1.95, -2.6), a)
	eyes(m, Vector3.new(0, 2.55, -2.47), 0.42, 0.42)
	for _, sx in { -1, 1 } do
		for _, z in { -0.9, 1.2 } do
			part(m, "Leg", Vector3.new(0.6, 0.9, 0.6), CFrame.new(sx * 0.65, 0.45, z), c:Lerp(INK, 0.15))
		end
		part(m, "Horn", Vector3.new(0.25, 0.6, 0.25), CFrame.new(sx * 0.5, 3.25, -1.6), a, Enum.Material.Neon)
	end
	part(m, "Tail", Vector3.new(0.4, 0.4, 0.9), CFrame.new(0, 1.9, 1.9), c)
end

function BUILDERS.Ape(m, c, a)
	part(m, "Body", Vector3.new(2.4, 2.2, 1.8), CFrame.new(0, 1.9, 0), c)
	part(m, "Chest", Vector3.new(1.6, 1.4, 0.2), CFrame.new(0, 2, -0.95), a)
	part(m, "Head", Vector3.new(1.6, 1.4, 1.4), CFrame.new(0, 3.6, -0.2), c)
	part(m, "Face", Vector3.new(1.2, 0.9, 0.2), CFrame.new(0, 3.45, -0.95), Color3.fromHex("FFD9A0"))
	eyes(m, Vector3.new(0, 3.75, -1.07), 0.32, 0.35)
	for _, sx in { -1, 1 } do
		part(m, "Arm", Vector3.new(0.8, 2, 0.8), CFrame.new(sx * 1.6, 1.6, -0.2), c)
		part(m, "Fist", Vector3.new(1, 0.9, 1), CFrame.new(sx * 1.6, 0.45, -0.3), a, Enum.Material.Neon)
		part(m, "Leg", Vector3.new(0.8, 0.8, 0.8), CFrame.new(sx * 0.6, 0.4, 0.2), c:Lerp(INK, 0.15))
	end
end

function BUILDERS.Serpent(m, c, a)
	local segments = { { 0, 0.6, 1.8, 1.2 }, { 0, 1.2, 0.9, 1.1 }, { 0, 2, 0.1, 1 }, { 0, 2.9, -0.5, 0.9 } }
	for i, s in segments do
		part(m, "Segment" .. i, Vector3.new(s[4] * 1.4, s[4] * 1.2, s[4] * 1.4), CFrame.new(s[1], s[2], s[3]), i % 2 == 0 and a or c, i % 2 == 0 and Enum.Material.Neon or nil)
	end
	part(m, "Head", Vector3.new(1.5, 1.2, 1.8), CFrame.new(0, 3.7, -1.1), c)
	eyes(m, Vector3.new(0, 3.95, -2.02), 0.4, 0.4)
	part(m, "Fin", Vector3.new(0.2, 1, 1.2), CFrame.new(0, 4.6, -0.8), a, Enum.Material.Neon)
end

function BUILDERS.CrabBug(m, c, a)
	part(m, "Body", Vector3.new(3, 1.1, 2.4), CFrame.new(0, 1.2, 0), c)
	part(m, "Shell", Vector3.new(2.4, 0.5, 1.8), CFrame.new(0, 1.95, 0.1), a, Enum.Material.Neon)
	for _, sx in { -1, 1 } do
		part(m, "EyeStalk", Vector3.new(0.2, 0.6, 0.2), CFrame.new(sx * 0.5, 2, -1.1), c)
		part(m, "Eye", Vector3.new(0.45, 0.45, 0.45), CFrame.new(sx * 0.5, 2.4, -1.1), WHITE)
		part(m, "Pupil", Vector3.new(0.22, 0.25, 0.1), CFrame.new(sx * 0.5, 2.4, -1.35), INK)
		part(m, "Claw", Vector3.new(0.9, 0.6, 1), CFrame.new(sx * 1.6, 1.1, -1.4), c:Lerp(a, 0.3))
		for _, z in { -0.7, 0, 0.7 } do
			part(m, "Leg", Vector3.new(0.9, 0.2, 0.2), CFrame.new(sx * 1.8, 0.5, z) * CFrame.Angles(0, 0, sx * math.rad(-30)), c:Lerp(INK, 0.2))
		end
	end
end

local XP_BLUE = Color3.fromHex("5AD1FF")

-- "Lv 12" + XP bar, centred together under the name (the label sizes to its text, so short and long levels both
-- sit centred). heightPx = the row's height in pixels (the billboard has a fixed pixel size).
local function levelRow(bb, order, h, heightPx)
	local row = Instance.new("Frame")
	row.Name = "LevelRow"
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(0.86, 0, h, 0)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, math.max(4, math.floor(heightPx * 0.3)))
	list.Parent = row
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.LayoutOrder = 1
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = false
	label.TextSize = math.max(8, math.floor(heightPx * 0.95))
	label.TextColor3 = XP_BLUE
	label.TextStrokeTransparency = 0.2
	label.Parent = row
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.LayoutOrder = 2
	bar.Size = UDim2.fromScale(0.6, 0.5)
	bar.BackgroundColor3 = Color3.fromHex("1A1033")
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = XP_BLUE
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	fill.Parent = bar
	bar.Parent = row
	row.Parent = bb
end

-- Updates the billboard's level text and XP bar (FoodService calls this after feeding).
function KaijuModel.SetProgress(model, level, xp, xpToNext)
	model:SetAttribute("Level", level)
	model:SetAttribute("XP", xp)
	model:SetAttribute("XPToNext", xpToNext)
	local info = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
	local row = info and info:FindFirstChild("LevelRow")
	if not row then
		return
	end
	row.Label.Text = level >= FoodConfig.MaxLevel and "MAX" or ("Lv " .. level)
	row.Bar.Fill.Size = UDim2.fromScale(xpToNext and math.clamp(xp / xpToNext, 0, 1) or 1, 1)
	row.Bar.Fill.BackgroundColor3 = xpToNext and XP_BLUE or GOLD
end

local function infoBillboard(model, top, cfg, size, scale, level)
	local rarity = EggConfig.RarityById[cfg.Rarity]
	local tier = EggConfig.SizeTierName(size)
	local k = math.clamp(0.85 + scale * 0.15, 1, 1.5)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	local bbHeight = (tier ~= "" and 110 or 88) * k
	bb.Size = UDim2.fromOffset(180 * k, bbHeight)
	bb.StudsOffsetWorldSpace = Vector3.new(0, top + 1.6, 0)
	bb.MaxDistance = 90 + (scale - 1) * 35
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bb
	local order = 0
	local function line(name, text, color, h)
		local l = Instance.new("TextLabel")
		order += 1
		l.LayoutOrder = order
		l.Name = name
		l.Size = UDim2.new(1, 0, h, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.2
		l.Text = text
		l.Parent = bb
	end
	local f = tier ~= "" and 0.82 or 1
	if tier ~= "" then
		line("SizeTier", string.format("%s  %.2fx", string.upper(tier), size), GOLD, 0.18)
	end
	line("Rarity", cfg.Rarity, rarity and rarity.Color or WHITE, 0.24 * f)
	line("Title", cfg.DisplayName, WHITE, 0.3 * f)
	order += 1
	levelRow(bb, order, 0.2 * f, 0.2 * f * bbHeight)
	line("Cash", Format.PerSecond(KaijuStats.CashPerSecond(model.Name, size, level)), Color3.fromHex("6BE04A"), 0.26 * f)
	bb.Parent = model.PrimaryPart
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.LightEmission = 1
	for key, value in props do
		pe[key] = value
	end
	pe.Parent = parent
	return pe
end

-- Invisible box around the body that carries the rarity flair (moves with the model like any other part).
local function aura(model, rarity, scale)
	if not (rarity and rarity.Glow) then
		return
	end
	local cf, ext = model:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "Aura"
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Size = ext * 0.85
	holder.CFrame = cf
	holder.Parent = model
	local colors = rarity.Id == "Secret" and RAINBOW or ColorSequence.new(rarity.Color, WHITE)
	emitter(holder, {
		Name = "Sparkles",
		Texture = SPARKLE,
		Color = colors,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.3 + 0.12 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.1, 1),
		Speed = NumberRange.new(0.3, 1.2),
		Acceleration = Vector3.new(0, 1.5, 0),
		Lifetime = NumberRange.new(1, 1.8),
		Rate = rarity.Aura and 8 + scale * 3 or 4,
	})
	if not rarity.Aura then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = rarity.Id == "Secret" and Color3.fromHex("F2D9FF") or rarity.Color
	light.Range = math.min(10 + ext.Magnitude * 0.5, 40)
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = holder
	emitter(holder, {
		Name = "Mist",
		Texture = MIST,
		Color = colors,
		Size = NumberSequence.new(1.2 * scale, 2.6 * scale),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(0.2, 0.6),
		Acceleration = Vector3.new(0, 0.8, 0),
		Lifetime = NumberRange.new(1.6, 2.6),
		RotSpeed = NumberRange.new(-30, 30),
		Rate = 4,
	})
end

-- How much bigger than its art this kaiju looks (see Shared.Util.KaijuStats).
function KaijuModel.VisualScale(speciesId, size, level)
	return KaijuStats.VisualScale(speciesId, size, level)
end

-- Returns a model whose pivot is the centre of its feet. Call :PivotTo() to place it.
function KaijuModel.Build(speciesId, size, level, xp)
	size = size or 1
	level = math.clamp(level or 1, 1, FoodConfig.MaxLevel)
	local cfg = KaijuConfig[speciesId]
	assert(cfg, "unknown kaiju " .. tostring(speciesId))
	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Kaiju") and assets.Kaiju:FindFirstChild(cfg.Model)

	local model
	if art then
		model = art:Clone()
	else
		model = Instance.new("Model")
		local root = part(model, "Root", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.1, 0), WHITE)
		root.Transparency = 1
		model.PrimaryPart = root
		;(BUILDERS[cfg.Archetype] or BUILDERS.Lizard)(model, cfg.Color, cfg.Accent)
	end
	model.Name = speciesId
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Rarity", cfg.Rarity)
	model:SetAttribute("Size", size)
	model:SetAttribute("SizeTier", EggConfig.SizeTierName(size))
	local scale = KaijuStats.VisualScale(speciesId, size, level)
	model:SetAttribute("VisualScale", scale)
	if math.abs(scale - 1) > 0.001 then
		model:ScaleTo(scale)
	end
	local _, ext = model:GetBoundingBox()
	infoBillboard(model, ext.Y, cfg, size, scale, level)
	KaijuModel.SetProgress(model, level, xp or 0, FoodConfig.XPToNext(level))
	aura(model, EggConfig.RarityById[cfg.Rarity], scale)
	-- clients wait until this many parts have arrived before animating the model (big models replicate over several frames)
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	model:SetAttribute("PartCount", parts)
	return model
end

return KaijuModel
