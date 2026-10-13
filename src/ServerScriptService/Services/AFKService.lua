-- Anti-AFK: players idle for a random 15-18 minutes (Shared.Config.AFKConfig) are moved to another public server and
-- put back on their treadmill there, so idling keeps training instead of ending in Roblox's idle kick.
--   activity  the client (KaijuUI AFKController) reports input with Remotes.AFK:FireServer("Active"), at most every
--             ActivePingSeconds (at once while the warning shows), and Roblox's own idle clock: Player.Idled ->
--             Remotes.AFK:FireServer("Idled", seconds). Idle time = the larger of the two, so the move always comes
--             before Roblox's 20 minute idle kick even if some input slipped past the client's own tracking.
--   warning   WarnSeconds before the move: GameEvent AFKWarning {Seconds}; any input sends "Active" and cancels it
--             (GameEvent AFKCancelled).
--   move      GameEvent AFKRejoining, the save is written (DataService:SaveNow), then TeleportService:TeleportAsync to a
--             different live server with room (servers list themselves in a MemoryStore sorted map every
--             RefreshSeconds), or any server Roblox picks when none is listed / that one is full.
--             TeleportData { AFKRejoin = true, FromJobId }.
--   arrival   a player who joined with AFKRejoin (teleported from this game) gets attribute AFKMode and, once their
--             base and treadmill are ready, TreadmillService:BeginRun; GameEvent AFKArrived {OnTreadmill}. Their first
--             input clears AFKMode. Still idle? The next random timer moves them again.
-- Not in private / reserved servers (there's no other public server to move to) and not in Studio (no teleports;
--   AFKConfig.StudioIdleSeconds runs the warning flow with a short timer and stops before teleporting).
-- Player attributes: AFKMode (arrived while AFK), AFKMoveAt (server time the move happens, while the warning shows).
-- Command bar: game.ServerStorage.DevHooks.Call:Invoke(userId, "AFKService", "SimulateArrival")   (treadmill autostart)
--              game.ServerStorage.DevHooks.Call:Invoke(userId, "AFKService", "SetIdleSeconds", 20)  (short timer)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

