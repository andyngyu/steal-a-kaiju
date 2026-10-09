-- Nest spawns, rarity rolls, pickup, carry, drop and delivery onto Nest Pads.
-- One egg model moves through states: Nest -> Carried -> (Ground -> Carried)* -> Pad. State lives in the model's "State" attribute.
-- Player attributes: CarryingEgg (rarity), CarryingFromBiome, StunnedUntil (workspace:GetServerTimeNow()), BaseWalkSpeed.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local EggConfig = require(Config.EggConfig)
local BiomeConfig = require(Config.BiomeConfig)
local MapConfig = require(Config.MapConfig)
local DevConfig = require(Config.DevConfig)

local BaseService = require(script.Parent.BaseService)
local GuardianService = require(script.Parent.GuardianService)

local EggService = {}

local rng = Random.new()
local gameEvent
local eggFolder
local nests = {} -- [biomeId] = { center = Part, slots = { [k] = { attachment, egg? } } }
local carried = {} -- [player] = egg model
local lastPickup = {} -- [player] = os.clock()
local fullWarned = {} -- [player] = true once BaseFull was sent for the current carry

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Egg]", ...)
	end
end

local function rollRarity(biomeId)
	local weights = EggConfig.Weights[biomeId]
	local total = 0
	for _, r in EggConfig.Rarities do
		total += weights[r.Id] or 0
	end
	local pick = rng:NextNumber() * total
	for _, r in EggConfig.Rarities do
		pick -= weights[r.Id] or 0
		if pick <= 0 then
			return r.Id
		end
	end
	return EggConfig.Rarities[1].Id
end

local function setPrompt(egg, enabled, action)
	local prompt = egg.PrimaryPart:FindFirstChild("Prompt")
	if prompt then
		prompt.Enabled = enabled
		if action then
			prompt.ActionText = action
		end
	end
end

local function setPhysics(egg, anchored)
	for _, p in egg:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = anchored and p == egg.PrimaryPart
			p.CanCollide = false
			p.CanTouch = false
			p.Massless = true
		end
	end
end

-- Placeholder egg: shell + rarity-coloured crack band. The art pass swaps this for ServerStorage.Assets.Eggs models.
local function makeEgg(biomeId, rarityId)
	local rarity = EggConfig.RarityById[rarityId]
	local size = EggConfig.Size
	local egg = Instance.new("Model")
	egg.Name = "Egg"
	egg:SetAttribute("EggId", HttpService:GenerateGUID(false))
	egg:SetAttribute("BiomeId", biomeId)
	egg:SetAttribute("Rarity", rarityId)

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
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player)
		EggService:TryPickup(player, egg)
	end)

	setPhysics(egg, true)
	return egg
end

-- A carried egg is part of the player's client-owned assembly, so moving that same instance from the server
-- doesn't reliably replicate. Swap it for a fresh server-owned copy with the same identity instead.
local function rebuild(egg)
	local new = makeEgg(egg:GetAttribute("BiomeId"), egg:GetAttribute("Rarity"))
	new:SetAttribute("EggId", egg:GetAttribute("EggId"))
	egg:Destroy()
	return new
end

local function spawnInSlot(biomeId, slot)
	local egg = makeEgg(biomeId, rollRarity(biomeId))
	egg:SetAttribute("State", "Nest")
	egg:PivotTo(CFrame.new(slot.attachment.WorldPosition + Vector3.new(0, EggConfig.Size.Y / 2 - 0.4, 0)))
	egg.Parent = eggFolder
	slot.egg = egg
	return egg
end

local function fillNest(biomeId)
	local nest = nests[biomeId]
	local empty, count = {}, 0
	for _, slot in nest.slots do
		if slot.egg then
			count += 1
		else
			table.insert(empty, slot)
		end
	end
	while count < EggConfig.Nest.EggsPerNest and #empty > 0 do
		local slot = table.remove(empty, rng:NextInteger(1, #empty))
		spawnInSlot(biomeId, slot)
		count += 1
	end
end

local function applyWalkSpeed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local base = player:GetAttribute("BaseWalkSpeed") or MapConfig.StartingWalkSpeed
	hum.WalkSpeed = carried[player] and base * EggConfig.Carry.SpeedMultiplier or base
end

local function clearCarry(player)
	carried[player] = nil
	fullWarned[player] = nil
	player:SetAttribute("CarryingEgg", nil)
	player:SetAttribute("CarryingFromBiome", nil)
	applyWalkSpeed(player)
end

local function groundY(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), params)
	return hit and hit.Position.Y or 0
end

function EggService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	eggFolder = Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = runtime

	local lane = workspace:WaitForChild("Map"):WaitForChild("Lane")
	for _, biome in BiomeConfig.List do
		local center = lane[biome.Id].NestSite.Center
		local slots = {}
		for _, a in center:GetChildren() do
			if a:IsA("Attachment") and a.Name:match("^EggSpawn") then
				table.insert(slots, { attachment = a })
			end
		end
		nests[biome.Id] = { center = center, slots = slots }
	end
end

function EggService:Start()
	for biomeId in nests do
		fillNest(biomeId)
	end

	local function onPlayer(player)
		if player:GetAttribute("BaseWalkSpeed") == nil then
			player:SetAttribute("BaseWalkSpeed", MapConfig.StartingWalkSpeed)
		end
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid")
			applyWalkSpeed(player)
			hum.Died:Connect(function()
				self:DropCarried(player, "Died")
			end)
		end)
		player.CharacterRemoving:Connect(function()
			self:DropCarried(player, "Died")
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:DropCarried(player, "Left")
		lastPickup[player] = nil
	end)

	-- Delivery: a carrier standing inside their own plot puts the egg on the first empty pad.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < EggConfig.DeliveryCheckInterval then
			return
		end
		acc = 0
		for player, egg in carried do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and BaseService:IsInOwnPlot(player, hrp.Position) then
				self:Deliver(player, egg)
			end
		end
	end)
