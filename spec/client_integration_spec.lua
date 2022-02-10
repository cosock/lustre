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
local lfs = require "lfs"

local HOST = "127.0.0.1"
local PORT = 9001

local function read_report_file(name)
  local full_path = string.format("spec/reports/clients/%s", name)
  local f = assert(io.open(full_path, "r"), string.format("failed to open %s", full_path))
  return assert(f:read("a"), string.format("nil contents for %s", full_path))
end

local function collect_all_reports()
  local reports = {}
  for path in lfs.dir("spec/reports/clients") do
    if string.match(path, "%.json$") then
      local report_json = read_report_file(path)
      local t = assert(dkjson.decode(report_json))
      if string.match(path, "^index%.json$") then
        reports.index = t
      else
        reports[tostring(t.case)] = t
        reports[t.id] = t
      end
    end
  end
  return reports
end

local function collect_failures(err_msgs)
  local reports = collect_all_reports()
  local results = assert(reports.index["lua-lustre"], "Invalid object shape, expected `lua-lustre`")
  local not_ok = {}
  print("collecting failed results")
  for k, v in pairs(results) do
    if v.behavior == "FAILED" then
      not_ok[k] = {
        expectation = reports[k].expectation,
        result = reports[k].result,
        expected = reports[k].expected,
        received = reports[k].received,
      }
    end
  end
  print("collecting error messages")
  for idx, msg in pairs(err_msgs) do
    local report = reports[tostring(idx)] or {id = idx}
    if not_ok[report.id] then
      not_ok[report.id] = { not_ok[report.id], msg }
    else
      not_ok[report.id] = msg
    end
  end
  print("collection complete")
  return not_ok
end

local function banner_print(...)
  print("*********************************************************")
  print(...)
  print("*********************************************************")
end

local function echo_client(case)
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  websocket.id = case
  local s, msg, err
  assert(websocket:connect(HOST, PORT))
  while true do
    msg, err = websocket:receive()
    if not msg then
      if err == "closed" then
        return 1
      end
      return nil, err
    end
    if msg.type == Message.TEXT then
      s, err = websocket:send_text(msg.data)
    else
      s, err = websocket:send_bytes(msg.data)
    end
    if not s then
      if err == "closed" then
        return 1
      end
      return nil, err
    end
  end
end

local function update_reports()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  websocket.id = "update_reports"
  assert(websocket:connect(HOST, PORT))
  while true do
    local msg, err = websocket:receive()
    if not msg then
      if err == "closed" then
        return 1
      end
      return nil, err
    end
    print('received message from updateReports', msg)
  end
end

local function get_num_test_cases()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/getCaseCount", config)
  websocket.id = "get_num_test_cases"
  websocket:connect(HOST, PORT)
  local res, err = websocket:receive()
  print("num test cases result", res, err)
  return tonumber(res.data), err
end

local function report_failures(failures)
  local lines = {"Test Failures:"}
  for id, failure in pairs(failures) do
    local json = dkjson.encode(failure, { indent = true })
    table.insert(lines, string.format("----%s----", id))
    table.insert(lines, json)
    table.insert(lines, string.format("----%s----", id))
  end
  if #lines > 1 then
    error(table.concat(lines, '\n'))
  end
end

describe("autobahn test cases #conformance", function()
  it("run", function()
    cosock.spawn(function()
      banner_print("Getting number of cases")
      local tx, rx = cosock.channel.new()
      rx:settimeout(3)
      local start = 1
      local total_cases
      local maybe_test = os.getenv("LUSTRE_TEST_CASE")
      if type(maybe_test) == "string" then
        total_cases = tonumber(maybe_test)
        start = total_cases
      else
        total_cases = assert(get_num_test_cases())
      end
      local err_msgs = {}
      for i = start, total_cases do
        banner_print("case: ", i)
        local result, err = echo_client(i)
        if not result then
          err_msgs[i] = (err_msgs[i] or "") .. "\t" ..err
        end
      end
      banner_print("Updating reports")
      assert(update_reports())
      banner_print("Checking results")
      local not_ok = collect_failures(err_msgs)
      report_failures(not_ok)
    end, "autobahn tests")
    cosock.run()
  end)
end)

