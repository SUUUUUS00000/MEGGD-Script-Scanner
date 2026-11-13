local M = {}
local cache = {}

local OP_LEN = {
    [0]=1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 2, 1, 1, 2,
    2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2,
    2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 1,
    1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 2, 2, 2,
    2, 1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2,
}

local SIMPLE_CLEAR_A = {
    [4]=true, [5]=true, [9]=true, [13]=true, [17]=true, [19]=true,
    [33]=true, [34]=true, [35]=true, [36]=true, [37]=true, [38]=true,
    [39]=true, [40]=true, [41]=true, [42]=true, [43]=true, [44]=true,
    [45]=true, [46]=true, [47]=true, [48]=true, [49]=true, [50]=true,
    [51]=true, [52]=true, [53]=true, [54]=true, [64]=true, [66]=true,
    [71]=true, [72]=true, [81]=true, [82]=true, [90]=true, [91]=true,
    [93]=true,
}

local OP_PATTERN = {
    [19]="function:closure",
    [24]="loop:jumpback",
    [27]="if:eq",
    [28]="if:le",
    [29]="if:lt",
    [30]="if:ne",
    [31]="if:gt",
    [32]="if:ge",
    [33]="arith:add",
    [34]="arith:sub",
    [35]="arith:mul",
    [36]="arith:div",
    [37]="arith:mod",
    [38]="arith:pow",
    [39]="arith:add",
    [40]="arith:sub",
    [41]="arith:mul",
    [42]="arith:div",
    [43]="arith:mod",
    [44]="arith:pow",
    [45]="cond:and",
    [46]="cond:or",
    [47]="cond:and",
    [48]="cond:or",
    [49]="concat",
    [50]="cond:not",
    [52]="arith:length",
    [53]="table:new",
    [54]="table:dup",
    [55]="table:setlist",
    [64]="function:dup",
    [71]="arith:sub",
    [72]="arith:div",
    [81]="arith:idiv",
    [82]="arith:idiv",
}

local BUILTIN_CALLS = {}
for id, name in pairs({
    [1]="assert", [2]="math.abs", [3]="math.acos", [4]="math.asin",
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
    [48]="math.round", [49]="rawset", [50]="rawget", [51]="rawequal",
    [52]="table.insert", [53]="table.unpack", [54]="vector",
    [55]="bit32.countlz", [56]="bit32.countrz", [57]="select",
    [58]="rawlen", [59]="bit32.extractk", [60]="getmetatable", [61]="setmetatable",
    [62]="tonumber", [63]="tostring", [64]="bit32.byteswap",
    [65]="buffer.readi8", [66]="buffer.readu8", [67]="buffer.writeu8",
    [68]="buffer.readi16", [69]="buffer.readu16", [70]="buffer.writeu16",
    [71]="buffer.readi32", [72]="buffer.readu32", [73]="buffer.writeu32",
    [74]="buffer.readf32", [75]="buffer.writef32", [76]="buffer.readf64",
    [77]="buffer.writef64", [78]="vector.magnitude", [79]="vector.normalize",
    [80]="vector.cross", [81]="vector.dot", [82]="vector.floor", [83]="vector.ceil",
    [84]="vector.abs", [85]="vector.sign", [86]="vector.clamp", [87]="vector.min",
    [88]="vector.max", [89]="math.lerp", [90]="vector.lerp", [91]="math.isnan",
    [92]="math.isinf", [93]="math.isfinite", [94]="integer.create", [95]="integer.tonumber",
    [96]="integer.neg", [97]="integer.add", [98]="integer.sub", [99]="integer.mul",
    [100]="integer.div", [101]="integer.min", [102]="integer.max", [103]="integer.rem",
    [104]="integer.idiv", [105]="integer.udiv", [106]="integer.urem", [107]="integer.mod",
    [108]="integer.clamp", [109]="integer.band", [110]="integer.bor", [111]="integer.bnot",
    [112]="integer.bxor", [113]="integer.lt", [114]="integer.le", [115]="integer.ult",
    [116]="integer.ule", [117]="integer.gt", [118]="integer.ge", [119]="integer.ugt",
    [120]="integer.uge", [121]="integer.lshift", [122]="integer.rshift", [123]="integer.arshift",
    [124]="integer.lrotate", [125]="integer.rrotate", [126]="integer.extract", [127]="integer.btest",
    [128]="integer.countrz", [129]="integer.countlz", [130]="integer.bswap",
    [131]="buffer.readinteger", [132]="buffer.writeinteger", [133]="table.create", [134]="table.clear",
}) do
    BUILTIN_CALLS[id] = "call:" .. name
end

local ENCODE_OP = {}
for i = 0, 255 do
    ENCODE_OP[i] = (i * 203) % 256
end

local byte = string.byte
local sub = string.sub
local slower = string.lower
local sort = table.sort
local sfind = string.find
local smatch = string.match
local band = bit32.band
local rshift = bit32.rshift
local tclear = table.clear
local tcreate = table.create

local buf_lib = buffer
local bfrom = buf_lib and buf_lib.fromstring
local breadu8 = buf_lib and buf_lib.readu8
local breadu32 = buf_lib and buf_lib.readu32
local breadstring = buf_lib and buf_lib.readstring

local os_clock = os and os.clock
local task_wait = task and task.wait

local scratch_strings = {}
local scratch_str_flags = {}
local scratch_insns = {}
local scratch_constants = {}
local scratch_const_sidx = {}
local scratch_import_gen = {}
local scratch_import_paths = {}
local scratch_import_calls = {}
local scratch_reg_call = {}
local scratch_reg_ret = {}
local scratch_max_reg = -1
local import_gen_counter = 0

@native
local function read_varint_tail_buf(buf, pos, len, b0)
    local result = b0 - 128
    local mul = 128
    pos = pos + 1
    while true do
        if pos >= len then
            error("eof")
        end
        local b = breadu8(buf, pos)
        pos = pos + 1
        if b < 128 then
            return result + b * mul, pos
        end
        result = result + (b - 128) * mul
        mul = mul * 128
    end
end

local function read_varint_tail_str(s, pos, b0)
    local result = b0 - 128
    local mul = 128
    pos = pos + 1
    while true do
        local b = byte(s, pos)
        if not b then
            error("eof")
        end
        pos = pos + 1
        if b < 128 then
            return result + b * mul, pos
        end
        result = result + (b - 128) * mul
        mul = mul * 128
    end
end

