local ffi = require 'ffi'

require 'iconv_h'
local iconv = ffi.os == 'Linux' and ffi.C or ffi.load('bin/libiconv')

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

return {NewConverter = NewConverter}