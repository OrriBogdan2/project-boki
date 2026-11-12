"""Cinder's fuller bust (women body pass 11-11): a dome pushed into cinder.glb's bind mesh, positions and normals only, so the
rig, skin weights, clips, x_breath and paint stay byte for byte. Run it again after a v95 re-swap of cinder.glb.
The glTF frame: y up, her front -z, her left +x. Normals go through the deformation (inverse-transpose of its Jacobian).
Run: python3 tools/art1/cinder_bust_dome.py <in.glb> <out.glb>"""

import sys

import numpy as np

from glb_add_clips import read, write
from kael_retarget import get, set_

LIFT = 0.028  # m the apex moves forward (the owner's "Cinder bust bigger"; 2.6-2.8 cm reads in profile)
APEX = (0.062, 1.145)  # m: |x| and height of each apex on the appeal4 cand_5 body
R_OUT, R_IN = 0.095, 0.07  # m: the dome's reach out to the side / in to the cleft
R_UP, R_DOWN = 0.13, 0.10  # m: its reach up the chest / down to the underbust
FRONT = (0.10, 0.16)  # m in front of the spine where the dome fades in (the back and the hair behind stay)
SIDE = (0.15, 0.18)  # m out from the middle where it fades out (the arms stay)
DROP, OUT = 0.3, 0.15  # of LIFT: the lower curve's sag and the outward spread


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def field(P):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    d = np.zeros_like(P)
    mask = smooth(-z, *FRONT) * (1 - smooth(np.abs(x), *SIDE))
    for s in (1, -1):
        lx, ly = (x - s * APEX[0]) * s, y - APEX[1]
        r2 = (lx / np.where(lx > 0, R_OUT, R_IN)) ** 2 + (ly / np.where(ly > 0, R_UP, R_DOWN)) ** 2
        f = np.where(r2 < 1, (1 - r2) ** 2, 0) * mask
        d[:, 2] -= LIFT * f
        d[:, 1] -= DROP * LIFT * f * np.clip(0.3 - ly / R_DOWN, 0, 1)
        d[:, 0] += s * OUT * LIFT * f
    return d


def main(src, out):
    j, b = read(src)
    moved = 0
    for pr in j["meshes"][0]["primitives"]:
        at = pr["attributes"]
        P = get(j, b, at["POSITION"]).astype(np.float64)
        d = field(P)
        if not d.any():
            continue
        e = 1e-4
        G = np.stack([(field(P + e * np.eye(3)[k]) - field(P - e * np.eye(3)[k])) / (2 * e) for k in range(3)], 2)
        N = np.einsum("iba,ib->ia", np.linalg.inv(np.eye(3)[None] + G), get(j, b, at["NORMAL"]).astype(np.float64))
        N /= np.linalg.norm(N, axis=1, keepdims=True)
        P = P + d
        set_(j, b, at["POSITION"], P.astype(np.float32))
        set_(j, b, at["NORMAL"], N.astype(np.float32))
        acc = j["accessors"][at["POSITION"]]
        acc["min"], acc["max"] = P.min(0).tolist(), P.max(0).tolist()
        moved += int((np.abs(d).max(1) > 1e-5).sum())
    write(out, j, b)
    print("moved", moved, "vertices")


if __name__ == "__main__":
    main(*sys.argv[1:3])
