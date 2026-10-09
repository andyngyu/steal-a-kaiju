-- Nest spawns, rarity rolls, pickup, carry and dropping. Players drop a carried egg by clicking/tapping a spot
-- (Remotes.DropEgg, sent by StarterPlayerScripts.Gameplay.KaijuInput): inside their own pen it's placed and starts
-- incubating (HatchService), anywhere else it lands on the ground for anyone to grab.
-- An egg moves through states (model attribute "State"): Nest -> Carried -> (Ground -> Carried)* -> Pen.
-- Each nest egg rolls a Size (EggConfig.SizeTiers) that stays with it through carry/drop/pen and becomes the kaiju's size.
-- Carried eggs get attribute CarryOffset (weld height) so client FX can bob them at the right height.
-- Carried eggs are never saved: leaving mid-carry drops the egg in the world, so nothing can be duplicated.
-- Egg luck perk (EggLuckMultiplier = the effective multiplier right now, EggLuckUntil = server time it ends or 0/nil for
-- no end; both set by GamePassService; EggConfig.Luck): applied when the egg lands in the pen; an upgrade fires GameEvent EggLucky {FromRarity, ToRarity, FromSize, ToSize, ItemId}.
-- Player attributes: CarryingEgg (rarity), CarryingFromBiome, StunnedUntil (server time), BaseWalkSpeed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local EggConfig = require(Config.EggConfig)
local BaseConfig = require(Config.BaseConfig)
local BiomeConfig = require(Config.BiomeConfig)
local MapConfig = require(Config.MapConfig)
local DevConfig = require(Config.DevConfig)
local StealConfig = require(Config.StealConfig)

local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)

local BaseService = require(script.Parent.BaseService)
local GuardianService = require(script.Parent.GuardianService)
local HatchService = require(script.Parent.HatchService)

local EggService = {}

local rng = Random.new()
local gameEvent
local eggFolder
local nests = {} -- [biomeId] = { slots = { { attachment, egg? } } }
local carried = {} -- [player] = egg model
local lastPickup = {} -- [player] = os.clock()
local lastDrop = {} -- [player] = os.clock()

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

-- World egg (nest/ground) with its prompt wired to pickup.
local function makeEgg(biomeId, rarityId, eggId, size)
	local egg = EggModel.Build(biomeId, rarityId, eggId, size)
	egg.PrimaryPart.Prompt.Triggered:Connect(function(player)
		EggService:TryPickup(player, egg)
	end)
	return egg
end

-- A carried egg is part of the player's client-owned assembly, so moving that same instance from the server
-- doesn't reliably replicate. Swap it for a fresh server-owned copy with the same identity instead.
local function rebuild(egg)
	local new = makeEgg(egg:GetAttribute("BiomeId"), egg:GetAttribute("Rarity"), egg:GetAttribute("EggId"), egg:GetAttribute("Size"))
	egg:Destroy()
	return new
end

local function spawnInSlot(biomeId, slot)
	local egg = makeEgg(biomeId, rollRarity(biomeId), nil, EggModel.RollSize())
	egg:SetAttribute("State", "Nest")
	setPrompt(egg, true, "Steal")
	egg:PivotTo(CFrame.new(slot.attachment.WorldPosition + Vector3.new(0, egg.PrimaryPart.Size.Y / 2 - 0.4, 0)))
	egg.Parent = eggFolder
	slot.egg = egg
end

