"""Mycroll (burrlet), a hedgehog whose quills are glowing toadstools: shapes and coat. Game axes as vespyx.py."""
import math
import random

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.27, 0.07)
BODY_R = v3(0.262, 0.235, 0.30)
HEAD_C = v3(0, 0.255, -0.20)
HEAD_R = v3(0.195, 0.175, 0.17)
EYE_C = v3(0.098, 0.286, -0.310)
EYE_R = v3(0.056, 0.062, 0.036)
EYE_YAW = 0.42
GLOW_PIECES = ()
LIT_PIECES = ("caps",)
PALE_PIECES = ("stalks", "caps")
BERRY_C = v3(0, 0.05, -0.50)
FACE = {"mouth_w": 0.06, "mouth_y": 0.172, "mouth_z": -0.40, "cat_mouth": True, "brow_x": 0.095, "brow_up": 0.024,
        "brow_k": 0.85, "fang_k": 0.0}
NOSE_C = v3(0, 0.205, -0.405)
TAIL_PTS = [v3(0, 0.20, 0.34), v3(0, 0.205, 0.43), v3(0, 0.25, 0.52)]
# toadstools: direction off the body, stalk length, cap radius, sway group
CAPS = [
    ((-0.42, 0.72, 0.1), 0.12, 0.085, 0), ((0.1, 0.92, 0.06), 0.15, 0.105, 1), ((0.5, 0.74, 0.18), 0.13, 0.09, 2),
    ((-0.08, 0.78, -0.36), 0.05, 0.05, 0), ((0.36, 0.62, -0.28), 0.045, 0.05, 1), ((-0.72, 0.42, -0.02), 0.06, 0.055, 0),
    ((0.72, 0.40, 0.05), 0.065, 0.06, 2), ((-0.3, 0.72, 0.55), 0.07, 0.07, 3), ((0.3, 0.62, 0.62), 0.08, 0.075, 3),
    ((-0.72, 0.3, 0.5), 0.05, 0.052, 3), ((0.78, 0.22, 0.42), 0.05, 0.052, 2), ((0.02, 0.5, 0.8), 0.06, 0.06, 3),
]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def on_body(d, k=1.0):
    n = np.asarray(d, float)
    n = n / np.linalg.norm(n)
    return BODY_C + n * BODY_R * k, n


def body_prims():
    p = [
        Ellipsoid("torso", "hips", BODY_C + v3(0, 0, 0.09), BODY_R * v3(1, 1, 0.68), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.255, -0.05), v3(0.24, 0.215, 0.21), k=0.06),
        Cone("neck", "neck", v3(0, 0.25, -0.05), v3(0, 0.25, -0.16), 0.15, 0.15, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.05),
        Cone("snout", "head", v3(0, 0.235, -0.30), NOSE_C + v3(0, 0.0, 0.02), 0.09, 0.03, k=0.04),
        Ellipsoid("nose", "head", NOSE_C, v3(0.03, 0.023, 0.022), k=0.005),
    ]
    rng = random.Random(4711)
    for i in range(26):
        a = rng.uniform(-math.pi * 0.98, math.pi * 0.98)
        up = rng.uniform(0.05, 1.0)
        d = v3(math.sin(a) * (1 - up * 0.65), up, math.cos(a) * (1 - up * 0.65) + 0.25)
        at, n = on_body(d, 0.93)
        if d[2] < -0.05 or at[1] < 0.14:
            continue
        tip = at + n * 0.075 + v3(0, 0.0, 0.05)
        p.append(Cone("spine%d" % i, "spine" if at[2] < 0.06 else "hips", at, tip, 0.05, 0.004, k=0.018))
    for sd, sx in SIDES:
        c = v3(sx * 0.158, 0.385, -0.14)
        n = v3(sx * 0.35, 0.15, -1.0)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, c, v3(0.062, 0.066, 0.024), rot=frame(n, v3(0, 1, 0)), k=0.012))
        p.append(Ellipsoid("earhole" + sd, "ear1." + sd, c + n / np.linalg.norm(n) * 0.022, v3(0.038, 0.042, 0.016),
                           rot=frame(n, v3(0, 1, 0)), k=0.008, sub=True))
        for leg, z, h in (("f", -0.09, 0.16), ("h", 0.21, 0.16)):
            top = v3(sx * 0.14, h, z)
            knee = v3(sx * 0.145, 0.085, z - 0.004)
            ankle = v3(sx * 0.147, 0.032, z - 0.008)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (leg, sd), top, knee, 0.058, 0.05, k=0.03))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (leg, sd), knee, ankle, 0.05, 0.046, k=0.012))
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (leg, sd), v3(sx * 0.149, 0.026, z - 0.03),
                               v3(0.05, 0.028, 0.064), k=0.016))
    p.append(Cone("tail0", "tail1", TAIL_PTS[0], TAIL_PTS[1], 0.05, 0.036, k=0.03))
    p.append(Cone("tail1", "tail2", TAIL_PTS[1], TAIL_PTS[2], 0.036, 0.024, k=0.012))
    return p


def cap_at(d, stalk):
    at, n = on_body(d, 0.98)
    return at, n, at + n * stalk


def stalk_prims():
    out = []
    for i, (d, stalk, r, grp) in enumerate(CAPS):
        at, n, top = cap_at(d, stalk)
        out.append(Cone("st%d" % i, "cap%d" % grp, at - n * 0.02, top, r * 0.42, r * 0.28, k=0))
    a = TAIL_PTS[2]
    out.append(Cone("stt", "tail2", a, a + v3(0, 0.07, 0.03), 0.03, 0.022, k=0))
    return out


