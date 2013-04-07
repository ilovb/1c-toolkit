local ffi = require("ffi")

require 'tinfl_h'
local tinfl = ffi.load("bin/tinfl")

require 'iconv_h'
local iconv = ffi.os == 'Linux' and ffi.C or ffi.load('bin/libiconv')

local lfs = require "lfs"
local cf_inside = require 'cf_tools.cf_inside'

local function NewConverter(dst, src)
    local ic = iconv.libiconv_open(dst, src)
    return function (s)
        local slen = #s

        local in_size    = ffi.new('size_t[1]', slen)
        local in_buf     = ffi.new('char  [?]', slen + 1, s)
        local in_bufptr  = ffi.new('char *[1]', in_buf)

        local out_size   = ffi.new('size_t[1]', slen * 2)
        local out_buf    = ffi.new('char  [?]', slen * 2)
        local out_bufptr = ffi.new('char *[1]', out_buf)

        iconv.libiconv(ic, in_bufptr, in_size, out_bufptr, out_size)
        local outlen = slen * 2 - out_size[0]
        return ffi.string(out_buf, outlen), outlen
    end
end

local function write(path, data)
    local mode = lfs.attributes(path, "mode")
    local file  = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
    if not mode then
        os.execute('svn.exe add "'..path..'"')
    end
end

local function parse_path(path)
    -- dir, filename, ext
    return string.match(path, "(.-)([^\\/]-)%.?([^%.\\/]*)$")
end

function NewSet(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end

local check = NewSet {"epf", "erf"}

local conv2ansi = NewConverter('CP1251', 'UTF-8')

for path in io.lines(arg[1] or "c:/temp/test.txt") do

    local fdir, fnam, fext = parse_path(path)
    if check[fext:lower()] and lfs.attributes(path, "mode") then
        
        local list = cf_inside.ReadModulesFromFile(path)
        local mod_name
        for _, item in ipairs(list) do
            mod_name = conv2ansi(item.mod_type == 'object' and 'Модуль' or item.mod_name)
            write(fdir..fnam..'_'..mod_name..'.txt', item.mod_text)
        end

    end

end