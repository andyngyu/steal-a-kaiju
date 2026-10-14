-- Wind in the Kaiju Citadel: every model tagged "CitadelWind" (Tools.CitadelBuilder's banners and flags) sways on this
-- client only. Hanging banners swing about their rod; flags flap about their pole. Only models near the camera move,
-- at most 30 times a second, and nothing moves with the ReducedEffects setting on (everything returns to rest).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent:WaitForChild("Settings"))

local TAG = "CitadelWind"
local RANGE = 360 -- studs from the camera
local STEP = 1 / 30
local FIXED = { Rod = true, RodKnob = true } -- a banner's rod stays put

local entries = {} -- [model] = { parts, rest, hinge (CFrame: the axis is its X for banners, Y for flags), kind, amp, speed, phase }

local function add(model)
	if entries[model] or not model:IsA("Model") then
		return
	end
	local parts, rest = {}, {}
	local rod, cloth
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Rod" then
				rod = d
			elseif d.Name == "Cloth" then
				cloth = d
			end
			if not FIXED[d.Name] then
				table.insert(parts, d)
				table.insert(rest, d.CFrame)
			end
		end
	end
	if #parts == 0 or not cloth then
		return
	end
	local e = { parts = parts, rest = rest, phase = math.random() * 10 }
	if rod then
		-- banner: swings about the rod (the rod's X axis), more for long banners, slower too
		e.kind = "banner"
		e.hinge = rod.CFrame
		local length = cloth.Size.Y
		e.amp = math.rad(math.clamp(70 / length, 2, 6))
		e.speed = math.clamp(9 / math.sqrt(length), 1, 2.6)
	else
		-- flag: flaps about the pole, at the cloth's edge nearest it (flags fly towards +X)
		e.kind = "flag"
		local edge = cloth.Position - cloth.CFrame.RightVector * cloth.Size.X / 2
		e.hinge = CFrame.new(edge)
		e.amp = math.rad(14)
		e.speed = 3.2
	end
	e.centre = cloth.Position
	entries[model] = e
end

local function remove(model)
	entries[model] = nil
end

for _, m in CollectionService:GetTagged(TAG) do
	add(m)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

local reduced = false
local function rest(e)
	workspace:BulkMoveTo(e.parts, e.rest, Enum.BulkMoveMode.FireCFrameChanged)
	e.moving = false
end
Settings.Changed("ReducedEffects", function(on)
	reduced = on and true or false
	if reduced then
		for _, e in entries do
			if e.moving then
				rest(e)
			end
		end
	end
end)

local acc = 0
local cfs = {}
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < STEP or reduced then
		return
	end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for model, e in entries do
		if not model.Parent then
			entries[model] = nil
		elseif (e.centre - camPos).Magnitude < RANGE then
			-- two mixed waves, so neighbours don't move in step and gusts come and go
			local w = math.sin(t * e.speed + e.phase) * 0.75 + math.sin(t * e.speed * 2.3 + e.phase * 1.7) * 0.25
			local turn
			if e.kind == "banner" then
				turn = e.hinge * CFrame.Angles(e.amp * w, 0, 0) * e.hinge:Inverse()
			else
				turn = e.hinge * CFrame.Angles(0, e.amp * w, 0) * e.hinge:Inverse()
			end
			table.clear(cfs)
			for i, cf in e.rest do
				cfs[i] = turn * cf
			end
			workspace:BulkMoveTo(e.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			e.moving = true
		elseif e.moving then
			rest(e)
		end
	end
end)
