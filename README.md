# Lustre

WebSockets for Lua
![Gilded Mirror](./Lustre.svg)

## Usage

Lustre's goal is to provide a high level websocket facade that can be used by a framework that
depends on [luncheon](https://github.com/FreeMasen/luncheon)'s HTTP types. By its very nature
it doesn't handle any of the parallelism that might be required to act on multiple WebSockets
at the same time or even to handle additional HTTP requests; leveraging [Cosock](https://github.com/cosock/cosock)
would be required to handle parallelism.


```lua
---This websocket server will report the time to the client
---once a second for 30 seconds and then disconnect. Any
---incoming messages will cause the server to close the connection
-----------------------------------------------------------
-----------------------------------------------------------
---Note: Currently this only an outline of the intended api
-----------------------------------------------------------
-----------------------------------------------------------
local lustre = require 'lustre'
local socket = require 'socket' --just for the sleeping

local ws = lustre.Websocket(lustre.Config.default())
-- Somehow get a Luncheon Request and Response object
local req = {}
local res = {}
assert(ws:perform_handshake(req, res))
ws:add_message_callback(function (message)
  ws:close()
end)
while true do
  ws:send_text(string.format('%s', os.time()))
  socket.sleep(1)
end
```