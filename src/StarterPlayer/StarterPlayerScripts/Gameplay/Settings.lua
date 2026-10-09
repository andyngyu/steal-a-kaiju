-- Client side of the player settings (Shared.Config.SettingsConfig, saved by Services.SettingsService).
--   Settings.Get(key)            current value (the default until the save loads)
--   Settings.Changed(key, fn)    fn(value) now and every time it changes; returns the connection
--   Settings.Set(key, value)     asks the server (Remotes.SetSetting); the attribute updates when it's accepted
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))

local player = Players.LocalPlayer

local Settings = {}

function Settings.Get(key)
	local value = player:GetAttribute(SettingsConfig.Attribute(key))
	if value == nil then
		local setting = SettingsConfig.ByKey[key]
		return setting and setting.Default
	end
	return value
end

function Settings.Changed(key, fn)
	task.spawn(fn, Settings.Get(key))
	return player:GetAttributeChangedSignal(SettingsConfig.Attribute(key)):Connect(function()
		fn(Settings.Get(key))
	end)
end

function Settings.Set(key, value)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting"):FireServer(key, value)
end

return Settings
