
local CloseCode = {}
CloseCode.__index = CloseCode

function CloseCode.from_int(code)
  local ret = {
    value = code,
  }
  if code == 1000 then
    ret.type = 'normal'
  elseif code == 1001 then
    ret.type = 'away'
  elseif code == 1002 then
    ret.type = 'protocol'
  elseif code == 1003 then
    ret.type = 'unsupported'
  elseif code == 1005 then
    ret.type = 'status'
  elseif code == 1006 then
    ret.type = 'abnormal'
  elseif code == 1007 then
    ret.type = 'invalid'
  elseif code == 1008 then
    ret.type = 'policy'
  elseif code == 1009 then
    ret.type = 'size'
  elseif code == 1010 then
    ret.type = 'extension'
  elseif code == 1011 then
    ret.type = 'error'
  elseif code == 1012 then
    ret.type = 'restart'
  elseif code == 1013 then
    ret.type = 'again'
  elseif code == 1015 then
    ret.type = 'tls'
  elseif code >= 1016 and code <= 2999 then
    ret.type = 'reserved'
  elseif code >= 3000 and code <= 3999 then
    ret.type = 'iana'
  elseif code >= 4000 and code <= 4999 then
    ret.type = 'library'
  else
    ret.type = 'bad'
  end
  return setmetatable(ret, CloseCode)
end

function CloseCode.decode(bytes)
  local one, two = string.byte(bytes, 1, 2)
  local int = (one << 8) | two
  return CloseCode.from_int(int)
end

function CloseCode:encode()
  local one = (self.value >> 8) & 255
  local two = self.value & 255
  return string.char(one, two)
end

return CloseCode