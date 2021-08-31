local cosock = require 'cosock'
local Request = require "luncheon.request"
local Response = require "luncheon.response"
local Handshake = require 'lustre.handshake'
local Key = require 'lustre.handshake.key'
local Config = require 'lustre.config'
local Frame = require 'lustre.frame'
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local CloseCode = require 'lustre.frame.close'
local Message = require "lustre.message"

--TODO We should obfuscate WebSocketClient from the user. They should
-- only ever interact with a WebSocket class that acts as a client when 
-- they call `connect`, and a server when they call `accept`.
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

---Create new client object
---@param socket table tcp socket to connect on
---@param url string url to connect
---@param config Config 
---@param message_cb function
---@param error_cb function
---@param close_cb function
---@return client WebSocketClient
---@return err string|nil
function WebSocketClient.new(socket, url, config, ...)
    --TODO how was this channel intended to be used again?
    local _tx, _rx = cosock.channel.new()
    return setmetatable({
        socket = socket,
        url = url or '/',
        handshake_key = Key.generate_key(),
        config = config or Config.default(),
        _tx = _tx,
        _rx = _rx,
        message_cb = message_cb,
        error_cb = error_cb, 
        close_cb = close_cb
    }, WebSocketClient)
end

---@param text string
---@return bytes_sent number
---@return err string|nil
function WebSocketClient:send_text(text)
    return nil, "not implmented"
end

---@param bytes string 
---@return bytes_sent number
---@return err string|nil
function WebSocketClient:send_bytes(bytes)
    return nil, "not implmented"
end

---@param message Message
---@return err string|nil
function WebSocketClient:send(message)
    local data_idx = 1
    local frames_sent = 0
    while data_idx <= message.data:len() do
        local header = FrameHeader.default()
        local payload = ""
        if (message.data:len() - data_idx + 1) > self.config._max_frame_size then
            header.set_fin(false)
        end
        if message.type == Message.BYTES then
            header:set_opcode(OpCode.binary()) 
        else
            header:set_opcode(OpCode.text())
        end
        local frame = Frame.from_parts(
            header,
            string.sub(message.data, data_idx, data_idx + self.config._max_frame_size)
        )
        frame:set_mask()
        local bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned or does it return when all the bytes were sent?
        data_idx = data_idx + bytes
        frames_sent = frames_sent + 1
    end
    --print("sent "..frames_sent.." frames.")
end

---@return success number 1 if handshake was successful
---@return err string|nil
function WebSocketClient:connect()
    --TODO open tcp connection if it isn't open
    --Do handshake
    local req = Request.new('GET', self.url, self.socket)
    req:add_header('Connection', 'upgrade')
    req:add_header('Sec-Websocket-Version', 13)
    req:add_header('Sec-Websocket-Key', self.handshake_key)
    print(string.format("***starting handshake with req: %s", req))
    req:send()

    local res = Response.tcp_source(self.socket)
    local handshake = Handshake.client(self.handshake_key, {}, {})
    if not handshake:validate_accept(res) then
        return nil, 'invalid handshake'
    end
    return 1
end

---@param close_code CloseCode
---@param reason string
---@return err string|nil
function WebSocketClient:close(close_code, reason)
    local close_frame = Frame.close(close_code, reason):set_mask()
    self.socket:send(close_frame:encode())
    self._close_frame_sent = true
end

---@return message Message
---@return err string|nil
function WebSocketClient:receive()

end

---@param cb function called when a complete message has been received
function WebSocketClient:register_message_cb(cb)
    if type(cb) == 'function' then
        self.message_cb = cb
    end
end

---@param cb function called when there is an error
function WebSocketClient:register_error_cb(cb)
    if type(cb) == 'function' then
        self.error_cb = cb
    end
end
---@param cb function called when the connection was closed
function WebSocketClient:register_close_cb(cb)
    if type(cb) == 'function' then
        self.close_cb = cb
    end
end

--TODO this will not be a public API and is very untested ATM.
function WebSocketClient:start_receive_loop()
    local partial_frames = {}
    local received_bytes = 0
    local frames_since_last_ping = 0
    local pending_pong = false
    while true do
        local recv, _, err = cosock.socket.select({self.socket, self._rx}, nil, self.config._keep_alive)
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
                self.error_cb(err)
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
                received_bytes = received_bytes + frame:payload_len()
                --Dont build up a message payload that is bigger than max message size
                if received_bytes <= self.config:max_message_size() then
                    table.insert(partial_frames, frame.payload)
                end
                goto continue
            end
            local full_payload = frame.payload
            if next(partial_frames) then
                table.insert(partial_frames, frame.payload)
                full_payload = table.concat(partial_frames)
                partial_frames = {}
            end
            self.message_cb(Message:new(full_payload))
        elseif recv[1] == self._rx then
            self._rx:recieve() 
            --todo
        end

        ::continue::
    end
end

return WebSocketClient
