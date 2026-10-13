-- Sculpted kaiju specs for ServerStorage.Tools.KaijuSculpt (2026-10-13 direction: cool and menacing monsters). One
-- child ModuleScript per species returns its spec (Palette, Joints, Parents, Gait, Emotes, Seed, Vary, Build(K));
-- Helpers holds the shared building blocks. Build space: feet on y = 0, facing -Z, +X = the kaiju's left.
local specs = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and child.Name ~= "Helpers" then
		specs[child.Name] = require(child)
	end
end
return specs
