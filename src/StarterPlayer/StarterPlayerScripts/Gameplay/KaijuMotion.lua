-- Gameplay.KaijuMotion: the emote sound hook. The animation engine (ReplicatedStorage.KaijuAnimation) calls
-- FireEmote(model, name) when a kaiju starts an action, and Gameplay.GameAudio plays the matching voice from
-- EmoteStarted (SoundConfig.Emotes). The gaits and emotes that used to live here are the engine's now.
local KaijuMotion = {}

local emoteStarted = Instance.new("BindableEvent")
KaijuMotion.EmoteStarted = emoteStarted.Event -- (model, emoteName)

function KaijuMotion.FireEmote(model, name)
	emoteStarted:Fire(model, name)
end

return KaijuMotion
