require "lua_plugin_loader"

mushz_plugins={
["43d213517f498583ee847c8b"]="plugin_instance_manager.xml",
["e3c18407bd5e477c0b603f7e"]="plugin_tag.xml"
}
if load_required_plugins_by_id(mushz_plugins) == true then
 Note("Mush-z plugins installed.")
else
 error("The required Mush-z plugins failed to install.", 2)
end