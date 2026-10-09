-- Kaiju Market + feeding visuals, client-only (the server owns every purchase, sale and level):
--   pads:     standing on a stall's Pad opens that shop's UI panel (Food Shop / Trail Shop / Sell) via the UI's UIApi;
--             OpenPrompts on the counters open the same panels.
--   stalls:   pad rings pulse and sparkle, food on the counter bobs, the trail wheel spins its orbs with real trails;
--             the food counter tags show SOLD OUT from this player's stock (FoodStock_<FoodId>) and the chalkboard by
--             the food pad (FoodStall.RestockBoard) counts down to the next restock (workspace attribute FoodRestockAt)
--   prompts:  Feed (E) / Feed x10 (F) prompts on kaiju and Hatch prompts on pen eggs only show for their owner. Kaiju move
--             only on clients, so the owner's Feed triggers are sent as Remotes.FeedKaiju (kaijuId, nil, 1 | 10)
--   feeding:  GameEvent KaijuFed -> the food arcs from the owner into the kaiju's mouth, sets the client-only attribute
--             EatAt on the kaiju (KaijuFX plays its Eat emote), "+XP" popup; level-ups get a burst + "LEVEL n!" banner
--             on the rebuilt model (attribute LeveledAt)
--   selling:  GameEvent KaijuSold -> coin burst + "+$" popup where the kaiju stood
--   perks:    GameEvent EggLucky -> gold burst + "LUCKY!" and what changed on the upgraded egg; EggGiven -> a store egg
--             falls into the pen and lands in a light pillar with "BONUS EGG!"
--   toasts:   GameEvent toasts belong to the UI (KaijuUI NotificationsController)
--   settings: Reduced Effects (Gameplay.Settings "ReducedEffects") cuts bursts to a third, shrinks coin showers and
--             turns the pad sparkles off
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local FoodConfig = require(Config.FoodConfig)
local TrailConfig = require(Config.TrailConfig)
local EggConfig = require(Config.EggConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Settings = require(script.Parent:WaitForChild("Settings"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameEvent = remotes:WaitForChild("GameEvent")
local feedRemote = remotes:WaitForChild("FeedKaiju")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local market = map:WaitForChild("Market")
local runtime = workspace:WaitForChild("Runtime")
local kaijuFolder = runtime:WaitForChild("Kaiju")
local eggFolder = runtime:WaitForChild("Eggs")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FX_RANGE = 160
local rng = Random.new()
local reduced = false -- Reduced Effects setting

local fxFolder = Instance.new("Folder")
fxFolder.Name = "MarketFXLocal"
fxFolder.Parent = workspace

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- ---------- the UI's API (owned by the UI; used only for panels) ----------

local uiApi = nil
local function ui()
	if uiApi then
		return uiApi
	end
	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("KaijuUI")
	local module = gui and gui:FindFirstChild("UIApi")
	if module then
		local ok, api = pcall(require, module)
		if ok and type(api) == "table" then
			uiApi = api
		end
	end
	return uiApi
end

local function openPanel(name)
	local api = ui()
	if api and api.OpenPanel then
		pcall(api.OpenPanel, name)
	end
end

local function closePanel(name)
	local api = ui()
	if api and api.ClosePanel then
		pcall(api.ClosePanel, name)
	end
end

-- ---------- small effect helpers ----------

local function anchorAt(pos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new(pos)
	p.Parent = fxFolder
	return p
end

local function burst(pos, color, count, speed, size)
	if reduced then
		count = math.max(1, math.floor(count * 0.3))
	end
	local holder = anchorAt(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 1)
	pe.Drag = 3
	pe.Rate = 0
	pe.Parent = holder
	pe:Emit(count)
	Debris:AddItem(holder, 1.5)
end

local function ring(pos, color, size, duration)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CastShadow = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Size = Vector3.new(0.15, 1, 1)
	r.Transparency = 0.15
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = fxFolder
	TweenService:Create(r, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, size, size), Transparency = 1 }):Play()
	Debris:AddItem(r, duration + 0.1)
end

-- Floating text that rises and fades (a world billboard on an invisible part or on a model part).
local function popup(adornee, offset, text, color, sizeStuds, duration)
	local host = adornee
	if typeof(adornee) == "Vector3" then
		host = anchorAt(adornee)
		Debris:AddItem(host, duration + 0.2)
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(sizeStuds * 2.6, 0, sizeStuds, 0)
	bb.StudsOffsetWorldSpace = offset
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromHex("1A1033")
	s.Parent = l
	l.Parent = bb
	bb.Parent = host
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffsetWorldSpace = offset + Vector3.new(0, sizeStuds * 1.4, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5), { Transparency = 1 }):Play()
	Debris:AddItem(bb, duration + 0.1)
end

local function findKaiju(kaijuId)
	for _, m in kaijuFolder:GetChildren() do
		if m:GetAttribute("KaijuId") == kaijuId then
			return m
		end
	end
	return nil
end

-- Where a kaiju's mouth is right now (its Head group's front), from the parts KaijuFX moves locally.
local function mouthOf(model)
	local head = model:FindFirstChild("Head", true)
	if head and head:IsA("Model") then
		local cf, size = head:GetBoundingBox()
		local root = model.PrimaryPart
		local forward = root and root.CFrame.LookVector or cf.LookVector
		return cf.Position + forward * size.Z * 0.45 - Vector3.new(0, size.Y * 0.15, 0)
	end
	local cf, size = model:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y * 0.3, 0)
