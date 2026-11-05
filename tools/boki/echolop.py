"""Echolop (zapple), a long-eared hare with bat wings that hears everything: shapes and coat. Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.43, -0.15)
HEAD_R = v3(0.19, 0.165, 0.17)
EYE_C = v3(0.094, 0.452, -0.283)
EYE_R = v3(0.05, 0.058, 0.033)
EYE_YAW = 0.48
GLOW_PIECES = ("ear_glow",)
FACE = {"mouth_w": 0.046, "mouth_y": 0.372, "mouth_z": -0.34, "cat_mouth": True, "brow_x": 0.092, "brow_up": 0.02,
        "brow_k": 0.72, "fang_k": 0.0}
NOSE_C = v3(0, 0.416, -0.336)
# an ear: base, two joints, tip (the right one; the left mirrors it), and its half widths
EAR_PTS = [v3(0.078, 0.565, -0.13), v3(0.104, 0.70, -0.112), v3(0.128, 0.83, -0.098), v3(0.142, 0.905, -0.092)]
EAR_W = (0.05, 0.072, 0.064, 0.042)
EAR_FLAT = 0.33
TAIL_PTS = [v3(0, 0.235, 0.215), v3(0, 0.27, 0.27), v3(0, 0.30, 0.31)]
# a folded wing, on the right: the shoulder, and in the wing's own plane (back, out) the wrist, three finger tips
# and where the web meets the body
WING_S = v3(0.06, 0.335, -0.03)
WING_UV = {"S": (0.0, 0.0), "W": (0.09, -0.035), "T1": (0.24, -0.01), "T2": (0.215, 0.10), "T3": (0.13, 0.16),
           "B": (0.02, 0.11)}
BERRY_C = v3(0, 0.07, -0.20)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def mirror(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def ear_normal(sx):
    """The way the ear's scoop faces: forward and a little out."""
    n = v3(sx * 0.28, 0.0, -1.0)
    return n / np.linalg.norm(n)


def ear_prims(sd, sx):
    n = ear_normal(sx)
    pts = [mirror(p, sx) for p in EAR_PTS]
    out = []
    for i in range(3):
        out.append(Cone("ear%d%s" % (i + 1, sd), "ear%d.%s" % (i + 1, sd), pts[i], pts[i + 1], EAR_W[i], EAR_W[i + 1],
                        k=0.02, flat=EAR_FLAT, flat_axis=n))
    along = pts[2] - pts[0]
    out.append(Ellipsoid("earhole" + sd, "ear2." + sd, pts[0] + along * 0.5 + n * 0.03, v3(0.044, 0.15, 0.022),
                         rot=frame(n, along), k=0.012, sub=True))
    return out


