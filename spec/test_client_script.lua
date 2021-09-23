local ws = require "lustre.ws"
local cosock = require "cosock"
local socket = cosock.socket
local CloseCode = require"lustre.frame.close".CloseCode
local Config = require "lustre.config"

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
  local data = "asdf"
  local config = Config.default():protocol("Gabbo")
  local recvd = false
  local websocket = ws.client(sock, "/", config)
  websocket:register_message_cb(function(msg)
    recvd = true
    print("INFO: Received msg: ", msg.data)
    -- check the messages are in fact echo'd
    assert(msg.data == data)
    -- close the web socket
    local close_code = CloseCode.normal()
    local reason = "Because I want to!"
    assert(websocket:close(close_code, reason))
  end):register_error_cb(function(err)
    recvd = true
    -- try to close the websocket on our end
    local close_code = CloseCode.normal()
    websocket:close(close_code, err)
    -- raise an error on errors
    error(err)
  end)

  print("INFO: Connection websocket")
  local success, err = websocket:connect(HOST, PORT)
  if err then
    print("ERROR: ", err)
    return
  end

  print("INFO: Sending text ", data)
  local bytes, err = websocket:send_text(data)
  if err then
    print("ERROR: ", err)
    return
  end
end

local function test_keep_alive()
  local url = "/"
  local sock, err = socket.tcp()
    print("INFO: Getting tcp socket")
  if err then
    print("ERROR: ", err)
    return
  end
  local data = "asdf"
  local config = Config.default():protocol("gabbo"):keep_alive(3)
  local recvd = false
  local websocket = ws.client(sock, "/", config)
  websocket:register_message_cb(function(msg)
    print("RECEIVED: ", msg.data)
  end):register_error_cb(function(err)
    print("ERR: "..err)
  end):register_close_cb(function(reason)
    print("CLOSED: "..reason)
  end)

  print("INFO: Connection websocket")
  local success, err = websocket:connect(HOST, PORT)
  if err then
    print("ERROR: ", err)
    return
  end

  while true do
    --[[]]
    print("INFO: Sending text ", data)
    local bytes, err = websocket:send_text(data)
    if err then
      print("ERROR: ", err)
      return
    end
    --]]
    print("sleeping")
    socket.sleep(8)
  end
end

cosock.spawn(green_light_echo, "green_light_echo")
cosock.spawn(test_keep_alive, "keep_alive")

cosock.run()
