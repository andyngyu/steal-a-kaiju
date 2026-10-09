-- Robux store (Shared.Config.StoreConfig): game pass perks and developer product receipts.
-- Game passes: ownership is checked on join (UserOwnsGamePassAsync, remembered in data.Store.Passes for when the API is
--   down) and on PromptGamePassPurchaseFinished. Perks become player attributes that other services read:
--     CashMultiplier (EconomyService), BonusPenCapacity (BaseService), VIP (StoreFX chat tag),
--     EggLuckMultiplier + EggLuckUntil (EggService; the multiplier is always the one in effect now = VIP x timed boost,
--       Until = end of the timed Luck Bundle in server time, 0 = no end), OwnedPasses ("DoubleCash,VIP"),
--     then PerksLoaded = true, once (EconomyService pays the offline CashMultiplier extra when it arrives).
-- Developer products: this is the game's only MarketplaceService.ProcessReceipt. It routes StoreConfig bundles, trails
--   with a TrailConfig ProductId (TrailService:Grant) and StoreConfig.Upgrades (BaseService / TreadmillService
--   :GrantUpgrade). The receipt id goes into data.Store.Purchases in the same save as the grant (DataService:SaveNow),
--   so every purchase is granted exactly once.
-- Product / pass IDs: StoreConfig when set, otherwise the ones the UI prompts (StarterGui.KaijuUI.UIConfig).
-- GameEvent StorePurchased {ItemId, Kind, DisplayName} after every grant.
-- Studio only (DevConfig.AdminCommands), command bar:
--   game.ServerStorage.DevHooks.StoreGrant:Invoke(userId, "VIP", true|false)   -- pass on/off for this session
--   game.ServerStorage.DevHooks.StoreReceipt:Invoke(userId, "StarterBundle" | "LuckBundle" | "Pen" | "Treadmill" | trailId,
--     purchaseId?)   -- runs the full receipt path (same purchaseId twice = granted once) -> decision name
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local Config = ReplicatedStorage.Shared.Config
local StoreConfig = require(Config.StoreConfig)
local TrailConfig = require(Config.TrailConfig)
local BaseConfig = require(Config.BaseConfig)
local TreadmillConfig = require(Config.TreadmillConfig)
local DevConfig = require(Config.DevConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local HatchService = require(script.Parent.HatchService)
local BaseService = require(script.Parent.BaseService)
local TreadmillService = require(script.Parent.TreadmillService)
local TrailService = require(script.Parent.TrailService)

local GamePassService = {}

local Decision = Enum.ProductPurchaseDecision
local MAX_RECEIPTS = 100 -- receipt ids kept per player (newest)

local gameEvent
local passIdOf = {} -- [itemId] = game pass id (0 = not set up)
local passItemById = {} -- [gamePassId] = item
local products = {} -- [productId] = product
local owned = {} -- [player] = { [itemId] = true }
local luckEndsAt = {} -- [player] = os.time() the timed boost ends
local granting = {} -- [purchaseId] = true while a grant runs

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Store]", ...)
	end
end

local function storeOf(data)
	data.Store = data.Store or {}
	local store = data.Store
	store.Purchases = store.Purchases or {}
	store.Passes = store.Passes or {}
	store.LuckUntil = store.LuckUntil or 0
	store.LuckMultiplier = store.LuckMultiplier or 1
	return store
end

-- The UI's copy of the IDs (UIConfig.StoreItems / UpgradeRobux), so they only have to be typed in once.
local function uiConfig()
	local ok, cfg = pcall(function()
		return require(StarterGui:WaitForChild("KaijuUI", 5):WaitForChild("UIConfig", 5))
	end)
	return ok and type(cfg) == "table" and cfg or {}
end

local function pick(own, fallback)
	if type(own) == "number" and own > 0 then
		return own
	end
	return type(fallback) == "number" and fallback > 0 and fallback or 0
end

local function fire(player, itemId, kind, displayName)
	gameEvent:FireClient(player, "StorePurchased", { ItemId = itemId, Kind = kind, DisplayName = displayName })
end

-- Perk attributes from owned passes + the timed luck boost.
local function refreshPerks(player)
	local data = DataService:Get(player)
	local cash, pen, vip, luck = 1, 0, false, 1
	local names = {}
	for _, item in StoreConfig.Items do
		if owned[player] and owned[player][item.Id] and item.Perks then
			cash *= item.Perks.CashMultiplier or 1
			pen += item.Perks.BonusPenCapacity or 0
			vip = vip or item.Perks.VIP == true
			luck *= item.Perks.EggLuckMultiplier or 1
			table.insert(names, item.Id)
		end
	end
	local luckUntil = 0
	luckEndsAt[player] = nil
	if data then
		local store = storeOf(data)
		if store.LuckUntil > os.time() then
			luck *= store.LuckMultiplier
			luckUntil = store.LuckUntil
			luckEndsAt[player] = store.LuckUntil
		end
	end
	player:SetAttribute("CashMultiplier", cash)
	player:SetAttribute("BonusPenCapacity", pen)
	player:SetAttribute("VIP", vip)
	player:SetAttribute("EggLuckMultiplier", luck)
	player:SetAttribute("EggLuckUntil", luckUntil)
	player:SetAttribute("OwnedPasses", table.concat(names, ","))
