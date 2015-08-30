local _IOFBF,_IOLBF,_IONBF,SEEK_SET,SEEK_CUR,SEEK_END=0,1,2,0,1,2
-- change environment
setfenv(1, setmetatable({}, {__index=getfenv(),__newindex=error}))

--local modules = require("tweaks").modules
local bit = require"bit"
local ffi = require"ffi"
local C = ffi.C

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

-- change as needed
local buffersize = 8192

--[[
/*
** $Id: liolib.c,v 2.112.1.1 2013/04/12 18:48:47 roberto Exp $
** Standard I/O (and system) library
** See Copyright Notice in lua.h
*/


/*
** This definition must come before the inclusion of 'stdio.h'; it
** should not affect non-POSIX systems
*/
#if !defined(_FILE_OFFSET_BITS)
#define	_LARGEFILE_SOURCE	1
#define _FILE_OFFSET_BITS	64
#endif


#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define liolib_c
#define LUA_LIB

#include "lua.h"

#include "lauxlib.h"
#include "lualib.h"


#if !defined(lua_checkmode)

/*
** Check whether 'mode' matches '[rwa]%+?b?'.
** Change this macro to accept other modes for 'fopen' besides
** the standard ones.
*/
#define lua_checkmode(mode) \
	(*mode != '\0' && strchr("rwa", *(mode++)) != NULL &&	\
	(*mode != '+' || ++mode) &&  /* skip if char is '+' */	\
	(*mode != 'b' || ++mode) &&  /* skip if char is 'b' */	\
	(*mode == '\0'))

#endif
--]]
local lua_checkmode = (function()
    local function lua_checkmode_char(str, pos)
      return string.sub(str, pos, pos)
    end
    local function poi(v)
      local x = v.d
      v.d = x + 1
      return x
    end
    ffi.cdef[[
      struct SExCOps {
        double d;
      }
    ]]
    local function lua_checkmode(mode)
      local n = ffi.new("struct SExCOps", 1)
      return #mode ~= 0 and string.find("rwa", lua_checkmode_char(mode, poi(n)), 1, true) and -- good thing "plain" searches get JITted huh?
      (lua_checkmode_char(mode, n.d) ~= '+' or poi(n)) and -- skip if char is '+'
      (lua_checkmode_char(mode, n.d) ~= 'b' or poi(n)) and -- skip if char is 'b'
      (n.d - 1) == #mode
    end
    return lua_checkmode
  end)()

--[[
-- TODO reimplement io.popen (priority: low)
/*
** {======================================================
** lua_popen spawns a new process connected to the current
** one through the file streams.
** =======================================================
*/
-- the "--" below fixes an IDE issue I'm having
--#if !defined(lua_popen)	/* { */
  
  #if defined(LUA_USE_POPEN)	/* { */

    #define lua_popen(L,c,m)	((void)L, fflush(NULL), popen(c,m))
    #define lua_pclose(L,file)	((void)L, pclose(file))

    #elif defined(LUA_WIN)		/* }{ */

    #define lua_popen(L,c,m)		((void)L, _popen(c,m))
    #define lua_pclose(L,file)		((void)L, _pclose(file))


    #else				/* }{ */

    #define lua_popen(L,c,m)		((void)((void)c, m),  \
		luaL_error(L, LUA_QL("popen") " not supported"), (FILE*)0)
    #define lua_pclose(L,file)		((void)((void)L, file), -1)


    #endif				/* } */

  #endif			/* } */

/* }====================================================== */
--]]


--[[
  #define IO_PREFIX	"_IO_"
  #define IO_INPUT	(IO_PREFIX "input")
  #define IO_OUTPUT	(IO_PREFIX "output")
--]]
local IO_PREFIX = "_IO_"
local IO_INPUT = IO_PREFIX .. "input"
local IO_OUTPUT = IO_PREFIX .. "output"
local stdio = {}


--typedef luaL_Stream LStream;
ffi.cdef[[
typedef struct FILE FILE;

typedef struct SExIO_Stream {
  FILE *f;  /* stream (NULL for incompletely created streams) */
} SExIO_Stream;
]]
local closef = {}

--#define tolstream(L)	((LStream *)luaL_checkudata(L, 1, LUA_FILEHANDLE))
local function tolstream(v)
  return ffi.istype("SExIO_Stream", v) and v or error("bad argument (SExIO_Stream expected)")
end

--#define isclosed(p)	((p)->closef == NULL)
local function isclosed(p)
  return closef[p] == nil
end