def cap_prims():
    out = []
    for i, (d, stalk, r, grp) in enumerate(CAPS):
        _, n, top = cap_at(d, stalk)
        out.append(Ellipsoid("cap%d" % i, "cap%d" % grp, top + n * r * 0.12, v3(r, r, r * 0.62), rot=frame(n, v3(1, 0.1, 0)),
                             k=0))
    a = TAIL_PTS[2] + v3(0, 0.08, 0.035)
    n = v3(0, 1, 0.45)
    out.append(Ellipsoid("capt", "tail2", a, v3(0.09, 0.09, 0.055), rot=frame(n, v3(1, 0.1, 0)), k=0))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2200),
        "stalks": (Shape(stalk_prims()), 0.0035, 170),
        "caps": (Shape(cap_prims()), 0.0035, 500),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.165, -0.40)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.07, 0.42, -0.22), (0.14, 0.56, -0.28), 0.036), "fang": ((0.034, 0.165, -0.385), (0.038, 0.125, -0.39), 0.014),
    "antenna": ((0.05, 0.42, -0.24), (0.11, 0.58, -0.32), 0.012), "brow": ((0.015, 0.36, -0.325), (0.125, 0.365, -0.285), 0.018),
    "head_top": (0, 0.41, -0.22), "fang_at": (0, 0.17, -0.38), "brow_at": (0, 0.35, -0.32), "third_eye": (0, 0.365, -0.335),
    "back": ((0, 0.50, -0.06), (0, 0.51, 0.08), (0, 0.46, 0.24)), "back_at": (0, 0.49, 0.06), "plates": (0, 0.495, 0.0),
    "plate_r": (0.17, 0.05, 0.11), "shell_c": (0, 0.255, 0.07), "shell_r": (0.276, 0.25, 0.07), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.06,
    "spots": ((0.255, 0.22, 0.0, 0.024), (0.262, 0.2, 0.1, 0.02), (0.235, 0.17, 0.19, 0.022)), "spots_at": (0, 0.22, 0.08),
    "wing": ((0.2, 0.40, 0.02), (0.40, 0.50, 0.1), (0.36, 0.45, 0.2)), "wing_at": (0, 0.42, 0.02),
    "fin": ((0.24, 0.2, 0.2), (0.33, 0.28, 0.32)), "fin_at": (0, 0.22, 0.2), "crest": (0.40, -0.22, 0.05, 0.06),
    "crest_at": (0, 0.41, -0.18),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
FUR = hexc("8a5c42")
FUR_LIGHT = hexc("b08258")
FUR_DARK = hexc("5e3a2a")
CREAM = hexc("f6e6c8")
EAR_IN = hexc("c89678")
BLUSH = hexc("ff8f96")
NOSE = hexc("3a241c")
STALK = hexc("f2e4cc")
CAP = hexc("86ecd2")
CAP_DARK = hexc("3fc4a8")
CAP_SPOT = hexc("e8fff0")
CAP_UNDER = hexc("d8f6dc")
LILAC = hexc("c8a07c")     # brows
LID = CREAM * 0.9
INK = hexc("3a2418")
MOUTH_DARK = hexc("6e2a2a")
TONGUE = hexc("f08a8a")
IRIS = hexc("3fc8b4")
SHELL_A = hexc("c49a70")
SHELL_B = hexc("8a5c42")
SHELL_C = hexc("5e3a2a")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    jag = (value_noise(p * np.array([60, 60, 22])) - 0.5) * 0.05
    col = mixc(CREAM, CREAM * 0.97, value_noise(p * 40))
    # the brown cloak: a widow's peak on the brow, back behind the ears, low along the flanks
    yb = np.interp(z, [-0.42, -0.3, -0.2, -0.05, 0.15, 0.45], [0.62, 0.40, 0.33, 0.20, 0.145, 0.12])
    yb = yb + ax * np.interp(z, [-0.4, -0.15, 0.1], [0.9, 0.55, 0.0])
    fur = edge(y - yb + jag, 0.005)
    streak = value_noise(p * np.array([90, 22, 40]))
    brown = mixc(mixc(FUR_DARK, FUR, sat(streak * 2.2 - 0.2)), FUR_LIGHT, sat(n[:, 1] - 0.2) * 0.55)
    col = mixc(col, brown, fur)
    for sd in "LR":
        hole = prim["earhole" + sd].d(p)
        ear = prim["ear" + sd].d(p) < 0.03
        col = mixc(col, FUR_LIGHT * 0.95, ear.astype(float))
        col = mixc(col, EAR_IN, edge(0.005 - hole, 0.003) * ear)
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.13, 0.215, 0])) / np.array([0.05, 0.03, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.15) * 0.7)
    col = mixc(col, NOSE, edge(0.003 - prim["nose"].d(p), 0.0015))
    return col


def paint_caps(q, n, pc):
    """Mint domes with pale spots, a paler gilled underside."""
    col = np.zeros((len(q), 3))
    ds = np.stack([pr.d(q) for pr in pc.shape.prims], -1)
    own = ds.argmin(1)
    facing = np.zeros(len(q))
    for i, pr in enumerate(pc.shape.prims):
        m = own == i
        if m.any():
            facing[m] = n[m] @ (pr.rot[2])
    spot = sat((value_noise(q * 34) - 0.62) / 0.05)
    col = mixc(np.tile(CAP_DARK, (len(q), 1)), CAP, sat(facing * 1.2 + 0.2))
    col = mixc(col, CAP_SPOT, spot * sat(facing * 3))
    return mixc(col, CAP_UNDER, sat(-facing * 3))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "stalks":
        return np.tile(STALK, (len(q), 1)) * 1.0
    if pc.name == "caps":
        return paint_caps(q, nn, pc)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(CAP, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
