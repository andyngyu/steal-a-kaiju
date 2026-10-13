-- Mutation looks (Shared.Config.MutationConfig), used on the server for world eggs / kaiju and on clients for UI
-- portraits and the hatch reveal, so a mutated thing looks the same everywhere.
--   Recolor(model, id)        every visible brick keeps its light-dark shading but in the mutation's palette
--                             (Rainbow sweeps the hue around the model); material / reflectance / neon highlights
--   AddFX(model, id, scale)   an invisible "MutationAura" box around the model with VFX Studio particles + a light
--   Tag(adornee, id, height)  a small floating "⚡ Shocked x2" label (eggs)
--   RichName(id, name)        '<font color=...>Shocked</font> Rumblerex' for TextLabels with RichText on
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)

local MutationVisuals = {}

local hex = Color3.fromHex
local RAINBOW = { "#FF4D4D", "#FFB84D", "#FFF04D", "#4DFF88", "#4DB8FF", "#C44DFF" }

local function seq(list)
	if #list == 1 then
		return ColorSequence.new(hex(list[1]))
	end
	local kps = {}
	for i, h in list do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), hex(h)))
	end
	return ColorSequence.new(kps)
end
MutationVisuals.Sequence = seq

local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function shade(pal, c)
	local l = lum(c)
	if l < 0.1 then
		return pal[1]:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	if l < 0.5 then
		return pal[1]:Lerp(pal[2], (l - 0.1) / 0.4)
	end
	return pal[2]:Lerp(pal[3], (l - 0.5) / 0.5)
end

function MutationVisuals.Recolor(model, id)
	local m = id and MutationConfig.ById[id]
	if not m then
		return
	end
	local pal = { hex(m.Palette[1]), hex(m.Palette[2]), hex(m.Palette[3]) }
	local material = m.Material and Enum.Material[m.Material]
	local root = model:IsA("Model") and model.PrimaryPart or nil
	local centre = model:IsA("Model") and model:GetPivot().Position or Vector3.zero
	if model:IsA("Model") then
		local cf = model:GetBoundingBox()
		centre = cf.Position
	end
	-- NeonBright only lights up a few small pale accent parts. Pastel species (e.g. Prismling: 65 of 77 parts
	-- pale) would otherwise turn almost entirely Neon, and at giant scale the bloom whites out the screen.
	local glowParts = {}
	if m.NeonBright then
		local pale, total = {}, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= root and d.Transparency < 1 and d.Name ~= "MutationAura" and d.Name ~= "Aura" then
				total += 1
				if d.Material ~= Enum.Material.Neon and lum(d.Color) > 0.72 then
					table.insert(pale, d)
				end
			end
		end
		table.sort(pale, function(a, b)
			return a.Size.X * a.Size.Y * a.Size.Z < b.Size.X * b.Size.Y * b.Size.Z
		end)
		for i = 1, math.min(#pale, math.floor(total * 0.15)) do
			glowParts[pale[i]] = true
		end
	end
	local neonColor = pal[3]:Lerp(pal[2], 0.3) -- slightly deeper than the palette highlight so bloom keeps its hue
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 1 and d.Name ~= "MutationAura" and d.Name ~= "Aura" then
			local l = lum(d.Color)
			local wasNeon = d.Material == Enum.Material.Neon
			if m.Rainbow then
				local o = d.Position - centre
				local h = ((math.atan2(o.Z, o.X) / (math.pi * 2)) + o.Y * 0.06) % 1
				d.Color = l < 0.1 and Color3.fromHSV(h, 0.6, 0.25) or Color3.fromHSV(h, 0.72, 0.6 + 0.4 * math.min(1, l * 1.3))
			else
				d.Color = shade(pal, d.Color)
			end
			if wasNeon or glowParts[d] then
				d.Material = Enum.Material.Neon
				if not m.Rainbow then
					d.Color = neonColor
				end
			elseif material then
				d.Material = material
			end
			if m.Reflectance and d.Material ~= Enum.Material.Neon then
				d.Reflectance = m.Reflectance
			end
		elseif d:IsA("Texture") or d:IsA("Decal") then
			d.Color3 = pal[2]
		end
	end
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.LightEmission = 1
	pe.LightInfluence = 0
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

-- Particles + light in an invisible box around the model (or inside `part` when given a BasePart).
function MutationVisuals.AddFX(target, id, scale)
	local m = id and MutationConfig.ById[id]
	if not m then
		return nil
	end
	scale = scale or 1
	local holder
	if target:IsA("BasePart") then
		holder = target
	else
		local old = target:FindFirstChild("MutationAura")
		if old then
			old:Destroy()
		end
		local cf, ext = target:GetBoundingBox()
		holder = Instance.new("Part")
		holder.Name = "MutationAura"
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanTouch = false
		holder.CanQuery = false
		holder.CastShadow = false
		holder.Massless = true
		holder.Size = ext * 0.9
		holder.CFrame = cf
		holder.Parent = target
		scale = math.clamp(math.max(scale, ext.Magnitude / 8), 1, 3.5)
	end
	local colors = seq(m.Colors)
	local fx = m.FX
	local main = emitter(holder, {
		Name = "MutationMain",
		Texture = fx.Main,
		Color = colors,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, 0.45 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.9, 1.7),
		Speed = NumberRange.new(0.2, 1),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
		Rate = fx.Rate * math.clamp(scale, 1, 2.5),
		Acceleration = fx.Rise and Vector3.new(0, 2.5, 0) or fx.Fall and Vector3.new(0, -2, 0) or Vector3.zero,
	})
	if fx.Orbit then
		main.Rate = fx.Rate * 0.6 * math.clamp(scale, 1, 2.5)
		main.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 1.1 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		main.RotSpeed = NumberRange.new(40, 90)
	end
	emitter(holder, {
		Name = "MutationAccent",
		Texture = fx.Accent,
		Color = colors,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2 * scale),
			NumberSequenceKeypoint.new(0.4, (fx.Flicker and 1.1 or 0.8) * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = fx.Flicker and NumberRange.new(0.12, 0.25) or NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0, 0.3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		Rate = (fx.Flicker and 2.5 or 1.4) * math.clamp(scale, 1, 2),
	})
	local light = holder:FindFirstChild("MutationLight") or Instance.new("PointLight")
	light.Name = "MutationLight"
	light.Color = hex(m.Glow)
	light.Brightness = 1.2
	light.Range = math.clamp(8 * scale, 8, 30)
	light.Shadows = false
	light.Parent = holder
	return holder