end

-- ---------- prompts: owner-only feeding and hatching ----------

local function ownerOf(inst, folder)
	local a = inst
	while a and a.Parent ~= folder do
		a = a.Parent
	end
	return a and a:GetAttribute("OwnerUserId"), a
end

local function filterPrompt(prompt, folder)
	if not prompt:IsA("ProximityPrompt") or prompt.Name == "StealPrompt" then
		return -- steal prompts are for other players (Gameplay.StealFX)
	end
	local ownerId, model = ownerOf(prompt, folder)
	if not model then
		return
	end
	local ownerOnly = folder == kaijuFolder or model:GetAttribute("State") == "Pen"
	if ownerOnly and ownerId ~= player.UserId then
		prompt.MaxActivationDistance = 0 -- local only: other players' feed/hatch prompts never show
		return
	end
	if folder == kaijuFolder and (prompt.Name == "FeedPrompt" or prompt.Name == "FeedTenPrompt") then
		local count = prompt.Name == "FeedTenPrompt" and 10 or 1
		prompt.Triggered:Connect(function()
			feedRemote:FireServer(model:GetAttribute("KaijuId"), nil, count)
		end)
	end
end

for _, folder in { kaijuFolder, eggFolder } do
	folder.DescendantAdded:Connect(function(d)
		filterPrompt(d, folder)
	end)
	for _, d in folder:GetDescendants() do
		filterPrompt(d, folder)
	end
end

-- ---------- stalls ----------

local pads = {} -- { pad, ring, radius, panel }
local foodItems = {} -- { model, base, seed }
local orbs = {} -- { part, index }
local wheelCenter = nil

local function addPad(pad)
	local stall = pad.Parent
	local entry = {
		pad = pad,
		ring = stall:FindFirstChild("PadRing"),
		radius = pad:GetAttribute("Radius") or 4.6,
		panel = pad:GetAttribute("Panel"),
		seed = rng:NextNumber(0, 10),
	}
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(entry.ring and entry.ring.Color or pad.Color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0.2, 1)
	pe.Speed = NumberRange.new(1.5, 3)
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.EmissionDirection = Enum.NormalId.Right -- the pad cylinder's axis points up
	pe.SpreadAngle = Vector2.new(10, 10)
	pe.Rate = 7
	pe.Enabled = not reduced
	pe.Parent = pad
	entry.emitter = pe
	table.insert(pads, entry)
end

