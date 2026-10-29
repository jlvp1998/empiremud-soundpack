--[[
lua_table
table.count(t)    - count for ivalue and nvalue tables
table.inverse(t)  - inverses table so keys become values and vice versa, i.e. turns t[k]=v into t[v]=k
--]]


table.count=function (t)
 if type(t)~="table" then return nil end
 local count=0

 for k, v in pairs(t) do
  count=count+1
 end

 return count
end -- function table.count


table.inverse=function(t)
 if type(t)~="table" then return nil end

 local temp = {}
 for k, v in pairs(t) do
  temp[v] = k
 end
 return temp
end -- function table.inverse