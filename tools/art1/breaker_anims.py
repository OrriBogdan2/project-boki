"""Breaker the Barnacle Knight's clips (ART-1), keyed by hand on the contract armature and timed to his kit's real numbers
(content/archetypes/bulwark.json, KMovesPinBjorn), then the .glb export:
  blender -b WORK/breaker_art1.blend --python tools/art1/breaker_anims.py -- WORK/breaker_anims.blend OUT.glb
He is a walking hull: everything starts from the ball of his body rocking on two stubby legs, and the drum's weight
arrives late."""
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
FR, FL = (AX, -0.02, AZ), (-AX, 0.04, AZ)
tau = math.tau
SZ = float(C.rig.P["upper_arm.R"].z)    # shoulder height and width, for reading the keys below
SHX = float(C.rig.P["upper_arm.R"].x)


def merged(*ps, **kw):
    o = {}
    for p in ps:
        o.update(p)
    o.update(kw)
    return o


def add(p, c, v):
    p[c] = tuple(x + y for x, y in zip(p.get(c, (0, 0, 0)), v))


def sp(x, y, dz):
    """The right hand, from the right shoulder: out x, forward y, up dz."""
    return (SHX + x, y, SZ + dz)


def sl(x, y, dz):
    """The left hand, from the left shoulder: out x (to his left), forward y, up dz."""
    return (-SHX - x, y, SZ + dz)


# He is a ball on two stubs. The legs can't lunge, so his weight moves by the whole hull tipping on its feet (`rot`), and his
# arms hang off the sides, so swings go wide round the hull instead of across it.
CARRY = dict(pos=(0, 0, 0.0), hips=(-2, 0, -2), head=(1, 0, 2),
             gr=sp(0.06, 0.1, -0.3), gd=(-0.05, 0.8, -0.6), ga=(0.99, 0.06, 0.0), er=(0.95, -0.25, -0.1), fing_r=1.0, thumb_r=1.0,
             sh=sl(0.09, 0.04, -0.41), sn=(-0.95, 0.3, 0.0), su=(0.0, 0.0, 1.0), el=(-0.9, -0.4, 0.1), fing_l=0.9, thumb_l=0.8,
             fr=FR, fl=FL, fra=0.0, fla=0.0, wtw=(0, 0, 0))
FREE = dict(gr=sp(0.06, 0.1, -0.43), gd=(0.05, 1.0, -0.2), ga=(0.1, 0.2, 1.0), er=(0.9, -0.3, -0.3), fing_r=0.35, thumb_r=0.3)
# the fighting stance (item 52): rocked onto the left foot, door half across him, hammer hauled up behind the right shoulder
STANCE = dict(pos=(0, 0, -0.03), rot=(-5, 3, -8), hips=(-3, 0, -6), head=(4, 0, 12),
              gr=sp(0.1, 0.05, 0.14), gd=(0.3, -0.5, 0.8), ga=(0.0, 0.85, 0.5), er=(1.0, -0.2, -0.6), fing_r=1.0, thumb_r=1.0,
              sh=sl(-0.14, 0.3, -0.26), sn=(-0.55, 0.83, 0.0), su=(0.0, 0.0, 1.0), el=(-0.9, -0.1, -0.5), fing_l=0.9, thumb_l=0.9,
              fr=(AX + 0.03, -0.06, AZ), fl=(-AX - 0.02, 0.07, AZ))
OVER = dict(gr=sp(0.04, -0.12, 0.4), gd=(0.25, -0.45, 0.85), ga=(0.0, 0.88, 0.47), er=(1.0, 0.0, -0.3))   # up behind him


def breathe(period, amp=1.0):
    def f(t, p):
        s = math.sin(t / period * tau)
        add(p, "pos", (0, 0, 0.005 * amp * s))
        add(p, "rot", (1.0 * amp * s, 0.8 * amp * math.sin(t / period * tau * 0.5), 0))
        add(p, "head", (-0.8 * amp * s, 0, 2.5 * math.sin(t / period * tau * 0.5 + 1)))
        add(p, "gr", (0, 0, 0.007 * amp * math.sin(t / period * tau - 0.8)))
        add(p, "sh", (0, 0, 0.005 * amp * math.sin(t / period * tau - 1.2)))
    return f


