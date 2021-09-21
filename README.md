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
---This websocket client will report the time to the server
---once a second for 30 seconds and then disconnect. Any
---incoming messages will cause the client to close the connection
local lustre = require 'lustre'
local cosock = require 'cosock'

local ws = lustre.Websocket.client(assert(cosock.socket.tcp()), '/sse', lustre.Config.default())
assert(ws:connect('0.0.0.0', 8080))
ws:register_message_cb(function (message)
  ws:close()
end)
while true do
  ws:send_text(string.format('%s', os.time()))
  cosock.socket.sleep(1)
end
```