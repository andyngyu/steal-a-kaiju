-- Gameplay input for carried eggs (not UI): a ghost egg previews where the egg will land, and a click / tap /
-- gamepad R2 sends Remotes.DropEgg. The server validates everything (reach, pen, capacity).
-- Ghost colours: green = inside your pen, white = on the ground, red = your pen is full.
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

-- World point under a screen position. `inset` = true for positions that include the top bar (touch events).
local function aimPoint(screenPos, inset)
	local camera = workspace.CurrentCamera
	local ray = inset and camera:ScreenPointToRay(screenPos.X, screenPos.Y) or camera:ViewportPointToRay(screenPos.X, screenPos.Y)
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

local function groundY(spot)
	local hit = workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), mapOnly)
	return hit and hit.Position.Y or 0
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
	local y = groundY(spot)
	local color = COLORS[classify(spot)]
	local t = os.clock()
	ghost.Color = color
	ring.Color = color
	ghost.CFrame = CFrame.new(spot.X, y + EggConfig.Size.Y / 2 + 0.3 + math.sin(t * 4) * 0.2, spot.Z) * CFrame.Angles(0, t * 1.5, 0)
	ring.CFrame = CFrame.new(spot.X, y + 0.08, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
	local pulse = 4.5 + math.sin(t * 6) * 0.35
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
