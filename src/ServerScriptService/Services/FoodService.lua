-- Kaiju food and levels (numbers in Shared.Config.FoodConfig).
--   Buying:  the Kaiju Food panel (UI FoodShopController; opened at the Food stall) -> Remotes.BuyFood (foodId, amount).
--   Stock:   limited supply that restocks every FoodConfig.RestockSeconds on one clock (FoodConfig.RollStock: rarer food
--            is in stock less often and in smaller amounts). Each player buys from their own copy of the restock
--            (data.FoodStock, so rejoining doesn't refill it). Buying more than is left buys what's left.
--            workspace attribute FoodRestockAt = unix time of the next restock (compare with GetServerTimeNow()).
--   Holding: the food hotbar (UI FoodHotbarController: keys 1-6, tap, DPad) -> Remotes.SelectFood (foodId, or "" to put
--            it away). The held food is a Tool "HeldFood" in the character's hand (never in the Backpack, can't be
--            dropped). Buying food with empty hands picks it up; running out of the held food puts it away.
--   Feeding: every kaiju has a FeedPrompt (E, one of the held food) and a FeedTenPrompt (F, up to 10), shown only while
--            its owner holds food. Kaiju only move on clients, so the server can't validate these prompts by distance:
--            Gameplay.MarketFX shows them to the owner only and turns a trigger into Remotes.FeedKaiju (kaijuId,
--            foodId?, count?); without foodId the held food is used.
--   Levels:  food XP fills the kaiju's level bar (FoodConfig.XPToNext). Each level adds income and size; a level-up
--            rebuilds the kaiju bigger where it stands (KaijuService:Refresh) after the food lands.
-- Player attributes: Food_<FoodId> (count owned), FoodStock_<FoodId> (left in this restock), SelectedFood (held food id,
--   "" = empty hands).
-- GameEvent: FoodBought {FoodId, Amount, Count}, OutOfStock {FoodId, RestockAt}, FoodRestocked {Stock = {[foodId] = n},
--   Rare = {foodIds}} (to everyone when a rare food is in stock), NoFood {FoodId}, NotHoldingFood {}, FoodRanOut {FoodId},
--   NotEnoughCash {Cost}, KaijuMaxLevel {KaijuId}, KaijuFed {KaijuId, OwnerUserId, FoodId, Count, XPGained, Level, XP,
--   XPToNext, LevelsGained} (to every client, for the eating effect).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local FoodConfig = require(Config.FoodConfig)
local KaijuConfig = require(Config.KaijuConfig)
local DevConfig = require(Config.DevConfig)
local KaijuModel = require(game:GetService("ServerScriptService").Lib.KaijuModel)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local KaijuService = require(script.Parent.KaijuService)

local FoodService = {}

local HELD = "HeldFood"
local foodArt = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Food")
local gameEvent
local kaijuFolder
local lastAction = {} -- [player] = os.clock(), light spam guard
local refreshToken = {} -- [kaijuId] = token of the pending grow-rebuild

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Food]", ...)
	end
end

local function owned(data, foodId)
	return data.Food[foodId] or 0
end

-- ---------- stock ----------

local cycleOffset = 0 -- Studio testing only (RestockForTesting)
local rolled = { cycle = nil, stock = nil }

local function currentCycle()
	return math.floor(os.time() / FoodConfig.RestockSeconds) + cycleOffset
end

local function shopStock()
	local cycle = currentCycle()
	if rolled.cycle ~= cycle then
		rolled.cycle, rolled.stock = cycle, FoodConfig.RollStock(cycle)
	end
	return rolled.stock, cycle
end

-- How many of a food this player can still buy in the current restock.
local function stockLeft(data, foodId)
	local stock, cycle = shopStock()
	local s = data.FoodStock
	if s.Cycle ~= cycle then
		s.Cycle = cycle
		s.Bought = {}
	end
	return math.max(0, (stock[foodId] or 0) - (s.Bought[foodId] or 0))
end

local function restockAt()
	return (currentCycle() - cycleOffset + 1) * FoodConfig.RestockSeconds
end

-- The food in the player's hands (nil when empty or when they've run out of it).
local function heldFood(data)
	local food = FoodConfig.ById[data.SelectedFood or ""]
	return food and owned(data, food.Id) > 0 and food or nil
