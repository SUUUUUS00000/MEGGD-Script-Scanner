local M = {}
local cache = {}
local hdr_cache = {}

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
    [1]="return:void", [2]="return:value", [3]="return:call",
    [4]="return:nil", [5]="return:false", [6]="return:true",
    [7]="if:then", [8]="if:not-then", [9]="cond:and",
    [10]="cond:or", [11]="cond:not", [12]="if:eq",
    [13]="if:ne", [14]="if:le", [15]="if:lt",
    [16]="if:gt", [17]="if:ge", [18]="loop:for-num",
    [19]="loop:for-in", [20]="loop:for-in-next", [21]="loop:for-in-inext",
    [22]="loop:jumpback", [23]="function:closure", [24]="function:dup",
    [25]="vararg:get", [26]="table:new", [27]="table:dup",
    [28]="table:setlist", [29]="concat", [30]="arith:add",
    [31]="arith:sub", [32]="arith:mul", [33]="arith:div",
    [34]="arith:mod", [35]="arith:pow", [36]="arith:idiv",
    [37]="arith:length", [38]="call:pcall", [39]="call:xpcall",
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
    string = true, get = true, set = true, method = true,
    func = true, ["local"] = true, upval = true, call = true, import = true,
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

local os_clock = os and os.clock
local task_wait = task and task.wait

local scratch_str_flags = {}
local scratch_constants = {}
local scratch_const_sidx = {}
local scratch_import_gen = {}
local scratch_import_paths = {}
local scratch_import_calls = {}
local scratch_import_sidx = {}
local scratch_reg_call = tcreate(256)
local scratch_reg_ret = tcreate(256)
local scratch_imp_seen = {}
local scratch_tag_seen = tcreate(240, 0)
local scratch_max_reg = 0
local import_gen_counter = 0
local script_gen_counter = 0

local function get_str_table_slice(bc)
    local sbyte = string.byte
    local blen = #bc
    if blen < 4 then return nil end
    local version = sbyte(bc, 1)
    if not version or version < 3 or (version > 14 and version ~= 100) then return nil end
    local pos = version >= 4 and 3 or 2
    local str_count = sbyte(bc, pos)
    if not str_count then return nil end
    if str_count < 128 then
        pos = pos + 1
    else
        local result, mul = str_count - 128, 128
        pos = pos + 1
        while true do
            local b = sbyte(bc, pos)
            if not b then return nil end
            pos = pos + 1
            if b < 128 then str_count = result + b * mul; break end
            result = result + (b - 128) * mul
            mul = mul * 128
        end
    end
    local str_start = pos
    local rem = str_count
    while rem >= 4 do
        local s1 = sbyte(bc, pos)
        if not s1 or s1 >= 128 then break end
        local p2 = pos + 1 + s1
        local s2 = sbyte(bc, p2)
        if not s2 or s2 >= 128 then pos = p2; rem = rem - 1; break end
        local p3 = p2 + 1 + s2
        local s3 = sbyte(bc, p3)
        if not s3 or s3 >= 128 then pos = p3; rem = rem - 2; break end
        local p4 = p3 + 1 + s3
        local s4 = sbyte(bc, p4)
        if not s4 or s4 >= 128 then pos = p4; rem = rem - 3; break end
        pos = p4 + 1 + s4
        rem = rem - 4
    end
    while rem > 0 do
        local slen = sbyte(bc, pos)
        if not slen then return nil end
        if slen < 128 then
            pos = pos + 1 + slen
        else
            local result, mul = slen - 128, 128
            pos = pos + 1
            while true do
                local b = sbyte(bc, pos)
                if not b then return nil end
                pos = pos + 1
                if b < 128 then pos = pos + result + b * mul; break end
                result = result + (b - 128) * mul
                mul = mul * 128
            end
        end
        rem = rem - 1
    end
    if pos - 1 > blen then return nil end
    if pos <= str_start then return "" end
    return string.sub(bc, str_start, pos - 1)
end

local function decode_import(constants, const_sidx, const_count, strings, idx1, active_imp_gen)
    if idx1 < 1 or idx1 > const_count or const_sidx[idx1] ~= -1 then return nil, nil, 0 end
    local import_gen = scratch_import_gen
    local import_paths = scratch_import_paths
    local import_calls = scratch_import_calls
    local import_sidx = scratch_import_sidx
    if import_gen[idx1] == active_imp_gen then
        local cached = import_paths[idx1]
        if not cached then return nil, nil, 0 end
        return cached, import_calls[idx1], import_sidx[idx1]
    end
    import_gen[idx1] = active_imp_gen
    local iid = constants[idx1]
    local cnt = rshift(iid, 30)
    local k1 = cnt >= 1 and band(rshift(iid, 20), 1023) + 1 or 0
    local k2 = cnt >= 2 and band(rshift(iid, 10), 1023) + 1 or 0
    local k3 = cnt >= 3 and band(iid, 1023) + 1 or 0
    local idx_s1 = (k1 >= 1 and k1 <= const_count) and const_sidx[k1] or 0
    local idx_s2 = (k2 >= 1 and k2 <= const_count) and const_sidx[k2] or 0
    local idx_s3 = (k3 >= 1 and k3 <= const_count) and const_sidx[k3] or 0
    local s1 = idx_s1 > 0 and strings[idx_s1] or nil
    local s2 = idx_s2 > 0 and strings[idx_s2] or nil
    local s3 = idx_s3 > 0 and strings[idx_s3] or nil
    local path, last, last_k
    if s1 and s2 and s3 then
        path, last, last_k = s1 .. "." .. s2 .. "." .. s3, s3, idx_s3
    elseif s1 and s2 then
        path, last, last_k = s1 .. "." .. s2, s2, idx_s2
    elseif s1 and s3 then
        path, last, last_k = s1 .. "." .. s3, s3, idx_s3
    elseif s2 and s3 then
        path, last, last_k = s2 .. "." .. s3, s3, idx_s3
    else
        path = s1 or s2 or s3
        last = path
        last_k = (s1 and idx_s1) or (s2 and idx_s2) or idx_s3
    end
    if not path then import_paths[idx1] = false; return nil, nil, 0 end
    local short = smatch(last, "([^.]+)$") or last
    local call_pat = "call:" .. short
    local last_sidx = short == last and last_k or 0
    import_paths[idx1], import_calls[idx1], import_sidx[idx1] = path, call_pat, last_sidx
    return path, call_pat, last_sidx