--[[
static int io_type (lua_State *L) {
  LStream *p;
  luaL_checkany(L, 1);
  p = (LStream *)luaL_testudata(L, 1, LUA_FILEHANDLE);
  if (p == NULL)
    lua_pushnil(L);  /* not a file */
  else if (isclosed(p))
    lua_pushliteral(L, "closed file");
  else
    lua_pushliteral(L, "file");
  return 1;
}
--]]
local function io_type(p)
  if not ffi.istype("SExIO_Stream", p) then
    return nil
  elseif isclosed(p) then
    return "closed file"
  else
    return "file"
  end
end


--[[
static int f_tostring (lua_State *L) {
  LStream *p = tolstream(L);
  if (isclosed(p))
    lua_pushliteral(L, "file (closed)");
  else
    lua_pushfstring(L, "file (%p)", p->f);
  return 1;
}
--]]
ffi.cdef[[
int sprintf(char *str, const char *format, ...);
]]
local function f_tostring(p)
  p = tolstream(p)
  if isclosed(p) then
    return "file (closed)"
  else
    local buf = ffi.new("char[?]", 2 + ffi.sizeof("void *") * 2)
    local x = C.sprintf(buf, "%p", p.f)
    return "file (" .. ffi.string(buf, x) .. ")"
  end
end


--[[
static FILE *tofile (lua_State *L) {
  LStream *p = tolstream(L);
  if (isclosed(p))
    luaL_error(L, "attempt to use a closed file");
  lua_assert(p->f);
  return p->f;
}
--]]
local function tofile(p)
  p = tolstream(p)
  if isclosed(p) then
    error("attempt to use a closed file")
  end
  -- assert(p.f ~= nil)
  return p.f
end


--[[
/*
** When creating file handles, always creates a `closed' file handle
** before opening the actual file; so, if there is a memory error, the
** file is not left opened.
*/
static LStream *newprefile (lua_State *L) {
  LStream *p = (LStream *)lua_newuserdata(L, sizeof(LStream));
  p->closef = NULL;  /* mark file handle as 'closed' */
  luaL_setmetatable(L, LUA_FILEHANDLE);
  return p;
}
--]]
local function newprefile()
  local p = ffi.new("SExIO_Stream");
  closef[p] = nil;
  return p;
end


--[[
static int aux_close (lua_State *L) {
  LStream *p = tolstream(L);
  lua_CFunction cf = p->closef;
  p->closef = NULL;  /* mark stream as closed */
  return (*cf)(L);  /* close it */
}
--]]
local function aux_close(v)
  local p = tolstream(v)
  local f = closef[p]
  closef[p] = nil -- mark stream as closed
  return f(v) -- close it
end


--[[
static int io_close (lua_State *L) {
  if (lua_isnone(L, 1))  /* no argument? */
    lua_getfield(L, LUA_REGISTRYINDEX, IO_OUTPUT);  /* use standard output */
  tofile(L);  /* make sure argument is an open stream */
  return aux_close(L);
}
--]]
local function io_close(...)
  local v = ...
  if select('#', ...) == 0 then -- no argument?
    v = stdio[IO_OUTPUT] -- use standard output
  end
  tofile(v) -- make sure argument is an open stream
  return aux_close(v)
end


--[[
static int f_gc (lua_State *L) {
  LStream *p = tolstream(L);
  if (!isclosed(p) && p->f != NULL)
    aux_close(L);  /* ignore closed and incompletely open files */
  return 0;
}
--]]
local function f_gc(v)
  local p = tolstream(v)
  if (not isclosed(p) and p.f ~= nil) then
    aux_close(v)
  end
end


--[[
/*
** function to close regular files
*/
static int io_fclose (lua_State *L) {
  LStream *p = tolstream(L);
  int res = fclose(p->f);
  return luaL_fileresult(L, (res == 0), NULL);
}
--]]
ffi.cdef[[
int fclose(FILE *stream);
]]
local function io_fclose(v)
  local p = tolstream(v)
  local res = C.fclose(p.f)
  return fileresult(res, nil)
end


--[[
static LStream *newfile (lua_State *L) {
  LStream *p = newprefile(L);
  p->f = NULL;
  p->closef = &io_fclose;
  return p;
}
--]]
local function newfile()
  local p = newprefile()
  p.f = nil
  closef[p] = io_fclose
  return p
end


--[[
static void opencheck (lua_State *L, const char *fname, const char *mode) {
  LStream *p = newfile(L);
  p->f = fopen(fname, mode);
  if (p->f == NULL)
    luaL_error(L, "cannot open file " LUA_QS " (%s)", fname, strerror(errno));
}
--]]
local function opencheck(fname, mode)
  local p = newfile()
  p.f = C.fopen(fname, mode)
  if p.f == nil then
    error(string.format("cannot open file '%s' (%s)", fname, ffi.string(C.strerror(ffi.errno()))))
  end
  return p
end


