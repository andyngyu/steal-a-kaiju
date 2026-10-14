-- The champion statues in the Kaiju Citadel (workspace.Map.Citadel.Statues, built by Tools.CitadelBuilder):
--   Statue_Champion       the #1 player on the Money leaderboard (the richest hunter), as a golden statue of their own
--                         avatar with a fist raised. Plaque: "RICHEST HUNTER" / <name>
--   Statue_ChampionKaiju  the #1 player on the BestKaiju leaderboard, shown as their best kaiju (the highest-earning one
--                         in their pen) in gold. Plaque: "MIGHTIEST KAIJU" / <name>'s / <kaiju>
-- Each champion comes from ReplicatedStorage.LeaderboardData.<board> (LeaderboardService); at start-up the boards'
-- OrderedDataStores are read directly so the statues don't wait for the first board refresh. Kaiju are read from the
-- save with DataService:ViewAsync, so offline champions work too. Rechecked whenever a board refreshes and every RECHECK
-- seconds. Only reads data; the statues are server-built and replicate like any other part.
-- Until a board has a #1 (empty, or DataStores off in Studio) the builder's placeholders stay.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local StatueMaker = require(ServerScriptService.Lib.StatueMaker)

local DataService = require(script.Parent.DataService)

local ChampionService = {}

local RECHECK = 120

-- board -> the statue it drives and what it shows
local TRACKS = {
	{ board = "Money", statue = "Statue_Champion", kind = "Avatar" },
	{ board = "BestKaiju", statue = "Statue_ChampionKaiju", kind = "Kaiju" },
}

local shown = {} -- [statue name] = what it shows now (\"<userId>\" or \"<userId>|<species>|<variant>\")
local busy, again = false, false

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Champion]", ...)
	end
end

local function setPlaque(statue, text)
	local plaque = statue:FindFirstChild("Plaque")
	local board = plaque and plaque:FindFirstChild("Board")
	local label = board and board:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
	end
end

-- false (and the old figure stays) if the new one didn't come out as a proper statue
local function setFigure(statue, figure)
	local maxH, maxW = statue:GetAttribute("FigureMaxH"), statue:GetAttribute("FigureMaxW")
	StatueMaker.Place(figure, statue:GetAttribute("FigureBase"), statue:GetAttribute("FigureFacing"), maxH, maxW)
	local _, size = figure:GetBoundingBox()
	if size.Y < maxH * 0.25 then -- a figure that didn't assemble comes out flat
		warn("[Champion] statue came out wrong (" .. tostring(size) .. "), keeping the old one")
		figure:Destroy()
		return false
	end
	local old = statue:FindFirstChild("Figure")
	if old then
		old:Destroy()
	end
	figure.Name = "Figure"
	figure.Parent = statue
	return true
end

-- a board's #1 from the replicated board data: userId, name
local function fromBoard(board)
	local folder = ReplicatedStorage:FindFirstChild("LeaderboardData")
	local value = folder and folder:FindFirstChild(board)
	if not value then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value.Value)
	local row = ok and type(data) == "table" and data.Rows and data.Rows[1]
	if row and tonumber(row.U) then
		return tonumber(row.U), row.N
	end
	return nil
end

-- a board's #1 straight from its OrderedDataStore (before the first board refresh)
local function fromStore(board)
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore("LB_" .. board .. "_v1"):GetSortedAsync(false, 1)
	end)
	local entry = ok and pages and pages:GetCurrentPage()[1]
	return entry and tonumber(entry.key) or nil
end

local function nameOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return p.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return ok and name or ("Player " .. userId)
end

-- the highest-earning kaiju in the player's pen (their save's Pen.Items), or nil
local function bestKaiju(userId)
	local data = DataService:ViewAsync(userId)
	local items = data and data.Pen and data.Pen.Items
	local best, bestCps = nil, -1
	for _, entry in items or {} do
		if type(entry) == "table" and entry.Kind == "Kaiju" and entry.Species and KaijuConfig[entry.Species] then
			local ok, cps = pcall(KaijuStats.EntryCashPerSecond, entry)
			cps = ok and cps or 0
			if cps > bestCps then
				best, bestCps = entry, cps
			end
		end
	end
	return best
end

local function showAvatar(statue, userId, name)
	local key = tostring(userId)
	if shown[statue.Name] == key then
		return
	end
	local ok, avatar = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
	if not (ok and avatar) then
		warn("[Champion] couldn't load the avatar of " .. userId .. ": " .. tostring(avatar))
		return
	end
	StatueMaker.RaiseFist(avatar)
	StatueMaker.Gild(avatar, true)
	if not setFigure(statue, avatar) then
		return -- tried again at the next check
	end
	setPlaque(statue, "RICHEST HUNTER\n" .. (name or nameOf(userId)))
	shown[statue.Name] = key
	log("richest hunter", name, userId)
end

local function showKaiju(statue, userId, name)
	local entry = bestKaiju(userId)
	if not entry then
		return -- no kaiju in their pen right now: whatever is shown stays
	end
	local key = userId .. "|" .. entry.Species .. "|" .. tostring(entry.Variant or "")
	if shown[statue.Name] == key then
		return
	end
	local asset = ServerStorage.Assets.Kaiju:FindFirstChild(entry.Species)
	if not asset or not setFigure(statue, StatueMaker.Gild(asset:Clone())) then
		return
	end
	local cfg = KaijuConfig[entry.Species]
	local kaijuName = (entry.Variant == "Golden" and "Golden " or "") .. (cfg.DisplayName or entry.Species)
	setPlaque(statue, "MIGHTIEST KAIJU\n" .. (name or nameOf(userId)) .. "'s\n" .. kaijuName)
	shown[statue.Name] = key
	log("mightiest kaiju", name, kaijuName)
end

local statues = {}

-- updates both statues (first = { [board] = userId } from the stores at start-up); a call arriving mid-update runs
-- once more afterwards
local function refresh(first)
	if busy then
		again = true
		return
	end
	busy = true
	repeat
		again = false
		for _, t in TRACKS do
			local userId, name = fromBoard(t.board)
			if not userId and first then
				userId = first[t.board]
			end
			local statue = statues[t.statue]
			if userId and statue then
				local ok, err = pcall(t.kind == "Avatar" and showAvatar or showKaiju, statue, userId, name)
				if not ok then
					warn("[Champion]", err)
				end
			end
		end
		first = nil
	until not again
	busy = false
end

function ChampionService:Start()
	local map = workspace:WaitForChild("Map", 30)
	local citadel = map and map:WaitForChild("Citadel", 30)
	local folder = citadel and citadel:WaitForChild("Statues", 30)
	for _, t in TRACKS do
		statues[t.statue] = folder and folder:WaitForChild(t.statue, 30)
		if not statues[t.statue] then
			warn("[Champion] no " .. t.statue .. " in workspace.Map.Citadel.Statues")
		end
	end
	-- right away from the stores, then whenever a board refreshes, and every RECHECK seconds
	local first = {}
	for _, t in TRACKS do
		first[t.board] = fromBoard(t.board) or fromStore(t.board)
	end
	refresh(first)
	local data = ReplicatedStorage:WaitForChild("LeaderboardData", 60)
	for _, t in TRACKS do
		local value = data and data:WaitForChild(t.board, 60)
		if value then
			value.Changed:Connect(function()
				task.spawn(refresh)
			end)
		end
	end
	while true do
		task.wait(RECHECK)
		refresh()
	end
end

return ChampionService
