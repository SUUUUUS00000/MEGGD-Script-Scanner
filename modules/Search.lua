local M = {}
local cache = {}

local OP_LEN = {
    1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 2, 1, 1, 2,
    2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2,
    2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 1,
    1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 2, 2, 2,
    2, 1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2,
}

local SIMPLE_CLEAR_A = {}
for _, op in ipairs({
    4, 5, 9, 13, 17, 19, 33, 34, 35, 36, 37, 38,
    39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 64, 66, 71, 72, 81, 82, 90, 91,
    93,
}) do
    SIMPLE_CLEAR_A[op + 1] = true
end

local FAST_PATH_OP = {}
for _, op in ipairs({
    0, 1, 4, 5, 9, 10, 11, 13, 14, 17, 18, 19,
    23, 24, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
    37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 53, 54, 55, 62, 64, 65, 66, 67,
    69, 70, 71, 72, 81, 82, 88, 90, 91, 92, 93, 94,
}) do
    FAST_PATH_OP[op + 1] = true
end

local TAG_STRINGS = {
    [1]="return:void",
    [2]="return:value",
    [3]="return:call",
    [4]="return:nil",
    [5]="return:false",
    [6]="return:true",
    [7]="if:then",
    [8]="if:not-then",
    [9]="cond:and",
    [10]="cond:or",
    [11]="cond:not",
    [12]="if:eq",
    [13]="if:ne",
    [14]="if:le",
    [15]="if:lt",
    [16]="if:gt",
    [17]="if:ge",
    [18]="loop:for-num",
    [19]="loop:for-in",
    [20]="loop:for-in-next",
    [21]="loop:for-in-inext",
    [22]="loop:jumpback",
    [23]="function:closure",
    [24]="function:dup",
    [25]="vararg:get",
    [26]="table:new",
    [27]="table:dup",
    [28]="table:setlist",
    [29]="concat",
    [30]="arith:add",
    [31]="arith:sub",
    [32]="arith:mul",
    [33]="arith:div",
    [34]="arith:mod",
    [35]="arith:pow",
    [36]="arith:idiv",
    [37]="arith:length",
    [38]="call:pcall",
    [39]="call:xpcall",
}

local OP_TAG_ID = {}
for op, tid in pairs({
    [19]=23, [24]=22, [27]=12, [28]=14, [29]=15, [30]=13,
    [31]=16, [32]=17, [33]=30, [34]=31, [35]=32, [36]=33,
    [37]=34, [38]=35, [39]=30, [40]=31, [41]=32, [42]=33,
    [43]=34, [44]=35, [45]=9,  [46]=10, [47]=9,  [48]=10,
    [49]=29, [50]=11, [52]=37, [53]=26, [54]=27, [55]=28,
    [64]=24, [71]=31, [72]=33, [81]=36, [82]=36,
}) do
    OP_TAG_ID[op + 1] = tid
end

local BUILTIN_CALLS = {
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
}

