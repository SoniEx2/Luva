-- I/O Utils

local tweaks = require("tweaks")
local modules = tweaks.modules

local ffi = modules.ffi
local C = ffi.C
local bit = modules.bit
local blshift = bit.lshift
local brshift = bit.rshift
local bor = bit.bor

-- file I/O stuff
ffi.cdef[[
typedef struct FILE FILE;
FILE *fopen(const char *path, const char *mode);
int fclose(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
int ferror(FILE *stream);
int feof(FILE *stream);
char *strerror(int errnum);
]]

-- fileutils stuff
ffi.cdef[[
typedef struct SEx_fwrapper {
  FILE *f;
  bool isClosed;
} SEx_fwrapper;
]]

local FILE = ffi.metatype("SEx_fwrapper", {
    __index =
    {
      -- low level functions
      -- LL: close
      close = function(f)
        if f.isClosed then
          error("attempt to use a closed file")
        end

        ffi.errno(0)

        local status = C.fclose(f) == 0

        local errno = ffi.errno()

        f.isClosed = true

        if not status and errno ~= 0 then
          return status, ffi.string(C.strerror(errno)), errno
        end

        return status
      end,
      -- LL: eof
      eof = function(f)
        return C.feof(f.f) ~= 0
      end,
      -- LL: error
      error = function(f)
        return C.ferror(f.f)
      end,
      -- LL: write
      write = function(f, s)
        if f.isClosed then
          error("attempt to use a closed file")
        end

        assert(type(s) == "string" or type(s) == "number")

        local str = tostring(s)
        local len = #str

        ffi.errno(0)
        local written = C.fwrite(str, 1, len, f.f)
        local status = written == len;

        if not status then
          -- TODO
          local errno = ffi.errno()
          local ferr = f:error()

          if errno ~= 0 then
            return status, ferr, ffi.string(C.strerror(errno)), errno
          end
          return status, ferr
        end

        return status
      end,
      -- LL: read
      read = function(f, x)
        if f.isClosed then
          error("attempt to use a closed file")
        end

        assert(type(x) == "number")

        local chars = ffi.new("char[?]", x)
        ffi.errno(0)
        local read = C.fread(chars, 1, x, f)

        if read ~= x then
          local errno = ffi.errno()
          local ferr = f:error()
          local feof = f:eof()
          if eof ~= 0 then
            return read == 0 and nil or ffi.string(chars, read)
          elseif ferr ~= 0 then
            return read == 0 and nil or ffi.string(chars, read), nil, ferr
          elseif errno ~= 0 then
            return read == 0 and nil or ffi.string(chars, read), ffi.string(C.strerror(errno)), errno
          end
        end

        return ffi.string(chars, read)
      end,
      -- ML: readb
      readb = function(f, x)
        if x == "*b" then
          local data, err, ec = f:read(1);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a          = data:byte(1, -1)
          return ffi.cast("uint8_t" , a)

        elseif x == "*B" then
          local data, err, ec = f:read(1);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a          = data:byte(1, -1)
          return ffi.cast("int8_t"  , a)

        elseif x == "*s" then
          local data, err, ec = f:read(2);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a, b       = data:byte(1, -1)
          return ffi.cast("uint16_t", bor(blshift(a, 8), b))

        elseif x == "*S" then
          local data, err, ec = f:read(2);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a, b       = data:byte(1, -1)
          return ffi.cast("int16_t" , bor(blshift(a, 8), b))

        elseif x == "*i" then
          local data, err, ec = f:read(4);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a, b, c, d = data:byte(1, -1)
          return ffi.cast("uint32_t", bor(blshift(a, 24), blshift(b, 16), blshift(c, 8), d))

        elseif x == "*I" then
          local data, err, ec = f:read(4);
          if not data then if not err and not ec then return data end return data, err, ec end

          local a, b, c, d = data:byte(1, -1)
          return ffi.cast("int32_t",  bor(blshift(a, 24), blshift(b, 16), blshift(c, 8), d))

        else
          error(x)
        end
      end,
      -- HL: readn
      -- like readb() but returns a Lua number
      readn = function(f, x)
        return tonumber(f:readb(x))
      end
    }
  }
)

local gcfunc = function(f)
  if not f.isClosed then
    f:close()
  end
end

local function open(p, m)
  ffi.errno(0)
  local f = C.fopen(p, m)
  if f == nil then
    local errno = ffi.errno()
    return nil, p .. ": " .. ffi.string(C.strerror(errno)), errno
  end
  return ffi.gc(FILE(f, false), gcfunc)
end

return
{
  open = open,
}