local Handshake = require 'lustre.handshake'

local WebSocketServer = {}
WebSocketServer.__index = WebSocketServer

function WebSocketServer.new(config)
  return setmetatable({
    config = config,
    accept_callback = function() return true end
  }, WebSocketServer)
end

function WebSocketServer:set_accept_callback(cb)
  self.accept_callback = cb
  return self
end

function WebSocketServer:accept(req, res)
  local should_accept = self.accept_callback(req, res)
  local hs = Handshake.server(req, res)
  assert(not res:has_sent(), 'Error, cannot send response data during accept')
  if not should_accept then
    res:send('')
    return nil, 'error during accept'
  end
end

--TODO is there any more api calls, perhaps `send_text` and `send_bytes`
return WebSocketServer
