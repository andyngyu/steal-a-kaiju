-- Tuning for Gameplay.GameVFX (client-only visuals): rare kaiju auras, hatch extras, purchase effects,
-- biome weather + lighting mood, guardian roars and stomps. Change numbers here; no logic lives in this file.
-- Every rate / count is cut to ReducedScale when the player turns on Reduced Effects (Settings).
local hex = Color3.fromHex

local VFXConfig = {}

VFXConfig.ReducedScale = 0.35

-- Built-in Roblox particle textures (always available, no upload needed) + the game's own coin icon.
VFXConfig.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Puff = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	Coin = "rbxassetid://133140224705236", -- UIConfig.Images.Coin
	Soft = "rbxassetid://241779220", -- soft white dot (Creator Store "soft circle particle"): snow, pollen, ash
}

---------------------------------------------------------------- rare kaiju auras (on top of KaijuModel's sparkles)
-- MinOrder = lowest rarity that gets the upgraded aura (EggConfig: Epic = 4, Legendary = 5, Mythic = 6, Secret = 7).
VFXConfig.Aura = {
	MinOrder = 4,
	Range = 160, -- studs from the camera; farther auras switch off
	Tiers = {
		Epic = { Orbits = 2, OrbitSpeed = 1.6, Rings = true },
		Legendary = { Orbits = 2, OrbitSpeed = 1.9, Rings = true, Rays = true, Halo = true },
		Mythic = { Orbits = 3, OrbitSpeed = 2.2, Rings = true, Rays = true, Halo = true, Flames = hex("FF4DB8") },
		Secret = { Orbits = 3, OrbitSpeed = 2.4, Rings = true, Rays = true, Halo = true, Rainbow = true, StarBurstEvery = 2.5 },
	},
}

---------------------------------------------------------------- hatches (extras on top of KaijuFX's shell burst / grand pillar)
VFXConfig.Hatch = {
	Poof = true, -- every hatch: cartoon smoke poof
	FountainMinOrder = 3, -- Rare+: sparkle fountain
	FireworksMinOrder = 5, -- Legendary+: fireworks overhead
	Fireworks = { Legendary = 3, Mythic = 4, Secret = 6 },
}

---------------------------------------------------------------- purchases
VFXConfig.Purchase = {
	Coins = { FoodBought = 8, TrailBought = 16, PenUpgraded = 18, TreadmillUpgraded = 16 },
	PenGold = hex("FFD23F"),
}

---------------------------------------------------------------- guardians
VFXConfig.Guardian = {
	EyeGlow = hex("FF3B3B"),
	ShakeRange = 140, -- camera shake fades out by this distance
	Shake = 1.1,
	-- tint for the roar rings / dust per biome
	Biome = {
		PebblePlains = { Ring = hex("F4FFE8"), Dust = hex("D9C9A3"), Rock = hex("9C8463") },
		LavaLagoon = { Ring = hex("FF9A3C"), Dust = hex("6B5A50"), Rock = hex("3B2A2A"), Sparks = hex("FF6A1F") },
		FrostfangPeaks = { Ring = hex("BFEFFF"), Dust = hex("FFFFFF"), Rock = hex("9CB8D6") },
		VenomJungle = { Ring = hex("C8FF8A"), Dust = hex("7A8A56"), Rock = hex("4A5A32") },
		SunkenAbyss = { Ring = hex("7FF4FF"), Dust = hex("8FB0B4"), Rock = hex("2A4A5A") },
	},
}

---------------------------------------------------------------- biome weather + lighting mood (crossfades as you walk)
-- Lighting values are offsets from Lighting.KaijuColor / Atmosphere as they are at start (Tint replaces the tint;
-- Saturation / Brightness are added; Haze is added to Atmosphere.Density). Zones without Lighting use the base look.
-- Optional sky: AtmoColor / AtmoDecay / AtmoHaze / AtmoGlare replace the Atmosphere's own (a high AtmoHaze with a grey
-- colour turns the sky overcast); WeatherFX blends its events from these.
VFXConfig.Weather = {
	Fade = 2, -- seconds
	PebblePlains = {
		Pollen = { Rate = 18, Color = hex("FFF6B0") },
		Leaves = { Rate = 7, Color = hex("7FD957") },
		Lighting = { Tint = hex("FFF4DE"), Saturation = 0.08, Brightness = 0.03, Haze = -0.06 }, -- warm and bright
	},
	LavaLagoon = {
		Embers = { Rate = 70, Color = hex("FF7A1F") },
		Ash = { Rate = 14, Color = hex("8A7F7A") },
		Lighting = { Tint = hex("FFD9BC"), Saturation = 0.1, Brightness = -0.01, Haze = 0.14 }, -- orange haze
	},
	FrostfangPeaks = {
		Snow = { Rate = 110, Color = hex("FFFFFF") },
		Lighting = { Tint = hex("DCEBFF"), Saturation = -0.06, Brightness = 0.02, Haze = 0.18 }, -- cool blue light and mist
	},
	VenomJungle = {
		Spores = { Rate = 26, Color = hex("B8FF6A") },
		-- green humid light, the sky a jungle haze, but clear enough air to read the temple and the mushrooms
		Lighting = { Tint = hex("E8FFDC"), Saturation = 0.04, Brightness = 0.02, Haze = 0.06, AtmoColor = hex("B4E39C"), AtmoDecay = hex("5A8A46"), AtmoHaze = 3.2, AtmoGlare = 0 },
	},
	SunkenAbyss = {
		Bubbles = { Rate = 34, Color = hex("D8FBFF") },
		-- bright teal water light, the sky an aqua haze as if seen from under the sea
		Lighting = { Tint = hex("D6F6F0"), Saturation = 0.14, Brightness = 0.02, Haze = 0.06, AtmoColor = hex("8EE0DA"), AtmoDecay = hex("2F8F98"), AtmoHaze = 2.0, AtmoGlare = 0 },
	},
	-- the locked biomes (ready for when they open)
	StormSpires = {
		Rain = { Rate = 150, Color = hex("C8D2E6") },
		-- overcast and darker: a grey hazed sky, greyed light, but clear air so the spires still read
		Lighting = { Tint = hex("E6E8EC"), Saturation = -0.2, Brightness = -0.04, Haze = -0.02, AtmoColor = hex("8C9098"), AtmoDecay = hex("4E525A"), AtmoHaze = 2.8, AtmoGlare = 0 },
	},
	CosmicRift = {
		Stardust = { Rate = 40, Color = hex("E8D8FF") },
		-- a deep violet sky (stars and planets show against it), the ground still clearly lit, clear air
		Lighting = { Tint = hex("F0E6FF"), Saturation = 0.08, Brightness = 0.03, Haze = -0.05, AtmoColor = hex("3A2266"), AtmoDecay = hex("1A0C33"), AtmoHaze = 3.4, AtmoGlare = 0 },
	},
}

return VFXConfig
