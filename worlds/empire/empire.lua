PPI = require("ppi")
ppi = PPI.Load("aedf0cb0be5bf045860d54b7")
function ExecuteNoStack(cmd)
local s = GetOption("enable_command_stack")
SetOption("enable_command_stack", 0)
Execute(cmd)
SetOption("enable_command_stack", s)
end

area=100
amb_id=100
sound_id=100
Gv=100
Av=100
Mv=0
coords=""
race=""
gender=""
name=""
channel=0
hit=""
cspam=""
recast="on"
am=100
mu=0
wonderland=""
halloween=""

-- soundpack auto-updater and extra sound triggers (worlds/empire/updater)
dofile(string.gsub(GetInfo(56), "[\\/]+$", "") .. "/worlds/empire/updater/updater.lua")
