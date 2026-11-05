"""Rimeshrew, a tiny shrew furred with hoarfrost: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #12), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.92
HEAD_C = v3(0, 0.27, -0.2)
HEAD_R = v3(0.155, 0.14, 0.15)
EYE_C = v3(0.078, 0.302, -0.31)
EYE_R = v3(0.043, 0.047, 0.028)
EYE_YAW = 0.5
GLOW_PIECES = ()
LIT_PIECES = ("frost",)
BERRY_C = v3(0, 0.05, -0.5)
NOSE_C = v3(0, 0.235, -0.445)
FACE = {"mouth_w": 0.042, "mouth_y": 0.205, "mouth_z": -0.36, "cat_mouth": True, "brow_x": 0.075, "brow_up": 0.02,
        "brow_k": 0.75, "fang_k": 0.0}
TAIL_PTS = [v3(0, 0.2, 0.24), v3(0, 0.19, 0.33), v3(0, 0.2, 0.42), v3(0, 0.235, 0.5), v3(0, 0.285, 0.56),
            v3(0, 0.345, 0.59)]
TAIL_R = (0.034, 0.028, 0.022, 0.017, 0.013, 0.01)
# frost plumes down the spine: (z, height, half-spread, bone)
PLUMES = [(-0.12, 0.09, 0.0, "spine"), (-0.05, 0.13, 0.045, "spine"), (0.03, 0.155, 0.05, "spine"),
          (0.11, 0.14, 0.05, "hips"), (0.19, 0.11, 0.04, "hips"), (0.25, 0.075, 0.0, "hips")]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def back_y(z):
    """The top of the back at z (m)."""
    return 0.355 - 0.5 * (z - 0.03) ** 2


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.215, 0.1), v3(0.15, 0.14, 0.2), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.22, -0.04), v3(0.14, 0.14, 0.14), k=0.05),
        Cone("neck", "neck", v3(0, 0.235, -0.06), v3(0, 0.255, -0.15), 0.12, 0.125, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Cone("snout", "head", v3(0, 0.255, -0.27), NOSE_C + v3(0, 0.004, 0.018), 0.075, 0.022, k=0.045),
        Ellipsoid("nose", "head", NOSE_C, v3(0.024, 0.02, 0.02), k=0.006),
    ]
    for sd, sx in SIDES:
        c = v3(sx * 0.105, 0.375, -0.15)
        n = v3(sx * 0.45, 0.2, -1.0)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, c, v3(0.056, 0.058, 0.018), rot=frame(n, v3(0, 1, 0)), k=0.012))
        p.append(Ellipsoid("earhole" + sd, "ear1." + sd, c + n / np.linalg.norm(n) * 0.016, v3(0.036, 0.04, 0.012),
                           rot=frame(n, v3(0, 1, 0)), k=0.008, sub=True))
        for leg, z, par in (("f", -0.08, "fleg"), ("h", 0.2, "hleg")):
            top = v3(sx * 0.1, 0.15, z)
            knee = v3(sx * 0.11, 0.085, z - 0.008)
            ankle = v3(sx * 0.115, 0.028, z - 0.012)
            r = 0.04 if leg == "f" else 0.046
            p.append(Cone(leg + "leg1" + sd, "%s1.%s" % (par, sd), top, knee, r, r * 0.75, k=0.025))
            p.append(Cone(leg + "leg2" + sd, "%s2.%s" % (par, sd), knee, ankle, r * 0.75, r * 0.6, k=0.01))
            paw = "%spaw.%s" % (leg, sd)
            p.append(Ellipsoid(leg + "paw" + sd, paw, ankle + v3(0, -0.008, -0.022), v3(0.032, 0.018, 0.042), k=0.01))
    return p


def tail_prims():
    out = []
    for i in range(len(TAIL_PTS) - 1):
        out.append(Cone("seg%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], TAIL_R[i], TAIL_R[i + 1],
                        k=0.012))
    return out


def plume(name, bone, root, h, lean):
    """A frost feather: a flat blade swept back off the spine, fat in the middle, a sharp tip."""
    tip = root + v3(lean, h, 0.06)
    mid = root + (tip - root) * 0.45
    side = v3(1, 0, 0) if lean == 0 else v3(0.0, 0.0, 1.0)
    flat = {"flat": 0.32, "flat_axis": np.cross(tip - root, side) if lean else v3(1, 0, 0)}
    return [Cone(name + "a", bone, root, mid, 0.012, 0.03, k=0, **flat),
            Cone(name + "b", bone, mid, tip, 0.03, 0.003, k=0.004, **flat)]


def frost_prims():
    out = []
    for i, (z, h, spread, bone) in enumerate(PLUMES):
        root = v3(0, back_y(z) - 0.03, z)
        out += plume("p%d" % i, bone, root, h, 0.0)
        if spread:
            for sx in (-1.0, 1.0):
                out += plume("p%d%d" % (i, sx > 0), bone, root + v3(sx * 0.03, -0.01, 0.02), h * 0.75, sx * spread)
    tip = TAIL_PTS[-1]
    out += plume("tail", "tail5", tip - v3(0, 0.01, 0.01), 0.05, 0.0)
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2300),
        "tailskin": (Shape(tail_prims()), 0.003, 210),
        "frost": (Shape(frost_prims()), 0.0025, 460),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.215, -0.42)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.05, 0.39, -0.24), (0.1, 0.5, -0.3), 0.028), "fang": ((0.022, 0.2, -0.37), (0.025, 0.165, -0.375), 0.011),
    "antenna": ((0.04, 0.4, -0.25), (0.09, 0.55, -0.33), 0.01), "brow": ((0.012, 0.36, -0.31), (0.1, 0.365, -0.275), 0.015),
    "head_top": (0, 0.4, -0.21), "fang_at": (0, 0.21, -0.36), "brow_at": (0, 0.35, -0.3), "third_eye": (0, 0.36, -0.31),
    "back": ((0, 0.33, -0.1), (0, 0.35, 0.04), (0, 0.32, 0.2)), "back_at": (0, 0.34, 0.04), "plates": (0, 0.34, -0.02),
    "plate_r": (0.11, 0.032, 0.08), "shell_c": (0, 0.215, 0.08), "shell_r": (0.165, 0.155, 0.06), "tail_bone": "tail4",
    "club_at": tuple(TAIL_PTS[4]), "club_dir": tuple(TAIL_PTS[5] - TAIL_PTS[3]), "club_r": 0.05,
    "spots": ((0.145, 0.22, 0.0, 0.02), (0.15, 0.21, 0.09, 0.018), (0.14, 0.19, 0.17, 0.018)), "spots_at": (0, 0.21, 0.08),
    "wing": ((0.11, 0.3, 0.0), (0.3, 0.4, 0.1), (0.26, 0.36, 0.19)), "wing_at": (0, 0.3, 0.02),
    "fin": ((0.14, 0.22, 0.14), (0.2, 0.32, 0.24)), "fin_at": (0, 0.22, 0.14), "crest": (0.4, -0.24, 0.05, 0.06),
    "crest_at": (0, 0.4, -0.2),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
FUR = hexc("9fb6c8")
FUR_LIGHT = hexc("c8d8e6")
FUR_DARK = hexc("6f879c")
BELLY = hexc("f4fbff")
EAR_IN = hexc("f2c4d0")
BLUSH = hexc("ff9cb4")
NOSE = hexc("f08aa6")
FROST = hexc("8cecff")
FROST_TIP = hexc("ffffff")
FROST_DEEP = hexc("3fc4ec")
LILAC = hexc("7f93a6")     # brows
LID = FUR_LIGHT
INK = hexc("2a3644")
MOUTH_DARK = hexc("6a2a3e")
TONGUE = hexc("f08aa8")
IRIS = hexc("4fb0e0")
IRIS_DEEP = hexc("12304e")
SHELL_A = hexc("e6f6ff")
SHELL_B = hexc("9fd6ea")
SHELL_C = hexc("5a8aa8")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    grain = value_noise(p * np.array([90, 30, 30]))
    col = mixc(FUR_DARK, FUR, sat(n[:, 1] * 0.55 + 0.6 + (grain - 0.5) * 0.4))
    col = mixc(col, FUR_LIGHT, sat(n[:, 1] - 0.3) * 0.5)
    # hoarfrost: white flecks on the back and the crown
    frost = sat((value_noise(p * 60) - 0.55) / 0.2) * sat((y - 0.3) / 0.05)
    col = mixc(col, FUR_LIGHT, frost * 0.5)
    # white chin, throat and belly
    under = edge(0.14 - y - np.abs(x) * 0.25, 0.012)
    bib = edge(0.055 + (0.24 - y) * 0.3 - np.abs(x), 0.012) * edge(0.245 - y, 0.012) * edge(-0.04 - z, 0.03)
    col = mixc(col, BELLY, sat(under + bib))
    for sd in "LR":
        col = mixc(col, EAR_IN, edge(0.004 - prim["earhole" + sd].d(p), 0.003) * (prim["ear" + sd].d(p) < 0.02))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.11, 0.235, 0])) / np.array([0.04, 0.026, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.2) * 0.75)
    col = mixc(col, NOSE, edge(0.004 - prim["nose"].d(p), 0.002))
    return col


def paint_frost(q, n):
    """Ice feathers: cyan at the root, clearing to white at the tips, a little sparkle."""
    up = sat((q[:, 1] - 0.31) / 0.1)
    col = mixc(FROST_DEEP, FROST, sat(up * 1.6))
    col = mixc(col, FROST_TIP, sat(up * 2 - 0.9) + sat((value_noise(q * 140) - 0.8) / 0.05) * 0.5)
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name in ("body", "tailskin"):
        return paint_body(q, nn, prim)
    if pc.name == "frost":
        return paint_frost(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(FROST, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
