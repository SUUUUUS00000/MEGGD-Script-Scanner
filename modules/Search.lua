local M = {}
local cache = {}

local OP_NAMES = {
    [0]="NOP", [1]="BREAK", [2]="LOADNIL", [3]="LOADB", [4]="LOADN", [5]="LOADK",
    [6]="MOVE", [7]="GETGLOBAL", [8]="SETGLOBAL", [9]="GETUPVAL", [10]="SETUPVAL",
    [11]="CLOSEUPVALS", [12]="GETIMPORT", [13]="GETTABLE", [14]="SETTABLE",
    [15]="GETTABLEKS", [16]="SETTABLEKS", [17]="GETTABLEN", [18]="SETTABLEN",
    [19]="NEWCLOSURE", [20]="NAMECALL", [21]="CALL", [22]="RETURN", [23]="JUMP",
    [24]="JUMPBACK", [25]="JUMPIF", [26]="JUMPIFNOT", [27]="JUMPIFEQ", [28]="JUMPIFLE",
    [29]="JUMPIFLT", [30]="JUMPIFNOTEQ", [31]="JUMPIFNOTLE", [32]="JUMPIFNOTLT",
    [33]="ADD", [34]="SUB", [35]="MUL", [36]="DIV", [37]="MOD", [38]="POW",
    [39]="ADDK", [40]="SUBK", [41]="MULK", [42]="DIVK", [43]="MODK", [44]="POWK",
    [45]="AND", [46]="OR", [47]="ANDK", [48]="ORK", [49]="CONCAT", [50]="NOT",
    [51]="MINUS", [52]="LENGTH", [53]="NEWTABLE", [54]="DUPTABLE", [55]="SETLIST",
    [56]="FORNPREP", [57]="FORNLOOP", [58]="FORGLOOP", [59]="FORGPREP_INEXT",
    [60]="FASTCALL3", [61]="FORGPREP_NEXT", [62]="NATIVECALL", [63]="GETVARARGS",
    [64]="DUPCLOSURE", [65]="PREPVARARGS", [66]="LOADKX", [67]="JUMPX", [68]="FASTCALL",
    [69]="COVERAGE", [70]="CAPTURE", [71]="SUBRK", [72]="DIVRK", [73]="FASTCALL1",
    [74]="FASTCALL2", [75]="FASTCALL2K", [76]="FORGPREP", [77]="JUMPXEQKNIL",
    [78]="JUMPXEQKB", [79]="JUMPXEQKN", [80]="JUMPXEQKS", [81]="IDIV", [82]="IDIVK",
    [83]="GETUDATAKS", [84]="SETUDATAKS", [85]="NAMECALLUDATA", [86]="NEWCLASSMEMBER",
    [87]="CALLFB", [88]="CMPPROTO", [89]="FASTPCALL", [90]="NEWCLASS",
    [91]="CONSTRUCT", [92]="FINCONSTRUCT", [93]="GETPRIVATEFIELD", [94]="SETPRIVATEFIELD",
}
local OP_COUNT = 95

local TWO_WORD = {
    GETGLOBAL=true, SETGLOBAL=true, GETIMPORT=true, GETTABLEKS=true, SETTABLEKS=true,
    NAMECALL=true, JUMPIFEQ=true, JUMPIFLE=true, JUMPIFLT=true, JUMPIFNOTEQ=true,
    JUMPIFNOTLE=true, JUMPIFNOTLT=true, NEWTABLE=true, SETLIST=true, FORGLOOP=true,
    LOADKX=true, FASTCALL2=true, FASTCALL2K=true, FASTCALL3=true, JUMPXEQKNIL=true,
    JUMPXEQKB=true, JUMPXEQKN=true, JUMPXEQKS=true, GETUDATAKS=true, SETUDATAKS=true,
    NAMECALLUDATA=true, NEWCLASSMEMBER=true, CALLFB=true, CMPPROTO=true, NEWCLASS=true,
    CONSTRUCT=true, GETPRIVATEFIELD=true, SETPRIVATEFIELD=true,
}

