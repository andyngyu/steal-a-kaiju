-- Nest spawns, rarity rolls, pickup, carry and dropping. Players drop a carried egg by clicking/tapping a spot
-- (Remotes.DropEgg, sent by StarterPlayerScripts.Gameplay.KaijuInput): inside their own pen it's placed and starts
-- incubating (HatchService), anywhere else it lands on the ground for anyone to grab.
-- An egg moves through states (model attribute "State"): Nest -> Carried -> (Ground -> Carried)* -> Pen.
-- A dropped egg in its biome's chase area is fetched by a guardian and dragged home: Ground -> Guardian (welded behind
-- it, still grabbable) -> Nest (ReturnToNest), unless someone grabs it first (GuardianService).
-- A nest egg remembers its slot (attribute NestSlot = the EggSpawn attachment's name) and that slot stays reserved
-- (no respawn into it) while the egg is out in the world, so a guardian puts it back exactly where it was taken from.
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
local night = false -- DayNightService: during the night reset the nests stay empty and nothing can be picked up
-- A new nest egg of at least this rarity (EggConfig.Rarities Order: 6 = Mythic, 7 = Secret) is announced to everyone
-- (GameEvent RareEggSpawned {Rarity, BiomeId, SizeTier}; KaijuUI RareSpawnController shows it at the top).
local SPAWN_ANNOUNCE_MIN_ORDER = 6

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
	new:SetAttribute("NestSlot", egg:GetAttribute("NestSlot"))
	new:SetAttribute("WeatherEgg", egg:GetAttribute("WeatherEgg"))
	EggModel.SetMutation(new, egg:GetAttribute("Mutation")) -- weather mutations stay with the egg
	egg:Destroy()
	return new
end

-- An egg a guardian dragged was part of the guardian's moving assembly, and moving that same instance from the server
-- afterwards doesn't reliably replicate (clients kept seeing it where it was let go, with a prompt the server then
-- rejected as too far). Like rebuild above: swap it for a fresh server-owned copy before putting it anywhere.
local function freshCopy(egg)
	local weld = egg.PrimaryPart and egg.PrimaryPart:FindFirstChild("GuardianWeld")
	if weld then
		weld:Destroy()
	end
	return rebuild(egg)
end

local function spawnInSlot(biomeId, slot)
	local egg = makeEgg(biomeId, rollRarity(biomeId), nil, EggModel.RollSize())
	egg:SetAttribute("State", "Nest")
	setPrompt(egg, true, "Steal")
	egg:PivotTo(CFrame.new(slot.attachment.WorldPosition + Vector3.new(0, egg.PrimaryPart.Size.Y / 2 - 0.4, 0)))
	egg.Parent = eggFolder
	slot.egg = egg
	local rarity = EggConfig.RarityById[egg:GetAttribute("Rarity")]
	if gameEvent and rarity and rarity.Order >= SPAWN_ANNOUNCE_MIN_ORDER then
		gameEvent:FireAllClients("RareEggSpawned", { Rarity = rarity.Id, BiomeId = biomeId, SizeTier = egg:GetAttribute("SizeTier") })
	end
end

-- Is the egg with this id still out in the world (carried, on the ground, or being dragged home by a guardian)?
local function eggOut(eggId)
	if not eggId then
		return false
	end
	for _, egg in carried do
		if egg:GetAttribute("EggId") == eggId then
			return true
		end
	end
	for _, egg in eggFolder:GetChildren() do
		local st = egg:GetAttribute("State")
		if egg:GetAttribute("EggId") == eggId and (st == "Ground" or st == "Guardian" or st == "Carried") then
			return true
		end
	end
	-- in a guardian's jaws / arms on its way home (the egg is inside the guardian model)
	local guardians = workspace.Runtime:FindFirstChild("Guardians")
	if guardians then
		for _, d in guardians:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("EggId") == eggId and d:GetAttribute("State") == "Guardian" then
				return true
			end
		end
	end
	return false
end

