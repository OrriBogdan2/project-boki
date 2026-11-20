"""Gives the legs' skin to the leg bones in a shipped Hero .glb, in place (JOINTS_0 / WEIGHTS_0 only, numpy, no Blender).
Meshy's auto-rig left the upper thighs on the hips bone (Albert 11-20: thigh.L owned 527 vertices, thigh.R 1173, `hips`
owned the legs down to y 0.23): when the legs spread the thigh skin tore away from the pelvis skin as a flat sheet at
crotch height. Every vertex below the hip joint whose main bone is hips / skirt / a thigh moves to the thigh of its
side (a soft split across the middle), and to the shin below the knee; a soft band above the hip joint keeps the old
weights. Run: python3 tools/art1/glb_leg_weights.py <in.glb> <out.glb> [--i-checked-renders]
Then tools/art1/glb_relax.py (the weights changed: the skin relaxes again)."""

import os
import re
import struct
import sys

import numpy as np

import glb_add_clips
import glb_relax

HIP_Y = 0.40  # m: above this the old weights stay
FULL_Y = 0.34  # m: below this the leg bones have the whole weight
KNEE_Y = 0.232  # m: below this the shin takes over from the thigh (band 0.06 m)
MID_X = 0.05  # m: the crotch's soft left/right split
MAX_X = 0.40  # m: an arm / shield hung beside the leg is not a leg vertex


def main(args):
    checked = "--i-checked-renders" in args
    args = [a for a in args if a != "--i-checked-renders"]
    if re.search(r"(^|/)art/wardens/([^/]+)/\2\.glb$", os.path.abspath(args[1])) and not checked:
        sys.exit("glb_leg_weights: refusing to write a shipped Hunter glb without --i-checked-renders")
    j, bin_ = glb_add_clips.read(args[0])
    skin = j["skins"][0]
    names = [j["nodes"][jt]["name"] for jt in skin["joints"]]
    ix = {n: k for k, n in enumerate(names)}
    leg = [ix["hips"], ix["skirt"], ix["thigh.L"], ix["thigh.R"]]
    moved = 0
    for mesh, prims in glb_relax.skinned(j, bin_).items():
        if mesh == "hammer":  # (the hammer is its own piece)
            continue
        for p in prims:
            pos, jo, wt = p["pos"], p["joints"], p["weights"]
            dense = np.zeros((len(pos), len(names)))
            np.put_along_axis(dense, jo, wt, axis=1)
            dom = dense.argmax(1)
            sel = np.isin(dom, leg) & (pos[:, 1] < HIP_Y) & (np.abs(pos[:, 0]) < MAX_X)
            y, x = pos[sel, 1], pos[sel, 0]
            a = np.clip((HIP_Y - y) / (HIP_Y - FULL_Y), 0, 1)[:, None]
            k = np.clip((KNEE_Y - y) / 0.06, 0, 1)
            s = np.clip(x / MID_X, -1, 1)
            right, left = (1 + s) / 2, (1 - s) / 2
            new = np.zeros((sel.sum(), len(names)))
            for side, share in (("L", left), ("R", right)):
                new[:, ix["thigh." + side]] = share * (1 - k)
                new[:, ix["shin." + side]] = share * k
            dense[sel] = (1 - a) * dense[sel] + a * new
            moved += int(sel.sum())
            top = np.argsort(-dense, axis=1)[:, :4]
            w4 = np.take_along_axis(dense, top, 1)
            w4 = w4 / np.maximum(w4.sum(1, keepdims=True), 1e-9)
            top[w4 == 0.0] = 0
            jo_at, jo_st, jo_dt = p["jo"]
            wt_at, wt_st = p["wt"]
            for v in np.flatnonzero(sel):
                o = jo_at + v * jo_st
                bin_[o : o + 4 * jo_dt.itemsize] = top[v].astype(jo_dt).tobytes()
                o = wt_at + v * wt_st
                bin_[o : o + 16] = struct.pack("<4f", *w4[v])
    print("glb_leg_weights: %d vertices moved to the leg bones" % moved)
    glb_add_clips.write(args[1], j, bin_)


if __name__ == "__main__":
    main(sys.argv[1:])