end

-- Owner-facing prompts on every kaiju the player owns (only the owner sees them): shown while holding food.
local function refreshPrompts(player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local food = heldFood(data)
	local count = food and owned(data, food.Id) or 0
	BaseService:ForEachItem(player, function(_, entry, model)
		local attach = entry.Kind == "Kaiju" and model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("PromptAttachment")
		if not attach then
			return
		end
		local feed, ten = attach:FindFirstChild("FeedPrompt"), attach:FindFirstChild("FeedTenPrompt")
		local cfg = KaijuConfig[entry.Species]
		local level = entry.Level or 1
		local canFeed = food ~= nil and level < FoodConfig.MaxLevel
		if feed then
			feed.Enabled = canFeed
			feed.ObjectText = (cfg and cfg.DisplayName or entry.Species) .. "  Lv " .. level
			feed.ActionText = food and string.format("Feed %s (%d)", food.DisplayName, count) or "Feed"
		end
		if ten then
			ten.Enabled = canFeed and count > 1
			ten.ActionText = count >= 10 and "Feed x10" or string.format("Feed all (%d)", count)
		end
	end)
end

-- A Tool holding the food's brick model (Root becomes the Handle; the rest is welded to it).
local function makeTool(food)
	local art = foodArt:FindFirstChild(food.Id)
	if not (art and art.PrimaryPart) then
		return nil
	end
	local model = art:Clone()
	local tool = Instance.new("Tool")
	tool.Name = HELD
	tool.ToolTip = food.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("FoodId", food.Id)
	local handle = model.PrimaryPart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			if p ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	handle.Name = "Handle"
	-- held up in front of the hand, food centred on the grip
	local _, size = art:GetBoundingBox()
	tool.Grip = CFrame.new(0, -size.Y * 0.15, -0.15) * CFrame.Angles(0, math.rad(90), 0)
	return tool
end

-- Puts the held food in the character's hand (or takes it away).
local function updateHeld(player, data)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local food = heldFood(data)
	local current = char:FindFirstChild(HELD)
	if current and food and current:GetAttribute("FoodId") == food.Id then
		return
	end
	if current then
		current:SetAttribute("Swapping", true)
		current:Destroy()
	end
	if food and hum.Health > 0 then
		local tool = makeTool(food)
		if tool then
			-- the client can unequip it (it lands in the Backpack): treat that as putting the food away
			tool.AncestryChanged:Connect(function(_, parent)
				if parent and parent:IsA("Backpack") and not tool:GetAttribute("Swapping") then
					tool:Destroy()
					FoodService:Select(player, "")
				end
			end)
			tool.Parent = char
		end
	end
end

local function publish(player, data)
	if data.SelectedFood ~= "" and not heldFood(data) then
		data.SelectedFood = ""
	end
	for _, f in FoodConfig.Foods do
		player:SetAttribute("Food_" .. f.Id, owned(data, f.Id))
		player:SetAttribute("FoodStock_" .. f.Id, stockLeft(data, f.Id))
	end
	player:SetAttribute("SelectedFood", data.SelectedFood or "")
	updateHeld(player, data)
	refreshPrompts(player)
end

local function spamGuard(player, seconds)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < seconds then
		return false
	end
	lastAction[player] = now
	return true
end

function FoodService:Buy(player, foodId, amount)
	local food = FoodConfig.ById[foodId]
	local data = DataService:Get(player)
	if not (food and data) then
		return false
	end
	local left = stockLeft(data, food.Id)
	if left <= 0 then
		gameEvent:FireClient(player, "OutOfStock", { FoodId = food.Id, RestockAt = restockAt() })
		publish(player, data)
		return false
	end
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, math.min(FoodConfig.MaxBuy, left))
	local cost = food.Price * amount
	if not EconomyService:TrySpend(player, cost) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = cost })
		return false
	end
	data.FoodStock.Bought[food.Id] = (data.FoodStock.Bought[food.Id] or 0) + amount
	data.Food[food.Id] = owned(data, food.Id) + amount
	if not heldFood(data) then
		data.SelectedFood = food.Id -- empty hands pick up what was just bought
	end
	publish(player, data)
	DataService:Save(player)
	gameEvent:FireClient(player, "FoodBought", { FoodId = food.Id, Amount = amount, Count = data.Food[food.Id] })
	log(player.Name, "bought", amount, food.Id, "for", cost)
	return true
