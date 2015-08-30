setfenv(1, setmetatable({}, {__index=getfenv()}))

local modules = require("tweaks").modules
local ffi = modules.ffi
local C = ffi.C

local function jitable_unpack(t, i, j, ...)
  if j - i >= 5 then return jitable_unpack(t, i, j - 5, t[j], t[j-1], t[j-2], t[j-3], t[j-4], ...) end
  --if j - i >= 3 then return jitable_unpack(t, i, j - 3, t[j], t[j-1], t[j-2], ...) end
  if i == j then return t[j], ... end
  return jitable_unpack(t, i, j - 1, t[j], ...)
end

local function jitable_pack(...)
  return select("#", ...), {...}
end

--[[
local function vswap(...)
  local n = select("#", ...)
  if n == 1 then
    return ...
  end
  return select(n, ...), vswap(unpack({ ... }, 1, n - 1))
end
--]]

local function swap_impl(n, ...)
  if n == 1 then return (...) end
  return select(n, ...), swap_impl(n-1, ...)
end

-- swap("a", "b", "c") -> "c", "b", "a"
-- swap(1, 2, 3, 4, 5) -> 5, 4, 3, 2, 1
local function swap(...)
  return swap_impl(select("#", ...), ...)
end

return
{
  pack = jitable_pack,
  unpack = function(t, i, j) return jitable_unpack(t, i or 1, j or #t) end,
  swap = swap,
}