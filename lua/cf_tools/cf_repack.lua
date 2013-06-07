local common = require 'common'
local lmz = require 'lmz'
local cf  = require 'cf_tools.cf_reader'

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )

local level = {
    NO_COMPRESSION      =  0, 
    BEST_SPEED          =  1,
    BEST_COMPRESSION    =  9, 
    UBER_COMPRESSION    = 10, 
    DEFAULT_LEVEL       =  6, 
    DEFAULT_COMPRESSION = -1 
}

local function UnpackTo(path, rd, zip)
    
    local Image = cf.ReadImage(rd)
    local res

    for ID, Body, Packed in Image.Rows() do
        if Packed then
            res = lmz.inflate(Body)
            if res then
                if res:sub(1, 4) == SIG then
                    UnpackTo(ID .. '/', cf.NewStringReader(res), zip)
                else
                    assert(zip:write(path .. ID, res, level.BEST_SPEED))
                end
            else
                print('inflate error', ID)
            end
            -- only for luajit
            -- force the garbage collector
            collectgarbage('step')
        else
            assert(zip:write(path .. ID, Body, level.BEST_SPEED))
        end
    end

end

local file = arg[1] and assert(io.open(arg[1], 'rb'))

if file then
    local fdir, fnam, fext = common.parse_path(arg[1])
    local zip = assert(lmz.new_zip_writer(arg[2] or fdir..fnam..'zip'))
    UnpackTo('', cf.NewFileReader(file), zip)
    assert(zip:finalize())
else
    print 'Usage: cf_repack.lua myfile.cf [myfile.zip]'
end

