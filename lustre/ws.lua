local cosock = require "cosock"
local socket = require "cosock.socket"
local Request = require "luncheon.request"
local Response = require "luncheon.response"
local send_utils = require "luncheon.utils"
local Handshake = require "lustre.handshake"
local Key = require "lustre.handshake.key"
local Config = require "lustre.config"
local Frame = require "lustre.frame"
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local CloseCode = require"lustre.frame.close".CloseCode
local Message = require "lustre.message"
local log = require "log"

local utils = require "lustre.utils"

---@class WebSocket
---
---@field public id number|string
---@field public url string the endpoint to hit
---@field public socket table lua socket
---@field public handshake_key string key used in the websocket handshake
---@field public config Config
---@field private handshake Handshake
---@field private _send_tx table
---@field private _send_rx table
---@field private _recv_tx table
---@field private _recv_rx table
---@field private is_client boolean
local WebSocket = {}
WebSocket.__index = WebSocket

---Create new client object
---@param socket table connected tcp socket
---@param url string url to connect
---@param config Config 
---@return WebSocket
---@return string|nil
function WebSocket.client(socket, url, config)
  local _send_tx, _send_rx = cosock.channel.new()
  local _recv_tx, _recv_rx = cosock.channel.new()
  local ret = setmetatable({
    is_client = true,
    socket = socket,
    url = url or "/",
    handshake = Handshake.client(),
    config = config or Config.default(),
    _send_tx = _send_tx,
    _send_rx = _send_rx,
    _recv_tx = _recv_tx,
    _recv_rx = _recv_rx,
    id = math.random(),
    state = "Active",
  }, WebSocket)
  ret:register_message_cb(function(msg)
    _recv_tx:send({ msg = msg })
  end)
  ret:register_error_cb(function(err)
    _recv_tx:send({ err = err })
  end)
  ret:register_close_cb(function(msg)
    log.debug("closing", msg)
    _recv_tx:send({ err = "closed" })
  end)
  return ret
end

function WebSocket.server(socket, config, ...) end

---@param cb function called when a complete message has been received
---@return WebSocket
function WebSocket:register_message_cb(cb)
  if type(cb) == "function" then self.message_cb = cb end
  return self
end

---@param cb function called when there is an error
---@return WebSocket
function WebSocket:register_error_cb(cb)
  if type(cb) == "function" then self.error_cb = cb end
  return self
end
---@param cb function called when the connection was closed
---@return WebSocket
function WebSocket:register_close_cb(cb)
  if type(cb) == "function" then self.close_cb = cb end
  return self
end

function WebSocket:receive()
  local result = self._recv_rx:receive()
  if result.err then
    return nil, result.err
  end
  return result.msg
end

