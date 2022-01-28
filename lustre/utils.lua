--- Print binary string as ascii hex
---@param str string
---@return string ascii hex string
function get_print_safe_string(str, limit)
  local ret
  if str:match("^[%g ]+$") ~= nil then
    ret = string.format("%s", str)
  else
    ret = string.format(string.rep("\\x%02X", #str), string.byte(str, 1, #str))
  end
  if limit and #str > limit then
    return string.sub(ret, 1, limit).."..."
  end
  return ret
end

local key_order_cmp = function(key1, key2)
  local type1 = type(key1)
  local type2 = type(key2)
  if type1 ~= type2 then
    return type1 < type2
  elseif type1 == "number" or type1 == "string" then -- comparable types
    return key1 < key2
  elseif type1 == "boolean" then
    return key1 == true
  else
    return tostring(key1) < tostring(key2)
  end
end

local stringify_table_helper

stringify_table_helper = function(val, name, multi_line, indent, previously_printed, str_limit)
  local tabStr = multi_line and string.rep(" ", indent) or ""

  if name then tabStr = tabStr .. tostring(name) .. "=" end

  local multi_line_str = ""
  if multi_line then multi_line_str = "\n" end

  if type(val) == "table" then
    if not previously_printed[val] then
      tabStr = tabStr .. "{" .. multi_line_str
      -- sort keys for repeatability of print
      local tkeys = {}
      for k in pairs(val) do table.insert(tkeys, k) end
      table.sort(tkeys, key_order_cmp)

      for _, k in ipairs(tkeys) do
        local v = val[k]
        previously_printed[val] = name
        if #val > 0 and type(k) == "number" then
          tabStr = tabStr ..
                     stringify_table_helper(v, nil, multi_line, indent + 2, previously_printed, str_limit) ..
                     ", " .. multi_line_str
        else
          tabStr = tabStr ..
                     stringify_table_helper(v, k, multi_line, indent + 2, previously_printed, str_limit) ..
                     ", " .. multi_line_str
        end
      end
      if tabStr:sub(#tabStr, #tabStr) == "\n" and tabStr:sub(#tabStr - 1, #tabStr - 1) == "{" then
        tabStr = tabStr:sub(1, -2) .. "}"
      elseif tabStr:sub(#tabStr - 1, #tabStr - 1) == "," then
        tabStr = tabStr:sub(1, -3) .. (multi_line and string.rep(" ", indent) or "") .. "}"
      else
        tabStr = tabStr .. (multi_line and string.rep(" ", indent) or "") .. "}"
      end
    else
      tabStr = tabStr .. "RecursiveTable: " .. previously_printed[val]
    end
  elseif type(val) == "number" then
    tabStr = tabStr .. tostring(val)
  elseif type(val) == "string" then
    tabStr = tabStr .. "\"" .. get_print_safe_string(val, str_limit) .. "\""
  elseif type(val) == "boolean" then
    tabStr = tabStr .. (val and "true" or "false")
  elseif type(val) == "function" then
    tabStr = tabStr .. tostring(val)
  else
    tabStr = tabStr .. "\"[unknown datatype:" .. type(val) .. "]\""
  end

  return tabStr
end

--- Convert value to string
---@param val table Value to stringify
---@param name string Print a name along with value [Optional]
---@param multi_line boolean use newlines to provide a more easily human readable string [Optional]
---@returns string String representation of `val`
local function table_string(val, name, multi_line, str_limit)
  return stringify_table_helper(val, name, multi_line, 0, {}, str_limit)
end

local function has_continue_bits(ch)
  return ch & 0x80 == 0x80
end

local function to_bits(ch)
  local bits = {}
  while ch > 0 do
    if (ch & 1) > 0 then
      table.insert(bits, '1')
    else
      table.insert(bits, '0')
    end
    ch = ch >> 1
  end
  while #bits < 8 do
    table.insert(bits, '0')
  end
  return string.reverse(table.concat(bits, ' '))
end

local function validate_utf8(s)
  local i = 1
  while i <= #s do
    local bytes = table.pack(s:byte(i, i+4))
    print(i, "checking: ", to_bits(bytes[1]))
    if bytes[1] == 0xFE or bytes[1] == 0xFF then
      return nil, "Invalid UTF-8 Byte"
    end
    if bytes[1] & 0xF0 == 0xF0 then
      print('found 4 byte character')
      if #bytes < 4 then
        return nil, 'UTF-8 Sequence Too Short'
      end
      if not (has_continue_bits(bytes[2])
         and has_continue_bits(bytes[3])
         and has_continue_bits(bytes[4])) then
        return nil, 'Invalid UTF-8 Sequence Continue'
      end
      i = i + 4
    elseif bytes[1] & 224 == 224 then
      print("found 3 byte character")
      if #bytes < 3 then
        return nil, 'UTF-8 Sequence Too Short'
      end
      if not (has_continue_bits(bytes[2])
         and has_continue_bits(bytes[3])) then
        return nil, 'Invalid UTF-8 Sequence Continue'
      end
      i = i + 3
    elseif bytes[1] & 0xC0 == 0xC0 then
      print("found 2 byte character")
      if #bytes < 2 then
        return nil, 'UTF-8 Sequence Too Short'
      end
      if not has_continue_bits(bytes[2]) then
        return nil, 'Invalid UTF-8 Sequence Continue'
      end
      i = i + 2
    else
      print("found potential 1 byte character")
      if bytes[1] & 0x80 ~= 0 then
        print("1 byte character can't have 128 set")
        return nil, 'Invalid UTF-8 Sequence Start'
      end
      i = i + 1
    end
  end
  return 1
end

return {
  table_string = table_string,
  validate_utf8 = validate_utf8,
}
