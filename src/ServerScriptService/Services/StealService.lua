-- Player stealing and base defense (numbers in Shared.Config.StealConfig).
--   Stealing: every pen egg and kaiju has a StealPrompt (hold E) that only other players see. Its HoldDuration is
--             StealConfig.HoldTime(rarity, size, level): 2.5 s for a plain Common up to 10 s for a big Secret.
--             Gameplay.StealFX sends Remotes.Steal (ownerUserId, itemId, "Begin") when the hold starts,
--             (ownerUserId, itemId, "Cancel") if it's let go and (ownerUserId, itemId) when it completes. The server
--             times the hold itself (a completion that comes too early is refused) and checks at the start, every
--             0.2 s and at the end that the thief stays inside the owner's pen within reach of the item (kaiju: its
--             logical position), isn't carrying anything or stunned and has room at home, that the base isn't locked
--             or protected, the item isn't hatching, freshly hatched or being stolen by someone else, and the
--             cooldown. The owner is warned the moment a hold starts; a thief holding a steal barely moves
--             (HoldSpeedMultiplier, EggService) and can be bonked with a bat; a kaiju being grabbed stands still and
--             struggles.
--   Carrying: the item stays in the owner's save marked StolenBy (cleared on load) while the thief carries a copy over
--             their head (an egg as itself, a kaiju shrunk to CarriedKaijuHeight; Gameplay.CarryPose holds it up)
--             and runs slower (CarrySpeedMultiplier). It only moves to the thief when they walk into their own pen,
--             so dying, being bonked, leaving or the owner leaving can never duplicate or lose it: the item just goes
--             home. A carrier who covers more ground than their server-side WalkSpeed allows (a teleport or speed
--             hack; SpeedTolerance, SpeedSlackStuds) loses it too.
--   Defense:  every player has a bat (Services.BatService, StealConfig.Bat; it replaced the old Tackle prompt on
--             16 Oct 2026): a hit stops a steal being held or sends carried goods home (CancelSteal / Return with
--             Reason "Bonked"), and the target is ragdolled (Lib.Ragdoll), knocked back and stunned. Owners lock their base with the
--             LockButton in the pen (or Remotes.LockBase) for Lock.Seconds: no steals, other players inside are pushed
--             out; then a cooldown. After a theft the victim's base is protected for ProtectAfterTheftSeconds.
-- Plot attributes: LockedUntil, LockCooldownUntil, ProtectedUntil (server time). Plot child LockButton (Model, Button
--   part with LockPrompt).
-- Player attributes: Stealing (name of the item being held), CarryingStolen (item name), CarryingStolenFrom (owner's
--   display name), StunnedUntil. Character attribute RagdollUntil (Lib.Ragdoll).
-- Item model attributes while a steal is held: StealBy (thief's UserId), StealStart (server time), StealSeconds.
-- GameEvent (item events all carry Kind "Egg" | "Kaiju", Name and Rarity): StealBegan {Thief, Seconds} (owner),
--   StealCancelled {Reason = "Moved" | "Locked" | "Bonked", By} (thief), StealStarted {Owner} / BeingStolen {Thief}
--   (carry begins), StealDelivered {Owner} / Stolen {Thief, ProtectedSeconds}, StealReturned {Reason, By, ByUserId}
--   (thief) / ItemRecovered {Reason, By, ByUserId} (owner) with Reason "Bonked" | "Died" | "Left" | "OwnerLeft" |
--   "TooFast" | "Stopped" (a hold was bonked); StealDenied {Reason = "Busy" | "Locked"
--   | "Protected" | "NotInPen" | "JustHatched" | "TooFar" | "PenFull" | "Contested"}, BaseLocked {Seconds},
--   BaseUnlocked {}, LockDenied {Reason = "Locked" | "Cooldown", Seconds}, PushedOut {Owner}, Intruder {Name}.
-- Studio only: DevConfig.AllowSelfSteal lets a solo tester steal from their own pen (delivered after leaving and coming
--   back in); StealForTesting(thief, owner, id) holds and completes a steal; ReturnForTesting(player) and
--   RagdollForTesting(player) stand in for a bat hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage.Shared.Config
local StealConfig = require(Config.StealConfig)
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local MapConfig = require(Config.MapConfig)
local DevConfig = require(Config.DevConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local EggModel = require(ServerScriptService.Lib.EggModel)
local KaijuModel = require(ServerScriptService.Lib.KaijuModel)
local MutationVisuals = require(ReplicatedStorage.Shared.Util.MutationVisuals)
local Ragdoll = require(ServerScriptService.Lib.Ragdoll)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local KaijuService = require(script.Parent.KaijuService)
local HatchService = require(script.Parent.HatchService)
local EconomyService = require(script.Parent.EconomyService)
local IndexService = require(script.Parent.IndexService)

local StealService = {}

local gameEvent
local holding = {} -- [thief] = { owner, id, kind, name, rarity, model, need, startedAt }
local carrying = {} -- [thief] = { owner, id, kind, name, rarity, model, startedAt, lastPos, travelled, topSpeed, leftHome }
local lastSteal, lastPush = {}, {}
local lastAlert = {} -- [owner] = { [intruder] = os.clock() }

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Steal]", ...)
	end
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function itemName(entry)
	if entry.Kind == "Kaiju" then
		local cfg = KaijuConfig[entry.Species]
		return cfg and cfg.DisplayName or entry.Species
	end
	local tier = EggConfig.SizeTierName(entry.Size or 1)
	return (tier ~= "" and tier .. " " or "") .. (entry.Rarity or "Common") .. " Egg"
end

local function hrpOf(player)
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then
		return hrp
	end
	return nil
end

-- Inside `owner`'s pen, `margin` studs of slack past the fence.
local function inPen(owner, position, margin)
	local plot = BaseService:GetPlot(owner)
	if not plot then
		return false
	end
	local x, d = PenGeometry.ToLocal(plot, position)
	return PenGeometry.Contains(BaseService:GetLevel(owner), x, d, -(margin or 0))
end

local function plotUntil(owner, attr)
	local plot = BaseService:GetPlot(owner)
	return plot and plot:GetAttribute(attr) or 0
end

local function isLocked(owner)
	return plotUntil(owner, "LockedUntil") > serverNow()
end

local function knockback(hrp, fromPos, strength)
	local flat = Vector3.new(hrp.Position.X - fromPos.X, 0, hrp.Position.Z - fromPos.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or -Vector3.xAxis
	local att = hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChildOfClass("Attachment")
	if not att then
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = dir * strength + Vector3.new(0, strength * 0.45, 0)
	lv.Parent = hrp
	Debris:AddItem(lv, 0.18)
end

-- ---------- what the thief carries ----------

local function unanchor(model, weldTo)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			if weldTo and p ~= weldTo then
				local w = Instance.new("WeldConstraint")
				w.Part0 = weldTo
				w.Part1 = p
				w.Parent = p
			end
		end
	end
end

-- A copy of the pen egg, carried like a nest egg (Gameplay.CarryPose bobs a character's "Egg" by its CarryWeld).
local function carryEgg(entry, id, hrp)
	local egg = EggModel.Build(entry.BiomeId, entry.Rarity, id, entry.Size)
	EggModel.SetMutation(egg, entry.Mutation)
	egg.Name = "Egg"
	egg:SetAttribute("State", "Stolen")
	local prompt = egg.PrimaryPart:FindFirstChild("Prompt")
	if prompt then
		prompt:Destroy()
	end
	EggModel.SetPhysics(egg, false)
	local offset = EggModel.CarryOffset(egg)
	egg:SetAttribute("CarryOffset", offset)
	egg:PivotTo(hrp.CFrame * CFrame.new(0, offset, 0))
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = egg.PrimaryPart
	weld.C0 = CFrame.new(0, offset, 0)
	weld.Parent = egg.PrimaryPart
	return egg
end

-- The kaiju shrunk to about CarriedKaijuHeight, held over the head (Gameplay.CarryPose bobs it by its CarryWeld).
local function carryKaiju(entry, hrp)
	local m = KaijuModel.Build(entry.Species, entry.Size or 1, entry.Level, entry.XP)
	m.Name = "StolenKaiju"
	if entry.Mutation then
		MutationVisuals.Recolor(m, entry.Mutation)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * math.min(1, StealConfig.CarriedKaijuHeight / math.max(size.Y, 0.1)))
	local root = m.PrimaryPart
	local rootOffset = m:GetPivot():ToObjectSpace(root.CFrame)
	unanchor(m, root)
	local lift = EggConfig.Carry.HeadClearance + 0.3
	m:SetAttribute("CarryOffset", lift)
	m:PivotTo(hrp.CFrame * CFrame.new(0, lift, 0))
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = root
	weld.C0 = CFrame.new(0, lift, 0) * rootOffset
	weld.Parent = root
	return m
end

-- ---------- carrying state ----------

local function clearCarry(thief)
	local c = carrying[thief]
	carrying[thief] = nil
	if c and c.model then
		c.model:Destroy()
	end
	if thief.Parent then
		thief:SetAttribute("CarryingStolen", nil)
		thief:SetAttribute("CarryingStolenFrom", nil)
	end
	return c
end

-- The item goes back to its owner's pen. reason: "Bonked" | "Died" | "Left" | "OwnerLeft" | "TooFast".
function StealService:Return(thief, reason, by)
	local c = clearCarry(thief)
	if not c then
		return false
	end
	local owner = c.owner
	local entry = owner.Parent == Players and BaseService:GetItem(owner, c.id)
	if entry and entry.StolenBy == thief.UserId then
		entry.StolenBy = nil
		HatchService:SpawnItem(owner, c.id, entry)
		EconomyService:Publish(owner)
		gameEvent:FireClient(owner, "ItemRecovered", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Reason = reason, By = by and by.DisplayName, ByUserId = by and by.UserId })
	end
	if thief.Parent == Players then
		gameEvent:FireClient(thief, "StealReturned", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Reason = reason, By = by and by.DisplayName, ByUserId = by and by.UserId })
	end
	log(thief.Name, "lost", c.name, "->", owner.Name, "(" .. reason .. ")")
	return true
