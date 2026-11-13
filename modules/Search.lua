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

local scratch_insns = {}
local scratch_ops = {}
local scratch_lens = {}
local scratch_starts = {}
local scratch_constants = {}
local scratch_import_paths = {}
local scratch_import_calls = {}
local scratch_reg_call = {}
local scratch_reg_ret = {}
local gen_counter = 0

local function reset_table(t)
    if tclear then
        tclear(t)
        return t
    end
    return {}
end

local function add_pat(set, found, found_n, p)
    if not set[p] then
        set[p] = true
        found_n = found_n + 1
        found[found_n] = p
    end
    return found_n
end

local function read_varint_buf(buf, pos, len)
    if pos >= len then
        error("eof")
    end
    local b0 = breadu8(buf, pos)
    if b0 < 128 then
        return b0, pos + 1
    end
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

local function read_varint_str(s, pos)
    local b0 = byte(s, pos)
    if not b0 then
        error("eof")
    end
    if b0 < 128 then
        return b0, pos + 1
    end
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

local function decode_import(constants, import_paths, import_calls, idx1)
    local cached = import_paths[idx1]
    if cached ~= nil then
        if cached == false then
            return nil, nil
        end
        return cached, import_calls[idx1]
    end

    local iid = constants[idx1]
    if type(iid) ~= "number" then
        import_paths[idx1] = false
        return nil, nil
    end

    local cnt = rshift(iid, 30)
    local p1 = cnt >= 1 and constants[band(rshift(iid, 20), 1023) + 1]
    local p2 = cnt >= 2 and constants[band(rshift(iid, 10), 1023) + 1]
    local p3 = cnt >= 3 and constants[band(iid, 1023) + 1]

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

local function decode_ops(insns, n, use_encode, ops, lens, starts, gen_id)
    local pc = 1
    while pc <= n do
        local op = band(insns[pc], 255)
        if use_encode then
            op = ENCODE_OP[op]
        end
        local len = OP_LEN[op]
        if not len or pc + len - 1 > n then
            return false
        end
        ops[pc] = op
        lens[pc] = len
        starts[pc] = gen_id
        pc = pc + len
    end
    return true
end

local function is_andor_jump(pc, insn, starts, gen_id, ops, insns)
    local d = rshift(insn, 16)
    if d >= 32768 then
        d = d - 65536
    end
    local target = pc + 1 + d
    if starts[target] == gen_id then
        local top = ops[target]
        if top == 3 then
            return rshift(insns[target], 24) ~= 0
        end
        if top == 6 then
            return true
        end
    end
    return false
end

local function is_call_target(pc, len, reg, total, ops, insns)
    local nxt = pc + len
    if nxt > total then
        return false
    end
    local nop = ops[nxt]
    return (nop == 21 or nop == 87) and band(rshift(insns[nxt], 8), 255) == reg
end

