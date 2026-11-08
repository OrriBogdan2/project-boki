"""ART-1 Sable's animation set (hand-keyed as targets, solved by posekit). Times match the kit: the thf_* tables in scripts/match/kmoves_dj.gd. Personality: a sly duelist and a dancer. She is never
where you aimed and she smiles when you miss: weight on one hip, one brow up, the pistols carried loose and flicked up late; the flips are clean and show-off, the landings low and pretty.
Space: Z up, she faces +Y, her right is +X. G/BE the right pistol (grip, barrel direction + lock's top), GL/BL the left; "flip" (pitch forward, yaw left, roll right) turns the whole solved body about the pelvis.
Run: blender -b --python tools/art1/sable_clips.py -- <sable.blend> <out.glb> [clip,clip]"""
import sys, os, math
from functools import partial
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, eul, FPS, frame_of, lerp, ease
import sable_pieces as K
import crouchkit
from crouchkit import off

A_Z = K.ANKLE_Z
FX = K.THIGH_X
SZ = K.SHOULDER_Z
TAU = 2 * math.pi


def PR(a, e, top=(0, 0, 1.0)):
    """A pistol aimed toward ang_dir(a, e); `top`: where the lock's top looks."""
    return (D(a, e), top)


class TwinSolver(Solver):
    """Both hands hold pistols: the left has the same targets as the right. Then "flip" turns everything about the pelvis, so a cartwheel keeps the pose it's in."""

    def __init__(self, arm, rig):
        Solver.__init__(self, arm, rig)
        self.grip_l = Vector(rig["grip_l"])

    def solve(self, P):
        P = dict(P)
        fr = P["BL"] if isinstance(P["BL"], Quaternion) else frame_of(*P["BL"])
        q_lh = fr @ self.rest_frame.inverted()
        P["LP"] = tuple(Vector(P["GL"]) - q_lh @ (self.grip_l - self.H0["hand.L"]))
        P["Lw"] = 0.0
        Q, r = Solver.solve(self, P)
        Q["hand.L"] = q_lh
        fl = P.get("flip")
        if fl:
            qf = eul(fl)
            c = Vector((0, 0, self.rig["pelvis"])) + Vector(P["pel"])
            Q = {b: qf @ q for b, q in Q.items()}
            r = c + qf @ (r - c)
        return Q, r


class Clip2(Clip):
    """As Clip; BL slerps like BE."""

    def sample(self, t):
        ks = self.keys
        if t <= ks[0][0]:
            return dict(ks[0][1])
        for i in range(len(ks) - 1):
            a, b = ks[i], ks[i + 1]
            if t <= b[0]:
                u = ease((t - a[0]) / max(b[0] - a[0], 1e-5), b[2])
                out = {}
                for k in b[1]:
                    va, vb = a[1].get(k), b[1].get(k)
                    if k in ("BE", "BL"):
                        out[k] = frame_of(*va).slerp(frame_of(*vb), u)
                    else:
                        out[k] = lerp(va, vb, u)
                return out
        return dict(ks[-1][1])


READY = {
    "pel": (0.012, 0.0, -0.03), "prt": (0.03, 0.09, -0.03), "tor": (0.02, -0.14, 0.04), "hed": (0.02, 0.08, -0.06), "flip": (0.0, 0.0, 0.0),
    "G": (0.24, 0.12, 0.845), "BE": PR(-14, -34), "GL": (-0.24, 0.09, 0.83), "BL": PR(12, -40),
    "FL": (-0.085, 0.07, A_Z), "FR": (0.105, -0.03, A_Z), "FLy": 0.14, "FRy": -0.42, "FLp": 0.0, "FRp": 0.0, "FLr": 0.0, "FRr": 0.0,
    "brow": -0.1, "cock": 0.5, "lid": 0.22, "smile": 0.75,
}
AIM_R = {"G": (0.13, 0.44, 1.26), "BE": PR(0, 3)}
AIM_L = {"GL": (-0.13, 0.44, 1.26), "BL": PR(0, 3)}


def mirror(p):
    """The same pose on her other side."""
    def mv(v):
        return (-v[0], v[1], v[2])

    def me(r):             # (pitch, yaw, roll)
        return (r[0], -r[1], -r[2])

    def mb(b):
        return ((-b[0][0], b[0][1], b[0][2]), (-b[1][0], b[1][1], b[1][2]))
    o = dict(p)
    for k in ("prt", "tor", "hed", "flip"):
        if k in p:
            o[k] = me(p[k])
    if "pel" in p:
        o["pel"] = mv(p["pel"])
    for a, b, f in (("G", "GL", mv), ("BE", "BL", mb), ("FL", "FR", mv)):
        o.pop(a, None)
        o.pop(b, None)
        if a in p:
            o[b] = f(p[a])
        if b in p:
            o[a] = f(p[b])
    for a, b in (("FLy", "FRy"),):
        o.pop(a, None)
        o.pop(b, None)
        if a in p:
            o[b] = -p[a]
        if b in p:
            o[a] = -p[b]
    for a, b in (("FLp", "FRp"),):
        o.pop(a, None)
        o.pop(b, None)
        if a in p:
            o[b] = p[a]
        if b in p:
            o[a] = p[b]
    if "cock" in p:
        o["cock"] = -p["cock"]
    return o


def C(name, dur, keys, loop=False, base=READY):
    return Clip2(name, dur, keys, base, loop)


END = dict(READY)


# ---------------------------------------------------------------------- idle, stance (docs/art/IDLE_AUDIT.md, Sable)
# Quick, quiet, light: off balance on purpose, the weight on one leg and the other on its toe. Both loops stand on the same
# FEET, so the 0.5 s hand-off into the stance never slides them. Every curve is whole cycles of its loop, or a beat that
# starts and ends inside it, so the seam closes. Parts follow one another: the pelvis leads, the chest, head and hands
# trail it by LAG seconds.
IDLE_T = 5.0                     # s: the weight over and back, a glance, the twirl
STANCE_T = 6.0                   # s: two slow sways, the left pistol turned over and hidden away
LAG = dict(pelvis=0.0, chest=0.1, head=0.2, hands=0.3)
BALL, BALL_DOWN = 0.11, A_Z - 0.015      # m: the ball of her foot ahead of the ankle, and below it
FEET = dict(FL=(-0.06, 0.1, A_Z), FR=(0.11, -0.04, A_Z), FLy=0.3, FRy=-0.45)
TOE_DEG = 26.0                   # deg: the free foot's heel off the ground, on its toe
TWIRL_DIP = (0.03, 0.05, 0.05)   # m: the right hand's flick up and forward for the twirl


def ring(t, period):
    return t % period


def plateau(t, period, a, b, c, d):
    """0 before a, eases up to 1 by b, holds, eases back to 0 from c to d."""
    t = ring(t, period)
    u = min(1.0, max(0.0, (t - a) / (b - a))) if t < c else 1.0 - min(1.0, max(0.0, (t - c) / (d - c)))
    return u * u * (3 - 2 * u)


def snap(t, period, a, b, c, d):
    """A plateau whose rise is quick and lands hard (ease out); the fall is slow."""
    t = ring(t, period)
    if a < t < b:
        return 1 - (1 - (t - a) / (b - a)) ** 3
    return plateau(t, period, a, b, c, d)