C.bake("idle", 3.2, [(0, CARRY), (3.2, {})], over=breathe(3.2, 1.0), loop=True)
C.bake("stance", 1.6, [(0, STANCE), (1.6, {})], over=breathe(1.6, 1.3), loop=True)


# ---------------------------------------------------------------------- walk, run: a waddle, the whole hull rocking
def foot(ph, stride, lift, duty=0.58):
    ph = ph % 1.0
    if ph < duty:
        u = ph / duty
        return stride * (1 - 2 * u), 0.0, 0.0
    u = (ph - duty) / (1 - duty)
    e = u * u * (3 - 2 * u)
    return stride * (-1 + 2 * e), lift * math.sin(u * math.pi) ** 0.8, 18.0 * math.sin(u * math.pi) * (1 - u)


def gait(period, stride, lift, lean, dirv, bob, roll, twist, swing, duty=0.58):
    dx, dy = dirv

    def f(t, p):
        ph = t / period
        for side, off, sign in (("r", 0.0, 1), ("l", 0.5, -1)):
            d, u, pit = foot(ph + off, stride, lift, duty)
            p["f" + side] = (AX * sign + dx * d, (-0.02 if sign > 0 else 0.03) + dy * d, AZ + u)
            p["f" + side + "a"] = pit * abs(dy)
        w = math.sin(ph * tau)
        c2 = math.cos(ph * 2 * tau)
        # the hull rolls onto each planted foot; that roll IS the walk
        add(p, "pos", (w * 0.022, 0, -bob * (0.5 + 0.5 * c2)))
        add(p, "rot", (lean * dy, roll * w, twist * w))
        add(p, "head", (-lean * 0.6 * dy, -roll * 0.6 * w, -twist * 0.5 * w))
        add(p, "gr", (0.0, swing * 0.3 * w, 0.015 * c2))
        add(p, "sh", (0.0, swing * w, 0.012 * math.sin(ph * 2 * tau + 1)))
    return f


DIRS = {"f": (0, 1), "b": (0, -1), "l": (-1, 0), "r": (1, 0)}
for nm, d in DIRS.items():
    # (no foot slide: a planted foot travels back at his ground speed: stride x 2 / (period x duty) x his 2.0 size = 2.0 and 4.8 m/s)
    C.bake("walk_" + nm, 0.5, [(0, CARRY), (0.5, {})], loop=True, over=gait(0.5, 0.145, 0.05, -3.0, d, 0.012, 6.0, 6.0, 0.05))
    C.bake("run_" + nm, 0.36, [(0, merged(CARRY, gr=sp(0.08, 0.14, -0.28), sh=sl(0.08, 0.14, -0.33))), (0.36, {})], loop=True,
           over=gait(0.36, 0.18, 0.08, -11.0, d, 0.02, 8.0, 9.0, 0.09, 0.42))
C.bake("arm_free", 0.5, [(0, merged(CARRY, FREE)), (0.5, {})], loop=True)

# ---------------------------------------------------------------------- LMB
# the throw (0.5 s; it leaves ~0.12 s in): the hull rocks back and away, the arm hauls round the side and over, then the
# whole ball tips after it
TH_BACK = merged(OVER, pos=(0, -0.03, -0.02), rot=(10, 0, -24), head=(-6, 0, 20), fr=(AX, -0.05, AZ), fl=(-AX, 0.06, AZ))
TH_TOP = dict(rot=(2, 0, -6), head=(0, 0, 6), gr=sp(0.02, 0.1, 0.42), gd=(0.1, 0.2, 0.97), ga=(0, 0.97, -0.2), er=(1, -0.2, 0.1), fing_r=0.8, thumb_r=0.8, e="in")
TH_OUT = dict(pos=(0, 0.06, -0.03), rot=(-20, 4, 20), head=(12, 0, -14), gr=sp(-0.02, 0.42, 0.06), gd=(0, 0.95, 0.25), ga=(0, -0.25, 0.95), er=(0.9, 0.1, -0.3),
              fing_r=0.05, thumb_r=0.1, fra=-14.0, fr=(AX, -0.08, AZ + 0.01), fl=(-AX, 0.09, AZ), e="io")
