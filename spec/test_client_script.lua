local websocket = require "lustre.ws"
local socket = require 'cosock'.socket
local timer = require 'cosock'.timer
local utils = require "utils"
local CloseCode = require "lustre.frame.close"


local HOST = "123.123.123.123"
local PORT = 9000


local function green_light_echo()
    local url = "/"
    local sock, err = socket.tcp()
    if err then print("ERROR: ", err) end
    local r, err = sock:connect(HOST, PORT)
    if err then print("ERROR: ", err) end

    local config = nil
    local websocket = ws:new(sock, url, config)
    print("Created websocket:\n", utils.stringify_table(websocket))

    local success, err = websocket:open()
    if err then
        print("!!Failed to open: ", err)
        exit()
    end

    local data = "asdfasdfasdf"
    local bytes, err = websocket:send_text(data)
    if err then
        print("!!Failed to send: ", err)
        exit()
    end

    local msg, err = websocket:receive()
    if msg then
        print("!!Received echo from echoserver: ", msg.data)
    else
        print("!!Failed to receive: ", err)
        print("\tnot exiting")
    end

    local close_code = CloseCode.normal()
    local reason = "Because I want to!"
    local err = websocket:close(close_code, reason)
    if err then
        print("!!Failed to close connection: ", err)
        exit()
    end
end

green_light_echo()
