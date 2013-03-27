local BOM = string.char( 0xef, 0xbb, 0xbf )

local function print_tree(tree, indent)
    indent = indent or 0
    for _, branch in ipairs(tree.children) do
        print(string.rep('\t', indent) .. branch.value)
        if branch.children then
            print_tree(branch, indent + 1)
        end
    end
end

local function comp(a, b)
    return a.value < b.value
end

local function read(file)
    local line = file:read()
    if not line then
        error('empty file')
        return nil
    end
    local _, indent = line:find('^\t+')
    indent = indent or 0
    local last = indent
    local first = indent
    local tree = {children = {}}
    local branch
    local symbol = ''
    while line do
        _, indent = line:find('^\t+')
        indent = indent or 0
        if indent < first then
            error('wrong indentation')
            return nil
        end
        if indent > last then
            tree = branch
            tree.children = {}
            last = last + 1
        else
            while indent < last do
                table.sort(tree.children, comp)
                tree = tree.parent
                last = last - 1
            end
        end
        symbol = line:sub(indent + 1, indent + 1)
        if (symbol == ' ' or symbol == '"') then
            branch = {parent = tree, value = line:sub(indent + 2, -2)}
        else
            branch = {parent = tree, value = line:sub(indent + 1)}
        end
        table.insert(tree.children, branch)
        line = file:read()
    end
    while tree.parent do
        table.sort(tree.children, comp)
        tree = tree.parent
    end
    table.sort(tree.children, comp)
    return tree
end

local function diff(t1, t2, indent, index, res)

    local c1, c2 = t1.children, t2.children
    local i, j = 1, 1
    local n1, n2 = c1 and c1[i], c2 and c2[j] -- nodes
    local temp = 0

    while n1 or n2 do
        index = index + 1
        if not n1 or (n2 and (n1.value > n2.value)) then
            j = j + 1
            res[index] = '-->' .. string.rep('\t', indent) .. n2.value
        elseif not n2 or (n1 and (n1.value < n2.value)) then
            i = i + 1
            res[index] = '<--' .. string.rep('\t', indent) .. n1.value
        else
            i = i + 1
            j = j + 1
            temp = diff(n1, n2, indent + 1, index, res)
            if temp > index then
                res[index] = '   ' .. string.rep('\t', indent) .. n1.value
                index = temp
            else
                res[index] = nil
                index = index - 1
            end
        end
        n1, n2 = c1 and c1[i], c2 and c2[j]
    end

    return index

end

local function print_diff(t1, t2)
    local res = {}
    if diff(t1, t2, 1, 0, res) > 0 then
        for _, v in pairs(res) do
            print(v)
        end
    end
end

local file1 = arg[1] and io.open(arg[1])
local file2 = arg[2] and io.open(arg[2])
if file1 then
    if file2 then
        if file1:read(3) == BOM then
            assert(file2:read(3) == BOM, arg[2] .. ' not UTF-8 with BOM')
            os.execute("chcp 65001 > nul")
            io.write(BOM)
        else
            file1:seek('set')
            assert(not (file2:read(3) == BOM), arg[2] .. ' not ANSI')
            file2:seek('set')
            os.execute("chcp 1251 > nul")
        end
        local tree1 = read(file1)
        local tree2 = read(file2)
        if tree1 and tree2 then
            print_diff(tree1, tree2)
        else
            print('epic fail...')
        end
    else
        if file1:read(3) == BOM then
            os.execute("chcp 65001 > nul")
            io.write(BOM)
        else
            os.execute("chcp 1251 > nul")
            file1:seek('set')
        end
        local tree = read(file1)
        if tree then
            print_tree(tree)
        end
    end
else
    print [[

    Usage: diff_conf.lua first_file [second_file] [> result_file]

    Examples:
        c:\>diff_conf.lua conf.txt
        c:\>diff_conf.lua conf.txt > conf_sorted.txt
        c:\>diff_conf.lua conf1.txt conf2.txt
        c:\>diff_conf.lua conf1.txt conf2.txt > conf1_vs_conf2.txt
    ]]
end