C.bake("lmb_throw", 0.5, [(0, CARRY), (0.07, merged(TH_BACK, e="io")), (0.11, TH_TOP), (0.19, TH_OUT),
                          (0.3, dict(rot=(-14, 2, 16), gr=sp(0.04, 0.34, -0.2), fing_r=0.25)),
                          (0.5, merged(CARRY, FREE, rot=(0, 0, 0), fra=0.0))])
# the recall: the empty hand goes out for it, the catch rocks him back on his heels
C.bake("lmb_recall", 0.484, [(0, merged(CARRY, FREE)),
                             (0.176, dict(rot=(-8, 0, 12), head=(4, 0, -10), gr=sp(-0.03, 0.42, 0.02), gd=(0, 0.9, 0.4), ga=(0, -0.4, 0.9), er=(1, 0, -0.3), fing_r=0.0, thumb_r=0.0)),
                             (0.3, dict(pos=(0, -0.04, -0.03), rot=(10, 0, -6), gr=sp(0.06, 0.22, -0.02), gd=(0.05, 0.1, 1.0), ga=(0, 1, -0.1), fing_r=1.0, thumb_r=1.0, e="snap")),
                             (0.484, merged(CARRY, rot=(0, 0, 0)))])
# LMB held: the whirl (item 59): the drum swung round over the helmet, the hull counter-rocking under it. 0..0.2 goes up;
# from 0.2 one full turn: the kit's angle seeks it (WardenClips.PHASE), so lmb.spin_turns drives it
SPIN_T = 0.85
WIND = merged(CARRY, pos=(0, 0, -0.03), hips=(0, 0, 0), head=(-6, 0, 0), sh=sl(-0.1, 0.26, -0.3), sn=(-0.5, 0.85, 0.1), er=(1, -0.2, 0.4),
              fr=(AX + 0.02, -0.03, AZ), fl=(-AX - 0.02, 0.04, AZ))


def whirl_over(t, p):
    if t < 0.2:
        return
    a2 = (t - 0.2) / SPIN_T * tau
    p["gr"] = (0.38 + 0.2 * math.cos(a2), 0.2 * math.sin(a2), 1.02)
    # (the haft aims the head at the kit's angle round his axis, not round the shoulder the hand circles)
    p["gd"] = (0.95 * math.cos(a2) - p["gr"][0], 0.95 * math.sin(a2) - p["gr"][1], 0.2)
    p["ga"] = (0, 0, 1)
    p["er"] = (0.6, -0.3, -0.6)
    add(p, "rot", (3.0 * math.sin(a2), -4.0 * math.cos(a2), 0))
    add(p, "hips", (0, 0, 14.0 * math.sin(a2 - 0.6)))
    add(p, "head", (0, 0, -14.0 * math.sin(a2 - 0.6)))


C.bake("lmb_hold", 0.2 + SPIN_T, [(0, CARRY), (0.2, merged(WIND, gr=(0.58, 0.0, 1.02), gd=(1, 0, 0.22), ga=(0, 0, 1))), (0.2 + SPIN_T, {})], over=whirl_over)
# the release (0.5 s): up behind him, the impact at 0.08: the hull slams forward onto its toes, a shudder, then he hauls it up
UP = merged(WIND, OVER, rot=(9, 0, -8))
IMP = dict(pos=(0, 0.1, -0.05), rot=(-24, 3, 8), hips=(-6, 0, 6), head=(12, 0, -6), gr=sp(-0.1, 0.44, -0.3), gd=(-0.12, 0.8, -0.58), ga=(0.05, 0.58, 0.8), er=(0.9, 0.2, -0.3),
           fr=(AX, -0.11, AZ + 0.02), fl=(-AX, 0.12, AZ), fra=-20.0, e="io")