local BUILTIN_LIST = { "pcall", "xpcall" }
for id, name in pairs(BUILTIN_CALLS) do
    TAG_STRINGS[100 + id] = "call:" .. name
    BUILTIN_LIST[#BUILTIN_LIST + 1] = name
end

local TAG_ID_BY_NAME = {}
local static_parts = {}
for id, str in pairs(TAG_STRINGS) do
    TAG_ID_BY_NAME[str] = id
    static_parts[#static_parts + 1] = str
end
local STATIC_CI_HAYSTACK = "\0" .. string.lower(table.concat(static_parts, "\0")) .. "\0"

local HINT_TAGS = {
    string = true,
    get = true,
    set = true,
    method = true,
    func = true,
    ["local"] = true,
    upval = true,
    call = true,
    import = true,
}

local ENCODE_OP = {}
local ENCODE_LEN = {}
for i = 0, 255 do
    local dec = (i * 203) % 256
    ENCODE_OP[i + 1] = dec
    ENCODE_LEN[i + 1] = OP_LEN[dec + 1] or 0
end

local byte = string.byte
local sub = string.sub
local slower = string.lower
local concat = table.concat
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

local scratch_str_flags = {}
local scratch_insns = {}
local scratch_constants = {}
local scratch_const_sidx = {}
local scratch_import_gen = {}
local scratch_import_paths = {}
local scratch_import_calls = {}
local scratch_import_sidx = {}
local scratch_reg_call = tcreate and tcreate(256) or {}
local scratch_reg_ret = tcreate and tcreate(256) or {}
local scratch_imp_seen = {}
local scratch_tag_seen = tcreate and tcreate(240, 0) or {}
if not tcreate then
    for i = 1, 240 do
        scratch_tag_seen[i] = 0
    end
end
local scratch_max_reg = 0
local import_gen_counter = 0
local script_gen_counter = 0

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

@native
local function read_u32_array(buf, bp, count, out)
    for i = 1, count do
        out[i] = breadu32(buf, bp)
        bp = bp + 4
    end
    return bp
end

@native
local function skip_local_tail_buf(buf, bp, limit)
    local b = breadu8(buf, bp)
    if b < 128 then
        bp = bp + 1
    else
        _, bp = read_varint_tail_buf(buf, bp, limit, b)
    end
    b = breadu8(buf, bp)
    if b < 128 then
        return bp + 2
    end
    local np
    _, np = read_varint_tail_buf(buf, bp, limit, b)
    return np + 1
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

local function get_str_table_slice(bc)
    local blen = #bc
    if blen < 4 then
        return nil
    end
    local version = byte(bc, 1)
    if not version or version < 3 or (version > 14 and version ~= 100) then
        return nil
    end
    local pos = version >= 4 and 3 or 2
    local str_count = byte(bc, pos)
    if not str_count then
        return nil
    end
    if str_count < 128 then
        pos = pos + 1
    else
        local result = str_count - 128
        local mul = 128
        pos = pos + 1
        while true do
            local b = byte(bc, pos)
            if not b then
                return nil
            end
            pos = pos + 1
            if b < 128 then
                str_count = result + b * mul
                break
            end
            result = result + (b - 128) * mul
            mul = mul * 128
        end
    end
    local str_start = pos
    for _ = 1, str_count do
        local slen = byte(bc, pos)
        if not slen then
            return nil
        end
        if slen < 128 then
            pos = pos + 1 + slen
        else
            local result = slen - 128
            local mul = 128
            pos = pos + 1
            while true do
                local b = byte(bc, pos)
                if not b then
                    return nil
                end
                pos = pos + 1
                if b < 128 then
                    pos = pos + result + b * mul
                    break
                end
                result = result + (b - 128) * mul
                mul = mul * 128
            end
        end
        if pos - 1 > blen then
            return nil
        end
    end
    if pos <= str_start then
        return ""
    end
    return sub(bc, str_start, pos - 1)
end

local function decode_import(constants, const_sidx, const_count, idx1, active_imp_gen)
    if idx1 < 1 or idx1 > const_count then
        return nil, nil, 0
    end

    local import_gen = scratch_import_gen
    local import_paths = scratch_import_paths
    local import_calls = scratch_import_calls
    local import_sidx = scratch_import_sidx

    if import_gen[idx1] == active_imp_gen then
        local cached = import_paths[idx1]
        if not cached then
            return nil, nil, 0
        end
        return cached, import_calls[idx1], import_sidx[idx1]
    end

    import_gen[idx1] = active_imp_gen

    local iid = constants[idx1]
    if type(iid) ~= "number" then
        import_paths[idx1] = false
        return nil, nil, 0
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
    local last_k = 0
    if s1 and s2 and s3 then
        path = s1 .. "." .. s2 .. "." .. s3
        last = s3
        last_k = k3
    elseif s1 and s2 then
        path = s1 .. "." .. s2
        last = s2
        last_k = k2
    elseif s1 and s3 then
        path = s1 .. "." .. s3
        last = s3
        last_k = k3
    elseif s2 and s3 then
        path = s2 .. "." .. s3
        last = s3
        last_k = k3
    else
        path = s1 or s2 or s3
        last = path
        last_k = (s1 and k1) or (s2 and k2) or k3
    end

    if not path then
        import_paths[idx1] = false
        return nil, nil, 0
    end

    local short = smatch(last, "([^.]+)$") or last
    local call_pat = "call:" .. short
    local last_sidx = (short == last and last_k >= 1 and last_k <= const_count) and const_sidx[last_k] or 0

    import_paths[idx1] = path
    import_calls[idx1] = call_pat
    import_sidx[idx1] = last_sidx
    return path, call_pat, last_sidx
end

@native
local function is_valid_stream_detect(insns, n)
    local pc = 1
    local certain_plain = false
    while pc <= n do
        local raw = band(insns[pc], 255)
        local len = OP_LEN[raw + 1]
        if not len or pc + len - 1 > n then
            return false, false
        end
        if not certain_plain and ENCODE_LEN[raw + 1] == 0 then
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
        local len = ENCODE_LEN[band(insns[pc], 255) + 1]
        if len == 0 or pc + len - 1 > n then
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
            top = ENCODE_OP[top + 1]
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
        nop = ENCODE_OP[nop + 1]
    end
    return (nop == 21 or nop == 87) and band(rshift(ninsn, 8), 255) == reg
end

local function extract_proto(insns, total, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, found, found_n)
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
    if scratch_max_reg >= 1 then
        for r = 1, scratch_max_reg do
            reg_call[r] = nil
            reg_ret[r] = nil
        end
    end
    scratch_max_reg = 256

    local active_imp_gen = 0
    if has_imports then
        import_gen_counter = import_gen_counter + 1
        active_imp_gen = import_gen_counter
    end

    local max_reg = 0
    local pc = 1

    while pc <= total do
        local insn = insns[pc]
        local op = band(insn, 255)
        if use_encode then
            op = ENCODE_OP[op + 1]
        end
        local op1 = op + 1
        local len = OP_LEN[op1]
        if not len or pc + len - 1 > total then
            break
        end

        local a = band(rshift(insn, 8), 255)
        local r1 = a + 1

        if FAST_PATH_OP[op1] then
            local tid = OP_TAG_ID[op1]
            if tid and tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
            if SIMPLE_CLEAR_A[op1] then
                reg_call[r1] = nil
                reg_ret[r1] = nil
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
                        found_n = found_n + 1
                        found[found_n] = "get:" .. key
                    end
                end
                reg_call[r1] = sidx
            else
                reg_call[r1] = nil
            end
            reg_ret[r1] = nil
            if r1 > max_reg then
                max_reg = r1
            end
        elseif op == 21 or op == 87 then
            local cp = reg_call[r1]
            if cp then
                if type(cp) == "number" then
                    if band(str_flags[cp], 8) == 0 then
                        str_flags[cp] = str_flags[cp] + 8
                        local cpat = "call:" .. strings[cp]
                        local st_id = TAG_ID_BY_NAME[cpat]
                        if st_id then
                            if tag_seen[st_id] ~= script_gen then
                                tag_seen[st_id] = script_gen
                                found_n = found_n + 1
                                found[found_n] = TAG_STRINGS[st_id]
                            end
                        else
                            found_n = found_n + 1
                            found[found_n] = cpat
                        end
                    end
                else
                    local st_id = TAG_ID_BY_NAME[cp]
                    if st_id then
                        if tag_seen[st_id] ~= script_gen then
                            tag_seen[st_id] = script_gen
                            found_n = found_n + 1
                            found[found_n] = TAG_STRINGS[st_id]
                        end
                    elseif not imp_seen[cp] then
                        imp_seen[cp] = true
                        found_n = found_n + 1
                        found[found_n] = cp
                    end
                end
            end
            local nres = rshift(insn, 24) - 1
            if nres < 0 then
                for r = r1, max_reg do
                    reg_call[r] = nil
                    reg_ret[r] = nil
                end
                reg_ret[r1] = 3
                if r1 > max_reg then
                    max_reg = r1
                end
            elseif nres == 0 then
                reg_call[r1] = nil
                reg_ret[r1] = nil
            else
                local top = a + nres
                for r = r1, top do
                    reg_call[r] = nil
                    reg_ret[r] = 3
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
                    found_n = found_n + 1
                    found[found_n] = "method:" .. key
                end
                if band(fl, 8) == 0 then
                    fl = fl + 8
                    local cpat = "call:" .. key
                    local st_id = TAG_ID_BY_NAME[cpat]
                    if st_id then
                        if tag_seen[st_id] ~= script_gen then
                            tag_seen[st_id] = script_gen
                            found_n = found_n + 1
                            found[found_n] = TAG_STRINGS[st_id]
                        end
                    else
                        found_n = found_n + 1
                        found[found_n] = cpat
                    end
                end
                str_flags[sidx] = fl
                reg_call[r1] = sidx
            else
                reg_call[r1] = nil
            end
            local r2 = r1 + 1
            reg_call[r2] = nil
            reg_ret[r1] = nil
            reg_ret[r2] = nil
            if r2 > max_reg then
                max_reg = r2
            end
        elseif op == 6 then
            local rb = band(rshift(insn, 16), 255) + 1
            reg_call[r1] = reg_call[rb]
            reg_ret[r1] = reg_ret[rb]
            if r1 > max_reg then
                max_reg = r1
            end
        elseif op == 12 then
            local dfield = rshift(insn, 16)
            local path, cpat, last_sidx = decode_import(constants, const_sidx, const_count, dfield + 1, active_imp_gen)
            if path then
                local ipat = "import:" .. path
                if not imp_seen[ipat] then
                    imp_seen[ipat] = true
                    found_n = found_n + 1
                    found[found_n] = ipat
                end
                if not is_call_target(pc, len, a, total, insns, use_encode) then
                    local gpat = "get:" .. path
                    if not imp_seen[gpat] then
                        imp_seen[gpat] = true
                        found_n = found_n + 1
                        found[found_n] = gpat
                    end
                end
                if last_sidx ~= 0 then
                    reg_call[r1] = last_sidx
                else
                    reg_call[r1] = cpat
                end
            else
                reg_call[r1] = nil
            end
            reg_ret[r1] = nil
            if r1 > max_reg then
                max_reg = r1
            end
        elseif op == 16 or op == 8 or op == 84 then
            local aux = insns[pc + 1]
            local idx1 = (op == 84 and band(aux, 65535) or aux) + 1
            local key = idx1 <= const_count and constants[idx1]
            if type(key) == "string" and #key > 0 then
                local sidx = const_sidx[idx1]
                if band(str_flags[sidx], 4) == 0 then
                    str_flags[sidx] = str_flags[sidx] + 4
                    found_n = found_n + 1
                    found[found_n] = "set:" .. key
                end
            end
        elseif op == 22 then
            local b = band(rshift(insn, 16), 255)
            local tid = b == 1 and 1 or (reg_ret[r1] or 2)
            if tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
        elseif op == 26 then
            if is_andor_jump(pc, insn, total, insns, use_encode) then
                if tag_seen[9] ~= script_gen then
                    tag_seen[9] = script_gen
                    found_n = found_n + 1
                    found[found_n] = "cond:and"
                end
            else
                if tag_seen[7] ~= script_gen then
                    tag_seen[7] = script_gen
                    found_n = found_n + 1
                    found[found_n] = "if:then"
                end
                if tag_seen[8] ~= script_gen then
                    tag_seen[8] = script_gen
                    found_n = found_n + 1
                    found[found_n] = "if:not-then"
                end
            end
        elseif op == 25 then
            local tid = is_andor_jump(pc, insn, total, insns, use_encode) and 10 or 7
            if tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
        elseif op == 2 then
            reg_call[r1] = nil
            reg_ret[r1] = 4
            if r1 > max_reg then
                max_reg = r1
            end
        elseif op == 3 then
            local b = band(rshift(insn, 16), 255)
            reg_call[r1] = nil
            reg_ret[r1] = b == 0 and 5 or (b == 1 and 6 or nil)
            if r1 > max_reg then
                max_reg = r1
            end
        elseif op == 68 or op == 73 or op == 74 or op == 75 or op == 60 then
            local tid = 100 + a
            local str = TAG_STRINGS[tid]
            if str and tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = str
            end
        elseif op == 77 or op == 78 or op == 79 or op == 80 then
            local tid = insns[pc + 1] >= 2147483648 and 13 or 12
            if tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
        elseif op == 56 or op == 59 or op == 61 or op == 76 then
            local tid = op == 56 and 18 or (op == 61 and 20 or (op == 59 and 21 or 19))
            if tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
            for r = r1, r1 + 3 do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 57 then
            if tag_seen[18] ~= script_gen then
                tag_seen[18] = script_gen
                found_n = found_n + 1
                found[found_n] = "loop:for-num"
            end
            reg_call[r1 + 2] = nil
            reg_call[r1 + 3] = nil
            reg_ret[r1 + 2] = nil
            reg_ret[r1 + 3] = nil
        elseif op == 58 then
            if tag_seen[19] ~= script_gen then
                tag_seen[19] = script_gen
                found_n = found_n + 1
                found[found_n] = "loop:for-in"
            end
            local top = r1 + 2 + band(insns[pc + 1], 255)
            for r = r1 + 2, top do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 63 then
            if tag_seen[25] ~= script_gen then
                tag_seen[25] = script_gen
                found_n = found_n + 1
                found[found_n] = "vararg:get"
            end
            local b = band(rshift(insn, 16), 255)
            if b == 0 then
                for r = r1, max_reg do
                    reg_call[r] = nil
                    reg_ret[r] = nil
                end
            elseif b >= 2 then
                local top = a + b - 1
                for r = r1, top do
                    reg_call[r] = nil
                    reg_ret[r] = nil
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
                        found_n = found_n + 1
                        found[found_n] = "set:" .. key
                    end
                end
            end
        elseif op == 89 then
            local tid = a == 0 and 38 or (a == 1 and 39 or 0)
            if tid ~= 0 and tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
        end

        pc = pc + len
    end

    scratch_max_reg = max_reg
    return found_n, encoded_mode
end

local function parse_and_extract_buf(bytecode)
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

    local strings = tcreate and tcreate(str_count) or {}
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

    script_gen_counter = script_gen_counter + 1
    local script_gen = script_gen_counter
    local tag_seen = scratch_tag_seen

    local imp_seen = scratch_imp_seen
    if tclear then
        tclear(imp_seen)
    else
        imp_seen = {}
        scratch_imp_seen = imp_seen
    end

    local found = tcreate and tcreate(str_count + 24) or {}
    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local max_const = 0
    local any_imports = false
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

        bp = read_u32_array(buf, bp, insn_count, insns)

        local const_count = breadu8(buf, bp)
        if const_count < 128 then
            bp = bp + 1
        else
            const_count, bp = read_varint_tail_buf(buf, bp, limit, const_count)
        end
        if const_count > max_const then
            max_const = const_count
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
                        found_n = found_n + 1
                        found[found_n] = "string:" .. sv
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
                any_imports = true
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

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, found, found_n)

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
                        found_n = found_n + 1
                        found[found_n] = "func:" .. dn
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
                                    found_n = found_n + 1
                                    found[found_n] = "local:" .. vn
                                end
                            end
                            bp = skip_local_tail_buf(buf, bp, limit)
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
                                    found_n = found_n + 1
                                    found[found_n] = "upval:" .. un
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

    for i = 1, max_const do
        constants[i] = nil
    end
    if any_imports then
        local ipaths = scratch_import_paths
        local icalls = scratch_import_calls
        for i = 1, max_const do
            ipaths[i] = nil
            icalls[i] = nil
        end
    end

    return found_n, found
end

local function parse_and_extract_str(bytecode)
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

    local strings = tcreate and tcreate(str_count) or {}
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

    script_gen_counter = script_gen_counter + 1
    local script_gen = script_gen_counter
    local tag_seen = scratch_tag_seen

    local imp_seen = scratch_imp_seen
    if tclear then
        tclear(imp_seen)
    else
        imp_seen = {}
        scratch_imp_seen = imp_seen
    end

    local found = tcreate and tcreate(str_count + 24) or {}
    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local max_const = 0
    local any_imports = false
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
        if const_count > max_const then
            max_const = const_count
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
                        found_n = found_n + 1
                        found[found_n] = "string:" .. sv
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
                any_imports = true
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

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, found, found_n)

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
                        found_n = found_n + 1
                        found[found_n] = "func:" .. dn
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
                                    found_n = found_n + 1
                                    found[found_n] = "local:" .. vn
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
                                    found_n = found_n + 1
                                    found[found_n] = "upval:" .. un
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

    for i = 1, max_const do
        constants[i] = nil
    end
    if any_imports then
        local ipaths = scratch_import_paths
        local icalls = scratch_import_calls
        for i = 1, max_const do
            ipaths[i] = nil
            icalls[i] = nil
        end
    end

    return found_n, found
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
local function is_token_start(raw_blob, s_pos)
    local prev_b = byte(raw_blob, s_pos - 1)
    if prev_b == 0 then
        local p = s_pos
        local rlen = #raw_blob
        while p <= rlen do
            local ch = byte(raw_blob, p)
            if ch == 0 then
                break
            end
            if ch == 58 then
                return false
            end
            p = p + 1
        end
        return true
    end

    local pk = char_kind(prev_b)
    if pk < 0 then
        return true
    end

    local fk = char_kind(byte(raw_blob, s_pos))
    if fk < 0 then
        return true
    end
    if fk == 2 then
        if pk == 1 or pk == 0 then
            return true
        end
        if pk == 2 and s_pos < #raw_blob and char_kind(byte(raw_blob, s_pos + 1)) == 1 then
            return true
        end
        return false
    end
    if fk == 0 then
        return pk > 0
    end
    return pk == 0
