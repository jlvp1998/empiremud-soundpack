-- Volume controls for the soundpack, loaded by extras.lua.
--
--   voltoggle  picks which volume to change: global, ambients, msp, battle or music
--   volup      raises the picked volume by 10
--   voldown    lowers the picked volume by 10 (0 mutes it)
--   volumes    says all five volumes
--
-- The kinds of sound, by folder:
--   ambients  am
--   msp       the sounds of things being done: battle (kicks, punches, hits),
--             natural magic, sorcery, skills, vampire, morph, and firearms
--   battle    battle music, in music\battle
--   music     everything else in music
--   global    everything else
--
-- Every sound goes through ppi.play, so this wraps ppi.play and gives each
-- sound the volume for its kind. The volumes are saved in volumes.txt next to
-- this file, so they last between sessions.

local dir = string.gsub(GetInfo(56), "[\\/]+$", "") .. "\\worlds\\empire\\updater"
local save_file = dir .. "\\volumes.txt"

local KINDS = { "global", "ambients", "msp", "battle", "music" }
local STEP = 10

local MSP_FOLDERS = { "battle", "natural magic", "sorcery", "skills", "vampire", "morph", "sounds/firearms" }

-- which kind of volume a sound uses, by its folder
local function kind_of(path)
	path = string.lower(string.gsub(tostring(path), "\\", "/"))
	local rel = string.match(path, "/worlds/empire/(.*)$") or ""
	if string.sub(rel, 1, 3) == "am/" then
		return "ambients"
	elseif string.sub(rel, 1, 13) == "music/battle/" then
		return "battle"
	elseif string.sub(rel, 1, 6) == "music/" then
		return "music"
	end
	for _, folder in ipairs(MSP_FOLDERS) do
		if string.sub(rel, 1, #folder + 1) == folder .. "/" then
			return "msp"
		end
	end
	return "global"
end


-- load the saved volumes (once per client start; spupdate reloads this file)
if not empire_volumes then
	empire_volumes = { global = 100, ambients = 100, msp = 100, battle = 100, music = 100, picked = "global" }
	local f = io.open(save_file, "r")
	if f then
		for name, value in string.gmatch(f:read("*a"), "(%a+)=(%w+)") do
			if name == "picked" then
				empire_volumes.picked = value
			elseif empire_volumes[name] then
				empire_volumes[name] = math.max(0, math.min(100, tonumber(value) or 100))
			end
		end
		f:close()
	end
	empire_looping = {}	-- looped sounds playing now, by kind, so volume changes reach them
	empire_last_loop = {}	-- the last looped sound asked for, by kind, so it can start again
end
-- volumes saved by an older version of this file
for _, kind in ipairs(KINDS) do
	empire_volumes[kind] = empire_volumes[kind] or 100
end
empire_last_loop = empire_last_loop or {}


local function save_volumes()
	local f = io.open(save_file, "w")
	if f then
		for _, kind in ipairs(KINDS) do
			f:write(kind .. "=" .. empire_volumes[kind] .. "\n")
		end
		f:write("picked=" .. empire_volumes.picked .. "\n")
		f:close()
	end
end


-- keep the old volume variables the world's triggers use in step
local function sync_variables()
	Gv = empire_volumes.global
	Av = empire_volumes.ambients
	Bv = empire_volumes.battle
	Mv = empire_volumes.music
end
sync_variables()


-- the world's own volume commands (like Av 50, Gv+5, and the volume keys) set
-- these variables directly, so take up any change they made
local OLD_VARIABLES = { global = "Gv", ambients = "Av", battle = "Bv", music = "Mv" }
function empire_adopt_old_variables()
	local changed = false
	for kind, var in pairs(OLD_VARIABLES) do
		local v = tonumber(_G[var])
		if v then
			v = math.max(0, math.min(100, v))
			if v ~= empire_volumes[kind] then
				empire_volumes[kind] = v
				changed = true
			end
		end
	end
	if changed then
		sync_variables()
		save_volumes()
	end
end


-- wrap ppi.play once; reloading this file keeps the same wrapper
if ppi and not empire_real_play then
	empire_real_play = ppi.play
	ppi.play = function(path, loop, pan, vol, ...)
		empire_adopt_old_variables()
		local kind = kind_of(path)
		local volume = empire_volumes[kind]
		if loop == 1 then
			-- a new ambient replaces the old one, even while muted, so unmuting starts the right one
			empire_last_loop[kind] = { path = path, pan = pan }
		end
		if volume <= 0 or empire_sounds_off then
			return 0	-- muted, or all sounds turned off with Control+F12
		end
		local id = empire_real_play(path, loop, pan, volume, ...)
		if loop == 1 and id and id ~= 0 then
			empire_looping[kind] = empire_looping[kind] or {}
			table.insert(empire_looping[kind], id)
		end
		return id
	end
end


-- after a volume change: change looped sounds already playing, stop them if
-- muted, or start the last one again if none is playing (like after unmuting)
local function apply_to_loops(kind)
	local still = {}
	for _, id in ipairs(empire_looping[kind] or {}) do
		if ppi.isPlaying(id) then
			if empire_volumes[kind] <= 0 then
				ppi.stop(id)
			else
				ppi.setVol(empire_volumes[kind], id)
				table.insert(still, id)
			end
		end
	end
	empire_looping[kind] = still

	local last = empire_last_loop[kind]
	if #still == 0 and last and empire_volumes[kind] > 0 then
		ppi.play(last.path, 1, last.pan or 0, empire_volumes[kind])
	end
end


local function describe(kind)
	local v = empire_volumes[kind]
	return (kind == "msp" and "MSP" or kind) .. " volume " .. (v <= 0 and "muted" or tostring(v))
end


function empire_vol_toggle()
	local next_kind = KINDS[1]
	for i, kind in ipairs(KINDS) do
		if kind == empire_volumes.picked then
			next_kind = KINDS[i % #KINDS + 1]
		end
	end
	empire_volumes.picked = next_kind
	save_volumes()
	Note("Adjusting " .. describe(next_kind) .. ".")
end


local function change(amount)
	empire_adopt_old_variables()
	local kind = empire_volumes.picked
	if not empire_volumes[kind] then
		kind = "global"
		empire_volumes.picked = kind
	end
	empire_volumes[kind] = math.max(0, math.min(100, empire_volumes[kind] + amount))
	sync_variables()
	save_volumes()
	apply_to_loops(kind)
	Note(string.upper(string.sub(kind, 1, 1)) .. string.sub(describe(kind), 2) .. ".")
end

function empire_vol_up()
	change(STEP)
end

function empire_vol_down()
	change(-STEP)
end

function empire_vol_list()
	empire_adopt_old_variables()
	local parts = {}
	for _, kind in ipairs(KINDS) do
		table.insert(parts, describe(kind))
	end
	Note("Volumes: " .. table.concat(parts, ", ") .. ". Adjusting " .. empire_volumes.picked .. ".")
end


-- Control+F12 turns all sounds off and on (in the LuaAudio plugin, which updates
-- can't change). Nothing restarted the ambience when sounds came back on, so
-- Control+F12 now runs the plugin's toggle and then starts the current ambience
-- over. (When sounds just went off, that restart is silent, so it doesn't
-- matter which way the toggle went.)
local function stop_loops()
	for _, kind in ipairs(KINDS) do
		for _, id in ipairs(empire_looping[kind] or {}) do
			ppi.stop(id)
		end
		empire_looping[kind] = {}
	end
end

function empire_restart_loops()
	stop_loops()
	for _, kind in ipairs(KINDS) do
		local last = empire_last_loop[kind]
		if last and empire_volumes[kind] > 0 then
			ppi.play(last.path, 1, last.pan or 0, empire_volumes[kind])
		end
	end
end

-- sounds start on; while they're off, no new sounds play, but the ambience
-- you walk into is still remembered, so the right one starts when they're on
function empire_sound_toggle()
	Execute("sound_toggle")	-- the plugin's own on/off, with its on and off sounds
	empire_sounds_off = not empire_sounds_off
	if empire_sounds_off then
		stop_loops()
	else
		-- after the plugin has finished switching back on
		DoAfterSpecial(0.5, "empire_restart_loops()", sendto.script)
	end
end


local flags = alias_flag.Enabled + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary
AddAlias("sp_sound_toggle", "sp_sound_toggle", "", flags, "empire_sound_toggle")
SetAliasOption("sp_sound_toggle", "omit_from_command_history", "y")
SetAliasOption("sp_sound_toggle", "omit_from_output", "y")
SetAliasOption("sp_sound_toggle", "omit_from_log", "y")
-- after the plugins have set up their own keys, take over Control+F12
DoAfterSpecial(2, 'Accelerator("ctrl+f12", "sp_sound_toggle")', sendto.script)
AddAlias("sp_voltoggle", "voltoggle", "", flags, "empire_vol_toggle")
AddAlias("sp_volup", "volup", "", flags, "empire_vol_up")
AddAlias("sp_voldown", "voldown", "", flags, "empire_vol_down")
AddAlias("sp_volumes", "volumes", "", flags, "empire_vol_list")
