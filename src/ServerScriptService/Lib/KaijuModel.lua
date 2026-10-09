-- Builds a kaiju display model. Uses ServerStorage.Assets.Kaiju.<Model> when it exists (art pass), otherwise a blocky
-- placeholder per archetype. Origin = centre of the feet, facing -Z. Adds an "Info" billboard with TextLabels Rarity / Title / Cash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage.Shared.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local KaijuModel = {}

local INK = Color3.fromHex("1A1033")
local WHITE = Color3.new(1, 1, 1)

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

local function infoBillboard(model, top, cfg, cps)
	local rarity = EggConfig.RarityById[cfg.Rarity]
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(180, 70)
	bb.StudsOffsetWorldSpace = Vector3.new(0, top + 1.6, 0)
	bb.MaxDistance = 90
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bb
	local function line(name, text, color, h)
		local l = Instance.new("TextLabel")
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
	line("Rarity", cfg.Rarity, rarity and rarity.Color or WHITE, 0.3)
	line("Title", cfg.DisplayName, WHITE, 0.36)
	line("Cash", Format.PerSecond(cps), Color3.fromHex("6BE04A"), 0.34)
	bb.Parent = model.PrimaryPart
end

-- Returns a model whose pivot is the centre of its feet. Call :PivotTo() to place it.
function KaijuModel.Build(speciesId)
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
	if cfg.Scale ~= 1 then
		model:ScaleTo(cfg.Scale)
	end
	local _, size = model:GetBoundingBox()
	infoBillboard(model, size.Y, cfg, cfg.CashPerSecond)
	return model
end

return KaijuModel