local BUILTIN_NAMES = {
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

local byte = string.byte
local sub = string.sub
local floor = math.floor
local sort = table.sort
local concat = table.concat
local sfind = string.find
local smatch = string.match

local function fdiv(a, b)
    return floor(a / b)
end

local function varint(s, pos)
    local result, mul = 0, 1
    while true do
        local b = byte(s, pos)
        if not b then error("eof") end
        pos = pos + 1
        result = result + (b % 128) * mul
        if b < 128 then return result, pos end
        mul = mul * 128
    end
end

local TWO_WORD_OP = {}
for op = 0, OP_COUNT - 1 do
    local name = OP_NAMES[op]
    if name and TWO_WORD[name] then
        TWO_WORD_OP[op] = true
    end
end

local ENCODE_OP = {}
for i = 0, 255 do
    ENCODE_OP[i] = (i * 203) % 256
end

local WRITE_SIMPLE_A = {}
for _, op in ipairs({
    2, 3, 4, 5, 6, 7, 9, 12, 13, 15, 17, 19,
    33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
    45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
    64, 66, 71, 72, 81, 82, 83, 90, 91, 93,
}) do
    WRITE_SIMPLE_A[op] = true
end

local RET_SIMPLE_A = {}
for _, op in ipairs({
    2, 3, 4, 5, 6, 7, 9, 12, 13, 15, 17, 19,
    33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
    45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
    63, 64, 66, 71, 72, 83, 90, 91, 93,
}) do
    RET_SIMPLE_A[op] = true
end

local function get_string(constants, idx1)
    local c = constants[idx1]
    if type(c) == "string" then
        return c
    end
    return nil
end

local function decode_import(constants, c)
    if type(c) ~= "table" then
        return nil
    end

    local path = c.path
    if path == false then
        return nil
    end
    if path ~= nil then
        return path
    end

    local imp = c.import
    if not imp then
        c.path = false
        return nil
    end

    local parts = {}
    for i = 1, #imp do
        local s = get_string(constants, imp[i] + 1)
        if s then
            parts[#parts + 1] = s
        end
    end

    if #parts == 0 then
        c.path = false
        return nil
    end

    local result = concat(parts, ".")
    c.path = result
    return result
end

local function build_meta(insns, encoded)
    local n = #insns
    local previous, starts = {}, {}
    local ops, As, Bs, Cs = {}, {}, {}, {}

    local pc, prior = 1, nil

    while pc <= n do
        local insn = insns[pc]
        local op = insn % 256

        if encoded then
            op = ENCODE_OP[op]
        end

        if op >= OP_COUNT then
            return nil
        end

        local len = TWO_WORD_OP[op] and 2 or 1
        if pc + len - 1 > n then
            return nil
        end

        starts[pc] = true
        if prior then
            previous[pc] = prior
        end

        ops[pc] = op
        As[pc] = fdiv(insn, 256) % 256
        Bs[pc] = fdiv(insn, 65536) % 256
        Cs[pc] = fdiv(insn, 16777216) % 256

        prior = pc
        pc = pc + len
    end

    return previous, starts, ops, As, Bs, Cs
end

local function is_andor_jump(pc, starts, ops, Bs, Cs)
    local d = Bs[pc] + Cs[pc] * 256
    if d >= 32768 then
        d = d - 65536
    end

    local target = pc + 1 + d
    if starts[target] then
        local top = ops[target]
        if top == 3 then
            return Cs[target] ~= 0
        end
        if top == 6 then
            return true
        end
    end

    return false
end

local function is_call_target(pc, len, reg, starts, ops, As)
    local nxt = pc + len
    if not starts[nxt] then
        return false
    end

    local op = ops[nxt]
    return (op == 21 or op == 87) and As[nxt] == reg
end

local function instruction_writes_register(insns, pc, target, op, a, b, c)
    if WRITE_SIMPLE_A[op] then
        return target == a
    elseif op == 20 or op == 85 then
        return target == a or target == a + 1
    elseif op == 21 or op == 87 then
        local nresults = c - 1
        if nresults == 0 then
            return false
        end
        return target >= a and (nresults < 0 or target < a + nresults)
    elseif op == 63 then
        return target >= a and (b == 0 or target < a + b - 1)
    elseif op == 58 then
        local aux = insns[pc + 1] or 0
        local count = aux % 256
        return target >= a + 2 and target < a + 3 + count
    elseif op == 57 then
        return target >= a + 2 and target <= a + 3
    elseif op == 76 or op == 59 or op == 61 or op == 56 then
        return target >= a and target <= a + 3
    end

    return false
end

local function find_return_pattern(pc, a, ops, As, Bs, Cs, previous)
    local target = a
    local prev_pc = previous[pc]

    while prev_pc do
        local op = ops[prev_pc]
        local pa = As[prev_pc]
        local pb = Bs[prev_pc]
        local pcc = Cs[prev_pc]

        local writes = false

        if RET_SIMPLE_A[op] then
            writes = (pa == target)
        elseif op == 21 or op == 87 then
            local nres = pcc - 1
            if nres == 0 then
                writes = false
            elseif nres < 0 then
                writes = (target >= pa)
            else
                writes = (target >= pa and target < pa + nres)
            end
        elseif op == 20 or op == 85 then
            writes = (pa == target or pa + 1 == target)
        end

        if writes then
            if op == 3 then
                if pb == 0 then return "return:false" end
                if pb == 1 then return "return:true" end
                return nil
            elseif op == 2 then
                return "return:nil"
            elseif op == 21 or op == 87 then
                return "return:call"
            elseif op == 6 then
                target = pb
            else
                return nil
            end
        end

        prev_pc = previous[prev_pc]
    end

    return nil
end

local function find_call_pattern(insns, pc, a, constants, previous, ops, As, Bs, Cs)
    local target = a
    local prev_pc = previous[pc]

    while prev_pc do
        local op = ops[prev_pc]
        local pa = As[prev_pc]
        local pb = Bs[prev_pc]
        local pcc = Cs[prev_pc]

        if instruction_writes_register(insns, prev_pc, target, op, pa, pb, pcc) then
            if op == 15 or op == 7 then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, aux + 1)
                if key then
                    return "call:" .. key
                end
                return nil
            elseif op == 83 then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, (aux % 65536) + 1)
                if key then
                    return "call:" .. key
                end
                return nil
            elseif op == 12 then
                local dfield = Bs[prev_pc] + Cs[prev_pc] * 256
                local path = decode_import(constants, constants[dfield + 1])
                if path then
                    local last = smatch(path, "([^.]+)$") or path
                    return "call:" .. last
                end
                return nil
            elseif op == 20 then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, aux + 1)
                if key then
                    return "call:" .. key
                end
                return nil
            elseif op == 85 then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, (aux % 65536) + 1)
                if key then
                    return "call:" .. key
                end
                return nil
            elseif op == 6 then
                target = pb
            else
                return nil
            end
        end

        prev_pc = previous[prev_pc]
    end

    return nil
