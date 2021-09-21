
local function assert_fmt(b, ...) if not b then error(string.format(...), 2) end end

local function deep_equal(lhs, rhs)
  if type(lhs) ~= type(rhs) then return false end
  if type(lhs) == "table" then
    for key, value in pairs(lhs) do if not deep_equal(value, rhs[key]) then return false end end
    return true
  end
  return lhs == rhs
end

local function assert_eq(lhs, rhs, msg)
  if not deep_equal(lhs, rhs) then
    local template = "%q ~= %q"
    if msg then template = template .. " %s" end
    error(string.format(template, table_string(lhs), table_string(rhs), table_string(msg)), 2)
  end
end

local function assert_ne(lhs, rhs, msg)
  if deep_equal(lhs, rhs) then
    local template = "%q == %q"
    if msg then template = template .. " %s" end
    error(string.format(template, table_string(lhs), table_string(rhs), table_string(msg)), 2)
  end
end

return {
  assert_fmt = assert_fmt,
  assert_eq = assert_eq,
  deep_equal = deep_equal,
  assert_ne = assert_ne,
}
