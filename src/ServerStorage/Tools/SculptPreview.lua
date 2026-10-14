-- Edit-time preview stage for the sculpted kaiju and guardians (Tools.KaijuSculptSpecs / GuardianSculptSpecs): builds
-- them fresh from their specs (nothing in Assets changes) in a row on a stage at y = 2000 (Workspace.SculptPreview).
--   local P = require(game.ServerStorage.Tools.SculptPreview:Clone())
--   P.Show({ "Vinewhip", "Shroomhog" }, { gap = 9, yaw = 30 })  -> summary, centres (x per name); P.Clear()
local ServerStorage = game:GetService("ServerStorage")

local P = {}

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

function P.Clear()
	local old = workspace:FindFirstChild("SculptPreview")
	if old then
		old:Destroy()
	end
end

local function stage(width)
	P.Clear()
	local f = Instance.new("Folder")
	f.Name = "SculptPreview"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(width + 40, 1, 80)
	floor.CFrame = CFrame.new(0, 1999.5, 10)
	floor.Color = Color3.fromHex("6E8A5A")
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = f
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.Size = Vector3.new(width + 40, 80, 1)
	wall.CFrame = CFrame.new(0, 2030, 30)
	wall.Color = Color3.fromHex("C8DCE8")
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = f
	f.Parent = workspace
	return f
end

-- names: species (KaijuSculptSpecs) or guardians ("Guardian_<BiomeId>", GuardianSculptSpecs); opts: gap (studs between
-- centres), yaw (degrees turned towards the viewer), scale (per name: shown at this size, e.g. guardians smaller)
function P.Show(names, opts)
	opts = opts or {}
	local S = fresh(ServerStorage.Tools.KaijuSculpt)
	local specs = fresh(ServerStorage.Tools.KaijuSculptSpecs)
	local gspecs = fresh(ServerStorage.Tools.GuardianSculptSpecs)
	local gap = opts.gap or 9
	local f = stage(#names * gap)
	local out, centres = {}, {}
	for i, name in names do
		local spec = specs[name] or gspecs[name]
		if spec then
			local ok, m = pcall(S.BuildModel, name, spec)
			if ok then
				local cx = ((#names + 1) / 2 - i) * gap
				centres[name] = cx
				local s = opts.scale and opts.scale[name]
				if s then
					m:ScaleTo(m:GetScale() * s)
				end
				m:PivotTo(CFrame.new(cx, 2000.05, 0) * CFrame.Angles(0, math.rad(opts.yaw or 30), 0))
				m.Parent = f
				local _, size = m:GetBoundingBox()
				table.insert(out, string.format("%s: %d parts, %.1f x %.1f x %.1f", name, m:GetAttribute("Bricks"), size.X, size.Y, size.Z))
			else
				table.insert(out, name .. ": ERROR " .. tostring(m))
			end
		else
			table.insert(out, name .. ": no spec")
		end
		task.wait()
	end
	return table.concat(out, "\n"), centres
end

return P
