-- Player settings (Shared.Config.SettingsConfig). Saved in data.Settings (only values that differ from the default, so
-- changing a default reaches everyone who never touched it), published as player attributes Setting_<Key> once the
-- profile loads (then SettingsLoaded = true), changed with Remotes.SetSetting (key, value).
-- Server code asks SettingsService:Get(player, key) (the default until the profile loads).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local lastChange = {} -- [player] = os.clock()

local function publish(player, data)
	local saved = data.Settings or {}
	for _, setting in SettingsConfig.List do
		local value = saved[setting.Key]
		if value == nil then
			value = setting.Default
		end
		player:SetAttribute(SettingsConfig.Attribute(setting.Key), value)
	end
	player:SetAttribute("SettingsLoaded", true)
end

function SettingsService:Get(player, key)
	local value = player:GetAttribute(SettingsConfig.Attribute(key))
	if value == nil then
		local setting = SettingsConfig.ByKey[key]
		return setting and setting.Default
	end
	return value
end

-- Returns false for an unknown key, a value of the wrong type or data that isn't loaded yet.
function SettingsService:Set(player, key, value)
	local setting = SettingsConfig.ByKey[key]
	local data = DataService:Get(player)
	if not (setting and data and type(value) == type(setting.Default)) then
		return false
	end
	data.Settings = data.Settings or {}
	if value == setting.Default then
		data.Settings[key] = nil
	else
		data.Settings[key] = value
	end
	player:SetAttribute(SettingsConfig.Attribute(key), value)
	DataService:Save(player)
	return true
end

function SettingsService:Init()
	ReplicatedStorage.Remotes:WaitForChild("SetSetting").OnServerEvent:Connect(function(player, key, value)
		local now = os.clock()
		if type(key) ~= "string" or (lastChange[player] and now - lastChange[player] < 0.1) then
			return
		end
		lastChange[player] = now
		self:Set(player, key, value)
	end)
end

function SettingsService:Start()
	DataService:OnLoaded(publish)
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SettingsService
