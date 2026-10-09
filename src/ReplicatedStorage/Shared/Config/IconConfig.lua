-- Uploaded 2D icons (512x512, transparent) for every kaiju species and every biome egg in every rarity. Rendered from the
-- brick models in Studio; source PNGs + this list live in the project's icons folder (icons/asset_ids.json).
--   IconConfig.ForKaiju(species)          -> "rbxassetid://..." or "" (unknown species)
--   IconConfig.ForEgg(biomeId, rarityId)  -> "rbxassetid://..."; falls back to the biome's Common egg, then ""
-- UI rows take these as their Icon image (UIApi.SetPet / SetIndexEntry data.Icon).
local IconConfig = {}

IconConfig.Kaiju = {
	Pebblesaur = "rbxassetid://115700737045701",
	Chompling = "rbxassetid://105018332894896",
	Rumblerex = "rbxassetid://113056806500772",
	Bonkey = "rbxassetid://82244615785009",
	Tuskit = "rbxassetid://83704701249409",
	Thunderback = "rbxassetid://119130236863941",
	Magmite = "rbxassetid://99840747705986",
	CinderToad = "rbxassetid://92921189955423",
	Scorchback = "rbxassetid://74671830261665",
	BlazeBonkey = "rbxassetid://132027621489065",
	MoltenRex = "rbxassetid://121184717701582",
	InfernoSerpent = "rbxassetid://136196614876097",
	Snowpup = "rbxassetid://72962725876027",
	GlacierCrab = "rbxassetid://90408909859252",
	Frostrhino = "rbxassetid://109307678669650",
	Brrrilla = "rbxassetid://96328089571207",
	IcebreakerRex = "rbxassetid://119669208077528",
	AuroraSerpent = "rbxassetid://128205471450256",
	Prismling = "rbxassetid://135476221391794",
}

IconConfig.Eggs = {
	PebblePlains = {
		Common = "rbxassetid://85576555844600",
		Uncommon = "rbxassetid://102909884093512",
		Rare = "rbxassetid://75838355382417",
		Epic = "rbxassetid://79291022203406",
		Legendary = "rbxassetid://106185195416440",
		Mythic = "rbxassetid://109856133405283",
		Secret = "rbxassetid://111652585961160",
	},
	LavaLagoon = {
		Common = "rbxassetid://108782331755463",
		Uncommon = "rbxassetid://136756755942712",
		Rare = "rbxassetid://110215826959542",
		Epic = "rbxassetid://85505832478893",
		Legendary = "rbxassetid://128969907595441",
		Mythic = "rbxassetid://74894826657222",
		Secret = "rbxassetid://100853077999386",
	},
	FrostfangPeaks = {
		Common = "rbxassetid://98661111545024",
		Uncommon = "rbxassetid://80141478613005",
		Rare = "rbxassetid://131764705084075",
		Epic = "rbxassetid://129537103856578",
		Legendary = "rbxassetid://107860130256180",
		Mythic = "rbxassetid://111475031064959",
		Secret = "rbxassetid://110676084565853",
	},
}

function IconConfig.ForKaiju(species)
	return IconConfig.Kaiju[species or ""] or ""
end

function IconConfig.ForEgg(biomeId, rarityId)
	local biome = IconConfig.Eggs[biomeId or ""]
	if not biome then
		return ""
	end
	return biome[rarityId or ""] or biome.Common or ""
end

return IconConfig
