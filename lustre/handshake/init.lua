local key = require 'lustre.handshake.key'
---@class Handshake
---@field protocols string[] List of requested protocols
---@field extensions table[] List of requested extensions
---@field key string|nil Signing key
---@field accept string|nil Sec-WebSocket-Accept header value
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
    local accept = headers:get_one('Sec-Websocket-Accept')
    if not accept then
        return nil, 'Invalid request, no Sec-Websocket-Accept header'
    end
    if not self.accept then
        self.accept = key.build_accept_from(self.key)
    end
    return self.accept == accept
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
    local connection = headers:get_one('Connection')
    if not connection then
        return nil, 'Missing connection header'
    end
    if not string.find(string.lower(connection), 'upgrade') then
        return nil, string.format('Invalid connection header %q', connection)
    end
    local upgrade = headers:get_one('Upgrade')
    if not upgrade then
        return nil, 'Upgrade header not present'
    end
    if not string.find(string.lower(upgrade), '^websocket$') then
        return nil, string.format('Upgrade header must contain `websocket` found %q', upgrade)
    end
    local swv = headers:get_one('Sec-Websocket-Version')
    if not swv then
        return nil, 'Missing Sec-Websocket-Version header'
    end
    if not string.find(swv, '13') then
        return nil, string.format('Unsupported websocket version %q', swv)
    end
    local sw_key = headers:get_one('Sec-Websocket-Key')
    if not sw_key then
        return nil, 'No Sec-Websocket-Key header present'
    end
    local accept = key.build_accept_from(sw_key)
    res:status(101)
    res:add_header('Upgrade', 'websocket')
    res:add_header('Connection', 'Upgrade')
    res:add_header('Sec-Websocket-Accept', accept)
    local ret = {
        protocols = {},
        extensions = {},
    }
    local protocols = headers:get_one('sec_websocket_protocol')
    if protocols then
        parse_protocols(protocols, ret.protocols)
    end
    local extensions = headers:get_one('sec_websocket_extensions')
    if extensions then
        parse_extensions(extensions, ret.extensions)
    end
    return setmetatable(ret, Handshake)
end


return Handshake
