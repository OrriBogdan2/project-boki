"""Pip's animation set (hand-keyed as targets, solved by posekit). Times are the kit's: the "mm_" table in scripts/match/kmoves_care.gd and
content/archetypes/tender.json. Personality: a brave little field medic, afraid of the dark. Quick, light steps, big ears, everything leans on
the lantern: she keeps it close, checks the dark over her shoulder, and when she must she thrusts it out like a shield. She weighs nothing: a
hit throws the ears first, a landing is a bounce.
The lantern hangs from her right fist on spring_hanglantern_* (the runtime's hang chain), so the right hand is posed as a hook: G is the ring's
pivot, BE the way the fingers point. The left hand is free; "Lh" turns it from the chest's frame.
Run: blender -b --python tools/art1/pip_clips.py -- <pip_art1.blend> <out.glb> [clip,clip]"""
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, ang_dir as D, at, bake, eul, FPS
import pip_sculpt as K
import crouchkit
from crouchkit import off

A = K.ANKLE_Z
SH = K.SH
SZ = float(K.J["upper_arm.R"][2])
HOOK = (0.04, 0.0, -1.0)
FRONT = (0, 1, 0)
UP = (0, 0, 1)


def be(d=HOOK, e=FRONT):
    return (d, e)


READY = {
    "pel": (0.0, 0.0, -0.022), "prt": (0.03, 0.08, -0.02), "tor": (0.05, 0.06, 0.02), "hed": (-0.06, -0.10, 0.03),
    "G": (SH + 0.16, 0.17, 0.875), "BE": be(), "Lw": 0.0, "LP": (-0.20, 0.205, 0.745), "Lh": (-0.5, -0.6, 0.0),
    "FL": (-0.122, 0.035, A), "FR": (0.13, -0.035, A), "FLy": 0.16, "FRy": -0.22, "FLp": 0.0, "FRp": 0.0,
    "brow": -0.25, "lid": 0.0, "jaw": 0.0, "ear": 0.0, "earR": 0.0, "earL": 0.0, "fing": 0.35, "skirt": 0.0, "wing": 0.0, "wfl": 0.03, "wfq": 1.0, "wb": 0.0,
}
LOW = {"pel": (0.0, -0.01, -0.09), "prt": (0.2, 0, 0), "tor": (0.22, 0, 0)}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


END = {k: v for k, v in READY.items()}


# ---- idle: the lantern held close, a slow breath; she checks the dark over her left shoulder, then her right, and takes a small breath of courage
def idle(u):
    s = math.sin(u * 2 * math.pi)
    c = math.cos(u * 2 * math.pi)
    p = dict(READY)
    p["pel"] = (0.004 * c, 0.0, -0.022 - 0.007 * s)
    p["tor"] = (0.05 + 0.03 * s, 0.06, 0.02)
    look = -1.0 * bump(u, 0.16, 0.36) + 0.8 * bump(u, 0.50, 0.68)
    p["hed"] = (-0.06 - 0.02 * s, -0.10 + 0.72 * look * -1, 0.03 - 0.08 * look)
    p["ear"] = 0.14 * abs(look)
    p["earL"] = 0.5 * bump(u, 0.17, 0.25) - 0.35 * bump(u, 0.84, 0.9)
    p["earR"] = 0.5 * bump(u, 0.54, 0.62)
    p["brow"] = -0.25 - 0.6 * abs(look)
    p["lid"] = -0.08 * abs(look) + (0.95 if 0.42 < u < 0.455 or 0.90 < u < 0.93 else 0.0)
    g = READY["G"]
    lift = 0.03 * abs(look)
    p["G"] = (g[0] - 0.03 * abs(look), g[1] + 0.02 * abs(look), g[2] + 0.008 * s + lift)
    p["LP"] = (-0.20, 0.205, 0.745 + 0.008 * s)
    p["wfl"] = 0.03
    return p


def bump(u, a, b):
    if u <= a or u >= b:
        return 0.0
    x = (u - a) / (b - a)
    return math.sin(x * math.pi) ** 2


# ---- the signature stance: both paws round the lantern, hugged to her chest; eyes dart at the dark; a deep breath, and she lifts it high
def stance(u):
    p = dict(READY)
    s = math.sin(u * 2 * math.pi)
    hug = 1.0 - bump(u, 0.52, 0.92)
    high = bump(u, 0.55, 0.9)
    p["pel"] = (0.0, 0.0, -0.05 + 0.03 * high)
    p["prt"] = (0.08 - 0.1 * high, 0.0, 0.0)
    p["tor"] = (0.14 - 0.26 * high, 0.0, 0.0)
    dart = math.sin(u * 2 * math.pi * 3) * hug
    p["hed"] = (0.12 * hug - 0.2 * high, 0.34 * dart, 0.0)
    p["G"] = (0.075 + 0.28 * high, 0.19 + 0.04 * high, 0.905 + 0.42 * high)
    p["BE"] = be((0.0, 0.1, -1.0))
    p["LP"] = (-0.13 - 0.1 * high, 0.20 - 0.02 * high, 0.90 - 0.16 * high)
    p["Lh"] = (-1.1 + 0.6 * high, 0.9, 0.0)
    p["fing"] = 0.8 - 0.4 * high
    p["ear"] = 0.55 * hug
    p["earL"] = 0.25 * max(dart, 0)
    p["earR"] = 0.25 * max(-dart, 0)
    p["brow"] = -0.9 * hug + 0.6 * high
    p["lid"] = -0.12 * hug + (0.95 if 0.48 < u < 0.52 else 0.0)
    p["FL"], p["FR"] = (-0.105, 0.03, A), (0.11, 0.0, A)
    p["FLy"], p["FRy"] = 0.3, -0.34
    p["wing"] = 0.22 * high - 0.1 * hug
    p["wfl"] = 0.03 + 0.1 * high
    return p


