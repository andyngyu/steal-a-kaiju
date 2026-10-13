-- Character trails (Shared.Config.TrailConfig): bought with cash, equipped one at a time, multiply the Speed earned on the treadmill.
--   Remotes.BuyTrail (trailId): buys and equips it. Remotes.EquipTrail (trailId, or "" to take it off).
--   Used by the UI's POWERS / Trail Shop panel; the Trails stall in the Kaiju Market opens that panel.
--   Free trails (Price 0) are owned by everyone; new players start with the first free one equipped.
--   Robux trails (ProductId > 0) are granted by GamePassService's receipt handler through TrailService:Grant.
-- Player attributes: OwnedTrails ("PebbleDust,JungleLeaf"), EquippedTrail (trailId or "").
-- The equipped trail is a Trail between two attachments on the HumanoidRootPart (+ sparkles for Legendary and up).
-- GameEvent: TrailBought {Id}, TrailEquipped {Id}, NotEnoughCash {Cost}.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local TrailConfig = require(Config.TrailConfig)
local EggConfig = require(Config.EggConfig)
local DevConfig = require(Config.DevConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SpeedService = require(script.Parent.SpeedService)

local TrailService = {}

local NONE = "none" -- data.Trails.Equipped when the player took their trail off ("" = never chose one)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local gameEvent
local lastAction = {}

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Trail]", ...)
	end
end

local function isFree(trail)
	return (trail.Price or 0) <= 0 and (trail.RobuxPrice or 0) <= 0
end

local function owns(data, trail)
	return isFree(trail) or data.Trails.Owned[trail.Id] == true
end

local function equippedId(data)
	local id = data.Trails.Equipped
	return TrailConfig.ById[id] and id or ""
end

local function sequence(colors)
	local points = {}
	for i, hex in colors do
		table.insert(points, ColorSequenceKeypoint.new(#colors == 1 and 0 or (i - 1) / (#colors - 1), Color3.fromHex(hex)))
	end
	if #points == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, points[1].Value))
	end
	return ColorSequence.new(points)
end

-- Puts the equipped trail on the character (or removes it).
local function apply(player)
	local data = DataService:Get(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (data and hrp) then
		return
	end
	for _, name in { "KaijuTrail", "KaijuTrailTop", "KaijuTrailBottom", "KaijuTrailSparkles" } do
		local old = hrp:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local trail = TrailConfig.ById[equippedId(data)]
	if not trail then
		return
	end
	local w = trail.Width
	local top = Instance.new("Attachment")
	top.Name = "KaijuTrailTop"
	top.Position = Vector3.new(0, 0.3 + 0.35 * w, 0.4)
	top.Parent = hrp
	local bottom = Instance.new("Attachment")
	bottom.Name = "KaijuTrailBottom"
	bottom.Position = Vector3.new(0, -1.1 - 0.35 * w, 0.4)
	bottom.Parent = hrp
	local t = Instance.new("Trail")
	t.Name = "KaijuTrail"
	t.Attachment0 = top
	t.Attachment1 = bottom
	t.Color = sequence(trail.Colors)
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new(1, 0.35)
	t.Lifetime = trail.Lifetime
	t.LightEmission = trail.LightEmission
	t.FaceCamera = true
	t.MinLength = 0.05
	t.Parent = hrp
	local rarity = EggConfig.RarityById[trail.Rarity]
	if rarity and rarity.Order >= 5 then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "KaijuTrailSparkles"
		pe.Texture = SPARKLE
		pe.Color = t.Color
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.1, 1)
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rate = 14
		pe.Parent = bottom
	end
end

local function publish(player, data)
	local list = {}
	for _, trail in TrailConfig.List do
		if owns(data, trail) then
			table.insert(list, trail.Id)
		end
	end
	player:SetAttribute("OwnedTrails", table.concat(list, ","))
	player:SetAttribute("EquippedTrail", equippedId(data))
end

local function spamGuard(player)
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.3 then
		return false
	end
	lastAction[player] = now
	return true
end

function TrailService:Equip(player, trailId)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	if trailId == "" or trailId == NONE then
		data.Trails.Equipped = NONE
	else
		local trail = TrailConfig.ById[trailId]
		if not (trail and owns(data, trail)) then
			return false
		end
		data.Trails.Equipped = trail.Id
	end
	publish(player, data)
	apply(player)
	SpeedService:Refresh(player)
	DataService:Save(player)
	gameEvent:FireClient(player, "TrailEquipped", { Id = equippedId(data) })
	return true
end

function TrailService:Buy(player, trailId)
	local data = DataService:Get(player)
	local trail = TrailConfig.ById[trailId]
	if not (data and trail) then
		return false
	end
	if owns(data, trail) then
		return self:Equip(player, trail.Id)
	end
	if (trail.Price or 0) <= 0 then
		return false -- Robux-only trail
	end
	if not EconomyService:TrySpend(player, trail.Price) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = trail.Price })
		return false
	end
	data.Trails.Owned[trail.Id] = true
	gameEvent:FireClient(player, "TrailBought", { Id = trail.Id })
	log(player.Name, "bought trail", trail.Id)
	return self:Equip(player, trail.Id)
end

-- Gives a trail for free (Robux purchase): owned + equipped + TrailBought. True if the player has it afterwards (also
-- when they already did); false for an unknown trail or when their data isn't loaded yet.
function TrailService:Grant(player, trailId)
	local data = DataService:Get(player)
	local trail = TrailConfig.ById[trailId]
	if not (data and trail) then
		return false
	end
	if not owns(data, trail) then
		data.Trails.Owned[trail.Id] = true
		gameEvent:FireClient(player, "TrailBought", { Id = trail.Id })
		log(player.Name, "was granted trail", trail.Id)
	end
	self:Equip(player, trail.Id)
	return true
end

function TrailService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	ReplicatedStorage.Remotes:WaitForChild("BuyTrail").OnServerEvent:Connect(function(player, trailId)
		if type(trailId) == "string" and spamGuard(player) then
			self:Buy(player, trailId)
		end
	end)
	ReplicatedStorage.Remotes:WaitForChild("EquipTrail").OnServerEvent:Connect(function(player, trailId)
		if (trailId == nil or type(trailId) == "string") and spamGuard(player) then
			self:Equip(player, trailId or "")
		end
	end)
end

function TrailService:Start()
	local function onCharacter(player)
		local char = player.Character
		if char then
			char:WaitForChild("HumanoidRootPart", 10)
			apply(player)
		end
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	DataService:OnLoaded(function(player, data)
		-- drop unknown trails; new players start wearing the first free trail
		for id in data.Trails.Owned do
			if not TrailConfig.ById[id] then
				data.Trails.Owned[id] = nil
			end
		end
		if data.Trails.Equipped == "" then
			for _, trail in TrailConfig.List do
				if isFree(trail) then
					data.Trails.Equipped = trail.Id
					break
				end
			end
		end
		publish(player, data)
		SpeedService:Refresh(player)
		onCharacter(player)
	end)
end

return TrailService
