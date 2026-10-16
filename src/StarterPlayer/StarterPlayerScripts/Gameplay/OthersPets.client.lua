-- The "Others' Pets" setting (Shared.Config.SettingsConfig key OthersPets). Off: other players' kaiju in
-- workspace.Runtime.Kaiju are hidden for you only (LocalTransparencyModifier on their parts and decals; their name
-- plates, particles, lights and sounds switched off). Your own kaiju always show. Purely cosmetic: they still exist
-- on the server and can still be stolen from / steal prompts still work.
local Players = game:GetService("Players")

local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("Runtime"):WaitForChild("Kaiju")
local show = Settings.Get("OthersPets") ~= false

local saved = setmetatable({}, { __mode = "k" }) -- [instance] = its own Enabled before we hid it

local function isOthers(model)
	local owner = model:GetAttribute("OwnerUserId")
	return owner ~= nil and owner ~= player.UserId and not model:GetAttribute("Showcase")
end

local function apply(inst, hide)
	if inst:IsA("BasePart") or inst:IsA("Decal") or inst:IsA("Texture") then
		inst.LocalTransparencyModifier = hide and 1 or 0
	elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") or inst:IsA("ParticleEmitter") or inst:IsA("Light")
		or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") then
		if hide then
			if saved[inst] == nil then
				saved[inst] = inst.Enabled
			end
			inst.Enabled = false
		elseif saved[inst] ~= nil then
			inst.Enabled = saved[inst]
			saved[inst] = nil
		end
	elseif inst:IsA("Sound") then
		if hide then
			if saved[inst] == nil then
				saved[inst] = inst.Volume
			end
			inst.Volume = 0
		elseif saved[inst] ~= nil then
			inst.Volume = saved[inst]
			saved[inst] = nil
		end
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function refresh(model)
	local hide = not show and isOthers(model)
	for _, d in model:GetDescendants() do
		apply(d, hide)
	end
end

local function watch(model)
	if watched[model] then
		return
	end
	watched[model] = true
	model.DescendantAdded:Connect(function(d)
		if not show and isOthers(model) then
			task.defer(apply, d, true)
		end
	end)
	model:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refresh(model)
	end)
	refresh(model)
end

folder.ChildAdded:Connect(function(m)
	task.defer(watch, m)
end)
for _, m in folder:GetChildren() do
	watch(m)
end

Settings.Changed("OthersPets", function(value)
	local newShow = value ~= false
	if newShow == show then
		return
	end
	show = newShow
	for _, m in folder:GetChildren() do
		refresh(m)
	end
end)