end

@native
local function read_varint_tail_buf(buf, pos, len, b0)
    local result, mul = b0 - 128, 128
    pos = pos + 1
    while true do
        if pos >= len then error("eof") end
        local b = buffer.readu8(buf, pos)
        pos = pos + 1
        if b < 128 then return result + b * mul, pos end
        result = result + (b - 128) * mul
        mul = mul * 128
    end
end

@native
local function skip_local_tail_buf(buf, bp, limit)
    if bp >= limit then error("eof") end
    local b = buffer.readu8(buf, bp)
    if b < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, b) end
    if bp >= limit then error("eof") end
    b = buffer.readu8(buf, bp)
    if b < 128 then return bp + 2 end
    local np
    _, np = read_varint_tail_buf(buf, bp, limit, b)
    return np + 1
end

@native
local function is_valid_stream_detect_buf(buf, insn_base, insn_end)
    local off, certain_plain = insn_base, false
    while off < insn_end do
        local raw = buffer.readu8(buf, off)
        local len = OP_LEN[raw + 1]
        if not len then return false, false end
        local nxt = off + len * 4
        if nxt > insn_end then return false, false end
        if not certain_plain and ENCODE_LEN[raw + 1] == 0 then certain_plain = true end
        off = nxt
    end
    return true, certain_plain
end

@native
local function is_valid_stream_true_buf(buf, insn_base, insn_end)
    local off = insn_base
    while off < insn_end do
        local len = ENCODE_LEN[buffer.readu8(buf, off) + 1]
        if len == 0 then return false end
        local nxt = off + len * 4
        if nxt > insn_end then return false end
        off = nxt
    end
    return true
end

@native
local function is_andor_jump_buf(buf, off, insn_base, insn_end, use_encode)
    local d = buffer.readi16(buf, off + 2)
    local target_off = off + 4 + d * 4
    if target_off >= insn_base and target_off < insn_end then
        local top = buffer.readu8(buf, target_off)
        if use_encode then top = ENCODE_OP[top + 1] end
        if top == 3 then return buffer.readu8(buf, target_off + 3) ~= 0 end
        if top == 6 then return true end
    end
    return false
end

@native
local function is_call_target_buf(buf, off, len, reg, insn_end, use_encode)
    local nxt_off = off + len * 4
    if nxt_off >= insn_end then return false end
    local nop = buffer.readu8(buf, nxt_off)
    if use_encode then nop = ENCODE_OP[nop + 1] end
    return (nop == 21 or nop == 87) and buffer.readu8(buf, nxt_off + 1) == reg
end

