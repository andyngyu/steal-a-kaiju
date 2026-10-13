-- Global leaderboards (all servers, all time). Self-contained: it only READS other systems (player attributes and the
-- kaiju models in workspace.Runtime.Kaiju) and keeps its own data, so no other service depends on it.
--
-- Boards (OrderedDataStore "LB_<Key>_v1", key = UserId):
--   Money      player attribute Cash (current cash)
--   Speed      player attribute Speed (stored x10 so one decimal survives)
--   BestKaiju  highest CashPerSecond of one kaiju you own (best ever)
--   Playtime   total seconds played (tracked here)
--   Streak     days in a row you joined (tracked here, UTC days; also rolls forward at UTC midnight while you're
--              online). It is the same streak the daily rewards use (Services.DailyRewardService: GetStreak).
--   Donations  Robux donated (tracked here, see RecordDonation)
--
-- Own save (DataStore "LeaderboardStats_v1", key "u_<UserId>"): { Playtime, Streak, LastDay, Donated }.
-- Player attributes it sets: Playtime (seconds), Streak, Donated, LeaderboardStatsLoaded.
-- Output for the boards: ReplicatedStorage.LeaderboardData.<Key> (StringValue, JSON { Updated, Rows = { {U, N, V} } }),
-- drawn by StarterGui.KaijuUI.Controllers.LeaderboardController on the boards in workspace.Map.Leaderboards.
--
-- Donations: Roblox allows one ProcessReceipt and GamePassService owns it, so donation products must be registered
-- there; their Grant should call LeaderboardService:RecordDonation(player, robux) and return true.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LeaderboardService = {}

local BOARDS = { "Money", "Speed", "BestKaiju", "Playtime", "Streak", "Donations" }
local TOP = 10
local WRITE_EVERY = 120 -- seconds between each player's score uploads
local REFRESH_EVERY = 90 -- seconds for one full pass over all boards
local MAX_SCORE = 2 ^ 53

-- Donation product IDs (the Donations board's buttons) are in StarterGui.KaijuUI.UIConfig.Leaderboards.Donations.

local statsStore
local ordered = {}
local stats = {} -- [player] = { Playtime, Streak, LastDay, Donated, joinedAt }
local nameCache = {}
local dataFolder

local function today()
	return math.floor(os.time() / 86400)
end

local function retry(fn, tries)
	for i = 1, tries or 3 do
		local ok, a = pcall(fn)
		if ok then
			return true, a
		end
		if i < (tries or 3) then
			task.wait(i * 2)
		else
			warn("[Leaderboards]", a)
		end
	end
	return false, nil
end

local function bestKaiju(player)
	local runtime = workspace:FindFirstChild("Runtime")
	local folder = runtime and runtime:FindFirstChild("Kaiju")
	local best = 0
	if folder then
		for _, model in folder:GetChildren() do
			if model:GetAttribute("OwnerUserId") == player.UserId then
				best = math.max(best, tonumber(model:GetAttribute("CashPerSecond")) or 0)
			end
		end
	end
	return best
end

local function playtime(player)
	local s = stats[player]
	if not s then
		return 0
	end
	return s.Playtime + (os.clock() - s.joinedAt)
end

-- current score per board (whole numbers; Speed is x10)
local function scores(player)
	local s = stats[player]
	return {
		Money = tonumber(player:GetAttribute("Cash")) or 0,
		Speed = (tonumber(player:GetAttribute("Speed")) or 0) * 10,
		BestKaiju = bestKaiju(player),
		Playtime = playtime(player),
		Streak = s and s.Streak or 0,
		Donations = s and s.Donated or 0,
	}
end

-- boards that only ever go up keep the best value ever seen
local KEEP_MAX = { BestKaiju = true, Playtime = true, Donations = true }

local function upload(player)
	if not stats[player] then
		return
	end
	local key = tostring(player.UserId)
	for board, value in scores(player) do
		value = math.clamp(math.floor(value), 0, MAX_SCORE)
		local store = ordered[board]
		if value > 0 and store then
			pcall(function()
				if KEEP_MAX[board] then
					store:UpdateAsync(key, function(old)
						if old and old >= value then
							return nil
						end
						return value
					end)
				else
					store:SetAsync(key, value)
				end
			end)
		end
	end
end

local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.Name
		return p.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	name = ok and name or ("Player " .. userId)
	nameCache[userId] = name
	return name
end

local function refresh(board)
	local store = ordered[board]
	local ok, pages = retry(function()
		return store:GetSortedAsync(false, TOP)
	end, 2)
	if not ok or not pages then
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { U = userId, N = nameOf(userId), V = entry.value })
		end
	end
	dataFolder[board].Value = HttpService:JSONEncode({ Updated = os.time(), Rows = rows })
end