local function decode_import(constants, const_count, idx1, active_imp_gen)
    if idx1 < 1 or idx1 > const_count then
        return nil, nil
    end

    local import_gen = scratch_import_gen
    local import_paths = scratch_import_paths
    local import_calls = scratch_import_calls

    if import_gen[idx1] == active_imp_gen then
        local cached = import_paths[idx1]
        if not cached then
            return nil, nil
        end
        return cached, import_calls[idx1]
    end

    import_gen[idx1] = active_imp_gen

    local iid = constants[idx1]
    if type(iid) ~= "number" then
        import_paths[idx1] = false
        return nil, nil
    end

    local cnt = rshift(iid, 30)
    local k1 = cnt >= 1 and band(rshift(iid, 20), 1023) + 1 or 0
    local k2 = cnt >= 2 and band(rshift(iid, 10), 1023) + 1 or 0
    local k3 = cnt >= 3 and band(iid, 1023) + 1 or 0

    local p1 = k1 >= 1 and k1 <= const_count and constants[k1]
    local p2 = k2 >= 1 and k2 <= const_count and constants[k2]
    local p3 = k3 >= 1 and k3 <= const_count and constants[k3]

    local s1 = type(p1) == "string" and p1 or nil
    local s2 = type(p2) == "string" and p2 or nil
    local s3 = type(p3) == "string" and p3 or nil

    local path
    local last
    if s1 and s2 and s3 then
        path = s1 .. "." .. s2 .. "." .. s3
        last = s3
    elseif s1 and s2 then
        path = s1 .. "." .. s2
        last = s2
    elseif s1 and s3 then
        path = s1 .. "." .. s3
        last = s3
    elseif s2 and s3 then
        path = s2 .. "." .. s3
        last = s3
    else
        path = s1 or s2 or s3
        last = path
    end

    if not path then
        import_paths[idx1] = false
        return nil, nil
    end

    local short = smatch(last, "([^.]+)$") or last
    local call_pat = "call:" .. short
    import_paths[idx1] = path
    import_calls[idx1] = call_pat
    return path, call_pat
end

@native
local function is_valid_stream_detect(insns, n)
    local pc = 1
    local certain_plain = false
    while pc <= n do
        local op = band(insns[pc], 255)
        local len = OP_LEN[op]
        if not len or pc + len - 1 > n then
            return false, false
        end
        if not certain_plain and not OP_LEN[ENCODE_OP[op]] then
            certain_plain = true
        end
        pc = pc + len
    end
    return true, certain_plain
end

@native
local function is_valid_stream_true(insns, n)
    local pc = 1
    while pc <= n do
        local op = ENCODE_OP[band(insns[pc], 255)]
        local len = OP_LEN[op]
        if not len or pc + len - 1 > n then
            return false
        end
        pc = pc + len
    end
    return true
end

@native
local function is_andor_jump(pc, insn, total, insns, use_encode)
    local d = rshift(insn, 16)
    if d >= 32768 then
        d = d - 65536
    end
    local target = pc + 1 + d
    if target >= 1 and target <= total then
        local tinsn = insns[target]
        local top = band(tinsn, 255)
        if use_encode then
            top = ENCODE_OP[top]
        end
        if top == 3 then
            return rshift(tinsn, 24) ~= 0
        end
        if top == 6 then
            return true
        end
    end
    return false
end

@native
local function is_call_target(pc, len, reg, total, insns, use_encode)
    local nxt = pc + len
    if nxt > total then
        return false
    end
    local ninsn = insns[nxt]
    local nop = band(ninsn, 255)
    if use_encode then
        nop = ENCODE_OP[nop]
    end
    return (nop == 21 or nop == 87) and band(rshift(ninsn, 8), 255) == reg
end

