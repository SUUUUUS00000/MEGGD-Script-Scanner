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

local function varint(s, pos)
    local result, shift = 0, 0
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

local function u32(s, pos)
    local b1, b2, b3, b4 = s:byte(pos, pos + 3)
    if not b1 or not b2 or not b3 or not b4 then error("eof u32") end
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function fdiv(a, b) return math.floor(a / b) end

local function check_mode(insns, encoded)
    local pc = 1
    local total = #insns
    while pc <= total do
        local op = insns[pc] % 256
        if encoded then op = (op * 203) % 256 end
        if op >= OP_COUNT then return false end
        local name = OP_NAMES[op]
        if name == nil then return false end
        pc = pc + (TWO_WORD[name] and 2 or 1)
    end
    return pc == total + 1
end

local function decode_opcodes(insns)
    if #insns == 0 then return false end
    if check_mode(insns, false) then return false end
    if check_mode(insns, true) then return true end
    return nil
end

local function decode_instr(insn, encoded)
    local op = insn % 256
    if encoded then op = (op * 203) % 256 end
    local name = OP_NAMES[op] or "?"
    local a = fdiv(insn, 256) % 256
    local b = fdiv(insn, 65536) % 256
    local c = fdiv(insn, 16777216) % 256
    return op, name, a, b, c
end

local function get_string(constants, idx1)
    if idx1 < 1 or idx1 > #constants then return nil end
    local c = constants[idx1]
    if c and c.type == 3 then return c.value end
    return nil
end

