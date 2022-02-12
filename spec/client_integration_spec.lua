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
local Config = require "lustre.config"
local Message = require "lustre.message"
local dkjson = require "dkjson"
local lfs = require "lfs"
local log = require "log"

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
        case = reports[k].case,
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

local function generate_websocket(case)
  log.trace("generate_websocket", case)
  local sock, err = socket.tcp()
  if err then assert(false, err) end
  local config = Config.default()
  local websocket = ws.client(sock, "/runCase?case=" .. case .. "&agent=lua-lustre", config)
  websocket.id = case
  log.info(case, "connecting websocket")
  assert(websocket:connect(HOST, PORT))
  return websocket
end

local function echo_client(websocket)
  while true do
    log.info(websocket.id, "receiving on websocket")
    msg, err = websocket:receive()
    log.info(websocket.id, "websocket received", (msg and msg.type) or ("Error: " .. err))
    if not msg then
      if err == "closed" then
        return 1
      end
      return nil, err, websocket.id
    end
    log.info(websocket.id, "sending on websocket")
    if msg.type == Message.TEXT then
      s, err = websocket:send_text(msg.data)
    else
      s, err = websocket:send_bytes(msg.data)
    end
    log.info(websocket.id, "websocket sent", (s and "successfully") or ("unsuccessfully: " .. err))
    if not s then
      if err == "closed" then
        return 1
      end
      return nil, err
    end
  end
end

local function echo_clients(cases)
  log.trace("echo_client", table.concat(cases, ', '))
  if #cases == 1 then
    return echo_client(generate_websocket(cases[1]))
  end
  local websockets = {}
  for _, case in ipairs(cases) do
    table.insert(websockets, generate_websocket(case))
  end

  local s, msg, err, rcvrs
  while true do
    assert(#websockets > 0)
    rcvrs = assert(cosock.socket.select(websockets))
    local websocket = rcvrs[1]
    log.info(websocket.id, "receiving on websocket")
    msg, err = websocket:receive()
    log.info(websocket.id, "websocket received", (msg and msg.type) or ("Error: " .. err))
    if not msg then
      if err == "closed" then
        return 1
      end
      return nil, err, websocket.id
    end
    log.info(websocket.id, "sending on websocket")
    if msg.type == Message.TEXT then
      s, err = websocket:send_text(msg.data)
    else
      s, err = websocket:send_bytes(msg.data)
    end
    log.info(websocket.id, "websocket sent", (s and "successfully") or ("unsuccessfully: " .. err))
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
  local lines = {"Test Failures: "}
  local ct = 0
  for id, failure in pairs(failures) do
    ct = ct + 1
    local json = dkjson.encode(failure, { indent = true })
    table.insert(lines, string.format("----%s(%s)----", id, failure.case or "???"))
    table.insert(lines, json)
    table.insert(lines, string.format("----%s(%s)----", id, failure.case or "???"))
  end
  print("reporting %s lines of failures", #lines)
  if #lines > 1 then
    table.insert(lines, string.format("Failure count: %s", ct))
    error(table.concat(lines, '\n'))
  end
end

describe("autobahn test cases #conformance", function()
  it("run", function()
    cosock.spawn(function()
      
      local tx, rx = cosock.channel.new()
      rx:settimeout(3)
      local start = 1
      local total_cases
      local maybe_test = os.getenv("LUSTRE_TEST_CASE")
      if type(maybe_test) == "string" then
        total_cases = tonumber(maybe_test)
        banner_print("running test", maybe_test)
        start = total_cases
      else
        banner_print("Getting number of cases")
        total_cases = assert(get_num_test_cases())
      end
      local err_msgs = {}
      -- run the first 2 cases to run concurrently to flex the `select` usage
      if start == 1 then
        start = start + 2
        local result, err, err_id = echo_clients({"1", "2"})
        if not result then
          err_msgs[err_id or 1] = (err_msgs[err_id or 1] or "") .. "\t" ..err
        end
      end
      for i = start, total_cases, 2 do
        banner_print("case: ", i)
        local s = os.time()
        local result, err, err_id = echo_clients({tostring(i)})
        local e = os.time()
        if not result then
          err_msgs[err_id] = (err_msgs[err_id] or "") .. "\t" ..err
        end
        if os.difftime(e, s) > 1 then
          log.warn("Test "  .. tostring(i) .. "too more than 1 sec" .. tostring(os.difftime(e, s)))
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

