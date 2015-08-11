# luaotp

## Requirements

luaotp uses the LuaCrypto, basexx and randbytes libraries. It was written for Lua 5.1.

## Terminology

* **OTP** is a One-Time Password.
* **HOTP** means Hash-based OTP. It is based on a counter that both the user
  and the service share. Each time the user gerenates a HOTP, his counter is
  incremented. Each time the service validates an HOTP, its counter is set
  to the counter value that was used by the client to generate the HOTP.
* **TOTP** means Time-based OTP. It is the same implementation, except the
  counter used by both the user and service is always set to a global time
  dependent value. Thus each code generated with the TOTP method is only valid
  for a short period of time. The service and user must be synchonised to
  the global time.

## HOTP

### Functions

* **``hotp = otp.new_hotp([key_length], [digits], [counter])``** creates and returns a new HOTP generator and validator.

The ``key_length`` is expressed in bytes and defaults to 15, ``digits`` default to 6 and ``counter`` to 0.

* **``hotp:generate([counter_value])``** generates and returns a new code.

If ``counter_value`` is provided, use this value instead of the internal counter and do not increment the internal counter.

* **``hotp:verify(code, [accepted_deviation])``** returns true if the code is valid, false otherwise.

If the code is valid, the internal counter is synchronised with the user's counter and incremented.

``accepted_deviation`` is the accepted difference between the values of the counters on the user and service systems. It defaults to 20.

* **``hotp:serialize()``** returns an ASCII representation of the object for use with ``otp.read()``

* **``hotp:get_url(issuer, account, [issuer_uuid])``** returns a standardized URL to be used in HOTP generators to synchronise with this HOTP object.

``issuer`` is the name of the service, ``account`` is the name of the account associated with this HOTP object, and ``issuer_uuid`` is an unique value to différentiate this service from another that would use the same issuer name (it defaults to the ``issuer`` value).

### Usage notes

As the counter is the main security mechanism in HOTP, it is essential that it is stored and updated each time a verification is successful or a code is generated. Use the ``hotp:serialize()`` function for this task.

## TOTP

TOTP uses ``os.time()`` as the source for the global time.

### Functions

* **``totp = otp.new_totp([key_length], [digits], [period])``** creates and returns a new TOTP generator and validator.

The ``key_length`` is expressed in bytes and defaults to 15, ``digits`` default to 6. ``period`` is the validity period of each generated code and defauts to 30.

* **``hotp:generate()``** generates and returns the code valid at the time of the call.

* **``hotp:verify(code, [accepted_deviation])``** returns true if the code is valid, false otherwise.

``accepted_deviation`` is the accepted difference of time between the user and service systems. It is expressed in periods and defaults to 5.

* **``hotp:serialize()``** returns an ASCII representation of the object for use with ``otp.read()``

* **``hotp:get_url(issuer, account, [issuer_uuid])``** returns a standardized URL to be used in TOTP generators to synchronise with this TOTP object.

``issuer`` is the name of the service, ``account`` is the name of the account associated with this HOTP object, and ``issuer_uuid`` is an unique value to différentiate this service from another that would use the same issuer name (it defaults to the ``issuer`` value).

## Other functions

+ **``otp.read(str)``** creates a new HOTP or TOTP object from ``str``.

The string representation to be used with this function is obtaind from an existing HOTP or TOTP object with their ``:serialize()`` function.

## QR code generation

The ``:get_url()`` method generates an URL that can be directly converted into a QR code for flashing by client mobile applications. For example, you can use the ``qrencode`` program to create a binary PNG string in lua:

```lua
local otp = require"otp"
totp = otp.new_totp()
local h = io.popen("qrencode -o- " .. totp:get_url("service name", "user name"), "r")
local png_data = h:read"*a"
h:close()
```

