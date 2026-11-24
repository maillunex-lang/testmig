extends RefCounted

var valid := true
var _buffer := StreamPeerBuffer.new()

func _init(payload: PackedByteArray) -> void:
    _buffer.big_endian = true
    _buffer.data_array = payload

func remaining() -> int:
    return _buffer.get_available_bytes()

func integer() -> int:
    if not _require(1):
        return 0
    var marker := _buffer.get_8()
    if marker > -128 and marker < 122:
        return marker
    match marker:
        122:
            return _buffer.get_8() if _require(1) else 0
        123:
            return _buffer.get_16() if _require(2) else 0
        124:
            return _buffer.get_32() if _require(4) else 0
        125:
            if _require(8):
                var value := _buffer.get_double()
                if is_finite(value) and value == floor(value) and absf(value) <= 9007199254740991.0:
                    return int(value)
    valid = false
    return 0

func count() -> int:
    var result := integer()
    if result < 0 or result > remaining():
        valid = false
        return 0
    return result

func utf8() -> String:
    var size := count()
    if not valid or size == 0:
        return ""
    var bytes: PackedByteArray = _buffer.get_data(size)[1]
    var value := bytes.get_string_from_utf8()
    if value.to_utf8_buffer() != bytes:
        valid = false
    return value

func _require(size: int) -> bool:
    valid = valid and remaining() >= size
    return valid
