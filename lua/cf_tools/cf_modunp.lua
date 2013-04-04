local ffi = require("ffi")

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
    local file  = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
end

local src, dst = arg[1], arg[2]

if src and dst then

    local dir = dst:sub(-1) == '/' and dst or dst..'/'
    lfs.mkdir(dir)

    local conv2ansi = NewConverter('CP1251', 'UTF-8')

    local list = cf_inside.ReadModulesFromFile(src)
    local fname
    for _, item in ipairs(list) do
        fname = conv2ansi(item.mod_type == 'object' and 'МодульОбъекта' or item.mod_name)
        write(dir..fname, item.mod_text)
    end

end