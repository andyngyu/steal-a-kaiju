-- Admin panel: ServerScriptService.Services.AdminService runs the commands, StarterGui.KaijuUI.Controllers.
-- AdminPanelController fills KaijuUI.Panels.AdminPanel (F2 or the crown tile in the left rail, admins only).
-- Admins: the game's owner (its creator, or rank MinGroupRank+ in the owning group), every user id in UserIds, and
-- everyone while testing in Studio. The server checks this on every command; the client only hides the panel.
local AdminConfig = {
	UserIds = { -- Roblox user ids with admin
		417447293,
		361829322,
		1911640138,
		2063975111,
	},
	MinGroupRank = 255,
	ToggleKey = Enum.KeyCode.F2,
}

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local AREAS = { "Base", "PebblePlains", "LavaLagoon", "FrostfangPeaks", "VenomJungle", "SunkenAbyss", "StormSpires" }

-- mutation and weather choices come straight from their configs, so new ones show up here by themselves
local MUTATIONS, MUTATIONS_OR_NONE, WEATHERS = {}, { "None" }, {}
for _, m in require(script.Parent.MutationConfig).List do
	table.insert(MUTATIONS, m.Id)
	table.insert(MUTATIONS_OR_NONE, m.Id)
end
for _, e in require(script.Parent.WeatherConfig).Events do
	table.insert(WEATHERS, e.Id)
end

-- Commands, in panel order. Target = acts on the player selected in the panel's player list.
-- Params are inputs left to right: text boxes, or a cycling button when Options is given (Small = narrower,
-- Wide = wider). Danger = click twice.
AdminConfig.Commands = {
	{ Id = "GiveCash", Section = "Economy", Label = "Give Cash", Target = true, Params = { { Name = "Amount", Default = "1000000" } } },
	{ Id = "GiveSpeed", Section = "Economy", Label = "Give Speed", Target = true, Params = { { Name = "Amount", Default = "100000" } } },
	{ Id = "UnlockTrails", Section = "Economy", Label = "Unlock All Trails", Target = true },
	{ Id = "SetLuck", Section = "Boosts", Label = "Set Luck", Target = true, Params = {
		{ Name = "Luck", Default = "x2", Options = { "x1", "x1.5", "x2", "x3", "x5", "x10" } },
	} },
	{ Id = "DailyBoost", Section = "Boosts", Label = "Give Boost", Target = true, Params = {
		{ Name = "Boost", Default = "Luck", Options = { "Luck", "Cash", "Speed" } },
		{ Name = "Minutes", Default = "10", Hint = "minutes" },
	} },
	{ Id = "LightningBoost", Section = "Boosts", Label = "Lightning x4", Target = true },
	{ Id = "LightningBolt", Section = "Boosts", Label = "Spawn Bolt", Target = true },
	{ Id = "SpawnEgg", Section = "Eggs", Label = "Ready Egg In Pen", Target = true, Params = {
		{ Name = "Rarity", Default = "Legendary", Options = RARITIES, Small = true },
		{ Name = "Mutation", Default = "None", Options = MUTATIONS_OR_NONE, Small = true },
		{ Name = "Size", Default = "", Hint = "size", Small = true },
	} },
	{ Id = "MutatePenEggs", Section = "Mutations", Label = "Mutate Pen Eggs", Target = true, Params = {
		{ Name = "Mutation", Default = "Shocked", Options = MUTATIONS },
	} },
	{ Id = "MutatePets", Section = "Mutations", Label = "Mutate Pets", Target = true, Params = {
		{ Name = "Mutation", Default = "Shocked", Options = MUTATIONS_OR_NONE },
	} },
	{ Id = "MutateNests", Section = "Mutations", Label = "Mutate Nest Eggs", Params = {
		{ Name = "Mutation", Default = "Golden", Options = MUTATIONS },
	} },
	{ Id = "StartWeather", Section = "Weather", Label = "Start Weather", Params = {
		{ Name = "Weather", Default = WEATHERS[1], Options = WEATHERS },
		{ Name = "Seconds", Default = "180", Hint = "seconds" },
	} },
	{ Id = "StopWeather", Section = "Weather", Label = "Stop Weather" },
	{ Id = "NightNow", Section = "World", Label = "Start Night Now" },
	{ Id = "DayNow", Section = "World", Label = "Skip To Day" },
	{ Id = "Announce", Section = "World", Label = "Announce", Params = { { Name = "Message", Default = "", Hint = "message to everyone", Wide = true } } },
	{ Id = "ResetDaily", Section = "Rewards", Label = "Reset Daily Claim", Target = true },
	{ Id = "ResetGroupReward", Section = "Rewards", Label = "Reset Group Reward", Target = true },
	{ Id = "GoArea", Section = "Teleport", Label = "Go To Area", Params = { { Name = "Area", Default = "PebblePlains", Options = AREAS } } },
	{ Id = "GoTo", Section = "Teleport", Label = "Go To Player", Target = true },
	{ Id = "Bring", Section = "Teleport", Label = "Bring Player", Target = true },
	{ Id = "Respawn", Section = "Teleport", Label = "Respawn", Target = true },
	{ Id = "Kick", Section = "Moderation", Label = "Kick", Target = true, Danger = true, Params = { { Name = "Reason", Default = "", Hint = "reason", Wide = true } } },
	{ Id = "WipeData", Section = "Moderation", Label = "Wipe Data", Target = true, Danger = true },
}

AdminConfig.ById = {}
for _, c in AdminConfig.Commands do
	AdminConfig.ById[c.Id] = c
end

return AdminConfig