# ---- locomotion
def gait(k, heading):
    """k 0.45 walk .. 1 run. Quick, light, up on the toes; the lantern carried out of her stride; the free paw pumps."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    stride = 0.09 + 0.135 * k
    lift = 0.04 + 0.10 * k
    share = 0.60 - 0.22 * k
    back = max(0.0, -d.y)
    fwd = max(0.0, d.y)

    def foot(ph, sx):
        ph %= 1.0
        base = Vector((sx * 0.122, 0, A))
        if ph < share:
            s = 1 - 2 * ph / share
            z, pit = 0.0, 0.0
        else:
            q = (ph - share) / (1 - share)
            sm = q * q * (3 - 2 * q)
            s = -1 + 2 * sm
            z = lift * math.sin(q * math.pi)
            pit = -0.8 * math.sin(q * math.pi) * k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"], p["FRp"], p["FLp"] = tuple(rp), tuple(lp), pr, pl
        hy = math.radians(heading) * 0.5
        p["FRy"], p["FLy"] = -0.1 + hy, 0.08 + hy
        s2 = math.sin(u * 4 * math.pi + 0.4)
        c1 = math.cos(u * 2 * math.pi)
        p["pel"] = (0.012 * c1, 0.02 * k * fwd - 0.02 * back, -0.03 - 0.012 * k + (0.012 + 0.026 * k) * s2)
        lean = (0.10 + 0.26 * k) * fwd - 0.12 * back
        p["prt"] = (lean * 0.6, 0.10 * c1 * k, 0.12 * k * d.x * -1 - 0.02 * c1)
        p["tor"] = (lean * 0.7 + 0.03, -0.20 * c1 * k, 0.05 * c1)
        p["hed"] = (-lean * 1.0 - 0.05, 0.14 * c1 * k, -0.03 * c1)
        w = min(1.0, k * 1.3)
        p["G"] = (SH + 0.14 - 0.02 * w, 0.17 - 0.05 * w + 0.03 * math.sin(u * 2 * math.pi + 1.0) * k, 0.875 - 0.03 * w + 0.018 * s2)
        p["LP"] = (-0.235, 0.09 - 0.22 * c1 * k, 0.76 + 0.09 * max(0, -c1) * k)
        p["Lh"] = (-0.5 * c1 * k, 0.0, 0.0)
        p["fing"] = 0.75
        p["skirt"] = 0.16 * k + 0.12 * c1 * k
        p["ear"] = 0.22 * k * fwd + 0.1 * math.sin(u * 4 * math.pi) * k
        p["brow"], p["lid"] = 0.1 * k - 0.1, 0.0
        p["wing"] = -0.16 * k
        p["wb"] = 0.25 * k
        p["wfl"] = 0.10 * k
        p["wfq"] = 3.0
        return p
    return fn


# ---- the crouch (item 143): a small scared thing keeping out of sight. Knees in, toes in, up on her toes, curled round the lantern with both paws so it won't show; the ears flat, big eyes over her shoulder.
HUDDLE = {
    "pel": (0.0, -0.035, -0.115), "prt": (0.52, 0.0, 0.0), "tor": (0.38, 0.08, 0.0), "hed": (-0.74, -0.16, 0.05),
    "G": (0.055, 0.38, 0.83), "BE": be((0.0, 0.12, -1.0)), "Lw": 0.0, "LP": (-0.115, 0.40, 0.82), "Lh": (-1.1, 0.9, 0.0),
    "FL": (-0.125, 0.14, A + 0.03), "FR": (0.135, -0.12, A + 0.04), "FLy": -0.16, "FRy": 0.12, "FLp": 0.4, "FRp": 0.5,
    "brow": -0.95, "lid": -0.1, "jaw": 0.0, "ear": 0.72, "earR": 0.0, "earL": 0.0, "fing": 0.85, "skirt": 0.3, "wing": -0.1, "wfl": 0.02, "wfq": 2.0, "wb": -0.75,
}
TIPTOE = {"ankle": A, "foot": 0.07, "width": 0.115, "stride": 0.16, "lift": 0.03, "toe": 0.4, "share": 0.6, "sway": 0.018, "bob": 0.009, "twist": 0.06, "T": 0.38, "toe_out": 0.12}


def huddle(u):
    """Shivering very slightly, darting looks: left, a long stare right, an ear flick at every noise, one quick blink."""
    s = math.sin(u * 2 * math.pi)
    p = dict(HUDDLE)
    look = bump(u, 0.08, 0.30) - 1.0 * bump(u, 0.46, 0.82)
    shiver = 0.0025 * math.sin(u * 2 * math.pi * 26)
    p["pel"] = (shiver, -0.035, -0.115 - 0.004 * s)
    p["tor"] = (0.38 + 0.022 * s, 0.08, 0.0)
    p["hed"] = (-0.74, -0.16 + 0.75 * look, 0.05 - 0.1 * look)
    p["earL"] = 0.3 * bump(u, 0.14, 0.2) - 0.22 * bump(u, 0.6, 0.66)
    p["earR"] = 0.3 * bump(u, 0.52, 0.58)
    p["G"] = (0.055 + shiver, 0.38, 0.83 + 0.004 * s)
    p["LP"] = (-0.115, 0.40, 0.82 + 0.004 * s)
    p["lid"] = 0.95 if 0.40 < u < 0.43 else -0.1
    return p


def huddle_upper(p, u, c1, s2, d):
    """The lantern stays hugged, only trembling with her steps; she looks where she's going, never at it."""
    k = max(d.y, 0.8)
    p["G"] = (0.055, 0.38 * k, 0.83 + 0.007 * s2)
    p["LP"] = (-0.115, 0.40 * k, 0.82 + 0.007 * s2)
    p["hed"] = (-0.74 * (0.65 + 0.35 * max(d.y, 0.0)), -0.08 + 0.06 * c1 + 0.5 * d.x * -1, 0.03)
    p["ear"] = 0.72 + 0.05 * s2
    p["wfl"] = 0.02


def crouch_set():
    dip = off(HUDDLE, pel=(0.0, 0.0, -0.035), prt=(0.08, 0, 0), hed=(-0.06, 0, 0), G=(0.0, -0.03, -0.03), LP=(0.0, -0.03, -0.03))
    return crouchkit.clips(C, END, HUDDLE, huddle, TIPTOE, huddle_upper, dip, up=dict(READY, pel=(0.0, 0.0, -0.005)), idle_t=4.0)


LHAND_PUSH = (-1.45, 0.0, 0.0)     # fingers forward, the palm out