end

@native
local function is_token_end(raw_blob, e_pos)
    local next_b = byte(raw_blob, e_pos + 1)
    local nk = char_kind(next_b)
    if nk < 0 then
        return true
    end

    local lk = char_kind(byte(raw_blob, e_pos))
    if lk < 0 then
        return true
    end
    if nk == 2 then
        if lk == 1 or lk == 0 then
            return true
        end
        if lk == 2 and e_pos + 2 <= #raw_blob and char_kind(byte(raw_blob, e_pos + 2)) == 1 then
            return true
        end
        return false
    end
    if nk == 0 then
        return lk > 0
    end
    return lk == 0
end

local function get_low_blob(entry)
    local low_blob = entry.low_blob
    if not low_blob then
        low_blob = slower(entry.raw_blob)
        entry.low_blob = low_blob
    end
    return low_blob
end

local function has_bare_token(entry, lneedle, nlen)
    local raw_blob = entry.raw_blob
    local low_blob = get_low_blob(entry)
    local pos = sfind(low_blob, lneedle, 1, true)
    while pos do
        if is_token_start(raw_blob, pos) and is_token_end(raw_blob, pos + nlen - 1) then
            return true
        end
        pos = sfind(low_blob, lneedle, pos + 1, true)
    end
    return false
end