local function fillNest(biomeId)
	if night then
		return -- EndNight refills every nest as day breaks
	end
	local nest = nests[biomeId]
	local empty, count = {}, 0
	for _, slot in nest.slots do
		if slot.egg and slot.egg.Parent then
			count += 1
		else
			slot.egg = nil
			if slot.reserved and not eggOut(slot.reserved) then
				slot.reserved = nil
			end
			if not slot.reserved then
				table.insert(empty, slot)
			end
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
	if state ~= "Nest" and state ~= "Ground" and state ~= "Guardian" then
		return false
	end
	if night then
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
				-- remembered (and kept free) so a guardian can put it back in this exact spot
				slot.reserved = egg:GetAttribute("EggId")
				egg:SetAttribute("NestSlot", slot.attachment.Name)
			end
		end
		task.delay(EggConfig.Nest.RespawnSeconds, fillNest, biomeId)
	end

	local eggPos = egg.PrimaryPart.Position
	local guardianWeld = egg.PrimaryPart:FindFirstChild("GuardianWeld")
	if guardianWeld then
		guardianWeld:Destroy() -- snatched back off the guardian carrying it home
	end
	local fullScale = egg:GetAttribute("FullScale")
	if fullScale then
		egg:SetAttribute("FullScale", nil)
		egg:ScaleTo(fullScale) -- a guardian shrank it to fit its jaws / arms
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
	if state ~= "Nest" and GuardianService:InChaseArea(egg:GetAttribute("BiomeId"), eggPos) then
		pickedIn = egg:GetAttribute("BiomeId") -- a dropped egg brings back the guardian it was stolen from
	end
	player:SetAttribute("CarryingEgg", egg:GetAttribute("Rarity"))
	player:SetAttribute("CarryingFromBiome", pickedIn)
	applyWalkSpeed(player)
	gameEvent:FireClient(player, "EggPickedUp", { Rarity = egg:GetAttribute("Rarity"), BiomeId = egg:GetAttribute("BiomeId"), Size = egg:GetAttribute("Size"), SizeTier = egg:GetAttribute("SizeTier"), Mutation = egg:GetAttribute("Mutation") })
	log(player.Name, "picked up", egg:GetAttribute("Rarity"), "in", pickedIn or "safe zone", "dist", math.floor(dist))
	if pickedIn then
		GuardianService:OnEggTaken(pickedIn, player, state ~= "Nest" and egg or nil)
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
	GuardianService:OnEggDropped(egg, player) -- its guardian comes to take it home
	if player.Parent == Players then
		gameEvent:FireClient(player, "EggDropped", { Reason = reason })
	end
	log(player.Name, "dropped egg:", reason)

	local eggId = egg:GetAttribute("EggId")
	local droppedAt = egg:GetAttribute("DroppedAt")
	task.delay(EggConfig.Ground.DespawnSeconds, function()
		if egg.Parent == eggFolder and egg:GetAttribute("State") == "Ground" and egg:GetAttribute("EggId") == eggId and egg:GetAttribute("DroppedAt") == droppedAt then
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
-- (Luck's rarity boost now happens at hatch time - HatchService / Shared.Util.Luck - so here it only adds size rolls.)
local function applyLuck(player, biomeId, rarityId, size)
	local luckStat = player:GetAttribute("Luck")
	local luck = type(luckStat) == "number" and luckStat or luckOf(player)
	if luck <= 1 then
		return rarityId, size
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
		EggModel.SetMutation(fresh, egg:GetAttribute("Mutation"))
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

-- A guardian dragged a dropped egg home: it goes back into the exact slot it was taken from (kept free for it), or any
-- free slot if that's somehow taken (gone if the nest has none).
function EggService:ReturnToNest(egg)
	local nest = nests[egg:GetAttribute("BiomeId")]
	local eggId = egg:GetAttribute("EggId")
	local home = egg:GetAttribute("NestSlot")
	local slot
	local free = {}
	if nest then
		for _, s in nest.slots do
			if not (s.egg and s.egg.Parent) or s.egg == egg then
				s.egg = nil
				if s.attachment.Name == home then
					slot = s
				elseif not s.reserved or s.reserved == eggId or not eggOut(s.reserved) then
					table.insert(free, s)
				end
			end
		end
	end
	slot = slot or free[1] and free[rng:NextInteger(1, #free)]
	if not slot then
		egg:Destroy()
		return false
	end
	slot.reserved = nil
	local fresh = freshCopy(egg)
	fresh:PivotTo(CFrame.new(slot.attachment.WorldPosition + Vector3.new(0, fresh.PrimaryPart.Size.Y / 2 - 0.4, 0)))
	fresh:SetAttribute("State", "Nest")
	setPrompt(fresh, true, "Steal")
	fresh.Parent = eggFolder
	slot.egg = fresh
	log("egg back in the", fresh:GetAttribute("BiomeId"), "nest", slot.attachment.Name)
	return true
end

-- A guardian picks up a dropped egg to carry home: returns a fresh unanchored copy (State "Guardian", still "Grab"-able)
-- for GuardianService to weld into the guardian model. Fresh, and outside Runtime.Eggs, so neither the old instance's
-- replication nor the client egg animation (Gameplay.KaijuFX only animates eggs in Runtime.Eggs) gets in the way.
function EggService:TakeIntoGuardian(egg)
	local fresh = freshCopy(egg)
	EggModel.SetPhysics(fresh, false)
	fresh:SetAttribute("State", "Guardian")
	setPrompt(fresh, true, "Grab")
	return fresh
end

-- A guardian let go of the egg it was dragging (it went after someone instead): the egg stays on the ground there.
function EggService:LetGoFromGuardian(egg)
	local pos = egg.PrimaryPart.Position
	local fresh = freshCopy(egg)
	local y = groundY(pos, { fresh, workspace.Runtime })
	fresh:PivotTo(CFrame.new(pos.X, y + fresh.PrimaryPart.Size.Y / 2, pos.Z))
	fresh:SetAttribute("State", "Ground")
	setPrompt(fresh, true, "Grab")
	local stamp = workspace:GetServerTimeNow()
	fresh:SetAttribute("DroppedAt", stamp)
	fresh.Parent = eggFolder
	task.delay(EggConfig.Ground.DespawnSeconds, function()
		if fresh.Parent == eggFolder and fresh:GetAttribute("State") == "Ground" and fresh:GetAttribute("DroppedAt") == stamp then
			fresh:Destroy()
		end
	end)
	return fresh
end

-- Night falls (DayNightService): every egg out in the world is lost - carried ones (their players get GameEvent
-- EggLostNight), dropped ones and the nests' own. Eggs in pens are untouched. Guardians let go of theirs first
-- (GuardianService:ResetForNight).
function EggService:ResetForNight()
	night = true
	local holders = {}
	for player in carried do
		table.insert(holders, player)
	end
	for _, player in holders do
		local egg = carried[player]
		clearCarry(player)
		if egg then
			egg:Destroy()
		end
		if player.Parent == Players then
			gameEvent:FireClient(player, "EggLostNight", {})
		end
		log(player.Name, "lost their egg to the night")
	end
	for _, egg in eggFolder:GetChildren() do
		local st = egg:GetAttribute("State")
		if st == "Nest" or st == "Ground" or st == "Guardian" or st == "Carried" then
			egg:Destroy()
		end
	end
	for _, nest in nests do
		for _, slot in nest.slots do
			slot.egg = nil
			slot.reserved = nil
		end
	end
end

-- Day breaks: every nest gets a fresh set of eggs.
function EggService:EndNight()
	night = false
	for biomeId in nests do
		fillNest(biomeId)
	end
end

function EggService:GetCarried(player)
	return carried[player]
end

-- Every egg sitting in a nest right now: { { egg = model, biomeId = id, position = Vector3 } } (empty at night).
function EggService:GetNestEggs()
	local list = {}
	if night then
		return list
	end
	for biomeId, nest in nests do
		for _, slot in nest.slots do
			if slot.egg and slot.egg.Parent and slot.egg:GetAttribute("State") == "Nest" and slot.egg.PrimaryPart then
				table.insert(list, { egg = slot.egg, biomeId = biomeId, position = slot.egg.PrimaryPart.Position })
			end
		end
	end
	return list
end

function EggService:IsNight()
	return night
end

-- WeatherService: a nest / ground egg gets a mutation (an egg keeps the first one it gets). Returns true if it changed.
function EggService:MutateEgg(egg, mutation, weatherEgg)
	if not (egg and egg.Parent and egg.PrimaryPart) or egg:GetAttribute("Mutation") then
		return false
	end
	local st = egg:GetAttribute("State")
	if st ~= "Nest" and st ~= "Ground" then
		return false
	end
	if not EggModel.SetMutation(egg, mutation) then
		return false
	end
	if weatherEgg then
		egg:SetAttribute("WeatherEgg", true)
	end
	egg:SetAttribute("MutatedAt", workspace:GetServerTimeNow()) -- clients play a flash
	log(egg:GetAttribute("BiomeId"), egg:GetAttribute("Rarity"), "egg mutated:", mutation, weatherEgg and "(weather egg)" or "")
	return true
end

return EggService
