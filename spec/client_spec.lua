local ws = require "lustre.ws"
local cosock = require "cosock"
local MockSocket = require"spec.mock_socket".MockSocket
local CloseCode = require"lustre.frame.close".CloseCode
local Config = require "lustre.config"
local utils = require "lustre.utils"

describe("Websocket.client", function()
  describe("echos", function()
    it("case 45", function ()
      cosock.spawn(function()
        local tx, rx = cosock.channel.new()
        local config = Config.default()
        
        local websocket = ws.client(MockSocket.new({
          "HTTP/1.1 200 Ok",
          "",
          "asdf",
        }), "/case-45", config)
        websocket
          :register_message_cb(function(msg)
            tx:send({
              kind = "message",
              data = msg,
            })
          end)
          :register_error_cb(function(msg)
            tx:send({
              kind = "error",
              data = msg,
            })
          end)
          :register_close_cb(function(msg)
            tx:send({
              kind = "close",
              data = msg,
            })
          end)
          :connect("0.0.0.0", 80)
        while true do
          local ev = rx:receive()
          print(ev.kind, utils.table_string(ev.data, "event", true))
        end
      end)
    end)
  end)
end)

cosock.run()
