extends SceneTree

const Response = preload("res://network/world_response.gd")

func _initialize() -> void:
    var packet := ("4e230200007c00007fff04e99baa41097b01f47b03e80f106406780001012a01"
        + "7d41dfffffffc000001f200474657374046e69636b63017a7b0203040506027b7d").hex_decode()
    var expected := {
        "ok": true, "cmd": 20003, "player_id": 32767, "player_name": "雪A",
        "timestamp": 9, "hp": 500, "hp_max": 1000, "fight_value": 15, "total_value": 16,
        "scene_id": 100, "level": 6, "exp": 120, "head": "", "sex": 1,
        "attributes": [42], "currencies": [2147483647], "open_time": 31, "create_time": 32,
        "checksum": "test", "nickname": "nick", "last_scene_id": 99, "function_ids": [123],
        "quality": 2, "title_id": 3, "fashion_id": 4, "mounts": 5, "partner_table_id": 6,
        "extend": "{}",
    }
    if Response.decode(packet) != expected:
        push_error("World response differs from original Java fixture")
        quit(1)
        return
    for length in range(packet.size()):
        if Response.decode(packet.slice(0, length)).ok:
            push_error("Accepted truncated world response")
            quit(1)
            return
    print("Java world response fixture PASS")
    quit(0)
