extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")
const CREATE_CHARACTER := 10002
const BINARY_CODEC := 2
const MAX_PAYLOAD := 32767

static func encode_create_character(user_id: int, sex: int, player_name: String, avatar_url: String) -> PackedByteArray:
    var payload: PackedByteArray = Codec.encode_player_id(user_id)
    if payload.is_empty() or sex < 0 or sex > 127:
        return PackedByteArray()
    var name_bytes := player_name.to_utf8_buffer()
    var avatar_bytes := avatar_url.to_utf8_buffer()
    if name_bytes.size() + avatar_bytes.size() > MAX_PAYLOAD:
        return PackedByteArray()
    payload.append_array(Codec.encode_vary_nonnegative(sex))
    payload.append_array(Codec.encode_vary_nonnegative(name_bytes.size()))
    payload.append_array(name_bytes)
    payload.append_array(Codec.encode_vary_nonnegative(avatar_bytes.size()))
    payload.append_array(avatar_bytes)
    if payload.size() > MAX_PAYLOAD:
        return PackedByteArray()
    return Codec.encode_request(CREATE_CHARACTER, BINARY_CODEC, payload)
