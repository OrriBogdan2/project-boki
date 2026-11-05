"""Breaker's clips (ART-1), keyed by hand on the contract armature and timed to his kit's real numbers
(content/archetypes/bulwark.json, KMovesPinBjorn), then the .glb export:
  blender -b WORK/breaker_art1.blend --python tools/blender/breaker_anims.py -- WORK/breaker_anims.blend OUT.glb
He is a huge, warm old ferryman: everything starts from the belly and the feet, the hammer's weight arrives late, and
he grins through it all."""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import anim_kit as A

a = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = a[0], a[1]
arm = bpy.data.objects["Armature"]
C = A.Clips(arm)
AX = float(C.rig.P["x_foot.R"].x)      # the ankle's rest x
AZ = float(C.rig.P["x_foot.R"].z)
FR, FL = (AX, -0.02, AZ), (-AX, 0.05, AZ)
tau = math.tau

# the carry: the hammer resting across the right shoulder, the fist low in front; the prow at his left side
CARRY = dict(pos=(0, 0, -0.012), hips=(-7, 0, -3), head=(5, 0, 3),
             gr=(0.27, 0.34, 0.95), gd=(0.07, -0.6, 0.8), ga=(0.0, 0.8, 0.6), er=(0.95, -0.15, -0.3), fing_r=1.0, thumb_r=1.0,
             sh=(-0.525, 0.14, 0.7), sn=(-0.92, 0.38, 0.0), su=(0.04, -0.06, 1.0), el=(-0.8, -0.6, -0.1), fing_l=0.85, thumb_l=0.8,
             fr=FR, fl=FL, fra=0.0, fla=0.0, jaw=0.09, brow=0.0, lid=0.0, wtw=(0, 0, 0))
# the right hand with nothing in it, loose at his side (the hammer is out)
FREE = dict(gr=(0.43, 0.1, 0.6), gd=(0.05, 1.0, -0.2), ga=(0.1, 0.2, 1.0), er=(0.9, -0.3, -0.3), fing_r=0.35, thumb_r=0.3)
# his fighting stance (item 52): low and wide, the prow square ahead, the hammer up by the right ear
STANCE = dict(pos=(0, 0, -0.07), rot=(0, 0, -4), hips=(-15, 0, -15), head=(11, 0, 14),
              gr=(0.5, 0.2, 1.1), gd=(0.12, -0.32, 0.94), ga=(0.0, 0.95, 0.3), er=(1.0, -0.2, -0.5), fing_r=1.0, thumb_r=1.0,
              sh=(-0.17, 0.47, 0.84), sn=(-0.2, 1.0, 0.05), su=(0.05, 0.0, 1.0), el=(-0.9, -0.1, -0.5), fing_l=0.9, thumb_l=0.9,
              fr=(AX + 0.08, -0.15, AZ), fl=(-AX - 0.04, 0.17, AZ), jaw=0.35, brow=1.0)


def merged(*ps, **kw):
    o = {}
    for p in ps:
        o.update(p)
    o.update(kw)
    return o


def add(p, c, v):
    p[c] = tuple(x + y for x, y in zip(p.get(c, (0, 0, 0)), v))


# ---------------------------------------------------------------------- idle, stance
def breathe(period, amp=1.0, blink=None):
    def f(t, p):
        s = math.sin(t / period * tau)
        add(p, "pos", (0, 0, 0.007 * amp * s))
        add(p, "hips", (1.5 * amp * s, 0, 0))
        add(p, "head", (-0.9 * amp * s, 0, 2.0 * math.sin(t / period * tau * 0.5 + 1)))
        add(p, "gr", (0, 0, 0.009 * amp * math.sin(t / period * tau - 0.8)))
        add(p, "sh", (0, 0, 0.006 * amp * math.sin(t / period * tau - 1.2)))
        if blink is not None and abs(t - blink) < 0.09:
            p["lid"] = 1.0
    return f


C.bake("idle", 3.2, [(0, CARRY), (3.2, {})], over=breathe(3.2, 1.0, 1.7), loop=True)
C.bake("stance", 1.6, [(0, STANCE), (1.6, {})], over=breathe(1.6, 1.3), loop=True)


