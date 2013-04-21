local iconv = require 'iconv'
local lfs = require 'lfs'
local cf_inside = require 'cf_tools.cf_inside'
require 'iuplua'

local utf8_to_cp1251 = iconv.new('CP1251', 'UTF-8')

local function write(path, data)
    local file = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
end

local window = {}

window.list = iup.list {expand="yes", visiblelines = 3}

window.modules = {}

function window.list:action(t, i, v)
    if v ~= 0 then 
        window.text.value = window.modules[i]
        window.caretpos = 1
    end
    return iup.default
end

window.text = iup.multiline {
    readonly = "yes",
    expand   = "yes",
    font     = "Courier, 10",
    tabsize  = 4,
    padding  = '10x0', -- formatting = 'yes'
}

    window.caretpos = 1

function window.text:caret_cb(lin, col, pos)
    window.caretpos = pos
end

window.button_open = iup.button {
    size = "60x13",
    title = utf8_to_cp1251:iconv "Открыть"
}

window.button_store = iup.button {
    size = "70x13",
    title = utf8_to_cp1251:iconv "Сохранить как" 
}

window.button_find = iup.button {
    size = "40x13",
    title = utf8_to_cp1251:iconv "Найти" 
}

window.findbox = iup.text {
    size = 'x13', 
    expand = 'horizontal', 
    font = "Courier, 10"
}

window.regexp = iup.toggle{title = 'RegExp'}

function window:OpenFile(filename)
    local list = cf_inside.ReadModulesFromFile(filename)
    local mod_name
    self.modules = {}
    self.list[1] = nil
    for i, v in ipairs(list) do
        mod_name = utf8_to_cp1251:iconv(v.mod_type == 'object' and 'МодульОбъекта' or v.mod_name)
        self.list[i] = mod_name    
        self.modules[i] = utf8_to_cp1251:iconv(v.mod_text:sub(4))
    end
    self.text.value = self.modules[1]
    self.list.value = 1
    self.main.title = filename
end

function window:GotoLine()
    local ret, line = iup.GetParam(
        utf8_to_cp1251:iconv "Перейти", nil,
        utf8_to_cp1251:iconv "Номер строки: %s/d+\n", ''
    )
    if line then
        self.text.scrollto = line..':1'
        self.text.selection = line..',1:'..line..',1000'
        iup.SetFocus(window.text) 
    end
end

function window.button_open:action()
    local fd = iup.filedlg {
        dialogtype  = "open", 
        title       = utf8_to_cp1251:iconv "Открыть", 
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

function window.button_store:action()
    local fd = iup.filedlg {
        dialogtype  = "save", 
        title       = utf8_to_cp1251:iconv "Сохранить как", 
        nochangedir = "no",
        directory   = window.last_directory,
        extfilter   = "*.txt|*.txt",
        allownew    = "no",
        file        = window.list[window.list.value]..'.txt'
    }
    fd:popup(iup.center, iup.center)
    local status = fd.status
    local filename = fd.value
    window.last_directory = fd.directory
    fd:destroy()

    if (status == "0") or (status == "1") then
        write(filename, window.text.value:gsub('\n', '\r\n'))
    end
end

function window.button_find:action()
    if window.findbox.value == '' then return end
    
    local text      = window.text
    local selection = text.selection
    local findbox   = window.findbox
    local regexp    = window.regexp

    local start = window.caretpos
    if selection and (regexp.value == 'ON') then
        if findbox.value:find('%b', 1, true) then
            start = start - #text.selectedtext + 2
        else
            start = start + 1
        end
    end
    local b, e = text.value:find(findbox.value, start, regexp.value == 'OFF')
    if b then
        window.caretpos = e
        text.caretpos   = e
        text.selectionpos = (b - 1)..':'..e
        text.scrollto = text.selection:sub(1, text.selection:find(',', 1, true))
        iup.SetFocus(text)
    else
        dlg = iup.messagedlg {
            dialogtype = 'question',
            buttons = 'yesno',
            title = utf8_to_cp1251:iconv "Вхождения не найдены",
            value = utf8_to_cp1251:iconv "Искать сначала?"
        }
        dlg:popup()
        local buttonresponse = dlg.buttonresponse
        dlg:destroy() 
        if buttonresponse == '1' then
            window.caretpos = 1
            text.caretpos   = 1
            self:action()
        end
    end
end

window.vbox = iup.vbox {
    iup.split {
        iup.hbox {
            window.button_open,
            window.button_store
        },
        iup.hbox {
            window.regexp,
            window.findbox,
            window.button_find,
            alignment  = 'acenter', 
        }
    },
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
    size = "HALFxHALF", shrink="yes",
    -- placement = 'maximized',
}

function window.main:k_any(c)
    if c == iup.K_ESC then
        self:hide()
    elseif c == iup.K_cCR then
        self.placement = 'maximized'
        iup.Show(self)
    elseif c == iup.K_cO then
        window.button_open:action()
    elseif c == iup.K_cS then
        window.button_store:action()
    elseif c == iup.K_cF then
        window.regexp.value = 'off'
        iup.SetFocus(window.findbox)
    elseif c == iup.K_cR then
        window.regexp.value = 'on'
        iup.SetFocus(window.findbox)
    elseif c == iup.K_F2 then
        iup.SetFocus(window.list)
    end
    return iup.default
end

function window.findbox:k_any(c)
    if (c == iup.K_CR) then
        window.button_find:action()
    end
    window.main:k_any(c)
    return iup.default
end

function window.text:k_any(c)
    if c == iup.K_cG then
        window:GotoLine()
    elseif c == iup.K_F3 then
        window.button_find:action()
    end
    window.main:k_any(c)
    return iup.default
end

if arg[1] then
    window:OpenFile(arg[1])    
end

window.main:show(iup.CENTER,iup.CENTER)
iup.SetFocus(window.list)

if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end