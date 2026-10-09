-- Studio-only test commands (DevConfig.AdminCommands is forced off in live servers).
-- Chat:         /givecash 1000      /resetdata (wipes your save to a brand-new player, then kicks you)
-- Command bar:  game.ServerStorage.DevHooks.GiveCash:Invoke(<userId or nil for everyone>, 1000)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local DevService = {}

local function giveCash(player, amount)
	amount = tonumber(amount)
	if amount and amount > 0 then
		EconomyService:AddCash(player, math.floor(amount))
		print("[Dev] gave", player.Name, amount, "cash")
	end
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
	hooks.Parent = ServerStorage

	local function onPlayer(player)
		player.Chatted:Connect(function(message)
			local amount = message:match("^/givecash%s+(%d+)")
			if amount then
				giveCash(player, amount)
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