def bump(t, period, a, b):
    """0 outside a..b, one smooth hill inside it."""
    t = ring(t, period)
    return math.sin(math.pi * (t - a) / (b - a)) ** 2 if a < t < b else 0.0


def settle(t, period, a, dur):
    """The overshoot after a move lands at a: one swing past, then still."""
    u = (ring(t, period) - a) / dur
    return math.sin(math.pi * u) * (1 - u) if 0 < u < 1 else 0.0


def cyc(t, period, k, ph=0.0):
    return math.sin(TAU * k * t / period + ph)


def on_toe(p, side, deg):
    """The heel up deg off the ground, the foot rolled onto its planted ball: the ankle swings up and forward round it."""
    a = math.radians(deg)
    fwd = BALL * (1 - math.cos(a)) + BALL_DOWN * math.sin(a)
    up = BALL * math.sin(a) - BALL_DOWN * (1 - math.cos(a))
    yaw = p["F%sy" % side]
    x, y, z = p["F" + side]
    p["F" + side] = (x - fwd * math.sin(yaw), y + fwd * math.cos(yaw), z + up)
    p["F%sp" % side] = a


def shift(p, w, lag_w):
    """Weight w: 0 on her right leg (the hip thrown out right), 1 over on her left. lag_w: the same, a beat late per part."""
    wp, wc, wh, wa = (lag_w[k] for k in ("pelvis", "chest", "head", "hands"))
    p["pel"] = (0.04 - 0.07 * wp, 0.025 * wp, -0.04 - 0.012 * math.sin(math.pi * wp))
    p["prt"] = (0.03, 0.09 - 0.14 * wp, -0.07 + 0.12 * wp)
    p["tor"] = (0.02, -0.14 + 0.17 * wc, 0.06 - 0.1 * wc)
    p["hed"] = (0.02, 0.08 - 0.12 * wh, -0.07 + 0.08 * wh)
    drag = 0.03 * (wc - wa)        # the hanging hands swing behind the shift and catch up
    for k, x0 in (("G", 0.24), ("GL", -0.24)):
        _, y, z = p[k]
        p[k] = (x0 + 0.035 - 0.06 * wa + drag, y + 0.02 * wa, z)
    on_toe(p, "L", TOE_DEG * (1 - w))
    on_toe(p, "R", 0.6 * TOE_DEG * w)


def breathe(p, t, period, k, amp):
    """k breaths a loop: the rib cage swells on x_breath, the shoulders lift the hands, the head counters."""
    b = 0.5 - 0.5 * cyc(t, period, k, math.pi / 2)
    lag = 0.5 - 0.5 * cyc(t - LAG["hands"], period, k, math.pi / 2)
    p = off(p, pel=(0, 0, 0.002 * b), tor=(-0.015 * b, 0, 0), hed=(0.012 * b, 0, 0), G=(0, 0, 0.005 * lag), GL=(0, 0, 0.005 * lag))
    p["breath"] = amp * b
    return p


def idle_weight(t):
    """0 on the right leg, held; over to the left from 1.9 s, held through the twirl; back from 3.9 s; each with a settle."""
    return plateau(t, IDLE_T, 1.9, 2.5, 3.9, 4.5) + 0.12 * settle(t, IDLE_T, 2.5, 0.45) - 0.1 * settle(t, IDLE_T, 4.5, 0.45)


def idle(u):
    """She waits on her right leg, the left foot on its toe; snaps a glance at something on her left and holds it; shifts
    over to the left, and there, once a loop, twirls the right pistol a full turn round her trigger finger and back into
    her grip, a sleight of hand with a sly look; then back onto the right leg."""
    t = u * IDLE_T
    p = dict(READY, **FEET)
    shift(p, idle_weight(t), {k: idle_weight(t - lag) for k, lag in LAG.items()})
    p = breathe(p, t, IDLE_T, 2, 0.02)
    # the glance: the head snaps round to her left and holds, the chest follows late; a blink on the turn
    g = snap(t, IDLE_T, 0.55, 0.72, 1.45, 1.95) + 0.1 * settle(t, IDLE_T, 0.72, 0.3)
    p = off(p, hed=(-0.03 * g, 0.36 * g, 0.05 * g))
    p = off(p, tor=(0, 0.06 * snap(t - LAG["chest"], IDLE_T, 0.55, 0.8, 1.45, 1.95), 0))
    # the twirl: a flick up of the hand (2.8), one turn round the trigger finger (2.9 to 3.35), the catch and its settle
    flick = bump(t, IDLE_T, 2.72, 3.5)
    p = off(p, G=tuple(v * flick for v in TWIRL_DIP))
    p = off(p, G=(0, 0, -0.025 * bump(t, IDLE_T, 3.33, 3.62)))
    p["BE"] = PR(-14, -34 + 22 * flick - 8 * settle(t, IDLE_T, 3.35, 0.35))
    s = min(1.0, max(0.0, (ring(t, IDLE_T) - 2.9) / 0.45))
    p["twirl"] = TAU * s * s * (3 - 2 * s) if s < 1.0 else 0.0
    look = plateau(t, IDLE_T, 2.7, 2.9, 3.35, 3.6)
    p = off(p, hed=(0.12 * look, -0.08 * look, 0.04 * look))
    # the face: a blink with the glance and one after the twirl; the brow and the smile come up when she has done it
    p["lid"] = 1.0 if 0.52 < ring(t, IDLE_T) < 0.6 or 3.75 < ring(t, IDLE_T) < 3.83 else 0.22
    sly = plateau(t, IDLE_T, 3.35, 3.55, 4.2, 4.8)
    p["cock"] = 0.5 + 0.45 * sly + 0.2 * g
    p["smile"] = 0.75 + 0.25 * sly + 0.1 * g
    return p


