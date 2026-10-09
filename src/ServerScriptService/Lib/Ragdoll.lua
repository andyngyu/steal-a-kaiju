-- Ragdolls a character for a few seconds (StealService tackles), then the joints come back and the player gets up.
-- Two kinds of rig:
--   avatar joints (Roblox's current characters: a kinematic AnimationConstraint per joint, each paired with a limited
--     "<Joint>BallSocket" BallSocketConstraint): the AnimationConstraints are switched off so the ball sockets take
--     over (a joint without its ball socket gets one built);
--   classic Motor6D rigs: each limb Motor6D is switched off and a limited ball socket is built in its place.
-- The root and neck joints stay rigid (no death from a loose head, and the camera keeps following). While limp the
-- limbs collide with the ground and the root box doesn't.
-- The server does the joints so everyone sees it; the owning client puts its Humanoid into the Physics state while
-- the character attribute RagdollUntil (server time) is set (StarterPlayerScripts.Gameplay.RagdollFX).
local Ragdoll = {}

local RIGID = { Root = true, RootJoint = true, Neck = true }

-- [joint name] = { cone, twist low, twist high } in degrees, for sockets this module builds. Twist is the swing
-- forward/back about the joint's X axis.
local LIMITS = {
	Waist = { 20, -25, 25 },
	LeftShoulder = { 75, -110, 110 },
	RightShoulder = { 75, -110, 110 },
	LeftElbow = { 10, -5, 120 },
	RightElbow = { 10, -5, 120 },
	LeftWrist = { 25, -30, 30 },
	RightWrist = { 25, -30, 30 },
	LeftHip = { 45, -80, 80 },
	RightHip = { 45, -80, 80 },
	LeftKnee = { 10, -120, 5 },
	RightKnee = { 10, -120, 5 },
	LeftAnkle = { 20, -35, 35 },
	RightAnkle = { 20, -35, 35 },
	-- R6
	["Left Shoulder"] = { 60, -90, 90 },
	["Right Shoulder"] = { 60, -90, 90 },
	["Left Hip"] = { 45, -70, 70 },
	["Right Hip"] = { 45, -70, 70 },
}
local DEFAULT_LIMIT = { 30, -30, 30 }

local active = {} -- [character] = { token, joints, made, collide }

local function buildSocket(rec, a0, a1, limit)
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollJoint"
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.UpperAngle = limit[1]
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = limit[2]
	socket.TwistUpperAngle = limit[3]
	socket.Restitution = 0
	socket.Parent = a1.Parent
	table.insert(rec.made, socket)
	local apart = Instance.new("NoCollisionConstraint")
	apart.Name = "RagdollApart"
	apart.Part0 = a0.Parent
	apart.Part1 = a1.Parent
	apart.Parent = a1.Parent
	table.insert(rec.made, apart)
end

local function goLimp(rec, joint)
	if RIGID[joint.Name] or not joint.Enabled then
		return
	end
	if joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		if not (a0 and a1 and a0.Parent and a1.Parent) then
			return
		end
		local own = a1.Parent:FindFirstChild(joint.Name .. "BallSocket")
		if not (own and own:IsA("BallSocketConstraint") and own.Enabled) then
			buildSocket(rec, a0, a1, LIMITS[joint.Name] or DEFAULT_LIMIT)
		end
	elseif joint:IsA("Motor6D") and LIMITS[joint.Name] and joint.Part0 and joint.Part1 then
		local a0 = Instance.new("Attachment")
		a0.Name = "RagdollA"
		a0.CFrame = joint.C0
		a0.Parent = joint.Part0
		local a1 = Instance.new("Attachment")
		a1.Name = "RagdollB"
		a1.CFrame = joint.C1
		a1.Parent = joint.Part1
		table.insert(rec.made, a0)
		table.insert(rec.made, a1)
		buildSocket(rec, a0, a1, LIMITS[joint.Name])
	else
		return
	end
	joint.Enabled = false
	table.insert(rec.joints, joint)
end

function Ragdoll.Stop(character)
	local rec = active[character]
	if not rec then
		return
	end
	active[character] = nil
	for _, inst in rec.made do
		inst:Destroy()
	end
	for _, joint in rec.joints do
		if joint.Parent then
			joint.Enabled = true
		end
	end
	for part, collide in rec.collide do
		if part.Parent then
			part.CanCollide = collide
		end
	end
	if character.Parent then
		character:SetAttribute("RagdollUntil", nil)
	end
end

-- Limp for `seconds` (calling it again while limp just extends it). Returns false for a dead or missing character.
function Ragdoll.Start(character, seconds)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then
		return false
	end
	local rec = active[character]
	if not rec then
		rec = { token = 0, joints = {}, made = {}, collide = {} }
		active[character] = rec
		for _, joint in character:GetDescendants() do
			if joint:IsA("AnimationConstraint") or joint:IsA("Motor6D") then
				goLimp(rec, joint)
			end
		end
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") then
				rec.collide[part] = part.CanCollide
				part.CanCollide = part.Name ~= "HumanoidRootPart"
			end
		end
		character.Destroying:Once(function()
			active[character] = nil
		end)
	end
	rec.token += 1
	local token = rec.token
	character:SetAttribute("RagdollUntil", workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, function()
		if active[character] == rec and rec.token == token then
			Ragdoll.Stop(character)
		end
	end)
	return true
end

function Ragdoll.IsLimp(character)
	return active[character] ~= nil
end

return Ragdoll
