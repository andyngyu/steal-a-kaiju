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
	HoldReachSlack = 4, -- extra studs allowed while holding (a thief may shuffle a little)
	CooldownSeconds = 5, -- between two steals by the same thief
	Reach = 11.5, -- studs from the thief to the item's edge (egg: its surface; kaiju: its footprint), checked by the server
	-- The client shows the steal prompt this many studs short of Reach (lag between where you are and where the
	-- server thinks you are), so a prompt you can see is one the server accepts. Gameplay.StealFX keeps the prompt on
	-- the item's edge nearest you at your height, so big kaiju are as easy to grab as small ones.
	ClientReachMargin = 1.5,
	CarrySpeedMultiplier = 0.7, -- a thief runs slower while carrying stolen goods
	CarriedKaijuHeight = 3.4, -- a stolen kaiju shrinks to about this tall over the thief's head
	-- A carrier can't cover more ground than their (server-side) WalkSpeed allows: path length so far must stay under
	-- WalkSpeed x SpeedTolerance x seconds + SpeedSlackStuds (lag). A teleport or speed hack sends the item home.
	SpeedTolerance = 1.35,
	SpeedSlackStuds = 18,
	NewHatchProtectionSeconds = 30, -- a kaiju can't be stolen this soon after hatching
	ProtectAfterTheftSeconds = 60, -- after a theft the victim's base can't be stolen from for this long
	IntruderAlertSeconds = 20, -- gap between "someone is in your base" alerts for the same intruder

	-- The bat (Services.BatService; Steal a Brainrot style, replaced the old Tackle prompt on 16 Oct 2026). Every player
	-- carries one. A swing hits the closest player in front of you: they're knocked back, ragdolled and stunned, drop a
	-- carried nest egg on the spot, and stolen goods they carry (or a steal they're holding) go back home.
	Bat = table.freeze({
		CooldownSeconds = 0.9, -- between two swings
		WindUpSeconds = 0.17, -- the hit lands this long after the swing starts (the strike in Gameplay.BatFX's swing)
		Reach = 8.5, -- studs from the swinger to the target (flat distance between root parts)
		ConeDegrees = 110, -- how wide in front of the swinger a hit counts (anyone closer than CloseReach always counts)
		CloseReach = 3.5,
		StunSeconds = 2, -- ragdolled and can't grab, steal or swing for this long
		ImmuneSeconds = 0.75, -- after getting up, a short window where you can't be hit again
		Knockback = 60, -- studs/s away from the swinger
		Lift = 0.5, -- share of the knockback sent upwards
	}),

	Lock = table.freeze({
		Seconds = 60, -- how long a base lock holds (no steals, other players are pushed out)
		CooldownSeconds = 90, -- wait after a lock ends before locking again
	}),
})
