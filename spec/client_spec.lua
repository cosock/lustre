--[[
local utils = require "spec.utils"
local WebSocketClient = require "lustre.client"
local MockSocket = require "spec.mock_socket".MockSocket
local Frame = require "lustre.frame"
local FrameHeader = require "lustre.frame.frame_header"
local OpCode = require "lustre.frame.opcode"
local Message = require "lustre.message"
local CloseCode = require "lustre.frame.close".CloseCode

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
    --I dont think this is actually testing anything, but Im not sure how to test doing it with bytes
    it("Send BYTEs message that results in a single frame on the socket", function()
        local message_data = "this is a short message"
        local exp_frame_header = FrameHeader.default()
            :set_fin(true)
            :set_opcode(OpCode.binary())
            :set_length(#message_data)
        local exp_frame = Frame.from_parts(exp_frame_header, message_data)
        local socket = MockSocket.new({}, {}) --were not receiving anything we are just sending
        local client = WebSocketClient.new(socket)
        client:send(Message.new(Message.BYTES, message_data))
        assert(socket.sent == #exp_frame:encode()) 
    end)
    it("Masking is performed when sending a message", function()

    end)
    it("Send message that results in multiple frames on the wire", function()

    end)
    it("Receive too many frames to fit the payload into the message", function()

    end)
    it('client:close() sends a close frame', function ()
        local close_code = CloseCode.normal()
        local reason = "time to die"
        local exp_close_frame = Frame.close(close_code, reason):set_mask()
        local socket = MockSocket.new({}, {}, {})
        local client = WebSocketClient.new(socket)
        client:close(close_code, reason)
        assert(socket.sent == #exp_close_frame:encode(), string.format("%d ~= %d", socket.sent, #exp_close_frame:encode()))
    end)
    it('single frame message is received successfully', function ()
        
    end)
    it('multi frame message is received successfully', function ()

    end)
    it('received close frame is echoed', function ()

    end)
    it('received close frame closes socket if client has called close', function ()

    end)
    it('ping replied to with pong', function ()
        --[[
        I dont think we can start the receive loop because the mock socket doesn't act how
        cosock expects it to act. When I run the test below I get:
        ```
        /usr/local/share/lua/5.3/cosock/cosocket.lua:83: attempt to yield from outside a coroutine
        ```
        How do we test the receive loop?
        ]]
        --[[
        local payload = 'junk'
        local exp_pong_frame = Frame.pong(payload):encode()
        local socket = MockSocket.new({
            Frame.ping(payload):encode()
        }, {}, {})
        local client = WebSocketClient.new(socket)
        client:start_receive_loop()
        socket:receive()
        assert(socket.sent == #exp_pong_frame)
        --
    end)
    it('control flow handled during multi frame message', function ()

    end)
end)
--]]