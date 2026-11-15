"""Sets one clip of a .glb to a new length with no Blender: every key time of the clip is scaled by new/old, nothing
else in the file changes (the clip's time accessors must be its own; a time accessor another clip shares stops it).
Run: python3 tools/art1/glb_clip_length.py <glb> <clip> <seconds> [out.glb]"""
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write


def main() -> None:
    src, clip, want = sys.argv[1], sys.argv[2], float(sys.argv[3])
    out = sys.argv[4] if len(sys.argv) > 4 else src
    js, bin_ = read(src)
    bin_ = bytearray(bin_)
    anims = js["animations"]
    an = next(a for a in anims if a.get("name") == clip)
    own = {s["input"] for s in an["samplers"]}
    others = {s["input"] for a in anims if a is not an for s in a["samplers"]}
    if own & others:
        sys.exit("%s: a time accessor is shared with another clip" % clip)
    length = max(js["accessors"][i]["max"][0] for i in own)
    k = want / length
    for i in own:
        acc = js["accessors"][i]
        view = js["bufferViews"][acc["bufferView"]]
        at = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 4)
        for n in range(acc["count"]):
            p = at + n * stride
            struct.pack_into("<f", bin_, p, struct.unpack_from("<f", bin_, p)[0] * k)
        acc["min"] = [acc["min"][0] * k]
        acc["max"] = [acc["max"][0] * k]
    write(out, js, bytes(bin_))
    print("%s: %.3f s -> %.3f s" % (clip, length, want))


if __name__ == "__main__":
    main()
