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

local HOST = "127.0.0.1"
local PORT = 9001
local case = 1

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
    local err = websocket:send_text(msg.data)
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
  print("INFO: Requesting report generation")
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
  describe("client text handling", function()
    it("1.1.1", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 1")
    end)
    it("1.1.2", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 2")
    end)
    it("1.1.3", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 3")
    end)
    it("1.1.4", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 4")
    end)
    it("1.1.5", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 5")
    end)
    it("1.1.6", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 6")
    end)
    it("1.1.7", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 7")
    end)
    it("1.1.8", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 8")
    end)
  end)
  describe("ping/pong handling", function()
    it("2.1", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 1")
    end)
    it("2.2", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 2")
    end)
    it("2.3", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 3")
    end)
    it("2.4", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 4")
    end)
    it("2.5", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 5")
    end)
    it("2.6", function()
      cosock.spawn(echo_client, "echo")
      cosock.run()
      print("finished 6")
    end)
  end)
end)

cosock.spawn(update_reports, "report_update")
cosock.run()
