-- Guardians. One resident guardian per biome sleeps by its nest, and every player who takes an egg there gets a guardian
-- of their own: the resident wakes for the first thief, and while it's busy a copy rises out of the ground beside the
-- nest for each other thief. A guardian only ever chases its own player:
--   resident: Sleeping -> Waking (roar) -> Chasing -> Returning -> Sleeping
--   copy:     Rising (out of the ground) -> Waking -> Chasing -> Returning -> Leaving (sinks back into the ground)
-- A chase runs from the far end of the guardian's biome through every biome nearer the bases, all the way to the safe
-- zone (Map attribute SafeZoneX; the lanes are joined end to end). It gives up when its player reaches the safe zone,
-- drops or delivers the egg, dies or leaves, or the chase runs too long (MaxChaseSeconds plus the time to run the whole
-- way home). While walking home it goes after its player again if they carry another egg from its biome nearby.
-- Caught players are ragdolled (Lib.Ragdoll) and flung back toward the safe zone (-X); the egg drops where they were.
-- A dropped egg (caught, clicked down, died) inside its own biome's chase area is fetched by that biome's guardian - the
-- one that was after the player, else the resident if it's free - and dragged home behind it at Guardian.HaulSpeed
-- (slow, so players can catch up), then set back in the nest (EggService:ReturnToNest). The egg keeps its "Grab" prompt
-- the whole time (egg State "Guardian" while dragged); whoever grabs it gets that same guardian after them, after a
-- short roar (REGRAB_ROAR). Fetching/dragging is part of the "Returning" state, so clients just see it walking.
-- Model attribute CarryingEgg (EggId) while it drags an egg.
-- Guardians aim a little ahead of a running player (LEAD_SECONDS), smoothed so the heading doesn't jerk.
-- Chase speed scales with the player it chases, so every chase is close whatever their speed:
-- (each constant below is a default; a biome can override it in BiomeConfig - Pebble Plains is gentler)
--   right behind them (within FOLLOW_DISTANCE studs past catch reach): TRAIL_PACE x their pace - on their heels, but a
--     player at the biome's RecommendedSpeed or faster who keeps running gets away at the safe zone;
--   further back: their pace plus a catch-up of CATCHUP_PER_STUD per stud, never more than MAX_CATCHUP x their pace,
--     so it closes in steadily instead of rocketing up (and never below its own WalkSpeed);
--   under-speed thieves (Speed below the biome's RecommendedSpeed, the lane sign's "Too slow"): it roars for only
--     UNDERSPEED_WAKE, then runs at UNDERSPEED_BOOST x their pace plus a hard catch-up (UNDERSPEED_CATCHUP_PER_STUD,
--     up to UNDERSPEED_MAX_CATCHUP x their pace), so it's on them in moments and knocks the egg off them.
--   over-speed thieves (RunSpeed above the biome's RecommendedSpeed): the whole chase pace is scaled down by
--     1 / (1 + OVERSPEED_FALLOFF x fraction over), never below OVERSPEED_MIN_PACE - the further over the recommended
--     speed, the slower it runs and the less likely it is to reach them (overspeedPace below).
-- Uses ServerStorage.Assets.Kaiju.Guardian_<BiomeId> if present, otherwise builds a placeholder.
-- Model attributes: BiomeId, State, TargetUserId (its player while it has one), Personal (a copy), RiseAt / SinkAt
--   (server time a copy started rising / sinking; Gameplay.KaijuFX animates both).
-- Rig: a "Body" Motor6D (HumanoidRootPart -> BodyJoint) is added at runtime and carries the body bricks and every limb
--   motor, so clients can bob, lean and turn the whole body (Gameplay.KaijuFX).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local Ragdoll = require(game:GetService("ServerScriptService").Lib.Ragdoll)
local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)

local GuardianService = {}

