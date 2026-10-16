-- Studio-only bench for checking converted eggs in-engine: Bench.Show(biome, row) fetches the five test exports from the
-- local server (Blender serves KaijuEggs/v2/test on :8766) and lines them up at workspace._EggCheck (y = 700).
local HttpService = game:GetService("HttpService")
local Importer = require(script.Parent.BlenderEggImporter)

local Bench = {}
Bench.Base = Vector3.new(0, 700, 0)

function Bench.Show(biome, row, scale)
	row = row or 0
	local f = workspace:FindFirstChild("_EggCheck") or Instance.new("Folder")
	f.Name = "_EggCheck"
	f.Parent = workspace
	for _, c in f:GetChildren() do
		if c:GetAttribute("Row") == row then
			c:Destroy()
		end
	end
	local base = Bench.Base + Vector3.new(0, 0, row * 8)
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(40, 1, 8)
	floor.Color = Color3.fromHex("6A8A4A")
	floor.CFrame = CFrame.new(base - Vector3.new(0, 0.5, 0))
	floor:SetAttribute("Row", row)
	floor.Parent = f
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, err = pcall(function()
		for i, r in { "Common", "Rare", "Epic", "Legendary", "Secret" } do
			local js = HttpService:GetAsync("http://127.0.0.1:8766/" .. biome .. "_" .. r .. ".json?" .. os.clock(), true)
			local m = Importer.Build(js)
			m:ScaleTo(scale or 1.5)
			m:PivotTo(CFrame.new(base + Vector3.new((3 - i) * 5, m.PrimaryPart.Size.Y / 2, 0)))
			m:SetAttribute("Row", row)
			m.Parent = f
		end
	end)
	HttpService.HttpEnabled = was
	return ok, err
end

return Bench
