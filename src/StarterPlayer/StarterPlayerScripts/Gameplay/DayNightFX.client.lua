-- The day / night cycle on this client (ServerScriptService.Services.DayNightService runs the real thing):
--   sky   the sun crosses from 9:00 to 17:00 over the day; the night swings through dusk, midnight and dawn, darker
--         and bluer, then back to 9:00 as day breaks
--   wall  the NightBarrier's countdown (moon icon + seconds until day)
-- The phase comes from workspace attribute DayNightEpoch (Shared.Config.DayNightConfig.Phase).
-- Weather events (Gameplay.WeatherFX) lean on the same lighting through Lighting attributes: WeatherDark (0..1, darker
-- like the night), WeatherAmbient (Color3 the ambient tints to as it darkens), WeatherClock + WeatherClockBlend (pull
-- the sky clock towards an hour: a Blood Moon at midnight, dusk for meteors).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNightConfig = require(ReplicatedStorage.Shared.Config.DayNightConfig)

local DAY_START, DAY_END = 9, 17 -- clock hours the sun covers during the day
local NIGHT_AMBIENT = Color3.fromHex("#3A4166")
local NIGHT_OUTDOOR = Color3.fromHex("#4A5694")

local base = {
	Brightness = Lighting.Brightness,
	ExposureCompensation = Lighting.ExposureCompensation,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local wall, wallTime, wallIcon
local function findWall()
	local map = workspace:FindFirstChild("Map")
	wall = map and map:FindFirstChild("NightBarrier")
	local gui = wall and wall:FindFirstChild("Countdown")
	wallTime = gui and gui:FindFirstChild("Time", true)
	wallIcon = gui and gui:FindFirstChild("Icon", true)
end

RunService.RenderStepped:Connect(function()
	local epoch = workspace:GetAttribute("DayNightEpoch")
	if not epoch then
		return
	end
	local night, left = DayNightConfig.Phase(workspace:GetServerTimeNow(), epoch)
	local clock, dark
	if night then
		local q = 1 - left / DayNightConfig.NightSeconds -- 0 dusk .. 1 dawn
		if q < 0.2 then
			clock = DAY_END + (22 - DAY_END) * smooth(q / 0.2)
		elseif q < 0.8 then
			clock = 22 + 5 * ((q - 0.2) / 0.6) -- 22:00 through midnight to 03:00
		else
			clock = 27 + (DAY_START + 24 - 27) * smooth((q - 0.8) / 0.2)
		end
		dark = smooth(q / 0.2) * (1 - smooth((q - 0.8) / 0.2))
	else
		local p = 1 - left / DayNightConfig.DaySeconds
		clock = DAY_START + (DAY_END - DAY_START) * p
		dark = 0
	end
	local wDark = Lighting:GetAttribute("WeatherDark")
	wDark = type(wDark) == "number" and math.clamp(wDark, 0, 1) or 0
	local wClock, wBlend = Lighting:GetAttribute("WeatherClock"), Lighting:GetAttribute("WeatherClockBlend")
	if type(wClock) == "number" and type(wBlend) == "number" and wBlend > 0 then
		local diff = ((wClock - clock + 12) % 24) - 12
		clock += diff * math.clamp(wBlend, 0, 1)
	end
	local wAmbient = Lighting:GetAttribute("WeatherAmbient")
	local total = math.max(dark, wDark)
	Lighting.ClockTime = clock % 24
	Lighting.Brightness = base.Brightness * (1 - 0.55 * total)
	Lighting.ExposureCompensation = base.ExposureCompensation - 0.35 * total
	local ambient = base.Ambient:Lerp(NIGHT_AMBIENT, dark)
	local outdoor = base.OutdoorAmbient:Lerp(NIGHT_OUTDOOR, dark)
	if wDark > 0 and typeof(wAmbient) == "Color3" then
		ambient = ambient:Lerp(wAmbient, wDark)
		outdoor = outdoor:Lerp(wAmbient:Lerp(Color3.new(1, 1, 1), 0.25), wDark)
	end
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = outdoor

	if not (wall and wall.Parent and wallTime) then
		findWall()
	end
	if wallTime then
		wallTime.Text = night and (tostring(math.ceil(left)) .. "s") or ""
	end
	if wallIcon then
		wallIcon.Image = DayNightConfig.Icons.Night
		wallIcon.Visible = DayNightConfig.Icons.Night ~= ""
	end
end)
