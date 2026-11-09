"""Lockatara (tuatrune): a stocky spiny olive lizard with an iron padlock's shackle arched over its back, a glowing
keyhole third eye and a key-bit tail.

Like Zippelith its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/tuatrune_turnaround.png), read
from ~/meshy/tuatrune/run1 (raw files stay out of git), turned into game axes, decimated to the budget and painted
from Meshy's own texture, graded to the sheet's olive, dark iron and old gold. The primitives below are a proxy for
the skin weights and the rig. Game axes as vespyx.py."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from meshy_body import Meshy, MeshShape
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

MESHY_DIR = os.path.expanduser("~/meshy/tuatrune/run1")
HEIGHT = 0.6             # the model's height in game metres, before SCALE
SCALE = 0.95
BODY_TRIS = 3400
HEAD_C = v3(0, 0.27, -0.39)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


EYE_C = v3(0.104, 0.276, -0.425)
EYE_R = v3(0.033, 0.035, 0.02)
EYE_YAW = 0.62
GLOW_PIECES = ()
LIT_PIECES = ("keyhole",)
BERRY_C = v3(0, 0.05, -0.58)
FACE = {"mouth_w": 0.07, "mouth_y": 0.222, "mouth_z": -0.49, "cat_mouth": False,
        "brow_x": 0.1, "brow_up": 0.016, "brow_k": 0.6, "fang_k": 0.0}
# the shackle: a U of dark iron over the back, its legs in the lock bodies on the flanks
SHACKLE_C = v3(0, 0.40, -0.105)
SHACKLE_R = 0.17         # radius of the arch's centre line
KEYHOLE_C = v3(0, 0.331, -0.433)
KEYHOLE_N = v3(0, 0.45, -1.0)
# the tail, root to the key bit; it bends out to the right (+x)
TAIL_PTS = [v3(0, 0.2, 0.08), v3(0, 0.17, 0.18), v3(0.01, 0.13, 0.27), v3(0.06, 0.105, 0.34), v3(0.12, 0.08, 0.48)]
TAIL_R = [0.075, 0.055, 0.04, 0.03, 0.02]
LEGS = (("f", -0.255, 0.14, 0.131), ("h", 0.0, 0.15, 0.146))     # leg, z, x at the hip, x at the foot
GRIP = v3(0, 0.215, -0.52)
AXIS = np.array((0.0, 0.5, -0.866))
STONE_C = v3(0, 0.2, -0.56)
# Meshy painted its own eyes and mouth; the Boki face (lids, brows, mouth that move) takes their place
PAINTED_EYES = [v3(sx * 0.108, 0.272, -0.413) for sx in (1, -1)]
PAINTED_MOUTH = (0.222, -0.44)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def leg_pts(z, xh, xf, sx):
    return v3(sx * xh, 0.17, z), v3(sx * (xh * 0.6 + xf * 0.4), 0.09, z - 0.004), v3(sx * xf, 0.035, z - 0.01)


def proxy_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.22, 0.0), v3(0.17, 0.13, 0.13), k=0.04),
        Ellipsoid("chest", "spine", v3(0, 0.23, -0.17), v3(0.18, 0.14, 0.13), k=0.05),
        Cone("neck", "neck", v3(0, 0.24, -0.25), v3(0, 0.26, -0.32), 0.12, 0.12, k=0.04),
        Ellipsoid("head", "head", HEAD_C, v3(0.14, 0.11, 0.11), k=0.04),
        Ellipsoid("snout", "head", v3(0, 0.24, -0.46), v3(0.09, 0.06, 0.05), k=0.03),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("lock" + sd, "spine", v3(sx * 0.19, 0.29, -0.105), v3(0.03, 0.11, 0.06), k=0.01))
        for leg, z, xh, xf in LEGS:
            top, knee, ankle = leg_pts(z, xh, xf, sx)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (leg, sd), top, knee, 0.05, 0.042, k=0.02))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (leg, sd), knee, ankle, 0.042, 0.036, k=0.01))
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (leg, sd), ankle + v3(0, -0.015, -0.03),
                               v3(0.045, 0.022, 0.055), k=0.01))
    for i in range(4):
        p.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], TAIL_R[i], TAIL_R[i + 1],
                      k=0.02))
    p.append(Ellipsoid("key", "tail4", v3(0.11, 0.075, 0.44), v3(0.04, 0.06, 0.07), k=0.01))
    arch = [SHACKLE_C + v3(math.cos(a), math.sin(a), 0) * SHACKLE_R for a in np.linspace(0, math.pi, 7)]
    for i in range(len(arch) - 1):
        p.append(Cone("arch%d" % i, "shackle", arch[i], arch[i + 1], 0.035, 0.035, k=0.0))
    return p


def keyhole_prims():
    rot = frame(KEYHOLE_N, v3(0, 1, 0))
    return [Ellipsoid("plate", "head", KEYHOLE_C, v3(0.022, 0.025, 0.006), rot=rot, k=0)]


def stone_prims():
    return [Ellipsoid("stone", "prop_stone", STONE_C, v3(0.045, 0.038, 0.042), k=0)]


def body():
    return Meshy.get(MESHY_DIR, HEIGHT)


def parts():
    return {"body": (MeshShape(proxy_prims(), body()), 0.0035, BODY_TRIS),
            "keyhole": (Shape(keyhole_prims()), 0.0015, 60),
            "stone": (Shape(stone_prims()), 0.003, 80)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.05, 0.09, 0.02), hd(0.09, 0.18, 0.06), 0.022),
    "fang": ((0.035, 0.215, -0.47), (0.037, 0.18, -0.475), 0.01),
    "antenna": (hd(0.04, 0.09, 0.0), hd(0.08, 0.21, -0.05), 0.009),
    "brow": ((0.04, 0.312, -0.455), (0.13, 0.31, -0.415), 0.011),
    "head_top": hd(0, 0.11, 0.0), "fang_at": (0, 0.22, -0.47), "brow_at": (0, 0.31, -0.45),
    "third_eye": (0, 0.36, -0.43),
    "back": ((0, 0.40, -0.26), (0, 0.39, 0.02), (0, 0.32, 0.09)), "back_at": (0, 0.40, 0.0),
    "plates": (0, 0.39, 0.02),
    "plate_r": (0.1, 0.035, 0.06), "shell_c": (0, 0.35, 0.02), "shell_r": (0.14, 0.07, 0.1), "tail_bone": "tail3",
    "club_at": tuple(TAIL_PTS[3]), "club_dir": tuple(TAIL_PTS[4] - TAIL_PTS[2]), "club_r": 0.045,
    "spots": ((0.175, 0.25, -0.22, 0.02), (0.17, 0.24, 0.02, 0.02), (0.15, 0.21, 0.07, 0.018)),
    "spots_at": (0, 0.25, -0.08),
    "wing": ((0.15, 0.38, 0.0), (0.32, 0.48, 0.06), (0.28, 0.43, 0.13)), "wing_at": (0, 0.38, 0.0),
    "fin": ((0.17, 0.25, 0.05), (0.25, 0.33, 0.12)), "fin_at": (0, 0.25, 0.05),
    "crest": (0.38, -0.36, 0.05, 0.05), "crest_at": (0, 0.38, -0.36),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
OLIVE = hexc("5a6a2e")
IRON = hexc("2e3036")
GOLD = hexc("ffcf5a")
OLD_GOLD = hexc("b08a3a")
LILAC = hexc("4a5226")     # brows
INK = hexc("1a1a14")
LID = hexc("6a7a3a")
MOUTH_DARK = hexc("4a1a1a")
TONGUE = hexc("e07a7a")
BLUSH = hexc("c86a5a")
IRIS = hexc("e0a43a")
IRIS_DEEP = hexc("6a3a08")
STONE = hexc("8a8478")
STONE_LIGHT = hexc("b8b2a4")
STONE_DARK = hexc("5a564e")
GAMMA = 1.2            # Meshy's coat is washed out against the sheet: a little deeper
TINT = np.array([0.85, 1.0, 0.8])    # and yellower than its olive green; the gold runes keep their colour


def in_shackle(q):
    """1 on the shackle's iron (the arch and the lock bodies), 0 elsewhere."""
    r = np.hypot(q[:, 0] - SHACKLE_C[0], q[:, 1] - SHACKLE_C[1])
    near_z = sat((0.075 - np.abs(q[:, 2] - SHACKLE_C[2])) / 0.015)
    arch = sat((0.05 - np.abs(r - SHACKLE_R)) / 0.012) * sat((q[:, 1] - 0.38) / 0.02)
    sides = sat((np.abs(q[:, 0]) - 0.165) / 0.012) * sat((0.43 - q[:, 1]) / 0.02) * sat((q[:, 1] - 0.17) / 0.02)
    return np.maximum(arch, sides) * near_z