local function extract_proto_buf(buf, insn_base, insn_end, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, found, found_n)
    if insn_base >= insn_end then return found_n, encoded_mode end

    local breadu8 = buffer.readu8
    local breadu16 = buffer.readu16
    local breadu32 = buffer.readu32
    local band_fn = bit32.band

    local use_encode
    if encoded_mode == true then
        use_encode = true
    elseif encoded_mode == false then
        use_encode = false
    else
        local valid, certain_plain = is_valid_stream_detect_buf(buf, insn_base, insn_end)
        if valid then
            use_encode = false
            if certain_plain then encoded_mode = false end
        elseif is_valid_stream_true_buf(buf, insn_base, insn_end) then
            use_encode = true
            encoded_mode = true
        else
            return found_n, encoded_mode
        end
    end

    local reg_call, reg_ret = scratch_reg_call, scratch_reg_ret
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
    local off = insn_base

    while off < insn_end do
        local op = breadu8(buf, off)
        if use_encode then op = ENCODE_OP[op + 1] end
        local op1 = op + 1
        local len = OP_LEN[op1]
        if not len then break end
        local nxt_off = off + len * 4
        if nxt_off > insn_end then break end

        if FAST_PATH_OP[op1] then
            local tid = OP_TAG_ID[op1]
            if tid and tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
            if SIMPLE_CLEAR_A[op1] then
                local r1 = breadu8(buf, off + 1) + 1
                reg_call[r1] = nil
                reg_ret[r1] = nil
            end
        elseif op == 15 or op == 7 or op == 83 then
            local a = breadu8(buf, off + 1)
            local r1 = a + 1
            local idx1 = (op == 83 and breadu16(buf, off + 4) or breadu32(buf, off + 4)) + 1
            local sidx = idx1 <= const_count and const_sidx[idx1] or 0
            if sidx > 0 then
                local key = strings[sidx]
                if #key > 0 then
                    if not is_call_target_buf(buf, off, len, a, insn_end, use_encode) and band_fn(str_flags[sidx], 2) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 2
                        found_n = found_n + 1
                        found[found_n] = "get:" .. key
                    end
                    reg_call[r1] = sidx
                else
                    reg_call[r1] = nil
                end
            else
                reg_call[r1] = nil
            end
            reg_ret[r1] = nil
            if r1 > max_reg then max_reg = r1 end
        elseif op == 21 or op == 87 then
            local a = breadu8(buf, off + 1)
            local r1 = a + 1
            local cp = reg_call[r1]
            if cp then
                if type(cp) == "number" then
                    if band_fn(str_flags[cp], 8) == 0 then
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
            local nres = breadu8(buf, off + 3) - 1
            if nres < 0 then
                for r = r1, max_reg do reg_call[r] = nil; reg_ret[r] = nil end
                reg_ret[r1] = 3
                if r1 > max_reg then max_reg = r1 end
            elseif nres == 0 then
                reg_call[r1] = nil
                reg_ret[r1] = nil
            else
                local top = a + nres
                for r = r1, top do reg_call[r] = nil; reg_ret[r] = 3 end
                if top > max_reg then max_reg = top end
            end
        elseif op == 20 or op == 85 then
            local r1 = breadu8(buf, off + 1) + 1
            local idx1 = (op == 20 and breadu32(buf, off + 4) or breadu16(buf, off + 4)) + 1
            local sidx = idx1 <= const_count and const_sidx[idx1] or 0
            if sidx > 0 then
                local key = strings[sidx]
                if #key > 0 then
                    local fl = str_flags[sidx]
                    if band_fn(fl, 16) == 0 then
                        fl = fl + 16
                        found_n = found_n + 1
                        found[found_n] = "method:" .. key
                    end
                    if band_fn(fl, 8) == 0 then
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
            else
                reg_call[r1] = nil
            end
            local r2 = r1 + 1
            reg_call[r2] = nil
            reg_ret[r1] = nil
            reg_ret[r2] = nil
            if r2 > max_reg then max_reg = r2 end
        elseif op == 6 then
            local r1 = breadu8(buf, off + 1) + 1
            local rb = breadu8(buf, off + 2) + 1
            reg_call[r1] = reg_call[rb]
            reg_ret[r1] = reg_ret[rb]
            if r1 > max_reg then max_reg = r1 end
        elseif op == 12 then
            local a = breadu8(buf, off + 1)
            local r1 = a + 1
            local dfield = breadu16(buf, off + 2)
            local path, cpat, last_sidx = decode_import(constants, const_sidx, const_count, strings, dfield + 1, active_imp_gen)
            if path then
                local ipat = "import:" .. path
                if not imp_seen[ipat] then
                    imp_seen[ipat] = true
                    found_n = found_n + 1
                    found[found_n] = ipat
                end
                if not is_call_target_buf(buf, off, len, a, insn_end, use_encode) then
                    local gpat = "get:" .. path
                    if not imp_seen[gpat] then
                        imp_seen[gpat] = true
                        found_n = found_n + 1
                        found[found_n] = gpat
                    end
                end
                reg_call[r1] = last_sidx ~= 0 and last_sidx or cpat
            else
                reg_call[r1] = nil
            end
            reg_ret[r1] = nil
            if r1 > max_reg then max_reg = r1 end
        elseif op == 16 or op == 8 or op == 84 then
            local idx1 = (op == 84 and breadu16(buf, off + 4) or breadu32(buf, off + 4)) + 1
            local sidx = idx1 <= const_count and const_sidx[idx1] or 0
            if sidx > 0 then
                local key = strings[sidx]
                if #key > 0 and band_fn(str_flags[sidx], 4) == 0 then
                    str_flags[sidx] = str_flags[sidx] + 4
                    found_n = found_n + 1
                    found[found_n] = "set:" .. key
                end
            end
        elseif op == 22 then
            local b = breadu8(buf, off + 2)
            local tid = b == 1 and 1 or (reg_ret[breadu8(buf, off + 1) + 1] or 2)
            if tag_seen[tid] ~= script_gen then
                tag_seen[tid] = script_gen
                found_n = found_n + 1
                found[found_n] = TAG_STRINGS[tid]
            end
        elseif op == 26 then
            if is_andor_jump_buf(buf, off, insn_base, insn_end, use_encode) then
                if tag_seen[9] ~= script_gen then tag_seen[9] = script_gen; found_n = found_n + 1; found[found_n] = "cond:and" end
            else
                if tag_seen[7] ~= script_gen then tag_seen[7] = script_gen; found_n = found_n + 1; found[found_n] = "if:then" end
                if tag_seen[8] ~= script_gen then tag_seen[8] = script_gen; found_n = found_n + 1; found[found_n] = "if:not-then" end
            end
        elseif op == 25 then
            local tid = is_andor_jump_buf(buf, off, insn_base, insn_end, use_encode) and 10 or 7
            if tag_seen[tid] ~= script_gen then tag_seen[tid] = script_gen; found_n = found_n + 1; found[found_n] = TAG_STRINGS[tid] end
        elseif op == 2 then
            local r1 = breadu8(buf, off + 1) + 1
            reg_call[r1] = nil
            reg_ret[r1] = 4
            if r1 > max_reg then max_reg = r1 end
        elseif op == 3 then
            local r1 = breadu8(buf, off + 1) + 1
            local b = breadu8(buf, off + 2)
            reg_call[r1] = nil
            reg_ret[r1] = b == 0 and 5 or (b == 1 and 6 or nil)
            if r1 > max_reg then max_reg = r1 end
        elseif op == 68 or op == 73 or op == 74 or op == 75 or op == 60 then
            local tid = 100 + breadu8(buf, off + 1)
            local str = TAG_STRINGS[tid]
            if str and tag_seen[tid] ~= script_gen then tag_seen[tid] = script_gen; found_n = found_n + 1; found[found_n] = str end
        elseif op == 77 or op == 78 or op == 79 or op == 80 then
            local tid = breadu8(buf, off + 7) >= 128 and 13 or 12
            if tag_seen[tid] ~= script_gen then tag_seen[tid] = script_gen; found_n = found_n + 1; found[found_n] = TAG_STRINGS[tid] end
        elseif op == 56 or op == 59 or op == 61 or op == 76 then
            local r1 = breadu8(buf, off + 1) + 1
            local tid = op == 56 and 18 or (op == 61 and 20 or (op == 59 and 21 or 19))
            if tag_seen[tid] ~= script_gen then tag_seen[tid] = script_gen; found_n = found_n + 1; found[found_n] = TAG_STRINGS[tid] end
            for r = r1, r1 + 3 do reg_call[r] = nil; reg_ret[r] = nil end
        elseif op == 57 then
            local r1 = breadu8(buf, off + 1) + 1
            if tag_seen[18] ~= script_gen then tag_seen[18] = script_gen; found_n = found_n + 1; found[found_n] = "loop:for-num" end
            reg_call[r1 + 2] = nil; reg_call[r1 + 3] = nil
            reg_ret[r1 + 2] = nil; reg_ret[r1 + 3] = nil
        elseif op == 58 then
            local r1 = breadu8(buf, off + 1) + 1
            if tag_seen[19] ~= script_gen then tag_seen[19] = script_gen; found_n = found_n + 1; found[found_n] = "loop:for-in" end
            local top = r1 + 2 + breadu8(buf, off + 4)
            for r = r1 + 2, top do reg_call[r] = nil; reg_ret[r] = nil end
        elseif op == 63 then
            local a = breadu8(buf, off + 1)
            local r1 = a + 1
            if tag_seen[25] ~= script_gen then tag_seen[25] = script_gen; found_n = found_n + 1; found[found_n] = "vararg:get" end
            local b = breadu8(buf, off + 2)
            if b == 0 then
                for r = r1, max_reg do reg_call[r] = nil; reg_ret[r] = nil end
            elseif b >= 2 then
                local top = a + b - 1
                for r = r1, top do reg_call[r] = nil; reg_ret[r] = nil end
            end
        elseif op == 86 then
            if breadu8(buf, off + 2) == 0 then
                local idx1 = breadu32(buf, off + 4) + 1
                local sidx = idx1 <= const_count and const_sidx[idx1] or 0
                if sidx > 0 then
                    local key = strings[sidx]
                    if #key > 0 and band_fn(str_flags[sidx], 4) == 0 then
                        str_flags[sidx] = str_flags[sidx] + 4
                        found_n = found_n + 1
                        found[found_n] = "set:" .. key
                    end
                end
            end
        elseif op == 89 then
            local a = breadu8(buf, off + 1)
            local tid = a == 0 and 38 or (a == 1 and 39 or 0)
            if tid ~= 0 and tag_seen[tid] ~= script_gen then tag_seen[tid] = script_gen; found_n = found_n + 1; found[found_n] = TAG_STRINGS[tid] end
        end

        off = nxt_off
    end

    scratch_max_reg = max_reg
    return found_n, encoded_mode
