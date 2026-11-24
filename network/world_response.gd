extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")
const Reader = preload("res://network/binary_reader.gd")

static func decode(packet: PackedByteArray) -> Dictionary:
    var header: Dictionary = Codec.decode_response(packet)
    if not header.ok:
        return header
    if header.cmd != 20003 or header.codec != 2:
        return {"ok": false, "error": "unexpected world response type"}
    if header.error_code != 0:
        return {"ok": false, "cmd": header.cmd, "error_code": header.error_code}

    var reader := Reader.new(header.payload)
    var result := {"ok": true, "cmd": header.cmd}
    result["player_id"] = reader.integer()
    result["player_name"] = reader.utf8()
    for field in ["timestamp", "hp", "hp_max", "fight_value", "total_value", "scene_id", "level", "exp"]:
        result[field] = reader.integer()
    result["head"] = reader.utf8()
    result["sex"] = reader.integer()
    result["attributes"] = _integers(reader)
    result["currencies"] = _integers(reader)
    result["open_time"] = reader.integer()
    result["create_time"] = reader.integer()
    result["checksum"] = reader.utf8()
    result["nickname"] = reader.utf8()
    result["last_scene_id"] = reader.integer()
    result["function_ids"] = _integers(reader)
    for field in ["quality", "title_id", "fashion_id", "mounts", "partner_table_id"]:
        result[field] = reader.integer()
    result["extend"] = reader.utf8()
    if not reader.valid or reader.remaining() != 0:
        return {"ok": false, "error": "invalid world response body"}
    return result

static func _integers(reader: Reader) -> Array[int]:
    var values: Array[int] = []
    for index in range(reader.count()):
        var value := reader.integer()
        if not reader.valid:
            break
        values.append(value)
    return values
