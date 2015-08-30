-- "dummy" lauxlib, implements only things required by liolib.lua

setfenv(1, setmetatable({}, {__index=getfenv()}))

local modules = require("tweaks").modules
local ffi = modules.ffi
local C = ffi.C

--[[
LUALIB_API int luaL_fileresult (lua_State *L, int stat, const char *fname) {
  int en = errno;  /* calls to Lua API may change this value */
  if (stat) {
    lua_pushboolean(L, 1);
    return 1;
  }
  else {
    lua_pushnil(L);
    if (fname)
      lua_pushfstring(L, "%s: %s", fname, strerror(en));
    else
      lua_pushstring(L, strerror(en));
    lua_pushinteger(L, en);
    return 3;
  }
}
]]
ffi.cdef[[
char *strerror(int errnum);
]]
local function fileresult(stat, fname)
  if stat then
    return true
  end
  local en = ffi.errno()
  io.write("Calling C.strerror(en)")
  return nil, fname and (fname .. ": " .. ffi.string(C.strerror(en))) or ffi.string(C.strerror(en)), en
end

return
{
fileresult = fileresult,
buffersize = 8192,
}