@native
local function extract_proto(insns, total, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, set, found, found_n)
    if total == 0 then
        return found_n, encoded_mode
    end

    local use_encode
    if encoded_mode == true then
        use_encode = true
    elseif encoded_mode == false then
        use_encode = false
    else
        local valid, certain_plain = is_valid_stream_detect(insns, total)
        if valid then
            use_encode = false
            if certain_plain then
                encoded_mode = false
            end
        elseif is_valid_stream_true(insns, total) then
            use_encode = true
            encoded_mode = true
        else
            return found_n, encoded_mode
        end
    end

    local reg_call = scratch_reg_call
    local reg_ret = scratch_reg_ret
    if scratch_max_reg >= 0 then
        for r = 0, scratch_max_reg do
            reg_call[r] = nil
            reg_ret[r] = nil
        end
    end
    scratch_max_reg = 255

    local active_imp_gen = 0
    if has_imports then
        import_gen_counter = import_gen_counter + 1
        active_imp_gen = import_gen_counter
    end

    local max_reg = -1
    local pc = 1

    while pc <= total do
        local insn = insns[pc]
        local op = band(insn, 255)
        if use_encode then
            op = ENCODE_OP[op]
        end
        local len = OP_LEN[op]
        if not len or pc + len - 1 > total then
            break
        end

        local a = band(rshift(insn, 8), 255)

        if op == 22 then
            local b = band(rshift(insn, 16), 255)
            local pat = b == 1 and "return:void" or (reg_ret[a] or "return:value")
            if not set[pat] then
                set[pat] = true
                found_n = found_n + 1
                found[found_n] = pat
            end
        elseif op == 21 or op == 87 then
            local cp = reg_call[a]
            if cp then
                if type(cp) == "number" then
                    if band(str_flags[cp], 8) == 0 then
                        str_flags[cp] = str_flags[cp] + 8
                        local cpat = "call:" .. strings[cp]
                        if not set[cpat] then
                            set[cpat] = true
                            found_n = found_n + 1
                            found[found_n] = cpat
                        end
                    end
                elseif not set[cp] then
                    set[cp] = true
                    found_n = found_n + 1
                    found[found_n] = cp
                end
            end
            local c = rshift(insn, 24)
            local nres = c - 1
            if nres < 0 then
                for r = a, max_reg do
                    reg_call[r] = nil
                    reg_ret[r] = nil
                end
                reg_ret[a] = "return:call"
                if a > max_reg then
                    max_reg = a
                end
            elseif nres == 0 then
                reg_call[a] = nil
                reg_ret[a] = nil
            else
                local top = a + nres - 1
                for r = a, top do
                    reg_call[r] = nil
                    reg_ret[r] = "return:call"
                end
                if top > max_reg then
                    max_reg = top
                end
            end
        elseif op == 20 or op == 85 then
            local aux = insns[pc + 1]
            local idx1 = (op == 20 and aux or band(aux, 65535)) + 1
            local key = idx1 <= const_count and constants[idx1]
            if type(key) == "string" and #key > 0 then
                local sidx = const_sidx[idx1]
                local fl = str_flags[sidx]
                if band(fl, 16) == 0 then
                    fl = fl + 16
                    local mpat = "method:" .. key
                    if not set[mpat] then
                        set[mpat] = true
                        found_n = found_n + 1
                        found[found_n] = mpat
                    end
                end
                if band(fl, 8) == 0 then
                    fl = fl + 8
                    local cpat = "call:" .. key
                    if not set[cpat] then
                        set[cpat] = true
                        found_n = found_n + 1
                        found[found_n] = cpat
                    end
                end
                str_flags[sidx] = fl
                reg_call[a] = sidx
            else
                reg_call[a] = nil
            end
            reg_call[a + 1] = nil
            reg_ret[a] = nil
            reg_ret[a + 1] = nil
            if a + 1 > max_reg then
                max_reg = a + 1
            end
        elseif op == 15 or op == 7 or op == 83 then
            local aux = insns[pc + 1]
            local idx1 = (op == 83 and band(aux, 65535) or aux) + 1
            local key = idx1 <= const_count and constants[idx1]
            if type(key) == "string" and #key > 0 then
                local sidx = const_sidx[idx1]
                if not is_call_target(pc, len, a, total, insns, use_encode) then
                    if band(str_flags[sidx], 2) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 2
                        local gpat = "get:" .. key
                        if not set[gpat] then
                            set[gpat] = true
                            found_n = found_n + 1
                            found[found_n] = gpat
                        end
                    end
                end
                reg_call[a] = sidx
            else
                reg_call[a] = nil
            end
            reg_ret[a] = nil
            if a > max_reg then
                max_reg = a
            end
        elseif op == 16 or op == 8 or op == 84 then
            local aux = insns[pc + 1]
            local idx1 = (op == 84 and band(aux, 65535) or aux) + 1
            local key = idx1 <= const_count and constants[idx1]
            if type(key) == "string" and #key > 0 then
                local sidx = const_sidx[idx1]
                if band(str_flags[sidx], 4) == 0 then
                    str_flags[sidx] = str_flags[sidx] + 4
                    local spat = "set:" .. key
                    if not set[spat] then
                        set[spat] = true
                        found_n = found_n + 1
                        found[found_n] = spat
                    end
                end
            end
        elseif op == 86 then
            if band(rshift(insn, 16), 255) == 0 then
                local idx1 = insns[pc + 1] + 1
                local key = idx1 <= const_count and constants[idx1]
                if type(key) == "string" and #key > 0 then
                    local sidx = const_sidx[idx1]
                    if band(str_flags[sidx], 4) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 4
                        local spat = "set:" .. key
                        if not set[spat] then
                            set[spat] = true
                            found_n = found_n + 1
                            found[found_n] = spat
                        end
                    end
                end
            end
        elseif op == 12 then
            local dfield = rshift(insn, 16)
            local path, cpat = decode_import(constants, const_count, dfield + 1, active_imp_gen)
            if path then
                local ipat = "import:" .. path
                if not set[ipat] then
                    set[ipat] = true
                    found_n = found_n + 1
                    found[found_n] = ipat
                end
                if not is_call_target(pc, len, a, total, insns, use_encode) then
                    local gpat = "get:" .. path
                    if not set[gpat] then
                        set[gpat] = true
                        found_n = found_n + 1
                        found[found_n] = gpat
                    end
                end
                reg_call[a] = cpat
            else
                reg_call[a] = nil
            end
            reg_ret[a] = nil
            if a > max_reg then
                max_reg = a
            end
        elseif op == 6 then
            local b = band(rshift(insn, 16), 255)
            reg_call[a] = reg_call[b]
            reg_ret[a] = reg_ret[b]
            if a > max_reg then
                max_reg = a
            end
        elseif op == 2 then
            reg_call[a] = nil
            reg_ret[a] = "return:nil"
            if a > max_reg then
                max_reg = a
            end
        elseif op == 3 then
            local b = band(rshift(insn, 16), 255)
            reg_call[a] = nil
            reg_ret[a] = b == 0 and "return:false" or (b == 1 and "return:true" or nil)
            if a > max_reg then
                max_reg = a
            end
        elseif op == 25 then
            local pat = is_andor_jump(pc, insn, total, insns, use_encode) and "cond:or" or "if:then"
            if not set[pat] then
                set[pat] = true
                found_n = found_n + 1
                found[found_n] = pat
            end
        elseif op == 26 then
            if is_andor_jump(pc, insn, total, insns, use_encode) then
                if not set["cond:and"] then
                    set["cond:and"] = true
                    found_n = found_n + 1
                    found[found_n] = "cond:and"
                end
            else
                if not set["if:then"] then
                    set["if:then"] = true
                    found_n = found_n + 1
                    found[found_n] = "if:then"
                end
                if not set["if:not-then"] then
                    set["if:not-then"] = true
                    found_n = found_n + 1
                    found[found_n] = "if:not-then"
                end
            end
        elseif op == 77 or op == 78 or op == 79 or op == 80 then
            local pat = insns[pc + 1] >= 2147483648 and "if:ne" or "if:eq"
            if not set[pat] then
                set[pat] = true
                found_n = found_n + 1
                found[found_n] = pat
            end
        elseif op == 56 or op == 59 or op == 61 or op == 76 then
            local pat = op == 56 and "loop:for-num" or (op == 61 and "loop:for-in-next" or (op == 59 and "loop:for-in-inext" or "loop:for-in"))
            if not set[pat] then
                set[pat] = true
                found_n = found_n + 1
                found[found_n] = pat
            end
            for r = a, a + 3 do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 57 then
            if not set["loop:for-num"] then
                set["loop:for-num"] = true
                found_n = found_n + 1
                found[found_n] = "loop:for-num"
            end
            reg_call[a + 2] = nil
            reg_call[a + 3] = nil
            reg_ret[a + 2] = nil
            reg_ret[a + 3] = nil
        elseif op == 58 then
            if not set["loop:for-in"] then
                set["loop:for-in"] = true
                found_n = found_n + 1
                found[found_n] = "loop:for-in"
            end
            local top = a + 2 + band(insns[pc + 1], 255)
            for r = a + 2, top do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 63 then
            if not set["vararg:get"] then
                set["vararg:get"] = true
                found_n = found_n + 1
                found[found_n] = "vararg:get"
            end
            local b = band(rshift(insn, 16), 255)
            if b == 0 then
                for r = a, max_reg do
                    reg_call[r] = nil
                    reg_ret[r] = nil
                end
            elseif b >= 2 then
                local top = a + b - 2
                for r = a, top do
                    reg_call[r] = nil
                    reg_ret[r] = nil
                end
            end
        elseif op == 68 or op == 73 or op == 74 or op == 75 or op == 60 then
            local bcall = BUILTIN_CALLS[a]
            if bcall and not set[bcall] then
                set[bcall] = true
                found_n = found_n + 1
                found[found_n] = bcall
            end
        elseif op == 89 then
            if a == 0 then
                if not set["call:pcall"] then
                    set["call:pcall"] = true
                    found_n = found_n + 1
                    found[found_n] = "call:pcall"
                end
            elseif a == 1 then
                if not set["call:xpcall"] then
                    set["call:xpcall"] = true
                    found_n = found_n + 1
                    found[found_n] = "call:xpcall"
                end
            end
        else
            local tag = OP_PATTERN[op]
            if tag and not set[tag] then
                set[tag] = true
                found_n = found_n + 1
                found[found_n] = tag
            end
            if SIMPLE_CLEAR_A[op] then
                reg_call[a] = nil
                reg_ret[a] = nil
            end
        end

        pc = pc + len
    end

    scratch_max_reg = max_reg
    return found_n, encoded_mode
end

