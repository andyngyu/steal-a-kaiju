-- Kaiju food and levels (numbers in Shared.Config.FoodConfig).
--   Buying:  the Food stall counter in the Kaiju Market (each item: BuyPrompt E = 1, BuyTenPrompt F = 10),
--            or Remotes.BuyFood (foodId, amount) from the UI. Buying also selects that food for feeding.
--   Feeding: every kaiju has a FeedPrompt (E, feeds one of the selected food) and a SwapFoodPrompt (F, picks the next
--            food you own). Kaiju only move on clients, so the server can't validate these prompts by distance:
--            Gameplay.MarketFX shows them to the owner only and turns a trigger into Remotes.FeedKaiju (kaijuId,
--            foodId?, count?) / Remotes.SelectFood (foodId, "" = auto, "next" = cycle). The UI uses the same remotes.
--   Levels:  food XP fills the kaiju's level bar (FoodConfig.XPToNext). Each level adds income and size; a level-up
--            rebuilds the kaiju bigger where it stands (KaijuService:Refresh) after the food lands.
-- Player attributes: Food_<FoodId> (count owned), SelectedFood ("" = auto: best food owned).
-- GameEvent: FoodBought {FoodId, Amount, Count}, NoFood {}, NotEnoughCash {Cost}, KaijuMaxLevel {KaijuId},
--   KaijuFed {KaijuId, OwnerUserId, FoodId, Count, XPGained, Level, XP, XPToNext, LevelsGained} (to every client, for
--   the eating effect).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- The food a feed uses: the one asked for, else the selected one, else the best one owned.
local function chooseFood(data, requested)
	if requested and FoodConfig.ById[requested] and owned(data, requested) > 0 then
		return FoodConfig.ById[requested]
	end
	local selected = FoodConfig.ById[data.SelectedFood or ""]
	if selected and owned(data, selected.Id) > 0 then
		return selected
	end
	for i = #FoodConfig.Foods, 1, -1 do
		local food = FoodConfig.Foods[i]
		if owned(data, food.Id) > 0 then
			return food
		end
	end
	return nil
end

-- Owner-facing prompt texts on every kaiju the player owns (only the owner sees these prompts).
local function refreshPrompts(player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local food = chooseFood(data, nil)
	BaseService:ForEachItem(player, function(_, entry, model)
		local attach = entry.Kind == "Kaiju" and model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("PromptAttachment")
		if not attach then
			return
		end
		local feed, swap = attach:FindFirstChild("FeedPrompt"), attach:FindFirstChild("SwapFoodPrompt")
		local cfg = KaijuConfig[entry.Species]
		local level = entry.Level or 1
		local maxed = level >= FoodConfig.MaxLevel
		if feed then
			feed.ObjectText = (cfg and cfg.DisplayName or entry.Species) .. (maxed and "  MAX LEVEL" or ("  Lv " .. level))
			if maxed then
				feed.ActionText = "Max level!"
			elseif food then
				feed.ActionText = string.format("Feed %s (%d)", food.DisplayName, owned(data, food.Id))
			else
				feed.ActionText = "Feed (no food - visit the Food stall)"
			end
		end
		if swap then
			swap.Enabled = food ~= nil and not maxed
			swap.ObjectText = food and ("Using " .. food.DisplayName) or ""
		end
	end)
end

local function publish(player, data)
	for _, f in FoodConfig.Foods do
		player:SetAttribute("Food_" .. f.Id, owned(data, f.Id))
	end
	player:SetAttribute("SelectedFood", data.SelectedFood or "")
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
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, FoodConfig.MaxBuy)
	local cost = food.Price * amount
	if not EconomyService:TrySpend(player, cost) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = cost })
		return false
	end
	data.Food[food.Id] = owned(data, food.Id) + amount
	data.SelectedFood = food.Id
	publish(player, data)
	DataService:Save(player)
	gameEvent:FireClient(player, "FoodBought", { FoodId = food.Id, Amount = amount, Count = data.Food[food.Id] })
	log(player.Name, "bought", amount, food.Id, "for", cost)
	return true
end

function FoodService:Select(player, foodId)
	local data = DataService:Get(player)
	if not data or (foodId ~= "" and not FoodConfig.ById[foodId]) then
		return
	end
	data.SelectedFood = foodId
	publish(player, data)
end

-- Next owned food after the selected one (wraps around).
function FoodService:CycleSelected(player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local current = chooseFood(data, nil)
	local start = current and current.Order or 0
	local n = #FoodConfig.Foods
	for step = 1, n do
		local food = FoodConfig.Foods[(start + step - 1) % n + 1]
		if owned(data, food.Id) > 0 then
			self:Select(player, food.Id)
			return
		end
	end
end

-- Feeds up to `count` of one food to the player's kaiju. Returns true if anything was eaten.
function FoodService:Feed(player, kaijuId, foodId, count)
	local data = DataService:Get(player)
	local entry, model = BaseService:GetItem(player, kaijuId)
	if not (data and entry and entry.Kind == "Kaiju") then
		return false
	end
	entry.Level = entry.Level or 1
	entry.XP = entry.XP or 0
	if entry.Level >= FoodConfig.MaxLevel then
		gameEvent:FireClient(player, "KaijuMaxLevel", { KaijuId = kaijuId })
		return false
	end
	local food = chooseFood(data, foodId)
	if not food then
		gameEvent:FireClient(player, "NoFood", {})
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

-- Feed (E) and change-food (F) prompts on a kaiju, at mid-body height. The owner's client handles them
-- (Gameplay.MarketFX -> Remotes.FeedKaiju / SelectFood); the server only labels them.
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
	feed.HoldDuration = FoodConfig.FeedHoldSeconds
	feed.MaxActivationDistance = reach
	feed.RequiresLineOfSight = false
	feed.Parent = attach

	local swap = Instance.new("ProximityPrompt")
	swap.Name = "SwapFoodPrompt"
	swap.ActionText = "Change food"
	swap.KeyboardKeyCode = Enum.KeyCode.F
	swap.GamepadKeyCode = Enum.KeyCode.ButtonY
	swap.HoldDuration = 0
	swap.MaxActivationDistance = reach
	swap.RequiresLineOfSight = false
	swap.UIOffset = Vector2.new(0, 80)
	swap.Parent = attach

	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		task.defer(refreshPrompts, owner)
	end
end

-- Food stall counter: every item has BuyPrompt (1) and BuyTenPrompt (10).
local function hookCounter()
	local market = workspace:WaitForChild("Map"):WaitForChild("Market", 10)
	local stall = market and market:FindFirstChild("FoodStall")
	local items = stall and stall:FindFirstChild("Items")
	if not items then
		warn("[FoodService] no Map.Market.FoodStall.Items - run Tools.MarketBuilder")
		return
	end
	for _, item in items:GetChildren() do
		local foodId = item:GetAttribute("FoodId")
		for _, prompt in item:GetDescendants() do
			if prompt:IsA("ProximityPrompt") then
				local amount = prompt.Name == "BuyTenPrompt" and 10 or 1
				prompt.Triggered:Connect(function(player)
					if spamGuard(player, 0.12) then
						FoodService:Buy(player, foodId, amount)
					end
				end)
			end
		end
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
		if foodId == "next" then
			if spamGuard(player, 0.15) then
				self:CycleSelected(player)
			end
		elseif type(foodId) == "string" then
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
	hookCounter()
	DataService:OnLoaded(function(player, data)
		-- drop unknown foods (renamed/removed in config)
		for id in data.Food do
			if not FoodConfig.ById[id] then
				data.Food[id] = nil
			end
		end
		publish(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return FoodService
