local Handshake = require 'lustre.handshake'

local ServerWebSocket = {}
ServerWebSocket.__index = ServerWebSocket

function ServerWebSocket.new(config)
  return setmetatable({
    config = config,
    accept_callback = function() return true end
  }, ServerWebSocket)
end

function ServerWebSocket:set_accept_callback(cb)
  self.accept_callback = cb
  return self
end

function ServerWebSocket:accept(req, res)
  local should_accept = self.accept_callback(req, res)
  local hs = Handshake.server(req, res)
  assert(not res:has_sent(), 'Error, cannot send response data during accept')
  if not should_accept then
    res:send('')
    return nil, 'error during accept'
  end
end

return ServerWebSocket