def stance(u):
    """Ready, a crouch lower on the same feet, the weight held on the right leg: the right pistol up by her shoulder,
    muzzle to the sky (item 52, the master's pose). The left hand turns its pistol over and over at her thigh, a trinket
    walked over the knuckles, then flicks it out of sight behind her hip and brings it back with a smile."""
    t = u * STANCE_T
    p = dict(READY, **FEET)
    sway = {k: cyc(t - lag, STANCE_T, 1) for k, lag in LAG.items()}
    w = 0.08 + 0.08 * sway["pelvis"]
    shift(p, w, {k: 0.08 + 0.08 * v for k, v in sway.items()})
    p = off(p, pel=(0.01, -0.01, -0.03))
    p = off(p, prt=(0.05, 0.1, 0))
    p = off(p, tor=(0.0, -0.12 - 0.02 * sway["chest"], 0.03))
    p = off(p, hed=(0.08, 0.18 + 0.03 * sway["head"], -0.04))
    p = breathe(p, t, STANCE_T, 2, 0.025)
    p["G"] = (0.27, 0.12 + 0.006 * sway["hands"], 1.36 + 0.008 * cyc(t - LAG["hands"], STANCE_T, 2))
    p["BE"] = PR(-10, 74 + 3 * sway["hands"], (0.0, -1.0, 0.25))
    # the trinket: three turns of the wrist over 0.6 to 2.4 s, then the flick behind the hip (2.6), hidden, back by 5.4
    turn = math.sin(TAU * 1.5 * (ring(t, STANCE_T) - 0.6) / 1.8) * plateau(t, STANCE_T, 0.5, 0.8, 2.2, 2.5)
    hide = plateau(t, STANCE_T, 2.5, 2.8, 4.7, 5.4) + 0.08 * settle(t, STANCE_T, 2.8, 0.4)
    gl = (-0.26 + 0.08 * hide, 0.05 - 0.19 * hide, 0.86 + 0.02 * turn * (1 - hide) + 0.04 * hide)
    p["GL"] = tuple(v + 0.005 * sway["hands"] * (i == 1) for i, v in enumerate(gl))
    fr = frame_of(*PR(10 + 140 * hide, -60 - 15 * hide, (-hide, 1.0 - hide, 0.1)))   # tucked down behind her hip, gone
    p["BL"] = Quaternion(fr @ Vector((1, 0, 0)), math.radians(70) * turn) @ fr
    look = plateau(t, STANCE_T, 0.5, 0.9, 2.3, 2.9)
    p = off(p, hed=(0.16 * look, 0.12 * look, 0.06 * look))
    sly = plateau(t, STANCE_T, 2.7, 3.0, 4.6, 5.3)
    p["lid"] = 1.0 if 3.0 < ring(t, STANCE_T) < 3.08 else 0.3 - 0.08 * sly
    p["smile"], p["brow"], p["cock"] = 0.85 + 0.15 * sly, 0.15, 0.6 + 0.3 * sly
    return p


