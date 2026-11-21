#!/usr/bin/env python3
"""glb_wing_cards.py IN.glb OUT.glb PARAMS.json
Re-places the two `card-wing` cards v95_swap.py's `wing_cards` made (Meeko r3), touching nothing else in the glb: each card
vertex is rebuilt from its UV (a across the painted wing, b down it) and the side of its x with the same formula as
wing_cards() (PARAMS = the spec's wing_cards: w, h, root [x, y, z], attach [u, v], u_max, sweep, lean). Skin weights, clips and
every other mesh stay as they are, so a card's size, height or sweep is tuned in seconds, not a 1 h swap."""
import json
import struct
import sys

import numpy as np


def main(src, out, params):
    c = json.load(open(params))
    b = open(src, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    o = 20 + n
    blen = struct.unpack("<I", b[o:o + 4])[0]
    binary = bytearray(b[o + 8:o + 8 + blen])
    mi = [i for i, m in enumerate(j["materials"]) if m["name"] == "card-wing"][0]
    uw = float(c.get("u_max", 0.689))
    au, av = c["attach"]
    rx, ry, rz = c["root"]
    done = 0
    for mesh in j["meshes"]:
        for pr in mesh["primitives"]:
            if pr.get("material") != mi:
                continue
            def acc(k):
                a = j["accessors"][pr["attributes"][k]]
                v = j["bufferViews"][a["bufferView"]]
                return a, v.get("byteOffset", 0) + a.get("byteOffset", 0), v.get("byteStride", 0)
            pa, po, ps = acc("POSITION")
            ta, to, ts = acc("TEXCOORD_0")
            na, no, ns = acc("NORMAL")
            P = np.zeros((pa["count"], 3), np.float32)
            for i in range(pa["count"]):
                u, v = struct.unpack_from("<2f", binary, to + i * (ts or 8))
                x0, y0, z0 = struct.unpack_from("<3f", binary, po + i * (ps or 12))      # glTF: x, z, -y
                sgn = 1.0 if x0 > 0 else -1.0
                a_, bb = u / uw, 1.0 - v
                d = (au / uw - a_) * c["w"]
                z = rz + (av - bb) * c["h"]
                x = sgn * (rx + d)
                y = ry - c.get("sweep", 0.15) * d + c.get("lean", 0.1) * (z - rz)
                P[i] = (x, z, -y)
                struct.pack_into("<3f", binary, po + i * (ps or 12), *P[i])
            # (a flat card: every normal the plane's, facing the back for the right card's winding as exported)
            for i in range(pa["count"]):
                sgn = 1.0 if P[i][0] > 0 else -1.0
                du = np.array([-sgn, 0.0, c.get("sweep", 0.15) * sgn])      # along the outward direction, glTF (x, z, -y): d(x)=sgn, d(-y)=+sweep*sgn
                dv = np.array([0.0, 1.0, -c.get("lean", 0.1)])
                nrm = np.cross(du, dv)
                nrm = nrm / (np.linalg.norm(nrm) or 1)
                old = struct.unpack_from("<3f", binary, no + i * (ns or 12))
                if np.dot(nrm, old) < 0:
                    nrm = -nrm
                struct.pack_into("<3f", binary, no + i * (ns or 12), *nrm)
            lo, hi = P.min(0).tolist(), P.max(0).tolist()
            pa["min"], pa["max"] = lo, hi
            done += 1
    if not done:
        sys.exit("no card-wing primitive")
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(binary)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + bytes(binary))
    print("wing cards re-placed:", done, "primitive(s) ->", out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
