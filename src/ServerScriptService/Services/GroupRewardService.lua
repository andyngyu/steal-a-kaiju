-- Group reward: join the game's Roblox group (Shared.Config.GroupRewardConfig) and claim a one-time bundle at the golden
-- Rumblerex NPC in the Kaiju Market (its ground pad opens KaijuUI GroupRewardPanel, Controllers.GroupRewardController).
--   Bundle: Cash, Speed, a unique Golden Rumblerex (fixed CashPerSecond, can't be stolen or sold) and a Luck bonus.
--   The Luck bonus (LuckService source "GroupReward") lasts for as long as the player stays in the group: it is
--   re-checked on every join, so leaving the group removes it (the rest of the bundle is kept).
-- Remotes.ClaimGroupReward (RemoteFunction): ("Status") -> { InGroup, Claimed } | ("Claim") -> ok, reason
--   reason: "NotInGroup" | "Claimed" | "NotReady" | "Busy"
-- Saved: data.GroupReward = { ClaimedAt = os.time, PetId }
-- Player attributes: InRewardGroup, GroupRewardClaimed.  GameEvent: GroupRewardClaimed {Cash, Speed, Luck, PetId}
-- Studio only: workspace attribute GroupRewardTestBypass = true counts everyone as a group member (for testing).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
local GroupRewardConfig = require(ReplicatedStorage.Shared.Config.GroupRewardConfig)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local SpeedService = require(script.Parent.SpeedService)
local LuckService = require(script.Parent.LuckService)
local HatchService = require(script.Parent.HatchService)
local PetService = require(script.Parent.PetService)

local GroupRewardService = {}

local LUCK_SOURCE = "GroupReward"
local busy = {} -- [player] = true while a claim runs
local lastCheck = {} -- [player] = os.clock() of the last web check
local CHECK_COOLDOWN = 3
local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[GroupReward]", ...)
	end
end

-- Fresh membership check (GetGroupsAsync isn't cached per session like Player:IsInGroup, so joining mid-game counts).
local function isMember(player)
	if RunService:IsStudio() and workspace:GetAttribute("GroupRewardTestBypass") then
		return true
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if ok and type(groups) == "table" then
		for _, g in groups do
			if g.Id == GroupRewardConfig.GroupId then
				return true
			end
		end
		return false
	end
	local ok2, inGroup = pcall(player.IsInGroup, player, GroupRewardConfig.GroupId)
	return ok2 and inGroup == true
end

local function refresh(player)
	local member = isMember(player)
	lastCheck[player] = os.clock()
	if player.Parent ~= Players then
		return false
	end
	player:SetAttribute("InRewardGroup", member)
	local data = DataService:Get(player)
	local claimed = data and data.GroupReward and data.GroupReward.ClaimedAt ~= nil
	LuckService:SetSource(player, LUCK_SOURCE, (member and claimed) and GroupRewardConfig.Luck or nil)
	return member
end

local function petEntry(id)
	local pet = GroupRewardConfig.Pet
	local species = KaijuConfig[pet.Species]
	return {
		Kind = "Kaiju",
		KaijuId = id,
		Species = pet.Species,
		Rarity = species and species.Rarity or "Epic",
		BiomeId = species and species.Biome or "PebblePlains",
		HatchedAt = os.time(),
		Size = 1,
		Level = 1,
		XP = 0,
		Variant = pet.Variant,
		Unique = "GroupReward",
		FixedCashPerSecond = pet.CashPerSecond,
	}
end

function GroupRewardService:Claim(player)
	local data = DataService:Get(player)
	if not data then
		return false, "NotReady"
	end
	if data.GroupReward and data.GroupReward.ClaimedAt then
		return false, "Claimed"
	end
	if busy[player] then
		return false, "Busy"
	end
	busy[player] = true
	local member = refresh(player)
	busy[player] = nil
	if not member then
		return false, "NotInGroup"
	end
	if player.Parent ~= Players or (data.GroupReward and data.GroupReward.ClaimedAt) then
		return false, "Claimed"
	end
	local id = HttpService:GenerateGUID(false)
	data.GroupReward = { ClaimedAt = os.time(), PetId = id }
	player:SetAttribute("GroupRewardClaimed", true)

	EconomyService:AddCash(player, GroupRewardConfig.Cash)
	SpeedService:AddSpeed(player, GroupRewardConfig.Speed)
	LuckService:SetSource(player, LUCK_SOURCE, GroupRewardConfig.Luck)
	-- the pet goes straight into the pen when there's room, otherwise into the Pets inventory
	local entry = petEntry(id)
	local placed = BaseService:GetPlot(player) and BaseService:HasRoom(player) and HatchService:SpawnItem(player, id, entry)
	if not placed then
		PetService:AddToInventory(player, id, entry)
	end
	EconomyService:Publish(player)
	DataService:Save(player)
	gameEvent:FireClient(player, "GroupRewardClaimed", {
		Cash = GroupRewardConfig.Cash,
		Speed = GroupRewardConfig.Speed,
		Luck = GroupRewardConfig.Luck,
		PetId = id,
		InInventory = not placed,
	})
	log(player.Name, "claimed the group reward", placed and "(pet in pen)" or "(pet to inventory)")
	return true, ""
end

local function onInvoke(player, action)
	if action == "Status" then
		if not lastCheck[player] or os.clock() - lastCheck[player] > CHECK_COOLDOWN then
			refresh(player)
		end
		return {
			InGroup = player:GetAttribute("InRewardGroup") == true,
			Claimed = player:GetAttribute("GroupRewardClaimed") == true,
		}
	elseif action == "Claim" then
		local ok, reason = GroupRewardService:Claim(player)
		return ok, reason
	end
	return false, ""
end

-- Admin panel: forget the claim so it can be claimed again (the Golden Rumblerex already given stays).
function GroupRewardService:ResetForTesting(player)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	data.GroupReward = nil
	player:SetAttribute("GroupRewardClaimed", false)
	LuckService:SetSource(player, LUCK_SOURCE, nil)
	DataService:Save(player)
	return true
end

-- Testing: mark the reward claimed without granting anything (undoes ResetForTesting).
function GroupRewardService:MarkClaimedForTesting(player)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	data.GroupReward = data.GroupReward or { ClaimedAt = os.time() }
	player:SetAttribute("GroupRewardClaimed", true)
	refresh(player)
	DataService:Save(player)
	return true
end

function GroupRewardService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remote = ReplicatedStorage.Remotes:FindFirstChild("ClaimGroupReward") or Instance.new("RemoteFunction")
	remote.Name = "ClaimGroupReward"
	remote.OnServerInvoke = onInvoke
	remote.Parent = ReplicatedStorage.Remotes
end

function GroupRewardService:Start()
	DataService:OnLoaded(function(player, data)
		player:SetAttribute("GroupRewardClaimed", data.GroupReward ~= nil and data.GroupReward.ClaimedAt ~= nil)
		refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastCheck[player] = nil
	end)
end

return GroupRewardService
