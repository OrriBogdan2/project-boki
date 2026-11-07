"""The Spore Fusion: a shaggy cloak of Mycroll's fur over the shoulders, toadstools growing out of it and swaying,
one big cap high on the back. Torso coordinates as vespyx_fusion.py."""
import math
import random

import numpy as np

import mycroll as sp
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3

SIDES = sp.SIDES
HARD = ("stalks", "caps")
# base, direction, stalk, cap radius, sway group
CAPS = (((-0.27, 0.90, 0.02), (-0.7, 0.7, 0.1), 0.17, 0.15, 0), ((0.27, 0.90, 0.02), (0.7, 0.72, 0.1), 0.18, 0.16, 1),
        ((0.0, 0.86, 0.17), (0.0, 0.9, 0.42), 0.46, 0.235, 2), ((-0.17, 0.72, 0.2), (-0.55, 0.3, 0.8), 0.13, 0.11, 0),
        ((0.17, 0.72, 0.2), (0.55, 0.3, 0.8), 0.13, 0.115, 1), ((-0.14, 0.97, 0.13), (-0.3, 0.9, 0.3), 0.24, 0.1, 2),
        ((0.15, 0.97, 0.12), (0.3, 0.9, 0.3), 0.26, 0.11, 2))


def unit(d):
    return np.asarray(d, float) / np.linalg.norm(d)


def cloak_shape():
    prims = [Ellipsoid("c", "cloak", v3(0, 0.84, 0.05), v3(0.3, 0.13, 0.24), k=0)]
    rng = random.Random(77)
    for i in range(22):
        a = rng.uniform(-0.5, math.pi + 0.5)
        at = v3(math.cos(a) * 0.26, 0.82 + rng.uniform(-0.03, 0.05), 0.05 + math.sin(a) * 0.19)
        tip = at + v3(math.cos(a) * 0.15, -0.14 - rng.uniform(0, 0.1), math.sin(a) * 0.15)
        prims.append(Cone("t%d" % i, "cloak", at, tip, 0.07, 0.005, k=0.03))
    return Shape(prims)


def stalk_shape():
    return Shape([Cone("s%d" % i, "cap%d" % g, v3(*b), v3(*b) + unit(d) * h, r * 0.34, r * 0.22, k=0)
                  for i, (b, d, h, r, g) in enumerate(CAPS)])


def cap_shape():
    out = []
    for i, (b, d, h, r, g) in enumerate(CAPS):
        n = unit(d)
        out.append(Ellipsoid("c%d" % i, "cap%d" % g, v3(*b) + n * (h + r * 0.12), v3(r, r, r * 0.62), rot=frame(n, v3(1, 0.1, 0)), k=0))
    return Shape(out)


def parts():
    return {"cloak": (cloak_shape(), 300, 0, "fur"), "stalks": (stalk_shape(), 80, 0, "stalk"),
            "caps": (cap_shape(), 280, 2, "cap")}


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None), "cloak": ((0, 0.84, 0.05), (0, 0.98, 0.05), "root")}
    for i, x in enumerate((-0.25, 0.25, 0.0)):
        b["cap%d" % i] = ((x, 0.9, 0.08), (x, 1.05, 0.08), "cloak")
    return b


def idle(t):
    """The toadstools nod, each cluster a beat behind the last."""
    p = {}
    for i in range(3):
        ph = math.tau * (t + i * 0.27)
        p["cap%d" % i] = (0.05 * math.sin(ph), 0, 0.05 * math.sin(ph + 1.2))
    return p


CLIPS = {"idle": (3.0, True, idle)}


class _Pc:
    def __init__(self, shape):
        self.shape = shape


def paint_piece(name, p, n, prims):
    if name == "stalk":
        return np.tile(sp.STALK, (len(p), 1))
    if name == "cap":
        return sp.paint_caps(p, n, _Pc(Shape(prims)))
    streak = sp.value_noise(p * np.array([30, 12, 30]))
    return sp.mixc(sp.mixc(sp.FUR_DARK, sp.FUR, sp.sat(streak * 2.2 - 0.2)), sp.FUR_LIGHT, sp.sat(n[:, 1]) * 0.5)
