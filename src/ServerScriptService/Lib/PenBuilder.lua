-- Builds a plot's wooden pen fence for a level: posts with coloured caps, two rails and X braces per span,
-- with a gap at the front for the entrance. Model attributes: Level, BuiltAt (server time, clients animate the rise).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)

local PenBuilder = {}

local P = MapConfig.Plots
local C = MapConfig.Palette

local function part(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function beam(parent, name, a, b, thickness, color)
	local len = (b - a).Magnitude
	return part(parent, name, Vector3.new(thickness, thickness * 1.2, len), CFrame.lookAt((a + b) / 2, b), color)
end

function PenBuilder.Build(plot, levelIndex)
	local level = PenGeometry.Level(levelIndex)
	local frame = PenGeometry.Frame(plot)
	local accent = plot:GetAttribute("Color") or C.Cream
	local h = P.FenceHeight
	local W, D = level.Width, level.Depth
	local eh = P.EntranceWidth / 2

	local pen = Instance.new("Model")
	pen.Name = "Pen"
	pen:SetAttribute("Level", levelIndex)

	local function world(x, d, y)
		return (frame * CFrame.new(x, y or 0, -d)).Position
	end

	local posts = {}
	local function post(x, d)
		local key = math.round(x * 10) .. ":" .. math.round(d * 10)
		if posts[key] then
			return
		end
		posts[key] = true
		part(pen, "Post", Vector3.new(0.9, h + 0.4, 0.9), CFrame.new(world(x, d, (h + 0.4) / 2)), C.WoodDark)
		part(pen, "Cap", Vector3.new(1.2, 0.5, 1.2), CFrame.new(world(x, d, h + 0.65)), accent)
	end

	-- one straight fence run from (x0,d0) to (x1,d1)
	local function run(x0, d0, x1, d1)
		local a, b = world(x0, d0), world(x1, d1)
		local len = (b - a).Magnitude
		local spans = math.max(1, math.round(len / P.PostSpacing))
		for i = 0, spans do
			local t = i / spans
			post(x0 + (x1 - x0) * t, d0 + (d1 - d0) * t)
		end
		for _, y in { 1.2, h - 0.5 } do
			beam(pen, "Rail", a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.35, C.Wood)
		end
		for i = 0, spans - 1 do
			local p0 = a:Lerp(b, i / spans)
			local p1 = a:Lerp(b, (i + 1) / spans)
			beam(pen, "Brace", p0 + Vector3.new(0, 1.2, 0), p1 + Vector3.new(0, h - 0.5, 0), 0.25, C.Wood)
			beam(pen, "Brace", p0 + Vector3.new(0, h - 0.5, 0), p1 + Vector3.new(0, 1.2, 0), 0.25, C.Wood)
		end
	end

	run(-W / 2, 0, -eh, 0)
	run(eh, 0, W / 2, 0)
	run(-W / 2, 0, -W / 2, D)
	run(W / 2, 0, W / 2, D)
	run(-W / 2, D, W / 2, D)

	pen:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
	return pen
end

return PenBuilder