local function extract_proto(insns, total, constants, encoded_mode, set, found, found_n)
    if total == 0 then
        return found_n, encoded_mode
    end

    local ops = scratch_ops
    local lens = scratch_lens
    local starts = scratch_starts

    local active_gen
    if encoded_mode == true then
        gen_counter = gen_counter + 1
        active_gen = gen_counter
        if not decode_ops(insns, total, true, ops, lens, starts, active_gen) then
            return found_n, encoded_mode
        end
    else
        gen_counter = gen_counter + 1
        active_gen = gen_counter
        if not decode_ops(insns, total, false, ops, lens, starts, active_gen) then
            gen_counter = gen_counter + 1
            active_gen = gen_counter
            if not decode_ops(insns, total, true, ops, lens, starts, active_gen) then
                return found_n, encoded_mode
            end
            encoded_mode = true
        end
    end

    local reg_call = reset_table(scratch_reg_call)
    local reg_ret = reset_table(scratch_reg_ret)
    local import_paths = reset_table(scratch_import_paths)
    local import_calls = reset_table(scratch_import_calls)
    scratch_reg_call = reg_call
    scratch_reg_ret = reg_ret
    scratch_import_paths = import_paths
    scratch_import_calls = import_calls

    local max_reg = 0
    local pc = 1

    while pc <= total do
        local insn = insns[pc]
        local op = ops[pc]
        local len = lens[pc]
        local a = band(rshift(insn, 8), 255)
        local b = band(rshift(insn, 16), 255)
        local c = rshift(insn, 24)

        if op == 22 then
            local pat = b == 1 and "return:void" or (reg_ret[a] or "return:value")
            found_n = add_pat(set, found, found_n, pat)
        elseif op == 21 or op == 87 then
            local cp = reg_call[a]
            if cp then
                found_n = add_pat(set, found, found_n, cp)
            end
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
            local kidx = op == 20 and aux or band(aux, 65535)
            local key = constants[kidx + 1]
            if type(key) == "string" then
                found_n = add_pat(set, found, found_n, "method:" .. key)
                local cpat = "call:" .. key
                found_n = add_pat(set, found, found_n, cpat)
                reg_call[a] = cpat
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
            local kidx = op == 83 and band(aux, 65535) or aux
            local key = constants[kidx + 1]
            if type(key) == "string" then
                if not is_call_target(pc, len, a, total, ops, insns) then
                    found_n = add_pat(set, found, found_n, "get:" .. key)
                end
                reg_call[a] = "call:" .. key
            else
                reg_call[a] = nil
            end
            reg_ret[a] = nil
            if a > max_reg then
                max_reg = a
            end
        elseif op == 16 or op == 8 or op == 84 then
            local aux = insns[pc + 1]
            local kidx = op == 84 and band(aux, 65535) or aux
            local key = constants[kidx + 1]
            if type(key) == "string" then
                found_n = add_pat(set, found, found_n, "set:" .. key)
            end
        elseif op == 12 then
            local dfield = rshift(insn, 16)
            local path, cpat = decode_import(constants, import_paths, import_calls, dfield + 1)
            if path then
                found_n = add_pat(set, found, found_n, "import:" .. path)
                if not is_call_target(pc, len, a, total, ops, insns) then
                    found_n = add_pat(set, found, found_n, "get:" .. path)
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
            reg_call[a] = nil
            reg_ret[a] = b == 0 and "return:false" or (b == 1 and "return:true" or nil)
            if a > max_reg then
                max_reg = a
            end
        elseif op == 25 then
            local pat = is_andor_jump(pc, insn, starts, active_gen, ops, insns) and "cond:or" or "if:then"
            found_n = add_pat(set, found, found_n, pat)
        elseif op == 26 then
            if is_andor_jump(pc, insn, starts, active_gen, ops, insns) then
                found_n = add_pat(set, found, found_n, "cond:and")
            else
                found_n = add_pat(set, found, found_n, "if:then")
                found_n = add_pat(set, found, found_n, "if:not-then")
            end
        elseif op == 77 or op == 78 or op == 79 or op == 80 then
            local pat = insns[pc + 1] >= 2147483648 and "if:ne" or "if:eq"
            found_n = add_pat(set, found, found_n, pat)
        elseif op == 56 or op == 59 or op == 61 or op == 76 then
            local pat = op == 56 and "loop:for-num" or (op == 61 and "loop:for-in-next" or (op == 59 and "loop:for-in-inext" or "loop:for-in"))
            found_n = add_pat(set, found, found_n, pat)
            for r = a, a + 3 do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 57 then
            found_n = add_pat(set, found, found_n, "loop:for-num")
            reg_call[a + 2] = nil
            reg_call[a + 3] = nil
            reg_ret[a + 2] = nil
            reg_ret[a + 3] = nil
        elseif op == 58 then
            found_n = add_pat(set, found, found_n, "loop:for-in")
            local top = a + 2 + band(insns[pc + 1], 255)
            for r = a + 2, top do
                reg_call[r] = nil
                reg_ret[r] = nil
            end
        elseif op == 63 then
            found_n = add_pat(set, found, found_n, "vararg:get")
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
            if bcall then
                found_n = add_pat(set, found, found_n, bcall)
            end
        elseif op == 89 then
            if a == 0 then
                found_n = add_pat(set, found, found_n, "call:pcall")
            elseif a == 1 then
                found_n = add_pat(set, found, found_n, "call:xpcall")
            end
        else
            local tag = OP_PATTERN[op]
            if tag then
                found_n = add_pat(set, found, found_n, tag)
            end
            if SIMPLE_CLEAR_A[op] then
                reg_call[a] = nil
                reg_ret[a] = nil
            end
        end

        pc = pc + len
    end

    return found_n, encoded_mode
