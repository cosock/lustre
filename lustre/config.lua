---@class Config
---@field private _max_queue_size number|nil
---@field private _max_frame_size number
---@field private _max_message_size number
---@field private _accept_unmasked_frames boolean
---@field public extensions table[]
---@field public protocols string[]
local Config = {}
Config.__index = Config

local DEFAULT_MAX_FRAME = 16 * 1024 * 1024
local DEFAULT_MAX_MESSAGE = 64 * 1024 * 1024

---Construct a default configurations
---@return Config
function Config.default()
    return setmetatable({
        _max_queue_size = nil,
        _max_frame_size = DEFAULT_MAX_FRAME,
        _max_message_size = DEFAULT_MAX_MESSAGE,
        _accept_unmasked_frames = false,
        extensions = {},
        protocols = {},
    }, Config)
end

---Set the max message queue size
---@param size number|nil
---@return Config
function Config:max_queue_size(size)
    self._max_queue_size = size
    return self
end

---Set the max message size (Default 64mb)
---@param size number|nil
---@return Config
function Config:max_message_size(size)
    self._max_message_size = size or DEFAULT_MAX_MESSAGE
    return self
end

---Set the max frame size (Default 16mb)
---@param size number|nil
---@return Config
function Config:max_frame_size(size)
    self._max_frame_size = size or DEFAULT_MAX_FRAME
    return self
end

function Config:extension(name, params)
    table.insert(self.extensions, {
        name = name,
        params = params,
    })
    return self
end

function Config:protocol(name)
    table.insert(self.protocols, name)
    return self
end

return Config
