-- Edit-time tool: copies every species' brick model (ServerStorage.Assets.Kaiju, built by Tools.KaijuBuilder) into
-- ReplicatedStorage.Assets.KaijuPortraits, so clients can show any kaiju in a ViewportFrame (Kaiju Index portraits),
-- not only the ones standing in their pen. Copies are anchored with collisions, queries and touches off, and prompts,
-- scripts and billboards stripped. Rerun after rebuilding kaiju art:
--   require(game.ServerStorage.Tools.PortraitBuilder:Clone()).Build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PortraitBuilder = {}

function PortraitBuilder.Build()
	local copy = ReplicatedStorage.Shared.Config.KaijuConfig:Clone()
	local KaijuConfig = require(copy)
	copy:Destroy()
	local source = ServerStorage:WaitForChild("Assets"):WaitForChild("Kaiju")
	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local old = assets:FindFirstChild("KaijuPortraits")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "KaijuPortraits"
	local made, missing, parts = 0, {}, 0
	for species in KaijuConfig do
		local art = source:FindFirstChild(species)
		if art then
			local m = art:Clone()
			m.Name = species
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
					parts += 1
				elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then
					d:Destroy()
				end
			end
			m.Parent = folder
			made += 1
		else
			table.insert(missing, species)
		end
	end
	folder.Parent = assets
	return string.format("KaijuPortraits: %d models, %d parts%s", made, parts, #missing > 0 and (", no art for " .. table.concat(missing, ", ")) or "")
end

return PortraitBuilder
