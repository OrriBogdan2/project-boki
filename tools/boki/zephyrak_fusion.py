"""The Stormwing Fusion: Zephyrak's swift wings spread from the Hunter's shoulder blades, its eel tail swimming off the
lower back, and a crackling ridge of static down the spine. Torso coordinates as vespyx_fusion.py."""
import math

import numpy as np

import zephyrak as sp
from boki_sdf import Cone, Ellipsoid, Shape, v3

SIDES = sp.SIDES
HARD = ("ridge", "sparks")
# shoulder, wrist, tip of the right wing; mirrored
WING = (v3(0.13, 0.9, 0.16), v3(0.42, 1.08, 0.26), v3(0.98, 1.22, 0.56))
TAIL = [v3(0, 0.5, 0.2), v3(0.02, 0.38, 0.3), v3(0.06, 0.26, 0.38), v3(0.12, 0.17, 0.44), v3(0.2, 0.11, 0.48),
        v3(0.29, 0.08, 0.5)]
TAIL_R = [0.1, 0.085, 0.068, 0.05, 0.034]


def wing_line(sx):
    """(point, radius, bone) along the wing, and its normal: level along the chord, tipped up along the span."""
    root, wrist, tip = (v3(sx * q[0], q[1], q[2]) for q in WING)
    n = np.cross(v3(0, 0, 1), tip - root) * sx
    n = n / np.linalg.norm(n)
    mid = wrist + (tip - wrist) * 0.45
    return [(root, 0.1, "wing1"), (wrist, 0.11, "wing2"), (mid, 0.085, "wing2"), (tip, 0.01, "wing2")], n


def wing_shape():
    prims = []
    for sd, sx in SIDES:
        pts, n = wing_line(sx)
        flat = {"flat": 0.14, "flat_axis": n}
        for i in range(len(pts) - 1):
            (a, ra, bone), (b, rb, _) = pts[i], pts[i + 1]
            prims.append(Cone("w%d%s" % (i, sd), "%s.%s" % (bone, sd), a, b, ra, rb, k=0.03, **flat))
        back = sp.trailing(pts, n, 0.55)
        prims.append(Cone("wd" + sd, "wing1." + sd, back[0], back[1] + (back[2] - back[1]) * 0.3, 0.085, 0.075, k=0.04,
                          **flat))
    return Shape(prims)


def spark_shape():
    prims = []
    for sd, sx in SIDES:
        pts, n = wing_line(sx)
        edge_pts = sp.trailing(pts, n, 0.92)
        for i in range(1, len(pts) - 1):
            prims.append(Cone("s%d%s" % (i, sd), "wing2." + sd, edge_pts[i] + n * 0.005, edge_pts[i + 1] + n * 0.005,
                              0.018, 0.018 if i < len(pts) - 2 else 0.006, k=0.01))
    return Shape(prims)


def tail_shape():
    prims = [Ellipsoid("mantle", "root", v3(0, 0.86, 0.13), v3(0.2, 0.08, 0.1), k=0)]
    for i, r in enumerate(TAIL_R):
        prims.append(Cone("t%d" % i, "tail%d" % (i + 1), TAIL[i], TAIL[i + 1], r, r * 0.8, k=0.03))
    end = TAIL[-1]
    for sd, sx in SIDES:
        prims.append(Cone("fork" + sd, "tail5", end - v3(0.03, 0, 0.02), end + v3(0.12 + 0.06 * sx, 0.1 * sx, 0.12),
                          0.06, 0.008, k=0.03, flat=0.25, flat_axis=v3(0.3, 0.2, -1)))
    return Shape(prims)


def ridge_shape():
    side = v3(1, 0, 0)
    prims = []
    for i, (y, z) in enumerate(((0.98, 0.17), (0.88, 0.2), (0.76, 0.22), (0.64, 0.22), (0.53, 0.24))):
        h = 0.13 - i * 0.015
        prims.append(Cone("r%d" % i, "root", v3(0, y, z - 0.02), v3(0, y + h * 0.4, z + h), 0.05, 0.005, k=0, flat=0.3,
                          flat_axis=side))
    return Shape(prims)


def parts():
    """name -> (Shape, tris, slot, paint name)."""
    return {"wings": (wing_shape(), 405, 0, "wing"), "tail": (tail_shape(), 315, 0, "skin"),
            "ridge": (ridge_shape(), 100, 1, "glow"), "sparks": (spark_shape(), 90, 1, "glow")}


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None)}
    for sd, sx in SIDES:
        root, wrist, tip = (tuple(v3(sx * q[0], q[1], q[2])) for q in WING)
        b["wing1." + sd] = (root, wrist, "root")
        b["wing2." + sd] = (wrist, tip, "wing1." + sd)
    parent = "root"
    for i in range(len(TAIL_R)):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL[i]), tuple(TAIL[i + 1]), parent)
        parent = n
    return b


def idle(t):
    """Slow wingbeats with the tips whipping after, the tail swimming the air behind."""
    p = {}
    for sd, sx in SIDES:
        p["wing1." + sd] = (0, 0, sx * 0.14 * math.sin(math.tau * t * 2))
        p["wing2." + sd] = (0, 0, sx * 0.12 * math.sin(math.tau * (t * 2 - 0.12)))
    for i in range(len(TAIL_R)):
        ph = math.tau * (t - i * 0.1)
        p["tail%d" % (i + 1)] = (0.03 * math.sin(ph), 0.12 * math.sin(ph - 0.12 * i), 0)
    return p


CLIPS = {"idle": (3.0, True, idle)}


def paint_piece(name, p, n, prims):
    if name == "wing":
        return sp.paint_wing(p * 0.46, n)
    if name == "skin":
        return sp.paint_body(p * 0.5 + np.array([0, 0, 0.1]), n)
    return np.tile(sp.GLOW, (len(p), 1))