end

function StealService:IsCarrying(player)
	return carrying[player] ~= nil
end

-- ---------- holding a steal ----------

-- Every rule a steal must pass, when the hold starts, while it runs and when it completes. Returns entry, model, hrp,
-- or nil, nil, nil and the reason to tell the thief ("" = say nothing). `slack` widens the reach while holding.
local function check(thief, owner, id, slack)
	if not (owner and owner.Parent == Players and DataService:Get(owner) and DataService:Get(thief)) then
		return nil, nil, nil, ""
	end
	if (owner == thief and not DevConfig.AllowSelfSteal) or not BaseService:GetPlot(thief) then
		return nil, nil, nil, ""
	end
	if carrying[thief] or thief:GetAttribute("CarryingEgg") then
		return nil, nil, nil, "Busy"
	end
	if (thief:GetAttribute("StunnedUntil") or 0) > serverNow() then
		return nil, nil, nil, ""
	end
	local hrp = hrpOf(thief)
	local entry, model = BaseService:GetItem(owner, id)
	if not (hrp and entry and model) or entry.StolenBy or entry.Unique then -- Unique: reward kaiju (GroupRewardService) can't be stolen
		return nil, nil, nil, ""
	end
	if isLocked(owner) then
		return nil, nil, nil, "Locked"
	end
	if plotUntil(owner, "ProtectedUntil") > serverNow() then
		return nil, nil, nil, "Protected"
	end
	if not inPen(owner, hrp.Position, 2) then
		return nil, nil, nil, "NotInPen"
	end
	local itemPos, radius
	if entry.Kind == "Kaiju" then
		if entry.HatchedAt and os.time() - entry.HatchedAt < StealConfig.NewHatchProtectionSeconds then
			return nil, nil, nil, "JustHatched"
		end
		itemPos = KaijuService:GetPosition(model)
		local _, ext = model:GetBoundingBox()
		radius = math.max(ext.X, ext.Z) / 2
	else
		if model:GetAttribute("HatchStartedAt") then
			return nil, nil, nil, ""
		end
		itemPos = model.PrimaryPart.Position
		radius = model.PrimaryPart.Size.X / 2
	end
	local gap = Vector3.new(hrp.Position.X - itemPos.X, 0, hrp.Position.Z - itemPos.Z).Magnitude - radius
	if gap > StealConfig.Reach + (slack or 0) then
		return nil, nil, nil, "TooFar"
	end
	if owner ~= thief and not BaseService:HasRoom(thief) then
		return nil, nil, nil, "PenFull"
	end
	return entry, model, hrp, nil
