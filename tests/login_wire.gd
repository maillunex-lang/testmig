extends SceneTree

const Request = preload("res://network/login_request.gd")
const Response = preload("res://network/login_response.gd")

func _initialize() -> void:
    var request: PackedByteArray = Request.encode(121, 122, "synt", 0, 2, 1, 0, 0, "é")
    var fixture := "4e2102000079017c00007fff0104e99baa41013100056c6f63616c".hex_decode()
    var login: Dictionary = Response.decode(fixture)
    var created: Dictionary = Response.decode("4e220200007c00007fff".hex_decode())
    var denied: Dictionary = Response.decode("4e2102ffff".hex_decode())
    if request.hex_encode() != "2711020010797a7a0473796e74000201000002c3a9":
        _fail("Login request differs from Java probe")
        return
    if not login.ok or login.user_id != 121 or login.players != [{"player_id": 32767, "sex": 1, "name": "雪A"}]:
        _fail("Invalid player list from Java login fixture")
        return
    if login.version != "1" or login.tag != "" or login.key != "local":
        _fail("Invalid login metadata")
        return
    if not created.ok or created.player_id != 32767 or denied.ok or denied.error_code != -1:
        _fail("Invalid create-character or error response")
        return
    for length in range(fixture.size()):
        if Response.decode(fixture.slice(0, length)).ok:
            _fail("Accepted truncated login fixture")
            return
    fixture.append(0)
    if Response.decode(fixture).ok:
        _fail("Accepted trailing login data")
        return
    print("Login and create-character wire fixtures PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
