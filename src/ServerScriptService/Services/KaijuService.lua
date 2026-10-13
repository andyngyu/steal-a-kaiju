-- Kaiju living in pens: spawns display models and decides where they wander. The server only sets the route
-- (attributes); clients animate it smoothly (StarterPlayerScripts.Gameplay.KaijuFX), so the server never moves the model.
-- Kaiju model attributes: OwnerUserId, KaijuId, Species, Rarity, Size, SizeTier, VisualScale, Level, XP, XPToNext,
--   CashPerSecond (see Shared.Util.KaijuStats), SpawnedAt (server time, only when it just hatched),
--   LeveledAt (server time, the model was rebuilt bigger after a level-up),
--   WanderFrom, WanderTo (Vector3, ground level), MoveStart, MoveEnd (workspace:GetServerTimeNow() seconds).
-- Current logical position = WanderFrom:Lerp(WanderTo, progress) - use KaijuService:GetPosition for gameplay checks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseConfig = require(ReplicatedStorage.Shared.Config.BaseConfig)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)
local GoldVariant = require(ReplicatedStorage.Shared.Util.GoldVariant)
local MutationVisuals = require(ReplicatedStorage.Shared.Util.MutationVisuals)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local KaijuModel = require(game:GetService("ServerScriptService").Lib.KaijuModel)

local BaseService = require(script.Parent.BaseService)

local KaijuService = {}

local rng = Random.new()
local folder
local wanderers = {} -- [model] = { player, nextAt, inset, speed }

function KaijuService:Init()
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	folder = runtime:FindFirstChild("Kaiju") or Instance.new("Folder")
	folder.Name = "Kaiju"
	folder.Parent = runtime
end

-- yaw (optional) keeps the facing of a model being replaced; otherwise it faces a random way.
-- attrs (optional) are set on the model before it is parented, so clients see them on arrival.
function KaijuService:Spawn(player, id, entry, position, justHatched, yaw, attrs)
	local W = BaseConfig.Wander
	local size = entry.Size or 1
	local model = KaijuModel.Build(entry.Species, size, entry.Level, entry.XP)
	local scale = model:GetAttribute("VisualScale") or 1
	local _, ext = model:GetBoundingBox()
	-- Big kaiju keep their body inside the fence (tails may overlap a little) and take longer strides.
	local inset = math.max(W.Inset, math.max(ext.X, ext.Z) * 0.4 + 1)
	local now = workspace:GetServerTimeNow()
	local ground = BaseService:ClampToPen(player, position, inset)
	ground = Vector3.new(ground.X, 0, ground.Z)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, yaw or rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("KaijuId", id)
	model:SetAttribute("CashPerSecond", KaijuStats.EntryCashPerSecond(entry))
	if entry.Variant == "Golden" then
		-- a unique reward kaiju (GroupRewardService): gold bricks, its own name and income on the name plate,
		-- and attribute Unique (StealService gives it no steal prompt, MarketService won't sell it)
		GoldVariant.Apply(model)
		model:SetAttribute("Variant", entry.Variant)
		model:SetAttribute("Unique", true)
		local plate = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
		if plate then
			local title, rarity, cash = plate:FindFirstChild("Title"), plate:FindFirstChild("Rarity"), plate:FindFirstChild("Cash")
			if title then
				title.Text = "Golden " .. title.Text
				-- gold name (a gradient of its own, so the client's rarity tint leaves it alone)
				title.TextColor3 = Color3.new(1, 1, 1)
				local g = Instance.new("UIGradient")
				g.Rotation = 90
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("FFF6B0")),
					ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFD23F")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("E89A00")),
				})
				g.Parent = title
			end
			if rarity then
				rarity.Text = "Unique"
				rarity.TextColor3 = Color3.fromRGB(255, 210, 63)
			end
			if cash then
				cash.Text = Format.PerSecond(KaijuStats.EntryCashPerSecond(entry))
			end
		end
	end
	if entry.Mutation and MutationConfig.ById[entry.Mutation] then
		-- a weather mutation (WeatherService): recoloured, glowing, named on the plate ("Shocked Rumblerex"), income x mult
		model:SetAttribute("Mutation", entry.Mutation)
		MutationVisuals.Recolor(model, entry.Mutation)
		MutationVisuals.AddFX(model, entry.Mutation, scale)
		local plate = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
		local title = plate and plate:FindFirstChild("Title")
		if title then
			-- "<Shocked> <Rumblerex>": the mutation word in its colour, the species name in its rarity colour (or gold for
			-- the Golden reward kaiju). Clients leave coloured rich text untinted (WorldTextController).
			local r = EggConfig.RarityById[model:GetAttribute("Rarity") or ""]
			local nameColor = entry.Variant == "Golden" and "#FFD23F" or (r and ("#" .. r.Color:ToHex()) or "#FFFFFF")
			local g = title:FindFirstChildOfClass("UIGradient")
			if g then
				g:Destroy()
			end
			title.RichText = true
			title.TextColor3 = Color3.new(1, 1, 1)
			title.Text = MutationVisuals.RichName(entry.Mutation, string.format('<font color="%s">%s</font>', nameColor, title.Text))
		end
		local cash = plate and plate:FindFirstChild("Cash")
		if cash then
			cash.Text = Format.PerSecond(KaijuStats.EntryCashPerSecond(entry))
		end
	end
	model:SetAttribute("WanderFrom", ground)
	model:SetAttribute("WanderTo", ground)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveEnd", now)
	if justHatched then
		model:SetAttribute("SpawnedAt", now)
	end
	for key, value in attrs or {} do
		model:SetAttribute(key, value)
	end
	model.Parent = folder
	wanderers[model] = {
		player = player,
		nextAt = now + (justHatched and 3.5 or rng:NextNumber(0.5, 3)),
		inset = inset,
		speed = W.Speed * math.min(math.sqrt(scale), W.MaxSpeedScale),
	}
	model.Destroying:Connect(function()
		wanderers[model] = nil
	end)
	return model
