"""Inspect the AMF3 MapData object stored in a zlib-compressed CMDT."""
import argparse
import io
import json
import struct
import zlib
from pathlib import Path


class AmfReader:
    def __init__(self, data):
        self.stream = io.BytesIO(data)
        self.strings = []
        self.objects = []
        self.traits = []

    def read(self, size):
        result = self.stream.read(size)
        if len(result) != size:
            raise ValueError("Truncated AMF3 value")
        return result

    def u29(self):
        value = 0
        for _ in range(3):
            byte = self.read(1)[0]
            value = (value << 7) | (byte & 127)
            if byte < 128:
                return value
        return (value << 8) | self.read(1)[0]

    def string(self):
        head = self.u29()
        if not head & 1:
            return self.strings[head >> 1]
        value = self.read(head >> 1).decode("utf-8")
        if value:
            self.strings.append(value)
        return value

    def value(self):
        tag = self.read(1)[0]
        if tag in (0, 1):
            return None
        if tag in (2, 3):
            return tag == 3
        if tag == 4:
            value = self.u29()
            return value - (1 << 29) if value & (1 << 28) else value
        if tag == 5:
            return struct.unpack(">d", self.read(8))[0]
        if tag == 6:
            return self.string()
        if tag not in (9, 10, 12, 13, 14, 15, 16):
            raise ValueError(f"Unsupported AMF3 marker {tag} at {self.stream.tell() - 1}")
        head = self.u29()
        if not head & 1:
            return self.objects[head >> 1]
        if tag == 12:
            value = self.read(head >> 1)
            self.objects.append(value)
            return value
        if tag >= 13:
            self.read(1)  # Fixed-length flag.
            count = head >> 1
            value = []
            self.objects.append(value)
            if tag == 16:
                self.string()  # Element class name.
                value.extend(self.value() for _ in range(count))
            else:
                unit = {13: "i", 14: "I", 15: "d"}[tag]
                value.extend(item[0] for item in struct.iter_unpack(">" + unit, self.read(count * struct.calcsize(unit))))
            return value
        if tag == 9:
            dense, named = [], {}
            key = self.string()
            result = {"named": named, "dense": dense} if key else dense
            self.objects.append(result)
            while key:
                named[key] = self.value()
                key = self.string()
            dense.extend(self.value() for _ in range(head >> 1))
            return result
        if head & 2:
            if head & 4:
                raise ValueError("Externalizable AMF3 objects are unsupported")
            klass = self.string()
            fields = [self.string() for _ in range(head >> 4)]
            trait = klass, fields, bool(head & 8)
            self.traits.append(trait)
        else:
            trait = self.traits[head >> 2]
        klass, fields, dynamic = trait
        result = {"_class": klass} if klass else {}
        self.objects.append(result)
        for field in fields:
            result[field] = self.value()
        if dynamic:
            while field := self.string():
                result[field] = self.value()
        return result


def read_cmdt(path):
    reader = AmfReader(zlib.decompress(path.read_bytes()))
    result = reader.value()
    if reader.stream.read(1):
        raise ValueError("Trailing bytes after MapData")
    if not isinstance(result, dict) or result.get("_class") != "map.MapData":
        raise ValueError("Expected map.MapData")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cmdt", type=Path)
    args = parser.parse_args()
    print(json.dumps(read_cmdt(args.cmdt), default=lambda value: {"bytes": value.hex()}))