C.bake("lmb_slam", 0.5, [(0, UP), (0.08, IMP), (0.16, dict(pos=(0, 0.1, -0.06), rot=(-26, 3, 8), e="io")), (0.5, merged(STANCE, fra=0.0))])
# the perfect launch (0.85 s): the ball leaves the ground, feet tucked under, and lands drum-first
C.bake("lmb_launch", 0.85, [(0, UP),
                            (0.09, dict(pos=(0, 0.06, 0.08), rot=(-8, 0, 6), gr=sp(0.0, 0.2, 0.42), gd=(0.05, 0.3, 0.95), ga=(0, 0.95, -0.3), fr=(AX, -0.08, AZ + 0.02), fl=(-AX, 0.1, AZ + 0.05), e="io")),
                            (0.17, dict(pos=(0, 0.08, 0.15), rot=(-16, 0, 4), gr=sp(-0.02, 0.36, 0.2), gd=(0.0, 0.75, 0.65), ga=(0, 0.65, -0.75), fr=(AX, 0.0, AZ + 0.08), fl=(-AX, 0.06, AZ + 0.09))),
                            (0.26, dict(pos=(0, 0.1, 0.07), rot=(-24, 0, 6), gr=sp(-0.06, 0.44, -0.08), gd=(-0.05, 0.95, -0.1), ga=(0, 0.1, 1), fr=(AX, -0.05, AZ + 0.04), fl=(-AX, 0.1, AZ + 0.02))),
                            (0.32, merged(IMP, pos=(0, 0.12, -0.07), rot=(-28, 3, 8))),
                            (0.48, dict(pos=(0, 0.12, -0.06), rot=(-25, 3, 8), e="io")),
                            (0.85, merged(STANCE, fra=0.0))])

# ---------------------------------------------------------------------- RMB, the aegis: the door dead ahead, the hull sunk behind it
GUARD = merged(STANCE, pos=(0, 0.02, -0.05), rot=(-9, 0, -3), hips=(-3, 0, -2), head=(8, 0, 3), sh=sl(-0.3, 0.42, -0.34), sn=(-0.08, 1, 0.05), su=(0, -0.05, 1), el=(-0.9, 0, -0.5),
               gr=sp(0.12, -0.12, -0.2), gd=(0.3, -0.8, 0.5), ga=(0, 0.55, 0.83))


def guard_over(t, p):
    if t > 0.12:
        s = math.sin((t - 0.12) / 0.6 * tau)
        add(p, "sh", (0, 0.006 * s, 0.005 * s))


C.bake("rmb_guard", 0.72, [(0, CARRY), (0.1, merged(GUARD, e="out")), (0.72, {})], over=guard_over)
C.bake("guard_break", 0.65, [(0, GUARD), (0.06, dict(pos=(0, -0.06, 0.0), rot=(14, -5, 6), head=(-10, 0, 0), sh=sl(0.06, 0.24, 0.0), sn=(-0.6, 0.6, 0.5), e="snap")),
                             (0.3, dict(rot=(4, 0, 2), sh=sl(0.06, 0.12, -0.38), sn=(-0.86, 0.5, 0))), (0.65, CARRY)])
C.bake("guard_armed", 0.35, [(0, CARRY), (0.1, dict(rot=(-5, 0, -8), head=(6, 0, 8), sh=sl(-0.04, 0.22, -0.3), e="out")), (0.35, CARRY)])