end

-- true / false, or nil when Roblox couldn't be asked.
local function ownsPass(player, passId)
	for attempt = 1, 3 do
		local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok then
			return has
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return nil
end

local function loadPasses(player, data)
	local store = storeOf(data)
	owned[player] = owned[player] or {}
	for _, item in StoreConfig.Items do
		local id = passIdOf[item.Id]
		if item.Kind == "GamePass" and id and id > 0 then
			local has = ownsPass(player, id)
			if has == nil then
				has = store.Passes[item.Id] == true -- API down: trust what we saw last time
				warn("[Store] couldn't check pass", item.Id, "for", player.Name, "- using saved", has)
			end
			store.Passes[item.Id] = has or nil
			if has then
				owned[player][item.Id] = true
			end
		end
	end
	refreshPerks(player)
	player:SetAttribute("PerksLoaded", true)
end

local function grantPass(player, item)
	owned[player] = owned[player] or {}
	if owned[player][item.Id] then
		return
	end
	owned[player][item.Id] = true
	local data = DataService:Get(player)
	if data then
		storeOf(data).Passes[item.Id] = true
		DataService:Save(player)
	end
	refreshPerks(player)
	fire(player, item.Id, "GamePass", item.DisplayName)
	log(player.Name, "got pass", item.Id)
end

-- ---------- developer products ----------

local function bundleProduct(item)
	return {
		Key = item.Id,
		Kind = "Bundle",
		DisplayName = function()
			return item.DisplayName
		end,
		Grant = function(player, data)
			local g = item.Grant or {}
			if g.Egg and not HatchService:GiveEgg(player, g.Egg.BiomeId, g.Egg.Rarity, g.Egg.Size) then
				return false -- pen/data not ready yet: try again later, nothing granted
			end
			if g.Cash then
				EconomyService:AddCash(player, g.Cash)
			end
			if g.LuckSeconds then
				local store = storeOf(data)
				store.LuckUntil = math.max(store.LuckUntil, os.time()) + g.LuckSeconds
				store.LuckMultiplier = g.LuckMultiplier or 2
				refreshPerks(player)
			end
			return true
		end,
	}
end

local function trailProduct(trail)
	return {
		Key = trail.Id,
		Kind = "Trail",
		DisplayName = function()
			return trail.DisplayName or trail.Id
		end,
		Grant = function(player)
			if type(TrailService.Grant) ~= "function" then
				warn("[Store] TrailService:Grant missing - can't grant", trail.Id)
				return false
			end
			return TrailService:Grant(player, trail.Id)
		end,
	}
end

-- Robux upgrade to `level` of the pen or the treadmill. If that level was already reached (bought twice), the player
-- gets the level's cash price instead so the Robux aren't wasted.
local function upgradeProduct(key, level)
	local service = key == "Pen" and BaseService or TreadmillService
	local levels = key == "Pen" and BaseConfig.Levels or TreadmillConfig.Levels
	return {
		Key = key,
		Kind = "Upgrade",
		DisplayName = function()
			local def = levels[level]
			return key == "Pen" and ("Pen Level " .. level) or ("Treadmill: " .. (def and def.Name or ("Level " .. level)))
		end,
		Grant = function(player, data)
			local current = key == "Pen" and data.Pen.Level or data.Treadmill.Level
			if current < level then
				if type(service.GrantUpgrade) ~= "function" then
					warn("[Store]", key, "GrantUpgrade missing - can't grant")
					return false
				end
				return service:GrantUpgrade(player)
			end
			local cost = levels[level] and levels[level].Cost or 0
			return cost <= 0 or EconomyService:AddCash(player, cost)
		end,
	}
end

local function register(productId, product)
	if productId <= 0 then
		return
	end
	if products[productId] then
		warn("[Store] product id", productId, "is used twice:", products[productId].Key, "and", product.Key)
		return
	end
	products[productId] = product
end

local function waitForData(player, timeout)
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < timeout do
		local data = DataService:Get(player)
		if data then
			return data
		end
		task.wait(0.25)
	end
	return nil
end

local function pruneReceipts(purchases)
	local list = {}
	for id, t in purchases do
		table.insert(list, { id, t })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	for i = 1, #list - MAX_RECEIPTS do
		purchases[list[i][1]] = nil
	end
