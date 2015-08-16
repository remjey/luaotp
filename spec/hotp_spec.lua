local otp = require"otp"

local sample_counter = 256
local sample_key = "hotp:1:lbKiV5EPVZgWXJ+YYSIJ:6:256:"
local sample_key_b32 = "SWZKEV4RB5KZQFS4T6MGCIQJ"
local sample_key_url = "otpauth://hotp/lua%20otp:J%C3%A9r%C3%A9my?secret=SWZKEV4RB5KZQFS4T6MGCIQJ&issuer=82a9cfef2760fa&counter=258&digits=6"
local expected_code = "160496"

describe("HOTP tests:", function ()
  local key

  it("Create key", function () 
    local key = otp.new_hotp()
    assert.is_not_nil(key)
  end)

  it("Deserialize and serialize key", function ()
    key = otp.read(sample_key)
    assert.is_not_nil(key)
    assert(key:serialize() == sample_key)
    assert(key:get_key() == sample_key_b32)

    key = otp.new_hotp_from_key(sample_key_b32, nil, sample_counter)
    assert(key:serialize() == sample_key)
  end)

  it("Generate code and verify code and counter incrementation", function ()
    local oc = key.counter

    local code = key:generate()
    assert(code == expected_code)
    assert(key.counter == oc + 1)

    key.counter = oc - 10
    assert(key:verify(code))

    key.counter = oc - 100
    assert(not key:verify(code))

    key.counter = oc
    assert(key:verify(code, 0))

    assert(key.counter == oc + 1)
    assert(not key:verify(code))
  end)

  it("Generate URL", function ()
    key = otp.read(sample_key)
    local url = key:get_url("lua otp", "Jérémy", "82a9cfef2760fa")
    assert(url == sample_key_url) 
  end)

end)
