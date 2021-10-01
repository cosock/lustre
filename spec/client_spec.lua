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
local ALLOWED_FAILURES = {
  ["1.1.7"] = true,
  ["1.2.7"] = true,
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
  should_print = case == 63 or case == 64
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  websocket.id = case
  websocket:register_message_cb(function(msg)
    local err
    if msg.type == Message.TEXT then
      err = websocket:send_text(msg.data)
    else
      err = websocket:send_bytes(msg.data)
    end
    if err then print(case, "ECHOERROR: "..err) end
  end):register_error_cb(function(err)
    print(case, "ERROR: ", err)
    tx:send(err)
  end):register_close_cb(function(arg)
    print(case, "INFO: Connection closed. ", arg)
    tx:send(1)
  end)
  print(case, "INFO: Connecting websocket")
  assert(websocket:connect(HOST, PORT))
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
    tx:send(1)
  end)
  local success, err = websocket:connect(HOST, PORT)
  if err then assert(false, err) end
  local success, err = websocket:close()
  if err then assert(false, err) end
end

local function get_num_test_cases(tx)
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/getCaseCount", config)
  websocket:register_message_cb(function(msg)
    print("Received total cases ", msg.data)
    local total_cases = tonumber(msg.data)
    local success, err = websocket:close()
    if err then error(err) end
    tx:send(total_cases)
  end)
  websocket:register_error_cb(print)
  local success, err = websocket:connect(HOST, PORT)
  if err then error(err) end
  print("Connected for case count")
end

local function report_failures(failures, err_msgs)
  local throw = false
  local lines = {"Test Failures:"}
  local errors = {}
  for _, failure in ipairs(failures) do
    throw = true
    local report = read_report_file(failure.reportfile)
    local json = dkjson.decode(report)
    table.insert(errors, string.format("%s: %s", json.case, json.id))
    if json and json.case and err_msgs[json.case] then
      report = report .. '\n' .. err_msgs[json.case]
    end
    table.insert(lines, report)
  end
  if #lines > 1 then
    error(table.concat(errors, '\n'))
  end
end

describe("autobahn test cases", function()
  it("run", function()
    cosock.spawn(function()
      banner_print("Getting number of cases")
      local tx, rx = cosock.channel.new()
      get_num_test_cases(tx)
      local total_cases = assert(rx:receive())
      local err_msgs = {}
      for i = 1, total_cases do
        banner_print("case: ", i)
        echo_client(tx, i)
        cosock.socket.sleep(1)
        result = rx:receive()
        if type(result) == 'string' then
          err_msgs[i] = result
          print(result)
        end
      end
      banner_print("Updating reports")
      update_reports(tx)
      rx:receive()
      banner_print("Checking results")
      local not_ok = collect_failures()
      report_failures(not_ok, err_msgs)
    end, "autobahn tests")
    cosock.run()
  end)
end)