local function has_bare_prefix(entry, lneedle)
    local raw_blob = entry.raw_blob
    local low_blob = get_low_blob(entry)
    local pos = sfind(low_blob, lneedle, 1, true)
    while pos do
        if is_token_start(raw_blob, pos) then
            return true
        end
        pos = sfind(low_blob, lneedle, pos + 1, true)
    end
    return false
end

local function has_fragment(entry, needle, lneedle)
    if sfind(entry.raw_blob, needle, 1, true) then
        return true
    end
    if not smatch(needle, "%a") then
        return false
    end
    return sfind(get_low_blob(entry), lneedle, 1, true) ~= nil
end

local function parse_and_cache(bytecode)
    local ok, found_n, found = pcall(parse_and_extract, bytecode)

    local entry
    if ok and found_n and found_n > 0 then
        entry = {
            list = found,
            raw_blob = "\0" .. concat(found, "\0") .. "\0",
        }
    else
        entry = false
    end

    cache[bytecode] = entry
    return entry
end

local function get_entry(bytecode)
    if type(bytecode) ~= "string" or #bytecode < 2 then
        return false
    end

    local hit = cache[bytecode]
    if hit ~= nil then
        return hit
    end

    return parse_and_cache(bytecode)
end

local function longest_dot_segment(val)
    local best = nil
    local best_len = 0
    local start = 1
    local vlen = #val
    while start <= vlen do
        local dot = sfind(val, ".", start, true)
        local seg_end = dot and (dot - 1) or vlen
        local seg_len = seg_end - start + 1
        if seg_len > best_len then
            best_len = seg_len
            best = sub(val, start, seg_end)
        end
        if not dot then
            break
        end
        start = dot + 1
    end
    return best
