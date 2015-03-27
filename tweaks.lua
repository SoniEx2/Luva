-- Tweaks to Lua libs

-- Tweaked require

local function req(...)
  local t = {...}
  local n = select('#', ...)
  local o = {}
  for i = 1, n do
    o[i] = require(t[i])
  end
  return unpack(o, 1, n)
end

local modules = setmetatable({},
  {
    __index = function(t,k)
      local v = require(k)
      if v == true and _G[k] then
        v = _G[k]
      end
      t[k] = v
      return v
    end
  }
)

-- init modules
for k,v in package.loaded do
  modules[k]
end

return
{
  modules = modules,
  require = req,
}