local function decode_import(constants, c)
    if not c or c.type ~= 4 or not c.import then return nil end
    local parts = {}
    for i = 1, #c.import do
        local s = get_string(constants, c.import[i] + 1)
        if s then parts[#parts + 1] = s end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ".")
end

local function build_instruction_layout(insns, encoded)
    local previous, next_pc, starts = {}, {}, {}
    local pc, prior = 1, nil
    while pc <= #insns do
        starts[pc] = true
        if prior then next_pc[prior] = pc; previous[pc] = prior end
        local _, name = decode_instr(insns[pc], encoded)
        local len = TWO_WORD[name] and 2 or 1
        if pc + len - 1 > #insns then return nil end
        prior = pc
        pc = pc + len
    end
    return previous, next_pc, starts
end

local function is_andor_jump(insns, pc, encoded, starts)
    local insn = insns[pc]
    local d = fdiv(insn, 65536) % 65536
    if d >= 32768 then d = d - 65536 end
    local target = pc + 1 + d
    local ti = insns[target]
    if ti and (not starts or starts[target]) then
        local _, tname, _, _, tc = decode_instr(ti, encoded)
        if tname == "LOADB" and tc ~= 0 then return true end
        if tname == "MOVE" then return true end
    end
    return false
end

local function is_call_target(insns, pc, len, encoded, reg, starts)
    local next_pc = pc + len
    if starts and not starts[next_pc] then return false end
    local nxt = insns[next_pc]
    if not nxt then return false end
    local _, nname, na = decode_instr(nxt, encoded)
    return (nname == "CALL" or nname == "CALLFB") and na == reg
end

local function find_return_pattern(insns, pc, a, encoded, constants, previous)
    local target = a
    local prev_pc = previous[pc]
    while prev_pc do
        local prev = insns[prev_pc]
        local _, name, pa, pb, pcc = decode_instr(prev, encoded)
        local writes = false
        if name == "LOADB" or name == "LOADNIL" or name == "LOADN" or name == "LOADK" or
           name == "MOVE" or name == "GETGLOBAL" or name == "GETUPVAL" or name == "GETIMPORT" or
           name == "GETTABLEKS" or name == "GETTABLE" or name == "GETTABLEN" or name == "LOADKX" or
           name == "GETUDATAKS" or name == "GETPRIVATEFIELD" or name == "GETVARARGS" or
           name == "NEWTABLE" or name == "DUPTABLE" or name == "NEWCLOSURE" or name == "DUPCLOSURE" or
           name == "NEWCLASS" or name == "CONSTRUCT" or
           name == "ADD" or name == "SUB" or name == "MUL" or name == "DIV" or name == "MOD" or name == "POW" or
           name == "AND" or name == "OR" or name == "CONCAT" or name == "NOT" or name == "MINUS" or name == "LENGTH" or
           name == "ADDK" or name == "SUBK" or name == "MULK" or name == "DIVK" or name == "MODK" or name == "POWK" or
           name == "ANDK" or name == "ORK" or name == "SUBRK" or name == "DIVRK" then
            writes = (pa == target)
        elseif name == "CALL" or name == "CALLFB" then
            local nres = pcc - 1
            if nres == 0 then writes = false
            elseif nres < 0 then writes = (target >= pa)
            else writes = (target >= pa and target < pa + nres) end
        elseif name == "NAMECALL" or name == "NAMECALLUDATA" then
            writes = (pa == target or pa + 1 == target)
        end
        if writes then
            if name == "LOADB" then
                if pb == 0 then return "return:false" end
                if pb == 1 then return "return:true" end
                return nil
            elseif name == "LOADNIL" then return "return:nil"
            elseif name == "CALL" or name == "CALLFB" then return "return:call"
            elseif name == "MOVE" then target = pb
            else return nil end
        end
        prev_pc = previous[prev_pc]
    end
    return nil
end

local function instruction_writes_register(insns, pc, encoded, target)
    local insn = insns[pc]
    if not insn then return false end
    local _, name, a, b, c = decode_instr(insn, encoded)
    if name == "LOADNIL" or name == "LOADB" or name == "LOADN" or name == "LOADK" or
       name == "MOVE" or name == "GETGLOBAL" or name == "GETUPVAL" or name == "GETIMPORT" or
       name == "GETTABLE" or name == "GETTABLEKS" or name == "GETTABLEN" or name == "GETUDATAKS" or
       name == "GETPRIVATEFIELD" or name == "LOADKX" or name == "NEWTABLE" or name == "DUPTABLE" or
       name == "NEWCLOSURE" or name == "DUPCLOSURE" or name == "NEWCLASS" or name == "CONSTRUCT" or
       name == "ADD" or name == "SUB" or name == "MUL" or name == "DIV" or name == "MOD" or name == "POW" or
       name == "ADDK" or name == "SUBK" or name == "MULK" or name == "DIVK" or name == "MODK" or name == "POWK" or
       name == "AND" or name == "OR" or name == "ANDK" or name == "ORK" or name == "CONCAT" or
       name == "NOT" or name == "MINUS" or name == "LENGTH" or name == "SUBRK" or name == "DIVRK" or
       name == "IDIV" or name == "IDIVK" then
        return target == a
    elseif name == "NAMECALL" or name == "NAMECALLUDATA" then
        return target == a or target == a + 1
    elseif name == "CALL" or name == "CALLFB" then
        local nresults = c - 1
        if nresults == 0 then return false end
        return target >= a and (nresults < 0 or target < a + nresults)
    elseif name == "GETVARARGS" then
        return target >= a and (b == 0 or target < a + b - 1)
    elseif name == "FORGLOOP" then
        local aux = insns[pc + 1] or 0
        local count = aux % 256
        return target >= a + 2 and target < a + 3 + count
    elseif name == "FORNLOOP" then
        return target >= a + 2 and target <= a + 3
    elseif name == "FORGPREP" or name == "FORGPREP_INEXT" or name == "FORGPREP_NEXT" or name == "FORNPREP" then
        return target >= a and target <= a + 3
    end
    return false
end

local function find_call_pattern(insns, pc, a, encoded, constants, previous)
    local target = a
    local prev_pc = previous[pc]
    while prev_pc do
        local prev = insns[prev_pc]
        local _, name, pa, pb = decode_instr(prev, encoded)
        if instruction_writes_register(insns, prev_pc, encoded, target) then
            if name == "GETTABLEKS" or name == "GETGLOBAL" then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, aux + 1)
                if key then return "call:" .. key end
                return nil
            elseif name == "GETUDATAKS" then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, (aux % 65536) + 1)
                if key then return "call:" .. key end
                return nil
            elseif name == "GETIMPORT" then
                local dfield = fdiv(prev, 65536) % 65536
                local path = decode_import(constants, constants[dfield + 1])
                if path then
                    local last = path:match("([^.]+)$") or path
                    return "call:" .. last
                end
                return nil
            elseif name == "NAMECALL" then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, aux + 1)
                if key then return "call:" .. key end
                return nil
            elseif name == "NAMECALLUDATA" then
                local aux = insns[prev_pc + 1] or 0
                local key = get_string(constants, (aux % 65536) + 1)
                if key then return "call:" .. key end
                return nil
            elseif name == "MOVE" then
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
    local version = bytecode:byte(pos); pos = pos + 1
    if not version or version < 3 or (version > 14 and version ~= 100) then error("bad version") end
    local typesversion = 0
    if version >= 4 then typesversion = bytecode:byte(pos); pos = pos + 1 end
    local str_count; str_count, pos = varint(bytecode, pos)
    local strings = {}
    for i = 1, str_count do
        local len; len, pos = varint(bytecode, pos)
        strings[i] = bytecode:sub(pos, pos + len - 1)
        pos = pos + len
    end
    if typesversion == 3 then
        while true do
            local tag = bytecode:byte(pos); pos = pos + 1
            if tag == nil or tag == 0 then break end
            local _, np = varint(bytecode, pos); pos = np
        end
    end
    local proto_count; proto_count, pos = varint(bytecode, pos)
    local has_size = version >= 12 or version == 100
    local protos = {}
    for pi = 1, proto_count do
        local blob_end
        if has_size then
            local sz; sz, pos = varint(bytecode, pos)
            blob_end = pos + sz
            if blob_end > #bytecode then break end
        end
        local bp = pos + 4
        local is_vararg = bytecode:byte(pos + 3) ~= 0
        if version >= 4 then
            bp = bp + 1
            local tsize, np = varint(bytecode, bp); bp = np + tsize
        end
        local insn_count; insn_count, bp = varint(bytecode, bp)
        local insns = {}
        for i = 1, insn_count do insns[i] = u32(bytecode, bp); bp = bp + 4 end
        local const_count; const_count, bp = varint(bytecode, bp)
        local constants = {}
        for ci = 1, const_count do
            local ctype = bytecode:byte(bp); bp = bp + 1
            local c = {type = ctype}
            if ctype == 0 then
            elseif ctype == 1 then c.value = bytecode:byte(bp) ~= 0; bp = bp + 1
            elseif ctype == 2 then bp = bp + 8
            elseif ctype == 3 then
                local sidx; sidx, bp = varint(bytecode, bp)
                c.value = strings[sidx]
            elseif ctype == 4 then
                local iid = u32(bytecode, bp); bp = bp + 4
                local cnt = fdiv(iid, 1073741824) % 4
                local ids = {fdiv(iid, 1048576) % 1024, fdiv(iid, 1024) % 1024, iid % 1024}
                c.import = {}
                for k = 1, cnt do c.import[k] = ids[k] end
            elseif ctype == 5 then
                local n; n, bp = varint(bytecode, bp)
                for _ = 1, n do local _, np = varint(bytecode, bp); bp = np end
            elseif ctype == 6 then local _, np = varint(bytecode, bp); bp = np
            elseif ctype == 7 then bp = bp + 16
            elseif ctype == 8 then
                local n; n, bp = varint(bytecode, bp)
                for _ = 1, n do local _, np = varint(bytecode, bp); bp = np + 4 end
            elseif ctype == 9 then
                bp = bp + 1
                local _, np = varint(bytecode, bp); bp = np
            elseif ctype == 10 then bp = bp + 32
            elseif ctype == 11 then
                local _, np = varint(bytecode, bp); bp = np
                local pc2, np2 = varint(bytecode, bp); bp = np2
                local mc, np3 = varint(bytecode, bp); bp = np3
                for _ = 1, pc2 do local _, np4 = varint(bytecode, bp); bp = np4 end
                for _ = 1, mc do local _, np5 = varint(bytecode, bp); bp = np5 end
            else break end
            constants[ci] = c
        end
        local child_count; child_count, bp = varint(bytecode, bp)
        for _ = 1, child_count do local _, np = varint(bytecode, bp); bp = np end
        local _, np2 = varint(bytecode, bp); bp = np2
        local _, np3 = varint(bytecode, bp); bp = np3
        if bytecode:byte(bp) == 1 then
            local linegap = bytecode:byte(bp + 1)
            local intervals = 1
            if insn_count > 0 then intervals = fdiv(insn_count - 1, 2 ^ linegap) + 1 end
            bp = bp + 2 + insn_count + intervals * 4
        else bp = bp + 1 end
        if bytecode:byte(bp) == 1 then
            bp = bp + 1
            local lc; lc, bp = varint(bytecode, bp)
            for _ = 1, lc do
                local _, np4 = varint(bytecode, bp); bp = np4
                local _, np5 = varint(bytecode, bp); bp = np5
                local _, np6 = varint(bytecode, bp); bp = np6
                bp = bp + 1
            end
            local uc; uc, bp = varint(bytecode, bp)
            for _ = 1, uc do local _, np7 = varint(bytecode, bp); bp = np7 end
        else bp = bp + 1 end
        if version >= 11 or version == 100 then
            local fb; fb, bp = varint(bytecode, bp)
            for _ = 1, fb do
                bp = bp + 1
                local _, np8 = varint(bytecode, bp); bp = np8
            end
        end
        pos = blob_end or bp
        protos[pi] = {insns = insns, constants = constants, is_vararg = is_vararg}
    end
    return {protos = protos, strings = strings}
