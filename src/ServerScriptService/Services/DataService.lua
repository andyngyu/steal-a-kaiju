-- Player data via ProfileStore (session-locked). Other services read/write DataService:Get(player) and call :Save() after
-- important changes. ProfileStore also auto-saves periodically and on leave/shutdown.
-- Player attribute: DataLoaded = true once the profile is ready.
--
-- Data shape (string keys only - ProfileStore can't store gappy arrays):
--   Cash, TotalEarned, LastOnline (os.time)
--   Speed = { Trained (treadmill bonus), Level (bought upgrades) }
--   Treadmill = { Level } (0 = locked)
--   Pen = { Level, Items = { [id] = { Kind = "Egg", EggId, BiomeId, Rarity, Species, PlacedAt, HatchAt, X, D, Size }
--                                | { Kind = "Kaiju", KaijuId, Species, Rarity, BiomeId, HatchedAt, Size, Level, XP } } }
--     (X, D are pen-local, see Shared.Util.PenGeometry; kaiju wander so their position isn't saved;
--      Level/XP are missing on kaiju from before levels existed = level 1, 0 XP)
--   Food = { [foodId] = count }, SelectedFood = held foodId or "" (empty hands)
--   FoodStock = { Cycle = restock number, Bought = { [foodId] = count bought this restock } }
--   Index = { [species] = { Count, Best, First } } (Kaiju Index, IndexService)
--   Trails = { Owned = { [trailId] = true }, Equipped = trailId or "" }
--   Stats = { EggsDelivered, EggsHatched, KaijuSold, FoodFed }
--   Store = { Purchases = { [purchaseId] = os.time }, LuckUntil, Passes = { [itemId] = true } } - created lazily and
--     owned by GamePassService (receipts, timed luck, owned-pass cache); not in TEMPLATE
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ServerScriptService.Lib.ProfileStore)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local STORE_NAME = "PlayerData_v1"
local SAVE_THROTTLE_SECONDS = 15

local TEMPLATE = {
	Cash = EconomyConfig.StartingCash,
	TotalEarned = 0,
	Speed = {
		Trained = 0,
		Level = 0,
	},
	Treadmill = {
		Level = 0,
	},
	LastOnline = 0,
	Pen = {
		Level = 1,
		Items = {},
	},
	Food = {},
	SelectedFood = "",
	FoodStock = {
		Cycle = 0,
		Bought = {},
	},
	Index = {},
	Trails = {
		Owned = {},
		Equipped = "",
	},
	Stats = {
		EggsDelivered = 0,
		EggsHatched = 0,
		KaijuSold = 0,
		FoodFed = 0,
	},
}

local DataService = {}

local store
local profiles = {} -- [player] = profile
local loadedCallbacks = {}
local lastSave = {}
local pendingSave = {}

local function load(player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("Couldn't load your data. Please rejoin.")
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.Data.Pads = nil -- pre-pen format (pads were removed)
	if profile.Data.PendingCash then -- collect pad was removed; cash is now earned straight into Cash
		profile.Data.Cash += math.floor(profile.Data.PendingCash)
		profile.Data.PendingCash = nil
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	for _, fn in loadedCallbacks do
		task.spawn(fn, player, profile.Data)
	end
end

function DataService:Init()
	store = ProfileStore.New(STORE_NAME, TEMPLATE)
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		profiles[player] = nil
		lastSave[player] = nil
		pendingSave[player] = nil
		if profile then
			profile.Data.LastOnline = os.time()
			profile:EndSession()
		end
	end)
end

-- Returns the player's data table, or nil if it isn't loaded (yet).
function DataService:Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:IsLoaded(player)
	return profiles[player] ~= nil
end

-- Read-only look at any player's saved data, online or not (no session lock; yields). The live table for a player in
-- this server, otherwise a snapshot of their last save - don't write to it. nil if they have no save or it fails.
-- Used by ChampionService to show the richest player's best kaiju while they're offline.
function DataService:ViewAsync(userId)
	local online = Players:GetPlayerByUserId(userId)
	if online and profiles[online] then
		return profiles[online].Data
	end
	if not store then
		return nil
	end
	local ok, profile = pcall(function()
		return store:GetAsync("Player_" .. userId)
	end)
	return ok and profile and profile.Data or nil
end

-- fn(player, data) runs for every player whose profile loads, including ones already loaded.
function DataService:OnLoaded(fn)
	table.insert(loadedCallbacks, fn)
	for player, profile in profiles do
		task.spawn(fn, player, profile.Data)
	end
end

-- Wipes an online player's save back to a brand-new player (TEMPLATE), saves it and kicks them so they rejoin
-- fresh. DevService's /wipedata command guards who may call it. Returns true when wiped.
function DataService:Wipe(player, kickMessage)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data
	for k in data do
		data[k] = nil
	end
	local function deepCopy(t)
		local c = {}
		for k, v in t do
			c[k] = type(v) == "table" and deepCopy(v) or v
		end
		return c
	end
	for k, v in deepCopy(TEMPLATE) do
		data[k] = v
	end
	profile:Save()
	player:Kick(kickMessage or "Your data was wiped. Rejoin to start fresh.")
	return true
end

-- Deletes the save of a player who isn't in this server (by user id). They start fresh next time they join.
-- Fails (returns false) if their profile is open on another server; wipe them there instead. Yields.
function DataService:WipeOffline(userId)
	local ok, result = pcall(function()
		return store:RemoveAsync("Player_" .. tostring(userId))
	end)
	return ok and result ~= false, ok and nil or result
end

-- Studio testing only (DevService guards it): wipes the profile back to the template and kicks the player to rejoin.
function DataService:ResetForTesting(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data
	for k in data do
		data[k] = nil
	end
	local function deepCopy(t)
		local c = {}
		for k, v in t do
			c[k] = type(v) == "table" and deepCopy(v) or v
		end
		return c
	end
	for k, v in deepCopy(TEMPLATE) do
		data[k] = v
	end
	profile:Save()
	player:Kick("Test data reset. Start the playtest again for a fresh save.")
	return true
end

-- Writes right now and waits for the write to finish (dev product receipts must be stored before returning
-- PurchaseGranted). Returns true once saved, false if the profile isn't active or it timed out.
function DataService:SaveNow(player, timeoutSeconds)
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return false
	end
	local saved = false
	local conn = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()
	local t0 = os.clock()
	while not saved and profile:IsActive() and os.clock() - t0 < (timeoutSeconds or 20) do
		task.wait(0.1)
	end
	conn:Disconnect()
	lastSave[player] = os.clock()
	return saved
end

-- Saves soon after an important change; throttled so bursts collapse into one write.
function DataService:Save(player)
	local profile = profiles[player]
	if not profile or pendingSave[player] then
		return
	end
	local wait = SAVE_THROTTLE_SECONDS - (os.clock() - (lastSave[player] or 0))
	pendingSave[player] = true
	task.delay(math.max(0, wait), function()
		pendingSave[player] = nil
		local p = profiles[player]
		if p and p:IsActive() then
			lastSave[player] = os.clock()
			p:Save()
		end
	end)
end

return DataService