# ---------------------------------------------------------------------- Shift
# 360 Smash (0.75 s): 0.17 s of leaning in, ONE full spin of the whole ball 0.17..0.33, the hammer straight out, then a skid
OUT_R = dict(gr=sp(0.43, 0.06, 0.0), gd=(1, 0.06, 0.05), ga=(0, 0, 1), er=(0.1, -1, 0.3), fing_r=1.0)
C.bake("shift_whirl", 0.75, [(0, CARRY),
                             (0.17, merged(OUT_R, pos=(0, 0.03, -0.04), rot=(-12, 0, 28), head=(2, 0, 12), sh=sl(-0.1, 0.26, -0.2), sn=(-0.5, 0.8, 0.1), fr=(AX, -0.08, AZ), fl=(-AX, 0.08, AZ), e="out")),
                             (0.33, dict(rot=(-8, 0, -332), pos=(0, 0.0, -0.03), e="lin")),
                             (0.58, merged(STANCE, rot=(-6, 3, -360), pos=(0, 0, -0.05), gr=sp(0.3, 0.26, -0.15), gd=(0.5, 0.75, -0.3), ga=(0, 0.3, 1), e="out")),
                             (0.75, merged(CARRY, rot=(0, 0, -360)))])
# Shield Charge (0.6 s): the whole hull thrown behind the door
CH = merged(GUARD, pos=(0, 0.06, -0.05), rot=(-22, 0, -2), head=(16, 0, 2), sh=sl(-0.3, 0.44, -0.3), fr=(AX, -0.11, AZ), fl=(-AX, 0.09, AZ), fra=-16.0)
C.bake("shift_charge", 0.6, [(0, CARRY), (0.16, merged(CH, e="out")), (0.34, dict(rot=(-24, 0, -2), fr=(AX, 0.09, AZ + 0.03), fl=(-AX, -0.1, AZ), fla=-16.0, fra=0.0)), (0.6, GUARD)])
C.bake("dash_short", 0.25, [(0, CARRY), (0.1, dict(pos=(0, 0.03, -0.03), rot=(-16, 0, 0), fr=(AX, -0.1, AZ), fl=(-AX, 0.1, AZ), fra=-12.0, e="out")), (0.25, CARRY)])
C.bake("dash_air", 0.6, [(0, CARRY), (0.12, dict(pos=(0, 0.02, 0.07), rot=(-24, 0, 0), head=(14, 0, 0), fr=(AX, -0.08, AZ + 0.04), fl=(-AX, 0.05, AZ + 0.09), sh=sl(0.04, 0.18, -0.26), gr=sp(0.05, 0.3, -0.34), e="out")),
                         (0.3, dict(pos=(0, 0, 0.1), rot=(-14, 0, 0), fr=(AX, 0.03, AZ + 0.08), fl=(-AX, 0.0, AZ + 0.06))),
                         (0.5, dict(pos=(0, 0, -0.05), rot=(-10, 0, 0), fr=(AX + 0.02, 0.0, AZ), fl=(-AX - 0.02, 0.04, AZ))), (0.6, CARRY)])
C.bake("crush", 0.6, [(0, CARRY), (0.1, dict(rot=(-10, 0, 12), head=(4, 0, -8), e="out")), (0.6, CARRY)])
# Shield Slam (0.85 s): wound back behind the door, the shove at 0.33 with everything he has
C.bake("shield_slam", 0.85, [(0, GUARD), (0.25, merged(GUARD, pos=(0, -0.05, -0.05), rot=(10, 0, -26), sh=sl(-0.14, 0.2, -0.3), sn=(-0.8, 0.5, 0.1), fr=(AX, -0.1, AZ), fl=(-AX, 0.03, AZ))),
                             (0.33, merged(GUARD, pos=(0, 0.1, -0.05), rot=(-24, 0, 22), sh=sl(-0.36, 0.46, -0.3), fr=(AX, -0.12, AZ), fl=(-AX, 0.11, AZ), fra=-18.0, e="snap")),
                             (0.55, dict(rot=(-20, 0, 18))), (0.85, CARRY)])

