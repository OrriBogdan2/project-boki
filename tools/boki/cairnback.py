"""Cairnback (cairnback), a tortoise with an ibex's sweeping horns and a rune-carved cairn on its shell: shapes and
coat. Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.30, -0.31)
HEAD_R = v3(0.16, 0.145, 0.16)
EYE_C = v3(0.088, 0.319, -0.412)
EYE_R = v3(0.047, 0.053, 0.031)
EYE_YAW = 0.42
GLOW_PIECES = ("runes",)
BERRY_C = v3(0, 0.05, -0.54)
FACE = {"mouth_w": 0.064, "mouth_y": 0.25, "mouth_z": -0.50, "cat_mouth": False, "brow_x": 0.095, "brow_up": 0.02,
        "brow_k": 0.7, "fang_k": 0.0}
SHELL_C = v3(0, 0.29, 0.05)
SHELL_R = v3(0.25, 0.215, 0.27)
RIM_Y = 0.15
# the cairn: flat stones stacked on the top of the shell (centre, radii, yaw), the rune-stone it throws on top
CAIRN = ((v3(0, 0.51, 0.06), v3(0.105, 0.04, 0.09), 0.2), (v3(0.012, 0.568, 0.05), v3(0.08, 0.034, 0.068), -0.4),
         (v3(-0.006, 0.616, 0.062), v3(0.058, 0.028, 0.05), 0.5))
STONE_C = v3(0, 0.668, 0.058)
STONE_R = v3(0.042, 0.036, 0.04)
TAIL_PTS = [v3(0, 0.17, 0.30), v3(0, 0.135, 0.36), v3(0, 0.1, 0.395)]
# ibex horns, right side: base on the head, sweeping up and back over the shell's front
HORN_PTS = [v3(0.06, 0.41, -0.32), v3(0.082, 0.50, -0.30), v3(0.108, 0.565, -0.25), v3(0.135, 0.598, -0.18),
            v3(0.16, 0.594, -0.11), v3(0.18, 0.56, -0.065)]
HORN_R = [0.046, 0.04, 0.034, 0.027, 0.019, 0.012]
# scutes: directions from the shell's centre to the middle of each plate
SCUTES = [(0, 1, -0.75), (0, 1, -0.25), (0, 1, 0.25), (0, 1, 0.75)] + \
    [(sx * 0.95, 0.7, z) for sx in (-1, 1) for z in (-0.62, 0.0, 0.62)] + \
    [(math.sin(a), -0.05, math.cos(a)) for a in np.linspace(0, math.tau, 18, endpoint=False)]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def on_shell(d):
    """The point of the dome along direction d from its centre, and the outward normal there."""
    d = np.asarray(d, float)
    p = SHELL_C + d / np.linalg.norm(d / SHELL_R)
    n = (p - SHELL_C) / (SHELL_R * SHELL_R)
    return p, n / np.linalg.norm(n)


SCUTE_AT = np.array([on_shell(d)[0] for d in SCUTES])


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.205, 0.08), v3(0.205, 0.12, 0.23), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.215, -0.08), v3(0.19, 0.13, 0.14), k=0.06),
        Cone("neck", "neck", v3(0, 0.225, -0.12), v3(0, 0.27, -0.24), 0.115, 0.12, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("muzzle", "head", v3(0, 0.258, -0.41), v3(0.1, 0.08, 0.08), k=0.05),
    ]
    for sd, sx in SIDES:
        c = v3(sx * 0.17, 0.375, -0.27)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, c + v3(sx * 0.03, -0.01, 0), v3(0.055, 0.022, 0.032),
                           rot=frame(v3(sx, -0.25, 0.2), v3(0, 1, 0)), k=0.012))
        p.append(Ellipsoid("earhole" + sd, "ear1." + sd, c + v3(sx * 0.035, -0.002, -0.012), v3(0.036, 0.012, 0.012),
                           rot=frame(v3(sx, -0.25, 0.2), v3(0, 1, 0)), k=0.006, sub=True))
        for leg, z in (("f", -0.12), ("h", 0.22)):
            top = v3(sx * 0.15, 0.17, z)
            knee = v3(sx * 0.165, 0.09, z - 0.005)
            ankle = v3(sx * 0.168, 0.036, z - 0.01)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (leg, sd), top, knee, 0.068, 0.062, k=0.03))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (leg, sd), knee, ankle, 0.062, 0.06, k=0.012))
            paw = v3(sx * 0.17, 0.028, z - 0.02)
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (leg, sd), paw, v3(0.066, 0.03, 0.068), k=0.016))
            for j, dx in enumerate((-0.034, 0.0, 0.034)):
                nail = paw + v3(sx * dx, -0.006, -0.058 + abs(dx) * 0.4)
                p.append(Ellipsoid("%snail%s%d" % (leg, sd, j), "%spaw.%s" % (leg, sd), nail, v3(0.017, 0.014, 0.016),
                                   k=0.004))
    p.append(Cone("tail0", "tail1", TAIL_PTS[0], TAIL_PTS[1], 0.045, 0.032, k=0.03))
    p.append(Cone("tail1", "tail2", TAIL_PTS[1], TAIL_PTS[2], 0.032, 0.012, k=0.01))
    return p


def shell_prims():
    return [
        Ellipsoid("dome", "hips", SHELL_C, SHELL_R, k=0.0),
        Ellipsoid("rim", "hips", v3(0, 0.185, 0.05), v3(0.268, 0.042, 0.29), k=0.03),
        Ellipsoid("cut", "hips", v3(0, RIM_Y - 1.0, 0.05), v3(2.0, 1.0, 2.0), k=0.01, sub=True),
    ]


def cairn_prims():
    out = []
    for i, (c, r, yaw) in enumerate(CAIRN):
        rot = frame(v3(math.sin(yaw), 0, math.cos(yaw)), v3(0, 1, 0))
        out.append(Ellipsoid("stone%d" % i, "cairn", c, r, rot=rot, k=0.004))
    out.append(Ellipsoid("moss0", "cairn", v3(-0.07, 0.49, 0.1), v3(0.045, 0.025, 0.04), k=0.01))
    out.append(Ellipsoid("moss1", "cairn", v3(-0.04, 0.495, 0.13), v3(0.035, 0.022, 0.03), k=0.01))
    return out


def horn_prims():
    out = []
    for sd, sx in SIDES:
        pts = [v3(q[0] * sx, q[1], q[2]) for q in HORN_PTS]
        for i in range(len(pts) - 1):
            out.append(Cone("horn%s%d" % (sd, i), "horn." + sd, pts[i], pts[i + 1], HORN_R[i], HORN_R[i + 1], k=0.006))
            d = pts[i + 1] - pts[i]
            out.append(Ellipsoid("ridge%s%d" % (sd, i), "horn." + sd, pts[i] + d * 0.5,
                                 v3(HORN_R[i] * 1.16, HORN_R[i] * 1.16, 0.01), rot=frame(d, v3(1, 0, 0)), k=0.006))
    return out


GLYPHS = (
    (((0, -1.2), (0, 1.2)), ((0, 0.2), (0.8, 1.0)), ((0, -0.5), (0.8, 0.3))),
    (((0, -1.2), (0, 1.2)), ((-0.8, 0.4), (0, 1.2)), ((0.8, 0.4), (0, 1.2))),
    (((-0.7, -1.1), (0.7, 1.1)), ((-0.7, 1.1), (0.7, -1.1))),
    (((0, -1.2), (0, 1.2)), ((0, 1.2), (0.8, 0.45)), ((0.8, 0.45), (0, -0.25))),
)


def glyph(name, bone, at, n, unit, which, shape):
    """A rune of short strokes lying on `shape` at `at`, facing n."""
    n = n / np.linalg.norm(n)
    u = np.cross(v3(0, 1, 0) if abs(n[1]) < 0.9 else v3(0, 0, -1), n)
    u = u / np.linalg.norm(u)
    v = np.cross(n, u)
    out = []
    for i, (a, b) in enumerate(GLYPHS[which % len(GLYPHS)]):
        pa = shape.project((at + u * a[0] * unit + v * a[1] * unit)[None], steps=6)[0]
        pb = shape.project((at + u * b[0] * unit + v * b[1] * unit)[None], steps=6)[0]
        out.append(Cone("%s_%d" % (name, i), bone, pa, pb, unit * 0.32, unit * 0.32, k=0.0, flat=0.45, flat_axis=n))
    return out


def rune_prims():
    out = [Ellipsoid("stone", "prop_stone", STONE_C, STONE_R, k=0)]
    shell = Shape(shell_prims())
    for i in range(10):
        at, n = on_shell(SCUTES[i])
        out += glyph("sr%d" % i, "hips", at, n, 0.016, i, shell)
    for i, (c, r, _) in enumerate(CAIRN):
        stone = Shape([Ellipsoid("s", "cairn", c, r)])
        for j, ang in enumerate((-0.7, 0.7, math.pi - 0.6, math.pi + 0.6)[:4 - i]):
            d = v3(math.sin(ang), 0, -math.cos(ang))
            at = stone.project((c + d * 0.2)[None], steps=10)[0]
            out += glyph("cr%d%d" % (i, j), "cairn", at, at - c, r[1] * 0.42, i + j, stone)
    for sd, sx in SIDES:
        out.append(Ellipsoid("tip" + sd, "horn." + sd, v3(HORN_PTS[-1][0] * sx, HORN_PTS[-1][1], HORN_PTS[-1][2]),
                             v3(0.016, 0.016, 0.016), k=0))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 1700),
        "shell": (Shape(shell_prims()), 0.0035, 780),
        "cairn": (Shape(cairn_prims()), 0.003, 250),
        "horns": (Shape(horn_prims()), 0.003, 340),
        "runes": (Shape(rune_prims()), 0.0022, 340),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.235, -0.485)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.03, 0.43, -0.39), (0.06, 0.53, -0.45), 0.026),
    "fang": ((0.04, 0.232, -0.48), (0.043, 0.195, -0.485), 0.013),
    "antenna": ((0.03, 0.44, -0.36), (0.07, 0.6, -0.44), 0.012),
    "brow": ((0.03, 0.385, -0.43), (0.105, 0.388, -0.395), 0.011),
    "head_top": (0, 0.45, -0.33), "fang_at": (0, 0.24, -0.47), "brow_at": (0, 0.39, -0.43),
    "third_eye": (0, 0.405, -0.455),
    "back": ((0, 0.47, -0.13), (0, 0.44, 0.24), (0, 0.37, 0.3)), "back_at": (0, 0.47, 0.05),
    "plates": (0, 0.47, -0.13),
    "plate_r": (0.12, 0.04, 0.07), "shell_c": (0, 0.4, 0.23), "shell_r": (0.16, 0.08, 0.1), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.05,
    "spots": ((0.245, 0.27, -0.08, 0.022), (0.25, 0.27, 0.05, 0.02), (0.235, 0.26, 0.18, 0.022)),
    "spots_at": (0, 0.27, 0.05),
    "wing": ((0.18, 0.42, 0.0), (0.38, 0.53, 0.08), (0.34, 0.48, 0.18)), "wing_at": (0, 0.43, 0.02),
    "fin": ((0.23, 0.29, 0.2), (0.31, 0.39, 0.31)), "fin_at": (0, 0.29, 0.2), "crest": (0.44, -0.36, 0.05, 0.05),
    "crest_at": (0, 0.44, -0.33),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
SAND = hexc("cdb88c")
SAND_LIGHT = hexc("e2d0a4")
CREAM = hexc("f2e8cc")
SHELL = hexc("8e94a2")
SHELL_LIGHT = hexc("b6bbc6")
SHELL_DARK = hexc("626672")
SCUTE_EDGE = hexc("464a54")
PLASTRON = hexc("d8c59a")
NAIL = hexc("5a5048")
HORN = hexc("b0a796")
HORN_LIGHT = hexc("e2dccc")
HORN_DARK = hexc("7a7264")
STONE = hexc("b4afa4")
STONE_LIGHT = hexc("dcd8ce")
STONE_DARK = hexc("7c776e")
MOSS = hexc("6f9a4a")
EAR_IN = hexc("e8a8a0")
BLUSH = hexc("ff9a90")
LILAC = hexc("8a7a5c")     # brows
LID = SAND_LIGHT
INK = hexc("2e2a26")
MOUTH_DARK = hexc("5a2a2a")
TONGUE = hexc("f08a8a")
IRIS = hexc("e0a43a")
GOLD = hexc("ffd36a")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fine = value_noise(p * np.array([70, 50, 70]))
    col = mixc(SAND * 0.92, SAND_LIGHT, sat(n[:, 1] * 0.5 + 0.45 + (fine - 0.5) * 0.35))
    # a pale chin, throat and plastron; scaly knees
    chin = edge(0.27 - y + ax * 0.2, 0.01) * (z < -0.25)
    plastron = edge(0.15 - y, 0.01) * (z > -0.2) * edge(0.17 - ax, 0.02)
    col = mixc(col, CREAM, chin)
    col = mixc(col, PLASTRON, plastron)
    seg = np.abs(((z + 0.15) / 0.09) % 1.0 - 0.5)
    col = mixc(col, PLASTRON * 0.82, edge(0.04 - seg, 0.02) * plastron * (z < 0.32))
    legs = (y < 0.16) & (ax > 0.1)
    scale = sat((value_noise(p * 95) - 0.55) / 0.08)
    col = mixc(col, SAND * 0.88, scale * legs * 0.3)
    for sd in "LR":
        hole = prim["earhole" + sd].d(p)
        ear = prim["ear" + sd].d(p) < 0.02
        col = mixc(col, EAR_IN, edge(0.004 - hole, 0.002) * ear)
        for j in range(6):
            leg = "fnail" if j < 3 else "hnail"
            col = mixc(col, NAIL, edge(0.003 - prim["%s%s%d" % (leg, sd, j % 3)].d(p), 0.002))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.122, 0.278, 0])) / np.array([0.04, 0.026, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.33) * 0.6)
    for sx in (-1.0, 1.0):       # nostrils
        q = np.hypot(x - sx * 0.032, y - 0.29)
        col = mixc(col, INK, edge(0.006 - q, 0.002) * (z < -0.44) * 0.6)
    return col


def paint_scutes(p, n):
    """Stone-grey plates with a paler middle and growth rings, dark seams between them, a pale rim underneath."""
    d = np.linalg.norm(p[:, None, :] - SCUTE_AT[None, :, :], axis=-1)
    order = np.argsort(d, axis=1)
    d1 = np.take_along_axis(d, order[:, :1], 1)[:, 0]
    d2 = np.take_along_axis(d, order[:, 1:2], 1)[:, 0]
    own = order[:, 0]
    tone = (np.sin(own * 12.9898) * 43758.5453) % 1.0
    up = sat(n[:, 1] * 0.55 + 0.45)
    col = mixc(SHELL_DARK, mixc(SHELL, SHELL_LIGHT, tone * 0.5), up)
    rings = np.abs(((d1 / 0.028) % 1.0) - 0.5)
    col = mixc(col, SHELL_DARK, edge(0.08 - rings, 0.05) * 0.35 * (d1 > 0.02))
    col = mixc(col, SHELL_LIGHT * 1.05, edge(0.024 - d1, 0.01) * 0.6)
    col = mixc(col, SCUTE_EDGE, edge(0.007 - (d2 - d1), 0.003))
    return mixc(col, PLASTRON * 0.85, edge(-n[:, 1] - 0.5, 0.15))


def paint_cairn(q, nn, prim_of):
    stone = paint_shell(q, nn, np.full(len(q), 1.0), STONE_LIGHT, STONE, STONE_DARK)
    grain = value_noise(q * np.array([40, 90, 40]))
    stone = stone * (0.9 + 0.2 * grain[:, None])
    moss = np.minimum(prim_of["moss0"].d(q), prim_of["moss1"].d(q))
    tuft = mixc(MOSS * 0.8, MOSS * 1.2, value_noise(q * 120))
    return mixc(stone, tuft, edge(0.004 - moss, 0.003))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "shell":
        return paint_scutes(q, nn)
    if pc.name == "cairn":
        return paint_cairn(q, nn, {pr.name: pr for pr in pc.shape.prims})
    if pc.name == "horns":
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_LIGHT, HORN, HORN_DARK)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GOLD, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), STONE_LIGHT, STONE, STONE_DARK)
    if pc.name in GLOW_PIECES:
        return np.tile(GOLD, (len(q), 1))
    return tool_colour(pc.name, q)
