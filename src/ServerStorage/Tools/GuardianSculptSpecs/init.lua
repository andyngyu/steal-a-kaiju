-- Sculpted biome guardians (built by Tools.KaijuSculpt through Tools.BiomeArtBuilder.BuildGuardian). One child module
-- per guardian (Guardian_<BiomeId>) returning a KaijuSculpt spec plus the rig fields BuildGuardian needs: RootSize and
-- HipHeight (kept from the old guardians so GuardianService's reach and footing are unchanged), Joints for LegL / LegR /
-- ArmL / ArmR / Head / Jaw (parent Head) / Tail. GuardianKit holds shared helpers.
local specs = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and child.Name ~= "GuardianKit" then
		specs[child.Name] = require(child)
	end
end
return specs
