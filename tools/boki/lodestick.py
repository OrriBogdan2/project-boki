"""Lodestick (lodestick), a stick insect of dark lodestone twigs: shapes and coat. Game axes as vespyx.py. Twig
segments meet at blocky lodestone knuckles, a violet glow in every seam; iron filings bristle on its legs."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Prim, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.33, -0.36)
HEAD_R = v3(0.152, 0.135, 0.13)
EYE_YAW = 0.42
EYE_R = v3(0.04, 0.044, 0.027)
GLOW_PIECES = ("seams", "beads", "lode")
BERRY_C = v3(0, 0.045, -0.53)
FACE = {"mouth_w": 0.04, "mouth_y": 0.272, "mouth_z": -0.47, "cat_mouth": True, "brow_x": 0.07, "brow_up": 0.016,
        "brow_k": 0.72, "fang_k": 0.0}
# the twig body, head to tail: (bone, from, to, radius from, radius to)
TWIGS = (("neck", v3(0, 0.215, -0.2), v3(0, 0.27, -0.29), 0.05, 0.054),
         ("spine", v3(0, 0.205, -0.15), v3(0, 0.2, -0.01), 0.054, 0.052),
         ("hips", v3(0, 0.2, 0.03), v3(0, 0.205, 0.14), 0.052, 0.05),
         ("tail1", v3(0, 0.205, 0.18), v3(0, 0.215, 0.3), 0.047, 0.042),
         ("tail2", v3(0, 0.22, 0.34), v3(0, 0.24, 0.44), 0.04, 0.034),
         ("tail3", v3(0, 0.248, 0.475), v3(0, 0.29, 0.55), 0.03, 0.016))
# the lodestone knuckles between them: (bone, centre, half size)
KNUCKLES = (("spine", v3(0, 0.21, -0.175), v3(0.066, 0.058, 0.04)),
            ("hips", v3(0, 0.2, 0.01), v3(0.07, 0.06, 0.042)),
            ("tail1", v3(0, 0.205, 0.16), v3(0.064, 0.056, 0.038)),
            ("tail2", v3(0, 0.218, 0.32), v3(0.055, 0.05, 0.034)),
            ("tail3", v3(0, 0.243, 0.458), v3(0.044, 0.04, 0.03)))
# legs: (bone prefix, hip, knee, foot)
LEGS = (("fleg", v3(0.05, 0.19, -0.13), v3(0.17, 0.27, -0.3), v3(0.2, 0.012, -0.46)),
        ("mleg", v3(0.056, 0.19, 0.01), v3(0.24, 0.25, 0.0), v3(0.36, 0.012, 0.04)),
        ("hleg", v3(0.05, 0.19, 0.13), v3(0.2, 0.26, 0.26), v3(0.3, 0.012, 0.44)))
CROWN_C = v3(0, 0.455, -0.37)       # a lodestone set in its brow
ANTENNA = (v3(0.045, 0.43, -0.42), v3(0.11, 0.56, -0.5), v3(0.2, 0.64, -0.46))
GRIP = v3(0, 0.27, -0.5)
AXIS = np.array((0.0, 0.5, -0.866))


class Box(Prim):
    """A rounded box: half size `b`, edges rounded by `r`, turned by the rows of `rot`."""

    def __init__(self, name, bone, c, b, r=0.012, rot=None, k=0.02, sub=False):
        super().__init__(name, bone, k, sub)
        self.c, self.b, self.r = np.asarray(c, float), np.asarray(b, float), r
        self.rot = np.eye(3) if rot is None else rot
        m = self.b.max() * 1.8 + 0.08
        self.lo, self.hi = self.c - m, self.c + m

    def d(self, p):
        q = np.abs((p - self.c) @ self.rot.T) - (self.b - self.r)
        outside = np.linalg.norm(np.maximum(q, 0.0), axis=-1)
        return outside + np.minimum(q.max(-1), 0.0) - self.r


def _eye_dir(sx):
    return v3(sx * math.sin(EYE_YAW), 0.12, -math.cos(EYE_YAW))


def _on_head(d, depth):
    d = d / np.linalg.norm(d)
    return HEAD_C + d * depth / np.linalg.norm(d / HEAD_R)


EYE_C = _on_head(_eye_dir(1.0), 0.86)


def eye_frame(sx):
    fr = frame(_eye_dir(sx), v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def mir(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def leg_pts(leg, sx):
    _, hip, knee, foot = leg
    return mir(hip, sx), mir(knee, sx), mir(foot, sx)


def twig_frame(a, b):
    return frame(b - a, v3(0, 1, 0)) if abs((b - a)[1]) < 0.9 * np.linalg.norm(b - a) else frame(b - a, v3(0, 0, 1))


def body_prims():
    p = [Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.03),
         Ellipsoid("snout", "head", v3(0, 0.29, -0.42), v3(0.1, 0.07, 0.08), k=0.04)]
    for bone, a, b, ra, rb in TWIGS:
        p.append(Cone("twig_" + bone, bone, a, b, ra, rb, k=0.02))
    for sd, sx in SIDES:
        a, m, c = (mir(q, sx) for q in ANTENNA)
        p.append(Cone("ant0" + sd, "ear1." + sd, a, m, 0.016, 0.012, k=0.015))
        p.append(Cone("ant1" + sd, "ear1." + sd, m, c, 0.012, 0.009, k=0.008))
        for leg in LEGS:
            hip, knee, foot = leg_pts(leg, sx)
            pre = leg[0]
            p.append(Cone(pre + "1" + sd, pre + "1." + sd, hip, knee, 0.026, 0.022, k=0.015))
            ankle = foot + (knee - foot) * 0.16
            p.append(Cone(pre + "2" + sd, pre + "2." + sd, knee, ankle, 0.021, 0.017, k=0.01))
            p.append(Cone(pre + "f" + sd, pre.replace("leg", "paw") + "." + sd, ankle, foot + v3(sx * 0.012, 0, -0.03),
                          0.016, 0.011, k=0.008))
    return p


def knuckle_prims():
    p = [Box("k%d" % i, bone, c, b, r=0.014, k=0.0) for i, (bone, c, b) in enumerate(KNUCKLES)]
    p.append(Box("crown", "head", CROWN_C, v3(0.05, 0.03, 0.045), r=0.012, k=0.0))
    for sd, sx in SIDES:
        for leg in LEGS:
            hip, knee, foot = leg_pts(leg, sx)
            rot = twig_frame(hip, knee)
            p.append(Box("knee%s%s" % (leg[0], sd), leg[0] + "2." + sd, knee, v3(0.032, 0.032, 0.03), r=0.011, rot=rot,
                         k=0.0))
    return p


def seam_prims():
    """A thin violet disc on each face of a knuckle: the glow where twig meets stone."""
    out = []
    for i, (bone, c, b) in enumerate(KNUCKLES):
        for j, sz in enumerate((-1.0, 1.0)):
            out.append(Ellipsoid("s%d%d" % (i, j), bone, c + v3(0, 0, sz * (b[2] + 0.004)),
                                 v3(b[0] * 0.97, b[1] * 0.97, 0.011), k=0))
    for sd, sx in SIDES:
        for leg in LEGS:
            hip, knee, foot = leg_pts(leg, sx)
            for j, other in enumerate((hip, foot)):
                d = (other - knee) / np.linalg.norm(other - knee)
                out.append(Ellipsoid("s%s%s%d" % (leg[0], sd, j), leg[0] + "2." + sd, knee + d * 0.034,
                                     v3(0.031, 0.031, 0.009), rot=frame(d, v3(0, 0, 1) if abs(d[1]) > 0.9 else v3(0, 1, 0)),
                                     k=0))
    return out


def filing_prims():
    """Iron filings standing up on the shins, as on a magnet: a row out to the side and a row along the top."""
    out = []
    for sd, sx in SIDES:
        for leg in LEGS:
            hip, knee, foot = leg_pts(leg, sx)
            d = foot - knee
            dn = d / np.linalg.norm(d)
            side = np.cross(dn, v3(0, 0, 1) if leg[0] != "mleg" else v3(1, 0, 0))
            side = side / np.linalg.norm(side) * (1 if side[0] * sx > 0 else -1)
            top = np.cross(side, dn)
            top = top if top[1] > 0 else -top
            for j, f in enumerate((0.36, 0.62)):
                a = knee + d * f
                for row, out_dir in (("f", side), ("g", top)):
                    tip = a + out_dir * 0.026 + dn * 0.01
                    out.append(Cone("%s%s%s%d" % (row, leg[0], sd, j), leg[0] + "2." + sd, a, tip, 0.01, 0.003,
                                    k=0.004))
    return out


def bead_prims():
    """A lodestone bead glowing at each feeler's tip."""
    return [Ellipsoid("bead" + sd, "ear1." + sd, mir(ANTENNA[2], sx), v3(0.026, 0.026, 0.026), k=0) for sd, sx in SIDES]


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2300),
        "knuckles": (Shape(knuckle_prims()), 0.003, 420),
        "seams": (Shape(seam_prims()), 0.0022, 240),
        "filings": (Shape(filing_prims()), 0.0022, 230),
        "beads": (Shape(bead_prims()), 0.0025, 30),
    }