end

-- Restocks the shop now (Studio testing only; everyone in the server gets the next restock early).
function FoodService:RestockForTesting()
	if RunService:IsStudio() then
		cycleOffset += 1
	end
end

-- Hold a food ("" = empty hands). Only food the player owns can be held.
function FoodService:Select(player, foodId)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	if foodId ~= "" then
		local food = FoodConfig.ById[foodId]
		if not food then
			return false
		end
		if owned(data, food.Id) <= 0 then
			gameEvent:FireClient(player, "NoFood", { FoodId = food.Id })
			return false
		end
	end
	data.SelectedFood = foodId
	publish(player, data)
	return true
end

-- Feeds up to `count` of one food to the player's kaiju. Returns true if anything was eaten.
function FoodService:Feed(player, kaijuId, foodId, count)
	local data = DataService:Get(player)
	local entry, model = BaseService:GetItem(player, kaijuId)
	if not (data and entry and entry.Kind == "Kaiju") or entry.StolenBy then
		return false
	end
	entry.Level = entry.Level or 1
	entry.XP = entry.XP or 0
	if entry.Level >= FoodConfig.MaxLevel then
		gameEvent:FireClient(player, "KaijuMaxLevel", { KaijuId = kaijuId })
		return false
	end
	local food = FoodConfig.ById[foodId or data.SelectedFood or ""]
	if not food then
		gameEvent:FireClient(player, "NotHoldingFood", {})
		return false
	end
	if owned(data, food.Id) <= 0 then
		gameEvent:FireClient(player, "NoFood", { FoodId = food.Id })
		return false
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, FoodConfig.MaxFeed)

	local fed, gained, levels = 0, 0, 0
	while fed < count and owned(data, food.Id) > 0 and entry.Level < FoodConfig.MaxLevel do
		data.Food[food.Id] -= 1
		fed += 1
		entry.XP += food.XP
		gained += food.XP
		local need = FoodConfig.XPToNext(entry.Level)
		while need and entry.XP >= need do
			entry.XP -= need
			entry.Level += 1
			levels += 1
			need = FoodConfig.XPToNext(entry.Level)
		end
	end
	if entry.Level >= FoodConfig.MaxLevel then
		entry.XP = 0 -- leftover XP has nowhere to go
	end
	if owned(data, food.Id) <= 0 then
		data.Food[food.Id] = nil
		if data.SelectedFood == food.Id then
			data.SelectedFood = ""
			gameEvent:FireClient(player, "FoodRanOut", { FoodId = food.Id })
		end
	end
	data.Stats.FoodFed = (data.Stats.FoodFed or 0) + fed

	local xpToNext = FoodConfig.XPToNext(entry.Level)
	if model then
		KaijuModel.SetProgress(model, entry.Level, entry.XP, xpToNext)
	end
	gameEvent:FireAllClients("KaijuFed", {
		KaijuId = kaijuId,
		OwnerUserId = player.UserId,
		FoodId = food.Id,
		Count = fed,
		XPGained = gained,
		Level = entry.Level,
		XP = entry.XP,
		XPToNext = xpToNext,
		LevelsGained = levels,
	})
	if levels > 0 then
		-- income goes up right away; the model grows once the food has landed
		EconomyService:Publish(player)
		local token = {}
		refreshToken[kaijuId] = token
		task.delay(FoodConfig.LevelUpRespawnDelay, function()
			if refreshToken[kaijuId] ~= token or player.Parent ~= Players then
				return
			end
			refreshToken[kaijuId] = nil
			local still = BaseService:GetItem(player, kaijuId)
			if still == entry then
				KaijuService:Refresh(player, kaijuId, entry)
				refreshPrompts(player)
			end
		end)
	end
	publish(player, data)
	DataService:Save(player)
	log(player.Name, "fed", fed, food.Id, "to", entry.Species, "-> Lv", entry.Level, "XP", entry.XP)
	return true
end

