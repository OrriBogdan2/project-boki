"""Slides every clip of a .glb to start at time 0, leaving all else byte for byte the same. Blender keys a clip from
frame 1, so one exported without export_anim_slide_to_zero has no key before 1/30 s: Godot fills that gap by easing
the last key into the first, and a loop whose last key is its first holds still for a frame each time round (a planted
paw stops while the body goes on, so it slides). A clip that already starts at 0 is left as it is.
Run: python3 tools/art1/glb_clip_start.py <file.glb>..."""

import struct
import sys

from glb_add_clips import read, write

FLOAT = 5126  # glTF componentType of a float32


def slide(j, bin_):
    """Moves each animation's keys back by its first key's time; returns how many clips moved."""
    done = {}
    moved = 0
    clips = [sorted({s["input"] for s in anim["samplers"]}) for anim in j.get("animations", [])]
    starts = [min(j["accessors"][i]["min"][0] for i in inputs) for inputs in clips]
    for inputs, start in zip(clips, starts):
        if start <= 0.0:
            continue
        moved += 1
        for i in inputs:
            if i in done:
                assert done[i] == start, "a key time list shared by clips that start at different times"
                continue
            done[i] = start
            acc = j["accessors"][i]
            view = j["bufferViews"][acc["bufferView"]]
            assert acc["componentType"] == FLOAT and acc["type"] == "SCALAR" and view.get("byteStride", 4) == 4
            at = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            times = struct.unpack_from("<%df" % acc["count"], bin_, at)
            times = [t - start for t in times]
            struct.pack_into("<%df" % acc["count"], bin_, at, *times)
            acc["min"], acc["max"] = [min(times)], [max(times)]
    return moved


if __name__ == "__main__":
    for path in sys.argv[1:]:
        j, bin_ = read(path)
        n = slide(j, bin_)
        if n:
            write(path, j, bin_)
        print("%s: %d clips slid to 0" % (path, n))
