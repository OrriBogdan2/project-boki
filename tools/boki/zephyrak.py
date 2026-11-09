"""Zephyrak (zephyrak), a moray eel with a swift's wings, crackling with static: shapes and coat. Game axes as
vespyx.py. No legs: the body is one chain from the head back to a forked tail and floats a hand above the ground."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.9
HEAD_C = v3(0, 0.375, -0.255)
HEAD_R = v3(0.225, 0.18, 0.21)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


EYE_C = hd(0.108, 0.028, -0.166)
EYE_R = v3(0.05, 0.056, 0.034)
EYE_YAW = 0.46
GLOW_PIECES = ("ridge", "sparks")
PALE_PIECES = ("wings", "fins", "tail_fin")
BERRY_C = v3(0, 0.05, -0.47)
FACE = {"mouth_w": 0.112, "mouth_y": HEAD_C[1] - 0.064, "mouth_z": HEAD_C[2] - 0.235, "cat_mouth": False,
        "brow_x": 0.104, "brow_up": 0.022, "brow_k": 0.8, "fang_k": 0.0}
# the body chain, head to tail: joints and the body's radius there; segment i rides BODY_BONES[i]
SPINE = [v3(0, 0.355, -0.155), v3(0, 0.285, -0.085), v3(0, 0.22, -0.015), v3(0, 0.175, 0.06), v3(0, 0.16, 0.135),
         v3(0, 0.165, 0.21), v3(0, 0.18, 0.275), v3(0, 0.198, 0.33), v3(0, 0.222, 0.375), v3(0, 0.25, 0.41)]
SPINE_R = [0.12, 0.112, 0.104, 0.096, 0.088, 0.078, 0.066, 0.054, 0.043, 0.032]
BODY_BONES = ["neck", "spine", "hips", "tail1", "tail2", "tail3", "tail4", "tail5", "tail6"]
TAIL_N = 6
# a swift's wing: shoulder, wrist, tip (right side; mirrored)
WING = (v3(0.07, 0.30, -0.04), v3(0.205, 0.38, -0.015), v3(0.47, 0.43, 0.17))
GRIP = hd(0, -0.085, -0.215)
AXIS = np.array((0.0, 0.5, -0.866))


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.12, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def chain_prims():
    """The eel: round cones joint to joint, a touch narrower than tall."""
    out = []
    for i, bone in enumerate(BODY_BONES):
        out.append(Cone("seg%d" % i, bone, SPINE[i], SPINE[i + 1], SPINE_R[i], SPINE_R[i + 1], k=0.03, flat=0.9,
                        flat_axis=v3(1, 0, 0)))
    return out


def head_prims():
    p = [
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("snout", "head", hd(0, -0.03, -0.125), v3(0.155, 0.095, 0.122), k=0.05),
        # the soft underbite: the chin sits a little ahead of the snout
        Ellipsoid("jaw", "head", hd(0, -0.1, -0.098), v3(0.16, 0.07, 0.148), k=0.045),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", hd(sx * 0.128, -0.06, -0.02), v3(0.112, 0.095, 0.115), k=0.04))
    return p


def ear_fin(sx):
    """A frilled fin behind the cheek: its root, upper tip and back tip."""
    return hd(sx * 0.18, -0.02, 0.07), hd(sx * 0.29, 0.085, 0.13), hd(sx * 0.305, -0.01, 0.18)


def ear_fin_prims():
    """Two little frilled fins behind the cheeks (the ears its Unique rolls bend)."""
    out = []
    for sd, sx in SIDES:
        base, up, back = ear_fin(sx)
        n = np.cross(up - base, back - base) * sx
        out.append(Cone("fu" + sd, "ear1." + sd, base, up, 0.042, 0.010, k=0.02, flat=0.28, flat_axis=n))
        out.append(Cone("fb" + sd, "ear1." + sd, base, back, 0.040, 0.010, k=0.02, flat=0.28, flat_axis=n))
    return out


def wing_line(sx):
    """The wing's spine, shoulder to tip, as (point, radius, bone), and the wing's normal."""
    root, wrist, tip = (v3(sx * q[0], q[1], q[2]) for q in WING)
    n = np.cross(v3(0, 0, 1), tip - root) * sx      # level along the chord, tipped up along the span
    n = n / np.linalg.norm(n)
    mid = wrist + (tip - wrist) * 0.45 + v3(0, 0, -0.01)
    return [(root, 0.055, "wing1"), (wrist, 0.058, "wing2"), (mid, 0.042, "wing2"), (tip, 0.005, "wing2")], n


def trailing(pts, n, k):
    """Points along the back edge of a wing line, k of the radius out."""
    out = []
    for i, (q, r, _) in enumerate(pts):
        d = pts[min(i + 1, len(pts) - 1)][0] - pts[max(i - 1, 0)][0]
        b = np.cross(n, d)
        b = b / np.linalg.norm(b) * (1 if b[2] > 0 else -1)
        out.append(q + b * r * k)
    return out


def wing_prims():
    """A swift's sickle wing: a broad arm, long tapering primaries, the secondaries filling the back edge."""
    out = []
    for sd, sx in SIDES:
        pts, n = wing_line(sx)
        flat = {"flat": 0.16, "flat_axis": n}
        for i in range(len(pts) - 1):
            (a, ra, bone), (b, rb, _) = pts[i], pts[i + 1]
            out.append(Cone("w%d%s" % (i, sd), "%s.%s" % (bone, sd), a, b, ra, rb, k=0.02, **flat))
        back = trailing(pts, n, 0.55)
        out.append(Cone("wd" + sd, "wing1." + sd, back[0], back[1] + (back[2] - back[1]) * 0.3, 0.045, 0.04, k=0.03,
                        **flat))
    return out


