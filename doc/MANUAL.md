# Manual for luaotp

luaotp is a library for Lua that implements the OATH-HOTP and OATH-TOTP authentication protocol.
It can be used additonally to a regular password authentication to dramatically enhance security.
It implements RFCs 4226 and 6238 and is able to generate standard URLs to represent and share
the authentication key with client programs or devices. These URLs can arso be embedded in
QR codes for easy transfer to smartphone applications.

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

* **``hotp = otp.new_hotp([key_length], [digits], [counter])``** creates and returns a new HOTP generator and validator with a random key.

The ``key_length`` is expressed in bytes and defaults to 15, ``digits`` defaults to 6 and ``counter`` to 0.

* **``hotp = otp.new_hotp_from_key(key, [digits], [counter])``** creates and returns a new HOTP generator and validator with the given key.

The ``key`` must be encoded in base-32, ``digits`` defaults to 6 and ``counter`` to 0.

* **``hotp:generate([counter_value])``** generates and returns a new code.

If ``counter_value`` is provided, use this value instead of the internal counter and do not increment the internal counter.

* **``hotp:verify(code, [accepted_deviation])``** returns true if the code is valid, false otherwise.

If the code is valid, the internal counter is synchronised with the user's counter and incremented.

``accepted_deviation`` is the accepted difference between the values of the counters on the user and service systems. It defaults to 20.

* **``hotp:serialize()``** returns an ASCII representation of the object for use with ``otp.read()``

* **``hotp:get_url(issuer, account, [issuer_uuid])``** returns a standardized URL to be used in HOTP generators to synchronise with this HOTP object.

``issuer`` is the name of the service, ``account`` is the name of the account associated with this HOTP object, and ``issuer_uuid`` is an unique value to différentiate this service from another that would use the same issuer name (it defaults to the ``issuer`` value).

* **``hotp:get_key()``** returns the base-32 encoded representation of the key.

### Usage notes

As the counter is the main security mechanism in HOTP, it is **essential** that it is **stored and updated each time a verification is successful or a code is generated**. Use the ``hotp:serialize()`` function for this task. See examples below.

## TOTP

### Functions

* **``totp = otp.new_totp([key_length], [digits], [period])``** creates and returns a new TOTP generator and validator with a random key.

The ``key_length`` is expressed in bytes and defaults to 15, ``digits`` defaults to 6. ``period`` is the validity period of each generated code and defaults to 30.

* **``totp = otp.new_totp_from_key(key, [digits], [period])``** creates and returns a new TOTP generator and validator with the given key.

The ``key`` must be encoded in base-32, ``digits`` defaults to 6 and ``period`` to 30.

* **``totp:generate()``** generates and returns the code valid at the time of the call.

* **``totp:verify(code, [accepted_deviation])``** returns true if the code is valid, false otherwise.

``accepted_deviation`` is the accepted difference of time between the user and service systems. It is expressed in periods and defaults to 5.

* **``totp:serialize()``** returns an ASCII representation of the object for use with ``otp.read()``

* **``totp:get_url(issuer, account, [issuer_uuid])``** returns a standardized URL to be used in TOTP generators to synchronise with this TOTP object.

``issuer`` is the name of the service, ``account`` is the name of the account associated with this HOTP object, and ``issuer_uuid`` is an unique value to différentiate this service from another that would use the same issuer name (it defaults to the ``issuer`` value).

* **``totp:get_key()``** returns the base-32 encoded representation of the key.

### Usage notes

TOTP uses ``os.time()`` as the source for the global time to generate and verify TOTP codes. It is therefore **essential** that **the system running
the service is on time**. Consider activating services like NTP on your system to keep it on time.

## Other functions

+ **``otp.read(str)``** creates a new HOTP or TOTP object from ``str``.

The string representation to be used with this function is obtained from an existing HOTP or TOTP object with their ``:serialize()`` function.

## Examples

### Simple two-factor authentication for web sites

Authentication form:

```html
<form method="post" action="/app/login">
<table>
<tr><th>Login:<td><input type="text" name="login">
<tr><th>Password:<td><input type="password" name="password">
<tr><th>OTP:<td><input type="text" name="otp" autocomplete="off">
<tr><td><td><input type="submit">
</table>
</form>
```

Server (pseudo-)code:

```lua
otp = require"otp"

-- Returns user object on successful login, or false otherwise
function login(env --[[ a WSAPI parsed request ]])
  local user = db.get_user_by_login(env.POST.login)

  if not user then return false end

  if not check_password(env.POST.password, user.password_digest) then return false end

  local otp_object = otp.read(user.otp_data)
  if not otp_object:verify(env.POST.otp) then return false end

  -- The 2 following lines are mandatory for HOTP, and useless for TOTP
  user.otp_data = otp_object:serialize()
  db.update_otp(user.id, user.otp_data)

  return user
end
```

### QR code generation

The ``:get_url()`` method generates an URL that can be directly converted into a QR code for flashing by mobile client applications. For example, you can use the ``qrencode`` program to create a binary PNG in string in Lua:

```lua
local otp = require"otp"
totp = otp.new_totp()
local h = io.popen("qrencode -o- " .. totp:get_url("service name", "user name"), "r")
local png_data = h:read"*a"
h:close()
```

## Compatibility

This library was tested for compatibility with [FreeOTP](https://fedorahosted.org/freeotp/) and the [OATH Toolkit](http://www.nongnu.org/oath-toolkit/).

## Possible problems

### Big counters

Lua 5.1 use 64-bit doubles for all numbers, so very high counter values (> 2^52 - 1) will cause errors because they use exponentiation and the low bits of the fraction part are lost. However, this should not occur under normal conditions of use.


