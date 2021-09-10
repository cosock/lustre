local cosock = require 'cosock'
local socket = require "socket"
local Request = require "luncheon.request"
local Response = require "luncheon.response"
local Handshake = require 'lustre.handshake'
local Key = require 'lustre.handshake.key'
local Config = require 'lustre.config'
local Frame = require 'lustre.frame'
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local CloseCode = require 'lustre.frame.close'.CloseCode
local Message = require "lustre.message"

local utils = require "spec.utils"
--TODO cleanup print statements

---@class WebSocket
---
---@field url string the endpoint to hit
---@field socket table lua socket
---@field handshake_key string key used in the websocket handshake
---@field config Config
---@field _tx table
---@field _rx table
local WebSocket = {}
WebSocket.__index = WebSocket

---Create new client object
---@param socket table connected tcp socket
---@param url string url to connect
---@param config Config 
---@param message_cb function
---@param error_cb function
---@param close_cb function
---@return client WebSocket
---@return err string|nil
function WebSocket.client(socket, url, config, ...)
    local _tx, _rx = cosock.channel.new()
    return setmetatable({
        is_client = true,
        socket = socket,
        url = url or '/',
        handshake_key = Key.generate_key(),
        config = config or Config.default(),
        _tx = _tx,
        _rx = _rx,
        message_cb = arg[1],
        error_cb = arg[2], 
        close_cb = arg[3],
    }, WebSocket)
end

function WebSocket.server(socket, config, ...)
end


---@param cb function called when a complete message has been received
---@return self WebSocket
function WebSocket:register_message_cb(cb)
    if type(cb) == 'function' then
        self.message_cb = cb
    end
    return self
end

---@param cb function called when there is an error
---@return self WebSocket
function WebSocket:register_error_cb(cb)
    if type(cb) == 'function' then
        self.error_cb = cb
    end
    return self
end
---@param cb function called when the connection was closed
---@return self WebSocket
function WebSocket:register_close_cb(cb)
    if type(cb) == 'function' then
        self.close_cb = cb
    end
    return self
end

