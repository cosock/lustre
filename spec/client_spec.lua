--- There must be an autobahn fuzzing server running with the following config
--- to allow for the tests to pass.
---
--- `docker run -it -p 9001:9001 -v "/home/parallels/lustre/spec:/config" crossbario/autobahn-testsuite wstest -d -m fuzzingserver -s /config/fuzzingserver.json`
--[[
TODO config
TODO docker start cmd
]]

local ws = require "lustre.ws"
local cosock = require "cosock"
local socket = cosock.socket
local CloseCode = require "lustre.frame.close".CloseCode
local Config = require "lustre.config"
local Message = require "lustre.message"

local HOST = "127.0.0.1"
local PORT = 9001
local case = 1
local total_cases = 0

local function echo_client()
  local sock, err = socket.tcp()
  if err then
      assert(false, err)
  end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case="..case.."&agent=lua-lustre", config)
  case = case + 1
  websocket:register_message_cb(
  function (msg)
    local err
    if msg.type == Message.TEXT then
      print("echoing text")
      err = websocket:send_text(msg.data)
    else
      print("echoing bytes") 
      err = websocket:send_bytes(msg.data)
    end
    if err then print("ECHOERROR") end
    local close_code = CloseCode.normal()
    local reason = ""
    --print("CLOSING")
    --assert(websocket:close(close_code, reason))
  end):register_error_cb(print)
  print("INFO: Connecting websocket")
  print(os.clock(), " connect: ")
  local success, err = websocket:connect(HOST, PORT)
  print(os.clock(), "end connect: ")
  if err then
      assert(false, err)
  end
end

local function update_reports()
  local sock, err = socket.tcp()
  if err then
      assert(false, err)
  end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  websocket:register_message_cb(
  function (msg)
    print("ERR shouldn't have received msg: ", msg.data)
  end)
  websocket:register_error_cb(print)
  local success, err = websocket:connect(HOST, PORT)
  if err then
      assert(false, err)
  end
  local success, err = websocket:close()
  if err then
      assert(false, err)
  end
end

local function get_num_test_cases()
  local sock, err = socket.tcp()
  if err then
      assert(false, err)
  end
  local config = Config.default()
  local websocket = ws.client(sock, "/getCaseCount", config)
  websocket:register_message_cb(
  function (msg)
    print("Received total cases ", msg.data)
    total_cases = tonumber(msg.data)
  end)
  websocket:register_error_cb(print)
  local success, err = websocket:connect(HOST, PORT)
  if err then
      assert(false, err)
  end
  local success, err = websocket:close()
  if err then
      assert(false, err)
  end

end

describe("autobahn test cases", function()
  it("run", function()
    print("*********************************************************")
    print("Getting number of cases")
    print("*********************************************************")
    cosock.spawn(get_num_test_cases, "get_num_test_cases")
    cosock.run()
    for i=1, total_cases do
      print("*********************************************************")
      print("case: ", i)
      print("*********************************************************")
      cosock.spawn(echo_client, "echo")
      cosock.run()
    end
    print("*********************************************************")
    print("Updating reports")
    print("*********************************************************")
    cosock.spawn(update_reports, "report_update")
    cosock.run()
  end)
end)

