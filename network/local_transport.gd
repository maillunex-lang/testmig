extends RefCounted

const Codec = preload("res://network/legacy_codec.gd")

var _peer := WebSocketPeer.new()

func connect_local(port: int) -> Error:
    if port < 1 or port > 65535:
        return ERR_INVALID_PARAMETER
    return _peer.connect_to_url("ws://127.0.0.1:%d" % port)

func poll() -> void:
    _peer.poll()

func send_packet(packet: PackedByteArray) -> Error:
    if _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return ERR_UNCONFIGURED
    if packet.is_empty():
        return ERR_INVALID_DATA
    return _peer.send(packet, WebSocketPeer.WRITE_MODE_BINARY)

func ready_state() -> int:
    return _peer.get_ready_state()

func disconnect_from_server() -> void:
    _peer.close()

func read_frame() -> Dictionary:
    if _peer.get_available_packet_count() == 0:
        return {}
    var packet := _peer.get_packet()
    if _peer.was_string_packet():
        return {"ok": false, "error": "expected binary WebSocket packet"}
    return {"ok": true, "packet": packet}

func read_response() -> Dictionary:
    var frame := read_frame()
    if frame.is_empty() or not frame.ok:
        return frame
    return Codec.decode_response(frame.packet)
