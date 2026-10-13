-- Day / night cycle and the egg reset (timings in Shared.Config.DayNightConfig: 5 minutes of day, 10 seconds of night).
-- When night falls:
--   * the NightBarrier wall rises across the lane at Map attribute SafeZoneX (it stays up all night) and everyone past
--     it is sent back into the safe zone; anyone who still ends up inside during the night is sent back too
--   * guardians drop everything and go home (GuardianService:ResetForNight)
--   * every egg out in the world is lost - carried, on the ground or in a guardian's jaws - and the nests are emptied
--     (EggService:ResetForNight); a player who loses an egg gets GameEvent EggLostNight
-- When day breaks the wall sinks and every nest is refilled with freshly rolled eggs (EggService:EndNight).
-- Workspace attributes (clients work the phase out themselves from these):
--   ServerStartedAt  server time this server started (the HUD's server time)
--   DayNightEpoch    server time the first day began (DayNightConfig.Phase)
--   IsNight          true during the night
-- GameEvents to everyone: NightFell, DayBroke.
-- The wall's countdown is drawn by StarterPlayerScripts.Gameplay.DayNightFX, which also moves the sun and darkens the
-- sky; the HUD countdown is StarterGui.KaijuUI.Controllers.DayNightController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DayNightConfig = require(ReplicatedStorage.Shared.Config.DayNightConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local DayNightService = {}

local BARRIER_HEIGHT = 60
local BARRIER_RISE = 0.6 -- seconds the wall takes to rise / sink
local EJECT_GAP = 10 -- studs on the safe side of the wall where ejected players land

local gameEvent
local barrier
local safeX, laneHalfZ = 0, 0
local isNight = false

local function log(...)
	if DevConfig.VerboseLogging then
		print("[DayNight]", ...)
	end
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- The wall across the lane entrance, sunk below the ground by day. Its SurfaceGui faces the safe zone (-X).
local function buildBarrier(map)
	local old = map:FindFirstChild("NightBarrier")
	if old then
		old:Destroy()
	end
	local wall = Instance.new("Part")
	wall.Name = "NightBarrier"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CanTouch = false
	wall.CastShadow = false
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = Color3.fromHex("#E9EBF2")
	wall.Size = Vector3.new(2, BARRIER_HEIGHT, laneHalfZ * 2 + 4)
	wall:SetAttribute("UpCFrame", CFrame.new(safeX, BARRIER_HEIGHT / 2, 0))
	wall.CFrame = CFrame.new(safeX, -BARRIER_HEIGHT / 2 - 2, 0)
	wall.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Countdown"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 5 -- coarse on purpose: text can't go past 100 px, and this makes 100 px = 20 studs tall
	gui.LightInfluence = 0
	gui:SetAttribute("NoAutoGradient", true) -- WorldTextController leaves it alone
	gui.Parent = wall
	-- an unlit face so the wall stays a clean light grey at night instead of picking up the dark blue night light
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.BackgroundColor3 = Color3.fromHex("#E4E6EE")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("#C9CCD8"))
	shade.Parent = face
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.fromOffset(500, 130)
	row.Parent = face
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(125, 125)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.LayoutOrder = 1
	icon.Parent = row
	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 100
	label.TextColor3 = Color3.fromHex("#55565F")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 110)
	label.Text = ""
	label.LayoutOrder = 2
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#2A2A33")
	stroke.Thickness = 5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = row

	wall.Parent = map
	return wall
end

local function setBarrier(up)
	local target = up and barrier:GetAttribute("UpCFrame") or barrier:GetAttribute("UpCFrame") * CFrame.new(0, -BARRIER_HEIGHT - 2, 0)
	barrier.CanCollide = up
	if up then
		barrier.Transparency = 0
	end
	local tween = TweenService:Create(barrier, TweenInfo.new(BARRIER_RISE, Enum.EasingStyle.Quad, up and Enum.EasingDirection.Out or Enum.EasingDirection.In), { CFrame = target })
	tween.Completed:Connect(function()
		if not isNight then
			barrier.Transparency = 1
		end
	end)
	tween:Play()
end

-- Anyone past the wall goes back to the safe zone, a few studs in front of it.
local function ejectPlayers()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.X > safeX - 1.5 and math.abs(hrp.Position.Z) < laneHalfZ + 6 then
			local x = safeX - EJECT_GAP
			local z = math.clamp(hrp.Position.Z, -laneHalfZ + 6, laneHalfZ - 6)
			params.FilterDescendantsInstances = { char, barrier }
			local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), params)
			local y = (hit and hit.Position.Y or 0) + 4
			char:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x - 10, y, z)))
			log("sent", player.Name, "back to the safe zone")
		end
	end
end

local function nightFalls()
	isNight = true
	workspace:SetAttribute("IsNight", true)
	log("night falls")
	setBarrier(true)
	local services = script.Parent
	require(services.GuardianService):ResetForNight()
	require(services.EggService):ResetForNight()
	ejectPlayers()
	gameEvent:FireAllClients("NightFell", {})
end

local function dayBreaks()
	isNight = false
	workspace:SetAttribute("IsNight", false)
	log("day breaks")
	setBarrier(false)
	require(script.Parent.EggService):EndNight()
	gameEvent:FireAllClients("DayBroke", {})
end

function DayNightService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local now = serverNow()
	workspace:SetAttribute("ServerStartedAt", now)
	workspace:SetAttribute("DayNightEpoch", now)
	workspace:SetAttribute("IsNight", false)
	local map = workspace:WaitForChild("Map")
	safeX = map:GetAttribute("SafeZoneX") or 0
	local lane = map:FindFirstChild("Lane")
	if lane then
		for _, biome in lane:GetChildren() do
			local zone = biome:FindFirstChild("Zone")
			if zone and zone:IsA("BasePart") then
				laneHalfZ = math.max(laneHalfZ, zone.Size.Z / 2)
			end
		end
	end
	if laneHalfZ <= 0 then
		laneHalfZ = 55
	end
	barrier = buildBarrier(map)
end

function DayNightService:Start()
	while true do
		local night = DayNightConfig.Phase(serverNow(), workspace:GetAttribute("DayNightEpoch") or 0)
		if night and not isNight then
			local ok, err = pcall(nightFalls)
			if not ok then
				warn("[DayNightService] night", err)
			end
		elseif not night and isNight then
			local ok, err = pcall(dayBreaks)
			if not ok then
				warn("[DayNightService] day", err)
			end
		elseif isNight then
			ejectPlayers() -- nobody stays (or slips back) inside during the reset
		end
		task.wait(0.25)
	end
end

-- Is it night (the egg reset) right now?
function DayNightService:IsNight()
	return isNight
end

-- Studio testing: jump the cycle so night falls in `seconds` (default 3). (Setting workspace attribute DayNightEpoch to
-- serverNow + seconds - DaySeconds does the same from the command bar.)
function DayNightService:NightInForTesting(seconds)
	if not DevConfig.InStudio then
		return
	end
	local epoch = serverNow() + (seconds or 3) - DayNightConfig.DaySeconds
	workspace:SetAttribute("DayNightEpoch", epoch)
end

return DayNightService
