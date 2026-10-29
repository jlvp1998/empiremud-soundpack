-- EmpireMUD soundpack auto-updater. empire.lua runs this when the world opens.
--
-- The soundpack lives on GitHub. A few seconds after the world opens, this asks
-- GitHub whether the soundpack changed since the last update. If it did, it
-- finds the files under worlds/empire that are new or different here,
-- downloads them, then reloads the extra triggers.
--
-- GitHub needs a secure (https) connection, which MUSHclient can't make by
-- itself, so the downloads are done by curl.exe (built into Windows 10 and 11),
-- run hidden in the background. MUSHclient stays usable the whole time.

local REPO = "jlvp1998/empiremud-soundpack"
local BRANCH = "main"
local MANAGED = "worlds/empire/"	-- only files under here are updated

local root = string.gsub(GetInfo(56), "[\\/]+$", "")
local dir = root .. "\\worlds\\empire\\updater"
local work = dir	-- the updater's own files go in its folder, which always exists

-- extra triggers live in extras.lua so the updater can add new ones
function empire_load_extras()
	local ok, err = pcall(dofile, dir .. "\\extras.lua")
	if not ok then
		Note("Soundpack: couldn't load the extra sound triggers: " .. tostring(err))
	end
end


local function read_file(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end


local function write_file(path, data)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	f:write(data)
	f:close()
	return true
end


-- makes each missing folder on the way to a file
local function make_folders(path)
	local folder = string.match(path, "^(.*)\\[^\\]+$")
	local found = folder and utils.readdir(folder .. "\\*")
	-- (readdir can give back an empty list instead of nothing for a missing folder)
	if folder and (not found or next(found) == nil) then
		make_folders(folder)
		os.execute('mkdir "' .. folder .. '"')
	end
end


local function url_escape(s)
	return (string.gsub(s, "[^%w%-%._~/]", function(c) return string.format("%%%02X", string.byte(c)) end))
end


-- the same fingerprint GitHub uses for each file
local function git_hash(data)
	return string.lower(utils.hash("blob " .. #data .. "\0" .. data))
end


-- runs a little batch file with no window
-- name.flag gets curl's result number (0 means it worked) or "nocurl", and
-- name.err gets curl's error message. File names inside the batch file are
-- relative to the work folder, so folder names with accents can't break it.
local function run_hidden(name, curl_args)
	os.remove(work .. "\\" .. name .. ".flag")
	os.remove(work .. "\\" .. name .. ".err")
	local path = work .. "\\" .. name .. ".cmd"
	write_file(path, table.concat({
		'@echo off',
		'cd /d "%~dp0"',
		'where curl.exe >nul 2>nul || (>' .. name .. '.flag echo nocurl& exit /b)',
		'curl.exe -sS ' .. curl_args .. ' 2>' .. name .. '.err',
		'>' .. name .. '.flag echo %ERRORLEVEL%',
	}, "\r\n") .. "\r\n")
	local ok, err = utils.shellexecute(path, nil, work, "open", 0)
	if not ok then
		write_file(work .. "\\" .. name .. ".flag", "start " .. tostring(err))
	end
end


-- turns a finished name.flag into a reason a player can understand, or nil if it worked
local function why_failed(name)
	local flag = read_file(work .. "\\" .. name .. ".flag") or ""
	local result = string.match(flag, "^%s*(%S+)")
	local curl_said = string.match(read_file(work .. "\\" .. name .. ".err") or "", "curl: %(%d+%) ([^\r\n]+)")
	if result == "0" then
		return nil
	elseif result == "nocurl" then
		return "this computer doesn't have curl, which comes with Windows 10 and 11"
	elseif result == "start" then
		return "Windows wouldn't start the download (" .. string.sub(flag, 7) .. ")"
	elseif result == "6" or result == "7" then
		return "it couldn't reach GitHub. Check your internet connection"
	elseif result == "22" then
		return "GitHub refused (" .. (curl_said or "too many checks from this internet connection, try again in an hour") .. ")"
	elseif result == "35" or result == "60" then
		return "the secure connection to GitHub failed. An antivirus or an out-of-date Windows can cause this"
	elseif result == "28" then
		return "GitHub took too long to answer"
	end
	return "curl error " .. tostring(result) .. (curl_said and (": " .. curl_said) or "")
end


function empire_updater_tick()
	local w = empire_updater_wait
	if not w then
		DeleteTimer("empire_updater_timer")
		return
	end
	if w.step then
		w.step()	-- slow work, a little at a time
		return
	end
	if read_file(w.flag) then
		empire_updater_wait = nil
		DeleteTimer("empire_updater_timer")
		w.func()
		return
	end
	w.left = w.left - 1
	if w.left <= 0 then
		empire_updater_wait = nil
		DeleteTimer("empire_updater_timer")
		w.give_up()
	end
end


-- calls func once flag_file appears, or give_up after a while
local function wait_for(flag_file, seconds, func, give_up)
	empire_updater_wait = { flag = flag_file, left = seconds * 2, func = func, give_up = give_up }
	AddTimer("empire_updater_timer", 0, 0, 0.5, "", timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary, "empire_updater_tick")
end


-- runs step() every tick until it returns true, then calls func
local function work_in_steps(step, func)
	empire_updater_wait = { step = function()
		if step() then
			empire_updater_wait = nil
			DeleteTimer("empire_updater_timer")
			func()
		end
	end }
	AddTimer("empire_updater_timer", 0, 0, 0.1, "", timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary, "empire_updater_tick")
end


local function finish_update(commit, items)
	local changed, failed, code, new_updater = 0, 0, false, false

	for _, item in ipairs(items) do
		local data = read_file(item.path .. ".download")
		os.remove(item.path .. ".download")
		if data and git_hash(data) == item.hash then
			make_folders(item.path)
			os.remove(item.path)	-- os.rename won't replace a file on Windows
			if write_file(item.path, data) then
				changed = changed + 1
				if item.rel == MANAGED .. "updater/updater.lua" then
					new_updater = true	-- reloaded below, no restart needed
				elseif item.rel == MANAGED .. "updater/extras.lua" then
					-- reloaded below, no restart needed
				elseif string.match(item.rel, "%.lua$") or string.match(item.rel, "%.xml$") then
					code = true
				end
			else
				failed = failed + 1
			end
		else
			failed = failed + 1
		end
	end

	-- only mark this update as done if everything worked; otherwise try again next time
	if failed == 0 then
		write_file(dir .. "\\version.txt", commit)
	end
	empire_load_extras()

	local msg = "Soundpack updated (" .. changed .. " new or changed files)."
	if failed > 0 then
		msg = msg .. " " .. failed .. " files couldn't be downloaded; it will try again next time you open the client."
	end
	if code then
		msg = msg .. " Restart MUSHclient to finish the update."
	end
	Note(msg)

	-- load the new updater right away (it won't check again until spupdate or a restart)
	if new_updater then
		DoAfterSpecial(1, 'dofile(string.gsub(GetInfo(56), "[\\\\/]+$", "") .. "/worlds/empire/updater/updater.lua")', sendto.script)
	end
end


local function download(commit, items)
	-- one list for curl, so it downloads everything in one go
	local list = {}
	for _, item in ipairs(items) do
		table.insert(list, 'url = "https://raw.githubusercontent.com/' .. REPO .. '/' .. commit .. '/' .. url_escape(item.rel) .. '"')
		-- relative to the updater folder, which is 3 folders below the soundpack folder
		table.insert(list, 'output = "../../../' .. item.rel .. '.download"')
	end
	write_file(work .. "\\list.txt", table.concat(list, "\n") .. "\n")
	os.remove(work .. "\\downloaded.flag")

	Note("Soundpack: downloading " .. #items .. " updated files...")
	run_hidden("download", '-L --create-dirs --retry 2 -K list.txt')
	-- big updates can take a while on a slow connection
	wait_for(work .. "\\download.flag", 1800, function()
		local reason = why_failed("download")
		if reason then
			Note("Soundpack: some updated files didn't download, because " .. reason .. ".")
		end
		finish_update(commit, items)	-- keeps whatever did download
	end, function()
		Note("Soundpack: the update download didn't finish. It will try again next time you open the client.")
	end)
end


local function compare(commit, json, manual)
	-- every soundpack file, with GitHub's fingerprint for it
	local files = {}
	for entry in string.gmatch(json, "{[^{}]-}") do
		local path = string.match(entry, '"path"%s*:%s*"([^"\\]+)"')
		local kind = string.match(entry, '"type"%s*:%s*"(%a+)"')
		local sha = string.match(entry, '"sha"%s*:%s*"(%x+)"')
		-- safety: only ever write inside worlds/empire
		if path and sha and kind == "blob" and string.sub(path, 1, #MANAGED) == MANAGED
				and not string.find(path, "..", 1, true) and not string.match(path, "/updater/version%.txt$") then
			table.insert(files, { rel = path, path = root .. "\\" .. string.gsub(path, "/", "\\"), hash = string.lower(sha) })
		end
	end

	if #files == 0 then
		Note("Soundpack: the update list from GitHub was empty or damaged.")
		return
	end

	-- check a few files per tick, so the client doesn't freeze
	local items, index = {}, 1
	work_in_steps(function()
		for _ = 1, 25 do
			local f = files[index]
			if not f then
				return true
			end
			local data = read_file(f.path)
			if not data or git_hash(data) ~= f.hash then
				table.insert(items, f)
			end
			index = index + 1
		end
		return false
	end, function()
		if #items == 0 then
			write_file(dir .. "\\version.txt", commit)
			if manual then
				Note("Soundpack: you already have the latest version.")
			end
		else
			download(commit, items)
		end
	end)
end


-- downloads url into work\<name>.json, then calls func with what came back (nil if it failed)
local function fetch(name, url, func)
	os.remove(work .. "\\" .. name .. ".json")
	run_hidden(name, '-f -L --retry 2 -o ' .. name .. '.json "' .. url .. '"')
	wait_for(work .. "\\" .. name .. ".flag", 60, function()
		local reason = why_failed(name)
		if reason then
			func(nil, reason)
		else
			func(read_file(work .. "\\" .. name .. ".json"))
		end
	end, function()
		func(nil, "the background download never finished. An antivirus may be blocking it")
	end)
end


-- asks GitHub whether the soundpack changed; manual is true when a player
-- typed spupdate, so they always hear the result
function empire_updater_check(manual)
	if empire_updater_wait then
		if manual then
			Note("Soundpack: already checking for updates. Please wait.")
		end
		return
	end
	if manual then
		Note("Soundpack: checking for updates...")
	end

	fetch("latest", "https://api.github.com/repos/" .. REPO .. "/commits/" .. BRANCH, function(info, reason)
		local commit = info and string.match(info, '^%s*{%s*"sha"%s*:%s*"(%x+)"')
		if not commit then
			Note("Soundpack: couldn't check GitHub for updates, because " .. (reason or "GitHub's answer was damaged") .. ". Type spupdate to try again.")
			return
		end

		local current = string.match(read_file(dir .. "\\version.txt") or "", "%x+")
		if current == commit then
			if manual then
				Note("Soundpack: you already have the latest version.")
			end
			return	-- up to date
		end

		-- something changed: get the full list of files in that version
		fetch("files", "https://api.github.com/repos/" .. REPO .. "/git/trees/" .. commit .. "?recursive=1", function(json, reason)
			if not json then
				Note("Soundpack: couldn't get the update list from GitHub, because " .. (reason or "GitHub's answer was damaged") .. ". Type spupdate to try again.")
				return
			end
			compare(commit, json, manual)
		end)
	end)
end


empire_load_extras()

-- only check once per client start (the world script can be reloaded)
if not empire_updater_started then
	empire_updater_started = true
	DoAfterSpecial(3, "empire_updater_check()", sendto.script)
end
