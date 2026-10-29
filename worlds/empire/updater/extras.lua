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

-- volume controls: voltoggle, volup, voldown, volumes
do
	local ok, err = pcall(dofile, string.gsub(GetInfo(56), "[\\/]+$", "") .. "/worlds/empire/updater/volume.lua")
	if not ok then
		Note("Soundpack: couldn't load the volume controls: " .. tostring(err))
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