local function setupStalls()
	for _, d in market:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Pad" then
			addPad(d)
		elseif d:IsA("ProximityPrompt") and d.Name == "OpenPrompt" then
			d.Triggered:Connect(function()
				openPanel(d:GetAttribute("Panel"))
			end)
		end
	end
	local foodStall = market:FindFirstChild("FoodStall")
	local items = foodStall and foodStall:FindFirstChild("Items")
	if items then
		for _, item in items:GetChildren() do
			if item:IsA("Model") then
				table.insert(foodItems, { model = item, base = item:GetPivot(), seed = rng:NextNumber(0, 10) })
				local food = FoodConfig.ById[item:GetAttribute("FoodId") or ""]
				local tag = item.PrimaryPart and item.PrimaryPart:FindFirstChild("Tag")
				local price = tag and tag:FindFirstChild("Price")
				if food and price then
					local function showStock()
						local left = player:GetAttribute("FoodStock_" .. food.Id)
						local soldOut = left ~= nil and left <= 0
						price.Text = soldOut and "SOLD OUT" or Format.Money(food.Price)
						price.TextColor3 = soldOut and Color3.fromHex("FF4D5E") or Color3.fromHex("6BE04A")
					end
					player:GetAttributeChangedSignal("FoodStock_" .. food.Id):Connect(showStock)
					showStock()
				end
			end
		end
	end
	local restockBoard = foodStall and foodStall:FindFirstChild("RestockBoard")
	local board = restockBoard and restockBoard:FindFirstChild("Board")
	local timeLabel = board and board:FindFirstChild("Gui") and board.Gui:FindFirstChild("Time")
	if timeLabel then
		task.spawn(function()
			while timeLabel.Parent do
				local at = workspace:GetAttribute("FoodRestockAt")
				if at then
					local left = math.max(0, math.ceil(at - workspace:GetServerTimeNow()))
					timeLabel.Text = string.format("%d:%02d", left // 60, left % 60)
				end
				task.wait(1)
			end
		end)
	end
	local trailStall = market:FindFirstChild("TrailStall")
	local wheel = trailStall and trailStall:FindFirstChild("Wheel")
	if wheel then
		wheelCenter = wheel:FindFirstChild("Center")
		for _, orb in wheel:GetChildren() do
			local trail = TrailConfig.ById[orb:GetAttribute("TrailId") or ""]
			if orb:IsA("BasePart") and orb.Name == "Orb" and trail then
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0.24, 0, 0)
				a0.Parent = orb
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(-0.24, 0, 0)
				a1.Parent = orb
				local points = {}
				for i, h in trail.Colors do
					table.insert(points, ColorSequenceKeypoint.new(#trail.Colors == 1 and 0 or (i - 1) / (#trail.Colors - 1), Color3.fromHex(h)))
				end
				if #points == 1 then
					table.insert(points, ColorSequenceKeypoint.new(1, points[1].Value))
				end
				local t = Instance.new("Trail")
				t.Attachment0 = a0
				t.Attachment1 = a1
				t.Color = ColorSequence.new(points)
				t.Transparency = NumberSequence.new(0.1, 1)
				t.Lifetime = 0.45
				t.LightEmission = trail.LightEmission
				t.FaceCamera = true
				t.Parent = orb
				table.insert(orbs, { part = orb, index = orb:GetAttribute("Index") or 1 })
			end
		end
	end
end
setupStalls()
Settings.Changed("ReducedEffects", function(on)
	reduced = on == true
	for _, entry in pads do
		entry.emitter.Enabled = not reduced
	end
end)

local currentPad = nil
local function checkPads()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = nil
	if hrp then
		for _, entry in pads do
			local p = entry.pad.Position
			local flat = Vector3.new(hrp.Position.X - p.X, 0, hrp.Position.Z - p.Z)
			if flat.Magnitude <= entry.radius and math.abs(hrp.Position.Y - p.Y) < 6 then
				inside = entry
				break
			end
		end
	end
	if inside == currentPad then
		return
	end
	if currentPad and currentPad.panel then
		closePanel(currentPad.panel)
	end
	currentPad = inside
	if inside then
		burst(inside.pad.Position + Vector3.new(0, 0.5, 0), inside.ring and inside.ring.Color or inside.pad.Color, 18, 8, 0.5)
		if inside.panel then
			openPanel(inside.panel)
		end
	end
end

-- ---------- feeding, levelling and selling ----------

local foodArt = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Food")

local function toss(foodId, from, model, delay, onLand)
	local art = foodArt:FindFirstChild(foodId)
	if not art then
		return
	end
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		local item = art:Clone()
		item.Parent = fxFolder
		local duration = 0.5
		local t0 = os.clock()
		local spin = rng:NextNumber(6, 10)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local p = math.clamp((os.clock() - t0) / duration, 0, 1)
			local to = model.Parent and mouthOf(model) or from
			local height = math.max(2.5, (to - from).Magnitude * 0.35)
			local pos = from:Lerp(to, p) + Vector3.new(0, math.sin(p * math.pi) * height, 0)
			item:PivotTo(CFrame.new(pos) * CFrame.Angles(p * spin, p * spin * 0.7, 0))
			if p >= 1 then
				conn:Disconnect()
				item:Destroy()
				onLand(to)
			end
		end)
	end)
end

