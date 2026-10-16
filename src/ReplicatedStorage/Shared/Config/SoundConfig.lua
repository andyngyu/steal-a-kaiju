-- Every sound in the game, in one place. Gameplay.GameAudio (StarterPlayerScripts) plays them; nothing here changes gameplay.
-- To swap a sound: paste a new asset id. Id can be one number or a list (a random one plays each time).
-- Volume 0..1, Pitch = PlaybackSpeed, Vary = random pitch +/- (0.05 = 5%), Cooldown = min seconds between plays.
-- 3D sounds use MinDist/MaxDist (studs). MaxSeconds fades a long clip out early.
-- Sources: Roblox official UI set (15675xxxxxx), Pro Sound Effects (91xxxxxxxx), APM licensed music (18xxxxxxxx).
-- All are free, public and licensed for Roblox games.

local SoundConfig = {}

-- Mix levels. These become SoundGroups in SoundService (tweak them there in Studio too).
SoundConfig.Groups = {
	Music = 0.5,
	SFX = 0.4, -- sound effects halved on 9 Oct (were SFX 0.8, UI 0.7, Kaiju 0.85)
	UI = 0.35,
	Ambience = 0.6,
	Kaiju = 0.45,
}

SoundConfig.Sounds = {
	---------------------------------------------------------------- UI
	Hover = { Id = 15675032796, Volume = 0.18, Pitch = 1.25, Vary = 0.04, Group = "UI", Cooldown = 0.05 },
	Click = { Id = 15675059323, Volume = 0.55, Vary = 0.04, Group = "UI", Cooldown = 0.04 },
	PanelOpen = { Id = 15675024286, Volume = 0.4, Group = "UI", Cooldown = 0.1 },
	PanelClose = { Id = 15675012262, Volume = 0.32, Group = "UI", Cooldown = 0.1 },
	Arrow = { Id = 15675037413, Volume = 0.45, Vary = 0.05, Group = "UI", Cooldown = 0.05 },
	Error = { Id = 15675075163, Volume = 0.55, Group = "UI", Cooldown = 0.25 },
	Warn = { Id = 15675062723, Volume = 0.45, Group = "UI", Cooldown = 0.25 },
	Notify = { Id = 15675085146, Volume = 0.3, Group = "UI", Cooldown = 0.2 },
	Welcome = { Id = 15675016548, Volume = 0.5, Group = "UI" },
	Success = { Id = 15675043410, Volume = 0.5, Group = "UI", Cooldown = 0.1 },
	CutePop = { Id = 15675055424, Volume = 0.4, Vary = 0.05, Group = "UI", Cooldown = 0.1 },
	PromptShown = { Id = 15675032796, Volume = 0.1, Pitch = 1.5, Group = "UI", Cooldown = 0.3 },
	PromptHold = { Id = 9113078189, Volume = 0.25, Pitch = 1.3, Group = "UI", Cooldown = 0.1 },
	PromptDone = { Id = 15675059323, Volume = 0.45, Pitch = 0.9, Group = "UI", Cooldown = 0.05 },

	---------------------------------------------------------------- economy
	Purchase = { Id = 9113728625, Volume = 0.5, Vary = 0.03, Group = "SFX", Cooldown = 0.08 },
	Coins = { Id = { 9125444677, 9125444505 }, Volume = 0.5, Vary = 0.05, Group = "SFX", Cooldown = 0.08 },
	SpeedUp = { Id = 9119816546, Volume = 0.45, Group = "SFX", Cooldown = 0.1 },
	Build = { Id = 9114756004, Volume = 0.5, Group = "SFX", Cooldown = 0.2 },
	TrailUnlock = { Id = 9126073318, Volume = 0.5, Group = "SFX" },
	TrailEquip = { Id = 9125646917, Volume = 0.45, Group = "SFX", Cooldown = 0.1 },
	Teleport = { Id = 9114373678, Volume = 0.5, Pitch = 1.1, Group = "SFX", Cooldown = 0.5 },

	---------------------------------------------------------------- eggs and hatching
	EggPickup = { Id = 9117841338, Volume = 0.6, Vary = 0.03, Group = "SFX" },
	EggSparkle = { Id = 9119834248, Volume = 0.35, Group = "SFX" },
	EggPlace = { Id = 9117840021, Volume = 0.6, Pitch = 0.9, Group = "SFX" },
	EggDrop = { Id = 9113480915, Volume = 0.6, Group = "SFX", Cooldown = 0.2 },
	EggReady = { Id = 9126072698, Volume = 0.45, Group = "SFX", Cooldown = 0.4 },
	EggCrack = { Id = { 9113959071, 9113959343 }, Volume = 0.7, Group = "SFX" },
	HatchBurst = { Id = 9116385087, Volume = 0.55, Group = "SFX" },
	-- hatch celebration layers (see HatchTiers below); all short, no horns
	HatchChime = { Id = { 9116394545, 9116394876 }, Volume = 0.45, Group = "SFX" }, -- magic twinkle cluster
	HatchDing = { Id = 9126073318, Volume = 0.45, Pitch = 1.05, Group = "SFX" }, -- short bright bell ding
	HatchGliss = { Id = 1836343550, Volume = 0.32, Group = "SFX", MaxSeconds = 3 }, -- rising glissando
	HatchOther = { Id = 15675043410, Volume = 0.22, Pitch = 1.1, Group = "UI", Cooldown = 1 },

	---------------------------------------------------------------- guardians (3D, from the guardian)
	GuardianSnore = { Id = { 9114663727, 9114663393 }, Volume = 0.45, Group = "Kaiju", MinDist = 10, MaxDist = 70 },
	GuardianRoar = { Id = { 9113985717, 9113987603 }, Volume = 1, Group = "Kaiju", MinDist = 25, MaxDist = 320 },
	GuardianStomp = { Id = { 9114080859, 9114080245, 9114077887 }, Volume = 0.75, Vary = 0.06, Group = "Kaiju", MinDist = 15, MaxDist = 220 },
	GuardianGrumble = { Id = 9125467833, Volume = 0.6, Group = "Kaiju", MinDist = 15, MaxDist = 150 },
	CaughtHit = { Id = 9119062052, Volume = 0.6, Group = "SFX" },
	Knockback = { Id = 9114373678, Volume = 0.5, Pitch = 0.85, Group = "SFX" },
	Escaped = { Id = 15675043410, Volume = 0.45, Pitch = 1.15, Group = "UI" },

	---------------------------------------------------------------- kaiju emotes (3D, from the kaiju; pitch drops for bigger kaiju)
	Roar = { Id = { 9113972711, 9113973009, 9125467833 }, Volume = 0.6, Pitch = 1.25, Vary = 0.06, Group = "Kaiju", MinDist = 8, MaxDist = 90 },
	ChestBeat = { Id = { 9113789512, 9113789511 }, Volume = 0.55, Vary = 0.05, Group = "Kaiju", MinDist = 8, MaxDist = 80 },
	Trumpet = { Id = 9114300941, Volume = 0.55, Pitch = 1.1, Group = "Kaiju", MinDist = 8, MaxDist = 90 },
	Chomp = { Id = { 9125466463, 9125466525 }, Volume = 0.55, Vary = 0.08, Group = "Kaiju", MinDist = 6, MaxDist = 60 },
	ClawSnap = { Id = { 9113957245, 9113957592 }, Volume = 0.45, Vary = 0.06, Group = "Kaiju", MinDist = 6, MaxDist = 55 },
	RearUp = { Id = { 9120049650, 9120049811 }, Volume = 0.45, Pitch = 1.1, Vary = 0.05, Group = "Kaiju", MinDist = 6, MaxDist = 60 },
	BigHop = { Id = { 9113858648, 9113858402 }, Volume = 0.5, Vary = 0.06, Group = "Kaiju", MinDist = 6, MaxDist = 60 },
	Bark = { Id = 9113956477, Volume = 0.45, Pitch = 1.45, Vary = 0.06, Group = "Kaiju", MinDist = 6, MaxDist = 60 },
	TailSwing = { Id = 9119713371, Volume = 0.35, Pitch = 0.8, Group = "Kaiju", MinDist = 5, MaxDist = 40 },
	Hop = { Id = 9117841338, Volume = 0.14, Pitch = 0.8, Vary = 0.1, Group = "Kaiju", MinDist = 4, MaxDist = 35 },
	Eat = { Id = 9118772457, Volume = 0.6, Vary = 0.06, Group = "Kaiju", MinDist = 6, MaxDist = 60 },
	FoodToss = { Id = 9119713371, Volume = 0.3, Pitch = 1.2, Vary = 0.08, Group = "SFX", MinDist = 6, MaxDist = 50 },
	LevelUp = { Id = 9119816546, Volume = 0.55, Pitch = 1.15, Group = "SFX", MinDist = 10, MaxDist = 90 },

	---------------------------------------------------------------- loops
	Treadmill = { Id = 9113910422, Volume = 0.22, Group = "SFX" },
}