end

local function parse_and_extract(bytecode)
    local bfrom = buffer.fromstring
    local breadu8 = buffer.readu8
    local breadu32 = buffer.readu32
    local breadstring = buffer.readstring
    local band_fn = bit32.band
    local rshift_fn = bit32.rshift
    local tcreate_fn = table.create

    local blen = #bytecode
    local buf = bfrom(bytecode)
    local pos = 0

    local version = breadu8(buf, pos)
    pos = pos + 1
    if version < 3 or (version > 14 and version ~= 100) then error("bad version") end

    local typesversion = 0
    if version >= 4 then
        typesversion = breadu8(buf, pos)
        pos = pos + 1
    end

    local str_count = breadu8(buf, pos)
    if str_count < 128 then pos = pos + 1 else str_count, pos = read_varint_tail_buf(buf, pos, blen, str_count) end

    local strings = tcreate_fn(str_count)
    local str_flags = scratch_str_flags
    for i = 1, str_count do
        local slen = breadu8(buf, pos)
        if slen < 128 then pos = pos + 1 else slen, pos = read_varint_tail_buf(buf, pos, blen, slen) end
        if pos + slen > blen then error("eof") end
        strings[i] = breadstring(buf, pos, slen)
        str_flags[i] = 0
        pos = pos + slen
    end

    if typesversion == 3 then
        while true do
            if pos >= blen then error("eof") end
            local tag = breadu8(buf, pos)
            pos = pos + 1
            if tag == 0 then break end
            local tv = breadu8(buf, pos)
            if tv < 128 then pos = pos + 1 else _, pos = read_varint_tail_buf(buf, pos, blen, tv) end
        end
    end

    local proto_count = breadu8(buf, pos)
    if proto_count < 128 then pos = pos + 1 else proto_count, pos = read_varint_tail_buf(buf, pos, blen, proto_count) end

    script_gen_counter = script_gen_counter + 1
    local script_gen = script_gen_counter
    local tag_seen = scratch_tag_seen
    local imp_seen = scratch_imp_seen
    tclear(imp_seen)

    local found = tcreate_fn(str_count + 24)
    local has_size = version >= 12 or version == 100
    local found_n, encoded_mode, max_const, any_imports = 0, nil, 0, false
    local constants, const_sidx = scratch_constants, scratch_const_sidx

    for _ = 1, proto_count do
        local blob_end
        if has_size then
            local sz = breadu8(buf, pos)
            if sz < 128 then pos = pos + 1 else sz, pos = read_varint_tail_buf(buf, pos, blen, sz) end
            blob_end = pos + sz
            if blob_end > blen then break end
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
        if insn_count < 128 then bp = bp + 1 else insn_count, bp = read_varint_tail_buf(buf, bp, limit, insn_count) end
        local insn_base = bp
        local insn_end = bp + insn_count * 4
        if insn_end > limit then error("eof u32") end
        bp = insn_end

        local const_count = breadu8(buf, bp)
        if const_count < 128 then bp = bp + 1 else const_count, bp = read_varint_tail_buf(buf, bp, limit, const_count) end
        if const_count > max_const then max_const = const_count end

        local has_imports, broken_const = false, false

        for ci = 1, const_count do
            if bp >= limit then broken_const = true; break end
            local ctype = breadu8(buf, bp)
            bp = bp + 1

            if ctype == 3 then
                local sidx = breadu8(buf, bp)
                if sidx < 128 then bp = bp + 1 else sidx, bp = read_varint_tail_buf(buf, bp, limit, sidx) end
                if sidx >= 1 and sidx <= str_count then
                    const_sidx[ci] = sidx
                    if band_fn(str_flags[sidx], 1) == 0 then
                        local sv = strings[sidx]
                        if #sv > 0 then
                            str_flags[sidx] = str_flags[sidx] + 1
                            found_n = found_n + 1
                            found[found_n] = "string:" .. sv
                        end
                    end
                else
                    const_sidx[ci] = 0
                end
            elseif ctype == 2 then
                const_sidx[ci] = 0; bp = bp + 8
            elseif ctype == 4 then
                if bp + 4 > limit then error("eof u32") end
                constants[ci] = breadu32(buf, bp)
                const_sidx[ci] = -1
                has_imports = true
                any_imports = true
                bp = bp + 4
            elseif ctype == 1 then
                const_sidx[ci] = 0; bp = bp + 1
            elseif ctype == 0 then
                const_sidx[ci] = 0
            elseif ctype == 5 then
                const_sidx[ci] = 0
                local n = breadu8(buf, bp)
                if n < 128 then bp = bp + 1 else n, bp = read_varint_tail_buf(buf, bp, limit, n) end
                for _ = 1, n do
                    local v = breadu8(buf, bp)
                    if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end
                end
            elseif ctype == 6 then
                const_sidx[ci] = 0
                local v = breadu8(buf, bp)
                if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end
            elseif ctype == 7 then
                const_sidx[ci] = 0; bp = bp + 16
            elseif ctype == 8 then
                const_sidx[ci] = 0
                local n = breadu8(buf, bp)
                if n < 128 then bp = bp + 1 else n, bp = read_varint_tail_buf(buf, bp, limit, n) end
                for _ = 1, n do
                    local v = breadu8(buf, bp)
                    if v < 128 then bp = bp + 5 else local np; _, np = read_varint_tail_buf(buf, bp, limit, v); bp = np + 4 end
                end
            elseif ctype == 9 then
                const_sidx[ci] = 0; bp = bp + 1
                local v = breadu8(buf, bp)
                if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end
            elseif ctype == 10 then
                const_sidx[ci] = 0
                local v1 = breadu8(buf, bp)
                if v1 < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v1) end
                local pc2 = breadu8(buf, bp)
                if pc2 < 128 then bp = bp + 1 else pc2, bp = read_varint_tail_buf(buf, bp, limit, pc2) end
                local mc = breadu8(buf, bp)
                if mc < 128 then bp = bp + 1 else mc, bp = read_varint_tail_buf(buf, bp, limit, mc) end
                for _ = 1, pc2 + mc do
                    local pv = breadu8(buf, bp)
                    if pv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, pv) end
                end
            elseif ctype == 11 then
                const_sidx[ci] = 0; bp = bp + 32
            else
                broken_const = true; break
            end
        end

        found_n, encoded_mode = extract_proto_buf(buf, insn_base, insn_end, constants, const_sidx, const_count, strings, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, found, found_n)

        if broken_const then
            if blob_end then pos = blob_end else break end
        else
            if bp < limit then
                local child_count = breadu8(buf, bp)
                if child_count < 128 then bp = bp + 1 else child_count, bp = read_varint_tail_buf(buf, bp, limit, child_count) end
                for _ = 1, child_count do
                    local cv = breadu8(buf, bp)
                    if cv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, cv) end
                end

                local ld = breadu8(buf, bp)
                if ld < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, ld) end

                local didx = breadu8(buf, bp)
                if didx < 128 then bp = bp + 1 else didx, bp = read_varint_tail_buf(buf, bp, limit, didx) end
                if didx >= 1 and didx <= str_count and band_fn(str_flags[didx], 32) == 0 then
                    local dn = strings[didx]
                    if #dn > 0 then
                        str_flags[didx] = str_flags[didx] + 32
                        found_n = found_n + 1
                        found[found_n] = "func:" .. dn
                    end
                end

                if bp < limit then
                    if breadu8(buf, bp) == 1 then
                        if bp + 1 >= limit then
                            if blob_end then bp = limit else error("eof") end
                        else
                            local linegap = breadu8(buf, bp + 1)
                            local intervals = 1
                            if insn_count > 0 and linegap < 32 then intervals = rshift_fn(insn_count - 1, linegap) + 1 end
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
                        if lc < 128 then bp = bp + 1 else lc, bp = read_varint_tail_buf(buf, bp, limit, lc) end
                        for _ = 1, lc do
                            local vidx = breadu8(buf, bp)
                            if vidx < 128 then bp = bp + 1 else vidx, bp = read_varint_tail_buf(buf, bp, limit, vidx) end
                            if vidx >= 1 and vidx <= str_count and band_fn(str_flags[vidx], 64) == 0 then
                                local vn = strings[vidx]
                                if #vn > 0 then
                                    str_flags[vidx] = str_flags[vidx] + 64
                                    found_n = found_n + 1
                                    found[found_n] = "local:" .. vn
                                end
                            end
                            bp = skip_local_tail_buf(buf, bp, limit)
                        end

                        local uc = breadu8(buf, bp)
                        if uc < 128 then bp = bp + 1 else uc, bp = read_varint_tail_buf(buf, bp, limit, uc) end
                        for _ = 1, uc do
                            local uidx = breadu8(buf, bp)
                            if uidx < 128 then bp = bp + 1 else uidx, bp = read_varint_tail_buf(buf, bp, limit, uidx) end
                            if uidx >= 1 and uidx <= str_count and band_fn(str_flags[uidx], 128) == 0 then
                                local un = strings[uidx]
                                if #un > 0 then
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
                    if fb < 128 then bp = bp + 1 else fb, bp = read_varint_tail_buf(buf, bp, limit, fb) end
                    for _ = 1, fb do
                        bp = bp + 1
                        local fv = breadu8(buf, bp)
                        if fv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, fv) end
                    end
                end
                pos = bp
            end
        end
    end

    if any_imports then
        local ipaths, icalls = scratch_import_paths, scratch_import_calls
        for i = 1, max_const do ipaths[i] = nil; icalls[i] = nil end
    end

    return found_n, found