# ---------------------------------------------------------------------- walk, run
def foot(ph, stride, lift, duty=0.56):
    """(along the walk, up, foot pitch) at a phase 0..1 of one foot's cycle: planted, then swung through."""
    ph = ph % 1.0
    if ph < duty:
        u = ph / duty
        return stride * (1 - 2 * u), 0.0, -8.0 * max(0.0, (u - 0.7) / 0.3)
    u = (ph - duty) / (1 - duty)
    e = u * u * (3 - 2 * u)
    return stride * (-1 + 2 * e), lift * math.sin(u * math.pi) ** 0.8, 22.0 * math.sin(u * math.pi) * (1 - u) - 10 * u * (1 - u)


def gait(period, stride, lift, lean, dirv, bob, roll, twist, swing, base):
    dx, dy = dirv

    def f(t, p):
        ph = t / period
        for side, off, sign in (("r", 0.0, 1), ("l", 0.5, -1)):
            d, u, pit = foot(ph + off, stride, lift)
            x0, y0 = (AX + 0.01) * sign, (-0.02 if sign > 0 else 0.03)
            p["f" + side] = (x0 + dx * d, y0 + dy * d, AZ + u)
            p["f" + side + "a"] = pit * (1 if dy >= 0 else -0.5) * (abs(dy) if dy else 0.3)
        # a heavy gait: down onto each planted foot, the belly and shoulders rolling over it
        w = math.sin(ph * tau)
        c2 = math.cos(ph * 2 * tau)
        add(p, "pos", (w * 0.018, 0, -bob * (0.5 + 0.5 * c2) - bob * 0.4))
        add(p, "rot", (0, roll * w, 0))
        add(p, "hips", (lean * dy, -roll * 1.3 * w, twist * w * dy if dy else 0))
        add(p, "head", (-lean * 0.7 * dy, roll * 0.7 * w, -twist * 0.6 * w * dy if dy else 0))
        add(p, "gr", (0.0, swing * 0.35 * w, 0.02 * c2))
        add(p, "sh", (0.0, swing * w, 0.015 * math.sin(ph * 2 * tau + 1)))
    return f


DIRS = {"f": (0, 1), "b": (0, -1), "l": (-1, 0), "r": (1, 0)}
for nm, d in DIRS.items():
    C.bake("walk_" + nm, 1.1, [(0, CARRY), (1.1, {})], loop=True,
           over=gait(1.1, 0.19, 0.075, -5.0, d, 0.012, 3.0, 7.0, 0.06, CARRY))
    C.bake("run_" + nm, 0.68, [(0, merged(CARRY, gr=(0.3, 0.3, 0.9), sh=(-0.48, 0.22, 0.76), head=(14, 0, 3)) ), (0.68, {})], loop=True,
           over=gait(0.68, 0.29, 0.16, -17.0, d, 0.03, 5.0, 12.0, 0.13, CARRY))

# the free right arm (a layer: only the arm's tracks are used)
C.bake("arm_free", 0.5, [(0, merged(CARRY, FREE)), (0.5, {})], loop=True)

# ---------------------------------------------------------------------- LMB
# throw (0.5 s; the hammer leaves ~0.12 s in, as the arm comes through)
COCK = dict(pos=(0, -0.03, -0.09), hips=(10, 0, -40), head=(-6, 0, 34), gr=(0.62, -0.26, 1.2), gd=(0.3, -0.65, 0.72), ga=(0, 0.72, 0.65),
            er=(0.9, -0.5, 0.1), fr=(AX + 0.06, -0.2, AZ), fl=(-AX, 0.12, AZ), jaw=0.45, brow=1.0)
THROWN = dict(pos=(0, 0.09, -0.1), hips=(-30, 0, 34), head=(20, 0, -28), gr=(0.28, 0.62, 0.98), gd=(0.0, 0.95, 0.25), ga=(0, -0.25, 0.95),
              er=(0.9, 0.1, -0.3), fing_r=0.05, thumb_r=0.1, fr=(AX + 0.06, -0.26, AZ), fl=(-AX, 0.26, AZ), fla=0.0, fra=-22.0, jaw=0.75, e="out")
C.bake("lmb_throw", 0.5, [(0, CARRY), (0.07, merged(COCK, e="out")), (0.14, THROWN),
                          (0.21, dict(hips=(-34, 0, 44), gr=(0.08, 0.5, 0.62), gd=(-0.2, 0.7, -0.7), ga=(0, 0.7, 0.7), e="io")),
                          (0.34, dict(pos=(0, 0.03, -0.05), hips=(-16, 0, 18), gr=(0.3, 0.32, 0.62), fing_r=0.3, fr=(AX + 0.03, -0.1, AZ), fl=(-AX, 0.14, AZ), fra=-6.0, jaw=0.3)),
                          (0.5, merged(CARRY, FREE, hips=(-7, 0, -3), head=(5, 0, 3)))])
