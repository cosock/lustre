local utils = require "spec.utils"
local Frame = require "lustre.frame"
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local CloseCode = require "lustre.frame.close".CloseCode
local MockSocket = require "spec.mock_socket".MockSocket
local cosock = require "cosock"

describe("Frame", function()
  describe("apply_mask", function()
    it("will not change payloads w/o a mask in header", function()
      local header = FrameHeader:default()
      local payload = "asdfasdf"
      local f = Frame.from_parts(header, payload)
      f:apply_mask()
      assert.are(f.payload, payload)
    end)
    it("round tripping with mask will remain unchanged", function()
      local header = FrameHeader:default():set_mask({1, 2, 3, 4})
      local payload = "asdfasdf"
      local f = Frame.from_parts(header, payload)
      f:apply_mask()
      utils.assert_fmt(f.payload ~= payload, "Expected payloads to not match\n%s\n%s", f.payload,
                       payload)
      f:apply_mask()
      assert.are(f.payload, payload)
    end)
    it("round tripping with mask will remain unchanged large payload #W", function()
      local header = FrameHeader:default():set_mask({1, 2, 3, 4})
      local payload = string.rep(
          string.rep("BAsd7&jh23", 2),
          2 ^ 20
      )
      payload = string.sub(payload, 1, 16 * 2 ^ 20)
      local f = Frame.from_parts(header, payload)
      f:apply_mask()
      utils.assert_fmt(f.payload ~= payload, "Expected payloads to not match\n%s\n%s", f.payload,
                       payload)
      f:apply_mask()
      assert.are.same(f.payload, payload)
    end)
  end)
  it("full round trip matches #a", function()
    local bytes = string.char(0x80 | 2, 0x80 | 100, 42, 42, 42, 42) .. string.rep("a", 2048)
    local dec_start = cosock.socket.gettime()
    local f = assert(Frame.decode(bytes))
    local dec_end = cosock.socket.gettime()
    assert.are(#f.payload, f.header:payload_len())
    assert.are(f:len(), #bytes)
    utils.assert_fmt(f.header:is_masked(), "Not masked...")
    local enc_start = cosock.socket.gettime()
    local back = f:encode()
    local enc_end = cosock.socket.gettime()
    assert.are(bytes, back)
    local f2 = assert(Frame.decode(back))

    assert.are(f, f2)
  end)
  describe("constructors", function()
    it("ping", function()
      local f = Frame.ping("")
      assert.are(f.header.opcode, OpCode.ping())
    end)
    it("pong", function()
      local f = Frame.pong("")
      assert.are(f.header.opcode, OpCode.pong())
    end)
    it("close", function()
      local f = Frame.close(CloseCode.normal())
      assert.are(f.header.opcode, OpCode.close())
      assert.are(f.payload, CloseCode.normal():encode())
    end)
  end)
  describe("decode", function()
    it("ping #t", function()
      local f = assert(Frame.from_stream(MockSocket.new({
        string.char(0x89, 0x02),
        string.char(0x01, 0x02),
      })))
    end)
  end)
end)
