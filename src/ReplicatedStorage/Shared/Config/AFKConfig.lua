--!strict
-- Anti-AFK (ServerScriptService.Services.AFKService, KaijuUI AFKController).
-- A player who gives no input (keys, mouse, touch, gamepad) for a random IdleSeconds is moved to another public server
-- of the game and starts running on their own treadmill there, so they keep training instead of being kicked by
-- Roblox's 20 minute idle kick. Staying AFK repeats it (a fresh random timer in every server).
-- WarnSeconds before the move a countdown shows; any input cancels it.
return table.freeze({
	Enabled = true,
	IdleSeconds = table.freeze({ 900, 1080 }), -- 15 to 18 minutes, random per player per server
	WarnSeconds = 60,
	ActivePingSeconds = 10, -- how often the client may report activity (it reports at once while the warning shows)
	AutoTreadmill = true, -- arriving AFK players start running on their treadmill
	ArrivalTimeoutSeconds = 45, -- give up putting them on the treadmill if their base isn't ready by then

	-- the list of live servers (MemoryStoreService sorted map) used to pick a *different* server with room
	ServerList = table.freeze({
		MapName = "KaijuServers_v1",
		RefreshSeconds = 30,
		ExpirySeconds = 120,
		KeepFreeSlots = 1, -- don't pick a server with fewer free slots than this
	}),

	-- Studio can't teleport: set > 0 to try the flow with a short timer (it stops before the teleport)
	StudioIdleSeconds = 0,
})