def paint_body(q, nn):
    col = np.clip(body().colour(q), 0, 1) ** GAMMA
    lum = col @ np.array([0.3, 0.55, 0.15])
    gold = sat((col[:, 0] - col[:, 2] - 0.3) / 0.1) * sat((lum - 0.3) / 0.1)
    col = mixc(col * TINT, col, gold)
    iron = in_shackle(q) * (1 - gold)
    col = mixc(col, (lum[:, None] * 0.85 + 0.02) * IRON / (IRON @ np.array([0.3, 0.55, 0.15])), 0.75 * iron)
    gone = np.zeros(len(q))
    for c in PAINTED_EYES:
        gone = np.maximum(gone, sat((0.048 - np.linalg.norm((q - c) * v3(1, 1.0, 1.3), axis=1)) / 0.01))
    my, mz = PAINTED_MOUTH
    mouth = (sat((0.016 - np.abs(q[:, 1] - my - 3 * q[:, 0] ** 2)) / 0.006) * sat((mz - q[:, 2]) / 0.02)
             * sat((0.09 - np.abs(q[:, 0])) / 0.012))
    gone = np.maximum(gone, mouth)
    return mixc(col, np.tile(OLIVE, (len(q), 1)), gone)


def paint_keyhole(q):
    """Glowing gold with a dark keyhole cut through: a round top over a flared slot."""
    d = q - KEYHOLE_C
    up = d @ v3(0, 1, 0)
    side = d @ v3(1, 0, 0)
    slot = (up < 0.004) & (up > -0.017) & (np.abs(side) < 0.003 + (0.004 - up) * 0.2)
    hole = (np.hypot(side, up - 0.006) < 0.0075) | slot
    rim = np.hypot(side, up) > 0.019
    col = np.tile(GOLD, (len(q), 1))
    col[rim] = OLD_GOLD
    col[hole] = INK
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name == "keyhole":
        return paint_keyhole(q)
    if pc.name == "stone":
        return paint_shell(q, nn, np.full(len(q), 1.0), STONE_LIGHT, STONE, STONE_DARK)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GOLD, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), OLIVE * 1.4, OLIVE, IRON)
    return tool_colour(pc.name, q)
