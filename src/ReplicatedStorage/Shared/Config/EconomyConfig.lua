--!strict
-- Cash flow: kaiju earn into a per-base pending pool; stepping on the base's collect pad moves it into Cash.
return table.freeze({
	StartingCash = 0,

	TickSeconds = 1, -- how often pending cash and labels update
	CollectCheckInterval = 0.2,

	Offline = table.freeze({
		Rate = 0.5, -- fraction of normal earnings paid while offline
		CapSeconds = 3 * 60 * 60, -- at most 3 hours of offline earnings
		MinSeconds = 60, -- ignore very short gaps (quick rejoins)
	}),
})
