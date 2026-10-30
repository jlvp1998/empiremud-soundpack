-- Extra soundpack triggers. The auto-updater can replace this file, so new
-- sound triggers go here instead of in world.MCL. They're temporary triggers
-- (made fresh each time the world opens), so they never get saved twice.

local function sound_trigger(name, match, file)
	AddTriggerEx(name, match,
		'ppi.play(GetInfo("56").."/worlds/empire/sounds/' .. file .. '",0,0,Gv)',
		trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
		custom_colour.NoChange, 0, "", "", sendto.script, 90)
	SetTriggerOption(name, "group", "soundpack_extras")
end

-- spupdate: check for soundpack updates now, without restarting the client
function empire_spupdate_alias()
	if empire_updater_check then
		empire_updater_check(true)
	else
		Note("Soundpack: the updater isn't loaded. Restart MUSHclient.")
	end
end
AddAlias("sp_update", "spupdate", "", alias_flag.Enabled + alias_flag.IgnoreAliasCase + alias_flag.Replace + alias_flag.Temporary, "empire_spupdate_alias")

-- the soundpack's triggers, aliases, timers and macros (soundpack.xml), and spexport
do
	local ok, err = pcall(dofile, string.gsub(GetInfo(56), "[\\/]+$", "") .. "/worlds/empire/updater/soundpack.lua")
	if not ok then
		Note("Soundpack: couldn't load the sound triggers: " .. tostring(err))
	end
end

-- volume controls: voltoggle, volup, voldown, volumes
do
	local ok, err = pcall(dofile, string.gsub(GetInfo(56), "[\\/]+$", "") .. "/worlds/empire/updater/volume.lua")
	if not ok then
		Note("Soundpack: couldn't load the volume controls: " .. tostring(err))
	end
end

-- Room titles on the map start with the island's name, like
-- "Unexplored Island, An Overgrown Forest (12, 34)". Some of world.MCL's room
-- triggers only match when the title starts with the land's name, so each of
-- those gets a temporary copy that allows an island name first. The copy's
-- %1, %2 and so on are the same as the original's.
do
	local coords = [[\(([0-9, ]*?)\)$]]
	local count = 0
	local function on(name, option)
		local v = GetTriggerOption(name, option)
		return v == 1 or v == true or v == "y"
	end
	for _, name in ipairs(GetTriggerList() or {}) do
		local match = GetTriggerOption(name, "match") or ""
		if string.sub(name, 1, 8) ~= "sp_isle_" and on(name, "regexp")
				and string.sub(match, 1, 1) == "^" and string.sub(match, -#coords) == coords
				and string.sub(match, 1, 13) ~= "^([A-Za-z0-9(" then
			count = count + 1
			local copy = "sp_isle_" .. count
			local flags = trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary
			if on(name, "enabled") then flags = flags + trigger_flag.Enabled end
			if on(name, "omit_from_log") then flags = flags + trigger_flag.OmitFromLog end
			if on(name, "omit_from_output") then flags = flags + trigger_flag.OmitFromOutput end
			if on(name, "ignore_case") then flags = flags + trigger_flag.IgnoreCase end
			if on(name, "keep_evaluating") then flags = flags + trigger_flag.KeepEvaluating end
			AddTriggerEx(copy, "^[^()]+?, " .. string.sub(match, 2), GetTriggerOption(name, "send") or "", flags,
				custom_colour.NoChange, 0, "", "", GetTriggerOption(name, "send_to") or sendto.script, GetTriggerOption(name, "sequence") or 100)
			SetTriggerOption(copy, "group", GetTriggerOption(name, "group") or "")
		end
	end
end

-- new change posted by staff (not ticket replies)
sound_trigger("sp_new_change", [[^\[Notification\] .+ \d{1,2}:\d\d [AP]M (?!The Staff: ).+?: Category: .+ Change: ]], "new-change.ogg")

-- new announcement from the staff
sound_trigger("sp_new_announcement", [[^\[Notification\] .+ \d{1,2}:\d\d [AP]M The Staff: ]], "new-announcement.ogg")

-- firearms (sound files go in worlds\empire\sounds\firearms)
sound_trigger("sp_fa_revolver_fire", [[^BANG! ]], "firearms/revolver-fire.ogg")
sound_trigger("sp_fa_handgun_fire", [[^BLAM! ]], "firearms/handgun-fire.ogg")
sound_trigger("sp_fa_empty", [[^\*Click!\* |^.+ clicks\. It's empty!$]], "firearms/empty.ogg")
sound_trigger("sp_fa_load_rounds", [[^You load \d+ rounds? into (?!.*magazine)|^.+ reloads .*(revolver|gun|pistol).*\.$]], "firearms/load-rounds.ogg")
sound_trigger("sp_fa_fill_magazine", [[^You load \d+ rounds? into .*magazine|^.+ loads rounds into .*magazine]], "firearms/fill-magazine.ogg")
sound_trigger("sp_fa_magazine_in", [[^You (eject the old magazine and )?load a (fresh one|magazine) into |^.+ loads a magazine into ]], "firearms/magazine-in.ogg")
sound_trigger("sp_fa_magazine_out", [[^You eject the magazine from |^.+ ejects the magazine from ]], "firearms/magazine-out.ogg")
sound_trigger("sp_fa_unload", [[^You unload \d+ rounds? from |^You thumb \d+ rounds? out of |^.+ unloads .*(revolver|gun|pistol).*\.$|^.+ empties .*magazine]], "firearms/unload.ogg")