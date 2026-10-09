-- Builds an egg model at its rolled size. Uses ServerStorage.Assets.Eggs.<BiomeId> when it exists (art pass), otherwise
-- a placeholder shell with a rarity-coloured crack band. Always has PrimaryPart "Shell" with a ProximityPrompt "Prompt"
-- (disabled by default). Attributes: EggId, BiomeId, Rarity, Size (multiplier), SizeTier ("" | Big | Huge | Giant).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)

local EggModel = {}

local rng = Random.new()

function EggModel.RollSize()
	local total = 0
	for _, t in EggConfig.SizeTiers do
		total += t.Weight
	end
	local pick = rng:NextNumber() * total
	for _, t in EggConfig.SizeTiers do
		pick -= t.Weight
		if pick <= 0 then
			return math.floor(rng:NextNumber(t.Min, t.Max) * 100 + 0.5) / 100
		end
	end
	return 1
end

-- "Giant Rare Egg", "Common Egg"
function EggModel.Label(rarityId, size)
	local tier = EggConfig.SizeTierName(size or 1)
	return (tier ~= "" and tier .. " " or "") .. rarityId .. " Egg"
end

-- Weld offset (above the HumanoidRootPart) for carrying this egg overhead.
function EggModel.CarryOffset(egg)
	local h = egg.PrimaryPart.Size.Y
	return math.max(EggConfig.Carry.OverheadOffset, EggConfig.Carry.HeadClearance + h / 2)
end

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

local function placeholder(biomeId, rarity, scale)
	local size = EggConfig.Size * scale
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

function EggModel.Build(biomeId, rarityId, eggId, size)
	size = size or 1
	local rarity = EggConfig.RarityById[rarityId]
	local scale = rarity.EggScale * size
	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Eggs") and assets.Eggs:FindFirstChild(biomeId)
	local egg
	if art then
		egg = art:Clone()
		egg:ScaleTo(scale)
	else
		egg = placeholder(biomeId, rarity, scale)
	end
	egg.Name = "Egg"
	egg:SetAttribute("EggId", eggId or HttpService:GenerateGUID(false))
	egg:SetAttribute("BiomeId", biomeId)
	egg:SetAttribute("Rarity", rarityId)
	egg:SetAttribute("Size", size)
	egg:SetAttribute("SizeTier", EggConfig.SizeTierName(size))

	local shell = egg.PrimaryPart
	if rarity.Glow or size >= 1.85 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 10 * math.sqrt(scale)
		light.Brightness = 1.5
		light.Parent = shell
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = EggModel.Label(rarityId, size)
	prompt.HoldDuration = EggConfig.Pickup.HoldSeconds
	prompt.MaxActivationDistance = EggConfig.Pickup.PromptDistance + shell.Size.X / 2
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = shell

	-- clients wait until this many parts have arrived before animating the model (big models replicate over several frames)
	local parts = 0
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	egg:SetAttribute("PartCount", parts)

	EggModel.SetPhysics(egg, true)
	return egg
end

return EggModel
