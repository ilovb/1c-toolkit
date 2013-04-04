local ffi = require("ffi")

require 'tinfl_h'
local tinfl = ffi.load("bin/tinfl")

require 'iconv_h'
local iconv = ffi.os == 'Linux' and ffi.C or ffi.load('bin/libiconv')

local lfs = require "lfs"
local cf = require 'cf_tools.cf_reader'

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

local function inflate(source)
    local decomp_len = ffi.new 'size_t[1]'
    local pdata = tinfl.tinfl_decompress_mem_to_heap(source, #source, decomp_len, 0)
    return pdata ~= ffi.NULL, ffi.string(pdata, ffi.cast("int", decomp_len[0])) 
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

local check = {
    ["epf"] = true,
    ["erf"] = true
}

local conv2ansi = NewConverter('CP1251', 'UTF-8')

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )
local BOM = string.char( 0xEF, 0xBB, 0xBF )
local tform = {
    ['d5b0e5ed-256d-401c-9c36-f630cafd8a62'] = true,
    ['a3b368c0-29e2-11d6-a3c7-0050bae0a776'] = true
}

local dir = {}

for path in io.lines(arg[1] or "c:/temp/test.txt") do
   
    local fdir, fnam, fext = parse_path(path)
    if check[fext:lower()] and lfs.attributes(path, "mode") then
        
        local Image = cf.ReadImage(cf.NewFileReader(assert(io.open(path, "rb"))))
        local ret, res
        for ID, Body, Packed in Image.Rows() do           
            if Packed then
                ret, res = inflate(Body)
                assert(ret, 'inflate error')
                if res:sub(1, 4) == SIG then
                    Image = cf.ReadImage(cf.NewStringReader(res))
                    local subdir = {}
                    for ID, Body in Image.Rows() do
                        subdir[ID] = Body
                    end
                    dir[ID] = subdir
                else
                    dir[ID] = res
                end
            else
                dir[ID] = Body
            end
        end

        local root_head, root_uuid, root_body

        root_head = assert(cf.NewStructReader(dir['root']))
        root_uuid = assert(root_head.read(2))
        root_body = assert(cf.NewStructReader(dir[root_uuid]))

        ---------------------------------------------------------------------------------------
        ----   модуль объекта
        ---------------------------------------------------------------------------------------

        local object_uuid, object_body, object_module

        object_uuid = root_body.read(4, 2, 2, 4, 2, 2, 3)
        object_body = dir[object_uuid..'.0']
        if type(object_body) == 'table' then
            object_module = object_body['text']
            if object_module then
                write(fdir..fnam..'_'..conv2ansi('Модуль.txt'), object_module)
            end
        end

        ---------------------------------------------------------------------------------------
        ----   модули форм
        ---------------------------------------------------------------------------------------

        local form_uuid, form_head, form_name, form_body, form_type, form_struct, form_module

        -- состав корневого элемента
        root_body.goto(4, 2)
        for i = 4, assert(root_body.read(3)) + 3 do
            -- ищем список форм
            if tform[assert(root_body.read(i, 1))] then
                root_body.goto(i)
                for j = 3, assert(root_body.read(2)) + 2 do
                    form_uuid = assert(root_body.read(j))
                    form_head = assert(cf.NewStructReader(dir[form_uuid]))
                    -- если формат формы 8.2
                    if form_head.read(2, 1) == '1' then
                        form_name = conv2ansi(assert(form_head.read(2, 2, 2, 2, 3)):sub(2, -2))
                    else
                        form_name = conv2ansi(assert(form_head.read(2, 2, 2, 3)):sub(2, -2))
                    end
                    form_body = assert(dir[form_uuid..'.0'])
                    form_type = form_head.read(2, 2, 2, 4)
                    -- если форма управляемая
                    if form_type == '1' then
                        assert(type(form_body) == 'string')
                        -- извлекаем модуль из структуры формы
                        form_struct = assert(cf.NewStructReader(form_body))
                        form_module = BOM..assert(form_struct.read(3)):sub(2, -2):gsub('""', '"')
                    else
                        assert(type(form_body) == 'table')
                        form_module = assert(form_body['module'])
                    end
                    write(fdir..fnam..'_'..form_name..'.txt', form_module)
                end
                break
            end
        end

    end -- check

end -- path