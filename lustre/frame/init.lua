local FrameHeader = require 'lustre.frame.frame_header'
local OpCode = require 'lustre.frame.opcode'
local CloseCode = require 'lustre.frame.close'.CloseCode
local CloseFrame = require 'lustre.frame.close'.CloseFrame

local Frame = {}
Frame.__index = Frame

function Frame.from_stream(socket)
  local header, err = FrameHeader.from_stream(socket)
  if not header then
    return nil, err
  end
  local payload, err = socket:receive(header.length) --num bytes
  if not payload then
    return nil, err
  end
  local ret = Frame.from_parts(header, payload)
  if ret:is_masked() then
    ret:_apply_mask()
  end
  return ret
end

function Frame.decode(bytes)
  local header, err = FrameHeader.decode(bytes)
  if not header then
    return nil, err
  end
  return Frame.from_parts(header, string.sub(bytes, header:len()+1))
end

function Frame.ping(payload)
  return Frame.from_parts(
    FrameHeader.default()
      :set_opcode(OpCode.ping()),
      payload or ''
  )
end

function Frame.pong(payload)
  return Frame.from_parts(
    FrameHeader.default()
      :set_opcode(OpCode.pong()),
      payload or ''
  )
end

function Frame.close(close_code, reason)
  local payload = ''
  if close_code then
    payload = payload .. CloseFrame.from_parts(close_code, reason):encode()
  end
  return Frame.from_parts(
    FrameHeader.default(),
    payload
  )
end

function Frame.from_parts(header, payload)
  return setmetatable({
    header = header,
    payload = payload,
    _applied_mask = false,
  }, Frame)
end

function Frame:len()
  return self.header:len() + self.header:payload_len()
end

function Frame:payload_len()
  return self.header:payload_len()
end

---Check if this Frame is masked
---@return any
function Frame:is_masked()
  return self.header.masked
end

function Frame:is_final()
  return self.header.fin
end

function Frame:is_control()
  return self.header.opcode.type == 'control'
end

---Get the mask array for this Frame
---@return number[]|nil @ 4 byte array
function Frame:mask()
  return self.header.mask
end

function Frame:set_mask(mask)
  mask = mask or generate_mask()
  self.header:set_mask(mask)
  return self
end

---Apply the mask array from the header, for outbound
---client messages, this will mask the payload, for inbound
---client messages, this will unmask the payload.
---
---note: this applies the mask in place
function Frame:_apply_mask()
  if self._applied_mask then
    return
  end
  if not self.header.mask then
    return nil, 'No mask to apply'
  end
  local unmasked = ''
  for i = 1, #self.payload do
    local byte = string.byte(self.payload, i, i)
    local char = byte ~ self.header.mask[(i % 4) + 1]
    unmasked = unmasked .. string.char(char)
  end
  self.payload = unmasked
  self._applied_mask = true
end

function Frame:encode()
  if self:is_masked() then
    self:_apply_mask()
  end
  return self.header:encode() .. self.payload
end

return Frame
