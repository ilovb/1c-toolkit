local ffi = require 'ffi'

ffi.cdef [[
extern  int _libiconv_version; /* Likewise */
typedef void* iconv_t;
iconv_t libiconv_open (const char* /*tocode*/, const char* /*fromcode*/);
size_t libiconv (iconv_t /*cd*/,
    char ** __restrict /*inbuf*/,  size_t * __restrict /*inbytesleft*/,
    char ** __restrict /*outbuf*/, size_t * __restrict /*outbytesleft*/);
int libiconv_close (iconv_t /*cd*/);
]]