"""Takes the scale off Meshy's armature node. Rigs from 2026-11-22 come as a skeleton in centimetres under an
"Armature" node scaled 0.01 (older ones were in metres, unscaled); WardenNative fits the body from the skeleton's own
space, so the 0.01 on top shrank the body to 1/10000. The file is rewritten so the armature keeps its place and
rotation but not its scale: every node below it, the inverse bind matrices and the clips' translation keys are in
metres instead. The pose in the world is unchanged (a metre-unit file has no such node and passes through).

  python3 flatten.py OUT.glb IN.glb
"""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 2)[0])
import native_pack as npk


def scaled(js):
    """(armature node index, its uniform scale) when a non-joint node carries one, else None."""
    joints = {i for sk in js.get("skins", []) for i in sk["joints"]}
    for i, n in enumerate(js["nodes"]):
        s = n.get("scale")
        if s and i not in joints and n.get("children") and abs(s[0] - s[1]) < 1e-6 and abs(s[0] - s[2]) < 1e-6:
            if abs(s[0] - 1.0) > 1e-6:
                return i, float(s[0])
    return None


def below(js, root):
    out, todo = set(), list(js["nodes"][root].get("children", []))
    while todo:
        i = todo.pop()
        out.add(i)
        todo += js["nodes"][i].get("children", [])
    return out


def scale_accessor(out, ai, f):
    """Edits accessor `ai` (float, tightly packed) in place: f(array of rows) -> array."""
    a = out.js["accessors"][ai]
    a.pop("min", None)
    a.pop("max", None)
    k = npk.COMP[a["type"]]
    chunk = bytearray(out.chunks[2 * a["bufferView"] + 1])
    o = a.get("byteOffset", 0)
    v = np.frombuffer(bytes(chunk[o : o + a["count"] * k * 4]), np.float32).reshape(a["count"], k)
    chunk[o : o + a["count"] * k * 4] = np.ascontiguousarray(f(v.copy()), np.float32).tobytes()
    out.chunks[2 * a["bufferView"] + 1] = bytes(chunk)


def main(out_path, in_path):
    js, bin_ = npk.load(in_path)
    hit = scaled(js)
    out = npk.Out(js, bin_)
    if hit:
        root, s = hit
        kids = below(js, root)
        del js["nodes"][root]["scale"]
        for i in kids:
            n = js["nodes"][i]
            if "translation" in n:
                n["translation"] = [x * s for x in n["translation"]]
        for sk in js.get("skins", []):
            if "inverseBindMatrices" in sk:  # (column-major: element c*4 + r; the first three rows scale)
                def ibm(v):
                    m = v.reshape(-1, 4, 4)  # [joint, column, row]
                    m[:, :, :3] *= s
                    return m.reshape(-1, 16)

                scale_accessor(out, sk["inverseBindMatrices"], ibm)
        seen = set()
        for a in js.get("animations", []):
            for c in a["channels"]:
                ai = a["samplers"][c["sampler"]]["output"]
                if c["target"]["path"] == "translation" and c["target"]["node"] in kids and ai not in seen:
                    seen.add(ai)
                    scale_accessor(out, ai, lambda v: v * s)
    out.write(out_path)
    print(out_path, "armature scale", hit[1] if hit else "none")


if __name__ == "__main__":
    main(*sys.argv[1:3])
