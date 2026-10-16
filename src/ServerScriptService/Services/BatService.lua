-- The bat (Steal a Brainrot style; replaced the old Tackle prompt on 16 Oct 2026). Numbers in StealConfig.Bat.
--   Every player spawns with a wooden baseball bat (ReplicatedStorage.Assets.Bat, a Tool) in their backpack; the
--   KaijuUI hotbar's first slot (key 1) takes it out / puts it away through Remotes.SwingBat ("Equip" / "Unequip";
--   the server moves the tool, since a tool moved by the client didn't reach the server here). Clicking / tapping
--   with it out swings (Gameplay.BatFX -> Remotes.SwingBat with no argument). The server checks the cooldown and that the swinger is free (not carrying,
--   stealing, stunned, ragdolled or on a treadmill), plays the swing (the Animate script's tool slash, started by a
--   "toolanim" StringValue in the tool; the tool's SwungAt attribute cues the whoosh for every client) and after
--   WindUpSeconds hits the closest other player within Reach in front of the swinger (ConeDegrees; anyone closer
--   than CloseReach counts from any side).
--   A hit: a steal being held stops and carried stolen goods go home (StealService, Reason "Bonked"), a carried
--   nest egg drops on the spot for anyone to grab (EggService), a treadmill run stops; then the target is
--   ragdolled (Lib.Ragdoll), knocked back and stunned (StunnedUntil) for StunSeconds, and can't be hit again until
--   ImmuneSeconds after getting up (player attribute HitImmuneUntil).
-- GameEvent: BatHit {Attacker, Target, Position} (everyone: the BONK effect and sound), Bonked {By, Lost} (target),
--   BonkLanded {Target, Lost} (swinger). Lost = what the target lost: "Egg" | "Stolen" | "Steal" | nil.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local StealConfig = require(ReplicatedStorage.Shared.Config.StealConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local Ragdoll = require(game:GetService("ServerScriptService").Lib.Ragdoll)

local StealService = require(script.Parent.StealService)
local EggService = require(script.Parent.EggService)
local TreadmillService = require(script.Parent.TreadmillService)

local BatService = {}

local B = StealConfig.Bat
local TOOL_NAME = "Bat"
local gameEvent
local template
local lastSwing = {} -- [player] = os.clock()

-- The bat's hold (Tool.Grip; the bat runs along the handle's +Y): pointing forward from the hand, arms in the normal
-- idle pose (Gameplay.BatFX stops the arm-out tool hold). Grip angles about the handle's X: -80 = straight up,
-- 0 = forward (a touch above level), +60 = forward and down.
-- The swing pose is drawn by every client (Gameplay.BatFX: a full wind-up and an arm fully extended at the strike,
-- cued by the tool's SwungAt attribute); the hit lands WindUpSeconds in, at the strike. (A server tween of the Grip on top of it arrived a beat late over the network, so the
-- arm moved ahead of the bat; it's left switched off: SWING_GRIP = false.)
local SWING_GRIP = false
local function grip(deg)
	return CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(deg), 0, 0)
end
local REST = grip(0)
local SWING = {
	{ 0.08, grip(-120), Enum.EasingStyle.Quad, Enum.EasingDirection.Out }, -- wind up: back over the shoulder
	-- (in two halves: a single tween takes the shortest way round, which would swing it backwards)
	{ 0.05, grip(-25), Enum.EasingStyle.Quad, Enum.EasingDirection.In }, -- whip over the top...
	{ 0.05, grip(65), Enum.EasingStyle.Linear, Enum.EasingDirection.In }, -- ...and through, forward and down
	{ 0.3, REST, Enum.EasingStyle.Back, Enum.EasingDirection.Out }, -- back to the hold
}
local swinging = {} -- [tool] = token

local function playSwing(tool)
	local token = {}
	swinging[tool] = token
	task.spawn(function()
		for _, step in SWING do
			if swinging[tool] ~= token or not tool.Parent then
				return
			end
			local tw = TweenService:Create(tool, TweenInfo.new(step[1], step[3], step[4]), { Grip = step[2] })
			tw:Play()
			tw.Completed:Wait()
		end
		if swinging[tool] == token then
			swinging[tool] = nil
		end
	end)
end

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Bat]", ...)
	end
end

local function now()
	return workspace:GetServerTimeNow()
end

local function alive(player)
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then
		return char, hum, hrp
	end
	return nil
end

local function stunned(player)
	local char = player.Character
	return (player:GetAttribute("StunnedUntil") or 0) > now() or (char ~= nil and char:GetAttribute("RagdollUntil") ~= nil)
end

-- Hands full or busy: no swinging. (Running on your treadmill is fine: you can bonk thieves from it.)
local function busy(player)
	return player:GetAttribute("CarryingEgg") ~= nil
		or player:GetAttribute("CarryingStolen") ~= nil
		or player:GetAttribute("Stealing") ~= nil
		or stunned(player)
end

local function giveBat(player)
	local backpack = player:WaitForChild("Backpack", 10)
	local char = player.Character
	if not (backpack and template) then
		return
	end
	if backpack:FindFirstChild(TOOL_NAME) or (char and char:FindFirstChild(TOOL_NAME)) then
		return
	end
	local tool = template:Clone()
	tool.Grip = REST
	-- put the hold back if a swing was cut short by unequipping
	tool.Unequipped:Connect(function()
		swinging[tool] = nil
		tool.Grip = REST
	end)
	tool.Parent = backpack
end

