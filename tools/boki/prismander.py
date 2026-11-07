"""Prismander (puddlet), an axolotl whose frills grew into living crystal: shapes and coat. Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import mixc, sat, edge, hexc, paint_shell, tool_colour
from vespyx_sides import SIDES

SCALE = 0.92
HEAD_C = v3(0, 0.31, -0.24)
HEAD_R = v3(0.262, 0.165, 0.205)
EYE_C = v3(0.150, 0.352, -0.362)
EYE_R = v3(0.062, 0.066, 0.040)
EYE_YAW = 0.5
GLOW_PIECES = ("gills", "shards", "tail_fin")
BERRY_C = v3(0, 0.05, -0.52)
FACE = {"mouth_w": 0.135, "mouth_y": 0.262, "mouth_z": -0.40, "cat_mouth": False, "brow_x": 0.15, "brow_up": 0.026,
        "brow_k": 0.8, "fang_k": 0.0}
TAIL_PTS = [v3(0, 0.215, 0.33), v3(0, 0.225, 0.46), v3(0, 0.245, 0.59), v3(0, 0.275, 0.72), v3(0, 0.32, 0.84),
            v3(0, 0.375, 0.94)]
TAIL_R = [(0.105, 0.105), (0.09, 0.095), (0.07, 0.08), (0.05, 0.062), (0.03, 0.044)]
GILLS = (((0.205, 0.415, -0.21), (0.39, 0.62, -0.14)), ((0.245, 0.345, -0.19), (0.47, 0.47, -0.12)),
         ((0.25, 0.275, -0.18), (0.44, 0.285, -0.12)))


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.215, 0.14), v3(0.135, 0.118, 0.25), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.215, -0.05), v3(0.135, 0.125, 0.15), k=0.05),
        Cone("neck", "neck", v3(0, 0.22, -0.08), v3(0, 0.27, -0.16), 0.12, 0.13, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("jaw", "head", v3(0, 0.255, -0.27), v3(0.215, 0.105, 0.165), k=0.05),
    ]
    for sd, sx in SIDES:
        for i, (a, _) in enumerate(GILLS):
            a2 = v3(a[0] * sx * 0.82, a[1] * 0.97, a[2] - 0.01)
            b = v3(a[0] * sx * 1.12, a[1] + (0.03 if i == 0 else 0.0), a[2] + 0.012)
            p.append(Cone("stalk%s%d" % (sd, i), "ear1." + sd, a2, b, 0.04, 0.016, k=0.018))
        hip = v3(sx * 0.125, 0.17, -0.095)
        knee = v3(sx * 0.178, 0.11, -0.115)
        ankle = v3(sx * 0.205, 0.035, -0.13)
        p.append(Cone("fleg1" + sd, "fleg1." + sd, hip, knee, 0.05, 0.036, k=0.03))
        p.append(Cone("fleg2" + sd, "fleg2." + sd, knee, ankle, 0.036, 0.03, k=0.012))
        hip = v3(sx * 0.125, 0.17, 0.27)
        knee = v3(sx * 0.178, 0.11, 0.285)
        ankle2 = v3(sx * 0.205, 0.035, 0.30)
        p.append(Ellipsoid("haunch" + sd, "hleg1." + sd, v3(sx * 0.125, 0.175, 0.275), v3(0.056, 0.07, 0.08), k=0.03))
        p.append(Cone("hleg2" + sd, "hleg2." + sd, knee, ankle2, 0.038, 0.03, k=0.014))
        for leg, a, z in (("fpaw", ankle, -1), ("hpaw", ankle2, 1)):
            p.append(Ellipsoid(leg + sd, leg + "." + sd, a + v3(sx * 0.008, -0.012, -0.02), v3(0.042, 0.02, 0.046), k=0.012))
            for j, (dx, dz) in enumerate(((0.05, -0.052), (0.0, -0.075), (-0.042, -0.058))):
                tip = a + v3(sx * (dx + 0.01), -0.02, dz - 0.012)
                p.append(Cone("%sf%s%d" % (leg, sd, j), leg + "." + sd, a + v3(0, -0.014, -0.02), tip, 0.016, 0.014, k=0.008))
    return p


def tail_prims():
    out = []
    for i, (rx, ry) in enumerate(TAIL_R):
        a, b = TAIL_PTS[i], TAIL_PTS[i + 1]
        d = b - a
        out.append(Ellipsoid("seg%d" % i, "tail%d" % (i + 1), (a + b) * 0.5, v3(rx * 0.62, ry, np.linalg.norm(d) * 0.8),
                             rot=frame(d, v3(1, 0, 0)), k=0.03))
    return out


def shard(name, bone, a, b, r, flat=1.0, axis=None):
    """A crystal: narrow at the root, widest two thirds out, a sharp point."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    m = a + (b - a) * 0.66
    extra = {} if flat == 1.0 else {"flat": flat, "flat_axis": axis}
    return [Cone(name + "a", bone, a, m, r * 0.42, r, k=0, **extra), Cone(name + "b", bone, m, b, r, 0.004, k=0.0, **extra)]


def gill_prims():
    out = []
    for sd, sx in SIDES:
        n = v3(0, 0.1, -1)
        for i, (a, b) in enumerate(GILLS):
            for pr in shard("g%s%d" % (sd, i), "ear1." + sd, v3(a[0] * sx * 1.1, a[1], a[2]),
                            v3(b[0] * sx, b[1], b[2]), (0.058, 0.062, 0.05)[i], 0.7, n):
                out.append(pr)
    return out