# ---------------------------------------------------------------------- E, Mending Ground: the drum lifted and set down gently
C.bake("e_mend", 0.95, [(0, CARRY),
                        (0.16, dict(rot=(5, 0, 0), head=(-10, 0, 0), gr=sp(-0.02, 0.26, -0.06), gd=(0, 0.3, 0.95), ga=(0, 0.95, -0.3))),
                        (0.26, dict(pos=(0, 0.03, -0.05), rot=(-16, 0, 4), head=(10, 0, 0), gr=sp(-0.04, 0.42, -0.42), gd=(0.05, 0.1, -1), ga=(0, 1, 0.1), e="out")),
                        (0.45, dict(pos=(0, 0.03, -0.05), rot=(-15, 0, 4))),
                        (0.95, CARRY)])

# ---------------------------------------------------------------------- X, Faultline
UW = merged(WIND, pos=(0, 0, -0.04), rot=(12, 0, 0), head=(-10, 0, 0), gr=sp(-0.04, -0.06, 0.43), gd=(-0.1, -0.5, 0.85), ga=(0, 0.85, 0.5), er=(1, 0, 0.1),
            sh=sl(0.06, 0.06, -0.32), fr=(AX + 0.03, -0.05, AZ), fl=(-AX - 0.02, 0.06, AZ))
C.bake("x_wind", 0.5, [(0, CARRY), (0.2, merged(UW, pos=(0, 0, -0.05), e="out")), (0.4, UW), (0.5, dict(pos=(0, 0, -0.035)))])
C.bake("x_slam", 0.6, [(0, UW), (0.1, merged(IMP, pos=(0, 0.1, -0.06), rot=(-30, 0, 2), gr=sp(-0.14, 0.42, -0.36), gd=(0, 0.45, -0.9), ga=(0, 0.9, 0.45))),
                       (0.2, dict(pos=(0, 0.1, -0.07), rot=(-32, 0, 2))), (0.36, dict(pos=(0, 0.08, -0.06), rot=(-24, 0, 2))), (0.6, merged(STANCE, fra=0.0))])

# ---------------------------------------------------------------------- crouch (item 143): a hammer-brace. The hull sinks and tips
# forward behind the door held low ahead, the hammer hauled in on his shoulder ready to swing, one foot forward, the helmet up scanning.
BRACE = merged(CARRY, pos=(0, 0.03, -0.1), rot=(-16, 0, -7), hips=(-3, 0, -4), head=(13, 0, 9),
               gr=sp(0.03, 0.04, 0.02), gd=(0.06, -0.62, 0.78), ga=(0.05, 0.78, 0.62), er=(1.0, -0.2, -0.6),
               sh=sl(-0.2, 0.34, -0.36), sn=(-0.3, 0.95, 0.0), su=(0.0, 0.0, 1.0), el=(-0.9, 0.0, -0.5),
               fr=(AX + 0.03, -0.09, AZ + 0.025), fl=(-AX - 0.02, 0.09, AZ), fra=-18.0, fla=0.0)


def scan(t, p):
    add(p, "head", (0, 0, 16.0 * math.sin(t / 2.4 * tau)))
    add(p, "pos", (0, 0, 0.004 * math.sin(t / 1.2 * tau)))
    add(p, "sh", (0, 0, 0.005 * math.sin(t / 1.2 * tau - 1)))


C.bake("crouch_idle", 2.4, [(0, BRACE), (2.4, {})], over=scan, loop=True)
# (the sneak: 2.42 m/s in game, so a planted foot travels back at that: stride x 2 / (period x duty) x his 2.0 size)
for nm, d in DIRS.items():
    C.bake("crouch_" + nm, 0.6, [(0, BRACE), (0.6, {})], loop=True, over=gait(0.6, 0.113, 0.035, 0.0, d, 0.01, 5.0, 5.0, 0.03, 0.62))
C.bake("crouch_in", 0.3, [(0, CARRY), (0.1, merged(BRACE, pos=(0, 0.03, -0.125), e="out")), (0.3, BRACE)])
C.bake("crouch_out", 0.3, [(0, BRACE), (0.1, dict(pos=(0, 0, 0.012), rot=(-3, 0, -2), e="out")), (0.3, CARRY)])

