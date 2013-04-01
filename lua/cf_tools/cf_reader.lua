local SIG  = 0x7FFFFFFF
local BOM  = string.char( 0xEF, 0xBB, 0xBF )
local CRLF = string.char( 0x0D, 0x0A )

local ImageHeaderLen = 4 + 4 + 4 + 4     -- uint32 + uint32 + uint32 + uint32
local PageHeaderLen  = 2 + 9 + 9 + 9 + 2 -- CRLF + hex8byte_ + hex8byte_ + hex8byte_ + CRLF
local RowHeaderLen   = 8 + 8 + 4         -- datetime + datetime + attr

local function NewFileReader(file, buflen)
    buflen = buflen or 256 * 1024
    local offset = 0
    local fpos   = 0
    local flen  = file:seek("end")
    file:seek("set")
    if flen < buflen then buflen = flen end
    local buffer = file:read(buflen)

    local function pos()  return fpos + offset end
    local function size() return flen end

    local function seek(newpos)
        if fpos ~= newpos then
            fpos = file:seek("set", newpos);
            buffer = file:read(math.min(buflen, flen - newpos))
        end
    end

    local function setpos(newpos)
        assert(newpos <= flen)
        offset = newpos % buflen
        seek(newpos - offset)
    end

    local function read(len)
        local t = {}
        local tail = buflen - offset
        if len > tail then
            t[#t+1] = buffer:sub(offset + 1, buflen)
            setpos(fpos + buflen)
            len = len - tail
        end
        while len >= buflen do
            t[#t+1] = buffer
            setpos(fpos + buflen)
            len = len - buflen
        end
        if buffer then
            local newoffset = offset + len
            t[#t+1] = buffer:sub(offset + 1, newoffset)
            offset = newoffset
        end
        return table.concat(t)
    end

    return {
        read = read,
        setpos = setpos,
        pos = pos,
        size = size
    }
end

local function NewStringReader(s)
    local slen = #s
    local spos  = 0

    local function pos()  return spos  end
    local function size() return slen end

    local function setpos(newpos)
        assert(newpos <= slen)
        spos = newpos
    end

    local function read(len)
        local start = spos + 1
        spos = spos + len
        if spos <= slen then
            return s:sub(start, spos)
        else
            return ''
        end
    end

    return {
        read = read,
        setpos = setpos,
        pos = pos,
        size = size
    }
end

local function NewStructReader(s, beg)
    beg = beg or 1
    local pos = s:find('{', beg, true)
    if not pos then return nil end
    local leaf = {}
    local function newleaf(b, e)
        leaf[#leaf+1] = b
        leaf[#leaf+1] = e
        return #leaf
    end
    local qt, lb, rb = ('"{}'):byte(1,3)
    local skip, b = false, 0
    local function parse()     
        beg = pos + 1
        pos = s:find('["{},]', pos + 1)
        local tree = {}
        while pos do
            b = s:byte(pos)
            if b == qt then
                skip = not skip
            elseif not skip then
                if b == lb then
                    tree[#tree+1] = assert(parse())
                    pos = pos + 1
                    beg = pos + 1
                elseif b == rb then
                    if beg < pos then
                        tree[#tree+1] = newleaf(beg, pos - 1)
                    end
                    return tree
                else -- ','
                    tree[#tree+1] = newleaf(beg, pos - 1)
                    beg = pos + 1
                end
            end
            pos = s:find('["{},]', pos + 1)
        end
        return nil
    end
    local tree = parse()
    local node = tree
    local function get(n, t)
        local i, c = 0, #t
        while n and (i < c) do
            i = i + 1
            n = n[t[i]]
        end
        return n, i
    end
    local function goto(key, ...)
        local n, p
        if key == 0 then -- go to root
            n, p = get(tree, {...})
        else
            n, p = get(node[key], {...})
        end
        if n then
            node = n
        else
            return false, p + 1
        end 
        return true, 0
    end
    local function read(...)
        local n, p = get(node, {...})
        if type(n) == 'number' then 
            return s:sub(leaf[n - 1], leaf[n]), 0
        end
        return nil, p
    end
    return {
        goto = goto,
        read = read
    }
end

local function GetUInt32(b0, b1, b2, b3)
    return b3 * 256^3 + b2 * 256^2 + b1 * 256 + b0
end

local function ReadImageHeader(rd)
    local s = rd.read(ImageHeaderLen)
    assert(GetUInt32(s:byte(1, 4)) == SIG)
    return {
        PageSize  = GetUInt32(s:byte(5,  8)),
        Revision  = GetUInt32(s:byte(9, 12)),
        --Unknown   = GetUInt32(s:byte(13, 16))
    }
end

local function ReadPageHeader(rd)
    local s = rd.read(PageHeaderLen)
    assert(s:sub( 1,  2) == CRLF)
    assert(s:sub(30, 31) == CRLF)
    return {
        FullSize = tonumber("0x"..s:sub( 3, 10)),
        PageSize = tonumber("0x"..s:sub(12, 19)),
        NextPage = tonumber("0x"..s:sub(21, 28))
    }
end

local function ReadRowHeader(rd)
    local PageHeader = ReadPageHeader(rd)
    assert(PageHeader.NextPage == SIG)
    local s = rd.read(RowHeaderLen)
    return {
        --Creation   = s:sub(1,  8),
        --Modified   = s:sub(9, 16),
        --Attributes = GetUInt32(s:byte(17, 20)),
        ID = rd.read(PageHeader.FullSize - 24) -- 24 = Creation + Modified + Attributes + 4 unknown bytes
    }
end

local function ReadRowBody(rd)
    local PageHeader = ReadPageHeader(rd)
    local FullSize = PageHeader.FullSize
    local Size = math.min(FullSize, PageHeader.PageSize)
    local t = {rd.read(Size)}
    FullSize = FullSize - Size
    while PageHeader.NextPage ~= SIG do
        rd.setpos(PageHeader.NextPage)
        PageHeader = ReadPageHeader(rd)
        Size = math.min(FullSize, PageHeader.PageSize)
        t[#t+1] = rd.read(Size)
        FullSize = FullSize - Size
    end
    assert(FullSize == 0)
    return table.concat(t)
end

local function ReadPages(rd, Pointers)
    local Pages = {}
    local function NewPage(Header, BodyPos)
        Pages[#Pages + 1] = {
            Header = Header,
            BodyPos = BodyPos
        }
    end
    local function ReadPointers(size)
        local s = rd.read(size)
        for i = 1, size, 4 do
            Pointers[#Pointers + 1] = GetUInt32(s:byte(i,  i + 3))
        end
    end
    local Header   = ReadPageHeader(rd);
    local FullSize = Header.FullSize; assert(FullSize ~= 0)
    local ReadSize = 0
    while Header.NextPage ~= SIG do
        ReadSize = ReadSize + Header.PageSize
        ReadPointers(Header.PageSize)
        NewPage(Header, rd.pos())
        rd.setpos(Header.NextPage)
        Header = ReadPageHeader(rd);
    end
    ReadPointers(FullSize - ReadSize)
    NewPage(Header, rd.pos())
    return Pages
end

local function ReadImage(rd)
    local Pointers = {}
    return {
        Header = ReadImageHeader(rd),
        Pages = ReadPages(rd, Pointers),
        Pointers = Pointers,
        Rows = function ()
            local RowHeader, RowBody
            local index, count = 1, #Pointers
            return function()
                local ID, Body, Header
                if index > count then
                    return nil
                else
                    assert(Pointers[index + 2] == SIG)
                    rd.setpos(Pointers[index])
                    Header = ReadRowHeader(rd)
                    ID = string.gsub(Header.ID, "%z", "")
                    rd.setpos(Pointers[index + 1])
                    Body = ReadRowBody(rd)
                    index = index + 3
                    return ID, Body, Header, Body:sub(1, 3) ~= BOM
                end
            end
        end
    }
end

return {
    NewFileReader = NewFileReader,
    NewStringReader = NewStringReader,
    NewStructReader = NewStructReader,
    ReadImage = ReadImage
}