def shard_prims():
    out = []
    for i, (z, h, r, bone) in enumerate(((0.0, 0.085, 0.032, "spine"), (0.085, 0.12, 0.042, "spine"),
                                         (0.175, 0.095, 0.034, "hips"), (0.255, 0.065, 0.026, "hips"))):
        y = 0.325 - abs(z - 0.1) * 0.05
        out += shard("s%d" % i, bone, v3(0, y - 0.03, z), v3(0, y + h, z + 0.02), r)
    return out


def fin_prims():
    out = []
    side = v3(1, 0, 0)
    for i in range(1, 5):
        a = TAIL_PTS[i]
        b = TAIL_PTS[i + 1]
        h = 0.075 + 0.012 * i
        out.append(Cone("fin%d" % i, "tail%d" % (i + 1), a + v3(0, 0.03, 0), b + v3(0, h, 0.03), 0.042, 0.03, k=0.02, flat=0.14,
                        flat_axis=side))
        out.append(Cone("finl%d" % i, "tail%d" % (i + 1), a - v3(0, 0.03, 0), b - v3(0, h * 0.7, -0.02), 0.03, 0.022, k=0.02,
                        flat=0.14, flat_axis=side))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2300),
        "tailskin": (Shape(tail_prims()), 0.0035, 240),
        "gills": (Shape(gill_prims()), 0.0035, 330),
        "shards": (Shape(shard_prims()), 0.0035, 110),
        "tail_fin": (Shape(fin_prims()), 0.0035, 110),
    }


AXIS = np.array((0.0, 0.5, -0.866))


def prop_parts():
    out = boki_tools.tools(v3(0, 0.235, -0.44), AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.09, 0.455, -0.26), (0.16, 0.60, -0.31), 0.04), "fang": ((0.07, 0.235, -0.425), (0.075, 0.185, -0.43), 0.016),
    "antenna": ((0.06, 0.46, -0.28), (0.13, 0.64, -0.36), 0.013), "brow": ((0.02, 0.43, -0.385), (0.165, 0.435, -0.345), 0.02),
    "head_top": (0, 0.46, -0.27), "fang_at": (0, 0.24, -0.41), "brow_at": (0, 0.42, -0.38), "third_eye": (0, 0.44, -0.385),
    "back": ((0, 0.30, -0.04), (0, 0.31, 0.05), (0, 0.30, 0.17)), "back_at": (0, 0.31, 0.06), "plates": (0, 0.325, 0.03),
    "plate_r": (0.125, 0.036, 0.09), "shell_c": (0, 0.215, 0.12), "shell_r": (0.152, 0.13, 0.06), "tail_bone": "tail4",
    "club_at": tuple(TAIL_PTS[4]), "club_dir": tuple(TAIL_PTS[5] - TAIL_PTS[3]), "club_r": 0.07,
    "spots": ((0.13, 0.24, -0.02, 0.024), (0.13, 0.25, 0.09, 0.02), (0.128, 0.22, 0.17, 0.022)), "spots_at": (0, 0.23, 0.08),
    "wing": ((0.11, 0.30, 0.0), (0.30, 0.40, 0.10), (0.26, 0.36, 0.19)), "wing_at": (0, 0.30, 0.02),
    "fin": ((0.128, 0.235, 0.14), (0.16, 0.36, 0.26)), "fin_at": (0, 0.23, 0.14), "crest": (0.45, -0.25, 0.05, 0.075),
    "crest_at": (0, 0.45, -0.2),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
PINK = hexc("f4a8d0")
PINK_LIGHT = hexc("ffc6e2")
CREAM = hexc("ffeed2")
LILAC = hexc("ffe6f2")     # brows
INK = hexc("5a2640")
LID = PINK
BLUSH = hexc("ff7f96")
MOUTH_DARK = hexc("8a2c4c")
TONGUE = hexc("ff8aa4")
IRIS = hexc("3fd8c8")
ROSE_LIGHT = hexc("ffd4e8")
ROSE = hexc("e27ab0")
ROSE_DARK = hexc("a84a80")


def paint_body(p, n):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    fine = value_noise(p * np.array([50, 30, 50]))
    col = mixc(PINK, PINK_LIGHT, sat(n[:, 1] * 0.5 + 0.5 + (fine - 0.5) * 0.3))
    # the jaw and the belly: cream, with a soft edge under the long smile
    jaw = edge(0.262 - 0.016 * (1 - (x / 0.135) ** 2) - y, 0.006) * (z < -0.14) * edge(0.235 - np.abs(x), 0.02)
    belly = edge(0.128 - y + np.abs(x) * 0.25, 0.012) * (z >= -0.2) * edge(0.115 - np.abs(x), 0.012)
    col = mixc(col, CREAM, sat(jaw + belly))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.20, 0.285, 0])) / np.array([0.05, 0.03, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.2) * 0.65)
    for sx in (-1.0, 1.0):       # nostrils
        q = np.hypot(x - sx * 0.04, y - 0.335)
        col = mixc(col, INK, edge(0.0065 - q, 0.002) * (z < -0.3) * 0.75)
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name in ("body", "tailskin"):
        return paint_body(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(hexc("7ff3ff"), (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), ROSE_LIGHT, ROSE, ROSE_DARK)
    if pc.name in GLOW_PIECES:
        return np.tile(hexc("7ff3ff"), (len(q), 1))
    return tool_colour(pc.name, q)
