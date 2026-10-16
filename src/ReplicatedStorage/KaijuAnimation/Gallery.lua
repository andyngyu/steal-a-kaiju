-- KaijuAnimation.Gallery (Studio only, never in live servers): an animation test area floating high above the map
-- (Config.Gallery) with one kaiju of every motion profile in a row, facing a walkway. The creatures are client-only
-- copies of ReplicatedStorage.Assets.KaijuPortraits at their in-game size (Thornmaw: a copy of the live Venom Jungle
-- guardian), owned by the local player so walking up to them shows the owner greeting. Nothing here replicates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Gallery = {}

local player = Players.LocalPlayer
local folder
local returnCF
local slots = {} -- [name] = { model, centre, size }
local opening = false

local function kaijuConfig()
	local ok, KC = pcall(function()
		return require(ReplicatedStorage.Shared.Config.KaijuConfig)
	end)
	return ok and KC or {}
end

local function visualScale(name)
	local ok, s = pcall(function()
		return require(ReplicatedStorage.Shared.Util.KaijuStats).VisualScale(name, 1, 1)
	end)
	return ok and s or 1
end

local function liveGuardian(biome)
	local runtime = workspace:FindFirstChild("Runtime")
	local guardians = runtime and runtime:FindFirstChild("Guardians")
	if not guardians then
		return nil
	end
	for _, g in guardians:GetChildren() do
		if g:GetAttribute("BiomeId") == biome and not g:GetAttribute("Personal") then
			return g
		end
	end
	return nil
end

local function part(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function plaque(parent, cf, title, sub)
	local p = part("Plaque", Vector3.new(4, 0.6, 1.4), cf, Color3.fromHex("2B2F3A"), parent)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 1.4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.6)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = title
	t.Parent = bb
	local s = t:Clone()
	s.Position = UDim2.fromScale(0, 0.6)
	s.Size = UDim2.fromScale(1, 0.4)
	s.Font = Enum.Font.GothamBold
	s.TextColor3 = Color3.fromHex("BFD4FF")
	s.Text = sub
	s.Parent = bb
	bb.Parent = p
end

function Gallery.IsOpen()
	return folder ~= nil
end

local function teleport(cf)
	local char = player.Character
	if char and char.PrimaryPart then
		char:PivotTo(cf)
	end
end

function Gallery.Start()
	local first = slots[Config.Gallery.Order[1]]
	local o = Config.Gallery.Origin
	local x = first and first.centre.X or o.X
	return CFrame.lookAt(Vector3.new(x + 6, o.Y + 4, o.Z - 22), Vector3.new(x - 4, o.Y + 4, o.Z))
end

