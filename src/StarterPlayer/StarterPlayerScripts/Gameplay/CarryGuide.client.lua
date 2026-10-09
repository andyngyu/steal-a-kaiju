-- While the local player carries an egg (CarryingEgg) or stolen goods (CarryingStolen, StealService):
--   a glowing arrow floats ahead of them pointing to their pen (entrance first, then the middle) with the distance,
--     hidden once they're inside the pen or when the Path Home setting (CarryGuide) is off;
--   while carrying a nest egg, the screen edges pulse red as your guardian closes in (each player has their own:
--     guardian attribute TargetUserId).
-- Client-only and cosmetic.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer
local plotsFolder = workspace:WaitForChild("Map"):WaitForChild("Plots")
local guardianFolder = workspace:WaitForChild("Runtime"):WaitForChild("Guardians")

local ARROW_COLOR = Color3.fromHex("6BFF4A")
local DANGER_COLOR = Color3.fromHex("FF2E3E")
local DANGER_RANGE = 40 -- studs between the guardian's reach and you where the edges start to glow

-- ---------- arrow ----------

local function neonPart(parent, size, cf)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = ARROW_COLOR
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Chevron arrow pointing along -Z, built around the origin; parts keep their offsets for BulkMoveTo.
local arrow = Instance.new("Model")
arrow.Name = "CarryGuideArrow"
local pieces = {}
local function piece(size, offset)
	local p = neonPart(arrow, size, offset)
	table.insert(pieces, { part = p, offset = offset })
	return p
end
local shaft = piece(Vector3.new(0.8, 0.45, 3.4), CFrame.new(0, 0, 1.1))
piece(Vector3.new(0.8, 0.45, 2.6), CFrame.new(-0.82, 0, -0.85) * CFrame.Angles(0, math.rad(-42), 0))
piece(Vector3.new(0.8, 0.45, 2.6), CFrame.new(0.82, 0, -0.85) * CFrame.Angles(0, math.rad(42), 0))
local light = Instance.new("PointLight")
light.Color = ARROW_COLOR
light.Range = 10
light.Brightness = 1.2
light.Shadows = false
light.Parent = shaft

local label = Instance.new("BillboardGui")
label.Name = "Distance"
label.Size = UDim2.fromOffset(120, 34)
label.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
label.AlwaysOnTop = true
label.LightInfluence = 0
label.Adornee = shaft
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.Font = Enum.Font.FredokaOne
text.TextScaled = true
text.TextColor3 = Color3.new(1, 1, 1)
text.TextStrokeColor3 = Color3.fromHex("1E5A12")
text.TextStrokeTransparency = 0
text.Parent = label
label.Parent = shaft

local function myPlot()
	local id = player:GetAttribute("PlotId")
	return id and plotsFolder:FindFirstChild("Plot" .. id)
end

local function insidePart(part, pos)
	local p = part.CFrame:PointToObjectSpace(pos)
	return math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2
end

-- Where the arrow should point, or nil when it shouldn't show.
local function guideTarget(pos)
	local plot = myPlot()
	local zone = plot and plot:FindFirstChild("Zone")
	local mat = plot and plot:FindFirstChild("EntranceMat")
	if not (zone and mat) then
		return nil
	end
	if insidePart(zone, pos) then
		return nil -- home: drop it
	end
	local entrance = Vector3.new(mat.Position.X, pos.Y, mat.Position.Z)
	if (entrance - pos).Magnitude > 6 then
		return entrance
	end
	return Vector3.new(zone.Position.X, pos.Y, zone.Position.Z)
end

-- ---------- danger edges ----------

local gui = Instance.new("ScreenGui")
gui.Name = "DangerEdges"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -5
gui.Enabled = false
local edges = {}
for _, e in {
	{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), -90 },
	{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
} do
	local f = Instance.new("Frame")
	f.Size = e[1]
	f.Position = e[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = DANGER_COLOR
	local g = Instance.new("UIGradient")
	g.Rotation = e[3]
	g.Parent = f
	f.Parent = gui
	table.insert(edges, g)
end
gui.Parent = player:WaitForChild("PlayerGui")

-- 0..1: how close the guardian chasing this egg's biome is.
local function danger(pos)
	local from = player:GetAttribute("CarryingFromBiome")
	if not from then
		return 0
	end
	for _, g in guardianFolder:GetChildren() do
		local target = g:GetAttribute("TargetUserId")
		if g:GetAttribute("State") == "Chasing" and g.PrimaryPart and (target == player.UserId or (target == nil and g:GetAttribute("BiomeId") == from)) then
			local root = g.PrimaryPart
			local d = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude - root.Size.Z / 2
			return math.clamp(1 - d / DANGER_RANGE, 0, 1)
		end
	end
	return 0
end

-- ---------- update ----------

local heading = nil
local shown = 0
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local carrying = hrp and player:GetAttribute("CarryingEgg") ~= nil
	local stealing = hrp and player:GetAttribute("CarryingStolen") ~= nil
	local t = os.clock()

	-- arrow
	local target = (carrying or stealing) and Settings.Get("CarryGuide") and guideTarget(hrp.Position)
	if target then
		local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
		local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
		heading = heading and heading:Lerp(dir, math.min(1, dt * 10)).Unit or dir
		shown = math.min(1, shown + dt * 4)
		local at = hrp.Position + heading * 6.5 + Vector3.new(0, -0.3 + math.sin(t * 4) * 0.15, 0)
		local cf = CFrame.lookAt(at, at + heading) * CFrame.new(0, 0, -math.sin(t * 6) * 0.25)
		local parts, cfs = {}, {}
		for _, pc in pieces do
			table.insert(parts, pc.part)
			table.insert(cfs, cf * pc.offset)
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		for _, pc in pieces do
			pc.part.Transparency = 1 - shown
		end
		text.Text = string.format("HOME %dm", math.floor(flat.Magnitude))
		text.TextTransparency = 1 - shown
		text.TextStrokeTransparency = 1 - shown
		if arrow.Parent ~= workspace then
			arrow.Parent = workspace
		end
	elseif arrow.Parent then
		shown = 0
		heading = nil
		arrow.Parent = nil
	end

	-- danger edges
	local k = carrying and danger(hrp.Position) or 0
	if k > 0 then
		gui.Enabled = true
		local pulse = 0.75 + 0.25 * math.sin(t * (6 + 8 * k))
		local edge = 1 - 0.65 * k * pulse
		for _, g in edges do
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, edge), NumberSequenceKeypoint.new(1, 1) })
		end
	else
		gui.Enabled = false
	end
end)
