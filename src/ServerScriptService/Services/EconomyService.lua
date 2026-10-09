-- Cash per second from kaiju on pads -> PendingCash -> stepping on the plot's CollectPad moves it into Cash.
-- Offline earnings are added to PendingCash on join (capped, reduced rate).
-- Player attributes: Cash, PendingCash, CashPerSecond. Also leaderstats.Cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local EconomyConfig = require(Config.EconomyConfig)
local KaijuConfig = require(Config.KaijuConfig)
local DevConfig = require(Config.DevConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)

local EconomyService = {}

local gameEvent
local lastTick = {} -- [player] = os.clock()

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Economy]", ...)
	end
end

function EconomyService:GetCashPerSecond(player)
	local total = 0
	BaseService:ForEachPad(player, function(_, entry)
		if entry.Kind == "Kaiju" then
			local cfg = KaijuConfig[entry.Species]
			total += cfg and cfg.CashPerSecond or 0
		end
	end)
	return total
end

local function collectLabel(player)
	local plot = BaseService:GetPlot(player)
	local pad = plot and plot:FindFirstChild("CollectPad")
	local bb = pad and pad:FindFirstChild("Pending")
	return bb and bb.Amount
end

local function publish(player, data)
	local cps = EconomyService:GetCashPerSecond(player)
	player:SetAttribute("Cash", math.floor(data.Cash))
	player:SetAttribute("PendingCash", math.floor(data.PendingCash))
	player:SetAttribute("CashPerSecond", cps)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = math.floor(data.Cash)
	end
	local label = collectLabel(player)
	if label then
		label.Text = Format.Money(data.PendingCash)
	end
end

local function setupCollectBillboard(player)
	local plot = BaseService:GetPlot(player)
	local pad = plot and plot:FindFirstChild("CollectPad")
	if not pad or pad:FindFirstChild("Pending") then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Pending"
	bb.Size = UDim2.fromOffset(160, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.MaxDistance = 120
	local l = Instance.new("TextLabel")
	l.Name = "Amount"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromHex("6BE04A")
	l.TextStrokeTransparency = 0.2
	l.Text = "$0"
	l.Parent = bb
	bb.Parent = pad
end

-- Offline earnings: each kaiju earns from max(LastOnline, when it hatched) until now, capped.
-- Eggs whose timer ran out while offline count as hatched at their HatchAt.
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
	for _, entry in data.Pads do
		local cfg = KaijuConfig[entry.Species]
		local from = entry.Kind == "Kaiju" and entry.HatchedAt or entry.HatchAt
		if cfg and from and from <= now then
			local start = math.max(data.LastOnline, from)
			local seconds = math.min(now - start, cap)
			total += cfg.CashPerSecond * seconds
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
		data.PendingCash += amount
		gameEvent:FireClient(player, "OfflineEarnings", { Amount = amount, Seconds = seconds })
		log(player.Name, "offline earnings", amount, "for", seconds, "s")
	end
	data.LastOnline = os.time()
	lastTick[player] = os.clock()
	setupCollectBillboard(player)
	publish(player, data)
end

local function insideCollectPad(player)
	local plot = BaseService:GetPlot(player)
	local pad = plot and plot:FindFirstChild("CollectPad")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (pad and hrp) then
		return false
	end
	local p = pad.CFrame:PointToObjectSpace(hrp.Position)
	return math.abs(p.X) <= pad.Size.X / 2 + 0.5 and math.abs(p.Z) <= pad.Size.Z / 2 + 0.5 and p.Y >= 0 and p.Y <= 6
end

function EconomyService:Collect(player)
	local data = DataService:Get(player)
	if not data then
		return 0
	end
	local amount = math.floor(data.PendingCash)
	if amount < 1 then
		return 0
	end
	data.PendingCash -= amount
	data.Cash += amount
	data.TotalEarned += amount
	publish(player, data)
	gameEvent:FireClient(player, "CashCollected", { Amount = amount })
	DataService:Save(player)
	return amount
end

-- For later phases (shop, rebirth): returns false if the player can't afford it.
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
	end)

	local acc, collectAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		collectAcc += dt
		if collectAcc >= EconomyConfig.CollectCheckInterval then
			collectAcc = 0
			for player in lastTick do
				if insideCollectPad(player) then
					self:Collect(player)
				end
			end
		end
		if acc < EconomyConfig.TickSeconds then
			return
		end
		acc = 0
		local now = os.clock()
		for player, last in lastTick do
			local data = DataService:Get(player)
			if data then
				data.PendingCash += self:GetCashPerSecond(player) * (now - last)
				data.LastOnline = os.time()
				lastTick[player] = now
				publish(player, data)
			end
		end
	end)
end

return EconomyService
