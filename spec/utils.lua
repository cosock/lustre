
local function format_non_table(v)
    if v == nil then
        return 'nil'
    end
    if type(v) == 'string' then return string.format('\'%q\'', v) end
    return string.format('%q', v)
end
---Format a table as a pretty printed string
---@param v any can be any value but works best with a table
---@param pre string|nil the current prefix (set by recursive calls)
---@param visited table[] tables that have been already printed to avoid infinite recursion (set by recursive calls)
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
        else
            ret = ret .. format_non_table(value)
        end
    end
    return string.format('%s\n%s}', ret, orig_pre)
end

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
}