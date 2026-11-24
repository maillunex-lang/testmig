extends SceneTree

const Request = preload("res://network/world_request.gd")

func _initialize() -> void:
    var fixtures := {
        121: "271302000179",
        122: "27130200027a7a",
        32767: "27130200037b7fff",
        32768: "27130200057c00008000",
        2147483647: "27130200097d41dfffffffc00000",
        9007199254740991: "27130200097d433fffffffffffff",
    }
    for player_id in fixtures:
        var packet: PackedByteArray = Request.encode_enter_world(player_id)
        if packet.hex_encode() != fixtures[player_id]:
            push_error("Unexpected enter-world frame for ID %d" % player_id)
            quit(1)
            return
    for player_id in [-1, 0, 9007199254740992]:
        if not Request.encode_enter_world(player_id).is_empty():
            push_error("Accepted invalid or inexact player ID %d" % player_id)
            quit(1)
            return
    print("Enter-world request fixtures PASS")
    quit(0)
