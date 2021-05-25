local key = require 'lustre.handshake.key'
local Handshake = require 'lustre.handshake'

local utils = require "spec.utils"
describe('handshake', function ()
    it('build_key_from', function ()
        local key = key.build_accept_from('dGhlIHNhbXBsZSBub25jZQ==');
        utils.assert_eq(key, 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=')
    end)
    describe('server', function ()
        it('fails with bad response', function ()
            local h, err = Handshake.server({}, {has_sent = function() return true end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Cannot handshake on used response')
        end)
        it('fails with bad method', function ()
            local h, err = Handshake.server({method = 'POST'}, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Websocket handshake must be a GET request')
        end)
        it('fails with bad http_version', function ()
            local h, err = Handshake.server({method = 'GET', http_version = '0.9'}, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Websocket handshake request version must be 1.1 found: "0.9"')
        end)
        it('fails with no connection header', function ()
            local headers = {}
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Missing connection header')
        end)
        it('fails with bad connection header', function ()
            local headers = {
                connection = 'downgrade'
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Invalid connection header "downgrade"')
        end)
        it('fails with no upgrade header', function ()
            local headers = {
                connection = 'upgrade'
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Upgrade header not present')
        end)
        it('fails with bad upgrade header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'junk'
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Upgrade header must contain `websocket` found "junk"')
        end)
        it('fails with no version header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket'
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Missing Sec-Websocket-Version header')
        end)
        it('fails with bad version header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '12',
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'Unsupported websocket version "12"')
        end)
        it('fails with no key header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
            }
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, {has_sent = function() return false end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            utils.assert_eq(err, 'No Sec-Websocket-Key header present')
        end)
        it('success, no protocols or encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 0)
            utils.assert_eq(#h.extensions, 0)
        end)
        it('success with 1 protocol, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = 'junk',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 1)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(#h.extensions, 0)
        end)
        it('success with 2 protocol 1 string, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = 'junk, trash',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 2)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'trash')
            utils.assert_eq(#h.extensions, 0)
        end)
        it('success with 2 protocols 2 strings, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk', 'trash',
                }
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 2)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'trash')
            utils.assert_eq(#h.extensions, 0)
        end)
        it('success with 3 protocols 2 strings, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                }
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 0)
        end)
        
        it('success with 3 protocols 2 strings, 1 extension 1 string no params', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                },
                sec_websocket_extensions = 'asdf',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 1)
            utils.assert_eq(h.extensions[1].name, 'asdf')
        end)
        it('success with 3 protocols 2 strings, 1 extensions 1 string 1 param', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                },
                sec_websocket_extensions = 'asdf; foo=1',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 1)
            utils.assert_eq(h.extensions[1].name, 'asdf')
            utils.assert_eq(h.extensions[1].params.foo, '1')
        end)
        it('success with 3 protocols 2 strings, 2 extensions 1 string 1 param', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                },
                sec_websocket_extensions = 'asdf; foo=1,qwer',
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 2)
            utils.assert_eq(h.extensions[1].name, 'asdf')
            utils.assert_eq(h.extensions[1].params.foo, '1')
            utils.assert_eq(h.extensions[2].name, 'qwer')
        end)
        it('success with 3 protocols 2 strings, 2 extensions 2 strings 1 param', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                },
                sec_websocket_extensions = {
                    'asdf; foo=1,qwer',
                    'zxcv',
                },
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 3)
            utils.assert_eq(h.extensions[1].name, 'asdf')
            utils.assert_eq(h.extensions[1].params.foo, '1')
            utils.assert_eq(h.extensions[2].name, 'qwer')
            utils.assert_eq(h.extensions[3].name, 'zxcv')
        end)
        it('success with 3 protocols 2 strings, 2 extensions 2 strings 2 params', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = {
                    'junk, garbage', 'trash',
                },
                sec_websocket_extensions = {
                    'asdf; foo=1,qwer',
                    'zxcv; bar=false',
                },
            }
            local res = {
                has_sent = function() return false end,
                headers = {},
            }
            stub(res, 'status')
            stub(res.headers, 'append')
            local h, err = Handshake.server({
                method = 'GET',
                http_version = '1.1',
                get_headers = function() return headers end,
            }, res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            assert.stub(res.status).was.called_with(res, 101)
            assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            utils.assert_eq(#h.protocols, 3)
            utils.assert_eq(h.protocols[1], 'junk')
            utils.assert_eq(h.protocols[2], 'garbage')
            utils.assert_eq(h.protocols[3], 'trash')
            utils.assert_eq(#h.extensions, 3)
            utils.assert_eq(h.extensions[1].name, 'asdf')
            utils.assert_eq(h.extensions[1].params.foo, '1')
            utils.assert_eq(h.extensions[2].name, 'qwer')
            utils.assert_eq(h.extensions[3].name, 'zxcv')
            utils.assert_eq(h.extensions[3].params.bar, 'false')
        end)
    end)
    describe('client', function ()
        it('constructs with no protocols, not encodings', function ()
            local h = Handshake.client()
            utils.assert_eq(#h.protocols, 0)
            utils.assert_eq(#h.extensions, 0)
            utils.assert_fmt(h.key, 'expected key fount %q', h.key)
        end)
        it('constructs with protocols, not encodings', function ()
            local h = Handshake.client({'asdf', 'qwer'})
            utils.assert_eq(#h.protocols, 2)
            utils.assert_eq(h.protocols[1], 'asdf')
            utils.assert_eq(h.protocols[2], 'qwer')
            utils.assert_eq(#h.extensions, 0)
            utils.assert_fmt(h.key, 'expected key fount %q', h.key)
        end)
        it('constructs with protocols and encodings', function ()
            local h = Handshake.client({'asdf', 'qwer'}, {'poiu', 'lkjh'})
            utils.assert_eq(#h.protocols, 2)
            utils.assert_eq(h.protocols[1], 'asdf')
            utils.assert_eq(h.protocols[2], 'qwer')
            utils.assert_eq(#h.extensions, 2)
            utils.assert_eq(h.extensions[1], 'poiu')
            utils.assert_eq(h.extensions[2], 'lkjh')
            utils.assert_fmt(h.key, 'expected key fount %q', h.key)
        end)
        it('validates accept', function ()
            local h = Handshake.client()
            local req = {
                get_headers = function() return {
                    sec_websocket_accept = key.build_accept_from(h.key)
                } end
            }
            spy(req.get_headers)
            assert(h:validate_accept(req))
        end)
        it('no validation of bad accept', function ()
            local h = Handshake.client()
            local req = {
                get_headers = function() return {
                    sec_websocket_accept = 'junk'
                } end
            }
            assert(not h:validate_accept(req))
        end)
        it('no validation of missing accept', function ()
            local h = Handshake.client()
            local req = {
                get_headers = function() return {} end
            }
            local suc, err = h:validate_accept(req)
            assert(not suc, 'expected failure')
            utils.assert_eq(err, 'Invalid request, no Sec-Websocket-Accept header')
        end)
    end)
end)
