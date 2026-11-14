local M = {}
local cache = {}
local hdr_cache = {}

local OP_LEN = {
  1,1,1,1,1,1,1,2,2,1,1,1,2,1,1,2,
  2,1,1,1,2,1,1,1,1,1,1,2,2,2,2,2,
  2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,2,1,2,1,1,2,1,2,1,1,1,
  1,1,2,1,1,1,1,1,1,1,2,2,1,2,2,2,
  2,1,1,2,2,2,2,2,2,1,2,2,1,2,2,
}

local OP_STEP = table.create(95)
for i = 1, 95 do OP_STEP[i] = OP_LEN[i] * 4 end

local TAG_STRINGS = {
  "return:void","return:value","return:call","return:nil","return:false","return:true",
  "if:then","if:not-then","cond:and","cond:or","cond:not","if:eq","if:ne","if:le","if:lt","if:gt","if:ge",
  "loop:for-num","loop:for-in","loop:for-in-next","loop:for-in-inext","loop:jumpback",
  "function:closure","function:dup","vararg:get","table:new","table:dup","table:setlist",
  "concat","arith:add","arith:sub","arith:mul","arith:div","arith:mod","arith:pow","arith:idiv","arith:length",
  "call:pcall","call:xpcall",
}

local OP_FAST = table.create(95, 0)
for _, op in ipairs({0,1,10,11,14,18,23,62,65,67,69,70,88,92,94}) do OP_FAST[op + 1] = 1 end
for _, op in ipairs({4,5,9,13,17,51,66,90,91,93}) do OP_FAST[op + 1] = 2 end
for op, tid in pairs({[24]=22,[27]=12,[28]=14,[29]=15,[30]=13,[31]=16,[32]=17,[55]=28}) do OP_FAST[op + 1] = tid end
for op, tid in pairs({
  [19]=23,[33]=30,[34]=31,[35]=32,[36]=33,[37]=34,[38]=35,[39]=30,[40]=31,[41]=32,[42]=33,[43]=34,[44]=35,
  [45]=9,[46]=10,[47]=9,[48]=10,[49]=29,[50]=11,[52]=37,[53]=26,[54]=27,[64]=24,[71]=31,[72]=33,[81]=36,[82]=36,
}) do OP_FAST[op + 1] = 100 + tid end

local BUILTIN_CALLS = {
  "assert","math.abs","math.acos","math.asin","math.atan2","math.atan","math.ceil","math.cosh","math.cos",
  "math.deg","math.exp","math.floor","math.fmod","math.frexp","math.ldexp","math.log10","math.log","math.max",
  "math.min","math.modf","math.pow","math.rad","math.sinh","math.sin","math.sqrt","math.tanh","math.tan",
  "bit32.arshift","bit32.band","bit32.bnot","bit32.bor","bit32.bxor","bit32.btest","bit32.extract",
  "bit32.lrotate","bit32.lshift","bit32.replace","bit32.rrotate","bit32.rshift",
  "type","string.byte","string.char","string.len","typeof","string.sub","math.clamp","math.sign","math.round",
  "rawset","rawget","rawequal","table.insert","table.unpack","vector","bit32.countlz","bit32.countrz",
  "select","rawlen","bit32.extractk","getmetatable","setmetatable","tonumber","tostring","bit32.byteswap",
  "buffer.readi8","buffer.readu8","buffer.writeu8","buffer.readi16","buffer.readu16","buffer.writeu16",
  "buffer.readi32","buffer.readu32","buffer.writeu32","buffer.readf32","buffer.writef32","buffer.readf64","buffer.writef64",
  "vector.magnitude","vector.normalize","vector.cross","vector.dot","vector.floor","vector.ceil","vector.abs",
  "vector.sign","vector.clamp","vector.min","vector.max","math.lerp","vector.lerp","math.isnan","math.isinf","math.isfinite",
  "integer.create","integer.tonumber","integer.neg","integer.add","integer.sub","integer.mul","integer.div",
  "integer.min","integer.max","integer.rem","integer.idiv","integer.udiv","integer.urem","integer.mod","integer.clamp",
  "integer.band","integer.bor","integer.bnot","integer.bxor","integer.lt","integer.le","integer.ult","integer.ule",
  "integer.gt","integer.ge","integer.ugt","integer.uge","integer.lshift","integer.rshift","integer.arshift",
  "integer.lrotate","integer.rrotate","integer.extract","integer.btest","integer.countrz","integer.countlz","integer.bswap",
  "buffer.readinteger","buffer.writeinteger","table.create","table.clear",
}

