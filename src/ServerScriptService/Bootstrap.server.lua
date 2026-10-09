--!strict
-- Loads every ModuleScript in ServerScriptService.Services, calls :Init() on all of them, then :Start().
-- Init: create remotes/state, no cross-service calls. Start: connect events, run loops.
local ServerScriptService = game:GetService("ServerScriptService")

local servicesFolder = ServerScriptService:WaitForChild("Services")

type Service = {
	Init: ((any) -> ())?,
	Start: ((any) -> ())?,
}

local names: { string } = {}
local services: { [string]: Service } = {}

for _, module in servicesFolder:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		services[module.Name] = result
		table.insert(names, module.Name)
	else
		warn(`[Bootstrap] failed to load {module.Name}: {result}`)
	end
end
table.sort(names)

for _, name in names do
	local service = services[name]
	if service.Init then
		local ok, err = xpcall(service.Init, debug.traceback, service)
		if not ok then
			warn(`[Bootstrap] {name}:Init failed: {err}`)
		end
	end
end

for _, name in names do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print(`[Bootstrap] started {#names} service(s)`)