def ear_glow_prims():
    out = []
    for sd, sx in SIDES:
        n = ear_normal(sx)
        pts = [mirror(p, sx) for p in EAR_PTS]
        for i, (a, b, r) in enumerate(((0.12, 0.62, 0.032), (0.5, 0.95, 0.036))):
            pa = pts[0] + (pts[2] - pts[0]) * a + n * 0.006
            pb = pts[0] + (pts[2] - pts[0]) * b + n * 0.006
            out.append(Cone("eg%s%d" % (sd, i), "ear%d.%s" % (i + 1, sd), pa, pb, r * 0.8, r, k=0.02, flat=0.3,
                            flat_axis=n))
    return out


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.205, 0.075), v3(0.135, 0.13, 0.165), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.225, -0.05), v3(0.118, 0.128, 0.115), k=0.05),
        Cone("neck", "neck", v3(0, 0.28, -0.07), v3(0, 0.37, -0.12), 0.09, 0.105, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("muzzle", "head", v3(0, 0.382, -0.268), v3(0.08, 0.062, 0.074), k=0.04),
        Ellipsoid("nose", "head", NOSE_C, v3(0.024, 0.016, 0.014), k=0.005),
        Cone("crown", "head", v3(0, 0.575, -0.15), v3(0.004, 0.632, -0.19), 0.03, 0.003, k=0.016),
        Cone("crown1", "head", v3(-0.03, 0.57, -0.17), v3(-0.035, 0.612, -0.215), 0.022, 0.003, k=0.016),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.085, 0.375, -0.215), v3(0.105, 0.08, 0.095), k=0.04))
        for i, (a, b, r) in enumerate((((0.16, 0.39, -0.18), (0.215, 0.355, -0.15), 0.045),
                                       ((0.13, 0.34, -0.19), (0.175, 0.30, -0.17), 0.04))):
            p.append(Cone("ruff%s%d" % (sd, i), "head", mirror(a, sx), mirror(b, sx), r, 0.003, k=0.016))
        p += ear_prims(sd, sx)
        # front leg: a short post, the paw a little mitten
        sh = v3(sx * 0.072, 0.23, -0.10)
        el = v3(sx * 0.078, 0.12, -0.115)
        wr = v3(sx * 0.080, 0.042, -0.125)
        p.append(Cone("fleg1" + sd, "fleg1." + sd, sh, el, 0.046, 0.036, k=0.03))
        p.append(Cone("fleg2" + sd, "fleg2." + sd, el, wr, 0.036, 0.033, k=0.012))
        p.append(Ellipsoid("fpaw" + sd, "fpaw." + sd, v3(sx * 0.082, 0.026, -0.145), v3(0.04, 0.026, 0.05), k=0.016))
        # hind leg: a big round haunch over a long flat foot
        p.append(Ellipsoid("haunch" + sd, "hleg1." + sd, v3(sx * 0.105, 0.165, 0.10), v3(0.075, 0.105, 0.115), k=0.03))
        p.append(Cone("hleg2" + sd, "hleg2." + sd, v3(sx * 0.112, 0.105, 0.06), v3(sx * 0.115, 0.04, 0.15), 0.046, 0.036,
                      k=0.016))
        p.append(Ellipsoid("hpaw" + sd, "hpaw." + sd, v3(sx * 0.115, 0.028, 0.07), v3(0.046, 0.028, 0.105), k=0.018))
    for i, (a, b, r) in enumerate((((0.0, 0.205, -0.16), (0.0, 0.15, -0.19), 0.04),
                                   ((-0.045, 0.225, -0.155), (-0.055, 0.165, -0.18), 0.032),
                                   ((0.045, 0.225, -0.155), (0.055, 0.165, -0.18), 0.032))):
        p.append(Cone("chestfur%d" % i, "spine", v3(*a), v3(*b), r, 0.003, k=0.014))
    p.append(Ellipsoid("puff", "tail1", (TAIL_PTS[0] + TAIL_PTS[1]) * 0.5, v3(0.062, 0.06, 0.055), k=0.03))
    p.append(Ellipsoid("puff2", "tail2", TAIL_PTS[1] + v3(0, 0.0, 0.0), v3(0.05, 0.05, 0.045), k=0.03))
    return p


def wing_frame(sx):
    """Origin at the shoulder; u runs back along the body, v out and down across the folded wing, n out of it."""
    u = v3(0, 0.12, 1.0)
    u = u / np.linalg.norm(u)
    n = v3(sx * 0.75, 0.66, 0.0)
    n = n / np.linalg.norm(n)
    v = np.cross(n, u)
    v = v if v[0] * sx > 0 else -v
    return mirror(WING_S, sx), u, v, n


def wing_at(sx, uv):
    s, u, v, _ = wing_frame(sx)
    return s + u * uv[0] + v * uv[1]