local BUILTIN_LIST = { "pcall", "xpcall" }
for id, name in ipairs(BUILTIN_CALLS) do
  TAG_STRINGS[100 + id] = "call:" .. name
  BUILTIN_LIST[#BUILTIN_LIST + 1] = name
end

local TAG_ID_BY_NAME = {}
local TAG_NUL = table.create(240)
local TAG_NLEN = table.create(240)
local static_parts = {}
for id, str in pairs(TAG_STRINGS) do
  TAG_ID_BY_NAME[str] = id
  local nul = str .. "\0"
  TAG_NUL[id] = nul
  TAG_NLEN[id] = #nul
  static_parts[#static_parts + 1] = str
end
local STATIC_CI_HAYSTACK = "\0" .. string.lower(table.concat(static_parts, "\0")) .. "\0"

local BUILTIN_RAW_ID = {}
local BUILTIN_B0_MAP = {}
for id, str in pairs(TAG_STRINGS) do
  if string.sub(str, 1, 5) == "call:" then
    local raw_name = string.sub(str, 6)
    if not string.find(raw_name, ".", 1, true) then
      BUILTIN_RAW_ID[raw_name] = id
      BUILTIN_B0_MAP[string.byte(raw_name, 1)] = true
    end
  end
end

local HINT_TAGS = { string=true, get=true, set=true, method=true, func=true, ["local"]=true, upval=true, call=true, import=true }

local ENCODE_OP = table.create(256)
local ENCODE_STEP = table.create(256, 0)
for i = 0, 255 do
  local dec = (i * 203) % 256
  ENCODE_OP[i + 1] = dec
  ENCODE_STEP[i + 1] = OP_STEP[dec + 1] or 0
end

local byte, sub, slower, supper, sfind, smatch = string.byte, string.sub, string.lower, string.upper, string.find, string.match
local band, rshift, tclear, tcreate = bit32.band, bit32.rshift, table.clear, table.create
local os_clock = os and os.clock
local task_wait = task and task.wait

local scratch_str_off, scratch_str_len, scratch_str_flags = {}, {}, {}
local scratch_constants, scratch_const_sidx = {}, {}
local scratch_import_gen, scratch_import_paths, scratch_import_calls, scratch_import_sidx = {}, {}, {}, {}
local scratch_reg_call, scratch_reg_ret = tcreate(256), tcreate(256)
local scratch_imp_seen, scratch_tag_seen = {}, tcreate(240, 0)
local scratch_max_reg, import_gen_counter, script_gen_counter = 0, 0, 0
local scratch_blob_cap = 65536
local scratch_blob_buf = buffer.create(scratch_blob_cap)

local function grow_blob(wbuf: buffer, wpos: number, wcap: number, need: number): (buffer, number)
  repeat wcap = wcap * 2 until wcap >= need
  local nb = buffer.create(wcap)
  buffer.copy(nb, 0, wbuf, 0, wpos)
  return nb, wcap
end

local function get_str_table_slice(bc: string): string?
  local sbyte, blen = string.byte, #bc
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
      result = result + (b - 128) * mul; mul = mul * 128
    end
  end
  local str_start, rem = pos, str_count
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
    pos = p4 + 1 + s4; rem = rem - 4
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
        result = result + (b - 128) * mul; mul = mul * 128
      end
    end
    rem = rem - 1
  end
  if pos - 1 > blen then return nil end
  if pos <= str_start then return "" end
  return string.sub(bc, str_start, pos - 1)
end

local function decode_import(buf: buffer, constants: {number}, const_sidx: {number}, const_count: number, str_off: {number}, str_len: {number}, idx1: number, active_imp_gen: number)
  if idx1 < 1 or idx1 > const_count or const_sidx[idx1] ~= -1 then return nil, nil, 0 end
  local import_gen, import_paths, import_calls, import_sidx = scratch_import_gen, scratch_import_paths, scratch_import_calls, scratch_import_sidx
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
  local breadstring = buffer.readstring
  local s1 = idx_s1 > 0 and breadstring(buf, str_off[idx_s1], str_len[idx_s1]) or nil
  local s2 = idx_s2 > 0 and breadstring(buf, str_off[idx_s2], str_len[idx_s2]) or nil
  local s3 = idx_s3 > 0 and breadstring(buf, str_off[idx_s3], str_len[idx_s3]) or nil
  local path, last, last_k
  if s1 and s2 and s3 then path, last, last_k = s1 .. "." .. s2 .. "." .. s3, s3, idx_s3
  elseif s1 and s2 then path, last, last_k = s1 .. "." .. s2, s2, idx_s2
  elseif s1 and s3 then path, last, last_k = s1 .. "." .. s3, s3, idx_s3
  elseif s2 and s3 then path, last, last_k = s2 .. "." .. s3, s3, idx_s3
  else path = s1 or s2 or s3; last = path; last_k = (s1 and idx_s1) or (s2 and idx_s2) or idx_s3 end
  if not path then import_paths[idx1] = false; return nil, nil, 0 end
  local short = smatch(last, "([^.]+)$") or last
  local call_pat = "call:" .. short
  local last_sidx = short == last and last_k or 0
  import_paths[idx1], import_calls[idx1], import_sidx[idx1] = path, call_pat, last_sidx
  return path, call_pat, last_sidx
end

local function read_varint_tail_buf(buf: buffer, pos: number, len: number, b0: number): (number, number)
  local breadu8, result, mul = buffer.readu8, b0 - 128, 128
  pos = pos + 1
  while true do
    if pos >= len then error("eof") end
    local b = breadu8(buf, pos)
    pos = pos + 1
    if b < 128 then return result + b * mul, pos end
    result = result + (b - 128) * mul; mul = mul * 128
  end
end

@native
local function is_valid_stream_detect_buf(buf: buffer, insn_base: number, insn_end: number): (boolean, boolean)
  local off, certain_plain = insn_base, false
  while off < insn_end do
    local raw = buffer.readu8(buf, off)
    local step = OP_STEP[raw + 1]
    if not step then return false, false end
    local nxt = off + step
    if nxt > insn_end then return false, false end
    if not certain_plain and ENCODE_STEP[raw + 1] == 0 then certain_plain = true end
    off = nxt
  end
  return true, certain_plain
end

@native
local function is_valid_stream_true_buf(buf: buffer, insn_base: number, insn_end: number): boolean
  local off = insn_base
  while off < insn_end do
    local step = ENCODE_STEP[buffer.readu8(buf, off) + 1]
    if step == 0 then return false end
    local nxt = off + step
    if nxt > insn_end then return false end
    off = nxt
  end
  return true
end

@native
local function extract_proto_buf(buf: buffer, insn_base: number, insn_end: number, constants: {number}, const_sidx: {number}, const_count: number, str_off: {number}, str_len: {number}, str_flags: {number}, has_imports: boolean, encoded_mode: boolean?, tag_seen: {number}, script_gen: number, imp_seen: {[string]: boolean}, wbuf: buffer, wpos: number, wcap: number)
  if insn_base >= insn_end then return wbuf, wpos, wcap, encoded_mode end

  local breadu8, breadu16, breadi16, breadu32, breadstring = buffer.readu8, buffer.readu16, buffer.readi16, buffer.readu32, buffer.readstring
  local bcopy, bwriteu8, bwriteu32, bwritestring, band_fn = buffer.copy, buffer.writeu8, buffer.writeu32, buffer.writestring, bit32.band

  local use_encode: boolean
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
      return wbuf, wpos, wcap, encoded_mode
    end
  end

  local reg_call, reg_ret = scratch_reg_call, scratch_reg_ret
  if scratch_max_reg >= 1 then
    for r = 1, scratch_max_reg do reg_call[r] = nil; reg_ret[r] = nil end
  end
  scratch_max_reg = 256

  local active_imp_gen = 0
  if has_imports then
    import_gen_counter = import_gen_counter + 1
    active_imp_gen = import_gen_counter
  end

  local max_reg, off = 0, insn_base

  while off < insn_end do
    local op = breadu8(buf, off)
    if use_encode then op = ENCODE_OP[op + 1] end
    local op1 = op + 1
    local step = OP_STEP[op1]
    if not step then break end
    local nxt_off = off + step
    if nxt_off > insn_end then break end

    local emit_tid = 0
    local f = OP_FAST[op1]
    if f ~= 0 then
      if f == 1 then
      elseif f == 2 then
        local r1 = breadu8(buf, off + 1) + 1
        reg_call[r1] = nil; reg_ret[r1] = nil
      elseif f < 100 then
        emit_tid = f
      else
        emit_tid = f - 100
        local r1 = breadu8(buf, off + 1) + 1
        reg_call[r1] = nil; reg_ret[r1] = nil
      end
    elseif op == 15 or op == 7 or op == 83 then
      local a = breadu8(buf, off + 1)
      local r1 = a + 1
      local idx1 = (op == 83 and breadu16(buf, off + 4) or breadu32(buf, off + 4)) + 1
      local sidx = idx1 <= const_count and const_sidx[idx1] or 0
      if sidx > 0 and str_len[sidx] > 0 then
        local slen, is_call = str_len[sidx], false
        if nxt_off < insn_end then
          local nop = breadu8(buf, nxt_off)
          if use_encode then nop = ENCODE_OP[nop + 1] end
          if (nop == 21 or nop == 87) and breadu8(buf, nxt_off + 1) == a then is_call = true end
        end
        if not is_call and band_fn(str_flags[sidx], 2) == 0 then
          str_flags[sidx] = str_flags[sidx] + 2
          local need = wpos + 5 + slen
          if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
          bwriteu32(wbuf, wpos, 0x3A746567); bcopy(wbuf, wpos + 4, buf, str_off[sidx], slen); bwriteu8(wbuf, wpos + 4 + slen, 0)
          wpos = need
        end
        reg_call[r1] = sidx
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
            local slen, soff = str_len[cp], str_off[cp]
            local st_id = (slen >= 4 and slen <= 12 and BUILTIN_B0_MAP[breadu8(buf, soff)]) and BUILTIN_RAW_ID[breadstring(buf, soff, slen)] or nil
            if st_id then
              emit_tid = st_id
            else
              local need = wpos + 6 + slen
              if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
              bwriteu32(wbuf, wpos, 0x6C6C6163); bwriteu8(wbuf, wpos + 4, 0x3A); bcopy(wbuf, wpos + 5, buf, soff, slen); bwriteu8(wbuf, wpos + 5 + slen, 0)
              wpos = need
            end
          end
        else
          local st_id = TAG_ID_BY_NAME[cp]
          if st_id then
            emit_tid = st_id
          elseif not imp_seen[cp] then
            imp_seen[cp] = true
            local clen = #cp
            local need = wpos + clen + 1
            if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
            bwritestring(wbuf, wpos, cp); bwriteu8(wbuf, wpos + clen, 0)
            wpos = need
          end
        end
      end
      local nres = breadu8(buf, off + 3) - 1
      if nres < 0 then
        for r = r1, max_reg do reg_call[r] = nil; reg_ret[r] = nil end
        reg_ret[r1] = 3
        if r1 > max_reg then max_reg = r1 end
      elseif nres == 0 then
        reg_call[r1] = nil; reg_ret[r1] = nil
      else
        local top = a + nres
        for r = r1, top do reg_call[r] = nil; reg_ret[r] = 3 end
        if top > max_reg then max_reg = top end
      end
    elseif op == 20 or op == 85 then
      local r1 = breadu8(buf, off + 1) + 1
      local idx1 = (op == 20 and breadu32(buf, off + 4) or breadu16(buf, off + 4)) + 1
      local sidx = idx1 <= const_count and const_sidx[idx1] or 0
      if sidx > 0 and str_len[sidx] > 0 then
        local slen, soff, fl = str_len[sidx], str_off[sidx], str_flags[sidx]
        if band_fn(fl, 16) == 0 then
          fl = fl + 16
          local need = wpos + 8 + slen
          if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
          bwriteu32(wbuf, wpos, 0x6874656D); bwriteu32(wbuf, wpos + 4, 0x003A646F); bcopy(wbuf, wpos + 7, buf, soff, slen); bwriteu8(wbuf, wpos + 7 + slen, 0)
          wpos = need
        end
        if band_fn(fl, 8) == 0 then
          fl = fl + 8
          local st_id = (slen >= 4 and slen <= 12 and BUILTIN_B0_MAP[breadu8(buf, soff)]) and BUILTIN_RAW_ID[breadstring(buf, soff, slen)] or nil
          if st_id then
            emit_tid = st_id
          else
            local need = wpos + 6 + slen
            if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
            bwriteu32(wbuf, wpos, 0x6C6C6163); bwriteu8(wbuf, wpos + 4, 0x3A); bcopy(wbuf, wpos + 5, buf, soff, slen); bwriteu8(wbuf, wpos + 5 + slen, 0)
            wpos = need
          end
        end
        str_flags[sidx] = fl
        reg_call[r1] = sidx
      else
        reg_call[r1] = nil
      end
      local r2 = r1 + 1
      reg_call[r2] = nil; reg_ret[r1] = nil; reg_ret[r2] = nil
      if r2 > max_reg then max_reg = r2 end
    elseif op == 6 then
      local r1, rb = breadu8(buf, off + 1) + 1, breadu8(buf, off + 2) + 1
      reg_call[r1] = reg_call[rb]; reg_ret[r1] = reg_ret[rb]
      if r1 > max_reg then max_reg = r1 end
    elseif op == 12 then
      local a = breadu8(buf, off + 1)
      local r1 = a + 1
      local path, cpat, last_sidx = decode_import(buf, constants, const_sidx, const_count, str_off, str_len, breadu16(buf, off + 2) + 1, active_imp_gen)
      if path then
        local plen, ipat = #path, "import:" .. path
        if not imp_seen[ipat] then
          imp_seen[ipat] = true
          local need = wpos + 8 + plen
          if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
          bwriteu32(wbuf, wpos, 0x6F706D69); bwriteu32(wbuf, wpos + 4, 0x003A7472); bwritestring(wbuf, wpos + 7, path); bwriteu8(wbuf, wpos + 7 + plen, 0)
          wpos = need
        end
        local is_call = false
        if nxt_off < insn_end then
          local nop = breadu8(buf, nxt_off)
          if use_encode then nop = ENCODE_OP[nop + 1] end
          if (nop == 21 or nop == 87) and breadu8(buf, nxt_off + 1) == a then is_call = true end
        end
        if not is_call then
          local gpat = "get:" .. path
          if not imp_seen[gpat] then
            imp_seen[gpat] = true
            local need = wpos + 5 + plen
            if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
            bwriteu32(wbuf, wpos, 0x3A746567); bwritestring(wbuf, wpos + 4, path); bwriteu8(wbuf, wpos + 4 + plen, 0)
            wpos = need
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
      if sidx > 0 and str_len[sidx] > 0 and band_fn(str_flags[sidx], 4) == 0 then
        local slen = str_len[sidx]
        str_flags[sidx] = str_flags[sidx] + 4
        local need = wpos + 5 + slen
        if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
        bwriteu32(wbuf, wpos, 0x3A746573); bcopy(wbuf, wpos + 4, buf, str_off[sidx], slen); bwriteu8(wbuf, wpos + 4 + slen, 0)
        wpos = need
      end
    elseif op == 22 then
      emit_tid = breadu8(buf, off + 2) == 1 and 1 or (reg_ret[breadu8(buf, off + 1) + 1] or 2)
    elseif op == 26 or op == 25 then
      local is_andor, target_off = false, off + 4 + breadi16(buf, off + 2) * 4
      if target_off >= insn_base and target_off < insn_end then
        local top = breadu8(buf, target_off)
        if use_encode then top = ENCODE_OP[top + 1] end
        if top == 3 then is_andor = breadu8(buf, target_off + 3) ~= 0 elseif top == 6 then is_andor = true end
      end
      if op == 26 then
        if is_andor then
          emit_tid = 9
        else
          if tag_seen[8] ~= script_gen then
            tag_seen[8] = script_gen
            local need = wpos + TAG_NLEN[8]
            if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
            bwritestring(wbuf, wpos, TAG_NUL[8]); wpos = need
          end
          emit_tid = 7
        end
      else
        emit_tid = is_andor and 10 or 7
      end
    elseif op == 2 then
      local r1 = breadu8(buf, off + 1) + 1
      reg_call[r1] = nil; reg_ret[r1] = 4
      if r1 > max_reg then max_reg = r1 end
    elseif op == 3 then
      local r1, b = breadu8(buf, off + 1) + 1, breadu8(buf, off + 2)
      reg_call[r1] = nil; reg_ret[r1] = b == 0 and 5 or (b == 1 and 6 or nil)
      if r1 > max_reg then max_reg = r1 end
    elseif op == 68 or op == 73 or op == 74 or op == 75 or op == 60 then
      local tid = 100 + breadu8(buf, off + 1)
      if TAG_NUL[tid] then emit_tid = tid end
    elseif op == 77 or op == 78 or op == 79 or op == 80 then
      emit_tid = breadu8(buf, off + 7) >= 128 and 13 or 12
    elseif op == 56 or op == 59 or op == 61 or op == 76 then
      local r1 = breadu8(buf, off + 1) + 1
      emit_tid = op == 56 and 18 or (op == 61 and 20 or (op == 59 and 21 or 19))
      for r = r1, r1 + 3 do reg_call[r] = nil; reg_ret[r] = nil end
    elseif op == 57 then
      local r1 = breadu8(buf, off + 1) + 1
      emit_tid = 18
      reg_call[r1 + 2] = nil; reg_call[r1 + 3] = nil; reg_ret[r1 + 2] = nil; reg_ret[r1 + 3] = nil
    elseif op == 58 then
      local r1 = breadu8(buf, off + 1) + 1
      emit_tid = 19
      for r = r1 + 2, r1 + 2 + breadu8(buf, off + 4) do reg_call[r] = nil; reg_ret[r] = nil end
    elseif op == 63 then
      local a = breadu8(buf, off + 1)
      local r1, b = a + 1, breadu8(buf, off + 2)
      emit_tid = 25
      if b == 0 then
        for r = r1, max_reg do reg_call[r] = nil; reg_ret[r] = nil end
      elseif b >= 2 then
        for r = r1, a + b - 1 do reg_call[r] = nil; reg_ret[r] = nil end
      end
    elseif op == 86 and breadu8(buf, off + 2) == 0 then
      local idx1 = breadu32(buf, off + 4) + 1
      local sidx = idx1 <= const_count and const_sidx[idx1] or 0
      if sidx > 0 and str_len[sidx] > 0 and band_fn(str_flags[sidx], 4) == 0 then
        local slen = str_len[sidx]
        str_flags[sidx] = str_flags[sidx] + 4
        local need = wpos + 5 + slen
        if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
        bwriteu32(wbuf, wpos, 0x3A746573); bcopy(wbuf, wpos + 4, buf, str_off[sidx], slen); bwriteu8(wbuf, wpos + 4 + slen, 0)
        wpos = need
      end
    elseif op == 89 then
      local a = breadu8(buf, off + 1)
      if a == 0 then emit_tid = 38 elseif a == 1 then emit_tid = 39 end
    end

    if emit_tid ~= 0 and tag_seen[emit_tid] ~= script_gen then
      tag_seen[emit_tid] = script_gen
      local need = wpos + TAG_NLEN[emit_tid]
      if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
      bwritestring(wbuf, wpos, TAG_NUL[emit_tid]); wpos = need
    end

    off = nxt_off
  end

  scratch_max_reg = max_reg
  return wbuf, wpos, wcap, encoded_mode
end

local function parse_and_extract(bytecode: string): string?
  local bfrom, bcopy, breadu8, breadu32, breadstring = buffer.fromstring, buffer.copy, buffer.readu8, buffer.readu32, buffer.readstring
  local bwriteu8, bwriteu16, bwriteu32, band_fn, rshift_fn = buffer.writeu8, buffer.writeu16, buffer.writeu32, bit32.band, bit32.rshift

  local blen = #bytecode
  local buf = bfrom(bytecode)
  local pos = 0

  local version = breadu8(buf, pos)
  pos = pos + 1
  if version < 3 or (version > 14 and version ~= 100) then error("bad version") end

  local typesversion = 0
  if version >= 4 then typesversion = breadu8(buf, pos); pos = pos + 1 end

  local str_count = breadu8(buf, pos)
  if str_count < 128 then pos = pos + 1 else str_count, pos = read_varint_tail_buf(buf, pos, blen, str_count) end

  local str_off, str_len, str_flags = scratch_str_off, scratch_str_len, scratch_str_flags
  for i = 1, str_count do
    local slen = breadu8(buf, pos)
    if slen < 128 then pos = pos + 1 else slen, pos = read_varint_tail_buf(buf, pos, blen, slen) end
    if pos + slen > blen then error("eof") end
    str_off[i] = pos; str_len[i] = slen; str_flags[i] = 0; pos = pos + slen
  end

  if typesversion == 3 then
    while true do
      if pos >= blen then error("eof") end
      local tag = breadu8(buf, pos); pos = pos + 1
      if tag == 0 then break end
      local tv = breadu8(buf, pos)
      if tv < 128 then pos = pos + 1 else _, pos = read_varint_tail_buf(buf, pos, blen, tv) end
    end
  end

  local proto_count = breadu8(buf, pos)
  if proto_count < 128 then pos = pos + 1 else proto_count, pos = read_varint_tail_buf(buf, pos, blen, proto_count) end

  script_gen_counter = script_gen_counter + 1
  local script_gen = script_gen_counter
  local tag_seen, imp_seen = scratch_tag_seen, scratch_imp_seen
  tclear(imp_seen)

  local wbuf, wcap = scratch_blob_buf, scratch_blob_cap
  bwriteu8(wbuf, 0, 0)
  local wpos = 1

  local has_size = version >= 12 or version == 100
  local encoded_mode, max_const, any_imports = nil, 0, false
  local constants, const_sidx = scratch_constants, scratch_const_sidx

  for _ = 1, proto_count do
    local blob_end
    if has_size then
      local sz = breadu8(buf, pos)
      if sz < 128 then pos = pos + 1 else sz, pos = read_varint_tail_buf(buf, pos, blen, sz) end
      blob_end = pos + sz
      if blob_end > blen then break end
    end

    local limit, bp = blob_end or blen, pos + 4
    if version >= 4 then
      bp = bp + 1
      local tsize = breadu8(buf, bp)
      if tsize < 128 then bp = bp + 1 + tsize else local np; tsize, np = read_varint_tail_buf(buf, bp, limit, tsize); bp = np + tsize end
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
      local ctype = breadu8(buf, bp); bp = bp + 1

      if ctype == 3 then
        local sidx = breadu8(buf, bp)
        if sidx < 128 then bp = bp + 1 else sidx, bp = read_varint_tail_buf(buf, bp, limit, sidx) end
        if sidx >= 1 and sidx <= str_count then
          const_sidx[ci] = sidx
          if band_fn(str_flags[sidx], 1) == 0 and str_len[sidx] > 0 then
            local slen = str_len[sidx]
            str_flags[sidx] = str_flags[sidx] + 1
            local need = wpos + 8 + slen
            if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
            bwriteu32(wbuf, wpos, 0x69727473); bwriteu32(wbuf, wpos + 4, 0x003A676E)
            bcopy(wbuf, wpos + 7, buf, str_off[sidx], slen); bwriteu8(wbuf, wpos + 7 + slen, 0)
            wpos = need
          end
        else
          const_sidx[ci] = 0
        end
      elseif ctype == 2 then const_sidx[ci] = 0; bp = bp + 8
      elseif ctype == 4 then
        if bp + 4 > limit then error("eof u32") end
        constants[ci] = breadu32(buf, bp); const_sidx[ci] = -1; has_imports = true; any_imports = true; bp = bp + 4
      elseif ctype == 1 then const_sidx[ci] = 0; bp = bp + 1
      elseif ctype == 0 then const_sidx[ci] = 0
      elseif ctype == 5 then
        const_sidx[ci] = 0
        local n = breadu8(buf, bp)
        if n < 128 then bp = bp + 1 else n, bp = read_varint_tail_buf(buf, bp, limit, n) end
        for _ = 1, n do local v = breadu8(buf, bp); if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end end
      elseif ctype == 6 then
        const_sidx[ci] = 0
        local v = breadu8(buf, bp); if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end
      elseif ctype == 7 then const_sidx[ci] = 0; bp = bp + 16
      elseif ctype == 8 then
        const_sidx[ci] = 0
        local n = breadu8(buf, bp)
        if n < 128 then bp = bp + 1 else n, bp = read_varint_tail_buf(buf, bp, limit, n) end
        for _ = 1, n do local v = breadu8(buf, bp); if v < 128 then bp = bp + 5 else local np; _, np = read_varint_tail_buf(buf, bp, limit, v); bp = np + 4 end end
      elseif ctype == 9 then
        const_sidx[ci] = 0; bp = bp + 1
        local v = breadu8(buf, bp); if v < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v) end
      elseif ctype == 10 then
        const_sidx[ci] = 0
        local v1 = breadu8(buf, bp); if v1 < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, v1) end
        local pc2 = breadu8(buf, bp); if pc2 < 128 then bp = bp + 1 else pc2, bp = read_varint_tail_buf(buf, bp, limit, pc2) end
        local mc = breadu8(buf, bp); if mc < 128 then bp = bp + 1 else mc, bp = read_varint_tail_buf(buf, bp, limit, mc) end
        for _ = 1, pc2 + mc do local pv = breadu8(buf, bp); if pv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, pv) end end
      elseif ctype == 11 then const_sidx[ci] = 0; bp = bp + 32
      else broken_const = true; break end
    end

    wbuf, wpos, wcap, encoded_mode = extract_proto_buf(buf, insn_base, insn_end, constants, const_sidx, const_count, str_off, str_len, str_flags, has_imports, encoded_mode, tag_seen, script_gen, imp_seen, wbuf, wpos, wcap)

    if broken_const then
      if blob_end then pos = blob_end else break end
    else
      if bp < limit then
        local child_count = breadu8(buf, bp)
        if child_count < 128 then bp = bp + 1 else child_count, bp = read_varint_tail_buf(buf, bp, limit, child_count) end
        for _ = 1, child_count do local cv = breadu8(buf, bp); if cv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, cv) end end

        local ld = breadu8(buf, bp); if ld < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, ld) end
        local didx = breadu8(buf, bp); if didx < 128 then bp = bp + 1 else didx, bp = read_varint_tail_buf(buf, bp, limit, didx) end
        if didx >= 1 and didx <= str_count and band_fn(str_flags[didx], 32) == 0 and str_len[didx] > 0 then
          local slen = str_len[didx]
          str_flags[didx] = str_flags[didx] + 32
          local need = wpos + 6 + slen
          if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
          bwriteu32(wbuf, wpos, 0x636E7566); bwriteu8(wbuf, wpos + 4, 0x3A); bcopy(wbuf, wpos + 5, buf, str_off[didx], slen); bwriteu8(wbuf, wpos + 5 + slen, 0)
          wpos = need
        end

        if bp < limit then
          if breadu8(buf, bp) == 1 then
            if bp + 1 >= limit then
              if blob_end then bp = limit else error("eof") end
            else
              local linegap = breadu8(buf, bp + 1)
              local intervals = (insn_count > 0 and linegap < 32) and (rshift_fn(insn_count - 1, linegap) + 1) or 1
              bp = bp + 2 + insn_count + intervals * 4
            end
          else
            bp = bp + 1
          end
        end

        if bp < limit then
          if breadu8(buf, bp) == 1 then
            bp = bp + 1
            local lc = breadu8(buf, bp); if lc < 128 then bp = bp + 1 else lc, bp = read_varint_tail_buf(buf, bp, limit, lc) end
            for _ = 1, lc do
              local vidx = breadu8(buf, bp); if vidx < 128 then bp = bp + 1 else vidx, bp = read_varint_tail_buf(buf, bp, limit, vidx) end
              if vidx >= 1 and vidx <= str_count and band_fn(str_flags[vidx], 64) == 0 and str_len[vidx] > 0 then
                local slen = str_len[vidx]
                str_flags[vidx] = str_flags[vidx] + 64
                local need = wpos + 7 + slen
                if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
                bwriteu32(wbuf, wpos, 0x61636F6C); bwriteu16(wbuf, wpos + 4, 0x3A6C); bcopy(wbuf, wpos + 6, buf, str_off[vidx], slen); bwriteu8(wbuf, wpos + 6 + slen, 0)
                wpos = need
              end
              if bp >= limit then error("eof") end
              local b1 = breadu8(buf, bp); if b1 < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, b1) end
              if bp >= limit then error("eof") end
              local b2 = breadu8(buf, bp); if b2 < 128 then bp = bp + 2 else _, bp = read_varint_tail_buf(buf, bp, limit, b2); bp = bp + 1 end
            end

            if bp < limit then
              local uc = breadu8(buf, bp); if uc < 128 then bp = bp + 1 else uc, bp = read_varint_tail_buf(buf, bp, limit, uc) end
              for _ = 1, uc do
                local uidx = breadu8(buf, bp); if uidx < 128 then bp = bp + 1 else uidx, bp = read_varint_tail_buf(buf, bp, limit, uidx) end
                if uidx >= 1 and uidx <= str_count and band_fn(str_flags[uidx], 128) == 0 and str_len[uidx] > 0 then
                  local slen = str_len[uidx]
                  str_flags[uidx] = str_flags[uidx] + 128
                  local need = wpos + 7 + slen
                  if need > wcap then wbuf, wcap = grow_blob(wbuf, wpos, wcap, need) end
                  bwriteu32(wbuf, wpos, 0x61767075); bwriteu16(wbuf, wpos + 4, 0x3A6C); bcopy(wbuf, wpos + 6, buf, str_off[uidx], slen); bwriteu8(wbuf, wpos + 6 + slen, 0)
                  wpos = need
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
          local fb = breadu8(buf, bp); if fb < 128 then bp = bp + 1 else fb, bp = read_varint_tail_buf(buf, bp, limit, fb) end
          for _ = 1, fb do bp = bp + 1; local fv = breadu8(buf, bp); if fv < 128 then bp = bp + 1 else _, bp = read_varint_tail_buf(buf, bp, limit, fv) end end
        end
        pos = bp
      end
    end
  end

  if any_imports then
    local ipaths, icalls = scratch_import_paths, scratch_import_calls
    for i = 1, max_const do ipaths[i] = nil; icalls[i] = nil end
  end

  scratch_blob_buf = wbuf; scratch_blob_cap = wcap
  if wpos <= 1 then return nil end
  return breadstring(wbuf, 0, wpos)
