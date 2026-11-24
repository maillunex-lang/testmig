extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")
const Reader = preload("res://network/binary_reader.gd")

static func decode(packet: PackedByteArray) -> Dictionary:
    var header: Dictionary = Codec.decode_response(packet)
    if not header.ok:
        return header
    if header.cmd not in [20001, 20002] or header.codec != 2:
        return {"ok": false, "error": "unexpected response type"}
    if header.error_code != 0:
        return {"ok": false, "cmd": header.cmd, "error_code": header.error_code}
    var reader := Reader.new(header.payload)
    var result := {"ok": true, "cmd": header.cmd}
    if header.cmd == 20002:
        result["player_id"] = reader.integer()
    else:
        result["user_id"] = reader.integer()
        var players: Array[Dictionary] = []
        for index in range(reader.count()):
            players.append({"player_id": reader.integer(), "sex": reader.integer(), "name": reader.utf8()})
            if not reader.valid:
                break
        result["players"] = players
        result["version"] = reader.utf8()
        result["tag"] = reader.utf8()
        result["key"] = reader.utf8()
    if not reader.valid or reader.remaining() != 0:
        return {"ok": false, "error": "invalid response body"}
    return result
