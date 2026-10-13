-- Edit-time tool for the kaiju quality pass: lays out current (ServerStorage.Assets.Kaiju) vs redesigned
-- (Tools.KaijuSpecsV2) models in pairs on a stage at y = 2000 (Workspace.KaijuPreview) for screenshots.
--   local P = require(game.ServerStorage.Tools.KaijuPreview:Clone())
--   P.Show({ "Chompling", "Bonkey" })   -> returns brick counts; P.Clear() removes the stage
local ServerStorage = game:GetService("ServerStorage")

local P = {}

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

function P.Clear()
	local old = workspace:FindFirstChild("KaijuPreview")
	if old then
		old:Destroy()
	end
end

local function stage()
	local f = workspace:FindFirstChild("KaijuPreview")
	if f then
		for _, c in f:GetChildren() do
			if c:IsA("Model") then
				c:Destroy()
			end
		end
		return f
	end
	f = Instance.new("Folder")
	f.Name = "KaijuPreview"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(120, 1, 60)
	floor.CFrame = CFrame.new(0, 1999.5, 10)
	floor.Color = Color3.fromHex("8FC46A")
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = f
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.Size = Vector3.new(120, 50, 1)
	wall.CFrame = CFrame.new(0, 2020, 18)
	wall.Color = Color3.fromHex("BFE3FF")
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = f
	f.Parent = workspace
	return f
end

-- Pairs (current left, new right) along X, `gap` studs apart, every model turned `yaw` degrees towards the viewer.
-- Returns a summary and the X centre of each pair.
function P.Show(names, gap, yaw)
	gap = gap or 7
	yaw = yaw or 28
	local B = fresh(ServerStorage.Tools.KaijuBuilder)
	local specs = fresh(ServerStorage.Tools.KaijuSpecsV2)
	local f = stage()
	local out, centres = {}, {}
	for i, name in names do
		local cx = ((#names + 1) / 2 - i) * gap * 2
		centres[name] = cx
		local cur = ServerStorage.Assets.Kaiju:FindFirstChild(name)
		local count = 0
		if cur then
			cur = cur:Clone()
			cur.Name = name .. "_Current"
			cur.WorldPivot = cur.PrimaryPart.CFrame
			cur:PivotTo(CFrame.new(cx + gap / 2, 2000.1, 0) * CFrame.Angles(0, math.rad(yaw), 0))
			cur.Parent = f
			for _, d in cur:GetDescendants() do
				if d:IsA("BasePart") then
					count += 1
				end
			end
		end
		local spec = specs[name]
		if spec then
			local m = B.BuildModel(name .. "_New", spec)
			m:PivotTo(CFrame.new(cx - gap / 2, 2000.1, 0) * CFrame.Angles(0, math.rad(yaw), 0))
			m.Parent = f
			table.insert(out, string.format("%s: %d -> %d parts", name, count, m:GetAttribute("Bricks") + #(spec.Bits or {}) + #(spec.Details or {})))
		else
			table.insert(out, name .. ": no V2 spec")
		end
		task.wait()
	end
	return table.concat(out, "\n"), centres
end

return P