-- Background music by zone (crossfades as you walk). Chase plays while a guardian is chasing you.
-- A zone can have one looping track ({ Id, Volume }) or a Playlist = { { Id, Volume }, ... } that plays the songs in
-- turn (starting at a random one) so nothing repeats every couple of minutes. Playlist volumes are levelled per song:
-- each was metered (Sound.PlaybackLoudness) and set so they all sit at the same soft level.
-- Every zone has music + ambience (16 Oct 2026). Levels were metered with Sound.PlaybackLoudness and set to one mix:
--   music        loudness x Volume ~13 (the safe zone ~16; biomes sit a little under it because ambience plays too)
--   ambience bed loudness x Volume ~5-7 in total per zone (always under the music)
--   gusts        peak x Volume ~20-25 (soft accents at about the music's own peaks, never jump-scares)
-- When you swap a track, meter it and scale Volume so loudness x Volume stays on these targets.
SoundConfig.Music = {
	-- Safe zone (fairytale kaiju castle): gentle, easy-going light classical / kids pieces, ~9.5 min before a repeat.
	-- Was Outward Bound (1842179736, a busier kids activity bed, loudness ~100 at Volume 0.278) until 15 Oct.
	Hub = {
		Playlist = {
			{ Id = 1837478855, Volume = 0.195 }, -- Outdoor Fun: bright, steady kids bed (loudness ~82)
			{ Id = 1842276427, Volume = 0.24 }, -- The Nature of Woodwind: "pleasant scenes of country and water" (~67)
			{ Id = 1842302279, Volume = 0.18 }, -- Fantasy: lightly scored storybook children's theme (~82, a few swells)
			{ Id = 1842276612, Volume = 0.26 }, -- Placidity: unhurried woodwind (~56)
		},
		Gap = 2, -- seconds of quiet between songs
	},
	PebblePlains = { Id = 1842357537, Volume = 0.245 }, -- Animal Antics (~53; was 0.35, a touch loud)
	LavaLagoon = { Id = 1842214009, Volume = 0.094 }, -- Plenty Funny: "theme for the mischievous youngster" (~139)
	FrostfangPeaks = {
		Playlist = {
			{ Id = 1840201434, Volume = 0.117 }, -- Crystal Forest (~111)
			{ Id = 9042431290, Volume = 0.083 }, -- Ice Princess: easy-listening orchestra, very steady (~158)
		},
		Gap = 2,
	},
	VenomJungle = {
		Playlist = {
			{ Id = 112847711833027, Volume = 0.44 }, -- Zoes World: soft and steady (~30)
			{ Id = 1840694199, Volume = 0.17 }, -- Nature's Secrets (~77)
		},
		Gap = 2,
	},
	SunkenAbyss = { Id = 102969823693650, Volume = 0.14 }, -- Glass Bay: calm, steady (~94)
	StormSpires = {
		Playlist = {
			{ Id = 1840776993, Volume = 0.58 }, -- Science Mysteries: quiet, curious, very steady (~23)
			{ Id = 1841144738, Volume = 0.067 }, -- Hint Of Uncertainty: steady, a little mysterious (~195)
		},
		Gap = 2,
	},
	CosmicRift = {
		Playlist = {
			{ Id = 1840492619, Volume = 0.64 }, -- Celestial Voices: soft dreamy pads (~20)
			{ Id = 132084099535932, Volume = 0.15 }, -- Starry Music Box (~87)
		},
		Gap = 2,
	},
	Chase = { Id = 1836289689, Volume = 0.45 }, -- Silly Chase
}
SoundConfig.MusicFade = 1.5
SoundConfig.DuckDuringHatch = 0.35 -- music volume multiplier while a hatch reveal is on screen

-- Ambience per zone: looping beds (Bed = one, Beds = a list) plus one-shot layers (Gusts = one or a list), each on
-- its own random timer (Every = { min, max } seconds). Metered loudness at Volume 1 is noted per sound.
SoundConfig.Ambience = {
	Hub = { Bed = { Id = 9119383684, Volume = 1.5 } }, -- morning birds chirping in the castle grounds (~3.3, a quiet file)
	PebblePlains = {
		Beds = {
			{ Id = 9114518794, Volume = 1.8 }, -- gentle breeze in leaves (~1.9; was 0.22, basically inaudible)
			{ Id = 9119383684, Volume = 0.9, Pitch = 1.05 }, -- birds, a little further off
		},
	},
	LavaLagoon = {
		Beds = {
			{ Id = { 9112823197, 9112823199 }, Volume = 0.07 }, -- Lava Rumble loop (~106; was 0.5 = 3x louder than the music)
			{ Id = 9125410075, Volume = 0.12, Pitch = 0.7 }, -- low gurgly bubbles underneath (~20)
		},
		Gusts = {
			{ Id = { 9125337823, 9120311866 }, Volume = 0.1, Pitch = 0.75, Vary = 0.1, Every = { 2.5, 6 } }, -- deep lava bloops (peak ~218)
			{ Id = { 9118882814, 9118884046 }, Volume = 0.1, Pitch = 0.8, Vary = 0.08, Every = { 6, 12 } }, -- steam hiss (~220)
			{ Id = 9113200364, Volume = 0.1, Pitch = 0.7, Every = { 14, 24 } }, -- distant volcanic rumble (~214)
		},
	},
	FrostfangPeaks = {
		Beds = {
			{ Id = 136454830957820, Volume = 0.18 }, -- looping mountain wind (~39; was 0.42)
		},
		Gusts = {
			{ Id = { 9120697823, 9120698415, 9120697984 }, Volume = 0.09, Vary = 0.06, Every = { 4, 8 } }, -- howling gusts (~242)
			{ Id = { 9114858583, 9114858588 }, Volume = 0.058, Pitch = 1.1, Vary = 0.1, Every = { 9, 16 } }, -- ice cracking (~379)
			{ Id = { 9116394545, 9116394876 }, Volume = 0.55, Pitch = 1.5, Vary = 0.1, Every = { 10, 18 } }, -- icicle twinkle (~34)
		},
	},
	VenomJungle = {
		Beds = {
			{ Id = 9112738716, Volume = 1.4 }, -- real jungle day: frogs, crickets, cicadas, birds (~4.6)
			{ Id = 9114518794, Volume = 1.2, Pitch = 0.85 }, -- heavy leaves stirring (~1.9)
		},
		Gusts = {
			{ Id = { 9125337823, 9120311866 }, Volume = 0.1, Pitch = 1.25, Vary = 0.12, Every = { 5, 11 } }, -- toxic pools plopping
		},
	},
	SunkenAbyss = {
		Beds = {
			{ Id = 9112889917, Volume = 0.9 }, -- real underwater ambience: low bubbles, soft resonance (~6.2)
			{ Id = 9125410075, Volume = 0.1, Pitch = 0.55 }, -- slow deep bubbling (~20)
		},
		Gusts = {
			{ Id = { 9125337823, 9120311866 }, Volume = 0.1, Pitch = 0.6, Vary = 0.12, Every = { 4, 9 } }, -- bubbles rising
			{ Id = 9113200364, Volume = 0.1, Pitch = 0.45, Every = { 16, 28 } }, -- something huge moving far below
		},
	},
	StormSpires = {
		Beds = {
			{ Id = 136454830957820, Volume = 0.16, Pitch = 0.8 }, -- storm wind across the spires (~39; was 0.36)
		},
		Gusts = {
			{ Id = { 9120697823, 9120698415, 9120697984 }, Volume = 0.09, Pitch = 0.85, Vary = 0.06, Every = { 5, 10 } }, -- howling gusts
			{ Id = 9113200364, Volume = 0.11, Pitch = 0.6, Vary = 0.08, Every = { 7, 14 } }, -- thunder rolling in the distance
			{ Id = { 9118882814, 9118884046 }, Volume = 0.08, Pitch = 1.6, Vary = 0.1, Every = { 6, 12 } }, -- electric crackle off the rods
		},
	},
	CosmicRift = {
		Beds = {
			{ Id = 9116386858, Volume = 0.1, Pitch = 0.8 }, -- a slow pulsing cosmic hum (~61)
			{ Id = 136454830957820, Volume = 0.05, Pitch = 0.42 }, -- a deep hollow drone from the rift (~39)
		},
		Gusts = {
			{ Id = { 9116394545, 9116394876 }, Volume = 0.55, Pitch = 1.35, Vary = 0.12, Every = { 5, 10 } }, -- stars twinkling (~34)
			{ Id = 9113200364, Volume = 0.1, Pitch = 0.4, Vary = 0.08, Every = { 14, 26 } }, -- the rift groaning far off
		},
	},
}

-- Guardian voice pitch per biome (bigger guardians sound deeper).
SoundConfig.GuardianPitch = {
	PebblePlains = 1,
	LavaLagoon = 0.86,
	FrostfangPeaks = 0.74,
	VenomJungle = 0.66,
	SunkenAbyss = 0.58,
	StormSpires = 0.52,
	CosmicRift = 0.46,
}

-- Hatch reveal celebration: which layers play, by the lowest rarity that gets them (EggConfig rarity Order:
-- Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, Mythic 6, Secret 7). Every hatch gets crack + burst + Success.
SoundConfig.HatchTiers = {
	Chime = 2, -- Uncommon+
	Ding = 4, -- Epic+
	Gliss = 5, -- Legendary+
}

-- Egg pickup pitch per rarity (rarer = brighter).
SoundConfig.RarityPitch = {
	Common = 1,
	Uncommon = 1.05,
	Rare = 1.1,
	Epic = 1.16,
	Legendary = 1.22,
	Mythic = 1.3,
	Secret = 1.4,
}

-- Kaiju emote -> sound key. Emotes without an entry stay silent (Look, Wiggle).
SoundConfig.Emotes = {
	Roar = "Roar",
	ChestBeat = "ChestBeat",
	Trumpet = "Trumpet",
	Chomp = "Chomp",
	ClawSnap = "ClawSnap",
	RearUp = "RearUp",
	BigHop = "BigHop",
	PlayBow = "Bark",
	Paw = "Bark",
	TailSwing = "TailSwing",
	Hop = "Hop",
	HopSpin = "Hop",
	Eat = "Eat",
}

return SoundConfig
