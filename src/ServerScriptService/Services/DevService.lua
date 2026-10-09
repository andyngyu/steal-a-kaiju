-- Studio-only test commands (DevConfig.AdminCommands is forced off in live servers).
-- Chat:         /givecash 1000      /resetdata (wipes your save to a brand-new player, then kicks you)
--               /egg Legendary 2.8  (puts a ready-to-hatch egg in your pen; size optional = random roll)
-- Command bar:  game.ServerStorage.DevHooks.GiveCash:Invoke(<userId or nil for everyone>, 1000)
--               game.ServerStorage.DevHooks.SetTrained:Invoke(<userId or nil>, 0)   -- treadmill bonus
--               game.ServerStorage.DevHooks.SpawnEgg:Invoke(userId, "Epic", 2.1)  -> item id
--               game.ServerStorage.DevHooks.HatchEgg:Invoke(userId, itemId)  -- as if the owner held Hatch
--               game.ServerStorage.DevHooks.PatchData:Invoke(userId, { Cash = 1000, PenLevel = 2, RemoveItems = { id } })
--                 (edits the live save; the pen fence rebuilds for a new level on the next join)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local BaseService = require(script.Parent.BaseService)
local HatchService = require(script.Parent.HatchService)

local DevService = {}

local function giveCash(player, amount)
	amount = tonumber(amount)
	if amount and amount > 0 then
		EconomyService:AddCash(player, math.floor(amount))
		print("[Dev] gave", player.Name, amount, "cash")
	end
end

-- Ready egg of a chosen rarity/size near the middle of the player's pen. Returns its item id or nil.
local function spawnEgg(player, rarityId, size, biomeId)
	for _, r in EggConfig.Rarities do
		if string.lower(r.Id) == string.lower(tostring(rarityId)) then
			rarityId = r.Id
		end
	end
	if not EggConfig.RarityById[rarityId] then
		rarityId = "Common"
	end
	size = tonumber(size) or EggModel.RollSize()
	if not (BaseService:GetPlot(player) and BaseService:HasRoom(player)) then
		warn("[Dev] no plot or pen is full for", player.Name)
		return nil
	end
	local level = PenGeometry.Level(BaseService:GetLevel(player))
	local x, d = BaseService:FindFreeSpot(player, 0, level.Depth / 2, size, rarityId)
	if not x then
		warn("[Dev] no free spot in", player.Name, "pen")
		return nil
	end
	local egg = EggModel.Build(biomeId or "PebblePlains", rarityId, nil, size)
	local id = egg:GetAttribute("EggId")
	if not HatchService:PlaceEgg(player, egg, x, d, nil) then
		egg:Destroy()
		return nil
	end
	local entry = BaseService:GetItem(player, id)
	entry.HatchAt = os.time() -- ready on the next tick
	print("[Dev] egg", rarityId, size, "->", entry.Species, "for", player.Name)
	return id
end

function DevService:Start()
	if not DevConfig.AdminCommands then
		return
	end
	local hooks = Instance.new("Folder")
	hooks.Name = "DevHooks"
	local give = Instance.new("BindableFunction")
	give.Name = "GiveCash"
	give.OnInvoke = function(userId, amount)
		for _, player in Players:GetPlayers() do
			if userId == nil or player.UserId == userId then
				giveCash(player, amount)
			end
		end
		return true
	end
	give.Parent = hooks
	local setTrained = Instance.new("BindableFunction")
	setTrained.Name = "SetTrained"
	setTrained.OnInvoke = function(userId, value)
		for _, player in Players:GetPlayers() do
			if userId == nil or player.UserId == userId then
				SpeedService:SetTrainedForTesting(player, tonumber(value) or 0)
			end
		end
		return true
	end
	setTrained.Parent = hooks
	local spawn = Instance.new("BindableFunction")
	spawn.Name = "SpawnEgg"
	spawn.OnInvoke = function(userId, rarityId, size, biomeId)
		local player = Players:GetPlayerByUserId(userId)
		return player and spawnEgg(player, rarityId, size, biomeId)
	end
	spawn.Parent = hooks
	local hatch = Instance.new("BindableFunction")
	hatch.Name = "HatchEgg"
	hatch.OnInvoke = function(userId, id)
		local player = Players:GetPlayerByUserId(userId)
		local _, egg = BaseService:GetItem(player, id)
		local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (egg and hrp) then
			return false
		end
		hrp.CFrame = CFrame.new(egg.PrimaryPart.Position + Vector3.new(0, 0, egg.PrimaryPart.Size.X / 2 + 4))
		task.wait(0.2)
		HatchService:TryHatch(player, id)
		return true
	end
	hatch.Parent = hooks
	local patchData = Instance.new("BindableFunction")
	patchData.Name = "PatchData"
	patchData.OnInvoke = function(userId, patch)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and DataService:Get(player)
		if not (data and type(patch) == "table") then
			return false
		end
		for _, id in patch.RemoveItems or {} do
			BaseService:RemoveItem(player, id)
		end
		if patch.Cash then
			data.Cash = patch.Cash
		end
		if patch.PenLevel then
			data.Pen.Level = patch.PenLevel
		end
		for stat, delta in patch.StatDeltas or {} do
			data.Stats[stat] = math.max(0, (data.Stats[stat] or 0) + delta)
		end
		DataService:Save(player)
		print("[Dev] patched data for", player.Name)
		return true
	end
	patchData.Parent = hooks
	hooks.Parent = ServerStorage

	local function onPlayer(player)
		player.Chatted:Connect(function(message)
			local amount = message:match("^/givecash%s+(%d+)")
			local eggRarity, eggSize = message:match("^/egg%s+(%a+)%s*([%d%.]*)")
			if amount then
				giveCash(player, amount)
			elseif eggRarity then
				spawnEgg(player, eggRarity, tonumber(eggSize))
			elseif message == "/resetdata" then
				print("[Dev] resetting data for", player.Name)
				DataService:ResetForTesting(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return DevService