def gait(speed_k, heading, stride, lift):
    """Light and on the toes: a dancer's catwalk (the feet close to one line, the hips rolling), running low with the pistols pumped back at the hips. heading deg, + left of facing."""
    h = math.radians(heading)
    d = Vector((-math.sin(h), math.cos(h), 0))
    side = Vector((d.y, -d.x, 0))
    fwd = max(0.0, d.y)
    back = max(0.0, -d.y)
    lat = abs(d.x)

    def foot(ph, sx):
        ph = ph % 1.0
        if ph < 0.56:          # planted: slides back under her
            k = ph / 0.56
            s = 0.5 - k
            z, pit = 0.0, 0.0
            if k < 0.16:
                pit = -0.32 * (1 - k / 0.16) * fwd
            if k > 0.7:
                pit = 0.5 * (k - 0.7) / 0.3 * fwd
        else:                  # the swing
            k = (ph - 0.56) / 0.44
            sm = k * k * (3 - 2 * k)
            s = -0.5 + sm
            z = lift * math.sin(k * math.pi) * (1.0 + 0.4 * (1 - k))
            pit = 0.5 * (1 - k) * fwd - 0.3 * k * fwd
        width = FX * (0.62 + 0.3 * speed_k)
        return Vector((sx * width, 0.0, A_Z)) + d * (s * stride) + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, rt = foot(u, 1.0)
        lp, lt = foot(u + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        c1 = math.cos(u * TAU)
        s2 = math.sin(u * 2 * TAU + 0.5)
        hy = h * 0.5
        p["FRy"], p["FLy"] = -0.16 + hy, 0.16 + hy
        p["FRp"], p["FLp"] = rt, lt
        p["pel"] = (0.03 * c1 * (1 - 0.5 * speed_k), 0.03 * speed_k * fwd - 0.02 * back, -0.03 - 0.055 * speed_k + (0.012 + 0.016 * speed_k) * s2)
        lean = (0.05 + 0.3 * speed_k) * fwd - 0.09 * back
        p["prt"] = (lean * 0.55, 0.13 * c1 * (1 - 0.3 * speed_k), 0.07 * c1 + 0.13 * d.x * lat)
        p["tor"] = (lean * 0.5, -0.17 * c1, -0.04 * c1 + 0.04 * d.x)
        p["hed"] = (-lean * 0.75 + 0.03, 0.09 * c1 + 0.05, -0.04)
        w = speed_k
        sw = 0.075 + 0.13 * w
        p["G"] = (0.24 + 0.01 * w, 0.1 - 0.04 * w + sw * c1, 0.855 + 0.05 * w + 0.03 * max(0.0, c1))
        p["GL"] = (-0.24 - 0.01 * w, 0.08 - 0.04 * w - sw * c1, 0.84 + 0.05 * w + 0.03 * max(0.0, -c1))
        p["BE"] = PR(-14, -26 + 30 * w - 16 * c1 * w)
        p["BL"] = PR(14, -32 + 30 * w + 16 * c1 * w)
        p["brow"], p["cock"], p["lid"], p["smile"] = -0.05, 0.4, 0.2, 0.75 + 0.15 * w
        return p
    return fn


# ---- the pose bank
COIL = {"pel": (0, -0.03, -0.09), "prt": (0.16, 0, 0), "tor": (0.08, 0, 0), "hed": (-0.12, 0, 0), "FL": (-0.12, 0.13, A_Z), "FR": (0.13, -0.11, A_Z), "FLy": 0.1, "FRy": -0.5}


def shot_r():
    """The right arm whipped out: cocked wide (t 0), snapped ahead (0.04), the recoil kicking the muzzle up (0.1), settling."""
    c = {"tor": (0.03, 0.5, 0.03), "hed": (0.02, -0.34, 0), "G": (0.38, 0.12, 1.2), "BE": PR(-55, 14), "prt": (0.05, 0.16, 0), "brow": 0.25, "cock": 0.3, "smile": 0.6, "lid": 0.15}
    s = dict(c, tor=(0.08, -0.46, -0.03), hed=(-0.06, 0.34, 0.03), prt=(0.1, -0.12, 0), pel=(0.0, 0.04, -0.05), G=(0.12, 0.47, 1.24), BE=PR(0, 3), smile=0.85)
    k = dict(s, G=(0.13, 0.41, 1.28), BE=PR(0, 26), hed=(-0.1, 0.3, 0.03))
    r = dict(s, tor=(0.04, -0.2, 0), G=(0.17, 0.36, 1.2), BE=PR(-4, 8), hed=(-0.03, 0.14, 0))
    return c, s, k, r


# ---- the crouch (item 143): a stalking cat. Belly down, shoulders ahead of the hips, the head level and hunting; the right pistol out low, sighting along the ground, the left held wide for balance, like the second claw.
PROWL = {
    "pel": (0.03, -0.03, -0.33), "prt": (0.26, 0.16, -0.04), "tor": (0.66, -0.24, 0.05), "hed": (-0.82, 0.10, -0.04),
    "G": (0.20, 0.66, 0.60), "BE": PR(-3, -4), "GL": (-0.40, 0.34, 0.50), "BL": PR(38, -12),
    "FL": (-0.13, 0.26, A_Z + 0.03), "FR": (0.17, -0.25, A_Z + 0.06), "FLy": 0.22, "FRy": -0.5, "FLp": 0.25, "FRp": 0.55,
    "brow": 0.25, "cock": 0.7, "lid": 0.2, "smile": 0.85,
}
SNEAK = {"ankle": A_Z, "foot": 0.11, "width": FX * 1.15, "stride": 0.34, "lift": 0.05, "toe": 0.28, "share": 0.6, "sway": 0.035, "bob": 0.014, "twist": 0.12, "T": 0.6, "toe_out": -0.22}


def prowl(u):
    """Held dead still but for the breath, the head swinging slowly over the ground ahead; the tail end of the scan, a sly look back at you."""
    a, b = math.sin(u * TAU), math.cos(u * TAU)
    p = dict(PROWL)
    p["pel"] = (0.03 + 0.008 * a, -0.03, -0.33 - 0.008 * b)
    p["tor"] = (0.66 + 0.012 * b, -0.24, 0.05)
    p["hed"] = (-0.82, 0.10 + 0.34 * a, -0.04 - 0.05 * a)
    p["G"] = (0.20 + 0.01 * a, 0.66, 0.60 + 0.006 * b)
    p["GL"] = (-0.40, 0.34, 0.50 - 0.006 * b)
    p["lid"] = 1.0 if 0.70 < u < 0.73 else 0.2
    return p


def prowl_upper(p, u, c1, s2, d):
    """The pistols stay on their line as the body flows under them; the head stays on the prey."""
    p["G"] = (0.20 + 0.03 * d.x, 0.66 * max(d.y, 0.55) - 0.02 * c1, 0.60 + 0.008 * s2)
    p["GL"] = (-0.40 + 0.03 * d.x, 0.34 * max(d.y, 0.55) + 0.05 * c1, 0.50 - 0.008 * s2)
    p["hed"] = (-0.82 * (0.55 + 0.45 * max(d.y, 0.0)), 0.10 - 0.06 * c1, -0.04)


def crouch_set():
    dip = off(PROWL, pel=(0.0, 0.02, -0.07), prt=(0.1, 0, 0), hed=(-0.08, 0, 0), G=(0.0, -0.08, -0.06), GL=(0.03, -0.06, -0.05))
    return crouchkit.clips(C, END, PROWL, prowl, SNEAK, prowl_upper, dip, up=dict(READY, pel=(0.012, 0.0, 0.006)), dip_t=0.18)


def clips():
    out = [FnClip("idle", IDLE_T, idle), FnClip("stance", STANCE_T, stance)]
    out += crouch_set()
    for nm, sk, stride, lift, T in (("walk", 0.0, 0.42, 0.03, 0.95), ("run", 1.0, 0.86, 0.1, 0.62)):
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            out.append(FnClip("%s_%s" % (nm, tag), T, gait(sk, hd, stride * (0.72 if tag in "lrb" else 1.0), lift)))

    # LMB (thf_lmb_r / _l: the shot at 0, the reach by 0.04, overshoot 0.12, settled 0.26, wound to the other hand by 0.45, let go by 0.7)
    c, s, k, r = shot_r()
    other = dict(mirror(c), G=READY["G"], BE=READY["BE"])
    keys_r = [(0.0, c), (0.04, s, "out"), (0.12, k, "out"), (0.26, r), (0.45, dict(other)), (0.7, END)]
    out.append(C("lmb_r", 0.7, keys_r))
    out.append(C("lmb_l", 0.7, [(t_, mirror(q_)) + tuple(e) for t_, q_, *e in keys_r[:-1]] + [(0.7, END)]))

    # the empowered shot (thf_primed: coiled at 0, both pistols out in a V at 0.04, held to 0.12, recoiled onto the heels by 0.24, settled 0.55)
    p0 = dict(COIL, G=(0.2, 0.14, 1.12), BE=PR(-6, 30), GL=(-0.2, 0.14, 1.12), BL=PR(6, 30), brow=0.45, cock=0.0, smile=0.4, lid=0.1)
    p1 = {"pel": (0, 0.1, -0.09), "prt": (0.3, 0, 0), "tor": (0.1, 0, 0), "hed": (-0.26, 0, 0), "G": (0.17, 0.52, 1.2), "BE": PR(-9, 2), "GL": (-0.17, 0.52, 1.2), "BL": PR(9, 2), "FL": (-0.12, 0.3, A_Z), "FR": (0.13, -0.26, A_Z), "FRy": -0.6, "FRp": 0.3, "smile": 1.0, "brow": 0.25}
    p2 = dict(p1, pel=(0, -0.02, -0.07), prt=(-0.12, 0, 0), tor=(-0.08, 0, 0), G=(0.18, 0.36, 1.32), BE=PR(-9, 40), GL=(-0.18, 0.36, 1.32), BL=PR(9, 40), hed=(0.04, 0, 0), FL=(-0.12, 0.2, A_Z), FR=(0.13, -0.14, A_Z), FRp=0.0)
    out.append(C("primed", 0.55, [(0.0, p0), (0.04, p1, "out"), (0.12, dict(p1, pel=(0, 0.12, -0.1)), "out"), (0.24, p2), (0.38, dict(p2, G=(0.21, 0.26, 1.14), GL=(-0.21, 0.26, 1.14), BE=PR(-12, 10), BL=PR(12, 10))), (0.55, END)]))

    # the Vault, 0.48 s: 0.05 a crouch with the arms swung up, 0.1 the push-off, the pistols crossed on her chest, one aerial turn to 0.3, a low landing at 0.36, up by 0.48
    TUCK = {"G": (0.08, 0.2, 1.24), "BE": PR(38, 56, (0, -1, 0.2)), "GL": (-0.08, 0.2, 1.24), "BL": PR(-38, 56, (0, -1, 0.2))}
    UP = {"G": (0.25, 0.1, 1.56), "BE": PR(-6, 74, (0, -1, 0.2)), "GL": (-0.25, 0.1, 1.56), "BL": PR(6, 74, (0, -1, 0.2))}
    LAND = {"pel": (0, 0, -0.24), "prt": (0.3, 0, 0), "tor": (0.14, 0, 0), "hed": (-0.34, 0, 0), "G": (0.34, 0.14, 0.86), "BE": PR(-32, -6), "GL": (-0.34, 0.14, 0.86), "BL": PR(32, -6), "FL": (-0.15, 0.17, A_Z), "FR": (0.17, -0.13, A_Z), "FRy": -0.5, "FRp": 0.25, "smile": 1.0, "cock": 0.7}
    START = dict(UP, pel=(0, 0, -0.14), prt=(0.1, 0, 0), FL=(-0.11, 0.07, A_Z), FR=(0.12, -0.05, A_Z), brow=0.0, smile=0.9)
    STAR = dict(TUCK, pel=(0, 0, 0.22), prt=(0, 0, 0), tor=(0, 0, 0), hed=(0.04, 0, 0), FL=(-0.36, 0.0, 0.42), FR=(0.36, 0.0, 0.42), FLy=0.0, FRy=0.0, FLp=0.0, FRp=0.0, smile=1.0, lid=0.15)
    def spin(name, a, pre, mid, flip):
        fa = tuple(0.09 * v for v in flip)
        keys = [(0.0, END), (0.05, dict(pre, flip=(0, 0, 0)), "out"), (0.1, dict(mid, flip=fa)), (0.3, dict(mid, flip=flip), "lin"), (0.36, dict(LAND, flip=flip), "out"), (0.48, dict(END, flip=flip))]
        out.append(C(name, 0.48, keys))
    spin("vault_r", 0, dict(START, prt=(0.1, 0, 0.32)), STAR, (0.0, 0.0, TAU))
    spin("vault_l", 0, dict(START, prt=(0.1, 0, -0.32)), STAR, (0.0, 0.0, -TAU))
    TUCKF = dict(TUCK, pel=(0, 0, 0.22), prt=(0, 0, 0), tor=(0.2, 0, 0), hed=(0.2, 0, 0), FL=(-0.07, 0.3, 0.6), FR=(0.07, 0.3, 0.6), FLp=0.3, FRp=0.3, FLy=0, FRy=0)
    spin("vault_f", 0, dict(START, prt=(0.3, 0, 0), UP=None) if False else dict(START, prt=(0.3, 0, 0)), TUCKF, (TAU, 0.0, 0.0))
    spin("vault_b", 0, dict(START, prt=(-0.12, 0, 0), hed=(-0.2, 0, 0)), TUCKF, (-TAU, 0.0, 0.0))
    PENCIL = dict(TUCK, pel=(0, 0, 0.26), prt=(0, 0, 0), tor=(0, 0, 0), hed=(0.02, 0, 0), FL=(-0.03, 0.0, A_Z + 0.03), FR=(0.03, 0.0, A_Z + 0.03), FLp=0.6, FRp=0.6, FLy=0, FRy=0)
    spin("vault_twist", 0, START, PENCIL, (0.0, TAU, TAU))

    # the air Vault (thf_exdash, up to 1.09 s; the keys end at 0.5): a tuck, the star turned over to 0.34, then carried flat and stretched, legs split, arms swept back, held until she lands
    ST2 = dict(STAR, G=(0.42, 0.06, 1.3), BE=PR(-70, 10), GL=(-0.42, 0.06, 1.3), BL=PR(70, 10))
    FLAT = {"pel": (0, 0, 0.14), "prt": (0.95, 0, 0), "tor": (0.0, 0, 0), "hed": (-0.8, 0, 0), "G": (0.3, -0.26, 1.08), "BE": PR(-120, 4, (0, 0, 1.0)), "GL": (-0.3, -0.26, 1.08), "BL": PR(120, 4, (0, 0, 1.0)),
            "FL": (-0.1, -0.5, 0.56), "FR": (0.12, -0.22, 0.33), "FLp": 0.5, "FRp": 0.9, "FLy": 0, "FRy": 0, "smile": 1.0, "lid": 0.15}
    out.append(C("exdash", 0.5, [(0.0, END), (0.05, dict(START, prt=(0.25, 0, 0)), "out"), (0.08, dict(ST2, flip=(0, 0, 0.36))), (0.34, dict(ST2, flip=(0, 0, TAU)), "lin"), (0.5, dict(FLAT, flip=(0, 0, TAU)))]))
    # touching down (thf_land): a low crouch held 0.1, up in 0.08
    out.append(C("land_v", 0.18, [(0.0, LAND), (0.1, dict(LAND, pel=(0, 0, -0.21))), (0.18, END)]))

    # the Bola (thf_bola: 0.05 the arm up, circles every 0.13 to 0.394, the sling at 0.42, the follow-through to 0.5, 0.75): the right fist whirled over her head, the left pistol out for balance
    B = dict(hed=(-0.06, 0.1, 0.0), tor=(-0.04, -0.2, 0.04), prt=(-0.02, -0.08, 0), GL=(-0.3, 0.2, 1.06), BL=PR(30, 0), BE=PR(0, 80, (0, -1, 0.1)), smile=0.9, cock=0.8, pel=(0, -0.02, -0.05), FL=(-0.11, 0.1, A_Z), FR=(0.13, -0.08, A_Z))
    rc = lambda a_: (0.14 + 0.13 * math.cos(a_), 0.04 + 0.13 * math.sin(a_), 1.68)
    ks = [(0.0, END), (0.05, dict(B, G=rc(0.0)))]
    t_ = 0.05
    ang = 0.0
    while t_ < 0.39:
        t_ += 0.043
        ang += TAU / 3
        ks.append((min(t_, 0.394), dict(B, G=rc(ang)), "lin"))
    sl = {"pel": (0, 0.1, -0.09), "prt": (0.26, 0.2, 0), "tor": (0.12, 0.42, 0), "hed": (-0.2, -0.4, 0), "G": (0.1, 0.56, 1.24), "BE": PR(4, 14), "GL": (-0.3, 0.0, 1.0), "BL": PR(60, -10), "FL": (-0.12, 0.3, A_Z), "FR": (0.13, -0.26, A_Z), "FRy": -0.6, "smile": 1.0}
    ks += [(0.42, sl, "out"), (0.5, dict(sl, G=(0.08, 0.54, 1.18))), (0.75, END)]
    out.append(C("bola", 0.75, ks))

    # the Shadow Knife (thf_knife: a whole-body spin, the left hand cocked back, unwinding into a side-arm throw released at 0.12)
    kn0 = dict(READY, GL=(-0.38, -0.12, 1.2), BL=PR(120, 20), hed=(0.0, 0.0, 0), pel=(0, 0, -0.06), FL=(-0.07, 0.03, A_Z + 0.05), FR=(0.07, 0.0, A_Z))
    kn1 = {"tor": (0.1, 0.46, 0), "prt": (0.2, 0.16, 0), "hed": (-0.14, -0.4, 0), "GL": (0.04, 0.56, 1.25), "BL": PR(-14, 4), "G": (0.3, 0.0, 1.02), "BE": PR(-50, -20), "pel": (0, 0.08, -0.08), "FL": (-0.11, 0.26, A_Z), "FR": (0.12, -0.22, A_Z), "smile": 1.0, "cock": 0.0, "brow": 0.2, "FRy": -0.5}
    out.append(C("knife", 0.45, [(0.0, dict(END, pel=(0, 0, -0.08))), (0.04, dict(kn0, flip=(0, -1.6, 0))), (0.09, dict(kn0, flip=(0, -4.4, 0)), "lin"), (0.12, dict(kn1, flip=(0, -TAU, 0)), "out"), (0.24, dict(kn1, flip=(0, -TAU, 0), GL=(0.02, 0.5, 1.2))), (0.45, dict(END, flip=(0, -TAU, 0)))]))
    # ... arriving at it: dropped in low out of the blink, one hand to the ground, then rising
    ar0 = dict(LAND, pel=(0, 0, -0.34), prt=(0.5, 0, 0), tor=(0.2, 0, 0), hed=(-0.5, 0, 0), G=(0.3, 0.3, 0.58), BE=PR(-30, -10), GL=(-0.26, 0.2, 0.34), BL=PR(30, -60))
    out.append(C("arrive", 0.6, [(0.0, dict(STAR, pel=(0, 0, 0.1), flip=(0, 0, 0))), (0.06, ar0, "out"), (0.3, dict(ar0, pel=(0, 0, -0.3))), (0.6, END)]))

    # Encore (thf_encore): pistols raised as the ring grows, a little sink, then a whole-body spin opening out; the dance takes over at 0.4
    OPEN = {"G": (0.5, 0.14, 1.32), "BE": PR(-78, 8), "GL": (-0.5, 0.14, 1.32), "BL": PR(78, 8)}
    en0 = dict(UP, pel=(0, 0, -0.1), prt=(0.1, 0, 0), smile=1.0, cock=0.9, lid=0.2)
    out.append(C("encore", 0.55, [(0.0, END), (0.08, en0), (0.2, dict(en0, pel=(0, 0, -0.14))), (0.38, dict(READY, **OPEN, pel=(0, 0, 0.02), flip=(0, TAU, 0)), "smooth"), (0.55, dict(END, flip=(0, TAU, 0)))]))

    # the dance, 8 beats of 0.2 s, looped from the kit's own clock: step and shoot right, step and shoot left, a slow turn with the arms open, a dip low, the mirror turn with the pistols high, a shimmy back to the start
    D0 = {"pel": (0.05, 0, -0.05), "prt": (0.0, -0.3, 0.1), "tor": (0, -0.34, 0.1), "hed": (0, 0.44, -0.06), "G": (0.5, 0.2, 1.18), "BE": PR(-68, 4), "GL": (-0.12, 0.3, 1.1), "BL": PR(30, 30), "FL": (-0.14, 0.1, A_Z), "FR": (0.17, -0.02, A_Z), "FLy": 0.2, "FRy": -0.6, "smile": 1.0, "cock": 0.8, "lid": 0.2, "flip": (0, 0, 0)}
    D1 = dict(D0, pel=(0.01, 0, -0.09), prt=(0.04, -0.1, 0.02), tor=(0.04, -0.1, 0.0), G=(0.36, 0.3, 1.1), GL=(-0.2, 0.3, 1.14))
    D2 = mirror(D0)
    D3 = dict(D1, pel=(-0.01, 0, -0.1), G=(0.3, 0.3, 1.2), GL=(-0.36, 0.26, 1.16), prt=(0.04, 0.1, -0.02), tor=(0.04, 0.1, 0))
    D4 = dict(READY, **OPEN, pel=(0, 0, -0.01), prt=(0, 0, 0), tor=(-0.04, 0, 0), hed=(-0.14, 0, 0), FL=(-0.06, 0.02, A_Z + 0.03), FR=(0.06, 0.0, A_Z), FLp=0.3, FRp=0.2, smile=1.0, cock=0.3, lid=0.3)
    D5 = dict(D4, flip=(0, math.pi, 0))
    D6 = dict(D0, pel=(0, 0.04, -0.2), prt=(0.3, 0.2, 0), tor=(0.14, 0.26, 0), hed=(-0.3, -0.2, 0), FL=(-0.16, 0.2, A_Z), FR=(0.16, -0.16, A_Z), G=(0.44, 0.34, 0.92), BE=PR(-40, -24), GL=(-0.3, 0.1, 1.2), BL=PR(40, 30), flip=(0, TAU, 0))
    D7 = dict(mirror(D6), flip=(0, TAU, 0))
    HIGH = dict(UP, pel=(0, 0, 0.01), prt=(-0.06, 0, 0), tor=(-0.06, 0, 0), hed=(-0.16, 0, 0), FL=(-0.06, 0.02, A_Z + 0.03), FR=(0.06, 0.0, A_Z), FLp=0.3, FRp=0.2, G=(0.1, 0.06, 1.72), GL=(-0.1, 0.06, 1.72), smile=1.0, cock=0.3, lid=0.2)
    out.append(C("encore_dance", 1.6, [(0.0, D0), (0.12, D1), (0.2, D2), (0.32, D3), (0.4, D4), (0.6, D5, "lin"), (0.8, D6, "lin"), (0.92, dict(D1, flip=(0, TAU, 0))), (1.0, D7), (1.12, dict(D3, flip=(0, TAU, 0))),
                                         (1.2, dict(HIGH, flip=(0, TAU, 0))), (1.4, dict(HIGH, G=(0.3, 0.06, 1.62), GL=(-0.3, 0.06, 1.62), flip=(0, math.pi, 0)), "lin"), (1.52, dict(D1, flip=(0, 0.9, 0))), (1.6, D0)]))

    # Vault reset (thf_reset): a heel spin with the arms flung wide, a snap back to aim
    out.append(C("reset", 0.4, [(0.0, dict(END, pel=(0, 0, -0.08))), (0.08, dict(READY, **OPEN, pel=(0, 0, 0.0), flip=(0, -math.pi, 0), smile=1.0), "lin"), (0.18, dict(READY, **OPEN, pel=(0, 0, -0.05), flip=(0, -TAU, 0), smile=1.0), "lin"), (0.4, dict(END, flip=(0, -TAU, 0)))]))
    # a knock (thf_flourish): chin up, the left pistol blown out by her lips, the right on the hip
    fo = dict(READY, pel=(0, 0, 0.0), prt=(-0.04, 0.1, 0), tor=(-0.08, -0.14, 0), hed=(-0.22, 0.1, 0.0), GL=(-0.12, 0.17, 1.46), BL=PR(-10, 62, (0, -1, 0.3)), G=(0.26, 0.04, 0.98), BE=PR(-20, -40), smile=1.0, cock=1.0, lid=0.45)
    out.append(C("flourish", 0.75, [(0.0, END), (0.1, fo, "out"), (0.45, dict(fo, pel=(0, 0, -0.01))), (0.75, END)]))

    # air
    out.append(C("jump", 0.45, [(0.0, {"pel": (0, 0, -0.12), "prt": (0.16, 0, 0)}), (0.08, {"pel": (0, 0, 0.0), "prt": (-0.04, 0, 0), "tor": (-0.08, 0, 0), "FL": (-0.07, 0.1, A_Z + 0.28), "FR": (0.09, -0.08, A_Z + 0.14), "FLp": 0.4, "FRp": 0.6, "G": (0.27, 0.1, 1.04), "GL": (-0.27, 0.08, 1.02)}, "out"), (0.3, {"FL": (-0.07, 0.12, A_Z + 0.32), "FR": (0.09, -0.06, A_Z + 0.18)}), (0.45, {"FL": (-0.07, 0.1, A_Z + 0.3), "FR": (0.09, -0.04, A_Z + 0.16)})]))
    ri = {"pel": (0, 0, 0.0), "prt": (-0.03, 0, 0), "tor": (-0.05, 0, 0), "FL": (-0.07, 0.12, A_Z + 0.32), "FR": (0.09, -0.06, A_Z + 0.18), "FLp": 0.4, "FRp": 0.6, "G": (0.28, 0.1, 1.06), "GL": (-0.28, 0.08, 1.04)}
    out.append(C("rise", 0.4, [(0.0, ri), (0.2, dict(ri, FL=(-0.07, 0.12, A_Z + 0.35))), (0.4, ri)]))
    fa = {"pel": (0, 0, 0.02), "prt": (0.03, 0, 0), "tor": (-0.04, 0, 0), "hed": (0.14, 0, 0), "G": (0.36, 0.08, 1.14), "BE": PR(-40, 0), "GL": (-0.36, 0.06, 1.12), "BL": PR(40, 0), "FL": (-0.1, 0.04, A_Z + 0.16), "FR": (0.11, 0.0, A_Z + 0.22), "FLp": 0.4, "FRp": 0.5}
    out.append(C("fall", 0.6, [(0.0, fa), (0.3, dict(fa, G=(0.36, 0.08, 1.18), GL=(-0.36, 0.06, 1.16))), (0.6, fa)]))
    gr = dict(G=(0.15, 0.08, SZ + 0.36), BE=PR(-90, 0, (0, -1, 0)), GL=(-0.15, 0.08, SZ + 0.36), BL=PR(90, 0, (0, -1, 0)))
    gl = dict(gr, pel=(0, 0, 0.04), prt=(0.3, 0, 0), tor=(-0.04, 0, 0), hed=(-0.12, 0, 0), FL=(-0.06, -0.16, A_Z + 0.16), FR=(0.06, -0.1, A_Z + 0.2), FLp=0.5, FRp=0.5, smile=0.9)
    out.append(C("glide", 1.2, [(0.0, gl), (0.6, dict(gl, pel=(0, 0, 0.02))), (1.2, gl)]))
    l2 = dict(LAND, pel=(0, 0, -0.17))
    out.append(C("land", 0.4, [(0.0, fa), (0.08, l2, "out"), (0.2, dict(l2, pel=(0, 0, -0.08))), (0.4, END)]))

    # hit reacts: a flinch that stays pretty, the smile gone for a moment, the pistols pulled in
    fl = {"pel": (0, -0.05, -0.07), "prt": (-0.14, 0, 0), "tor": (-0.18, 0.12, 0), "hed": (0.14, 0.2, 0.06), "brow": -0.8, "cock": 0.0, "lid": 0.5, "smile": -0.4, "G": (0.24, 0.1, 1.02), "GL": (-0.22, 0.1, 1.08), "BL": PR(30, 20)}
    out.append(C("hit_f", 0.42, [(0.0, END), (0.07, fl, "out"), (0.2, dict(fl, pel=(0, -0.02, -0.05))), (0.42, END)]))
    fb = dict(fl, pel=(0, 0.05, -0.07), prt=(0.22, 0, 0), tor=(0.14, -0.1, 0), hed=(-0.18, -0.2, 0.05))
    out.append(C("hit_b", 0.42, [(0.0, END), (0.07, fb, "out"), (0.2, dict(fb, pel=(0, 0.02, -0.05))), (0.42, END)]))
    daz = {"pel": (0.0, 0, -0.1), "prt": (0.06, 0, 0.05), "tor": (0.12, 0, -0.1), "hed": (0.3, 0, -0.14), "lid": 0.55, "brow": -0.8, "cock": 0.0, "smile": -0.3, "G": (0.27, 0.14, 0.88), "GL": (-0.27, 0.1, 0.86), "BE": PR(-14, -60), "BL": PR(14, -60)}
    out.append(C("stun", 1.2, [(0.0, daz), (0.6, dict(daz, hed=(0.3, 0, 0.14), tor=(0.12, 0, 0.1), prt=(0.06, 0, -0.05))), (1.2, daz)]))

    # downed: sunk onto one hip, propped on the left pistol hand, the right still holding its pistol up at whoever comes close; breath slow
    dn = {"pel": (-0.03, -0.1, -0.60), "prt": (0.1, 0.25, 0.14), "tor": (0.2, 0.05, 0.12), "hed": (0.2, 0, 0.1), "G": (0.3, 0.26, 0.56), "BE": PR(-10, -6), "GL": (-0.33, -0.02, 0.1), "BL": PR(30, -40), "FL": (-0.16, 0.34, A_Z - 0.09), "FR": (0.05, 0.38, A_Z - 0.09), "FLy": 1.0, "FRy": 0.8, "FLp": -0.3, "FRp": -0.3, "brow": -0.8, "cock": 0.3, "lid": 0.55, "smile": 0.1}
    d2 = dict(dn, tor=(0.25, 0.05, 0.12), pel=(-0.03, -0.1, -0.615), hed=(0.26, 0, 0.1), G=(0.3, 0.26, 0.53))
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, d2), (2.4, dn)]))
    out.append(C("revive", 1.6, [(0.0, dn), (0.5, dict(dn, tor=(0.1, 0.05, 0.05), hed=(-0.1, 0, 0), lid=0.3, brow=-0.4)), (0.95, dict(LAND, pel=(0, -0.05, -0.34), smile=0.5)), (1.6, END)]))
    # death: a stagger back, one last look, the pistols slipping, folding down onto her side
    dd0 = {"pel": (0, -0.06, -0.08), "prt": (-0.14, 0, 0), "tor": (-0.2, 0, 0), "hed": (-0.14, 0.1, 0), "lid": 0.4, "brow": -1.0, "cock": 0.0, "smile": -0.2, "G": (0.3, 0.14, 1.06), "GL": (-0.3, 0.1, 1.08)}
    dd1 = {"pel": (0, -0.02, -0.46), "prt": (0.25, 0, 0.12), "tor": (0.3, 0, 0.12), "hed": (0.3, 0.1, 0.1), "G": (0.32, 0.26, 0.42), "BE": PR(-30, -50), "GL": (-0.3, 0.14, 0.44), "BL": PR(30, -50), "FL": (-0.14, -0.14, A_Z - 0.06), "FR": (0.14, 0.24, A_Z - 0.06), "lid": 0.75}
    dead = {"pel": (0.06, -0.16, -0.72), "prt": (0.28, 0.1, 1.2), "tor": (0.14, 0.1, 0.12), "hed": (0.3, 0.25, 0.1), "G": (0.46, 0.3, 0.1), "BE": PR(-60, 0, (0, 1, 0.3)), "GL": (-0.04, 0.34, 0.2), "BL": PR(40, 0, (0, -1, 0.3)), "FL": (-0.26, 0.08, 0.1), "FR": (-0.06, 0.26, 0.12), "FLy": 0.5, "FRy": 0.7, "FLp": 0.3, "FRp": 0.3, "lid": 1.0, "smile": 0.3, "brow": -0.2}
    out.append(C("death", 1.5, [(0.0, END), (0.18, dd0, "out"), (0.62, dd1), (1.08, dead), (1.22, dict(dead, pel=(0.06, -0.16, -0.74))), (1.5, dead)]))

    # Fusion (mf_xform, 0.8): a gathered breath, a rising turn with the pistols thrown wide
    out.append(C("fusion", 0.8, [(0.0, END), (0.2, dict(en0, pel=(0, 0, -0.16), lid=0.8)), (0.56, dict(READY, **OPEN, pel=(0, 0, 0.06), flip=(0, TAU, 0), hed=(-0.2, 0, 0), smile=1.0), "smooth"), (0.8, dict(END, flip=(0, TAU, 0)))]))

    # the emote: pistols spun, a low stage bow with a flourish, a wink
    em0 = dict(READY, **UP, pel=(0, 0, -0.02), smile=1.0, cock=1.0)
    bow_ = dict(READY, pel=(0.0, -0.04, -0.14), prt=(0.28, 0, 0), tor=(0.3, 0, 0), hed=(0.1, 0, 0), G=(0.4, 0.1, 0.74), BE=PR(-40, -30), GL=(-0.4, -0.06, 1.1), BL=PR(100, 26), FL=(-0.08, 0.24, A_Z), FR=(0.11, -0.2, A_Z), FRp=0.3, smile=1.0, lid=0.4)
    wink = dict(END, hed=(-0.08, 0.2, -0.1), smile=1.0, cock=1.0, lid=0.2)
    out.append(C("emote", 3.2, [(0.0, END), (0.5, em0), (0.9, dict(em0, flip=(0, TAU, 0)), "smooth"), (1.0, dict(READY, flip=(0, TAU, 0))), (1.6, dict(bow_, flip=(0, TAU, 0))), (2.2, dict(bow_, flip=(0, TAU, 0), pel=(0.0, -0.04, -0.16))), (2.7, dict(wink, flip=(0, TAU, 0))), (3.0, dict(wink, flip=(0, TAU, 0), lid=1.0)), (3.2, dict(END, flip=(0, TAU, 0)))]))
    return out


