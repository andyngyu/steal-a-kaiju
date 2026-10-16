-- The bat, client side (rules in Services.BatService, numbers in StealConfig.Bat):
--   swinging: clicking / tapping with the bat out sends Remotes.SwingBat (the server times the cooldown too)
--   hands full: the bat goes away while you carry an egg or stolen goods, hold a steal, are stunned / ragdolled or on
--               a treadmill, and can't be taken out again until you're free (the server moves the tool: the
--               hotbar's bat slot sends Remotes.SwingBat "Equip" / "Unequip")
--   idle pose:  holding the bat keeps the normal idle / walk pose (the Animate script's arm-out "toolnone" hold is
--               stopped), so the bat points forward from the hand
--   the swing:  a full-arm swing posed in code on every client when a bat's SwungAt attribute changes: the arm winds
--               up over the shoulder (torso twisted back), then whips forward until it's fully extended with the bat
--               level (torso twisting through), holds a beat and settles. It drives the R15 shoulder / elbow / wrist /
--               waist joints (Motor6D.Transform, after the Animator each frame), and the bat is welded to the hand, so
--               arm and bat always move together. (A custom animation asset would need uploading from Studio's
--               animation editor; this needs nothing uploaded.)
--   effects:    the whoosh when anyone swings (the tool's SwungAt attribute), and on a hit (GameEvent BatHit) a wooden
--               BONK sound, a star burst and a "BONK!" pop over the target; the camera shakes if it was you
--               (unless Camera Shake is off in Settings)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StealConfig = require(Config:WaitForChild("StealConfig"))
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local swingRemote = remotes:WaitForChild("SwingBat")
local gameEvent = remotes:WaitForChild("GameEvent")

local player = Players.LocalPlayer
local B = StealConfig.Bat
local TOOL_NAME = "Bat"
local rng = Random.new()
local swings = {} -- [character] = os.clock() its swing started (the pose is driven further down)

---------------------------------------------------------------- sounds
local function playAt(key, where)
	local def = SoundConfig.Sounds[key]
	if not (def and where and where.Parent) then
		return
	end
	local ids = type(def.Id) == "table" and def.Id or { def.Id }
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(ids[rng:NextInteger(1, #ids)])
	s.Volume = def.Volume or 0.5
	local vary = def.Vary or 0
	s.PlaybackSpeed = (def.Pitch or 1) * (1 + rng:NextNumber(-vary, vary))
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = def.MinDist or 10
	s.RollOffMaxDistance = def.MaxDist or 100
	local group = SoundService:FindFirstChild(def.Group or "SFX")
	if group and group:IsA("SoundGroup") then
		s.SoundGroup = group
	end
	s.Parent = where
	s:Play()
	Debris:AddItem(s, def.MaxSeconds or 4)
end

local function playAtPosition(key, pos)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	Debris:AddItem(att, 5)
	playAt(key, att)
end

---------------------------------------------------------------- my bat: swing + hands-full rule
local function handsFull()
	local char = player.Character
	return player:GetAttribute("CarryingEgg") ~= nil
		or player:GetAttribute("CarryingStolen") ~= nil
		or player:GetAttribute("Stealing") ~= nil
		or player:GetAttribute("OnTreadmill") ~= nil
		or (player:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow()
		or (char ~= nil and char:GetAttribute("RagdollUntil") ~= nil)
end

local lastSwing = 0
local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool)
	if hooked[tool] or not tool:IsA("Tool") or tool.Name ~= TOOL_NAME then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local t = os.clock()
		if t - lastSwing < B.CooldownSeconds or handsFull() then
			return
		end
		lastSwing = t
		if player.Character then
			swings[player.Character] = os.clock() -- your own swing starts at once, no network wait
		end
		swingRemote:FireServer()
	end)
	tool.Equipped:Connect(function()
		if handsFull() then
			swingRemote:FireServer("Unequip")
		end
	end)
end

local function putAway()
	local char = player.Character
	if char and char:FindFirstChild(TOOL_NAME) and handsFull() then
		swingRemote:FireServer("Unequip")
	end
end

-- no arm-out tool hold while the bat is out: the plain idle pose with the bat upright at your side
local function holdingBat(char)
	local t = char:FindFirstChild(TOOL_NAME)
	return t ~= nil and t:IsA("Tool")
end
local function stopToolHold(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Name == "ToolNoneAnim" then
			track:Stop(0.1)
		end
	end
end

local function onCharacter(char)
	char.ChildAdded:Connect(hookTool)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and hum:WaitForChild("Animator", 10)
	if animator then
		animator.AnimationPlayed:Connect(function(track)
			if track.Name == "ToolNoneAnim" and holdingBat(char) then
				track:Stop(0)
			end
		end)
	end
	char.ChildAdded:Connect(function(c)
		if c.Name == TOOL_NAME and c:IsA("Tool") then
			task.defer(stopToolHold, char)
			task.delay(0.15, stopToolHold, char)
		end
	end)
	char:GetAttributeChangedSignal("RagdollUntil"):Connect(putAway)
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(hookTool)
	for _, c in backpack:GetChildren() do
		hookTool(c)
	end
	for _, c in char:GetChildren() do
		hookTool(c)
	end
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
for _, attr in { "CarryingEgg", "CarryingStolen", "Stealing", "OnTreadmill", "StunnedUntil" } do
	player:GetAttributeChangedSignal(attr):Connect(putAway)
end

---------------------------------------------------------------- everyone's swings: the whoosh
-- the swing pose: keyframes of { time, shoulder pitch, elbow bend, wrist pitch, waist yaw } in degrees
-- (shoulder: + raises the arm forward and up; wrist: - tips the bat forward / down; waist: + twists the torso back)
local SWING_KEYS = {
	{ 0, 0, 0, 0, 0 },
	{ 0.11, 165, 35, 20, 32 }, -- wind up: arm high over the shoulder, bat back
	{ 0.2, 85, 0, -75, -25 }, -- strike: arm fully out in front, bat level, torso twisted through
	{ 0.3, 80, 0, -70, -22 }, -- follow-through hold
	{ 0.5, 0, 0, 0, 0 }, -- settle back to the idle hold
}
local SWING_TIME = SWING_KEYS[#SWING_KEYS][1]
local function ease(t)
	return t * t * (3 - 2 * t)
end
local function sample(t)
	for i = 1, #SWING_KEYS - 1 do
		local a, b = SWING_KEYS[i], SWING_KEYS[i + 1]
		if t <= b[1] then
			local k = ease(math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1))
			return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k, a[5] + (b[5] - a[5]) * k
		end
	end
	return 0, 0, 0, 0
end
RunService.Stepped:Connect(function()
	local now = os.clock()
	for char, started in swings do
		local t = now - started
		local sh = char.Parent and char:FindFirstChild("RightUpperArm")
		sh = sh and sh:FindFirstChild("RightShoulder")
		if t > SWING_TIME or not sh or not char:FindFirstChild(TOOL_NAME) or char:GetAttribute("RagdollUntil") then
			swings[char] = nil
			continue
		end
		local s, e, w, waist = sample(t)
		sh.Transform = CFrame.Angles(math.rad(s), 0, 0)
		local el = char:FindFirstChild("RightLowerArm") and char.RightLowerArm:FindFirstChild("RightElbow")
		if el then
			el.Transform = CFrame.Angles(math.rad(e), 0, 0)
		end
		local wr = char:FindFirstChild("RightHand") and char.RightHand:FindFirstChild("RightWrist")
		if wr then
			wr.Transform = CFrame.Angles(math.rad(w), 0, 0)
		end
		local wa = char:FindFirstChild("UpperTorso") and char.UpperTorso:FindFirstChild("Waist")
		if wa then
			wa.Transform = CFrame.Angles(0, math.rad(waist), 0)
		end
	end
end)

local watched = setmetatable({}, { __mode = "k" })
local function watchTool(tool)
	if watched[tool] or not tool:IsA("Tool") or tool.Name ~= TOOL_NAME then
		return
	end
	watched[tool] = true
	tool:GetAttributeChangedSignal("SwungAt"):Connect(function()
		local char = tool.Parent
		if char and char:IsA("Model") and char:FindFirstChildOfClass("Humanoid") then
			if char ~= player.Character then -- (your own swing already started when you clicked)
				swings[char] = os.clock()
			end
		end
		local handle = tool:FindFirstChild("Handle")
		if handle then
			playAt("BatSwing", handle)
		end
	end)
end
local function watchCharacter(char)
	char.ChildAdded:Connect(watchTool)
	for _, c in char:GetChildren() do
		watchTool(c)
	end
end
local function watchPlayer(p)
	p.CharacterAdded:Connect(watchCharacter)
	if p.Character then
		watchCharacter(p.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in Players:GetPlayers() do
	task.spawn(watchPlayer, p)
end

---------------------------------------------------------------- hits: BONK
local fx = Instance.new("Folder")
fx.Name = "BatFXLocal"
fx.Parent = workspace

local function burst(pos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = fx
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromHex("FFF36B"), Color3.fromHex("FFB020"))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(18, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Rate = 0
	e.Parent = p
	e:Emit(22)
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxasset://textures/particles/explosion01_core_main.dds"
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.LightEmission = 1
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 6) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	ring.Lifetime = NumberRange.new(0.25)
	ring.Speed = NumberRange.new(0)
	ring.Rate = 0
	ring.Parent = p
	ring:Emit(1)
	Debris:AddItem(p, 1.5)
end

local WORDS = { "BONK!", "BONK!", "WHACK!", "BOP!" }
local function pop(pos)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	anchor.Parent = fx
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 90)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.Size = UDim2.fromScale(0.3, 0.3)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = WORDS[rng:NextInteger(1, #WORDS)]
	l.TextColor3 = Color3.fromHex("FFE23F")
	l.Rotation = rng:NextNumber(-12, 12)
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = Color3.fromHex("1A1033")
	s.Parent = l
	l.Parent = gui
	TweenService:Create(l, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
	task.delay(0.45, function()
		TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 1)
end

local function shake(seconds, strength)
	if not Settings.Get("CameraShake") then
		return
	end
	local cam = workspace.CurrentCamera
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > seconds then
			conn:Disconnect()
			return
		end
		local k = strength * (1 - t / seconds)
		cam.CFrame = cam.CFrame * CFrame.Angles(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
	end)
end

gameEvent.OnClientEvent:Connect(function(kind, d)
	if kind ~= "BatHit" or type(d) ~= "table" or typeof(d.Position) ~= "Vector3" then
		return
	end
	local target = Players:GetPlayerByUserId(d.Target or 0)
	local char = target and target.Character
	local pos = d.Position
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		pos = hrp.Position
	end
	playAtPosition("BatHit", pos)
	burst(pos + Vector3.new(0, 1, 0))
	pop(pos)
	if target == player then
		shake(0.35, math.rad(2.2))
	elseif d.Attacker == player.UserId then
		shake(0.12, math.rad(0.8))
	end
end)
