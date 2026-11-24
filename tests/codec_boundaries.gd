extends SceneTree

const Codec = preload("res://network/legacy_codec.gd")

func _initialize() -> void:
    var empty := PackedByteArray()
    var request := Codec.encode_request(-32768, -128, empty)
    if request.hex_encode() != "8000800000":
        _fail("signed request fields or empty payload")
        return
    var packet := PackedByteArray([0x80, 0, 0x80, 0xff, 0xff])
    var response := Codec.decode_response(packet)
    if not response.ok or response.cmd != -32768 or response.codec != -128:
        _fail("signed response fields")
        return
    if response.error_code != -1 or not response.payload.is_empty():
        _fail("signed error code or empty response payload")
        return
    for length in range(5):
        if Codec.decode_response(packet.slice(0, length)).ok:
            _fail("accepted truncated header of length %d" % length)
            return
    print("Offline codec boundary tests PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
