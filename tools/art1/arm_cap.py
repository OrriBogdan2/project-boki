"""Eases a rotation track's far swings toward a centre pose, in a .glb with no Blender (keys, times and every other byte stay).
Two loops blended on a ring (walk over run) slerp each bone along the shorter way; where a bone's two loops sit ~180 deg
apart the shorter way flips from one frame to the next, so a start or stop pops the arm (--loco-dir-check SNAP). Capping
the swing at CAP degrees from a centre keeps every pair under 180.
Run: python3 tools/art1/arm_cap.py SRC.glb OUT.glb "[(['run'], 'forearm.L', (x, y, z, w), CAP_DEG), ...]"
A swing past KNEE x CAP degrees is squeezed (tanh) toward CAP, so no key meets a hard corner."""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write

KNEE = 0.7


def cap_track(q, centre, cap):
    """q: (n, 4) keys. Returns them with every swing past the knee eased to under `cap` degrees from `centre`."""
    out = q.copy()
    knee = cap * KNEE
    for i, k in enumerate(q):
        k = k if k @ centre >= 0 else -k
        deg = np.degrees(2 * np.arccos(min(1.0, k @ centre)))
        if deg > knee:
            f = (knee + (cap - knee) * np.tanh((deg - knee) / (cap - knee))) / deg
            th = np.arccos(min(1.0, k @ centre))
            k = (np.sin((1 - f) * th) * centre + np.sin(f * th) * k) / np.sin(th)
        out[i] = k / np.linalg.norm(k)
    return out


if __name__ == "__main__":
    src, out, plan = sys.argv[1], sys.argv[2], eval(sys.argv[3])
    j, b = read(src)
    names = [n.get("name") for n in j["nodes"]]
    for clips, bone, centre, cap in plan:
        c = np.array(centre, float) / np.linalg.norm(centre)
        for an in j["animations"]:
            for ch in an["channels"]:
                if (
                    not an["name"].startswith(tuple(clips))
                    or ch["target"]["path"] != "rotation"
                    or names[ch["target"]["node"]] != bone
                ):
                    continue
                ac = j["accessors"][an["samplers"][ch["sampler"]]["output"]]
                bv = j["bufferViews"][ac["bufferView"]]
                at = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
                q = np.frombuffer(bytes(b[at : at + ac["count"] * 16]), dtype="<f4").reshape(-1, 4).astype(float)
                b[at : at + ac["count"] * 16] = cap_track(q, c, cap).astype("<f4").tobytes()
    write(out, j, b)