local function onFed(data)
	local model = findKaiju(data.KaijuId)
	local camera = workspace.CurrentCamera
	if not (model and model.PrimaryPart) or (model.PrimaryPart.Position - camera.CFrame.Position).Magnitude > FX_RANGE then
		return
	end
	local food = FoodConfig.ById[data.FoodId]
	local owner = Players:GetPlayerByUserId(data.OwnerUserId)
	local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	local from = hrp and (hrp.Position + hrp.CFrame.LookVector * 1.2 + Vector3.new(0, 1.2, 0)) or mouthOf(model) + Vector3.new(0, 4, 0)
	local throws = math.clamp(data.Count or 1, 1, 3)
	for i = 1, throws do
		toss(data.FoodId, from, model, (i - 1) * 0.15, function(at)
			if model.Parent then
				model:SetAttribute("EatAt", os.clock()) -- KaijuFX plays its Eat emote
			end
			burst(at, food and food.Color or Color3.new(1, 1, 1), 10, 6, 0.4)
			if i == throws then
				local _, size = model:GetBoundingBox()
				popup(model.PrimaryPart or at, Vector3.new(0, size.Y + 1, 0), "+" .. Format.Short(data.XPGained or 0) .. " XP", Color3.fromHex("5AD1FF"), 1.4, 1.2)
			end
		end)
	end
end

-- A rebuilt (bigger) kaiju after a level-up.
local function onLeveled(model)
	local leveledAt = model:GetAttribute("LeveledAt")
	if not leveledAt or serverNow() - leveledAt > 3 then
		return
	end
	local root = model:WaitForChild("Root", 5)
	if not root then
		return
	end
	task.wait(0.1)
	local camera = workspace.CurrentCamera
	if (root.Position - camera.CFrame.Position).Magnitude > FX_RANGE then
		return
	end
	local _, size = model:GetBoundingBox()
	local ground = Vector3.new(root.Position.X, root.Position.Y, root.Position.Z)
	local gold = Color3.fromHex("FFD84A")
	ring(ground + Vector3.new(0, 0.2, 0), gold, 10 + size.X * 1.5, 0.6)
	task.delay(0.12, ring, ground + Vector3.new(0, 0.2, 0), Color3.fromHex("5AD1FF"), 16 + size.X * 2, 0.75)
	burst(ground + Vector3.new(0, size.Y * 0.5, 0), gold, 45, 16, 0.9)
	local level = model:GetAttribute("Level") or 1
	local text = level >= FoodConfig.MaxLevel and "MAX LEVEL!" or ("LEVEL " .. level .. "!")
	popup(root, Vector3.new(0, size.Y + 2, 0), text, gold, 2.2, 2.2)
end

kaijuFolder.ChildAdded:Connect(function(model)
	if model:GetAttribute("LeveledAt") then
		task.spawn(onLeveled, model)
	end
end)

local function coins(pos, price)
	local gold = Color3.fromHex("FFD23F")
	for _ = 1, reduced and 4 or 14 do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.15, 0.7, 0.7)
		c.Color = gold
		c.Material = Enum.Material.Neon
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 1 + rng:NextNumber(0, 1), rng:NextNumber(-1, 1)))
		c.Parent = fxFolder
		local a = rng:NextNumber(0, math.pi * 2)
		c.AssemblyLinearVelocity = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, 9) + Vector3.new(0, rng:NextNumber(20, 30), 0)
		c.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
		task.delay(1.0, function()
			if c.Parent then
				TweenService:Create(c, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(c, 1.5)
	end
	burst(pos + Vector3.new(0, 1.5, 0), gold, 30, 12, 0.7)
	popup(pos, Vector3.new(0, 3, 0), "+" .. Format.Money(price), Color3.fromHex("6BE04A"), 1.8, 1.6)
end

-- ---------- store perks: lucky and gifted eggs ----------

local function findEgg(itemId)
	local t0 = os.clock()
	while os.clock() - t0 < 4 do
		for _, m in eggFolder:GetChildren() do
			if m:GetAttribute("ItemId") == itemId and m.PrimaryPart then
				return m
			end
		end
		task.wait(0.1)
	end
	return nil
end

local function rarityColor(id)
	local r = EggConfig.RarityById[id or ""]
	return r and r.Color or Color3.new(1, 1, 1)
end

local function lightPillar(ground, color, width, height, duration)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(height, width, width)
	p.CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(height, 0.1, 0.1), Transparency = 1 }):Play()
	Debris:AddItem(p, duration + 0.1)
end