end

local function matches_builtin_prefix(val)
    local vlen = #val
    for i = 1, #BUILTIN_LIST do
        local bn = BUILTIN_LIST[i]
        if #bn >= vlen and sub(bn, 1, vlen) == val then
            return true
        end
    end
    return false
end

local function extract_cold_hint(term, is_prefix)
    local colon = sfind(term, ":", 1, true)
    if not colon then
        return nil
    end
    local tag = sub(term, 1, colon - 1)
    if not HINT_TAGS[tag] then
        return nil
    end
    local val = sub(term, colon + 1)
    if #val == 0 then
        return nil
    end
    if tag == "call" then
        if is_prefix then
            if matches_builtin_prefix(val) then
                return nil
            end
            return val
        end
        if TAG_ID_BY_NAME[term] then
            return nil
        end
        return val
    end
    if tag == "import" or tag == "get" then
        if sfind(val, ".", 1, true) then
            if is_prefix then
                return nil
            end
            return longest_dot_segment(val)
        end
        return val
    end
    return val
end

local function extract_cold_ci_hint(lneedle)
    if #lneedle == 0 then
        return nil
    end
    if sfind(STATIC_CI_HAYSTACK, lneedle, 1, true) then
        return nil
    end
    return lneedle
end

local function passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci)
    for h = 1, nhints do
        if not sfind(bc, cold_hints[h], 1, true) then
            return true, false
        end
    end
    if nci > 0 then
        local hdr = get_str_table_slice(bc)
        if not hdr then
            cache[bc] = false
            return false, false
        end
        local low_hdr = slower(hdr)
        for h = 1, nci do
            if not sfind(low_hdr, cold_ci_hints[h], 1, true) then
                return true, false
            end
        end
    end
    return true, true
