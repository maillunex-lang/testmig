extends SceneTree
const Codec = preload("res://network/legacy_codec.gd")
func _initialize() -> void:
    var packet: PackedByteArray = Codec.encode_request(100, 2, PackedByteArray([1, 2, 3]))
    assert(packet.hex_encode() == "0064020003010203", "request wire format")
    var response: Dictionary = Codec.decode_response(PackedByteArray([0, 101, 2, 0, 0, 7]))
    assert(response.ok and response.cmd == 101 and response.codec == 2 and response.error_code == 0)
    assert(response.payload == PackedByteArray([7]))
    assert(Codec.encode_vary_nonnegative(121).hex_encode() == "79")
    assert(Codec.encode_vary_nonnegative(122).hex_encode() == "7a7a")
    assert(Codec.encode_vary_nonnegative(128).hex_encode() == "7b0080")
    assert(Codec.encode_vary_nonnegative(32768).hex_encode() == "7c00008000")
    print("MMO2 legacy codec offline smoke tests PASS")
    quit(0)
