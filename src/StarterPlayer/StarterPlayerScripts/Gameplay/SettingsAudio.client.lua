-- Applies the Music and Sound Effects settings (Gameplay.Settings) by scaling the SoundService groups that GameAudio
-- plays through. GameAudio sets each group to its SoundConfig.Groups volume once at start, so a muted group is pinned
-- back to 0 whenever anything raises it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SoundConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local GROUPS = {
	Music = { "Music" },
	SoundEffects = { "SFX", "Kaiju", "UI", "Ambience" },
}

for key, names in GROUPS do
	for _, name in names do
		task.spawn(function()
			local group = SoundService:WaitForChild(name, 30)
			if not (group and group:IsA("SoundGroup")) then
				return
			end
			local base = SoundConfig.Groups[name] or group.Volume
			local function apply()
				local want = Settings.Get(key) and base or 0
				if group.Volume ~= want then
					group.Volume = want
				end
			end
			Settings.Changed(key, apply)
			group:GetPropertyChangedSignal("Volume"):Connect(function()
				if not Settings.Get(key) and group.Volume > 0 then
					group.Volume = 0
				end
			end)
		end)
	end
end
