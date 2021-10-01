local Key = require "lustre.handshake.key"
local Handshake = require "lustre.handshake"
local utils = require "spec.utils"
local Request = require "luncheon.request"
local Response = require "luncheon.response"

local function fill_headers(headers, t)
  for key, value in pairs(headers) do
    if type(value) == "table" then
      for _, value in ipairs(value) do t:add_header(key, value) end
    else
      t:add_header(key, value)
    end
  end
  t._parsed_headers = true
end

local function mock_request(headers, method)
  local req = Request.new(method, "/")
  fill_headers(headers, req)
  return req
end

local function mock_response(headers, status)
  local res = Response.new(status)
  fill_headers(headers, res)
  return res
end

describe("handshake", function()
  it("build_key_from", function()
    local key = Key.build_accept_from("dGhlIHNhbXBsZSBub25jZQ==");
    assert.are(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
  end)
  --[[
    -- Server functionality isn't supported yet
    describe('server', function ()
        it('fails with bad response', function ()
            local h, err = Handshake.server({}, {has_sent = function() return true end})
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Cannot handshake on used response')
        end)
        it('fails with bad method', function ()
            local h, err = Handshake.server({method = 'POST'}, mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Websocket handshake must be a GET request')
        end)
        it('fails with bad http_version', function ()
            local h, err = Handshake.server({method = 'GET', http_version = '0.9'}, mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Websocket handshake request version must be 1.1 found: "0.9"')
        end)
        it('fails with no connection header #test', function ()
            local headers = {
                upgrade = 'junk'
            }
            local h, err = Handshake.server(
                mock_request(headers),
                mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Missing connection header')
        end)
        it('fails with bad connection header', function ()
            local headers = {
                connection = 'downgrade'
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Invalid connection header "downgrade"')
        end)
        it('fails with no upgrade header', function ()
            local headers = {
                connection = 'upgrade'
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Upgrade header not present')
        end)
        it('fails with bad upgrade header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'junk'
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Upgrade header must contain `websocket` found "junk"')
        end)
        it('fails with no version header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket'
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Missing Sec-Websocket-Version header')
        end)
        it('fails with bad version header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '12',
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'Unsupported websocket version "12"')
        end)
        it('fails with no key header', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
            }
            local h, err = Handshake.server(mock_request(headers), mock_response({}))
            utils.assert_fmt(not h, 'Expected nil found %q', h)
            assert.are(err, 'No Sec-Websocket-Key header present')
        end)
        it('success, no protocols or encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
            }
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            --TODO edit this test
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 0)
            assert.are(#h.extensions, 0)
        end)
        it('success with 1 protocol, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = 'junk',
            }
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 1)
            assert.are(h.protocols[1], 'junk')
            assert.are(#h.extensions, 0)
        end)
        it('success with 2 protocol 1 string, no encodings', function ()
            local headers = {
                connection = 'upgrade',
                upgrade = 'websocket',
                sec_websocket_version = '13',
                sec_websocket_key = 'asdf',
                sec_websocket_protocol = 'junk, trash',
            }
            local res = mock_response({})

            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 2)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'trash')
            assert.are(#h.extensions, 0)
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 2)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'trash')
            assert.are(#h.extensions, 0)
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 0)
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 1)
            assert.are(h.extensions[1].name, 'asdf')
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 1)
            assert.are(h.extensions[1].name, 'asdf')
            assert.are(h.extensions[1].params.foo, '1')
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 2)
            assert.are(h.extensions[1].name, 'asdf')
            assert.are(h.extensions[1].params.foo, '1')
            assert.are(h.extensions[2].name, 'qwer')
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 3)
            assert.are(h.extensions[1].name, 'asdf')
            assert.are(h.extensions[1].params.foo, '1')
            assert.are(h.extensions[2].name, 'qwer')
            assert.are(h.extensions[3].name, 'zxcv')
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
            local res = mock_response({})
            local h, err = Handshake.server(mock_request(headers), res)
            utils.assert_fmt(h, 'Expected handshake %s', err)
            -- assert.stub(res.status).was.called_with(res, 101)
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Upgrade', 'websocket')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Connection', 'Upgrade')
            -- assert.stub(res.headers.append).was.called_with(res.headers, 'Sec-Websocket-Accept', match.is_string())
            assert.are(#h.protocols, 3)
            assert.are(h.protocols[1], 'junk')
            assert.are(h.protocols[2], 'garbage')
            assert.are(h.protocols[3], 'trash')
            assert.are(#h.extensions, 3)
            assert.are(h.extensions[1].name, 'asdf')
            assert.are(h.extensions[1].params.foo, '1')
            assert.are(h.extensions[2].name, 'qwer')
            assert.are(h.extensions[3].name, 'zxcv')
            assert.are(h.extensions[3].params.bar, 'false')
        end)
    end)
--]]
  describe("client", function()
    it("constructs with no protocols, not encodings", function()

      local h = Handshake.client()
      assert.are(#h.protocols, 0)
      assert.are(#h.extensions, 0)
      utils.assert_fmt(h.key, "expected key fount %q", h.key)
    end)
    it("constructs with protocols, not encodings", function()
      local h = Handshake.client(nil, {"asdf", "qwer"})
      assert.are(#h.protocols, 2)
      assert.are(h.protocols[1], "asdf")
      assert.are(h.protocols[2], "qwer")
      assert.are(#h.extensions, 0)
      utils.assert_fmt(h.key, "expected key fount %q", h.key)
    end)
    it("constructs with protocols and encodings", function()
      local h = Handshake.client(nil, {"asdf", "qwer"}, {"poiu", "lkjh"})
      assert.are(#h.protocols, 2)
      assert.are(h.protocols[1], "asdf")
      assert.are(h.protocols[2], "qwer")
      assert.are(#h.extensions, 2)
      assert.are(h.extensions[1], "poiu")
      assert.are(h.extensions[2], "lkjh")
      utils.assert_fmt(h.key, "expected key fount %q", h.key)
    end)
    it("validates accept", function()
      local h = Handshake.client()
      local headers = {sec_websocket_accept = Key.build_accept_from(h.key)}
      local req = mock_request(headers)
      spy(req.get_headers)
      assert(h:validate_accept(req))
    end)
    it("no validation of bad accept", function()
      local h = Handshake.client()
      local headers = {sec_websocket_accept = "junk"}
      local req = mock_request(headers)
      assert(not h:validate_accept(req))
    end)
    it("no validation of missing accept", function()
      local h = Handshake.client()
      local req = mock_request({})
      local suc, err = h:validate_accept(req)
      assert(not suc, "expected failure")
      assert.are(err, "no Sec-Websocket-Accept header")
    end)
  end)
end)