end

@native
local function char_kind(b)
    if b >= 97 and b <= 122 then return 1 end
    if b >= 65 and b <= 90 then return 2 end
    if b >= 48 and b <= 57 then return 0 end
    return -1
end

@native
local function is_token_start(raw_blob, s_pos)
    local prev_b = string.byte(raw_blob, s_pos - 1)
    if prev_b == 0 then
        local p, rlen = s_pos, #raw_blob
        while p <= rlen do
            local ch = string.byte(raw_blob, p)
            if ch == 0 then break end
            if ch == 58 then return false end
            p = p + 1
        end
        return true
    end
    local pk = char_kind(prev_b)
    if pk < 0 then return true end
    local fk = char_kind(string.byte(raw_blob, s_pos))
    if fk < 0 then return true end
    if fk == 2 then
        if pk == 1 or pk == 0 then return true end
        if pk == 2 and s_pos < #raw_blob and char_kind(string.byte(raw_blob, s_pos + 1)) == 1 then return true end
        return false
    end
    if fk == 0 then return pk > 0 end
    return pk == 0
end

@native
local function is_token_end(raw_blob, e_pos)
    local nk = char_kind(string.byte(raw_blob, e_pos + 1))
    if nk < 0 then return true end
    local lk = char_kind(string.byte(raw_blob, e_pos))
    if lk < 0 then return true end
    if nk == 2 then
        if lk == 1 or lk == 0 then return true end
        if lk == 2 and e_pos + 2 <= #raw_blob and char_kind(string.byte(raw_blob, e_pos + 2)) == 1 then return true end
        return false
    end
    if nk == 0 then return lk > 0 end
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
    local raw_blob, low_blob = entry.raw_blob, get_low_blob(entry)
    local pos = sfind(low_blob, lneedle, 1, true)
    while pos do
        if is_token_start(raw_blob, pos) and is_token_end(raw_blob, pos + nlen - 1) then return true end
        pos = sfind(low_blob, lneedle, pos + 1, true)
    end
    return false
