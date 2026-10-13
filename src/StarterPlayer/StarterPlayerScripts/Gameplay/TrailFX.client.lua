-- TrailFX: the client-side upgrade of every equipped trail (TrailService puts the plain Trail "KaijuTrail" between
-- KaijuTrailTop / KaijuTrailBottom on the HumanoidRootPart). Follows the VFX reference playbook:
--   core     a narrow white-hot inner trail (value contrast: white core, coloured edges)
--   texture  a textured energy layer in the trail's theme over the colour trail (VFX Studio texture, scrolling)
--   wake     themed particles left behind while running (dust, leaves, frost, void smoke, gold sparks + bolts,
--            flipbook fire + embers, chromatic slivers, shadow smoke + violet flames), with a dark backdrop layer
--            for the dark themes so the bright parts pop
--   pops     Legendary and up: 4-point lens flares with an anamorphic streak at your feet as you run
-- Everything scales with running speed and goes quiet when you stop. Respects Reduced Effects; sleeps beyond RANGE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local TrailConfig = require(Config:WaitForChild("TrailConfig"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local RANGE = 180
local rng = Random.new()
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local STREAK = Enum.ParticleOrientation.VelocityParallel

local function id(n)
	return "rbxassetid://" .. n
end
local function NS(...)
	local p = { ... }
	if #p == 1 then
		return NumberSequence.new(p[1])
	end
	if #p == 2 then
		return NumberSequence.new(p[1], p[2])
	end
	local k = {}
	for i = 1, #p, 2 do
		table.insert(k, NumberSequenceKeypoint.new(p[i], p[i + 1]))
	end
	return NumberSequence.new(k)
end
local function CS(list)
	if #list == 1 then
		return ColorSequence.new(hex(list[1]))
	end
	local k = {}
	for i, c in list do
		table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#list - 1), hex(c)))
	end
	return ColorSequence.new(k)
end
local function NR(a, b)
	b = b or a
	return NumberRange.new(math.min(a, b), math.max(a, b)) -- order-safe (negative spins)
end

local FOURSTAR, ANAMORPHIC = id(14198353638), id(114278596683627)

-- Per trail: Core (colours of the white-hot core, nil = no core), Texture (textured layer), Wake = emitter recipes,
-- Pops = lens-flare colours (nil = none). Wake rates are per second at full running speed.
local THEMES = {
	PebbleDust = {
		Texture = { Image = id(12302665387), Colors = { "#F2EBDD", "#B8B0A0" }, Light = 0.05, Alpha = 0.55, Length = 6 },
		Wake = {
			{ Texture = id(4510290214), Colors = { "#E6DAC0", "#A89A7C" }, Light = 0, Influence = 1, Rate = 14, Size = { 0.6, 2.2 }, Life = { 0.6, 1 }, Alpha = 0.45, Ground = true, Rise = 1 },
			{ Texture = id(131917326401050), Colors = { "#FFFFFF" }, Light = 0, Influence = 1, Rate = 5, Size = { 0.35, 0.2 }, Life = { 0.4, 0.6 }, Ground = true, Hop = true, Flip = Enum.ParticleFlipbookLayout.Grid2x2 },
		},
	},
	JungleLeaf = {
		Core = { "#FFFFFF", "#B6FF8C" },
		Texture = { Image = id(303195022), Colors = { "#B6FF8C", "#2FC22A" }, Light = 0.5, Alpha = 0.35, Length = 5 },
		Wake = {
			{ Texture = id(122342824323639), Colors = { "#B6FF8C", "#3FAF2A" }, Light = 0.2, Influence = 0.6, Rate = 9, Size = { 0.45, 0.3 }, Life = { 1, 1.6 }, Spin = true, Flutter = true },
			{ Texture = id(90431684950883), Colors = { "#FFFFFF", "#9CFF6A" }, Rate = 6, Size = { 0.9, 0 }, Life = { 0.3, 0.5 } },
		},
	},
	FrostBreath = {
		Core = { "#FFFFFF", "#E6F7FF" },
		Texture = { Image = id(16034294138), Colors = { "#E6F7FF", "#5DB8FF" }, Light = 0.6, Alpha = 0.3, Length = 6 },
		Wake = {
			{ Texture = id(2671910894), Colors = { "#F4FAFF", "#BFE6FF" }, Light = 0.3, Influence = 0.8, Rate = 8, Size = { 0.8, 2.4 }, Life = { 0.8, 1.2 }, Alpha = 0.55 },
			{ Texture = id(115439406679930), Colors = { "#FFFFFF", "#9FE8FF" }, Rate = 10, Size = { 0.5, 0 }, Life = { 0.6, 1 }, Spin = true, Fall = true },
			{ Texture = id(7245988767), Colors = { "#FFFFFF", "#7FDFFF" }, Rate = 5, Size = { 0.4, 0.1 }, Life = { 0.5, 0.8 }, Spin = true },
		},
	},
	VoidPlasma = {
		Core = { "#FFFFFF", "#F0C8FF" },
		Texture = { Image = id(131828635123418), Colors = { "#F0C8FF", "#B05CFF", "#5A1FB8" }, Light = 0.8, Alpha = 0.25, Length = 5 },
		Wake = {
			{ Texture = id(291880914), Colors = { "#2A0B4D", "#0A0218" }, Light = 0, Influence = 0.5, Rate = 10, Size = { 1, 2.6 }, Life = { 0.8, 1.2 }, Alpha = 0.35, ZOffset = -1 },
			{ Texture = id(15265616867), Colors = { "#F0C8FF", "#B05CFF" }, Rate = 6, Size = { 0.9, 0 }, Life = { 0.3, 0.5 }, Spin = true },
			{ Texture = id(72740225235951), Colors = { "#3A0F6E", "#000000" }, Light = 0, Influence = 0.5, Rate = 5, Size = { 0.7, 0 }, Life = { 0.5, 0.8 }, Spin = true },
		},
	},
	ThunderGold = {
		Core = { "#FFFFFF", "#FFF6B0" },
		Texture = { Image = id(882168791), Colors = { "#FFFFFF", "#FFE24A", "#FFA000" }, Light = 1, Alpha = 0.15, Length = 4, Speed = 3 },
		Wake = {
			{ Texture = id(12402856027), Colors = { "#FFFFFF", "#FFE24A" }, Rate = 7, Size = { 1.8, 1.8 }, Life = { 0.1, 0.16 }, Bright = 4 },
			{ Texture = "rbxasset://textures/particles/fire_sparks_main.dds", Colors = { "#FFFFFF", "#FFC21F" }, Rate = 22, Size = { 0.3, 0 }, Life = { 0.3, 0.6 }, Burst = 6 },
		},
		Pops = { "#FFFFFF", "#FFD23F" },
	},
	MagmaRoar = {
		Core = { "#FFFFFF", "#FFE24A" },
		Texture = { Image = "", Colors = { "#FFE24A", "#FF8A1F", "#E8301A", "#7A1206" }, Light = 1, Alpha = 0.2, Length = 5 }, -- molten gradient ribbon (the flame sheet is a flipbook, unusable as a trail)
		Wake = {
			{ Texture = id(291880914), Colors = { "#3A1208", "#120604" }, Light = 0, Influence = 0.5, Rate = 9, Size = { 1, 2.8 }, Life = { 0.8, 1.2 }, Alpha = 0.35, ZOffset = -1, Rise = 3 },
			{ Texture = id(126174900723501), Colors = { "#FFE08A", "#FF7A1F", "#B81E00" }, Rate = 14, Size = { 1.4, 0.4 }, Life = { 0.4, 0.6 }, Rise = 4, Flip = Enum.ParticleFlipbookLayout.Grid4x4, OneShot = true, Bright = 2 },
			{ Texture = "rbxasset://textures/particles/fire_sparks_main.dds", Colors = { "#FFE08A", "#FF5A1F" }, Rate = 24, Size = { 0.3, 0 }, Life = { 0.6, 1.1 }, Rise = 5 },
		},
		Pops = { "#FFE24A", "#FF6A1F" },
	},
	PrismRainbow = {
		Core = { "#FFFFFF", "#FFFFFF" },
		Texture = { Image = id(9533207455), Colors = { "#FF4D4D", "#FFF04D", "#4DFF88", "#4DB8FF", "#C44DFF" }, Light = 0.6, Alpha = 0.2, Length = 4, Speed = 2 },
		Wake = {
			{ Texture = id(14221474657), Colors = { "#FFFFFF" }, Rate = 14, Size = { 0.9, 0 }, Life = { 0.4, 0.7 }, Spin = true, Bright = 2 },
			{ Texture = id(73385444872956), Colors = { "#FFFFFF" }, Rate = 8, Size = { 1.2, 0 }, Life = { 0.5, 0.8 } },
		},
		Pops = { "#FFFFFF", "#FF8AE0" },
		Rainbow = true,
	},
	ShadowMonarch = {
		Core = { "#F3EAFF", "#B98AFF" },
		Texture = { Image = id(16034294138), Colors = { "#E6D4FF", "#8A3DFF", "#2A1050" }, Light = 0.5, Alpha = 0.25, Length = 5, Speed = -1.5 },
		Wake = {
			{ Texture = id(4510290214), Colors = { "#1A0833", "#000000" }, Light = 0, Influence = 0.4, Rate = 14, Size = { 1.2, 3 }, Life = { 0.8, 1.3 }, Alpha = 0.25, ZOffset = -1, Rise = 2 },
			{ Texture = id(95682174626496), Colors = { "#E6D4FF", "#8A3DFF" }, Rate = 8, Size = { 1.3, 0.3 }, Life = { 0.35, 0.55 }, Rise = 4, Bright = 2 },
			{ Texture = id(243043091), Colors = { "#FFFFFF", "#8A3DFF" }, Rate = 4, Size = { 1.8, 1.8 }, Life = { 0.1, 0.16 }, Bright = 3 },
		},
		Pops = { "#FFFFFF", "#8A3DFF" },
	},
}

local function reduced()
	return Settings.Get("ReducedEffects") == true
end

local rigs = {} -- [player] = rig

local function clear(p)
	local r = rigs[p]
	rigs[p] = nil
	if r then
		for _, inst in r.instances do
			inst:Destroy()
		end
	end
end

local function build(p)
	clear(p)
	local trailId = p:GetAttribute("EquippedTrail")
	local theme = THEMES[trailId or ""]
	local cfg = TrailConfig.ById[trailId or ""]
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (theme and cfg and hrp) then
		return
	end
	local top, bottom = hrp:FindFirstChild("KaijuTrailTop"), hrp:FindFirstChild("KaijuTrailBottom")
	if not (top and bottom) then
		return
	end
	local r = { player = p, hrp = hrp, theme = theme, instances = {}, wakes = {}, enabled = true, nextPop = 0 }
	local function own(inst)
		table.insert(r.instances, inst)
		return inst
	end
	local function att(name, pos)
		local a = own(Instance.new("Attachment"))
		a.Name = name
		a.Position = pos
		a.Parent = hrp
		return a
	end
	local tp, bp = top.Position, bottom.Position
	-- core: narrow and white-hot
	if theme.Core then
		local c0 = att("TrailFXCoreTop", tp:Lerp(bp, 0.42))
		local c1 = att("TrailFXCoreBottom", tp:Lerp(bp, 0.58))
		local tr = own(Instance.new("Trail"))
		tr.Name = "TrailFXCore"
		tr.Attachment0, tr.Attachment1 = c0, c1
		tr.Color = CS({ theme.Core[1], theme.Core[#theme.Core], theme.Core[#theme.Core] })
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Brightness = 2
		tr.Transparency = NS(0, 0.05, 0.5, 0.5, 1, 1)
		tr.WidthScale = NS(0, 1, 1, 0.1)
		tr.Lifetime = cfg.Lifetime * 0.55
		tr.FaceCamera = true
		tr.MinLength = 0.05
		tr.Parent = hrp
		r.core = tr
	end
	-- textured energy layer
	local tx = theme.Texture
	if tx then
		local tr = own(Instance.new("Trail"))
		tr.Name = "TrailFXTexture"
		tr.Attachment0, tr.Attachment1 = top, bottom
		tr.Texture = tx.Image
		tr.TextureMode = Enum.TextureMode.Wrap
		tr.TextureLength = tx.Length or 5
		local cols = tx.Colors
		if #cols > 2 and cols[1]:upper() == "#FFFFFF" then
			cols = { table.unpack(cols, 2) }
		end
		tr.Color = CS(cols)
		tr.LightEmission = tx.Light or 1
		tr.LightInfluence = (tx.Light or 1) > 0.2 and 0 or 1
		tr.Transparency = NS(0, tx.Alpha or 0.3, 0.6, math.min(1, (tx.Alpha or 0.3) + 0.35), 1, 1)
		tr.WidthScale = NS(0, 1.05, 1, 0.4)
		tr.Lifetime = cfg.Lifetime * 0.9
		tr.FaceCamera = true
		tr.MinLength = 0.05
		tr.Parent = hrp
		r.texture = tr
		r.textureSpeed = tx.Speed or 0
		if (tx.Light or 1) > 0.2 then
			local deep = hex(cols[#cols]):Lerp(Color3.new(0, 0, 0), 0.55)
			local under = own(Instance.new("Trail"))
			under.Name = "TrailFXUnder"
			under.Attachment0, under.Attachment1 = top, bottom
			under.Color = ColorSequence.new(deep)
			under.LightEmission = 0
			under.LightInfluence = 0
			under.Transparency = NS(0, 0.55, 0.5, 0.8, 1, 1)
			under.WidthScale = NS(0, 1.15, 1, 0.5)
			under.Lifetime = cfg.Lifetime * 0.75
			under.FaceCamera = true
			under.MinLength = 0.05
			under.Parent = hrp
		end
	end
	-- wake particles
	local mid = att("TrailFXMid", tp:Lerp(bp, 0.5))
	local feet = att("TrailFXFeet", Vector3.new(0, bp.Y - 0.6, 0.3))
	for _, w in theme.Wake do
		local pe = own(Instance.new("ParticleEmitter"))
		pe.Name = "TrailFXWake"
		pe.Texture = w.Texture
		pe.Color = CS(w.Colors)
		pe.LightEmission = w.Light or 1
		pe.LightInfluence = w.Influence or 0
		pe.Brightness = w.Bright or 1
		pe.Size = NS(0, w.Size[1], 1, w.Size[2])
		pe.Transparency = NS(0, w.Alpha or 0.1, 1, 1)
		pe.Lifetime = NR(w.Life[1], w.Life[2])
		pe.Speed = NR(w.Hop and 5 or 0.3, w.Hop and 9 or 1.2)
		pe.SpreadAngle = Vector2.new(w.Hop and 30 or 180, w.Hop and 30 or 180)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Rotation = NR(0, 360)
		pe.RotSpeed = w.Spin and NR(-180, 180) or NR(-20, 20)
		pe.ZOffset = w.ZOffset or 0
		pe.Drag = w.Flutter and 2 or 1
		pe.Acceleration = w.Hop and Vector3.new(0, -30, 0) or w.Fall and Vector3.new(0, -3, 0) or w.Flutter and Vector3.new(0, -1, 0)
			or Vector3.new(0, w.Rise or 0.5, 0)
		if w.Flip then
			pe.FlipbookLayout = w.Flip
			pe.FlipbookMode = w.OneShot and Enum.ParticleFlipbookMode.OneShot or Enum.ParticleFlipbookMode.Loop
			pe.FlipbookStartRandom = not w.OneShot
		end
		pe.Rate = 0
		pe.Parent = w.Ground and feet or mid
		table.insert(r.wakes, { pe = pe, rate = w.Rate, burst = w.Burst })
	end
	-- lens-flare pops at the feet
	if theme.Pops then
		local function flare(tex, size, life, alpha)
			local pe = own(Instance.new("ParticleEmitter"))
			pe.Name = "TrailFXPop"
			pe.Texture = tex
			pe.Color = CS(theme.Pops)
			pe.LightEmission = 1
			pe.LightInfluence = 0
			pe.Brightness = 4
			pe.Size = NS(0, 0, 0.3, size, 1, 0)
			pe.Transparency = NS(alpha or 0)
			pe.Lifetime = NR(life)
			pe.Speed = NR(0)
			pe.Rate = 0
			pe.Parent = feet
			return pe
		end
		r.pops = { flare(FOURSTAR, 2.2, 0.35), flare(ANAMORPHIC, 4.5, 0.3, 0.15) }
	end
	rigs[p] = r
end

local function watch(p)
	local function later()
		task.delay(0.3, build, p) -- TrailService swaps the trail on the server first
	end
	p:GetAttributeChangedSignal("EquippedTrail"):Connect(later)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(1)
		build(p)
	end)
	if p.Character then
		later()
	end
end
Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerRemoving:Connect(clear)

RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	local scale = reduced() and 0.35 or 1
	local hue = (now * 0.44) % 1
	for p, r in rigs do
		local hrp = r.hrp
		if not hrp.Parent then
			continue
		end
		-- the server rebuilt the trail (re-equip / respawn): rebuild on top of the new one
		if not hrp:FindFirstChild("KaijuTrailTop") then
			task.defer(build, p)
			continue
		end
		local near = (hrp.Position - camPos).Magnitude < RANGE
		local v = hrp.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local run = near and math.clamp((speed - 2) / 14, 0, 1) or 0
		if p:GetAttribute("OnTreadmill") then
			run = near and 0.6 or 0 -- running on the treadmill counts as running
		end
		for _, w in r.wakes do
			w.pe.Rate = w.rate * run * scale
		end
		if r.texture and r.textureSpeed ~= 0 then
			r.texture.TextureLength = r.texture.TextureLength -- keep
		end
		if r.pops and run > 0.4 and now >= r.nextPop then
			r.nextPop = now + rng:NextNumber(0.3, 0.55) / math.max(0.5, run)
			for _, pe in r.pops do
				pe:Emit(1)
			end
		end
		if r.theme.Rainbow then
			local c = ColorSequence.new(Color3.fromHSV(hue, 0.6, 1), Color3.fromHSV((hue + 0.33) % 1, 0.6, 1))
			for _, w in r.wakes do
				w.pe.Color = c
			end
			if r.pops then
				for _, pe in r.pops do
					pe.Color = c
				end
			end
		end
	end
end)
