-- The soundpack's own shortcut keys, for keys that MUSHclient's macros don't
-- cover. They're kept in worlds\empire\keys.txt, one per line: the key, a
-- space, then the command it sends, like "Ctrl+Shift+B inventory".
--
-- spkey <key> <command>: makes or changes a key and saves it
-- spkey <key>: removes a key
-- spkeys: lists them

local root = string.gsub(GetInfo(56), "[\\/]+$", "")
local KEYS_FILE = root .. "\\worlds\\empire\\keys.txt"

local HEADER = "# The soundpack's shortcut keys. Each line is a key, a space, then the\r\n"
	.. "# command it sends, like: Ctrl+Shift+B inventory\r\n"
	.. "# Change them in MUSHclient with spkey, or edit this file and restart.\r\n"

-- the keys in file order, each { key = "Alt+I", send = "north" }; kept
-- across reloads so the old ones can be cleared
local keys = empire_soundpack_keys or {}

-- "Shift+Ctrl+K" and "ctrl+shift+k" are the same key
local function same_key(a, b)
	local function norm(k)
		local parts = {}
		for part in string.gmatch(string.lower(k), "[^+%s]+") do
			table.insert(parts, part)
		end
		local last = table.remove(parts)
		table.sort(parts)
		return table.concat(parts, "+") .. "+" .. (last or "")
	end
	return norm(a) == norm(b)
end

local function find(key)
	for i, k in ipairs(keys) do
		if same_key(k.key, key) then
			return i
		end
	end
end

-- what a key already does, if something else (a plugin, say) set it
local function used_for(key)
	for _, entry in ipairs(AcceleratorList() or {}) do
		local k, send = string.match(entry, "^(.-) = (.*)$")
		if k and same_key(k, key) then
			return send
		end
	end
end

local function save()
	local lines = {}
	for _, k in ipairs(keys) do
		table.insert(lines, k.key .. " " .. k.send)
	end
	local f = io.open(KEYS_FILE, "wb")
	if not f then
		Note("Soundpack: couldn't write keys.txt.")
		return false
	end
	f:write(HEADER .. table.concat(lines, "\r\n") .. (#lines > 0 and "\r\n" or ""))
	f:close()
	return true
end

function empire_load_keys()
	-- forget the last load's keys, in case the file lost some
	for _, k in ipairs(keys) do
		Accelerator(k.key, "")
	end
	keys = {}
	empire_soundpack_keys = keys

	local f = io.open(KEYS_FILE, "rb")
	if not f then
		return
	end
	for line in f:lines() do
		line = string.gsub(line, "\r$", "")
		local key, send = string.match(line, "^%s*([^#%s]%S*)%s+(.-)%s*$")
		if key and send ~= "" then
			if Accelerator(key, send) == 0 then
				table.insert(keys, { key = key, send = send })
			else
				Note("Soundpack: keys.txt has a key MUSHclient doesn't know: " .. key)
			end
		end
	end
	f:close()
end

function empire_set_key(name, line, wildcards)
	local key, send = wildcards[1], wildcards[2]
	if key == "" then
		Note("Type spkey, a key, then a command to make a shortcut key, like: spkey Ctrl+Shift+B inventory")
		Note("Type spkey and just the key to remove it. Type spkeys to list them.")
		return
	end

	local i = find(key)
	if send == "" then
		if not i then
			Note("Soundpack: there's no soundpack key " .. key .. ".")
			return
		end
		Accelerator(keys[i].key, "")
		table.remove(keys, i)
		if save() then
			Note("Soundpack: removed " .. key .. ". Push keys.txt to send it to everyone.")
		end
		return
	end

	local old = not i and used_for(key)
	if Accelerator(key, send) ~= 0 then
		Note("Soundpack: MUSHclient doesn't know the key " .. key .. ". Write it like Ctrl+Shift+B, Alt+F5 or Ctrl+Numpad1.")
		return
	end
	if old and old ~= send then
		Note("Soundpack: " .. key .. " used to send " .. old .. ", which it doesn't do any more. If you didn't want that, type spkey " .. key .. " to remove it, then restart MUSHclient.")
	end
	if i then
		keys[i].send = send
	else
		table.insert(keys, { key = key, send = send })
	end
	if save() then
		Note("Soundpack: " .. key .. " now sends " .. send .. ". Push keys.txt to send it to everyone.")
	end
end

function empire_list_keys()
	if #keys == 0 then
		Note("Soundpack: there are no soundpack keys yet.")
		return
	end
	for _, k in ipairs(keys) do
		Note(k.key .. ": " .. k.send)
	end
end

AddAlias("sp_key", "^spkey(?: +(\\S+)(?: +(.*?))?)? *$", "", alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary, "empire_set_key")
AddAlias("sp_keys", "spkeys", "", alias_flag.Enabled + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary, "empire_list_keys")

empire_load_keys()
