-- Studio-only test commands (DevConfig.AdminCommands is forced off in live servers).
-- Wipe command (Studio, and in live servers for the game's owner only - the creator, or rank 255 of the owning group):
--   /wipedata confirm                 wipe your own save (you're kicked and start fresh on rejoin)
--   /wipedata <name> confirm          wipe a player in this server (name or display name, partial is fine)
--   /wipedata <userId> confirm        wipe a player who's offline (deletes their save)
--   Without "confirm" it only tells you what it would do. Alias: /wipe
-- Chat:         /givecash 1000      /resetdata (wipes your save to a brand-new player, then kicks you)
--               /egg Legendary 2.8  (puts a ready-to-hatch egg in your pen; size optional = random roll)
--               /showcase [Species ...] [size]   (every species, or the ones named, wandering in your pen;
--               display only: not saved, no income)      /showcase clear
-- Command bar:  game.ServerStorage.DevHooks.GiveCash:Invoke(<userId or nil for everyone>, 1000)
--               game.ServerStorage.DevHooks.SetTrained:Invoke(<userId or nil>, 0)   -- treadmill bonus
--               game.ServerStorage.DevHooks.SpawnEgg:Invoke(userId, "Epic", 2.1)  -> item id
--               game.ServerStorage.DevHooks.HatchEgg:Invoke(userId, itemId)  -- as if the owner held Hatch
--               game.ServerStorage.DevHooks.Showcase:Invoke(userId, { "Rumblerex", "2" })   or (userId, "clear")
--               game.ServerStorage.DevHooks.Snapshot:Invoke(userId) / Restore:Invoke(userId)
--                 (copy the save before a test and put it back after; stop the playtest right after Restore)
--               game.ServerStorage.DevHooks.PatchData:Invoke(userId, { Cash = 1000, CashDelta = -50, PenLevel = 2,
--                 TreadmillLevel = 0, RemoveItems = { id }, AddItems = { [id] = entry }, Food = {...}, SelectedFood = "", Trails = {...},
--                 StatDeltas = { KaijuSold = -1 } })
--                 (edits the live save; pen changes show on the next join)
--               game.ServerStorage.DevHooks.Call:Invoke(userId, "HatchService", "GiveEgg", "PebblePlains", "Rare")
--                 -> whatever Services.<name>:<method>(player, ...) returns (the command bar's require() gets
--                 separate module copies, so server APIs are tested through this)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local BaseService = require(script.Parent.BaseService)
local HatchService = require(script.Parent.HatchService)
local KaijuService = require(script.Parent.KaijuService)

local DevService = {}

local TextChatService = game:GetService("TextChatService")

-- Who may wipe saves: anyone in Studio (with AdminCommands on); in live servers only the game's owner.
local function canWipe(player)
	if DevConfig.AdminCommands then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 255
end

local function notify(player, text, kind)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local gameEvent = remotes and remotes:FindFirstChild("GameEvent")
	if gameEvent and player.Parent == Players then
		gameEvent:FireClient(player, "DevNotice", { Text = text, Kind = kind })
	end
	print("[Dev]", player.Name, "-", text)
end

local function findPlayer(query)
	query = string.lower(query)
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == query or string.lower(p.DisplayName) == query then
			return p
		end
	end
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name):sub(1, #query) == query or string.lower(p.DisplayName):sub(1, #query) == query then
			return p
		end
	end
	return nil
end

local function wipeCommand(caller, args)
	if not canWipe(caller) then
		return
	end
	local last = args[#args]
	local confirmed = last ~= nil and string.lower(last) == "confirm"
	if confirmed then
		table.remove(args, #args)
	end
	local targetText = args[1]
	local target = nil
	local offlineId = nil
	if targetText == nil then
		target = caller
	else
		target = findPlayer(targetText)
		if not target then
			offlineId = tonumber(targetText)
			if offlineId then
				target = Players:GetPlayerByUserId(offlineId)
				if target then
					offlineId = nil
				end
			end
		end
	end
	if not target and not offlineId then
		notify(caller, "No player called \"" .. tostring(targetText) .. "\" here. Use their user id to wipe someone offline.", "warn")
		return
	end
	local who = target and (target == caller and "your" or (target.Name .. "'s")) or ("user " .. offlineId .. "'s")
	if not confirmed then
		notify(caller, "This wipes " .. who .. " save for good. Type the same command with \"confirm\" at the end to do it.", "warn")
		return
	end
	if target then
		print("[Dev]", caller.Name, "wiped the data of", target.Name, target.UserId)
		if target ~= caller then
			notify(caller, "Wiped " .. target.Name .. "'s data.", "info")
		end
		DataService:Wipe(target, target == caller and "Your data was wiped. Rejoin to start fresh."
			or "Your data was reset by the game's owner. Rejoin to start fresh.")
	else
		local ok, err = DataService:WipeOffline(offlineId)
		if ok then
			notify(caller, "Deleted the save of user " .. offlineId .. ".", "info")
		else
			notify(caller, "Couldn't delete user " .. offlineId .. "'s save" .. (err and (": " .. tostring(err)) or " (are they in another server?)"), "error")
		end
	end
end

local function setupWipeCommand()
	local command = Instance.new("TextChatCommand")
	command.Name = "WipeDataCommand"
	command.PrimaryAlias = "/wipedata"
	command.SecondaryAlias = "/wipe"
	command.Triggered:Connect(function(textSource, message)
		local caller = textSource and Players:GetPlayerByUserId(textSource.UserId)
		if not caller then
			return
		end
		local args = string.split(message, " ")
		table.remove(args, 1) -- the alias itself
		for i = #args, 1, -1 do
			if args[i] == "" then
				table.remove(args, i)
			end
		end
		task.spawn(wipeCommand, caller, args)
	end)
	command.Parent = TextChatService
end

local function giveCash(player, amount)
	amount = tonumber(amount)
	if amount and amount > 0 then
		EconomyService:AddCash(player, math.floor(amount))
		print("[Dev] gave", player.Name, amount, "cash")
	end
end

-- Display-only kaiju (not in the save, no income) for looking at models and animations.
local showcase = {} -- [player] = { models }

local function clearShowcase(player)
	for _, model in showcase[player] or {} do
		model:Destroy()
	end
	showcase[player] = nil
end

local function spawnShowcase(player, words)
	clearShowcase(player)
	if not BaseService:GetPlot(player) then
		return
	end
	local list, size = {}, 1
	for _, word in words do
		if tonumber(word) then
			size = tonumber(word)
		else
			for id in KaijuConfig do
				if string.lower(id) == string.lower(word) then
					table.insert(list, id)
				end
			end
		end
	end
	if #list == 0 then
		for id in KaijuConfig do
			table.insert(list, id)
		end
		table.sort(list, function(a, b)
			local ra, rb = EggConfig.RarityById[KaijuConfig[a].Rarity].Order, EggConfig.RarityById[KaijuConfig[b].Rarity].Order
			return ra == rb and a < b or ra < rb
		end)
	end
	showcase[player] = {}
	for i, species in list do
		local spot = BaseService:RandomSpot(player, 5)
		local model = KaijuService:Spawn(player, "Showcase" .. i, { Species = species, Size = size }, spot, false)
		model:SetAttribute("Showcase", true)
		table.insert(showcase[player], model)
	end
	print("[Dev] showcase of", #list, "kaiju for", player.Name)
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
	setupWipeCommand() -- also in live servers, but only the game's owner can use it
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
		for id, entry in patch.AddItems or {} do
			data.Pen.Items[id] = entry
		end
		if patch.Cash then
			data.Cash = patch.Cash
		end
		if patch.CashDelta then
			data.Cash = math.max(0, data.Cash + patch.CashDelta)
		end
		if patch.Food then
			data.Food = patch.Food
		end
		if patch.SelectedFood then
			data.SelectedFood = patch.SelectedFood
		end
		if patch.Trails then
			data.Trails = patch.Trails
		end
		if patch.PenLevel then
			data.Pen.Level = patch.PenLevel
		end
		if patch.TreadmillLevel then
			data.Treadmill.Level = patch.TreadmillLevel
		end
		for stat, delta in patch.StatDeltas or {} do
			data.Stats[stat] = math.max(0, (data.Stats[stat] or 0) + delta)
		end
		DataService:Save(player)
		print("[Dev] patched data for", player.Name)
		return true
	end
	patchData.Parent = hooks
	local showcaseHook = Instance.new("BindableFunction")
	showcaseHook.Name = "Showcase"
	showcaseHook.OnInvoke = function(userId, words)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			if words == "clear" then
				clearShowcase(player)
			else
				spawnShowcase(player, words or {})
			end
		end
		return true
	end
	showcaseHook.Parent = hooks
	local snapshots = {}
	local function deepCopy(t)
		local c = {}
		for k, v in t do
			c[k] = type(v) == "table" and deepCopy(v) or v
		end
		return c
	end
	local snapshotHook = Instance.new("BindableFunction")
	snapshotHook.Name = "Snapshot"
	snapshotHook.OnInvoke = function(userId)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and DataService:Get(player)
		if not data then
			return false
		end
		snapshots[userId] = deepCopy(data)
		return true
	end
	snapshotHook.Parent = hooks
	local restoreHook = Instance.new("BindableFunction")
	restoreHook.Name = "Restore"
	restoreHook.OnInvoke = function(userId)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and DataService:Get(player)
		local snap = snapshots[userId]
		if not (data and snap) then
			return false
		end
		for k in data do
			data[k] = nil
		end
		for k, v in deepCopy(snap) do
			data[k] = v
		end
		DataService:Save(player)
		print("[Dev] restored the snapshot for", player.Name)
		return true
	end
	restoreHook.Parent = hooks
	local call = Instance.new("BindableFunction")
	call.Name = "Call"
	call.OnInvoke = function(userId, serviceName, method, ...)
		local player = Players:GetPlayerByUserId(userId)
		local module = script.Parent:FindFirstChild(tostring(serviceName))
		if not (player and module and module:IsA("ModuleScript")) then
			return nil
		end
		local service = require(module)
		if type(service[method]) ~= "function" then
			return nil
		end
		return service[method](service, player, ...)
	end
	call.Parent = hooks
	hooks.Parent = ServerStorage

	local function onPlayer(player)
		player.Chatted:Connect(function(message)
			local amount = message:match("^/givecash%s+(%d+)")
			local eggRarity, eggSize = message:match("^/egg%s+(%a+)%s*([%d%.]*)")
			if amount then
				giveCash(player, amount)
			elseif eggRarity then
				spawnEgg(player, eggRarity, tonumber(eggSize))
			elseif message == "/showcase clear" then
				clearShowcase(player)
			elseif message:match("^/showcase") then
				local words = string.split(message, " ")
				table.remove(words, 1)
				spawnShowcase(player, words)
			elseif message == "/resetdata" then
				print("[Dev] resetting data for", player.Name)
				DataService:ResetForTesting(player)
			end
		end)
	end
	Players.PlayerRemoving:Connect(clearShowcase)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return DevService
