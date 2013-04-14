local ffi = require("ffi")

local iconv = require 'iconv'

local lfs = require "lfs"
local cf_inside = require 'cf_tools.cf_inside'

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

local conv2ansi = iconv.NewConverter('CP1251', 'UTF-8')

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