extends RefCounted

const Transport = preload("res://network/local_transport.gd")
const Codec = preload("res://network/legacy_codec.gd")
const LoginRequest = preload("res://network/login_request.gd")
const LoginResponse = preload("res://network/login_response.gd")
const CharacterRequest = preload("res://network/character_request.gd")
const WorldRequest = preload("res://network/world_request.gd")
const WorldResponse = preload("res://network/world_response.gd")

enum State { IDLE, CONNECTING, AUTHENTICATING, CHOOSING, CREATING, ENTERING, IN_WORLD, FAILED }

var state := State.IDLE
var characters: Array[Dictionary] = []
var world: Dictionary = {}
var error: Dictionary = {}
var _transport: Transport
var _login := PackedByteArray()
var _deadline := 0
var _user_id := 0
var _selected_id := 0

func start(port: int, user_id: int, login_time: int, signature: String, white: int,
        server_status: int, server_id: int, is_new_user: int, order_by_player_id: int, uid: String) -> Error:
    if state != State.IDLE:
        return ERR_ALREADY_IN_USE
    var packet: PackedByteArray = LoginRequest.encode(user_id, login_time, signature, white,
        server_status, server_id, is_new_user, order_by_player_id, uid)
    if packet.is_empty():
        return ERR_INVALID_PARAMETER
    _transport = Transport.new()
    var status := _transport.connect_local(port)
    if status != OK:
        _transport = null
        return status
    _user_id = user_id
    _login = packet
    _wait(State.CONNECTING)
    return OK

func select_character(player_id: int) -> Error:
    if state != State.CHOOSING:
        return ERR_BUSY
    for character in characters:
        if character.player_id == player_id:
            var status := _send(WorldRequest.encode_enter_world(player_id), State.ENTERING)
            if status == OK:
                _selected_id = player_id
            return status
    return ERR_DOES_NOT_EXIST

func create_character(sex: int, player_name: String, avatar_url: String) -> Error:
    if state != State.CHOOSING:
        return ERR_BUSY
    return _send(CharacterRequest.encode_create_character(_user_id, sex, player_name, avatar_url),
        State.CREATING)

func poll() -> void:
    if _transport == null:
        return
    _transport.poll()
    if state == State.FAILED:
        return
    if _deadline > 0 and Time.get_ticks_msec() >= _deadline:
        _fail({"error": "session timed out"})
        return
    if _transport.ready_state() == WebSocketPeer.STATE_CLOSED:
        _fail({"error": "connection closed"})
        return
    if state == State.CONNECTING and _transport.ready_state() == WebSocketPeer.STATE_OPEN:
        if _send(_login, State.AUTHENTICATING) != OK:
            _fail({"error": "could not send login request"})
        _login.clear()
    while state != State.FAILED and state != State.IN_WORLD:
        var frame := _transport.read_frame()
        if frame.is_empty():
            break
        if not frame.ok:
            _fail(frame)
            return
        _receive(frame.packet)

func _send(packet: PackedByteArray, next_state: State) -> Error:
    var status := _transport.send_packet(packet)
    if status == OK:
        error = {}
        _wait(next_state)
    return status

func _wait(next_state: State) -> void:
    state = next_state
    _deadline = Time.get_ticks_msec() + 5000

func _receive(packet: PackedByteArray) -> void:
    var header: Dictionary = Codec.decode_response(packet)
    if not header.ok:
        _fail(header)
        return
    var expected: int = {State.AUTHENTICATING: 20001, State.CREATING: 20002, State.ENTERING: 20003}.get(state, 0)
    if header.cmd != expected:
        return
    var result: Dictionary = WorldResponse.decode(packet) if state == State.ENTERING else LoginResponse.decode(packet)
    _deadline = 0
    if not result.ok:
        if state != State.AUTHENTICATING and result.has("error_code"):
            error = result
            state = State.CHOOSING
            return
        _fail(result)
        return
    match state:
        State.AUTHENTICATING:
            if result.user_id != _user_id:
                _fail({"error": "login response user does not match request"})
                return
            characters = result.players
            state = State.CHOOSING
        State.CREATING:
            if result.player_id <= 0:
                _fail({"error": "invalid created character ID"})
                return
            var status := _send(WorldRequest.encode_enter_world(result.player_id), State.ENTERING)
            if status != OK:
                _fail({"error": "could not enter world after character creation"})
                return
            _selected_id = result.player_id
            characters.append({"player_id": _selected_id})
        State.ENTERING:
            if result.player_id != _selected_id:
                _fail({"error": "world response character does not match request"})
                return
            world = result
            state = State.IN_WORLD

func _fail(reason: Dictionary) -> void:
    error = reason
    _login.clear()
    _deadline = 0
    state = State.FAILED
    _transport.disconnect_from_server()
