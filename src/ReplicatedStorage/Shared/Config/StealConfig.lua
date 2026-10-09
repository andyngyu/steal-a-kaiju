--!strict
-- Player stealing and base defense (Services.StealService has the rules). Numbers, plus HoldTime.
local HOLD_SECONDS = table.freeze({ Common = 2.5, Uncommon = 3, Rare = 3.5, Epic = 4.5, Legendary = 5.5, Mythic = 6.5, Secret = 8 })
local HOLD_PER_SIZE = 0.5
local HOLD_PER_LEVEL = 0.04
local MAX_HOLD_SECONDS = 10

return table.freeze({
	-- Holding E on someone's egg or kaiju takes longer the more it's worth: HoldSeconds[rarity] x (1 + HoldPerSize x
	-- (size - 1)) + HoldPerLevel x (level - 1), at most MaxHoldSeconds (HoldTime below). The server times the hold too.
	HoldSeconds = HOLD_SECONDS,
	HoldPerSize = HOLD_PER_SIZE,
	HoldPerLevel = HOLD_PER_LEVEL,
	MaxHoldSeconds = MAX_HOLD_SECONDS,
	HoldTime = function(rarity: string?, size: number?, level: number?): number
		local base = HOLD_SECONDS[rarity or "Common"] or HOLD_SECONDS.Common
		local t = base * (1 + HOLD_PER_SIZE * math.max(0, (size or 1) - 1)) + HOLD_PER_LEVEL * math.max(0, (level or 1) - 1)
		return math.min(MAX_HOLD_SECONDS, math.floor(t * 10 + 0.5) / 10)
	end,
	HoldGraceSeconds = 0.35, -- network slack when the server checks a finished hold
	HoldSpeedMultiplier = 0.35, -- a thief can barely move while holding a steal
	HoldReachSlack = 3, -- extra studs allowed while holding (a thief may shuffle a little)
	CooldownSeconds = 5, -- between two steals by the same thief
	Reach = 10, -- studs from the thief to the item (egg: its surface; kaiju: where it stands), checked by the server
	CarrySpeedMultiplier = 0.7, -- a thief runs slower while carrying stolen goods
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
		StunSeconds = 2.5, -- the thief is ragdolled and can't grab anything for this long
		Knockback = 48,
	}),

	Lock = table.freeze({
		Seconds = 60, -- how long a base lock holds (no steals, other players are pushed out)
		CooldownSeconds = 90, -- wait after a lock ends before locking again
	}),
})