@native
local function parse_and_extract_buf(bytecode, set, found)
    local blen = #bytecode
    local buf = bfrom(bytecode)
    local pos = 0

    local version = breadu8(buf, pos)
    pos = pos + 1
    if version < 3 or (version > 14 and version ~= 100) then
        error("bad version")
    end

    local typesversion = 0
    if version >= 4 then
        typesversion = breadu8(buf, pos)
        pos = pos + 1
    end

    local str_count = breadu8(buf, pos)
    if str_count < 128 then
        pos = pos + 1
    else
        str_count, pos = read_varint_tail_buf(buf, pos, blen, str_count)
    end

    local strings = scratch_strings
    local str_flags = scratch_str_flags
    for i = 1, str_count do
        local slen = breadu8(buf, pos)
        if slen < 128 then
            pos = pos + 1
        else
            slen, pos = read_varint_tail_buf(buf, pos, blen, slen)
        end
        if pos + slen > blen then
            error("eof")
        end
        strings[i] = breadstring(buf, pos, slen)
        str_flags[i] = 0
        pos = pos + slen
    end

    if typesversion == 3 then
        while true do
            if pos >= blen then
                error("eof")
            end
            local tag = breadu8(buf, pos)
            pos = pos + 1
            if tag == 0 then
                break
            end
            local tv = breadu8(buf, pos)
            if tv < 128 then
                pos = pos + 1
            else
                _, pos = read_varint_tail_buf(buf, pos, blen, tv)
            end
        end
    end

    local proto_count = breadu8(buf, pos)
    if proto_count < 128 then
        pos = pos + 1
    else
        proto_count, pos = read_varint_tail_buf(buf, pos, blen, proto_count)
    end

    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local insns = scratch_insns
    local constants = scratch_constants
    local const_sidx = scratch_const_sidx

    for _ = 1, proto_count do
        local blob_end
        if has_size then
            local sz = breadu8(buf, pos)
            if sz < 128 then
                pos = pos + 1
            else
                sz, pos = read_varint_tail_buf(buf, pos, blen, sz)
            end
            blob_end = pos + sz
            if blob_end > blen then
                break
            end
        end

        local limit = blob_end or blen
        local bp = pos + 4

        if version >= 4 then
            bp = bp + 1
            local tsize = breadu8(buf, bp)
            if tsize < 128 then
                bp = bp + 1 + tsize
            else
                local np
                tsize, np = read_varint_tail_buf(buf, bp, limit, tsize)
                bp = np + tsize
            end
        end

        local insn_count = breadu8(buf, bp)
        if insn_count < 128 then
            bp = bp + 1
        else
            insn_count, bp = read_varint_tail_buf(buf, bp, limit, insn_count)
        end
        if bp + insn_count * 4 > limit then
            error("eof u32")
        end

        for i = 1, insn_count do
            insns[i] = breadu32(buf, bp)
            bp = bp + 4
        end

        local const_count = breadu8(buf, bp)
        if const_count < 128 then
            bp = bp + 1
        else
            const_count, bp = read_varint_tail_buf(buf, bp, limit, const_count)
        end

        local has_imports = false
        local broken_const = false

        for ci = 1, const_count do
            if bp >= limit then
                broken_const = true
                break
            end
            local ctype = breadu8(buf, bp)
            bp = bp + 1

            if ctype == 0 then
                constants[ci] = nil
                const_sidx[ci] = 0
            elseif ctype == 1 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 1
            elseif ctype == 2 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 8
            elseif ctype == 3 then
                local sidx = breadu8(buf, bp)
                if sidx < 128 then
                    bp = bp + 1
                else
                    sidx, bp = read_varint_tail_buf(buf, bp, limit, sidx)
                end
                if sidx >= 1 and sidx <= str_count then
                    local sv = strings[sidx]
                    constants[ci] = sv
                    const_sidx[ci] = sidx
                    if #sv > 0 and band(str_flags[sidx], 1) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 1
                        local sp = "string:" .. sv
                        if not set[sp] then
                            set[sp] = true
                            found_n = found_n + 1
                            found[found_n] = sp
                        end
                    end
                else
                    constants[ci] = nil
                    const_sidx[ci] = 0
                end
            elseif ctype == 4 then
                if bp + 4 > limit then
                    error("eof u32")
                end
                constants[ci] = breadu32(buf, bp)
                const_sidx[ci] = 0
                has_imports = true
                bp = bp + 4
            elseif ctype == 5 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local n = breadu8(buf, bp)
                if n < 128 then
                    bp = bp + 1
                else
                    n, bp = read_varint_tail_buf(buf, bp, limit, n)
                end
                for _ = 1, n do
                    local v = breadu8(buf, bp)
                    if v < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_buf(buf, bp, limit, v)
                    end
                end
            elseif ctype == 6 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local v = breadu8(buf, bp)
                if v < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_buf(buf, bp, limit, v)
                end
            elseif ctype == 7 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 16
            elseif ctype == 8 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local n = breadu8(buf, bp)
                if n < 128 then
                    bp = bp + 1
                else
                    n, bp = read_varint_tail_buf(buf, bp, limit, n)
                end
                for _ = 1, n do
                    local v = breadu8(buf, bp)
                    if v < 128 then
                        bp = bp + 5
                    else
                        local np
                        _, np = read_varint_tail_buf(buf, bp, limit, v)
                        bp = np + 4
                    end
                end
            elseif ctype == 9 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 1
                local v = breadu8(buf, bp)
                if v < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_buf(buf, bp, limit, v)
                end
            elseif ctype == 10 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local v1 = breadu8(buf, bp)
                if v1 < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_buf(buf, bp, limit, v1)
                end
                local pc2 = breadu8(buf, bp)
                if pc2 < 128 then
                    bp = bp + 1
                else
                    pc2, bp = read_varint_tail_buf(buf, bp, limit, pc2)
                end
                local mc = breadu8(buf, bp)
                if mc < 128 then
                    bp = bp + 1
                else
                    mc, bp = read_varint_tail_buf(buf, bp, limit, mc)
                end
                for _ = 1, pc2 + mc do
                    local pv = breadu8(buf, bp)
                    if pv < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_buf(buf, bp, limit, pv)
                    end
                end
            elseif ctype == 11 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 32
            else
                broken_const = true
                break
            end
        end

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, set, found, found_n)

        if broken_const then
            if blob_end then
                pos = blob_end
            else
                break
            end
        else
            if bp < limit then
                local child_count = breadu8(buf, bp)
                if child_count < 128 then
                    bp = bp + 1
                else
                    child_count, bp = read_varint_tail_buf(buf, bp, limit, child_count)
                end
                for _ = 1, child_count do
                    local cv = breadu8(buf, bp)
                    if cv < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_buf(buf, bp, limit, cv)
                    end
                end

                local ld = breadu8(buf, bp)
                if ld < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_buf(buf, bp, limit, ld)
                end

                local didx = breadu8(buf, bp)
                if didx < 128 then
                    bp = bp + 1
                else
                    didx, bp = read_varint_tail_buf(buf, bp, limit, didx)
                end
                if didx >= 1 and didx <= str_count then
                    local dn = strings[didx]
                    if #dn > 0 and band(str_flags[didx], 32) == 0 then
                        str_flags[didx] = str_flags[didx] + 32
                        local fp = "func:" .. dn
                        if not set[fp] then
                            set[fp] = true
                            found_n = found_n + 1
                            found[found_n] = fp
                        end
                    end
                end

                if bp < limit then
                    if breadu8(buf, bp) == 1 then
                        if bp + 1 >= limit then
                            if blob_end then
                                bp = limit
                            else
                                error("eof")
                            end
                        else
                            local linegap = breadu8(buf, bp + 1)
                            local intervals = 1
                            if insn_count > 0 and linegap < 32 then
                                intervals = rshift(insn_count - 1, linegap) + 1
                            end
                            bp = bp + 2 + insn_count + intervals * 4
                        end
                    else
                        bp = bp + 1
                    end
                end

                if bp < limit then
                    if breadu8(buf, bp) == 1 then
                        bp = bp + 1
                        local lc = breadu8(buf, bp)
                        if lc < 128 then
                            bp = bp + 1
                        else
                            lc, bp = read_varint_tail_buf(buf, bp, limit, lc)
                        end
                        for _ = 1, lc do
                            local vidx = breadu8(buf, bp)
                            if vidx < 128 then
                                bp = bp + 1
                            else
                                vidx, bp = read_varint_tail_buf(buf, bp, limit, vidx)
                            end
                            if vidx >= 1 and vidx <= str_count then
                                local vn = strings[vidx]
                                if #vn > 0 and band(str_flags[vidx], 64) == 0 then
                                    str_flags[vidx] = str_flags[vidx] + 64
                                    local lp = "local:" .. vn
                                    if not set[lp] then
                                        set[lp] = true
                                        found_n = found_n + 1
                                        found[found_n] = lp
                                    end
                                end
                            end
                            local spc = breadu8(buf, bp)
                            if spc < 128 then
                                bp = bp + 1
                            else
                                _, bp = read_varint_tail_buf(buf, bp, limit, spc)
                            end
                            local epc = breadu8(buf, bp)
                            if epc < 128 then
                                bp = bp + 2
                            else
                                local np6
                                _, np6 = read_varint_tail_buf(buf, bp, limit, epc)
                                bp = np6 + 1
                            end
                        end

                        local uc = breadu8(buf, bp)
                        if uc < 128 then
                            bp = bp + 1
                        else
                            uc, bp = read_varint_tail_buf(buf, bp, limit, uc)
                        end
                        for _ = 1, uc do
                            local uidx = breadu8(buf, bp)
                            if uidx < 128 then
                                bp = bp + 1
                            else
                                uidx, bp = read_varint_tail_buf(buf, bp, limit, uidx)
                            end
                            if uidx >= 1 and uidx <= str_count then
                                local un = strings[uidx]
                                if #un > 0 and band(str_flags[uidx], 128) == 0 then
                                    str_flags[uidx] = str_flags[uidx] + 128
                                    local up = "upval:" .. un
                                    if not set[up] then
                                        set[up] = true
                                        found_n = found_n + 1
                                        found[found_n] = up
                                    end
                                end
                            end
                        end
                    else
                        bp = bp + 1
                    end
                end
            end

            if blob_end then
                pos = blob_end
            else
                if (version >= 11 or version == 100) and bp < limit then
                    local fb = breadu8(buf, bp)
                    if fb < 128 then
                        bp = bp + 1
                    else
                        fb, bp = read_varint_tail_buf(buf, bp, limit, fb)
                    end
                    for _ = 1, fb do
                        bp = bp + 1
                        local fv = breadu8(buf, bp)
                        if fv < 128 then
                            bp = bp + 1
                        else
                            _, bp = read_varint_tail_buf(buf, bp, limit, fv)
                        end
                    end
                end
                pos = bp
            end
        end
    end

    return found_n
