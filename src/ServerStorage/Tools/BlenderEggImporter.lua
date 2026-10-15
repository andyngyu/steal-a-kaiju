-- Builds egg models from the Blender egg export (ROBLOX3/Models/KaijuEggs: src/blender_build.py writes export/<Biome>_<Design>.json).
-- Each JSON holds a palette and greedy-merged voxel boxes "x0,y0,z0,x1,y1,z1,colour;..." in voxel units (body bottom at y0,
-- body = 28 voxels wide = the game's 2.2-stud egg). Blender's x is mirrored here so the front (-Z) faces the same way.
-- Result: Model <Biome>_<Design> with an invisible Shell (EggConfig.Size, bottom flush with the egg's bottom) as
-- PrimaryPart and the bricks welded to it. Parts named Gem / GemLight / GemCore are the front gem (Lib.EggModel tints
-- them with the egg's actual rarity).
-- Usage (command bar, Edit mode):
--   local Importer = require(game.ServerStorage.Tools.BlenderEggImporter)
--   local model = Importer.Build(jsonText)   -- or Importer.FetchAll("http://127.0.0.1:8766/", folder) while Blender serves export/
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)

local Importer = {}

Importer.Biomes = { "PebblePlains", "LavaLagoon", "FrostfangPeaks", "VenomJungle", "SunkenAbyss", "StormSpires", "CosmicRift" }
Importer.Designs = { "Common", "Rare", "Epic", "Legendary", "Secret" }

function Importer.Build(json)
	local data = HttpService:JSONDecode(json)
	local vox = data.vox
	local grid = data.grid
	local cx, cz = grid[1] / 2, grid[3] / 2
	local bodyY0 = data.body[1]
	local shellSize = EggConfig.Size
	-- shell centre in voxel space: bottom flush with the body's bottom
	local shellCentreY = bodyY0 + (shellSize.Y / 2) / vox

	local model = Instance.new("Model")
	model.Name = data.name
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = shellSize
	shell.Transparency = 1
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanTouch = false
	shell.CanQuery = true
	shell.CFrame = CFrame.new()
	shell.Parent = model
	model.PrimaryPart = shell

	local palette = {}
	for i, p in data.palette do
		palette[i] = { name = p.key, color = Color3.fromHex(p.hex), neon = p.neon }
	end
	local count = 0
	for box in string.gmatch(data.boxes, "[^;]+") do
		local v = string.split(box, ",")
		local x0, y0, z0, x1, y1, z1, c = tonumber(v[1]), tonumber(v[2]), tonumber(v[3]), tonumber(v[4]), tonumber(v[5]), tonumber(v[6]), tonumber(v[7])
		local p = palette[c]
		local size = Vector3.new(x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1) * vox
		-- centre in voxel units (x mirrored), relative to the shell centre
		local mx = (x0 + x1 + 1) / 2 - cx
		local my = (y0 + y1 + 1) / 2 - shellCentreY
		local mz = (z0 + z1 + 1) / 2 - cz
		local part = Instance.new("Part")
		part.Name = p.name
		part.Size = size
		part.CFrame = CFrame.new(-mx * vox, my * vox, mz * vox)
		part.Color = p.color
		part.Material = p.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = size.Magnitude > vox * 3
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shell
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		count += 1
	end
	model:SetAttribute("Bricks", count)
	model:SetAttribute("Design", data.design)
	model:SetAttribute("Source", "Blender")
	model:SetAttribute("VoxelStuds", vox)
	return model
end

-- Fetches every <Biome>_<Design>.json from a local server (Blender serves the export folder) into `folder`.
-- Turns HttpService on for the duration and puts it back.
function Importer.FetchAll(baseUrl, folder, biomes)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local made, errors = {}, {}
	local ok, err = pcall(function()
		for _, biome in biomes or Importer.Biomes do
			for _, design in Importer.Designs do
				local name = biome .. "_" .. design
				local got, body = pcall(HttpService.GetAsync, HttpService, baseUrl .. name .. ".json", true)
				if got then
					local old = folder:FindFirstChild(name)
					if old then
						old:Destroy()
					end
					local model = Importer.Build(body)
					model.Parent = folder
					table.insert(made, name .. "=" .. model:GetAttribute("Bricks"))
					task.wait()
				else
					table.insert(errors, name .. ": " .. tostring(body))
				end
			end
		end
	end)
	HttpService.HttpEnabled = was
	if not ok then
		table.insert(errors, tostring(err))
	end
	return made, errors
end

return Importer