end

local function compile_terms(terms)
    local nterms = #terms
    local exact_needles = {}
    local prefix_needles = {}
    local bare_needles = {}
    local bare_lower = {}
    local bare_len = {}
    local bare_prefix_lower = {}
    local frag_needles = {}
    local frag_lower = {}
    local cold_hints = {}
    local cold_ci_hints = {}
    local nexact, nprefix, nbare, nbare_prefix, nfrag, nhints, nci = 0, 0, 0, 0, 0, 0, 0

    for t = 1, nterms do
        local term = terms[t]
        if type(term) ~= "string" or #term == 0 then
            return nil
        end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            if #needle > 0 then
                local lneedle = slower(needle)
                nfrag = nfrag + 1
                frag_needles[nfrag] = needle
                frag_lower[nfrag] = lneedle
                local ch = extract_cold_ci_hint(lneedle)
                if ch then
                    nci = nci + 1
                    cold_ci_hints[nci] = ch
                end
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            if #needle > 0 then
                if sfind(needle, ":", 1, true) then
                    nprefix = nprefix + 1
                    prefix_needles[nprefix] = "\0" .. needle
                    local hint = extract_cold_hint(needle, true)
                    if hint then
                        nhints = nhints + 1
                        cold_hints[nhints] = hint
                    end
                else
                    local lneedle = slower(needle)
                    nbare_prefix = nbare_prefix + 1
                    bare_prefix_lower[nbare_prefix] = lneedle
                    local ch = extract_cold_ci_hint(lneedle)
                    if ch then
                        nci = nci + 1
                        cold_ci_hints[nci] = ch
                    end
                end
            end
        else
            if sfind(term, ":", 1, true) then
                nexact = nexact + 1
                exact_needles[nexact] = "\0" .. term .. "\0"
                local hint = extract_cold_hint(term, false)
                if hint then
                    nhints = nhints + 1
                    cold_hints[nhints] = hint
                end
            else
                local lterm = slower(term)
                nbare = nbare + 1
                bare_needles[nbare] = "\0" .. term .. "\0"
                bare_lower[nbare] = lterm
                bare_len[nbare] = #term
                local ch = extract_cold_ci_hint(lterm)
                if ch then
                    nci = nci + 1
                    cold_ci_hints[nci] = ch
                end
            end
        end
    end

    return exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag, cold_hints, nhints, cold_ci_hints, nci
