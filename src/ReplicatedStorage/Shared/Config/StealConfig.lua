--!strict
-- Player stealing and base defense (Services.StealService has the rules). Numbers only.
return table.freeze({
	HoldSeconds = 1.2, -- hold E on someone else's egg or kaiju to steal it
	CooldownSeconds = 3, -- between two steals by the same thief
	Reach = 10, -- studs from the thief to the item (egg: its surface; kaiju: where it stands), checked by the server
	CarrySpeedMultiplier = 0.8, -- a thief runs slower while carrying stolen goods
	CarriedKaijuHeight = 3.4, -- a stolen kaiju shrinks to about this tall over the thief's head
	-- A carrier can't cover more ground than their (server-side) WalkSpeed allows: path length so far must stay under
	-- WalkSpeed x SpeedTolerance x seconds + SpeedSlackStuds (lag). A teleport or speed hack sends the item home.
	SpeedTolerance = 1.35,
	SpeedSlackStuds = 18,
	NewHatchProtectionSeconds = 30, -- a kaiju can't be stolen this soon after hatching
	ProtectAfterTheftSeconds = 60, -- after a theft the victim's base can't be stolen from for this long
	IntruderAlertSeconds = 20, -- gap between "someone is in your base" alerts for the same intruder

	Tackle = table.freeze({
		Reach = 10, -- studs between the tackler and the thief
		CooldownSeconds = 1.5,
		StunSeconds = 2, -- the thief can't grab anything for this long
		Knockback = 55,
	}),

	Lock = table.freeze({
		Seconds = 60, -- how long a base lock holds (no steals, other players are pushed out)
		CooldownSeconds = 90, -- wait after a lock ends before locking again
	}),
})