def lode_prims():
    """Lodestar: a glowing lodestone held up between the forelegs, shown while it pulls."""
    return [Ellipsoid("lode", "prop_lode", LODE_C, v3(0.075, 0.075, 0.075), k=0)]


LODE_C = v3(0, 0.56, -0.5)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    out["lode"] = (Shape(lode_prims()), 0.003, 40)
    return out


GROWN = {
    "horn": ((0.07, 0.43, -0.35), (0.12, 0.55, -0.4), 0.03), "fang": ((0.04, 0.27, -0.48), (0.042, 0.23, -0.49), 0.013),
    "antenna": ((0.05, 0.45, -0.33), (0.1, 0.6, -0.3), 0.011), "brow": ((0.02, 0.4, -0.48), (0.11, 0.405, -0.45), 0.016),
    "head_top": (0, 0.45, -0.36), "fang_at": (0, 0.27, -0.47), "brow_at": (0, 0.39, -0.47), "third_eye": (0, 0.41, -0.48),
    "back": ((0, 0.255, -0.1), (0, 0.255, 0.06), (0, 0.25, 0.2)), "back_at": (0, 0.255, 0.04), "plates": (0, 0.255, -0.08),
    "plate_r": (0.07, 0.025, 0.07), "shell_c": (0, 0.21, 0.08), "shell_r": (0.08, 0.075, 0.08), "tail_bone": "tail3",
    "club_at": (0, 0.29, 0.55), "club_dir": (0, 0.04, 0.08), "club_r": 0.045,
    "spots": ((0.05, 0.215, -0.08, 0.016), (0.05, 0.21, 0.08, 0.015), (0.045, 0.22, 0.25, 0.014)), "spots_at": (0, 0.21, 0.08),
    "wing": ((0.04, 0.24, -0.04), (0.18, 0.34, 0.12), (0.12, 0.29, 0.22)), "wing_at": (0, 0.24, -0.02),
    "fin": ((0.05, 0.2, 0.2), (0.07, 0.32, 0.3)), "fin_at": (0, 0.2, 0.2), "crest": (0.46, -0.38, 0.04, 0.06),
    "crest_at": (0, 0.45, -0.38),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
BARK = hexc("5e5a7c")
BARK_LIGHT = hexc("8a85a8")
BARK_DARK = hexc("423f5a")
UNDER = hexc("8a86a0")
FACE_LIGHT = hexc("b4b0cc")
STONE_LIGHT = hexc("dcd7f0")
STONE = hexc("7a7598")
STONE_DARK = hexc("3a3850")
IRON = hexc("2a2934")
IRON_LIGHT = hexc("9a98ac")
GLOW = hexc("b48cff")
BLUSH = hexc("e88ab8")
LILAC = hexc("d4cfe6")     # brows
LID = BARK_LIGHT
INK = hexc("15141e")
MOUTH_DARK = hexc("4a1a36")
TONGUE = hexc("e87aa8")
IRIS = hexc("b48cff")
IRIS_DEEP = hexc("3a1f6e")
GROWN_A = hexc("b0abc8")
GROWN_B = hexc("4a4660")
GROWN_C = hexc("1c1b28")


def paint_bark(p, n, prim):
    """Twig bark: long grain along each twig, knots, paler underneath; a pale face round the eyes and mouth."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    grain = value_noise(p * np.array([140, 140, 18]))
    knots = value_noise(p * 22 + 3.0)
    col = mixc(BARK_DARK, BARK, sat(n[:, 1] * 0.5 + 0.7 + (grain - 0.5) * 0.6))
    col = mixc(col, BARK_LIGHT, sat((grain - 0.55) * 3.5) * sat(n[:, 1] + 0.4) * 0.6)
    col = mixc(col, BARK_DARK, sat((knots - 0.78) * 6) * 0.7)
    col = mixc(col, UNDER, sat(-n[:, 1] - 0.2) * 0.65)
    head = edge(0.02 - prim["head"].d(p), 0.01) + edge(0.02 - prim["snout"].d(p), 0.01)
    muzzle = sat(head) * edge(0.395 - y + (np.abs(x) - 0.04) * 0.5, 0.014) * edge(-0.4 - z, 0.03)
    col = mixc(col, FACE_LIGHT, muzzle)
    for sx in (-1.0, 1.0):
        b = (p - np.array([sx * 0.105, 0.3, 0])) / np.array([0.036, 0.022, 1.0])
        col = mixc(col, BLUSH, np.exp(-(b[:, 0] ** 2 + b[:, 1] ** 2) * 1.25) * (z < -0.38) * 0.6)
    return col


def paint_knuckles(q, nn):
    speck = value_noise(q * 160)
    col = paint_shell(q, nn, np.full(len(q), 1.0), STONE_LIGHT, STONE, STONE_DARK)
    return mixc(col, STONE_DARK, sat((speck - 0.7) * 5) * 0.6)


def paint_filings(q):
    speck = value_noise(q * 200)
    return mixc(IRON, IRON_LIGHT, sat((speck - 0.45) * 2.5))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_bark(q, nn, prim)
    if pc.name == "knuckles":
        return paint_knuckles(q, nn)
    if pc.name == "filings":
        return paint_filings(q)
    if pc.name in GLOW_PIECES:
        return np.tile(GLOW, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), GROWN_A, GROWN_B, GROWN_C)
    return tool_colour(pc.name, q)
