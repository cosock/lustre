local key = require 'lustre.handshake.key'
local utils = require "spec.utils"
describe('handshake', function ()
    it('build_key_from', function ()
        local key = key.build_key_from('dGhlIHNhbXBsZSBub25jZQ==');
        utils.assert_eq(key, 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=')
    end)
end)
