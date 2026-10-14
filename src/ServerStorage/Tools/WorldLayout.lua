-- The new world's measurements (studs), shared by Tools.WorldBuilder (block-out now, art later). Pure data + maths,
-- no instances. The world still runs along +X: Kaiju Citadel (hub) -> Grand Gate on the safe line -> one long canyon
-- of every biome in BiomeConfig.All, back to back, ending at the Void Gate.
--   local L = require(game.ServerStorage.Tools.WorldLayout:Clone())
--   for _, b in L.Biomes() do print(b.Id, b.x0, b.x1, b.nestX) end
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local L = {}

L.SafeX = 302 -- Map attribute SafeZoneX; the Grand Gate stands on it (unchanged from the old map)
L.LaneHalf = 65 -- playable canyon half-width (was 55); the trail runs down the middle
L.PathHalf = 15
L.GateOpenHalf = 55 -- every gate opening is 110 wide (the night barrier at the Grand Gate is 114)
L.CollisionHeight = 90 -- invisible walls over the inner cliffs

-- canyon cliffs, both sides: distance from the centre line (z) and height range; Segment = block length along X
L.Segment = 24
L.Tiers = {
	{ z0 = 65, z1 = 95, h = { 44, 60 } }, -- inner cliff (behind the collision wall)
	{ z0 = 95, z1 = 200, h = { 72, 104 } }, -- second tier
	{ z0 = 200, z1 = 330, h = { 115, 175 } }, -- backdrop ranges (no collision)
}

-- the Citadel (hub): footprint, walls and the Grand Gate. Plot positions are unchanged (MapConfig.Plots).
L.Hub = {
	x0 = -116, x1 = L.SafeX, halfZ = 166,
	wallH = 45, wallT = 8, towerH = 62, towerW = 24,
	towersX = { -116, -20, 76, 172, 268 },
	plaza = Vector3.new(-32, 0, 0), plazaR = 48, fountainR = 20,
	statueH = 65,
	avenueHalf = 20,
	gate = { x = L.SafeX, depth = 26, h = 80, towerZ = { 55, 92 } },
	stalls = { Food = Vector3.new(-47, 0, 25), Trail = Vector3.new(-17, 0, 25), Sell = Vector3.new(-47, 0, -25), Reward = Vector3.new(-17, 0, -23) },
	hallR = 70, -- Hall of Champions colonnade round the plaza's west side
	lots = { 26, 122, 218 }, lotW = 70, lotD = 80, lotFront = 34, -- plots 1-3 at z < 0, 4-6 at z > 0
}

-- per biome: entrance gate (height, look) and hero landmark (kind + where, in biome-local terms)
L.Biome = {
	PebblePlains = { gate = "Grand Gate", gateH = 80, landmark = { kind = "Skull", at = 0.62, side = 1 } },
	LavaLagoon = { gate = "Obsidian Maw", gateH = 72, landmark = { kind = "Volcano", at = 0.6, side = -1 }, window = { at = 0.6, half = 50, side = -1 } },
	FrostfangPeaks = { gate = "Frozen Fangs", gateH = 74, landmark = { kind = "Glacier", at = 0.72, side = 1 } },
	VenomJungle = { gate = "Temple Gate", gateH = 70, landmark = { kind = "Mushrooms", at = 0.45 } },
	SunkenAbyss = { gate = "Coral Gate", gateH = 68, landmark = { kind = "WhaleRibs", at = 0.36 } },
	StormSpires = { gate = "Tesla Gate", gateH = 90, landmark = { kind = "Islands", at = 0.5 } },
	CosmicRift = { gate = "Star Gate", gateH = 76, landmark = { kind = "VoidGate", at = 1.0 } },
}

-- every biome (open and locked) with its X range, nest position and layout data, in lane order
function L.Biomes()
	local BiomeConfig = fresh(ReplicatedStorage.Shared.Config.BiomeConfig)
	local out, x = {}, L.SafeX
	for _, b in BiomeConfig.All do
		local e = table.clone(b)
		e.x0, e.x1 = x, x + b.Length
		e.nestX = x + b.NestAt * b.Length
		e.layout = L.Biome[b.Id] or { gate = b.DisplayName .. " Gate", gateH = 70 }
		table.insert(out, e)
		x = e.x1
	end
	return out
end

function L.EndX()
	local list = L.Biomes()
	return list[#list].x1
end

-- Vista windows: from the trail the cliffs hide anything behind them that isn't both tall and close, so a landmark
-- behind the cliffs gets a window: over [at - half, at + half] (biome fraction / studs) on one side the tiers drop
-- to these fractions of their height, framing it.
L.WindowScale = { 0.4, 0.3, 0.22 }
function L.WindowFactor(b, x, side, tier)
	local w = b.layout and b.layout.window
	if not (w and w.side == side) then
		return 1
	end
	local cx = b.x0 + w.at * b.Length
	local d = math.abs(x - cx)
	if d > w.half then
		return 1
	end
	local edge = math.clamp((w.half - d) / 18, 0, 1) -- stepped shoulders, not a sheer cut
	return 1 - (1 - L.WindowScale[tier]) * edge
end

-- deterministic cliff height for a segment starting at x on one side (blocky: snapped to 2 studs)
function L.CliffHeight(tier, x, side, seed)
	local t = L.Tiers[tier]
	local n = math.noise(x / 70 + (seed or 0) * 0.37, side * 3.1 + tier * 7.7, 0.5) -- about -0.5..0.5
	local k = math.clamp(n + 0.5, 0, 1)
	local h = t.h[1] + (t.h[2] - t.h[1]) * k
	return math.floor(h / 2 + 0.5) * 2
end

return L