local function save(player, final)
	local s = stats[player]
	if not s then
		return
	end
	local snapshot = {
		Playtime = math.floor(playtime(player)),
		Streak = s.Streak,
		LastDay = s.LastDay,
		Donated = s.Donated,
	}
	retry(function()
		statsStore:UpdateAsync("u_" .. player.UserId, function(old)
			old = old or {}
			-- never lose donations or playtime if another server saved more
			snapshot.Donated = math.max(snapshot.Donated, old.Donated or 0)
			snapshot.Playtime = math.max(snapshot.Playtime, old.Playtime or 0)
			return snapshot
		end)
	end, final and 2 or 3)
end

local function publish(player)
	local s = stats[player]
	if s then
		player:SetAttribute("Playtime", math.floor(playtime(player)))
		player:SetAttribute("Streak", s.Streak)
		player:SetAttribute("Donated", s.Donated)
	end
end

local function onJoin(player)
	local ok, data = retry(function()
		return statsStore:GetAsync("u_" .. player.UserId)
	end)
	if not player.Parent then
		return
	end
	data = (ok and data) or {}
	local day = today()
	local streak = data.Streak or 0
	if data.LastDay == day then
		streak = math.max(streak, 1)
	elseif data.LastDay == day - 1 then
		streak += 1
	else
		streak = 1
	end
	stats[player] = {
		Playtime = data.Playtime or 0,
		Streak = streak,
		LastDay = day,
		Donated = data.Donated or 0,
		joinedAt = os.clock(),
	}
	publish(player)
	player:SetAttribute("LeaderboardStatsLoaded", true)
	save(player)
end

local function onLeave(player)
	if stats[player] then
		save(player, true)
		upload(player)
		stats[player] = nil
	end
end

-- A new UTC day began while the player was online: the streak goes on (or restarts if a day was somehow skipped).
local function rollDay(player)
	local s = stats[player]
	local day = today()
	if not s or s.LastDay == day then
		return false
	end
	s.Streak = s.LastDay == day - 1 and s.Streak + 1 or 1
	s.LastDay = day
	publish(player)
	task.spawn(save, player)
	return true
end

-- The player's day streak (the Streak board's value; the daily rewards' streak bonus reads it). nil until loaded.
function LeaderboardService:GetStreak(player)
	rollDay(player)
	local s = stats[player]
	return s and s.Streak or nil
end

-- Call from the donation products' Grant (GamePassService). Returns true so the receipt can be granted.
function LeaderboardService:RecordDonation(player, robux)
	local s = stats[player]
	if not s then
		return false
	end
	s.Donated += math.max(0, math.floor(robux))
	publish(player)
	task.spawn(save, player)
	task.spawn(upload, player)
	return true
end

-- Uploads and refreshes right away (used for testing in Studio).
function LeaderboardService:ForceRefresh()
	for _, p in Players:GetPlayers() do
		upload(p)
	end
	for _, board in BOARDS do
		refresh(board)
	end
end

function LeaderboardService:Init()
	dataFolder = ReplicatedStorage:FindFirstChild("LeaderboardData") or Instance.new("Folder")
	dataFolder.Name = "LeaderboardData"
	for _, board in BOARDS do
		local v = dataFolder:FindFirstChild(board) or Instance.new("StringValue")
		v.Name = board
		v.Value = v.Value ~= "" and v.Value or '{"Rows":[]}'
		v.Parent = dataFolder
	end
	dataFolder.Parent = ReplicatedStorage
end

function LeaderboardService:Start()
	local ok = pcall(function()
		statsStore = DataStoreService:GetDataStore("LeaderboardStats_v1")
		for _, board in BOARDS do
			ordered[board] = DataStoreService:GetOrderedDataStore("LB_" .. board .. "_v1")
		end
	end)
	if not ok then
		warn("[Leaderboards] DataStores unavailable (in Studio: Game Settings > Security > Enable Studio Access to API Services)")
		return
	end

	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
	game:BindToClose(function()
		local waiting = 0
		for _, p in Players:GetPlayers() do
			waiting += 1
			task.spawn(function()
				onLeave(p)
				waiting -= 1
			end)
		end
		local t = os.clock()
		while waiting > 0 and os.clock() - t < 20 do
			task.wait(0.2)
		end
	end)

	-- live playtime attribute
	task.spawn(function()
		while true do
			task.wait(15)
			for p in stats do
				if not rollDay(p) then
					publish(p)
				end
			end
		end
	end)

	-- uploads + saves, spread over time
	task.spawn(function()
		task.wait(20)
		while true do
			local list = Players:GetPlayers()
			local gap = math.max(1, WRITE_EVERY / math.max(#list, 1))
			for _, p in list do
				if p.Parent and stats[p] then
					task.spawn(upload, p)
					task.spawn(save, p)
				end
				task.wait(gap)
			end
			if #list == 0 then
				task.wait(WRITE_EVERY)
			end
		end
	end)

	-- board refresh, one board at a time
	task.spawn(function()
		task.wait(RunService:IsStudio() and 25 or 30)
		while true do
			for _, board in BOARDS do
				refresh(board)
				task.wait(REFRESH_EVERY / #BOARDS)
			end
		end
	end)
end

return LeaderboardService
