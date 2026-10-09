-- Builds an egg model. Uses ServerStorage.Assets.Eggs.<BiomeId> when it exists (art pass), otherwise a placeholder
-- shell with a rarity-coloured crack band. Always has PrimaryPart "Shell" with a disabled-by-default ProximityPrompt "Prompt".
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)

local EggModel = {}

function EggModel.SetPhysics(egg, anchored)
	for _, p in egg:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = anchored and p == egg.PrimaryPart
			p.CanCollide = false
			p.CanTouch = false
			p.Massless = true
		end
	end
end

local function placeholder(biomeId, rarity)
	local size = EggConfig.Size
	local egg = Instance.new("Model")
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = size
	shell.Color = EggConfig.ShellColors[biomeId] or Color3.new(1, 1, 1)
	shell.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	shell.Parent = egg
	egg.PrimaryPart = shell

	local band = Instance.new("Part")
	band.Name = "Crack"
	band.Size = Vector3.new(size.X * 1.04, size.Y * 0.18, size.Z * 1.04)
	band.CFrame = shell.CFrame * CFrame.new(0, size.Y * 0.05, 0)
	band.Color = rarity.Color
	band.Material = rarity.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Parent = band
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shell
	weld.Part1 = band
	weld.Parent = band
	band.Parent = egg
	return egg
end

function EggModel.Build(biomeId, rarityId, eggId)
	local rarity = EggConfig.RarityById[rarityId]
	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Eggs") and assets.Eggs:FindFirstChild(biomeId)
	local egg = art and art:Clone() or placeholder(biomeId, rarity)
	egg.Name = "Egg"
	egg:SetAttribute("EggId", eggId or HttpService:GenerateGUID(false))
	egg:SetAttribute("BiomeId", biomeId)
	egg:SetAttribute("Rarity", rarityId)

	local shell = egg.PrimaryPart
	if rarity.Glow then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = shell
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = rarityId .. " Egg"
	prompt.HoldDuration = EggConfig.Pickup.HoldSeconds
	prompt.MaxActivationDistance = EggConfig.Pickup.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = shell

	EggModel.SetPhysics(egg, true)
	return egg
end

return EggModel
