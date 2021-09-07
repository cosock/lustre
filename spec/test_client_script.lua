local ws = require "lustre.ws"
local socket = require 'socket'
local timer = require 'cosock'.timer
local utils = require "luncheon.print"
local CloseCode = require "lustre.frame.close"


--- Autobahn test framework echo server
--- Start it with:
--- `docker run -it -p 9000:9000 crossbario/autobahn-testsuite wstest -d -m echoserver -w ws://localhost:9000`
local HOST = "127.0.0.1"
local PORT = 9000


local function green_light_echo()
    local url = "/"
    local sock, err = socket.tcp()
    print("INFO: Getting tcp socket")
    if err then
        print("ERROR: ", err)
        return
    end

    local r, err = sock:connect(HOST, PORT)
    print("INFO: Connecting to tcp socket")
    if not r then
        print("ERROR: ", err)
        return
    end

    local config = nil
    local websocket = ws.client(sock, "/", config):register_message_cb(
        function (msg)
            print("INFO: Received msg: ", msg.data)
        end)

    print("INFO: Connection websocket")
    local success, err = websocket:connect()
    if err then
        print("ERROR: ", err)
        return
    end

    local data = "asdf"
    print("INFO: Sending text ", data)
    local bytes, err = websocket:send_text(data)
    if err then
        print("ERROR: ", err)
        return
    end

    local msg, err = websocket:receive()
    if msg then
        print("!!Received echo from echoserver: ", msg.data)
    else
        print("!!Failed to receive: ", err)
        exit()
    end

    local close_code = CloseCode.normal()
    local reason = "Because I want to!"
    local err = websocket:close(close_code, reason)
    if err then
        print("!!Failed to close connection: ", err)
        return
    end
end

green_light_echo()


--[[
--should this work with cosock locally? Probably
local co = coroutine.create(green_light_echo)
while not done do
    if coroutine.status(co) == "suspended" then
        print("**Coroutine resuming: ",
              coroutine.resume(co))
        
    elseif coroutine.status(co) == "dead" then
        print("**coroutine dead:")
        done = true
    end
end
--]]
