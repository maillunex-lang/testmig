extends RefCounted
## Offline codec for MMO2 Egret game.Net binary envelope.
## Request: signed 16-bit cmd, signed 8-bit codec, signed 16-bit payload length, payload.
## Response: signed 16-bit cmd, signed 8-bit codec, signed 16-bit error, remaining payload.
## Egret ByteArray default big endian. No live network traffic.

static func encode_request(cmd: int, codec: int, payload: PackedByteArray) -> PackedByteArray:
    assert(cmd >= -32768 and cmd <= 32767)
    assert(codec >= -128 and codec <= 127)
    assert(payload.size() <= 32767)
    var b := StreamPeerBuffer.new()
    b.big_endian = true
    b.put_16(cmd & 0xffff)
    b.put_8(codec & 0xff)
    b.put_16(payload.size())
    b.put_data(payload)
    return b.data_array

static func decode_response(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() < 5:
        return {"ok": false, "error": "short response"}
    var b := StreamPeerBuffer.new()
    b.big_endian = true
    b.data_array = bytes
    var cmd := b.get_16()
    var codec := b.get_8()
    var error_code := b.get_16()
    var payload := bytes.slice(5)
    return {"ok": true, "cmd": cmd, "codec": codec, "error_code": error_code, "payload": payload}

static func encode_vary_nonnegative(value: int) -> PackedByteArray:
    assert(value >= 0 and value <= 2147483646)
    var b := StreamPeerBuffer.new()
    b.big_endian = true
    if value < 122:
        b.put_8(value)
    elif value < 128:
        b.put_8(122)
        b.put_8(value)
    elif value < 32768:
        b.put_8(123)
        b.put_16(value)
    else:
        b.put_8(124)
        b.put_32(value)
    return b.data_array

## The Egret writer uses a double at and above the signed int32 maximum.
static func encode_player_id(player_id: int) -> PackedByteArray:
    if player_id <= 0 or player_id > 9007199254740991:
        return PackedByteArray()
    if player_id < 2147483647:
        return encode_vary_nonnegative(player_id)
    var buffer := StreamPeerBuffer.new()
    buffer.big_endian = true
    buffer.put_u8(125)
    buffer.put_double(float(player_id))
    return buffer.data_array