-- Builds the gallery (once) and takes the local player there. Yields while the creatures are copied.
function Gallery.Open(Controller)
	if not RunService:IsStudio() then
		return false
	end
	local char = player.Character
	if not folder and not opening then
		opening = true
		if char and char.PrimaryPart then
			returnCF = char:GetPivot()
		end
		folder = Instance.new("Folder")
		folder.Name = "KaijuAnimGallery"
		folder.Parent = workspace
		local o = Config.Gallery.Origin
		local KC = kaijuConfig()
		-- copies, posed at the origin first so they can be measured
		local list = {}
		for _, name in Config.Gallery.Order do
			local spec = Config.Creatures[name]
			local src, info
			if spec and spec.Guardian then
				src = liveGuardian(spec.Guardian)
				info = { name = name, rarity = "Guardian", biome = spec.Guardian, owner = player.UserId, guardian = true }
			else
				local portraits = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("KaijuPortraits")
				src = portraits and portraits:FindFirstChild(name)
				local c = KC[name] or {}
				info = { name = name, rarity = c.Rarity or "Common", biome = c.Biome, owner = player.UserId }
			end
			if not src then
				warn("[KaijuAnimation] Gallery: no model for " .. name)
				continue
			end
			local m = src:Clone()
			if info.guardian then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:Destroy()
				end
				m.PrimaryPart.Anchored = true
				for _, d in m:GetDescendants() do
					if d:IsA("Motor6D") then
						d.Transform = CFrame.identity
					elseif d:IsA("BasePart") then
						d.CanCollide = false
					end
				end
				m:SetAttribute("State", "Sleeping")
			else
				local s = visualScale(name)
				if math.abs(s - 1) > 0.001 then
					m:ScaleTo(s)
				end
				m:SetAttribute("VisualScale", s)
				m:SetAttribute("Species", name)
				m:SetAttribute("Rarity", info.rarity)
			end
			m:SetAttribute("OwnerUserId", player.UserId)
			m:SetAttribute("Gallery", true)
			m:PivotTo(CFrame.new(o))
			local cf, size = m:GetBoundingBox()
			table.insert(list, { name = name, model = m, info = info, centre = cf.Position, size = size })
		end
		-- one row along -X, facing -Z where the walkway is, so it reads left to right from the walkway
		local gap = Config.Gallery.Gap
		local x = 0
		for _, e in list do
			local w = math.max(e.size.X, e.size.Z * 0.6, 4)
			e.slotX = o.X - (x + w / 2)
			x += w + gap
		end
		local length = x
		local floor = part("Floor", Vector3.new(length + 40, 2, 90), CFrame.new(o.X - length / 2 + 10, o.Y - 1, o.Z), Color3.fromHex("3A4150"), folder)
		floor.Material = Enum.Material.Slate
		part("Walkway", Vector3.new(length + 40, 2.05, 12), CFrame.new(o.X - length / 2 + 10, o.Y - 1, o.Z - 22), Color3.fromHex("525B6E"), folder)
		for _, e in list do
			local m = e.model
			local bottom = e.centre.Y - e.size.Y / 2
			m:PivotTo(m:GetPivot() + Vector3.new(e.slotX - e.centre.X, o.Y - bottom, o.Z - e.centre.Z))
			m.Parent = folder
			local profile = Config.Creatures[e.name].Profile
			plaque(folder, CFrame.new(e.slotX, o.Y + 0.3, o.Z - e.size.Z / 2 - 3), e.name, profile .. " | " .. e.info.rarity)
			slots[e.name] = { model = m, centre = Vector3.new(e.slotX, o.Y + e.size.Y / 2, o.Z), size = e.size }
			Controller.Register(m, e.info)
			task.wait()
		end
		opening = false
	end
	while opening do
		task.wait()
	end
	teleport(Gallery.Start())
	return true
end

function Gallery.Close()
	Gallery.Unfocus()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(slots)
	if returnCF then
		teleport(returnCF)
		returnCF = nil
	end
end

function Gallery.Names()
	local out = {}
	for _, name in Config.Gallery.Order do
		if slots[name] then
			table.insert(out, name)
		end
	end
	return out
end

-- Points the camera at one creature (view: "front", "side", "back", "top" or a 3/4 view by default) and walks the
-- player there so the creature is in its Full tier.
function Gallery.Focus(name, view)
	local s = slots[name]
	if not s then
		return false
	end
	local cam = workspace.CurrentCamera
	local d = math.max(s.size.X, s.size.Y, s.size.Z) * 1.5 + 6
	local dir = Vector3.new(0.75, 0.35, -0.9)
	if view == "front" then
		dir = Vector3.new(0, 0.2, -1)
	elseif view == "side" then
		dir = Vector3.new(1, 0.15, 0)
	elseif view == "back" then
		dir = Vector3.new(-0.6, 0.35, 1)
	elseif view == "top" then
		dir = Vector3.new(0.2, 1, -0.4)
	end
	local c = s.centre
	teleport(CFrame.lookAt(Vector3.new(c.X, Config.Gallery.Origin.Y + 4, c.Z - s.size.Z / 2 - 14), c))
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(c + dir.Unit * d, c)
	return true
end

function Gallery.Unfocus()
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Custom
	end
end

return Gallery
