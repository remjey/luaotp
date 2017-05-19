local otp = require"otp"

local sample_key = "totp:1:GK0rXHy4oBrDWxJxsmur:6:30:"
local sample_key_v1b = "totp:1:GK0rXHy4oBrDWxJxsmur:6:30:0:"
local sample_key_b32 = "DCWSWXD4XCQBVQ23CJY3E25L"
local sample_key_url = "otpauth://totp/lua%20otp:J%C3%A9r%C3%A9my?secret=DCWSWXD4XCQBVQ23CJY3E25L&issuer=82a9cfef2760fa&period=30&digits=6"

local test_epoch = 1439312195
local expected_code = "223468"

local test_epoch_2 = 1238474822
local expected_code_2 = "046183"

local test_epoch_3 = { -- UNIX time: 1328194321
  year=2012,
  month=2,
  day=2,
  hour=15,
  min=52,
  sec=1,
  isdst=false
}
local expected_code_3 = "393634"

describe("TOTP tests:", function ()
  local key

  it("Create key", function ()
    local key = otp.new_totp()
    assert.is_not_nil(key)
  end)

  it("Deserialize and serialize key", function ()
    key = otp.read(sample_key)
    assert.is_not_nil(key)
    assert(key:serialize() == sample_key_v1b)
    assert(key:get_key() == sample_key_b32)

    key = otp.new_totp_from_key(sample_key_b32)
    assert(key:serialize() == sample_key_v1b)
  end)

  insulate("Setting os.time to a fixed value:", function()
    local old_os_time = os.time
    os.time = function (time)
      if time then
        return old_os_time(time)
      else
        return test_epoch
      end
    end

    it("Generate code for fixed epoch using for_time number parameter and verify", function ()
      local code = key:generate(nil, test_epoch_2);
      assert(code == expected_code_2)
      assert(not key:verify(code))
      assert(key:verify(code, nil, test_epoch_2))
    end)

    it("Generate code for fixed epoch using for_time table parameter and verify", function ()
      local code = key:generate(nil, test_epoch_3);
      assert(code == expected_code_3)
      assert(not key:verify(code))
      assert(key:verify(code, nil, test_epoch_3))
    end)

    it("Generate code for fixed epoch and verify", function ()
      local code = key:generate()
      assert(code == expected_code)
      assert(key:verify(code))
      assert(not key:verify(code))
      code = key:generate(20)
      assert(not key:verify(code))
    end)

    it("Verify past code doesn’t get verified", function ()
      local code = key:generate(nil, test_epoch_2);
      assert(not key:verify(code, nil, test_epoch_2))
    end)

    it("Verify serialized counter", function ()
      local code = key:generate(3)
      -- TOTP stores the value of the next valid counter,
      -- so we expect it to be incremented by 3 + 1
      local expected_counter = math.floor(test_epoch / key.period) + 3 + 1
      key = otp.read(key:serialize())
      assert(key:verify(code))
      assert(key.counter == expected_counter)
    end)

  end)

  it("Generate URL", function ()
    local url = key:get_url("lua otp", "Jérémy", "82a9cfef2760fa")
    assert(url == sample_key_url)
  end)

end)

