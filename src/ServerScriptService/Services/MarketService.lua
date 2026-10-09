-- Kaiju Market backend (the stalls themselves are built by ServerStorage.Tools.MarketBuilder into Map.Market).
--   Remotes.SellKaiju (kaijuId): sells one of your kaiju for KaijuStats.SellPrice (income x EconomyConfig.SellMultiplier).
--     Used by the UI's Sell panel; the Sell stall's pad/prompt opens that panel (Gameplay.MarketFX).
--   Remotes.TeleportToShop (): to the market (the UI's BUY button). Remotes.TeleportToBase (): to your pen's entrance,
--     only from the bases side of Map.SafeZoneX (the UI's BASE button). Neither works while carrying an egg or stolen
--     goods (StealService: no teleporting home with loot).
-- GameEvent: KaijuSold {KaijuId, OwnerUserId, Species, Price, Position} (to every client, for the coin burst),
--   CantTeleport {Reason = "Carrying" | "SafeZone"}.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local KaijuService = require(script.Parent.KaijuService)

local MarketService = {}

local gameEvent
local lastTeleport = {}
local TELEPORT_COOLDOWN = 1.5

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Market]", ...)
	end
end

function MarketService:Sell(player, kaijuId)
	local data = DataService:Get(player)
	local entry, model = BaseService:GetItem(player, kaijuId)
	if not (data and entry and entry.Kind == "Kaiju") or entry.StolenBy then
		return false
	end
	local price = KaijuStats.SellPrice(entry.Species, entry.Size, entry.Level)
	local position = model and KaijuService:GetPosition(model) or nil
	BaseService:RemoveItem(player, kaijuId)
	data.Stats.KaijuSold = (data.Stats.KaijuSold or 0) + 1
	if price > 0 then
		EconomyService:AddCash(player, price)
	else
		EconomyService:Publish(player)
	end
	DataService:Save(player)
	gameEvent:FireAllClients("KaijuSold", {
		KaijuId = kaijuId,
		OwnerUserId = player.UserId,
		Species = entry.Species,
		Price = price,
		Position = position,
	})
	log(player.Name, "sold", entry.Species, "Lv", entry.Level or 1, "for", price)
	return true
end

local function canTeleport(player)
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < TELEPORT_COOLDOWN then
		return false
	end
	if player:GetAttribute("CarryingEgg") or player:GetAttribute("CarryingStolen") then
		gameEvent:FireClient(player, "CantTeleport", { Reason = "Carrying" })
		return false
	end
	lastTeleport[player] = now
	return true
end

local function teleport(player, cf)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		char:PivotTo(cf + Vector3.new(0, 3, 0))
	end
end

function MarketService:TeleportToShop(player)
	local market = workspace.Map:FindFirstChild("Market")
	local spot = market and market:FindFirstChild("ShopTeleport")
	if spot and canTeleport(player) then
		teleport(player, spot.CFrame)
	end
end

function MarketService:TeleportToBase(player)
	local plot = BaseService:GetPlot(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local safeX = workspace.Map:GetAttribute("SafeZoneX")
	if not (plot and hrp) then
		return
	end
	if safeX and hrp.Position.X >= safeX then
		gameEvent:FireClient(player, "CantTeleport", { Reason = "SafeZone" })
		return
	end
	local mat = plot:FindFirstChild("EntranceMat")
	if mat and canTeleport(player) then
		-- onto the entrance mat (just inside the pen), facing into the pen
		local origin = plot:GetAttribute("PenOrigin") or mat.Position
		local inward = Vector3.new(mat.Position.X - origin.X, 0, mat.Position.Z - origin.Z)
		local pos = mat.Position
		teleport(player, inward.Magnitude > 0.1 and CFrame.lookAt(pos, pos + inward.Unit) or CFrame.new(pos))
	end
end

function MarketService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remotes = ReplicatedStorage.Remotes
	remotes:WaitForChild("SellKaiju").OnServerEvent:Connect(function(player, kaijuId)
		if type(kaijuId) == "string" then
			self:Sell(player, kaijuId)
		end
	end)
	remotes:WaitForChild("TeleportToShop").OnServerEvent:Connect(function(player)
		self:TeleportToShop(player)
	end)
	remotes:WaitForChild("TeleportToBase").OnServerEvent:Connect(function(player)
		self:TeleportToBase(player)
	end)
end

function MarketService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return MarketService