end

@native
local function char_kind(b: number): number
  if b >= 97 and b <= 122 then return 1 end
  if b >= 65 and b <= 90 then return 2 end
  if b >= 48 and b <= 57 then return 0 end
  return -1
end

@native
local function check_bare_token_at(raw_blob: string, low_blob: string, lneedle: string, nlen: number, pos: number?): boolean
  local sbyte, rlen = string.byte, #raw_blob
  while pos do
    local start_ok = false
    local prev_b = sbyte(raw_blob, pos - 1)
    if not prev_b or prev_b == 0 then
      local p = pos; start_ok = true
      while p <= rlen do local ch = sbyte(raw_blob, p); if ch == 0 then break end; if ch == 58 then start_ok = false; break end; p = p + 1 end
    else
      local pk = char_kind(prev_b)
      if pk < 0 then
        start_ok = true
      else
        local fk = char_kind(sbyte(raw_blob, pos))
        if fk < 0 then start_ok = true
        elseif fk == 2 then start_ok = pk == 1 or pk == 0 or (pk == 2 and pos < rlen and char_kind(sbyte(raw_blob, pos + 1)) == 1)
        elseif fk == 0 then start_ok = pk > 0
        else start_ok = pk == 0 end
      end
    end
    if start_ok then
      local e_pos = pos + nlen - 1
      local next_b = sbyte(raw_blob, e_pos + 1)
      if not next_b then return true end
      local nk = char_kind(next_b)
      if nk < 0 then return true end
      local lk = char_kind(sbyte(raw_blob, e_pos))
      if lk < 0 then return true end
      if nk == 2 then
        if lk == 1 or lk == 0 or (lk == 2 and e_pos + 2 <= rlen and char_kind(sbyte(raw_blob, e_pos + 2)) == 1) then return true end
      elseif nk == 0 then
        if lk > 0 then return true end
      elseif lk == 0 then
        return true
      end
    end
    pos = string.find(low_blob, lneedle, pos + 1, true)
  end
  return false
