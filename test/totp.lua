local otp = require"otp"

local sample_key = "totp:1:GK0rXHy4oBrDWxJxsmur:6:30:"
local sample_key_url = "otpauth://totp/lua%20otp:J%C3%A9r%C3%A9my?secret=DCWSWXD4XCQBVQ23CJY3E25L&issuer=82a9cfef2760fa&period=30&digits=6"

local test_epoch = 1439312195
local expected_code = "223468"

describe("TOTP tests:", function ()
  local key

  it("Create key", function () 
    local key = otp.new_totp()
    assert.is_not_nil(key)
  end)

  it("Deserialize and serialize key", function ()
    key = otp.read(sample_key)
    assert.is_not_nil(key)
    assert(key:serialize() == sample_key)
  end)

  insulate("Setting os.time to a fixed value:", function()
    os.time = function () return test_epoch end

    it("Generate code for fixed epoch and verify", function ()
      local code = key:generate()
      assert(code == expected_code)
      assert(key:verify(code))
      assert(not key:verify(key:generate(20)))
    end)

  end)

  it("Generate URL", function ()
    local url = key:get_url("lua otp", "Jérémy", "82a9cfef2760fa")
    assert(url == sample_key_url)
  end)

end)
