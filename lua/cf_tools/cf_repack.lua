local ffi = require("ffi")
ffi.cdef[[
int remove(const char* filename);
]]
local C = ffi.C

require 'miniz_h'
local miniz = ffi.load("bin/miniz")

local cf = require 'cf_tools.cf_reader'

local function inflate(source)
    local decomp_len = ffi.new 'size_t[1]'
    local pdata = miniz.tinfl_decompress_mem_to_heap(source, #source, decomp_len, 0)
    return pdata ~= ffi.NULL, ffi.string(pdata, ffi.cast("int", decomp_len[0])) 
end

local function NewZipWriter(fpath)
    
    local zip = ffi.new 'mz_zip_archive'
    zip.m_file_offset_alignment = 0
    if miniz.mz_zip_writer_init_file(zip, fpath, 0) == miniz.MZ_FALSE then
        return nil
    end

    function write(dpath, data, level)
        if miniz.mz_zip_writer_add_mem(zip, dpath, data, #data, level) == miniz.MZ_FALSE then
            mz_zip_writer_end(zip)
            C.remove(fpath)
            return false
        end
        return true
    end

    function finalize()
        if miniz.mz_zip_writer_finalize_archive(zip) == miniz.MZ_FALSE then
            miniz.mz_zip_writer_end(zip)
            C.remove(fpath)
            return false
        end  
        miniz.mz_zip_writer_end(zip)  
        return true
    end

    return {
        write = write,
        finalize = finalize
    }

end

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )

local function UnpackTo(path, rd, zip)
    
    local Image = cf.ReadImage(rd)
    local ret, res

    for ID, Body, Header, Packed in Image.Rows() do
        if Packed then
            ret, res = inflate(Body)
            if ret then
                if res:sub(1, 4) == SIG then
                    UnpackTo(ID .. "/", cf.NewStringReader(res), zip)
                else
                    assert(zip.write(path .. ID, res, 1))
                end
            else
                print("inflate error", ID)
            end
        else
            assert(zip.write(path .. ID, Body, 1))
        end
    end

end


local file = assert(io.open(arg[1] or "c:/1C/1Cv8.cf", "rb"))
local zip  = assert(NewZipWriter(arg[2] or "c:/1C/1Cv8.zip"))
UnpackTo("", cf.NewFileReader(file), zip)
zip.finalize()

