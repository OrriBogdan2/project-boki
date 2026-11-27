"""Meshy rigs made from an uploaded .glb have their bones in centimetres: the Armature node carries scale 0.01 over
the bones and the clips' translation keys, and the inverse bind matrices carry the x100 (mesh metres to bone cm). The
game's native path (docs/art/wardens/MESHY_NATIVE.md) wants metres like the rigs made from a task id. This writes the
same file with Armature scale 1, the bones' offsets, the clips' translation keys and the inverse bind matrices x0.01.
Rotations, weights, the mesh and names stay.

  python3 tools/meshy/rig_to_metres.py IN.glb OUT.glb
"""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import native_pack as npk

CM = 0.01


def _view(js, bin_, ai):
    a = js["accessors"][ai]
    bv = js["bufferViews"][a["bufferView"]]
    assert "byteStride" not in bv, "interleaved accessor"
    k = npk.COMP[a["type"]]
    return np.frombuffer(bin_, np.float32, a["count"] * k, bv.get("byteOffset", 0) + a.get("byteOffset", 0)), a, k


def main(src, dst):
    js, bin_ = npk.load(src)
    bin_ = bytearray(bin_)
    arm = next(n for n in js["nodes"] if n.get("scale") == [CM, CM, CM] and "children" in n)
    arm["scale"] = [1.0, 1.0, 1.0]
    for i in js["skins"][0]["joints"]:
        if "translation" in js["nodes"][i]:
            js["nodes"][i]["translation"] = [v * CM for v in js["nodes"][i]["translation"]]
    v, a, k = _view(js, bin_, js["skins"][0]["inverseBindMatrices"])
    v.reshape(-1, 4, 4)[:, :, :3] *= CM  # (column-major: the matrices' rows 0-2 map the mesh's metres to the bones' cm)
    for an in js.get("animations", []):
        for ch in an["channels"]:
            if ch["target"]["path"] == "translation":
                v, a, k = _view(js, bin_, an["samplers"][ch["sampler"]]["output"])
                v[:] *= CM
                a["min"], a["max"] = v.reshape(-1, 3).min(0).tolist(), v.reshape(-1, 3).max(0).tolist()
    out = npk.Out(js, bytes(bin_))
    out.write(dst)


if __name__ == "__main__":
    main(*sys.argv[1:3])
