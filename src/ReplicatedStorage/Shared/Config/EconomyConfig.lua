--!strict
-- Cash flow: kaiju in a player's pen pay their CashPerSecond straight into Cash every tick.
return table.freeze({
	StartingCash = 0,

	TickSeconds = 1, -- how often income is paid out

	Offline = table.freeze({
		Rate = 0.5, -- fraction of normal earnings paid while offline
		CapSeconds = 3 * 60 * 60, -- at most 3 hours of offline earnings
		MinSeconds = 60, -- ignore very short gaps (quick rejoins)
	}),
})