# ---------------------------------------------------------------------- body states
JUMP = merged(CARRY, pos=(0, 0, 0.04), rot=(6, 0, 0), head=(-4, 0, 3), sh=sl(0.1, 0.1, -0.28), gr=sp(0.1, 0.16, -0.36), fr=(AX, -0.02, AZ + 0.05), fl=(-AX, 0.05, AZ + 0.09), fra=14.0, fla=10.0)
C.bake("jump", 0.4, [(0, JUMP), (0.4, dict(fr=(AX, 0.0, AZ + 0.08), fl=(-AX, 0.03, AZ + 0.06)))])
FALLK = dict(sh=sl(0.14, 0.08, -0.2), gr=sp(0.14, 0.14, -0.28))
C.bake("fall", 0.6, [(0, merged(JUMP, FALLK, rot=(9, 0, 0), fr=(AX + 0.01, 0.03, AZ + 0.05), fl=(-AX - 0.01, -0.02, AZ + 0.08))), (0.3, dict(fr=(AX + 0.01, 0.01, AZ + 0.07), fl=(-AX - 0.01, 0.01, AZ + 0.06))), (0.6, dict(fr=(AX + 0.01, 0.03, AZ + 0.05), fl=(-AX - 0.01, -0.02, AZ + 0.08)))])
# the glider: both fists up on the bar over his shoulders (the rig's grips), the ball hanging under it, feet dangling
GL = merged(CARRY, rot=(-12, 0, 0), head=(10, 0, 0), gr=sp(-0.04, -0.05, 0.36), gd=(0.1, -0.7, -0.7), ga=(0.95, 0, 0.1), sh=sl(-0.04, -0.05, 0.36), sn=(-0.2, 0, -1), su=(0, 1, 0),
            fr=(AX, -0.06, AZ + 0.05), fl=(-AX, -0.04, AZ + 0.07), fra=24.0, fla=24.0)
C.bake("glide", 1.2, [(0, GL), (0.6, dict(pos=(0, 0, 0.012), fr=(AX, -0.05, AZ + 0.07), fl=(-AX, -0.06, AZ + 0.05))), (1.2, dict(pos=(0, 0, -0.006), fr=(AX, -0.06, AZ + 0.05), fl=(-AX, -0.04, AZ + 0.07)))])
C.bake("dive", 0.6, [(0, merged(CARRY, rot=(-58, 0, 0), head=(40, 0, 0), sh=sl(0.1, -0.1, -0.2), gr=sp(0.1, 0.1, -0.2), fr=(AX, -0.1, AZ + 0.08), fl=(-AX, -0.08, AZ + 0.08), fra=30.0, fla=30.0)), (0.6, {})])
# downed: tipped over backwards onto the hull's round, feet up, drum and door dropped
DOWN = merged(CARRY, pos=(0, -0.08, 0.05), rot=(38, 8, 6), hips=(0, 0, 4), head=(-14, 0, -6), gr=sp(0.08, 0.34, -0.42), gd=(0.3, 0.9, 0.1), ga=(0, -0.1, 1), sh=sl(0.06, 0.24, -0.42), sn=(0.1, 0.1, 1), su=(0, 1, 0),
              fr=(AX + 0.03, 0.12, AZ + 0.04), fl=(-AX - 0.03, 0.1, AZ + 0.06))