end

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

    local str_count
    str_count, pos = read_varint_buf(buf, pos, blen)

    local strings = tcreate and tcreate(str_count) or {}
    for i = 1, str_count do
        local slen
        slen, pos = read_varint_buf(buf, pos, blen)
        if pos + slen > blen then
            error("eof")
        end
        strings[i] = breadstring(buf, pos, slen)
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
            local _, np = read_varint_buf(buf, pos, blen)
            pos = np
        end
    end

    local proto_count
    proto_count, pos = read_varint_buf(buf, pos, blen)

    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local insns = scratch_insns

    for _ = 1, proto_count do
        local blob_end
        if has_size then
            local sz
            sz, pos = read_varint_buf(buf, pos, blen)
            blob_end = pos + sz
            if blob_end > blen then
                break
            end
        end

        local limit = blob_end or blen
        local bp = pos + 4

        if version >= 4 then
            bp = bp + 1
            local tsize, np = read_varint_buf(buf, bp, limit)
            bp = np + tsize
        end

        local insn_count
        insn_count, bp = read_varint_buf(buf, bp, limit)
        if bp + insn_count * 4 > limit then
            error("eof u32")
        end

        for i = 1, insn_count do
            insns[i] = breadu32(buf, bp)
            bp = bp + 4
        end

        local const_count
        const_count, bp = read_varint_buf(buf, bp, limit)

        local constants = reset_table(scratch_constants)
        scratch_constants = constants
        local broken_const = false

        for ci = 1, const_count do
            if bp >= limit then
                broken_const = true
                break
            end
            local ctype = breadu8(buf, bp)
            bp = bp + 1

            if ctype == 0 then
            elseif ctype == 1 then
                bp = bp + 1
            elseif ctype == 2 then
                bp = bp + 8
            elseif ctype == 3 then
                local sidx
                sidx, bp = read_varint_buf(buf, bp, limit)
                local sv = strings[sidx]
                if sv ~= nil then
                    constants[ci] = sv
                    if #sv > 0 then
                        found_n = add_pat(set, found, found_n, "string:" .. sv)
                    end
                end
            elseif ctype == 4 then
                if bp + 4 > limit then
                    error("eof u32")
                end
                constants[ci] = breadu32(buf, bp)
                bp = bp + 4
            elseif ctype == 5 then
                local n
                n, bp = read_varint_buf(buf, bp, limit)
                for _ = 1, n do
                    local _, np = read_varint_buf(buf, bp, limit)
                    bp = np
                end
            elseif ctype == 6 then
                local _, np = read_varint_buf(buf, bp, limit)
                bp = np
            elseif ctype == 7 then
                bp = bp + 16
            elseif ctype == 8 then
                local n
                n, bp = read_varint_buf(buf, bp, limit)
                for _ = 1, n do
                    local _, np = read_varint_buf(buf, bp, limit)
                    bp = np + 4
                end
            elseif ctype == 9 then
                bp = bp + 1
                local _, np = read_varint_buf(buf, bp, limit)
                bp = np
            elseif ctype == 10 then
                local _, np = read_varint_buf(buf, bp, limit)
                bp = np
                local pc2, np2 = read_varint_buf(buf, bp, limit)
                bp = np2
                local mc, np3 = read_varint_buf(buf, bp, limit)
                bp = np3
                for _ = 1, pc2 do
                    local _, np4 = read_varint_buf(buf, bp, limit)
                    bp = np4
                end
                for _ = 1, mc do
                    local _, np5 = read_varint_buf(buf, bp, limit)
                    bp = np5
                end
            elseif ctype == 11 then
                bp = bp + 32
            else
                broken_const = true
                break
            end
        end

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, encoded_mode, set, found, found_n)

        if blob_end then
            pos = blob_end
        else
            if broken_const then
                break
            end

            local child_count
            child_count, bp = read_varint_buf(buf, bp, limit)
            for _ = 1, child_count do
                local _, np = read_varint_buf(buf, bp, limit)
                bp = np
            end

            local _, np2 = read_varint_buf(buf, bp, limit)
            bp = np2
            local _, np3 = read_varint_buf(buf, bp, limit)
            bp = np3

            if bp >= limit then
                error("eof")
            end
            if breadu8(buf, bp) == 1 then
                if bp + 1 >= limit then
                    error("eof")
                end
                local linegap = breadu8(buf, bp + 1)
                local intervals = 1
                if insn_count > 0 and linegap < 32 then
                    intervals = rshift(insn_count - 1, linegap) + 1
                end
                bp = bp + 2 + insn_count + intervals * 4
            else
                bp = bp + 1
            end

            if bp >= limit then
                error("eof")
            end
            if breadu8(buf, bp) == 1 then
                bp = bp + 1
                local lc
                lc, bp = read_varint_buf(buf, bp, limit)
                for _ = 1, lc do
                    local _, np4 = read_varint_buf(buf, bp, limit)
                    bp = np4
                    local _, np5 = read_varint_buf(buf, bp, limit)
                    bp = np5
                    local _, np6 = read_varint_buf(buf, bp, limit)
                    bp = np6 + 1
                end

                local uc
                uc, bp = read_varint_buf(buf, bp, limit)
                for _ = 1, uc do
                    local _, np7 = read_varint_buf(buf, bp, limit)
                    bp = np7
                end
            else
                bp = bp + 1
            end

            if version >= 11 or version == 100 then
                local fb
                fb, bp = read_varint_buf(buf, bp, limit)
                for _ = 1, fb do
                    bp = bp + 1
                    local _, np8 = read_varint_buf(buf, bp, limit)
                    bp = np8
                end
            end

            pos = bp
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

    local str_count
    str_count, pos = read_varint_str(bytecode, pos)

    local strings = tcreate and tcreate(str_count) or {}
    for i = 1, str_count do
        local len
        len, pos = read_varint_str(bytecode, pos)
        if pos + len - 1 > slen then
            error("eof")
        end
        strings[i] = sub(bytecode, pos, pos + len - 1)
        pos = pos + len
    end

    if typesversion == 3 then
        while true do
            local tag = byte(bytecode, pos)
            pos = pos + 1
            if tag == nil or tag == 0 then
                break
            end
            local _, np = read_varint_str(bytecode, pos)
            pos = np
        end
    end

    local proto_count
    proto_count, pos = read_varint_str(bytecode, pos)

    local has_size = version >= 12 or version == 100
    local found_n = 0
    local encoded_mode = nil
    local insns = scratch_insns

    for _ = 1, proto_count do
        local blob_end
        if has_size then
            local sz
            sz, pos = read_varint_str(bytecode, pos)
            blob_end = pos + sz
            if blob_end > slen + 1 then
                break
            end
        end

        local max_end = blob_end and (blob_end - 1) or slen
        local bp = pos + 4

        if version >= 4 then
            bp = bp + 1
            local tsize, np = read_varint_str(bytecode, bp)
            bp = np + tsize
        end

        local insn_count
        insn_count, bp = read_varint_str(bytecode, bp)
        if bp + insn_count * 4 - 1 > max_end then
            error("eof u32")
        end

        for i = 1, insn_count do
            local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
            insns[i] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            bp = bp + 4
        end

        local const_count
        const_count, bp = read_varint_str(bytecode, bp)

        local constants = reset_table(scratch_constants)
        scratch_constants = constants
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
            elseif ctype == 1 then
                bp = bp + 1
            elseif ctype == 2 then
                bp = bp + 8
            elseif ctype == 3 then
                local sidx
                sidx, bp = read_varint_str(bytecode, bp)
                local sv = strings[sidx]
                if sv ~= nil then
                    constants[ci] = sv
                    if #sv > 0 then
                        found_n = add_pat(set, found, found_n, "string:" .. sv)
                    end
                end
            elseif ctype == 4 then
                local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
                if not b1 or not b2 or not b3 or not b4 then
                    error("eof u32")
                end
                constants[ci] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
                bp = bp + 4
            elseif ctype == 5 then
                local n
                n, bp = read_varint_str(bytecode, bp)
                for _ = 1, n do
                    local _, np = read_varint_str(bytecode, bp)
                    bp = np
                end
            elseif ctype == 6 then
                local _, np = read_varint_str(bytecode, bp)
                bp = np
            elseif ctype == 7 then
                bp = bp + 16
            elseif ctype == 8 then
                local n
                n, bp = read_varint_str(bytecode, bp)
                for _ = 1, n do
                    local _, np = read_varint_str(bytecode, bp)
                    bp = np + 4
                end
            elseif ctype == 9 then
                bp = bp + 1
                local _, np = read_varint_str(bytecode, bp)
                bp = np
            elseif ctype == 10 then
                local _, np = read_varint_str(bytecode, bp)
                bp = np
                local pc2, np2 = read_varint_str(bytecode, bp)
                bp = np2
                local mc, np3 = read_varint_str(bytecode, bp)
                bp = np3
                for _ = 1, pc2 do
                    local _, np4 = read_varint_str(bytecode, bp)
                    bp = np4
                end
                for _ = 1, mc do
                    local _, np5 = read_varint_str(bytecode, bp)
                    bp = np5
                end
            elseif ctype == 11 then
                bp = bp + 32
            else
                broken_const = true
                break
            end
        end

        found_n, encoded_mode = extract_proto(insns, insn_count, constants, encoded_mode, set, found, found_n)

        if blob_end then
            pos = blob_end
        else
            if broken_const then
                break
            end

            local child_count
            child_count, bp = read_varint_str(bytecode, bp)
            for _ = 1, child_count do
                local _, np = read_varint_str(bytecode, bp)
                bp = np
            end

            local _, np2 = read_varint_str(bytecode, bp)
            bp = np2
            local _, np3 = read_varint_str(bytecode, bp)
            bp = np3

            local has_li = byte(bytecode, bp)
            if not has_li then
                error("eof")
            end
            if has_li == 1 then
                local linegap = byte(bytecode, bp + 1)
                if not linegap then
                    error("eof")
                end
                local intervals = 1
                if insn_count > 0 and linegap < 32 then
                    intervals = rshift(insn_count - 1, linegap) + 1
                end
                bp = bp + 2 + insn_count + intervals * 4
            else
                bp = bp + 1
            end

            local has_di = byte(bytecode, bp)
            if not has_di then
                error("eof")
            end
            if has_di == 1 then
                bp = bp + 1
                local lc
                lc, bp = read_varint_str(bytecode, bp)
                for _ = 1, lc do
                    local _, np4 = read_varint_str(bytecode, bp)
                    bp = np4
                    local _, np5 = read_varint_str(bytecode, bp)
                    bp = np5
                    local _, np6 = read_varint_str(bytecode, bp)
                    bp = np6 + 1
                end

                local uc
                uc, bp = read_varint_str(bytecode, bp)
                for _ = 1, uc do
                    local _, np7 = read_varint_str(bytecode, bp)
                    bp = np7
                end
            else
                bp = bp + 1
            end

            if version >= 11 or version == 100 then
                local fb
                fb, bp = read_varint_str(bytecode, bp)
                for _ = 1, fb do
                    bp = bp + 1
                    local _, np8 = read_varint_str(bytecode, bp)
                    bp = np8
                end
            end

            pos = bp
        end
    end

    return found_n
