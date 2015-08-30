-- Tweaks to Lua libs

local M = {}

-- Tweaked require
do
  local function reqimpl(t, n)
    if not t[n + 1] then
      return require(t[n])
    end
    return require(t[n]), reqimpl(t, n + 1)
  end
  local function req(...)
    local t = {...}
    return reqimpl(t, 1)
  end
  M.require = req
end

do
  local function callimpl(t, x, n)
    if not x[n + 1] then
      return t[x[n]]
    end
    return t[x[n]], callimpl(t, x, n + 1)
  end
  local modules = setmetatable({tweaks = M},
    {
      __index = function(t,k)
        local v = require(k)
        if v == true and _G[k] then
          v = _G[k]
        end
        t[k] = v
        return v
      end,
      __call = function(t, ...)
        local x = {...}
        return callimpl(t, x, 1)
      end
    }
  )
  
  M.modules = modules
  
  -- init modules
  for k,v in pairs(package.loaded) do
    local _ = modules[k]
  end
end

return M