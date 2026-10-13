-- Kaiju Index: which species each player has hatched (the UI's Index panel) and the Index rewards.
-- data.Index = { [species] = { Count = times hatched, Best = biggest size, First = os.time of the first,
--   Claimed = true once its reward was taken } }; data.IndexAreas = { [areaId] = true } for completed areas.
-- Rewards (Shared.Config.IndexConfig): each discovered species can be claimed once for Cash + Speed; claiming every
-- species of an area multiplies cash income by AreaCashMultiplier, stacking per area (player attribute IndexCashBonus,
-- used by EconomyService).
-- Remote ClaimIndex (kind, arg): ("One", species) or ("Area", areaId) = claim everything claimable in that area.
-- GameEvents: IndexClaimed {Count, Cash, Speed}, IndexAreaComplete {Area, Bonus, Total}.
-- Saves from before the Index count the kaiju already in their pen.
-- Player attributes: Index_<Species> = times hatched (nil = not discovered yet), IndexBest_<Species> = biggest size,
--   IndexClaimed_<Species> = true once claimed, IndexMut_<Species> = "Golden,Shocked" mutated variants found, IndexArea_<Area> = true once completed, IndexCashBonus (cash
--   multiplier: 1.5 per completed area, stacking), IndexClaimable = rewards waiting, IndexFound = species discovered, IndexTotal = species in KaijuConfig.
-- GameEvent: KaijuDiscovered {Species, Rarity, Found, Total} the first time a player hatches a species.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local IndexConfig = require(ReplicatedStorage.Shared.Config.IndexConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SpeedService = require(script.Parent.SpeedService)

local IndexService = {}

local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Index]", ...)
	end
end

local function areaComplete(data, area)
	for species, cfg in KaijuConfig do
		if IndexConfig.AreaOf(cfg) == area then
			local e = data.Index[species]
			if not (e and e.Claimed) then
				return false
			end
		end
	end
	return true
end

local function publish(player, data)
	data.IndexAreas = data.IndexAreas or {}
	local found, total, claimable = 0, 0, 0
	local areas = {}
	for species, cfg in KaijuConfig do
		total += 1
		local e = data.Index[species]
		player:SetAttribute("Index_" .. species, e and e.Count or nil)
		player:SetAttribute("IndexBest_" .. species, e and e.Best or nil)
		player:SetAttribute("IndexClaimed_" .. species, (e and e.Claimed) or nil)
		local muts = {}
		for id in (e and e.Mutations) or {} do
			table.insert(muts, id)
		end
		table.sort(muts)
		player:SetAttribute("IndexMut_" .. species, #muts > 0 and table.concat(muts, ",") or nil)
		if e then
			found += 1
			if not e.Claimed then
				claimable += 1
			end
		end
		areas[IndexConfig.AreaOf(cfg)] = true
	end
	local done = 0
	for area in areas do
		local complete = data.IndexAreas[area] == true
		player:SetAttribute("IndexArea_" .. area, complete or nil)
		if complete then
			done += 1
		end
	end
	player:SetAttribute("IndexFound", found)
	player:SetAttribute("IndexTotal", total)
	player:SetAttribute("IndexClaimable", claimable)
	player:SetAttribute("IndexCashBonus", IndexConfig.AreaCashMultiplier ^ done)
end

-- Claims the given species (already discovered, not yet claimed). Grants Cash + Speed, completes areas.
local function claim(player, list)
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.IndexAreas = data.IndexAreas or {}
	local cash, speed, count = 0, 0, 0
	local touched = {}
	for _, species in list do
		local cfg = KaijuConfig[species]
		local e = data.Index[species]
		if cfg and e and not e.Claimed then
			e.Claimed = true
			local rarity = EggConfig.RarityById[cfg.Rarity]
			local c, sp = IndexConfig.Reward(cfg, rarity and rarity.Order or 1)
			cash += c
			speed += sp
			count += 1
			touched[IndexConfig.AreaOf(cfg)] = true
		end
	end
	if count == 0 then
		return
	end
	if cash > 0 then
		EconomyService:AddCash(player, cash)
	end
	if speed > 0 then
		SpeedService:AddSpeed(player, speed)
	end
	local completed = {}
	for area in touched do
		if not data.IndexAreas[area] and areaComplete(data, area) then
			data.IndexAreas[area] = true
			table.insert(completed, area)
		end
	end
	publish(player, data)
	EconomyService:Publish(player) -- CashPerSecond includes the area bonus
	DataService:Save(player)
	gameEvent:FireClient(player, "IndexClaimed", { Count = count, Cash = cash, Speed = speed })
	for _, area in completed do
		gameEvent:FireClient(player, "IndexAreaComplete", { Area = area, Multiplier = IndexConfig.AreaCashMultiplier, Total = player:GetAttribute("IndexCashBonus") })
		log(player.Name, "completed area", area)
	end
end

-- Notes a hatch. Returns true the first time this player hatches the species. mutation (optional) = a weather
-- mutation it hatched with: the Index remembers every mutated variant found (e.Mutations[id] = true).
function IndexService:Record(player, species, size, mutation)
	local data = DataService:Get(player)
	if not (data and KaijuConfig[species]) then
		return false
	end
	local e = data.Index[species]
	local first = e == nil
	if first then
		e = { Count = 0, Best = 0, First = os.time() }
		data.Index[species] = e
	end
	e.Count += 1
	e.Best = math.max(e.Best or 0, size or 1)
	local newVariant = false
	if type(mutation) == "string" and mutation ~= "" then
		e.Mutations = e.Mutations or {}
		newVariant = not e.Mutations[mutation]
		e.Mutations[mutation] = true
	end
	publish(player, data)
	if first then
		gameEvent:FireClient(player, "KaijuDiscovered", {
			Species = species,
			Rarity = KaijuConfig[species].Rarity,
			Found = player:GetAttribute("IndexFound"),
			Total = player:GetAttribute("IndexTotal"),
		})
		log(player.Name, "discovered", species)
	end
	if newVariant then
		gameEvent:FireClient(player, "MutationDiscovered", { Species = species, Mutation = mutation })
	end
	return first
end

function IndexService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local last = {}
	ReplicatedStorage.Remotes:WaitForChild("ClaimIndex").OnServerEvent:Connect(function(player, kind, arg)
		if os.clock() - (last[player] or 0) < 0.25 or type(arg) ~= "string" then
			return
		end
		last[player] = os.clock()
		if kind == "One" and KaijuConfig[arg] then
			claim(player, { arg })
		elseif kind == "Area" then
			local list = {}
			for species, cfg in KaijuConfig do
				if IndexConfig.AreaOf(cfg) == arg then
					table.insert(list, species)
				end
			end
			claim(player, list)
		end
	end)
end

function IndexService:Start()
	DataService:OnLoaded(function(player, data)
		-- saves from before the Index: count the kaiju already in the pen
		for _, entry in data.Pen.Items do
			if entry.Kind == "Kaiju" and KaijuConfig[entry.Species] and not data.Index[entry.Species] then
				data.Index[entry.Species] = { Count = 1, Best = entry.Size or 1, First = entry.HatchedAt or os.time() }
			end
		end
		for species in data.Index do
			if not KaijuConfig[species] then
				data.Index[species] = nil
			end
		end
		publish(player, data)
	end)
end

return IndexService
