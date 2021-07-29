---@class Message
--TODO docstrings
---@field protocols string[] List of requested protocols
---@field extensions table[] List of requested extensions
---@field key string|nil Signing key
---@field accept string|nil Sec-WebSocket-Accept header value
local Message = {}
Message.__index = Message


---@param type string ['bytes'|'text']
---@param data string
function Message.new(type, data)
    --TODO set metatable
    return setmetatable({
        type = type,
        data = data
    }, Message)
end








