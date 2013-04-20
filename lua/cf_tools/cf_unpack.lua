local ffi = require("ffi")
local lfs = require "lfs"
ffi.cdef [[
void free(void *ptr);
]]

require 'miniz_h'
local miniz = ffi.load("miniz")

local cf = require 'cf_tools.cf_reader'

local function inflate(source)
    local decomp_len = ffi.new 'size_t[1]'
    local pdata = ffi.gc(miniz.tinfl_decompress_mem_to_heap(source, #source, decomp_len, 0), ffi.C.free)
    return pdata ~= ffi.NULL, ffi.string(pdata, ffi.cast("int", decomp_len[0])) 
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
            assert(ret, 'inflate error')
            if res:sub(1, 4) == SIG then
                dir = path .. ID .. "/"
                lfs.mkdir(dir)
                UnpackTo(dir, cf.NewStringReader(res))
            else
                write(path .. ID, res)
            end
        else
            write(path .. ID, Body)
        end
    end

end

local file = assert(io.open(arg[1] or "c:/1C/1Cv8.cf", "rb"))
local dir = arg[2] or "c:/1C/1Cv8_cf/"
dir = dir:sub(-1) == '/' and dir or dir..'/'
lfs.mkdir(dir)
UnpackTo(dir, cf.NewFileReader(file))