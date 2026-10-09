-- One guardian per biome: Sleeping -> Waking (roar) -> Chasing -> Returning -> Sleeping.
-- Wakes when an egg is taken in its biome and chases the thief out of its biome, through every biome nearer the bases,
-- all the way to the safe zone (Map attribute SafeZoneX; the lanes are joined end to end). Gives up when the thief
-- reaches the safe zone, drops or delivers the egg, dies, or the chase runs too long (MaxChaseSeconds plus the time to
-- run the whole way home). While walking home it re-targets carriers of its own eggs anywhere along that way.
-- Uses ServerStorage.Assets.Kaiju.Guardian_<BiomeId> if present, otherwise builds a placeholder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local GuardianService = {}

local TICK = 0.1
local guardians = {} -- [biomeId] = guardian state
local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Guardian]", ...)
	end
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

local function inZoneX(g, pos)
	return pos.X >= g.minX and pos.X <= g.maxX and math.abs(pos.Z) <= g.halfZ + 2
end

-- Where the guardian may chase: from the safe zone line to the far end of its own biome.
local function inChaseArea(g, pos)
	return pos.X >= g.safeX and pos.X <= g.maxX and math.abs(pos.Z) <= g.halfZ + 2
end

local function targetValid(g, player)
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

local function setState(g, state, target)
	g.state = state
	g.target = target
	g.stateTime = os.clock()
	g.model:SetAttribute("State", state)
	local hum = g.humanoid
	if state == "Sleeping" then
		setAwakeLook(g, false)
		hum:MoveTo(g.root.Position)
		g.root.CFrame = CFrame.lookAt(g.root.Position, g.root.Position - Vector3.xAxis)
	elseif state == "Waking" then
		setAwakeLook(g, true)
		hum.WalkSpeed = 0
		hum.Jump = true
	elseif state == "Chasing" then
		hum.WalkSpeed = g.cfg.WalkSpeed
	elseif state == "Returning" then
		setAwakeLook(g, true)
		hum.WalkSpeed = g.cfg.ReturnSpeed
		hum:MoveTo(g.home)
		-- the walk home can now be a few biomes long: allow for it before the safety net teleports it home
		local away = Vector3.new(g.home.X - g.root.Position.X, 0, g.home.Z - g.root.Position.Z).Magnitude
		g.returnLimit = 12 + away / g.cfg.ReturnSpeed * 1.6
	end
	log(g.biome.Id, state, target and target.Name or "")
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
	gameEvent:FireClient(player, "Caught", { BiomeId = g.biome.Id })
	setState(g, "Returning")
	g.humanoid.WalkSpeed = 0
	g.pauseUntil = os.clock() + 0.8
end

local function findCarrierNear(g)
	local best, bestDist
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CarryingFromBiome") == g.biome.Id then
			local ok, hrp = targetValid(g, player)
			if ok and inChaseArea(g, hrp.Position) then
				local d = (hrp.Position - g.root.Position).Magnitude
				if d <= g.cfg.DetectionRadius and (not bestDist or d < bestDist) then
					best, bestDist = player, d
				end
			end
		end
	end
	return best
end

local function step(g)
	local now = os.clock()
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

	if g.state == "Waking" then
		if now - g.stateTime >= g.cfg.WakeDelay then
			setState(g, "Chasing", g.target)
		end
	elseif g.state == "Chasing" then
		local ok, hrp = targetValid(g, g.target)
		if not ok then
			log(g.biome.Id, "target lost (dropped/delivered/died)")
			setState(g, "Returning")
			return
		end
		if not inChaseArea(g, hrp.Position) then
			log(g.biome.Id, "target escaped at x=" .. math.floor(hrp.Position.X))
			gameEvent:FireClient(g.target, "GuardianGaveUp", { BiomeId = g.biome.Id })
			setState(g, "Returning")
			return
		end
		if now - g.stateTime > g.maxChase then
			log(g.biome.Id, "chase timed out")
			setState(g, "Returning")
			return
		end
		local flat = Vector3.new(hrp.Position.X - g.root.Position.X, 0, hrp.Position.Z - g.root.Position.Z)
		local reach = g.cfg.CatchDistance + g.root.Size.Z / 2
		if flat.Magnitude <= reach then
			catch(g, g.target, hrp)
			return
		end
		local goal = Vector3.new(math.clamp(hrp.Position.X, g.safeX + 2, g.maxX - 2), g.home.Y, math.clamp(hrp.Position.Z, -g.halfZ + 4, g.halfZ - 4))
		g.humanoid:MoveTo(goal)
	elseif g.state == "Returning" then
		local carrier = findCarrierNear(g)
		if carrier then
			gameEvent:FireClient(carrier, "GuardianAwake", { BiomeId = g.biome.Id })
			setState(g, "Chasing", carrier)
			return
		end
		local flat = Vector3.new(g.home.X - g.root.Position.X, 0, g.home.Z - g.root.Position.Z)
		if flat.Magnitude < 2.5 then
			setState(g, "Sleeping")
		elseif now - (g.lastMoveTo or 0) > 2 then
			g.lastMoveTo = now
			g.humanoid:MoveTo(g.home)
		end
		if now - g.stateTime > (g.returnLimit or 30) then
			-- safety net: never leave a guardian stuck away from home
			g.model:PivotTo(CFrame.lookAt(g.homeCFrame.Position, g.homeCFrame.Position - Vector3.xAxis))
			setState(g, "Sleeping")
		end
	end
