-- Edit-time tool: exports the game's code to the local git working tree (steal-a-kaiju). Studio can't write files, so
-- each script is POSTed to a small listener on this PC (localhost only, export_listener.ps1) that writes it to disk.
-- Allow HTTP Requests is switched on only for the length of an export and always switched back off after it.
--   local E = require(game.ServerStorage.Tools.RepoExport:Clone())
--   E.Current("current")        every script, laid out Rojo-style under src/<Service>/...
--   E.Backups("snap")           the older versions kept in ServerStorage.Backups, mapped to the same paths
-- Layout: a ModuleScript is <Name>.lua, a Script <Name>.server.lua, a LocalScript (or a client Script) <Name>.client.lua;
-- a script with scripts inside it becomes a folder with init[.server|.client].lua. Folders and models are folders.
-- Left out: the teammate's UI (StarterGui.KaijuUI), ServerStorage.Backups (exported only through E.Backups), and the
-- model / asset folders (no code in them).
local HttpService = game:GetService("HttpService")

local E = {}

E.URL = "http://localhost:8765"
E.SERVICES = { "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "Workspace" }
local EXCLUDE = { "StarterGui.KaijuUI", "ServerStorage.Backups", "ServerStorage.LockedLaneProps", "ServerStorage.Assets" }

local function excluded(inst)
	local full = inst:GetFullName()
	for _, e in EXCLUDE do
		if full == e or full:sub(1, #e + 1) == e .. "." then
			return true
		end
	end
	return false
end

local function safe(name)
	return (name:gsub('[<>:"/\\|%?%*]', "_"))
end

local function hasScriptChildren(inst)
	for _, c in inst:GetChildren() do
		if c:IsA("LuaSourceContainer") then
			return true
		end
	end
	return false
end

local function ext(s)
	if s:IsA("ModuleScript") then
		return ".lua"
	elseif s:IsA("LocalScript") or (s:IsA("Script") and s.RunContext == Enum.RunContext.Client) then
		return ".client.lua"
	end
	return ".server.lua"
end

-- the repo path of a script in the live tree
function E.PathOf(s)
	local parts = {}
	local p = s.Parent
	while p and p.Parent ~= game do
		table.insert(parts, 1, safe(p.Name))
		p = p.Parent
	end
	local service = p and p.Name or "Unknown"
	local dir = "src/" .. service .. (#parts > 0 and ("/" .. table.concat(parts, "/")) or "")
	if hasScriptChildren(s) then
		return dir .. "/" .. safe(s.Name) .. "/init" .. ext(s)
	end
	return dir .. "/" .. safe(s.Name) .. ext(s)
end

-- every exported script in the live tree
function E.Scripts()
	local list = {}
	for _, name in E.SERVICES do
		local svc = game:FindFirstChild(name) or game:GetService(name)
		for _, d in svc:GetDescendants() do
			if d:IsA("LuaSourceContainer") and not excluded(d) then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function withHttp(fn)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, res = pcall(fn)
	HttpService.HttpEnabled = was
	if not ok then
		error(res, 0)
	end
	return res
end

local function post(root, path, body)
	local url = E.URL .. "/write?root=" .. HttpService:UrlEncode(root) .. "&path=" .. HttpService:UrlEncode(path)
	HttpService:PostAsync(url, body, Enum.HttpContentType.TextPlain)
end

local function clear(root)
	HttpService:PostAsync(E.URL .. "/clear?root=" .. HttpService:UrlEncode(root), "", Enum.HttpContentType.TextPlain)
end

-- the live tree into <root>/ (wiped first, so deleted scripts disappear)
function E.Current(root)
	return withHttp(function()
		clear(root)
		local n, bytes = 0, 0
		for _, s in E.Scripts() do
			post(root, E.PathOf(s), s.Source)
			n += 1
			bytes += #s.Source
			if n % 25 == 0 then
				task.wait()
			end
		end
		return string.format("%d scripts, %d KB", n, math.floor(bytes / 1024))
	end)
end

-- a backup's name -> the live script it is a copy of ("Tools_BiomeArtBuilder", "CanyonBuilder_v3", "Helpers_spec" ...)
local function liveName(name)
	local n = name:gsub("^Tools_", ""):gsub("^Config_", ""):gsub("^Gameplay_", ""):gsub("^Service_", ""):gsub("^Lib_", "")
	n = n:gsub("_spec$", ""):gsub("_v%d+.*$", ""):gsub("_ToughV%d+$", ""):gsub("_%d%d%d%d%-%d%d%-%d%d.*$", "")
	return n
end

-- the older versions in ServerStorage.Backups, each backup into <prefix>/<NN>_<backup name>/ under the live paths
-- (a backed-up script whose live copy is gone keeps its place next to its parent). UI backups are skipped.
function E.Backups(prefix)
	local live = E.Scripts()
	local byName = {}
	for _, s in live do
		byName[s.Name] = byName[s.Name] or {}
		table.insert(byName[s.Name], s)
	end
	local report = {}
	return withHttp(function()
		clear(prefix)
		for i, b in game:GetService("ServerStorage").Backups:GetChildren() do
			local root = string.format("%s/%02d_%s", prefix, i, b.Name)
			local items = b:IsA("LuaSourceContainer") and { b } or b:GetChildren()
			local n, missed = 0, {}
			-- map one backed-up script (and the scripts inside it) onto the live tree
			local function map(item, liveInst, liveDir)
				local path
				if liveInst then
					path = E.PathOf(liveInst)
				else
					path = liveDir .. "/" .. safe(item.Name) .. (hasScriptChildren(item) and ("/init" .. ext(item)) or ext(item))
				end
				post(root, path, item.Source)
				n += 1
				local dir = path:match("^(.*)/init[%w%.]*$") or path:gsub("%.%w+%.lua$", ""):gsub("%.lua$", "")
				for _, c in item:GetChildren() do
					if c:IsA("LuaSourceContainer") then
						map(c, liveInst and liveInst:FindFirstChild(c.Name), dir)
					end
				end
			end
			for _, item in items do
				if item:IsA("LuaSourceContainer") and not item.Name:match("^UI_") then
					local cands = byName[liveName(item.Name)]
					if cands and #cands == 1 then
						map(item, cands[1], nil)
					else
						table.insert(missed, item.Name .. (cands and ("(x" .. #cands .. ")") or "(none)"))
					end
				end
			end
			if n > 0 or #missed > 0 then
				table.insert(report, string.format("%02d %s: %d%s", i, b.Name, n, #missed > 0 and (" | unmapped: " .. table.concat(missed, ", ")) or ""))
			end
			task.wait()
		end
		return table.concat(report, "\n")
	end)
end

return E
