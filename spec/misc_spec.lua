local otp = require"otp"
local bxx = require"basexx"

describe("Private functions test:", function ()

  it("Counter format", function ()
    local n = 
      ("L"):byte() * 0x10000000000 +
      ("U"):byte() * 0x100000000 +
      ("A"):byte() * 0x1000000 +
      ("O"):byte() * 0x10000 +
      ("T"):byte() * 0x100 +
      ("P"):byte() * 0x1;
    assert(otp._private.counter_format(n) == "\0\0LUAOTP")
  end)

  it("URL Encoding", function ()
    assert(otp._private.url_encode("\0\12\n +=Jérémy=+ \128%\136") == "%00%0C%0A%20%2B%3DJ%C3%A9r%C3%A9my%3D%2B%20%80%25%88")
  end)

  it("OTP generation may return a code with less digits because of zeroes", function ()
    assert(
      "018006" == otp._private.generate(
        bxx.from_base32("RTKBTAZT4MDW7EVEPUQDIGYH"),
        5615, 6))
  end)
  
end)
