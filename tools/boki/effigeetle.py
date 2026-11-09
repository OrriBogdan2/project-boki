"""Effigeetle (goliathite), a cart-sized beetle whose wing cases are a marble statue's face: shapes and coat. Game axes
as vespyx.py. The two cases are their own pieces on their own bones, split down the statue's nose, so they open for
flight; amber wings fold away under them. A small white head with a gold Y horn, a striped thorax in a leather
harness with a grab bar, two hooked gold forelegs and four thick marble legs."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Prim, Shape, frame, smax, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.22, -0.32)
HEAD_R = v3(0.088, 0.088, 0.085)
EYE_YAW = 0.55
EYE_R = v3(0.026, 0.029, 0.018)
GLOW_PIECES = ("lids",)
BERRY_C = v3(0, 0.045, -0.5)
FACE = {"mouth_w": 0.024, "mouth_y": 0.172, "mouth_z": -0.392, "cat_mouth": True, "brow_x": 0.045, "brow_up": 0.012,
        "brow_k": 0.5, "fang_k": 0.0}
# the wing cases: one dome, cut flat underneath and split down the middle
CASE_C = v3(0, 0.33, 0.13)
CASE_R = v3(0.25, 0.23, 0.29)
CASE_FLOOR = 0.165     # m: the cases' lower rim
SEAM = 0.004           # m: half the gap between the cases
THORAX = (v3(0, 0.3, -0.06), v3(0, 0.255, -0.24), 0.15, 0.115)
ABDOMEN_C = v3(0, 0.2, 0.12)
ABDOMEN_R = v3(0.215, 0.085, 0.26)
# legs: (bone prefix, hip, knee, foot); the forelegs are the gold hooks
LEGS = (("fleg", v3(0.08, 0.17, -0.2), v3(0.17, 0.16, -0.31), v3(0.15, 0.012, -0.42)),
        ("mleg", v3(0.12, 0.16, 0.0), v3(0.21, 0.13, 0.0), v3(0.25, 0.012, 0.01)),
        ("hleg", v3(0.12, 0.16, 0.24), v3(0.2, 0.13, 0.26), v3(0.24, 0.012, 0.3)))
HORN = (v3(0, 0.27, -0.36), v3(0, 0.46, -0.42), v3(0.085, 0.6, -0.4))
HARNESS_C = v3(0, 0.29, -0.1)
HARNESS_R = 0.178
HANDLE_Y = 0.53
GRIP = v3(0, 0.2, -0.43)
AXIS = np.array((0.0, 0.5, -0.866))
WING = (v3(0.05, 0.45, 0.0), v3(0.46, 0.55, 0.12), v3(0.36, 0.5, 0.34))


class Clipped(Prim):
    """Another primitive kept only above the case floor and on one side of the seam (`sx`)."""

    def __init__(self, inner, sx, k=0.01):
        super().__init__(inner.name, inner.bone, k)
        self.inner, self.sx = inner, sx
        self.lo, self.hi = inner.lo.copy(), inner.hi.copy()
        # boxes carry 0.08 of padding, of which the mesher trims 0.05: keep 0.06 past the cuts
        self.lo[1] = max(self.lo[1], CASE_FLOOR - 0.06)
        if sx < 0:
            self.hi[0] = min(self.hi[0], 0.06)
        else:
            self.lo[0] = max(self.lo[0], -0.06)

    def d(self, p):
        d = smax(self.inner.d(p), CASE_FLOOR - p[..., 1], 0.012)
        return np.maximum(d, SEAM - self.sx * p[..., 0])


def on_case(x, y, lift=0.0):
    """The point on the cases' back (the statue's face) at x, y, raised `lift` off it."""
    q = 1.0 - (x / CASE_R[0]) ** 2 - ((y - CASE_C[1]) / CASE_R[1]) ** 2
    return v3(x, y, CASE_C[2] + CASE_R[2] * math.sqrt(max(q, 0.0)) + lift)


def _eye_dir(sx):
    return v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))


def _on_head(d, depth):
    d = d / np.linalg.norm(d)
    return HEAD_C + d * depth / np.linalg.norm(d / HEAD_R)


EYE_C = _on_head(_eye_dir(1.0), 0.86)


def eye_frame(sx):
    fr = frame(_eye_dir(sx), v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def mir(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def leg_pts(leg, sx):
    _, hip, knee, foot = leg
    return mir(hip, sx), mir(knee, sx), mir(foot, sx)


def body_prims():
    """Head, striped thorax, the bronze belly under the cases, and the four marble legs on black hips."""
    a, b, ra, rb = THORAX
    p = [Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.02),
         Cone("thorax", "spine", a, b, ra, rb, k=0.03),
         Ellipsoid("abdomen", "hips", ABDOMEN_C, ABDOMEN_R, k=0.03)]
    for sd, sx in SIDES:
        for pre, _, _, _ in LEGS[1:]:
            hip, knee, foot = leg_pts(next(lg for lg in LEGS if lg[0] == pre), sx)
            p.append(Ellipsoid("coxa" + pre + sd, pre + "1." + sd, (hip + knee) * 0.5, v3(0.06, 0.042, 0.05),
                               rot=frame(knee - hip, v3(0, 1, 0)), k=0.012))
            ankle = foot + (knee - foot) * 0.2
            p.append(Cone("leg" + pre + sd, pre + "2." + sd, knee, ankle, 0.045, 0.04, k=0.01))
            p.append(Cone("foot" + pre + sd, pre.replace("leg", "paw") + "." + sd, ankle,
                          foot + v3(sx * 0.01, 0.028, -0.03), 0.04, 0.03, k=0.01))
    return p


def arm_prims():
    """The hooked gold forelegs, a row of spurs down the outside, black hooks at the tips."""
    out = []
    for sd, sx in SIDES:
        hip, knee, foot = leg_pts(LEGS[0], sx)
        ankle = foot + (knee - foot) * 0.3
        hook = foot + v3(-sx * 0.035, 0.0, 0.03)
        out += [Cone("fa1" + sd, "fleg1." + sd, hip, knee, 0.032, 0.03, k=0.012),
                Cone("fa2" + sd, "fleg2." + sd, knee, ankle, 0.03, 0.024, k=0.01),
                Cone("fa3" + sd, "fpaw." + sd, ankle, foot, 0.024, 0.016, k=0.008),
                Cone("hook" + sd, "fpaw." + sd, foot, hook, 0.016, 0.005, k=0.006)]
        for j, (bone, a, b, f) in enumerate((("fleg1.", hip, knee, 0.6), ("fleg2.", knee, ankle, 0.35),
                                             ("fleg2.", knee, ankle, 0.8))):
            at = a + (b - a) * f
            d = (b - a) / np.linalg.norm(b - a)
            out_dir = np.cross(d, v3(0, 1, 0))
            out_dir = out_dir * (1 if out_dir[0] * sx > 0 else -1) / np.linalg.norm(out_dir)
            tip = at + out_dir * 0.045 + v3(0, 0.02, 0)
            out.append(Cone("spur%d%s" % (j, sd), bone + sd, at, tip, 0.014, 0.003, k=0.004))
    return out


def horn_prims():
    """The gold Y horn: a thick stalk rising off the front of the head, forking at the top."""
    base, fork, tip = HORN
    p = [Cone("stalk", "head", base, fork, 0.034, 0.022, k=0.0)]
    for sd, sx in SIDES:
        p.append(Cone("prong" + sd, "head", fork, mir(tip, sx), 0.021, 0.008, k=0.012))
    return p


def harness_prims():
    """A leather band round the thorax where the cases begin, and a grab bar on top."""
    p = []
    n = 14
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        pa = HARNESS_C + v3(math.sin(a0), math.cos(a0), 0) * HARNESS_R
        pb = HARNESS_C + v3(math.sin(a1), math.cos(a1), 0) * HARNESS_R
        radial = v3(math.sin(a0 + math.pi / n), math.cos(a0 + math.pi / n), 0)
        p.append(Cone("band%d" % i, "spine", pa, pb, 0.024, 0.024, k=0.004, flat=0.45, flat_axis=radial))
    top = HARNESS_C[1] + HARNESS_R
    for sd, sx in SIDES:
        p.append(Cone("post" + sd, "spine", v3(sx * 0.06, top - 0.01, -0.1), v3(sx * 0.06, HANDLE_Y, -0.1), 0.014,
                      0.013, k=0.006))
    p.append(Cone("bar", "spine", v3(-0.06, HANDLE_Y, -0.1), v3(0.06, HANDLE_Y, -0.1), 0.014, 0.014, k=0.008))
    return p


def case_prims(sx):
    """One wing case: its half of the dome and of the statue's face (brow, nose, cheek, lips)."""
    sd = "L" if sx < 0 else "R"
    bone = "case." + sd
    feats = [Ellipsoid("dome", bone, CASE_C, CASE_R, k=0.0),
             Cone("nose", bone, on_case(0, 0.43, -0.004), on_case(0, 0.31, 0.012), 0.012, 0.024, k=0.012),
             Ellipsoid("tip", bone, on_case(0, 0.305, 0.004), v3(0.03, 0.02, 0.018), k=0.012),
             Cone("brow", bone, on_case(sx * 0.012, 0.44, 0.0), on_case(sx * 0.11, 0.425, -0.004), 0.013, 0.008,
                  k=0.014),
             Ellipsoid("cheek", bone, on_case(sx * 0.1, 0.31, -0.012), v3(0.05, 0.045, 0.025), k=0.03),
             Ellipsoid("lip_u", bone, on_case(0, 0.262, 0.0), v3(0.046, 0.011, 0.014), k=0.008),
             Ellipsoid("lip_l", bone, on_case(0, 0.24, -0.002), v3(0.04, 0.012, 0.014), k=0.008),
             Ellipsoid("chin", bone, on_case(0, 0.205, -0.01), v3(0.04, 0.022, 0.02), k=0.02)]
    return [Clipped(f, sx, k=f.k) for f in feats]