end

local function extract_proto_patterns(proto, add)
    local insns = proto.insns
    local constants = proto.constants
    for _, c in ipairs(constants) do
        if c.type == 3 and c.value and #c.value > 0 then
            add("string:" .. c.value)
        end
    end
    if #insns == 0 then return end
    local encoded = decode_opcodes(insns)
    if encoded == nil then return end
    local previous, _, starts = build_instruction_layout(insns, encoded)
    if not previous then return end
    local pc = 1
    while pc <= #insns do
        local insn = insns[pc]
        local _, name, a, b, c = decode_instr(insn, encoded)
        if name == "?" then pc = pc + 1
        else
            local len = TWO_WORD[name] and 2 or 1
            local aux = insns[pc + 1] or 0
            if name == "RETURN" then
                if b == 1 then
                    add("return:void")
                else
                    local pat = find_return_pattern(insns, pc, a, encoded, constants, previous)
                    add(pat or "return:value")
                end
            elseif name == "CALL" or name == "CALLFB" then
                local cp = find_call_pattern(insns, pc, a, encoded, constants, previous)
                if cp then add(cp) end
            elseif name == "NAMECALL" then
                local key = get_string(constants, aux + 1)
                if key and is_call_target(insns, pc, len, encoded, a, starts) then
                    add("method:" .. key)
                    add("call:" .. key)
                end
            elseif name == "NAMECALLUDATA" then
                local key = get_string(constants, (aux % 65536) + 1)
                if key and is_call_target(insns, pc, len, encoded, a, starts) then
                    add("method:" .. key)
                    add("call:" .. key)
                end
            elseif name == "GETTABLEKS" then
                local key = get_string(constants, aux + 1)
                if key and not is_call_target(insns, pc, len, encoded, a, starts) then
                    add("get:" .. key)
                end
            elseif name == "GETUDATAKS" then
                local key = get_string(constants, (aux % 65536) + 1)
                if key and not is_call_target(insns, pc, len, encoded, a, starts) then
                    add("get:" .. key)
                end
            elseif name == "SETTABLEKS" then
                local key = get_string(constants, aux + 1)
                if key then add("set:" .. key) end
            elseif name == "SETUDATAKS" then
                local key = get_string(constants, (aux % 65536) + 1)
                if key then add("set:" .. key) end
            elseif name == "GETGLOBAL" then
                local key = get_string(constants, aux + 1)
                if key and not is_call_target(insns, pc, len, encoded, a, starts) then
                    add("get:" .. key)
                end
            elseif name == "SETGLOBAL" then
                local key = get_string(constants, aux + 1)
                if key then add("set:" .. key) end
            elseif name == "GETIMPORT" then
                if not is_call_target(insns, pc, len, encoded, a, starts) then
                    local dfield = fdiv(insn, 65536) % 65536
                    local c = constants[dfield + 1]
                    local path = decode_import(constants, c)
                    if path then
                        add("import:" .. path)
                        add("get:" .. path)
                    end
                end
            elseif name == "FORNPREP" or name == "FORNLOOP" then
                add("loop:for-num")
            elseif name == "FORGPREP_NEXT" then
                add("loop:for-in-next")
            elseif name == "FORGPREP_INEXT" then
                add("loop:for-in-inext")
            elseif name == "FORGPREP" or name == "FORGLOOP" then
                add("loop:for-in")
            elseif name == "JUMPBACK" then
                add("loop:jumpback")
            elseif name == "JUMPIF" then
                if is_andor_jump(insns, pc, encoded, starts) then
                    add("cond:or")
                else
                    add("if:then")
                end
            elseif name == "JUMPIFNOT" then
                if is_andor_jump(insns, pc, encoded, starts) then
                    add("cond:and")
                else
                    add("if:then")
                    add("if:not-then")
                end
            elseif name == "JUMPIFEQ" then
                add("if:eq")
            elseif name == "JUMPIFNOTEQ" then
                add("if:ne")
            elseif name == "JUMPIFLE" then
                add("if:le")
            elseif name == "JUMPIFLT" then
                add("if:lt")
            elseif name == "JUMPIFNOTLE" then
                add("if:gt")
            elseif name == "JUMPIFNOTLT" then
                add("if:ge")
            elseif name == "JUMPXEQKNIL" or name == "JUMPXEQKB" or name == "JUMPXEQKN" or name == "JUMPXEQKS" then
                if fdiv(aux, 2147483648) == 1 then
                    add("if:ne")
                else
                    add("if:eq")
                end
            elseif name == "AND" or name == "ANDK" then
                add("cond:and")
            elseif name == "OR" or name == "ORK" then
                add("cond:or")
            elseif name == "NOT" then
                add("cond:not")
            elseif name == "NEWCLOSURE" then
                add("function:closure")
            elseif name == "DUPCLOSURE" then
                add("function:dup")
            elseif name == "GETVARARGS" then
                add("vararg:get")
            elseif name == "NEWTABLE" then
                add("table:new")
            elseif name == "DUPTABLE" then
                add("table:dup")
            elseif name == "SETLIST" then
                add("table:setlist")
            elseif name == "CONCAT" then
                add("concat")
            elseif name == "ADD" or name == "ADDK" then
                add("arith:add")
            elseif name == "SUB" or name == "SUBK" or name == "SUBRK" then
                add("arith:sub")
            elseif name == "MUL" or name == "MULK" then
                add("arith:mul")
            elseif name == "DIV" or name == "DIVK" or name == "DIVRK" then
                add("arith:div")
            elseif name == "MOD" or name == "MODK" then
                add("arith:mod")
            elseif name == "POW" or name == "POWK" then
                add("arith:pow")
            elseif name == "IDIV" or name == "IDIVK" then
                add("arith:idiv")
            elseif name == "LENGTH" then
                add("arith:length")
            elseif name == "FASTCALL" or name == "FASTCALL1" or name == "FASTCALL2" or
                   name == "FASTCALL2K" or name == "FASTCALL3" then
                local bname = BUILTIN_NAMES[a]
                if bname then add("call:" .. bname) end
            elseif name == "FASTPCALL" then
                if a == 0 then add("call:pcall")
                elseif a == 1 then add("call:xpcall") end
            end
            pc = pc + len
        end
    end
