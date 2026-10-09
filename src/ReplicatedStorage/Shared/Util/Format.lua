--!strict
-- Number/time formatting shared by server labels and client UI.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(s: string): string
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s
end

-- 999 -> "999", 1234 -> "1.23K", 15600000 -> "15.6M"
function Format.Short(n: number): string
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local fmt = if n < 10 then "%.2f" elseif n < 100 then "%.1f" else "%.0f"
	return sign .. trim(string.format(fmt, n)) .. SUFFIXES[i]
end

function Format.Money(n: number): string
	return "$" .. Format.Short(n)
end

function Format.PerSecond(n: number): string
	return "$" .. Format.Short(n) .. "/s"
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
