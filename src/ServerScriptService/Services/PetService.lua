-- Pets: equipped kaiju live in the pen and earn; unequipped ones wait in the player's inventory, out of the world,
-- earning nothing (so they can't be stolen, fed or sold until equipped again). How many can be equipped is the pen's
-- capacity (BaseService: 6 at the start, more with pen upgrades and perks) - eggs in the pen take room too.
-- Saved: data.Inventory = { [kaijuId] = kaiju entry } (the same entry shape as data.Pen.Items, moved back and forth).
-- Every other system only ever sees data.Pen.Items, so to them an unequipped kaiju simply doesn't exist.
-- Remotes.PetAction (RemoteFunction): ("Equip", id) | ("Unequip", id) | ("EquipBest") -> ok, message
-- Player attribute PetInventory = JSON list of { Id, Species, Rarity, Size, SizeTier, Level, CashPerSecond, Variant? }.
-- A pen that ends up over capacity (a gifted egg hatching in a full pen, a perk running out) sends its newest kaiju
-- to the inventory a few seconds later, so the hatch reveal still finds the model.
-- UI: StarterGui.KaijuUI.Controllers.KaijuController (the Pets panel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local HatchService = require(script.Parent.HatchService)
local EconomyService = require(script.Parent.EconomyService)

local PetService = {}

local OVERFLOW_DELAY = 6 -- seconds before an over-capacity kaiju is sent to the inventory
local lastAction = {} -- [player] = os.clock()
local overflowPending = {} -- [player] = true

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Pets]", ...)
	end
end

local function inventoryOf(player)
	local data = DataService:Get(player)
	if not data then
		return nil, nil
	end
	data.Inventory = data.Inventory or {}
	return data.Inventory, data
end

local function sizeTier(size)
	local ok, name = pcall(EggConfig.SizeTierName, size)
	return ok and name or ""
end

local function publish(player)
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	local list = {}
	for id, entry in inv do
		table.insert(list, {
			Id = id,
			Species = entry.Species,
			Rarity = entry.Rarity,
			Size = entry.Size or 1,
			SizeTier = sizeTier(entry.Size or 1),
			Level = entry.Level or 1,
			CashPerSecond = KaijuStats.EntryCashPerSecond(entry),
			Variant = entry.Variant, -- "Golden" = the group reward kaiju
			Mutation = entry.Mutation, -- weather mutation (Shared.Config.MutationConfig)
		})
	end
	player:SetAttribute("PetInventory", HttpService:JSONEncode(list))
end

-- Pen kaiju that can be moved right now (not being carried off or grabbed by a thief).
local function movable(entry, model)
	return entry.Kind == "Kaiju" and not entry.StolenBy and not (model and model:GetAttribute("StealBy"))
end

local function unequip(player, id)
	local inv = inventoryOf(player)
	local entry, model = BaseService:GetItem(player, id)
	if not (inv and entry and entry.Kind == "Kaiju") then
		return false, "That kaiju isn't equipped."
	end
	if not movable(entry, model) then
		return false, "That kaiju is being stolen!"
	end
	BaseService:RemoveItem(player, id)
	inv[id] = entry
	return true
end

local function equip(player, id)
	local inv = inventoryOf(player)
	local entry = inv and inv[id]
	if not entry then
		return false, "That kaiju isn't in your inventory."
	end
	if not BaseService:GetPlot(player) then
		return false, "Your base isn't ready yet."
	end
	if not BaseService:HasRoom(player) then
		return false, "Your pen is full! Unequip one or upgrade your pen."
	end
	inv[id] = nil
	if not HatchService:SpawnItem(player, id, entry) then
		inv[id] = entry
		return false, "Couldn't equip that kaiju."
	end
	return true
end

-- The best earners fill the pen (as much of it as the eggs leave free); everything else goes to the inventory.
local function equipBest(player)
	local inv = inventoryOf(player)
	if not (inv and BaseService:GetPlot(player)) then
		return false, "Your base isn't ready yet."
	end
	local slots = BaseService:GetCapacity(player)
	local pool = {}
	BaseService:ForEachItem(player, function(id, entry, model)
		if entry.Kind ~= "Kaiju" or not movable(entry, model) then
			slots -= 1 -- eggs and kaiju being stolen keep their place
		else
			table.insert(pool, { id = id, cps = KaijuStats.EntryCashPerSecond(entry), equipped = true })
		end
	end)
	for id, entry in inv do
		table.insert(pool, { id = id, cps = KaijuStats.EntryCashPerSecond(entry), equipped = false })
	end
	table.sort(pool, function(a, b)
		if a.cps ~= b.cps then
			return a.cps > b.cps
		end
		return a.equipped and not b.equipped -- ties: keep what's already out
	end)
	local changed = 0
	for i, p in pool do
		if i > slots and p.equipped then
			if unequip(player, p.id) then
				changed += 1
			end
		end
	end
	for i, p in pool do
		if i <= slots and not p.equipped then
			if equip(player, p.id) then
				changed += 1
			end
		end
	end
	return true, changed > 0 and "Equipped your best kaiju!" or "Your best kaiju are already equipped."
end

local function after(player)
	publish(player)
	EconomyService:Publish(player)
	DataService:Save(player)
end

-- Over capacity: the newest kaiju (latest HatchedAt) goes to the inventory.
local function checkOverflow(player)
	if overflowPending[player] then
		return
	end
	local count, cap = player:GetAttribute("PenCount") or 0, player:GetAttribute("PenCapacity") or math.huge
	if count <= cap then
		return
	end
	overflowPending[player] = true
	task.delay(OVERFLOW_DELAY, function()
		overflowPending[player] = nil
		if player.Parent ~= Players then
			return
		end
		local over = (player:GetAttribute("PenCount") or 0) - BaseService:GetCapacity(player)
		local moved = 0
		while over > 0 do
			local newestId, newestAt
			BaseService:ForEachItem(player, function(id, entry, model)
				if movable(entry, model) and (not newestAt or (entry.HatchedAt or 0) > newestAt) then
					newestId, newestAt = id, entry.HatchedAt or 0
				end
			end)
			if not (newestId and unequip(player, newestId)) then
				break
			end
			over -= 1
			moved += 1
		end
		if moved > 0 then
			after(player)
			local gameEvent = ReplicatedStorage.Remotes:FindFirstChild("GameEvent")
			if gameEvent then
				gameEvent:FireClient(player, "PetsFull", { Count = moved })
			end
			log(player.Name, "pen over capacity:", moved, "kaiju sent to the inventory")
		end
	end)
end

local function onAction(player, action, id)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.25 then
		return false, ""
	end
	lastAction[player] = now
	local ok, msg
	if action == "Equip" and type(id) == "string" then
		ok, msg = equip(player, id)
	elseif action == "Unequip" and type(id) == "string" then
		ok, msg = unequip(player, id)
	elseif action == "EquipBest" then
		ok, msg = equipBest(player)
	else
		return false, ""
	end
	if ok then
		after(player)
		log(player.Name, action, id or "")
	end
	return ok == true, msg or ""
end

function PetService:Init()
	local remote = ReplicatedStorage.Remotes:FindFirstChild("PetAction") or Instance.new("RemoteFunction")
	remote.Name = "PetAction"
	remote.OnServerInvoke = onAction
	remote.Parent = ReplicatedStorage.Remotes
end

function PetService:Start()
	DataService:OnLoaded(function(player, data)
		data.Inventory = data.Inventory or {}
		for id, entry in data.Inventory do
			if not KaijuConfig[entry.Species] then
				warn("[PetService] dropping unknown species", entry.Species)
				data.Inventory[id] = nil
			end
		end
		publish(player)
		player:GetAttributeChangedSignal("PenCount"):Connect(function()
			checkOverflow(player)
		end)
		player:GetAttributeChangedSignal("PenCapacity"):Connect(function()
			checkOverflow(player)
		end)
		task.delay(3, checkOverflow, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		overflowPending[player] = nil
	end)
end

-- Puts a kaiju entry straight into the player's inventory (rewards, admin tools). Returns true.
function PetService:AddToInventory(player, id, entry)
	local inv = inventoryOf(player)
	if not inv then
		return false
	end
	inv[id] = entry
	after(player)
	return true
end

return PetService
