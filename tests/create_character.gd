extends SceneTree

const Request = preload("res://network/character_request.gd")

func _initialize() -> void:
    var packet: PackedByteArray = Request.encode_create_character(121, 1, "雪A", "")
    var boundary: PackedByteArray = Request.encode_create_character(121, 1, "A".repeat(122), "")
    if packet.hex_encode() != "2712020008790104e99baa4100" or boundary.slice(5, 9).hex_encode() != "79017a7a":
        push_error("Unexpected create-character frame")
        quit(1)
        return
    if not Request.encode_create_character(121, 1, "A".repeat(32767), "").is_empty():
        push_error("Oversized create-character frame accepted")
        quit(1)
        return
    print("Create-character request fixtures PASS")
    quit(0)
