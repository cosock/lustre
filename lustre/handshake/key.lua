math.randomseed(os.time())
local sha1 = require 'sha1'
local base64 = require 'base64'

local WEBSOCKET_SHA_UUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

---Use the Sec-WebSocket-Accept header value to create a
---the corresponding Sec-WebSocket-Key header value
local function build_key_from(accept)
  return base64.encode(sha1.binary(accept..WEBSOCKET_SHA_UUID))
end

---Generate a random Sec-WebSocket-Accept header value
---@return any
local function generate_accept()
  local bytes = {}
  for _ = 1, 16 do
    table.insert(bytes, math.random(0,255))
  end
  return base64.encode(string.char(table.unpack(bytes)))
end

return {
  build_key_from = build_key_from,
  generate_accept = generate_accept,
}
