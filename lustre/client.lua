local cosock = require 'cosock'
local Request = require "luncheon.request"
local Response = require "luncheon.response"
local Handshake = require 'lustre.handshake'
local Key = require 'lustre.handshake.key'
local Config = require 'lustre.config'
local Frame = require 'lustre.frame'
local CloseCode = require 'lustre.frame.close'

---@class WebSocketClient
---
---@field url string the endpoint to hit
---@field socket table lua socket
---@field handshake_key string key used in the websocket handshake
---@field config Config
---@field _tx table
---@field _rx table
local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

function WebSocketClient.new(socket, url, config)
    local _tx, _rx = cosock.channel.new()
    return setmetatable({
        socket = socket,
        url = url or '/',
        handshake_key = Key.generate_key(),
        config = config or Config.default(),
        _tx = _tx,
        _rx = _rx,
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
    --self._tx:send(...)
    -- need to define message structure: type, data, protocol/extension
end

function WebSocketClient:send_bytes(payload)
    
end

function WebSocketClient:close(close_code, reason)
    local close_frame = Frame.close(close_code, reason):set_mask()
    self.socket:send(close_frame:encode())
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
    local frames_since_last_ping = 0
    local pending_pong = false
    while true do
        local recv, _, err = cosock.select({self.socket, self._rx}, nil, self.config._keep_alive)
        if not recv then
            if err == "timeout" then
                self.socket:send(Frame.ping():set_mask():encode())
                pending_pong = true
            end
            goto continue
        end
        if recv[1] == self.socket then
            local frame, err = Frame.from_stream(self.socket)
            if not frame then
                self.error_callback(err)
            end
            if frame:is_control() then
                local control_type = frame.header.opcode.sub
                if control_type == 'ping' then
                    self.socket:send(Frame.pong(frame.payload):set_mask():encode())
                elseif control_type == 'pong' then
                    pending_pong = false
                    frames_since_last_ping = 0
                elseif control_type == 'close' then
                    if not self._close_frame_sent then
                        self:close(CloseCode.decode(frame.payload))
                    end
                    self.socket:close()
                    return
                end
                goto continue
            end
            if pending_pong then
                frames_since_last_ping = frames_since_last_ping + 1
                if frames_since_last_ping > self.config._max_frames_without_pong then
                    frames_since_last_ping = 0
                    self:close(CloseCode.policy(), "no pong after ping")
                end
            end
            if not frame:is_final() then
                table.insert(partial_frames, frame.payload)
                goto continue
            end
            local full_payload = frame.payload
            if next(partial_frames) then
                table.insert(partial_frames, frame.payload)
                full_payload = table.concat(partial_frames)
                partial_frames = {}
            end
            self.message_callback(full_payload)
        elseif recv[1] == self._rx then
            self._rx:recieve()
            --todo
        end

        ::continue::
    end
end




return WebSocketClient