def wing_prims():
    """A little bat wing folded on the back: an arm, three finger bones fanned from the wrist, a scalloped web."""
    out = []
    for sd, sx in SIDES:
        _, _, _, n = wing_frame(sx)
        at = {k: wing_at(sx, uv) for k, uv in WING_UV.items()}
        web = {"flat": 0.2, "flat_axis": n}
        for i, (a, b, ra, rb, bone) in enumerate((("S", "W", 0.03, 0.03, 1), ("W", "T1", 0.03, 0.012, 2),
                                                  ("W", "T2", 0.04, 0.02, 2), ("W", "T3", 0.04, 0.02, 2),
                                                  ("S", "B", 0.03, 0.03, 1), ("W", "B", 0.04, 0.03, 2),
                                                  ("B", "T3", 0.03, 0.02, 2), ("S", "T2", 0.04, 0.03, 1))):
            out.append(Cone("web%s%d" % (sd, i), "wing%d.%s" % (bone, sd), at[a], at[b], ra, rb, k=0.01, **web))
        for i, (a, b) in enumerate((("T1", "T2"), ("T2", "T3"), ("T3", "B"))):
            mid = (at[a] + at[b]) * 0.5
            away = mid - at["W"]
            c = mid + away / np.linalg.norm(away) * 0.026
            out.append(Ellipsoid("cut%s%d" % (sd, i), "wing2." + sd, c, v3(0.034, 0.034, 0.034), k=0.006, sub=True))
        out.append(Cone("arm" + sd, "wing1." + sd, at["S"], at["W"], 0.022, 0.016, k=0.01))
        for i, t in enumerate(("T1", "T2", "T3")):
            out.append(Cone("bone%s%d" % (sd, i), "wing2." + sd, at["W"], at[t], 0.012, 0.004, k=0.008))
        out.append(Cone("claw" + sd, "wing2." + sd, at["W"], at["W"] + wing_frame(sx)[2] * -0.03 + n * 0.006, 0.014,
                        0.003, k=0.006))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2700),
        "wings": (Shape(wing_prims()), 0.0035, 380),
        "ear_glow": (Shape(ear_glow_prims()), 0.0035, 125),
    }


# the tools are held in both forepaws: the grip between them, the handle running on from the arms, the blade on
# the edge that leads when the arms swing forward and down
GRIP = v3(0, 0.04, -0.17)
AXIS = np.array((0.0, -0.94, -0.34))


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS, -boki_tools.SIDE)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.05, 0.56, -0.2), (0.1, 0.68, -0.27), 0.032), "fang": ((0.022, 0.36, -0.33), (0.024, 0.322, -0.335), 0.013),
    "antenna": ((0.04, 0.565, -0.21), (0.08, 0.72, -0.3), 0.011), "brow": ((0.015, 0.53, -0.29), (0.13, 0.545, -0.25), 0.018),
    "head_top": (0, 0.58, -0.18), "fang_at": (0, 0.36, -0.32), "brow_at": (0, 0.53, -0.28), "third_eye": (0, 0.54, -0.29),
    "back": ((0, 0.335, -0.03), (0, 0.335, 0.06), (0, 0.31, 0.15)), "back_at": (0, 0.33, 0.05), "plates": (0, 0.33, 0.03),
    "plate_r": (0.12, 0.036, 0.08), "shell_c": (0, 0.215, 0.07), "shell_r": (0.15, 0.135, 0.06), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.06,
    "spots": ((0.13, 0.25, 0.0, 0.022), (0.17, 0.2, 0.09, 0.02), (0.16, 0.24, 0.15, 0.02)), "spots_at": (0, 0.22, 0.08),
    "wing": ((0.10, 0.33, 0.0), (0.28, 0.43, 0.10), (0.24, 0.39, 0.18)), "wing_at": (0, 0.33, 0.02),
    "fin": ((0.13, 0.22, 0.12), (0.17, 0.34, 0.24)), "fin_at": (0, 0.22, 0.12), "crest": (0.6, -0.22, 0.04, 0.06),
    "crest_at": (0, 0.6, -0.16),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
# the toon light darkens a deep coat: the data colour is the shade, the lit fur a step above it
BODY = hexc("5c6ec0")
BODY_LIGHT = hexc("7a8cdc")
BODY_DARK = hexc("4a5aa8")
BELLY = hexc("c9d2ff")
GLOW = hexc("7fe8ff")
WING = hexc("6e5ca8")
WING_LIGHT = hexc("ae9aea")
WING_DARK = hexc("4a3a7c")
EAR_TIP = hexc("3e3c80")
LILAC = hexc("dfe4ff")     # brows
LID = BODY
INK = hexc("1c1a3c")
BLUSH = hexc("ff8fb4")
NOSE = hexc("f27aa4")
MOUTH_DARK = hexc("4a1838")
TONGUE = hexc("f07a9a")
IRIS = hexc("ffc04a")