end

local function has_bare_prefix(entry, lneedle)
    local raw_blob, low_blob = entry.raw_blob, get_low_blob(entry)
    local pos = sfind(low_blob, lneedle, 1, true)
    while pos do
        if is_token_start(raw_blob, pos) then return true end
        pos = sfind(low_blob, lneedle, pos + 1, true)
    end
    return false
end

local function has_fragment(entry, needle, lneedle)
    if sfind(entry.raw_blob, needle, 1, true) then return true end
    if not smatch(needle, "%a") then return false end
    return sfind(get_low_blob(entry), lneedle, 1, true) ~= nil
end

local function parse_and_cache(bytecode)
    hdr_cache[bytecode] = nil
    local ok, found_n, found = pcall(parse_and_extract, bytecode)
    local entry = (ok and found_n and found_n > 0) and {
        list = found,
        raw_blob = "\0" .. concat(found, "\0") .. "\0",
    } or false
    cache[bytecode] = entry
    return entry
end

local function get_entry(bytecode)
    if type(bytecode) ~= "string" or #bytecode < 2 then return false end
    local hit = cache[bytecode]
    if hit ~= nil then return hit end
    return parse_and_cache(bytecode)
end

local function longest_dot_segment(val)
    local best, best_len, start, vlen = nil, 0, 1, #val
    while start <= vlen do
        local dot = sfind(val, ".", start, true)
        local seg_end = dot and (dot - 1) or vlen
        local seg_len = seg_end - start + 1
        if seg_len > best_len then
            best_len = seg_len
            best = sub(val, start, seg_end)
        end
        if not dot then break end
        start = dot + 1
    end
    return best
