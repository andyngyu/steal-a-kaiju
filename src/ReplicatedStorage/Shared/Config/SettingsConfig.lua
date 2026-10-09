-- Player settings. ServerScriptService.Services.SettingsService saves them (data.Settings) and publishes each one as a
-- player attribute "Setting_<Key>"; StarterPlayerScripts.Gameplay.Settings reads them on the client.
-- The settings panel lists them in this order and changes one with Remotes.SetSetting:FireServer(key, value).
-- All are on/off toggles for now (Default is a boolean).
local SettingsConfig = {}

SettingsConfig.List = {
	{ Key = "Music", Label = "Music", Description = "Background music", Default = true },
	{ Key = "SoundEffects", Label = "Sound Effects", Description = "Kaiju roars, buttons and world sounds", Default = true },
	{ Key = "CameraShake", Label = "Camera Shake", Description = "Screen shake on big hatches", Default = true },
	{ Key = "IncomePopups", Label = "Cash Popups", Description = "The \"+$\" above your kaiju", Default = true },
	{ Key = "ReducedEffects", Label = "Reduced Effects", Description = "Fewer particles, for slower devices", Default = false },
	{ Key = "AutoHatch", Label = "Auto Hatch", Description = "Hatch eggs as soon as they're ready", Default = false },
	{ Key = "CarryGuide", Label = "Path Home", Description = "Arrow to your pen while you carry an egg", Default = true },
}

SettingsConfig.ByKey = {}
for i, setting in SettingsConfig.List do
	setting.Order = i
	SettingsConfig.ByKey[setting.Key] = setting
end

-- Player attribute that holds a setting's current value.
function SettingsConfig.Attribute(key)
	return "Setting_" .. key
end

return SettingsConfig
