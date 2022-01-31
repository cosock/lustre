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
        reports[t.case] = t
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
  for k, v in pairs(results) do
    if v.behavior == "FAILED" then
      not_ok[k] = {
        expectation = reports[k].expectation,
        result = reports[k].result,
        expected = reports[k].expected,
        received = reports[k].received,
        case = reports[k].case,
      }
    end
  end
  for idx, msg in pairs(err_msgs) do
    local report = assert(reports[idx], "invalid report index" .. tostring(idx))
    if not_ok[report.id] then
      not_ok[report.id] = { not_ok[report.id], msg }
    else
      not_ok[report.id] = {
        case = report.case,
        msg = msg,
      }
    end
  end
  return not_ok
end

local function banner_print(...)
  print("*********************************************************")
  print(...)
  print("*********************************************************")
end

local function echo_client(case)
  should_print = case == 63 or case == 64
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  websocket.id = case
  local closed = false
  local tx, rx = cosock.channel.new()
  local s, err
  websocket:register_message_cb(function(msg)
    if msg.type == Message.TEXT then
      s, err = websocket:send_text(msg.data)
    else
      s, err = websocket:send_bytes(msg.data)
    end
    if not s then
      tx:send({ err = string.format("%s ECHOERROR: %s", case, err)})
    end
  end):register_error_cb(function(err)
    print(case, "ERROR: ", err)
    tx:send({err = string.format("%s ERROR: %s", case, err)})
  end):register_close_cb(function(arg)
    assert(not closed, 'ERROR: duplicate close in '..tostring(case)..tostring(arg))
    closed = true
    tx:send({ok = 1})
  end)
  assert(websocket:connect(HOST, PORT))
  local res = rx:receive()
  return res.ok, res.err
end

local function update_reports()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/updateReports?agent=lua-lustre", config)
  local tx, rx = cosock.channel.new()
  websocket:register_message_cb(
    function(msg)
      tx:send(nil, string.format("ERR shouldn't have received msg: %s", msg.data))
    end)
  websocket:register_error_cb(function (msg)
    tx:send(nil, msg)
  end)
  websocket:register_close_cb(function()
    tx:send(1)
  end)
  assert(websocket:connect(HOST, PORT))
  return rx:receive()
end

local function get_num_test_cases()
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/getCaseCount", config)
  local tx, rx = cosock.channel.new()
  websocket:register_message_cb(function(msg)
    tx:send(tonumber(msg.data))
  end)
  websocket:register_error_cb(function (msg)
    tx:send(nil, msg)
  end)
  assert(websocket:connect(HOST, PORT))
  return rx:receive()
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

describe("autobahn test cases", function()
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

