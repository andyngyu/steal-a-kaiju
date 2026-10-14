-- Edit-time performance pass over workspace.Map, with no visible change. Re-run it after any builder rebuilds an area
-- (the builders add the stud textures and shadows back).
--   local O = require(game.ServerStorage.Tools.MapOptimizer:Clone())
--   O.Run()                      everything below, over the whole map (except Plots / Leaderboards / Spawn)
--   O.Run({ workspace.Map.Lane.LavaLagoon })   just those
-- What it does:
--   * removes stud Textures that can't be seen: on a face narrower than half a stud tile (no stud fits), or on a face
--     that lies against / inside a single opaque block that covers it completely (masonry joints, stacked strata, parts
--     buried in parts)
--   * stops tiny parts (no side over 2 studs), Neon parts and see-through parts casting shadows (their shadows are
--     a few pixels, but every caster costs shadow-map time)
-- Returns a report. Nothing collides, moves or changes colour.
local O = {}

local SKIP = { Plots = true, Leaderboards = true, Spawn = true }

local function faceInfo(p, f)
	local s = p.Size
	local n, a, b, ua, ub
	if f == Enum.NormalId.Top then
		n, a, b, ua, ub = Vector3.yAxis, s.X, s.Z, Vector3.xAxis, Vector3.zAxis
	elseif f == Enum.NormalId.Bottom then
		n, a, b, ua, ub = -Vector3.yAxis, s.X, s.Z, Vector3.xAxis, Vector3.zAxis
	elseif f == Enum.NormalId.Front then
		n, a, b, ua, ub = -Vector3.zAxis, s.X, s.Y, Vector3.xAxis, Vector3.yAxis
	elseif f == Enum.NormalId.Back then
		n, a, b, ua, ub = Vector3.zAxis, s.X, s.Y, Vector3.xAxis, Vector3.yAxis
	elseif f == Enum.NormalId.Right then
		n, a, b, ua, ub = Vector3.xAxis, s.Z, s.Y, Vector3.zAxis, Vector3.yAxis
	else
		n, a, b, ua, ub = -Vector3.xAxis, s.Z, s.Y, Vector3.zAxis, Vector3.yAxis
	end
	local half = math.abs(n.X) * s.X / 2 + math.abs(n.Y) * s.Y / 2 + math.abs(n.Z) * s.Z / 2
	return n, a, b, ua, ub, half
end

-- is the world point inside box part q (with a little tolerance)?
local function inside(q, w)
	local l = q.CFrame:PointToObjectSpace(w)
	local h = q.Size / 2 + Vector3.new(0.02, 0.02, 0.02)
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

local function opaqueBox(q)
	return q.ClassName == "Part" and q.Shape == Enum.PartType.Block and q.Transparency == 0
end

function O.Run(roots)
	local map = workspace:FindFirstChild("Map")
	if not roots then
		roots = {}
		for _, c in map:GetChildren() do
			if not SKIP[c.Name] then
				table.insert(roots, c)
			end
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	local tiny, hidden, kept, shadows, checked = 0, 0, 0, 0, 0
	for _, root in roots do
		local list = root:GetDescendants()
		for i, d in list do
			if d:IsA("Texture") and d.Parent and d.Parent:IsA("BasePart") then
				local p = d.Parent
				local n, a, b, ua, ub, half = faceInfo(p, d.Face)
				local tile = math.max(d.StudsPerTileU, d.StudsPerTileV)
				if math.min(a, b) < tile * 0.5 then
					d:Destroy()
					tiny += 1
				else
					checked += 1
					-- a thin slab just outside the face, a little smaller than it
					local cf = p.CFrame
					local wn = cf:VectorToWorldSpace(n)
					local wa, wb = cf:VectorToWorldSpace(ua), cf:VectorToWorldSpace(ub)
					local centre = cf.Position + wn * (half + 0.06)
					local ea, eb = a / 2 - 0.1, b / 2 - 0.1
					local corners = {
						centre + wa * ea + wb * eb,
						centre + wa * ea - wb * eb,
						centre - wa * ea + wb * eb,
						centre - wa * ea - wb * eb,
						centre,
					}
					params.FilterDescendantsInstances = { p }
					local slab = CFrame.fromMatrix(centre, wa, wb, wn)
					local found = workspace:GetPartBoundsInBox(slab, Vector3.new(a - 0.2, b - 0.2, 0.04), params)
					local covered = false
					for _, q in found do
						if opaqueBox(q) then
							local all = true
							for _, c in corners do
								if not inside(q, c) then
									all = false
									break
								end
							end
							if all then
								covered = true
								break
							end
						end
					end
					if covered then
						d:Destroy()
						hidden += 1
					else
						kept += 1
					end
				end
			elseif d:IsA("BasePart") and d.CastShadow then
				local s = d.Size
				if math.max(s.X, s.Y, s.Z) <= 2 or d.Material == Enum.Material.Neon or d.Transparency > 0 then
					d.CastShadow = false
					shadows += 1
				end
			end
			if i % 400 == 0 then
				task.wait()
			end
		end
	end
	return string.format("textures removed: %d on faces too small for a stud, %d on covered faces (%d checked, %d kept); shadows off on %d tiny / neon / see-through parts", tiny, hidden, checked, kept, shadows)
end

return O
