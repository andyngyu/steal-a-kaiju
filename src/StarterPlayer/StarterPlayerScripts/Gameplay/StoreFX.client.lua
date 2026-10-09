-- Robux store client side (ServerScriptService.Services.GamePassService):
--   VIP chat tag ("[VIP]" in gold before the name of any player whose VIP attribute is true),
--   a celebration burst + toast on every purchase (GameEvent StorePurchased; trails and upgrades already get their own
--   TrailBought / PenUpgraded / TreadmillUpgraded toasts from the UI, so only passes and bundles toast here),
--   a lucky sparkle around every player while their timed Luck Bundle runs (EggLuckUntil > server time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local StoreConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StoreConfig"))

local player = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromHex("FFD23F")

local UIApi
task.spawn(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("KaijuUI", 30)
	local module = gui and gui:WaitForChild("UIApi", 10)
	if module then
		local ok, api = pcall(require, module)
		if ok then
			UIApi = api
		end
	end
end)

local function toast(text)
	if UIApi and UIApi.Toast then
		pcall(UIApi.Toast, text, "info")
	end
end

-- ---------- VIP chat tag ----------

TextChatService.OnIncomingMessage = function(message)
	local source = message.TextSource
	local from = source and Players:GetPlayerByUserId(source.UserId)
	if from and from:GetAttribute("VIP") then
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = string.format('<font color="%s">[%s]</font> %s', StoreConfig.VIPTag.Color, StoreConfig.VIPTag.Text, message.PrefixText)
		return props
	end
	return nil
end

-- ---------- purchase celebration ----------

local function burst()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "StoreBurst"
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.35, Color3.fromHex("FF5FA8")),
		ColorSequenceKeypoint.new(0.7, Color3.fromHex("5FD8FF")),
		ColorSequenceKeypoint.new(1, GOLD),
	})
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(14, 26)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -18, 0)
	pe.Drag = 2
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(80)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 18
	light.Brightness = 4
	light.Parent = att
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(att, 2)
end

local TOASTS = {
	GamePass = function(d)
		return d.DisplayName .. " unlocked! Thanks for the support!"
	end,
	Bundle = function(d)
		if d.ItemId == "LuckBundle" then
			return "Egg luck boosted for 30 minutes!"
		end
		return d.DisplayName .. " delivered!"
	end,
}

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent").OnClientEvent:Connect(function(name, data)
	if name ~= "StorePurchased" or type(data) ~= "table" then
		return
	end
	burst()
	local text = TOASTS[data.Kind] and TOASTS[data.Kind](data)
	if text then
		toast(text)
	end
end)

-- ---------- lucky sparkle while the Luck Bundle runs ----------

local function setLuckAura(other, on)
	local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local aura = hrp:FindFirstChild("LuckAura")
	if on and not aura then
		aura = Instance.new("ParticleEmitter")
		aura.Name = "LuckAura"
		aura.Texture = SPARKLE
		aura.Color = ColorSequence.new(Color3.fromHex("7CFF6B"), GOLD)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.1, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.3)
		aura.Speed = NumberRange.new(0.5, 1.5)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Acceleration = Vector3.new(0, 2.5, 0)
		aura.Rate = 12
		aura.Parent = hrp
	elseif not on and aura then
		aura:Destroy()
	end
end

task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		for _, other in Players:GetPlayers() do
			local untilTime = other:GetAttribute("EggLuckUntil")
			setLuckAura(other, type(untilTime) == "number" and untilTime > now)
		end
		task.wait(1)
	end
end)
