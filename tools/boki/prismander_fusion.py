"""The Prism Shell's Blender parts: a mantle of living crystal fanned from the shoulders, shards down the spine and
a crystal-finned tail. Torso coordinates as vespyx_fusion.py."""
import math

import numpy as np

import prismander as sp
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3

SIDES = sp.SIDES
HARD = ("crystal",)
FANS = (((0.17, 0.92, 0.10), (0.60, 1.26, 0.22), 0.13), ((0.21, 0.84, 0.10), (0.74, 0.92, 0.22), 0.14),
        ((0.20, 0.74, 0.12), (0.60, 0.56, 0.22), 0.115))
TAIL = [v3(0, 0.36, 0.14), v3(0, 0.30, 0.34), v3(0, 0.26, 0.54), v3(0, 0.28, 0.74), v3(0, 0.36, 0.90)]
TAIL_R = [(0.11, 0.13), (0.09, 0.11), (0.066, 0.085), (0.04, 0.06)]


def crystal_shape():
    prims = []
    n = v3(0, 0.1, 1)
    for sd, sx in SIDES:
        for i, (a, b, r) in enumerate(FANS):
            prims += sp.shard("f%s%d" % (sd, i), "gill." + sd, v3(a[0] * sx, a[1], a[2]), v3(b[0] * sx, b[1], b[2]), r, 0.55, n)
    for i, (y, z, h, r) in enumerate(((0.72, 0.17, 0.2, 0.07), (0.5, 0.2, 0.24, 0.085), (0.28, 0.2, 0.2, 0.07))):
        prims += sp.shard("s%d" % i, "root", v3(0, y, z), v3(0, y + 0.03, z + h), r)
    return Shape(prims)


def fin_shape():
    side = v3(1, 0, 0)
    prims = []
    for i in range(1, 4):
        a, b = TAIL[i], TAIL[i + 1]
        prims.append(Cone("f%d" % i, "tail%d" % (i + 1), a + v3(0, 0.05, 0), b + v3(0, 0.15, 0.04), 0.075, 0.05, k=0.03, flat=0.14,
                          flat_axis=side))
    return Shape(prims)


def tail_shape():
    prims = []
    for i, (rx, ry) in enumerate(TAIL_R):
        a, b = TAIL[i], TAIL[i + 1]
        d = b - a
        prims.append(Ellipsoid("t%d" % i, "tail%d" % (i + 1), (a + b) * 0.5, v3(rx * 0.7, ry, np.linalg.norm(d) * 0.8),
                               rot=frame(d, v3(1, 0, 0)), k=0.04))
    return Shape(prims)


def collar_shape():
    prims = [Ellipsoid("c", "root", v3(0, 0.84, 0.13), v3(0.17, 0.07, 0.09), k=0)]
    for sd, sx in SIDES:
        prims.append(Cone("st" + sd, "gill." + sd, v3(sx * 0.12, 0.84, 0.08), v3(sx * 0.24, 0.84, 0.11), 0.06, 0.04, k=0.03))
    return Shape(prims)


def parts():
    return {"crystal": (crystal_shape(), 420, 1, "glow"), "fin": (fin_shape(), 80, 1, "glow"),
            "tailskin": (tail_shape(), 130, 0, "skin"), "collar": (collar_shape(), 70, 0, "skin")}


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None)}
    for sd, sx in SIDES:
        b["gill." + sd] = ((sx * 0.14, 0.84, 0.09), (sx * 0.4, 0.9, 0.16), "root")
    parent = "root"
    for i in range(4):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL[i]), tuple(TAIL[i + 1]), parent)
        parent = n
    return b


def idle(t):
    """The fans breathe open and shut, the tail paddles the air."""
    br = math.sin(math.tau * t)
    p = {"gill.L": (0, 0.05 * br, 0.05 * br), "gill.R": (0, -0.05 * br, -0.05 * br)}
    for i in range(4):
        p["tail%d" % (i + 1)] = (0.02 * math.sin(math.tau * (t - i * 0.1)), 0.09 * math.sin(math.tau * (t - i * 0.14)), 0)
    return p


CLIPS = {"idle": (3.0, True, idle)}


def paint_piece(name, p, n, prims):
    if name == "skin":
        return sp.paint_body(p + np.array([0, 0.2, 0.3]), n)
    return np.tile(sp.hexc("7ff3ff"), (len(p), 1))
