local M = {}
local cache = {}

local OPCODE_COUNT = 95
local TEXT_FIELDS = {"const_words", "debug_words", "import_words", "table_words", "class_words"}

local function varint(s, pos)
    local result = 0
    local shift = 0
    local b
    repeat
        b = s:byte(pos)
        if not b then error("eof") end
        pos = pos + 1
        result = result + (b % 128) * 2 ^ shift
        shift = shift + 7
    until b < 128
    return result, pos
end

local function skip_varint(s, pos)
    local dummy
    local newpos
    dummy, newpos = varint(s, pos)
    return newpos
end

local function u32(s, pos)
    local b1, b2, b3, b4 = s:byte(pos, pos + 3)
    if not b1 then error("eof u32") end
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function shr(x, n)
    return math.floor(x / (2 ^ n))
end

local function lowbits(x, n)
    return x % (2 ^ n)
end

local function f32(s, pos)
    local bits = u32(s, pos)
    local sign = shr(bits, 31)
    local exp = lowbits(shr(bits, 23), 8)
    local mant = lowbits(bits, 23)
    if exp == 255 then
        if mant == 0 then
            if sign == 1 then return -math.huge end
            return math.huge
        end
        return 0 / 0
    end
    if exp == 0 then
        exp = -126
    else
        mant = mant + 8388608
        exp = exp - 127
    end
    local v = mant * 2 ^ (exp - 23)
    if sign == 1 then return -v end
    return v
end

local function f64(s, pos)
    local lo = u32(s, pos)
    local hi = u32(s, pos + 4)
    local sign = shr(hi, 31)
    local exp = lowbits(shr(hi, 20), 11)
    local mant = lowbits(hi, 20) * 4294967296 + lo
    if exp == 2047 then
        if mant == 0 then
            if sign == 1 then return -math.huge end
            return math.huge
        end
        return 0 / 0
    end
    if exp == 0 then
        exp = -1022
    else
        mant = mant + 2 ^ 52
        exp = exp - 1023
    end
    local v = mant * 2 ^ (exp - 52)
    if sign == 1 then return -v end
    return v
end

