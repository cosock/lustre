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
--]]
local ws = require "lustre.ws"
local cosock = require "cosock"
local socket = cosock.socket
local CloseCode = require"lustre.frame.close".CloseCode
local Config = require "lustre.config"
local Message = require "lustre.message"
local dkjson = require "dkjson"

local HOST = "127.0.0.1"
local PORT = 9001
local case = 1
local total_cases = 0
local ALLOWED_FAILURES = {
  ["1.1.7"] = true,
  ["1.1.8"] = true,
  ["1.2.1"] = true,
  ["1.2.2"] = true,
  ["1.2.7"] = true,
  ["1.2.8"] = true,
  ["2.2"]   = true,
  ["2.6"]   = true,
  ["2.11"]   = true,
  ["5.5"]   = true,
  ["5.8"]   = true,
  ["5.19"] =  true,
  ["5.20"] =  true,
}

local function collect_failures()
  local f = assert(io.open("spec/reports/clients/index.json", "r"), "failed to open spec/reports/clients/index.json")
  local contents = assert(f:read("a"), "nil contents for spec/reports/clients/index.json")
  local t = assert(dkjson.decode(contents), "Invalid json for spec/reports/clients/index.json")
  local results = assert(t["lua-lustre"], "Invalid object shape, expected `lua-luster`")
  local not_ok = {}
  for k, v in pairs(results) do
    if v.behavior == "FAILED" then
      if not ALLOWED_FAILURES[k] then
        print("Failed", k, v.behavior)
        table.insert(not_ok, k)
      else
        print("Ignoring failure", k)
      end
    elseif ALLOWED_FAILURES[k] then
      print("Unexpected success:", k, v.behavior)
    end
  end
  return not_ok
end

local function banner_print(...)
  print("*********************************************************")
  print(...)
  print("*********************************************************")
end

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
  local done = false
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  websocket:register_message_cb(
    function(msg) print("ERR shouldn't have received msg: ", msg.data) end)
  websocket:register_error_cb(print)
  websocket:register_close_cb(function()
    done = true
  end)
  local success, err = websocket:connect(HOST, PORT)
  if err then assert(false, err) end
  local success, err = websocket:close()
  if err then assert(false, err) end
  while not done do
    cosock.socket.sleep(0.5)
  end
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
      banner_print("Getting number of cases")
      get_num_test_cases()
      for i = 1, total_cases do
        banner_print("case: ", i)
        echo_client()
      end
      banner_print("Updating reports")
      update_reports()
      banner_print("Checking results")
      local not_ok = collect_failures()
      if #not_ok > 0 then
        error(string.format("Failed tests: %s", table.concat(not_ok, ',')))
      end
    end, "autobahn tests")
    cosock.run()
  end)
end)

