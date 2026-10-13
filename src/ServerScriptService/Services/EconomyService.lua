-- Passive income: every tick, each kaiju in the player's pen adds its CashPerSecond straight into Cash
-- (species x size roll x level, see Shared.Util.KaijuStats).
-- Offline earnings are added to Cash on join (capped, reduced rate).
-- Perks (set by GamePassService): player attribute CashMultiplier (default 1) multiplies all income and the shown
-- CashPerSecond (kaiju models keep their own base CashPerSecond, which also sets sell prices). Offline earnings pay the
-- base amount on join and the multiplier's extra once the player attribute PerksLoaded becomes true.
-- Player attributes: Cash, CashPerSecond. Also leaderstats.Cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local EconomyConfig = require(Config.EconomyConfig)
local KaijuConfig = require(Config.KaijuConfig)
local DevConfig = require(Config.DevConfig)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)

local EconomyService = {}

local gameEvent
local lastTick = {} -- [player] = os.clock() of the last payout
local fraction = {} -- [player] = sub-dollar remainder carried between ticks
local pendingOfflineBonus = {} -- [player] = base offline amount still owed the CashMultiplier extra
local PERKS_WAIT_SECONDS = 20

-- x2 Cash and similar perks (CashMultiplier, GamePassService) x the Kaiju Index area bonus (IndexCashBonus,
-- IndexService: x1.5 per completed area, stacking); 1 when the player has neither.
local function cashMultiplier(player)
	local m = player:GetAttribute("CashMultiplier")
	local index = player:GetAttribute("IndexCashBonus")
	local daily = player:GetAttribute("DailyCashBoost") -- timed Money Boost from the daily reward (DailyRewardService)
	m = type(m) == "number" and m > 0 and m or 1
	m *= type(daily) == "number" and daily > 0 and daily or 1
	return m * (type(index) == "number" and index > 0 and index or 1)
end

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Economy]", ...)
	end
end

function EconomyService:GetCashPerSecond(player)
	local total = 0
	BaseService:ForEachItem(player, function(_, entry)
		if entry.Kind == "Kaiju" and not entry.StolenBy then -- a kaiju being carried off earns nothing
			total += KaijuStats.EntryCashPerSecond(entry)
		end
	end)
	return total * cashMultiplier(player)
end

local function publish(player, data)
	player:SetAttribute("Cash", math.floor(data.Cash))
	player:SetAttribute("CashPerSecond", EconomyService:GetCashPerSecond(player))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = math.floor(data.Cash)
	end
end

-- Each kaiju earns from max(LastOnline, when it hatched) until now, capped. Eggs don't earn until hatched.
local function offlineEarnings(data)
	if (data.LastOnline or 0) <= 0 then
		return 0, 0
	end
	local now = os.time()
	local away = now - data.LastOnline
	if away < EconomyConfig.Offline.MinSeconds then
		return 0, away
	end
	local cap = EconomyConfig.Offline.CapSeconds
	local total = 0
	for _, entry in data.Pen.Items do
		local cfg = KaijuConfig[entry.Species]
		local from = entry.Kind == "Kaiju" and entry.HatchedAt
		if cfg and from and from <= now then
			total += KaijuStats.EntryCashPerSecond(entry) * math.min(now - math.max(data.LastOnline, from), cap)
		end
	end
	return math.floor(total * EconomyConfig.Offline.Rate), math.min(away, cap)
end

local function onLoaded(player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	ls.Parent = player

	local amount, seconds = offlineEarnings(data)
	if amount > 0 then
		data.Cash += amount
		data.TotalEarned += amount
		gameEvent:FireClient(player, "OfflineEarnings", { Amount = amount, Seconds = seconds })
		log(player.Name, "offline earnings", amount, "for", seconds, "s")
		-- perks load asynchronously (game pass checks); their extra is paid once PerksLoaded arrives
		pendingOfflineBonus[player] = amount
		local function payBonus()
			local base = pendingOfflineBonus[player]
			pendingOfflineBonus[player] = nil
			local extra = base and math.floor(base * (cashMultiplier(player) - 1)) or 0
			if extra > 0 and EconomyService:AddCash(player, extra) then
				gameEvent:FireClient(player, "OfflineEarnings", { Amount = extra, Seconds = seconds, Bonus = true })
			end
		end
		if player:GetAttribute("PerksLoaded") then
			payBonus()
		else
			local conn
			conn = player:GetAttributeChangedSignal("PerksLoaded"):Connect(function()
				conn:Disconnect()
				payBonus()
			end)
			task.delay(PERKS_WAIT_SECONDS, function()
				if conn.Connected then
					conn:Disconnect()
					pendingOfflineBonus[player] = nil
				end
			end)
		end
	end
	data.LastOnline = os.time()
	lastTick[player] = os.clock()
	fraction[player] = 0
	publish(player, data)
end

function EconomyService:AddCash(player, amount)
	local data = DataService:Get(player)
	if not data or amount <= 0 then
		return false
	end
	data.Cash += amount
	data.TotalEarned += amount
	publish(player, data)
	DataService:Save(player)
	return true
end

-- Re-sends Cash / CashPerSecond right away (after selling or levelling a kaiju).
function EconomyService:Publish(player)
	local data = DataService:Get(player)
	if data then
		publish(player, data)
	end
end

-- Returns false if the player can't afford it.
function EconomyService:TrySpend(player, amount)
	local data = DataService:Get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	publish(player, data)
	DataService:Save(player)
	return true
end

function EconomyService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
end

function EconomyService:Start()
	DataService:OnLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
		fraction[player] = nil
		pendingOfflineBonus[player] = nil
	end)
	local function watchPerks(player)
		player:GetAttributeChangedSignal("CashMultiplier"):Connect(function()
			self:Publish(player)
		end)
	end
	Players.PlayerAdded:Connect(watchPerks)
	for _, player in Players:GetPlayers() do
		watchPerks(player)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < EconomyConfig.TickSeconds then
			return
		end
		acc = 0
		local now = os.clock()
		for player, last in lastTick do
			local data = DataService:Get(player)
			if data then
				local earned = self:GetCashPerSecond(player) * (now - last) + fraction[player]
				local whole = math.floor(earned)
				fraction[player] = earned - whole
				data.Cash += whole
				data.TotalEarned += whole
				data.LastOnline = os.time()
				lastTick[player] = now
				publish(player, data)
			end
		end
	end)
end

return EconomyService
