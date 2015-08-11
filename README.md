# luaotp

A simple implementation of OATH-HOTP and OATH-TOTP. It is distributed
under the terms of the MIT licence.

## Description

This is a simple OATH-HOTP and OATH-TOTP implementation in pure lua
that makes use of LuaCrypto for its hashing needs. It can be used as
a generation and verification library and is compatible with the
RFCs 4226 and 6238. It only supports the SHA-1 hashing algorithm
(as specified in the RFCs).

It is possible to export and import the keys in a short ASCII format
for easy storing in databases or text files.

It is also possible to export a key to a standard URL format that
will work with ``otpauth://`` aware clients and can be simply converted
to a QR code to be scanned by mobile clients.

## Example

HOTP sample code that creates a shared secret and iterates over asking
and testing codes from the user until it encounters a blank line.

The counter is incremented with each successful verification, so one
code can't be used twice.

```lua
local otp = require"otp"

local hotp = otp.new_hotp()

print"Use this URL to configure your OATH-HOTP client:"
print(hotp:get_url("luaotp sample", "user"))

while true do
  print"Type in a code:"
  local code = io.stdin:read"*l"
  if not code or code == "" then break end

  if hotp:verify(code) then
    print"This code is valid!"
  else
    print"This code is invalid."
  end
end
```

## Documentation

The documentation can be found in the doc folder.

---

[Jérémy Farnaud](http://jf.almel.fr/)