local function push_split(words, str)
    words[#words + 1] = str:lower()
    local expanded = str:gsub("(%l)(%u)", "%1 %2")
    expanded = expanded:gsub("(%u)(%u%l)", "%1 %2")
    expanded = expanded:gsub("_", " ")
    for part in expanded:gmatch("[%w]+") do
        words[#words + 1] = part:lower()
    end
end

local function push_num(nums, v)
    nums[#nums + 1] = v
end

local OP_LEN_2 = {
    [7]=true, [8]=true, [12]=true, [15]=true, [16]=true, [20]=true,
    [27]=true, [28]=true, [29]=true, [30]=true, [31]=true, [32]=true,
    [53]=true, [55]=true, [58]=true, [66]=true, [74]=true, [75]=true,
    [77]=true, [78]=true, [79]=true, [80]=true, [87]=true, [88]=true,
    [91]=true, [93]=true, [94]=true,
}

local OPCODE_KEYWORDS = {
    [1]={"break"}, [2]={"nil"},
    [7]={"global","get"}, [8]={"global","set"},
    [9]={"upvalue","get"}, [10]={"upvalue","set"},
    [11]={"upvalue","close"}, [12]={"import"},
    [13]={"table","get"}, [14]={"table","set"},
    [15]={"table","get","string"}, [16]={"table","set","string"},
    [17]={"table","get","number"}, [18]={"table","set","number"},
    [19]={"function","closure"}, [20]={"call","method"},
    [21]={"call"}, [22]={"return"},
    [23]={"jump","else"}, [24]={"jump","loop"},
    [25]={"if"}, [26]={"if","not"},
    [27]={"if","=="}, [28]={"if","<="},
    [29]={"if","<"}, [30]={"if","~="},
    [31]={"if",">"}, [32]={"if",">="},
    [33]={"+","add"}, [34]={"-","sub"},
    [35]={"*","mul"}, [36]={"/","div"},
    [37]={"%","mod"}, [38]={"^","pow"},
    [39]={"+","add","constant"}, [40]={"-","sub","constant"},
    [41]={"*","mul","constant"}, [42]={"/","div","constant"},
    [43]={"%","mod","constant"}, [44]={"^","pow","constant"},
    [45]={"and"}, [46]={"or"},
    [47]={"and","constant"}, [48]={"or","constant"},
    [49]={"..","concat"}, [50]={"not"},
    [51]={"-","neg"}, [52]={"#","length"},
    [53]={"table","new"}, [54]={"table","dup"},
    [55]={"table","setlist"}, [56]={"for","numeric","prep"},
    [57]={"for","numeric"}, [58]={"for","generic"},
    [59]={"for","ipairs","prep"}, [60]={"call","fastcall3"},
    [61]={"for","pairs","prep"}, [62]={"native","call"},
    [63]={"...","vararg","get"}, [64]={"function","dup"},
    [65]={"...","vararg","prep"},
    [67]={"jump","long"}, [68]={"call","fastcall"},
    [69]={"coverage"}, [70]={"upvalue","capture"},
    [71]={"-","sub","constant"}, [72]={"/","div","constant"},
    [73]={"call","fastcall1"}, [74]={"call","fastcall2"},
    [75]={"call","fastcall2k"}, [76]={"for","generic","prep"},
    [77]={"if","nil","=="}, [78]={"if","boolean","=="},
    [79]={"if","number","=="}, [80]={"if","string","=="},
    [81]={"//","idiv"}, [82]={"//","idiv","constant"},
    [83]={"userdata","get"}, [84]={"userdata","set"},
    [85]={"userdata","call"}, [86]={"class","member"},
    [87]={"call","feedback"}, [88]={"compare","proto"},
    [89]={"call","pcall"}, [90]={"class","new"},
    [91]={"construct","class"}, [92]={"construct","finish"},
    [93]={"private","get"}, [94]={"private","set"},
}

local OPCODE_BY_OPERAND = {
    [3] = {[0]="false", [1]="true"},
}

local FASTCALL_OPS = {[60]=true, [68]=true, [73]=true, [74]=true, [75]=true}
local FASTCALL_K_OPS = {[74]=true, [75]=true}

local LBF_NAMES = {
    [0]="none", [1]="assert", [2]="math.abs", [3]="math.acos", [4]="math.asin",
    [5]="math.atan2", [6]="math.atan", [7]="math.ceil", [8]="math.cosh",
    [9]="math.cos", [10]="math.deg", [11]="math.exp", [12]="math.floor",
    [13]="math.fmod", [14]="math.frexp", [15]="math.ldexp", [16]="math.log10",
    [17]="math.log", [18]="math.max", [19]="math.min", [20]="math.modf",
    [21]="math.pow", [22]="math.rad", [23]="math.sinh", [24]="math.sin",
    [25]="math.sqrt", [26]="math.tanh", [27]="math.tan",
    [28]="bit32.arshift", [29]="bit32.band", [30]="bit32.bnot",
    [31]="bit32.bor", [32]="bit32.bxor", [33]="bit32.btest",
    [34]="bit32.extract", [35]="bit32.lrotate", [36]="bit32.lshift",
    [37]="bit32.replace", [38]="bit32.rrotate", [39]="bit32.rshift",
    [40]="type", [41]="string.byte", [42]="string.char", [43]="string.len",
    [44]="typeof", [45]="string.sub", [46]="math.clamp", [47]="math.sign",
    [48]="rawset", [49]="rawget", [50]="rawequal", [51]="table.insert",
    [52]="table.unpack", [53]="vector", [54]="bit32.countlz",
    [55]="bit32.countrz", [56]="select.vararg", [57]="rawlen",
    [58]="bit32.extractk", [59]="getmetatable", [60]="setmetatable",
    [61]="tonumber", [62]="tostring", [63]="bit32.byteswap",
    [64]="buffer.readi8", [65]="buffer.readu8", [66]="buffer.readi16",
    [67]="buffer.readu16", [68]="buffer.readi32", [69]="buffer.readu32",
    [70]="buffer.readf32", [71]="buffer.readf64", [72]="buffer.writeu8",
    [73]="buffer.writeu16", [74]="buffer.writeu32", [75]="buffer.writef32",
    [76]="buffer.writef64", [77]="math.round", [78]="buffer.readinteger",
    [79]="buffer.writeinteger", [80]="math.lerp", [81]="math.isnan",
    [82]="math.isinf", [83]="math.isfinite", [84]="vector.magnitude",
    [85]="vector.normalize", [86]="vector.cross", [87]="vector.dot",
    [88]="vector.floor", [89]="vector.ceil", [90]="vector.abs",
    [91]="vector.sign", [92]="vector.clamp", [93]="vector.min",
    [94]="vector.max", [95]="vector.lerp",
}

local function opcodes_valid(insns, encoded)
    for i = 1, #insns do
        local op = insns[i] % 256
        if encoded then
            op = (op * 203) % 256
        end
        if op >= OPCODE_COUNT then
            return false
        end
    end
    return true
end

local function detect_encoding(insns)
    if #insns == 0 then
        return nil
    end
    if opcodes_valid(insns, false) then
        return false
    end
    if opcodes_valid(insns, true) then
        return true
    end
    return nil
end

local function extract_insn_tokens(insns, encoded)
    local words = {}
    local i = 1
    while i <= #insns do
        local insn = insns[i]
        local op = insn % 256
        if encoded then
            op = (op * 203) % 256
        end

        local kws = OPCODE_KEYWORDS[op]
        if kws then
            for k = 1, #kws do
                words[#words + 1] = kws[k]
            end
        end

        local by_op = OPCODE_BY_OPERAND[op]
        if by_op then
            local bfield = lowbits(shr(insn, 16), 8)
            local kw = by_op[bfield]
            if kw then
                words[#words + 1] = kw
            end
        end

        local afield = lowbits(shr(insn, 8), 8)
        if FASTCALL_OPS[op] then
            local bfid
            if FASTCALL_K_OPS[op] and i + 1 <= #insns then
                bfid = insns[i + 1] % 256
            else
                bfid = afield
            end
            local bfname = LBF_NAMES[bfid]
            if bfname then
                words[#words + 1] = bfname
            end
        end

        if afield > 0 then
            words[#words + 1] = "reg" .. afield
        end
        local bfield2 = lowbits(shr(insn, 16), 8)
        if bfield2 > 0 then
            words[#words + 1] = "reg" .. bfield2
        end
        local cfield = lowbits(shr(insn, 24), 8)
        if cfield > 0 then
            words[#words + 1] = "reg" .. cfield
        end

        if OP_LEN_2[op] then
            i = i + 2
        else
            i = i + 1
        end
    end
    return words
end

local function parse_bytecode(s)
    local pos = 1
    local version = s:byte(pos)
    pos = pos + 1
    if not version or version == 0 or version > 14 then
        error("bad version")
    end

    local typesversion = 0
    if version >= 4 then
        typesversion = s:byte(pos)
        pos = pos + 1
    end

    if typesversion == 3 then
        while true do
            local tag = s:byte(pos)
            pos = pos + 1
            if tag == 0 then break end
            pos = skip_varint(s, pos)
        end
    end

    local str_count
    str_count, pos = varint(s, pos)
    local strings = {}
    for i = 1, str_count do
        local len
        len, pos = varint(s, pos)
        if not len or pos + len - 1 > #s then
            error("truncated strings")
        end
        strings[i] = s:sub(pos, pos + len - 1)
        pos = pos + len
    end

    local proto_count
    proto_count, pos = varint(s, pos)
    local has_size = version >= 12

    local insns = {}
    local const_words = {}
    local debug_words = {}
    local import_words = {}
    local table_words = {}
    local class_words = {}
    local number_words = {}

    for proto_idx = 1, proto_count do
        local blob_end = nil
        if has_size then
            local sz
            sz, pos = varint(s, pos)
            blob_end = pos + sz
            if blob_end > #s then break end
        end

        local bp = pos + 4
        if version >= 4 then
            bp = bp + 1
            local tsize
            tsize, bp = varint(s, bp)
            bp = bp + tsize
        end

        local insn_count
        insn_count, bp = varint(s, bp)
        for i = 1, insn_count do
            insns[#insns + 1] = u32(s, bp)
            bp = bp + 4
        end

        local const_count
        const_count, bp = varint(s, bp)
        local const_indices = {}
        for ci = 1, const_count do
            local ctype = s:byte(bp)
            bp = bp + 1
            if ctype == 0 then
            elseif ctype == 1 then
                bp = bp + 1
            elseif ctype == 2 then
                push_num(number_words, f64(s, bp))
                bp = bp + 8
            elseif ctype == 3 then
                local sidx
                sidx, bp = varint(s, bp)
                const_indices[ci] = sidx
                if strings[sidx] then
                    const_words[#const_words + 1] = strings[sidx]
                end
            elseif ctype == 4 then
                local iid = u32(s, bp)
                bp = bp + 4
                local cnt = shr(iid, 30) % 4
                local ids = { shr(iid, 20) % 1024, shr(iid, 10) % 1024, iid % 1024 }
                for k = 1, cnt do
                    if strings[ids[k] + 1] then
                        import_words[#import_words + 1] = strings[ids[k] + 1]
                    end
                end
            elseif ctype == 5 then
                local tcount
                tcount, bp = varint(s, bp)
                for _ = 1, tcount do
                    local kidx
                    kidx, bp = varint(s, bp)
                    if const_indices[kidx + 1] and strings[const_indices[kidx + 1]] then
                        table_words[#table_words + 1] = strings[const_indices[kidx + 1]]
                    end
                end
            elseif ctype == 6 then
                bp = skip_varint(s, bp)
            elseif ctype == 7 then
                for _ = 1, 4 do
                    push_num(number_words, f32(s, bp))
                    bp = bp + 4
                end
            elseif ctype == 8 then
                local tcount
                tcount, bp = varint(s, bp)
                for _ = 1, tcount do
                    local kidx
                    kidx, bp = varint(s, bp)
                    bp = bp + 4
                    if const_indices[kidx + 1] and strings[const_indices[kidx + 1]] then
                        table_words[#table_words + 1] = strings[const_indices[kidx + 1]]
                    end
                end
            elseif ctype == 9 then
                local sign = s:byte(bp)
                bp = bp + 1
                local mag
                mag, bp = varint(s, bp)
                if sign == 1 then
                    push_num(number_words, -mag)
                else
                    push_num(number_words, mag)
                end
            elseif ctype == 10 then
                for _ = 1, 4 do
                    push_num(number_words, f64(s, bp))
                    bp = bp + 8
                end
            elseif ctype == 11 then
                local cidx
                cidx, bp = varint(s, bp)
                local pc
                pc, bp = varint(s, bp)
                local mc
                mc, bp = varint(s, bp)
                if strings[cidx] then
                    class_words[#class_words + 1] = strings[cidx]
                end
                for _ = 1, pc do
                    local pidx
                    pidx, bp = varint(s, bp)
                    if strings[pidx] then
                        class_words[#class_words + 1] = strings[pidx]
                    end
                end
                for _ = 1, mc do
                    local midx
                    midx, bp = varint(s, bp)
                    if strings[midx] then
                        class_words[#class_words + 1] = strings[midx]
                    end
                end
            else
                break
            end
        end

        local child_count
        child_count, bp = varint(s, bp)
        for _ = 1, child_count do
            bp = skip_varint(s, bp)
        end

        bp = skip_varint(s, bp)

        local dbgname_idx
        dbgname_idx, bp = varint(s, bp)
        if dbgname_idx > 0 and strings[dbgname_idx] then
            debug_words[#debug_words + 1] = strings[dbgname_idx]
        end

        if s:byte(bp) == 1 then
            local linegaplog2 = s:byte(bp + 1)
            local intervals = shr(insn_count - 1, linegaplog2) + 1
            bp = bp + 2 + insn_count + intervals * 4
        else
            bp = bp + 1
        end

        if s:byte(bp) == 1 then
            bp = bp + 1
            local lc
            lc, bp = varint(s, bp)
            for _ = 1, lc do
                local nidx
                nidx, bp = varint(s, bp)
                bp = skip_varint(s, bp)
                bp = skip_varint(s, bp)
                bp = bp + 1
                if strings[nidx] then
                    debug_words[#debug_words + 1] = strings[nidx]
                end
            end
            local uc
            uc, bp = varint(s, bp)
            for _ = 1, uc do
                local nidx
                nidx, bp = varint(s, bp)
                if strings[nidx] then
                    debug_words[#debug_words + 1] = strings[nidx]
                end
            end
        else
            bp = bp + 1
        end

        if blob_end then
            pos = blob_end
        else
            pos = bp
        end
    end

    return {
        strings = strings,
        insns = insns,
        number_words = number_words,
        const_words = const_words,
        debug_words = debug_words,
        import_words = import_words,
        table_words = table_words,
        class_words = class_words,
    }
end

local function get_words(bytecode)
    local hit = cache[bytecode]
    if hit ~= nil then
        return hit
    end

    local ok, parsed = pcall(parse_bytecode, bytecode)
    if not ok then
        cache[bytecode] = false
        return false
    end

    local words = {}
    for i = 1, #parsed.strings do
        push_split(words, parsed.strings[i])
    end

    local encoded = detect_encoding(parsed.insns)
    if encoded ~= nil then
        local kw = extract_insn_tokens(parsed.insns, encoded)
        for i = 1, #kw do
            words[#words + 1] = kw[i]
        end
    end

    for _, field in ipairs(TEXT_FIELDS) do
        local arr = parsed[field]
        for i = 1, #arr do
            push_split(words, arr[i])
        end
    end

    for i = 1, #parsed.number_words do
        words[#words + 1] = tostring(parsed.number_words[i])
    end

    cache[bytecode] = words
    return words
end

function M.filter(bytecodes, terms)
    local matches = {}
    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local words = get_words(bc)
            if words then
                local all = true
                for t = 1, #terms do
                    local term = terms[t]
                    local found = false
                    for w = 1, #words do
                        if words[w]:find(term, 1, true) then
                            found = true
                            break
                        end
                    end
                    if not found then
                        all = false
                        break
                    end
                end
                if all then
                    matches[#matches + 1] = i
                end
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

M.version = "1.1.6"

return M
