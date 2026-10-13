-- Builds a personal treadmill model for a level (TreadmillConfig.Levels), or a locked hologram.
-- Model is built around the origin with feet at y = 0; the runner faces -Z (the console end).
-- Children: Deck (RunPoint attachment, RunPrompt), Chevrons/Chevron<i> (clients scroll these while someone runs).
-- Attributes: Level, Ghost.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)
local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)

local TreadmillBuilder = {}

local STUD_FACES = { Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }
local BLACK = Color3.fromHex("121218")
local C = CFrame.new
local A = CFrame.Angles

local function part(parent, name, size, cf, color, material, studs, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if studs then
		for _, face in STUD_FACES do
			local t = Instance.new("Texture")
			t.Texture = MapConfig.StudTexture
			t.Face = face
			t.StudsPerTileU = 2
			t.StudsPerTileV = 2
			t.Color3 = Color3.new(0, 0, 0)
			t.Transparency = 0.72
			t.Parent = p
		end
	end
	p.Parent = parent
	return p
end

local function cylinderX(parent, name, length, diameter, cf, color)
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function sparkles(parent, color, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Rate = rate
	pe.Parent = parent
	return pe
end

-- Shared shape. Returns deck, console, screen, crossbar.
local function geometry(model, th, neon)
	part(model, "Plinth", Vector3.new(6.6, 0.4, 11.4), C(0, 0.2, 0), BLACK, nil, true)
	local deck = part(model, "Deck", Vector3.new(5.6, 1.0, 10), C(0, 0.9, 0), th.Frame, nil, true)
	deck.CanCollide = true
	for _, s in { -1, 1 } do
		part(model, "Skirt", Vector3.new(0.8, 1.6, 10.4), C(s * 3.0, 1.2, 0), th.Trim, nil, true)
		if neon then
			part(model, "Strip", Vector3.new(0.22, 0.22, 10), C(s * 3.0, 2.08, 0), th.Trim, Enum.Material.Neon)
		end
	end
	local belt = part(model, "Belt", Vector3.new(4.4, 0.2, 9.0), C(0, 1.5, 0), th.Belt)
	belt.CanCollide = true
	for _, z in { -4.8, 4.8 } do
		cylinderX(model, "Roller", 4.9, 1.4, C(0, 1.1, z), th.Trim)
	end
	part(model, "RearStep", Vector3.new(5.6, 0.6, 0.9), C(0, 0.9, 5.4), th.Trim, nil, true)

	-- scrolling chevrons (V points towards the console)
	local chevrons = Instance.new("Folder")
	chevrons.Name = "Chevrons"
	chevrons.Parent = model
	for i = 1, 6 do
		local z = -3.6 + (i - 1) * 1.45
		local ch = Instance.new("Model")
		ch.Name = "Chevron" .. i
		for _, s in { -1, 1 } do
			part(ch, "Arm", Vector3.new(0.45, 0.07, 1.4), C(s * 0.52, 1.64, z) * A(0, math.rad(s * 40), 0), th.Chevron, Enum.Material.Neon)
		end
		ch.Parent = chevrons
	end

	-- sloped hood at the front, rising towards the console
	part(model, "Hood", Vector3.new(5.6, 2.2, 2.6), C(0, 2.5, -5.6) * A(0, math.rad(180), 0), th.Trim, nil, true, "WedgePart")

	-- leaning uprights joined by a crossbar arch
	local lean = math.rad(18)
	for _, s in { -1, 1 } do
		part(model, "Upright", Vector3.new(1.0, 5.2, 1.0), C(s * 2.65, 1.6 + 2.6 * math.cos(lean), -5.0 + 2.6 * math.sin(lean)) * A(lean, 0, 0), th.Trim, nil, true)
	end
	local topY, topZ = 1.6 + 5.2 * math.cos(lean), -5.0 + 5.2 * math.sin(lean)
	local crossbar = part(model, "Crossbar", Vector3.new(6.3, 1.0, 1.1), C(0, topY, topZ) * A(lean, 0, 0), th.Trim, nil, true)

	-- console hangs under the crossbar, tilted up towards the runner
	local console = part(model, "Console", Vector3.new(4.4, 1.5, 1.0), C(0, topY - 1.2, topZ + 0.3) * A(math.rad(-35), 0, 0), BLACK, nil, true)
	if neon then
		part(model, "ConsoleTrim", Vector3.new(4.6, 0.18, 1.1), console.CFrame * C(0, 0.8, 0), th.Trim, Enum.Material.Neon)
	end
	local screen = part(model, "Screen", Vector3.new(3.6, 0.9, 0.1), console.CFrame * C(0, 0.05, 0.52), th.Screen, Enum.Material.Neon)

	-- curved handlebars (two segments) with black grips
	for _, s in { -1, 1 } do
		part(model, "Handlebar", Vector3.new(0.5, 0.5, 3.4), C(s * 2.9, 4.5, -2.6) * A(math.rad(-8), 0, 0), th.Trim, nil, true)
		part(model, "HandlebarDrop", Vector3.new(0.5, 1.9, 0.5), C(s * 2.9, 3.55, -0.75) * A(math.rad(-28), 0, 0), th.Trim, nil, true)
		part(model, "Grip", Vector3.new(0.65, 0.65, 1.1), C(s * 2.9, 4.32, -1.5) * A(math.rad(-8), 0, 0), BLACK)
	end
	return deck, console, screen, crossbar
end

function TreadmillBuilder.Build(levelIndex)
	local level = TreadmillConfig.Levels[levelIndex]
	local th = level.Theme
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	model:SetAttribute("Level", levelIndex)
	model:SetAttribute("Ghost", false)
	local deck, console, screen, crossbar = geometry(model, th, th.NeonTrim)
	model.PrimaryPart = deck

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromHex("121218")
	l.Text = "LV " .. levelIndex .. " " .. string.upper(level.Name)
	l.Parent = gui
	gui.Parent = screen

	-- sparkles, flames and other tier VFX are drawn client-side (StarterPlayerScripts.Gameplay.SpeedFX)
	if th.Fire then
		for _, s in { -1, 1 } do
			part(model, "Jet", Vector3.new(0.7, 0.7, 0.7), C(s * 2.0, 1.4, 5.9), BLACK) -- flames: SpeedFX
		end
	end
	if th.Plates then
		for i, x in { -1.8, 0, 1.8 } do
			local h = i == 2 and 1.9 or 1.3
			part(model, "Plate", Vector3.new(0.4, h, 1.0), crossbar.CFrame * C(x, 0.5 + h / 2, 0) * A(math.rad(-12), 0, 0), th.Chevron, Enum.Material.Neon)
		end
	end

	local run = Instance.new("Attachment")
	run.Name = "RunPoint"
	run.Position = Vector3.new(0, 0.7, 1.0) -- belt top, a little behind centre
	run.Parent = deck

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RunPrompt"
	prompt.ActionText = "Run"
	prompt.ObjectText = level.Name .. " Treadmill"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TreadmillConfig.RunPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = deck
	return model
end

-- Locked placeholder: the level 1 shape as a blue hologram.
function TreadmillBuilder.BuildGhost()
	local th = TreadmillConfig.Levels[1].Theme
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	model:SetAttribute("Level", 0)
	model:SetAttribute("Ghost", true)
	local deck = geometry(model, th, false)
	model.PrimaryPart = deck
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.ForceField
			p.Color = Color3.fromHex("7FD7FF")
			p.CanCollide = false
			p.CastShadow = false
		elseif p:IsA("Texture") then
			p:Destroy()
		end
	end
	return model
end

return TreadmillBuilder
