-- Builds an egg model at its rolled size. Art: ServerStorage.Assets.Eggs.<BiomeId>_<Design> (modelled in Blender, imported
-- by Tools.BlenderEggImporter: invisible "Shell" hit box + welded voxel bricks). Each biome has five designs (DESIGN below:
-- Uncommon shares the Common egg, Mythic the Legendary egg); the front gem (parts Gem / GemLight / GemCore) is tinted with
-- the egg's real rarity, rainbow for Secret. Falls back to Assets.Eggs.<BiomeId> (older single-design art, parts named
-- "Band" tinted with the rarity colour), then to a placeholder shell. Always has PrimaryPart "Shell" with a
-- ProximityPrompt "Prompt" (disabled by default).
-- Attributes: EggId, BiomeId, Rarity, Size (multiplier), SizeTier ("" | Big | Huge | Giant).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local MutationVisuals = require(ReplicatedStorage.Shared.Util.MutationVisuals)

local EggModel = {}

local rng = Random.new()

-- Neon washes light colours toward pink (the Epic purple and the Mythic pink both rendered hot pink), so glowing bands
-- use a deeper shade that still reads as the rarity's hue.
local NEON_TINT = {
	Epic = Color3.fromHex("6A1FE0"),
	Mythic = Color3.fromHex("F0306A"),
}

local function bandColor(rarity)
	return rarity.Glow and NEON_TINT[rarity.Id] or rarity.Color
end

-- which of a biome's five egg designs each rarity uses
local DESIGN = {
	Common = "Common",
	Uncommon = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Legendary",
	Secret = "Secret",
}

-- front gem colour per rarity (Neon); GemLight is a paler shade, GemCore stays white
local GEM_COLOR = {
	Common = Color3.fromHex("C4CCD4"), -- gray (designer's egg descriptions)
	Uncommon = Color3.fromHex("3FD94A"),
	Rare = Color3.fromHex("2E9BFF"),
	Epic = Color3.fromHex("9A3CF0"),
	Legendary = Color3.fromHex("FFC42E"),
	Mythic = Color3.fromHex("F0306A"),
}

local function tintGem(egg, rarityId)
	local gems = {}
	local sum = Vector3.zero
	for _, p in egg:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Gem" or p.Name == "GemLight" or p.Name == "GemCore") then
			table.insert(gems, p)
			sum += p.Position
		end
	end
	if #gems == 0 then
		return
	end
	local centre = sum / #gems
	local cf = egg.PrimaryPart.CFrame
	local base = GEM_COLOR[rarityId] or Color3.new(1, 1, 1)
	for _, p in gems do
		p.Material = Enum.Material.Neon
		if p.Name == "GemCore" then
			p.Color = Color3.new(1, 1, 1)
		elseif rarityId == "Secret" then
			-- rainbow around the gem's centre
			local o = cf:VectorToObjectSpace(p.Position - centre)
			local hue = (math.atan2(o.Y, o.X) / (math.pi * 2)) % 1
			p.Color = Color3.fromHSV(hue, p.Name == "GemLight" and 0.45 or 0.8, 1)
		else
			p.Color = p.Name == "GemLight" and base:Lerp(Color3.new(1, 1, 1), 0.45) or base
		end
	end
end

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

-- "Giant Rare Egg", "Common Egg", "Shocked Epic Egg" (with a weather mutation)
function EggModel.Label(rarityId, size, mutation)
	local tier = EggConfig.SizeTierName(size or 1)
	return MutationConfig.Prefix(mutation) .. (tier ~= "" and tier .. " " or "") .. rarityId .. " Egg"
end

-- Gives an egg a weather mutation (Shared.Config.MutationConfig): attribute Mutation, recoloured shell, glowing FX,
-- a floating "⚡ Shocked x2" tag, and the prompt's name. nil / unknown = no change. Safe to call again.
function EggModel.SetMutation(egg, mutation)
	if not (mutation and MutationConfig.ById[mutation] and egg.PrimaryPart) then
		return false
	end
	if egg:GetAttribute("Mutation") == mutation and egg.PrimaryPart:FindFirstChild("MutationMain") then
		return true
	end
	egg:SetAttribute("Mutation", mutation)
	MutationVisuals.Recolor(egg, mutation)
	local shell = egg.PrimaryPart
	local scale = shell.Size.Y / EggConfig.Size.Y
	MutationVisuals.AddFX(shell, mutation, math.max(1, scale))
	for _, d in shell:GetChildren() do
		if d:IsA("PointLight") and d.Name ~= "MutationLight" then
			d:Destroy()
		end
	end
	MutationVisuals.Tag(shell, mutation, shell.Size.Y / 2 + 0.9, math.clamp(scale * 0.8, 0.8, 1.5))
	local prompt = shell:FindFirstChild("Prompt")
	if prompt then
		prompt.ObjectText = EggModel.Label(egg:GetAttribute("Rarity"), egg:GetAttribute("Size"), mutation)
	end
	return true
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
	band.Color = bandColor(rarity)
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
	local eggArt = assets and assets:FindFirstChild("Eggs")
	local designed = eggArt and eggArt:FindFirstChild(biomeId .. "_" .. (DESIGN[rarityId] or "Common"))
	local art = not designed and eggArt and eggArt:FindFirstChild(biomeId)
	local egg
	if designed then
		egg = designed:Clone()
		egg:ScaleTo(scale)
		tintGem(egg, rarityId)
	elseif art then
		egg = art:Clone()
		egg:ScaleTo(scale)
		local centre = egg.PrimaryPart.Position
		for _, p in egg:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "Band" then
				if rarityId == "Secret" then
					-- rainbow: hue follows the angle around the egg
					local offset = p.Position - centre
					p.Color = Color3.fromHSV((math.atan2(offset.Z, offset.X) / (math.pi * 2)) % 1, 0.75, 1)
				else
					p.Color = bandColor(rarity)
				end
				p.Material = rarity.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
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