def clips():
    out = [FnClip("idle", 4.2, idle), FnClip("stance", 5.0, stance)]
    out += crouch_set()
    for nm, sp, T in (("walk", 0.45, 0.62), ("run", 1.0, 0.40)):
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            out.append(FnClip("%s_%s" % (nm, tag), T, gait(sp, hd)))

    # Ember Cast, her lantern hand: pulled to the hip, the torso turned away; a straight push at the cursor on 0.08, the torso unwound past square
    r_w = {"pel": (0.0, -0.02, -0.05), "prt": (0.05, -0.28, 0), "tor": (0.08, -0.32, 0.03), "hed": (-0.08, 0.5, 0), "G": (SH + 0.08, -0.06, 0.76), "BE": be(),
           "LP": (-0.16, 0.26, 0.88), "Lh": (-1.2, 0.2, 0), "FL": (-0.12, 0.10, A), "FR": (0.13, -0.10, A), "brow": 0.4, "lid": -0.05, "ear": 0.15, "fing": 0.4, "skirt": 0.1}
    r_h = {"pel": (0.0, 0.05, -0.07), "prt": (0.16, 0.34, 0), "tor": (0.16, 0.42, -0.04), "hed": (-0.26, -0.62, 0.02), "G": (0.12, 0.52, 1.02), "BE": be((0, 0.5, -0.87), (0, 0.87, 0.5)),
           "LP": (-0.30, -0.08, 0.80), "Lh": (0.2, 0, 0), "FL": (-0.12, 0.16, A), "FR": (0.13, -0.14, A), "jaw": 0.25, "skirt": 0.25, "wing": 0.14}
    r_f = dict(r_h)
    r_f.update({"G": (0.13, 0.49, 1.0), "tor": (0.14, 0.36, -0.03), "hed": (-0.22, -0.52, 0.02)})
    out.append(C("shot_r", 0.42, [(0.0, END), (0.04, r_w, "out"), (0.08, r_h, "out"), (0.18, r_f, "lin"), (0.3, {"G": (SH + 0.06, 0.28, 0.93), "prt": (0.08, 0.12, 0), "tor": (0.08, 0.14, 0), "hed": (-0.1, -0.2, 0), "LP": (-0.18, 0.2, 0.80), "jaw": 0.0}), (0.42, END)]))
    # ... the left: an open paw pushed out, the lantern swung back for balance
    l_w = {"pel": (0.0, -0.02, -0.05), "prt": (0.05, 0.28, 0), "tor": (0.08, 0.34, -0.03), "hed": (-0.08, -0.52, 0), "LP": (-0.16, -0.04, 0.80), "Lh": (0.1, 0, 0), "G": (SH + 0.02, 0.30, 0.98), "FL": (-0.12, -0.10, A), "FR": (0.13, 0.10, A), "brow": 0.4, "ear": 0.15, "fing": 0.8}
    l_h = {"pel": (0.0, 0.05, -0.07), "prt": (0.16, -0.34, 0), "tor": (0.16, -0.42, 0.04), "hed": (-0.26, 0.62, -0.02), "LP": (-0.07, 0.50, 1.02), "Lh": LHAND_PUSH, "G": (SH + 0.18, -0.10, 0.84), "FL": (-0.12, -0.14, A), "FR": (0.13, 0.16, A), "fing": 0.0, "jaw": 0.25, "skirt": 0.25, "wing": 0.14}
    l_f = dict(l_h)
    l_f.update({"LP": (-0.08, 0.47, 1.0), "tor": (0.14, -0.36, 0.03), "hed": (-0.22, 0.52, -0.02)})
    out.append(C("shot_l", 0.42, [(0.0, END), (0.04, l_w, "out"), (0.08, l_h, "out"), (0.18, l_f, "lin"), (0.3, {"LP": (-0.20, 0.3, 0.92), "Lh": (-1.0, 0, 0), "G": (SH + 0.16, 0.08, 0.86), "prt": (0.08, -0.12, 0), "tor": (0.08, -0.14, 0), "hed": (-0.1, 0.2, 0), "jaw": 0.0, "fing": 0.3}), (0.42, END)]))
    # the Empowered ember: a coil down over the lantern, then up on her toes, both hands thrust out, wings wide
    e0 = {"pel": (0.0, -0.03, -0.13), "prt": (0.3, -0.2, 0), "tor": (0.3, -0.2, 0), "hed": (-0.3, 0.25, 0), "G": (0.17, 0.08, 0.72), "BE": be(), "LP": (-0.10, 0.10, 0.70), "Lh": (-1.0, 0.5, 0),
          "FL": (-0.13, 0.08, A), "FR": (0.14, -0.08, A), "brow": 0.8, "lid": 0.1, "ear": 0.5, "fing": 0.8, "wing": -0.2}
    e1 = {"pel": (0.0, 0.08, 0.035), "prt": (-0.02, 0.1, 0), "tor": (-0.1, 0.1, 0), "hed": (0.02, -0.12, 0), "G": (0.12, 0.52, 1.08), "BE": be((0, 0.5, -0.87), (0, 0.87, 0.5)), "LP": (-0.10, 0.52, 1.08), "Lh": LHAND_PUSH,
          "FL": (-0.12, 0.10, A + 0.04), "FR": (0.13, -0.08, A + 0.05), "FLp": 0.5, "FRp": 0.5, "brow": 1.0, "lid": -0.12, "ear": 0.0, "fing": 0.0, "jaw": 0.7, "wing": 0.3, "skirt": 0.3}
    e2 = dict(e1)
    e2.update({"pel": (0.0, 0.07, 0.015), "G": (0.12, 0.50, 1.05), "LP": (-0.10, 0.50, 1.05)})
    out.append(C("shot_emp", 0.55, [(0.0, END), (0.09, e0), (0.14, e1, "out"), (0.3, e2, "lin"), (0.55, END)]))
    # Burrseed wind-up (item 118b, Elluna's read): a graceful 1.0 s channel the enemy sees coming. A small scoop down, the arms sweep up and out, she
    # rises onto her toes with the wings opening, gathering the light into the lantern overhead; cocked back at the very top, then the throw
    s_d = {"pel": (0.0, 0.0, -0.075), "prt": (0.16, 0, 0), "tor": (0.2, 0, 0), "hed": (0.12, 0, 0), "G": (0.2, 0.2, 0.74), "BE": be(), "LP": (-0.17, 0.2, 0.72), "Lh": (-1.1, 0.6, 0),
           "FL": (-0.13, 0.05, A), "FR": (0.13, -0.05, A), "FLy": 0.16, "FRy": -0.16, "ear": 0.3, "fing": 0.7, "wing": -0.14, "wfl": 0.03, "wfq": 2.0}
    s_m = {"pel": (0.0, 0.0, 0.0), "prt": (0.0, 0, 0), "tor": (-0.08, 0, 0), "hed": (-0.14, 0, 0), "G": (0.44, 0.1, 1.14), "BE": be((0.2, 0, -0.97)), "LP": (-0.44, 0.1, 1.06), "Lh": (0.0, 0.0, -1.5),
           "FL": (-0.13, 0.03, A + 0.02), "FR": (0.13, -0.03, A + 0.02), "FLp": 0.25, "FRp": 0.25, "ear": 0.1, "fing": 0.1, "wing": 0.2, "wfl": 0.08, "wfq": 5.0}
    s_t = {"pel": (0.0, 0.0, 0.05), "prt": (-0.07, 0, 0), "tor": (-0.22, 0, 0), "hed": (-0.32, 0, 0), "G": (0.42, 0.06, 1.46), "BE": be((0.1, 0, -1.0)), "LP": (-0.42, 0.06, 1.4), "Lh": (0.0, 0.0, -2.4),
           "FL": (-0.12, 0.02, A + 0.05), "FR": (0.12, -0.02, A + 0.05), "FLp": 0.6, "FRp": 0.6, "ear": 0.0, "fing": 0.0, "jaw": 0.3, "skirt": -0.15, "wing": 0.42, "wfl": 0.14, "wfq": 8.0}
    s_c = dict(s_t)
    s_c.update({"pel": (0.0, -0.035, 0.06), "tor": (-0.32, 0, 0), "hed": (-0.26, 0, 0), "G": (0.36, -0.08, 1.47), "LP": (-0.36, -0.08, 1.41), "fing": 0.5, "wing": 0.34})
    out.append(C("seed_aim", 1.0, [(0.0, END), (0.16, s_d), (0.5, s_m), (0.82, s_t), (1.0, s_c)]))
    # ... the snap: the gathered light flung forward with both hands (the seed leaves on the first frame), a small hop down off the toes
    h1 = {"pel": (0.0, 0.1, 0.06), "prt": (0.26, 0.05, 0), "tor": (0.2, 0.0, 0), "hed": (-0.28, -0.05, 0), "G": (0.14, 0.5, 1.04), "BE": be((0, 0.5, -0.87), (0, 0.87, 0.5)), "LP": (-0.10, 0.52, 1.03), "Lh": LHAND_PUSH,
          "FL": (-0.12, 0.08, A + 0.06), "FR": (0.13, -0.06, A + 0.03), "FLy": 0.1, "FRy": -0.1, "FLp": -0.2, "FRp": 0.3, "fing": 0.0, "jaw": 0.5, "ear": 0.5, "wing": 0.26, "wfl": 0.05, "wfq": 2.0, "skirt": -0.3, "brow": 0.9, "lid": 0.0}
    out.append(C("seed", 0.55, [(0.0, s_c), (0.07, h1, "out"), (0.32, dict(h1, pel=(0.0, 0.1, -0.02), FL=(-0.12, 0.1, A), FR=(0.13, -0.08, A), FLp=0, FRp=0, skirt=0.1)), (0.55, END)]))
    # Hearthlight: a deep gather, then both arms straight up, the lantern high over her head, wings flung open, eyes shut in the light
    g0 = {"pel": (0.0, 0.0, -0.13), "prt": (0.32, 0, 0), "tor": (0.3, 0, 0), "hed": (0.05, 0, 0), "G": (0.12, 0.26, 0.60), "BE": be(), "LP": (-0.12, 0.26, 0.60), "Lh": (-1.2, 0, 0), "FL": (-0.15, 0.04, A), "FR": (0.15, -0.04, A), "fing": 0.9, "ear": 0.4, "wing": -0.25, "lid": 0.5, "brow": -0.3}
    g1 = {"pel": (0.0, 0.0, 0.05), "prt": (-0.1, 0, 0), "tor": (-0.18, 0, 0), "hed": (-0.3, 0, 0), "G": (0.20, 0.13, 1.55), "BE": be((0.0, 0.0, -1.0), FRONT), "LP": (-0.16, 0.04, 1.47), "Lh": (0.0, 0.0, 3.0), "FL": (-0.13, 0.03, A + 0.03), "FR": (0.13, -0.03, A + 0.03), "FLp": 0.5, "FRp": 0.5,
          "fing": 0.0, "ear": 0.0, "wing": 0.42, "lid": 0.0, "brow": 0.6, "jaw": 0.6, "skirt": -0.2}
    g2 = dict(g1)
    g2.update({"pel": (0.0, 0.0, 0.03), "G": (0.205, 0.13, 1.52), "LP": (-0.16, 0.04, 1.44), "jaw": 0.4})
    out.append(C("hearth", 0.65, [(0.0, END), (0.08, g0), (0.18, g1, "out"), (0.4, g2, "lin"), (0.65, END)]))
    # Hearthlight thrown: the left paw low behind, an underhand fling at the cursor
    t0 = {"pel": (0.0, -0.03, -0.08), "prt": (0.2, 0.3, 0), "tor": (0.2, 0.3, 0), "hed": (-0.2, -0.3, 0), "LP": (-0.28, -0.26, 0.72), "Lh": (0.7, 0, 0), "fing": 0.7, "G": (SH + 0.14, 0.2, 0.88), "FL": (-0.12, -0.08, A), "FR": (0.13, 0.08, A), "brow": 0.5}
    t1 = {"pel": (0.0, 0.08, -0.05), "prt": (0.12, -0.35, 0), "tor": (0.05, -0.4, 0), "hed": (-0.14, 0.5, 0), "LP": (-0.08, 0.50, 0.96), "Lh": LHAND_PUSH, "fing": 0.0, "G": (SH + 0.14, -0.06, 0.86), "FL": (-0.12, 0.2, A), "FR": (0.13, -0.14, A), "jaw": 0.4, "skirt": 0.3, "wing": 0.12}
    t2 = dict(t1)
    t2.update({"LP": (-0.09, 0.42, 1.10), "tor": (0.0, -0.32, 0)})
    out.append(C("toss", 0.5, [(0.0, END), (0.06, t0, "out"), (0.12, t1, "out"), (0.26, t2), (0.5, END)]))
    # Relay Step: a skip: a quick squash, off one foot with the lead knee up, wings snapping back
    k0 = {"pel": (0.0, -0.02, -0.09), "prt": (0.25, 0, 0), "tor": (0.1, 0, 0), "hed": (-0.2, 0, 0), "brow": 0.3, "ear": 0.3, "wing": -0.14}
    k1 = {"pel": (0.0, 0.08, 0.10), "prt": (0.42, 0, 0.0), "tor": (0.1, 0.1, 0), "hed": (-0.4, 0, 0), "G": (SH + 0.1, -0.03, 0.86), "LP": (-0.26, 0.22, 0.90), "FL": (-0.12, 0.2, A + 0.17), "FR": (0.13, -0.2, A + 0.02), "FLp": -0.4, "FRp": 0.8, "ear": 0.7, "skirt": -0.3, "wing": 0.28, "wb": 0.4, "wfq": 8.0, "wfl": 0.25, "jaw": 0.2, "lid": -0.1}
    out.append(C("skip", 0.24, [(0.0, k0), (0.04, k0), (0.11, k1, "out"), (0.17, dict(k1, pel=(0.0, 0.05, 0.03), FL=(-0.12, 0.14, A), FR=(0.13, -0.12, A + 0.06))), (0.24, END)]))
    # the air glide: a drifting seed on her fairy wings: the lantern out ahead to light the way, legs dangling, wings blurring
    f0 = {"pel": (0.0, 0.0, 0.02), "prt": (0.3, 0, 0), "tor": (0.0, 0, 0), "hed": (-0.26, 0, 0), "G": (SH + 0.02, 0.36, 0.98), "BE": be((0.0, 0.4, -0.9), (0, 0.9, 0.4)), "LP": (-0.32, 0.08, 0.96), "Lh": (-0.3, 0, -0.7),
          "FL": (-0.12, -0.06, A + 0.1), "FR": (0.13, -0.14, A + 0.14), "FLp": 0.7, "FRp": 0.8, "brow": -0.2, "lid": -0.05, "ear": 0.45, "fing": 0.0, "skirt": -0.4, "wing": 0.32, "wfl": 0.34, "wfq": 12.0, "wb": 0.1}
    f1 = dict(f0)
    f1.update({"pel": (0.012, 0.0, 0.05), "prt": (0.3, 0.1, 0.09), "FR": (0.13, -0.18, A + 0.17), "FL": (-0.12, -0.03, A + 0.08)})
    f2 = dict(f0)
    f2.update({"pel": (-0.012, 0.0, 0.015), "prt": (0.3, -0.1, -0.09), "FR": (0.13, -0.11, A + 0.12), "FL": (-0.12, -0.11, A + 0.13)})
    out.append(C("float", 1.05, [(0.0, k0), (0.06, f0, "out"), (0.26, f1), (0.46, f2), (0.66, f1), (0.85, f0), (0.95, {"pel": (0, 0, -0.1), "prt": (0.2, 0, 0), "FL": (-0.12, 0.05, A), "FR": (0.13, -0.05, A), "FLp": 0, "FRp": 0, "wfl": 0.08, "wfq": 4.0, "wing": 0.05}, "out"), (1.05, END)]))
    # Carrier: she ducks, gets her shoulder under them, and heaves up, staggering a little: small and stubborn
    p0 = {"pel": (0.0, 0.03, -0.17), "prt": (0.72, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.7, 0, 0), "G": (SH + 0.05, 0.24, 0.42), "LP": (-0.14, 0.40, 0.40), "Lh": (-1.2, 0, 0), "FL": (-0.15, 0.14, A), "FR": (0.15, -0.14, A), "brow": 0.8, "ear": 0.5, "fing": 0.9}
    p1 = {"pel": (0.0, 0.0, -0.02), "prt": (0.0, 0, 0), "tor": (-0.1, 0, 0), "hed": (-0.1, 0, 0), "G": (SH + 0.14, 0.14, 0.84), "LP": (-0.2, 0.04, 1.08), "Lh": (0.6, 0, 0), "FL": (-0.13, 0.06, A), "FR": (0.13, -0.06, A), "jaw": 0.6, "brow": 1.0, "lid": 0.3, "ear": 0.3, "fing": 0.8}
    out.append(C("pickup", 0.55, [(0.0, END), (0.12, p0), (0.3, p1, "out"), (0.55, END)]))
    # the Hearthlight's bloom: both arms up and out, up on the toes
    fl = {"pel": (0.0, 0.0, 0.05), "prt": (-0.08, 0, 0), "tor": (-0.2, 0, 0), "hed": (-0.26, 0, 0), "G": (SH + 0.22, 0.05, 1.32), "BE": be((0.3, 0, -0.95)), "LP": (-0.42, 0.05, 1.32), "Lh": (0.0, 0, 2.2), "FL": (-0.13, 0.02, A + 0.04), "FR": (0.13, -0.02, A + 0.04), "FLp": 0.5, "FRp": 0.5, "fing": 0, "jaw": 0.8, "brow": 0.3, "wing": 0.4, "skirt": -0.2}
    out.append(C("flare", 0.6, [(0.0, END), (0.07, dict(END, pel=(0, 0, -0.08), prt=(0.15, 0, 0))), (0.15, fl, "out"), (0.32, dict(fl, pel=(0, 0, 0.03), jaw=0.5)), (0.6, END)]))
    # the Burrseed's root going off: a tug on the thread: upper body only
    out.append(C("tug", 0.36, [(0.0, END), (0.05, {"LP": (-0.14, 0.42, 0.98), "Lh": LHAND_PUSH, "fing": 0.2, "tor": (0.0, 0.1, 0)}), (0.11, {"LP": (-0.24, -0.04, 0.96), "Lh": (0.2, 0, 0), "fing": 1.0, "tor": (0.22, -0.2, 0), "hed": (-0.2, 0.2, 0), "brow": 0.9, "jaw": 0.3}, "out"), (0.36, END)]))
    # a foe Kindled to 5: a snap of the fingers by her shoulder
    out.append(C("kindled", 0.34, [(0.0, END), (0.06, {"LP": (-0.22, 0.12, 1.06), "Lh": (-0.2, 0, 2.6), "fing": 0.5}), (0.12, {"LP": (-0.24, 0.1, 1.2), "Lh": (0, 0, 3.0), "fing": 1.0, "ear": -0.0, "hed": (-0.14, 0.14, 0), "brow": 0.8}, "out"), (0.34, END)]))
    # Hearth Call: the lantern pulled low, then thrust high and out over the tether; it holds there walking; swept down at the end
    c0 = {"G": (SH + 0.1, -0.04, 0.72), "tor": (0.14, -0.2, 0), "hed": (-0.1, 0.2, 0), "brow": 0.6}
    c1 = {"G": (0.26, 0.26, 1.42), "BE": be((0.1, 0.1, -1.0)), "tor": (-0.14, 0.14, 0), "hed": (-0.3, -0.14, 0), "LP": (-0.36, 0.06, 0.92), "Lh": (0, 0, -0.9), "brow": 0.9, "jaw": 0.6, "fing": 0.0, "wing": 0.3, "ear": 0.0}
    c2 = dict(c1)
    c2.update({"G": (0.25, 0.24, 1.38), "tor": (-0.1, 0.12, 0), "jaw": 0.15})
    out.append(C("call", 0.35, [(0.0, END), (0.05, c0, "out"), (0.1, c1, "out"), (0.2, dict(c1, G=(0.27, 0.27, 1.46)), "out"), (0.35, c2)]))
    c3 = dict(c2)
    c3.update({"G": (0.25, 0.24, 1.40), "wfl": 0.12})
    out.append(C("call_hold", 0.6, [(0.0, c2), (0.3, c3), (0.6, c2)]))
    c4 = {"G": (SH + 0.14, 0.1, 0.72), "tor": (0.18, 0, 0), "hed": (-0.14, 0, 0), "LP": (-0.3, 0.3, 0.96), "Lh": LHAND_PUSH, "jaw": 0.4, "wing": 0.1}
    out.append(C("call_end", 0.3, [(0.0, c2), (0.07, c4, "out"), (0.14, dict(c4, G=(SH + 0.26, 0.2, 0.98), LP=(-0.40, 0.2, 1.0), tor=(-0.06, 0, 0)), "out"), (0.3, END)]))

    # air and landing: rises with her knees up and ears back; wings catch the fall
    rise = {"pel": (0.0, 0.0, 0.0), "prt": (0.04, 0, 0), "tor": (-0.06, 0, 0), "hed": (-0.06, 0, 0), "FL": (-0.12, 0.12, A + 0.14), "FR": (0.13, -0.02, A + 0.05), "FLp": -0.4, "FRp": 0.5, "G": (SH + 0.16, 0.08, 0.84), "LP": (-0.28, 0.14, 0.96), "Lh": (-0.2, 0, -0.5), "ear": 0.5, "wing": -0.1, "wb": 0.2, "wfq": 6.0, "wfl": 0.15, "skirt": -0.1, "lid": -0.05}
    out.append(C("jump", 0.3, [(0.0, {"pel": (0, 0, -0.08), "prt": (0.2, 0, 0)}), (0.12, rise, "out"), (0.3, dict(rise, FL=(-0.12, 0.12, A + 0.17)))]))
    fall = {"pel": (0.0, 0.0, 0.0), "prt": (0.0, 0, 0), "tor": (0.02, 0, 0), "hed": (0.1, 0, 0), "G": (SH + 0.2, 0.1, 0.98), "LP": (-0.38, 0.08, 1.0), "Lh": (0, 0, -1.0), "FL": (-0.13, 0.07, A + 0.07), "FR": (0.13, -0.05, A + 0.05), "FLp": 0.2, "FRp": 0.2, "ear": 0.1, "wing": 0.3, "wfl": 0.22, "wfq": 10.0, "fing": 0, "skirt": -0.35, "brow": -0.7, "lid": -0.1, "jaw": 0.2}
    f2 = dict(fall)
    f2.update({"FL": (-0.13, 0.07, A + 0.09), "G": (SH + 0.2, 0.1, 1.0)})
    out.append(C("fall", 0.6, [(0.0, fall), (0.3, f2), (0.6, fall)]))
    ld = {"pel": (0.0, 0.01, -0.13), "prt": (0.3, 0, 0), "tor": (0.26, 0, 0), "hed": (-0.26, 0, 0), "G": (SH + 0.18, 0.16, 0.72), "LP": (-0.26, 0.2, 0.62), "FL": (-0.15, 0.06, A), "FR": (0.15, -0.05, A), "FLp": 0, "FRp": 0, "ear": -0.3, "skirt": 0.3, "wing": -0.15, "brow": 0.2}
    out.append(C("land", 0.4, [(0.0, ld), (0.07, dict(ld, pel=(0, 0.01, -0.15)), "out"), (0.22, dict(ld, pel=(0, 0, 0.0), prt=(0.0, 0, 0), tor=(0.0, 0, 0), hed=(0, 0, 0), ear=0.2)), (0.4, END)]))
    # the glider's bar overhead: her wings tucked, lantern swinging under the grip
    gl = {"pel": (0.0, 0.0, 0.0), "prt": (0.2, 0, 0), "tor": (0.0, 0, 0), "hed": (-0.14, 0, 0), "G": (SH - 0.02, -0.06, SZ + 0.36), "BE": be((0, 0, 1), (0, -1, 0)), "LP": (-SH + 0.02, -0.06, SZ + 0.36), "Lh": (0.0, 0.0, 3.14), "FL": (-0.11, -0.03, A + 0.06), "FR": (0.13, -0.15, A + 0.11), "FLp": 0.5, "FRp": 0.6, "skirt": -0.5, "fing": 1.0, "ear": 0.6, "wing": -0.2, "wb": 0.5, "lid": -0.05, "brow": 0.2}
    g3 = dict(gl)
    g3.update({"pel": (0.01, 0, 0.012), "FR": (0.13, -0.18, A + 0.13), "FL": (-0.11, 0.0, A + 0.05)})
    out.append(C("glide", 1.6, [(0.0, gl), (0.8, g3), (1.6, gl)]))
    # hits: she's tiny: thrown back on her heels, ears slapped flat, eyes shut tight
    out.append(C("hit_f", 0.42, [(0.0, END), (0.06, {"pel": (0.0, -0.09, -0.09), "prt": (-0.2, 0.08, 0.05), "tor": (-0.34, -0.2, 0.1), "hed": (0.3, 0.3, 0.1), "brow": -1.0, "lid": 0.85, "jaw": 0.6, "ear": 1.0, "G": (SH + 0.2, 0.12, 0.8), "LP": (-0.3, 0.14, 0.92), "FR": (0.13, -0.12, A), "skirt": -0.4, "wing": 0.2}, "out"), (0.16, {"pel": (0, -0.06, -0.08), "tor": (-0.18, -0.1, 0.05), "hed": (0.14, 0.14, 0.05), "lid": 0.5}), (0.42, END)]))
    out.append(C("hit_b", 0.42, [(0.0, END), (0.06, {"pel": (0.0, 0.09, -0.09), "prt": (0.32, -0.08, -0.05), "tor": (0.46, 0.2, -0.1), "hed": (-0.56, -0.2, 0), "brow": -1.0, "lid": 0.85, "jaw": 0.6, "ear": 1.0, "G": (SH + 0.1, 0.32, 0.74), "LP": (-0.24, -0.06, 0.80), "FL": (-0.12, 0.18, A), "skirt": 0.4, "wing": -0.2}, "out"), (0.16, {"pel": (0, 0.06, -0.08), "tor": (0.3, 0.12, -0.05), "hed": (-0.34, -0.12, 0), "lid": 0.5}), (0.42, END)]))
    # stun: wobbling on her feet, the head going round, one eye closing
    s1 = {"pel": (0.02, -0.01, -0.06), "prt": (0.1, 0.1, 0.06), "tor": (0.16, 0.1, 0.1), "hed": (0.2, 0.26, 0.2), "G": (SH + 0.1, 0.14, 0.72), "LP": (-0.28, 0.12, 0.68), "brow": -0.8, "lid": 0.55, "ear": 0.8, "jaw": 0.3}
    s2 = dict(s1)
    s2.update({"pel": (-0.02, -0.01, -0.06), "prt": (0.1, -0.1, -0.06), "tor": (0.16, -0.1, -0.1), "hed": (0.2, -0.26, -0.2)})
    out.append(C("stun", 1.2, [(0.0, s1), (0.6, s2), (1.2, s1)]))
    # downed: sat on the ground, legs folded, curled round the lantern, the only light she has; ears flat; a small shaking breath
    dn = {"pel": (0.0, -0.05, -0.27), "prt": (0.42, 0, 0.1), "tor": (0.3, 0, 0.05), "hed": (0.3, 0.2, 0.1), "G": (0.06, 0.30, 0.60), "BE": be((0, 0.2, -1.0)), "LP": (-0.13, 0.28, 0.58), "Lh": (-1.1, 0.9, 0), "FL": (-0.2, 0.30, A - 0.015), "FR": (0.2, 0.26, A - 0.015), "FLy": 0.5, "FRy": -0.5, "brow": -1.0, "lid": 0.5, "ear": 1.0, "fing": 0.9, "skirt": 0.3, "wing": -0.3, "wb": 0.5}
    d2 = dict(dn)
    d2.update({"tor": (0.34, 0, 0.05), "pel": (0.0, -0.05, -0.28), "hed": (0.34, 0.2, 0.1), "G": (0.06, 0.30, 0.59)})
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, d2), (2.4, dn)]))
    out.append(C("revive", 1.6, [(0.0, dn), (0.5, dict(dn, hed=(-0.1, 0, 0), lid=0.05, brow=-0.5, ear=0.5)), (0.95, {"pel": (0.0, -0.01, -0.12), "prt": (0.26, 0, 0), "tor": (0.2, 0, 0), "hed": (-0.26, 0, 0), "G": (0.2, 0.26, 0.78), "LP": (-0.2, 0.2, 0.62), "FL": (-0.13, 0.08, A), "FR": (0.13, -0.08, A), "FLy": 0.16, "FRy": -0.22, "lid": 0.0, "ear": 0.3, "brow": 0.4}), (1.6, END)]))
    # death: the lantern arm drops last: she sinks, curls over it and goes still
    dd = {"pel": (0.0, -0.04, -0.27), "prt": (0.72, 0.1, 0.2), "tor": (0.62, 0.1, 0.2), "hed": (0.3, 0.4, 0.2), "G": (0.16, 0.44, 0.12), "BE": be((0.3, 0.3, -0.9)), "LP": (-0.20, 0.50, 0.14), "Lh": (-1.4, 0, 0), "FL": (-0.16, -0.26, 0.11), "FR": (0.18, -0.30, 0.11), "FLp": 1.3, "FRp": 1.3, "FLy": 0.0, "FRy": 0.0, "lid": 1.0, "brow": -0.5, "ear": 1.0, "fing": 0.1, "jaw": 0.15, "skirt": 0.4, "wing": -0.4, "wb": 0.7, "tailw": 1.0}
    out.append(C("death", 1.5, [(0.0, END), (0.18, {"pel": (0, -0.07, -0.05), "prt": (-0.22, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.34, 0, 0), "lid": -0.1, "brow": -1, "jaw": 0.8, "ear": 0.8, "G": (SH + 0.2, 0.14, 0.86)}, "out"),
                                (0.6, {"pel": (0, 0.0, -0.23), "prt": (0.5, 0, 0.1), "tor": (0.4, 0, 0.1), "hed": (0.3, 0.1, 0), "G": (0.2, 0.34, 0.42), "LP": (-0.2, 0.3, 0.44), "Lh": (-1.2, 0, 0), "FL": (-0.15, 0.05, A + 0.03), "FR": (0.15, -0.2, A + 0.05), "FLp": 0.8, "FRp": 1.0, "lid": 0.7}),
                                (1.05, dd), (1.2, dict(dd, pel=(0, -0.04, -0.255))), (1.5, dd)]))
    # Fusion transform: curled small, then bursts open, arms and wings wide, the lantern flung high
    fu0 = {"pel": (0.0, -0.02, -0.17), "prt": (0.42, 0, 0), "tor": (0.42, 0, 0), "hed": (0.4, 0, 0), "G": (0.08, 0.24, 0.62), "LP": (-0.1, 0.22, 0.62), "Lh": (-1.1, 0.8, 0), "fing": 1, "lid": 0.9, "brow": 0.8, "ear": 1.0, "wing": -0.4}
    fu1 = {"pel": (0.0, 0.0, 0.05), "prt": (-0.1, 0, 0), "tor": (-0.24, 0, 0), "hed": (-0.34, 0, 0), "G": (SH + 0.2, 0.06, 1.44), "LP": (-0.42, 0.06, 1.3), "Lh": (0, 0, 2.2), "lid": 0.0, "fing": 0, "jaw": 0.9, "ear": 0.0, "wing": 0.45, "wfl": 0.3, "wfq": 12.0, "FL": (-0.15, 0.03, A + 0.04), "FR": (0.15, -0.03, A + 0.04), "FLp": 0.5, "FRp": 0.5, "brow": 1.0}
    out.append(C("fusion", 0.8, [(0.0, END), (0.18, fu0), (0.3, dict(fu0, pel=(0.006, -0.02, -0.19))), (0.45, fu1, "out"), (0.58, dict(fu1, pel=(0, 0, 0.03))), (0.8, END)]))
    # the emote: she holds the lantern up to her face, grins at it, and does a proud little twirl of a hop with the wings blurring
    em0 = {"G": (0.12, 0.27, 1.1), "BE": be((0, 0.1, -1.0)), "LP": (-0.05, 0.27, 0.98), "Lh": (-1.2, 0.8, 0), "hed": (0.08, 0.0, 0.1), "brow": 0.2, "lid": -0.1, "jaw": 0.25, "ear": 0.0, "fing": 0.3, "tor": (0.1, 0, 0)}
    em1 = dict(em0)
    em1.update({"pel": (0.0, 0.0, 0.14), "prt": (0.0, math.pi * 2, 0), "FL": (-0.1, 0.0, A + 0.14), "FR": (0.1, 0.0, A + 0.1), "FLp": 0.5, "FRp": 0.5, "G": (SH + 0.1, 0.1, 1.28), "LP": (-0.36, 0.08, 1.2), "Lh": (0, 0, 2.2), "fing": 0, "jaw": 0.8, "wing": 0.4, "wfl": 0.3, "wfq": 12.0, "lid": 0.95, "hed": (-0.2, 0, 0)})
    em2 = dict(END)
    em2["prt"] = (READY["prt"][0], READY["prt"][1] + 2 * math.pi, READY["prt"][2])
    out.append(C("emote", 2.6, [(0.0, END), (0.4, em0), (1.2, dict(em0, hed=(0.08, 0.2, 0.0))), (1.45, dict(em0, pel=(0, 0, -0.09))), (1.85, em1, "out"), (2.2, dict(END, prt=em2["prt"], pel=(0, 0, -0.06)), "in"), (2.6, em2)]))
    return out


