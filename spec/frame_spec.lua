local utils = require 'spec.utils'
local Frame = require 'lustre.frame'
local FrameHeader = require 'lustre.frame.frame_header'
local OpCode = require 'lustre.frame.opcode'
local CloseCode = require 'lustre.frame.close'.CloseCode

describe('Frame', function ()
  describe('apply_mask', function ()
    it('will not change payloads w/o a mask in header', function()
      local header = FrameHeader:default()
      local payload = 'asdfasdf'
      local f = Frame.from_parts(header, payload)
      f:apply_mask()
      utils.assert_eq(f.payload, payload)
    end)
    it('round tripping with mask will remain unchanged', function ()
      local header = FrameHeader:default():set_mask({1,2,3,4})
      local payload = 'asdfasdf'
      local f = Frame.from_parts(header, payload)
      f:apply_mask()
      utils.assert_fmt(f.payload ~= payload, 'Expected payloads to not match\n%s\n%s', f.payload, payload)
      f:apply_mask()
      utils.assert_eq(f.payload, payload)
    end)
  end)
  it('full round trip matches', function ()
    local bytes = string.char(
      0x80 | 2,
      0x80 | 100,
      42, 42, 42, 42
    )
    .. string.rep('a', 100)
    local f = assert(Frame.decode(bytes))
    utils.assert_eq(#f.payload, f.header:payload_len())
    utils.assert_eq(f:len(), #bytes)
    utils.assert_fmt(f.header:is_masked(), 'Not masked...')
    local back = f:encode()
    utils.assert_eq(bytes, back)
    local f2 = assert(Frame.decode(back))

    utils.assert_eq(f, f2)
  end)
  describe('constructors', function ()
    it('ping', function ()
      local f = Frame.ping('')
      utils.assert_eq(f.header.opcode, OpCode.ping())
    end)
    it('pong', function ()
      local f = Frame.pong('')
      utils.assert_eq(f.header.opcode, OpCode.pong())
    end)
    it('close', function ()
      local f = Frame.close(CloseCode.normal())
      utils.assert_eq(f.header.opcode, OpCode.close())
      utils.assert_eq(f.payload, CloseCode.normal():encode())
    end)
  end)
end)