local TICK = 0.1
local RISE_SECONDS = 1.1 -- a copy climbing out of the ground (KaijuFX uses the same number)
local SINK_SECONDS = 1.2 -- a copy sinking away once it's home
local LEAD_SECONDS = 0.2
local FOLLOW_DISTANCE = 6 -- studs beyond catch reach a guardian trails a player by
local CATCHUP_PER_STUD = 0.8 -- extra studs/s for every stud it's further back than that...
local MAX_CATCHUP = 0.3 -- ...up to this fraction of the player's pace on top of it
local TRAIL_PACE = 0.97 -- fraction of the player's pace it runs at once it's on their heels
local MAX_CHASE_SPEED = 250
-- Against a player below the biome's RecommendedSpeed (the lane sign's "Too slow") a guardian is much quicker:
local UNDERSPEED_BOOST = 1.4 -- pace multiple (a biome can override with Guardian.UnderspeedBoost)
local UNDERSPEED_WAKE = 0.25 -- seconds of roar before it charges (instead of Guardian.WakeDelay)
local underspeed -- (defined below, before step)
local UNDERSPEED_CATCHUP_PER_STUD = 1.5 -- closes a gap this much faster per stud behind...
local UNDERSPEED_MAX_CATCHUP = 0.6 -- ...up to this fraction of their pace on top
-- Against a player above the biome's RecommendedSpeed a guardian is slower, more so the further over they are:
-- pace x 1 / (1 + OVERSPEED_FALLOFF * (RunSpeed / RecommendedSpeed - 1)), floored at OVERSPEED_MIN_PACE.
-- e.g. 10% over -> 0.87x, 25% over -> 0.73x, 50% over -> 0.57x, double -> 0.4x (the floor).
-- (a biome can override with Guardian.OverspeedFalloff / Guardian.OverspeedMinPace)
local OVERSPEED_FALLOFF = 1.5
local OVERSPEED_MIN_PACE = 0.4
local MAX_PER_BIOME = 8
local CAUGHT_RAGDOLL_SECONDS = 1.4 -- a caught player flops (and can't grab eggs) this long
local FLING_SCALE = 0.5 -- fling speed toward the safe zone, as a fraction of the biome's Knockback (a ragdoll slides far)
local FLING_UP = 0.55 -- upward part of the fling, as a fraction of that
local POST_CATCH_PAUSE = 1 -- seconds it stands over the egg after a catch before picking it up (time to come back for it)
local FETCH_REACH = 3 -- studs past its body at which a guardian scoops up a dropped egg
local REGRAB_ROAR = 1.2 -- seconds it roars before chasing someone who snatched the egg back off it
-- Extra seconds of roar before every chase (taking a nest egg, snatching one back off it), on top of WakeDelay /
-- UNDERSPEED_WAKE / REGRAB_ROAR: a head start so a thief can get going, on mobile too.
local HEADSTART = 1.75
-- Picking a dropped egg up: it stops, reaches down (GRAB_DIP; KaijuFX ducks the head / arms to the ground off the model
-- attribute GrabAt), takes the egg at the bottom, then straightens up (GRAB_RISE) before setting off home.
local GRAB_DIP = 0.45
local GRAB_RISE = 0.45
-- Snatching it back: the egg rides at jaw / chest height (14-18 studs up), so its prompt reaches this far across the
-- ground (not counting the height) and needs no hold - the guardian is walking away with it.
local GRAB_REACH_FLAT = 30
-- where copies rise, around the resident's spot (the lane runs along X)
local COPY_OFFSETS = {
	Vector3.new(0, 0, 18),
	Vector3.new(0, 0, -18),
	Vector3.new(14, 0, 28),
	Vector3.new(14, 0, -28),
	Vector3.new(-12, 0, 26),
	Vector3.new(-12, 0, -26),
	Vector3.new(26, 0, 0),
}

local zones = {} -- [biomeId] = { biome, cfg, minX, maxX, halfZ, safeX, maxChase, ground, resident }
local guardians = {} -- [g] = true: every guardian in the world
local folder
local gameEvent
local kaijuAssets

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Guardian]", ...)
	end
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function billboard(parent, name, text, color, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromOffset(160, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = bb
	bb.Parent = parent
	return bb
end

local function weldPart(root, name, size, offset, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = root.Parent
	return p
end

-- Blocky placeholder: body, head, legs, glowing back plates, eyes that open when awake. Faces -Z.
local function buildPlaceholder(biome, cframe)
	local s = biome.Guardian.Scale
	local body = biome.GroundA:Lerp(Color3.new(0, 0, 0), 0.45)
	local model = Instance.new("Model")
	model.Name = "Guardian_" .. biome.Id

	local hipHeight = 2 * s
	local rootSize = Vector3.new(7, 6, 9) * s
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = cframe + Vector3.new(0, hipHeight + rootSize.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	weldPart(root, "Body", rootSize, CFrame.new(), body)
	weldPart(root, "Belly", Vector3.new(5, 4, 1) * s, CFrame.new(0, -0.5 * s, -4.3 * s), Color3.fromHex("FFEBC2"))
	local head = weldPart(root, "Head", Vector3.new(6, 5, 5) * s, CFrame.new(0, 3 * s, -5.5 * s), body)
	weldPart(root, "Snout", Vector3.new(4.5, 2, 2.5) * s, CFrame.new(0, 1.8 * s, -8.6 * s), Color3.fromHex("FFEBC2"))
	for _, sx in { -1, 1 } do
		weldPart(root, "EyeOpen", Vector3.new(1.4, 1.4, 0.3) * s, CFrame.new(sx * 1.6 * s, 4 * s, -8.05 * s), Color3.new(1, 1, 1))
		weldPart(root, "Pupil", Vector3.new(0.7, 0.8, 0.3) * s, CFrame.new(sx * 1.5 * s, 3.9 * s, -8.2 * s), Color3.fromHex("1A1033"))
		weldPart(root, "EyeClosed", Vector3.new(1.6, 0.3, 0.3) * s, CFrame.new(sx * 1.6 * s, 3.9 * s, -8.25 * s), Color3.fromHex("1A1033"))
		for _, z in { -3, 3 } do
			weldPart(root, "Leg", Vector3.new(2.2, 2.6, 2.2) * s, CFrame.new(sx * 2.6 * s, -rootSize.Y / 2 - 0.9 * s, z * s), body:Lerp(Color3.new(0, 0, 0), 0.2))
		end
	end
	for i = 0, 3 do
		local h = (3 - math.abs(i - 1.5)) * s
		weldPart(root, "Plate", Vector3.new(0.6, h, 2) * s, CFrame.new(0, rootSize.Y / 2 + h / 2 - 0.3 * s, (-2 + i * 2.2) * s) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromHex("B05CFF"), Enum.Material.Neon)
	end
	weldPart(root, "Tail", Vector3.new(2.5, 2.5, 7) * s, CFrame.new(0, -1 * s, 7.5 * s) * CFrame.Angles(math.rad(12), 0, 0), body)

	local hum = Instance.new("Humanoid")
	hum.HipHeight = hipHeight
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = model

	billboard(head, "Sleep", "Z Z", Color3.fromHex("BFE6FF"), 6 * s)
	local alert = billboard(head, "Alert", "!", Color3.fromHex("FF4D5E"), 6 * s)
	alert.Enabled = false
	return model
end

-- Body motor: an invisible BodyJoint on the root carries the body bricks and every limb motor that hung off the root.
local function addBodyJoint(model)
	local root = model.PrimaryPart
	if not (root and model:GetAttribute("Rigged")) or model:FindFirstChild("BodyJoint", true) then
		return
	end
	local body = Instance.new("Part")
	body.Name = "BodyJoint"
	body.Size = Vector3.new(0.2, 0.2, 0.2)
	body.Transparency = 1
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = root.CFrame
	body.Parent = model
	local motor = Instance.new("Motor6D")
	motor.Name = "Body"
	motor.Part0 = root
	motor.Part1 = body
	motor.Parent = root
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			if d.Part0 == root and d.Part1 ~= body then
				d.Part0 = body
			elseif d.Part1 == root and d.Part0 ~= body then
				d.Part1 = body
			end
		elseif d:IsA("Motor6D") and d ~= motor and d.Part0 == root then
			d.Part0 = body
		end
	end
end

local function makeModel(biome, cframe)
	local asset = kaijuAssets and kaijuAssets:FindFirstChild("Guardian_" .. biome.Id)
	local model
	if asset then
		model = asset:Clone()
		model:PivotTo(cframe)
	else
		model = buildPlaceholder(biome, cframe)
	end
	addBodyJoint(model)
	model:SetAttribute("BiomeId", biome.Id)
	return model
end

local function setAwakeLook(g, awake)
	for _, p in g.model:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "EyeOpen" or p.Name == "Pupil" then
				p.Transparency = awake and 0 or 1
			elseif p.Name == "EyeClosed" then
				p.Transparency = awake and 1 or 0
			end
		elseif p:IsA("BillboardGui") then
			if p.Name == "Sleep" then
				p.Enabled = not awake
			elseif p.Name == "Alert" then
				p.Enabled = awake
			end
		end
	end
end

local function inZoneX(zone, pos)
	return pos.X >= zone.minX and pos.X <= zone.maxX and math.abs(pos.Z) <= zone.halfZ + 2
end

-- Where a guardian may chase: from the safe zone line to the far end of its own biome.
local function inChaseArea(g, pos)
	local z = g.zone
	return pos.X >= z.safeX and pos.X <= z.maxX and math.abs(pos.Z) <= z.halfZ + 2
end

-- Its player is still around, alive and carrying an egg? Returns ok, hrp.
local function targetValid(player)
	if not player or player.Parent ~= Players then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp and hum.Health > 0) then
		return false
	end
	return player:GetAttribute("CarryingEgg") ~= nil, hrp
end

-- Weather (WeatherService sets workspace attribute WeatherGuardianSpeed): Blizzard < 1 slows guardians, Blood Moon > 1
-- makes them angrier.
local function weatherSpeed()
	local m = workspace:GetAttribute("WeatherGuardianSpeed")
	return type(m) == "number" and m > 0 and m or 1
end

local function haulSpeed(g)
	return g.cfg.HaulSpeed or math.max(8, g.cfg.WalkSpeed * 0.5)
end

-- Where a returning guardian heads: to the dropped egg it's fetching, home dragging it (slowly), or just home.
local function headOff(g)
	if g.egg and not (g.egg.Parent and g.egg.PrimaryPart) then
		g.egg = nil
		g.hauling = false
		g.model:SetAttribute("CarryingEgg", nil)
	end
	local target, speed
	if g.egg and not g.hauling then
		target, speed = g.egg.PrimaryPart.Position, g.cfg.ReturnSpeed
	elseif g.egg then
		target, speed = g.home, haulSpeed(g)
	else
		target, speed = g.home, g.cfg.ReturnSpeed
	end
	g.humanoid.WalkSpeed = speed * weatherSpeed()
	g.humanoid:MoveTo(target)
	g.lastMoveTo = os.clock()
	-- the walk can be a few biomes long: allow for it before the safety net steps in
	local away = Vector3.new(target.X - g.root.Position.X, 0, target.Z - g.root.Position.Z).Magnitude
	g.returnLimit = 12 + away / speed * 1.6
	g.stateTime = os.clock()
end

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y or position.Y
end

local function forgetEgg(g)
	local egg = g.egg
	g.egg = nil
	g.hauling = false
	g.grabAt = nil
	g.model:SetAttribute("CarryingEgg", nil)
	return egg
end

-- Lets go of the egg it's fetching/dragging: it stays on the ground where it is, up for grabs (and despawns later).
local function releaseEgg(g)
	local egg = forgetEgg(g)
	if not (egg and egg.Parent and egg:GetAttribute("State") == "Guardian") then
		return
	end
	require(script.Parent.EggService):LetGoFromGuardian(egg)
end

-- Home with the egg: back into the nest it goes.
local function nestEgg(g)
	local egg = forgetEgg(g)
	if egg and egg.Parent and egg:GetAttribute("State") == "Guardian" then
		require(script.Parent.EggService):ReturnToNest(egg)
	end
end

local function setState(g, state)
	if g.egg and state ~= "Returning" then
		releaseEgg(g)
	end
	g.state = state
	g.stateTime = os.clock()
	local model, hum = g.model, g.humanoid
	model:SetAttribute("State", state)
	if state == "Sleeping" then
		g.owner = nil
		setAwakeLook(g, false)
		hum.WalkSpeed = 0
		hum:MoveTo(g.root.Position)
		g.root.CFrame = CFrame.lookAt(g.root.Position, g.root.Position - Vector3.xAxis)
	elseif state == "Rising" then
		setAwakeLook(g, true)
		hum.WalkSpeed = 0
		model:SetAttribute("RiseAt", serverNow())
	elseif state == "Waking" then
		setAwakeLook(g, true)
		hum.WalkSpeed = 0
	elseif state == "Chasing" then
		setAwakeLook(g, true)
		hum.WalkSpeed = g.cfg.WalkSpeed
		g.aim = nil
	elseif state == "Returning" then
		setAwakeLook(g, true)
		headOff(g)
	elseif state == "Leaving" then
		g.owner = nil
		hum.WalkSpeed = 0
		hum:MoveTo(g.root.Position)
		model:SetAttribute("SinkAt", serverNow())
	end
	model:SetAttribute("TargetUserId", g.owner and g.owner.UserId or nil)
	log(g.zone.biome.Id, g.resident and "resident" or "copy", state, g.owner and g.owner.Name or "")
end

-- Throws a caught player back toward the safe zone (the lane's -X end), up and away.
local function fling(hrp, strength)
	local att = hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChildOfClass("Attachment")
	if not att then
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "GuardianFling"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	strength *= FLING_SCALE
	lv.VectorVelocity = Vector3.new(-strength, strength * FLING_UP, 0)
	lv.Parent = hrp
	Debris:AddItem(lv, 0.2)
end

local function catch(g, player, hrp)
	local EggService = require(script.Parent.EggService)
	-- the egg lands where they were caught, and this guardian goes to take it home (OnEggDropped)
	EggService:DropCarried(player, "Caught")
	Ragdoll.Start(player.Character, CAUGHT_RAGDOLL_SECONDS)
	fling(hrp, g.cfg.Knockback)
	player:SetAttribute("StunnedUntil", math.max(player:GetAttribute("StunnedUntil") or 0, serverNow() + CAUGHT_RAGDOLL_SECONDS))
	gameEvent:FireClient(player, "Caught", { BiomeId = g.zone.biome.Id })
	if g.state ~= "Returning" then
		setState(g, "Returning")
	end
	g.humanoid.WalkSpeed = 0
	g.pauseUntil = os.clock() + POST_CATCH_PAUSE
end

-- How a guardian carries an egg home: most in their jaws, the two apes (Frostfang, Cosmic Rift) in their arms. The arm pose
-- (radians: forward, inward) is the one Gameplay.KaijuFX holds the arms in.
local HOLD_STYLE = { FrostfangPeaks = "Arms", CosmicRift = "Arms" } -- everyone else: "Mouth"
local HOLD_ARM_PITCH, HOLD_ARM_IN = 0.9, 0.38
-- How far a rex holds its jaw open around an egg (radians). Sent to clients as the model attribute HoldJaw.
local HOLD_JAW = 0.75

-- Root-space box of the bricks welded to a rig joint part.
local function jointExtents(model, root, jointPart)
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, w in model:GetDescendants() do
		if w:IsA("WeldConstraint") or w:IsA("Weld") then
			local other = (w.Part0 == jointPart and w.Part1) or (w.Part1 == jointPart and w.Part0) or nil
			if other then
				local cf = root.CFrame:ToObjectSpace(other.CFrame)
				local h = other.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							mn, mx = mn:Min(c), mx:Max(c)
						end
					end
				end
			end
		end
	end
	return mn, mx
end

-- Visible bricks welded to a rig joint part.
local function weldedTo(model, jointPart)
	local list = {}
	for _, w in model:GetDescendants() do
		if w:IsA("WeldConstraint") or w:IsA("Weld") then
			local other = (w.Part0 == jointPart and w.Part1) or (w.Part1 == jointPart and w.Part0) or nil
			if other and other:IsA("BasePart") and other.Transparency < 1 then
				table.insert(list, other)
			end
		end
	end
	return list
end

-- How far a sphere (centre c, radius r) pokes into a part's box; <= 0 means clear of it.
local function sphereDepth(part, c, r)
	local p = part.CFrame:PointToObjectSpace(c)
	local h = part.Size / 2
	local q = Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	if q == p then
		return r + math.min(h.X - math.abs(p.X), h.Y - math.abs(p.Y), h.Z - math.abs(p.Z))
	end
	return r - (p - q).Magnitude
end

-- Egg in the jaws: sitting on the lower jaw, which KaijuFX holds HOLD_JAW open. Tries spots along the jaw and shrinking
-- egg sizes, checking the egg (with the jaw opened) against the head's actual bricks, and takes the biggest egg that fits
-- without poking into the upper jaw / face. Returns spot (root space, rest pose) and scale.
local function mouthSpot(g, motors, eggSize)
	local root = g.root
	local jm = motors.Jaw
	local mn, mx = jointExtents(g.model, root, jm.Part1)
	local hmn, hmx = jointExtents(g.model, root, motors.Head.Part1)
	local head = weldedTo(g.model, motors.Head.Part1)
	local hinge = jm.Part0.CFrame * jm.C0
	local open = hinge * CFrame.Angles(-HOLD_JAW, 0, 0) * hinge:Inverse()
	local scale = math.min(1, (hmx.X - hmn.X) * 0.6 / eggSize)
	while scale > 0.2 do
		local r = eggSize * scale / 2
		for _, f in { 0.3, 0.2, 0.4, 0.12, 0.5, 0.6 } do -- fraction of the jaw's length back from its tip
			local spot = Vector3.new(0, mx.Y + r * 0.75, mn.Z + (mx.Z - mn.Z) * f)
			local posed = open * (root.CFrame * spot)
			local worst = -math.huge
			for _, p in head do
				worst = math.max(worst, sphereDepth(p, posed, r * 0.9))
			end
			if worst <= 0.15 then
				return spot, scale
			end
		end
		scale *= 0.92
	end
	local r = eggSize * scale / 2
	return Vector3.new(0, mx.Y + r * 0.6, mn.Z - r * 0.5), scale -- nothing fits: out at the tip
end

-- Where the egg sits while carried. Returns the part it's welded to, its centre in root space (rest pose), the style
-- and a scale for the egg (big eggs shrink to fit a jaw / a pair of arms; back to full size when grabbed).
local function holdSpot(g, egg)
	local model, root = g.model, g.root
	local part = egg.PrimaryPart
	local size = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local style = HOLD_STYLE[g.zone.biome.Id] or "Mouth"
	if style == "Arms" and motors.ArmL and motors.Body then
		-- cradled between the hands of arms held forward and in (KaijuFX's hold pose)
		local arm = motors.ArmL.Part1
		local shoulder = root.CFrame:PointToObjectSpace(arm.Position)
		local mn = jointExtents(model, root, arm)
		local reach = math.max(2, shoulder.Y - mn.Y)
		local handY = shoulder.Y - reach * math.cos(HOLD_ARM_IN) * math.cos(HOLD_ARM_PITCH)
		local handZ = shoulder.Z - reach * math.cos(HOLD_ARM_IN) * math.sin(HOLD_ARM_PITCH)
		local bmn, bmx = jointExtents(model, root, motors.Body.Part1)
		local scale = math.min(1, math.max(1.5, (bmx.X - bmn.X) * 0.45) / size)
		local r = size * scale / 2
		-- resting on top of the hands, held out in front of the chest
		return motors.Body.Part1, Vector3.new(0, handY + r * 0.9, handZ - r * 0.1), style, scale
	elseif motors.Jaw and motors.Head then
		-- held between the jaws, sized and placed so it doesn't clip the head (mouthSpot)
		local spot, scale = mouthSpot(g, motors, size)
		return motors.Jaw.Part1, spot, style, scale
	end
	local r = size / 2
	return root, Vector3.new(0, 0, -(root.Size.Z / 2 + r)), style, 1 -- unrigged placeholder: in front of it
end

-- Picks up the egg it was fetching. The egg becomes part of the guardian model (a fresh server-owned copy - see
-- EggService:TakeIntoGuardian - so it never fights the egg animation in Gameplay.KaijuFX, which froze the whole
-- guardian on clients), welded to its jaw or body, still grabbable.
local function attachEgg(g)
	local holder, spot, style, scale = holdSpot(g, g.egg)
	local egg = require(script.Parent.EggService):TakeIntoGuardian(g.egg)
	g.egg = egg
	if scale < 0.99 then
		egg:SetAttribute("FullScale", egg:GetScale()) -- EggService puts it back to this when it's grabbed
		egg:ScaleTo(egg:GetScale() * scale)
	end
	local target = g.root.CFrame * CFrame.new(spot)
	egg:PivotTo(target)
	-- The egg rides 14-18 studs up, so its prompt hangs under it at a standing player's height (attachment GrabPoint):
	-- the button sits where the player is (easy to tap on mobile) and the range is GRAB_REACH_FLAT across the ground.
	-- EggService:TryPickup measures the same flat distance (GrabReach) and puts the prompt back on the shell.
	local feetY = g.root.Position.Y - g.root.Size.Y / 2 - g.humanoid.HipHeight
	egg:SetAttribute("GrabReach", GRAB_REACH_FLAT)
	local prompt = egg.PrimaryPart:FindFirstChild("Prompt")
	if prompt then
		local grabPoint = Instance.new("Attachment")
		grabPoint.Name = "GrabPoint"
		grabPoint.Parent = egg.PrimaryPart
		grabPoint.WorldPosition = Vector3.new(target.Position.X, feetY + 3, target.Position.Z)
		prompt.Parent = grabPoint
		prompt.MaxActivationDistance = GRAB_REACH_FLAT
		prompt.HoldDuration = 0
	end
	local weld = Instance.new("Weld")
	weld.Name = "GuardianWeld"
	weld.Part0 = holder
	weld.Part1 = egg.PrimaryPart
	weld.C0 = holder.CFrame:ToObjectSpace(target)
	weld.Parent = egg.PrimaryPart
	egg.Parent = g.model
	pcall(function()
		g.root:SetNetworkOwner(nil) -- the egg joined its assembly: keep the whole thing server-owned
	end)
	g.hauling = true
	g.model:SetAttribute("HoldStyle", style)
	g.model:SetAttribute("HoldJaw", HOLD_JAW)
	g.model:SetAttribute("CarryingEgg", egg:GetAttribute("EggId") or true)
	log(g.zone.biome.Id, "carrying egg home", style)
	headOff(g)
end

local function newGuardian(zone, model, resident)
	local root = model.PrimaryPart
	root.Anchored = false
	root:SetNetworkOwner(nil)
	local g = {
		zone = zone,
		cfg = zone.cfg,
		model = model,
		root = root,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		home = root.Position,
		homeCFrame = model:GetPivot(),
		resident = resident,
		state = "Sleeping",
		stateTime = os.clock(),
	}
	guardians[g] = true
	model.Destroying:Connect(function()
		guardians[g] = nil
	end)
	setAwakeLook(g, false)
	model:SetAttribute("State", "Sleeping")
	return g
end

-- A guardian of this player's own, rising out of the ground beside the nest (the spot furthest from the others).
local function spawnCopy(zone, player)
	local count = 0
	for g in guardians do
		if g.zone == zone then
			count += 1
		end
	end
	if count >= MAX_PER_BIOME then
		return nil
	end
	local best, bestGap
	for _, offset in COPY_OFFSETS do
		local p = zone.ground + offset
		p = Vector3.new(p.X, zone.ground.Y, math.clamp(p.Z, -zone.halfZ + 8, zone.halfZ - 8))
		local gap = math.huge
		for g in guardians do
			if g.zone == zone then
				gap = math.min(gap, Vector3.new(g.root.Position.X - p.X, 0, g.root.Position.Z - p.Z).Magnitude)
			end
		end
		if not bestGap or gap > bestGap then
			best, bestGap = p, gap
		end
	end
	local model = makeModel(zone.biome, CFrame.lookAt(best, best - Vector3.xAxis))
	model:SetAttribute("Personal", true)
	model.Parent = folder
	local g = newGuardian(zone, model, false)
	g.owner = player
	return g
end

-- Is this guardian's player below its biome's RecommendedSpeed?
function underspeed(g, owner)
	local recommended = g.zone.biome.RecommendedSpeed
	local statSpeed = owner and (owner:GetAttribute("RunSpeed") or owner:GetAttribute("BaseWalkSpeed"))
	return recommended ~= nil and type(statSpeed) == "number" and statSpeed < recommended
end

-- Pace multiplier (<= 1) for a guardian chasing a player faster than its biome's RecommendedSpeed: 1 at or below it,
-- dropping the further over they are.
local function overspeedPace(g, owner)
	local recommended = g.zone.biome.RecommendedSpeed
	local statSpeed = owner and (owner:GetAttribute("RunSpeed") or owner:GetAttribute("BaseWalkSpeed"))
	if not (recommended and recommended > 0 and type(statSpeed) == "number" and statSpeed > recommended) then
		return 1
	end
	local over = statSpeed / recommended - 1
	local falloff = g.cfg.OverspeedFalloff or OVERSPEED_FALLOFF
	return math.max(g.cfg.OverspeedMinPace or OVERSPEED_MIN_PACE, 1 / (1 + over * falloff))
end

local function step(g)
	local now = os.clock()
	if g.state == "Leaving" then
		if now - g.stateTime >= SINK_SECONDS then
			guardians[g] = nil
			g.model:Destroy()
		end
		return
	end
	if g.pauseUntil and now < g.pauseUntil then
		return
	end
	if g.pauseUntil then
		g.pauseUntil = nil
		if g.state == "Returning" then
			headOff(g)
		end
	end

	local owner = g.owner
	local biomeId = g.zone.biome.Id
	if g.state == "Rising" then
		if now - g.stateTime >= RISE_SECONDS then
			setState(g, "Waking")
		end
	elseif g.state == "Waking" then
		if now - g.stateTime >= (underspeed(g, owner) and UNDERSPEED_WAKE or g.cfg.WakeDelay) + HEADSTART then
			setState(g, "Chasing")
		end
	elseif g.state == "Chasing" then
		local ok, hrp = targetValid(owner)
		if not ok then
			log(biomeId, "target lost (dropped/delivered/died/left)")
			setState(g, "Returning")
			return
		end
		if not inChaseArea(g, hrp.Position) then
			log(biomeId, "target escaped at x=" .. math.floor(hrp.Position.X))
			gameEvent:FireClient(owner, "GuardianGaveUp", { BiomeId = biomeId })
			setState(g, "Returning")
			return
		end
		if now - g.stateTime > g.zone.maxChase then
			log(biomeId, "chase timed out")
			setState(g, "Returning")
			return
		end
		local flat = Vector3.new(hrp.Position.X - g.root.Position.X, 0, hrp.Position.Z - g.root.Position.Z)
		local reach = g.cfg.CatchDistance + g.root.Size.Z / 2
		if flat.Magnitude <= reach then
			catch(g, owner, hrp)
			return
		end
		-- keep pace: never let a faster player pull away, but don't out-run them once right behind
		local v = hrp.AssemblyLinearVelocity
		local playerHum = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
		local playerSpeed = math.max(playerHum and playerHum.WalkSpeed or 0, Vector3.new(v.X, 0, v.Z).Magnitude)
		local gap = flat.Magnitude - reach
		local wmult = weatherSpeed()
		local base = g.cfg.WalkSpeed * wmult
		local cfg = g.cfg -- a biome can soften or sharpen the scaling (BiomeConfig Guardian.TrailPace etc.)
		local catchup = math.min(math.max(0, gap - FOLLOW_DISTANCE) * (cfg.CatchupPerStud or CATCHUP_PER_STUD), playerSpeed * (cfg.MaxCatchup or MAX_CATCHUP)) * wmult
		local trailPace = (cfg.TrailPace or TRAIL_PACE) * wmult
		if wmult > 1 then
			trailPace = math.min(trailPace, 0.995) -- angrier, but a player at full speed can still just stay ahead
		end
		local speed
		if underspeed(g, owner) then
			-- too slow for this biome: clearly faster than them and closing gaps hard, so it's on them in moments
			local hardCatchup = math.min(math.max(0, gap) * UNDERSPEED_CATCHUP_PER_STUD, playerSpeed * UNDERSPEED_MAX_CATCHUP)
			speed = math.max(base * 1.25, playerSpeed * (cfg.UnderspeedBoost or UNDERSPEED_BOOST) + hardCatchup) * math.min(wmult, 1.1)
		elseif gap > FOLLOW_DISTANCE then
			speed = math.max(base, playerSpeed + catchup) * overspeedPace(g, owner)
		else
			-- on their heels: near their pace (a player who stops gets caught); over-speed players pull away
			speed = playerSpeed * trailPace * overspeedPace(g, owner)
		end
		g.humanoid.WalkSpeed = math.min(speed, MAX_CHASE_SPEED)
		-- aim a little ahead of the player, smoothed so the heading doesn't jerk with every step they take
		local lead = hrp.Position + Vector3.new(v.X, 0, v.Z) * LEAD_SECONDS
		g.aim = g.aim and g.aim:Lerp(lead, 0.5) or lead
		local z = g.zone
		local goal = Vector3.new(math.clamp(g.aim.X, z.safeX + 2, z.maxX - 2), g.home.Y, math.clamp(g.aim.Z, -z.halfZ + 4, z.halfZ - 4))
		g.humanoid:MoveTo(goal)
	elseif g.state == "Returning" then
		-- the egg it's fetching/dragging was grabbed (OnEggTaken normally deals with that) or vanished: just go home
		if g.egg then
			local st = g.egg.Parent and g.egg:GetAttribute("State")
			if st ~= (g.hauling and "Guardian" or "Ground") then
				forgetEgg(g)
				headOff(g)
			end
		end
		-- its own player has another egg from this biome nearby: back after them
		if owner and owner:GetAttribute("CarryingFromBiome") == biomeId then
			local ok, hrp = targetValid(owner)
			if ok and inChaseArea(g, hrp.Position) and (hrp.Position - g.root.Position).Magnitude <= g.cfg.DetectionRadius then
				gameEvent:FireClient(owner, "GuardianAwake", { BiomeId = biomeId })
				setState(g, "Chasing")
				return
			end
		end
		if g.egg and not g.hauling then
			-- fetching a dropped egg
			local at = g.egg.PrimaryPart.Position
			local gap = Vector3.new(at.X - g.root.Position.X, 0, at.Z - g.root.Position.Z).Magnitude
			if gap <= g.root.Size.Z / 2 + FETCH_REACH + g.egg.PrimaryPart.Size.X / 2 then
				if not g.grabAt then
					-- stop, face the egg and reach down for it
					g.grabAt = now
					g.humanoid.WalkSpeed = 0
					g.humanoid:MoveTo(g.root.Position)
					local dir = Vector3.new(at.X - g.root.Position.X, 0, at.Z - g.root.Position.Z)
					if dir.Magnitude > 0.1 then
						g.root.CFrame = CFrame.lookAt(g.root.Position, g.root.Position + dir)
					end
					g.model:SetAttribute("GrabAt", serverNow())
					g.pauseUntil = now + GRAB_DIP
					return
				end
				-- at the bottom of the reach: take it, then stand back up before walking off
				g.grabAt = nil
				attachEgg(g)
				g.humanoid.WalkSpeed = 0
				g.humanoid:MoveTo(g.root.Position)
				g.pauseUntil = os.clock() + GRAB_RISE
			elseif now - (g.lastMoveTo or 0) > 1 then
				g.lastMoveTo = now
				g.humanoid:MoveTo(at)
			end
		else
			local flat = Vector3.new(g.home.X - g.root.Position.X, 0, g.home.Z - g.root.Position.Z)
			if flat.Magnitude < 2.5 then
				nestEgg(g)
				setState(g, g.resident and "Sleeping" or "Leaving")
				return
			elseif now - (g.lastMoveTo or 0) > 2 then
				g.lastMoveTo = now
				g.humanoid:MoveTo(g.home)
			end
		end
		if now - g.stateTime > (g.returnLimit or 30) then
			-- safety net: never leave a guardian stuck away from home (a dragged egg goes straight back to the nest)
			if g.hauling then
				nestEgg(g)
			end
			if g.resident then
				g.model:PivotTo(CFrame.lookAt(g.homeCFrame.Position, g.homeCFrame.Position - Vector3.xAxis))
				setState(g, "Sleeping")
			else
				setState(g, "Leaving")
			end
		end
	end
end

function GuardianService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = runtime

	local lane = workspace:WaitForChild("Map"):WaitForChild("Lane")
	local assets = ServerStorage:FindFirstChild("Assets")
	kaijuAssets = assets and assets:FindFirstChild("Kaiju")
	for _, biome in BiomeConfig.List do
		local m = lane:FindFirstChild(biome.Id)
		if not m then
			warn("[GuardianService] missing lane biome", biome.Id)
			continue
		end
		local zonePart = m.Zone
		local homePos = m.NestSite.Center.GuardianSpawn.WorldPosition
		local ground = Vector3.new(homePos.X, 0, homePos.Z)
		local minX = zonePart.Position.X - zonePart.Size.X / 2
		local maxX = zonePart.Position.X + zonePart.Size.X / 2
		local safeX = workspace.Map:GetAttribute("SafeZoneX") or minX
		local zone = {
			biome = biome,
			cfg = biome.Guardian,
			minX = minX,
			maxX = maxX,
			halfZ = zonePart.Size.Z / 2,
			safeX = safeX,
			maxChase = biome.Guardian.MaxChaseSeconds + (maxX - safeX) / biome.Guardian.WalkSpeed * 1.5,
			ground = ground,
		}
		zones[biome.Id] = zone
		local model = makeModel(biome, CFrame.lookAt(ground, ground - Vector3.xAxis))
		model.Parent = folder
		zone.resident = newGuardian(zone, model, true)
	end
end

function GuardianService:Start()
	Players.PlayerRemoving:Connect(function(player)
		for g in guardians do
			if g.owner == player then
				g.owner = nil
				if g.egg and g.state == "Returning" then
					g.model:SetAttribute("TargetUserId", nil) -- still taking an egg home: carry on
				elseif not g.resident then
					setState(g, "Leaving")
				elseif g.state ~= "Sleeping" then
					setState(g, "Returning")
				end
			end
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local list = {}
		for g in guardians do
			table.insert(list, g)
		end
		for _, g in list do
			if guardians[g] then
				local ok, err = pcall(step, g)
				if not ok then
					warn("[GuardianService]", g.zone.biome.Id, err)
					if g.state ~= "Leaving" then
						setState(g, g.resident and "Returning" or "Leaving")
					end
				end
			end
		end
	end)
end

local function inZoneChase(zone, pos)
	return pos.X >= zone.safeX and pos.X <= zone.maxX and math.abs(pos.Z) <= zone.halfZ + 2
end

-- Is `position` inside the chase area of `biomeId`'s guardians (safe zone line to the far end of that biome)?
function GuardianService:InChaseArea(biomeId, position)
	local zone = biomeId and zones[biomeId]
	return zone ~= nil and inZoneChase(zone, position)
end

-- Called by EggService when an egg lands on the ground (caught, clicked down, died). Inside its own biome's chase area a
-- guardian of that biome fetches it and drags it home: the one that was after `player`, else the resident if it's free.
-- Returns whether one is coming for it.
function GuardianService:OnEggDropped(egg, player)
	local zone = zones[egg:GetAttribute("BiomeId")]
	if not (zone and egg.PrimaryPart and inZoneChase(zone, egg.PrimaryPart.Position)) then
		return false
	end
	local pick
	for g in guardians do
		if g.zone == zone and g.owner == player and not g.egg and g.state ~= "Leaving" and g.state ~= "Sleeping" then
			pick = g
			break
		end
	end
	local r = zone.resident
	if not pick and r and not r.egg and (r.state == "Sleeping" or (r.state == "Returning" and r.owner == nil)) then
		pick = r
	end
	if not pick then
		return false
	end
	pick.egg = egg
	pick.hauling = false
	if pick.state == "Returning" then
		headOff(pick)
	else
		setState(pick, "Returning")
	end
	log(zone.biome.Id, "fetching dropped egg")
	return true
end

-- Called by EggService when a player takes an egg inside a biome: that player's guardian comes after them. `egg` is
-- passed for ground/guardian eggs: if a guardian was fetching or dragging it, that same guardian goes after them.
function GuardianService:OnEggTaken(biomeId, player, egg)
	local zone = zones[biomeId]
	if not zone then
		return
	end
	if egg then
		for g in guardians do
			if g.egg == egg then
				forgetEgg(g)
				if g.zone == zone then
					g.owner = player
					gameEvent:FireClient(player, "GuardianAwake", { BiomeId = biomeId })
					setState(g, "Waking")
					g.pauseUntil = os.clock() + REGRAB_ROAR + HEADSTART -- the whole roar: it doesn't move until it's over
					return
				end
				headOff(g)
			end
		end
	end
	for g in guardians do
		if g.zone == zone and g.owner == player and g.state ~= "Leaving" and g.state ~= "Sleeping" then
			-- theirs is still about (on its way home after a drop, or already after them)
			if g.state == "Returning" then
				gameEvent:FireClient(player, "GuardianAwake", { BiomeId = biomeId })
				setState(g, "Chasing")
			end
			return
		end
	end
	gameEvent:FireClient(player, "GuardianAwake", { BiomeId = biomeId })
	local resident = zone.resident
	if resident and resident.state == "Sleeping" then
		resident.owner = player
		setState(resident, "Waking")
	elseif resident and resident.state == "Returning" and resident.owner == nil and not resident.egg then
		resident.owner = player
		setState(resident, "Chasing")
	else
		local g = spawnCopy(zone, player)
		if g then
			setState(g, "Rising")
		end
	end
end

-- Night falls (DayNightService): every guardian drops what it's doing. Eggs they hold are lost with the rest
-- (EggService:ResetForNight), residents are back asleep in their nests and personal copies sink away.
function GuardianService:ResetForNight()
	for g in guardians do
		local egg = forgetEgg(g)
		if egg then
			egg:Destroy()
		end
		g.pauseUntil = nil
		if g.resident then
			g.owner = nil
			if g.state ~= "Sleeping" then
				g.model:PivotTo(CFrame.lookAt(g.homeCFrame.Position, g.homeCFrame.Position - Vector3.xAxis))
				setState(g, "Sleeping")
			end
		elseif g.state ~= "Leaving" then
			setState(g, "Leaving")
		end
	end
end

-- The resident guardian's state.
function GuardianService:GetState(biomeId)
	local zone = zones[biomeId]
	return zone and zone.resident and zone.resident.state
end

-- Studio testing: a personal copy rises for `player` even while the resident is free (to see copies with one player).
function GuardianService:SpawnCopyForTesting(player, biomeId)
	local zone = DevConfig.InStudio and zones[biomeId]
	local g = zone and spawnCopy(zone, player)
	if g then
		setState(g, "Rising")
	end
	return g ~= nil
end

-- Which biome (if any) contains this position.
function GuardianService:BiomeAt(position)
	for id, zone in zones do
		if inZoneX(zone, position) then
			return id
		end
	end
	return nil
end

return GuardianService
