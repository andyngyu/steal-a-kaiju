-- Holding things overhead, client-only and cosmetic:
--   arms: anyone carrying a nest egg (attribute CarryingEgg) or stolen goods (CarryingStolen) holds it up in the Hold
--     pose (ReplicatedStorage.Assets.Animations.Hold, Andy's KeyframeSequence). Only the arm joints are posed, on top of
--     whatever the character is playing, so the legs keep walking, running and jumping. Blends in and out quickly.
--     Driven through each arm joint's Transform after the Animator every frame (Motor6D on classic rigs,
--     AnimationConstraint on Roblox's current avatar joints), so no uploaded animation id is needed.
--   item: the carried egg (character child "Egg", weld CarryWeld) and stolen kaiju ("StolenKaiju") bob and sway in time
--     with the arms instead of spinning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ARM_JOINTS = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
local SHOULDERS = { LeftUpperArm = true, RightUpperArm = true }
local BLEND_SPEED = 12 -- 1/s
local BOB_SPEED, BOB_HEIGHT = 3, 0.16

local holdSeq = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("Hold")

-- [joint name] = sorted { time, cf, style, dir } from the KeyframeSequence (weight-0 poses skipped). Rebuilt whenever
-- more of the sequence arrives (its keyframes can replicate after this script starts).
local tracks, length = {}, 0
local wanted = {}
for _, name in ARM_JOINTS do
	wanted[name] = true
end
local function collect(pose, time)
	if not pose:IsA("Pose") then
		return
	end
	if wanted[pose.Name] and pose.Weight > 0 then
		tracks[pose.Name] = tracks[pose.Name] or {}
		table.insert(tracks[pose.Name], { time = time, cf = pose.CFrame, style = pose.EasingStyle, dir = pose.EasingDirection })
	end
	for _, child in pose:GetChildren() do
		collect(child, time)
	end
end
local function buildTracks()
	tracks, length = {}, 0
	for _, kf in holdSeq:GetChildren() do
		if kf:IsA("Keyframe") then
			length = math.max(length, kf.Time)
			for _, pose in kf:GetChildren() do
				collect(pose, kf.Time)
			end
		end
	end
	for _, keys in tracks do
		table.sort(keys, function(a, b)
			return a.time < b.time
		end)
	end
end
buildTracks()
local tracksDirty = false
holdSeq.DescendantAdded:Connect(function()
	tracksDirty = true
end)

local EASING = {
	[Enum.PoseEasingStyle.Linear] = Enum.EasingStyle.Linear,
	[Enum.PoseEasingStyle.Elastic] = Enum.EasingStyle.Elastic,
	[Enum.PoseEasingStyle.Cubic] = Enum.EasingStyle.Cubic,
	[Enum.PoseEasingStyle.Bounce] = Enum.EasingStyle.Bounce,
	[Enum.PoseEasingStyle.CubicV2] = Enum.EasingStyle.Cubic,
}
local DIRECTION = {
	[Enum.PoseEasingDirection.In] = Enum.EasingDirection.In,
	[Enum.PoseEasingDirection.Out] = Enum.EasingDirection.Out,
	[Enum.PoseEasingDirection.InOut] = Enum.EasingDirection.InOut,
}

local function sample(keys, t)
	if #keys == 1 or t <= keys[1].time then
		return keys[1].cf
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.time then
			if a.style == Enum.PoseEasingStyle.Constant then
				return a.cf
			end
			local k = (t - a.time) / math.max(b.time - a.time, 1e-4)
			k = TweenService:GetValue(k, EASING[a.style] or Enum.EasingStyle.Linear, DIRECTION[a.dir] or Enum.EasingDirection.In)
			return a.cf:Lerp(b.cf, k)
		end
	end
	return keys[#keys].cf
end

-- [character] = { w = blend 0..1, joints = { [part name] = Motor6D | AnimationConstraint } }
local states = {}

-- Character joints by the part they move; both kinds carry a Transform the Animator writes every frame.
local function jointsOf(char)
	local map = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			map[d.Part1.Name] = d
		elseif d:IsA("AnimationConstraint") and d.Attachment1 and d.Attachment1.Parent then
			map[d.Attachment1.Parent.Name] = d
		end
	end
	return map
end

RunService.Stepped:Connect(function(_, dt)
	if tracksDirty then
		tracksDirty = false
		buildTracks()
	end
	local t = os.clock()
	local animT = length > 0 and t % length or 0
	local bob = math.sin(t * BOB_SPEED) * BOB_HEIGHT
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then
			continue
		end
		local carrying = plr:GetAttribute("CarryingEgg") ~= nil or plr:GetAttribute("CarryingStolen") ~= nil
		local st = states[char]
		if not st then
			if not carrying then
				continue
			end
			st = { w = 0, joints = jointsOf(char) }
			states[char] = st
			char.Destroying:Once(function()
				states[char] = nil
			end)
		end
		st.w = st.w + ((carrying and 1 or 0) - st.w) * (1 - math.exp(-BLEND_SPEED * dt))
		if not carrying and st.w < 0.01 then
			states[char] = nil
			continue
		end
		for name, keys in tracks do
			local joint = st.joints[name]
			if joint and joint.Parent and joint.Enabled then
				local pose = sample(keys, animT)
				if SHOULDERS[name] then
					pose = CFrame.new(0, bob * 0.6, 0) * pose -- the arms ride the bob with the item
				end
				joint.Transform = joint.Transform:Lerp(pose, st.w)
			end
		end
		-- the item rides the same bob and sways gently
		local egg = char:FindFirstChild("Egg")
		local shell = egg and egg.PrimaryPart
		local eggWeld = shell and shell:FindFirstChild("CarryWeld")
		if eggWeld then
			local offset = egg:GetAttribute("CarryOffset") or 4.4
			eggWeld.C0 = CFrame.new(0, offset + bob, 0) * CFrame.Angles(math.sin(t * 2) * 0.05, math.sin(t * 1.3) * 0.25, 0)
		end
		local kaiju = char:FindFirstChild("StolenKaiju")
		local root = kaiju and kaiju.PrimaryPart
		local kaijuWeld = root and root:FindFirstChild("CarryWeld")
		if kaijuWeld then
			kaijuWeld.C1 = CFrame.Angles(0, math.sin(t * 1.3) * 0.25, math.sin(t * 2.6) * 0.05) * CFrame.new(0, -bob, 0)
		end
	end
end)