class PipSolver(Solver):
    def solve(self, P):
        Q, root_at = super().solve(P)
        self.last = Q
        Lh = P.get("Lh")
        if Lh is not None:
            Q["hand.L"] = Q["hips"] @ eul(Lh)
        return Q, root_at


class Extras:
    """Face, ears, apron, wings. Wing flutter is on the clip's clock: a whole number of beats, so loops close."""

    def __init__(self, sol):
        self.f = 0
        self.dur = 1.0
        self.sol = sol

    def start(self, clip):
        self.f, self.dur = 0, clip.dur

    def __call__(self, P):
        if not P:
            return {}
        t = self.f / FPS
        self.f += 1
        out = {}
        l = P.get("lid", 0.0)
        e = P.get("ear", 0.0)
        for s, sd in ((1.0, "R"), (-1.0, "L")):
            out["lid." + sd] = (None, Vector((0, 0.05 * min(max(l * 1.6 - 0.3, 0.0), 1.0), 0)))
            ee = e + P.get("ear" + sd, 0.0)
            out["ear." + sd] = (Quaternion((1, 0, 0), -1.05 * ee) @ Quaternion((0, 0, 1), s * 0.25 * ee), None)
            n = max(1.0, round(P.get("wfq", 1.0) * self.dur))
            fl = P.get("wfl", 0.05) * math.sin(2 * math.pi * n * t / self.dur + (0.4 if s > 0 else 0.0))
            out["wing." + sd] = (Quaternion((1, 0, 0), P.get("wing", 0.0) + fl) @ Quaternion((0, 0, 1), s * P.get("wb", 0.0)), None)
        out["jaw"] = (Quaternion((1, 0, 0), -0.16 * P.get("jaw", 0.0)), None)
        out["apron"] = (Quaternion((1, 0, 0), 0.8 * P.get("skirt", 0.0)), None)
        # the tail keeps level while the body pitches: it lies on the ground when she falls, never stands on end
        qh, r0 = self.sol.last["hips"], self.sol.R0["tail"]
        qw = qh.slerp(Quaternion(), P.get("tailw", 0.65))
        out["tail"] = ((r0.inverted() @ qh.inverted() @ qw @ r0).normalized(), None)
        f = P.get("fing", 0.35)
        out["fingers.L"] = (Quaternion((0, 0, 1), -1.15 * f), None)
        out["thumb.L"] = (Quaternion((0, 0, 1), -0.6 * f), None)
        return out


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    grip = tuple(K.GRIP)
    rig = {"grip_rest": grip, "blade_rest": (0, 0, -1), "edge_rest": (0, 1, 0), "pelvis": float(K.J["hips"][2]), "hilt_l": 0.05, "dz": SZ - 1.072, "ankle": A, "ankle_keys": A,
           "lhand": {"k": (0, 1, 0), "o": (1, 0, 0), "palm": (-SH, 0, K.WRIST_Z - 0.05)}}
    bpy.context.scene.render.fps = FPS
    sol = PipSolver(arm, rig)
    bpy.context.view_layer.objects.active = arm
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    ex = Extras(sol)
    names = []
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        ex.start(c)
        bake(arm, c, sol, ex)
        names.append((c.name, round(c.dur, 3)))
    print("clips", len(names), names)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(a[1])[0] + "_anim.blend")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="AUTO", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))
