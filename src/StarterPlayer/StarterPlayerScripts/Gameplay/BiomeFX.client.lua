-- BiomeFX: a little life for the canyon set pieces, client-only and purely cosmetic (never touches game state).
--   FlickerBolt  models of neon bolt parts stay dark and strike now and then: a quick double flash, any lights inside
--                them flaring with it. Attributes MinGap / MaxGap (seconds between strikes, default 2..6).
--   SpinCloud    models that turn slowly round a vertical axis through their centre. Attribute SpinSpeed (deg/s).
-- Both only run while the camera is within RANGE. Parts the WorldCuller has taken out (Parent nil) are skipped; spin
-- is applied from each part's rest pose, so they line up again when they come back. Reduced Effects halves the strikes.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent:WaitForChild("Settings"))

local RANGE = 700
local SPIN_HZ = 30

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local function reduced()
	return Settings.Get("ReducedEffects") == true
end

---------------------------------------------------------------- bolts
local bolts = {}
local function addBolt(m)
	if bolts[m] or not m:IsA("Model") then
		return
	end
	local e = { parts = {}, lights = {}, next = os.clock() + math.random() * 4, step = 0 }
	local sum, n = Vector3.zero, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(e.parts, { d, d.Transparency })
			d.Transparency = 1
			sum += d.Position
			n += 1
		elseif d:IsA("Light") then
			table.insert(e.lights, { d, d.Brightness })
			d.Brightness = 0
		end
	end
	e.center = n > 0 and sum / n or Vector3.zero
	e.minGap = m:GetAttribute("MinGap") or 2
	e.maxGap = m:GetAttribute("MaxGap") or 6
	bolts[m] = e
end
local function show(e, on)
	for _, p in e.parts do
		p[1].Transparency = on and p[2] or 1
	end
	for _, l in e.lights do
		l[1].Brightness = on and l[2] or 0
	end
end
-- a strike: on, off, on (longer), off
local FLASH = { { 0, true }, { 0.07, false }, { 0.12, true }, { 0.32, false } }

---------------------------------------------------------------- spinning clouds
local spins = {}
local function addSpin(m)
	if spins[m] or not m:IsA("Model") then
		return
	end
	local cf = m:GetBoundingBox()
	local centre = CFrame.new(cf.Position)
	local e = { parts = {}, centre = centre, angle = 0, speed = math.rad(m:GetAttribute("SpinSpeed") or 3) }
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(e.parts, { d, centre:ToObjectSpace(d.CFrame) })
		end
	end
	spins[m] = e
end

for _, m in CollectionService:GetTagged("FlickerBolt") do
	addBolt(m)
end
for _, m in CollectionService:GetTagged("SpinCloud") do
	addSpin(m)
end
CollectionService:GetInstanceAddedSignal("FlickerBolt"):Connect(addBolt)
CollectionService:GetInstanceAddedSignal("SpinCloud"):Connect(addSpin)

local spinAcc = 0
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for _, e in bolts do
		if e.step > 0 then
			local f = FLASH[e.step]
			if now - e.started >= f[1] then
				show(e, f[2])
				e.step += 1
				if e.step > #FLASH then
					e.step = 0
					local k = reduced() and 2 or 1
					e.next = now + (e.minGap + math.random() * (e.maxGap - e.minGap)) * k
				end
			end
		elseif now >= e.next then
			if (e.center - camPos).Magnitude < RANGE then
				e.step, e.started = 1, now
			else
				e.next = now + 2
			end
		end
	end
	spinAcc += dt
	if spinAcc >= 1 / SPIN_HZ then
		local step = spinAcc
		spinAcc = 0
		for _, e in spins do
			if (e.centre.Position - camPos).Magnitude < RANGE + 200 then
				e.angle = (e.angle + e.speed * step) % (math.pi * 2)
				local rot = e.centre * CFrame.Angles(0, e.angle, 0)
				for _, p in e.parts do
					if p[1].Parent then
						p[1].CFrame = rot * p[2]
					end
				end
			end
		end
	end
end)
