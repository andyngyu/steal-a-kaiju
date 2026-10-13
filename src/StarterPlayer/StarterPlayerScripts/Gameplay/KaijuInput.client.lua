-- Gameplay input for carried eggs (not UI): a ghost egg previews where the egg will land, and a click / tap /
-- gamepad R2 sends Remotes.DropEgg. The server validates everything (reach, pen, capacity).
-- Ghost colours: green = inside your pen, white = on the ground, red = your pen is full. The ghost matches the carried egg's size.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BaseConfig = require(ReplicatedStorage.Shared.Config.BaseConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local dropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DropEgg")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")

local COLORS = {
	Pen = Color3.fromHex("6BE04A"),
	Ground = Color3.fromHex("FFFFFF"),
	Full = Color3.fromHex("FF4D5E"),
}

local ghost = Instance.new("Part")
ghost.Name = "EggDropGhost"
ghost.Size = EggConfig.Size
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.CastShadow = false
ghost.Material = Enum.Material.ForceField
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Sphere
mesh.Parent = ghost

local ring = Instance.new("Part")
ring.Name = "EggDropRing"
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.15, 4.5, 4.5)
ring.Anchored = true
ring.CanCollide = false
ring.CanQuery = false
ring.CanTouch = false
ring.CastShadow = false
ring.Material = Enum.Material.Neon
ring.Transparency = 0.45

local mapOnly = RaycastParams.new()
mapOnly.FilterType = Enum.RaycastFilterType.Include
mapOnly.FilterDescendantsInstances = { map }

local lastSent = 0

local function carrying()
	return player:GetAttribute("CarryingEgg") ~= nil
end

local function rootPart()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- Height of the ground the player is standing over (works mid-jump too).
local function floorY(hrp)
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), mapOnly)
	if hit then
		return hit.Position.Y
	end
	local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	return hrp.Position.Y - hrp.Size.Y / 2 - (hum and hum.HipHeight or 2)
end

-- World point under a screen position. `inset` = true for positions that include the top bar (touch events).
-- Aims at the ground level the player stands on, so fences, signs, trees, walls or boards under the cursor no longer
-- pull the preview away from where the cursor meets the ground.
local function aimPoint(screenPos, inset)
	local camera = workspace.CurrentCamera
	local ray = inset and camera:ScreenPointToRay(screenPos.X, screenPos.Y) or camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local hrp = rootPart()
	if hrp and ray.Direction.Y < -0.01 then
		local t = (floorY(hrp) - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			return ray.Origin + ray.Direction * t
		end
	end
	-- looking level / upwards: fall back to whatever the cursor is over
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, mapOnly)
	return hit and hit.Position
end

local function clampToReach(point, hrp)
	local flat = Vector3.new(point.X - hrp.Position.X, 0, point.Z - hrp.Position.Z)
	if flat.Magnitude > BaseConfig.Drop.MaxDistance then
		flat = flat.Unit * BaseConfig.Drop.MaxDistance
	end
	return Vector3.new(hrp.Position.X + flat.X, 0, hrp.Position.Z + flat.Z)
end

-- Ground height at a spot, looking down from just above the player's floor (so fence rails, sign tops and arches
-- above it are ignored).
local function groundY(spot, nearY)
	local from = (nearY or 0) + 1.5
	local hit = workspace:Raycast(Vector3.new(spot.X, from, spot.Z), Vector3.new(0, -12, 0), mapOnly)
	return hit and hit.Position.Y or (nearY or 0)
end

local function classify(spot)
	local plot = map.Plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("PlotId")))
	if plot then
		local x, d = PenGeometry.ToLocal(plot, spot)
		if PenGeometry.Contains(player:GetAttribute("PenLevel") or 1, x, d, 0) then
			if (player:GetAttribute("PenCount") or 0) >= (player:GetAttribute("PenCapacity") or 0) then
				return "Full"
			end
			return "Pen"
		end
	end
	return "Ground"
end

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function drop(screenPos, inset)
	if not carrying() then
		return
	end
	local hrp = rootPart()
	if not hrp then
		return
	end
	local aim = screenPos and aimPoint(screenPos, inset) or (hrp.Position + hrp.CFrame.LookVector * 5)
	if not aim then
		return
	end
	local now = os.clock()
	if now - lastSent < BaseConfig.Drop.CooldownSeconds then
		return
	end
	lastSent = now
	dropRemote:FireServer(clampToReach(aim, hrp))
end

RunService.RenderStepped:Connect(function()
	local hrp = rootPart()
	if not (carrying() and hrp) then
		ghost.Parent = nil
		ring.Parent = nil
		return
	end
	local aim
	if touchOnly() then
		aim = hrp.Position + hrp.CFrame.LookVector * 5
	else
		aim = aimPoint(UserInputService:GetMouseLocation(), false)
	end
	if not aim then
		ghost.Parent = nil
		ring.Parent = nil
		return
	end
	local spot = clampToReach(aim, hrp)
	local y = groundY(spot, floorY(hrp))
	local color = COLORS[classify(spot)]
	local t = os.clock()
	local egg = player.Character:FindFirstChild("Egg")
	local eggSize = egg and egg.PrimaryPart and egg.PrimaryPart.Size or EggConfig.Size
	local k = eggSize.X / EggConfig.Size.X
	ghost.Size = eggSize
	ghost.Color = color
	ring.Color = color
	ghost.CFrame = CFrame.new(spot.X, y + eggSize.Y / 2 + 0.3 + math.sin(t * 4) * 0.2, spot.Z) * CFrame.Angles(0, t * 1.5, 0)
	ring.CFrame = CFrame.new(spot.X, y + 0.08, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
	local pulse = (4.5 + math.sin(t * 6) * 0.35) * k
	ring.Size = Vector3.new(0.15, pulse, pulse)
	ghost.Parent = workspace
	ring.Parent = workspace
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		drop(UserInputService:GetMouseLocation(), false)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		drop(nil)
	end
end)

UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
	if not processedByUI then
		drop(position, true)
	end
end)