end

local function parse_and_extract_str(bytecode, set, found)
    local slen = #bytecode
    local pos = 1

    local version = byte(bytecode, pos)
    pos = pos + 1
    if not version or version < 3 or (version > 14 and version ~= 100) then
        error("bad version")
    end

    local typesversion = 0
    if version >= 4 then
        typesversion = byte(bytecode, pos)
        pos = pos + 1
    end

    local str_count = byte(bytecode, pos)
    if not str_count then
        error("eof")
    end
    if str_count < 128 then
        pos = pos + 1
    else
        str_count, pos = read_varint_tail_str(bytecode, pos, str_count)
    end

    local strings = scratch_strings
    local str_flags = scratch_str_flags
    for i = 1, str_count do
        local len = byte(bytecode, pos)
        if not len then
            error("eof")
        end
        if len < 128 then
            pos = pos + 1
        else
            len, pos = read_varint_tail_str(bytecode, pos, len)
        end
        if pos + len - 1 > slen then
            error("eof")
        end
        strings[i] = sub(bytecode, pos, pos + len - 1)
        str_flags[i] = 0
        pos = pos + len
    end

    if typesversion == 3 then
        while true do
            local tag = byte(bytecode, pos)
            pos = pos + 1
            if tag == nil or tag == 0 then
                break
            end
            local tv = byte(bytecode, pos)
            if not tv then
                error("eof")
            end
            if tv < 128 then
                pos = pos + 1
            else
                _, pos = read_varint_tail_str(bytecode, pos, tv)
            end
        end
    end

    local proto_count = byte(bytecode, pos)
    if not proto_count then
        error("eof")
    end
    if proto_count < 128 then
        pos = pos + 1
    else
        proto_count, pos = read_varint_tail_str(bytecode, pos, proto_count)
    end

    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local insns = scratch_insns
    local constants = scratch_constants
    local const_sidx = scratch_const_sidx

    for _ = 1, proto_count do
        local blob_end
        if has_size then
            local sz = byte(bytecode, pos)
            if not sz then
                error("eof")
            end
            if sz < 128 then
                pos = pos + 1
            else
                sz, pos = read_varint_tail_str(bytecode, pos, sz)
            end
            blob_end = pos + sz
            if blob_end > slen + 1 then
                break
            end
        end

        local max_end = blob_end and (blob_end - 1) or slen
        local bp = pos + 4

        if version >= 4 then
            bp = bp + 1
            local tsize = byte(bytecode, bp)
            if not tsize then
                error("eof")
            end
            if tsize < 128 then
                bp = bp + 1 + tsize
            else
                local np
                tsize, np = read_varint_tail_str(bytecode, bp, tsize)
                bp = np + tsize
            end
        end

        local insn_count = byte(bytecode, bp)
        if not insn_count then
            error("eof")
        end
        if insn_count < 128 then
            bp = bp + 1
        else
            insn_count, bp = read_varint_tail_str(bytecode, bp, insn_count)
        end
        if bp + insn_count * 4 - 1 > max_end then
            error("eof u32")
        end

        for i = 1, insn_count do
            local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
            insns[i] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            bp = bp + 4
        end

        local const_count = byte(bytecode, bp)
        if not const_count then
            error("eof")
        end
        if const_count < 128 then
            bp = bp + 1
        else
            const_count, bp = read_varint_tail_str(bytecode, bp, const_count)
        end

        local has_imports = false
        local broken_const = false

        for ci = 1, const_count do
            if bp > max_end then
                broken_const = true
                break
            end
            local ctype = byte(bytecode, bp)
            if not ctype then
                broken_const = true
                break
            end
            bp = bp + 1

            if ctype == 0 then
                constants[ci] = nil
                const_sidx[ci] = 0
            elseif ctype == 1 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 1
            elseif ctype == 2 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 8
            elseif ctype == 3 then
                local sidx = byte(bytecode, bp)
                if not sidx then
                    error("eof")
                end
                if sidx < 128 then
                    bp = bp + 1
                else
                    sidx, bp = read_varint_tail_str(bytecode, bp, sidx)
                end
                if sidx >= 1 and sidx <= str_count then
                    local sv = strings[sidx]
                    constants[ci] = sv
                    const_sidx[ci] = sidx
                    if #sv > 0 and band(str_flags[sidx], 1) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 1
                        local sp = "string:" .. sv
                        if not set[sp] then
                            set[sp] = true
                            found_n = found_n + 1
                            found[found_n] = sp
                        end
                    end
                else
                    constants[ci] = nil
                    const_sidx[ci] = 0
                end
            elseif ctype == 4 then
                local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
                if not b1 or not b2 or not b3 or not b4 then
                    error("eof u32")
                end
                constants[ci] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
                const_sidx[ci] = 0
                has_imports = true
                bp = bp + 4
            elseif ctype == 5 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local n = byte(bytecode, bp)
                if not n then
                    error("eof")
                end
                if n < 128 then
                    bp = bp + 1
                else
                    n, bp = read_varint_tail_str(bytecode, bp, n)
                end
                for _ = 1, n do
                    local v = byte(bytecode, bp)
                    if not v then
                        error("eof")
                    end
                    if v < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_str(bytecode, bp, v)
                    end
                end
            elseif ctype == 6 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local v = byte(bytecode, bp)
                if not v then
                    error("eof")
                end
                if v < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_str(bytecode, bp, v)
                end
            elseif ctype == 7 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 16
            elseif ctype == 8 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local n = byte(bytecode, bp)
                if not n then
                    error("eof")
                end
                if n < 128 then
                    bp = bp + 1
                else
                    n, bp = read_varint_tail_str(bytecode, bp, n)
                end
                for _ = 1, n do
                    local v = byte(bytecode, bp)
                    if not v then
                        error("eof")
                    end
                    if v < 128 then
                        bp = bp + 5
                    else
                        local np
                        _, np = read_varint_tail_str(bytecode, bp, v)
                        bp = np + 4
                    end
                end
            elseif ctype == 9 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 1
                local v = byte(bytecode, bp)
                if not v then
                    error("eof")
                end
                if v < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_str(bytecode, bp, v)
                end
            elseif ctype == 10 then
                constants[ci] = nil
                const_sidx[ci] = 0
                local v1 = byte(bytecode, bp)
                if not v1 then
                    error("eof")
                end
                if v1 < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_str(bytecode, bp, v1)
                end
                local pc2 = byte(bytecode, bp)
                if not pc2 then
                    error("eof")
                end
                if pc2 < 128 then
                    bp = bp + 1
                else
                    pc2, bp = read_varint_tail_str(bytecode, bp, pc2)
                end
                local mc = byte(bytecode, bp)
                if not mc then
                    error("eof")
                end
                if mc < 128 then
                    bp = bp + 1
                else
                    mc, bp = read_varint_tail_str(bytecode, bp, mc)
                end
                for _ = 1, pc2 + mc do
                    local pv = byte(bytecode, bp)
                    if not pv then
                        error("eof")
                    end
                    if pv < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_str(bytecode, bp, pv)
                    end
                end
            elseif ctype == 11 then
                constants[ci] = nil
                const_sidx[ci] = 0
                bp = bp + 32
            else
                broken_const = true
                break
            end
        end

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, set, found, found_n)

        if broken_const then
            if blob_end then
                pos = blob_end
            else
                break
            end
        else
            if bp <= max_end then
                local child_count = byte(bytecode, bp)
                if child_count < 128 then
                    bp = bp + 1
                else
                    child_count, bp = read_varint_tail_str(bytecode, bp, child_count)
                end
                for _ = 1, child_count do
                    local cv = byte(bytecode, bp)
                    if not cv then
                        error("eof")
                    end
                    if cv < 128 then
                        bp = bp + 1
                    else
                        _, bp = read_varint_tail_str(bytecode, bp, cv)
                    end
                end

                local ld = byte(bytecode, bp)
                if not ld then
                    error("eof")
                end
                if ld < 128 then
                    bp = bp + 1
                else
                    _, bp = read_varint_tail_str(bytecode, bp, ld)
                end

                local didx = byte(bytecode, bp)
                if not didx then
                    error("eof")
                end
                if didx < 128 then
                    bp = bp + 1
                else
                    didx, bp = read_varint_tail_str(bytecode, bp, didx)
                end
                if didx >= 1 and didx <= str_count then
                    local dn = strings[didx]
                    if #dn > 0 and band(str_flags[didx], 32) == 0 then
                        str_flags[didx] = str_flags[didx] + 32
                        local fp = "func:" .. dn
                        if not set[fp] then
                            set[fp] = true
                            found_n = found_n + 1
                            found[found_n] = fp
                        end
                    end
                end

                if bp <= max_end then
                    local has_li = byte(bytecode, bp)
                    if has_li == 1 then
                        local linegap = byte(bytecode, bp + 1)
                        if not linegap then
                            if blob_end then
                                bp = max_end + 1
                            else
                                error("eof")
                            end
                        else
                            local intervals = 1
                            if insn_count > 0 and linegap < 32 then
                                intervals = rshift(insn_count - 1, linegap) + 1
                            end
                            bp = bp + 2 + insn_count + intervals * 4
                        end
                    else
                        bp = bp + 1
                    end
                end

                if bp <= max_end then
                    local has_di = byte(bytecode, bp)
                    if has_di == 1 then
                        bp = bp + 1
                        local lc = byte(bytecode, bp)
                        if not lc then
                            error("eof")
                        end
                        if lc < 128 then
                            bp = bp + 1
                        else
                            lc, bp = read_varint_tail_str(bytecode, bp, lc)
                        end
                        for _ = 1, lc do
                            local vidx = byte(bytecode, bp)
                            if not vidx then
                                error("eof")
                            end
                            if vidx < 128 then
                                bp = bp + 1
                            else
                                vidx, bp = read_varint_tail_str(bytecode, bp, vidx)
                            end
                            if vidx >= 1 and vidx <= str_count then
                                local vn = strings[vidx]
                                if #vn > 0 and band(str_flags[vidx], 64) == 0 then
                                    str_flags[vidx] = str_flags[vidx] + 64
                                    local lp = "local:" .. vn
                                    if not set[lp] then
                                        set[lp] = true
                                        found_n = found_n + 1
                                        found[found_n] = lp
                                    end
                                end
                            end
                            local spc = byte(bytecode, bp)
                            if not spc then
                                error("eof")
                            end
                            if spc < 128 then
                                bp = bp + 1
                            else
                                _, bp = read_varint_tail_str(bytecode, bp, spc)
                            end
                            local epc = byte(bytecode, bp)
                            if not epc then
                                error("eof")
                            end
                            if epc < 128 then
                                bp = bp + 2
                            else
                                local np6
                                _, np6 = read_varint_tail_str(bytecode, bp, epc)
                                bp = np6 + 1
                            end
                        end

                        local uc = byte(bytecode, bp)
                        if not uc then
                            error("eof")
                        end
                        if uc < 128 then
                            bp = bp + 1
                        else
                            uc, bp = read_varint_tail_str(bytecode, bp, uc)
                        end
                        for _ = 1, uc do
                            local uidx = byte(bytecode, bp)
                            if not uidx then
                                error("eof")
                            end
                            if uidx < 128 then
                                bp = bp + 1
                            else
                                uidx, bp = read_varint_tail_str(bytecode, bp, uidx)
                            end
                            if uidx >= 1 and uidx <= str_count then
                                local un = strings[uidx]
                                if #un > 0 and band(str_flags[uidx], 128) == 0 then
                                    str_flags[uidx] = str_flags[uidx] + 128
                                    local up = "upval:" .. un
                                    if not set[up] then
                                        set[up] = true
                                        found_n = found_n + 1
                                        found[found_n] = up
                                    end
                                end
                            end
                        end
                    else
                        bp = bp + 1
                    end
                end
            end

            if blob_end then
                pos = blob_end
            else
                if (version >= 11 or version == 100) and bp <= max_end then
                    local fb = byte(bytecode, bp)
                    if fb < 128 then
                        bp = bp + 1
                    else
                        fb, bp = read_varint_tail_str(bytecode, bp, fb)
                    end
                    for _ = 1, fb do
                        bp = bp + 1
                        local fv = byte(bytecode, bp)
                        if not fv then
                            error("eof")
                        end
                        if fv < 128 then
                            bp = bp + 1
                        else
                            _, bp = read_varint_tail_str(bytecode, bp, fv)
                        end
                    end
                end
                pos = bp
            end
        end
    end

    return found_n
