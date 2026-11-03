local M = {}

local cache = {}

local function varint(s, pos)
    local result, shift = 0, 0
    local b
    repeat
        b = s:byte(pos)
        pos = pos + 1
        result = result + (b % 128) * 2 ^ shift
        shift = shift + 7
    until b < 128
    return result, pos
end

local function parse_strings(s)
    local pos = 1
    local version = s:byte(pos)
    pos = pos + 1
    if not version or version == 0 or version > 14 then
        error("bad version")
    end
    if version >= 4 then
        pos = pos + 1
    end
    local count
    count, pos = varint(s, pos)
    local strings = {}
    for i = 1, count do
        local len
        len, pos = varint(s, pos)
        if not len or pos + len - 1 > #s then
            error("truncated")
        end
        strings[i] = s:sub(pos, pos + len - 1)
        pos = pos + len
    end
    return strings
end

local function split_words(str)
    local out = { str:lower() }
    local camel = str:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
    for part in camel:gmatch("[%w]+") do
        out[#out + 1] = part:lower()
    end
    return out
end

local function get_words(bytecode)
    local hit = cache[bytecode]
    if hit ~= nil then
        return hit
    end
    local ok, strings = pcall(parse_strings, bytecode)
    if not ok then
        cache[bytecode] = false
        return false
    end
    local words = {}
    for i = 1, #strings do
        local parts = split_words(strings[i])
        for j = 1, #parts do
            words[#words + 1] = parts[j]
        end
    end
    cache[bytecode] = words
    return words
end

local function all_terms_present(words, terms)
    for i = 1, #terms do
        local term = terms[i]
        local found = false
        for j = 1, #words do
            if words[j]:find(term, 1, true) then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end
    return true
end

function M.filter(bytecodes, terms)
    local matches = {}
    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local words = get_words(bc)
            if words and all_terms_present(words, terms) then
                matches[#matches + 1] = i
            end
        end
    end
    return matches
end

function M.words(bytecode)
    return get_words(bytecode)
end

function M.clear()
    cache = {}
end

M.version = "1.0.0"

return M