end

local function clearHold(thief)
	local h = holding[thief]
	holding[thief] = nil
	if not h then
		return nil
	end
	if h.model.Parent and h.model:GetAttribute("StealBy") == thief.UserId then
		h.model:SetAttribute("StealBy", nil)
		h.model:SetAttribute("StealStart", nil)
		h.model:SetAttribute("StealSeconds", nil)
	end
	if thief.Parent then
		thief:SetAttribute("Stealing", nil)
	end
	return h
end

-- A hold that didn't finish. reason: "Released" | "Moved" | "Locked" | "Bonked" | "Left".
function StealService:CancelSteal(thief, reason, by)
	local h = clearHold(thief)
	if not h then
		return false
	end
	if h.kind == "Kaiju" and h.model.Parent then
		KaijuService:Resume(h.model)
	end
	if thief.Parent == Players and reason ~= "Released" and reason ~= "Left" then
		gameEvent:FireClient(thief, "StealCancelled", { Kind = h.kind, Name = h.name, Rarity = h.rarity, Reason = reason, By = by and by.DisplayName })
	end
	if reason == "Bonked" and h.owner ~= thief and h.owner.Parent == Players then
		gameEvent:FireClient(h.owner, "ItemRecovered", { Kind = h.kind, Name = h.name, Rarity = h.rarity, Reason = "Stopped", By = by and by.DisplayName, ByUserId = by and by.UserId })
	end
	log(thief.Name, "stopped stealing", h.name, "(" .. reason .. ")")
	return true
