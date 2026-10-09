--!strict
-- Studio-only test settings. Every flag is forced off in live servers, so it is safe to leave these on while developing.
local RunService = game:GetService("RunService")

local IN_STUDIO = RunService:IsStudio()

-- Edit these while testing in Studio.
local studio = {
	FastHatch = true,
	FastHatchSeconds = 5,

	FastRaids = true,
	FastRaidIntervalSeconds = 120,

	AdminCommands = true, -- give-cash / give-egg chat commands
	VerboseLogging = true,
}

return table.freeze({
	InStudio = IN_STUDIO,

	FastHatch = IN_STUDIO and studio.FastHatch,
	FastHatchSeconds = studio.FastHatchSeconds,

	FastRaids = IN_STUDIO and studio.FastRaids,
	FastRaidIntervalSeconds = studio.FastRaidIntervalSeconds,

	AdminCommands = IN_STUDIO and studio.AdminCommands,
	VerboseLogging = IN_STUDIO and studio.VerboseLogging,
})
