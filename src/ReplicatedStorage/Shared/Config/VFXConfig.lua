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
	},
}

---------------------------------------------------------------- biome weather + lighting mood (crossfades as you walk)
-- Lighting values are offsets from Lighting.KaijuColor / Atmosphere as they are at start (Tint replaces the tint;
-- Saturation / Brightness are added; Haze is added to Atmosphere.Density). Zones without Lighting use the base look.
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
	-- the locked biomes (ready for when they open)
	VenomJungle = {
		Spores = { Rate = 26, Color = hex("B8FF6A") },
		Lighting = { Tint = hex("E2FFD6"), Saturation = 0.12, Brightness = -0.02, Haze = 0.2 }, -- green, humid haze
	},
	SunkenAbyss = {
		Bubbles = { Rate = 34, Color = hex("D8FBFF") },
		Lighting = { Tint = hex("CDEFF2"), Saturation = 0.06, Brightness = -0.01, Haze = 0.12 }, -- teal water light
	},
	StormSpires = {
		Rain = { Rate = 150, Color = hex("C8D2E6") },
		Lighting = { Tint = hex("F0F0EC"), Saturation = -0.2, Brightness = 0.03, Haze = -0.04 }, -- pale, greyed storm light, clear air
	},
	CosmicRift = {
		Stardust = { Rate = 40, Color = hex("E8D8FF") },
		Lighting = { Tint = hex("E6D6FF"), Saturation = 0.12, Brightness = -0.06, Haze = 0.12 }, -- violet dusk
	},
}

return VFXConfig
