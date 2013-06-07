local common = require 'common'
local lfs = require "lfs"
local lmz = require 'lmz'
local cf = require 'cf_tools.cf_reader'

local SIG = string.char( 0xFF, 0xFF, 0xFF, 0x7F )

local function write(path, data)
    local file = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
end

local function UnpackTo(path, rd)

    local Image = cf.ReadImage(rd)
    local res, dir

    for ID, Body, Packed in Image.Rows() do
        if Packed then
            res = lmz.inflate(Body)
            assert(res, 'inflate error')
            if res:sub(1, 4) == SIG then
                dir = path .. ID .. "/"
                lfs.mkdir(dir)
                UnpackTo(dir, cf.NewStringReader(res))
            else
                write(path .. ID, res)
            end
        else
            write(path .. ID, Body)
        end
    end

end

local file = arg[1] and assert(io.open(arg[1], "rb"))
local dir = arg[2]

if file then
    if dir then
        dir = dir:sub(-1) == '/' and dir or dir..'/'
        lfs.mkdir(dir)
    else
        dir = common.parse_path(arg[1])
    end
    UnpackTo(dir, cf.NewFileReader(file))
else
    print 'Usage: cf_unpack.lua myfile.cf [mydir]'
end