local function fillNest(biomeId)
	local nest = nests[biomeId]
	local empty, count = {}, 0
	for _, slot in nest.slots do
		if slot.egg and slot.egg.Parent then
			count += 1
		else
			slot.egg = nil
			table.insert(empty, slot)
		end
	end
	while count < EggConfig.Nest.EggsPerNest and #empty > 0 do
		spawnInSlot(biomeId, table.remove(empty, rng:NextInteger(1, #empty)))
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
	if carried[player] then
		base *= EggConfig.Carry.SpeedMultiplier
	elseif player:GetAttribute("CarryingStolen") then -- StealService: running home with stolen goods
		base *= StealConfig.CarrySpeedMultiplier
	elseif player:GetAttribute("Stealing") then -- StealService: holding a steal
		base *= StealConfig.HoldSpeedMultiplier
	end
	hum.WalkSpeed = base
end

local function clearCarry(player)
	carried[player] = nil
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
	eggFolder = runtime:FindFirstChild("Eggs") or Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = runtime

	local lane = workspace:WaitForChild("Map"):WaitForChild("Lane")
	for _, biome in BiomeConfig.List do
		local slots = {}
		for _, a in lane[biome.Id].NestSite.Center:GetChildren() do
			if a:IsA("Attachment") and a.Name:match("^EggSpawn") then
				table.insert(slots, { attachment = a })
			end
		end
		nests[biome.Id] = { slots = slots }
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
		-- SpeedService changes BaseWalkSpeed (training, upgrades); re-apply with the carry slowdown
		player:GetAttributeChangedSignal("BaseWalkSpeed"):Connect(function()
			applyWalkSpeed(player)
		end)
		player:GetAttributeChangedSignal("CarryingStolen"):Connect(function()
			applyWalkSpeed(player)
		end)
		player:GetAttributeChangedSignal("Stealing"):Connect(function()
			applyWalkSpeed(player)
		end)
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
		lastDrop[player] = nil
	end)

	ReplicatedStorage.Remotes.DropEgg.OnServerEvent:Connect(function(player, target)
		self:TryDropAt(player, target)
	end)
end

function EggService:TryPickup(player, egg)
	local state = egg.Parent and egg:GetAttribute("State")
	if state ~= "Nest" and state ~= "Ground" then
		return false
	end
	if carried[player] or player:GetAttribute("CarryingStolen") then
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
	-- measured to the egg's surface so giant eggs aren't harder to grab
	local dist = (hrp.Position - egg.PrimaryPart.Position).Magnitude - egg.PrimaryPart.Size.X / 2
	if dist > EggConfig.Pickup.MaxDistance then
		log(player.Name, "pickup rejected: too far", math.floor(dist))
		return false
	end
	lastPickup[player] = now

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
	EggModel.SetPhysics(egg, false)
	local offset = EggModel.CarryOffset(egg)
	egg:SetAttribute("CarryOffset", offset)
	egg:PivotTo(hrp.CFrame * CFrame.new(0, offset, 0))
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = egg.PrimaryPart
	weld.C0 = CFrame.new(0, offset, 0)
	weld.Parent = egg.PrimaryPart
	egg.Parent = char

	carried[player] = egg
	local pickedIn = GuardianService:BiomeAt(hrp.Position)
	player:SetAttribute("CarryingEgg", egg:GetAttribute("Rarity"))
	player:SetAttribute("CarryingFromBiome", pickedIn)
	applyWalkSpeed(player)
	gameEvent:FireClient(player, "EggPickedUp", { Rarity = egg:GetAttribute("Rarity"), BiomeId = egg:GetAttribute("BiomeId"), Size = egg:GetAttribute("Size"), SizeTier = egg:GetAttribute("SizeTier") })
	log(player.Name, "picked up", egg:GetAttribute("Rarity"), "in", pickedIn or "safe zone", "dist", math.floor(dist))
	if pickedIn then
		GuardianService:OnEggTaken(pickedIn, player)
	end
	return true
end

-- Drops the carried egg on the ground at `at` (defaults to the player's feet). Reasons: Dropped, Caught, Died, Left.
function EggService:DropCarried(player, reason, at)
	local egg = carried[player]
	if not egg then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local fromPos = egg.PrimaryPart.Position
	local pos = at or (hrp and hrp.Position) or fromPos
	clearCarry(player)
	egg = rebuild(egg)
	egg:SetAttribute("DropFrom", fromPos)
	egg:SetAttribute("DroppedAt", workspace:GetServerTimeNow())
	if reason == "Caught" then
		player:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + EggConfig.StunSecondsAfterCatch)
	end
	local ignore = { egg, workspace.Runtime }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local y = groundY(pos, ignore)
	egg:PivotTo(CFrame.new(pos.X, y + egg.PrimaryPart.Size.Y / 2, pos.Z))
	egg:SetAttribute("State", "Ground")
	setPrompt(egg, true, "Grab")
	egg.Parent = eggFolder
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

local function validTarget(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Z) < 1e5
end

-- Active egg luck multiplier for a player (1 = none). EggLuckUntil 0/nil means it doesn't run out (VIP).
local function luckOf(player)
	local untilTime = player:GetAttribute("EggLuckUntil")
	local mult = player:GetAttribute("EggLuckMultiplier")
	local running = type(untilTime) ~= "number" or untilTime <= 0 or workspace:GetServerTimeNow() < untilTime
	if type(mult) == "number" and mult > 1 and running then
		return mult
	end
	return 1
end

-- A lucky player's egg can grow as it lands in their pen. Returns rarity, size (unchanged without luck).
local function applyLuck(player, biomeId, rarityId, size)
	local luck = luckOf(player)
	if luck <= 1 then
		return rarityId, size
	end
	local L = EggConfig.Luck
	local nextRarity = EggConfig.Rarities[EggConfig.RarityById[rarityId].Order + 1]
	local weights = EggConfig.Weights[biomeId] or {}
	if nextRarity and nextRarity.Id ~= "Secret" and (weights[nextRarity.Id] or 0) > 0 then
		if rng:NextNumber() < math.min(L.MaxUpgradeChance, L.UpgradeChancePerLuck * (luck - 1)) then
			rarityId = nextRarity.Id
		end
	end
	for _ = 1, math.max(0, math.floor(luck - 1 + 0.5)) do
		size = math.max(size, EggModel.RollSize())
	end
	return rarityId, size
end

-- Client asked to drop the carried egg at `target` (a world point under the cursor/tap).
function EggService:TryDropAt(player, target)
	local egg = carried[player]
	if not egg or not validTarget(target) then
		return
	end
	local now = os.clock()
	if lastDrop[player] and now - lastDrop[player] < BaseConfig.Drop.CooldownSeconds then
		return
	end
	lastDrop[player] = now
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	-- clicks further than MaxDistance are pulled in towards the player
	local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
	if flat.Magnitude > BaseConfig.Drop.MaxDistance then
		flat = flat.Unit * BaseConfig.Drop.MaxDistance
	end
	local spot = Vector3.new(hrp.Position.X + flat.X, 0, hrp.Position.Z + flat.Z)

	if BaseService:IsInOwnPen(player, spot, 0) then
		local biomeId = egg:GetAttribute("BiomeId")
		local fromRarity, fromSize = egg:GetAttribute("Rarity"), egg:GetAttribute("Size") or 1
		local rarityId, size = fromRarity, fromSize
		local x, d
		if BaseService:HasRoom(player) then
			rarityId, size = applyLuck(player, biomeId, fromRarity, fromSize)
			x, d = BaseService:ToPenLocal(player, spot)
			x, d = BaseService:FindFreeSpot(player, x, d, size, rarityId)
		end
		if not x then
			gameEvent:FireClient(player, "PenFull", {})
			return
		end
		local fromPos = egg.PrimaryPart.Position
		clearCarry(player)
		local fresh = EggModel.Build(biomeId, rarityId, egg:GetAttribute("EggId"), size)
		egg:Destroy()
		if HatchService:PlaceEgg(player, fresh, x, d, fromPos) then
			gameEvent:FireClient(player, "EggPlaced", { Rarity = rarityId })
			if rarityId ~= fromRarity or size ~= fromSize then
				gameEvent:FireClient(player, "EggLucky", {
					ItemId = fresh:GetAttribute("EggId"),
					FromRarity = fromRarity,
					ToRarity = rarityId,
					FromSize = fromSize,
					ToSize = size,
				})
			end
			log(player.Name, "placed", rarityId, "in pen", rarityId ~= fromRarity and ("(lucky from " .. fromRarity .. ")") or "")
		end
	else
		self:DropCarried(player, "Dropped", spot)
	end
end

function EggService:GetCarried(player)
	return carried[player]
end

return EggService