def ridge_prims():
    """Static along the back: a sawtooth fin of little sparks from the crown to the tail, and the crest on the head."""
    side = v3(1, 0, 0)
    out = []
    for i, (y, z, h) in enumerate(((0.165, -0.06, 0.085), (0.175, 0.01, 0.075), (0.15, 0.08, 0.06))):
        out.append(Cone("crest%d" % i, "head", hd(0, y - 0.04, z), hd(0, y + h, z + 0.05), 0.034, 0.004, k=0.0,
                        flat=0.32, flat_axis=side))
    for i in range(1, len(BODY_BONES) - 1):
        a, b = SPINE[i], SPINE[i + 1]
        r = (SPINE_R[i] + SPINE_R[i + 1]) * 0.5
        c = (a + b) * 0.5
        h = 0.03 + 0.5 * r
        out.append(Cone("r%d" % i, BODY_BONES[i], c + v3(0, r * 0.7, -0.01), c + v3(0, r + h * 0.75, 0.035), r * 0.32,
                        0.003, k=0.0, flat=0.3, flat_axis=side))
    return out


def tail_fin_prims():
    """A swift's forked tail: two streamers splayed flat behind the last joint."""
    end = SPINE[-1]
    out = []
    for sd, sx in SIDES:
        out.append(Cone("fork" + sd, "tail6", end - v3(0, 0.005, 0.045), end + v3(sx * 0.105, 0.03, 0.12), 0.046, 0.006,
                        k=0.025, flat=0.22, flat_axis=v3(0, 1, -0.3)))
    return out


def spark_prims():
    """The glowing back edge of each wing, from the wrist out to the tip."""
    out = []
    for sd, sx in SIDES:
        pts, n = wing_line(sx)
        edge_pts = trailing(pts, n, 0.92)
        for i in range(1, len(pts) - 1):
            out.append(Cone("s%d%s" % (i, sd), "wing2." + sd, edge_pts[i] + n * 0.003, edge_pts[i + 1] + n * 0.003,
                            0.011, 0.011 if i < len(pts) - 2 else 0.004, k=0.01))
    return out


def body_prims():
    return chain_prims() + head_prims()


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2200),
        "fins": (Shape(ear_fin_prims()), 0.0035, 125),
        "wings": (Shape(wing_prims()), 0.0035, 480),
        "tail_fin": (Shape(tail_fin_prims()), 0.0035, 110),
        "ridge": (Shape(ridge_prims()), 0.0035, 175),
        "sparks": (Shape(spark_prims()), 0.0035, 90),
    }


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.085, 0.115, -0.015), hd(0.15, 0.255, -0.075), 0.036),
    "fang": (hd(0.05, -0.10, -0.19), hd(0.055, -0.145, -0.195), 0.015),
    "antenna": (hd(0.06, 0.125, -0.035), hd(0.13, 0.295, -0.115), 0.012),
    "brow": (hd(0.02, 0.105, -0.14), hd(0.15, 0.115, -0.09), 0.018),
    "head_top": hd(0, 0.145, -0.015), "fang_at": hd(0, -0.095, -0.185), "brow_at": hd(0, 0.095, -0.125),
    "third_eye": hd(0, 0.105, -0.135), "back_at": (0, 0.275, 0.08), "plates": (0, 0.285, 0.06),
    "back": ((0, 0.31, 0.02), (0, 0.275, 0.11), (0, 0.255, 0.20)),
    "plate_r": (0.115, 0.035, 0.08), "shell_c": (0, 0.19, 0.09), "shell_r": (0.12, 0.12, 0.06), "tail_bone": "tail5",
    "club_at": tuple(SPINE[8]), "club_dir": tuple(SPINE[9] - SPINE[7]), "club_r": 0.06,
    "spots": ((0.096, 0.19, 0.08, 0.022), (0.088, 0.18, 0.16, 0.02), (0.076, 0.18, 0.24, 0.018)),
    "spots_at": (0, 0.18, 0.16),
    "wing": ((0.06, 0.25, 0.15), (0.22, 0.34, 0.23), (0.19, 0.30, 0.29)), "wing_at": (0, 0.25, 0.15),
    "fin": ((0.075, 0.16, 0.22), (0.135, 0.10, 0.31)), "fin_at": (0, 0.16, 0.22),
    "crest": (HEAD_C[1] + 0.135, HEAD_C[2] + 0.085, 0.05, 0.06),
    "crest_at": hd(0, 0.135, 0.085),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
