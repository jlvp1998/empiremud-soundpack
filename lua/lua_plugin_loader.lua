require "lua_warn"

--[[
lua_plugin_loader.lua
load_required_plugins_by_id(plugins)

--]]


--[[
loads required plugins into world file.  Generates an error if any of the plugins fail to load.
param1: table in format t[pluginid]="plugin_name.xml"
parem2: true to enable showing of warning messages
returns: true if successful or false if failed
--]]

function load_required_plugins_by_id(plugins, show_warnings)
 local ret=true

 if show_warnings==true then
  set_warnings_on()
 end

 warn("loading required plugins...")
 for pid, pname in pairs(plugins) do
  if IsPluginInstalled(pid)==false then
   warn(pid, pname, "not installed. attempting to add...")
   local r=LoadPlugin(string.format("%s%s", GetInfo(60), pname))

   if r==error_code.eOK then
    warn("plugin installed ok")
   elseif r==error_code.ePluginFileNotFound then
    warn("Plugin file not found")
    ret=false
   elseif r==error_code.eProblemsLoadingPlugin then
    warn("Parsing or other problem in plugin file")
    ret=false
   else
    warn("unrecognized error", r)
    ret=false    
   end -- if result
  else
   warn(pname, "already installed")
  end -- if isplugininstalled
 end -- for each plugin

 if ret==true then
  warn("required plugins successfully installed.")
  set_warnings_off()
  return true
 else
  warn("one or more required plugins failed to install.")
  set_warnings_off()
  return false
 end
end -- function load_required_plugins_by_id