# recall (0.484 s): the empty right hand goes out for it, then the catch snaps it in onto the shoulder
C.bake("lmb_recall", 0.484, [(0, merged(CARRY, FREE)),
                             (0.176, dict(pos=(0, 0.03, -0.04), hips=(-12, 0, 22), head=(4, 0, -16), gr=(0.3, 0.6, 1.02), gd=(0, 0.9, 0.4), ga=(0, -0.4, 0.9), er=(1, 0, -0.3), fing_r=0.0, thumb_r=0.0, jaw=0.4)),
                             (0.3, dict(pos=(0, -0.05, -0.1), hips=(5, 0, -8), gr=(0.36, 0.3, 1.0), gd=(0.05, 0.1, 1.0), ga=(0, 1, -0.1), fing_r=1.0, thumb_r=1.0, e="snap")),
                             (0.484, merged(CARRY))])

# LMB held: the whirl (item 59): the hammer swung round over his head like a lasso, at arm's length, 1.25 turns a second
# while the feet stay planted. 0..0.2 goes up into it; 0.2..1.0 loops.
SPIN_T = 0.8
WIND = merged(CARRY, pos=(0, 0, -0.07), hips=(-6, 0, 0), head=(-8, 0, 0), sh=(-0.42, 0.36, 0.86), sn=(-0.4, 0.9, 0.1), er=(1, -0.2, 0.4),
              fr=(AX + 0.07, -0.08, AZ), fl=(-AX - 0.07, 0.1, AZ), jaw=0.55, brow=1.0)


def whirl_over(t, p):
    if t < 0.2:
        return
    a2 = (t - 0.2) / SPIN_T * tau
    p["gr"] = (0.31 + 0.13 * math.cos(a2), 0.04 + 0.2 * math.sin(a2), 1.4)
    p["gd"] = (math.cos(a2), math.sin(a2), 0.22)
    p["ga"] = (0, 0, 1)
    p["er"] = (0.6, -0.3, -0.6)
    add(p, "hips", (0, 3.0 * math.cos(a2), 9.0 * math.sin(a2 + 0.5)))
    add(p, "head", (0, 0, -9.0 * math.sin(a2 + 0.5)))
    add(p, "pos", (0.012 * math.cos(a2), 0.012 * math.sin(a2), 0.006 * math.sin(a2 * 2)))


C.bake("lmb_hold", 0.2 + SPIN_T, [(0, CARRY), (0.2, merged(WIND, gr=(0.44, 0.04, 1.4), gd=(1, 0, 0.22), ga=(0, 0, 1))), (0.2 + SPIN_T, {})], over=whirl_over)

# release (0.5 s): up and over, the impact at 0.08, a shudder, 0.4 s to haul it back
IMP = dict(pos=(0, 0.13, -0.17), hips=(-36, 0, 14), head=(22, 0, -10), gr=(0.1, 0.62, 0.68), gd=(-0.12, 0.8, -0.58), ga=(0.05, 0.58, 0.8), er=(0.9, 0.2, -0.3),
           fr=(AX + 0.08, -0.34, AZ), fl=(-AX, 0.36, AZ), fra=-24.0, jaw=0.95, brow=1.0, e="out")
C.bake("lmb_slam", 0.5, [(0, merged(WIND, gr=(0.42, -0.1, 1.42), gd=(0.3, -0.5, 0.8), ga=(0, 0.8, 0.5), hips=(12, 0, -12))), (0.08, IMP),
                         (0.16, dict(pos=(0, 0.13, -0.19), hips=(-38, 0, 13), e="io")),
                         (0.5, merged(STANCE, jaw=0.3, fra=0.0))])