def extras(P, twirl_rest=Quaternion()):
    """The face, the breath and the twirl. twirl_rest: x_twirl's rest frame (its key turns the pistol round the
    lateral axis X of the rest pose)."""
    if not P:
        return {}
    br, tw = P.get("breath", 0.0), Quaternion((1, 0, 0), P.get("twirl", 0.0))
    out = {"x_breath": (None, None, (1.0 + BREATH_OUT * br, 1.0 + br, 1.0 + BREATH_OUT * br)),
           "x_twirl": (twirl_rest.inverted() @ tw @ twirl_rest, None)}
    b = P.get("brow", 0.0)
    l = P.get("lid", 0.2)
    sm = P.get("smile", 0.5)
    ck = P.get("cock", 0.0)
    for s, side in ((1.0, "R"), (-1.0, "L")):
        # brow: - lifts its inner end (worried), + lowers it (focus); "cock" raises her left brow, the sly one (negative her right)
        lift = max(0.0, -ck) if s > 0 else max(0.0, ck)
        out["brow." + side] = (Quaternion((0, 1, 0), s * 0.2 * b), Vector((0, 0, -0.005 * b + 0.006 * lift)))
        # (the lid's skin stays up under the brow until she really narrows or blinks: the painted liner shows)
        out["lid." + side] = (Quaternion((1, 0, 0), -0.82 * max(0.0, min(1.0, (l - 0.32) / 0.68))), None)
        # the smile pulls higher on her right: lopsided, sly
        out["mouth." + side] = (None, Vector((s * 0.002 * (sm - 0.5), 0, (0.0042 if s > 0 else 0.0028) * (sm - 0.5))))
    return out