end

-- '<font color="#5AD8FF">Shocked</font> Rumblerex' (Rainbow colours each letter).
function MutationVisuals.RichName(id, name)
	local m = id and MutationConfig.ById[id]
	if not m then
		return name
	end
	local word
	if m.Rainbow then
		local parts = {}
		local i = 0
		for _, ch in utf8.codes(m.DisplayName) do
			i += 1
			table.insert(parts, string.format('<font color="%s">%s</font>', RAINBOW[(i - 1) % #RAINBOW + 1], utf8.char(ch)))
		end
		word = table.concat(parts)
	else
		word = string.format('<font color="%s">%s</font>', m.Glow, m.DisplayName)
	end
	return name and (word .. " " .. name) or word
end

-- "⚡ Shocked x2" floating over an egg. heightStuds = how far above the adornee's centre.
function MutationVisuals.Tag(adornee, id, heightStuds, sizeScale)
	local m = id and MutationConfig.ById[id]
	local old = adornee:FindFirstChild("MutationTag")
	if old then
		old:Destroy()
	end
	if not m then
		return nil
	end
	sizeScale = sizeScale or 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "MutationTag"
	bb.Size = UDim2.fromOffset(170 * sizeScale, 34 * sizeScale)
	bb.StudsOffsetWorldSpace = Vector3.new(0, heightStuds, 0)
	bb.MaxDistance = 110
	bb.LightInfluence = 0
	-- the mutation's icon art on the left, then "Shocked x2"
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.2, 1)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Size = UDim2.fromScale(1, 1)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = MutationConfig.Image(id)
	icon.Parent = bb
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.21, 0)
	label.Size = UDim2.fromScale(0.79, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = MutationVisuals.RichName(id) .. string.format(' <font color="#6BE04A">x%s</font>', tostring(m.Multiplier))
	local stroke = Instance.new("UIStroke")
	stroke.Color = hex("1A1033")
	stroke.Thickness = 2.5 * sizeScale
	stroke.Parent = label
	label.Parent = bb
	bb.Parent = adornee
	return bb
end

return MutationVisuals