local function knockback(hrp, fromPos)
	local flat = Vector3.new(hrp.Position.X - fromPos.X, 0, hrp.Position.Z - fromPos.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or -Vector3.xAxis
	local att = hrp:FindFirstChild("RootAttachment") or hrp:FindFirstChildOfClass("Attachment")
	if not att then
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BatKnockback"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = dir * B.Knockback + Vector3.new(0, B.Knockback * B.Lift, 0)
	lv.Parent = hrp
	Debris:AddItem(lv, 0.2)
end

-- The closest other player in front of the swinger, or nil.
local function findTarget(attacker, hrp)
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.zAxis
	local cosHalf = math.cos(math.rad(B.ConeDegrees / 2))
	local best, bestDist = nil, math.huge
	for _, other in Players:GetPlayers() do
		if other == attacker then
			continue
		end
		local char, _, ohrp = alive(other)
		if not char or char:GetAttribute("RagdollUntil") or (other:GetAttribute("HitImmuneUntil") or 0) > now() then
			continue
		end
		local d = ohrp.Position - hrp.Position
		if math.abs(d.Y) > 7 then
			continue
		end
		local flat = Vector3.new(d.X, 0, d.Z)
		local dist = flat.Magnitude
		if dist > B.Reach or dist >= bestDist then
			continue
		end
		if dist > B.CloseReach and flat.Unit:Dot(look) < cosHalf then
			continue
		end
		best, bestDist = other, dist
	end
	return best
end

-- The hit itself (also used by the Studio test helper). Returns what the target lost.
function BatService:Hit(attacker, target, fromPos)
	local char, hum, hrp = alive(target)
	if not char then
		return nil
	end
	local lost = nil
	if StealService:IsHolding(target) then
		StealService:CancelSteal(target, "Bonked", attacker)
		lost = "Steal"
	end
	if StealService:IsCarrying(target) then
		StealService:Return(target, "Bonked", attacker)
		lost = "Stolen"
	end
	if EggService:GetCarried(target) then
		EggService:DropCarried(target, "Bonked")
		lost = "Egg"
	end
	if target:GetAttribute("OnTreadmill") then
		TreadmillService:Stop(target)
	end
	hum:UnequipTools() -- the bat goes back in the backpack while they're down
	local t = now()
	target:SetAttribute("StunnedUntil", t + B.StunSeconds)
	target:SetAttribute("HitImmuneUntil", t + B.StunSeconds + B.ImmuneSeconds)
	Ragdoll.Start(char, B.StunSeconds)
	knockback(hrp, fromPos)
	gameEvent:FireAllClients("BatHit", { Attacker = attacker and attacker.UserId, Target = target.UserId, Position = hrp.Position })
	gameEvent:FireClient(target, "Bonked", { By = attacker and attacker.DisplayName or "Someone", Lost = lost })
	if attacker then
		gameEvent:FireClient(attacker, "BonkLanded", { Target = target.DisplayName, Lost = lost })
	end
	log(attacker and attacker.Name or "?", "bonked", target.Name, lost and ("(" .. lost .. ")") or "")
	return lost
end

function BatService:Swing(player)
	local char, _, hrp = alive(player)
	local tool = char and char:FindFirstChild(TOOL_NAME)
	if not (tool and tool:IsA("Tool")) then
		return false
	end
	local t = os.clock()
	if lastSwing[player] and t - lastSwing[player] < B.CooldownSeconds - 0.08 then
		return false
	end
	if busy(player) then
		return false
	end
	lastSwing[player] = t
	if SWING_GRIP then
		playSwing(tool)
	end
	tool:SetAttribute("SwungAt", now())
	task.delay(B.WindUpSeconds, function()
		local c2, _, hrp2 = alive(player)
		if not (c2 and tool.Parent == c2) or stunned(player) then
			return
		end
		local target = findTarget(player, hrp2)
		if target then
			self:Hit(player, target, hrp2.Position)
		end
	end)
	return true
end

-- Takes the bat out (not while busy) or puts it away.
function BatService:SetEquipped(player, on)
	local char, hum = alive(player)
	if not char then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = char:FindFirstChild(TOOL_NAME) or (backpack and backpack:FindFirstChild(TOOL_NAME))
	if not tool then
		giveBat(player)
		tool = backpack and backpack:FindFirstChild(TOOL_NAME)
		if not tool then
			return false
		end
	end
	if on then
		if busy(player) then
			return false
		end
		if tool.Parent ~= char then
			hum:EquipTool(tool) -- (anything else in hand, like held food, goes back first)
		end
	elseif tool.Parent == char then
		hum:UnequipTools()
	end
	return true
end

-- Studio only: bonk a player as if someone stood in front of them.
function BatService:HitForTesting(player)
	local _, _, hrp = alive(player)
	if DevConfig.InStudio and hrp then
		return self:Hit(nil, player, hrp.Position + hrp.CFrame.LookVector * 4) or true
	end
	return false
end

function BatService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild(TOOL_NAME)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("SwingBat") or Instance.new("RemoteEvent")
	remote.Name = "SwingBat"
	remote.Parent = ReplicatedStorage.Remotes
	remote.OnServerEvent:Connect(function(player, action)
		if action == "Equip" or action == "Unequip" then
			self:SetEquipped(player, action == "Equip")
		else
			self:Swing(player)
		end
	end)
	-- the old Tackle prompt's remote is gone (the bat replaced it)
	local tackle = ReplicatedStorage.Remotes:FindFirstChild("Tackle")
	if tackle then
		tackle:Destroy()
	end
end

function BatService:Start()
	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			task.defer(giveBat, player)
		end)
		if player.Character then
			task.spawn(giveBat, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
	-- hands full: carrying, stealing, a treadmill run or a stun puts the bat away
	local function putAway(player)
		local char, hum = alive(player)
		if char and char:FindFirstChild(TOOL_NAME) and busy(player) then
			hum:UnequipTools()
		end
	end
	local function watch(player)
		for _, attr in { "CarryingEgg", "CarryingStolen", "Stealing", "StunnedUntil" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				putAway(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return BatService
