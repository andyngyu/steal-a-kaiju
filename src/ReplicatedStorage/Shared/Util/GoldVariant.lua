--!strict
-- Recolours a brick kaiju model in gold (the Kaiju Market's Rumblerex NPC, the group-reward Golden Rumblerex and its
-- UI portrait). Each brick keeps its light/dark shading: its brightness picks a shade between deep and pale gold, so
-- the pattern still reads. Near-black bricks (pupils, outlines) stay dark.
local GoldVariant = {}

local DEEP = Color3.fromRGB(150, 88, 8)
local MID = Color3.fromRGB(255, 178, 20)
local PALE = Color3.fromRGB(255, 222, 92)

local function shade(c: Color3): Color3
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	if l < 0.12 then
		return Color3.fromRGB(40, 24, 4)
	end
	if l < 0.5 then
		return DEEP:Lerp(MID, (l - 0.12) / 0.38)
	end
	return MID:Lerp(PALE, (l - 0.5) / 0.5)
end

function GoldVariant.Apply(model: Instance)
	local root = model:IsA("Model") and model.PrimaryPart or nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 1 then
			d.Color = shade(d.Color)
			if d.Material ~= Enum.Material.Neon then
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
		elseif d:IsA("Texture") or d:IsA("Decal") then
			d.Color3 = Color3.fromRGB(255, 214, 110)
		end
	end
end

return GoldVariant
