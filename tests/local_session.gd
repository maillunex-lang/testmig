extends SceneTree

const Session = preload("res://network/local_session.gd")
const State = Session.State
const LOGIN := "4e2102000079017c00007fff0104e99baa41013100056c6f63616c"
const WORLD := "4e230200007c00007fff04e99baa41097b01f47b03e80f106406780001012a017d41dfffffffc000001f200474657374046e69636b63017a7b0203040506027b7d"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for create in [false, true]:
        var issue: String = await _exercise(create)
        if not issue.is_empty():
            push_error(issue)
            quit(1)
            return
    print("Local session selection, creation and world entry PASS")
    quit(0)

func _exercise(create: bool) -> String:
    var listener := TCPServer.new()
    var server := WebSocketPeer.new()
    var session := Session.new()
    if listener.listen(0, "127.0.0.1") != OK:
        return "could not open loopback listener"
    if session.start(listener.get_local_port(), 121, 122, "synt", 0, 2, 1, 0, 0, "é") != OK:
        return "could not start session"
    var requests := ["2711020010797a7a0473796e74000201000002c3a9"]
    var replies := ["4e210200007900013100056c6f63616c" if create else LOGIN]
    if create:
        requests.append_array(["2712020008790104e99baa4100", "2712020008790104e99baa4100"])
        replies.append_array(["4e2202ffff", "4e220200007c00007fff"])
    requests.append("27130200037b7fff")
    replies.append(WORLD)

    var accepted := false
    var stage := 0
    var actions := 0
    var deadline := Time.get_ticks_msec() + 3000
    while Time.get_ticks_msec() < deadline:
        if not accepted and listener.is_connection_available():
            if server.accept_stream(listener.take_connection()) != OK:
                return "mock server could not accept connection"
            accepted = true
        if accepted:
            server.poll()
        session.poll()
        if session.state == State.FAILED:
            return "session failed: %s" % str(session.error)
        if session.state == State.CHOOSING and actions == 0:
            if session.characters.size() != (0 if create else 1) or session.select_character(1) != ERR_DOES_NOT_EXIST:
                return "character list or selection guard is incorrect"
            var status := session.create_character(1, "雪A", "") if create else session.select_character(32767)
            if status != OK:
                return "could not choose or create character"
            actions += 1
        elif create and session.state == State.CHOOSING and actions == 1:
            if session.error.get("error_code") != -1 or session.create_character(1, "雪A", "") != OK:
                return "session could not retry a rejected create request"
            actions += 1
        if server.get_available_packet_count() > 0:
            var packet := server.get_packet()
            if server.was_string_packet() or stage >= requests.size() or packet.hex_encode() != requests[stage]:
                return "unexpected request at stage %d" % stage
            if server.send(replies[stage].hex_decode(), WebSocketPeer.WRITE_MODE_BINARY) != OK:
                return "could not send fixture at stage %d" % stage
            stage += 1
        if session.state == State.IN_WORLD:
            if stage != requests.size() or session.world.player_id != 32767 or session.world.scene_id != 100:
                return "unexpected final world state"
            return ""
        await create_timer(0.01).timeout
    return "local session test timed out"
