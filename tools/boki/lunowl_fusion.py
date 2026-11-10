"""The Eclipse Fusion's Blender parts: Lunowl's luna-moth wings off the shoulder blades, its feathery antennae over the
head, an owl's ruff at the neck and a crescent moon behind the head. Torso coordinates as vespyx_fusion.py."""
import math

import numpy as np

import lunowl as sp
import lunowl_anim
from boki_sdf import Ellipsoid, Shape, Cone, v3

SIDES = sp.SIDES
WING_AT = v3(0.09, 0.82, 0.16)
WING_K = 1.9
ANTENNA_AT = v3(0.05, 1.08, 0.0)
ANTENNA_K = 1.8
MOON_C = v3(0, 1.14, 0.3)


def ruff_shape():
    """An owl's feather mantle over the shoulders and the back of the neck, open at the front."""
    prims = [Ellipsoid("collar", "root", v3(0, 0.9, 0.08), v3(0.17, 0.07, 0.11), k=0)]
    for i in range(9):
        a = math.pi * (i / 8 * 1.3 - 0.15)
        o = v3(math.cos(a) * 0.15, 0.9, 0.06 + math.sin(a) * 0.1)
        t = v3(math.cos(a) * 0.27, 0.78 + 0.04 * (i % 2), 0.06 + math.sin(a) * 0.22)
        prims.append(Cone("tuft%d" % i, "root", o, t, 0.07, 0.004, k=0.03))
    return Shape(prims)


def moon_shape():
    """A crescent: a thin disc with an offset disc taken out of it."""
    return Shape([Ellipsoid("disc", "root", MOON_C, v3(0.3, 0.3, 0.03), k=0),
                  Ellipsoid("bite", "root", MOON_C + v3(0.1, 0.09, 0), v3(0.27, 0.27, 0.08), k=0.01, sub=True)])


def parts():
    """name -> (Shape, tris, slot, paint name)."""
    return {"wings": (Shape(sp.wing_prims(WING_AT, WING_K)), 720, 0, "wing"),
            "antennae": (Shape(sp.antenna_prims(ANTENNA_AT, ANTENNA_K)), 225, 0, "antenna"),
            "ruff": (ruff_shape(), 225, 0, "ruff"), "moon": (moon_shape(), 90, 1, "glow")}


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None)}
    for sd, sx in SIDES:
        a, _, c = sp.antenna_pts(sx, ANTENNA_AT, ANTENNA_K)
        b["ant." + sd] = (tuple(a), tuple(c), "root")
        b["fwing." + sd] = (tuple(sp.on_wing(sx, 0, 0, WING_AT, WING_K)),
                            tuple(sp.on_wing(sx, 0.12, 0, WING_AT, WING_K)), "root")
        b["hwing." + sd] = (tuple(sp.on_wing(sx, 0, 0.06, WING_AT, WING_K)),
                            tuple(sp.on_wing(sx, 0.07, 0.15, WING_AT, WING_K)), "fwing." + sd)
        pts = sp.streamer_pts(sx, WING_AT, WING_K)
        b["strm1." + sd] = (tuple(pts[0]), tuple(pts[1]), "hwing." + sd)
        b["strm2." + sd] = (tuple(pts[1]), tuple(pts[3]), "strm1." + sd)
    return b


def idle(t):
    """The wings fan slowly, the long tails trailing after them; the antennae bob."""
    p = {}
    lunowl_anim.flap(p, t, 2, 0.06)
    lunowl_anim.feelers(p, t * 2, 0.05)
    return p


CLIPS = {"idle": (3.0, True, idle)}


def paint_piece(name, p, n, prims):
    if name == "wing":
        return sp.paint_wings(p, WING_AT, WING_K)
    if name == "antenna":
        return sp.paint_antennae(p, ANTENNA_AT, ANTENNA_K)
    if name == "ruff":
        return sp.mixc(sp.LAVENDER, sp.LAVENDER_DARK, sp.sat((0.86 - p[:, 1]) / 0.08))
    return np.tile(sp.MOON, (len(p), 1))