# the perfect launch (0.85 s): a full-body heave, airborne to 0.3, a hard plant, a slow rise
C.bake("lmb_launch", 0.85, [(0, merged(WIND, gr=(0.42, -0.1, 1.42), gd=(0.3, -0.5, 0.8), ga=(0, 0.8, 0.5), hips=(12, 0, -12))),
                            (0.05, dict(pos=(0, 0.1, 0.1), hips=(-20, 0, 12), gr=(0.25, 0.25, 1.46), gd=(0.05, 0.3, 0.95), ga=(0, 0.95, -0.3), fr=(AX, -0.3, AZ - 0.0), fl=(-AX, 0.3, AZ + 0.14), jaw=0.9, e="out")),
                            (0.15, dict(pos=(0, 0.1, 0.22), hips=(-14, 0, 8), gr=(0.2, 0.42, 1.34), gd=(0.0, 0.75, 0.65), ga=(0, 0.65, -0.75), fr=(AX + 0.04, -0.05, AZ + 0.22), fl=(-AX - 0.04, 0.22, AZ + 0.26), jaw=1.0)),
                            (0.26, dict(pos=(0, 0.12, 0.1), hips=(-30, 0, 10), gr=(0.15, 0.6, 1.0), gd=(-0.05, 0.95, -0.1), ga=(0, 0.1, 1), fr=(AX + 0.06, -0.2, AZ + 0.1), fl=(-AX, 0.34, AZ + 0.02))),
                            (0.32, merged(IMP, pos=(0, 0.14, -0.22), hips=(-42, 0, 12))),
                            (0.48, dict(pos=(0, 0.13, -0.2), hips=(-38, 0, 12), e="io")),
                            (0.85, merged(STANCE, jaw=0.3, fra=0.0))])

# ---------------------------------------------------------------------- RMB, the aegis
GUARD = merged(STANCE, pos=(0, 0.03, -0.09), hips=(-20, 0, -8), head=(16, 0, 8), sh=(-0.02, 0.5, 0.92), sn=(-0.02, 1, 0.1), su=(0, -0.1, 1), el=(-0.9, 0, -0.5),
               gr=(0.5, -0.1, 0.84), gd=(0.25, -0.75, 0.55), ga=(0, 0.6, 0.8), jaw=0.5)


def guard_over(t, p):
    if t > 0.12:
        s = math.sin((t - 0.12) / 0.6 * tau)
        add(p, "sh", (0, 0.008 * s, 0.006 * s))
        add(p, "pos", (0, 0, 0.005 * s))


C.bake("rmb_guard", 0.72, [(0, CARRY), (0.1, merged(GUARD, e="out")), (0.72, {})], over=guard_over)
C.bake("guard_break", 0.65, [(0, GUARD), (0.06, dict(pos=(0, -0.1, -0.04), hips=(14, 0, 8), head=(-14, 0, 0), sh=(-0.5, 0.2, 1.1), sn=(-0.6, 0.6, 0.5), jaw=0.7, brow=0.0, e="snap")),
                             (0.3, dict(pos=(0, -0.06, -0.1), hips=(-8, 0, 4), sh=(-0.53, 0.16, 0.74), sn=(-0.92, 0.38, 0))), (0.65, CARRY)])
C.bake("guard_armed", 0.35, [(0, CARRY), (0.1, dict(hips=(-13, 0, -10), head=(10, 0, 10), jaw=0.6, brow=1.0, sh=(-0.45, 0.3, 0.86), e="out")), (0.35, CARRY)])

# ---------------------------------------------------------------------- Shift
# 360 Smash (0.75 s): 0.17 s of hard run-up, ONE turn 0.17..0.33 with the hammer at full reach, a low skidding recovery
OUT_R = dict(gr=(0.82, 0.08, 1.02), gd=(1, 0.06, 0.05), ga=(0, 0, 1), er=(0.1, -1, 0.3), fing_r=1.0)
C.bake("shift_whirl", 0.75, [(0, CARRY),
                             (0.17, merged(OUT_R, pos=(0, 0.04, -0.13), rot=(0, 0, 25), hips=(-14, 0, -26), head=(4, 0, 20), sh=(-0.3, 0.3, 0.86), sn=(-0.5, 0.8, 0.1), fr=(AX + 0.08, -0.18, AZ), fl=(-AX, 0.22, AZ), jaw=0.7, brow=1.0, e="out")),
                             (0.33, dict(rot=(0, 0, -335), hips=(-10, 0, 8), pos=(0, 0.0, -0.1), e="lin")),
                             (0.58, merged(STANCE, rot=(0, 0, -360), pos=(0, 0, -0.14), gr=(0.56, 0.3, 0.86), gd=(0.5, 0.75, -0.3), ga=(0, 0.3, 1), e="out")),
                             (0.75, merged(CARRY, rot=(0, 0, -360)))])
