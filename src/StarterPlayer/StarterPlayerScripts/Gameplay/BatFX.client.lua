-- The bat, client side (rules in Services.BatService, numbers in StealConfig.Bat):
--   swinging: clicking / tapping with the bat out sends Remotes.SwingBat (the server times the cooldown too)
--   hands full: the bat goes away while you carry an egg or stolen goods, hold a steal, are stunned / ragdolled or on
--               a treadmill, and can't be taken out again until you're free (the server moves the tool: the
--               hotbar's bat slot sends Remotes.SwingBat "Equip" / "Unequip")
--   idle pose:  holding the bat keeps the normal idle / walk pose (the Animate script's arm-out "toolnone" hold is
--               stopped), so the bat points forward from the hand
--   the swing:  the designer's BatSwing animation (asset 76001367769633, kept as the KeyframeSequence
--               ReplicatedStorage.Assets.BatSwing). It's played from that copy in code on every client when a bat's
--               SwungAt attribute changes: each frame its poses are blended and written to the R15 joints
--               (Motor6D.Transform, after the Animator). That way it works in the live game without the experience
--               (owned by the group) needing permission to load an animation asset owned by the designer's account.
--               While it plays the bat sits in the hand at SWING_GRIP (both hands on the handle).
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
for _, attr in { "CarryingEgg", "CarryingStolen", "Stealing", "StunnedUntil" } do
	player:GetAttributeChangedSignal(attr):Connect(putAway)
end

