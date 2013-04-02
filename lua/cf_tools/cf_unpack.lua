local ffi = require("ffi")
ffi.cdef[[
int _mkdir(const char* pathname);
]]
local C = ffi.C

require 'zlib_h'
local zlib = ffi.load(ffi.os == "Windows" and "bin/zlib1" or "z")

local cf = require 'cf_tools.cf_reader'

local zlib_version = ffi.string(zlib.zlibVersion())
local zerr = {
    [zlib.Z_ERRNO        ] = "i/o error",
    [zlib.Z_STREAM_ERROR ] = "invalid compression level",
    [zlib.Z_DATA_ERROR   ] = "invalid or incomplete deflate data",
    [zlib.Z_MEM_ERROR    ] = "out of memory",
    [zlib.Z_VERSION_ERROR] = "zlib version mismatch!"
}

-- http://www.zlib.net/zpipe.c
local function inflate(source, CHUNK)
    CHUNK = CHUNK or 16384
    local slen = #source
    local spos = 0
    local function read(start, len)
        spos = math.min(slen, start + len)
        return source:sub(start + 1, spos), spos - start
    end

    local dest = {}
    local have = 0
    local strm = ffi.new 'z_stream'
    local out  = ffi.new('uint8_t[?]', CHUNK)

    -- allocate inflate state
    strm.zalloc = nil;
    strm.zfree  = nil;
    strm.opaque = nil;
    strm.avail_in, strm.next_in = 0, nil;

    local ret = zlib.inflateInit2_(strm, -15, zlib_version, ffi.sizeof(strm));
    if ret ~=  zlib.Z_OK then return ret end

    local data, size -- data must be anchored as an upvalue!!!

    -- decompress until deflate stream ends or end of file
    repeat
        data, size = read(spos, CHUNK)
        strm.next_in, strm.avail_in = data, size
        if strm.avail_in == 0 then break end

        -- run inflate() on input until output buffer not full
        repeat
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = zlib.inflate(strm, zlib.Z_NO_FLUSH)
            assert(ret ~= zlib.Z_STREAM_ERROR); -- state not clobbered
            if ret == zlib.Z_NEED_DICT then
                ret = zlib.Z_DATA_ERROR -- and fall through
            -- elseif zlib.Z_DATA_ERROR then
            elseif ret == zlib.Z_MEM_ERROR then
                zlib.inflateEnd(strm)
                return ret
            end
            have = CHUNK - strm.avail_out;
            if have > 0 then
                dest[#dest+1] = ffi.string(out, have)
            end
        until strm.avail_out ~= 0
    -- done when inflate() says it's done
    until ret == zlib.Z_STREAM_END

    -- clean up and return
    zlib.inflateEnd(strm)
    return ret == zlib.Z_STREAM_END and zlib.Z_OK or zlib.Z_DATA_ERROR, table.concat(dest)
end

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )

local function write(path, data)
    local file = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
end

local function UnpackTo(path, rd)
    
    local Image = cf.ReadImage(rd)
    local ret, res, dir

    for ID, Body, Packed in Image.Rows() do
        if Packed then
            ret, res = inflate(Body)
            if ret == zlib.Z_OK then
                if res:sub(1, 4) == SIG then
                    dir = path .. ID .. "/"
                    C._mkdir(dir)
                    UnpackTo(dir, cf.NewStringReader(res))
                else
                    write(path .. ID, res)
                end
            else
                print(zerr[ret], ID)
            end
        else
            write(path .. ID, Body)
        end
    end

end


local file = assert(io.open(arg[1] or "c:/1C/1Cv8.cf", "rb"))
local dir = arg[2] or "c:/1C/1Cv8_cf/"
C._mkdir(dir)
UnpackTo(dir, cf.NewFileReader(file))