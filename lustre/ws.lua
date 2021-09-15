local cosock = require "cosock"
local socket = require "cosock.socket"
local Request = require "luncheon.request"
local Response = require "luncheon.response"
local Handshake = require "lustre.handshake"
local Key = require "lustre.handshake.key"
local Config = require "lustre.config"
local Frame = require "lustre.frame"
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local CloseCode = require"lustre.frame.close".CloseCode
local Message = require "lustre.message"
local log = require "log"

local utils = require "spec.utils"

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
    url = url or "/",
    handshake_key = Key.generate_key(),
    config = config or Config.default(),
    _tx = _tx,
    _rx = _rx,
    message_cb = arg[1],
    error_cb = arg[2],
    close_cb = arg[3],
  }, WebSocket)
end

function WebSocket.server(socket, config, ...) end

---@param cb function called when a complete message has been received
---@return self WebSocket
function WebSocket:register_message_cb(cb)
  if type(cb) == "function" then self.message_cb = cb end
  return self
end

---@param cb function called when there is an error
---@return self WebSocket
function WebSocket:register_error_cb(cb)
  if type(cb) == "function" then self.error_cb = cb end
  return self
end
---@param cb function called when the connection was closed
---@return self WebSocket
function WebSocket:register_close_cb(cb)
  if type(cb) == "function" then self.close_cb = cb end
  return self
end

---@param text string
---@return err string|nil
function WebSocket:send_text(text)
  local data_idx = 1
  local frames_sent = 0
  local total_bytes
  if self._close_frame_sent then return "currently closing connection" end
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
    local suc, err = self._tx:send(frame)
    if err then return "channel error:" .. err end
    data_idx = data_idx + frame:payload_len()
    frames_sent = frames_sent + 1
  until text:len() <= data_idx
end

---@param bytes string 
---@return bytes_sent number
---@return err string|nil
function WebSocket:send_bytes(bytes)
  local data_idx = 1
  local frames_sent = 0
  local total_bytes
  if self._close_frame_sent then return "currently closing connection" end
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
    local suc, err = self._tx:send(frame)
    if err then return "channel error:" .. err end
    data_idx = data_idx + frame:payload_len()
    frames_sent = frames_sent + 1
  until bytes:len() <= data_idx
end

---@param message Message
---@return err string|nil
function WebSocket:send(message) return nil, "not implemented" end

---@return success number 1 if handshake was successful
---@return err string|nil
function WebSocket:connect(host, port)
  if not self.is_client then -- todo use metatables to enforce this
    return nil, "only a client can connect"
  end
  if not host or not port then return nil, "missing host or port" end

  local r, err = self.socket:connect(host, port)
  if not r then return nil, "socket connect failure: " .. err end

  -- Do handshake
  local req = Request.new("GET", self.url, self.socket)
  req:add_header("Connection", "Upgrade")
  req:add_header("Upgrade", "websocket")
  req:add_header("User-Agent", "lua-lustre")
  req:add_header("Sec-Websocket-Version", 13)
  req:add_header("Sec-Websocket-Key", self.handshake_key)
  req:add_header("Host", string.format("%s:%d", host, port))
  for _, prot in ipairs(self.config.protocols) do
    -- TODO I think luncheon should be able to handle multiple values, but
    -- it currently only sends the last value added
    req:add_header("Sec-Websocket-Protocol", prot)
  end
  local s, err = req:send()
  if not s then return "handshake request failure: " .. err end
  local res, err = Response.tcp_source(self.socket)
  if not res then return nil, "Upgrade response failure: " .. err end
  local handshake = Handshake.client(self.handshake_key, {}, {})
  local success, err = handshake:validate_accept(res)
  if not success then return nil, "invalid handshake: " .. err end
  cosock.spawn(function() self:receive_loop() end, "Client receive loop")
  return 1
end

function WebSocket:accept() end

---@param close_code CloseCode
---@param reason string
---@return success number 1 if succss
---@return err string|nil
function WebSocket:close(close_code, reason)
  local close_frame = Frame.close(close_code, reason):set_mask() -- TODO client vs server
  local suc, err = self._tx:send(close_frame)
  if not suc then return nil, "channel error:" .. err end
  return 1
end