--[[
static int io_open (lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  const char *mode = luaL_optstring(L, 2, "r");
  LStream *p = newfile(L);
  const char *md = mode;  /* to traverse/check mode */
  luaL_argcheck(L, lua_checkmode(md), 2, "invalid mode");
  p->f = fopen(filename, mode);
  return (p->f == NULL) ? luaL_fileresult(L, 0, filename) : 1;
}
--]]
ffi.cdef[[
FILE *fopen(const char *path, const char *mode);
]]
local function io_open(filename, mode)
  local p = newfile()
  if mode == nil then mode = "r" end
  if not lua_checkmode(mode) then error("bad argument (invalid mode)") end
  p.f = C.fopen(filename, mode)
  if p.f == nil then
    return fileresult(false, filename)
  end
  return p
end


--[[
-- TODO (priority: low)
/*
** function to close 'popen' files
*/
static int io_pclose (lua_State *L) {
  LStream *p = tolstream(L);
  return luaL_execresult(L, lua_pclose(L, p->f));
}
--]]


--[[
static int io_popen (lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  const char *mode = luaL_optstring(L, 2, "r");
  LStream *p = newprefile(L);
  p->f = lua_popen(L, filename, mode);
  p->closef = &io_pclose;
  return (p->f == NULL) ? luaL_fileresult(L, 0, filename) : 1;
}
--]]


--[[
static int io_tmpfile (lua_State *L) {
  LStream *p = newfile(L);
  p->f = tmpfile();
  return (p->f == NULL) ? luaL_fileresult(L, 0, NULL) : 1;
}
--]]
ffi.cdef[[
FILE *tmpfile(void);
]]
local function io_tmpfile()
  local p = newfile()
  p.f = C.tmpfile()
  if p.f == nil then
    return fileresult(false, nil)
  end
  return p
end


