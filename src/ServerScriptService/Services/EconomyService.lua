-- Passive income: every tick, each kaiju in the player's pen adds its CashPerSecond straight into Cash.
-- Offline earnings are added to Cash on join (capped, reduced rate).
-- Player attributes: Cash, CashPerSecond. Also leaderstats.Cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local EconomyConfig = require(Config.EconomyConfig)
local KaijuConfig = require(Config.KaijuConfig)
local DevConfig = require(Config.DevConfig)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)

local EconomyService = {}

local gameEvent
local lastTick = {} -- [player] = os.clock() of the last payout
local fraction = {} -- [player] = sub-dollar remainder carried between ticks

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Economy]", ...)
	end
end

function EconomyService:GetCashPerSecond(player)
	local total = 0
	BaseService:ForEachItem(player, function(_, entry)
		if entry.Kind == "Kaiju" then
			local cfg = KaijuConfig[entry.Species]
			total += cfg and cfg.CashPerSecond or 0
		end
	end)
	return total
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
			total += cfg.CashPerSecond * math.min(now - math.max(data.LastOnline, from), cap)
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
	end)

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