---------------------------------------------------------------- everyone's swings: the whoosh
-- the swing: the BatSwing KeyframeSequence, sampled into per-joint tracks once
local SPEED = 1.6 -- playback speed (1 = as animated; sped up so the swing feels snappy)
-- only the upper body swings: the legs and hips keep doing whatever the walk / run / idle animation does, so you
-- can swing on the move without the run freezing
local UPPER_BODY = { UpperTorso = true, Head = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true }
-- the bat in the hand during the swing (the RightGrip weld's C1): fitted to the animation so the bat starts up over
-- the right shoulder in a batting stance (both hands on the handle), comes through in front at the strike (~0.15 s)
-- and wraps round behind the back on the follow-through
local SWING_GRIP = CFrame.new(0, -0.3, 0, -0.6830, -0.4773, -0.5529, 0.7288, -0.3951, -0.5592, -0.0485, 0.7849, -0.6177)
-- after the strike the bat tips down so the follow-through ends with it angled down behind you (about 35 degrees
-- below level). The bat never turns inside the hand during the swing (that's what made it look out of sync with
-- the arms): the right WRIST turns instead, carrying the bat with it, between END_FROM and END_AT seconds. END_GRIP
-- is the grip that would give the same bat angle; the wrist turn is worked out from it.
local END_GRIP = CFrame.new(0, -0.3, 0, -0.9964, -0.0377, 0.0763, -0.0413, -0.5693, -0.8211, -0.0744, 0.8213, -0.5657)
local END_FROM, END_AT = 0.17, 0.4
local tracks = {} -- [part name] = { times = {...}, cfs = {...} }
local SWING_TIME = 0
do
	local ks = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BatSwing", 20)
	if ks then
		local kfs = ks:GetKeyframes()
		table.sort(kfs, function(a, b)
			return a.Time < b.Time
		end)
		for _, kf in kfs do
			SWING_TIME = math.max(SWING_TIME, kf.Time)
			for _, pose in kf:GetDescendants() do
				if pose:IsA("Pose") and pose.Weight > 0 and UPPER_BODY[pose.Name] then
					local tr = tracks[pose.Name]
					if not tr then
						tr = { times = {}, cfs = {} }
						tracks[pose.Name] = tr
					end
					table.insert(tr.times, kf.Time)
					table.insert(tr.cfs, pose.CFrame)
				end
			end
		end
	end
end
local function sampleTrack(tr, t)
	local times, cfs = tr.times, tr.cfs
	if t <= times[1] then
		return cfs[1]
	end
	for i = 1, #times - 1 do
		if t <= times[i + 1] then
			local k = (t - times[i]) / math.max(times[i + 1] - times[i], 1e-4)
			return cfs[i]:Lerp(cfs[i + 1], k)
		end
	end
	return cfs[#cfs]
end
-- the Motor6D that moves a body part (the joint inside the part whose Part1 is the part)
-- (classic rigs use Motor6Ds; current avatars use AnimationConstraints, which have a Transform too)
local function jointOf(char, partName)
	local part = char:FindFirstChild(partName)
	if not part then
		return nil
	end
	for _, m in part:GetChildren() do
		if (m:IsA("Motor6D") and m.Part1 == part) or (m:IsA("AnimationConstraint") and m.Attachment1 and m.Attachment1.Parent == part) then
			return m
		end
	end
	return nil
end
local BLEND_IN = 0.03 -- seconds (animation time) to ease into the swing from the idle pose (the bat jumps to the stance with the arms)
-- after the last frame the follow-through is held a moment, then eases back into the idle / walk pose over RECOVER
-- real seconds (bat and arms together). This used to be a 0.12 s blend squeezed into the end of the sped-up swing
-- (~0.075 s), which read as a snap back to idle.
-- The bat itself comes back on its own path: its direction (relative to the torso) turns straight from where the
-- follow-through left it to the idle hold, whatever the arms do on the way. (Blending the grip weld instead spun the
-- bat about 180 degrees in the hand - the swing grip and the idle grip are half a turn apart - and popped on the
-- first frame.)
local HOLD_END = 0.04
local RECOVER = 0.26
-- the wrist turn (in the wrist joint's frame) that tips the bat from SWING_GRIP's angle to END_GRIP's
local function wristTurn(char, joint)
	local hand = char:FindFirstChild("RightHand")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if not (weld and joint) then
		return nil
	end
	local c0 = weld.C0
	local delta = c0 * END_GRIP:Inverse() * SWING_GRIP * c0:Inverse() -- hand-local turn
	local b
	if joint:IsA("Motor6D") then
		b = joint.C1
	elseif joint.Attachment1 then
		b = joint.Attachment1.CFrame
	else
		return nil
	end
	return b:Inverse() * delta * b
end
local savedGrip = {} -- [character] = { weld, C1 }
local function restoreGrip(char)
	local s = savedGrip[char]
	savedGrip[char] = nil
	if s and s.weld.Parent then
		s.weld.C1 = s.c1
	end
end
RunService.Stepped:Connect(function()
	local now = os.clock()
	for char, started in swings do
		local real = now - started
		local t = math.min(real * SPEED, SWING_TIME)
		local past = real - SWING_TIME / SPEED - HOLD_END -- seconds into the recovery
		if past > RECOVER or not char.Parent or not char:FindFirstChild(TOOL_NAME) or char:GetAttribute("RagdollUntil") then
			swings[char] = nil
			restoreGrip(char)
			continue
		end
		local w = math.min(1, t / BLEND_IN)
		if past > 0 then
			local r = math.clamp(past / RECOVER, 0, 1)
			w = 1 - r * r * (3 - 2 * r) -- smooth ease out of the follow-through
		end
		local k = math.clamp((t - END_FROM) / (END_AT - END_FROM), 0, 1)
		k = k * k * (3 - 2 * k)
		for name, tr in tracks do
			local m = jointOf(char, name)
			if m then
				local cf = sampleTrack(tr, t)
				if name == "RightHand" and k > 0 then
					local turn = wristTurn(char, m)
					if turn then
						cf = cf * CFrame.new():Lerp(turn, k)
					end
				end
				m.Transform = w >= 1 and cf or m.Transform:Lerp(cf, w)
			end
		end
		local hand = char:FindFirstChild("RightHand")
		local weld = hand and hand:FindFirstChild("RightGrip")
		local torso = char:FindFirstChild("UpperTorso")
		if weld then
			local saved = savedGrip[char]
			if not saved then
				saved = { weld = weld, c1 = weld.C1 }
				savedGrip[char] = saved
			end
			if past <= 0 or not torso then
				-- fixed in the hand for the whole swing
				weld.C1 = SWING_GRIP
				saved.endRot = nil
			else
				-- recovery: turn the bat (torso-relative) from its follow-through direction to the idle hold's
				local handRot = (hand.CFrame * weld.C0).Rotation
				local torsoRot = torso.CFrame.Rotation
				if not saved.endRot then
					saved.endRot = torsoRot:Inverse() * handRot * SWING_GRIP.Rotation:Inverse()
				end
				local restRot = saved.c1.Rotation
				local idleRot = torsoRot:Inverse() * handRot * restRot:Inverse()
				local want = torsoRot * saved.endRot:Lerp(idleRot, 1 - w) -- the bat's world rotation now
				-- handle = hand * C0 * C1^-1  ->  C1 = handle^-1 * hand * C0 (rotation), keeping the idle grip's offset
				weld.C1 = CFrame.new(saved.c1.Position) * (want:Inverse() * handRot)
			end
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
