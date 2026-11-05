"""The Venom Fusion: what Vespyx becomes on a Hunter. Coordinates are the torso's (MergeLook hangs parts there, a 1.0
Hunter, head top about y 1.12, its back toward +z). Nothing crosses her back or chest: the tail arcs out from the
right hip, the pincers lie on the shoulders, three spines in the form's glow."""
import math

import numpy as np

import vespyx_paint as paint
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3

SIDES = (("L", -1.0), ("R", 1.0))
# the tail leaves the hip on its right side and arcs out and away, so her back stays clear; the sting hangs off her
# right shoulder, level with the head, not over it
TAIL = [v3(0.08, 0.36, 0.13), v3(0.19, 0.46, 0.25), v3(0.33, 0.64, 0.33), v3(0.44, 0.88, 0.33), v3(0.50, 1.12, 0.24),
        v3(0.50, 1.32, 0.09), v3(0.45, 1.40, -0.06), v3(0.38, 1.36, -0.17)]
RADII = [0.082, 0.086, 0.084, 0.078, 0.070, 0.062, 0.054]
STING_C = v3(0.355, 1.33, -0.22)
STING_DIR = np.array((-0.25, -0.5, -0.83))


def tail_shape():
    prims = []
    for i, r in enumerate(RADII):
        a, b = TAIL[i], TAIL[i + 1]
        d = b - a
        prims.append(Ellipsoid("plate%d" % i, "tail%d" % (i + 1), (a + b) * 0.5, v3(r, r * 0.96, np.linalg.norm(d) * 0.72),
                               rot=frame(d, v3(1, 0, 0)), k=0.008))
    return Shape(prims)


def sting_shape():
    return Shape([Cone("bulb", "sting", STING_C, STING_C + STING_DIR * 0.2, 0.09, 0.007, k=0)])


def claw_shape(sd, sx):
    """A pincer folded over the shoulder like a pauldron, small enough to keep her arm and shoulder line."""
    s = v3(sx, 1, 1)
    claw, nip = "claw." + sd, "nip." + sd
    return Shape([
        Ellipsoid("palm", claw, v3(0.31, 0.92, 0.0) * s, v3(0.095, 0.07, 0.095), k=0.01),
        Cone("finger", claw, v3(0.35, 0.92, -0.06) * s, v3(0.355, 0.93, -0.16) * s, 0.044, 0.03, k=0.02),
        Cone("fingertip", claw, v3(0.355, 0.93, -0.16) * s, v3(0.29, 0.94, -0.21) * s, 0.03, 0.004, k=0.012),
        Cone("nip0", nip, v3(0.25, 0.92, -0.07) * s, v3(0.235, 0.925, -0.15) * s, 0.036, 0.026, k=0.0),
        Cone("nip1", nip, v3(0.235, 0.925, -0.15) * s, v3(0.28, 0.935, -0.205) * s, 0.026, 0.004, k=0.012),
    ])


def spine_shape():
    """Three venom spines down the shoulders and the small of the back, in the form's glow."""
    prims = []
    for i, (a, b, r) in enumerate((((0.20, 0.97, 0.03), (0.27, 1.11, 0.08), 0.03), ((-0.20, 0.97, 0.03), (-0.27, 1.11, 0.08), 0.03),
                                   ((-0.26, 0.96, 0.03), (-0.37, 1.05, 0.08), 0.024))):
        prims.append(Cone("s%d" % i, "root", v3(*a), v3(*b), r, 0.003, k=0))
    return Shape(prims)


def parts():
    """name -> (Shape, tris, slot, paint name)."""
    out = {"tail": (tail_shape(), 420, 0, "shell"), "sting": (sting_shape(), 60, 1, "glow"),
           "spines": (spine_shape(), 40, 1, "glow")}
    for sd, sx in SIDES:
        out["claw" + sd] = (claw_shape(sd, sx), 170, 0, "shell")
    return out


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None)}
    parent = "root"
    for i in range(7):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL[i]), tuple(TAIL[i + 1]), parent)
        parent = n
    b["sting"] = (tuple(TAIL[7]), tuple(STING_C), "tail7")
    for sd, sx in SIDES:
        s = v3(sx, 1, 1)
        b["claw." + sd] = (tuple(v3(0.24, 0.92, 0.03) * s), tuple(v3(0.32, 0.92, -0.08) * s), "root")
        b["nip." + sd] = (tuple(v3(0.25, 0.92, -0.07) * s), tuple(v3(0.235, 0.925, -0.15) * s), "claw." + sd)
    return b


def idle(t):
    """The tail sways off her shoulder, ready to strike; the pincers snip now and then."""
    p = {}
    for i in range(7):
        ph = math.tau * (t - i * 0.09)
        p["tail%d" % (i + 1)] = (0.028 * math.sin(ph), 0.05 * math.sin(ph + 0.8), 0)
    snip = max(0.0, math.sin(math.tau * t * 3)) ** 4 * (1 if t > 0.55 else 0)
    p["nip.L"] = (0, -0.45 * snip, 0)
    p["nip.R"] = (0, 0.45 * snip, 0)
    return p


CLIPS = {"idle": (3.0, True, idle)}


def paint_piece(name, p, n, prims):
    if name == "shell":
        ds = np.sort(np.stack([pr.d(p) for pr in prims], -1), axis=-1)
        gap = ds[:, 1] - ds[:, 0] if len(prims) > 6 else np.full(len(p), 1.0)
        return paint.paint_shell(p, n, gap)
    return np.tile(np.array([0.72, 1.0, 0.3]), (len(p), 1))