C.bake("downed", 1.6, [(0, DOWN), (1.6, {})], over=breathe(1.6, 0.8))
C.bake("stun", 0.9, [(0, merged(CARRY, rot=(-4, 5, 0), head=(-4, 0, 0))), (0.45, dict(rot=(-4, -5, 6), head=(-4, -10, -8))), (0.9, dict(rot=(-4, 5, 0), head=(-4, 0, 0)))])
C.bake("revive", 1.0, [(0, merged(CARRY, pos=(0, 0.04, -0.07), rot=(-24, 0, 0), head=(14, 0, 0), sh=sl(-0.2, 0.42, -0.42), sn=(-0.5, 0.2, 0.7), su=(0.2, 0.9, 0), gr=sp(-0.1, 0.4, -0.4), gd=(0.3, 0.4, 0.8), fra=-14.0)), (0.5, dict(rot=(-27, 0, 0))), (1.0, dict(rot=(-24, 0, 0)))])
C.bake("death", 1.3, [(0, CARRY), (0.2, dict(pos=(0, -0.03, -0.02), rot=(10, 0, 0), head=(-14, 0, 0))),
                      (0.75, merged(DOWN, e="in")), (1.0, dict(pos=(0, -0.14, 0.3), rot=(80, 8, 8), e="snap")), (1.3, dict(pos=(0, -0.14, 0.34), rot=(86, 8, 10)))])

# ---------------------------------------------------------------------- one-shots
C.bake("land", 0.36, [(0, merged(CARRY, pos=(0, 0, -0.06), rot=(-12, 0, 0), head=(10, 0, 0), sh=sl(0.1, 0.12, -0.34), gr=sp(0.1, 0.2, -0.32), fr=(AX + 0.02, -0.02, AZ), fl=(-AX - 0.02, 0.04, AZ))), (0.36, CARRY)])

def hit(peak, bump):
    """A hit (0.36 s): the blow lands on the hips, since the upper-body hit path drops root. The hips bump peaks at 0.06 s
    and is carried back along 1 - u^2 (a heavy body, docs/art/REACT_AUDIT.md), keyed in three hips-only steps."""
    at = lambda f: tuple(c + f * b for c, b in zip(CARRY["hips"], bump))
    mid = [(0.06 + 0.075 * n, dict(hips=at(1 - (0.25 * n) ** 2), e="lin")) for n in (1, 2, 3)]
    return [(0, CARRY), (0.06, dict(peak, hips=at(1.0), e="snap"))] + mid + [(0.36, CARRY)]


C.bake("hit_f", 0.36, hit(dict(pos=(0, -0.04, 0.0), rot=(10, 5, 6), head=(-10, 0, -6)), (14, 0, 3)))
C.bake("hit_b", 0.36, hit(dict(pos=(0, 0.04, -0.01), rot=(-10, -4, -5), head=(8, 0, 5)), (-12, 0, -3)))
# the emote: he rocks with laughter, the door hand patting his hull
LAUGH = merged(CARRY, rot=(10, 0, 0), head=(-12, 0, 0), sh=sl(-0.2, 0.36, -0.3), sn=(-0.6, 0.75, 0.1), el=(-0.9, 0.1, -0.5))


def laugh(t, p):
    s = math.sin(t * 15.0) * min(1.0, t * 4) * min(1.0, (2.0 - t) * 4)
    add(p, "pos", (0, 0, 0.018 * abs(s)))
    add(p, "rot", (3.5 * s, 3.0 * math.sin(t * 7.0), 0))
    add(p, "sh", (0, 0.04 * abs(s), 0))


C.bake("emote", 2.0, [(0, CARRY), (0.3, LAUGH), (1.7, dict(rot=(8, 0, 0))), (2.0, CARRY)], over=laugh)
# Fusion: he sinks into himself, then throws both arms wide as the sea comes up through him
C.bake("fuse", 0.8, [(0, CARRY), (0.2, merged(WIND, pos=(0, 0, -0.07), rot=(-20, 0, 0), head=(16, 0, 0), gr=sp(-0.06, 0.3, -0.26), sh=sl(-0.1, 0.3, -0.3))),
                     (0.45, dict(pos=(0, 0, 0.03), rot=(10, 0, 0), head=(-16, 0, 0), gr=sp(0.3, 0.1, 0.3), gd=(0.4, 0, 0.9), ga=(0, 1, 0), sh=sl(0.3, 0.1, 0.3), sn=(-0.5, 0.7, 0.4), e="out")),
                     (0.6, dict(pos=(0, 0, 0.0))), (0.8, CARRY)])

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