end

local function matches_builtin_prefix(val)
    local vlen = #val
    for i = 1, #BUILTIN_LIST do
        local bn = BUILTIN_LIST[i]
        if #bn >= vlen and sub(bn, 1, vlen) == val then return true end
    end
    return false
end

local function extract_cold_hint(term, is_prefix)
    local colon = sfind(term, ":", 1, true)
    if not colon then return nil end
    local tag = sub(term, 1, colon - 1)
    if not HINT_TAGS[tag] then return nil end
    local val = sub(term, colon + 1)
    if #val == 0 then return nil end
    if tag == "call" then
        if is_prefix then return matches_builtin_prefix(val) and nil or val end
        return TAG_ID_BY_NAME[term] and nil or val
    end
    if tag == "import" or tag == "get" then
        if sfind(val, ".", 1, true) then
            return is_prefix and nil or longest_dot_segment(val)
        end
        return val
    end
    return val
end

local function extract_cold_ci_hint(lneedle)
    if #lneedle == 0 or sfind(STATIC_CI_HAYSTACK, lneedle, 1, true) then return nil end
    return lneedle
end

local function get_low_hdr(bc)
    local low_hdr = hdr_cache[bc]
    if low_hdr ~= nil then return low_hdr end
    local hdr = get_str_table_slice(bc)
    if not hdr then cache[bc] = false; return false end
    low_hdr = slower(hdr)
    hdr_cache[bc] = low_hdr
    return low_hdr
end

local function passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci)
    for h = 1, nhints do
        if not sfind(bc, cold_hints[h], 1, true) then return false end
    end
    if nci > 0 then
        local low_hdr = get_low_hdr(bc)
        if not low_hdr then return false end
        for h = 1, nci do
            if not sfind(low_hdr, cold_ci_hints[h], 1, true) then return false end
        end
    end
    return true
end

local function compile_terms(terms)
    local nterms = #terms
    local exact_needles, prefix_needles, bare_needles = {}, {}, {}
    local bare_lower, bare_len, bare_prefix_lower = {}, {}, {}
    local frag_needles, frag_lower, cold_hints, cold_ci_hints = {}, {}, {}, {}
    local nexact, nprefix, nbare, nbare_prefix, nfrag, nhints, nci = 0, 0, 0, 0, 0, 0, 0

    for t = 1, nterms do
        local term = terms[t]
        if type(term) ~= "string" or #term == 0 then return nil end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            if #needle > 0 then
                local lneedle = slower(needle)
                nfrag = nfrag + 1
                frag_needles[nfrag], frag_lower[nfrag] = needle, lneedle
                local ch = extract_cold_ci_hint(lneedle)
                if ch then nci = nci + 1; cold_ci_hints[nci] = ch end
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            if #needle > 0 then
                if sfind(needle, ":", 1, true) then
                    nprefix = nprefix + 1
                    prefix_needles[nprefix] = "\0" .. needle
                    local hint = extract_cold_hint(needle, true)
                    if hint then nhints = nhints + 1; cold_hints[nhints] = hint end
                else
                    local lneedle = slower(needle)
                    nbare_prefix = nbare_prefix + 1
                    bare_prefix_lower[nbare_prefix] = lneedle
                    local ch = extract_cold_ci_hint(lneedle)
                    if ch then nci = nci + 1; cold_ci_hints[nci] = ch end
                end
            end
        else
            if sfind(term, ":", 1, true) then
                nexact = nexact + 1
                exact_needles[nexact] = "\0" .. term .. "\0"
                local hint = extract_cold_hint(term, false)
                if hint then nhints = nhints + 1; cold_hints[nhints] = hint end
            else
                local lterm = slower(term)
                nbare = nbare + 1
                bare_needles[nbare] = (term == "concat" and "\0" or ":") .. term .. "\0"
                bare_lower[nbare] = lterm
                bare_len[nbare] = #term
                local ch = extract_cold_ci_hint(lterm)
                if ch then nci = nci + 1; cold_ci_hints[nci] = ch end
            end
        end
    end

    return exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag, cold_hints, nhints, cold_ci_hints, nci