end

@native
local function check_bare_prefix_at(raw_blob: string, low_blob: string, lneedle: string, pos: number?): boolean
  local sbyte, rlen = string.byte, #raw_blob
  while pos do
    local prev_b = sbyte(raw_blob, pos - 1)
    if not prev_b or prev_b == 0 then
      local p, ok = pos, true
      while p <= rlen do local ch = sbyte(raw_blob, p); if ch == 0 then break end; if ch == 58 then ok = false; break end; p = p + 1 end
      if ok then return true end
    else
      local pk = char_kind(prev_b)
      if pk < 0 then return true end
      local fk = char_kind(sbyte(raw_blob, pos))
      if fk < 0 then return true end
      if fk == 2 then
        if pk == 1 or pk == 0 or (pk == 2 and pos < rlen and char_kind(sbyte(raw_blob, pos + 1)) == 1) then return true end
      elseif fk == 0 then
        if pk > 0 then return true end
      elseif pk == 0 then
        return true
      end
    end
    pos = string.find(low_blob, lneedle, pos + 1, true)
  end
  return false
end

local function parse_and_cache(bytecode: string)
  hdr_cache[bytecode] = nil
  local ok, raw_blob = pcall(parse_and_extract, bytecode)
  local entry = (ok and raw_blob) and { raw_blob = raw_blob, low_blob = false, list = false } or false
  cache[bytecode] = entry
  return entry