# Shield Charge (0.6 s): behind the prow at a full lean
CH = merged(GUARD, pos=(0, 0.08, -0.12), hips=(-34, 0, -6), head=(26, 0, 4), sh=(0.02, 0.58, 0.84), fr=(AX + 0.03, -0.32, AZ), fl=(-AX, 0.26, AZ), fra=-20.0, jaw=0.9)
C.bake("shift_charge", 0.6, [(0, CARRY), (0.16, merged(CH, e="out")), (0.34, dict(hips=(-36, 0, -4), fr=(AX + 0.03, 0.24, AZ + 0.06), fl=(-AX, -0.3, AZ), fla=-20.0, fra=0.0)), (0.6, GUARD)])
# plain short dash out of a charge (0.25 s) and the air dash, a heavy lumbering hop (0.6 s)
C.bake("dash_short", 0.25, [(0, CARRY), (0.1, dict(pos=(0, 0.04, -0.1), hips=(-22, 0, 0), fr=(AX, -0.26, AZ), fl=(-AX, 0.26, AZ), fra=-16.0, e="out")), (0.25, CARRY)])
C.bake("dash_air", 0.6, [(0, CARRY), (0.12, dict(pos=(0, 0.02, 0.1), hips=(-28, 0, 0), head=(20, 0, 0), fr=(AX, -0.2, AZ + 0.1), fl=(-AX, 0.12, AZ + 0.24), sh=(-0.52, 0.28, 0.9), gr=(0.32, 0.4, 0.98), jaw=0.6, e="out")),
                         (0.3, dict(pos=(0, 0, 0.14), fr=(AX, 0.06, AZ + 0.2), fl=(-AX, 0.0, AZ + 0.14))),
                         (0.5, dict(pos=(0, 0, -0.1), hips=(-16, 0, 0), fr=(AX + 0.04, 0.0, AZ), fl=(-AX - 0.04, 0.1, AZ))), (0.6, CARRY)])
C.bake("crush", 0.6, [(0, CARRY), (0.1, dict(hips=(-16, 0, 14), head=(8, 0, -12), jaw=1.0, brow=1.0, e="out")), (0.6, CARRY)])
# Shield Slam (0.85 s): the wind-up behind the prow, the shove at 0.33
C.bake("shield_slam", 0.85, [(0, GUARD), (0.25, merged(GUARD, pos=(0, -0.08, -0.14), hips=(-4, 0, -30), sh=(-0.42, 0.14, 0.86), sn=(-0.8, 0.5, 0.1), fr=(AX, -0.3, AZ), fl=(-AX, 0.1, AZ), jaw=0.5)),
                             (0.33, merged(GUARD, pos=(0, 0.14, -0.13), hips=(-34, 0, 22), sh=(0.08, 0.72, 0.86), fr=(AX + 0.03, -0.36, AZ), fl=(-AX, 0.34, AZ), fra=-24.0, jaw=1.0, e="snap")),
                             (0.55, dict(hips=(-30, 0, 18))), (0.85, CARRY)])

# ---------------------------------------------------------------------- E, Mending Ground (0.95 s)
C.bake("e_mend", 0.95, [(0, CARRY),
                        (0.16, dict(pos=(0, 0, -0.03), hips=(4, 0, 0), head=(-14, 0, 0), gr=(0.3, 0.34, 1.0), sh=(-0.56, 0.2, 0.84), lid=0.6, jaw=0.15)),
                        (0.26, dict(pos=(0, 0.04, -0.13), hips=(-24, 0, 6), head=(16, 0, 0), gr=(0.28, 0.52, 0.5), gd=(0.05, 0.1, 1), ga=(0, 1, 0), er=(1, 0, 0), lid=0.3, e="out")),
                        (0.45, dict(pos=(0, 0.03, -0.11), hips=(-22, 0, 6), gr=(0.28, 0.52, 0.52), lid=0.7, jaw=0.2)),
                        (0.95, CARRY)])

# ---------------------------------------------------------------------- X, Faultline
UW = merged(WIND, pos=(0, 0, -0.1), hips=(14, 0, 0), head=(-12, 0, 0), gr=(0.26, -0.04, 1.54), gd=(-0.2, -0.45, 0.85), ga=(0, 0.88, 0.47), er=(1, 0, 0.1),
            sh=(-0.56, 0.1, 0.62), jaw=1.0, brow=1.0, fr=(AX + 0.09, -0.12, AZ), fl=(-AX - 0.05, 0.14, AZ))
