extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")

static func encode(user_id: int, login_time: int, signature: String, white: int, server_status: int,
        server_id: int, is_new_user: int, order_by_player_id: int, uid: String) -> PackedByteArray:
    var payload: PackedByteArray = Codec.encode_player_id(user_id)
    var time_bytes: PackedByteArray = Codec.encode_player_id(login_time)
    if payload.is_empty() or time_bytes.is_empty() or is_new_user < 0 or is_new_user > 127:
        return PackedByteArray()
    var order_bytes: PackedByteArray = Codec.encode_player_id(order_by_player_id)
    if order_by_player_id == 0:
        order_bytes = PackedByteArray([0])
    if order_bytes.is_empty():
        return PackedByteArray()
    var sign_bytes := signature.to_utf8_buffer()
    var uid_bytes := uid.to_utf8_buffer()
    if sign_bytes.size() + uid_bytes.size() > 32767:
        return PackedByteArray()
    payload.append_array(time_bytes)
    payload.append_array(Codec.encode_vary_nonnegative(sign_bytes.size()))
    payload.append_array(sign_bytes)
    for value in [white, server_status, server_id, is_new_user]:
        if value < 0 or value > 2147483647:
            return PackedByteArray()
        var encoded: PackedByteArray = Codec.encode_player_id(value) if value > 0 else PackedByteArray([0])
        payload.append_array(encoded)
    payload.append_array(order_bytes)
    payload.append_array(Codec.encode_vary_nonnegative(uid_bytes.size()))
    payload.append_array(uid_bytes)
    if payload.size() > 32767:
        return PackedByteArray()
    return Codec.encode_request(10001, 2, payload)