end

function StealService:BeginSteal(thief, owner, id)
	local h = holding[thief]
	if h then
		if h.owner == owner and h.id == id then
			return true
		end
		self:CancelSteal(thief, "Released")
	end
	if lastSteal[thief] and os.clock() - lastSteal[thief] < StealConfig.CooldownSeconds then
		return false
	end
	local entry, model, _, reason = check(thief, owner, id, 0)
	if not entry then
		if reason ~= "" then
			gameEvent:FireClient(thief, "StealDenied", { Reason = reason })
		end
		return false
	end
	local by = model:GetAttribute("StealBy")
	if by and by ~= thief.UserId then
		gameEvent:FireClient(thief, "StealDenied", { Reason = "Contested" })
		return false
	end
	local need = StealConfig.HoldTime(entry.Rarity, entry.Size, entry.Level)
	local name = itemName(entry)
	holding[thief] = { owner = owner, id = id, kind = entry.Kind, name = name, rarity = entry.Rarity, model = model, need = need, startedAt = os.clock() }
	model:SetAttribute("StealBy", thief.UserId)
	model:SetAttribute("StealStart", serverNow())
	model:SetAttribute("StealSeconds", need)
	thief:SetAttribute("Stealing", name)
	if entry.Kind == "Kaiju" then
		KaijuService:Pause(model, need + 1.5)
	end
	if owner ~= thief then
		gameEvent:FireClient(owner, "StealBegan", { Kind = entry.Kind, Name = name, Rarity = entry.Rarity, Thief = thief.DisplayName, Seconds = need })
	end
	log(thief.Name, "is holding a steal on", name, "from", owner.Name, "(" .. need .. " s)")
	return true
end

