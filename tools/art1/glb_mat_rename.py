"""Renames materials of a .glb, leaving every other byte the same (the binary chunk untouched, the JSON re-padded).
A Hunter's material name is its toon slot and tag ("<slot>-<tag>", WardenGlb._toon); a name starting "eyes-mood"
hands the surface to WardenMood's drawn face. Albert's v95 port kept the master's UVs, so the drawn face (UV-mapped
on the old glass) never showed and covered his painted eyes: eyes-mood-v95 -> eyes-v95 shows the picked paint.
Run: python3 tools/art1/glb_mat_rename.py IN.glb OUT.glb OLD=NEW [OLD=NEW ...]"""
import json
import struct
import sys


def main():
    src, out, pairs = sys.argv[1], sys.argv[2], dict(a.split("=", 1) for a in sys.argv[3:])
    b = open(src, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    rest = b[20 + n :]
    done = set()
    for m in j.get("materials", []):
        if m.get("name") in pairs:
            done.add(m["name"])
            m["name"] = pairs[m["name"]]
    missing = set(pairs) - done
    if missing:
        sys.exit("glb_mat_rename: no material " + ", ".join(sorted(missing)))
    s = json.dumps(j, separators=(",", ":")).encode()
    s += b" " * ((-len(s)) % 4)
    head = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(s) + len(rest)) + struct.pack("<II", len(s), 0x4E4F534A)
    open(out, "wb").write(head + s + rest)
    print("glb_mat_rename:", ", ".join("%s -> %s" % (k, pairs[k]) for k in sorted(done)))


main()
