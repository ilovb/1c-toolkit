local iconv = require 'iconv'
local lfs = require 'lfs'
local cf_inside = require 'cf_tools.cf_inside'
require 'iuplua'

local conv2ansi = iconv.NewConverter('CP1251', 'UTF-8')

local window = {}

window.list = iup.list {expand="yes", visiblelines = 3}

window.modules = {}

function window.list:action(t, i, v)
    if v ~= 0 then 
        window.text.value = window.modules[i]
    end
    return iup.default
end

window.text = iup.multiline {
    readonly = "yes",
    expand   = "yes",
    font     = "Courier, 10"
}

window.button_open = iup.button {size = "50x15", title = "open"}

function window:OpenFile(filename)
    local list = cf_inside.ReadModulesFromFile(filename)
    local mod_name
    self.modules = {}
    self.list[1] = nil
    for i, v in ipairs(list) do
        mod_name = conv2ansi(v.mod_type == 'object' and 'МодульОбъекта' or v.mod_name)
        self.list[i] = mod_name    
        self.modules[i] = conv2ansi(v.mod_text:sub(4))
    end
    self.text.value = self.modules[1]
    self.list.value = 1
end

function window.button_open:action()
    local fd = iup.filedlg {
        dialogtype  = "open", 
        title       = "open file", 
        nochangedir = "no",
        directory   = window.last_directory,
        filter      = "*.epf;*.erf", 
        filterinfo  = "*.epf;*.erf", 
        allownew    = "no"
    }
    fd:popup(iup.center, iup.center)
    local status = fd.status
    local filename = fd.value
    window.last_directory = fd.directory
    fd:destroy()

    if (status == "-1") or (status == "1") then
        if (status == "1") then
            error ("Cannot load file "..filename)
        end
    else
        window:OpenFile(filename)
    end
end

window.vbox = iup.vbox {
    window.button_open,
    iup.split {
        -- elements
        window.list,
        window.text;
        -- attributies
        value  = '200',
        minmax = '100:500'
    },   
    gap="2x2", margin="2x2" 
}

window.main = iup.dialog {
    window.vbox,
    title = "cf viewer",
    defaultenter = window.button_open,
    size = "HALFxHALF", shrink="yes"
}

if arg[1] then
    window:OpenFile(arg[1])    
end

window.main:show(iup.CENTER,iup.CENTER)
iup.SetFocus(window.list)

if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end