-- The hold finished: the thief picks the item up and starts carrying it.
function StealService:CompleteSteal(thief, owner, id)
	local h = holding[thief]
	if not (h and h.owner == owner and h.id == id) then
		return false
	end
	local early = h.need - StealConfig.HoldGraceSeconds - (os.clock() - h.startedAt)
	if early > 0 then
		if early <= 1 then
			-- a little early (network timing): finish once the hold really is up
			task.delay(early, function()
				if holding[thief] == h then
					self:CompleteSteal(thief, owner, id)
				end
			end)
		end
		return false -- far too early isn't a real hold; the server timer cancels it
	end
	local entry, model, hrp, reason = check(thief, owner, id, StealConfig.HoldReachSlack)
	if not entry or model ~= h.model then
		self:CancelSteal(thief, (reason == "Locked" or reason == "Protected") and "Locked" or "Moved")
		return false
	end
	clearHold(thief)
	lastSteal[thief] = os.clock()

	entry.StolenBy = thief.UserId
	BaseService:DetachModel(owner, id)
	local carried = entry.Kind == "Kaiju" and carryKaiju(entry, hrp) or carryEgg(entry, id, hrp)
	carried.Parent = thief.Character
	local name = itemName(entry)
	carrying[thief] = {
		owner = owner,
		id = id,
		kind = entry.Kind,
		name = name,
		rarity = entry.Rarity,
		model = carried,
		startedAt = os.clock(),
		lastPos = hrp.Position,
		travelled = 0,
		topSpeed = thief.Character:FindFirstChildOfClass("Humanoid").WalkSpeed,
		leftHome = not BaseService:IsInOwnPen(thief, hrp.Position, 0),
	}
	thief:SetAttribute("CarryingStolen", name)
	thief:SetAttribute("CarryingStolenFrom", owner.DisplayName)
	EconomyService:Publish(owner) -- its income pauses while it's away
	gameEvent:FireClient(thief, "StealStarted", { Kind = entry.Kind, Name = name, Rarity = entry.Rarity, Owner = owner.DisplayName })
	if owner ~= thief then
		gameEvent:FireClient(owner, "BeingStolen", { Kind = entry.Kind, Name = name, Rarity = entry.Rarity, Thief = thief.DisplayName })
	end
	log(thief.Name, "is carrying", name, "from", owner.Name)
	return true
end

-- The thief walked into their own pen: the item becomes theirs.
local function deliver(thief, c, hrp)
	local owner = c.owner
	local ownerData = owner.Parent == Players and DataService:Get(owner)
	local entry = ownerData and ownerData.Pen.Items[c.id]
	if not (entry and entry.StolenBy == thief.UserId) then
		clearCarry(thief)
		gameEvent:FireClient(thief, "StealReturned", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Reason = "OwnerLeft" })
		return
	end
	clearCarry(thief)
	entry.StolenBy = nil
	BaseService:RemoveItem(owner, c.id)
	local thiefData = DataService:Get(thief)
	if entry.Kind == "Kaiju" then
		local model = KaijuService:Spawn(thief, c.id, entry, hrp.Position, false)
		BaseService:SetItem(thief, c.id, model, entry)
		IndexService:Record(thief, entry.Species, entry.Size or 1, entry.Mutation) -- a stolen species counts as discovered
	else
		-- a few steps in from where they walked in, towards the middle (not in the doorway)
		local depth = PenGeometry.Level(BaseService:GetLevel(thief)).Depth
		local x, d = BaseService:ToPenLocal(thief, hrp.Position)
		x, d = BaseService:FindFreeSpot(thief, x * 0.6, math.max(d + 6, depth * 0.35), entry.Size, entry.Rarity)
		if not x then
			x, d = 0, depth / 2
		end
		entry.X, entry.D = x, d
		HatchService:SpawnItem(thief, c.id, entry, nil, hrp.Position + Vector3.new(0, 4, 0))
	end
	thiefData.Stats.Steals = (thiefData.Stats.Steals or 0) + 1
	ownerData.Stats.TimesStolenFrom = (ownerData.Stats.TimesStolenFrom or 0) + 1
	local plot = BaseService:GetPlot(owner)
	if plot and owner ~= thief then
		plot:SetAttribute("ProtectedUntil", serverNow() + StealConfig.ProtectAfterTheftSeconds)
	end
	EconomyService:Publish(owner)
	EconomyService:Publish(thief)
	task.spawn(function()
		-- the victim's loss is written first: a crash between the two writes can lose a steal but never duplicate it
		DataService:SaveNow(owner)
		if thief ~= owner then
			DataService:SaveNow(thief)
		end
	end)
	gameEvent:FireClient(thief, "StealDelivered", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Owner = owner.DisplayName })
	if owner ~= thief then
		gameEvent:FireClient(owner, "Stolen", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Thief = thief.DisplayName, ProtectedSeconds = StealConfig.ProtectAfterTheftSeconds })
	end
	log(thief.Name, "stole", c.name, "from", owner.Name)
end

