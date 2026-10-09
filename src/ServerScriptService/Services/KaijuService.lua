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