end

local function get_entry(bytecode: string)
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
    if seg_len > best_len then best_len = seg_len; best = sub(val, start, seg_end) end
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
    if sfind(val, ".", 1, true) then return is_prefix and nil or longest_dot_segment(val) end
    return val
  end
  return val
end

local function extract_cold_ci_hint(lneedle)
  if #lneedle == 0 or sfind(STATIC_CI_HAYSTACK, lneedle, 1, true) then return nil end
  return lneedle
end

local function get_low_hdr(bc: string)
  local low_hdr = hdr_cache[bc]
  if low_hdr ~= nil then return low_hdr end
  local hdr = get_str_table_slice(bc)
  if not hdr then cache[bc] = false; return false end
  low_hdr = slower(hdr)
  hdr_cache[bc] = low_hdr
  return low_hdr
end

local function cold_ci_match(bc: string, ci_hint: string, title_hint: string?): boolean
  local cached_hdr = hdr_cache[bc]
  if cached_hdr ~= nil then return cached_hdr ~= false and sfind(cached_hdr, ci_hint, 1, true) ~= nil end
  if (title_hint and sfind(bc, title_hint, 1, true)) or sfind(bc, ci_hint, 1, true) then return true end
  local low_hdr = get_low_hdr(bc)
  return low_hdr ~= false and sfind(low_hdr, ci_hint, 1, true) ~= nil
