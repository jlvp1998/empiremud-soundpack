show_warnings=false

function warn(...)
 if show_warnings==true then
  print(...)
 end
end

function set_warnings_on()
 show_warnings=true
end

function set_warnings_off()
 show_warnings=false
end