end

local function entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag)
    local raw_blob = entry.raw_blob
    for t = 1, nexact do
        if not sfind(raw_blob, exact_needles[t], 1, true) then
            return false
        end
    end
    for t = 1, nprefix do
        if not sfind(raw_blob, prefix_needles[t], 1, true) then
            return false
        end
    end
    for t = 1, nbare do
        if not sfind(raw_blob, bare_needles[t], 1, true) and not has_bare_token(entry, bare_lower[t], bare_len[t]) then
            return false
        end
    end
    for t = 1, nbare_prefix do
        if not has_bare_prefix(entry, bare_prefix_lower[t]) then
            return false
        end
    end
    for t = 1, nfrag do
        if not has_fragment(entry, frag_needles[t], frag_lower[t]) then
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
            if type(bc) == "string" and #bc >= 2 and get_entry(bc) then
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
            local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil then
                        if ci_hint then
                            local hdr = get_str_table_slice(bc)
                            if not hdr then
                                cache[bc] = false
                            elseif sfind(slower(hdr), ci_hint, 1, true) then
                                entry = parse_and_cache(bc)
                            end
                        else
                            entry = parse_and_cache(bc)
                        end
                    end
                    if entry and (not non_empty or has_fragment(entry, needle, lneedle)) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            local non_empty = #needle > 0
            if sfind(needle, ":", 1, true) then
                local pneedle = "\0" .. needle
                local hint = extract_cold_hint(needle, true)
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc >= 2 then
                        local entry = cache[bc]
                        if entry == nil then
                            if not hint or sfind(bc, hint, 1, true) then
                                entry = parse_and_cache(bc)
                            end
                        end
                        if entry and (not non_empty or sfind(entry.raw_blob, pneedle, 1, true) ~= nil) then
                            nmatches = nmatches + 1
                            matches[nmatches] = i
                        end
                    end
                end
            else
                local lneedle = slower(needle)
                local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc >= 2 then
                        local entry = cache[bc]
                        if entry == nil then
                            if ci_hint then
                                local hdr = get_str_table_slice(bc)
                                if not hdr then
                                    cache[bc] = false
                                elseif sfind(slower(hdr), ci_hint, 1, true) then
                                    entry = parse_and_cache(bc)
                                end
                            else
                                entry = parse_and_cache(bc)
                            end
                        end
                        if entry and (not non_empty or has_bare_prefix(entry, lneedle)) then
                            nmatches = nmatches + 1
                            matches[nmatches] = i
                        end
                    end
                end
            end
        elseif sfind(term, ":", 1, true) then
            local eneedle = "\0" .. term .. "\0"
            local hint = extract_cold_hint(term, false)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil then
                        if not hint or sfind(bc, hint, 1, true) then
                            entry = parse_and_cache(bc)
                        end
                    end
                    if entry and sfind(entry.raw_blob, eneedle, 1, true) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        else
            local eneedle = "\0" .. term .. "\0"
            local lterm = slower(term)
            local tlen = #term
            local ci_hint = extract_cold_ci_hint(lterm)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil then
                        if ci_hint then
                            local hdr = get_str_table_slice(bc)
                            if not hdr then
                                cache[bc] = false
                            elseif sfind(slower(hdr), ci_hint, 1, true) then
                                entry = parse_and_cache(bc)
                            end
                        else
                            entry = parse_and_cache(bc)
                        end
                    end
                    if entry and (sfind(entry.raw_blob, eneedle, 1, true) or has_bare_token(entry, lterm, tlen)) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        end

        return matches
    end

    local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag, cold_hints, nhints, cold_ci_hints, nci = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            if entry == nil then
                local _, possible = passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci)
                if possible then
                    entry = parse_and_cache(bc)
                end
            end
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag) then
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
            if type(bc) == "string" and #bc >= 2 then
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

    local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag, cold_hints, nhints, cold_ci_hints, nci = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            local did_parse = false
            if entry == nil then
                local _, possible = passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci)
                if possible then
                    entry = parse_and_cache(bc)
                    did_parse = true
                end
            end
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag) then
                nmatches = nmatches + 1
                matches[nmatches] = i
            end
            if can_yield and (did_parse or i % 64 == 0) and (os_clock() - slice_start) >= budget then
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
        if type(bc) == "string" and #bc >= 2 and cache[bc] == nil then
            parse_and_cache(bc)
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

    local token_list = entry.token_list
    if token_list then
        return token_list
    end

    local token_set = {}
    token_list = {}
    local token_n = 0
    local list = entry.list

    for i = 1, #list do
        local pat = list[i]
        local colon = sfind(pat, ":", 1, true)
        local val = colon and sub(pat, colon + 1) or pat
        local vlen = #val
        if vlen > 0 and vlen <= 4096 then
            local idx = 1
            while idx <= vlen do
                while idx <= vlen and char_kind(byte(val, idx)) < 0 do
                    idx = idx + 1
                end
                if idx > vlen then
                    break
                end
                local seg_start = idx
                while idx <= vlen and char_kind(byte(val, idx)) >= 0 do
                    idx = idx + 1
                end
                local seg_end = idx - 1
                local whole = slower(sub(val, seg_start, seg_end))
                if not token_set[whole] then
                    token_set[whole] = true
                    token_n = token_n + 1
                    token_list[token_n] = whole
                end
                if seg_end > seg_start then
                    local sub_start = seg_start
                    local prev_k = char_kind(byte(val, seg_start))
                    for j = seg_start + 1, seg_end do
                        local k = char_kind(byte(val, j))
                        local split = false
                        if k == 0 and prev_k ~= 0 then
                            split = true
                        elseif k ~= 0 and prev_k == 0 then
                            split = true
                        elseif k == 2 then
                            if prev_k == 1 then
                                split = true
                            elseif prev_k == 2 and j < seg_end and char_kind(byte(val, j + 1)) == 1 then
                                split = true
                            end
                        end
                        if split then
                            local part = slower(sub(val, sub_start, j - 1))
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
                        local tail = slower(sub(val, sub_start, seg_end))
                        if not token_set[tail] then
                            token_set[tail] = true
                            token_n = token_n + 1
                            token_list[token_n] = tail
                        end
                    end
                end
            end
        end
    end

    entry.token_list = token_list
    return token_list
end

function M.clear()
    if tclear then
        tclear(cache)
    else
        cache = {}
    end
end

M.version = "2.9.0"

return M
