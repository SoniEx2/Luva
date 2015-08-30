-- cops.lua
-- C operators for Lua(JIT)

setfenv(1, setmetatable({}, {__index=getfenv()}))

local modules = require("tweaks").modules
local ffi = modules.ffi
local C = ffi.C

-- v += n
local function add(v, n)
  v.d = v.d + n
  return v.d
end

-- v -= n
local function sub(v, n)
  v.d = v.d - n
  return v.d
end

local function get(v)
  return v.d
end

local function set(v, n)
  v.d = n
  return v.d
end

-- ++v
local function preincrement(v)
  return v:add(1)
end

-- v++
local function postincrement(v)
  local x = v:get()
  v:add(1)
  return x
end

-- --v
local function predecrement(v)
  return v:sub(1)
end

-- v--
local function postdecrement(v)
  local x = v:get()
  v:sub(1)
  return x
end

ffi.cdef[[
struct SExCOps {
  double d;
}
]]

local wrapper = ffi.metatype("struct SExCOps", {
    __index = {
      add = add,
      sub = sub,
      get = get,
      set = set,
      pri = preincrement,
      poi = postincrement,
      prd = predecrement,
      pod = postdecrement
    }
  }
)

local function new(initial_value)
  return wrapper(initial_value)
end

return {new = new}