BREATH_C = (0.0, 0.0, 1.16)       # m, the rib cage's centre (hips at 0.86, shoulders at 1.34)
BREATH_R = (0.15, 0.13, 0.17)     # m, its half sizes: the skin outside moves with hips alone
BREATH_CORE = 0.55                # of the half sizes: fully on x_breath inside this
BREATH_OUT = 0.6                  # x_breath's swell out through the ribs, against its rise up the bone


def leaf(arm, name, parent, head, tail):
    """A new leaf bone under parent, unless the blend has it."""
    if name in arm.data.bones:
        return False
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones.new(name)
    eb.head, eb.tail = head, tail
    eb.parent = arm.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return True


def add_leaves(arm, body):
    """x_breath under hips at the bottom of the rib cage, with the rib cage's skin moved onto it (an ellipsoid round the
    chest, full inside BREATH_CORE, nothing at its rim), so a scale on it swells the chest; and x_twirl under hand.R at
    the breech, with the right pistol's pieces moved onto it (every mesh island wholly on hand.R but the glove and the
    fingers), so it turns round her trigger finger."""
    if leaf(arm, "x_breath", "hips", (0, 0, 1.0), (0, 0, 1.2)):
        hips, xb = body.vertex_groups["hips"], body.vertex_groups.new(name="x_breath")
        for v in body.data.vertices:
            w = next((g.weight for g in v.groups if g.group == hips.index), 0.0)
            r = math.sqrt(sum(((v.co[i] - BREATH_C[i]) / BREATH_R[i]) ** 2 for i in range(3)))
            k = min(1.0, max(0.0, (1.0 - r) / (1.0 - BREATH_CORE)))
            k = w * k * k * (3 - 2 * k)
            if k > 1e-3:
                hips.add([v.index], w - k, "REPLACE")
                xb.add([v.index], k, "REPLACE")
    pivot = bpy.data.objects["anchor_blade_root"].matrix_world.translation
    if leaf(arm, "x_twirl", "hand.R", pivot, pivot + Vector((0, 0, -0.08))):
        bpy.context.view_layer.update()
        for n in ("anchor_blade_root", "weapon_muzzle"):   # the Gun and its Muzzle spin with it
            o = bpy.data.objects[n]
            mw = o.matrix_world.copy()
            o.parent, o.parent_type, o.parent_bone = arm, "BONE", "x_twirl"
            bpy.context.view_layer.update()
            o.matrix_world = mw
        hand, xt = body.vertex_groups["hand.R"], body.vertex_groups.new(name="x_twirl")
        me = body.data
        root = list(range(len(me.vertices)))

        def find(i):
            while root[i] != i:
                root[i] = root[root[i]]
                i = root[i]
            return i
        for e in me.edges:
            root[find(e.vertices[0])] = find(e.vertices[1])
        mats = {}
        for f in me.polygons:
            mats.setdefault(find(f.vertices[0]), set()).add(me.materials[f.material_index].name)
        isl = {}
        for v in me.vertices:
            w = next((g.weight for g in v.groups if g.group == hand.index), 0.0)
            i = isl.setdefault(find(v.index), {"vs": [], "w": 1.0, "z": 9.0})
            i["vs"].append(v.index)
            i["w"], i["z"] = min(i["w"], w), min(i["z"], v.co.z)
        for r, i in isl.items():
            m = mats.get(r, set())
            glove = m == {"leather-dark"} and i["z"] > pivot.z
            if i["w"] > 0.99 and "skin-face" not in m and not glove:
                hand.remove(i["vs"])
                xt.add(i["vs"], 1.0, "ADD")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig = {"grip_rest": tuple(K.grip("R")), "grip_l": tuple(K.grip("L")), "blade_rest": tuple(K.B_REST), "edge_rest": tuple(K.U_REST), "pelvis": K.HIPS_Z, "hilt_l": 0.1,
           "lhand": {"k": (0, 1, 0), "o": (-1, 0, 0), "palm": tuple(K.grip("L"))}}
    bpy.context.scene.render.fps = FPS
    add_leaves(arm, bpy.data.objects["Body"])
    sol = TwinSolver(arm, rig)
    twirl = partial(extras, twirl_rest=arm.data.bones["x_twirl"].matrix_local.to_quaternion())
    bpy.context.view_layer.objects.active = arm
    names = []
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        bake(arm, c, sol, twirl)
        names.append((c.name, round(c.dur, 3)))
    print("clips", len(names), names)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(a[1])[0] + "_anim.blend")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY") and o.name not in ("Src", "Low"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))
