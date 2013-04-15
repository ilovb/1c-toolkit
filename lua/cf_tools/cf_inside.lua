local ffi = require("ffi")
ffi.cdef [[
void free(void *ptr);
]]

require 'tinfl_h'
local tinfl = ffi.load("bin/tinfl")

local cf = require 'cf_tools.cf_reader'

local function inflate(source)
    local decomp_len = ffi.new 'size_t[1]'
    local pdata = ffi.gc(tinfl.tinfl_decompress_mem_to_heap(source, #source, decomp_len, 0), ffi.C.free)
    return pdata ~= ffi.NULL, ffi.string(pdata, ffi.cast("int", decomp_len[0])) 
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

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )
local BOM = string.char( 0xEF, 0xBB, 0xBF )
local tform = NewSet {
    'd5b0e5ed-256d-401c-9c36-f630cafd8a62', -- форма обработки
    'a3b368c0-29e2-11d6-a3c7-0050bae0a776'  -- форма отчета
}

local dir = {}

local function ReadModulesFromFile(path)
    
    local check = NewSet {"epf", "erf"}

    local fdir, fnam, fext = parse_path(path)
    assert(check[fext:lower()])
     
    local modules = {}
    local function add_module(mod_type, mod_name, mod_text)
        modules[#modules+1] = {
            mod_type = mod_type,
            mod_name = mod_name,
            mod_text = mod_text
        }
    end

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

    local object_name, object_uuid, object_body, object_module

    object_name = assert(root_body.read(4, 2, 2, 4, 2, 3)):sub(2, -2)
    object_uuid = assert(root_body.read(4, 2, 2, 4, 2, 2, 3))
    object_body = dir[object_uuid..'.0']
    if type(object_body) == 'table' then
        object_module = object_body['text']
        if object_module then
            add_module('object', object_name, object_module)
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
                    form_name = assert(form_head.read(2, 2, 2, 2, 3)):sub(2, -2)
                else
                    form_name = assert(form_head.read(2, 2, 2, 3)):sub(2, -2)
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
                add_module('form', form_name, form_module)
            end
            break
        end
    end

    return modules

end

return {
    ReadModulesFromFile = ReadModulesFromFile
}