end

local function passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci)
  for h = 1, nhints do if not sfind(bc, cold_hints[h], 1, true) then return false end end
  if nci > 0 then
    local cached_hdr = hdr_cache[bc]
    if cached_hdr ~= nil then
      if not cached_hdr then return false end
      for h = 1, nci do if not sfind(cached_hdr, cold_ci_hints[h], 1, true) then return false end end
      return true
    end
    local all_fast = true
    for h = 1, nci do
      local ch, th = cold_ci_hints[h], cold_ci_titles[h]
      if not ((th and sfind(bc, th, 1, true)) or sfind(bc, ch, 1, true)) then all_fast = false; break end
    end
    if all_fast then return true end
    local low_hdr = get_low_hdr(bc)
    if not low_hdr then return false end
    for h = 1, nci do if not sfind(low_hdr, cold_ci_hints[h], 1, true) then return false end end
  end
  return true
end

local function compile_terms(terms)
  local nterms = #terms
  local exact_needles, prefix_needles, bare_needles, bare_lower, bare_len, bare_prefix_lower = {}, {}, {}, {}, {}, {}
  local frag_needles, frag_lower, frag_alpha, cold_hints, cold_ci_hints, cold_ci_titles = {}, {}, {}, {}, {}, {}
  local nexact, nprefix, nbare, nbare_prefix, nfrag, nhints, nci = 0, 0, 0, 0, 0, 0, 0

  for t = 1, nterms do
    local term = terms[t]
    if type(term) ~= "string" or #term == 0 then return nil end

    if sub(term, 1, 1) == "~" then
      local needle = sub(term, 2)
      if #needle > 0 then
        local lneedle, alpha = slower(needle), smatch(needle, "%a") ~= nil
        nfrag = nfrag + 1; frag_needles[nfrag], frag_lower[nfrag], frag_alpha[nfrag] = needle, lneedle, alpha
        local ch = extract_cold_ci_hint(lneedle)
        if ch then nci = nci + 1; cold_ci_hints[nci] = ch; cold_ci_titles[nci] = alpha and (supper(sub(ch, 1, 1)) .. sub(ch, 2)) or false end
      end
    elseif sub(term, -1) == "*" then
      local needle = sub(term, 1, -2)
      if #needle > 0 then
        if sfind(needle, ":", 1, true) then
          nprefix = nprefix + 1; prefix_needles[nprefix] = "\0" .. needle
          local hint = extract_cold_hint(needle, true)
          if hint then nhints = nhints + 1; cold_hints[nhints] = hint end
        else
          local lneedle = slower(needle)
          nbare_prefix = nbare_prefix + 1; bare_prefix_lower[nbare_prefix] = lneedle
          local ch = extract_cold_ci_hint(lneedle)
          if ch then nci = nci + 1; cold_ci_hints[nci] = ch; cold_ci_titles[nci] = smatch(needle, "%a") ~= nil and (supper(sub(ch, 1, 1)) .. sub(ch, 2)) or false end
        end
      end
    else
      if sfind(term, ":", 1, true) then
        nexact = nexact + 1; exact_needles[nexact] = "\0" .. term .. "\0"
        local hint = extract_cold_hint(term, false)
        if hint then nhints = nhints + 1; cold_hints[nhints] = hint end
      else
        local lterm = slower(term)
        nbare = nbare + 1
        bare_needles[nbare] = (term == "concat" and "\0" or ":") .. term .. "\0"
        bare_lower[nbare], bare_len[nbare] = lterm, #term
        local ch = extract_cold_ci_hint(lterm)
        if ch then nci = nci + 1; cold_ci_hints[nci] = ch; cold_ci_titles[nci] = smatch(term, "%a") ~= nil and (supper(sub(ch, 1, 1)) .. sub(ch, 2)) or false end
      end
    end
  end

  if nexact > 1 then table.sort(exact_needles, function(a, b) return #a > #b end) end

  return exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci
end

local function entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag)
  local raw_blob = entry.raw_blob
  for t = 1, nexact do if not sfind(raw_blob, exact_needles[t], 1, true) then return false end end
  for t = 1, nprefix do if not sfind(raw_blob, prefix_needles[t], 1, true) then return false end end
  local low_blob = entry.low_blob
  for t = 1, nbare do
    if low_blob or not sfind(raw_blob, bare_needles[t], 1, true) then
      if not low_blob then low_blob = slower(raw_blob); entry.low_blob = low_blob end
      local lterm = bare_lower[t]
      local pos = sfind(low_blob, lterm, 1, true)
      if not pos or not check_bare_token_at(raw_blob, low_blob, lterm, bare_len[t], pos) then return false end
    end
  end
  for t = 1, nbare_prefix do
    if not low_blob then low_blob = slower(raw_blob); entry.low_blob = low_blob end
    local lneedle = bare_prefix_lower[t]
    local pos = sfind(low_blob, lneedle, 1, true)
    if not pos or not check_bare_prefix_at(raw_blob, low_blob, lneedle, pos) then return false end
  end
  for t = 1, nfrag do
    if frag_alpha[t] then
      if low_blob then
        if not sfind(low_blob, frag_lower[t], 1, true) then return false end
      elseif not sfind(raw_blob, frag_needles[t], 1, true) then
        low_blob = slower(raw_blob); entry.low_blob = low_blob
        if not sfind(low_blob, frag_lower[t], 1, true) then return false end
      end
    elseif not sfind(raw_blob, frag_needles[t], 1, true) then
      return false
    end
  end
  return true
