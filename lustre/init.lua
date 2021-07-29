local CloseCode = require 'lustre.frame.close_code'
local Config = require 'lustre.config'
local Frame = require 'lustre.frame'
local Handshake = require 'lustre.handshake'
local Opcode = require 'lustre.frame.opcode'
local Message = require 'lustre.message'

local WebSocket = {}
WebSocket.__index = WebSocket

function WebSocket.new(socket, url, config, type)
    local _tx, _rx = cosock.channel.new()
    --todo branch on type to create
    return setmetatable({
        socket = socket,
        url = url or '/',
        handshake_key = Key.generate_key(),
        config = config or Config.default(),
        _tx = _tx,
        _rx = _rx,
    }, WebSocket)
end

function WebSocket:send(message, ...)
    --self._tx:send(...)
    --todo need to define message structure: type, data, protocol/extension
end

function WebSocket:close(code, reason)

end

--This seems like it will be the same for both client and server
function WebSocket:start_receive_loop()
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

return {
  CloseCode = CloseCode,
  Config = Config,
  Frame = Frame,
  Handshake = Handshake,
  Opcode = Opcode,
  WebSocket = WebSocket,
  Message = Message,
}