-- Feed (E) and feed-ten (F) prompts on a kaiju, at mid-body height. The owner's client handles them
-- (Gameplay.MarketFX -> Remotes.FeedKaiju); the server only labels and enables them.
local function addPrompts(model)
	if model:GetAttribute("Showcase") or not model.PrimaryPart then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId")
	local _, ext = model:GetBoundingBox()
	local attach = Instance.new("Attachment")
	attach.Name = "PromptAttachment"
	attach.Position = Vector3.new(0, ext.Y * 0.45, 0)
	attach.Parent = model.PrimaryPart
	local reach = 7 + math.max(ext.X, ext.Z) / 2

	local feed = Instance.new("ProximityPrompt")
	feed.Name = "FeedPrompt"
	feed.ActionText = "Feed"
	feed.Enabled = false
	feed.HoldDuration = FoodConfig.FeedHoldSeconds
	feed.MaxActivationDistance = reach
	feed.RequiresLineOfSight = false
	feed.Parent = attach

	local ten = Instance.new("ProximityPrompt")
	ten.Name = "FeedTenPrompt"
	ten.ActionText = "Feed x10"
	ten.Enabled = false
	ten.KeyboardKeyCode = Enum.KeyCode.F
	ten.GamepadKeyCode = Enum.KeyCode.ButtonY
	ten.HoldDuration = FoodConfig.FeedHoldSeconds * 2
	ten.MaxActivationDistance = reach
	ten.RequiresLineOfSight = false
	ten.UIOffset = Vector2.new(0, 80)
	ten.Parent = attach

	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		task.defer(refreshPrompts, owner)
	end
end

function FoodService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remotes = ReplicatedStorage.Remotes
	remotes:WaitForChild("BuyFood").OnServerEvent:Connect(function(player, foodId, amount)
		if type(foodId) == "string" and spamGuard(player, 0.12) then
			self:Buy(player, foodId, amount)
		end
	end)
	remotes:WaitForChild("SelectFood").OnServerEvent:Connect(function(player, foodId)
		if type(foodId) == "string" then
			self:Select(player, foodId)
		end
	end)
	remotes:WaitForChild("FeedKaiju").OnServerEvent:Connect(function(player, kaijuId, foodId, count)
		if type(kaijuId) == "string" and (foodId == nil or type(foodId) == "string") and spamGuard(player, 0.1) then
			self:Feed(player, kaijuId, foodId, count)
		end
	end)
end

function FoodService:Start()
	local runtime = workspace:WaitForChild("Runtime")
	kaijuFolder = runtime:WaitForChild("Kaiju")
	kaijuFolder.ChildAdded:Connect(addPrompts)
	for _, model in kaijuFolder:GetChildren() do
		addPrompts(model)
	end
	local function onCharacter(player)
		local char = player.Character
		local data = DataService:Get(player)
		if char and data then
			char:WaitForChild("Humanoid", 10)
			updateHeld(player, data)
		end
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService:OnLoaded(function(player, data)
		-- drop unknown foods (renamed/removed in config)
		for id in data.Food do
			if not FoodConfig.ById[id] then
				data.Food[id] = nil
			end
		end
		publish(player, data)
	end)

	-- restock clock: republish everyone's stock when a new restock starts; rare stock is news for the whole server
	local lastCycle = currentCycle()
	workspace:SetAttribute("FoodRestockAt", restockAt())
	task.spawn(function()
		while true do
			task.wait(1)
			local cycle = currentCycle()
			if cycle ~= lastCycle then
				lastCycle = cycle
				workspace:SetAttribute("FoodRestockAt", restockAt())
				for _, player in Players:GetPlayers() do
					local data = DataService:Get(player)
					if data then
						publish(player, data)
					end
				end
				local stock = shopStock()
				local rare = {}
				for _, f in FoodConfig.Foods do
					if (stock[f.Id] or 0) > 0 and f.Stock.Chance < FoodConfig.RareStockChance then
						table.insert(rare, f.Id)
					end
				end
				if #rare > 0 then
					gameEvent:FireAllClients("FoodRestocked", { Stock = stock, Rare = rare })
				end
				log("restock", cycle, "rare:", table.concat(rare, ","))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return FoodService