end

-- Grants one purchase exactly once. Returns an Enum.ProductPurchaseDecision.
local function grantReceipt(player, product, purchaseId)
	local data = waitForData(player, 15)
	if not data then
		return Decision.NotProcessedYet
	end
	local store = storeOf(data)
	if store.Purchases[purchaseId] then
		return Decision.PurchaseGranted -- granted before (the save went through, Roblox asked again)
	end
	if granting[purchaseId] then
		return Decision.NotProcessedYet
	end
	granting[purchaseId] = true
	local ok, granted = pcall(product.Grant, player, data)
	if not (ok and granted) then
		granting[purchaseId] = nil
		if not ok then
			warn("[Store] grant failed for", product.Key, granted)
		end
		return Decision.NotProcessedYet
	end
	store.Purchases[purchaseId] = os.time()
	pruneReceipts(store.Purchases)
	fire(player, product.Key, product.Kind, product.DisplayName())
	log(player.Name, "bought", product.Key, purchaseId)
	local saved = DataService:SaveNow(player, 15)
	granting[purchaseId] = nil
	-- not saved yet: the grant and the receipt id are both in memory and get saved together later; if they're lost
	-- together, Roblox asks again and the purchase is granted again (correct either way)
	return saved and Decision.PurchaseGranted or Decision.NotProcessedYet
end

local function processReceipt(receipt)
	local product = products[receipt.ProductId]
	if not product then
		warn("[Store] receipt for unknown product", receipt.ProductId)
		return Decision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Decision.NotProcessedYet -- granted when they next join
	end
	return grantReceipt(player, product, receipt.PurchaseId)
end

-- ---------- dev hooks ----------

local function devProduct(player, key)
	local item = StoreConfig.ById[key]
	if item and item.Kind == "Bundle" then
		return bundleProduct(item)
	end
	local data = DataService:Get(player)
	if key == "Pen" and data then
		return upgradeProduct("Pen", data.Pen.Level + 1)
	end
	if key == "Treadmill" and data then
		return upgradeProduct("Treadmill", data.Treadmill.Level + 1)
	end
	local trail = TrailConfig.ById[key]
	return trail and trailProduct(trail)
end

local function addDevHooks()
	local hooks = ServerStorage:WaitForChild("DevHooks", 30)
	if not hooks then
		return
	end
	local grant = Instance.new("BindableFunction")
	grant.Name = "StoreGrant"
	grant.OnInvoke = function(userId, itemId, on)
		local player = Players:GetPlayerByUserId(userId)
		local item = StoreConfig.ById[itemId]
		if not (player and item and item.Kind == "GamePass") then
			return false
		end
		if on == false then
			if owned[player] then
				owned[player][item.Id] = nil
			end
			refreshPerks(player)
		else
			grantPass(player, item)
		end
		return true
	end
	grant.Parent = hooks
	local receipt = Instance.new("BindableFunction")
	receipt.Name = "StoreReceipt"
	receipt.OnInvoke = function(userId, key, purchaseId)
		local player = Players:GetPlayerByUserId(userId)
		local product = player and devProduct(player, key)
		if not product then
			return "unknown"
		end
		return grantReceipt(player, product, purchaseId or ("dev-" .. HttpService:GenerateGUID(false))).Name
	end
	receipt.Parent = hooks
end

function GamePassService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local ui = uiConfig()
	local uiItems = {}
	for _, it in ui.StoreItems or {} do
		uiItems[it.Id] = it
	end
	for _, item in StoreConfig.Items do
		local u = uiItems[item.Id] or {}
		if item.Kind == "GamePass" then
			local id = pick(item.GamePassId, u.GamePassId)
			passIdOf[item.Id] = id
			if id > 0 then
				passItemById[id] = item
			end
		else
			register(pick(item.ProductId, u.ProductId), bundleProduct(item))
		end
	end
	local uiUpgrades = ui.UpgradeRobux or {}
	for key, levels in StoreConfig.Upgrades do
		for level, entry in levels do
			local u = uiUpgrades[key] and uiUpgrades[key][level] or {}
			register(pick(entry.ProductId, u.ProductId), upgradeProduct(key, level))
		end
	end
	for _, trail in TrailConfig.List do
		register(pick(trail.ProductId, 0), trailProduct(trail))
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

function GamePassService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local item = passItemById[passId]
		if purchased and item then
			grantPass(player, item)
		end
	end)
	DataService:OnLoaded(loadPasses)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		luckEndsAt[player] = nil
	end)
	-- the timed luck boost runs out
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player, endsAt in luckEndsAt do
				if now >= endsAt and player.Parent then
					refreshPerks(player)
				end
			end
		end
	end)
	if DevConfig.AdminCommands then
		task.spawn(addDevHooks)
	end
end

return GamePassService
