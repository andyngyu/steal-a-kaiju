-- Guardians. One resident guardian per biome sleeps by its nest, and every player who takes an egg there gets a guardian
-- of their own: the resident wakes for the first thief, and while it's busy a copy rises out of the ground beside the
-- nest for each other thief. A guardian only ever chases its own player:
--   resident: Sleeping -> Waking (roar) -> Chasing -> Returning -> Sleeping
--   copy:     Rising (out of the ground) -> Waking -> Chasing -> Returning -> Leaving (sinks back into the ground)
-- A chase runs from the far end of the guardian's biome through every biome nearer the bases, all the way to the safe
-- zone (Map attribute SafeZoneX; the lanes are joined end to end). It gives up when its player reaches the safe zone,
-- drops or delivers the egg, dies or leaves, or the chase runs too long (MaxChaseSeconds plus the time to run the whole
-- way home). While walking home it goes after its player again if they carry another egg from its biome nearby.
-- Guardians aim a little ahead of a running player (LEAD_SECONDS), smoothed so the heading doesn't jerk.
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

local GuardianService = {}

local TICK = 0.1
local RISE_SECONDS = 1.1 -- a copy climbing out of the ground (KaijuFX uses the same number)
local SINK_SECONDS = 1.2 -- a copy sinking away once it's home
local LEAD_SECONDS = 0.2
local MAX_PER_BIOME = 8
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

local function setState(g, state)
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
		hum.WalkSpeed = g.cfg.ReturnSpeed
		hum:MoveTo(g.home)
		-- the walk home can be a few biomes long: allow for it before the safety net steps in
		local away = Vector3.new(g.home.X - g.root.Position.X, 0, g.home.Z - g.root.Position.Z).Magnitude
		g.returnLimit = 12 + away / g.cfg.ReturnSpeed * 1.6
	elseif state == "Leaving" then
		g.owner = nil
		hum.WalkSpeed = 0
		hum:MoveTo(g.root.Position)
		model:SetAttribute("SinkAt", serverNow())
	end
	model:SetAttribute("TargetUserId", g.owner and g.owner.UserId or nil)
	log(g.zone.biome.Id, g.resident and "resident" or "copy", state, g.owner and g.owner.Name or "")
end

local function knockback(hrp, fromPos, strength)
	local flat = Vector3.new(hrp.Position.X - fromPos.X, 0, hrp.Position.Z - fromPos.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.xAxis * -1
	local att = hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChildOfClass("Attachment")
	if not att then
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = dir * strength + Vector3.new(0, strength * 0.5, 0)
	lv.Parent = hrp
	Debris:AddItem(lv, 0.18)
end

local function catch(g, player, hrp)
	local EggService = require(script.Parent.EggService)
	EggService:DropCarried(player, "Caught")
	knockback(hrp, g.root.Position, g.cfg.Knockback)
	gameEvent:FireClient(player, "Caught", { BiomeId = g.zone.biome.Id })
	setState(g, "Returning")
	g.humanoid.WalkSpeed = 0
	g.pauseUntil = os.clock() + 0.8
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
			g.humanoid.WalkSpeed = g.cfg.ReturnSpeed
			g.humanoid:MoveTo(g.home)
		end
	end

	local owner = g.owner
	local biomeId = g.zone.biome.Id
	if g.state == "Rising" then
		if now - g.stateTime >= RISE_SECONDS then
			setState(g, "Waking")
		end
	elseif g.state == "Waking" then
		if now - g.stateTime >= g.cfg.WakeDelay then
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
		-- aim a little ahead of the player, smoothed so the heading doesn't jerk with every step they take
		local v = hrp.AssemblyLinearVelocity
		local lead = hrp.Position + Vector3.new(v.X, 0, v.Z) * LEAD_SECONDS
		g.aim = g.aim and g.aim:Lerp(lead, 0.5) or lead
		local z = g.zone
		local goal = Vector3.new(math.clamp(g.aim.X, z.safeX + 2, z.maxX - 2), g.home.Y, math.clamp(g.aim.Z, -z.halfZ + 4, z.halfZ - 4))
		g.humanoid:MoveTo(goal)
	elseif g.state == "Returning" then
		-- its own player has another egg from this biome nearby: back after them
		if owner and owner:GetAttribute("CarryingFromBiome") == biomeId then
			local ok, hrp = targetValid(owner)
			if ok and inChaseArea(g, hrp.Position) and (hrp.Position - g.root.Position).Magnitude <= g.cfg.DetectionRadius then
				gameEvent:FireClient(owner, "GuardianAwake", { BiomeId = biomeId })
				setState(g, "Chasing")
				return
			end
		end
		local flat = Vector3.new(g.home.X - g.root.Position.X, 0, g.home.Z - g.root.Position.Z)
		if flat.Magnitude < 2.5 then
			setState(g, g.resident and "Sleeping" or "Leaving")
			return
		elseif now - (g.lastMoveTo or 0) > 2 then
			g.lastMoveTo = now
			g.humanoid:MoveTo(g.home)
		end
		if now - g.stateTime > (g.returnLimit or 30) then
			-- safety net: never leave a guardian stuck away from home
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
				if not g.resident then
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

-- Called by EggService when a player takes an egg inside a biome: that player's guardian comes after them.
function GuardianService:OnEggTaken(biomeId, player)
	local zone = zones[biomeId]
	if not zone then
		return
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
	elseif resident and resident.state == "Returning" and resident.owner == nil then
		resident.owner = player
		setState(resident, "Chasing")
	else
		local g = spawnCopy(zone, player)
		if g then
			setState(g, "Rising")
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
