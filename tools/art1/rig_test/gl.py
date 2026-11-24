import json, struct


def read(path):
    b = open(path, "rb").read()
    assert b[:4] == b"glTF"
    jl, _ = struct.unpack("<II", b[12:20])
    js = json.loads(b[20 : 20 + jl])
    o = 20 + jl
    bl, _ = struct.unpack("<II", b[o : o + 8])
    bin_ = bytearray(b[o + 8 : o + 8 + bl])
    return js, bin_
