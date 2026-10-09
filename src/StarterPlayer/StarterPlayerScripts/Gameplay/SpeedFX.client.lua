-- Speed visuals, client-only: scrolling treadmill belt, "+Speed" popups while training, the Speed Shop kiosk showing
-- this viewer's own price, biome signs showing the viewer's speed against the recommended speed, and a burst on purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SpeedConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SpeedConfig"))
local Format = require(ReplicatedStorage.Shared.Util.Format)
local gameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local belt = map:WaitForChild("Treadmill"):WaitForChild("Belt")
local shop = map:WaitForChild("SpeedShop")
local lane = map:WaitForChild("Lane")

local GREEN = Color3.fromHex("6BE04A")
local RED = Color3.fromHex("FF4D5E")
local GOLD = Color3.fromHex("FFD23F")

local function fmtSpeed(n)
	return (string.format("%.1f", n):gsub("%.0$", ""))
end

-- ---------- signs ----------

local function refreshShop()
	local gui = shop.Board:FindFirstChildOfClass("SurfaceGui")
	local prompt = shop.Board:FindFirstChild("BuyPrompt")
	if not gui then
		return
	end
	local speed = player:GetAttribute("Speed") or SpeedConfig.BaseSpeed
	local cost = player:GetAttribute("NextSpeedCost")
	if cost and speed < SpeedConfig.MaxSpeed then
		local nextSpeed = math.min(SpeedConfig.MaxSpeed, speed + SpeedConfig.Upgrade.SpeedPerLevel)
		gui.Detail.Text = "Speed " .. fmtSpeed(speed) .. " > " .. fmtSpeed(nextSpeed)
		gui.PriceFrame.Price.Text = Format.Money(cost)
		if prompt then
			prompt.ObjectText = "+" .. SpeedConfig.Upgrade.SpeedPerLevel .. " Speed: " .. Format.Money(cost)
			prompt.Enabled = true
		end
	else
		gui.Detail.Text = "Speed " .. fmtSpeed(speed) .. " (Max)"
		gui.PriceFrame.Price.Text = "MAX"
		if prompt then
			prompt.Enabled = false
		end
	end
end

local function refreshBiomeSigns()
	local speed = player:GetAttribute("Speed") or SpeedConfig.BaseSpeed
	for _, biome in lane:GetChildren() do
		local sign = biome:FindFirstChild("Sign")
		local rec = sign and sign:GetAttribute("RecommendedSpeed")
		if rec then
			local ready = speed >= rec
			local gui = sign.Board:FindFirstChildOfClass("SurfaceGui")
			if gui and gui:FindFirstChild("Status") then
				gui.Status.Text = "Your Speed: " .. fmtSpeed(speed) .. (ready and "  OK" or "  Too slow")
				gui.Status.TextColor3 = ready and GREEN or RED
			end
			local lamp = sign:FindFirstChild("Lamp")
			if lamp then
				lamp.Color = ready and GREEN or RED
			end
		end
	end
end

local function refreshAll()
	refreshShop()
	refreshBiomeSigns()
end

player:GetAttributeChangedSignal("Speed"):Connect(refreshAll)
player:GetAttributeChangedSignal("NextSpeedCost"):Connect(refreshShop)
refreshAll()

-- ---------- popups & bursts ----------

local function popup(text, color)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.1
	l.Text = text
	l.Parent = bb
	bb.Parent = head
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.1)
end

local function burst(color)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(40)
	Debris:AddItem(att, 1.2)
end

-- batch treadmill gains into one popup per second
local lastTrained = player:GetAttribute("TrainedSpeed")
local pendingGain, lastPopup = 0, 0
player:GetAttributeChangedSignal("TrainedSpeed"):Connect(function()
	local now = player:GetAttribute("TrainedSpeed") or 0
	if lastTrained and now > lastTrained then
		pendingGain += now - lastTrained
	end
	lastTrained = now
end)

gameEvent.OnClientEvent:Connect(function(name, data)
	if name == "SpeedBought" then
		popup("Speed " .. fmtSpeed(data.Speed) .. "!", GOLD)
		burst(GOLD)
	elseif name == "TreadmillMaxed" then
		popup("Treadmill maxed! Buy Speed to go faster", GOLD)
	end
end)

-- ---------- treadmill belt ----------

local stripes = belt:FindFirstChild("Stripes")
RunService.RenderStepped:Connect(function(dt)
	if stripes then
		stripes.OffsetStudsU = (stripes.OffsetStudsU + SpeedConfig.Treadmill.BeltSpeed * dt) % stripes.StudsPerTileU
	end
	if pendingGain > 0 and os.clock() - lastPopup > 1 then
		lastPopup = os.clock()
		popup("+" .. string.format("%.1f", pendingGain) .. " Speed", GREEN)
		pendingGain = 0
	end
end)
