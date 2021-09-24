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

local function read_report_file(name)
  local full_path = string.format("spec/reports/clients/%s", name)
  local f = assert(io.open(full_path, "r"), string.format("failed to open %s", full_path))
  return assert(f:read("a"), string.format("nil contents for %s", full_path))
end

local function collect_failures()
  local contents = read_report_file("index.json")
  local t = assert(dkjson.decode(contents), "Invalid json for index.json")
  local results = assert(t["lua-lustre"], "Invalid object shape, expected `lua-luster`")
  local not_ok = {}
  for k, v in pairs(results) do
    if v.behavior == "FAILED" then
      if not ALLOWED_FAILURES[k] then
        print("Failed", k, v.behavior)
        v.id = k
        table.insert(not_ok, v)
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

local function echo_client(tx, case)
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  websocket:register_message_cb(function(msg)
    local err
    if msg.type == Message.TEXT then
      err = websocket:send_text(msg.data)
    else
      err = websocket:send_bytes(msg.data)
    end
    if err then print("ECHOERROR: "..err) end
  end):register_error_cb(function(err)
    print(case, "ERROR: ", err)
    tx:send(case)
  end):register_close_cb(function(arg)
    print(case, "INFO: Connection closed. ", arg)
    tx:send(case)
  end)
  print(case, "INFO: Connecting websocket")
  local success, err = websocket:connect(HOST, PORT)
  if err then assert(false, err) end
end

local function update_reports(tx)
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  websocket:register_message_cb(
    function(msg) print("ERR shouldn't have received msg: ", msg.data) end)
  websocket:register_error_cb(print)
  websocket:register_close_cb(function()
    tx:send()
  end)
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

local function report_failures(failures)
  local throw = false
  local lines = {"Test Failures:"}
  for _, failure in ipairs(failures) do
    throw = true
    local report = read_report_file(failure.reportfile)
    table.insert(lines, report)
  end
  if #lines > 1 then
    error(table.concat(lines))
  end
end

describe("autobahn test cases", function()
  it("run", function()
    cosock.spawn(function()
      banner_print("Getting number of cases")
      get_num_test_cases()
      local tx, rx = cosock.channel.new()
      for i = 1, total_cases + 4 do
        if i <= total_cases then
          cosock.spawn(function()
            local i = i
            echo_client(tx, i)
          end, string.format("test %s", i))
        end
        if i > 4 then
          local finished = rx:receive()
          banner_print("case: ", finished)
        end
      end
      banner_print("Updating reports")
      update_reports(tx)
      rx:receive()
      banner_print("Checking results")
      local not_ok = collect_failures()
      report_failures(not_ok)
    end, "autobahn tests")
    cosock.run()
  end)
end)