def ripples(p, sx, prim):
    """Sound rings on a haunch: three pale arcs spreading back from the hip."""
    c = np.array([sx * 0.14, 0.2, 0.03])
    d = np.linalg.norm((p - c) * np.array([0.6, 1.0, 1.0]), axis=1)
    band = sum(edge(0.006 - np.abs(d - r), 0.003) for r in (0.045, 0.075, 0.105))
    on = (prim["haunch" + ("L" if sx < 0 else "R")].d(p) < 0.01) & (p[:, 0] * sx > 0.12) & (p[:, 2] > c[2])
    return band * on


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    jag = (value_noise(p * np.array([70, 18, 70])) - 0.5) * 0.03
    fine = value_noise(p * np.array([110, 34, 110]))
    col = mixc(BODY_DARK, BODY, sat(n[:, 1] * 0.6 + 0.75))
    col = mixc(col, BODY_LIGHT, sat(n[:, 1] - 0.3) * 0.5 + (fine - 0.5) * 0.12)
    # muzzle and cheeks pale, a soft blaze up the nose
    head = (y > 0.3) & (z < -0.12)
    yb = np.interp(ax, [0, 0.03, 0.08, 0.15, 0.24], [0.43, 0.425, 0.40, 0.375, 0.34])
    mask = edge(yb + jag * 0.4 - y, 0.004) * head
    col = mixc(col, BELLY, mask)
    # chest, belly and the inside of the feet
    bib = edge(1.0 - (x / 0.09) ** 2 - ((y - 0.21) / 0.12) ** 2 + jag * 6, 0.05) * edge(-0.02 - z, 0.03)
    belly = edge(0.12 - y + jag, 0.006) * edge(0.085 - ax + jag, 0.008)
    feet = edge(0.04 - y + jag * 0.3, 0.004)
    col = mixc(col, BELLY, sat(bib + belly + feet) * (~head))
    for sx in (-1.0, 1.0):
        col = mixc(col, BODY_LIGHT * 1.15, ripples(p, sx, prim) * 0.85)
    # ears: dark tips, the scoop's lip pale
    for sd in "LR":
        tip = prim["ear3" + sd].d(p) < 0.02
        col = mixc(col, EAR_TIP, edge(y - 0.85 + jag * 1.2, 0.006) * tip)
        hole = prim["earhole" + sd].d(p)
        near = (prim["ear2" + sd].d(p) < 0.02) | (prim["ear1" + sd].d(p) < 0.02)
        col = mixc(col, BELLY, edge(0.008 - np.abs(hole), 0.003) * near)
    # puff of a tail
    col = mixc(col, BELLY, edge(0.01 - np.minimum(prim["puff"].d(p), prim["puff2"].d(p)), 0.006))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.13, 0.385, 0])) / np.array([0.045, 0.028, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.15) * 0.7)
    col = mixc(col, NOSE, edge(0.003 - prim["nose"].d(p), 0.0015))
    return col


def paint_wings(p, n, pc):
    """A velvet membrane, darker at the root, with ink-dark finger bones."""
    prims = {pr.name: pr for pr in pc.shape.prims}
    bone = np.min(np.stack([pr.d(p) for name, pr in prims.items() if name.startswith(("bone", "arm"))], -1), axis=1)
    root = np.minimum(np.linalg.norm(p - wing_at(1.0, WING_UV["W"]), axis=1),
                      np.linalg.norm(p - wing_at(-1.0, WING_UV["W"]), axis=1))
    col = mixc(WING_DARK, WING, sat(root / 0.06))
    col = mixc(col, WING_LIGHT, sat((root - 0.06) / 0.08) * 0.8)
    return mixc(col, WING_DARK * 0.8, edge(0.004 - bone, 0.002))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wings(q, nn, pc)
    if pc.name == "ear_glow":
        return np.tile(GLOW, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), WING_LIGHT, WING, WING_DARK)
    return tool_colour(pc.name, q)