end

local parse_and_extract = bfrom and parse_and_extract_buf or parse_and_extract_str

@native
local function char_kind(b)
    if b >= 97 and b <= 122 then
        return 1
    end
    if b >= 65 and b <= 90 then
        return 2
    end
    if b >= 48 and b <= 57 then
        return 0
    end
    return -1
end

@native
local function tokenize_into(s, token_set, token_list, token_n)
    local slen = #s
    if slen == 0 or slen > 4096 then
        return token_n
    end

    local i = 1
    while i <= slen do
        while i <= slen and char_kind(byte(s, i)) < 0 do
            i = i + 1
        end
        if i > slen then
            break
        end

        local seg_start = i
        while i <= slen and char_kind(byte(s, i)) >= 0 do
            i = i + 1
        end
        local seg_end = i - 1

        local whole = slower(sub(s, seg_start, seg_end))
        if not token_set[whole] then
            token_set[whole] = true
            token_n = token_n + 1
            token_list[token_n] = whole
        end

        if seg_end > seg_start then
            local sub_start = seg_start
            local prev_k = char_kind(byte(s, seg_start))
            for j = seg_start + 1, seg_end do
                local k = char_kind(byte(s, j))
                local split = false
                if k == 0 and prev_k ~= 0 then
                    split = true
                elseif k ~= 0 and prev_k == 0 then
                    split = true
                elseif k == 2 then
                    if prev_k == 1 then
                        split = true
                    elseif prev_k == 2 and j < seg_end and char_kind(byte(s, j + 1)) == 1 then
                        split = true
                    end
                end
                if split then
                    local part = slower(sub(s, sub_start, j - 1))
                    if not token_set[part] then
                        token_set[part] = true
                        token_n = token_n + 1
                        token_list[token_n] = part
                    end
                    sub_start = j
                end
                prev_k = k
            end
            if sub_start > seg_start then
                local tail = slower(sub(s, sub_start, seg_end))
                if not token_set[tail] then
                    token_set[tail] = true
                    token_n = token_n + 1
                    token_list[token_n] = tail
                end
            end
        end
    end

    return token_n
