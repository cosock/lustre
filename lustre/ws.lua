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
    print("tring to send??")
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
        print("SENDING TEXT FRAME: \n", utils.table_string(frame), "\n\n")
        local bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned or does it return when all the bytes were sent?
        --TODO send frame over cosock channel to be sent on socket from receive loop
        if not bytes then
            return err
        end
        data_idx = data_idx + bytes
        frames_sent = frames_sent + 1
    end
    print("fingished senign")
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
        local sent_bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned or does it return when all the bytes were sent?
        --TODO send frame over cosock channel to be sent on socket from receive loop
        if not sent_bytes then
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
    local s, err = req:send()
    if not s then
        return "handshake request failure: "..err
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
    local close_frame = Frame.close(close_code, reason):set_mask()
    local sent, err = self.socket:send(close_frame:encode())
    if not sent then return nil, err end
    print("SENT CLOSE FRAME: \n", utils.table_string(close_frame), "\n\n")
    self._close_frame_sent = true
    if self.close_cb then self.close_cb(reason) end
    return 1
end

---@return message Message
---@return err string|nil
--TODO break out some helper functions for this...
--TODO confirm the socket lifecycle throughout the receive loop: the receive loop ends when the socket is closed
function WebSocket:receive_loop()
    local partial_frames = {}
    local received_bytes = 0
    local frames_since_last_ping = 0
    local pending_pong = false
    local multiframe_message = false 
    local msg_type
    while true do
        local recv, _, err = socket.select({self.socket, self._rx}, nil, self.config._keep_alive)
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
                print("!!!!!!!!!!!!!! attempted to receive, but no frame")
                if self._close_frame_sent then
                    --TODO this error case is a little weird, but it seems
                    -- needed atm to ensure the loop ends when the server initates a close
                    print("!@#$!@#$!@#$!@#$!@#$!$@#!@#$!@#$ weird error case exit loop: \n", self.socket:getpeername())
                    return
                elseif err == "invalid opcode" or err == "invalid rsv bit" then
                    self:close(CloseCode.protocol(), err)
                elseif self.error_cb then
                    self.error_cb(err)
                    return "failed to get frame from socket"
                end
                goto continue
            end
            print("RECEIVE FRAME: \n", utils.table_string(frame), "\n\n")
            if frame:is_control() then
                local control_type = frame.header.opcode.sub
                if frame:payload_len() > Frame.MAX_CONTROL_FRAME_LENGTH then
                    self:close(CloseCode.protocol())
                    self.socket:close() -- probably shouldn't preemtively do this.
                    return
                end
                if control_type == 'ping' then
                    if not frame:is_final() then
                        self:close(CloseCode.protocol())
                    end
                    local fm = Frame.pong(frame.payload):set_mask()
                    self.socket:send(fm:encode())
                elseif control_type == 'pong' then
                    if not frame:is_final() then
                        self:close(CloseCode.protocol())
                    end
                    pending_pong = false --TODO this functionality is not tested by the test framework
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

            --should we close because we have been waiting to long for a ping
            -- we might not need to do this...it doesn't seem like it was prioritized
            -- with a test case in autobahn
            if pending_pong then
                frames_since_last_ping = frames_since_last_ping + 1
                if frames_since_last_ping > self.config._max_frames_without_pong then
                    frames_since_last_ping = 0
                    local err = self:close(CloseCode.policy(), "no pong after ping")
                end
            end


            --handle fragmentation
            print("!!!!!!!!!multiframe_message ", multiframe_message)
            if frame.header.opcode.sub == 'text' then
                msg_type = "text"
                if multiframe_message then
                    self:close(CloseCode.protocol(), "expected "..msg_type.."continuation frame")
                    goto continue
                end
                if not frame:is_final() then
                    multiframe_message = true
                end
            elseif frame.header.opcode.sub == 'binary' then
                msg_type = "binary"
                if multiframe_message then
                    self:close(CloseCode.protocol(), "expected "..msg_type.."continuation frame")
                    goto continue
                end
                if not frame:is_final() then
                    multiframe_message = true
                end
            elseif frame.header.opcode.sub   == 'continue' and not multiframe_message then
                self:close(CloseCode.protocol(), "unexpected continue frame")
                goto continue
            end
            --aggregate payloads
            if not frame:is_final() then --todo and we are continuing something
                multiframe_message = true
                received_bytes = received_bytes + frame:payload_len()
                --Dont build up a message payload that is bigger than max message size
                print("\treceived_bytes: ", received_bytes, "self.config:max_message_size(): ", self.config.max_message_size)
                if received_bytes <= self.config.max_message_size then
                    print("\tinserting into the payload.\n")
                    table.insert(partial_frames, frame.payload)
                end
                goto continue
            else
                multiframe_message = false
            end


            --coalesce frame payloads into single message payload
            local full_payload = frame.payload
            if next(partial_frames) then
                print("THERE shoudl be partial frames: \n\t", utils.table_string(partial_frames))
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
            --we could receive a message from the close api to close the socket at the appropriate time
        end

        ::continue::
        --socket.sleep(0.5)
    end
end

return WebSocket
