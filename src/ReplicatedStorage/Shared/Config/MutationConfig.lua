--!strict
-- Mutations: a weather event (Shared.Config.WeatherConfig, ServerScriptService.Services.WeatherService) can mutate eggs
-- in the nests and in pens. The mutation stays with the egg (model attribute Mutation, pen entry .Mutation) and passes
-- to the kaiju that hatches from it, multiplying its income on top of size and level (Shared.Util.KaijuStats).
-- Looks: Shared.Util.MutationVisuals recolours the model with Palette and adds the FX below (VFX Studio textures).
--   Palette  deep / mid / pale: each brick keeps its light-dark shading but in these colours (Rainbow = hue sweep)
--   Material bricks switch to this (nil = keep), Reflectance added
--   Glow     the light / tag colour; Colors = particle colour sequence (hex list)
local MutationConfig = {}

MutationConfig.List = {
	{
		Id = "Golden", DisplayName = "Golden", Multiplier = 1.5, Order = 1, Icon = "☀️",
		Glow = "#FFD23F", Colors = { "#FFF6B0", "#FFD23F", "#FF9E1F" },
		Palette = { "#8C5206", "#FFB214", "#FFE27A" }, Material = "SmoothPlastic", Reflectance = 0.12,
		FX = { Main = "rbxassetid://106213021633252", Accent = "rbxassetid://14197583306", Rate = 6 },
	},
	{
		Id = "Shocked", DisplayName = "Shocked", Multiplier = 2, Order = 2, Icon = "⚡",
		Glow = "#5AD8FF", Colors = { "#FFFFFF", "#7FE8FF", "#2E7BFF" },
		Palette = { "#0C2C73", "#2F8BFF", "#C9F6FF" }, Material = "SmoothPlastic", NeonBright = true,
		FX = { Main = "rbxassetid://278520320", Accent = "rbxassetid://103597677385771", Rate = 7, Flicker = true },
	},
	{
		Id = "Frozen", DisplayName = "Frozen", Multiplier = 2, Order = 3, Icon = "❄️",
		Glow = "#9FE8FF", Colors = { "#FFFFFF", "#BFEFFF", "#6FC8FF" },
		Palette = { "#3A7FB0", "#9AD9FF", "#F0FBFF" }, Material = "Ice", Reflectance = 0.1,
		FX = { Main = "rbxassetid://86390398432271", Accent = "rbxassetid://4510290214", Rate = 5, Fall = true },
	},
	{
		Id = "Molten", DisplayName = "Molten", Multiplier = 2.5, Order = 4, Icon = "🌋",
		Glow = "#FF6A1F", Colors = { "#FFE08A", "#FF7A1F", "#B81E00" },
		Palette = { "#1C0A06", "#4A1A0C", "#FF6A1F" }, Material = "Basalt", NeonBright = true,
		FX = { Main = "rbxasset://textures/particles/fire_sparks_main.dds", Accent = "rbxassetid://15811794808", Rate = 10, Rise = true },
	},
	{
		Id = "Diamond", DisplayName = "Diamond", Multiplier = 3, Order = 5, Icon = "💎",
		Glow = "#B8F4FF", Colors = { "#FFFFFF", "#CFF8FF", "#7FDFFF" },
		Palette = { "#5BBFE0", "#C4F5FF", "#FFFFFF" }, Material = "Glass", Reflectance = 0.35,
		FX = { Main = "rbxassetid://14197626379", Accent = "rbxassetid://7245988767", Rate = 6 },
	},
	{
		Id = "Rainbow", DisplayName = "Rainbow", Multiplier = 4, Order = 6, Icon = "🌈", Rainbow = true,
		Glow = "#FF8AF0", Colors = { "#FF4D4D", "#FFE84D", "#4DFF88", "#4DB8FF", "#C44DFF" },
		Palette = { "#FF4D4D", "#FFFFFF", "#C44DFF" }, Material = "SmoothPlastic",
		FX = { Main = "rbxassetid://73385444872956", Accent = "rbxassetid://78694460034696", Rate = 8 },
	},
	{
		Id = "Bloodmoon", DisplayName = "Bloodmoon", Multiplier = 5, Order = 7, Icon = "🩸",
		Glow = "#FF1F3D", Colors = { "#FF8A8A", "#FF1F3D", "#5A0010" },
		Palette = { "#1A0004", "#7A0A1C", "#FF3B4E" }, Material = "SmoothPlastic", NeonBright = true,
		FX = { Main = "rbxassetid://2671910894", Accent = "rbxassetid://12402875536", Rate = 6, Rise = true },
	},
	{
		Id = "Galaxy", DisplayName = "Galaxy", Multiplier = 8, Order = 8, Icon = "🌌",
		Glow = "#9B5CFF", Colors = { "#FFFFFF", "#C9A6FF", "#6A2CFF", "#1B0B4D" },
		Palette = { "#0A0420", "#33188A", "#C8A8FF" }, Material = "SmoothPlastic", NeonBright = true,
		FX = { Main = "rbxassetid://134563328683175", Accent = "rbxassetid://8210105100", Rate = 8, Orbit = true },
	},
}

MutationConfig.ById = {}
for _, m in MutationConfig.List do
	MutationConfig.ById[m.Id] = m
end

-- Income multiplier for a mutation id (1 for none / unknown).
function MutationConfig.Multiplier(id: string?): number
	local m = id and MutationConfig.ById[id]
	return m and m.Multiplier or 1
end

-- "Shocked " (with the space) or "" - put in front of an egg / kaiju name.
function MutationConfig.Prefix(id: string?): string
	local m = id and MutationConfig.ById[id]
	return m and (m.DisplayName .. " ") or ""
end

-- Icon art for each mutation (the designer's weather icons; the emoji Icon fields are only a text fallback).
MutationConfig.Images = {
	Golden = "rbxassetid://138091978151722", -- sun
	Shocked = "rbxassetid://100025630781095", -- lightning
	Frozen = "rbxassetid://127309455403576", -- snowflake
	Molten = "rbxassetid://101806306419298", -- volcano
	Diamond = "rbxassetid://111219280491679", -- diamond
	Rainbow = "rbxassetid://93031476821507", -- rainbow
	Bloodmoon = "rbxassetid://137507026671790", -- red moon
	Galaxy = "rbxassetid://124958356347158", -- eclipse
}
function MutationConfig.Image(id: string?): string
	return id and MutationConfig.Images[id] or ""
end

function MutationConfig.Color(id: string?): Color3
	local m = id and MutationConfig.ById[id]
	return m and Color3.fromHex(m.Glow) or Color3.new(1, 1, 1)
end

return MutationConfig
