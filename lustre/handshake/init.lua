local key = require 'lustre.handshake.key'
local Handshake = {}
Handshake.__index = Handshake

function Handshake.client(protocols, encodings)
    return setmetatable({
        protocols = protocols or {},
        encodings = encodings or {},
        key = key.generate_key(),
    }, Handshake)
end

function Handshake:validate_accept(accept)
    if not self.accept then
        self.accept = key.build_accept_from(self.key)
    end
    return self.accept == accept
end

function Handshake.server(protocols, encodings, client_key)
    return setmetatable({
        protocols = protocols,
        encodings = encodings,
        accept = key.build_accept_from(client_key),
    }, Handshake)
end


return Handshake
