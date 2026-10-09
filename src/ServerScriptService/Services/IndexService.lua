-- Kaiju Index: which species each player has hatched (the UI's Index panel; Index rewards come in Phase 8).
-- data.Index = { [species] = { Count = times hatched, Best = biggest size, First = os.time of the first } }.
-- Saves from before the Index count the kaiju already in their pen.
-- Player attributes: Index_<Species> = times hatched (nil = not discovered yet), IndexBest_<Species> = biggest size,
--   IndexFound = species discovered, IndexTotal = species in KaijuConfig.
-- GameEvent: KaijuDiscovered {Species, Rarity, Found, Total} the first time a player hatches a species.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local DataService = require(script.Parent.DataService)

local IndexService = {}

local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Index]", ...)
	end
end

local function publish(player, data)
	local found, total = 0, 0
	for species in KaijuConfig do
		total += 1
		local e = data.Index[species]
		player:SetAttribute("Index_" .. species, e and e.Count or nil)
		player:SetAttribute("IndexBest_" .. species, e and e.Best or nil)
		if e then
			found += 1
		end
	end
	player:SetAttribute("IndexFound", found)
	player:SetAttribute("IndexTotal", total)
end

-- Notes a hatch. Returns true the first time this player hatches the species.
function IndexService:Record(player, species, size)
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
	return first
end

function IndexService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
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
