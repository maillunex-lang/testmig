extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")
const ENTER_WORLD := 10003
const BINARY_CODEC := 2

static func encode_enter_world(player_id: int) -> PackedByteArray:
    var payload: PackedByteArray = Codec.encode_player_id(player_id)
    if payload.is_empty():
        return payload
    return Codec.encode_request(ENTER_WORLD, BINARY_CODEC, payload)
