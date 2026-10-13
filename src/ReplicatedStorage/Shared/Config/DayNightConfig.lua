--!strict
-- Day / night cycle (ServerScriptService.Services.DayNightService). Every cycle is DaySeconds of day followed by
-- NightSeconds of night, counted from workspace attribute DayNightEpoch (server time the first day began), so the server
-- and every client work out the same phase on their own.
-- Night is the egg reset: a barrier closes the lane at Map attribute SafeZoneX and everyone inside is sent back to the
-- safe zone, carried / dropped eggs are lost, guardians go home, and every nest is rerolled as day breaks.
local DayNight = {
	DaySeconds = 300,
	NightSeconds = 10,
}
DayNight.CycleSeconds = DayNight.DaySeconds + DayNight.NightSeconds

-- Icons for the HUD countdown and the barrier wall: Night = moon (shown while counting down to night),
-- Day = sun (shown during the night, counting down to day).
DayNight.Icons = {
	Night = "rbxassetid://72209680335402",
	Day = "rbxassetid://138091978151722",
}

-- Returns isNight, seconds left in the current phase, and which cycle it is (0 = the first day).
function DayNight.Phase(now: number, epoch: number): (boolean, number, number)
	local elapsed = math.max(0, now - epoch)
	local cycle = math.floor(elapsed / DayNight.CycleSeconds)
	local t = elapsed - cycle * DayNight.CycleSeconds
	if t < DayNight.DaySeconds then
		return false, DayNight.DaySeconds - t, cycle
	end
	return true, DayNight.CycleSeconds - t, cycle
end

return DayNight