end

local function get_patterns(bytecode)
    if type(bytecode) ~= "string" or #bytecode < 2 then return false end
    local hit = cache[bytecode]
    if hit ~= nil then return hit end
    local ok, parsed = pcall(parse, bytecode)
    local patterns
    if ok and parsed then
        local found, seen = {}, {}
        local function add(p)
            if p and #p > 0 and not seen[p] then seen[p] = true; found[#found + 1] = p end
        end
        for _, proto in ipairs(parsed.protos) do
            extract_proto_patterns(proto, add)
        end
        if #found > 0 then patterns = found end
    end
    if not patterns or #patterns == 0 then patterns = false end
    cache[bytecode] = patterns
    return patterns
end

function M.filter(bytecodes, terms)
    local matches = {}
    for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc > 0 then
            local patterns = get_patterns(bc)
            if patterns then
                local all = true
                for t = 1, #terms do
                    local term = terms[t]
                    local found = false
                    if type(term) == "string" and #term > 0 then
                        local prefix = term:sub(-1) == "*"
                        local fragment = term:sub(1, 1) == "~"
                        local needle = prefix and term:sub(1, -2) or (fragment and term:sub(2) or term)
                        for j = 1, #patterns do
                            local pattern = patterns[j]
                            if (prefix and pattern:sub(1, #needle) == needle) or
                               (fragment and pattern:find(needle, 1, true) ~= nil) or
                               (not prefix and not fragment and pattern == needle) then
                                found = true
                                break
                            end
                        end
                    end
                    if not found then all = false; break end
                end
                if all then matches[#matches + 1] = i end
            end
        end
    end
    return matches
end

function M.words(bytecode) return get_patterns(bytecode) end
function M.clear() cache = {} end

M.version = "2.4.0"

return M
