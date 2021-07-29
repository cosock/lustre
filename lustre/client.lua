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

-- todo can this api be used by both client and server?
--  need to modify to use Handshake.server() as well.
-- Also, I think this could be private and then get encapsulated within the open
-- api. 
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

function WebSocketClient:send(message, ...)
    --self._tx:send(...)
    -- need to define message structure: type, data, protocol/extension
    --
    -- why are we not calling?
    --  self.socket:send(Frame)

    local data_idx = 1
    local frames_sent = 0
    while data_idx <= message.data.len() do
        local header = FrameHeader.default()
        if (message.data.len() - data_idx - 1) > self.config._max_frame_size then
            header.set_fin(false)
        else

        end
        if message.type == 'bytes' then
            header:set_opcode(OpCode.binary())
        else
            header:set_opcode(OpCode.text())
        end
        --todo set mask too?
        local frame = Frame.from_parts(
            header,
            string.sub(message.data, data_idx, data_idx + self.config._max_frame_size)
        )
        local bytes, err = self.socket:send(frame:encode()) --todo do we get num bytes sent returned?
        data_idx = data_idx + bytes
        frames_sent = frames_sent + 1
    end
    print("sent "..frames_sent.." frames.")
end

function WebSocketClient:open(...)

end

function WebSocketClient:close(close_code, reason)
    local close_frame = Frame.close(close_code, reason):set_mask()
    self.socket:send(close_frame:encode())
    self._close_frame_sent = true
end

---@param cb function
function WebSocketClient:register_message_cb(cb)
    if type(cb) == 'function' then
        self.message_cb = cb
    end
end
---@param cb function
function WebSocketClient:register_error_cb(cb)
    if type(cb) == 'function' then
        self.error_cb = cb
    end
end
---@param cb function
function WebSocketClient:register_close_cb(cb)
    if type(cb) == 'function' then
        self.close_cb = cb
    end
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
                table.insert(partial_frames, frame.payload)
                goto continue
            end
            local full_payload = frame.payload
            if next(partial_frames) then
                table.insert(partial_frames, frame.payload)
                full_payload = table.concat(partial_frames)
                partial_frames = {}
            end
            --todo encapsulate in a message object
            self.message_cb(full_payload)
        elseif recv[1] == self._rx then
            self._rx:recieve() 
            --todo
        end

        ::continue::
    end
end




return WebSocketClient