end

function EggService:TryPickup(player, egg)
	local state = egg.Parent and egg:GetAttribute("State")
	if state ~= "Nest" and state ~= "Ground" then
		return false
	end
	if carried[player] then
		return false
	end
	local now = os.clock()
	if lastPickup[player] and now - lastPickup[player] < EggConfig.Pickup.CooldownSeconds then
		return false
	end
	if (player:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp and hum.Health > 0) then
		return false
	end
	local dist = (hrp.Position - egg.PrimaryPart.Position).Magnitude
	if dist > EggConfig.Pickup.MaxDistance then
		log(player.Name, "pickup rejected: too far", math.floor(dist))
		return false
	end
	lastPickup[player] = now

	-- free the nest slot and schedule a respawn
	if state == "Nest" then
		local biomeId = egg:GetAttribute("BiomeId")
		for _, slot in nests[biomeId].slots do
			if slot.egg == egg then
				slot.egg = nil
			end
		end
		task.delay(EggConfig.Nest.RespawnSeconds, fillNest, biomeId)
	end

	egg:SetAttribute("State", "Carried")
	setPrompt(egg, false)
	setPhysics(egg, false)
	egg:PivotTo(hrp.CFrame * CFrame.new(0, EggConfig.Carry.OverheadOffset, 0))
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = egg.PrimaryPart
	weld.C0 = CFrame.new(0, EggConfig.Carry.OverheadOffset, 0)
	weld.Parent = egg.PrimaryPart
	egg.Parent = char

	carried[player] = egg
	local pickedIn = GuardianService:BiomeAt(hrp.Position)
	player:SetAttribute("CarryingEgg", egg:GetAttribute("Rarity"))
	player:SetAttribute("CarryingFromBiome", pickedIn)
	applyWalkSpeed(player)
	gameEvent:FireClient(player, "EggPickedUp", { Rarity = egg:GetAttribute("Rarity"), BiomeId = egg:GetAttribute("BiomeId") })
	log(player.Name, "picked up", egg:GetAttribute("Rarity"), "in", pickedIn or "safe zone", "dist", math.floor(dist))
	if pickedIn then
		GuardianService:OnEggTaken(pickedIn, player)
	end
	return true
end

function EggService:DropCarried(player, reason)
	local egg = carried[player]
	if not egg then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pos = hrp and hrp.Position or egg.PrimaryPart.Position
	clearCarry(player)
	egg = rebuild(egg)
	if reason == "Caught" then
		player:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + EggConfig.StunSecondsAfterCatch)
	end
	local ignore = { egg, workspace.Runtime }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local y = groundY(pos, ignore)
	egg:PivotTo(CFrame.new(pos.X, y + EggConfig.Size.Y / 2, pos.Z))
	egg.Parent = eggFolder
	egg:SetAttribute("State", "Ground")
	setPrompt(egg, true, "Grab")
	if player.Parent == Players then
		gameEvent:FireClient(player, "EggDropped", { Reason = reason })
	end
	log(player.Name, "dropped egg:", reason)

	local eggId = egg:GetAttribute("EggId")
	task.delay(EggConfig.Ground.DespawnSeconds, function()
		if egg.Parent == eggFolder and egg:GetAttribute("State") == "Ground" and egg:GetAttribute("EggId") == eggId then
			egg:Destroy()
		end
	end)
end

function EggService:Deliver(player, egg)
	local padIndex, pad = BaseService:FindEmptyPad(player)
	if not padIndex then
		if not fullWarned[player] then
			fullWarned[player] = true
			gameEvent:FireClient(player, "BaseFull", {})
		end
		return
	end
	clearCarry(player)
	egg = rebuild(egg)
	egg:PivotTo(CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2 + EggConfig.Size.Y / 2, 0)))
	egg:SetAttribute("State", "Pad")
	egg:SetAttribute("OwnerUserId", player.UserId)
	egg:SetAttribute("PadIndex", padIndex)
	egg:SetAttribute("PlacedAt", workspace:GetServerTimeNow())
	setPrompt(egg, false)
	egg.Parent = eggFolder
	BaseService:SetPadEgg(player, padIndex, egg)
	gameEvent:FireClient(player, "EggDelivered", { Rarity = egg:GetAttribute("Rarity"), PadIndex = padIndex })
	log(player.Name, "delivered", egg:GetAttribute("Rarity"), "to pad", padIndex)
end

function EggService:GetCarried(player)
	return carried[player]
end

return EggService