--[[
static FILE *getiofile (lua_State *L, const char *findex) {
  LStream *p;
  lua_getfield(L, LUA_REGISTRYINDEX, findex);
  p = (LStream *)lua_touserdata(L, -1);
  if (isclosed(p))
    luaL_error(L, "standard %s file is closed", findex + strlen(IO_PREFIX));
  return p->f;
}
--]]
local function getiofile(findex)
  local p = stdio[findex]
  if isclosed(p) then
    error("standard " .. string.sub(findex, #IO_PREFIX) .. " file is closed")
  end
  return p.f
end


--[[
static int g_iofile (lua_State *L, const char *f, const char *mode) {
  if (!lua_isnoneornil(L, 1)) {
    const char *filename = lua_tostring(L, 1);
    if (filename)
      opencheck(L, filename, mode);
    else {
      tofile(L);  /* check that it's a valid file handle */
      lua_pushvalue(L, 1);
    }
    lua_setfield(L, LUA_REGISTRYINDEX, f);
  }
  /* return current value */
  lua_getfield(L, LUA_REGISTRYINDEX, f);
  return 1;
}
--]]
local function g_iofile(p, f, mode)
  if p then
    if type(p) == "string" then
      stdio[f] = opencheck(p, mode)
    else
      stdio[f] = tofile(p)
    end
  end
  return stdio[f]
end


--[[
static int io_input (lua_State *L) {
  return g_iofile(L, IO_INPUT, "r");
}
--]]
local function io_input(p)
  return g_iofile(p, IO_INPUT, "r")
end


--[[
static int io_output (lua_State *L) {
  return g_iofile(L, IO_OUTPUT, "w");
}
--]]
local function io_output(p)
  return g_iofile(p, IO_OUTPUT, "w")
end


--static int io_readline (lua_State *L);
local make_io_readline


--[[
static void aux_lines (lua_State *L, int toclose) {
  int i;
  int n = lua_gettop(L) - 1;  /* number of arguments to read */
  /* ensure that arguments will fit here and into 'io_readline' stack */
  luaL_argcheck(L, n <= LUA_MINSTACK - 3, LUA_MINSTACK - 3, "too many options");
  lua_pushvalue(L, 1);  /* file handle */
  lua_pushinteger(L, n);  /* number of arguments to read */
  lua_pushboolean(L, toclose);  /* close/not close file when finished */
  for (i = 1; i <= n; i++) lua_pushvalue(L, i + 1);  /* copy arguments */
  lua_pushcclosure(L, io_readline, 3 + n);
}
--]]
local function aux_lines(p, toclose, ...)
  return make_io_readline(p, toclose, ...)
end


--[[
static int f_lines (lua_State *L) {
  tofile(L);  /* check that it's a valid file handle */
  aux_lines(L, 0);
  return 1;
}
--]]
local function f_lines(p, ...)
  tofile(p)
  return aux_lines(p, false, ...)
end


--[[
static int io_lines (lua_State *L) {
  int toclose;
  if (lua_isnone(L, 1)) lua_pushnil(L);  /* at least one argument */
  if (lua_isnil(L, 1)) {  /* no file name? */
    lua_getfield(L, LUA_REGISTRYINDEX, IO_INPUT);  /* get default input */
    lua_replace(L, 1);  /* put it at index 1 */
    tofile(L);  /* check that it's a valid file handle */
    toclose = 0;  /* do not close it after iteration */
  }
  else {  /* open a new file */
    const char *filename = luaL_checkstring(L, 1);
    opencheck(L, filename, "r");
    lua_replace(L, 1);  /* put file at index 1 */
    toclose = 1;  /* close it after iteration */
  }
  aux_lines(L, toclose);
  return 1;
}
--]]
local function io_lines(v, ...)
  local toclose
  local p
  if v == nil then
    p = tofile(stdio[IO_INPUT])
    toclose = false
  else
    if type(v) ~= "string" then error("bad argument (string expected)") end
    p = opencheck(filename, "r")
    toclose = true
  end
  return aux_lines(p, toclose, ...)
end


--[[
/*
** {======================================================
** READ
** =======================================================
*/


static int read_number (lua_State *L, FILE *f) {
  lua_Number d;
  if (fscanf(f, LUA_NUMBER_SCAN, &d) == 1) {
    lua_pushnumber(L, d);
    return 1;
  }
  else {
   lua_pushnil(L);  /* "result" to be removed */
   return 0;  /* read fails */
  }
}
--]]
ffi.cdef[[
int fscanf(FILE *stream, const char *format, ...);
void *malloc(size_t size);
void free(void *ptr);
]]
local function read_number(f)
  -- ew, is this really needed?
  local dptr = ffi.cast("double *", C.malloc(ffi.sizeof("double")))
  if C.fscanf(f, "%1f", dptr) == 1 then
    C.free(dptr)
    return true, tonumber(dptr[0])
  else
    C.free(dptr)
    return false, nil
  end
end


--[[
static int test_eof (lua_State *L, FILE *f) {
  int c = getc(f);
  ungetc(c, f);
  lua_pushlstring(L, NULL, 0);
  return (c != EOF);
}
--]]
ffi.cdef[[
int fgetc(FILE *stream);
int ungetc(int c, FILE *stream);
]]
local function test_eof(f)
  local c = C.fgetc(f)
  C.ungetc(c, f)
  local status = not (0 <= c and c <= 255) -- idk how else I'm supposed to get the value of "EOF", but let's NOT assume it's -1
  if status then
    return status, ""
  else
    return status, nil
  end
end


--[[
static int read_line (lua_State *L, FILE *f, int chop) {
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  for (;;) {
    size_t l;
    char *p = luaL_prepbuffer(&b);
    if (fgets(p, LUAL_BUFFERSIZE, f) == NULL) {  /* eof? */
      luaL_pushresult(&b);  /* close buffer */
      return (lua_rawlen(L, -1) > 0);  /* check whether read something */
    }
    l = strlen(p);
    if (l == 0 || p[l-1] != '\n')
      luaL_addsize(&b, l);
    else {
      luaL_addsize(&b, l - chop);  /* chop 'eol' if needed */
      luaL_pushresult(&b);  /* close buffer */
      return 1;  /* read at least an `eol' */
    }
  }
}
--]]
ffi.cdef[[
size_t strlen(const char *s);
char *fgets(char *s, int size, FILE *stream);
]]
local read_line = (function() -- in case you need extra locals
    local p = ffi.new("char[?]", buffersize) -- do this outside so we save on both GC AND allocations
    ffi.fill(p, buffersize)
    local function read_line(f, chop)
      local buffer = ""

      -- run this once outside the loop, this makes it 200% faster
      if C.fgets(p, buffersize, f) == nil then
        return #buffer > 0, buffer
      end
      local l = C.strlen(p)
      if l == 0 or p[l-1] ~= ffi.cast("char*", '\n')[0] then
        buffer = buffer .. ffi.string(p, l)
      else
        buffer = buffer .. ffi.string(p, l - chop)
        return true, buffer
      end

      while true do
        if C.fgets(p, buffersize, f) == nil then
          return #buffer > 0, buffer
        end

        local l = C.strlen(p)
        if l == 0 or p[l-1] ~= ffi.cast("char*", '\n')[0] then
          buffer = buffer .. ffi.string(p, l)
        else
          buffer = buffer .. ffi.string(p, l - chop)
          return true, buffer
        end
      end
    end
    return read_line
  end)() -- call to generate function


--#define MAX_SIZE_T	(~(size_t)0)
local MAX_SIZE_T = bit.bnot(ffi.new("size_t", 0))

--[[
static void read_all (lua_State *L, FILE *f) {
  size_t rlen = LUAL_BUFFERSIZE;  /* how much to read in each cycle */
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  for (;;) {
    char *p = luaL_prepbuffsize(&b, rlen);
    size_t nr = fread(p, sizeof(char), rlen, f);
    luaL_addsize(&b, nr);
    if (nr < rlen) break;  /* eof? */
    else if (rlen <= (MAX_SIZE_T / 4))  /* avoid buffers too large */
      rlen *= 2;  /* double buffer size at each iteration */
  }
  luaL_pushresult(&b);  /* close buffer */
}
--]]
ffi.cdef[[
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
]]
local read_all = (function() -- in case you need extra locals
    -- b gets GCed as needed
    local b = setmetatable({ffi.new("char[?]", buffersize)},{__mode = "v"})
    local bs = buffersize
    local function read_all(f)
      local rlen = buffersize
      local buffer = ""
      while true do
        local p = b[1]
        if not p or rlen > bs then
          p = ffi.new("char[?]", rlen)
          b[1] = p
          bs = rlen
        end
        local nr = C.fread(p, ffi.sizeof("char"), rlen, f)
        buffer = buffer .. ffi.string(p, nr)
        if nr < rlen then
          break
        elseif rlen <= (MAX_SIZE_T / 4) then
          rlen = rlen * 2
        end
      end
      return buffer
    end
    return read_all
  end)() -- call to generate function


--[[
static int read_chars (lua_State *L, FILE *f, size_t n) {
  size_t nr;  /* number of chars actually read */
  char *p;
  luaL_Buffer b;
  luaL_buffinit(L, &b);
  p = luaL_prepbuffsize(&b, n);  /* prepare buffer to read whole block */
  nr = fread(p, sizeof(char), n, f);  /* try to read 'n' chars */
  luaL_addsize(&b, nr);
  luaL_pushresult(&b);  /* close buffer */
  return (nr > 0);  /* true iff read something */
}
--]]
local function read_chars(f, n)
  local buffer = ""
  local p = ffi.new("char[?]", n)
  local nr = C.fread(p, ffi.sizeof("char"), n, f)
  buffer = buffer .. ffi.string(p, nr)
  return nr > 0, buffer
end


--[[
static int g_read (lua_State *L, FILE *f, int first) {
  int nargs = lua_gettop(L) - 1;
  int success;
  int n;
  clearerr(f);
  if (nargs == 0) {  /* no arguments? */
    success = read_line(L, f, 1);
    n = first+1;  /* to return 1 result */
  }
  else {  /* ensure stack space for all results and for auxlib's buffer */
    luaL_checkstack(L, nargs+LUA_MINSTACK, "too many arguments");
    success = 1;
    for (n = first; nargs-- && success; n++) {
      if (lua_type(L, n) == LUA_TNUMBER) {
        size_t l = (size_t)lua_tointeger(L, n);
        success = (l == 0) ? test_eof(L, f) : read_chars(L, f, l);
      }
      else {
        const char *p = lua_tostring(L, n);
        luaL_argcheck(L, p && p[0] == '*', n, "invalid option");
        switch (p[1]) {
          case 'n':  /* number */
            success = read_number(L, f);
            break;
          case 'l':  /* line */
            success = read_line(L, f, 1);
            break;
          case 'L':  /* line with end-of-line */
            success = read_line(L, f, 0);
            break;
          case 'a':  /* file */
            read_all(L, f);  /* read entire file */
            success = 1; /* always success */
            break;
          default:
            return luaL_argerror(L, n, "invalid format");
        }
      }
    }
  }
  if (ferror(f))
    return luaL_fileresult(L, 0, NULL);
  if (!success) {
    lua_pop(L, 1);  /* remove last result */
    lua_pushnil(L);  /* push nil instead */
  }
  return n - first;
}
--]]
ffi.cdef[[
int ferror(FILE *stream);
]]
local g_read = (function()
    local function g_readloop(f, n, ...)
      local v
      local success = true
      if type((select(n, ...))) == "number" then
        local l = ffi.cast("size_t", (select(n, ...)))
        if l == 0 then
          success, v = test_eof(f)
        else
          success, v = read_chars(f, l)
        end
      else
        if string.sub((select(n, ...)), 1, 1) ~= "*" then error("bad argument (invalid option)") end
        local p1 = string.sub((select(n, ...)), 2, 2)
        if p1 == "n" then
          success, v = read_number(f)
        elseif p1 == "l" then
          success, v = read_line(f, 1)
        elseif p1 == "L" then
          success, v = read_line(f, 0)
        elseif p1 == "a" then
          success, v = true, read_all(f)
        else
          error("bad argument (invalid format)")
        end
      end
      if not success then return nil end
      if n == select('#', ...) then return v end
      return v, g_readloop(f, n + 1, ...)
    end
    local function handle_g_read(f, ...)
      if C.ferror(f) ~= 0 then
        return luaL.fileresult(0, nil)
      end
      return ...
    end
    local function g_read(f, ...)
      if select('#', ...) == 0 then
        return read_line(f, 1);
      end
      return handle_g_read(f, g_readloop(f, 1, ...))
    end
    return g_read
  end)()

-- g_read with tables instead of vararg. used for io.lines() (and file:lines())
local g_read_t = (function()
    local function g_readloop_t(f, n, nargs, t)
      local v
      local success = true
      if type(t[n]) == "number" then
        local l = ffi.cast("size_t", t[n])
        if l == 0 then
          success, v = test_eof(f)
        else
          success, v = read_chars(f, l)
        end
      else
        if string.sub(t[n], 1, 1) ~= "*" then error("bad argument (invalid option)") end
        local p1 = string.sub(t[n], 2, 2)
        if p1 == "n" then
          success, v = read_number(f)
        elseif p1 == "l" then
          success, v = read_line(f, 1)
        elseif p1 == "L" then
          success, v = read_line(f, 0)
        elseif p1 == "a" then
          success, v = true, read_all(f)
        else
          error("bad argument (invalid format)")
        end
      end
      if not success then return nil end
      if n == nargs then return v end
      return v, g_readloop_t(f, n + 1, nargs, t)
    end
    local function handle_g_read_t(f, ...)
      if C.ferror(f) ~= 0 then
        return luaL.fileresult(0, nil)
      end
      return ...
    end
    local function g_read_t(f, nargs, t)
      if nargs == 0 then
        return read_line(f, 1);
      end
      return handle_g_read_t(f, g_readloop_t(f, 1, nargs, t))
    end
    return g_read_t
  end)()


--[[
static int io_read (lua_State *L) {
  return g_read(L, getiofile(L, IO_INPUT), 1);
}
--]]
local function io_read(...)
  return g_read(getiofile(IO_INPUT), ...)
end


--[[
static int f_read (lua_State *L) {
  return g_read(L, tofile(L), 2);
}
--]]
local function f_read(f, ...)
  return g_read(tofile(f), ...)
end


--[[
static int io_readline (lua_State *L) {
  LStream *p = (LStream *)lua_touserdata(L, lua_upvalueindex(1));
  int i;
  int n = (int)lua_tointeger(L, lua_upvalueindex(2));
  if (isclosed(p))  /* file is already closed? */
    return luaL_error(L, "file is already closed");
  lua_settop(L , 1);
  for (i = 1; i <= n; i++)  /* push arguments to 'g_read' */
    lua_pushvalue(L, lua_upvalueindex(3 + i));
  n = g_read(L, p->f, 2);  /* 'n' is number of results */
  lua_assert(n > 0);  /* should return at least a nil */
  if (!lua_isnil(L, -n))  /* read at least one value? */
    return n;  /* return them */
  else {  /* first result is nil: EOF or error */
    if (n > 1) {  /* is there error information? */
      /* 2nd result is error message */
      return luaL_error(L, "%s", lua_tostring(L, -n + 1));
    }
    if (lua_toboolean(L, lua_upvalueindex(3))) {  /* generator created file? */
      lua_settop(L, 0);
      lua_pushvalue(L, lua_upvalueindex(1));
      aux_close(L);  /* close it */
    }
    return 0;
  }
}
--]]
make_io_readline = (function()
    function make_io_readline(p, toclose, ...)
      local tn, t = select('#', ...), {...}
      local function handle_return(...)
        local n = select("#", ...)
        -- lua_assert(n > 0)
        if (...) ~= nil then
          return ...
        end
        if n > 1 then
          error((select(2, ...)))
        end
        if toclose then
          aux_close(p)
        end
        -- return
      end
      local function io_readline()
        if isclosed(p) then
          error("file is already closed")
        end
        return handle_return(g_read_t(p.f, tn, t))
      end
      return io_readline
    end
    return make_io_readline
  end)()

--[[
/* }====================================================== */
--]]

--[[
static int g_write (lua_State *L, FILE *f, int arg) {
  int nargs = lua_gettop(L) - arg;
  int status = 1;
  for (; nargs--; arg++) {
    if (lua_type(L, arg) == LUA_TNUMBER) {
      /* optimization: could be done exactly as for strings */
      status = status &&
          fprintf(f, LUA_NUMBER_FMT, lua_tonumber(L, arg)) > 0;
    }
    else {
      size_t l;
      const char *s = luaL_checklstring(L, arg, &l);
      status = status && (fwrite(s, sizeof(char), l, f) == l);
    }
  }
  if (status) return 1;  /* file handle already on stack top */
  else return luaL_fileresult(L, status, NULL);
}
--]]
ffi.cdef[[
int fprintf(FILE *stream, const char *format, ...);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
]]
local function g_write(f, ...)
  local status = true
  local nargs = select('#', ...)
  for i=1, nargs do
    if type((select(i, ...))) == "number" then
      status = status and C.fprintf(f, "%.14g", ffi.cast("double", (select(i, ...)))) > 0
    elseif type((select(i, ...))) == "string" then
      status = status and (C.fwrite((select(i, ...)), ffi.sizeof("char"), #(select(i, ...)), f) == #(select(i, ...)))
    else
      error("bad argument (string expected)")
    end
  end
  if status then
    return true
  else
    return fileresult(status, nil)
  end
end


--[[
static int io_write (lua_State *L) {
  return g_write(L, getiofile(L, IO_OUTPUT), 1);
}
--]]
local function io_write(...)
  return g_write(getiofile(IO_OUTPUT), ...)
end


--[[
static int f_write (lua_State *L) {
  FILE *f = tofile(L);
  lua_pushvalue(L, 1);  /* push file at the stack top (to be returned) */
  return g_write(L, f, 2);
}
--]]
local function f_write(p, ...)
  local f = tofile(p)
  return g_write(f, ...)
end


--[[
static int f_seek (lua_State *L) {
  static const int mode[] = {SEEK_SET, SEEK_CUR, SEEK_END};
  static const char *const modenames[] = {"set", "cur", "end", NULL};
  FILE *f = tofile(L);
  int op = luaL_checkoption(L, 2, "cur", modenames);
  lua_Number p3 = luaL_optnumber(L, 3, 0);
  l_seeknum offset = (l_seeknum)p3;
  luaL_argcheck(L, (lua_Number)offset == p3, 3,
                  "not an integer in proper range");
  op = l_fseek(f, offset, mode[op]);
  if (op)
    return luaL_fileresult(L, 0, NULL);  /* error */
  else {
    lua_pushnumber(L, (lua_Number)l_ftell(f));
    return 1;
  }
}
--]]
-- TODO (priority: high)
local f_seek = (function()
    if true then return end
    local mode = {["set"] = SEEK_SET, ["cur"] = SEEK_CUR, ["end"] = SEEK_END}
    local isposix = {["Linux"]=true, ["OSX"]=true, ["BSD"]=true, ["POSIX"]=true}
    if ffi.abi("win") then
      -- TODO
      ffi.cdef[[
      int fseek(FILE *stream, long offset, int whence);
      long ftell(FILE *stream);
      ]]
      local function f_seek(p, op, p3)
        local f = tofile(p)
        op = op == nil and "cur" or op
        if type(op) ~= "string" then error("bad argument (string expected)") end
        if not mode[op] then error("bad argument (invalid option)") end
        p3 = tonumber(p3 or 0)
        local offset = ffi.cast("long", p3)
        if offset ~= p3 then error("bad argument (not an integer in proper range)") end
        op = C.fseek(f, offset, mode[op])
        if op ~= 0 then
          return fileresult(false, nil)
        end
        return tonumber(C.ftell(f))
      end
      return f_seek
    elseif isposix[ffi.os] then
      ffi.cdef[[
      int fseek(FILE *stream, long offset, int whence);
      long ftell(FILE *stream);
      ]]
      local function f_seek(p, op, p3)
        local f = tofile(p)
        op = op == nil and "cur" or op
        if type(op) ~= "string" then error("bad argument (string expected)") end
        if not mode[op] then error("bad argument (invalid option)") end
        p3 = tonumber(p3 or 0)
        local offset = ffi.cast("long", p3)
        if offset ~= p3 then error("bad argument (not an integer in proper range)") end
        op = C.fseek(f, offset, mode[op])
        if op ~= 0 then
          return fileresult(false, nil)
        end
        return tonumber(C.ftell(f))
      end
      return f_seek
    else
      ffi.cdef[[
      int fseek(FILE *stream, long offset, int whence);
      long ftell(FILE *stream);
      ]]
      local function f_seek(p, op, p3)
        local f = tofile(p)
        op = op == nil and "cur" or op
        if type(op) ~= "string" then error("bad argument (string expected)") end
        if not mode[op] then error("bad argument (invalid option)") end
        p3 = tonumber(p3 or 0)
        local offset = ffi.cast("long", p3)
        if offset ~= p3 then error("bad argument (not an integer in proper range)") end
        op = C.fseek(f, offset, mode[op])
        if op ~= 0 then
          return fileresult(false, nil)
        end
        return tonumber(C.ftell(f))
      end
      return f_seek
    end
  end)()


--[[
-- TODO (priority: medium)
static int f_setvbuf (lua_State *L) {
  static const int mode[] = {_IONBF, _IOFBF, _IOLBF};
  static const char *const modenames[] = {"no", "full", "line", NULL};
  FILE *f = tofile(L);
  int op = luaL_checkoption(L, 2, NULL, modenames);
  lua_Integer sz = luaL_optinteger(L, 3, LUAL_BUFFERSIZE);
  int res = setvbuf(f, NULL, mode[op], sz);
  return luaL_fileresult(L, res == 0, NULL);
}
--]]



--[[
static int io_flush (lua_State *L) {
  return luaL_fileresult(L, fflush(getiofile(L, IO_OUTPUT)) == 0, NULL);
}
--]]
ffi.cdef[[
int fflush(FILE *stream);
]]
local function io_flush(f)
  return fileresult(C.fflush(getiofile("IO_OUTPUT")) == 0, nil);
end


--[[
static int f_flush (lua_State *L) {
  return luaL_fileresult(L, fflush(tofile(L)) == 0, NULL);
}
--]]
local function f_flush(f)
  return fileresult(C.fflush(tofile(f)) == 0, nil);
end


--[[
/*
** functions for 'io' library
*/
static const luaL_Reg iolib[] = {
  {"close", io_close},
  {"flush", io_flush},
  {"input", io_input},
  {"lines", io_lines},
  {"open", io_open},
  {"output", io_output},
  {"popen", io_popen},
  {"read", io_read},
  {"tmpfile", io_tmpfile},
  {"type", io_type},
  {"write", io_write},
  {NULL, NULL}
};
--]]
local iolib = {
  close = io_close,
  flush = io_flush,
  input = io_input,
  lines = io_lines,
  open = io_open,
  output = io_output,
  popen = io_popen,
  read = io_read,
  tmpfile = io_tmpfile,
  type = io_type,
  write = io_write,
}


--[[
/*
** methods for file handles
*/
static const luaL_Reg flib[] = {
  {"close", io_close},
  {"flush", f_flush},
  {"lines", f_lines},
  {"read", f_read},
  {"seek", f_seek},
  {"setvbuf", f_setvbuf},
  {"write", f_write},
  {"__gc", f_gc},
  {"__tostring", f_tostring},
  {NULL, NULL}
};
--]]
local flib = {
  close = io_close,
  flush = f_flush,
  lines = f_lines,
  read = f_read,
  seek = f_seek,
  setvbuf = f_setvbuf,
  write = f_write,
  __gc = f_gc,
  __tostring = f_tostring,
}
flib.__index = flib
ffi.metatype("SExIO_Stream", flib)


--[[
static void createmeta (lua_State *L) {
  luaL_newmetatable(L, LUA_FILEHANDLE);  /* create metatable for file handles */
  lua_pushvalue(L, -1);  /* push metatable */
  lua_setfield(L, -2, "__index");  /* metatable.__index = metatable */
  luaL_setfuncs(L, flib, 0);  /* add file methods to new metatable */
  lua_pop(L, 1);  /* pop new metatable */
}
--]]


--[[
/*
** function to (not) close the standard files stdin, stdout, and stderr
*/
static int io_noclose (lua_State *L) {
  LStream *p = tolstream(L);
  p->closef = &io_noclose;  /* keep file opened */
  lua_pushnil(L);
  lua_pushliteral(L, "cannot close standard file");
  return 2;
}
--]]
local function io_noclose(p)
  p = tolstream(p)
  closef[p] = io_noclose
  return nil, "cannot close standard file"
end


--[[
static void createstdfile (lua_State *L, FILE *f, const char *k,
                           const char *fname) {
  LStream *p = newprefile(L);
  p->f = f;
  p->closef = &io_noclose;
  if (k != NULL) {
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, k);  /* add file to registry */
  }
  lua_setfield(L, -2, fname);  /* add file to module */
}
--]]
local function createstdfile(f, k, fname, t)
  local p = newprefile()
  p.f = f
  closef[p] = io_noclose
  if k ~= nil then
    stdio[k] = p
  end
  t[fname] = p
end


--[[
LUAMOD_API int luaopen_io (lua_State *L) {
  luaL_newlib(L, iolib);  /* new module */
  createmeta(L);
  /* create (and set) default files */
  createstdfile(L, stdin, IO_INPUT, "stdin");
  createstdfile(L, stdout, IO_OUTPUT, "stdout");
  createstdfile(L, stderr, NULL, "stderr");
  return 1;
}
--]]

createstdfile(ffi.cast("FILE*", io.stdin), IO_INPUT, "stdin", iolib)
createstdfile(ffi.cast("FILE*", io.stdout), IO_OUTPUT, "stdout", iolib)
createstdfile(ffi.cast("FILE*", io.stderr), nil, "stderr", iolib)

return iolib