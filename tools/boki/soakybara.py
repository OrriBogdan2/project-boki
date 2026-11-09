"""Soakybara (lilybara): a barrel capybara carrying a stone-rimmed hot spring on its back, turquoise water and pink
lilies in it, lily pads sprouting at its neck, short tusks under a blunt snout.

Like Zippelith, its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/lilybara_turnaround.png), read
from ~/meshy/lilybara/run1 through boki_scan (the raw files stay out of git). The primitives below are a proxy for the
skin weights and the face; the surface and the coat are the scan's. Game axes as vespyx.py: facing -Z, +Y up.
The pool's floor is the rider's seat (the saddle bone, soakybara_anim.py)."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_scan import MeshShape, Scan
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

MESHY_DIR = os.path.expanduser("~/meshy/lilybara/run1")
HEIGHT = 0.6             # lily pad tips; the pool's rim is at 0.50, its water at 0.46, its floor near ride height
SCALE = 1.0
BODY_TRIS = 3600
HEAD_C = v3(0, 0.385, -0.32)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


def scan():
    return Scan.get(MESHY_DIR, HEIGHT)


EYE_C = v3(0.098, 0.452, -0.318)
EYE_R = v3(0.03, 0.033, 0.016)
EYE_YAW = 0.85           # a capybara's eyes sit high on the sides of its head
GLOW_PIECES = ()
BERRY_C = v3(0, 0.05, -0.56)
FACE = {"mouth_w": 0.05, "mouth_y": 0.322, "mouth_z": -0.455, "cat_mouth": True,
        "brow_x": 0.095, "brow_up": 0.012, "brow_k": 0.6, "fang_k": 0.0}
SADDLE = v3(0, 0.43, 0.13)           # the pool's floor, where a rider sits
POOL_C = v3(0, 0.45, 0.14)
LEG_X = 0.10
LEGS = (("f", -0.07, "spine"), ("h", 0.31, "hips"))
PAD = [(v3(sx * 0.12, 0.47, -0.16), v3(sx * 0.19, 0.575, -0.17)) for sx in (-1, 1)]   # stalk base, pad centre
TAIL_PTS = [v3(0, 0.33, 0.45), v3(0, 0.315, 0.48), v3(0, 0.295, 0.50)]
GRIP = v3(0, 0.32, -0.47)
AXIS = np.array((0.0, 0.5, -0.866))
# Meshy painted closed eyes; the Boki face (lids, brows, mouth that move) takes their place
PAINTED_EYES = [v3(sx * 0.105, 0.455, -0.318) for sx in (1, -1)]
BLUSH_AT = [v3(sx * 0.118, 0.405, -0.35) for sx in (1, -1)]
CHEEK = v3(0.12, 0.40, -0.30)        # where the plain coat is sampled to paint over the drawn eyes


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.15, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    out = [Ellipsoid("barrel_f", "spine", v3(0, 0.27, -0.04), v3(0.25, 0.19, 0.2), k=0.05),
           Ellipsoid("barrel_h", "hips", v3(0, 0.27, 0.24), v3(0.25, 0.2, 0.24), k=0.05),
           Ellipsoid("pool", "saddle", POOL_C, v3(0.26, 0.055, 0.26), k=0.02),
           Cone("neck", "neck", v3(0, 0.31, -0.14), v3(0, 0.37, -0.24), 0.15, 0.13, k=0.04),
           Ellipsoid("head", "head", HEAD_C, v3(0.13, 0.125, 0.14), k=0.04),
           Ellipsoid("snout", "head", v3(0, 0.35, -0.42), v3(0.095, 0.08, 0.07), k=0.03)]
    for (sd, sx), (base, pad) in zip(SIDES, PAD):
        out.append(Ellipsoid("ear" + sd, "ear1." + sd, v3(sx * 0.108, 0.525, -0.225), v3(0.03, 0.035, 0.025), k=0))
        out.append(Cone("stalk" + sd, "pad." + sd, base, pad, 0.015, 0.012, k=0))
        out.append(Ellipsoid("pad" + sd, "pad." + sd, pad, v3(0.07, 0.02, 0.07), k=0))
        for leg, z, _ in LEGS:
            out.append(Cone("%sl1%s" % (leg, sd), "%sleg1.%s" % (leg, sd), v3(sx * LEG_X, 0.17, z),
                            v3(sx * LEG_X, 0.08, z), 0.06, 0.055, k=0.02))
            out.append(Cone("%sl2%s" % (leg, sd), "%sleg2.%s" % (leg, sd), v3(sx * LEG_X, 0.08, z),
                            v3(sx * LEG_X, 0.03, z), 0.055, 0.055, k=0.01))
            out.append(Ellipsoid("%spaw%s" % (leg, sd), "%spaw.%s" % (leg, sd), v3(sx * LEG_X, 0.015, z - 0.01),
                                 v3(0.06, 0.02, 0.07), k=0.01))
    for i in range(2):
        out.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], 0.03, 0.022, k=0.01))
    return out


def parts():
    return {"body": (MeshShape(proxy_prims(), scan()), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.06, 0.1, 0.03), hd(0.1, 0.19, 0.06), 0.024),
    "fang": (hd(0.03, -0.065, -0.13), hd(0.032, -0.095, -0.135), 0.01),
    "antenna": (hd(0.04, 0.11, 0.0), hd(0.085, 0.21, -0.04), 0.009),
    "brow": (hd(0.03, 0.08, -0.04), hd(0.11, 0.085, -0.0), 0.011),
    "head_top": hd(0, 0.125, 0.0), "fang_at": hd(0, -0.065, -0.13), "brow_at": hd(0, 0.08, -0.04),
    "third_eye": hd(0, 0.09, -0.08), "back_at": (0, 0.50, 0.14), "plates": (0, 0.50, 0.14),
    "back": ((0, 0.505, -0.06), (0, 0.51, 0.14), (0, 0.505, 0.34)),
    "plate_r": (0.17, 0.04, 0.11), "shell_c": (0, 0.42, 0.14), "shell_r": (0.22, 0.1, 0.2), "tail_bone": "tail2",
    "club_at": tuple(TAIL_PTS[2]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.045,
    "spots": ((0.25, 0.24, -0.06, 0.022), (0.255, 0.22, 0.08, 0.02), (0.245, 0.2, 0.22, 0.022)),
    "spots_at": (0, 0.22, 0.08),
    "wing": ((0.2, 0.38, 0.0), (0.38, 0.48, 0.08), (0.34, 0.43, 0.18)), "wing_at": (0, 0.38, 0.02),
    "fin": ((0.24, 0.22, 0.3), (0.31, 0.3, 0.4)), "fin_at": (0, 0.22, 0.3),
    "crest": (HEAD_C[1] + 0.125, HEAD_C[2] + 0.02, 0.045, 0.055),
    "crest_at": hd(0, 0.125, 0.02),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


INK = hexc("2a1a12")
BLUSH = hexc("ff9cc4")
LID = hexc("7a5638")
LILAC = hexc("5a3e2a")     # brows
MOUTH_DARK = hexc("4a2018")
TONGUE = hexc("ff8fa8")
IRIS = hexc("5a3a22")
IRIS_DEEP = hexc("1e120a")
STONE_A = hexc("c8c6d0")
STONE_B = hexc("8a8796")
STONE_C = hexc("4a4752")
LILY = hexc("ffa0d0")


COAT_SAT = 0.5           # the hero toon look pushes warm browns to orange-red: halve the scan's chroma first
COAT_DIM = 0.88


def tame(col):
    """The scan's colour with its chroma cut where it is warm (the fur), so the coat reads as the sheet's brown in the
    game; the green pads, the turquoise water and the pink lilies keep theirs."""
    lum = (col @ np.array([0.299, 0.587, 0.114]))[:, None]
    fur = (sat((col[:, 0] - col[:, 2]) / 0.12) * sat((col[:, 0] - col[:, 1]) / 0.08))[:, None]
    return np.clip(col + ((lum + (col - lum) * COAT_SAT) * COAT_DIM - col) * fur, 0, 1)


def paint_body(q, nn):
    sc = scan()
    col = tame(sc.colour(q))
    coat = tame(sc.colour(CHEEK[None]))[0]
    gone = np.zeros(len(q))
    for c in PAINTED_EYES:
        gone = np.maximum(gone, sat((0.042 - np.linalg.norm((q - c) * v3(1.4, 1.1, 1.0), axis=1)) / 0.012))
    col = mixc(col, np.tile(coat, (len(q), 1)), gone)
    blush = np.zeros(len(q))
    for c in BLUSH_AT:
        blush = np.maximum(blush, sat((0.024 - np.linalg.norm((q - c) * v3(0.8, 1.3, 1), axis=1)) / 0.014))
    return mixc(col, np.tile(BLUSH, (len(q), 1)), 0.6 * blush)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(LILY, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), STONE_A, STONE_B, STONE_C)
    return tool_colour(pc.name, q)
