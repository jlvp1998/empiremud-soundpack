-- Volume controls for the soundpack, loaded by extras.lua.
--
--   voltoggle  picks which volume to change: global, ambients, battle or music
--   volup      raises the picked volume by 10
--   voldown    lowers the picked volume by 10 (0 mutes it)
--   volumes    says all four volumes
--
-- Every sound goes through ppi.play, so this wraps ppi.play and gives each
-- sound the volume for its kind, worked out from its folder. The volumes are
-- saved in volumes.txt next to this file, so they last between sessions.

local dir = string.gsub(GetInfo(56), "[\\/]+$", "") .. "\\worlds\\empire\\updater"
local save_file = dir .. "\\volumes.txt"

local KINDS = { "global", "ambients", "battle", "music" }
local STEP = 10

-- which kind of volume a sound uses, by its folder
local function kind_of(path)
	path = string.lower(string.gsub(tostring(path), "\\", "/"))
	if string.find(path, "/worlds/empire/am/", 1, true) then
		return "ambients"
	elseif string.find(path, "/worlds/empire/battle/", 1, true) then
		return "battle"
	elseif string.find(path, "/worlds/empire/music/", 1, true) then
		return "music"
	end
	return "global"
end


-- load the saved volumes (once per client start; spupdate reloads this file)
if not empire_volumes then
	empire_volumes = { global = 100, ambients = 100, battle = 100, music = 100, picked = "global" }
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
	empire_looping = {}	-- looped sounds that are playing now, by kind, so volume changes reach them
end


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


-- wrap ppi.play once; reloading this file keeps the same wrapper
if ppi and not empire_real_play then
	empire_real_play = ppi.play
	ppi.play = function(path, loop, pan, vol, ...)
		local kind = kind_of(path)
		local volume = empire_volumes[kind]
		if volume <= 0 and loop ~= 1 then
			return 0	-- muted: don't play one-off sounds at all
		end
		local id = empire_real_play(path, loop, pan, volume, ...)
		if loop == 1 and id and id ~= 0 then
			empire_looping[kind] = empire_looping[kind] or {}
			table.insert(empire_looping[kind], id)
		end
		return id
	end
end


-- changes the volume of looped sounds already playing (like ambients)
local function apply_to_loops(kind)
	local still = {}
	for _, id in ipairs(empire_looping[kind] or {}) do
		if ppi.isPlaying(id) then
			ppi.setVol(empire_volumes[kind], id)
			table.insert(still, id)
		end
	end
	empire_looping[kind] = still
end


local function describe(kind)
	local v = empire_volumes[kind]
	return kind .. " volume " .. (v <= 0 and "muted" or tostring(v))
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
	local kind = empire_volumes.picked
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
	local parts = {}
	for _, kind in ipairs(KINDS) do
		table.insert(parts, describe(kind))
	end
	Note("Volumes: " .. table.concat(parts, ", ") .. ". Adjusting " .. empire_volumes.picked .. ".")
end


local flags = alias_flag.Enabled + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary
AddAlias("sp_voltoggle", "voltoggle", "", flags, "empire_vol_toggle")
AddAlias("sp_volup", "volup", "", flags, "empire_vol_up")
AddAlias("sp_voldown", "voldown", "", flags, "empire_vol_down")
AddAlias("sp_volumes", "volumes", "", flags, "empire_vol_list")
