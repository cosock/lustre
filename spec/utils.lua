
local function assert_fmt(b, ...) if not b then error(string.format(...), 2) end end

local function deep_equal(lhs, rhs)
  if type(lhs) ~= type(rhs) then return false end
  if type(lhs) == "table" then
    for key, value in pairs(lhs) do if not deep_equal(value, rhs[key]) then return false end end
    return true
  end
  return lhs == rhs
end

return {
  assert_fmt = assert_fmt,
  deep_equal = deep_equal,
}
