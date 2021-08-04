local utils = require "spec.utils"
local WebSocketClient = require "lustre.client"
local MockSocket = require "spec.mock_socket".MockSocket
local Frame = require "lustre.frame"
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local Message = require "lustre.message"

describe('client', function ()
    it("Send TEXT message that results in a single frame on the socket", function()
        local message_data = "this is a short message"
        local exp_frame_header = FrameHeader.default()
            :set_fin(true)
            :set_opcode(OpCode.text())
            :set_length(#message_data)
        local exp_frame = Frame.from_parts(exp_frame_header, message_data)
        local socket = MockSocket.new({}, {}) --were not receiving anything we are just sending
        local client = WebSocketClient.new(socket)
        client:send(Message.new(Message.TEXT, message_data))
        assert(socket.sent == #exp_frame:encode()) 
    end)
    it("Send BYTEs message that results in a single frame on the socket", function()

    end)
    it("Masking is performed when sending a message", function()

    end)
    it('single frame message is received successfully', function ()
        
    end)
    it('multi frame message is received successfully', function ()

    end)
    it('received close frame is echoed', function ()

    end)
    it('received close frame closes socket if client has called close', function ()

    end)
    it('client:close() sends a close frame', function ()

    end)
    it('ping replied to with pong', function ()

    end)
    it('control flow handled wduring multi frame message', function ()

    end)
end)