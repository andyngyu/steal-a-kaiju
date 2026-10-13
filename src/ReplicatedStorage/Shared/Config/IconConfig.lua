-- Uploaded 2D icons (512x512, transparent) for every kaiju species and every biome egg in every rarity. Rendered from the
-- brick models in Studio; source PNGs + this list live in the project's icons folder (icons/asset_ids.json).
--   IconConfig.ForKaiju(species)          -> "rbxassetid://..." or "" (unknown species)
--   IconConfig.ForEgg(biomeId, rarityId)  -> "rbxassetid://..."; falls back to the biome's Common egg, then ""
-- UI rows take these as their Icon image (UIApi.SetPet / SetIndexEntry data.Icon).
local IconConfig = {}

-- (re-rendered from the sculpted menacing models, 2026-10-13; previous set in icons/asset_ids_v2.json)
IconConfig.Kaiju = {
	Pebblesaur = "rbxassetid://86214005977607",
	Chompling = "rbxassetid://130401670254097",
	Rumblerex = "rbxassetid://78090860581568",
	Bonkey = "rbxassetid://106269960314788",
	Tuskit = "rbxassetid://92291136209195",
	Thunderback = "rbxassetid://97429742476045",
	Magmite = "rbxassetid://77116396076844",
	CinderToad = "rbxassetid://81933138674457",
	Scorchback = "rbxassetid://131879547111471",
	BlazeBonkey = "rbxassetid://98680513339022",
	MoltenRex = "rbxassetid://91664818713074",
	InfernoSerpent = "rbxassetid://83235369470255",
	Snowpup = "rbxassetid://91646335787432",
	GlacierCrab = "rbxassetid://95324063785335",
	Frostrhino = "rbxassetid://92132609444438",
	Brrrilla = "rbxassetid://124953833658672",
	IcebreakerRex = "rbxassetid://97949342854298",
	AuroraSerpent = "rbxassetid://75618888906866",
	Prismling = "rbxassetid://107278256092402",
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
