-- KaijuAnimation.Config: every tunable of the kaiju animation engine, in one place, so tuning never needs code changes.
-- Units: angles in degrees, times in seconds, frequencies in Hz (cycles per second), distances in studs at the kaiju's
-- build size (the engine multiplies distances by the kaiju's VisualScale; angles are never scaled).
-- Profiles hold the defaults for a body type. Creatures pick a profile and can override any value by name (the override
-- table is merged into the profile, key by key).
-- Joint names (the rig's Motor6D names): Body, Head, Jaw, Neck or Neck1..n, Tail or Tail1..n, Seg1..n, LegL / LegR,
-- LegFL / LegFR / LegBL / LegBR, LegAL..LegCR (six legs), ArmL / ArmR, WingL / WingR, EarL / EarR, EyeL / EyeR (eye
-- stalks), ClawL / ClawR, Trunk1..n, Tongue, Cloud, and the spinners Ring, Moons, Halo. A group whose name has a numbered
-- follower (Tail with Tail2) becomes name1 (Tail1); L is the +X side of the model, which faces -Z.
local Config = {}

-- Live kaiju species animated by this engine (Gameplay.KaijuFX keeps animating the rest), rolled out biome by biome.
Config.Rollout = {
	"Pebblesaur", "Chompling", "Bonkey", "Tuskit", "Rumblerex", "Thunderback", -- Pebble Plains
	"Magmite", "CinderToad", "Scorchback", "BlazeBonkey", "MoltenRex", "InfernoSerpent", -- Lava Lagoon
	"Snowpup", "GlacierCrab", "Frostrhino", "Brrrilla", "IcebreakerRex", "AuroraSerpent", -- Frostfang Peaks
}

-- Shared with Gameplay.KaijuFX: true when this engine animates a live kaiju (a pen kaiju of a rolled-out species).
function Config.Handles(model)
	local runtime = workspace:FindFirstChild("Runtime")
	local folder = runtime and runtime:FindFirstChild("Kaiju")
	if not folder or model.Parent ~= folder then
		return false
	end
	return table.find(Config.Rollout, model:GetAttribute("Species") or model.Name) ~= nil
end

Config.Global = {
	SpeedJitter = { 0.88, 1.12 }, -- per-creature speed multiplier, so no two creatures move in sync
	Exaggerate = 1.2, -- readability boost on every idle and action angle
	ActionShare = 0.3, -- at most this share of visible creatures may start an action in any one second
	BlendIn = 0.6, -- seconds to fade a freshly rigged creature in from its rest pose
	FirstAction = { 2, 6 }, -- seconds before a new creature's first action
}

Config.Performance = {
	-- Measured in the Gallery (Studio, 17 creatures, about 12,600 bricks all at full rate): about 0.35 ms of physics per
	-- creature per update, because every brick of a moving group is moved. So full rate is kept for the closest ones.
	FullNear = 30, -- studs: every frame inside this
	FullEvery = 2, -- 30 to 60 studs: all layers, every 2nd frame
	Full = 60, -- studs from the camera: full detail (micro layers, particles) inside this
	Reduced = 150, -- every ReducedEvery frames, no micro layers, half particles
	Far = 300, -- FarHz updates, breathing and orbits only, no particles; beyond it (or off screen) nothing updates
	ReducedEvery = 2,
	ReducedEveryCrowded = 3, -- used once more than CrowdedAt creatures are in the Reduced tier
	CrowdedAt = 30,
	FarHz = 8,
	Caps = { Desktop = { Full = 24, Reduced = 48 }, Mobile = { Full = 10, Reduced = 20 } }, -- the brief's 40 / 60 cost too much physics (see above)
	OwnBaseBonus = 0.5, -- the local player's own kaiju count as this much closer when sorting for the caps
	ClassifyHz = 6, -- tier and visibility checks per creature per second (batched across frames)
	BuildBudgetMs = { Desktop = 2, Mobile = 1 }, -- rig construction time per frame
	Particles = { Desktop = 800, Mobile = 300 }, -- active particle budget
	PulseHz = { 12, 6 }, -- neon pulse updates per second in the Full and Reduced tiers
}

-- Rarity personality. Tempo: idle speed. Fidget: how often micro motions happen (glances, flicks, taps). ActionGap:
-- seconds between signature actions. ActionAmp: action size. ActionSpeed: action duration multiplier.
Config.Rarity = {
	Common = { Tempo = 1.12, Fidget = 1.4, ActionGap = { 6, 10 }, ActionAmp = 0.95, ActionSpeed = 0.92 },
	Uncommon = { Tempo = 1.08, Fidget = 1.25, ActionGap = { 6.5, 11 }, ActionAmp = 1, ActionSpeed = 0.95 },
	Rare = { Tempo = 1, Fidget = 1, ActionGap = { 7, 12 }, ActionAmp = 1, ActionSpeed = 1 },
	Epic = { Tempo = 0.96, Fidget = 0.9, ActionGap = { 8, 13 }, ActionAmp = 1.05, ActionSpeed = 1.03 },
	Legendary = { Tempo = 0.88, Fidget = 0.7, ActionGap = { 10, 16 }, ActionAmp = 1.12, ActionSpeed = 1.08 },
	Mythic = { Tempo = 0.84, Fidget = 0.6, ActionGap = { 11, 18 }, ActionAmp = 1.18, ActionSpeed = 1.1 },
	Secret = { Tempo = 0.86, Fidget = 0.65, ActionGap = { 10, 17 }, ActionAmp = 1.15, ActionSpeed = 1.08 },
	Guardian = { Tempo = 0.7, Fidget = 0.45, ActionGap = { 14, 22 }, ActionAmp = 1.2, ActionSpeed = 1.15 },
}

-- Breathing period range by size. Bulk is the cube root of the creature's bounding volume at its in-game size; the
-- period runs from the low to the high end across each bulk range.
Config.Breath = {
	Small = { Period = { 2.5, 3.5 }, Bulk = { 3, 6 } },
	Large = { Period = { 3.5, 4.5 }, Bulk = { 6, 12 } },
	Guardian = { Period = { 5, 6 }, Bulk = { 10, 20 } },
	SmallBelow = 6, -- bulk under this is small (used for greetings too)
}

-- Follow-through springs by joint role. Hz: natural frequency at scale 1 (bigger creatures are slower by 1/sqrt(scale)).
-- Damping: damping ratio (1 would never overshoot; lower overshoots more before it settles). Inertia: how much of its
-- parent's motion the joint lags behind (0 none, 1 full). Grow: extra inertia per link along a chain, so tips swing most.
-- Joints without a spring (body, legs, arms) follow their pose exactly.
Config.Springs = {
	Head = { Hz = 2.6, Damping = 0.72, Inertia = 0.35 },
	Neck = { Hz = 1.8, Damping = 0.7, Inertia = 0.6, Grow = 0.1 },
	Jaw = { Hz = 5, Damping = 0.55, Inertia = 0.5 },
	Tail = { Hz = 1.5, Damping = 0.5, Inertia = 1, Grow = 0.18 },
	Trunk = { Hz = 1.7, Damping = 0.5, Inertia = 1, Grow = 0.15 },
	Ear = { Hz = 3.4, Damping = 0.4, Inertia = 1.1 },
	Wing = { Hz = 1.9, Damping = 0.55, Inertia = 0.7 },
	Tentacle = { Hz = 1.2, Damping = 0.45, Inertia = 1, Grow = 0.2 },
	Seg = { Hz = 1.6, Damping = 0.7, Inertia = 0.5, Grow = 0.08 },
	EyeStalk = { Hz = 3.8, Damping = 0.32, Inertia = 1.2 },
	Claw = { Hz = 3, Damping = 0.6, Inertia = 0.5 },
	Tongue = { Hz = 6, Damping = 0.6, Inertia = 0.3 },
	Cloud = { Hz = 1.1, Damping = 0.6, Inertia = 0.6 },
}

-- Head life, shared fields: Yaw / Pitch / Tilt: noise look-around range. Hz: look-around speed. Base: resting pitch.
-- GlanceEvery / Glance / GlanceHold: occasional quick glances. Mode "Snap": holds a pose for Hold seconds, then snaps to
-- a new one (SnapHz / SnapDamping: the head spring while snapping). Stabilize: how much the head cancels its parent's
-- motion to keep its gaze steady (0..1).
-- Breath: Lift (studs) and Pitch on the inhale; Joint moves the breath to another joint (Krakling's mantle).
-- Shift: weight shift, Roll / Slide (studs) / Pitch (diagonal pairs) / Yaw, Hz: speed.
-- Planted: limbs whose feet stay on the ground (the engine pivots them about their feet as the body moves).
Config.Profiles = {
	Rex = {
		Breath = { Lift = 0.045, Pitch = 1.3 },
		Shift = { Roll = 3, Slide = 0.05, Hz = 0.1 },
		Head = { Yaw = 18, Pitch = 5, Tilt = 2, Hz = 0.06, Base = -3, GlanceEvery = { 6, 11 }, Glance = 22, GlanceHold = { 0.8, 1.6 }, Stabilize = 0.7 },
		Planted = { "LegL", "LegR" },
		Tail = { Sway = 5, Hz = 0.13, Lift = 2.5, Counter = 0.5 },
		Arms = { Flex = 6, Hz = 0.25 },
		Jaw = { Breath = 2, Huff = 9, HuffEvery = { 6, 12 } },
		Actions = { "Roar", "TailSwing" },
	},
	Raptor = {
		Breath = { Lift = 0.035, Pitch = 1.2 },
		Shift = { Roll = 2.5, Slide = 0.04, Hz = 0.22 },
		Head = { Yaw = 30, Pitch = 10, Tilt = 9, Hz = 0.1, Base = 0, Mode = "Snap", Hold = { 0.5, 1.9 }, SnapHz = 4.5, SnapDamping = 0.62, Stabilize = 0.95 },
		Planted = { "LegL", "LegR" },
		Tail = { Sway = 4, Hz = 0.2, Lift = 2, FlickEvery = { 2, 4 }, Flick = 11 },
		Arms = { Flex = 7, Hz = 0.5 },
		Jaw = { Breath = 1.5 },
		Actions = { "Roar", "Scan", "TailSwing" },
	},
	Ape = {
		Breath = { Lift = 0.06, Pitch = 2, Shoulder = 2.5 },
		Shift = { Roll = 3, Slide = 0.04, Hz = 0.09 },
		Head = { Yaw = 22, Pitch = 6, Tilt = 4, Hz = 0.07, Base = 0, GlanceEvery = { 4, 9 }, Glance = 25, GlanceHold = { 0.7, 1.5 }, Stabilize = 0.6 },
		Planted = { "LegL", "LegR", "ArmL", "ArmR" },
		Shoulders = { Roll = 3, Hz = 0.12 },
		Knuckles = { Every = { 4, 9 }, Lift = 0.14, Pitch = 10, Length = 0.8 },
		Ears = { FlickEvery = { 3, 7 }, Flick = 18 },
		Jaw = { Breath = 3 },
		Actions = { "ChestBeat", "KnuckleSlam", "HeadScratch" },
	},
	HeavyQuad = {
		Breath = { Lift = 0.04, Pitch = 1.1, HeadBob = 3 },
		Shift = { Roll = 2.5, Slide = 0.035, Hz = 0.08, Pitch = 1.2 },
		Head = { Yaw = 15, Pitch = 4, Tilt = 3, Hz = 0.05, Base = 0, GlanceEvery = { 6, 12 }, Glance = 18, GlanceHold = { 1, 2 }, Stabilize = 0.4 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		Tail = { Sway = 12, Hz = 0.38, Lift = 2 },
		Ears = { FlickEvery = { 3, 7 }, Flick = 22, Fan = 0, FanHz = 0.3 },
		Trunk = { Sway = 7, Curl = 8, Hz = 0.14 },
		Actions = { "Trumpet", "EarFlap", "Stomp" },
	},
	AgileQuad = {
		Breath = { Lift = 0.03, Pitch = 1.2, Speed = 1.25 },
		Shift = { Roll = 2.5, Slide = 0.03, Hz = 0.16, Pitch = 0.8 },
		Head = { Yaw = 24, Pitch = 7, Tilt = 5, Hz = 0.09, Base = 0, GlanceEvery = { 3, 7 }, Glance = 28, GlanceHold = { 0.5, 1.2 }, Stabilize = 0.8 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		Tail = { Sway = 7, Hz = 0.3, Lift = 4, FlickEvery = { 2, 3.5 }, Flick = 14 },
		Ears = { FlickEvery = { 1.5, 4 }, Flick = 20 },
		Sniff = { Every = { 5, 9 }, Length = 0.7, Hz = 6, Pitch = 3 },
		Crouch = { Every = { 8, 14 }, Drop = 0.09, Length = 1.3 },
		Actions = { "PlayBow", "Paw", "Snarl" },
	},
	LowCrawler = {
		Breath = { Lift = 0.025, Pitch = 0.8 },
		Shift = { Roll = 2, Slide = 0.03, Hz = 0.1 },
		Head = { Yaw = 14, Pitch = 3, Tilt = 2, Hz = 0.05, GlanceEvery = { 6, 12 }, Glance = 16, GlanceHold = { 1, 2 }, Stabilize = 0.5 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		Spine = { Bend = 3.5, Hz = 0.16 }, -- body S-curve: the body yaws, the tail sweeps the other way, the head holds
		Tail = { Sway = 9, Hz = 0.16, Lift = 1.5, Wave = 0.9 },
		Jaw = { Pulse = 4, Hz = 0.35 }, -- jaw or gill pulse
		Actions = { "Chomp", "GillFlare", "Wiggle" },
	},
	Hopper = {
		Breath = { Lift = 0.025, Pitch = 1 },
		Throat = { Hz = 1.3, Lift = 0.012, Pitch = 1.5, Glow = 0.35 },
		Shift = { Roll = 1.5, Slide = 0.02, Hz = 0.12 },
		Head = { Yaw = 12, Pitch = 4, Tilt = 3, Hz = 0.06, Mode = "Snap", Hold = { 0.8, 2.2 }, SnapHz = 4, SnapDamping = 0.6, Stabilize = 0.5 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		IdleHop = { Every = { 5, 10 }, Action = "Hop" },
		Actions = { "BigHop", "ThroatPuff", "Hop" },
	},
	Shelled = {
		Breath = { Lift = 0.03, Pitch = 0.8 },
		Shift = { Roll = 1.8, Slide = 0.025, Hz = 0.07 },
		Head = { Yaw = 14, Pitch = 4, Tilt = 2, Hz = 0.04, GlanceEvery = { 7, 13 }, Glance = 15, GlanceHold = { 1.2, 2.4 }, Stabilize = 0.4 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		Extend = { Reach = 0.12, Hz = 0.11 }, -- the head slides out and back in
		Tail = { Sway = 7, Hz = 0.12, Lift = 3 },
		Pulse = 0.45, -- shell cracks pulse harder than the default glow
		Actions = { "ShellHide", "Wiggle" },
	},
	Arthropod = {
		Breath = { Lift = 0.02, Pitch = 0.6 },
		Shift = { Roll = 2, Slide = 0.02, Hz = 0.14, Yaw = 2 },
		Planted = { "LegAL", "LegBL", "LegCL", "LegAR", "LegBR", "LegCR" },
		LegTap = { Every = { 2.5, 5 }, Lift = 9, Step = 0.11, Order = { "LegAL", "LegBL", "LegCL", "LegCR", "LegBR", "LegAR" } },
		Claws = { ClickEvery = { 2, 4 }, Click = 9, Hold = 4 },
		Stalks = { Wiggle = 5, Hz = 0.5, KickEvery = { 1, 3 }, Kick = 7 },
		Actions = { "ClawSnap", "Shiver" },
	},
	Serpent = {
		Breath = { Lift = 0, Pitch = 0, Neck = 2 }, -- breathing shows as a neck lift
		Wave = { Amp = 6, Grow = 0.25, Hz = 0.28, K = 0.95, Vertical = 1.2 }, -- yaw = Amp x (1 + Grow x i) x sin(t x Hz - K x i)
		Neck = { Sway = 6, Hz = 0.12 },
		Head = { Yaw = 20, Pitch = 6, Tilt = 4, Hz = 0.08, GlanceEvery = { 4, 8 }, Glance = 24, GlanceHold = { 0.8, 1.6 }, Stabilize = 0.85 },
		Tongue = { Every = { 1.8, 3.6 }, Reach = 0.3, Length = 0.45 },
		Actions = { "RearUp", "Coil", "Hiss" },
	},
	VerticalCoil = {
		Breath = { Lift = 0.05, Pitch = 0.6, Neck = 1.5 },
		Coil = { Breathe = 1.6, Sway = 2, Hz = 0.09 }, -- the coils rise with each breath
		Neck = { Sway = 6, Hz = 0.08 },
		Head = { Yaw = 20, Pitch = 6, Tilt = 4, Hz = 0.06, GlanceEvery = { 5, 10 }, Glance = 22, GlanceHold = { 1, 2 }, Stabilize = 0.8 },
		Cloud = { Bob = 0.12, Hz = 0.22, Yaw = 4, Roll = 2 },
		Halo = { Sway = 6, Hz = 0.07 },
		Legs = { Curl = 6, Hz = 0.2 },
		Tongue = { Every = { 2.5, 5 }, Reach = 0.3, Length = 0.45 },
		Actions = { "Drumroll", "RearUp" },
	},
	Hydra = {
		Breath = { Lift = 0, Pitch = 0, Neck = 1.5 },
		Wave = { Amp = 4, Grow = 0.2, Hz = 0.22, K = 0.9, Vertical = 0.8 },
		Necks = { Sway = 7, Pitch = 4, Hz = 0.1 }, -- each neck on its own phase
		Head = { Yaw = 22, Pitch = 7, Tilt = 6, Hz = 0.08, GlanceEvery = { 3, 7 }, Glance = 26, GlanceHold = { 0.7, 1.5 }, Stabilize = 0.7 },
		LookAtEachOther = { Every = { 7, 13 }, Length = 1.8, Yaw = 30 },
		SnapSequence = { Every = { 9, 16 }, Gap = 0.22, Pitch = 9 },
		Tongue = { Every = { 2, 4 }, Reach = 0.3, Length = 0.45 },
		Actions = { "Roar", "RearUp", "Squabble" },
	},
	Winged = {
		Breath = { Lift = 0.035, Pitch = 1.2 },
		Shift = { Roll = 2.5, Slide = 0.03, Hz = 0.13, Pitch = 0.8 },
		Head = { Yaw = 22, Pitch = 7, Tilt = 6, Hz = 0.08, GlanceEvery = { 4, 8 }, Glance = 26, GlanceHold = { 0.6, 1.4 }, Stabilize = 0.8 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		Wings = { Breathe = 2.5, Settle = 12, SettleEvery = { 6, 12 }, SettleLength = 1.1 },
		Tail = { Sway = 7, Hz = 0.25, Lift = 3, FlickEvery = { 2.5, 4.5 }, Flick = 12 },
		Actions = { "WingSpread", "Paw" },
	},
	FinLegFish = {
		Breath = { Lift = 0.035, Pitch = 1 },
		Shift = { Roll = 2, Slide = 0.03, Hz = 0.1 },
		Head = { Yaw = 12, Pitch = 4, Tilt = 2, Hz = 0.05, GlanceEvery = { 6, 11 }, Glance = 15, GlanceHold = { 1, 2 }, Stabilize = 0.5 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		PlantWeight = 0.65, -- fin-legs paddle in place, so the feet may drift a little
		Tail = { Sway = 12, Hz = 0.36, Lift = 2, Wave = 1 },
		Gills = { Hz = 0.6, Glow = 0.55, Jaw = 2.5 },
		Paddle = { Pitch = 7, Hz = 0.45 },
		Actions = { "Lunge", "TailSwing" },
	},
	Tentacled = {
		Breath = { Lift = 0.04, Pitch = 1, Joint = "Head" }, -- the mantle breathes
		Shift = { Roll = 1.5, Slide = 0.02, Hz = 0.1 },
		Head = { Yaw = 6, Pitch = 3, Tilt = 3, Hz = 0.05, Stabilize = 0 },
		Tentacles = { Curl = { 4, 9, 16 }, Hz = { 0.22, 0.36 }, Sway = 5 }, -- Curl per link, base to tip
		Ripple = { Every = { 10, 16 }, Curl = 18, Gap = 0.12, Length = 1.2 },
		Actions = { "CurlBurst", "Wiggle" },
	},
	Sauropod = {
		Breath = { Lift = 0.05, Pitch = 1 },
		Shift = { Roll = 2, Slide = 0.04, Hz = 0.07, Pitch = 0.8 },
		Head = { Yaw = 16, Pitch = 5, Tilt = 3, Hz = 0.05, GlanceEvery = { 7, 13 }, Glance = 18, GlanceHold = { 1.2, 2.4 }, Stabilize = 0.6 },
		Planted = { "LegFL", "LegFR", "LegBL", "LegBR" },
		NeckSway = { Yaw = 5, Pitch = 2.5, Hz = 0.075, Delay = 0.55 }, -- Delay: phase lag per link (radians)
		Tail = { Sway = 8, Hz = 0.075, Lift = 2, Counter = 0.8 },
		Orbit = { Ring = 12, Moons = -22, Bob = 0.06 }, -- degrees per second
		Actions = { "Trumpet", "Stomp" },
	},
	GuardianTitan = {
		Breath = { Lift = 0.12, Pitch = 1.6, Shoulder = 4 },
		Shift = { Roll = 2, Slide = 0.08, Hz = 0.05 },
		Head = { Yaw = 16, Pitch = 5, Tilt = 2, Hz = 0.035, GlanceEvery = { 8, 14 }, Glance = 18, GlanceHold = { 1.4, 2.6 }, Stabilize = 0.6 },
		Planted = { "LegL", "LegR" },
		Tail = { Sway = 5, Hz = 0.08, Lift = 2 },
		Arms = { Flex = 3, Hz = 0.1 },
		TrapJaw = { Open = 22, Hz = 0.11, SnapEvery = { 10, 18 } }, -- Thornmaw's trap jaws
		Dust = { Every = { 3, 6 } },
		Actions = { "Roar" },
	},
}

-- The creatures. Profile picks the defaults above; Actions replaces the profile's action list; Rename maps group names
-- to joint names; Parents re-parents joints in the motor chain (by joint name); any other key overrides that profile
-- table by name. Biome and Rarity come from KaijuConfig (guardians: Guardian = their biome).
Config.Creatures = {
	Pebblesaur = { Profile = "LowCrawler", Actions = { "PushUp", "Chomp" } },
	Chompling = { Profile = "LowCrawler", Actions = { "Chomp", "TailSwing", "Lunge" } },
	Thunderback = { -- stands upright with its left fist raised
		Profile = "Ape", Gait = "Biped", Planted = { "LegL", "LegR" }, Knuckles = false,
		Shoulders = { Roll = 1.5, Hz = 0.12 }, Arms = { Flex = 4, Hz = 0.18 },
		Actions = { "GroundPunch", "ChestBeat", "Roar" },
	},
	Rumblerex = { Profile = "Rex" },
	Magmite = { Profile = "Arthropod", Actions = { "ClawSnap", "MagmaBurp" } },
	Scorchback = { Profile = "HeavyQuad", Actions = { "TailSwing", "Stomp" }, Tail = { Sway = 6, Hz = 0.22, Lift = 1 }, Pulse = 0.4 },
	BlazeBonkey = { Profile = "Ape", Actions = { "ChestBeat", "KnuckleSlam" } },
	MoltenRex = { Profile = "Rex" },
	Snowpup = { Profile = "AgileQuad", Actions = { "PlayBow", "Paw", "Howl" } },
	Frostrhino = { Profile = "HeavyQuad", Actions = { "Paw", "HornToss", "Snort" }, Tail = { Sway = 14, Hz = 0.5, Lift = 1 } },
	Brrrilla = { Profile = "Ape", Actions = { "ChestBeat", "KnuckleSlam" } },
	IcebreakerRex = { Profile = "Rex", Actions = { "Roar", "TailSwing", "Stomp" } },
	AuroraSerpent = { Profile = "Serpent", Actions = { "RearUp", "Coil" } },
	Vinewhip = { Profile = "Raptor" },
	Bonkey = { Profile = "Ape" },
	Tuskit = { Profile = "HeavyQuad", Ears = { Fan = 9 } },
	Sabrejag = { Profile = "AgileQuad" },
	Lurkfin = { Profile = "LowCrawler" },
	CinderToad = { Profile = "Hopper" },
	Cometshell = { Profile = "Shelled" },
	GlacierCrab = { Profile = "Arthropod" },
	InfernoSerpent = { Profile = "Serpent" },
	RaijinWyrm = { Profile = "VerticalCoil" },
	Hydravine = { Profile = "Hydra", Parents = { NeckLeft = "Body", NeckRight = "Body" } },
	Stormgriff = { Profile = "Winged" },
	Megajaw = { Profile = "FinLegFish" },
	Krakling = { Profile = "Tentacled" },
	Astrodon = { Profile = "Sauropod", Rename = { Head = "Neck1", HeadTop = "Head" } },
	Thornmaw = { Profile = "GuardianTitan", Guardian = "VenomJungle" },
	Prismling = { Profile = "Winged", Actions = { "WingFlare", "PlayBow" }, Shimmer = { "FacetC", "FacetM" } },
}

-- Walking (pen kaiju wander: the server sets WanderFrom / WanderTo / MoveStart / MoveEnd). Each planted limb steps on
-- its Phase (0..1) of the cycle: down for Duty of it, sliding back under the body at the walking speed so it never
-- skids, then lifted (Lift, a share of leg length) and swung forward. Stride: the longest step, as a share of leg
-- length (the cadence rises to keep steps within it). Bob (studs), Lean / Roll / Yaw (degrees) move the body with the
-- steps. Profiles pick a gait by name; a creature can override it with Gait = "...".
Config.Gaits = {
	Biped = { Duty = 0.6, Stride = 0.8, Lift = 0.22, Bob = 0.06, Lean = -3, Roll = 3, Phase = { LegL = 0, LegR = 0.5 } },
	Knuckle = { Duty = 0.6, Stride = 0.7, Lift = 0.2, Bob = 0.05, Lean = -4, Roll = 2.5, Phase = { LegL = 0, ArmR = 0, LegR = 0.5, ArmL = 0.5 } },
	Trot = { Duty = 0.6, Stride = 0.8, Lift = 0.22, Bob = 0.04, Lean = -1, Roll = 1.5, Phase = { LegFL = 0, LegBR = 0, LegFR = 0.5, LegBL = 0.5 } },
	Amble = { Duty = 0.7, Stride = 0.7, Lift = 0.18, Bob = 0.03, Roll = 2, Phase = { LegBL = 0, LegFL = 0.25, LegBR = 0.5, LegFR = 0.75 } },
	Crawl = { Duty = 0.65, Stride = 0.8, Lift = 0.18, Bob = 0.015, Yaw = 6, Phase = { LegFL = 0, LegBR = 0, LegFR = 0.5, LegBL = 0.5 } },
	Tripod = { Duty = 0.55, Stride = 0.6, Lift = 0.2, Bob = 0.02, Roll = 1.5, Sideways = true,
		Phase = { LegAL = 0, LegCL = 0, LegBR = 0, LegBL = 0.5, LegAR = 0.5, LegCR = 0.5 } },
	Hop = { Duty = 0.45, Stride = 0.9, Lift = 0.15, Hop = 0.35, Phase = { LegFL = 0, LegFR = 0, LegBL = 0, LegBR = 0 } },
	Slither = { Wave = 20, K = 1.05, Neck = 12 }, -- no feet: a travelling S-wave, the neck cancels it so the head keeps course
	Drift = { Curl = 10 }, -- tentacles ripple harder while it moves
}
Config.ProfileGaits = {
	Rex = "Biped", Raptor = "Biped", Ape = "Knuckle", HeavyQuad = "Amble", AgileQuad = "Trot", LowCrawler = "Crawl",
	Hopper = "Hop", Shelled = "Amble", Arthropod = "Tripod", Serpent = "Slither", VerticalCoil = "Slither",
	Hydra = "Slither", Winged = "Trot", FinLegFish = "Crawl", Tentacled = "Drift", Sauropod = "Amble",
	GuardianTitan = "Biped",
}

-- States (the engine reads game state, never writes it). Range: studs from the creature. LookYaw / LookPitch: how far
-- the head may turn to track someone.
Config.States = {
	OwnerNearby = { Range = 20, LookYaw = 45, LookPitch = 20, GreetCooldown = 25, GreetSmall = { "Hop", "TailWag", "Wiggle" } },
	StrangerNearby = { Range = 20, LookYaw = 50, LookPitch = 20, WarnEvery = { 6, 11 }, Warn = { "Snarl", "Hiss", "Growl" } },
	Night = { Tempo = 0.82, Amp = 0.85, Glow = 1.25, DozeShare = 0.35, DozeHead = -14, DozeDrop = 0.03 },
	Asleep = { Breath = 1.8, Drop = 0.08, Head = -22, Tempo = 0.7 },
	Carried = { Breath = 0.45, Paddle = 18, PaddleHz = 4.5, Thrash = 20, ThrashHz = 3.5, LookBack = 50 },
	Hatched = { Action = "Pop", Window = 2.5 }, -- a creature spawned (SpawnedAt) less than Window seconds ago pops in
}

-- Visual effects, created once per creature when it registers (never per frame).
Config.VFX = {
	Pulse = 0.22, -- neon accents brighten by this much on each inhale (profiles can set their own Pulse)
	Blink = { Every = { 2.5, 6 }, Length = 0.13, Double = 0.2 },
	Rarity = {
		Uncommon = { Sparkle = 1.5 },
		Rare = { Light = { Range = 7, Brightness = 0.5 } },
		Epic = { Pulse = 0.35, Sparkle = 2.5 },
		Legendary = { Pulse = 0.35, GroundAura = 0.94, AuraRate = 5, Gold = 3 }, -- GroundAura: the disc's transparency
		Mythic = { Pulse = 0.4, GroundAura = 0.9, AuraRate = 8, Motes = 5, Highlight = 26 },
		Secret = { Pulse = 0.4, Rainbow = 0.18, GroundAura = 0.92, AuraRate = 7 }, -- Rainbow: hue cycles per second
		Guardian = { GroundAura = 0.9, AuraRate = 10, AuraScale = 1.4 },
	},
	Biome = {
		PebblePlains = { Kind = "Dust", Color = "C9B48A", Rate = 0.8 },
		LavaLagoon = { Kind = "Embers", Color = "FF7A2E", Rate = 1.2 },
		FrostfangPeaks = { Kind = "Snow", Color = "E8F6FF", Rate = 0.9, FrostBreath = true },
		VenomJungle = { Kind = "Spores", Color = "A8F05A", Rate = 0.9 },
		SunkenAbyss = { Kind = "Bubbles", Color = "8FE3FF", Rate = 1 },
		StormSpires = { Kind = "Sparks", Color = "9FD8FF", Rate = 0.8 },
		CosmicRift = { Kind = "Stars", Color = "F2D9FF", Rate = 0.9 },
		Any = { Kind = "Glints", Color = "FFFFFF", Rate = 1.2 }, -- Prismling: prism glints
	},
	GuardianAura = {
		PebblePlains = "C9A46A", LavaLagoon = "FF6A1F", FrostfangPeaks = "9FE4FF", VenomJungle = "7CFF4A",
		SunkenAbyss = "3FD0FF", StormSpires = "9FB8FF", CosmicRift = "FF6AE8",
	},
}

-- Studio-only test area: one creature per profile in a row, high above the map.
Config.Gallery = {
	Origin = Vector3.new(0, 900, 0),
	Gap = 8, -- studs between neighbours
	Order = {
		"Rumblerex", "Vinewhip", "Bonkey", "Tuskit", "Sabrejag", "Lurkfin", "CinderToad", "Cometshell", "GlacierCrab",
		"InfernoSerpent", "RaijinWyrm", "Hydravine", "Stormgriff", "Megajaw", "Krakling", "Astrodon", "Thornmaw", "Prismling",
	},
}

------------------------------------------------------------------------------------------------------------------ ACTIONS
-- Actions[name][variant]: the variant is picked by creature name first, then profile, then "Default".
-- Duration: seconds at scale 1 (bigger creatures take longer by sqrt(scale)). Calm: how much the action quiets the
-- idle head look-around (0..1). Pivot: what the body rotates about: "Center" (default), "Hips" or "Shoulders".
-- Tracks: { selector, channel, keys, options }. Keys: { time, value, time, value, ... } with time 0..1 of Duration.
--   selectors: a joint name ("Head"), a prefix with * ("Tail*", "LegF*", "Wing*"), "@Spine" (Seg1..n and a serpent's
--     Tail), "@Heads" (every head), "@Tentacles" (every tentacle link)
--   channels: pitch / yaw / roll (degrees; pitch up = nose up, jaw open = negative, tail tip up = negative), x / y / z
--     (studs; -z is forward), plant (0..1, how firmly a planted foot stays put), spin (degrees added to a spinner),
--     spinRate (extra spin speed, 1 = double), curl (degrees, tentacles), glow (0..1 extra neon brightness)
--   options: Mirror (the R side gets yaw, roll and x flipped, so motions are symmetric), Grow (amplitude grows by this
--     per chain link), Height (y values are fractions of the creature's height), Osc = { Hz, Amp, From, To, Phase,
--     Decay } (an oscillation inside From..To, eased in and out; Decay fades it out across the window), Spread (Osc
--     phase step per tentacle)
-- Events: { time, kind, arg }: Sound (an emote name GameAudio knows: Roar, ChestBeat, ...), Dust (at a joint's foot,
--   or "Body"), Shake (camera shake if the camera is close), Burst (sparkles), Flash (neon parts by name, comma
--   separated), DrumFlash (Raijin's drums in sequence, arg = seconds), Shimmer (a light sweep across the facets).
Config.Actions = {
	Pop = {
		Default = {
			Duration = 1.1, Calm = 1,
			Tracks = {
				{ "Body", "y", { 0, -0.32, 0.36, 0.1, 0.56, -0.035, 0.78, 0.01, 1, 0 }, Height = true },
				{ "Body", "pitch", { 0, -10, 0.36, 7, 0.6, -2, 0.85, 0.5, 1, 0 } },
				{ "Leg*", "plant", { 0, 0, 0.5, 0, 0.6, 1, 1, 1 } },
				{ "Arm*", "plant", { 0, 0, 0.5, 0, 0.6, 1, 1, 1 } },
				{ "Leg*", "roll", { 0, 22, 0.36, -6, 0.6, 0, 1, 0 }, Mirror = true },
				{ "Head", "pitch", { 0, -14, 0.4, 12, 0.66, -3, 1, 0 } },
				{ "Tail*", "pitch", { 0, 16, 0.4, -10, 0.7, 2, 1, 0 }, Grow = 0.3 },
				{ "Wing*", "roll", { 0, -12, 0.4, 24, 0.72, -3, 1, 0 }, Mirror = true },
				{ "Ear*", "roll", { 0, -10, 0.42, 16, 0.72, 0, 1, 0 }, Mirror = true },
				{ "@Spine", "yaw", nil, Osc = { Hz = 3, Amp = 8, From = 0.3, To = 1, Decay = true }, Grow = 0.2 },
				{ "@Tentacles", "curl", { 0, 30, 0.4, -14, 0.7, 3, 1, 0 }, Grow = 0.4 },
			},
			Events = { { 0.05, "Sound", "Hop" }, { 0.32, "Burst" }, { 0.55, "Dust", "Body" } },
		},
	},
	Wiggle = {
		Default = {
			Duration = 1, Calm = 0.5,
			Tracks = {
				{ "Body", "roll", nil, Osc = { Hz = 4.5, Amp = 6, From = 0, To = 1, Decay = true } },
				{ "Head", "roll", nil, Osc = { Hz = 4.5, Amp = 5, From = 0.05, To = 1, Decay = true, Phase = 2.4 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 4.5, Amp = 9, From = 0.05, To = 1, Decay = true, Phase = 1.2 }, Grow = 0.3 },
			},
		},
		Shelled = {
			Duration = 1.6, Calm = 0.5,
			Tracks = {
				{ "Body", "roll", nil, Osc = { Hz = 2.2, Amp = 5, From = 0, To = 1, Decay = true } },
				{ "Head", "yaw", nil, Osc = { Hz = 2.2, Amp = 8, From = 0.05, To = 1, Decay = true, Phase = 1.6 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.2, Amp = 10, From = 0.05, To = 1, Decay = true, Phase = 1 }, Grow = 0.4 },
			},
		},
		Tentacled = {
			Duration = 1.8, Calm = 0.5,
			Tracks = {
				{ "@Tentacles", "curl", nil, Osc = { Hz = 2.4, Amp = 10, From = 0, To = 1, Decay = true }, Grow = 0.4, Spread = 0.8 },
				{ "Head", "roll", nil, Osc = { Hz = 2.4, Amp = 4, From = 0, To = 1, Decay = true } },
			},
		},
	},
	TailWag = {
		Default = {
			Duration = 1.4, Calm = 0.4,
			Tracks = {
				{ "Tail*", "yaw", nil, Osc = { Hz = 5.5, Amp = 14, From = 0.05, To = 0.95 }, Grow = 0.25 },
				{ "Tail*", "pitch", { 0, 0, 0.2, -10, 0.8, -10, 1, 0 } },
				{ "Body", "roll", nil, Osc = { Hz = 5.5, Amp = 1.2, From = 0.05, To = 0.95, Phase = 3.14 } },
				{ "Head", "roll", { 0, 0, 0.2, 8, 0.8, 8, 1, 0 } },
				{ "Ear*", "roll", { 0, 0, 0.2, 10, 0.8, 10, 1, 0 }, Mirror = true },
			},
		},
	},
	Growl = {
		Default = {
			Duration = 1.9, Calm = 0.8,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.2, -0.05, 0.8, -0.05, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.2, -3, 0.8, -3, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.18, -9, 0.82, -8, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.2, -12, 0.8, -12, 1, 0 }, Osc = { Hz = 9, Amp = 2.5, From = 0.2, To = 0.8 } },
				{ "Ear*", "roll", { 0, 0, 0.15, -16, 0.85, -16, 1, 0 }, Mirror = true },
				{ "Tail*", "pitch", { 0, 0, 0.2, 6, 0.8, 6, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.2, Amp = 6, From = 0.2, To = 0.85 }, Grow = 0.3 },
			},
			Events = { { 0.2, "Sound", "Roar" } },
		},
	},
	Roar = {
		Default = {
			Duration = 2, Calm = 1,
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.15, -2, 0.32, 6, 0.75, 5, 0.88, -1, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.15, -6, 0.32, 22, 0.75, 20, 0.88, -3, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 7, Amp = 2.5, From = 0.32, To = 0.75 } },
				{ "Jaw", "pitch", { 0, 0, 0.22, 2, 0.32, -30, 0.75, -28, 0.86, 0, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.32, -6, 0.75, -5, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.3, "Sound", "Roar" } },
		},
		Rex = { -- stomp, then roar with the head thrown back and the jaw wide; a light shake if the camera is close
			Duration = 2.6, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "LegR", "plant", { 0, 1, 0.04, 0, 0.22, 0, 0.27, 1, 1, 1 } },
				{ "LegR", "y", { 0, 0, 0.13, 0.32, 0.2, 0.26, 0.25, 0, 1, 0 } },
				{ "LegR", "pitch", { 0, 0, 0.13, 10, 0.25, 0, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.13, -2.5, 0.26, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.25, -0.05, 0.31, 0, 0.36, -0.03, 0.46, 0.05, 0.8, 0.04, 0.92, -0.01, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.26, -1, 0.35, -3, 0.47, 9, 0.78, 8, 0.9, -1.5, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, -2, 0.37, -9, 0.49, 28, 0.78, 26, 0.9, -4, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 7, Amp = 2.5, From = 0.49, To = 0.8 } },
				{ "Jaw", "pitch", { 0, 0, 0.37, 3, 0.47, -34, 0.78, -32, 0.9, 0, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.37, -6, 0.49, 24, 0.8, 20, 1, 0 } },
				{ "Arm*", "roll", { 0, 0, 0.49, 16, 0.8, 14, 1, 0 }, Mirror = true },
				{ "Tail*", "pitch", { 0, 0, 0.47, -7, 0.8, -6, 1, 0 }, Grow = 0.3 },
				{ "Tail*", "yaw", nil, Osc = { Hz = 3.5, Amp = 5, From = 0.47, To = 0.86 }, Grow = 0.4 },
			},
			Events = { { 0.25, "Dust", "LegR" }, { 0.25, "Shake", 0.2 }, { 0.38, "Sound", "Roar" }, { 0.46, "Shake", 0.5 } },
		},
		Raptor = { -- a screech: the head thrusts up and shakes, jaw wide, arms flared
			Duration = 1.9, Calm = 1,
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.15, -3, 0.3, 7, 0.72, 6, 0.86, -1, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.15, -0.03, 0.3, 0.04, 0.72, 0.03, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.15, -10, 0.3, 22, 0.72, 20, 0.86, -3, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 10, Amp = 3.5, From = 0.3, To = 0.72 } },
				{ "Head", "roll", nil, Osc = { Hz = 5, Amp = 4, From = 0.3, To = 0.72, Phase = 1 } },
				{ "Jaw", "pitch", { 0, 0, 0.22, 2, 0.3, -38, 0.72, -36, 0.84, 0, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.3, 30, 0.72, 26, 1, 0 } },
				{ "Arm*", "roll", { 0, 0, 0.3, 20, 0.72, 18, 1, 0 }, Mirror = true },
				{ "Tail*", "pitch", { 0, 0, 0.3, -9, 0.72, -8, 1, 0 }, Grow = 0.3 },
				{ "Tail*", "yaw", nil, Osc = { Hz = 6, Amp = 4, From = 0.3, To = 0.8 }, Grow = 0.5 },
			},
			Events = { { 0.28, "Sound", "Roar" } },
		},
		Hydra = { -- the three heads roar in sequence: left, centre, right
			Duration = 3.2, Calm = 1,
			Tracks = {
				{ "NeckLeft", "pitch", { 0, 0, 0.06, -4, 0.14, 12, 0.32, 11, 0.42, 0, 1, 0 } },
				{ "HeadLeft", "pitch", { 0, 0, 0.06, -6, 0.14, 26, 0.32, 24, 0.42, -2, 0.5, 0, 1, 0 } },
				{ "HeadLeft", "yaw", nil, Osc = { Hz = 8, Amp = 3, From = 0.14, To = 0.33 } },
				{ "Neck", "pitch", { 0, 0, 0.35, -4, 0.43, 12, 0.62, 11, 0.72, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.35, -6, 0.43, 28, 0.62, 26, 0.72, -2, 0.8, 0, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.36, 3, 0.43, -34, 0.62, -32, 0.72, 0, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 8, Amp = 3, From = 0.43, To = 0.63 } },
				{ "NeckRight", "pitch", { 0, 0, 0.64, -4, 0.72, 12, 0.9, 11, 0.98, 0, 1, 0 } },
				{ "HeadRight", "pitch", { 0, 0, 0.64, -6, 0.72, 26, 0.9, 24, 0.98, -2, 1, 0 } },
				{ "HeadRight", "yaw", nil, Osc = { Hz = 8, Amp = 3, From = 0.72, To = 0.91 } },
				{ "@Spine", "yaw", nil, Osc = { Hz = 1.2, Amp = 4, From = 0, To = 1 }, Grow = 0.3 },
			},
			Events = { { 0.12, "Sound", "Roar" }, { 0.42, "Sound", "Roar" }, { 0.71, "Sound", "Roar" } },
		},
		GuardianTitan = {
			Duration = 3, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.14, -3, 0.3, 11, 0.7, 10, 0.84, -1.5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.14, -0.15, 0.3, 0.12, 0.7, 0.1, 0.86, -0.03, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.16, -10, 0.32, 26, 0.7, 24, 0.86, -4, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 5, Amp = 3, From = 0.32, To = 0.7 } },
				{ "Jaw", "pitch", { 0, 0, 0.2, 4, 0.32, -40, 0.7, -38, 0.84, 0, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.18, -10, 0.34, 40, 0.7, 36, 1, 0 } },
				{ "Arm*", "roll", { 0, 0, 0.34, 22, 0.7, 20, 1, 0 }, Mirror = true },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.4, Amp = 8, From = 0.3, To = 0.85 } },
				{ "Tail*", "pitch", { 0, 0, 0.3, -8, 0.7, -7, 1, 0 } },
			},
			Events = { { 0.3, "Sound", "Roar" }, { 0.33, "Shake", 0.7 }, { 0.34, "Dust", "Body" } },
		},
	},
	TailSwing = {
		Scorchback = { -- the armoured club swings round, back plates flaring bright
			Duration = 2, Calm = 0.8,
			Tracks = {
				{ "Tail*", "yaw", { 0, 0, 0.22, -14, 0.46, 34, 0.6, 28, 0.78, -8, 0.9, 2, 1, 0 }, Grow = 0.3 },
				{ "Tail*", "pitch", { 0, 0, 0.22, -6, 0.5, -4, 1, 0 } },
				{ "Body", "yaw", { 0, 0, 0.22, 3, 0.46, -5, 0.62, -4, 0.8, 1, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.22, 1.5, 0.46, -2, 0.7, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.22, -0.04, 0.5, -0.03, 0.8, 0, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.25, -10, 0.5, 12, 0.8, 0, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.15, 0.6, 0.46, 1, 0.75, 0.6, 1, 0 } },
			},
			Events = { { 0.36, "Sound", "TailSwing" }, { 0.44, "Flash", "Magma,MagmaHot" }, { 0.46, "Shake", 0.15 }, { 0.46, "Dust", "Body" } },
		},
		Default = {
			Duration = 1.8, Calm = 0.6,
			Tracks = {
				{ "Tail*", "yaw", { 0, 0, 0.18, -10, 0.42, 30, 0.62, -20, 0.8, 7, 1, 0 }, Grow = 0.25 },
				{ "Tail*", "pitch", { 0, 0, 0.3, -5, 0.8, -3, 1, 0 } },
				{ "Body", "yaw", { 0, 0, 0.18, 2.5, 0.42, -4, 0.62, 3, 0.8, -1, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.42, -1.5, 0.62, 1.2, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.2, -8, 0.45, 14, 0.7, 0, 1, 0 } },
			},
			Events = { { 0.32, "Sound", "TailSwing" } },
		},
		Raptor = { -- a fast whip
			Duration = 1.4, Calm = 0.5,
			Tracks = {
				{ "Tail*", "yaw", { 0, 0, 0.12, -8, 0.28, 22, 0.44, -18, 0.6, 12, 0.76, -5, 1, 0 }, Grow = 0.35 },
				{ "Tail*", "pitch", { 0, 0, 0.25, -6, 0.8, -4, 1, 0 } },
				{ "Body", "yaw", { 0, 0, 0.12, 2, 0.28, -3, 0.44, 2.5, 0.6, -1.5, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.2, -6, 0.5, 6, 1, 0 } },
			},
			Events = { { 0.22, "Sound", "TailSwing" } },
		},
	},
	Scan = {
		Raptor = { -- the head snaps left, holds, snaps right, holds, then back
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "Head", "yaw", { 0, 0, 0.08, 38, 0.3, 38, 0.38, -38, 0.62, -38, 0.7, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.08, 6, 0.3, 6, 0.38, 4, 0.62, 4, 0.7, 10, 0.85, 10, 1, 0 } },
				{ "Head", "roll", { 0, 0, 0.08, -8, 0.3, -6, 0.38, 8, 0.62, 6, 0.7, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.1, 0.04, 0.85, 0.04, 1, 0 } },
				{ "Body", "yaw", { 0, 0, 0.08, 6, 0.3, 5, 0.38, -6, 0.62, -5, 0.7, 0, 1, 0 } },
				{ "Tail*", "yaw", { 0, 0, 0.08, -8, 0.3, -6, 0.38, 8, 0.62, 6, 0.7, 0, 1, 0 }, Grow = 0.3 },
			},
		},
	},
	ChestBeat = {
		Brrrilla = { -- the ape chest pound with a big frosty breath
			Extends = "Ape",
			Events = { { 0.22, "Breath", 2 }, { 0.5, "Breath", 2 }, { 0.62, "Breath", 1.5 } },
		},
		BlazeBonkey = { -- the ape chest pound, shedding embers with every beat
			Extends = "Ape",
			Tracks = { { "Body", "glow", { 0, 0, 0.2, 0.8, 0.62, 0.8, 0.75, 0, 1, 0 } } },
			Events = { { 0.24, "Flash", "Flame,MagmaHot" }, { 0.3, "Burst" }, { 0.48, "Flash", "Flame,MagmaHot" }, { 0.52, "Burst" }, { 0.77, "Burst" } },
		},
		Thunderback = { -- upright: the free right fist drums its chest while the raised left fist pumps
			Duration = 2.4, Calm = 1,
			Tracks = {
				{ "ArmR", "pitch", { 0, 0, 0.15, 75, 0.75, 75, 0.9, 0, 1, 0 }, Osc = { Hz = 6, Amp = 14, From = 0.16, To = 0.74 } },
				{ "ArmR", "roll", { 0, 0, 0.15, 30, 0.75, 30, 0.9, 0, 1, 0 } },
				{ "ArmL", "pitch", { 0, 0, 0.15, 10, 0.75, 8, 1, 0 }, Osc = { Hz = 3, Amp = 10, From = 0.16, To = 0.74, Phase = 1 } },
				{ "Body", "pitch", { 0, 0, 0.15, 6, 0.75, 6, 1, 0 } },
				{ "Body", "y", nil, Osc = { Hz = 6, Amp = 0.02, From = 0.16, To = 0.74 } },
				{ "Head", "pitch", { 0, 0, 0.15, 16, 0.75, 14, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.18, -20, 0.7, -18, 0.8, 0, 1, 0 } },
			},
			Events = { { 0.16, "Sound", "ChestBeat" }, { 0.45, "Sound", "ChestBeat" }, { 0.3, "Flash", "Spark,Vein" } },
		},
		Ape = { -- rears onto its legs, pounds its chest, then drops back onto its knuckles
			Duration = 2.6, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Arm*", "plant", { 0, 1, 0.04, 0, 0.7, 0, 0.78, 1, 1, 1 } },
				{ "Body", "pitch", { 0, 0, 0.08, -3, 0.2, 22, 0.62, 20, 0.74, -3, 0.86, 1, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.08, -0.04, 0.2, 0.06, 0.62, 0.05, 0.74, -0.05, 0.86, 0.01, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.2, 70, 0.62, 70, 0.72, 10, 0.78, 0, 1, 0 } },
				{ "Arm*", "roll", { 0, 0, 0.2, -28, 0.62, -28, 0.72, 0, 1, 0 }, Mirror = true },
				{ "ArmL", "pitch", nil, Osc = { Hz = 6, Amp = 16, From = 0.2, To = 0.62 } },
				{ "ArmR", "pitch", nil, Osc = { Hz = 6, Amp = 16, From = 0.2, To = 0.62, Phase = 3.14 } },
				{ "Head", "pitch", { 0, 0, 0.2, 14, 0.62, 12, 0.74, -6, 0.86, 0, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.22, -16, 0.6, -14, 0.7, 0, 1, 0 } },
				{ "Ear*", "roll", { 0, 0, 0.2, 14, 0.62, 12, 0.75, 0, 1, 0 }, Mirror = true },
			},
			Events = { { 0.2, "Sound", "ChestBeat" }, { 0.45, "Sound", "ChestBeat" }, { 0.76, "Dust", "ArmL" }, { 0.76, "Dust", "ArmR" }, { 0.76, "Shake", 0.15 } },
		},
	},
	KnuckleSlam = {
		Ape = { -- both fists up, then slammed into the ground
			Duration = 1.8, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Arm*", "plant", { 0, 1, 0.04, 0, 0.5, 0, 0.56, 1, 1, 1 } },
				{ "Body", "pitch", { 0, 0, 0.12, -2, 0.36, 14, 0.5, -4, 0.62, -5, 0.8, 0.5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.12, -0.03, 0.36, 0.06, 0.5, -0.06, 0.66, -0.05, 0.85, 0.005, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.36, 75, 0.46, 20, 0.5, -4, 0.62, -4, 0.85, 0, 1, 0 } },
				{ "Arm*", "roll", { 0, 0, 0.36, 12, 0.5, 0, 1, 0 }, Mirror = true },
				{ "Head", "pitch", { 0, 0, 0.36, 10, 0.5, -8, 0.7, -4, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.3, -10, 0.5, -20, 0.62, -6, 1, 0 } },
			},
			Events = { { 0.49, "Sound", "BigHop" }, { 0.5, "Dust", "ArmL" }, { 0.5, "Dust", "ArmR" }, { 0.5, "Shake", 0.3 } },
		},
	},
	HeadScratch = {
		Ape = { -- one hand up to scratch its head, which tilts into the scratch
			Duration = 2.6, Calm = 0.8,
			Tracks = {
				{ "ArmR", "plant", { 0, 1, 0.06, 0, 0.84, 0, 0.92, 1, 1, 1 } },
				{ "ArmR", "pitch", { 0, 0, 0.22, 95, 0.78, 95, 0.9, 0, 1, 0 }, Osc = { Hz = 5, Amp = 6, From = 0.26, To = 0.74 } },
				{ "ArmR", "roll", { 0, 0, 0.22, 30, 0.78, 30, 0.9, 0, 1, 0 } },
				{ "Head", "roll", { 0, 0, 0.22, 10, 0.78, 10, 0.9, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.22, -6, 0.78, -6, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.2, -3, 0.8, -3, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.2, 6, 0.8, 6, 1, 0 } },
			},
		},
	},
	Trumpet = {
		HeavyQuad = { -- head and trunk up, ears out, a trumpet blast
			Duration = 2.4, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.12, -2, 0.3, 5, 0.7, 4.5, 0.85, -0.5, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.25, 0.6, 0.75, 0.6, 0.85, 1, 1, 1 } },
				{ "Head", "pitch", { 0, 0, 0.12, -6, 0.3, 16, 0.7, 15, 0.85, -2, 1, 0 } },
				{ "Trunk*", "pitch", { 0, 0, 0.14, -8, 0.3, 50, 0.7, 46, 0.86, -4, 1, 0 }, Grow = -0.15 },
				{ "Trunk3", "pitch", nil, Osc = { Hz = 9, Amp = 4, From = 0.32, To = 0.7 } },
				{ "Ear*", "roll", { 0, 0, 0.28, 26, 0.7, 24, 0.86, 0, 1, 0 }, Mirror = true },
				{ "Tail*", "yaw", nil, Osc = { Hz = 4, Amp = 12, From = 0.3, To = 0.8 } },
			},
			Events = { { 0.3, "Sound", "Trumpet" } },
		},
		Sauropod = { -- rears its long neck high while the ring and moons speed up
			Duration = 3.2, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.12, -2, 0.32, 6, 0.74, 5.5, 0.88, -0.5, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.25, 0.5, 0.75, 0.5, 0.86, 1, 1, 1 } },
				{ "Neck1", "pitch", { 0, 0, 0.14, -4, 0.34, 14, 0.74, 13, 0.88, -1, 1, 0 } },
				{ "Neck2", "pitch", { 0, 0, 0.16, -3, 0.36, 10, 0.74, 9, 0.9, -1, 1, 0 } },
				{ "Neck3", "pitch", { 0, 0, 0.18, -2, 0.38, 6, 0.74, 5, 0.92, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, 4, 0.4, 18, 0.72, 16, 0.9, -2, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 5, Amp = 2, From = 0.42, To = 0.72 } },
				{ "Ring", "spinRate", { 0, 0, 0.3, 3, 0.8, 3, 1, 0 } },
				{ "Moons", "spinRate", { 0, 0, 0.3, 3.5, 0.8, 3.5, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.3, 0.7, 0.8, 0.7, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.32, -6, 0.74, -5, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.4, "Sound", "Trumpet" } },
		},
	},
	EarFlap = {
		HeavyQuad = {
			Duration = 2, Calm = 0.7,
			Tracks = {
				{ "Ear*", "roll", { 0, 0, 0.1, 12, 0.85, 12, 1, 0 }, Mirror = true, Osc = { Hz = 3.2, Amp = 22, From = 0.1, To = 0.85 } },
				{ "Head", "yaw", nil, Osc = { Hz = 1.6, Amp = 7, From = 0.1, To = 0.85 } },
				{ "Head", "pitch", { 0, 0, 0.1, 4, 0.85, 4, 1, 0 } },
				{ "Trunk*", "yaw", nil, Osc = { Hz = 1.6, Amp = 9, From = 0.1, To = 0.9, Phase = 1.3 }, Grow = 0.3 },
			},
		},
	},
	Stomp = {
		Rex = { -- a biped: the right foot lifts high and stamps down
			Duration = 1.6, Calm = 0.7, Pivot = "Hips",
			Tracks = {
				{ "LegR", "plant", { 0, 1, 0.06, 0, 0.38, 0, 0.44, 1, 1, 1 } },
				{ "LegR", "y", { 0, 0, 0.26, 0.4, 0.36, 0.3, 0.42, 0, 1, 0 } },
				{ "LegR", "pitch", { 0, 0, 0.26, 12, 0.42, 0, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.26, -3, 0.44, 1, 0.62, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.42, -0.06, 0.55, 0.01, 0.7, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.26, 8, 0.44, -8, 0.64, 0, 1, 0 } },
				{ "Arm*", "pitch", { 0, 0, 0.26, 14, 0.44, -6, 0.7, 0, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.26, -6, 0.44, 4, 0.7, 0, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.42, "Sound", "BigHop" }, { 0.43, "Dust", "LegR", 1.3 }, { 0.43, "Shake", 0.25 } },
		},
		Default = { -- a front foot lifts and stomps down
			Duration = 1.5, Calm = 0.6,
			Tracks = {
				{ "LegFR", "plant", { 0, 1, 0.06, 0, 0.36, 0, 0.42, 1, 1, 1 } },
				{ "LegFR", "y", { 0, 0, 0.24, 0.3, 0.34, 0.24, 0.4, 0, 1, 0 } },
				{ "LegFR", "pitch", { 0, 0, 0.24, 14, 0.4, 0, 1, 0 } },
				{ "Body", "roll", { 0, 0, 0.24, -2.5, 0.42, 0.8, 0.6, 0, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.24, 2.5, 0.42, -1.5, 0.6, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.24, 6, 0.42, -6, 0.62, 0, 1, 0 } },
				{ "Ring", "spin", { 0, 0, 0.41, 0, 0.5, 6, 0.7, -2, 1, 0 } },
			},
			Events = { { 0.4, "Sound", "BigHop" }, { 0.41, "Dust", "LegFR" }, { 0.41, "Shake", 0.18 } },
		},
	},
	PlayBow = {
		Default = { -- front down, rump and tail up, a wag, then a little bounce
			Duration = 2.2, Calm = 0.8, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.18, -14, 0.62, -13, 0.74, 2, 0.84, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.18, -0.04, 0.62, -0.04, 0.72, 0.18, 0.8, -0.02, 0.9, 0, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.1, 0.25, 0.64, 0.25, 0.68, 0, 0.82, 0, 0.88, 1, 1, 1 } },
				{ "LegB*", "plant", { 0, 1, 0.66, 1, 0.7, 0, 0.82, 0, 0.88, 1, 1, 1 } },
				{ "LegF*", "pitch", { 0, 0, 0.18, 22, 0.62, 20, 0.72, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.18, 12, 0.62, 10, 0.8, 0, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.18, -16, 0.62, -14, 0.8, 0, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 5, Amp = 12, From = 0.18, To = 0.66 }, Grow = 0.3 },
				{ "Ear*", "roll", { 0, 0, 0.18, 10, 0.66, 10, 1, 0 }, Mirror = true },
				{ "Wing*", "roll", { 0, 0, 0.18, 10, 0.66, 8, 1, 0 }, Mirror = true },
			},
			Events = { { 0.2, "Sound", "PlayBow" } },
		},
	},
	Paw = {
		Default = { -- the front right paw scrapes the ground three times, head down to watch it
			Duration = 1.7, Calm = 0.9,
			Tracks = {
				{ "LegFR", "plant", { 0, 1, 0.06, 0, 0.88, 0, 0.95, 1, 1, 1 } },
				{ "LegFR", "y", { 0, 0, 0.12, 0.12, 0.88, 0.1, 0.95, 0, 1, 0 } },
				{ "LegFR", "pitch", { 0, 0, 0.12, 8, 0.88, 6, 0.95, 0, 1, 0 }, Osc = { Hz = 3.5, Amp = 14, From = 0.15, To = 0.86 } },
				{ "Body", "roll", { 0, 0, 0.12, -2, 0.88, -2, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.12, -14, 0.88, -12, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.12, 8, 0.88, 8, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.5, Amp = 8, From = 0.1, To = 0.9 }, Grow = 0.3 },
			},
			Events = { { 0.1, "Sound", "Paw" } },
		},
	},
	Snarl = {
		AgileQuad = { -- crouches, ears flat, lips back in a shaking snarl, tail lashing
			Duration = 1.9, Calm = 1,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.15, -0.07, 0.8, -0.07, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.15, -4, 0.8, -4, 1, 0 } },
				{ "Body", "z", { 0, 0, 0.15, 0.06, 0.8, 0.06, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.15, -6, 0.3, 4, 0.8, 3, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.15, -8, 0.3, -24, 0.78, -22, 0.9, 0, 1, 0 }, Osc = { Hz = 11, Amp = 2, From = 0.3, To = 0.78 } },
				{ "Ear*", "roll", { 0, 0, 0.12, -24, 0.85, -24, 1, 0 }, Mirror = true },
				{ "Tail*", "yaw", nil, Osc = { Hz = 3, Amp = 10, From = 0.15, To = 0.85 }, Grow = 0.4 },
				{ "Tail*", "pitch", { 0, 0, 0.15, 4, 0.85, 4, 1, 0 } },
			},
			Events = { { 0.28, "Sound", "Roar" } },
		},
	},
	Chomp = {
		Default = { -- the head lunges up and the jaws snap twice
			Duration = 1.5, Calm = 0.9,
			Tracks = {
				{ "Head", "pitch", { 0, 0, 0.15, 10, 0.3, 4, 0.5, 9, 0.66, 3, 0.85, 0, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.12, -30, 0.24, 0, 0.42, -28, 0.54, 0, 0.7, -24, 0.8, 0, 1, 0 } },
				{ "Body", "z", { 0, 0, 0.12, -0.05, 0.8, -0.03, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.12, 2, 0.8, 1.5, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.5, Amp = 6, From = 0.1, To = 0.9 }, Grow = 0.3 },
			},
			Events = { { 0.22, "Sound", "Chomp" }, { 0.52, "Sound", "Chomp" } },
		},
	},
	GillFlare = {
		Default = { -- puffs up, head raised, gills flaring bright
			Duration = 2, Calm = 0.8,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.2, 0.04, 0.7, 0.04, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.2, 3, 0.7, 3, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.2, 9, 0.7, 8, 0.85, -1, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.2, -12, 0.7, -10, 0.85, 0, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.2, 1, 0.7, 1, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.2, -6, 0.7, -6, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 3, Amp = 8, From = 0.2, To = 0.8 }, Grow = 0.4 },
			},
			Events = { { 0.2, "Flash", "GillTip,Glow" } },
		},
	},
	Eat = {
		Default = { -- thrown food landed on it (MarketFX's EatAt): leans in, dips to the food and chews
			Duration = 1.2, Calm = 1,
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.18, -4, 0.8, -4, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.18, -18, 0.8, -16, 1, 0 }, Osc = { Hz = 5, Amp = 5, From = 0.2, To = 0.8 } },
				{ "Neck*", "pitch", { 0, 0, 0.18, -10, 0.8, -10, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.15, -16, 0.22, -4, 1, 0 }, Osc = { Hz = 5, Amp = 8, From = 0.22, To = 0.82 } },
				{ "Trunk*", "pitch", { 0, 0, 0.2, 40, 0.8, 38, 1, 0 }, Grow = -0.2 },
				{ "Claw*", "pitch", { 0, 0, 0.2, 30, 0.8, 30, 1, 0 }, Osc = { Hz = 4, Amp = 10, From = 0.2, To = 0.8 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 4, Amp = 8, From = 0.1, To = 0.9 }, Grow = 0.3 },
			},
			Events = { { 0, "Sound", "Eat" } },
		},
	},
	Howl = {
		AgileQuad = { -- sits back on its haunches and howls at the sky
			Duration = 2.8, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.15, 12, 0.85, 12, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.15, -0.05, 0.85, -0.05, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.1, 0.4, 0.88, 0.4, 0.95, 1, 1, 1 } },
				{ "Head", "pitch", { 0, 0, 0.12, -6, 0.25, 34, 0.8, 32, 0.92, -2, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 1.5, Amp = 3, From = 0.25, To = 0.8 } },
				{ "Jaw", "pitch", { 0, 0, 0.25, -24, 0.78, -20, 0.86, 0, 1, 0 } },
				{ "Ear*", "roll", { 0, 0, 0.2, -14, 0.85, -14, 1, 0 }, Mirror = true },
				{ "Tail*", "pitch", { 0, 0, 0.2, 10, 0.85, 10, 1, 0 } },
			},
			Events = { { 0.26, "Sound", "Roar" }, { 0.3, "Breath", 1.5 }, { 0.55, "Breath", 1.5 } },
		},
	},
	HornToss = {
		HeavyQuad = { -- head down, then the horn tossed up hard
			Duration = 1.7, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Head", "pitch", { 0, 0, 0.3, -22, 0.44, 30, 0.6, 24, 0.78, -3, 1, 0 } },
				{ "Head", "roll", { 0, 0, 0.3, 6, 0.44, -8, 0.7, 0, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.3, -5, 0.44, 6, 0.6, 5, 0.8, -1, 1, 0 } },
				{ "Body", "z", { 0, 0, 0.3, 0.06, 0.44, -0.12, 0.7, 0, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.36, 0.6, 0.7, 0.6, 0.8, 1, 1, 1 } },
				{ "Ear*", "roll", { 0, 0, 0.3, -14, 0.5, 10, 0.8, 0, 1, 0 }, Mirror = true },
				{ "Tail*", "yaw", nil, Osc = { Hz = 4, Amp = 14, From = 0.3, To = 0.8 } },
			},
			Events = { { 0.42, "Sound", "TailSwing" }, { 0.44, "Breath", 1.5 }, { 0.3, "Dust", "LegFR" } },
		},
	},
	Snort = {
		HeavyQuad = { -- two sharp snorts, head jerking, breath puffing
			Duration = 1.4, Calm = 0.8,
			Tracks = {
				{ "Head", "pitch", { 0, 0, 0.15, -6, 0.22, 4, 0.4, -6, 0.48, 4, 0.7, 0, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.15, 4, 0.4, -4, 0.7, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.15, -0.02, 0.22, 0.01, 0.4, -0.02, 0.48, 0.01, 0.7, 0, 1, 0 } },
				{ "Ear*", "roll", nil, Osc = { Hz = 5, Amp = 12, From = 0.15, To = 0.6 }, Mirror = true },
			},
			Events = { { 0.2, "Breath", 1 }, { 0.46, "Breath", 1.3 } },
		},
	},
	MagmaBurp = {
		Magmite = { -- puffs up, claws spread, then belches a flash of magma
			Duration = 1.8, Calm = 0.8,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.3, 0.06, 0.48, 0.07, 0.56, -0.03, 0.7, 0.01, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.3, 6, 0.48, 7, 0.56, -5, 0.72, 1, 1, 0 } },
				{ "Claw*", "roll", { 0, 0, 0.3, 14, 0.5, 14, 0.62, 4, 1, 0 }, Mirror = true },
				{ "Claw*", "pitch", { 0, 0, 0.3, 12, 0.5, 10, 0.62, -6, 1, 0 } },
				{ "Eye*", "pitch", { 0, 0, 0.3, 10, 0.5, 10, 0.56, -12, 0.7, 0, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.3, 0.5, 0.52, 1, 0.8, 0, 1, 0 } },
			},
			Events = { { 0.54, "Flash", "Mouth,Magma,MagmaHot,Belly" }, { 0.55, "Burst" }, { 0.56, "Sound", "Chomp" } },
		},
	},
	PushUp = {
		LowCrawler = { -- a lizard's display: three push-ups on the front legs, the head bobbing with each one
			Duration = 2.4, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.12, 2, 0.2, 9, 0.3, 1, 0.42, 9, 0.52, 1, 0.64, 10, 0.76, 0, 0.86, -1, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.2, 0.06, 0.3, 0.01, 0.42, 0.06, 0.52, 0.01, 0.64, 0.07, 0.76, 0, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.1, 0.4, 0.8, 0.4, 0.86, 1, 1, 1 } },
				{ "Head", "pitch", { 0, 0, 0.2, -8, 0.3, 6, 0.42, -8, 0.52, 6, 0.64, -9, 0.76, 4, 0.88, 0, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.6, 0, 0.66, -14, 0.76, 0, 1, 0 } },
				{ "Tail*", "yaw", nil, Osc = { Hz = 2.2, Amp = 6, From = 0.1, To = 0.9 }, Grow = 0.3 },
			},
			Events = { { 0.64, "Sound", "Chomp" } },
		},
	},
	GroundPunch = {
		Thunderback = { -- lightning crackles down the raised left arm, then the fist slams into the ground
			Duration = 2.6, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "ArmL", "pitch", { 0, 0, 0.3, 14, 0.38, -40, 0.46, -150, 0.72, -145, 0.9, 4, 1, 0 } },
				{ "ArmL", "roll", { 0, 0, 0.3, 6, 0.46, -12, 0.72, -12, 1, 0 } },
				{ "ArmL", "yaw", nil, Osc = { Hz = 14, Amp = 2, From = 0.02, To = 0.3 } },
				{ "ArmR", "pitch", { 0, 0, 0.3, -8, 0.46, 20, 0.72, 18, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.3, 5, 0.46, -20, 0.72, -18, 0.88, 1.5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.3, 0.04, 0.46, -0.22, 0.72, -0.2, 0.88, 0.02, 1, 0 } },
				{ "Body", "yaw", { 0, 0, 0.3, -8, 0.46, 10, 0.72, 8, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, 14, 0.46, -12, 0.72, -10, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.3, -20, 0.46, -30, 0.6, -6, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.05, 1, 0.5, 1, 0.8, 0, 1, 0 } },
			},
			Events = {
				{ 0.04, "Flash", "Spark" }, { 0.14, "Flash", "Vein" }, { 0.24, "Flash", "Bolt,Spark" }, { 0.3, "Sound", "Roar" },
				{ 0.45, "Sound", "BigHop" }, { 0.46, "Dust", "Body", 1.6 }, { 0.46, "Burst" }, { 0.46, "Shake", 0.45 }, { 0.47, "Flash", "Vein,Bolt" },
			},
		},
	},
	Lunge = {
		Default = { -- rocks back, jaw wide open, lunges forward and snaps shut
			Duration = 1.9, Calm = 1,
			Tracks = {
				{ "Body", "z", { 0, 0, 0.25, 0.14, 0.42, -0.4, 0.6, -0.36, 0.82, 0.02, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.25, 4, 0.42, -3, 0.6, -2, 0.85, 0.5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.25, -0.04, 0.42, 0.03, 0.6, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.25, 12, 0.42, 4, 0.52, -6, 0.7, -3, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.25, -42, 0.44, -44, 0.52, 0, 0.62, -4, 0.72, 0, 1, 0 } },
				{ "Tail*", "yaw", { 0, 0, 0.25, -8, 0.42, 12, 0.6, -6, 0.8, 2, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.52, "Sound", "Chomp" }, { 0.52, "Shake", 0.12 } },
		},
	},
	Hop = {
		Default = { -- a small hop with a squash on take-off and on landing
			Duration = 0.95, Calm = 0.4,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.16, -0.05, 0.46, 0.38, 0.74, -0.06, 0.86, 0.01, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.16, -3, 0.3, 7, 0.56, -2, 0.74, -4, 0.88, 0.5, 1, 0 } },
				{ "Leg*", "plant", { 0, 1, 0.2, 1, 0.26, 0, 0.66, 0, 0.74, 1, 1, 1 } },
				{ "Arm*", "plant", { 0, 1, 0.2, 1, 0.26, 0, 0.66, 0, 0.74, 1, 1, 1 } },
				{ "LegB*", "pitch", { 0, 0, 0.26, -24, 0.48, -10, 0.68, 0, 1, 0 } },
				{ "LegF*", "pitch", { 0, 0, 0.3, 6, 0.6, 14, 0.72, 0, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, 6, 0.6, -4, 0.8, 0, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.3, 8, 0.6, -10, 0.8, 0, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.22, "Sound", "Hop" }, { 0.74, "Dust", "Body" } },
		},
	},
	BigHop = {
		Hopper = { -- a big leap straight up, back legs kicking out, front legs reaching to land
			Duration = 1.35, Calm = 0.8,
			Tracks = {
				{ "Body", "y", { 0, 0, 0.15, -0.08, 0.45, 1.1, 0.72, -0.09, 0.84, 0.015, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.15, -5, 0.3, 12, 0.55, -4, 0.72, -6, 0.86, 1, 1, 0 } },
				{ "Leg*", "plant", { 0, 1, 0.18, 1, 0.24, 0, 0.68, 0, 0.72, 1, 1, 1 } },
				{ "LegB*", "pitch", { 0, 0, 0.24, -32, 0.5, -12, 0.66, 0, 1, 0 } },
				{ "LegF*", "pitch", { 0, 0, 0.3, 8, 0.58, 20, 0.7, 0, 1, 0 } },
				{ "Leg*", "roll", { 0, 0, 0.3, 6, 0.6, 10, 0.72, 0, 1, 0 }, Mirror = true },
				{ "Head", "pitch", { 0, 0, 0.3, 10, 0.6, -6, 0.8, 0, 1, 0 } },
			},
			Events = { { 0.2, "Sound", "BigHop" }, { 0.72, "Dust", "Body" }, { 0.72, "Shake", 0.12 } },
		},
	},
	ThroatPuff = {
		Hopper = { -- chin up, the glowing throat pulses three times
			Duration = 1.8, Calm = 0.8,
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.15, 5, 0.8, 5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.15, 0.03, 0.8, 0.03, 1, 0 }, Osc = { Hz = 2.6, Amp = 0.025, From = 0.15, To = 0.85 } },
				{ "Head", "pitch", { 0, 0, 0.15, 12, 0.8, 11, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.15, 0.4, 0.85, 0.4, 1, 0 }, Osc = { Hz = 2.6, Amp = 0.6, From = 0.15, To = 0.85 } },
			},
			Events = { { 0.18, "Flash", "Belly,Mouth" }, { 0.55, "Flash", "Belly,Mouth" } },
		},
	},
	ShellHide = {
		Shelled = { -- pulls head and legs into the shell, waits, then peeks back out
			Duration = 3.2, Calm = 1,
			Tracks = {
				{ "Head", "z", { 0, 0, 0.16, 0.3, 0.62, 0.3, 0.7, -0.04, 0.78, 0.18, 0.9, -0.03, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.16, -10, 0.62, -10, 0.7, 6, 0.78, -4, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.66, 0, 0.72, 12, 0.76, -10, 0.8, 0, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.16, -0.12, 0.62, -0.12, 0.8, 0, 1, 0 } },
				{ "Leg*", "plant", { 0, 1, 0.08, 0, 0.72, 0, 0.82, 1, 1, 1 } },
				{ "Leg*", "y", { 0, 0, 0.16, 0.12, 0.62, 0.12, 0.8, 0, 1, 0 } },
				{ "Leg*", "roll", { 0, 0, 0.16, -10, 0.62, -10, 0.8, 0, 1, 0 }, Mirror = true },
				{ "Tail*", "pitch", { 0, 0, 0.16, 14, 0.62, 12, 0.85, 0, 1, 0 }, Grow = 0.3 },
			},
		},
	},
	ClawSnap = {
		Arthropod = { -- both claws up, snapping
			Duration = 1.6, Calm = 0.6,
			Tracks = {
				{ "Claw*", "pitch", { 0, 0, 0.12, 24, 0.8, 22, 0.92, 0, 1, 0 } },
				{ "Claw*", "roll", { 0, 0, 0.12, 8, 0.8, 8, 1, 0 }, Mirror = true },
				{ "ClawL", "pitch", nil, Osc = { Hz = 6.5, Amp = 9, From = 0.14, To = 0.8 } },
				{ "ClawR", "pitch", nil, Osc = { Hz = 6.5, Amp = 9, From = 0.14, To = 0.8, Phase = 2 } },
				{ "Body", "y", { 0, 0, 0.12, 0.03, 0.8, 0.03, 1, 0 } },
				{ "Body", "pitch", { 0, 0, 0.12, 3, 0.8, 3, 1, 0 } },
				{ "Eye*", "pitch", { 0, 0, 0.12, 8, 0.8, 8, 1, 0 } },
			},
			Events = { { 0.15, "Sound", "ClawSnap" }, { 0.5, "Sound", "ClawSnap" } },
		},
	},
	Shiver = {
		Arthropod = { -- a full-body shiver, legs rattling, a puff of frost
			Duration = 1.5, Calm = 0.6,
			Tracks = {
				{ "Body", "roll", nil, Osc = { Hz = 13, Amp = 2.2, From = 0.05, To = 0.9, Decay = true } },
				{ "Body", "y", { 0, 0, 0.1, -0.03, 0.85, -0.02, 1, 0 } },
				{ "Leg*", "roll", nil, Osc = { Hz = 9, Amp = 4, From = 0.05, To = 0.85, Decay = true }, Mirror = true },
				{ "Claw*", "pitch", { 0, 0, 0.1, -8, 0.85, -6, 1, 0 } },
				{ "Eye*", "roll", nil, Osc = { Hz = 7, Amp = 10, From = 0.05, To = 0.9, Decay = true }, Mirror = true },
			},
			Events = { { 0.1, "Burst" } },
		},
	},
	RearUp = {
		Serpent = { -- rises like a cobra, swaying, tongue flicking
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "Neck", "pitch", { 0, 0, 0.12, -6, 0.3, 30, 0.75, 28, 0.9, -2, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, -4, 0.75, -4, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 1.4, Amp = 10, From = 0.3, To = 0.8 } },
				{ "Seg1", "pitch", { 0, 0, 0.3, 4, 0.75, 4, 1, 0 } },
				{ "@Spine", "yaw", nil, Osc = { Hz = 0.9, Amp = 5, From = 0.2, To = 0.9 }, Grow = 0.3 },
				{ "Tongue", "z", { 0, 0, 0.35, -0.22, 0.7, -0.22, 0.78, 0, 1, 0 }, Osc = { Hz = 6, Amp = 0.12, From = 0.35, To = 0.7 } },
			},
			Events = { { 0.22, "Sound", "RearUp" } },
		},
		VerticalCoil = {
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "Neck", "pitch", { 0, 0, 0.14, -4, 0.32, 14, 0.75, 13, 0.9, -1, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.32, 8, 0.75, 7, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.32, -14, 0.75, -12, 0.88, 0, 1, 0 } },
				{ "Seg1", "pitch", { 0, 0, 0.32, 4, 0.75, 4, 1, 0 } },
				{ "Cloud", "y", { 0, 0, 0.32, 0.1, 0.75, 0.1, 1, 0 } },
				{ "Leg*", "pitch", { 0, 0, 0.32, 14, 0.75, 12, 1, 0 } },
			},
			Events = { { 0.3, "Sound", "RearUp" } },
		},
		Hydra = {
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "Neck", "pitch", { 0, 0, 0.12, -4, 0.32, 18, 0.75, 16, 0.9, -1, 1, 0 } },
				{ "NeckLeft", "pitch", { 0, 0, 0.16, -4, 0.36, 14, 0.75, 13, 0.9, -1, 1, 0 } },
				{ "NeckRight", "pitch", { 0, 0, 0.1, -4, 0.3, 14, 0.75, 13, 0.9, -1, 1, 0 } },
				{ "@Heads", "pitch", { 0, 0, 0.32, 6, 0.75, 5, 1, 0 } },
				{ "@Heads", "yaw", nil, Osc = { Hz = 1.2, Amp = 8, From = 0.32, To = 0.8 } },
				{ "Seg1", "pitch", { 0, 0, 0.32, 3, 0.75, 3, 1, 0 } },
				{ "Tongue", "z", { 0, 0, 0.35, -0.2, 0.7, -0.2, 0.8, 0, 1, 0 }, Osc = { Hz = 6, Amp = 0.12, From = 0.35, To = 0.7 } },
			},
			Events = { { 0.28, "Sound", "RearUp" } },
		},
	},
	Coil = {
		Serpent = { -- curls up tight, head pulled in, then relaxes
			Duration = 3, Calm = 0.8,
			Tracks = {
				{ "@Spine", "yaw", { 0, 0, 0.3, 16, 0.72, 15, 0.9, -2, 1, 0 }, Grow = 0.15 },
				{ "Neck", "pitch", { 0, 0, 0.3, -8, 0.72, -8, 1, 0 } },
				{ "Neck", "yaw", { 0, 0, 0.3, -20, 0.72, -18, 1, 0 } },
				{ "Head", "yaw", { 0, 0, 0.3, 14, 0.72, 12, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.3, -4, 0.72, -4, 1, 0 } },
			},
		},
	},
	Hiss = {
		Serpent = { -- draws back, then a short strike with the jaw open and the tongue out
			Duration = 1.5, Calm = 1,
			Tracks = {
				{ "Neck", "pitch", { 0, 0, 0.2, -8, 0.36, 14, 0.7, 12, 1, 0 } },
				{ "Neck", "z", { 0, 0, 0.2, 0.08, 0.36, -0.12, 0.7, -0.1, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.2, 4, 0.36, 10, 0.7, 8, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.3, -28, 0.7, -26, 0.84, 0, 1, 0 } },
				{ "Head", "yaw", nil, Osc = { Hz = 9, Amp = 2, From = 0.36, To = 0.7 } },
				{ "Tongue", "z", { 0, 0, 0.36, -0.25, 0.7, -0.25, 0.8, 0, 1, 0 }, Osc = { Hz = 8, Amp = 0.12, From = 0.36, To = 0.7 } },
			},
			Events = { { 0.34, "Sound", "RearUp" } },
		},
	},
	Drumroll = {
		VerticalCoil = { -- the drum halo turns and each drum flashes in sequence
			Duration = 2.6, Calm = 0.8,
			Tracks = {
				{ "Halo", "spin", { 0, 0, 0.12, -4, 0.55, 25, 0.75, 27, 0.9, -3, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.12, -4, 0.3, 10, 0.75, 8, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.3, -12, 0.75, -10, 0.88, 0, 1, 0 } },
				{ "Neck", "pitch", { 0, 0, 0.3, 4, 0.75, 4, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.2, 0.6, 0.8, 0.6, 1, 0 } },
			},
			Events = {
				{ 0.18, "DrumFlash", 1.2 }, { 0.2, "Sound", "ChestBeat" }, { 0.36, "Sound", "ChestBeat" }, { 0.52, "Sound", "ChestBeat" },
				{ 0.7, "Flash", "Bolt,BoltHot" },
			},
		},
	},
	Squabble = {
		Hydra = { -- the side heads turn on each other and snap while the centre head pulls back
			Duration = 2.2, Calm = 1,
			Tracks = {
				{ "HeadLeft", "yaw", { 0, 0, 0.12, 32, 0.8, 30, 0.92, 0, 1, 0 } },
				{ "HeadRight", "yaw", { 0, 0, 0.12, -32, 0.8, -30, 0.92, 0, 1, 0 } },
				{ "NeckLeft", "yaw", { 0, 0, 0.12, 10, 0.8, 9, 1, 0 } },
				{ "NeckRight", "yaw", { 0, 0, 0.12, -10, 0.8, -9, 1, 0 } },
				{ "HeadLeft", "pitch", nil, Osc = { Hz = 4, Amp = 9, From = 0.18, To = 0.78 } },
				{ "HeadRight", "pitch", nil, Osc = { Hz = 4, Amp = 9, From = 0.18, To = 0.78, Phase = 3.14 } },
				{ "Head", "pitch", { 0, 0, 0.12, -8, 0.8, -6, 1, 0 } },
				{ "Neck", "z", { 0, 0, 0.12, 0.06, 0.8, 0.06, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.3, -10, 0.5, -2, 0.62, -12, 0.8, 0, 1, 0 } },
			},
			Events = { { 0.3, "Sound", "Chomp" }, { 0.55, "Sound", "Chomp" } },
		},
	},
	WingSpread = {
		Winged = { -- rears up, spreads its wings wide with lightning along the feathers
			Duration = 2.8, Calm = 1, Pivot = "Hips",
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.12, -3, 0.3, 16, 0.72, 15, 0.86, -1.5, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.12, -0.04, 0.3, 0.08, 0.72, 0.07, 0.88, -0.01, 1, 0 } },
				{ "LegF*", "plant", { 0, 1, 0.1, 0, 0.78, 0, 0.86, 1, 1, 1 } },
				{ "LegF*", "pitch", { 0, 0, 0.3, 24, 0.72, 20, 0.84, 0, 1, 0 } },
				{ "Wing*", "roll", { 0, 0, 0.12, -6, 0.32, 58, 0.72, 55, 0.86, -5, 1, 0 }, Mirror = true, Osc = { Hz = 2.4, Amp = 6, From = 0.34, To = 0.7 } },
				{ "Wing*", "yaw", { 0, 0, 0.32, -12, 0.72, -10, 1, 0 }, Mirror = true },
				{ "Head", "pitch", { 0, 0, 0.3, 14, 0.72, 12, 0.86, -2, 1, 0 } },
				{ "Jaw", "pitch", { 0, 0, 0.32, -18, 0.6, -16, 0.72, 0, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.3, -10, 0.72, -9, 1, 0 }, Grow = 0.3 },
			},
			Events = { { 0.26, "Sound", "TailSwing" }, { 0.36, "Sound", "Roar" }, { 0.34, "Flash", "Bolt,BoltHot" }, { 0.36, "Shake", 0.15 } },
		},
	},
	WingFlare = {
		Prismling = { -- wings flare wide while a shimmer sweeps across the crystal facets
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "Body", "pitch", { 0, 0, 0.15, -2, 0.32, 8, 0.72, 7, 0.86, -1, 1, 0 } },
				{ "Body", "y", { 0, 0, 0.15, -0.03, 0.32, 0.06, 0.72, 0.05, 1, 0 } },
				{ "Wing*", "roll", { 0, 0, 0.15, -6, 0.34, 46, 0.72, 44, 0.86, -4, 1, 0 }, Mirror = true },
				{ "Head", "pitch", { 0, 0, 0.32, 12, 0.72, 10, 1, 0 } },
				{ "Tail*", "pitch", { 0, 0, 0.32, -8, 0.72, -7, 1, 0 }, Grow = 0.3 },
				{ "Body", "glow", { 0, 0, 0.3, 0.8, 0.75, 0.8, 1, 0 } },
			},
			Events = { { 0.3, "Sound", "TailSwing" }, { 0.34, "Shimmer", 0.9 }, { 0.36, "Burst" } },
		},
	},
	CurlBurst = {
		Tentacled = { -- every tentacle curls into a ball, then bursts back out
			Duration = 2.6, Calm = 1,
			Tracks = {
				{ "@Tentacles", "curl", { 0, 0, 0.36, 34, 0.5, 36, 0.58, -24, 0.72, 6, 0.86, -2, 1, 0 }, Grow = 0.35 },
				{ "Head", "y", { 0, 0, 0.36, -0.12, 0.5, -0.12, 0.58, 0.1, 0.72, -0.02, 1, 0 } },
				{ "Head", "pitch", { 0, 0, 0.36, -6, 0.5, -6, 0.58, 8, 0.75, 0, 1, 0 } },
				{ "Body", "glow", { 0, 0, 0.5, 0, 0.56, 1, 0.8, 0, 1, 0 } },
			},
			Events = { { 0.56, "Sound", "TailSwing" }, { 0.57, "Burst" } },
		},
	},
}

return Config