-- Egg luck upgraded an egg as it landed in the pen.
local function onEggLucky(data)
	local egg = findEgg(data.ItemId)
	if not egg then
		return
	end
	task.wait(0.55) -- KaijuFX's toss arc lands first
	local shell = egg.PrimaryPart
	if not (egg.Parent and shell) then
		return
	end
	local h = shell.Size.Y
	local ground = shell.Position - Vector3.new(0, h / 2 - 0.15, 0)
	local gold = Color3.fromHex("FFD84A")
	local color = rarityColor(data.ToRarity)
	ring(ground, gold, 8 + h * 2, 0.6)
	task.delay(0.12, ring, ground, color, 12 + h * 3, 0.75)
	burst(shell.Position, gold, 40, 14, 0.8)
	burst(shell.Position, color, 30, 10, 0.6)
	popup(shell, Vector3.new(0, h / 2 + 4.2, 0), "LUCKY!", gold, 3, 3)
	local detail
	if data.ToRarity ~= data.FromRarity then
		detail = string.upper(tostring(data.FromRarity)) .. " > " .. string.upper(tostring(data.ToRarity))
	else
		detail = string.format("SIZE %.2fx > %.2fx", tonumber(data.FromSize) or 1, tonumber(data.ToSize) or 1)
	end
	task.delay(0.2, popup, shell, Vector3.new(0, h / 2 + 1.8, 0), detail, color, 1.9, 3)
end

-- A store egg (HatchService:GiveEgg) fell into the pen.
local function onEggGiven(data)
	local egg = findEgg(data.ItemId)
	if not egg then
		return
	end
	task.wait(0.5) -- KaijuFX drops it from the sky first
	local shell = egg.PrimaryPart
	if not (egg.Parent and shell) then
		return
	end
	local h = shell.Size.Y
	local ground = shell.Position - Vector3.new(0, h / 2 - 0.15, 0)
	local color = rarityColor(data.Rarity)
	lightPillar(ground, color, h * 1.3, 60, 2.4)
	ring(ground, color, 10 + h * 2, 0.6)
	task.delay(0.12, ring, ground, Color3.new(1, 1, 1), 16 + h * 3, 0.75)
	burst(shell.Position, color, 50, 16, 0.9)
	popup(shell, Vector3.new(0, h / 2 + 3.6, 0), "BONUS EGG!", Color3.fromHex("FFD84A"), 3.2, 3.2)
end

-- Gameplay moments (their toasts are the UI's NotificationsController).
local function onEvent(kind, data)
	data = type(data) == "table" and data or {}
	if kind == "KaijuFed" then
		onFed(data)
	elseif kind == "KaijuSold" then
		if data.Position and (data.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < FX_RANGE then
			coins(data.Position, data.Price or 0)
		end
	elseif kind == "EggLucky" then
		task.spawn(onEggLucky, data)
	elseif kind == "EggGiven" then
		task.spawn(onEggGiven, data)
	elseif kind == "FoodBought" then
		local food = FoodConfig.ById[data.FoodId or ""]
		if food then
			local stall = market:FindFirstChild("FoodStall")
			local item = stall and stall:FindFirstChild("Items") and stall.Items:FindFirstChild(food.Id)
			if item and item.PrimaryPart then
				burst(item.PrimaryPart.Position + Vector3.new(0, 0.6, 0), food.Color, 14, 6, 0.4)
			end
		end
	end
end
gameEvent.OnClientEvent:Connect(onEvent)

-- ---------- per-frame motion ----------

local padTimer = 0
local MARKET_CENTER = Vector3.new(-32, 0, 0) -- spawn plaza (MapConfig.SpawnPlaza)
RunService.RenderStepped:Connect(function(dt)
	padTimer += dt
	if padTimer >= 0.15 then
		padTimer = 0
		checkPads()
	end
	local t = os.clock()
	if (workspace.CurrentCamera.CFrame.Position - MARKET_CENTER).Magnitude > 220 then
		return
	end
	for _, entry in pads do
		if entry.ring then
			entry.ring.Transparency = 0.05 + (math.sin(t * 3 + entry.seed) + 1) * 0.15
		end
	end
	for _, f in foodItems do
		if f.model.Parent then
			f.model:PivotTo(f.base * CFrame.new(0, 0.08 + math.sin(t * 2 + f.seed) * 0.08, 0) * CFrame.Angles(0, math.sin(t * 0.9 + f.seed) * 0.35, 0))
		end
	end
	if wheelCenter then
		local n = #orbs
		for _, o in orbs do
			local a = t * 1.1 + (o.index - 1) / math.max(n, 1) * math.pi * 2
			o.part.CFrame = wheelCenter.CFrame * CFrame.Angles(0, 0, a) * CFrame.new(2.3, 0, -0.35)
		end
	end
end)
