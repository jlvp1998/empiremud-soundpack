-- The soundpack's triggers, aliases, timers and macros live in
-- worlds\empire\soundpack.xml, not in world.MCL, so the updater can send
-- changes to players and helpers can change them in git. They're loaded as
-- temporary items (named spx_...), so MUSHclient never saves them into
-- world.MCL. The player's own triggers and settings in world.MCL are left alone.
--
-- spexport: after changing the soundpack's triggers, aliases, timers or
-- macros in MUSHclient, this writes them back to soundpack.xml for git.

local root = string.gsub(GetInfo(56), "[\\/]+$", "")
local XML_FILE = root .. "\\worlds\\empire\\soundpack.xml"

-- every key MUSHclient can have a macro on
local MACRO_KEYS = { "up", "down", "north", "south", "east", "west", "examine", "look", "page", "help",
	"say", "whisper", "doing", "who", "drop", "take", "logout", "quit" }
for i = 1, 12 do
	table.insert(MACRO_KEYS, "F" .. i)
	table.insert(MACRO_KEYS, "F" .. i .. "+Shift")
	table.insert(MACRO_KEYS, "F" .. i .. "+Ctrl")
end
for c in string.gmatch("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ".") do
	table.insert(MACRO_KEYS, "Alt+" .. c)
end

-- each kind of item: its tag in the file, ExportXML's number, and its functions
local KINDS = {
	{ tag = "trigger", short = "t", export = 0, list = GetTriggerList, delete = DeleteTrigger, option = GetTriggerOption,
		key = function(name) return GetTriggerOption(name, "match") end },
	{ tag = "alias", short = "a", export = 1, list = GetAliasList, delete = DeleteAlias, option = GetAliasOption,
		key = function(name) return GetAliasOption(name, "match") end },
	{ tag = "timer", short = "i", export = 2, list = GetTimerList, delete = DeleteTimer, option = GetTimerOption,
		key = function(name) return GetTimerOption(name, "send") end },
}

local function read_file(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function starts(s, prefix)
	return string.sub(s or "", 1, #prefix) == prefix
end

-- the player's own items: saved in world.MCL, not made by a script
local function players_own(kind, name)
	local temp = kind.option(name, "temporary")
	return not starts(name, "sp") and not (temp == 1 or temp == true or temp == "y")
end


function empire_load_soundpack()
	local xml = read_file(XML_FILE)
	if not xml then
		Note("Soundpack: worlds\\empire\\soundpack.xml is missing, so the sound triggers didn't load. Type spupdate to get it again.")
		return
	end

	-- name each item and make it temporary; macros have no names or
	-- temporary setting, and a new macro simply replaces the old one
	for _, kind in ipairs(KINDS) do
		local n = 0
		xml = string.gsub(xml, "<" .. kind.tag .. "(%s)", function(space)
			n = n + 1
			return "<" .. kind.tag .. ' name="spx_' .. kind.short .. "_" .. n .. '" temporary="y"' .. space
		end)
	end

	-- the last load's copies (this runs again after an update)
	for _, kind in ipairs(KINDS) do
		for _, name in ipairs(kind.list() or {}) do
			if starts(name, "spx_") then
				kind.delete(name)
			end
		end
	end

	local count = ImportXML(xml)
	if not count or count < 0 then
		Note("Soundpack: soundpack.xml is damaged, so the sound triggers didn't load.")
		return
	end

	-- remove the old copies that were saved in world.MCL before this file
	-- existed: the ones with the same pattern as one of the soundpack's
	local removed = 0
	for _, kind in ipairs(KINDS) do
		local ours = {}
		for _, name in ipairs(kind.list() or {}) do
			if starts(name, "spx_") then
				ours[kind.key(name) or ""] = true
			end
		end
		for _, name in ipairs(kind.list() or {}) do
			if players_own(kind, name) and ours[kind.key(name) or ""] then
				kind.delete(name)
				removed = removed + 1
			end
		end
	end
	if removed > 0 then
		empire_soundpack_moved = true
		Note("Soundpack: moved " .. removed .. " old soundpack triggers and aliases out of your world file. If MUSHclient asks to save the world, say yes.")
	end
end


-- spexport: writes the soundpack's triggers, aliases, timers and macros to soundpack.xml
function empire_export_soundpack()
	local out, counts, new = {}, {}, 0

	for _, kind in ipairs(KINDS) do
		-- soundpack ones in their original order, then any new ones
		local names = {}
		for _, name in ipairs(kind.list() or {}) do
			if starts(name, "spx_") or players_own(kind, name) then
				table.insert(names, name)
			end
		end
		local function order(name)
			local n = starts(name, "spx_") and tonumber(string.match(name, "_(%d+)$"))
			return n or (1000000 + (tonumber(string.match(name, "(%d+)$")) or 0))
		end
		table.sort(names, function(a, b) return order(a) < order(b) end)

		local items = {}
		for _, name in ipairs(names) do
			local item = string.match(ExportXML(kind.export, name) or "", "(<" .. kind.tag .. "%s.-</" .. kind.tag .. ">)")
			if item then
				item = string.gsub(item, '%s+name="spx_[^"]*"', "")
				item = string.gsub(item, '%s+temporary="y"', "")
				table.insert(items, "  " .. item)
				if not starts(name, "spx_") then
					new = new + 1
				end
			end
		end
		counts[kind.tag] = #items
		local plural = kind.tag == "alias" and "aliases" or (kind.tag .. "s")
		table.insert(out, "<!-- " .. plural .. " -->\r\n\r\n<" .. plural .. ">\r\n" .. table.concat(items, "\r\n") .. "\r\n</" .. plural .. ">\r\n")
	end

	-- macros that do something
	local macros = {}
	for _, key in ipairs(MACRO_KEYS) do
		local item = string.match(ExportXML(3, key) or "", "(<macro%s.-</macro>)")
		if item and string.match(item, "<send>.-%S.-</send>") then
			table.insert(macros, "  " .. item)
		end
	end
	counts.macro = #macros
	table.insert(out, "<!-- macros -->\r\n\r\n<macros>\r\n" .. table.concat(macros, "\r\n") .. "\r\n</macros>\r\n")

	local text = '<?xml version="1.0" encoding="iso-8859-1"?>\r\n<!DOCTYPE muclient>\r\n<muclient>\r\n'
		.. "<!-- The soundpack's triggers, aliases, timers and macros. The soundpack loads\r\n"
		.. "     these every time the world opens, and the updater keeps this file up to\r\n"
		.. "     date. To change them, edit them in MUSHclient, then type spexport. -->\r\n\r\n"
		.. table.concat(out, "\r\n") .. "</muclient>\r\n"
	text = string.gsub(string.gsub(text, "\r\n", "\n"), "\n", "\r\n")

	local f = io.open(XML_FILE, "wb")
	if not f then
		Note("Soundpack: couldn't write soundpack.xml.")
		return
	end
	f:write(text)
	f:close()
	Note("Soundpack: saved " .. counts.trigger .. " triggers, " .. counts.alias .. " aliases, " .. counts.timer .. " timers and "
		.. counts.macro .. " macros to soundpack.xml" .. (new > 0 and (", including " .. new .. " new ones") or "")
		.. ". Now commit and push it with git.")
end
AddAlias("sp_export", "spexport", "", alias_flag.Enabled + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary, "empire_export_soundpack")

empire_load_soundpack()
