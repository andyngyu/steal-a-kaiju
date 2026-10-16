-- Player stealing and base defense, client side (rules in Services.StealService, numbers in StealConfig):
--   steal prompts: the StealPrompt on every pen egg / kaiju shows only on other players' items, and only while their
--                  base isn't locked or protected, the item isn't hatching, freshly hatched or being stolen by someone
--                  else, and you aren't carrying anything. Holding it sends Remotes.Steal (ownerUserId, itemId,
--                  "Begin"), letting go early sends (.., "Cancel"), finishing sends (ownerUserId, itemId); the hold
--                  time grows with the item's rarity, size and level (StealConfig.HoldTime, set on the prompt).
--                  Each prompt sits on the edge of its item nearest you, at your height (attributes StealRadius /
--                  StealBottom / StealHeight from StealService), so a big kaiju is as easy to reach as an egg.
--                  While you hold one: every other prompt is switched off (nothing walking past can take the
--                  focus), the kaiju stops walking at once (locally, until the server's Pause lands), and the
--                  prompt's range grows by HoldReachSlack. A refused or stopped steal ends the hold at once
--   steal bars:    an item someone is holding a steal on (attributes StealBy / StealStart / StealSeconds) shows a red
--                  "STEALING!" bar filling up over it, for everyone
--   thieves:       anyone holding a steal (attribute Stealing) or carrying stolen goods (CarryingStolen) gets a red
--                  "STEALING!" / "THIEF!" tag (stop them with the bat: Services.BatService / Gameplay.BatFX; the old
--                  Tackle prompt is gone). Carried things are held up by Gameplay.CarryPose
--   base lock:     a locked pen is wrapped in a red force field; each pen's LockButton shows LOCK READY / LOCKED 0:42 /
--                  LOCK IN 1:05 / PROTECTED 0:30 to its owner (others only see LOCKED / PROTECTED), and its prompt is
--                  the owner's only
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StealConfig = require(Config:WaitForChild("StealConfig"))
local PenGeometry = require(ReplicatedStorage.Shared:WaitForChild("Util"):WaitForChild("PenGeometry"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stealRemote = remotes:WaitForChild("Steal")
local gameEvent = remotes:WaitForChild("GameEvent")

local player = Players.LocalPlayer
local runtime = workspace:WaitForChild("Runtime")
local kaijuFolder = runtime:WaitForChild("Kaiju")
local eggFolder = runtime:WaitForChild("Eggs")
local plotsFolder = workspace:WaitForChild("Map"):WaitForChild("Plots")

local RED = Color3.fromHex("FF3B3B")
local INK = Color3.fromHex("1A1033")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "StealFXLocal"
fxFolder.Parent = workspace

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function plotOf(userId)
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == userId then
			return plot
		end
	end
	return nil
end

local function closed(plot)
	local now = serverNow()
	return plot ~= nil and ((plot:GetAttribute("LockedUntil") or 0) > now or (plot:GetAttribute("ProtectedUntil") or 0) > now)
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function outlinedLabel(parent, text, color, font, height, order)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order or 1
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = INK
	s.Parent = l
	l.Parent = parent
	return l
end

-- ---------- steal prompts ----------

local stealPrompts = {} -- [prompt] = { ownerId, model }
local allPrompts = {} -- [prompt] = true: every ProximityPrompt in the workspace, so a held steal can quiet the rest
local hold = nil -- the steal being held: { prompt, quiet = { [prompt] = true }, freeze }
local cooldownUntil = 0 -- os.clock(): the server refuses another steal this soon (StealConfig.CooldownSeconds)

local PROMPT_RANGE = StealConfig.Reach - StealConfig.ClientReachMargin
local HOLD_RANGE = PROMPT_RANGE + StealConfig.HoldReachSlack

local function trackPrompt(d)
	if d:IsA("ProximityPrompt") and not allPrompts[d] then
		allPrompts[d] = true
		d.AncestryChanged:Connect(function()
			if not d:IsDescendantOf(workspace) then
				allPrompts[d] = nil
			end
		end)
	end
end
workspace.DescendantAdded:Connect(trackPrompt)
for _, d in workspace:GetDescendants() do
	trackPrompt(d)
end

-- A kaiju stops walking the moment you start holding. Done locally so there's no wait for the server; its Pause lands
-- a moment later with the same spot and replaces this. Returns what to undo if the server never takes the steal.
local function freezeKaiju(model)
	if not model:GetAttribute("KaijuId") then
		return nil
	end
	local from, to = model:GetAttribute("WanderFrom"), model:GetAttribute("WanderTo")
	local s, e = model:GetAttribute("MoveStart"), model:GetAttribute("MoveEnd")
	if not (from and to and s and e) then
		return nil
	end
	local now = serverNow()
	local here = e > s and from:Lerp(to, math.clamp((now - s) / (e - s), 0, 1)) or to
	local f = {
		model = model,
		saved = { WanderFrom = from, WanderTo = to, MoveStart = s, MoveEnd = e },
		set = { WanderFrom = here, WanderTo = here, MoveStart = now, MoveEnd = now },
	}
	for k, v in f.set do
		model:SetAttribute(k, v)
	end
	return f
end

local function unfreezeKaiju(f)
	if not (f and f.model.Parent) then
		return
	end
	for k, v in f.set do
		if f.model:GetAttribute(k) ~= v then
			return -- the server has spoken since (Pause or a new route): its values stand
		end
	end
	for k, v in f.saved do
		f.model:SetAttribute(k, v) -- the server never took the steal: back on its real route
	end
end

-- Every other prompt off while a steal is held, so a kaiju or player wandering closer can't steal the focus
-- (Roblox shows only the nearest prompt per key and drops a hold when focus moves).
local function quietOthers()
	for p in allPrompts do
		if p ~= hold.prompt and p.Enabled then
			hold.quiet[p] = true
			p.Enabled = false
		end
	end
end

-- endIt: also stop the hold on screen (the server refused or stopped it).
local function releaseHold(endIt)
	local h = hold
	if not h then
		return
	end
	hold = nil
	for p in h.quiet do
		if p.Parent then
			p.Enabled = true -- steal prompts are re-checked by the 0.2 s pass below
		end
	end
	unfreezeKaiju(h.freeze)
	if endIt and h.prompt.Parent then
		h.prompt.Enabled = false -- the 0.2 s pass turns it back on when it can be used
	end
end

gameEvent.OnClientEvent:Connect(function(name)
	if name == "StealStarted" then
		cooldownUntil = os.clock() + StealConfig.CooldownSeconds
	elseif (name == "StealDenied" or name == "StealCancelled") and hold then
		releaseHold(true)
	end
end)

-- Keeps each nearby steal prompt on its item's edge nearest you (the same footprint the server measures reach from),
-- at your own height within the item's height: big kaiju no longer put it far overhead, out of range or off screen.
local function placePrompts()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local me = hrp.Position
	for prompt, info in stealPrompts do
		local att = prompt.Parent
		local radius = prompt:GetAttribute("StealRadius")
		if not (radius and att and att:IsA("Attachment")) then
			continue
		end
		local centre
		if prompt:GetAttribute("StealKaiju") then
			centre = info.model:GetPivot().Position
		else
			local pp = info.model.PrimaryPart
			if not pp then
				continue
			end
			centre = pp.Position
		end
		local flat = Vector3.new(me.X - centre.X, 0, me.Z - centre.Z)
		local d = flat.Magnitude
		if d > radius + HOLD_RANGE + 20 then
			continue
		end
		local edge = d > 0.01 and flat * (math.min(d, radius) / d) or Vector3.zero -- standing under it: right where you are
		local bottom = centre.Y + (prompt:GetAttribute("StealBottom") or 0)
		local height = prompt:GetAttribute("StealHeight") or 0
		local y = math.clamp(me.Y, bottom + 0.5, bottom + math.max(height - 0.5, 0.5))
		att.WorldPosition = Vector3.new(centre.X + edge.X, y, centre.Z + edge.Z)
		prompt.MaxActivationDistance = (hold and hold.prompt == prompt) and HOLD_RANGE or PROMPT_RANGE
	end
end

-- The pen item (a direct child of Runtime.Kaiju / Runtime.Eggs) a prompt belongs to.
local function ownerAndId(prompt)
	local model = prompt
	while model and model.Parent ~= kaijuFolder and model.Parent ~= eggFolder do
		model = model.Parent
	end
	if not (model and model:IsA("Model")) then
		return nil
	end
	return model:GetAttribute("OwnerUserId"), model:GetAttribute("KaijuId") or model:GetAttribute("ItemId"), model
end

local function addStealPrompt(prompt)
	if not (prompt:IsA("ProximityPrompt") and prompt.Name == "StealPrompt") then
		return
	end
	local ownerId, id, model = ownerAndId(prompt)
	if not (ownerId and id) then
		return
	end
	if ownerId == player.UserId then
		prompt.MaxActivationDistance = 0 -- never on your own things
		return
	end
	stealPrompts[prompt] = { ownerId = ownerId, model = model }
	local done = false
	prompt.PromptButtonHoldBegan:Connect(function()
		done = false
		releaseHold(false)
		hold = { prompt = prompt, quiet = {}, freeze = freezeKaiju(model) }
		quietOthers()
		prompt.MaxActivationDistance = HOLD_RANGE
		stealRemote:FireServer(ownerId, id, "Begin")
	end)
	prompt.Triggered:Connect(function()
		done = true
		if hold and hold.prompt == prompt then
			releaseHold(false)
		end
		stealRemote:FireServer(ownerId, id)
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		task.defer(function()
			if not done then
				stealRemote:FireServer(ownerId, id, "Cancel")
			end
			if hold and hold.prompt == prompt then
				releaseHold(false)
			end
		end)
	end)
	prompt.Destroying:Connect(function()
		stealPrompts[prompt] = nil
		if hold and hold.prompt == prompt then
			releaseHold(false)
		end
	end)
end

for _, folder in { kaijuFolder, eggFolder } do
	folder.DescendantAdded:Connect(addStealPrompt)
	for _, d in folder:GetDescendants() do
		addStealPrompt(d)
	end
end

-- ---------- steal bars ----------

local bars = {} -- [model] = { gui, fill }

local function removeBar(model)
	local b = bars[model]
	bars[model] = nil
	if b then
		b.gui:Destroy()
	end
end

local function refreshBar(model)
	if not model:GetAttribute("StealBy") then
		removeBar(model)
		return
	end
	if bars[model] or not model.PrimaryPart then
		return
	end
	local _, ext = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "StealBar"
	gui.Size = UDim2.fromOffset(190, 58)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ext.Y * 0.5 + 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	outlinedLabel(gui, "STEALING!", RED, Enum.Font.LuckiestGuy, 0.58, 1)
	local back = Instance.new("Frame")
	back.LayoutOrder = 2
	back.Size = UDim2.fromScale(0.9, 0.28)
	back.BackgroundColor3 = INK
	back.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	corner:Clone().Parent = fill
	fill.Parent = back
	back.Parent = gui
	gui.Parent = model.PrimaryPart
	bars[model] = { gui = gui, fill = fill }
end

local function watchItem(model)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("StealBy"):Connect(function()
		refreshBar(model)
	end)
	model.Destroying:Connect(function()
		bars[model] = nil
	end)
	refreshBar(model)
end

for _, folder in { kaijuFolder, eggFolder } do
	folder.ChildAdded:Connect(watchItem)
	for _, m in folder:GetChildren() do
		watchItem(m)
	end
end

-- ---------- thieves ----------

local thieves = {} -- [player] = { tag }

local function untrack(other)
	local t = thieves[other]
	thieves[other] = nil
	if t then
		for _, inst in t do
			inst:Destroy()
		end
	end
end

local function track(other)
	untrack(other)
	local carried = other:GetAttribute("CarryingStolen")
	local item = carried or other:GetAttribute("Stealing")
	local char = other.Character
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (item and head and hrp) then
		return
	end
	local t = {}
	local tag = Instance.new("BillboardGui")
	tag.Name = "ThiefTag"
	tag.Size = UDim2.fromOffset(220, 56)
	tag.StudsOffsetWorldSpace = Vector3.new(0, carried and 7.5 or 3.5, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 200
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = tag
	outlinedLabel(tag, carried and "THIEF!" or "STEALING!", RED, Enum.Font.LuckiestGuy, 0.6, 1)
	outlinedLabel(tag, item, Color3.new(1, 1, 1), Enum.Font.FredokaOne, 0.4, 2)
	tag.Parent = head
	table.insert(t, tag)
	thieves[other] = t
end

local function watchPlayer(other)
	for _, attr in { "CarryingStolen", "Stealing" } do
		other:GetAttributeChangedSignal(attr):Connect(function()
			track(other)
		end)
	end
	other.CharacterAdded:Connect(function()
		task.wait(0.5)
		track(other)
	end)
	track(other)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(untrack)
for _, other in Players:GetPlayers() do
	task.spawn(watchPlayer, other)
end

-- ---------- base lock ----------

local shields = {} -- [plot] = { level, parts }

local function removeShield(plot)
	local s = shields[plot]
	shields[plot] = nil
	if s then
		for _, p in s.parts do
			p:Destroy()
		end
	end
end

-- Red force-field walls with a glowing top rim around the pen at its current level.
local function buildShield(plot)
	removeShield(plot)
	local levelIndex = plot:GetAttribute("PenLevel") or 1
	local level = PenGeometry.Level(levelIndex)
	local frame = PenGeometry.Frame(plot)
	local W, D, H = level.Width, level.Depth, 9
	local parts = {}
	local function piece(name, material, cf, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material
		p.Color = RED
		p.Size = size
		p.CFrame = cf
		p.Parent = fxFolder
		table.insert(parts, p)
	end
	local function wall(x, z, size)
		local cf = frame * CFrame.new(x, H / 2, z)
		piece("LockShield", Enum.Material.ForceField, cf, size)
		piece("LockShieldRim", Enum.Material.Neon, cf * CFrame.new(0, H / 2, 0), Vector3.new(size.X, 0.3, size.Z))
	end
	wall(0, 0, Vector3.new(W, H, 0.4)) -- front (entrance)
	wall(0, -D, Vector3.new(W, H, 0.4))
	wall(-W / 2, -D / 2, Vector3.new(0.4, H, D))
	wall(W / 2, -D / 2, Vector3.new(0.4, H, D))
	shields[plot] = { level = levelIndex, parts = parts }
end

local buttonLabels = {} -- [plot] = TextLabel

local function buttonLabel(plot)
	local label = buttonLabels[plot]
	if label and label.Parent and label.Parent.Parent then
		return label
	end
	local lockButton = plot:FindFirstChild("LockButton")
	local button = lockButton and lockButton:FindFirstChild("Button")
	if not button then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "LockStatus"
	bb.Size = UDim2.fromOffset(200, 44)
	-- sits right on top of the button: its bottom edge just above the button's top
	local up = button.CFrame:VectorToObjectSpace(Vector3.yAxis) -- the button may be rotated (a sideways cylinder)
	local halfHeight = (math.abs(up.X) * button.Size.X + math.abs(up.Y) * button.Size.Y + math.abs(up.Z) * button.Size.Z) / 2
	-- StudsOffsetWorldSpace is measured along the button's own axes; the button is a cylinder lying on its side, so
	-- convert "straight up in the world" into its local space or the label ends up beside the button
	bb.StudsOffsetWorldSpace = button.CFrame:VectorToObjectSpace(Vector3.new(0, halfHeight + 1.1, 0))
	bb.SizeOffset = Vector2.new(0, 0.5) -- centred on the button, bottom edge just above it
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	label = outlinedLabel(bb, "", Color3.new(1, 1, 1), Enum.Font.FredokaOne, 1, 1)
	bb.Parent = button
	buttonLabels[plot] = label
	return label
end

local function updatePlot(plot, now)
	local owner = plot:GetAttribute("OwnerUserId")
	local lockedLeft = (plot:GetAttribute("LockedUntil") or 0) - now
	local cooldownLeft = (plot:GetAttribute("LockCooldownUntil") or 0) - now
	local protectedLeft = (plot:GetAttribute("ProtectedUntil") or 0) - now
	local mine = owner ~= nil and owner == player.UserId
	-- only the owner ever sees their Lock prompt, and only while it can be used (the server checks too)
	local lockButton = plot:FindFirstChild("LockButton")
	local lockPrompt = lockButton and lockButton:FindFirstChild("Button") and lockButton.Button:FindFirstChild("LockPrompt")
	if lockPrompt then
		lockPrompt.Enabled = mine and lockedLeft <= 0 and cooldownLeft <= 0
	end
	if owner and lockedLeft > 0 then
		local s = shields[plot]
		if not s or s.level ~= (plot:GetAttribute("PenLevel") or 1) then
			buildShield(plot)
		end
		local pulse = 0.12 + (math.sin(os.clock() * 3) + 1) * 0.06
		for _, p in shields[plot].parts do
			p.Transparency = p.Name == "LockShieldRim" and pulse * 1.5 or pulse
		end
	elseif shields[plot] then
		removeShield(plot)
	end
	local label = owner and buttonLabel(plot)
	if not label then
		return
	end
	local text, color
	if lockedLeft > 0 then
		text, color = "LOCKED " .. clock(lockedLeft), RED
	elseif protectedLeft > 0 then
		text, color = "PROTECTED " .. clock(protectedLeft), Color3.fromHex("5AD1FF")
	elseif mine and cooldownLeft > 0 then
		text, color = "LOCK IN " .. clock(cooldownLeft), Color3.fromHex("B8C0CC")
	elseif mine then
		text, color = "LOCK READY", Color3.fromHex("6BE04A")
	end
	label.Parent.Enabled = text ~= nil
	if text then
		label.Text = text
		label.TextColor3 = color
	end
end

-- ---------- per frame ----------

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	local now = serverNow()
	placePrompts()
	if hold then
		quietOthers() -- anything that switched itself on since
	end
	for model, b in bars do
		local start, seconds = model:GetAttribute("StealStart"), model:GetAttribute("StealSeconds")
		if start and seconds then
			b.fill.Size = UDim2.fromScale(math.clamp((now - start) / math.max(seconds, 0.1), 0, 1), 1)
		end
	end
	acc += dt
	if acc < 0.2 then
		return
	end
	acc = 0
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("PlotId") then
			updatePlot(plot, now)
		end
	end
	-- no steal prompts on locked or protected bases, on hatching, fresh or contested items, while carrying, during the
	-- server's cooldown after a steal, or (other than the one held) while holding one
	local handsFull = player:GetAttribute("CarryingStolen") ~= nil or player:GetAttribute("CarryingEgg") ~= nil
		or os.clock() < cooldownUntil
	local freshAfter = now - StealConfig.NewHatchProtectionSeconds
	local closedCache = {}
	for prompt, info in stealPrompts do
		local ownerId, model = info.ownerId, info.model
		if closedCache[ownerId] == nil then
			closedCache[ownerId] = closed(plotOf(ownerId))
		end
		local by = model:GetAttribute("StealBy")
		local busy = model:GetAttribute("HatchStartedAt") ~= nil
			or (model:GetAttribute("SpawnedAt") or -math.huge) > freshAfter
			or (by ~= nil and by ~= player.UserId)
		prompt.Enabled = not (handsFull or busy or closedCache[ownerId]) and (hold == nil or hold.prompt == prompt)
	end
end)
