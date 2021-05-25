local key = require 'lustre.handshake.key'
---@class Handshake
local Handshake = {}
Handshake.__index = Handshake

function Handshake.client(protocols, extensions)
    return setmetatable({
        protocols = protocols or {},
        extensions = extensions or {},
        key = key.generate_key(),
    }, Handshake)
end

---Validate the accept header returned by the
---the server
---@param req Request
---@return boolean
function Handshake:validate_accept(req)
    local headers = req:get_headers()
    if not headers.sec_websocket_accept then
        return nil, 'Invalid request, no Sec-Websocket-Accept header'
    end
    if not self.accept then
        self.accept = key.build_accept_from(self.key)
    end
    return self.accept == headers.sec_websocket_accept
end

local function parse_protocols(s, dest)
    for part in string.gmatch(s, '[^%s,]+') do
        table.insert(dest, part)
    end
end

local function parse_extension(s)
    local semi_pos = string.find(s, ';')
    if not semi_pos then
        return {
            name = s,
        }
    end
    local name = string.sub(s, 1, semi_pos-1)
    local params_s = string.sub(s, semi_pos)
    local params = {}
    for key, value in string.gmatch(params_s, '([^%s]+)=([^%s]+)') do
        params[key] = value
    end
    return {
        name = name,
        params = params,
    }
end

local function parse_extensions(s, dest)
    for part in string.gmatch(s, '[^,]+') do
        table.insert(dest, parse_extension(part))
    end
end

---Validate the incoming request and fill in the outbound response with appropriate status/headers
---on success
---@param req Request
---@param res Response
---@return Handshake|nil
---@return string
function Handshake.server(req, res)
    if res:has_sent() then
        return nil, 'Cannot handshake on used response'
    end
    if req.method ~= 'GET' then
        return nil, 'Websocket handshake must be a GET request'
    end
    if req.http_version ~= '1.1' then
        return nil, string.format('Websocket handshake request version must be 1.1 found: %q', req.http_version)
    end
    local headers, err = req:get_headers()
    if not headers then
        return nil, err
    end
    if not headers.connection then
        return nil, 'Missing connection header'
    end
    if not string.find(string.lower(headers.connection), 'upgrade') then
        return nil, string.format('Invalid connection header %q', headers.connection)
    end
    if not headers.upgrade then
        return nil, 'Upgrade header not present'
    end
    if not string.find(string.lower(headers.upgrade), '^websocket$') then
        return nil, string.format('Upgrade header must contain `websocket` found %q', headers.upgrade)
    end
    if not headers.sec_websocket_version then
        return nil, 'Missing Sec-Websocket-Version header'
    end
    if not string.find(headers.sec_websocket_version, '13') then
        return nil, string.format('Unsupported websocket version %q', headers.sec_websocket_version)
    end
    if not headers.sec_websocket_key then
        return nil, 'No Sec-Websocket-Key header present'
    end
    local accept = key.build_accept_from(headers.sec_websocket_key)
    res:status(101)
    res.headers:append('Upgrade', 'websocket')
    res.headers:append('Connection', 'Upgrade')
    res.headers:append('Sec-Websocket-Accept', accept)
    local ret = {
        protocols = {},
        extensions = {},
    }
    if headers.sec_websocket_protocol then
        local ty = type(headers.sec_websocket_protocol)
        if ty == 'string' then
            parse_protocols(headers.sec_websocket_protocol, ret.protocols)
        elseif ty == 'table' then
            for _, part in ipairs(headers.sec_websocket_protocol) do
                parse_protocols(part, ret.protocols)
            end
        end
    end
    if headers.sec_websocket_extensions then
        local ty = type(headers.sec_websocket_extensions)
        if ty == 'string' then
            parse_extensions(headers.sec_websocket_extensions, ret.extensions)
        elseif ty == 'table' then
            for _, part in ipairs(headers.sec_websocket_extensions) do
                parse_extensions(part, ret.extensions)
            end
        end
    end
    return setmetatable(ret, Handshake)
end


return Handshake