---@return message Message
---@return err string|nil
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
        if self._close_frame_sent then
          -- TODO this error case is a little weird, but it seems
          -- needed atm to ensure the loop ends when the server initates a close
          log.debug(string.format("weird error case exit loop: \n%s", self.socket:getpeername()))
          self.socket:close()
          return
        elseif err == "invalid opcode" or err == "invalid rsv bit" then
          self:close(CloseCode.protocol(), err)
        elseif err == "timeout" and self.error_cb then
          -- TODO retry receiving the frame, give partially received frame to err_cb
          self.error_cb("failed to get frame from socket: " .. err)
        elseif self.error_cb then
          self.error_cb(err)
          return "failed to get frame from socket"
        end
        goto continue
      end
      log.debug(string.format("RECEIVED FRAME: \n%s\n\n", utils.table_string(frame, nil, true)))
      if frame:is_control() then
        local control_type = frame.header.opcode.sub
        if frame:payload_len() > Frame.MAX_CONTROL_FRAME_LENGTH then
          self:close(CloseCode.protocol())
          goto continue
        end
        if control_type == "ping" then
          if not frame:is_final() then
            self:close(CloseCode.protocol())
            goto continue
          end
          local fm = Frame.pong(frame.payload):set_mask()
          self.socket:send(fm:encode())
        elseif control_type == "pong" then
          if not frame:is_final() then
            self:close(CloseCode.protocol())
            goto continue
          end
          pending_pong = false -- TODO this functionality is not tested by the test framework
          frames_since_last_ping = 0
        elseif control_type == "close" then
          self._close_frame_received = true
          if not self._close_frame_sent then
            self:close(CloseCode.decode(frame.payload))
          else
            self.socket:close()
            return
          end
        end
        goto continue
      end

      -- should we close because we have been waiting to long for a ping?
      -- we might not need to do this...it doesn't seem like it was prioritized
      -- with a test case in autobahn
      if pending_pong then
        frames_since_last_ping = frames_since_last_ping + 1
        if frames_since_last_ping > self.config._max_frames_without_pong then
          frames_since_last_ping = 0
          local err = self:close(CloseCode.policy(), "no pong after ping")
        end
      end

      -- handle fragmentation
      if frame.header.opcode.sub == "text" then
        msg_type = "text"
        if multiframe_message then -- we expected a continuation message
          self:close(CloseCode.protocol(), "expected " .. msg_type .. "continuation frame")
          goto continue
        end
        if not frame:is_final() then multiframe_message = true end
      elseif frame.header.opcode.sub == "binary" then
        msg_type = "binary"
        if multiframe_message then
          self:close(CloseCode.protocol(), "expected " .. msg_type .. "continuation frame")
          goto continue
        end
        if not frame:is_final() then multiframe_message = true end
      elseif frame.header.opcode.sub == "continue" and not multiframe_message then
        self:close(CloseCode.protocol(), "unexpected continue frame")
        goto continue
      end
      -- aggregate payloads
      if not frame:is_final() then
        received_bytes = received_bytes + frame:payload_len()
        -- TODO what should happen if we get message that is too big for the library?
        -- We are currently truncating the message.
        -- Dont build up a message payload that is bigger than max message size
        if received_bytes <= self.config.max_message_size then
          table.insert(partial_frames, frame.payload)
        end
        goto continue
      else
        multiframe_message = false
      end

      -- coalesce frame payloads into single message payload
      local full_payload = frame.payload
      if next(partial_frames) then
        table.insert(partial_frames, frame.payload)
        full_payload = table.concat(partial_frames)
        partial_frames = {}
      end
      if self.message_cb then self.message_cb(Message.new(msg_type, full_payload)) end
    elseif recv[1] == self._rx then -- frames we need to send on the socket
      local frame, err = self._rx:receive()
      if not frame then
        if self.error_cb then self.error_cb("channel receive failure: " .. err) end
        goto continue
      end

      local sent_bytes, err = self.socket:send(frame:encode())
      if not sent_bytes then
        -- TODO retry sending
        if self.error_cb then self.error_cb("socket send failure: " .. err) end
        goto continue
      end
      if frame:is_control() and frame.header.opcode.sub == "close" then
        self._close_frame_sent = true
        if self.close_cb then self.close_cb(reason) end
        if self._close_frame_received then
          self.socket:close()
          log.debug("Close handshake completed")
          return
        end
      end

      log.debug(string.format("SENT FRAME: \n%s\n\n", utils.table_string(frame, nil, true)))
    end

    ::continue::
  end
end

return WebSocket