---@param text string
---@return err string|nil
function WebSocket:send_text(text)
    local data_idx = 1
    local frames_sent = 0
    local total_bytes
    if self._close_frame_sent then
        return "currently closing connection"
    end
    while data_idx <= text:len() + 1 do
        local header = FrameHeader.default()
        local payload = ""
        if (text:len() - data_idx + 1) > self.config._max_frame_size then
            header.set_fin(false)
        end
        payload = string.sub(text, data_idx, data_idx + self.config._max_frame_size)
        header:set_opcode(OpCode.text())
        header:set_length(#payload)
        local frame = Frame.from_parts(
            header,
            payload
        )
        frame:set_mask() --todo handle client vs server
        print(os.clock(), " sending frame: ", utils.table_string(frame))
        local bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned or does it return when all the bytes were sent?
        --TODO send frame over cosock channel to be sent on socket from receive loop
        print("sent ", bytes, " bytes on the socket")
        if not bytes then
            --print("failed to send frame on socket: "..err)
            return err
        end
        data_idx = data_idx + bytes
        frames_sent = frames_sent + 1
    end
    --print("sent "..frames_sent.." frames.")
end

---@param bytes string 
---@return bytes_sent number
---@return err string|nil
function WebSocket:send_bytes(bytes)
    local data_idx = 1
    local frames_sent = 0
    local total_bytes
    if self._close_frame_sent then
        return "currently closing connection"
    end
    while data_idx <= bytes:len() + 1 do
        local header = FrameHeader.default()
        local payload = ""
        if (bytes:len() - data_idx + 1) > self.config._max_frame_size then
            header.set_fin(false)
        end
        payload = string.sub(bytes, data_idx, data_idx + self.config._max_frame_size)
        header:set_opcode(OpCode.binary())
        header:set_length(#payload)
        local frame = Frame.from_parts(
            header,
            payload
        )
        frame:set_mask() --todo handle client vs server
        print(os.clock(), " sending frame: ", utils.table_string(frame))
        local sent_bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned or does it return when all the bytes were sent?
        --TODO send frame over cosock channel to be sent on socket from receive loop
        print("sent ", sent_bytes, " bytes on the socket")
        if not sent_bytes then
            --print("failed to send frame on socket: "..err)
            return err
        end
        data_idx = data_idx + sent_bytes
        frames_sent = frames_sent + 1
    end
end

---@param message Message
---@return err string|nil
function WebSocket:send(message)
    return "not implemented"
end

---@return success number 1 if handshake was successful
---@return err string|nil
function WebSocket:connect(host, port)
    if not self.is_client then --todo use metatables to enforce this
        return nil, "only a client can connect"
    end
    if not host or not port then
        return nil, "missing host or port"
    end

    -- open socket
    --TODO what happens if the socket is already connected? 
    local r, err = self.socket:connect(host, port)
    if not r then
        return nil, "socket connect failure: "..err
    end

    --Do handshake
    local req = Request.new('GET', self.url, self.socket)
    req:add_header('Connection', 'Upgrade')
    req:add_header('Upgrade', 'websocket')
    req:add_header('User-Agent', "lua-lustre")
    req:add_header('Sec-Websocket-Version', 13)
    req:add_header('Sec-Websocket-Key', self.handshake_key)
    req:add_header("Host", string.format("%s:%d", host, port))
    for _, prot in ipairs(self.config.protocols) do
        --TODO I think luncheon should be able to handle multiple values, but
        -- it currently only sends the last value added
        req:add_header("Sec-Websocket-Protocol", prot)
    end
    --print("send req: \n", req:serialize())
    local s, err = req:send()
    if not s then
        print("Handshake request failure: ", err)
        return err
    end
    local res, err = Response.tcp_source(self.socket)
    if not res then
        return nil, "Upgrade response failure: "..err
    end
    local handshake = Handshake.client(self.handshake_key, {}, {})
    local success, err = handshake:validate_accept(res)
    if not success then
        return nil, 'invalid handshake: '..err
    end
    cosock.spawn(function() self:receive_loop() end, 'Client receive loop')
    return 1
end

function WebSocket:accept()
end

---@param close_code CloseCode
---@param reason string
---@return err string|nil
function WebSocket:close(close_code, reason)
    print("closing websocket")
    local close_frame = Frame.close(close_code, reason):set_mask()
    local sent, err = self.socket:send(close_frame:encode())
    if not sent then return nil, err end
    self._close_frame_sent = true
    return 1
end

---@return message Message
---@return err string|nil
function WebSocket:receive_loop()
    local partial_frames = {}
    local received_bytes = 0
    local frames_since_last_ping = 0
    local pending_pong = false
    while true do
        print(os.clock(), "tick: ")
        local recv, _, err = socket.select({self.socket, self._rx}, nil, self.config._keep_alive)
        if not recv then
            if err == "timeout" then
                self.socket:send(Frame.ping():set_mask():encode())
                pending_pong = true
            end
            goto continue
        end
        if recv[1] == self.socket then
            local msg_type
            local frame, err = Frame.from_stream(self.socket)
            print(os.clock(), " receiving frame: ", utils.table_string(frame))
            if not frame then
                if self._close_frame_sent then
                    return
                elseif self.error_cb then
                    print("errcb")
                    self.error_cb(err)
                    return "failed to get frame from socket"
                end
                print("!!! failed to get frame from socket: ", err)
                goto continue
            end
            if frame:is_control() then
                local control_type = frame.header.opcode.sub
                if frame:len() > Frame.MAX_CONTROL_FRAME_LENGTH then
                    self:close(CloseCode.protocol())
                end
                if control_type == 'ping' then
                    print(os.clock(), "received ping with payload: ", frame.payload)
                    self.socket:send(Frame.pong(frame.payload):set_mask():encode())
                elseif control_type == 'pong' then
                    pending_pong = false
                    frames_since_last_ping = 0
                elseif control_type == 'close' then
                    if not self._close_frame_sent then
                        print("sending close frame in response to one")
                        self:close(CloseCode.decode(frame.payload))
                    end
                    self.socket:close()
                    return
                end
                goto continue
            else
                msg_type = frame.header.opcode.sub
            end
            if pending_pong then
                frames_since_last_ping = frames_since_last_ping + 1
                if frames_since_last_ping > self.config._max_frames_without_pong then
                    frames_since_last_ping = 0
                    self:close(CloseCode.policy(), "no pong after ping")
                end
            end
            if not frame:is_final() then
                print("not final frame received")
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
            if self.message_cb then
                self.message_cb(Message.new(msg_type, full_payload))
            end
        elseif recv[1] == self._rx then
            self._rx:recieve()
            --todo
        end

        ::continue::
        --socket.sleep(0.5)
    end
end

return WebSocket
