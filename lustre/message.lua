---@class Message
---@field type string either "binary" or "text"
---@field data string 
local Message = {}
Message.__index = Message

Message.BYTES = 'binary'
Message.TEXT = 'text'

---@param type string ['binary'|'text']
---@param data string
function Message.new(type, data)
    return setmetatable({
        type = type,
        data = data
    }, Message)
end

return Message