-- ---------- defense ----------

local function stun(target, from)
	local B = StealConfig.Bat
	target:SetAttribute("StunnedUntil", serverNow() + B.StunSeconds)
	local hrp = hrpOf(target)
	if hrp then
		Ragdoll.Start(target.Character, B.StunSeconds)
		knockback(hrp, from, B.Knockback)
	end
end

-- (Players hit each other with the bat now: Services.BatService.)
function StealService:IsHolding(player)
	return holding[player] ~= nil
end

function StealService:Lock(owner)
	local plot = BaseService:GetPlot(owner)
	if not plot then
		return false
	end
	local now = serverNow()
	if (plot:GetAttribute("LockedUntil") or 0) > now then
		gameEvent:FireClient(owner, "LockDenied", { Reason = "Locked", Seconds = math.ceil(plot:GetAttribute("LockedUntil") - now) })
		return false
	end
	local cooldown = plot:GetAttribute("LockCooldownUntil") or 0
	if cooldown > now then
		gameEvent:FireClient(owner, "LockDenied", { Reason = "Cooldown", Seconds = math.ceil(cooldown - now) })
		return false
	end
	local L = StealConfig.Lock
	plot:SetAttribute("LockedUntil", now + L.Seconds)
	plot:SetAttribute("LockCooldownUntil", now + L.Seconds + L.CooldownSeconds)
	gameEvent:FireClient(owner, "BaseLocked", { Seconds = L.Seconds })
	task.delay(L.Seconds, function()
		if owner.Parent == Players and BaseService:GetPlot(owner) == plot and (plot:GetAttribute("LockedUntil") or 0) <= serverNow() + 0.1 then
			gameEvent:FireClient(owner, "BaseUnlocked", {})
		end
	end)
	log(owner.Name, "locked their base")
	return true
end

