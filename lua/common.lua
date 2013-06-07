local function parse_path(path)
    -- dir, filename, ext
    return string.match(path, "(.-)([^\\/]-)%.?([^%.\\/]*)$")
end

function new_set(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end

return {
	new_set    = new_set,
	parse_path = parse_path,
}