C.bake("x_wind", 0.5, [(0, CARRY), (0.2, merged(UW, pos=(0, 0, -0.14), e="out")), (0.4, UW), (0.5, dict(pos=(0, 0, -0.095)))])
C.bake("x_slam", 0.6, [(0, UW), (0.1, merged(IMP, pos=(0, 0.1, -0.22), hips=(-46, 0, 2), gr=(0.05, 0.56, 0.5), gd=(0, 0.45, -0.9), ga=(0, 0.9, 0.45))),
                       (0.2, dict(pos=(0, 0.1, -0.24), hips=(-47, 0, 2))), (0.36, dict(pos=(0, 0.08, -0.2), head=(8, 0, 0), jaw=1.0)), (0.6, merged(STANCE, jaw=0.5, fra=0.0))])

# ---------------------------------------------------------------------- body states
JUMP = merged(CARRY, pos=(0, 0, 0.03), hips=(-4, 0, 0), sh=(-0.56, 0.12, 0.84), fr=(AX, -0.04, AZ + 0.12), fl=(-AX, 0.12, AZ + 0.2), fra=18.0, fla=12.0, jaw=0.4)
C.bake("jump", 0.4, [(0, JUMP), (0.4, dict(fr=(AX, 0.0, AZ + 0.17), fl=(-AX, 0.06, AZ + 0.14)))])
C.bake("fall", 0.6, [(0, merged(JUMP, hips=(6, 0, 0), sh=(-0.58, 0.1, 0.9), gr=(0.3, 0.3, 1.02), fr=(AX + 0.03, 0.07, AZ + 0.12), fl=(-AX - 0.03, -0.04, AZ + 0.17))), (0.3, dict(fr=(AX + 0.03, 0.03, AZ + 0.16), fl=(-AX - 0.03, 0.02, AZ + 0.13))), (0.6, dict(fr=(AX + 0.03, 0.07, AZ + 0.12), fl=(-AX - 0.03, -0.04, AZ + 0.17)))])
C.bake("glide", 1.2, [(0, merged(CARRY, hips=(-24, 0, 0), head=(20, 0, 0), sh=(-0.6, 0.0, 0.92), sn=(-0.2, 0, -1), su=(0, 1, 0), gr=(0.56, 0.05, 1.28), gd=(0.05, -0.6, 0.8), fr=(AX, -0.2, AZ + 0.1), fl=(-AX, -0.14, AZ + 0.14), fra=30.0, fla=30.0, jaw=0.5)),
                      (0.6, dict(pos=(0, 0, 0.02), fr=(AX, -0.16, AZ + 0.14), fl=(-AX, -0.2, AZ + 0.1))), (1.2, dict(pos=(0, 0, -0.012), fr=(AX, -0.2, AZ + 0.1), fl=(-AX, -0.14, AZ + 0.14)))])
C.bake("dive", 0.6, [(0, merged(CARRY, rot=(-58, 0, 0), hips=(-8, 0, 0), head=(50, 0, 0), sh=(-0.54, -0.1, 0.8), gr=(0.3, 0.2, 1.2), fr=(AX, -0.5, AZ + 0.3), fl=(-AX, -0.42, AZ + 0.3), fra=40.0, fla=40.0, jaw=0.9)), (0.6, {})])
DOWN = merged(CARRY, pos=(0, -0.05, -0.32), rot=(14, 0, 0), hips=(-34, 0, 6), head=(30, 0, -6), gr=(0.42, 0.42, 0.32), gd=(0.3, 0.9, 0.1), ga=(0, -0.1, 1), sh=(-0.5, 0.36, 0.3), sn=(0.1, 0.1, 1), su=(0, 1, 0),
              fr=(AX + 0.12, 0.34, AZ), fl=(-AX - 0.1, -0.26, AZ + 0.02), jaw=0.3, lid=0.5, brow=0.0)
