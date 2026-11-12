"""Glintmole, a star-nosed mole whose back is a split geode full of quartz: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #11), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
BODY_C = v3(0, 0.25, 0.07)
BODY_R = v3(0.255, 0.22, 0.29)
HEAD_C = v3(0, 0.27, -0.19)
HEAD_R = v3(0.19, 0.165, 0.17)
EYE_C = v3(0.088, 0.312, -0.318)
EYE_R = v3(0.044, 0.049, 0.03)
EYE_YAW = 0.45
GLOW_PIECES = ()
LIT_PIECES = ("quartz",)
BERRY_C = v3(0, 0.05, -0.52)
FACE = {"mouth_w": 0.05, "mouth_y": 0.205, "mouth_z": -0.37, "cat_mouth": True, "brow_x": 0.085, "brow_up": 0.02,
        "brow_k": 0.8, "fang_k": 0.0}
NOSE_C = v3(0, 0.232, -0.45)
NOSE_AXIS = v3(0, -0.2, -1.0) / np.linalg.norm(v3(0, -0.2, -1.0))
RAYS = 11                  # the star's fleshy rays, round the nostrils
TAIL_PTS = [v3(0, 0.2, 0.33), v3(0, 0.195, 0.38), v3(0, 0.19, 0.42)]
# the geode: a trough down the back (from, to, radius) and the crystals growing out of it
GROOVE = (v3(0, 0.475, -0.08), v3(0, 0.47, 0.17), 0.062)
# (along the groove 0..1, lean out to the side, height, radius, bone)
QUARTZ = [(0.02, 0.0, 0.07, 0.024, "spine"), (0.12, -0.5, 0.10, 0.03, "spine"), (0.17, 0.55, 0.085, 0.026, "spine"),
          (0.3, 0.1, 0.135, 0.036, "spine"), (0.36, -0.75, 0.08, 0.024, "spine"), (0.46, 0.7, 0.11, 0.03, "hips"),
          (0.52, -0.25, 0.15, 0.04, "hips"), (0.62, 0.35, 0.12, 0.032, "hips"), (0.7, -0.65, 0.09, 0.026, "hips"),
          (0.8, 0.05, 0.1, 0.03, "hips"), (0.9, 0.6, 0.065, 0.022, "hips"), (0.95, -0.4, 0.06, 0.02, "hips")]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.12, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def groove_at(u):
    a, b, _ = GROOVE
    return a + (b - a) * u


def body_prims():
    p = [
        Ellipsoid("torso", "hips", BODY_C + v3(0, 0, 0.08), BODY_R * v3(1, 1, 0.7), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.25, -0.05), v3(0.235, 0.21, 0.2), k=0.06),
        Cone("neck", "neck", v3(0, 0.26, -0.05), v3(0, 0.26, -0.15), 0.15, 0.15, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.05),
        Cone("snout", "head", v3(0, 0.255, -0.29), NOSE_C + NOSE_AXIS * -0.02, 0.08, 0.036, k=0.04),
        Ellipsoid("cheekL", "head", v3(-0.1, 0.22, -0.25), v3(0.09, 0.07, 0.09), k=0.04),
        Ellipsoid("cheekR", "head", v3(0.1, 0.22, -0.25), v3(0.09, 0.07, 0.09), k=0.04),
    ]
    for sd, sx in SIDES:
        c = v3(sx * 0.145, 0.39, -0.14)
        n = v3(sx * 0.4, 0.2, -1.0)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, c, v3(0.036, 0.034, 0.016), rot=frame(n, v3(0, 1, 0)), k=0.012))
        # the digging arms: short, out to the side, ending in big spade paws
        top = v3(sx * 0.15, 0.17, -0.12)
        knee = v3(sx * 0.17, 0.095, -0.135)
        ankle = v3(sx * 0.18, 0.04, -0.15)
        p.append(Cone("fleg1" + sd, "fleg1." + sd, top, knee, 0.06, 0.05, k=0.03))
        p.append(Cone("fleg2" + sd, "fleg2." + sd, knee, ankle, 0.05, 0.046, k=0.012))
        p.append(Ellipsoid("fpaw" + sd, "fpaw." + sd, v3(sx * 0.19, 0.03, -0.185), v3(0.068, 0.03, 0.06),
                           rot=frame(v3(sx * 0.35, 0, -1), v3(0, 1, 0)), k=0.016))
        top = v3(sx * 0.14, 0.16, 0.22)
        knee = v3(sx * 0.145, 0.085, 0.216)
        ankle = v3(sx * 0.147, 0.03, 0.212)
        p.append(Cone("hleg1" + sd, "hleg1." + sd, top, knee, 0.058, 0.046, k=0.03))
        p.append(Cone("hleg2" + sd, "hleg2." + sd, knee, ankle, 0.046, 0.04, k=0.012))
        p.append(Ellipsoid("hpaw" + sd, "hpaw." + sd, v3(sx * 0.149, 0.024, 0.19), v3(0.044, 0.024, 0.056), k=0.016))
    p.append(Cone("tail0", "tail1", TAIL_PTS[0], TAIL_PTS[1], 0.036, 0.03, k=0.03))
    p.append(Cone("tail1", "tail2", TAIL_PTS[1], TAIL_PTS[2], 0.03, 0.024, k=0.012))
    a, b, r = GROOVE
    p.append(Cone("groove", "spine", a, b, r, r * 0.85, k=0.02, sub=True))
    return p


def claw_prims():
    out = []
    for sd, sx in SIDES:
        base = v3(sx * 0.19, 0.03, -0.2)
        fwd = v3(sx * 0.35, 0, -1)
        fwd = fwd / np.linalg.norm(fwd)
        side = np.cross(v3(0, 1, 0), fwd)
        for j in range(4):
            off = (j - 1.5) * 0.03
            a = base + side * off + fwd * 0.03
            out.append(Cone("claw%s%d" % (sd, j), "fpaw." + sd, a, a + fwd * 0.065 + v3(0, -0.022, 0), 0.016, 0.004, k=0))
    return out


def star_prims():
    """The pink star: a round nose pad ringed by fleshy rays."""
    up = v3(0, 1, 0)
    side = np.cross(up, NOSE_AXIS)
    side = side / np.linalg.norm(side)
    up = np.cross(NOSE_AXIS, side)
    out = [Ellipsoid("pad", "head", NOSE_C, v3(0.025, 0.023, 0.018), rot=frame(NOSE_AXIS, v3(0, 1, 0)), k=0)]
    for i in range(RAYS):
        a = math.tau * (i + 0.5) / RAYS
        d = side * math.cos(a) + up * math.sin(a)
        root = NOSE_C + d * 0.019 - NOSE_AXIS * 0.006
        out.append(Cone("ray%d" % i, "head", root, root + d * 0.028 + NOSE_AXIS * 0.008, 0.011, 0.0075, k=0.008))
    return out


def quartz_prims():
    out = []
    for i, (u, lean, h, r, bone) in enumerate(QUARTZ):
        base = groove_at(u) + v3(lean * 0.03, -0.03, 0)
        tip = base + v3(lean * h * 0.55, h, (u - 0.5) * 0.04)
        mid = base + (tip - base) * 0.72
        out.append(Cone("q%da" % i, bone, base, mid, r, r, k=0))
        out.append(Cone("q%db" % i, bone, mid, tip, r, 0.003, k=0))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2300),
        "claws": (Shape(claw_prims()), 0.0025, 130),
        "star": (Shape(star_prims()), 0.0025, 260),
        "quartz": (Shape(quartz_prims()), 0.0035, 420),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.19, -0.40)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.06, 0.41, -0.23), (0.12, 0.54, -0.29), 0.032), "fang": ((0.026, 0.19, -0.37), (0.03, 0.15, -0.375), 0.012),
    "antenna": ((0.05, 0.41, -0.25), (0.11, 0.57, -0.33), 0.011), "brow": ((0.015, 0.37, -0.32), (0.12, 0.375, -0.28), 0.017),
    "head_top": (0, 0.42, -0.21), "fang_at": (0, 0.2, -0.36), "brow_at": (0, 0.36, -0.31), "third_eye": (0, 0.375, -0.32),
    "back": ((0, 0.46, -0.13), (0.0, 0.45, 0.30), (0, 0.4, 0.33)), "back_at": (0, 0.45, 0.1), "plates": (0, 0.47, -0.12),
    "plate_r": (0.15, 0.045, 0.06), "shell_c": (0, 0.25, 0.07), "shell_r": (0.27, 0.235, 0.07), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.05,
    "spots": ((0.25, 0.22, 0.0, 0.024), (0.255, 0.2, 0.1, 0.02), (0.23, 0.17, 0.19, 0.022)), "spots_at": (0, 0.22, 0.08),
    "wing": ((0.2, 0.40, 0.02), (0.40, 0.50, 0.1), (0.36, 0.45, 0.2)), "wing_at": (0, 0.42, 0.02),
    "fin": ((0.24, 0.2, 0.2), (0.33, 0.28, 0.32)), "fin_at": (0, 0.22, 0.2), "crest": (0.41, -0.22, 0.05, 0.06),
    "crest_at": (0, 0.42, -0.19),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
FUR = hexc("8a7490")
FUR_LIGHT = hexc("a892ae")
FUR_DARK = hexc("64526a")
CREAM = hexc("ecd6bf")
PALM = hexc("f2b9c4")
CLAW = hexc("f6ecd8")
BLUSH = hexc("ff8fb0")
STAR = hexc("ff9cc4")
STAR_DEEP = hexc("e0608e")
STONE = hexc("8f8496")
STONE_DARK = hexc("5c5263")
GEODE = hexc("6b3fa8")
QUARTZ_A = hexc("c9a8ff")
QUARTZ_B = hexc("f4ecff")
QUARTZ_DEEP = hexc("8a62d8")
LILAC = hexc("8a7890")     # brows
LID = FUR_LIGHT
INK = hexc("2e2234")
MOUTH_DARK = hexc("6e2a44")
TONGUE = hexc("f08aa8")
IRIS = hexc("b58cff")
IRIS_DEEP = hexc("3a1f6e")
SHELL_A = hexc("b8aec0")
SHELL_B = hexc("8f8496")
SHELL_C = hexc("5c5263")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    velvet = value_noise(p * np.array([70, 70, 30]))
    col = mixc(FUR_DARK, FUR, sat(n[:, 1] * 0.6 + 0.55 + (velvet - 0.5) * 0.35))
    col = mixc(col, FUR_LIGHT, sat(n[:, 1] - 0.35) * 0.45)
    # cream from the chin down the throat and belly
    under = edge(0.1 - y - np.abs(x) * 0.12, 0.014)
    bib = edge(0.075 + (0.25 - y) * 0.25 - np.abs(x), 0.012) * edge(0.255 - y, 0.012) * edge(-0.02 - z, 0.03)
    belly = sat(under + bib)
    col = mixc(col, CREAM, belly)
    # the geode: a grey stone rim, a violet lining inside the trough
    g = prim["groove"].d(p)
    rim = edge(0.022 - np.abs(g + 0.004), 0.006) * (y > 0.36)
    inner = edge(-0.006 - g, 0.004) * (y > 0.36)
    speck = value_noise(p * 120)
    col = mixc(col, mixc(STONE_DARK, STONE, speck), rim)
    col = mixc(col, mixc(GEODE * 0.7, GEODE, speck), inner)
    for sd in "LR":
        col = mixc(col, PALM, edge(0.004 - prim["fpaw" + sd].d(p), 0.004) * (n[:, 1] < 0.2))
        col = mixc(col, FUR_LIGHT, edge(0.004 - prim["ear" + sd].d(p), 0.004))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.125, 0.235, 0])) / np.array([0.045, 0.028, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.2) * 0.7)
    return col


def paint_star(q, n):
    r = np.linalg.norm(np.cross(q - NOSE_C, NOSE_AXIS), axis=1)
    col = mixc(STAR_DEEP, STAR, sat((r - 0.012) / 0.014))
    for sx in (-1.0, 1.0):          # nostrils
        d = np.hypot(q[:, 0] - sx * 0.011, q[:, 1] - NOSE_C[1] - 0.002)
        col = mixc(col, MOUTH_DARK, edge(0.0055 - d, 0.0015) * ((q - NOSE_C) @ NOSE_AXIS > 0.012))
    return col


def paint_quartz(q, n, pc):
    """Lilac crystals, paler and clearer toward the tips, a flat facet shade from the normal."""
    base_y = np.array([groove_at(u)[1] for u, *_ in QUARTZ]).min() - 0.03
    tip = sat((q[:, 1] - base_y) / 0.14)
    facet = np.floor((np.arctan2(n[:, 0], n[:, 2]) / math.tau + 0.5) * 6) / 6
    col = mixc(QUARTZ_DEEP, QUARTZ_A, sat(tip * 1.4 + facet * 0.25))
    return mixc(col, QUARTZ_B, sat(tip * 1.6 - 0.75) + sat(n[:, 1]) * 0.15)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "claws":
        return np.tile(CLAW, (len(q), 1))
    if pc.name == "star":
        return paint_star(q, nn)
    if pc.name == "quartz":
        return paint_quartz(q, nn, pc)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(QUARTZ_A, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