end

local function parse(bytecode)
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
    str_count, pos = varint(bytecode, pos)

    local strings = {}
    for i = 1, str_count do
        local len
        len, pos = varint(bytecode, pos)
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
            local _, np = varint(bytecode, pos)
            pos = np
        end
    end

    local proto_count
    proto_count, pos = varint(bytecode, pos)

    local has_size = version >= 12 or version == 100
    local protos = {}

    for pi = 1, proto_count do
        local blob_end

        if has_size then
            local sz
            sz, pos = varint(bytecode, pos)
            blob_end = pos + sz
            if blob_end > #bytecode then
                break
            end
        end

        local bp = pos + 4

        if version >= 4 then
            bp = bp + 1
            local tsize, np = varint(bytecode, bp)
            bp = np + tsize
        end

        local insn_count
        insn_count, bp = varint(bytecode, bp)

        local insns = {}
        for i = 1, insn_count do
            local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
            if not b1 or not b2 or not b3 or not b4 then
                error("eof u32")
            end
            insns[i] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            bp = bp + 4
        end

        local const_count
        const_count, bp = varint(bytecode, bp)

        local constants = {}
        local proto_strings = {}

        for ci = 1, const_count do
            local ctype = byte(bytecode, bp)
            bp = bp + 1

            if ctype == 0 then
            elseif ctype == 1 then
                bp = bp + 1
            elseif ctype == 2 then
                bp = bp + 8
            elseif ctype == 3 then
                local sidx
                sidx, bp = varint(bytecode, bp)
                local sv = strings[sidx]
                if sv ~= nil then
                    constants[ci] = sv
                    if #sv > 0 then
                        proto_strings[#proto_strings + 1] = sv
                    end
                end
            elseif ctype == 4 then
                local b1, b2, b3, b4 = byte(bytecode, bp, bp + 3)
                if not b1 or not b2 or not b3 or not b4 then
                    error("eof u32")
                end

                local iid = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
                bp = bp + 4

                local cnt = fdiv(iid, 1073741824) % 4
                local imp = {}

                if cnt >= 1 then
                    imp[1] = fdiv(iid, 1048576) % 1024
                end
                if cnt >= 2 then
                    imp[2] = fdiv(iid, 1024) % 1024
                end
                if cnt >= 3 then
                    imp[3] = iid % 1024
                end

                constants[ci] = { import = imp }
            elseif ctype == 5 then
                local n
                n, bp = varint(bytecode, bp)
                for _ = 1, n do
                    local _, np = varint(bytecode, bp)
                    bp = np
                end
            elseif ctype == 6 then
                local _, np = varint(bytecode, bp)
                bp = np
            elseif ctype == 7 then
                bp = bp + 16
            elseif ctype == 8 then
                local n
                n, bp = varint(bytecode, bp)
                for _ = 1, n do
                    local _, np = varint(bytecode, bp)
                    bp = np + 4
                end
            elseif ctype == 9 then
                bp = bp + 1
                local _, np = varint(bytecode, bp)
                bp = np
            elseif ctype == 10 then
                bp = bp + 32
            elseif ctype == 11 then
                local _, np = varint(bytecode, bp)
                bp = np
                local pc2, np2 = varint(bytecode, bp)
                bp = np2
                local mc, np3 = varint(bytecode, bp)
                bp = np3
                for _ = 1, pc2 do
                    local _, np4 = varint(bytecode, bp)
                    bp = np4
                end
                for _ = 1, mc do
                    local _, np5 = varint(bytecode, bp)
                    bp = np5
                end
            else
                break
            end
        end

        local child_count
        child_count, bp = varint(bytecode, bp)
        for _ = 1, child_count do
            local _, np = varint(bytecode, bp)
            bp = np
        end

        local _, np2 = varint(bytecode, bp)
        bp = np2
        local _, np3 = varint(bytecode, bp)
        bp = np3

        if byte(bytecode, bp) == 1 then
            local linegap = byte(bytecode, bp + 1)
            local intervals = 1
            if insn_count > 0 then
                intervals = fdiv(insn_count - 1, 2 ^ linegap) + 1
            end
            bp = bp + 2 + insn_count + intervals * 4
        else
            bp = bp + 1
        end

        if byte(bytecode, bp) == 1 then
            bp = bp + 1
            local lc
            lc, bp = varint(bytecode, bp)

            for _ = 1, lc do
                local _, np4 = varint(bytecode, bp)
                bp = np4
                local _, np5 = varint(bytecode, bp)
                bp = np5
                local _, np6 = varint(bytecode, bp)
                bp = np6
                bp = bp + 1
            end

            local uc
            uc, bp = varint(bytecode, bp)
            for _ = 1, uc do
                local _, np7 = varint(bytecode, bp)
                bp = np7
            end
        else
            bp = bp + 1
        end

        if version >= 11 or version == 100 then
            local fb
            fb, bp = varint(bytecode, bp)
            for _ = 1, fb do
                bp = bp + 1
                local _, np8 = varint(bytecode, bp)
                bp = np8
            end
        end

        pos = blob_end or bp
        protos[pi] = {
            insns = insns,
            constants = constants,
            strings = proto_strings,
        }
    end

    return protos
end

local function extract_proto_patterns(proto, add)
    local insns = proto.insns
    local constants = proto.constants
    local strings = proto.strings

    for i = 1, #strings do
        add("string:" .. strings[i])
    end

    if #insns == 0 then
        return
    end

    local previous, starts, ops, As, Bs, Cs = build_meta(insns, false)

    if not previous then
        previous, starts, ops, As, Bs, Cs = build_meta(insns, true)
        if not previous then
            return
        end
    end

    local total = #insns
    local pc = 1

    while pc <= total do
        local op = ops[pc]
        local len = TWO_WORD_OP[op] and 2 or 1
        local a = As[pc]
        local b = Bs[pc]
        local c = Cs[pc]
        local aux = insns[pc + 1] or 0

        if op == 22 then
            if b == 1 then
                add("return:void")
            else
                local pat = find_return_pattern(pc, a, ops, As, Bs, Cs, previous)
                add(pat or "return:value")
            end
        elseif op == 21 or op == 87 then
            local cp = find_call_pattern(insns, pc, a, constants, previous, ops, As, Bs, Cs)
            if cp then
                add(cp)
            end
        elseif op == 20 then
            local key = get_string(constants, aux + 1)
            if key and is_call_target(pc, len, a, starts, ops, As) then
                add("method:" .. key)
                add("call:" .. key)
            end
        elseif op == 85 then
            local key = get_string(constants, (aux % 65536) + 1)
            if key and is_call_target(pc, len, a, starts, ops, As) then
                add("method:" .. key)
                add("call:" .. key)
            end
        elseif op == 15 then
            local key = get_string(constants, aux + 1)
            if key and not is_call_target(pc, len, a, starts, ops, As) then
                add("get:" .. key)
            end
        elseif op == 83 then
            local key = get_string(constants, (aux % 65536) + 1)
            if key and not is_call_target(pc, len, a, starts, ops, As) then
                add("get:" .. key)
            end
        elseif op == 16 then
            local key = get_string(constants, aux + 1)
            if key then
                add("set:" .. key)
            end
        elseif op == 84 then
            local key = get_string(constants, (aux % 65536) + 1)
            if key then
                add("set:" .. key)
            end
        elseif op == 7 then
            local key = get_string(constants, aux + 1)
            if key and not is_call_target(pc, len, a, starts, ops, As) then
                add("get:" .. key)
            end
        elseif op == 8 then
            local key = get_string(constants, aux + 1)
            if key then
                add("set:" .. key)
            end
        elseif op == 12 then
            if not is_call_target(pc, len, a, starts, ops, As) then
                local dfield = b + c * 256
                local cst = constants[dfield + 1]
                local path = decode_import(constants, cst)
                if path then
                    add("import:" .. path)
                    add("get:" .. path)
                end
            end
        elseif op == 56 or op == 57 then
            add("loop:for-num")
        elseif op == 61 then
            add("loop:for-in-next")
        elseif op == 59 then
            add("loop:for-in-inext")
        elseif op == 76 or op == 58 then
            add("loop:for-in")
        elseif op == 24 then
            add("loop:jumpback")
        elseif op == 25 then
            if is_andor_jump(pc, starts, ops, Bs, Cs) then
                add("cond:or")
            else
                add("if:then")
            end
        elseif op == 26 then
            if is_andor_jump(pc, starts, ops, Bs, Cs) then
                add("cond:and")
            else
                add("if:then")
                add("if:not-then")
            end
        elseif op == 27 then
            add("if:eq")
        elseif op == 30 then
            add("if:ne")
        elseif op == 28 then
            add("if:le")
        elseif op == 29 then
            add("if:lt")
        elseif op == 31 then
            add("if:gt")
        elseif op == 32 then
            add("if:ge")
        elseif op == 77 or op == 78 or op == 79 or op == 80 then
            if aux >= 2147483648 then
                add("if:ne")
            else
                add("if:eq")
            end
        elseif op == 45 or op == 47 then
            add("cond:and")
        elseif op == 46 or op == 48 then
            add("cond:or")
        elseif op == 50 then
            add("cond:not")
        elseif op == 19 then
            add("function:closure")
        elseif op == 64 then
            add("function:dup")
        elseif op == 63 then
            add("vararg:get")
        elseif op == 53 then
            add("table:new")
        elseif op == 54 then
            add("table:dup")
        elseif op == 55 then
            add("table:setlist")
        elseif op == 49 then
            add("concat")
        elseif op == 33 or op == 39 then
            add("arith:add")
        elseif op == 34 or op == 40 or op == 71 then
            add("arith:sub")
        elseif op == 35 or op == 41 then
            add("arith:mul")
        elseif op == 36 or op == 42 or op == 72 then
            add("arith:div")
        elseif op == 37 or op == 43 then
            add("arith:mod")
        elseif op == 38 or op == 44 then
            add("arith:pow")
        elseif op == 81 or op == 82 then
            add("arith:idiv")
        elseif op == 52 then
            add("arith:length")
        elseif op == 68 or op == 73 or op == 74 or op == 75 or op == 60 then
            local bname = BUILTIN_NAMES[a]
            if bname then
                add("call:" .. bname)
            end
        elseif op == 89 then
            if a == 0 then
                add("call:pcall")
            elseif a == 1 then
                add("call:xpcall")
            end
        end

        pc = pc + len
    end
end

local function get_entry(bytecode)
    if type(bytecode) ~= "string" or #bytecode < 2 then
        return false
    end

    local hit = cache[bytecode]
    if hit ~= nil then
        return hit
    end

    local ok, protos = pcall(parse, bytecode)
    local found, set = {}, {}

    local function add(p)
        if p and #p > 0 and not set[p] then
            set[p] = true
            found[#found + 1] = p
        end
    end

    if ok and protos then
        for i = 1, #protos do
            extract_proto_patterns(protos[i], add)
        end
    end

    local entry
    if #found > 0 then
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
    local sorted = entry.sorted

    if not sorted then
        local list = entry.list
        sorted = {}
        for i = 1, #list do
            sorted[i] = list[i]
        end
        sort(sorted)
        entry.sorted = sorted
    end

    local n = #sorted
    if n == 0 then
        return false
    end
    if needle == "" then
        return true
    end

    local lo, hi = 1, n
    while lo < hi do
        local mid = fdiv(lo + hi, 2)
        if sorted[mid] < needle then
            lo = mid + 1
        else
            hi = mid
        end
    end

    return sub(sorted[lo], 1, #needle) == needle
end

function M.filter(bytecodes, terms)
    local nterms = #terms
    local prefixes, fragments, needles = {}, {}, {}

    for t = 1, nterms do
        local term = terms[t]

        if type(term) ~= "string" or #term == 0 then
            return {}
        end

        local prefix = sub(term, -1) == "*"
        local fragment = sub(term, 1, 1) == "~"

        prefixes[t] = prefix
        fragments[t] = fragment
        needles[t] = prefix and sub(term, 1, -2) or (fragment and sub(term, 2) or term)
    end

    local matches = {}

    if nterms == 0 then
        for i = 1, #bytecodes do
            local bc = bytecodes[i]
            if type(bc) == "string" and #bc > 0 and get_entry(bc) then
                matches[#matches + 1] = i
            end
        end
        return matches
    end

    for i = 1, #bytecodes do
        local bc = bytecodes[i]

        if type(bc) == "string" and #bc > 0 then
            local entry = get_entry(bc)

            if entry then
                local all = true

                for t = 1, nterms do
                    local needle = needles[t]
                    local ok

                    if fragments[t] then
                        ok = list_contains(entry.list, needle)
                    elseif prefixes[t] then
                        ok = has_prefix(entry, needle)
                    else
                        ok = entry.set[needle] == true
                    end

                    if not ok then
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
    local entry = get_entry(bytecode)
    return entry and entry.list or false
end

function M.clear()
    cache = {}
end

M.version = "2.4.1"

return M