end

local function entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag)
    local raw_blob = entry.raw_blob
    for t = 1, nexact do
        if not sfind(raw_blob, exact_needles[t], 1, true) then return false end
    end
    for t = 1, nprefix do
        if not sfind(raw_blob, prefix_needles[t], 1, true) then return false end
    end
    for t = 1, nbare do
        if not sfind(raw_blob, bare_needles[t], 1, true) and not has_bare_token(entry, bare_lower[t], bare_len[t]) then return false end
    end
    for t = 1, nbare_prefix do
        if not has_bare_prefix(entry, bare_prefix_lower[t]) then return false end
    end
    for t = 1, nfrag do
        if not has_fragment(entry, frag_needles[t], frag_lower[t]) then return false end
    end
    return true
end

function M.filter(bytecodes, terms)
    local find_fn, lower_fn = string.find, string.lower
    local nterms, matches, nmatches = #terms, {}, 0

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
        if type(term) ~= "string" or #term == 0 then return matches end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            local non_empty = #needle > 0
            local lneedle = lower_fn(needle)
            local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil then
                        if ci_hint then
                            local low_hdr = get_low_hdr(bc)
                            if low_hdr and find_fn(low_hdr, ci_hint, 1, true) then entry = parse_and_cache(bc) end
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
            if find_fn(needle, ":", 1, true) then
                local pneedle = "\0" .. needle
                local hint = extract_cold_hint(needle, true)
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc >= 2 then
                        local entry = cache[bc]
                        if entry == nil and (not hint or find_fn(bc, hint, 1, true)) then
                            entry = parse_and_cache(bc)
                        end
                        if entry and (not non_empty or find_fn(entry.raw_blob, pneedle, 1, true) ~= nil) then
                            nmatches = nmatches + 1
                            matches[nmatches] = i
                        end
                    end
                end
            else
                local lneedle = lower_fn(needle)
                local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
                for i = 1, #bytecodes do
                    local bc = bytecodes[i]
                    if type(bc) == "string" and #bc >= 2 then
                        local entry = cache[bc]
                        if entry == nil then
                            if ci_hint then
                                local low_hdr = get_low_hdr(bc)
                                if low_hdr and find_fn(low_hdr, ci_hint, 1, true) then entry = parse_and_cache(bc) end
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
        elseif find_fn(term, ":", 1, true) then
            local eneedle = "\0" .. term .. "\0"
            local hint = extract_cold_hint(term, false)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil and (not hint or find_fn(bc, hint, 1, true)) then
                        entry = parse_and_cache(bc)
                    end
                    if entry and find_fn(entry.raw_blob, eneedle, 1, true) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        else
            local eneedle = (term == "concat" and "\0" or ":") .. term .. "\0"
            local lterm, tlen = lower_fn(term), #term
            local ci_hint = extract_cold_ci_hint(lterm)
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc >= 2 then
                    local entry = cache[bc]
                    if entry == nil then
                        if ci_hint then
                            local low_hdr = get_low_hdr(bc)
                            if low_hdr and find_fn(low_hdr, ci_hint, 1, true) then entry = parse_and_cache(bc) end
                        else
                            entry = parse_and_cache(bc)
                        end
                    end
                    if entry and (find_fn(entry.raw_blob, eneedle, 1, true) or has_bare_token(entry, lterm, tlen)) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        end

        return matches
    end

    local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, nfrag, cold_hints, nhints, cold_ci_hints, nci = compile_terms(terms)
    if not exact_needles then return matches end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            if entry == nil and passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci) then
                entry = parse_and_cache(bc)
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
    local nterms, matches, nmatches = #terms, {}, 0
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
    if not exact_needles then return matches end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            local did_parse = false
            if entry == nil and passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, nci) then
                entry = parse_and_cache(bc)
                did_parse = true
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
    if not entry then return false end

    local token_list = entry.token_list
    if token_list then return token_list end

    local token_set, token_n = {}, 0
    token_list = {}
    local list = entry.list

    for i = 1, #list do
        local pat = list[i]
        local colon = sfind(pat, ":", 1, true)
        local val = colon and sub(pat, colon + 1) or pat
        local vlen = #val
        if vlen > 0 and vlen <= 4096 then
            local idx = 1
            while idx <= vlen do
                while idx <= vlen and char_kind(byte(val, idx)) < 0 do idx = idx + 1 end
                if idx > vlen then break end
                local seg_start = idx
                while idx <= vlen and char_kind(byte(val, idx)) >= 0 do idx = idx + 1 end
                local seg_end = idx - 1
                local whole = slower(sub(val, seg_start, seg_end))
                if not token_set[whole] then
                    token_set[whole] = true
                    token_n = token_n + 1
                    token_list[token_n] = whole
                end
                if seg_end > seg_start then
                    local sub_start, prev_k = seg_start, char_kind(byte(val, seg_start))
                    for j = seg_start + 1, seg_end do
                        local k = char_kind(byte(val, j))
                        local split = (k == 0 and prev_k ~= 0) or (k ~= 0 and prev_k == 0) or (k == 2 and (prev_k == 1 or (prev_k == 2 and j < seg_end and char_kind(byte(val, j + 1)) == 1)))
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
    tclear(cache)
    tclear(hdr_cache)
end

M.version = "3.0.0"

return M