BLUE = hexc("2f6f9a")
BLUE_LIGHT = hexc("4f93bf")
BLUE_DARK = hexc("1f4d72")
BELLY = hexc("d6f4ff")
MASK = hexc("8cc6e6")
WING_C = hexc("bfe8ff")
GLOW = hexc("9ff4ff")
LILAC = hexc("d6f4ff")     # brows
INK = hexc("142c44")
LID = mixc(BLUE, MASK, np.array(0.55))
BLUSH = hexc("ff8fb4")
MOUTH_DARK = hexc("5a1f3c")
TONGUE = hexc("ff8aa8")
IRIS = hexc("ffc93a")
SHELL_A = hexc("9fd8f6")
SHELL_B = hexc("3f82b0")
SHELL_C = hexc("1f4d72")


def paint_body(p, n):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    fine = value_noise(p * np.array([60, 40, 60]))
    col = mixc(BLUE_DARK, BLUE, sat(n[:, 1] * 0.7 + 0.75))
    col = mixc(col, BLUE_LIGHT, sat(n[:, 1] - 0.35) * 0.55 + (fine - 0.5) * 0.12)
    # a pale sky mask round the eyes, so they read on the dark head from far off
    face = z < HEAD_C[2] - 0.06
    for sx in (-1.0, 1.0):
        q = (p - EYE_C * np.array([sx, 1, 1])) / np.array([0.058, 0.056, 1.0])
        col = mixc(col, MASK, edge(1.0 - np.hypot(q[:, 0], q[:, 1]), 0.14) * face * 0.5)
    # the pale belly runs from the chin to the tail; on the head it is the jaw below the smile
    jag = (value_noise(p * 30) - 0.5) * 0.06
    nape = HEAD_C[2] + 0.11
    belly = edge(-n[:, 1] - 0.12 + jag, 0.05) * (z > nape)
    jaw = edge(FACE["mouth_y"] - 0.014 - y, 0.005) * (z < nape) * edge(0.145 - np.abs(x), 0.02)
    throat = edge(-n[:, 1] - 0.15, 0.05) * (z < nape)
    col = mixc(col, BELLY, sat(belly + jaw + throat))
    # moray freckles along the back: soft pale spots
    sp = value_noise(p * 26 + 3.1)
    back = sat(n[:, 1] * 2.0 - 0.3) * (z > nape)
    col = mixc(col, mixc(BLUE_LIGHT, BELLY, np.full(len(p), 0.45)), edge(sp - 0.72, 0.02) * back * 0.8)
    for sx in (-1.0, 1.0):
        q = (p - hd(sx * 0.15, -0.025, 0)) / np.array([0.05, 0.03, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < HEAD_C[2] - 0.045) * 0.7)
    for sx in (-1.0, 1.0):       # nostrils
        q = np.hypot(x - sx * 0.04, y - HEAD_C[1] + 0.012)
        col = mixc(col, INK, edge(0.0065 - q, 0.002) * (z < HEAD_C[2] - 0.17) * 0.7)
    return col


def paint_wing(p, n):
    """Coverts in the body's blue by the shoulder, long pale primaries with fine dark seams, a cyan trailing edge."""
    ax, y, z = np.abs(p[:, 0]), p[:, 1], p[:, 2]
    jag = (value_noise(p * 50) - 0.5) * 0.02
    cov = edge(0.165 + z * 0.35 - ax + jag, 0.008)
    seam = np.abs(((z * 0.82 - ax * 0.58) / 0.045) % 1.0 - 0.5)
    col = mixc(np.tile(WING_C, (len(p), 1)), WING_C * 0.82, edge(0.07 - seam, 0.02) * edge(ax - 0.2, 0.01))
    col = mixc(col, mixc(BLUE, BLUE_LIGHT, sat(n[:, 1])), cov)
    return mixc(col, BELLY, sat(-n[:, 1]) * 0.25)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name == "wings":
        return paint_wing(q, nn)
    if pc.name in ("fins", "tail_fin"):
        tip = sat((np.abs(q[:, 0]) - 0.2) / 0.08) if pc.name == "fins" else sat((q[:, 2] - 0.5) / 0.06)
        return mixc(np.tile(WING_C, (len(q), 1)), GLOW, tip)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    if pc.name in GLOW_PIECES:
        return np.tile(GLOW, (len(q), 1))
    return tool_colour(pc.name, q)
