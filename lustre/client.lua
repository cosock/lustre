local Request = require "luncheon.request"
local Response = require "luncheon.response"
local Handshake = require 'lustre.handshake'
local Key = require 'lustre.handshake.key'
local Config = require 'lustre.config'

---@class WebSocketClient
---
---@field url string the endpoint to hit
---@field socket table lua socket
local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

function WebSocketClient.new(socket, url, config)
    return setmetatable({
        socket = socket,
        url = url or '/',
        handshake_key = Key.generate_key(),
        config = config or Config.default(),
    }, WebSocketClient)
end

function WebSocketClient:handshake()
    local req = Request.new('GET', self.url, self.socket)
    req:add_header('Connection', 'upgrade')
    req:add_header('Sec-Websocket-Version', 13)
    req:add_header('Sec-Websocket-Key', self.handshake_key)
    req:send()

    local res = Response.tcp_source(self.socket)
    local handshake = Handshake.client(self.handshake_key, {}, {})
    if not handshake:validate_accept(res) then
        return nil, 'invalid handshake'
    end
    return 1
end

function WebSocketClient:send_text(payload)
    
end

function WebSocketClient:send_bytes(payload)
    
end

function WebSocketClient:close(close_code)
    local close_frame = Frame.close(close_code)
    self.socket:send(close_frame.encode())
    self._close_frame_sent = true
end

function WebSocketClient:register_message_callback(cb)
    self.message_callback = cb
end

function WebSocketClient:register_error_callback(cb)
    self.error_callback = cb
end

function WebSocketClient:register_close_callback(cb)
    self.close_callback = cb
end

function WebSocketClient:start_receive_loop()
    local partial_frames = {}
    while true do
        local frame, err = Frame.from_stream(self.socket)
        if not frame then
            self.error_callback(err)
        end
        if frame:is_control() then
            local control_type = frame.header.opcode.sub
            if control_type == 'ping' then
                self.socket:send(Frame.pong(frame.payload):encode())
            elseif control_type == 'close' then
                if not self._close_frame_sent then
                    self:close(CloseCode.from_int(payload))
                else
                    self.socket:close()
                    return --TODO what conditions end this loop?
                end
            end
            goto continue
        end
        if not frame:is_final() then
            table.insert(partial_frames, frame)
            goto continue
        end
        local full_payload = frame.payload
        if next(partial_frames) then
            local full_payload = frame.payload
            for _, partial in ipairs(partial_frames) do
                full_payload  = full_payload .. partial.payload
            end
        end
        self.message_callback(full_payload)

        ::continue::
    end
end




return WebSocketClient
