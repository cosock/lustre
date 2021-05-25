local Config = {}
Config.__index = Config

local DEFAULT_MAX_FRAME = 16 * 1024
local DEFAULT_MAX_MESSAGE = 64 * 1024

function Config.default()
    return setmetatable({
        _max_queue_size = nil,
        _max_frame_size = DEFAULT_MAX_FRAME,
        _max_message_size = DEFAULT_MAX_MESSAGE,
        _accept_unmasked_frames = false,
    }, Config)
end

function Config:max_queue_size(size)
    self._max_queue_size = size
    return self
end

function Config:max_message_size(size)
    self._max_message_size = size or DEFAULT_MAX_MESSAGE
    return self
end

function Config:max_frame_size(size)
    self._max_frame_size = size or DEFAULT_MAX_FRAME
    return self
end

return Config