end

function M.filter(bytecodes, terms)
  local find_fn, lower_fn = string.find, string.lower
  local nterms, matches, nmatches = #terms, {}, 0

  if nterms == 0 then
    for i = 1, #bytecodes do
      local bc = bytecodes[i]
      if type(bc) == "string" and #bc >= 2 and get_entry(bc) then nmatches = nmatches + 1; matches[nmatches] = i end
    end
    return matches
  end

  if nterms == 1 then
    local term = terms[1]
    if type(term) ~= "string" or #term == 0 then return matches end

    if sub(term, 1, 1) == "~" then
      local needle = sub(term, 2)
      local non_empty, lneedle = #needle > 0, lower_fn(needle)
      local has_alpha = non_empty and smatch(needle, "%a") ~= nil
      local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
      local title_hint = (ci_hint and has_alpha) and (supper(sub(ci_hint, 1, 1)) .. sub(ci_hint, 2)) or nil
      for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
          local entry = cache[bc]
          if entry == nil and (not ci_hint or cold_ci_match(bc, ci_hint, title_hint)) then entry = parse_and_cache(bc) end
          if entry then
            if not non_empty then nmatches = nmatches + 1; matches[nmatches] = i
            elseif has_alpha then
              local lb = entry.low_blob
              if lb then
                if find_fn(lb, lneedle, 1, true) then nmatches = nmatches + 1; matches[nmatches] = i end
              elseif find_fn(entry.raw_blob, needle, 1, true) then
                nmatches = nmatches + 1; matches[nmatches] = i
              else
                lb = lower_fn(entry.raw_blob); entry.low_blob = lb
                if find_fn(lb, lneedle, 1, true) then nmatches = nmatches + 1; matches[nmatches] = i end
              end
            elseif find_fn(entry.raw_blob, needle, 1, true) then
              nmatches = nmatches + 1; matches[nmatches] = i
            end
          end
        end
      end
    elseif sub(term, -1) == "*" then
      local needle = sub(term, 1, -2)
      local non_empty = #needle > 0
      if find_fn(needle, ":", 1, true) then
        local pneedle, hint = "\0" .. needle, extract_cold_hint(needle, true)
        for i = 1, #bytecodes do
          local bc = bytecodes[i]
          if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            if entry == nil and (not hint or find_fn(bc, hint, 1, true)) then entry = parse_and_cache(bc) end
            if entry and (not non_empty or find_fn(entry.raw_blob, pneedle, 1, true) ~= nil) then nmatches = nmatches + 1; matches[nmatches] = i end
          end
        end
      else
        local lneedle = lower_fn(needle)
        local ci_hint = non_empty and extract_cold_ci_hint(lneedle) or nil
        local title_hint = (ci_hint and smatch(needle, "%a") ~= nil) and (supper(sub(ci_hint, 1, 1)) .. sub(ci_hint, 2)) or nil
        for i = 1, #bytecodes do
          local bc = bytecodes[i]
          if type(bc) == "string" and #bc >= 2 then
            local entry = cache[bc]
            if entry == nil and (not ci_hint or cold_ci_match(bc, ci_hint, title_hint)) then entry = parse_and_cache(bc) end
            if entry then
              if not non_empty then
                nmatches = nmatches + 1; matches[nmatches] = i
              else
                local lb = entry.low_blob
                if not lb then lb = lower_fn(entry.raw_blob); entry.low_blob = lb end
                local pos = find_fn(lb, lneedle, 1, true)
                if pos and check_bare_prefix_at(entry.raw_blob, lb, lneedle, pos) then nmatches = nmatches + 1; matches[nmatches] = i end
              end
            end
          end
        end
      end
    elseif find_fn(term, ":", 1, true) then
      local eneedle, hint = "\0" .. term .. "\0", extract_cold_hint(term, false)
      for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
          local entry = cache[bc]
          if entry == nil and (not hint or find_fn(bc, hint, 1, true)) then entry = parse_and_cache(bc) end
          if entry and find_fn(entry.raw_blob, eneedle, 1, true) then nmatches = nmatches + 1; matches[nmatches] = i end
        end
      end
    else
      local eneedle, lterm, tlen = (term == "concat" and "\0" or ":") .. term .. "\0", lower_fn(term), #term
      local ci_hint = extract_cold_ci_hint(lterm)
      local title_hint = (ci_hint and smatch(term, "%a") ~= nil) and (supper(sub(ci_hint, 1, 1)) .. sub(ci_hint, 2)) or nil
      for i = 1, #bytecodes do
        local bc = bytecodes[i]
        if type(bc) == "string" and #bc >= 2 then
          local entry = cache[bc]
          if entry == nil and (not ci_hint or cold_ci_match(bc, ci_hint, title_hint)) then entry = parse_and_cache(bc) end
          if entry then
            local lb = entry.low_blob
            if not lb and find_fn(entry.raw_blob, eneedle, 1, true) then
              nmatches = nmatches + 1; matches[nmatches] = i
            else
              if not lb then lb = lower_fn(entry.raw_blob); entry.low_blob = lb end
              local pos = find_fn(lb, lterm, 1, true)
              if pos and check_bare_token_at(entry.raw_blob, lb, lterm, tlen, pos) then nmatches = nmatches + 1; matches[nmatches] = i end
            end
          end
        end
      end
    end

    return matches
  end

  local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci = compile_terms(terms)
  if not exact_needles then return matches end

  for i = 1, #bytecodes do
    local bc = bytecodes[i]
    if type(bc) == "string" and #bc >= 2 then
      local entry = cache[bc]
      if entry == nil and passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci) then entry = parse_and_cache(bc) end
      if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag) then
        nmatches = nmatches + 1; matches[nmatches] = i
      end
    end
  end

  return matches
