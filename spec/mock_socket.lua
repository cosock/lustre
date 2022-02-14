---TCP Client Socket
local MockSocket = {}
MockSocket.__index = MockSocket

function MockSocket.new(inner, send_errs)
  local ret = {
    recvd = 0,
    sent = 0,
    inner = inner or {},
    open = true,
    timeouts = 0,
    send_errs = send_errs or {},
  }
  setmetatable(ret, MockSocket)
  return ret
end

function MockSocket:bind(ip, port) return 1 end

function MockSocket:listen(backlog) return 1 end

function MockSocket:getsockname() return "0.0.0.0", 0 end

function MockSocket:getstats() return self.recvd, self.sent end

function MockSocket:close()
  self.open = false
  return 1
end

function MockSocket.new_with_preamble(method, path)
  return MockSocket.new({
    string.format("%s %s HTTP/1.1", string.upper(method), path),
  })
end

function MockSocket:receive()
  if #self.inner == 0 then return nil, "empty" end
  local part = table.remove(self.inner, 1)
  if part == "timeout" or part == "closed" then return nil, part end
  self.recvd = self.recvd + #(part or "")
  return part
end

function MockSocket:send(s)
  if s == "timeout" or s == "closed" or s == "error" then return nil, s end
  local err, ct = string.match(s, "^(timeout)(%d)$")
  if not err then err, ct = string.match(s, "^(error)(%d)$") end
  if err then
    local target = math.tointeger(ct)
    if (self.timeouts or 0) < target then
      self.timeouts = (self.timeouts or 0) + 1
      return nil, err
    end
  end
  if string.find(s, "panic") and not self.panicked then
    self.panicked = true
    error("panic")
  end
  if next(self.send_errs) then return nil, table.remove(self.send_errs, 1) end
  self.inner = self.inner or {}
  self.sent = self.sent + #(s or "")
  if string.find(s, "clear") then
    self.inner = {}
    return
  end
  table.insert(self.inner, s)
  if s then return #s end
end

---TCP Master Socket
local MockTcp = {}
MockTcp.__index = MockTcp

function MockTcp.new(inner)
  local ret = {inner = inner or {}}
  setmetatable(ret, MockTcp)
  return ret
end

function MockTcp:accept()
  local list = assert(table.remove(self.inner))
  return MockSocket.new(list)
end

function MockTcp:bind(ip, port) return 1 end

function MockTcp:listen(backlog) return 1 end

function MockTcp:getsockname() return "0.0.0.0", 0 end

local MockModule = {}
MockModule.__index = MockModule
local sockets
function MockModule.new(inner)
  sockets = inner or {}
  return MockModule
end
function MockModule.tcp()
  local list = assert(table.remove(sockets), "No sockets in the list")
  return MockTcp.new(list)
end
function MockModule.bind(ip, port) return 1 end

return {MockSocket = MockSocket, MockTcp = MockTcp, MockModule = MockModule}