-- Lock button inside every pen, beside the entrance (pen-local coordinates never change with the pen's level).
local function buildLockButton(plot)
	local old = plot:FindFirstChild("LockButton")
	if old then
		old:Destroy()
	end
	local frame = PenGeometry.Frame(plot)
	local x = -(MapConfig.Plots.EntranceWidth / 2 + 3)
	local base = frame * CFrame.new(x, 0, -3) * CFrame.Angles(0, math.rad(180), 0) -- faces the entrance
	local m = Instance.new("Model")
	m.Name = "LockButton"
	local function part(name, size, cf, color, opts)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = opts and opts.material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if opts and opts.shape then
			p.Shape = opts.shape
		end
		p.CanCollide = not (opts and opts.noCollide)
		p.Parent = m
		return p
	end
	local accent = plot:GetAttribute("Color") or Color3.fromHex("FFD23F")
	part("Pedestal", Vector3.new(2.6, 2.4, 2.6), base * CFrame.new(0, 1.2, 0), Color3.fromHex("2B1B4D"))
	part("Trim", Vector3.new(2.8, 0.25, 2.8), base * CFrame.new(0, 2.4, 0), accent, { material = Enum.Material.Neon, noCollide = true })
	local button = part("Button", Vector3.new(0.6, 1.8, 1.8), base * CFrame.new(0, 2.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("FF3B3B"), { material = Enum.Material.Neon, shape = Enum.PartType.Cylinder })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock Base"
	prompt.ObjectText = "Base Lock"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = button
	prompt.Triggered:Connect(function(player)
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			StealService:Lock(player)
		end
	end)
	m.PrimaryPart = button
	m.Parent = plot
end

-- ---------- per tick ----------

-- Pushes other players out of locked pens, alerts owners about intruders, keeps holds honest, delivers or drops
-- stolen goods.
local function tick()
	local now = serverNow()
	for _, owner in Players:GetPlayers() do
		local plot = BaseService:GetPlot(owner)
		if not plot then
			continue
		end
		local locked = (plot:GetAttribute("LockedUntil") or 0) > now
		for _, other in Players:GetPlayers() do
			local hrp = other ~= owner and hrpOf(other)
			if not (hrp and inPen(owner, hrp.Position, 1.5)) then
				continue
			end
			if locked then
				-- out through the entrance, facing away
				local frame = PenGeometry.Frame(plot)
				local lx = PenGeometry.ToLocal(plot, hrp.Position)
				local outside = (frame * CFrame.new(math.clamp(lx, -4, 4), 3.5, 7)).Position
				other.Character:PivotTo(CFrame.lookAt(outside, outside - frame.LookVector))
				if carrying[other] then
					carrying[other].lastPos = outside -- our own move doesn't count as their travel
				end
				if not lastPush[other] or os.clock() - lastPush[other] > 2 then
					lastPush[other] = os.clock()
					gameEvent:FireClient(other, "PushedOut", { Owner = owner.DisplayName })
				end
			else
				local seen = lastAlert[owner] or {}
				lastAlert[owner] = seen
				if not seen[other] or os.clock() - seen[other] > StealConfig.IntruderAlertSeconds then
					seen[other] = os.clock()
					gameEvent:FireClient(owner, "Intruder", { Name = other.DisplayName })
				end
			end
		end
	end
	for thief, h in holding do
		if thief.Parent ~= Players or h.owner.Parent ~= Players then
			StealService:CancelSteal(thief, "Left")
		elseif os.clock() - h.startedAt > h.need + 4 then
			StealService:CancelSteal(thief, "Released") -- the client never finished it
		else
			local entry, model, _, reason = check(thief, h.owner, h.id, StealConfig.HoldReachSlack)
			if not entry or model ~= h.model then
				StealService:CancelSteal(thief, (reason == "Locked" or reason == "Protected") and "Locked" or "Moved")
			end
		end
	end
	for thief, c in carrying do
		if c.owner.Parent ~= Players then
			clearCarry(thief)
			gameEvent:FireClient(thief, "StealReturned", { Kind = c.kind, Name = c.name, Rarity = c.rarity, Reason = "OwnerLeft" })
			continue
		end
		local hrp = hrpOf(thief)
		if not hrp then
			StealService:Return(thief, "Died")
			continue
		end
		-- a carrier can't cover more ground than they could have walked (flat path length, so falls don't count)
		local pos = hrp.Position
		c.travelled += Vector3.new(pos.X - c.lastPos.X, 0, pos.Z - c.lastPos.Z).Magnitude
		c.lastPos = pos
		c.topSpeed = math.max(c.topSpeed, thief.Character:FindFirstChildOfClass("Humanoid").WalkSpeed)
		if c.travelled > c.topSpeed * StealConfig.SpeedTolerance * (os.clock() - c.startedAt) + StealConfig.SpeedSlackStuds then
			log(thief.Name, "moved too fast:", math.floor(c.travelled), "studs in", string.format("%.1f", os.clock() - c.startedAt), "s")
			StealService:Return(thief, "TooFast")
			continue
		end
		local home = BaseService:IsInOwnPen(thief, hrp.Position, 0)
		if not home then
			c.leftHome = true
		elseif c.leftHome then
			deliver(thief, c, hrp)
		end
	end
end

-- ---------- Studio test helpers ----------

-- Holds a steal for its full time and completes it (yields).
function StealService:StealForTesting(thief, owner, id)
	if not DevConfig.InStudio or not self:BeginSteal(thief, owner, id) then
		return false
	end
	task.wait(holding[thief] and holding[thief].need or 0)
	return self:CompleteSteal(thief, owner, id)
end

-- As if the carrier was bonked (no ragdoll).
function StealService:ReturnForTesting(player)
	if DevConfig.InStudio then
		return self:Return(player, "Bonked")
	end
	return false
end

-- A bat hit's effect on a solo player: whatever they hold or carry goes home, then ragdoll + knockback + stun.
function StealService:RagdollForTesting(player)
	local hrp = DevConfig.InStudio and hrpOf(player)
	if not hrp then
		return false
	end
	if holding[player] then
		self:CancelSteal(player, "Bonked")
	end
	if carrying[player] then
		self:Return(player, "Bonked")
	end
	stun(player, hrp.Position + hrp.CFrame.LookVector * 4)
	return true
end

-- ---------- wiring ----------

function StealService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remotes = ReplicatedStorage.Remotes
	remotes:WaitForChild("Steal").OnServerEvent:Connect(function(thief, ownerUserId, id, phase)
		if type(ownerUserId) ~= "number" or type(id) ~= "string" then
			return
		end
		local owner = Players:GetPlayerByUserId(ownerUserId)
		if phase == "Begin" then
			self:BeginSteal(thief, owner, id)
		elseif phase == "Cancel" then
			local h = holding[thief]
			if h and h.id == id then
				self:CancelSteal(thief, "Released")
			end
		elseif phase == nil then
			self:CompleteSteal(thief, owner, id)
		end
	end)
	remotes:WaitForChild("LockBase").OnServerEvent:Connect(function(owner)
		self:Lock(owner)
	end)
end

-- A steal prompt on a pen egg or kaiju (Gameplay.StealFX shows it only to other players and handles it).
local function addPrompt(model, isKaiju)
	if model:GetAttribute("Showcase") or model:GetAttribute("Unique") or not model.PrimaryPart or model.PrimaryPart:FindFirstChild("StealAttachment") then
		return
	end
	local boxCF, ext = model:GetBoundingBox()
	local att = Instance.new("Attachment")
	att.Name = "StealAttachment"
	att.Position = isKaiju and Vector3.new(0, ext.Y * 0.45, 0) or Vector3.zero
	att.Parent = model.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	-- the footprint check() measures reach from (kaiju: a circle round its pivot; egg: its shell), so Gameplay.StealFX
	-- can keep the prompt on the edge nearest the thief. StealBottom / StealHeight: its vertical span from that centre.
	local centreY = isKaiju and model:GetPivot().Position.Y or model.PrimaryPart.Position.Y
	prompt:SetAttribute("StealRadius", isKaiju and math.max(ext.X, ext.Z) / 2 or model.PrimaryPart.Size.X / 2)
	prompt:SetAttribute("StealBottom", boxCF.Position.Y - ext.Y / 2 - centreY)
	prompt:SetAttribute("StealHeight", ext.Y)
	prompt:SetAttribute("StealKaiju", isKaiju)
	prompt.ActionText = "Steal"
	local rarity, size = model:GetAttribute("Rarity") or "Common", model:GetAttribute("Size") or 1
	if isKaiju then
		local cfg = KaijuConfig[model:GetAttribute("Species") or ""]
		local level = model:GetAttribute("Level") or 1
		prompt.ObjectText = (cfg and cfg.DisplayName or "Kaiju") .. "  Lv " .. level
		prompt.HoldDuration = StealConfig.HoldTime(rarity, size, level)
	else
		prompt.ObjectText = EggModel.Label(rarity, size)
		prompt.HoldDuration = StealConfig.HoldTime(rarity, size)
	end
	prompt.MaxActivationDistance = StealConfig.Reach + math.max(ext.X, ext.Z) / 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = att
end

function StealService:Start()
	local runtime = workspace:WaitForChild("Runtime")
	local kaijuFolder = runtime:WaitForChild("Kaiju")
	local eggFolder = runtime:WaitForChild("Eggs")
	kaijuFolder.ChildAdded:Connect(function(model)
		addPrompt(model, true)
	end)
	for _, model in kaijuFolder:GetChildren() do
		addPrompt(model, true)
	end
	local function onEgg(egg)
		if egg:GetAttribute("State") == "Pen" then
			addPrompt(egg, false)
		end
	end
	eggFolder.ChildAdded:Connect(onEgg)
	for _, egg in eggFolder:GetChildren() do
		onEgg(egg)
	end

	for _, plot in workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("PlotId") then
			buildLockButton(plot)
		end
	end

	DataService:OnLoaded(function(_, data)
		-- a server that stopped mid-steal leaves StolenBy behind: the item is simply home
		for _, entry in data.Pen.Items do
			entry.StolenBy = nil
		end
	end)

	local function onPlayer(player)
		player.CharacterRemoving:Connect(function()
			if holding[player] then
				StealService:CancelSteal(player, "Released")
			end
			if carrying[player] then
				StealService:Return(player, "Died")
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if holding[player] then
			StealService:CancelSteal(player, "Left")
		end
		if carrying[player] then
			StealService:Return(player, "Left")
		end
		lastSteal[player], lastPush[player], lastAlert[player] = nil, nil, nil
		for _, seen in lastAlert do
			seen[player] = nil
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		tick()
	end)
end

return StealService
