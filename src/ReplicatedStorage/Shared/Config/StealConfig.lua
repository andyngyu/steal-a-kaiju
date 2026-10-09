--!strict
-- Player stealing and base defense (Services.StealService has the rules). Numbers only.
return table.freeze({
	HoldSeconds = 1.2, -- hold E on someone else's egg or kaiju to steal it
	CooldownSeconds = 3, -- between two steals by the same thief
	Reach = 10, -- studs from the thief to the item (egg: its surface; kaiju: where it stands), checked by the server
	CarrySpeedMultiplier = 0.8, -- a thief runs slower while carrying stolen goods
	CarriedKaijuHeight = 3.4, -- a stolen kaiju shrinks to about this tall over the thief's head
	MaxDeliverySpeed = 140, -- studs/s, start to delivery in a straight line; faster is a teleport and the item goes home
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