C.bake("downed", 1.6, [(0, DOWN), (1.6, {})], over=breathe(1.6, 0.8))
C.bake("stun", 0.9, [(0, merged(CARRY, pos=(0, 0, -0.06), hips=(-16, 0, 0), head=(-6, 0, 0), jaw=0.5, lid=0.5)), (0.45, dict(hips=(-16, 8, 4), head=(-6, -10, -8))), (0.9, dict(hips=(-16, 0, 0), head=(-6, 0, 0)))], over=None)
C.bake("revive", 1.0, [(0, merged(CARRY, pos=(0, 0.04, -0.3), hips=(-30, 0, 0), head=(18, 0, 0), sh=(-0.3, 0.5, 0.44), sn=(-0.5, 0.2, 0.7), su=(0.2, 0.9, 0), fr=(AX + 0.03, -0.34, AZ + 0.04), fl=(-AX, 0.3, AZ), fra=-30.0, gr=(0.2, 0.5, 0.58), gd=(0.3, 0.4, 0.8), lid=0.4, jaw=0.2)), (0.5, dict(hips=(-34, 0, 0))), (1.0, dict(hips=(-30, 0, 0)))])
C.bake("death", 1.3, [(0, merged(CARRY, jaw=0.9)), (0.2, dict(pos=(0, -0.04, -0.1), hips=(10, 0, 0), head=(-20, 0, 0), jaw=1.0)),
                      (0.75, merged(DOWN, e="in")), (1.0, dict(pos=(0, -0.2, -0.46), rot=(58, 0, 0), hips=(-5, 0, 0), head=(-20, 0, 10), lid=1.0, jaw=0.3, e="snap")),
                      (1.3, dict(pos=(0, -0.22, -0.5), rot=(74, 0, 0), lid=1.0))])

# ---------------------------------------------------------------------- one-shots
C.bake("land", 0.36, [(0, merged(CARRY, pos=(0, 0, -0.14), hips=(-22, 0, 0), head=(16, 0, 0), sh=(-0.58, 0.12, 0.62), gr=(0.3, 0.32, 0.82), fr=(AX + 0.05, -0.04, AZ), fl=(-AX - 0.05, 0.08, AZ), jaw=0.6)), (0.36, CARRY)])
C.bake("hit", 0.36, [(0, CARRY), (0.06, dict(pos=(0, -0.05, -0.03), hips=(11, 7, 6), head=(-14, 0, -6), jaw=0.7, lid=0.5, brow=1.0, e="snap")), (0.36, CARRY)])
# the emote: a great belly laugh, head back, slapping the belly with the shield hand... he is enjoying himself
LAUGH = merged(CARRY, hips=(11, 0, 0), head=(-16, 0, 0), jaw=1.0, lid=0.8)


def laugh(t, p):
    s = math.sin(t * 15.0) * min(1.0, t * 4) * min(1.0, (2.0 - t) * 4)
    add(p, "pos", (0, 0, 0.02 * abs(s)))
    add(p, "hips", (2.5 * s, 0, 0))
    add(p, "head", (3.0 * s, 0, 0))
    add(p, "gr", (0, 0, 0.012 * s))


C.bake("emote_laugh", 2.0, [(0, CARRY), (0.3, LAUGH), (1.7, dict(hips=(9, 0, 0))), (2.0, CARRY)], over=laugh)
# Fusion: he braces, drives the hammer down and heaves up with the power, arms wide
C.bake("fuse", 1.2, [(0, CARRY), (0.3, merged(WIND, pos=(0, 0, -0.16), hips=(-30, 0, 0), head=(26, 0, 0), gr=(0.3, 0.42, 0.72), sh=(-0.3, 0.3, 0.72), lid=1.0, jaw=0.0)),
                     (0.7, dict(pos=(0, 0, 0.02), hips=(14, 0, 0), head=(-22, 0, 0), gr=(0.72, 0.1, 1.46), gd=(0.4, 0, 0.9), ga=(0, 1, 0), sh=(-0.8, 0.1, 1.3), sn=(-0.5, 0.7, 0.4), lid=0.0, jaw=1.0, brow=1.0, e="out")),
                     (1.0, dict(pos=(0, 0, 0.0))), (1.2, CARRY)])

bpy.context.scene.render.fps = A.FPS
# the rest shown on load
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

if OUT_GLB != "-":
    ad = arm.animation_data
    # one NLA track per clip: the exporter takes each as a glTF animation by its track's name
    for act in [x for x in bpy.data.actions if x.name in C.lengths]:
        ad.action = act
        if len(act.slots) and ad.action_slot is None:
            ad.action_slot = act.slots[0]
        tr = ad.nla_tracks.new()
        tr.name = act.name
        st = tr.strips.new(act.name, 0, act)
        ad.action = None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=93, export_extras=False, export_force_sampling=True,
                              export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False,
                              export_vertex_color="MATERIAL")
    print("exported", os.path.getsize(OUT_GLB))
print("clips", json.dumps(C.lengths))
