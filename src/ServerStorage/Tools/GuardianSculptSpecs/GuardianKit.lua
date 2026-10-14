-- Shared helpers for the sculpted guardians.
local ServerStorage = game:GetService("ServerStorage")

local GK = {}

-- the kaiju sculpt helpers (a fresh copy, so edits to Helpers show up on the next build)
GK.H = require(ServerStorage.Tools.KaijuSculptSpecs.Helpers:Clone())

-- GuardianService closes the eyes while a guardian sleeps (parts named EyeOpen / EyeClosed): every glowing "Eye" part
-- becomes EyeOpen and gets a dark lid named EyeClosed over it (hidden until it falls asleep).
function GK.lids(K, color)
	for _, p in K.model:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "Eye" then
			p.Name = "EyeOpen"
			local lid = p:Clone()
			lid.Name = "EyeClosed"
			lid.Material = Enum.Material.SmoothPlastic
			lid.Color = color or Color3.fromHex("1A1A14")
			lid.Size = Vector3.new(p.Size.X * 1.2, p.Size.Y * 1.6, p.Size.Z)
			lid.CFrame = p.CFrame * CFrame.new(0, 0, -p.Size.Z * 0.6)
			lid.Transparency = 1
			lid.Parent = p.Parent
		end
	end
end

return GK
