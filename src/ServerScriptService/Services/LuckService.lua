-- Luck stat. Combines every luck source into one multiplier and publishes it as the player attribute Luck (1 = normal),
-- which the HUD shows and the server's RNG reads (Shared.Config.LuckConfig lists where).
-- Sources today: EggLuckMultiplier (game passes + timed Luck boosts, set by GamePassService; a timed boost counts only
-- until EggLuckUntil). Add more (group bonus, weather, rebirths...) with LuckService:SetSource(player, name, multiplier).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LuckConfig = require(ReplicatedStorage.Shared.Config.LuckConfig)
local Luck = require(ReplicatedStorage.Shared.Util.Luck)

local LuckService = {}

local sources = {} -- [player] = { [name] = multiplier }
local rng = Random.new()

local function passLuck(player)
	local mult = player:GetAttribute("EggLuckMultiplier")
	if type(mult) ~= "number" or mult <= 0 then
		return 1
	end
	return mult
end

local function recompute(player)
	local luck = LuckConfig.Base * passLuck(player)
	for _, mult in sources[player] or {} do
		luck *= mult
	end
	luck = Luck.Clamp(luck)
	luck = math.floor(luck * 1000 + 0.5) / 1000
	if player:GetAttribute("Luck") ~= luck then
		player:SetAttribute("Luck", luck)
	end
	return luck
end

-- The player's current Luck (1 = normal).
function LuckService:Get(player)
	local luck = player:GetAttribute("Luck")
	return type(luck) == "number" and luck or recompute(player)
end

-- Adds, changes or (multiplier nil / 1) removes a named luck source, e.g. ("GroupBonus", 1.1) or ("Storm", 1.5).
function LuckService:SetSource(player, name, multiplier)
	sources[player] = sources[player] or {}
	sources[player][name] = (type(multiplier) == "number" and multiplier ~= 1) and multiplier or nil
	recompute(player)
end

-- For the weather mutation events: does a mutation with base chance `baseChance` hit this player? (Luck applied)
function LuckService:RollMutation(player, baseChance)
	return Luck.RollMutation(rng, baseChance, self:Get(player))
end

-- The hatched rarity for one of this player's eggs (Luck applied). See Shared.Util.Luck.HatchOdds.
function LuckService:RollHatchRarity(player, biomeId, eggRarity)
	return Luck.RollHatchRarity(rng, biomeId, eggRarity, self:Get(player))
end

function LuckService:Start()
	local function watch(player)
		sources[player] = sources[player] or {}
		for _, attr in { "EggLuckMultiplier", "EggLuckUntil" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				recompute(player)
			end)
		end
		recompute(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sources[player] = nil
	end)
	-- a timed boost ending (GamePassService refreshes the multiplier; this catches any gap)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			recompute(player)
		end
	end)
end

return LuckService
