--!strict
-- Pen-local coordinates, shared by server and client.
-- x = across the pen (0 = entrance centre), d = depth from the front fence inward. Plots differ per session,
-- so saved egg positions are stored in (x, d), never in world space.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseConfig = require(ReplicatedStorage.Shared.Config.BaseConfig)

local PenGeometry = {}

-- Origin at the front-centre of the pen on the ground; LookVector points into the pen.
function PenGeometry.Frame(plot: Model): CFrame
	local origin = plot:GetAttribute("PenOrigin") :: Vector3
	local inward = Vector3.new(0, 0, plot:GetAttribute("Side") :: number)
	return CFrame.lookAt(origin, origin + inward)
end

function PenGeometry.ToWorld(plot: Model, x: number, d: number): Vector3
	return (PenGeometry.Frame(plot) * CFrame.new(x, 0, -d)).Position
end

function PenGeometry.ToLocal(plot: Model, position: Vector3): (number, number)
	local p = PenGeometry.Frame(plot):PointToObjectSpace(position)
	return p.X, -p.Z
end

function PenGeometry.Level(levelIndex: number): BaseConfig.Level
	local levels = BaseConfig.Levels
	return levels[math.clamp(levelIndex, 1, #levels)]
end

function PenGeometry.Contains(levelIndex: number, x: number, d: number, inset: number?): boolean
	local level = PenGeometry.Level(levelIndex)
	local i = inset or 0
	return math.abs(x) <= level.Width / 2 - i and d >= i and d <= level.Depth - i
end

function PenGeometry.Clamp(levelIndex: number, x: number, d: number, inset: number?): (number, number)
	local level = PenGeometry.Level(levelIndex)
	local i = inset or 0
	return math.clamp(x, -level.Width / 2 + i, level.Width / 2 - i), math.clamp(d, i, level.Depth - i)
end

return PenGeometry
