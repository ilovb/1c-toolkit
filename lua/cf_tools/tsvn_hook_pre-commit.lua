local common = require 'common'
local iconv = require 'iconv'
local lfs = require 'lfs'
local cf_inside = require 'cf_tools.cf_inside'

local function write(path, data)
    local mode = lfs.attributes(path, 'mode')
    local file  = assert(io.open(path, 'wb'))
    file:write(data)
    file:close()
    if not mode then
        os.execute('svn.exe add "'..path..'"')
    end
end

local check = common.new_set {'epf', 'erf'}

local utf8_to_cp1251 = iconv.new('CP1251', 'UTF-8')

if arg[1] then
    for path in io.lines(arg[1]) do

        local fdir, fnam, fext = common.parse_path(path)
        if check[fext:lower()] and lfs.attributes(path, 'mode') then
            
            local list = cf_inside.ReadModulesFromFile(path)
            local mod_name
            for _, item in ipairs(list) do
                mod_name = utf8_to_cp1251:iconv(item.mod_type == 'object' and 'Модуль' or item.mod_name)
                write(fdir..fnam..'_'..mod_name..'.txt', item.mod_text)
            end

        end

    end
end