local AFKConfig = require(ReplicatedStorage.Shared.Config.AFKConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local TreadmillService = require(script.Parent.TreadmillService)

local AFKService = {}

local rng = Random.new()
local gameEvent
local state = {} -- [player] = { last = os.clock() of the last activity, limit = idle seconds, warned, moving }
local isStudio = RunService:IsStudio()
local canTeleport = not isStudio and game.PrivateServerId == "" and game.JobId ~= ""
local serverMap

local function log(...)
	if DevConfig.VerboseLogging then
		print("[AFK]", ...)
	end
end

local function rollLimit()
	if isStudio and (AFKConfig.StudioIdleSeconds or 0) > 0 then
		return AFKConfig.StudioIdleSeconds
	end
	return rng:NextNumber(AFKConfig.IdleSeconds[1], AFKConfig.IdleSeconds[2])
end

local RETRY_SECONDS = 15 -- a failed move is tried again this soon (not after another 15 minutes: the idle kick is close)

-- Seconds this player has been idle: our own input clock, or Roblox's (Player.Idled reports), whichever is longer.
local function idleSeconds(s, now)
	local idle = now - s.last
	if s.robloxAt and now - s.robloxAt < 75 then -- Idled repeats about every 30 s while Roblox counts them idle
		idle = math.max(idle, s.robloxIdle + (now - s.robloxAt))
	end
	return idle
end

local function reset(player)
	local s = state[player]
	if not s then
		return
	end
	s.last = os.clock()
	s.robloxAt, s.robloxIdle = nil, nil
	s.retryAt = nil
	s.limit = rollLimit()
	if s.warned and not s.moving then
		s.warned = false
		player:SetAttribute("AFKMoveAt", nil)
		gameEvent:FireClient(player, "AFKCancelled", {})
	end
end

---------------------------------------------------------------- the server list
local function listSelf()
	if not serverMap then
		return
	end
	local value = HttpService:JSONEncode({ Players = #Players:GetPlayers(), Max = Players.MaxPlayers, Place = game.PlaceId })
	local ok, err = pcall(function()
		-- sort key: fuller servers first (so AFK players land somewhere lively), then the job id
		serverMap:SetAsync(game.JobId, value, AFKConfig.ServerList.ExpirySeconds, -#Players:GetPlayers())
	end)
	if not ok then
		log("couldn't list this server:", err)
	end
end

local function unlistSelf()
	if serverMap then
		pcall(function()
			serverMap:RemoveAsync(game.JobId)
		end)
	end
end

-- A different live server of this place with room for one more, or nil.
local function pickServer()
	if not serverMap then
		return nil
	end
	local ok, items = pcall(function()
		return serverMap:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or type(items) ~= "table" then
		return nil
	end
	local choices = {}
	for _, item in items do
		local okDecode, info = pcall(HttpService.JSONDecode, HttpService, item.value)
		if item.key ~= game.JobId and okDecode and type(info) == "table" and info.Place == game.PlaceId then
			local free = (info.Max or 0) - (info.Players or 0)
			if free > AFKConfig.ServerList.KeepFreeSlots then
				table.insert(choices, item.key)
			end
		end
	end
	if #choices == 0 then
		return nil
	end
	-- mostly the fullest, sometimes one of the next few, so a crowd of AFK players spreads out
	return choices[rng:NextInteger(1, math.min(3, #choices))]
end

---------------------------------------------------------------- moving
local function teleport(player, jobId)
	local options = Instance.new("TeleportOptions")
	if jobId then
		options.ServerInstanceId = jobId
	end
	options:SetTeleportData({ AFKRejoin = true, FromJobId = game.JobId })
	return pcall(function()
		return TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
end

local function move(player)
	local s = state[player]
	if not s or s.moving then
		return
	end
	s.moving = true
	if not canTeleport then
		-- Studio / private server: nothing to move to; start over (and say so in Studio)
		log(player.Name, "would be moved now (no teleport here)")
		gameEvent:FireClient(player, "AFKCancelled", { Reason = isStudio and "Studio" or "Private" })
		player:SetAttribute("AFKMoveAt", nil)
		s.moving, s.warned = false, false
		s.last, s.limit = os.clock(), rollLimit()
		return
	end
	gameEvent:FireClient(player, "AFKRejoining", {})
	TreadmillService:Stop(player)
	DataService:SaveNow(player, 8) -- the next server loads this save
	if player.Parent ~= Players then
		return
	end
	local jobId = pickServer()
	local ok, err = teleport(player, jobId)
	if not ok and jobId then
		log(player.Name, "couldn't join", jobId, "-", err, "- letting Roblox pick a server")
		ok, err = teleport(player, nil)
	end
	if ok then
		log(player.Name, "moved to", jobId or "a new server", "while AFK")
		-- if the teleport silently never happens, try again rather than wait for the idle kick
		task.delay(25, function()
			if player.Parent == Players and state[player] == s and s.moving then
				warn("[AFK] still here 25 s after the teleport for", player.Name, "- trying again")
				s.moving = false
				s.retryAt = os.clock()
			end
		end)
	else
		warn("[AFK] teleport failed for", player.Name, err, "- trying again in", RETRY_SECONDS, "s")
		gameEvent:FireClient(player, "AFKCancelled", { Reason = "Failed" })
		s.moving = false
		s.retryAt = os.clock() + RETRY_SECONDS
	end
end

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	local s = state[player]
	if s and s.moving then
		warn("[AFK] teleport init failed for", player.Name, result, message, "- trying again in", RETRY_SECONDS, "s")
		gameEvent:FireClient(player, "AFKCancelled", { Reason = "Failed" })
		s.moving = false
		s.retryAt = os.clock() + RETRY_SECONDS
	end
end)

---------------------------------------------------------------- arriving
-- Puts an AFK arrival on their treadmill once their base, treadmill and character are ready.
local function arrive(player)
	player:SetAttribute("AFKMode", true)
	if not AFKConfig.AutoTreadmill then
		return
	end
	local deadline = os.clock() + AFKConfig.ArrivalTimeoutSeconds
	while player.Parent == Players and os.clock() < deadline do
		local plot = DataService:IsLoaded(player) and BaseService:GetPlot(player)
		local model = plot and plot:FindFirstChild("Treadmill")
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if model and not model:GetAttribute("Ghost") and hum and hum.Health > 0 and hrp then
			if (player:GetAttribute("TreadmillLevel") or 0) < 1 then
				break -- no treadmill unlocked yet
			end
			task.wait(1.5) -- let the character settle and the client finish loading
			if player.Parent ~= Players then
				return
			end
			TreadmillService:BeginRun(player, plot)
			if player:GetAttribute("OnTreadmill") then
				log(player.Name, "arrived AFK and is back on their treadmill")
				gameEvent:FireClient(player, "AFKArrived", { OnTreadmill = true })
				return
			end
		end
		task.wait(1)
	end
	if player.Parent == Players then
		gameEvent:FireClient(player, "AFKArrived", { OnTreadmill = false })
	end
end

local function joinedAFK(player)
	local ok, joinData = pcall(player.GetJoinData, player)
	if not ok or type(joinData) ~= "table" then
		return false
	end
	local data = joinData.TeleportData
	-- only trust it when it came from this game
	return type(data) == "table" and data.AFKRejoin == true and joinData.SourcePlaceId == game.PlaceId
end

---------------------------------------------------------------- test hooks (DevHooks.Call passes the player first)
function AFKService:SimulateArrival(player)
	task.spawn(arrive, player)
	return true
end

function AFKService:SetIdleSeconds(player, seconds)
	local s = state[player]
	if s and tonumber(seconds) then
		s.limit = tonumber(seconds)
		s.last = os.clock()
		return true
	end
	return false
end

function AFKService:GetIdle(player)
	local s = state[player]
	return s and idleSeconds(s, os.clock()) or nil, s and s.limit or nil
end

---------------------------------------------------------------- lifecycle
function AFKService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remote = ReplicatedStorage.Remotes:WaitForChild("AFK")
	remote.OnServerEvent:Connect(function(player, kind, seconds)
		local s = state[player]
		if not s then
			return
		end
		if kind == "Active" then
			if not s.moving then
				reset(player)
				if player:GetAttribute("AFKMode") then
					player:SetAttribute("AFKMode", nil) -- they're back
				end
			end
		elseif kind == "Idled" and type(seconds) == "number" and seconds == seconds then
			-- Roblox's own idle clock (it kicks at 20 minutes of it)
			s.robloxIdle = math.clamp(seconds, 0, 3600)
			s.robloxAt = os.clock()
		end
	end)
end

function AFKService:Start()
	if not AFKConfig.Enabled then
		return
	end
	if canTeleport then
		local ok, map = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, AFKConfig.ServerList.MapName)
		serverMap = ok and map or nil
	end
	local function onPlayer(player)
		state[player] = { last = os.clock(), limit = rollLimit(), warned = false, moving = false }
		if joinedAFK(player) then
			task.spawn(arrive, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)

	game:BindToClose(unlistSelf)
	task.spawn(function()
		while true do
			listSelf()
			task.wait(AFKConfig.ServerList.RefreshSeconds)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local now = os.clock()
		for player, s in state do
			if s.moving then
				continue
			end
			local idle = idleSeconds(s, now)
			if not s.warned and idle >= s.limit - AFKConfig.WarnSeconds then
				s.warned = true
				local left = math.max(1, s.limit - idle)
				player:SetAttribute("AFKMoveAt", workspace:GetServerTimeNow() + left)
				gameEvent:FireClient(player, "AFKWarning", { Seconds = left })
				log(player.Name, "idle", math.floor(idle), "s - moving in", math.floor(left), "s")
			elseif s.warned and idle >= s.limit and now >= (s.retryAt or 0) then
				task.spawn(move, player)
			end
		end
	end)
end

return AFKService
