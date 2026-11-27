"""Bakes a uniform scale on a skeleton's parent node into the bones (no Blender, same look).

Meshy's rig of an UPLOADED glb comes back in centimetres under an `Armature` node scaled 0.01. The game's Meshy-native
path poses the Skeleton3D in metres and drops that node's scale, so such a body draws 100x too big (Meeko round 12:
invisible at the game camera, `--warden-native-check` "head 53 m over the hips"). This sets the node's scale to 1 and
multiplies by the old scale s: every descendant node's rest translation, every translation key of those nodes, and the
first three rows of every inverse bind matrix (IBM' = S * IBM, as the bones' globals become G * S^-1). Mesh, rotations,
skin indices and weights stay byte-identical.

  python3 tools/art1/glb_unscale_armature.py IN.glb OUT.glb [--node=Armature]
"""

import argparse
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "meshy", "native_hunters"))
import graft  # noqa: E402
import native_pack as npk  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--node", default="Armature")
    o = ap.parse_args()
    js, bin_ = npk.load(o.inp)
    root = next(i for i, n in enumerate(js["nodes"]) if n.get("name") == o.node)
    sc = js["nodes"][root].get("scale")
    if not sc or not np.allclose(sc, sc[0]) or abs(sc[0] - 1) < 1e-9:
        raise SystemExit(f"{o.node} has no uniform non-1 scale ({sc})")
    s = float(sc[0])
    del js["nodes"][root]["scale"]
    below, todo = set(), list(js["nodes"][root].get("children", []))
    while todo:
        i = todo.pop()
        below.add(i)
        todo += js["nodes"][i].get("children", [])
    for i in below:
        if "translation" in js["nodes"][i]:
            js["nodes"][i]["translation"] = [v * s for v in js["nodes"][i]["translation"]]
        if "matrix" in js["nodes"][i]:
            raise SystemExit(f"node {js['nodes'][i]['name']} uses a matrix")
    out = npk.Out(js, bin_)

    def replace(ai, arr):
        a = js["accessors"][ai]
        a["bufferView"] = out.add_view(np.ascontiguousarray(arr, np.float32).tobytes())
        a.pop("byteOffset", None)
        if "min" in a:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()

    done = set()
    for an in js.get("animations", []):
        for ch in an["channels"]:
            if ch["target"].get("node") in below and ch["target"]["path"] == "translation":
                ai = an["samplers"][ch["sampler"]]["output"]
                if ai not in done:
                    replace(ai, graft.read(js, bin_, ai).astype(np.float32) * s)
                    done.add(ai)
    for sk in js.get("skins", []):
        ai = sk["inverseBindMatrices"]
        if ai in done:
            continue
        m = graft.read(js, bin_, ai).astype(np.float32).reshape(-1, 4, 4)  # column-major: m[k, col, row]
        m[:, :, :3] *= s
        replace(ai, m.reshape(-1, 16))
        done.add(ai)
    graft.compact(out)
    out.write(o.out)
    print(o.out, f"{o.node} scale {s} baked into {len(below)} nodes, {len(done)} accessors")


if __name__ == "__main__":
    main()