---@param text string
---@return number, string|nil
function WebSocket:send_text(text)
  local data_idx = 1
  local frames_sent = 0
  if self.state ~= "Active" then
    return nil, "closed"
  end
  local valid_utf8, utf8_err = utils.validate_utf8(text)
  if not valid_utf8 then
    return nil, utf8_err
  end
  repeat -- TODO fragmentation while sending has not been tested
    local header = FrameHeader.default()
    local payload = ""
    if (text:len() - data_idx + 1) > self.config._max_frame_size then header:set_fin(false) end
    payload = string.sub(text, data_idx, data_idx + self.config._max_frame_size)
    if data_idx ~= 1 then
      header:set_opcode(OpCode.continue())
    else
      header:set_opcode(OpCode.text())
    end
    header:set_length(#payload)
    local frame = Frame.from_parts(header, payload)
    frame:set_mask() -- todo handle client vs server
    local suc, err = self._send_tx:send(frame)
    if err then return nil, "channel error:" .. err end
    data_idx = data_idx + frame:payload_len()
    frames_sent = frames_sent + 1
  until text:len() <= data_idx
  return 1
end

---@param bytes string 
---@return number
---@return number, string|nil
function WebSocket:send_bytes(bytes)
  local data_idx = 1
  local frames_sent = 0
  if self.state ~= "Active" then return nil, "currently closing connection" end
  repeat
    local header = FrameHeader.default()
    local payload = ""
    if (bytes:len() - data_idx + 1) > self.config._max_frame_size then header:set_fin(false) end
    payload = string.sub(bytes, data_idx, data_idx + self.config._max_frame_size)
    if data_idx ~= 1 then
      header:set_opcode(OpCode.continue())
    else
      header:set_opcode(OpCode.binary())
    end
    header:set_length(#payload)
    local frame = Frame.from_parts(header, payload)
    frame:set_mask() -- todo handle client vs server
    local suc, err = self._send_tx:send(frame)
    if err then return nil, "channel error:" .. err end
    data_idx = data_idx + frame:payload_len()
    frames_sent = frames_sent + 1
  until bytes:len() <= data_idx
  return 1
end

--TODO remove the fragmentation code duplication in the `send_text` and `send_bytes` apis
--TODO  Could perhaps remove those apis entirely.
---@param message Message
---@return number, string|nil
function WebSocket:send(message) return nil, "not implemented" end

---@return number, string|nil
function WebSocket:connect(host, port)
  log.trace(self.id, "WebSocket:connect", host, port)
  if not self.is_client then -- todo use metatables to enforce this
    log.error(self.id, "Invalid client websocket")
    return nil, "only a client can connect"
  end
  if not host or not port then return nil, "missing host or port" end
  log.debug(self.id, "calling socket.connect")
  local r, err = self.socket:connect(host, port)
  log.debug(self.id, "Socket connect completed", r or err)
  if not r then return nil, "socket connect failure: " .. err end

  -- Do handshake
  log.debug(self.id, "sending handshake")
  local success, err = self.handshake:send(self.socket, self.url, string.format("%s:%d", host, port))
  log.debug(self.id, "handshake complete", success or err)
  if not success then return nil, "invalid handshake: " .. err end
  cosock.spawn(function() self:receive_loop() end, "Client receive loop")
  return 1
end

function WebSocket:accept() end

---@param close_code CloseCode
---@param reason string
---@return number 1 if succss
---@return string|nil
function WebSocket:close(close_code, reason)
  log.debug('sending close message', close_code, reason)
  if self.state == "Active" then
    local close_frame = Frame.close(close_code, reason):set_mask() -- TODO client vs server
    local suc, err = self._send_tx:send(close_frame)
    if not suc then return nil, "channel error:" .. err end
  elseif self.state == "ClosedBySelf" then
    self.state = "CloseAcknowledged"
  end

  return 1
end

---@return Message
---@return string|nil
function WebSocket:receive_loop()
  log.trace(self.id, "starting receive loop")
  local msg_type
  local loop_state = {
    partial_frames = {},
    received_bytes = 0,
    frames_since_last_ping = 0,
    pending_pongs = 0,
    multiframe_message = false,
    msg_type,
  }
  while true do
    log.trace(self.id, "loop top")
    local recv, _, err = socket.select({self.socket, self._send_rx}, nil, self.config._keep_alive)
    log.debug(recv and "recv" or "~recv", err or "")
    if not recv then
      if self:_handle_select_err(loop_state, err) then
        return
      end
    end
    
    if self:_handle_recvs(loop_state, recv, 1) then return end
    if self:_handle_recvs(loop_state, recv, 2) then return end
  end
end

function WebSocket:_handle_recvs(state, recv, idx)
  if recv[idx] == self.socket then
    return self:_handle_recv_ready(state)
  end
  if recv[idx] == self._send_rx then -- frames we need to send on the socket
    return self:_handle_send_ready()
  end
end

function WebSocket:_handle_select_err(state, err)
  log.debug(self.id, "selected err:", err)
  if err == "timeout" then
    if state.pending_pongs >= 2 then --TODO max number of pings without a pong could be configurable
      if self.error_cb then self.error_cb("no response to keep alive ping commands") end
      self.state = "Terminated"
      log.debug("Closing socket")
      self.socket:close()
      return 1
    end
    local fm = Frame.ping():set_mask()
    local sent_bytes, err = send_utils.send_all(self.socket, fm:encode())
    if not err then
      log.debug(self.id, string.format("SENT FRAME: \n%s\n\n", utils.table_string(fm, nil, true)))
      state.pending_pongs = state.pending_pongs + 1
    elseif self.error_cb then
      self.error_cb(string.format("failed to send ping: "..err))
      self.state = "Terminated"
      log.debug("Closing socket")
      self.socket:close()
      return 1
    end
  end
end

function WebSocket:_handle_recv_ready(state)
  log.debug(self.id, "selected socket")
  local frame, err = Frame.from_stream(self.socket)
  log.debug(self.id, "build frame", frame or err)
  if not frame then
    log.info("error building frame", err)
    if err == "invalid opcode" or err == "invalid rsv bit" then
      log.warn(self.id, "PROTOCOL ERR: received frame with " .. err)
      self:close(CloseCode.protocol(), err)
      self.state = "ClosedBySelf"
    elseif err == "timeout" and self.error_cb then
      -- TODO retry receiving the frame, give partially received frame to err_cb
      self.error_cb("failed to get frame from socket: " .. err)
    elseif err and err:match("close") then
      if self.state == "Active" and self.error_cb then self.error_cb(err) end
      self.state = "Terminated"
      return 1
    elseif self.error_cb then
      self.error_cb("failed to get frame from socket: " .. err)
    end
    return
  end
  log.debug(self.id, cosock.socket.gettime(), string.format("RECEIVED FRAME: \n%s\n\n", utils.table_string(frame, nil, true, 100)))
  if frame:is_control() then
    if not frame:is_final() then
      log.trace(self.id, "PROTOCOL ERR: received non final control frame")
      self:close(CloseCode.protocol())
      self.state = "ClosedBySelf"
      return
    end
    local control_type = frame.header.opcode.sub
    if frame:payload_len() > Frame.MAX_CONTROL_FRAME_LENGTH then
      log.trace(self.id, "PROTOCOL ERR: received control frame that is too big")
      self:close(CloseCode.protocol())
      self.state = "ClosedBySelf"
      return
    end
    if control_type == "ping" then
      local fm = Frame.pong(frame.payload):set_mask()
      local sent_bytes, err = send_utils.send_all(self.socket, fm:encode())
      if not sent_bytes and self.error_cb then
        self.error_cb("failed to send pong in response to ping: "..err)
      else
        log.trace(self.id, cosock.socket.gettime(), string.format("SENT FRAME: \n%s\n\n", utils.table_string(fm, nil, true)))
      end
    elseif control_type == "pong" then
      state.pending_pongs = 0 -- TODO this functionality is not tested by the test framework
      state.frames_since_last_ping = 0
    elseif control_type == "close" then
      self:close(CloseCode.decode(frame.payload))
      if self.state == "ClosedBySelf" then
        self.state = "CloseAcknowledged"
      elseif self.state == "Active" then
        self.state = "ClosedByPeer"
      end
    end
    return
  end

  -- Should we close because we have been waiting to long for a ping?
  -- We might not need to do this, because it wasn't prioritized
  -- with a test case in autobahn
  if state.pending_pongs > 0 then
    state.frames_since_last_ping = state.frames_since_last_ping + 1
    if state.frames_since_last_ping > self.config._max_frames_without_pong then
      state.frames_since_last_ping = 0
      log.trace(self.id, "PROTOCOL ERR: received too many frames while waiting for pong")
      local err = self:close(CloseCode.policy(), "no pong after ping")
      self.state = "ClosedBySelf"
    end
  end

  -- handle fragmentation
  if frame.header.opcode.sub == "text" then
    state.msg_type = "text"
    if state.multiframe_message then -- we expected a continuation message
      self:close(CloseCode.protocol(), "expected " .. state.msg_type .. "continuation frame")
      self.state = "ClosedBySelf"
      return
    end
    if not frame:is_final() then state.multiframe_message = true end
  elseif frame.header.opcode.sub == "binary" then
    state.msg_type = "binary"
    if state.multiframe_message then
      self:close(CloseCode.protocol(), "expected " .. state.msg_type .. "continuation frame")
      self.state = "ClosedBySelf"
      return
    end
    if not frame:is_final() then state.multiframe_message = true end
  elseif frame.header.opcode.sub == "continue" and not state.multiframe_message then
    
    self:close(CloseCode.protocol(), "unexpected continue frame")
    self.state = "ClosedBySelf"
    return
  end
  -- aggregate payloads
  if not frame:is_final() then
    state.received_bytes = state.received_bytes + frame:payload_len()
    -- TODO what should happen if we get message that is too big for the library?
    -- We are currently truncating the message.
    if state.received_bytes <= self.config.max_message_size then
      table.insert(state.partial_frames, frame.payload)
    else
      log.warn(self.id, "truncating message thats bigger than max config size")
    end
    return
  else
    multiframe_message = false
  end

  -- coalesce frame payloads into single message payload
  local full_payload = frame.payload
  if next(state.partial_frames) then
    table.insert(state.partial_frames, frame.payload)
    full_payload = table.concat(state.partial_frames)
    state.partial_frames = {}
  end
  if state.msg_type == "text" then
    log.debug('checking for valid utf8')
    local valid_utf8, utf8_err = utils.validate_utf8(full_payload)
    log.trace('valid?', valid_utf8, utf8_err)
    if not valid_utf8 then
      log.warn("Received invalid utf8 text message, closing", utf8_err)
      self:close(CloseCode.invalid(), utf8_err)
      self.state = "ClosedBySelf"
      return
    end
  end
  if self.message_cb then self.message_cb(Message.new(state.msg_type, full_payload)) end
end

function WebSocket:_handle_send_ready()
  log.debug(self.id, "selected channel")
  local frame, err = self._send_rx:receive()
  log.debug("received from rx")
  if not frame then
    if self.error_cb then self.error_cb("channel receive failure: " .. err) end
    return
  end
  log.debug("encoding frame: ", cosock.socket.gettime())
  local bytes = frame:encode()
  log.debug("sending all bytes", cosock.socket.gettime())
  local sent_bytes, err = send_utils.send_all(self.socket, bytes)
  log.debug("sent bytes", cosock.socket.gettime())
  if not sent_bytes then
    local closed = err:match("close")
    if closed and self.state == "Active" then
      if self.error_cb then self.error_cb("socket send failure: " .. err) end
    end
    if not closed then
      if self.error_cb then self.error_cb("socket send failure: " .. err) end
    end
    return
  end
  log.debug(self.id, string.format("SENT FRAME: \n%s\n\n", utils.table_string(frame, nil, true, 100)))
  
  if frame:is_close() then
    if self.state == "Active" then
      self.state = "ClosedBySelf"
    elseif self.state == "ClosedByPeer" then
      self.state = "CloseAcknowledged"
    end
    if self.close_cb then self.close_cb(frame.payload) end
    if self.state == "CloseAcknowledged" then
      log.debug("Closing socket")
      self.socket:close()
      log.trace(self.id, "completed server close handshake")
      return 1
    end
  end
end

return WebSocket
