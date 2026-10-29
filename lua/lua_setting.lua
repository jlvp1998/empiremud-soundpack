--[[
functions to make it quicker to add in variable setting aliases

setvar(var, value, text) - sets a variable and displays some text to the user
toggle(s)                - toggles a variable from false to true and vice versa
onoff(s, bool)           - sets variable to true/false and enables/disables triggergroup also deletes temporary timers

changes:
July 16, 15 :- added suppress_notify to toggle.
               added friendly_name to toggle

--]]



function setvar(var, value, text)
 if type(var)~="string" or value==nil then
  print("invalid params to setvar")
  return nil
 end

 if type(text)~="string" then text=var end
 
 if _G[var]==nil then
  print("setting for first time")
 end

 if tonumber(value) then
   print("numeric value detected")
  _G[var]=tonumber(value)
 else
  _G[var]=value
 end
 print(text, "set to", value)
end

function toggle(var_name, friendly_name, suppress_notify)
 if type(var_name)~="string" then
  print("variable name must be a string")
  return nil
 end


 if _G[var_name]==false then
  _G[var_name]=true
  if suppress_notify~=true then 
   print(friendly_name or var_name, "is now on.") 
  end
 elseif _G[var_name]==true then
  _G[var_name]=false
  if suppress_notify~=true then 
   print(friendly_name or var_name, "is now off.")
  end
 else
  print("error toggling", tostring(var_name))
 end
end


function onoff(v, switch)
 if switch==nil or v==nil then
  print("invalid on off switch option")
  return nil
 end

 if switch=="off" then
  DeleteTemporaryTimers()
  EnableTriggerGroup(v, false)
  _G[v]=false
  print(v, "is now", swtich)
 elseif switch=="on" then
  EnableTriggerGroup(v, true)
  _G[v]=true
  print(v, "is now", swtich)
 else
  print("invalid on off switch option")
 end
end

function set_on_off(name, tgroups, switch)
 if type(name)~="string" then
  print("name must be a string")
  return nil
 elseif type(tgroups)~="table" then
  print("trigger groups must be a table.")
  return nil
 end

 if switch=="on" then
  _G[name]=true
  for _, tg in pairs(tgroups) do
   EnableTriggerGroup(tg, true)
  end
  print(name, "is now on.")
 elseif switch=="off" then
   _G[name]=false
   for _, tg in pairs(tgroups) do
    EnableTriggerGroup(tg, false)
   end
   print(name, "is now off.")
 else
  print("invalid set_on_off switch.")
 end
end