end

-- Rebuilds a kaiju's model where it currently stands (after a level-up it gets bigger and earns more).
-- The old model is destroyed by BaseService:SetItem. Returns the new model.
function KaijuService:Refresh(player, id, entry)
	local _, old = BaseService:GetItem(player, id)
	local position, yaw
	if old then
		position = self:GetPosition(old)
		local from, to = old:GetAttribute("WanderFrom"), old:GetAttribute("WanderTo")
		local dir = from and to and (to - from) or Vector3.zero
		if dir.Magnitude > 0.05 then
			yaw = math.atan2(-dir.X, -dir.Z)
		else
			local _, y = old:GetPivot():ToEulerAnglesYXZ()
			yaw = y
		end
	else
		position = BaseService:RandomSpot(player, BaseConfig.Wander.Inset)
	end
	local model = self:Spawn(player, id, entry, position, false, yaw, { LeveledAt = workspace:GetServerTimeNow() })
	BaseService:SetItem(player, id, model, entry)
	return model
end

function KaijuService:GetPosition(model)
	local from, to = model:GetAttribute("WanderFrom"), model:GetAttribute("WanderTo")
	local s, e = model:GetAttribute("MoveStart"), model:GetAttribute("MoveEnd")
	local now = workspace:GetServerTimeNow()
	if not (from and to and s and e) or e <= s then
		return to or model:GetPivot().Position
	end
	return from:Lerp(to, math.clamp((now - s) / (e - s), 0, 1))
end

-- Holds a kaiju still where it stands for `seconds` (StealService: someone is trying to grab it). It wanders again
-- afterwards, or soon after Resume.
function KaijuService:Pause(model, seconds)
	local w = wanderers[model]
	if not w then
		return
	end
	local now = workspace:GetServerTimeNow()
	local here = self:GetPosition(model)
	here = Vector3.new(here.X, 0, here.Z)
	model:SetAttribute("WanderFrom", here)
	model:SetAttribute("WanderTo", here)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveEnd", now)
	w.nextAt = now + seconds
end

function KaijuService:Resume(model)
	local w = wanderers[model]
	if w then
		w.nextAt = math.min(w.nextAt, workspace:GetServerTimeNow() + 0.5)
	end
end

function KaijuService:Start()
	local W = BaseConfig.Wander
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = workspace:GetServerTimeNow()
		for model, w in wanderers do
			if now < w.nextAt then
				continue
			end
			if not (model.Parent and BaseService:GetPlot(w.player)) then
				wanderers[model] = nil
				continue
			end
			local from = model:GetAttribute("WanderTo")
			local to = BaseService:RandomSpot(w.player, w.inset, from, W.MaxLeg * math.max(1, w.speed / W.Speed))
			to = Vector3.new(to.X, 0, to.Z)
			local duration = (to - from).Magnitude / w.speed
			model:SetAttribute("WanderFrom", from)
			model:SetAttribute("WanderTo", to)
			model:SetAttribute("MoveStart", now)
			model:SetAttribute("MoveEnd", now + duration)
			w.nextAt = now + duration + rng:NextNumber(W.MinPause, W.MaxPause)
		end
	end)
end

return KaijuService
