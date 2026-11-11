"""Puts Meeko's paws on her foot bones in the shipped pip.glb, in place (every other byte stays the same). pip_source.py
gave the leg weights only to fur near the thigh's line, so the splayed paws fell to `root` and slid with her body
whatever the legs did (fixed there too, for the next rebuild). Fur below the ankle that rides `root` goes to the
foot bone on its side; across the ankle (FOOT_TOP..SHIN_FROM) it blends into the shin, so the joint bends, not tears.
Run: python3 tools/art1/pip_feet_weights.py art/wardens/pip/pip.glb [out.glb]"""
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write

FOOT_TOP = 0.075    # model m: below this a paw vert is all foot
SHIN_FROM = 0.095   # model m: the shin's own weights start here (pip_source's leg band)
ROOT_HELD = 0.5     # a vert this much on `root` is one the leg weights missed


def start(j, acc):
    a = j["accessors"][acc]
    return j["bufferViews"][a["bufferView"]].get("byteOffset", 0) + a.get("byteOffset", 0), a["count"]


def main(src, out):
    j, bin_ = read(src)
    names = [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]
    root = names.index("root")
    moved = 0
    for prim in next(m for m in j["meshes"] if m["name"] == "Pip")["primitives"]:
        at = prim["attributes"]
        pos, n = start(j, at["POSITION"])
        jo, _ = start(j, at["JOINTS_0"])         # 4 unsigned bytes a vert
        we, _ = start(j, at["WEIGHTS_0"])        # 4 floats a vert
        for i in range(n):
            x, y, _z = struct.unpack_from("<3f", bin_, pos + 12 * i)       # glTF y is up
            js = bin_[jo + 4 * i:jo + 4 * i + 4]
            ws = struct.unpack_from("<4f", bin_, we + 16 * i)
            if y >= SHIN_FROM or sum(w for b, w in zip(js, ws) if b == root) <= ROOT_HELD:
                continue
            side = "L" if x < 0 else "R"                                    # her left is -x
            k = min(1.0, max(0.0, (y - FOOT_TOP) / (SHIN_FROM - FOOT_TOP)))
            bin_[jo + 4 * i:jo + 4 * i + 4] = bytes((names.index("foot." + side), names.index("shin." + side), 0, 0))
            struct.pack_into("<4f", bin_, we + 16 * i, 1.0 - k, k, 0.0, 0.0)
            moved += 1
    write(out, j, bin_)
    print("paws: %d verts moved off root onto the foot bones" % moved)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1])