end

local parse_and_extract = bfrom and parse_and_extract_buf or parse_and_extract_str

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

local function compile_terms(terms)
    local nterms = #terms
    local exact_needles = {}
    local prefix_needles = {}
    local fragment_needles = {}
    local nexact, nprefix, nfrag = 0, 0, 0

    for t = 1, nterms do
        local term = terms[t]
        if type(term) ~= "string" or #term == 0 then
            return nil
        end

        if sub(term, 1, 1) == "~" then
            local needle = sub(term, 2)
            if #needle > 0 then
                nfrag = nfrag + 1
                fragment_needles[nfrag] = needle
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            if #needle > 0 then
                nprefix = nprefix + 1
                prefix_needles[nprefix] = needle
            end
        else
            nexact = nexact + 1
            exact_needles[nexact] = term
        end
    end

    return exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag
end

local function entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag)
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
    if nfrag > 0 then
        local list = entry.list
        for t = 1, nfrag do
            if not list_contains(list, fragment_needles[t]) then
                return false
            end
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
            for i = 1, #bytecodes do
                local bc = bytecodes[i]
                if type(bc) == "string" and #bc > 0 then
                    local entry = get_entry(bc)
                    if entry and (not non_empty or list_contains(entry.list, needle)) then
                        nmatches = nmatches + 1
                        matches[nmatches] = i
                    end
                end
            end
        elseif sub(term, -1) == "*" then
            local needle = sub(term, 1, -2)
            local non_empty = #needle > 0
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
        end

        return matches
    end

    local exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local entry = get_entry(bc)
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag) then
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

    local exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag = compile_terms(terms)
    if not exact_needles then
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local was_cached = cache[bc] ~= nil
            local entry = get_entry(bc)
            if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, fragment_needles, nfrag) then
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

function M.clear()
    if tclear then
        tclear(cache)
    else
        cache = {}
    end
end

M.version = "2.5.0"

return M
