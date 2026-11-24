extends SceneTree

const Transport = preload("res://network/local_transport.gd")
const Request = preload("res://network/world_request.gd")

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var listener := TCPServer.new()
    var client := Transport.new()
    var server := WebSocketPeer.new()
    if listener.listen(0, "127.0.0.1") != OK or client.connect_local(listener.get_local_port()) != OK:
        _fail("could not establish loopback listener")
        return
    var deadline := Time.get_ticks_msec() + 3000
    var accepted := false
    var sent := false
    var request: PackedByteArray = Request.encode_enter_world(122)
    while Time.get_ticks_msec() < deadline:
        if not accepted and listener.is_connection_available():
            if server.accept_stream(listener.take_connection()) != OK:
                _fail("server rejected loopback stream")
                return
            accepted = true
        client.poll()
        if accepted:
            server.poll()
        if server.get_ready_state() == WebSocketPeer.STATE_OPEN and not sent:
            sent = client.send_packet(request) == OK
        if server.get_available_packet_count() > 0:
            if server.get_packet().hex_encode() != "27130200027a7a" or server.was_string_packet():
                _fail("server received an unexpected request")
                return
            if server.send("4e230200007a7a".hex_decode()) != OK:
                _fail("server could not send synthetic response")
                return
        var response: Dictionary = client.read_response()
        if not response.is_empty():
            if not response.ok or response.cmd != 20003 or response.codec != 2 or response.error_code != 0 or response.payload.hex_encode() != "7a7a":
                _fail("client received an unexpected response")
                return
            print("Loopback WebSocket frame exchange PASS")
            quit(0)
            return
        await create_timer(0.01).timeout
    _fail("loopback exchange timed out")

func _fail(error: String) -> void:
    push_error(error)
    quit(1)
