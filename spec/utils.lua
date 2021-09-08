
--- Print binary string as ascii hex
---@param str string
---@return string ascii hex string
function get_print_safe_string(str)
  if str:match("^[%g ]+$") ~= nil then
    return string.format("%s", str)
  else
    return string.format(string.rep("\\x%02X", #str), string.byte(str, 1, #str))
  end
end

local key_order_cmp = function (key1, key2)
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

stringify_table_helper = function(val, name, multi_line, indent, previously_printed)
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
          tabStr =  tabStr .. stringify_table_helper(v, nil, multi_line, indent + 2, previously_printed) .. ", " .. multi_line_str
        else
          tabStr =  tabStr .. stringify_table_helper(v, k, multi_line, indent + 2, previously_printed) .. ", ".. multi_line_str
        end
      end
      if tabStr:sub(#tabStr, #tabStr) == "\n" and tabStr:sub(#tabStr - 1, #tabStr - 1) == "{" then
        tabStr = tabStr:sub(1, -2) .. "}"
      elseif tabStr:sub(#tabStr - 1, #tabStr - 1) == ","  then
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
    tabStr = tabStr .. "\"" .. get_print_safe_string(val) .. "\""
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
function table_string(val, name, multi_line)
  return stringify_table_helper(val, name, multi_line, 0, {})
end


local function format_non_table(v)
    if v == nil then
        return 'nil'
    end
    return string.format('%q', v)
end
---Format a table as a pretty printed string
---@param v any can be any value but works best with a table
---@param pre string|nil the current prefix (set by recursive calls)
---@param visited table[] tables that have been already printed to avoid infinite recursion (set by recursive calls)
--[[
local function table_string(v, pre, visited)
    pre = pre or ''
    visited = visited or {}
    if type(v) ~= 'table' then
        return format_non_table(v)
    elseif next(v) == nil then
        return '{ }'
    end
    local ret = '{'
    local orig_pre = pre
    pre = pre .. '  '
    visited[v] = true
    for key, value in pairs(v) do
        ret = ret .. '\n' .. pre .. key .. ' = '
        if type(value) == 'table' then
            if visited[value] then
                ret = ret .. '[recursive]'
            else
                ret = ret .. table_string(value, pre .. '  ', visited)
            end
        elseif type(value) == 'function' then
            ret = ret .. 'function'
        elseif type(value) == 'string' then
            ret = ret .. value
        elseif type(value) == 'number' then
            ret = ret .. format_non_table(value)
        else
            ret = ret .. string.format("[%s]", type(value))
        end
    end
    return string.format('%s\n%s}', ret, orig_pre)
end
--]]

local function assert_fmt(b, ...)
    if not b then
        error(string.format(...), 2)
    end
end

local function deep_equal(lhs, rhs)
    if type(lhs) ~= type(rhs) then
        return false
    end
    if type(lhs) == 'table' then
        for key, value in pairs(lhs) do
            if not deep_equal(value, rhs[key]) then
                return false
            end
        end
        return true
    end
    return lhs == rhs
end

local function assert_eq(lhs, rhs, msg)
    if not deep_equal(lhs, rhs) then
        local template = '%q ~= %q'
        if msg then
            template = template .. ' %s'
        end
        error(
            string.format(
                template,
                table_string(lhs),
                table_string(rhs),
                table_string(msg)
            ), 2)
    end
end

local function assert_ne(lhs, rhs, msg)
    if deep_equal(lhs, rhs)then
        local template = '%q == %q'
        if msg then
            template = template .. ' %s'
        end
        error(
            string.format(
                template,
                table_string(lhs),
                table_string(rhs),
                table_string(msg)
            ), 2)
    end
end

return {
    assert_fmt = assert_fmt,
    assert_eq = assert_eq,
    deep_equal = deep_equal,
    assert_ne = assert_ne,
    table_string = table_string
}
