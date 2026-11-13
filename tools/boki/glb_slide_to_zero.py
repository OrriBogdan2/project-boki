"""Slide a glb's animation clips to start at 0 s, in place: the fix for Boki glbs exported before boki_rig.export
set `export_anim_slide_to_zero`. Their keys start at Blender's frame 1 (1/30 s), so Godot holds each clip's first pose
from 0 to 1/30 s and every looping clip stops for a frame at its wrap. Only the clips' key-time accessors change
(each animation's times minus its first time); meshes, skins and images stay byte for byte.

    python3 tools/boki/glb_slide_to_zero.py art/kin/*/*.glb [--check]

--check only reports the glbs whose clips do not start at 0 and exits 1 if there are any.
"""

import json
import struct
import sys

FLOAT = 5126


def _chunks(data):
    """The glb's JSON dict and the byte offset of its BIN chunk's data."""
    magic, _version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("not a glb")
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    if json_type != b"JSON":
        raise ValueError("first chunk is not JSON")
    doc = json.loads(data[20 : 20 + json_len])
    bin_head = 20 + json_len
    _bin_len, bin_type = struct.unpack_from("<I4s", data, bin_head)
    if bin_type != b"BIN\x00":
        raise ValueError("second chunk is not BIN")
    return doc, json_len, bin_head + 8


def _starts(doc):
    """{input accessor index: the start time of the animation it keys}. Fails if one accessor keys two animations
    that start at different times (it could not be shifted for both)."""
    out = {}
    for anim in doc.get("animations", []):
        inputs = {s["input"] for s in anim["samplers"]}
        start = min(doc["accessors"][i]["min"][0] for i in inputs)
        for i in inputs:
            if out.get(i, start) != start:
                raise ValueError("accessor %d keys animations with different starts" % i)
            out[i] = start
    return out


def slide(path, check=False):
    """Slides the clips in `path` to 0. Returns how many clips started after 0."""
    data = bytearray(open(path, "rb").read())
    doc, json_len, bin_at = _chunks(data)
    starts = {i: t for i, t in _starts(doc).items() if t > 0.0}
    if check or not starts:
        return len(starts)
    for i, start in starts.items():
        acc = doc["accessors"][i]
        view = doc["bufferViews"][acc["bufferView"]]
        if acc["componentType"] != FLOAT or acc["type"] != "SCALAR" or view.get("byteStride", 4) != 4:
            raise ValueError("%s: accessor %d is not tightly packed float times" % (path, i))
        if "sparse" in acc:
            raise ValueError("%s: accessor %d is sparse" % (path, i))
        at = bin_at + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        count = acc["count"]
        times = struct.unpack_from("<%df" % count, data, at)
        moved = [t - start if t - start > 1e-6 else 0.0 for t in times]
        struct.pack_into("<%df" % count, data, at, *moved)
        stored = struct.unpack_from("<%df" % count, data, at)
        acc["min"], acc["max"] = [min(stored)], [max(stored)]
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    if len(text) > json_len:
        raise ValueError("%s: the new JSON chunk outgrew the old one" % path)
    text += b" " * (json_len - len(text))
    data[20 : 20 + json_len] = text
    open(path, "wb").write(bytes(data))
    return len(starts)


def main(argv):
    check = "--check" in argv
    late = 0
    for path in [a for a in argv if not a.startswith("--")]:
        n = slide(path, check)
        if n:
            late += 1
            print("%s %s: %d clip key tracks started after 0" % ("LATE" if check else "SLID", path, n))
    print("%d glbs %s" % (late, "start late" if check else "slid to 0"))
    return 1 if check and late else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
