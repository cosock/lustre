# Lustre

WebSockets for Lua
![Gilded plaque](/Lustre.svg)

## Usage

Lustre's goal is to provide a high level websocket facade that can be used by any framework that
depends on [luncheon](https://github.com/FreeMasen/luncheon)'s HTTP types and
[Cosock](https://github.com/cosock/cosock) for coroutine execution.


```lua
--This websocket client will echo all received message
--back to the server
local lustre = require "lustre"
local cosock = require "cosock"

local ws = lustre.Websocket.client(assert(cosock.socket.tcp()), "/sse", lustre.Config.default())
assert(ws:connect('0.0.0.0', 8080))
cosock.spawn(function()
  local msg, err = 1, nil
  while msg do
    msg, err = ws:receive()
    print(msg.type, msg.data)
    ws:send(msg)
  end
  if err ~= "closed" then
    error(err)
  end
end, "websocket recv loop")
cosock.run()
```