end

function GuardianService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = runtime

	local lane = workspace:WaitForChild("Map"):WaitForChild("Lane")
	local assets = ServerStorage:FindFirstChild("Assets")
	local kaiju = assets and assets:FindFirstChild("Kaiju")
	for _, biome in BiomeConfig.List do
		local m = lane:FindFirstChild(biome.Id)
		if not m then
			warn("[GuardianService] missing lane biome", biome.Id)
			continue
		end
		local zone = m.Zone
		local spawnAtt = m.NestSite.Center.GuardianSpawn
		local homePos = spawnAtt.WorldPosition
		local ground = Vector3.new(homePos.X, 0, homePos.Z)
		local facing = CFrame.lookAt(ground, ground - Vector3.xAxis)

		local model
		local asset = kaiju and kaiju:FindFirstChild("Guardian_" .. biome.Id)
		if asset then
			model = asset:Clone()
			model:PivotTo(facing)
		else
			model = buildPlaceholder(biome, facing)
		end
		model:SetAttribute("BiomeId", biome.Id)
		model.Parent = folder
		local root = model.PrimaryPart
		root.Anchored = false
		root:SetNetworkOwner(nil)

		local maxX = zone.Position.X + zone.Size.X / 2
		local safeX = workspace.Map:GetAttribute("SafeZoneX") or (zone.Position.X - zone.Size.X / 2)
		guardians[biome.Id] = {
			biome = biome,
			cfg = biome.Guardian,
			safeX = safeX,
			maxChase = biome.Guardian.MaxChaseSeconds + (maxX - safeX) / biome.Guardian.WalkSpeed * 1.5,
			model = model,
			root = root,
			humanoid = model:FindFirstChildOfClass("Humanoid"),
			home = root.Position,
			homeCFrame = model:GetPivot(),
			minX = zone.Position.X - zone.Size.X / 2,
			maxX = zone.Position.X + zone.Size.X / 2,
			halfZ = zone.Size.Z / 2,
			state = "Sleeping",
			stateTime = os.clock(),
		}
		setAwakeLook(guardians[biome.Id], false)
		model:SetAttribute("State", "Sleeping")
	end
end

function GuardianService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		for _, g in guardians do
			local ok, err = pcall(step, g)
			if not ok then
				warn("[GuardianService]", g.biome.Id, err)
				setState(g, "Returning")
			end
		end
	end)
end

-- Called by EggService when a player takes an egg inside a biome.
function GuardianService:OnEggTaken(biomeId, player)
	local g = guardians[biomeId]
	if not g then
		return
	end
	if g.state == "Sleeping" then
		gameEvent:FireClient(player, "GuardianAwake", { BiomeId = biomeId })
		setState(g, "Waking", player)
	elseif g.state == "Returning" then
		gameEvent:FireClient(player, "GuardianAwake", { BiomeId = biomeId })
		setState(g, "Chasing", player)
	end
end

function GuardianService:GetState(biomeId)
	local g = guardians[biomeId]
	return g and g.state
end

-- Which biome (if any) contains this position.
function GuardianService:BiomeAt(position)
	for id, g in guardians do
		if inZoneX(g, position) then
			return id
		end
	end
	return nil
end

return GuardianService
