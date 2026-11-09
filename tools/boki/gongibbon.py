"""Gongibbon (gibbelle): a knuckle-walking gibbon with a bronze gong on its chest, a gold brow band, bronze knuckle
beads and a tail that ends in a mallet (Echo Chain: the tail strikes the gong).
Its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/gibbelle_turnaround.png), read from
~/meshy/gibbelle/run1 by boki_meshy (raw files stay out of git). The primitives below are a proxy for the skin weights.
The long arms ride the shared four-leg skeleton: fleg is the arm, fpaw the knuckle fist; hleg and hpaw are the legs."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_meshy import Meshy, MeshShape
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

MESHY_DIR = os.path.expanduser("~/meshy/gibbelle/run1")
HEIGHT = 0.66            # the model's height in game metres, before SCALE
SCALE = 0.95
BODY_TRIS = 3600
HEAD_C = v3(0, 0.565, -0.075)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


EYE_C = v3(0.045, 0.562, -0.148)
EYE_R = v3(0.027, 0.028, 0.013)
EYE_YAW = 0.3
GLOW_PIECES = ()
BERRY_C = v3(0, 0.05, -0.3)
FACE = {"mouth_w": 0.034, "mouth_y": 0.503, "mouth_z": -0.182, "cat_mouth": False,
        "brow_x": 0.045, "brow_up": 0.012, "brow_k": 0.55, "fang_k": 0.0}
# limbs, per side (x > 0): shoulder or hip, elbow or knee, wrist or ankle, knuckles or toes
ARM = (v3(0.19, 0.42, 0.03), v3(0.245, 0.25, 0.015), v3(0.26, 0.09, -0.06), v3(0.26, 0.015, -0.1))
LEG = (v3(0.1, 0.21, 0.07), v3(0.115, 0.12, 0.025), v3(0.1, 0.045, 0.08), v3(0.11, 0.012, -0.02))
LIMBS = (("fleg", "fpaw", ARM, (0.055, 0.045, 0.04, 0.05)), ("hleg", "hpaw", LEG, (0.055, 0.045, 0.035, 0.04)))
# the tail: down from the rump, out to its right, up behind the shoulder to the mallet
TAIL_PTS = [v3(0.04, 0.24, 0.16), v3(0.15, 0.19, 0.15), v3(0.23, 0.3, 0.16), v3(0.22, 0.42, 0.14),
            v3(0.205, 0.52, 0.1), v3(0.21, 0.6, 0.1)]
TAIL_N = len(TAIL_PTS) - 1
MALLET_C = v3(0.24, 0.6, 0.11)
EAR = v3(0.095, 0.578, -0.05)
EAR_TIP = v3(0.115, 0.598, -0.05)
GRIP = v3(0, 0.495, -0.2)
AXIS = np.array((0.0, 0.5, -0.866))
# Meshy painted a frown; the Boki face draws a mouth that moves, so the frown takes the muzzle colour above it
PAINTED_MOUTH = (0.5, 0.03)     # its height and half width (m)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.05, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    p = [
        Ellipsoid("rump", "hips", v3(0, 0.26, 0.08), v3(0.15, 0.11, 0.1), k=0.04),
        Ellipsoid("chest", "spine", v3(0, 0.37, 0.03), v3(0.19, 0.11, 0.13), k=0.04),
        Cone("neck", "neck", v3(0, 0.45, 0.0), v3(0, 0.5, -0.04), 0.09, 0.08, k=0.03),
        Ellipsoid("head", "head", HEAD_C, v3(0.1, 0.1, 0.1), k=0.03),
        Ellipsoid("muzzle", "head", v3(0, 0.51, -0.14), v3(0.055, 0.045, 0.045), k=0.02),
    ]
    for sd, sx in SIDES:
        m = v3(sx, 1, 1)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, EAR * m, v3(0.02, 0.025, 0.012), k=0.01))
        for leg, paw, pts, r in LIMBS:
            a, b, c, d = (q * m for q in pts)
            p.append(Cone(leg + "1" + sd, "%s1.%s" % (leg, sd), a, b, r[0], r[1], k=0.02))
            p.append(Cone(leg + "2" + sd, "%s2.%s" % (leg, sd), b, c, r[1], r[2], k=0.015))
            p.append(Cone(paw + sd, "%s.%s" % (paw, sd), c, d, r[2], r[3], k=0.015))
    for i in range(TAIL_N):
        p.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], 0.02, 0.016, k=0.008))
    p.append(Ellipsoid("mallet", "tail%d" % TAIL_N, MALLET_C, v3(0.06, 0.025, 0.04), k=0.01))
    return p


def parts():
    return {"body": (MeshShape(proxy_prims(), MESHY_DIR, HEIGHT), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.05, 0.08, -0.02), hd(0.09, 0.17, 0.0), 0.02),
    "fang": ((0.018, 0.5, -0.178), (0.02, 0.478, -0.18), 0.008),
    "antenna": (hd(0.04, 0.085, -0.025), hd(0.08, 0.185, -0.065), 0.008),
    "brow": ((0.012, 0.6, -0.16), (0.075, 0.605, -0.13), 0.011),
    "head_top": hd(0, 0.1, 0.005), "fang_at": (0, 0.5, -0.178), "brow_at": (0, 0.6, -0.155),
    "third_eye": (0, 0.615, -0.15), "back_at": (0, 0.39, 0.16), "plates": (0, 0.4, 0.15),
    "back": ((0, 0.46, 0.12), (0, 0.39, 0.16), (0, 0.31, 0.17)),
    "plate_r": (0.1, 0.03, 0.08), "shell_c": (0, 0.3, 0.1), "shell_r": (0.15, 0.14, 0.07), "tail_bone": "tail4",
    "club_at": tuple(TAIL_PTS[4]), "club_dir": tuple(TAIL_PTS[5] - TAIL_PTS[3]), "club_r": 0.04,
    "spots": ((0.16, 0.32, 0.06, 0.016), (0.155, 0.26, 0.1, 0.016), (0.14, 0.21, 0.13, 0.014)),
    "spots_at": (0, 0.28, 0.08),
    "wing": ((0.1, 0.44, 0.08), (0.28, 0.54, 0.16), (0.24, 0.5, 0.22)), "wing_at": (0, 0.44, 0.08),
    "fin": ((0.1, 0.24, 0.14), (0.16, 0.3, 0.24)), "fin_at": (0, 0.24, 0.14),
    "crest": (HEAD_C[1] + 0.1, HEAD_C[2] + 0.02, 0.04, 0.05),
    "crest_at": hd(0, 0.1, 0.02),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
GLOW = hexc("ffc54a")      # the gold of the brow band
LILAC = hexc("2a2c3a")     # brows
INK = hexc("101018")
LID = hexc("3a3c4c")
MOUTH_DARK = hexc("3a1a22")
TONGUE = hexc("e87a86")
BLUSH = hexc("b05a6a")
IRIS = hexc("f09a28")
IRIS_DEEP = hexc("5a2006")
BRONZE_A = hexc("e0b060")
BRONZE_B = hexc("a06a2a")
BRONZE_C = hexc("4a3010")
BLUSH_AT = [v3(sx * 0.06, 0.53, -0.14) for sx in (1, -1)]


def paint_body(q, nn):
    model = Meshy.get(MESHY_DIR, HEIGHT)
    col = model.colour(q)
    my, half = PAINTED_MOUTH
    mouth = (sat((0.016 - np.abs(q[:, 1] - my)) / 0.006) * sat((half - np.abs(q[:, 0])) / 0.01)
             * sat((-0.15 - q[:, 2]) / 0.01))
    hit = mouth > 0
    if hit.any():
        col[hit] = mixc(col[hit], model.colour(q[hit] + v3(0, 0.03, 0)), mouth[hit])
    blush = np.zeros(len(q))
    for c in BLUSH_AT:
        blush = np.maximum(blush, sat((0.02 - np.linalg.norm((q - c) * v3(0.8, 1.3, 1), axis=1)) / 0.012))
    return mixc(col, np.tile(BLUSH, (len(q), 1)), 0.5 * blush)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), BRONZE_A, BRONZE_B, BRONZE_C)
    return tool_colour(pc.name, q)