end

local function get_tokens(entry)
    local token_set = entry.token_set
    if token_set then
        return token_set
    end

    token_set = {}
    local token_list = {}
    local token_n = 0
    local list = entry.list
    local ln = #list

    for i = 1, ln do
        local pat = list[i]
        local colon = sfind(pat, ":", 1, true)
        local val = colon and sub(pat, colon + 1) or pat
        token_n = tokenize_into(val, token_set, token_list, token_n)
    end

    entry.token_set = token_set
    entry.token_list = token_list
    return token_set
end

local function get_entry(bytecode)
    if type(bytecode) ~= "string" or #bytecode < 2 then
        return false
    end

    local hit = cache[bytecode]
    if hit ~= nil then
        return hit
    end

    local found, set = {}, {}
    local ok, found_n = pcall(parse_and_extract, bytecode, set, found)

    local entry
    if ok and found_n and found_n > 0 then
        entry = {
            list = found,
            set = set,
        }
    else
        entry = false
    end

    cache[bytecode] = entry
    return entry
end

local function list_contains(list, needle)
    for j = 1, #list do
        if sfind(list[j], needle, 1, true) then
            return true
        end
    end
    return false
end

local function entry_contains_fragment(entry, needle, lower_needle)
    if list_contains(entry.list, needle) then
        return true
    end
    if not smatch(needle, "%a") then
        return false
    end
    local lower_list = entry.lower_list
    if not lower_list then
        local list = entry.list
        local n = #list
        lower_list = tcreate and tcreate(n) or {}
        for i = 1, n do
            lower_list[i] = slower(list[i])
        end
        entry.lower_list = lower_list
    end
    return list_contains(lower_list, lower_needle)
end

local function binary_prefix_search(sorted, needle)
    local n = #sorted
    if n == 0 then
        return false
    end

    local lo, hi = 1, n
    while lo < hi do
        local mid = rshift(lo + hi, 1)
        if sorted[mid] < needle then
            lo = mid + 1
        else
            hi = mid
        end
    end

    local cand = sorted[lo]
    local nlen = #needle
    if #cand < nlen then
        return false
    end
    if byte(cand, 1) ~= byte(needle, 1) then
        return false
    end
    if nlen == 1 then
        return true
    end
    if byte(cand, nlen) ~= byte(needle, nlen) then
        return false
    end
    return sub(cand, 1, nlen) == needle
end

