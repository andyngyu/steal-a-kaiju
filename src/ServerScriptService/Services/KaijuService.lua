-- Kaiju living in pens: spawns display models and decides where they wander. The server only sets the route
-- (attributes); clients animate it smoothly (StarterPlayerScripts.Gameplay.KaijuFX), so the server never moves the model.
-- Kaiju model attributes: OwnerUserId, KaijuId, Species, Rarity, Size, SizeTier, VisualScale, CashPerSecond (= species CPS x Size),
--   SpawnedAt (server time, only when it just hatched),
--   WanderFrom, WanderTo (Vector3, ground level), MoveStart, MoveEnd (workspace:GetServerTimeNow() seconds).
-- Current logical position = WanderFrom:Lerp(WanderTo, progress) - use KaijuService:GetPosition for gameplay checks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseConfig = require(ReplicatedStorage.Shared.Config.BaseConfig)
local KaijuConfig = require(ReplicatedStorage.Shared.Config.KaijuConfig)
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

function KaijuService:Spawn(player, id, entry, position, justHatched)
	local W = BaseConfig.Wander
	local size = entry.Size or 1
	local model = KaijuModel.Build(entry.Species, size)
	local scale = model:GetAttribute("VisualScale") or 1
	local _, ext = model:GetBoundingBox()
	-- Big kaiju keep their body inside the fence (tails may overlap a little) and take longer strides.
	local inset = math.max(W.Inset, math.max(ext.X, ext.Z) * 0.4 + 1)
	local now = workspace:GetServerTimeNow()
	local ground = BaseService:ClampToPen(player, position, inset)
	ground = Vector3.new(ground.X, 0, ground.Z)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("KaijuId", id)
	model:SetAttribute("CashPerSecond", KaijuConfig[entry.Species].CashPerSecond * size)
	model:SetAttribute("WanderFrom", ground)
	model:SetAttribute("WanderTo", ground)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveEnd", now)
	if justHatched then
		model:SetAttribute("SpawnedAt", now)
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

function KaijuService:GetPosition(model)
	local from, to = model:GetAttribute("WanderFrom"), model:GetAttribute("WanderTo")
	local s, e = model:GetAttribute("MoveStart"), model:GetAttribute("MoveEnd")
	local now = workspace:GetServerTimeNow()
	if not (from and to and s and e) or e <= s then
		return to or model:GetPivot().Position
	end
	return from:Lerp(to, math.clamp((now - s) / (e - s), 0, 1))
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
