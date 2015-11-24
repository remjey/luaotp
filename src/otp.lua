
local M = {}

local bxx = require"basexx"
local rand = require"openssl.rand"
local hmac = require"openssl.hmac"

------ Lua 5.3 compatibility ------

local unpack = unpack or table.unpack

------ Defaults ------

local serializer_format_version = 1

local default_key_length = 15
local default_digits = 6
local default_period = 30
local default_totp_deviation = 5
local default_hotp_deviation = 20

------ Helper functions ------

-- Formats a counter to a 8-byte string
local function counter_format(n)
  local rt = { 0, 0, 0, 0, 0, 0, 0, 0 }
  local i = 8
  while i > 1 and n > 0 do
    rt[i] = n % 0x100
    n = math.floor(n / 0x100)
    i = i - 1
  end
  return string.char(unpack(rt))
end

-- Generates a one-time password based on a raw key and a counter
local function generate(raw_key, counter, digits)
  local c = counter_format(counter)
  local h = hmac.new(raw_key, "sha1")
  local sign = { h:update(c):final():byte(1, 20) }
  local offset = 1 + sign[20] % 0x10
  local r = tostring(
    0x1000000 * (sign[offset] % 0x80) +
    0x10000 * (sign[offset + 1]) +
    0x100 * (sign[offset + 2]) +
    (sign[offset + 3])
  ):sub(-digits)
  if #r < digits then
    r = string.rep("0", digits - #r) .. r
  end
  return r
end

local function percent_encode_char(c)
  return string.format("%%%02X", c:byte())
end

local function url_encode(str)
  -- We use a temporary variable to discard the second result returned by gsub
  local r = str:gsub("[^a-zA-Z0-9.~_-]", percent_encode_char)
  return r
end

-- For testing purposes, we expose the local functions through a private table
-- while keeping them local for better performances

M._private = {
  counter_format = counter_format,
  generate = generate,
  url_encode = url_encode,
}

------ TOTP functions ------

local totpmt = {}

local function new_totp_from_key(key, digits, period)
  local r = {
    type = "totp",
    key = key,
    digits = digits or default_digits,
    period = period or default_period,
    counter = 0,
  }
  setmetatable(r, { __index = totpmt, __tostring = totpmt.serialize })
  return r
end

function M.new_totp(key_length, digits, period)
  return new_totp_from_key(rand.bytes(key_length or default_key_length), digits, period)
end

function M.new_totp_from_key(key, digits, period)
  return new_totp_from_key(bxx.from_base32(key), digits, period)
end

local function totp_generate(self, deviation)
  local counter = math.floor(os.time() / self.period) + (deviation or 0)
  return 
    generate(self.key, counter, self.digits),
    counter
end

function totpmt:generate(deviation)
  local r = totp_generate(self, deviation)
  return r -- discard second value
end

function totpmt:verify(code, accepted_deviation)
  if #code ~= self.digits then return false end
  local ad = accepted_deviation or default_totp_deviation
  for d = -ad, ad do
    local verif_code, verif_counter = totp_generate(self, d)
    if verif_counter >= self.counter and code == verif_code then
      self.counter = verif_counter + 1
      return true
    end
  end
  return false
end

function totpmt:get_url(issuer, account, issuer_uuid)
  local key, issuer, account = url_encode(bxx.to_base32(self.key)), url_encode(issuer), url_encode(account)
  local issuer_uuid = issuer_uuid and url_encode(issuer_uuid) or issuer
  return table.concat{
    "otpauth://totp/",
    issuer, ":", account,
    "?secret=", key,
    "&issuer=", issuer_uuid,
    "&period=", tostring(self.period),
    "&digits=", tostring(self.digits),
  }
end

function totpmt:serialize()
  return table.concat{
    "totp:", serializer_format_version,
    ":", bxx.to_base64(self.key),
    ":", tostring(self.digits),
    ":", tostring(self.period),
    ":", tostring(self.counter),
    ":"
  }
end

------ HOTP functions ------

local hotpmt = {}

local function new_hotp_from_key(key, digits, counter)
  local r = {
    type = "hotp",
    key = key,
    digits = digits or default_digits,
    counter = counter or 0,
  }
  setmetatable(r, { __index = hotpmt, __tostring = hotpmt.serialize })
  return r
end

function M.new_hotp(key_length, digits, counter)
  return new_hotp_from_key(rand.bytes(key_length or default_key_length), digits, counter)
end

function M.new_hotp_from_key(key, digits, counter)
  return new_hotp_from_key(bxx.from_base32(key), digits, counter)
end

function hotpmt:generate(counter_value)
  local r = generate(self.key, counter_value or self.counter, self.digits)
  if not counter_value then
    self.counter = self.counter + 1
  end
  return r
end

function hotpmt:verify(code, accepted_deviation)
  local counter_max = self.counter + (accepted_deviation or default_hotp_deviation)
  for i = self.counter, counter_max do
    if code == self:generate(i) then
      self.counter = i + 1
      return true
    end
  end
  return false
end

function hotpmt:get_url(issuer, account, issuer_uuid)
  local key, issuer, account = url_encode(bxx.to_base32(self.key)), url_encode(issuer), url_encode(account)
  local issuer_uuid = issuer_uuid and url_encode(issuer_uuid) or issuer
  return table.concat{
    "otpauth://hotp/",
    issuer, ":", account,
    "?secret=", key,
    "&issuer=", issuer_uuid,
    -- Some clients fail to use the counter correctly, so we give them a future counter to be sure
    "&counter=", tostring(self.counter + 2),
    "&digits=", tostring(self.digits),
  }
end

function hotpmt:serialize()
  return table.concat{
    "hotp:", serializer_format_version,
    ":", bxx.to_base64(self.key),
    ":", tostring(self.digits),
    ":", tostring(self.counter),
    ":"
  }
end

------ Common functions ------

-- Reads a HOTP or TOTP key from a string
function M.read(str)
  local items = {}
  for item in string.gmatch(str, "([^:]*):") do
    items[#items + 1] = item
  end
  assert(#items > 2, "Invalid string")
  local protocol = items[1]
  local version = tonumber(items[2])
  assert(version and version > 0 and version <= serializer_format_version, "Invalid format version")
  if protocol == "totp" then
    if version == 1 then
      local r = {
        type = "totp",
        key = bxx.from_base64(items[3]),
        digits = tonumber(items[4]),
        period = tonumber(items[5]),
        counter = tonumber(items[6] or "0"),
      }
      setmetatable(r, { __index = totpmt })
      return r
    else
      error("Unsupported format version")
    end
  elseif protocol == "hotp" then
    if version == 1 then
      local r = {
        type = "hotp",
        key = bxx.from_base64(items[3]),
        digits = tonumber(items[4]),
        counter = tonumber(items[5]),
      }
      setmetatable(r, { __index = hotpmt })
      return r
    else
      error("Unsupported format version")
    end
  else
    error("Unsupported protocol")
  end
end

local function get_key(key)
  return bxx.to_base32(key.key)
end
hotpmt.get_key = get_key
totpmt.get_key = get_key

return M

