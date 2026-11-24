"""fixcolor.py IN.glb LIVE.glb OUT.glb: IN's COLOR_0 is VEC3 (the ink room, alpha, was lost in the rig/export), so the
ink shell grows its full width and pokes through thin parts (the head fin). Copies LIVE's COLOR_0 alpha onto IN by
triangle corner (both have the same triangle lists, IN has split vertices) and writes COLOR_0 as VEC4."""
import json, struct, sys, numpy as np
from glbp import load, acc
src, live, dst = sys.argv[1:4]
j, b = load(src); jl, bl_ = load(live)
bin_ = bytearray(b)
P = j["meshes"][0]["primitives"]; PL = jl["meshes"][0]["primitives"]
rep = []
for p, q in zip(P, PL):
    ia = acc(j, b, p["indices"])[:, 0]; ib = acc(jl, bl_, q["indices"])[:, 0]
    assert len(ia) == len(ib)
    ca = acc(jl, bl_, q["attributes"]["COLOR_0"])[:, 3]
    n = j["accessors"][p["attributes"]["POSITION"]]["count"]
    al = np.full(n, np.nan, "f4")
    # IN's vertex v takes the alpha of the live vertex at the same triangle corner (mean over its corners)
    s = np.zeros(n); c = np.zeros(n)
    np.add.at(s, ia, ca[ib]); np.add.at(c, ia, 1)
    al = (s / np.maximum(c, 1)).astype("f4")
    # spread check: corners of one vertex should agree
    mx = np.zeros(n); np.maximum.at(mx, ia, ca[ib]); mn = np.ones(n); np.minimum.at(mn, ia, ca[ib])
    rep.append((n, float((mx - mn).max())))
    col = np.concatenate([np.ones((n, 3), "f4"), al[:, None]], 1).astype("<f4")
    while len(bin_) % 4: bin_.append(0)
    off = len(bin_); bin_ += col.tobytes()
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": col.nbytes})
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": n, "type": "VEC4"})
    p["attributes"]["COLOR_0"] = len(j["accessors"]) - 1
print("verts, max corner alpha spread:", rep)
j["buffers"][0]["byteLength"] = len(bin_)
hdr = json.dumps(j, separators=(",", ":")).encode(); hdr += b" " * ((4 - len(hdr) % 4) % 4)
while len(bin_) % 4: bin_.append(0)
open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 20 + len(hdr) + 8 + len(bin_)) + struct.pack("<I", len(hdr)) + b"JSON" + hdr + struct.pack("<I", len(bin_)) + b"BIN\0" + bytes(bin_))