end

function M.filter_async(bytecodes, terms, budget_ms, yield_fn)
  local nterms, matches, nmatches = #terms, {}, 0
  local yfn, budget = yield_fn or task_wait, (budget_ms or 4) * 0.001
  local can_yield = os_clock ~= nil and yfn ~= nil
  local slice_start = can_yield and os_clock() or 0

  if nterms == 0 then
    for i = 1, #bytecodes do
      local bc = bytecodes[i]
      if type(bc) == "string" and #bc >= 2 then
        local was_cached = cache[bc] ~= nil
        if get_entry(bc) then nmatches = nmatches + 1; matches[nmatches] = i end
        if can_yield and (not was_cached or i % 64 == 0) and (os_clock() - slice_start) >= budget then yfn(); slice_start = os_clock() end
      end
    end
    return matches
  end

  local exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci = compile_terms(terms)
  if not exact_needles then return matches end

  for i = 1, #bytecodes do
    local bc = bytecodes[i]
    if type(bc) == "string" and #bc >= 2 then
      local entry, did_parse = cache[bc], false
      if entry == nil and passes_cold_filters(bc, cold_hints, nhints, cold_ci_hints, cold_ci_titles, nci) then entry = parse_and_cache(bc); did_parse = true end
      if entry and entry_matches(entry, exact_needles, nexact, prefix_needles, nprefix, bare_needles, bare_lower, bare_len, nbare, bare_prefix_lower, nbare_prefix, frag_needles, frag_lower, frag_alpha, nfrag) then
        nmatches = nmatches + 1; matches[nmatches] = i
      end
      if can_yield and (did_parse or i % 64 == 0) and (os_clock() - slice_start) >= budget then yfn(); slice_start = os_clock() end
    end
  end

  return matches
end

function M.warmup(bytecodes, budget_ms, yield_fn)
  local yfn, budget = yield_fn or task_wait, (budget_ms or 4) * 0.001
  local can_yield = os_clock ~= nil and yfn ~= nil
  local slice_start = can_yield and os_clock() or 0
  for i = 1, #bytecodes do
    local bc = bytecodes[i]
    if type(bc) == "string" and #bc >= 2 and cache[bc] == nil then
      parse_and_cache(bc)
      if can_yield and (os_clock() - slice_start) >= budget then yfn(); slice_start = os_clock() end
    end
  end
end

function M.words(bytecode)
  local entry = get_entry(bytecode)
  if not entry then return false end
  local list = entry.list
  if list then return list end
  list = {}
  local rb, n, p = entry.raw_blob, 0, 2
  local rlen = #rb
  while p < rlen do
    local nxt = sfind(rb, "\0", p, true)
    if not nxt then break end
    if nxt > p then n = n + 1; list[n] = sub(rb, p, nxt - 1) end
    p = nxt + 1
  end
  entry.list = list
  return list
end

function M.tokens(bytecode)
  local entry = get_entry(bytecode)
  if not entry then return false end
  local token_list = entry.token_list
  if token_list then return token_list end
  local list, token_set, token_n = M.words(bytecode), {}, 0
  token_list = {}
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
        if not token_set[whole] then token_set[whole] = true; token_n = token_n + 1; token_list[token_n] = whole end
        if seg_end > seg_start then
          local sub_start, prev_k = seg_start, char_kind(byte(val, seg_start))
          for j = seg_start + 1, seg_end do
            local k = char_kind(byte(val, j))
            local split = (k == 0 and prev_k ~= 0) or (k ~= 0 and prev_k == 0) or (k == 2 and (prev_k == 1 or (prev_k == 2 and j < seg_end and char_kind(byte(val, j + 1)) == 1)))
            if split then
              local part = slower(sub(val, sub_start, j - 1))
              if not token_set[part] then token_set[part] = true; token_n = token_n + 1; token_list[token_n] = part end
              sub_start = j
            end
            prev_k = k
          end
          if sub_start > seg_start then
            local tail = slower(sub(val, sub_start, seg_end))
            if not token_set[tail] then token_set[tail] = true; token_n = token_n + 1; token_list[token_n] = tail end
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

M.version = "4.0.0"

return M
