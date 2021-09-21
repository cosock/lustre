--- There must be an autobahn fuzzing server running to allow for the tests to pass.
---
--[[
Start the autobahn test container
```
docker run -it -p 9001:9001 \
    -v "$PWD/spec/config:/config" \
    -v "$PWD/spec/reports:/reports" \
    -d crossbario/autobahn-testsuite \
    wstest -d -m fuzzingserver -s /config/fuzzingserver.json
```
Run the test cases
```
busted /path/to/lustre/spec/client_spec.lua
```
--]] local ws = require "lustre.ws"
local cosock = require "cosock"
local socket = cosock.socket
local CloseCode = require"lustre.frame.close".CloseCode
local Config = require "lustre.config"
local Message = require "lustre.message"

local HOST = "127.0.0.1"
local PORT = 9001
local case = 1
local total_cases = 0

local function echo_client()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  case = case + 1
  websocket:register_message_cb(function(msg)
    local err
    if msg.type == Message.TEXT then
      err = websocket:send_text(msg.data)
    else
      err = websocket:send_bytes(msg.data)
    end
    if err then print("ECHOERROR: "..err) end
  end):register_error_cb(function(err)
    print("ERROR: ", err)
  end):register_close_cb(function(arg)
    print("INFO: Connection closed. ", arg)
  end)
  print("INFO: Connecting websocket")
  local success, err = websocket:connect(HOST, PORT)
  if err then assert(false, err) end
end

local function update_reports()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  websocket:register_message_cb(
    function(msg) print("ERR shouldn't have received msg: ", msg.data) end)
  websocket:register_error_cb(print)
  local success, err = websocket:connect(HOST, PORT)
  if err then assert(false, err) end
  local success, err = websocket:close()
  if err then assert(false, err) end
end

local function get_num_test_cases()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/getCaseCount", config)
  websocket:register_message_cb(function(msg)
    print("Received total cases ", msg.data)
    total_cases = tonumber(msg.data)
    local success, err = websocket:close()
    if err then error(err) end
  end)
  websocket:register_error_cb(print)
  local success, err = websocket:connect(HOST, PORT)
  if err then error(err) end
  print("Connected for case count")
  while total_cases < 1 do
    cosock.socket.sleep(0.5)
  end
end

describe("autobahn test cases", function()
  it("run", function()
    cosock.spawn(function()
      print("*********************************************************")
      print("Getting number of cases")
      print("*********************************************************")
      get_num_test_cases()
      for i = 1, total_cases do
        print("*********************************************************")
        print("case: ", i)
        print("*********************************************************")
        echo_client()
      end
      print("*********************************************************")
      print("Updating reports")
      print("*********************************************************")
      update_reports()
    end, "autobahn tests")
    cosock.run()
  end)
end)

