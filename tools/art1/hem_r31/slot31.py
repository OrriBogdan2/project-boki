"""slot31.py IN.glb OUT.glb [name=new ...] : rename glTF materials in the JSON chunk only (binary chunk byte-identical).

Lace r31: WardenGlb._toon picks a surface's look by the material name's slot ("<slot>-<tag>"). The skirt's "skirt-*" slot is
not tuned in warden_look.json "hem", so it gets hero_look's fres 1.0 (a pale lightened-red fresnel) = the salmon-pink skirt at
the match camera. Default renames move the 4 skirt materials onto hem's tuned "cloth" slot (fres 0.35, far_lift 0.25).
"""
import json
import struct
import sys

DEFAULT = {
    "skirt-meshy": "cloth-skirtmeshy",
    "skirt-liner": "cloth-skirtliner",
    "skirt-lining23": "cloth-skirtlining",
    "skirt-godet30": "cloth-skirtgodet",
}


def main(src, dst, pairs):
    ren = dict(p.split("=", 1) for p in pairs) if pairs else DEFAULT
    b = open(src, "rb").read()
    magic, ver, _ = struct.unpack("<III", b[:12])
    jl, jt = struct.unpack("<II", b[12:20])
    assert magic == 0x46546C67 and jt == 0x4E4F534A
    j = json.loads(b[20 : 20 + jl])
    rest = b[20 + jl :]
    done = []
    for m in j["materials"]:
        if m.get("name") in ren:
            done.append((m["name"], ren[m["name"]]))
            m["name"] = ren[m["name"]]
    missing = set(ren) - {a for a, _ in done}
    if missing:
        sys.exit("missing materials: %s" % sorted(missing))
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out = struct.pack("<III", magic, ver, 20 + len(js) + len(rest)) + struct.pack("<II", len(js), jt) + js + rest
    open(dst, "wb").write(out)
    for a, c in done:
        print("%s -> %s" % (a, c))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