def lid_prims():
    """The statue's closed eyes, a soft downward arc each, glowing amber in the seam of the lids."""
    out = []
    for sd, sx in SIDES:
        pts = [on_case(sx * x, y, 0.001) for x, y in ((0.03, 0.385), (0.065, 0.372), (0.1, 0.383))]
        out += [Cone("lid0" + sd, "case." + sd, pts[0], pts[1], 0.006, 0.007, k=0.004),
                Cone("lid1" + sd, "case." + sd, pts[1], pts[2], 0.007, 0.005, k=0.004)]
    return out


def parts():
    out = {"body": (Shape(body_prims()), 0.003, 1280),
           "arms": (Shape(arm_prims()), 0.0025, 370),
           "horn": (Shape(horn_prims()), 0.003, 170),
           "harness": (Shape(harness_prims()), 0.003, 260),
           "lids": (Shape(lid_prims()), 0.002, 60)}
    for sd, sx in SIDES:
        out["case_" + sd] = (Shape(case_prims(sx)), 0.0035, 640)
    return out


def wing_prims(sx):
    root, t0, t1 = (mir(q, sx) for q in WING)
    n = v3(0, 1, 0.15)
    bone = "prop_wing." + ("L" if sx < 0 else "R")
    return [Cone("w0", bone, root, t0, 0.05, 0.04, k=0.0, flat=0.16, flat_axis=n),
            Cone("w1", bone, root, t1, 0.05, 0.05, k=0.05, flat=0.16, flat_axis=n)]


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    for sd, sx in SIDES:
        out["wing_" + sd] = (Shape(wing_prims(sx)), 0.004, 70)
    return out