local function has_prefix(entry, needle)
    if needle == "" then
        return true
    end
    local sorted = entry.sorted
    if not sorted then
        local list = entry.list
        local ln = #list
        sorted = tcreate and tcreate(ln) or {}
        for i = 1, ln do
            sorted[i] = list[i]
        end
        sort(sorted)
        entry.sorted = sorted
    end
    return binary_prefix_search(sorted, needle)
end

local function has_token_prefix(entry, lower_needle)
    if lower_needle == "" then
        return true
    end
    local sorted = entry.token_sorted
    if not sorted then
        get_tokens(entry)
        local tlist = entry.token_list
        local ln = #tlist
        sorted = tcreate and tcreate(ln) or {}
        for i = 1, ln do
            sorted[i] = tlist[i]
        end
        sort(sorted)
        entry.token_sorted = sorted
    end
    return binary_prefix_search(sorted, lower_needle)
end

local function compile_terms(terms)
    local nterms = #terms
    local exact_needles = {}
    local prefix_needles = {}
    local bare_needles = {}
    local bare_lower = {}
    local bare_prefix_needles = {}
    local bare_prefix_lower = {}
    local frag_needles = {}
    local frag_lower = {}
    local nexact, nprefix, nbare, nbare_prefix, nfrag = 0, 0, 0, 0, 0

    for t = 1, nterms do
        local term = terms[t]
        if type(term) ~= "string" or #term == 0 then
            return nil
        end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            if #needle > 0 then
                nfrag = nfrag + 1
                frag_needles[nfrag] = needle
                frag_lower[nfrag] = slower(needle)
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            if #needle > 0 then
                if sfind(needle, ":", 1, true) then
                    nprefix = nprefix + 1
                    prefix_needles[nprefix] = needle
                else
                    nbare_prefix = nbare_prefix + 1
                    bare_prefix_needles[nbare_prefix] = needle
                    bare_prefix_lower[nbare_prefix] = slower(needle)
                end
            end
        else
            if sfind(term, ":", 1, true) then
                nexact = nexact + 1
                exact_needles[nexact] = term
            else
                nbare = nbare + 1
                bare_needles[nbare] = term
                bare_lower[nbare] = slower(term)
            end
        end
    end

    return exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag
end

local function entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag)
    local set = entry.set
    for t = 1, nexact do
        if not set[exact_needles[t]] then
            return false
        end
    end
    for t = 1, nprefix do
        if not has_prefix(entry, prefix_needles[t]) then
            return false
        end
    end
    if nbare > 0 then
        local tset = get_tokens(entry)
        for t = 1, nbare do
            if not set[bare_needles[t]] and not tset[bare_lower[t]] then
                return false
            end
        end
    end
    for t = 1, nbare_prefix do
        if not has_prefix(entry, bare_prefix_needles[t]) and not has_token_prefix(entry, bare_prefix_lower[t]) then
            return false
        end
    end
    for t = 1, nfrag do
        if not entry_contains_fragment(entry, frag_needles[t], frag_lower[t]) then
            return false
        end
    end
    return true
end

function M.filter(bytecodes, terms)
    local nterms = #terms
    local matches = {}
    local nmatches = 0

    if nterms == 0 then
        for i = 1, #bytecodes do
            local bc = bytecodes[i]
            if type(bc) == "string" and #bc > 0 and get_entry(bc) then
                nmatches = nmatches + 1
                matches[nmatches] = i
            end
        end
        return matches
    end

    if nterms == 1 then
        local term = terms[1]
        if type(term) ~= "string" or #term == 0 then
            return matches
        end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            local non_empty = #needle > 0
            local lneedle = slower(needle)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc > 0 then
                    local entry = get_entry(bc)
                    if entry and (not non_empty or entry_contains_fragment(entry, needle, lneedle)) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            local non_empty = #needle > 0
            if sfind(needle, ":", 1, true) then
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc > 0 then
                        local entry = get_entry(bc)
                        if entry and (not non_empty or has_prefix(entry, needle)) then
                            nmatches = nmatches + 1
                            matches[nmatches] = i
                        end
                    end
                end
            else
                local lneedle = slower(needle)
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc > 0 then
                        local entry = get_entry(bc)
                        if entry and (not non_empty or has_prefix(entry, needle) or has_token_prefix(entry, lneedle)) then
                            nmatches = nmatches + 1
                            matches[nmatches] = i
                        end
                    end
                end
            end
        elseif sfind(term, ":", 1, true) then
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc > 0 then
                    local entry = get_entry(bc)
                    if entry and entry.set[term] then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        else
            local lterm = slower(term)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc > 0 then
                    local entry = get_entry(bc)
                    if entry and (entry.set[term] or get_tokens(entry)[lterm]) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        end

        return matches
    end

    local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local entry = get_entry(bc)
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag) then
                nmatches = nmatches + 1
                matches[nmatches] = i
            end
        end
    end

    return matches
end

function M.filter_async(bytecodes, terms, budget_ms, yield_fn)
    local nterms = #terms
    local matches = {}
    local nmatches = 0
    local yfn = yield_fn or task_wait
    local budget = (budget_ms or 4) * 0.001
    local can_yield = os_clock ~= nil and yfn ~= nil
    local slice_start = can_yield and os_clock() or 0

    if nterms == 0 then
        for i = 1, #bytecodes do
            local bc = bytecodes[i]
            if type(bc) == "string" and #bc > 0 then
                local was_cached = cache[bc] ~= nil
                if get_entry(bc) then
                    nmatches = nmatches + 1
                    matches[nmatches] = i
                end
                if can_yield and (not was_cached or i % 64 == 0) and (os_clock() - slice_start) >= budget then
                    yfn()
                    slice_start = os_clock()
                end
            end
        end
        return matches
    end

    local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local was_cached = cache[bc] ~= nil
            local entry = get_entry(bc)
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, nbare, bare_prefix_needles, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag) then
                nmatches = nmatches + 1
                matches[nmatches] = i
            end
            if can_yield and (not was_cached or i % 64 == 0) and (os_clock() - slice_start) >= budget then
                yfn()
                slice_start = os_clock()
            end
        end
    end

    return matches
end

function M.warmup(bytecodes, budget_ms, yield_fn)
    local yfn = yield_fn or task_wait
    local budget = (budget_ms or 4) * 0.001
    local can_yield = os_clock ~= nil and yfn ~= nil
    local slice_start = can_yield and os_clock() or 0

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 and cache[bc] == nil then
            get_entry(bc)
            if can_yield and (os_clock() - slice_start) >= budget then
                yfn()
                slice_start = os_clock()
            end
        end
    end
end

function M.words(bytecode)
    local entry = get_entry(bytecode)
    return entry and entry.list or false
end

function M.tokens(bytecode)
    local entry = get_entry(bytecode)
    if not entry then
        return false
    end
    get_tokens(entry)
    return entry.token_list
end

function M.clear()
    if tclear then
        tclear(cache)
    else
        cache = {}
    end
end

M.version = "2.6.0"

return M
