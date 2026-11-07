"""Kael v2's clips: the 49 hand-keyed clips of the first Kael (ext/art1-kael-2, 67 bones) copied onto the v2 rig by bone name.
The two rigs share every rest rotation of the bones they have in common, so each rotation track copies as is. The v2 torso is longer and the
shoulders wider, so a translation track keeps its motion and takes the v2 rest as its base (new = old - old rest + new rest: the hips' bob
rides the v2 hip height). Bones only the first rig had (lids, brows, fingers, thumb, feet, the scarftail and centre-mane springs) are dropped, and
springs go untracked (the game's spring chains drive them from the rest pose).
Run with Blender's python (numpy): blender -b --factory-startup --python tools/art1/kael_retarget.py -- <old.glb> <v2.glb> <out.glb>"""
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_add_clips import read, write

PAD = {"dash": 0.9}     # clip: the length the kit's move keys run to (the first kit's dash was 0.42 s, this one holds its recovery): the last pose holds
NCOMP = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}


def rest(j):
    return {n["name"]: (np.array(n.get("translation", [0, 0, 0]), np.float64), np.array(n.get("rotation", [0, 0, 0, 1]), np.float64)) for n in j["nodes"]}


def get(j, b, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    k = NCOMP[ac["type"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return np.frombuffer(bytes(b[off:off + ac["count"] * k * 4]), np.float32).reshape(ac["count"], k)


def put(j, b, arr, typ):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b.extend(arr.tobytes())
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR":
        ac["min"], ac["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def main(old_p, new_p, out_p):
    oj, ob = read(old_p)
    nj, nb = read(new_p)
    o_rest, n_rest = rest(oj), rest(nj)
    nid = {n["name"]: i for i, n in enumerate(nj["nodes"])}
    nj["animations"] = []
    times = {}
    dropped = set()
    for an in oj["animations"]:
        out = {"name": an["name"], "channels": [], "samplers": []}
        for ch in an["channels"]:
            nm = oj["nodes"][ch["target"]["node"]]["name"]
            if nm not in nid or nm.startswith("spring"):
                dropped.add(nm)
                continue
            sm = an["samplers"][ch["sampler"]]
            assert sm.get("interpolation", "LINEAR") != "CUBICSPLINE"
            path = ch["target"]["path"]
            t = get(oj, ob, sm["input"]).copy()
            v = get(oj, ob, sm["output"]).copy()
            if an["name"] in PAD and t[-1] < PAD[an["name"]]:
                t = np.append(t, np.float32(PAD[an["name"]]))
                v = np.vstack([v, v[-1:]])
            if (an["name"] in PAD, sm["input"]) not in times:
                times[(an["name"] in PAD, sm["input"])] = put(nj, nb, t, "SCALAR")
            if path == "translation":
                v += (n_rest[nm][0] - o_rest[nm][0]).astype(np.float32)
            out["samplers"].append({"input": times[(an["name"] in PAD, sm["input"])], "output": put(nj, nb, v, "VEC4" if path == "rotation" else "VEC3"),
                                    "interpolation": sm.get("interpolation", "LINEAR")})
            out["channels"].append({"sampler": len(out["samplers"]) - 1, "target": {"node": nid[nm], "path": path}})
        nj["animations"].append(out)
    write(out_p, nj, nb)
    drift = [k for k in n_rest if k in o_rest and not k.startswith("spring") and abs(float(np.dot(o_rest[k][1], n_rest[k][1]))) < 0.99999]
    print("clips", len(nj["animations"]), "dropped", len(dropped), "rest rotation drift", drift)


if __name__ == "__main__":
    main(*sys.argv[sys.argv.index("--") + 1:][:3])