GROWN = {
    "horn": ((0.05, 0.29, -0.3), (0.1, 0.38, -0.3), 0.022), "fang": ((0.025, 0.16, -0.38), (0.028, 0.12, -0.39), 0.01),
    "antenna": ((0.04, 0.29, -0.36), (0.12, 0.38, -0.44), 0.009), "brow": ((0.015, 0.28, -0.39), (0.07, 0.285, -0.37),
                                                                           0.012),
    "head_top": (0, 0.3, -0.32), "fang_at": (0, 0.16, -0.38), "brow_at": (0, 0.28, -0.38), "third_eye": (0, 0.27, -0.39),
    "back": ((0, 0.56, 0.0), (0, 0.565, 0.13), (0, 0.55, 0.26)), "back_at": (0, 0.56, 0.12), "plates": (0, 0.56, 0.0),
    "plate_r": (0.08, 0.025, 0.08), "shell_c": (0, 0.4, 0.13), "shell_r": (0.2, 0.15, 0.22), "tail_bone": "hips",
    "club_at": (0, 0.2, 0.4), "club_dir": (0, 0.0, 0.08), "club_r": 0.05,
    "spots": ((0.12, 0.45, 0.0, 0.02), (0.17, 0.4, 0.15, 0.02), (0.14, 0.42, 0.3, 0.018)), "spots_at": (0, 0.42, 0.13),
    "wing": ((0.05, 0.45, 0.0), (0.2, 0.52, 0.14), (0.14, 0.48, 0.26)), "wing_at": (0, 0.45, 0.0),
    "fin": ((0.2, 0.2, 0.3), (0.24, 0.3, 0.38)), "fin_at": (0, 0.2, 0.3), "crest": (0.3, -0.33, 0.04, 0.05),
    "crest_at": (0, 0.3, -0.33),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
MARBLE = hexc("f2f0ec")
MARBLE_SHADE = hexc("c8c7c6")
VEIN = hexc("8c8a94")
WHITE = hexc("f6f6f8")
WHITE_SHADE = hexc("bdbcc2")
STRIPE = hexc("26242a")
BRONZE = hexc("9a7444")
BRONZE_DARK = hexc("5e4428")
GOLD_LIGHT = hexc("f0d27a")
GOLD = hexc("c9a24a")
GOLD_DARK = hexc("7a5a22")
LEATHER = hexc("7a4a2a")
LEATHER_DARK = hexc("4a2a16")
RIVET = hexc("d8b060")
CLAW = hexc("1c1a1e")
AMBER = hexc("ffb43a")
WING_AMBER = hexc("e9a640")
WING_VEIN = hexc("9a5a1c")
BLUSH = hexc("f0a8b0")
LILAC = hexc("d6d2dc")     # brows
LID = WHITE
INK = hexc("15141e")
MOUTH_DARK = hexc("4a1a36")
TONGUE = hexc("e87aa8")
IRIS = hexc("f0a020")
IRIS_DEEP = hexc("8a4a08")
GROWN_A = hexc("f0d27a")
GROWN_B = hexc("c9a24a")
GROWN_C = hexc("5e4428")


def nearest(pc, q):
    prims = [pr for pr in pc.shape.prims if not pr.sub]
    return [prims[i].name for i in np.argmin(np.stack([pr.d(q) for pr in prims], -1), -1)]


def paint_marble(q, n):
    """White marble with grey veins: thin lines where a turbulent sine crosses zero; shaded under the curve."""
    turb = value_noise(q * 7.0) + 0.5 * value_noise(q * 17.0 + 3.0) + 0.25 * value_noise(q * 41.0 + 9.0)
    t = np.sin((q[:, 0] * 0.8 + q[:, 1] * 1.3 + q[:, 2] * 0.4) * 22.0 + turb * 7.0)
    vein = edge(0.08 - np.abs(t), 0.03)
    fine = edge(0.05 - np.abs(np.sin(q[:, 1] * 40.0 - q[:, 0] * 25.0 + turb * 9.0)), 0.02) * 0.35
    col = mixc(MARBLE_SHADE, MARBLE, sat(n[:, 1] * 0.6 + 0.75))
    col = mixc(col, VEIN, np.maximum(vein * 0.75, fine))
    # the statue's carved lines: the parting of the lips and the nostrils, in shadow
    back = q[:, 2] > CASE_C[2] + 0.2
    lips = edge(0.005 - np.abs(q[:, 1] - 0.252), 0.003) * edge(0.042 - np.abs(q[:, 0]), 0.01)
    nost = edge(0.007 - np.hypot(np.abs(q[:, 0]) - 0.014, q[:, 1] - 0.3), 0.003)
    return mixc(col, hexc("6e6a72"), np.maximum(lips, nost * 0.7) * back)


def paint_body(q, n, pc):
    names = np.array(nearest(pc, q))
    col = mixc(WHITE_SHADE, WHITE, sat(n[:, 1] * 0.6 + 0.75))
    thorax = names == "thorax"
    if thorax.any():
        a, _, _, _ = THORAX
        ang = np.arctan2(q[:, 0] - a[0], q[:, 1] - a[1])
        band = edge(np.sin(ang * 7.0), 0.15)
        tc = mixc(STRIPE, col, band)
        # the black ring where the head sits in
        tc = mixc(tc, STRIPE, edge(-0.215 - q[:, 2], 0.006))
        col[thorax] = tc[thorax]
    belly = names == "abdomen"
    col[belly] = mixc(BRONZE_DARK, BRONZE, sat(n[:, 1] * 0.5 + 0.6 + (value_noise(q * 60) - 0.5) * 0.3))[belly]
    coxa = np.char.startswith(names, "coxa")
    col[coxa] = mixc(CLAW, hexc("3a383e"), sat(n[:, 1] * 0.5 + 0.5))[coxa]
    for sx in (-1.0, 1.0):
        b = (q - (HEAD_C + v3(sx * 0.055, -0.035, -0.06))) / np.array([0.022, 0.012, 1.0])
        col = mixc(col, BLUSH, np.exp(-(b[:, 0] ** 2 + b[:, 1] ** 2) * 1.2) * (q[:, 2] < -0.36) * 0.5)
    return col


def paint_gold(q, n, dark_tip=None):
    col = paint_shell(q, n, np.full(len(q), 1.0), GOLD_LIGHT, GOLD, GOLD_DARK)
    return col


def paint_arms(q, n, pc):
    names = np.array(nearest(pc, q))
    col = paint_gold(q, n)
    hook = np.char.startswith(names, "hook") | np.char.startswith(names, "fa3")
    tip = np.zeros(len(q))
    for sx in (-1.0, 1.0):
        foot = mir(LEGS[0][3], sx)
        tip = np.maximum(tip, edge(0.05 - np.linalg.norm(q - foot, axis=-1), 0.008))
    return mixc(col, CLAW, np.maximum(tip, hook * 0.0))


def paint_harness(q, n, pc):
    names = np.array(nearest(pc, q))
    col = mixc(LEATHER_DARK, LEATHER, sat(n[:, 1] * 0.5 + 0.7 + (value_noise(q * 90) - 0.5) * 0.25))
    # brass rivets at the band's sides and on the grab bar's posts
    rivet = np.zeros(len(q))
    for c in (HARNESS_C + v3(-HARNESS_R, 0, -0.02), HARNESS_C + v3(HARNESS_R, 0, -0.02),
              v3(-0.06, HARNESS_C[1] + HARNESS_R, -0.125), v3(0.06, HARNESS_C[1] + HARNESS_R, -0.125)):
        rivet = np.maximum(rivet, edge(0.014 - np.linalg.norm(q - c, axis=-1), 0.003))
    post = np.char.startswith(names, "post") | (names == "bar")
    col = mixc(col, LEATHER_DARK, post * 0.25)
    return mixc(col, RIVET, rivet)


def paint_wing(q, n):
    v = value_noise(q * np.array([60, 10, 60]))
    return mixc(WING_AMBER, WING_VEIN, edge(0.03 - np.abs(v - 0.5), 0.01) * 0.7)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, pc)
    if pc.name.startswith("case_"):
        return paint_marble(q, nn)
    if pc.name == "arms":
        return paint_arms(q, nn, pc)
    if pc.name == "horn":
        return paint_gold(q, nn)
    if pc.name == "harness":
        return paint_harness(q, nn, pc)
    if pc.name.startswith("wing_"):
        return paint_wing(q, nn)
    if pc.name in GLOW_PIECES:
        return np.tile(AMBER, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(AMBER, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), GROWN_A, GROWN_B, GROWN_C)
    return tool_colour(pc.name, q)
