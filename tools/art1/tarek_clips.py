"""Tarek's clips (ART-1), keyed by hand on the contract armature and timed to his kit (content/archetypes/dolm.json,
KMovesStone's beats), then the .glb export:
  blender -b WORK/tarek.blend --python tools/art1/tarek_clips.py -- WORK/tarek_anims.blend OUT.glb
Young, nimble, cheerful: he stands on the balls of his feet, sways like he hears the ground, and the huge fists are
thrown from the hips, late and loose. He grins through nearly everything; he blinks at nothing, he has no eyes to blink."""
import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fistkit as A  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = a[0], a[1]
arm = bpy.data.objects["Armature"]
C = A.Clips(arm)
AX = float(C.rig.P["foot.R"].x)
AZ = float(C.rig.P["foot.R"].z)
SX = float(C.rig.P["upper_arm.R"].x)
SZ = float(C.rig.P["upper_arm.R"].z)
HZ = float(C.rig.P["hips"].z)
tau = math.tau


def m(*ps, **kw):
    o = {}
    for p in ps:
        o.update(p)
    o.update(kw)
    return o


def add(p, c, v):
    p[c] = tuple(x + y for x, y in zip(p[c], v)) if not isinstance(p[c], (int, float)) else p[c] + v


def hand(x, y, z):
    """A hand target relative to the shoulder (right side; mirror() for the left)."""
    return (SX + x + 0.07, y, SZ + z)      # (the stone arm's bulk keeps it off his side)


def lhand(x, y, z):
    return (-SX - x - 0.15, y, SZ + z)     # (the huge stone arm stands well off his side)


# his loose rest: the weight on the left leg, the right foot turned out, fists half shut and heavy, a little out from
# the trousers; the head cocked, listening to the ground
LOOSE = dict(pos=(-0.022, 0, -0.018), rot=(0, 0, 0), hips=(-2, -2.5, -4), head=(-3, 5, 7), jaw=0.05, lip=0.2,
             hr=hand(0.14, 0.06, -0.62), hl=lhand(0.12, 0.08, -0.62), er=(0.8, -0.6, -0.1), el=(-0.8, -0.6, -0.1),
             wr=(0, 0, 0), wl=(0, 0, 0), fing_r=0.55, fing_l=0.45, thumb_r=0.4, thumb_l=0.4,
             fr=(AX + 0.05, -0.03, AZ), fl=(-AX + 0.0, 0.05, AZ), fra=0.0, fla=0.0, frt=-14.0, flt=8.0, kr=(0.35, 1, 0), kl=(-0.15, 1, 0))
# item 52, the signature stance: sunk and springy, a stonemason's boxer: left fist forward and low, the right cocked by
# the ribs, chin tucked, head turned aside to listen
STANCE = m(LOOSE, pos=(0.02, -0.01, -0.13), rot=(0, 0, 14), hips=(-13, 3, -6), head=(9, -5, 16), jaw=0.1, lip=0.6,
           hr=hand(0.06, 0.2, -0.3), hl=lhand(-0.04, 0.44, -0.24), er=(0.9, -0.5, -0.5), el=(-0.7, -0.3, -0.7),
           wr=(0, 0, 0), wl=(0, 0, 0), fing_r=1.0, fing_l=1.0, thumb_r=1.0, thumb_l=1.0,
           fr=(AX + 0.1, -0.2, AZ), fl=(-AX - 0.06, 0.22, AZ), frt=-22.0, flt=6.0, fra=0.0, fla=0.0, kr=(0.5, 1, 0), kl=(-0.3, 1, 0))
FIGHT = dict(fing_r=1.0, fing_l=1.0, thumb_r=1.0, thumb_l=1.0)
GRIT = dict(lip=-0.8, jaw=0.12)
SHOUT = dict(lip=0.3, jaw=0.9)


def breathe(period, amp=1.0, sway=0.0):
    def f(t, p):
        s = math.sin(t / period * tau)
        c = math.cos(t / period * tau)
        add(p, "pos", (sway * 0.012 * c, 0, 0.006 * amp * s))
        add(p, "hips", (1.3 * amp * s, sway * 1.2 * c, sway * 1.5 * c))
        add(p, "head", (-0.8 * amp * s, 0, sway * 3.0 * math.sin(t / period * tau + 0.6)))
        add(p, "hr", (0, 0, 0.008 * amp * math.sin(t / period * tau - 0.8)))
        add(p, "hl", (0, 0, 0.008 * amp * math.sin(t / period * tau - 1.2)))
    return f


# ---------------------------------------------------------------------- idle, stance
C.bake("idle", 3.6, [(0, LOOSE), (3.6, {})], over=breathe(3.6, 1.0, 1.0), loop=True)


def bounce(t, p):
    s = math.sin(t / 0.8 * tau * 2)
    add(p, "pos", (0.012 * math.sin(t / 0.8 * tau), 0, 0.022 * s))
    add(p, "hips", (1.6 * s, 0, 2.0 * math.sin(t / 0.8 * tau)))
    add(p, "hr", (0, 0, 0.018 * math.sin(t / 0.8 * tau * 2 - 0.9)))
    add(p, "hl", (0, 0.015 * math.sin(t / 0.8 * tau), 0.018 * math.sin(t / 0.8 * tau * 2 - 1.3)))


C.bake("stance", 0.8, [(0, STANCE), (0.8, {})], over=bounce, loop=True)


# ---------------------------------------------------------------------- walk, run
def gait(T, stride, lift, duty, dx, dy, lean, bob, armsw, base_y=0.0, back=0.0, turn=0.0, width=1.0):
    """A foot cycle: each foot on the ground runs back through the stride, then swings forward over `lift`, and the arms
    and hips answer the legs."""
    def foot(u):
        if u < duty:
            k = u / duty
            s = 0.5 - k
            z = 0.0
            pitch = 14.0 * max(0.0, 1.0 - k * 5.0) - 34.0 * max(0.0, k - 0.62) / 0.38
        else:
            k = (u - duty) / (1.0 - duty)
            sm = k * k * (3 - 2 * k)
            s = -0.5 + sm
            z = lift * math.sin(math.pi * k) ** 1.2 + back * math.sin(math.pi * min(1.0, k * 1.6)) ** 2
            pitch = -46.0 * (1 - k) ** 1.5 + 22.0 * k ** 2
        return s, z, pitch

    def f(t, p):
        ph = t / T
        for lab, off, sx in (("r", 0.0, 1.0), ("l", 0.5, -1.0)):
            s, z, pitch = foot((ph + off) % 1.0)
            x = sx * (AX + 0.01) * width + s * stride * dx
            p["f" + lab] = (x, base_y + s * stride * dy, AZ - 0.02 + z)
            p["f" + lab + "a"] = pitch
            p["f" + lab + "t"] = sx * -7.0
            p["k" + lab] = (0.06 * sx, 1, 0)
        c2 = math.cos(ph * tau * 2)
        s1 = math.sin(ph * tau)
        c1 = math.cos(ph * tau)
        p["pos"] = (0.018 * c1 * (dy != 0), 0, -0.03 - bob * c2 * -1.0)
        p["hips"] = (lean + 1.6 * c2, 2.2 * c1, (9.0 * s1 + 0.0) * (1 if dy >= 0 else -1) + turn)
        p["head"] = (-lean * 0.75 + 2.0 * c2, 0, -7.0 * s1 + 6.0 - turn * 0.5)
        p["rot"] = (0, 0, turn * 0.4)
        # the arms pump against the legs, the heavy fists a beat late
        a1 = math.sin(ph * tau - 0.45)
        p["hr"] = hand(0.11, -0.05 + base_y + armsw * -a1 * 0.6, -0.5 + 0.1 * max(0.0, -a1) * (armsw / 0.4))
        p["hl"] = lhand(0.11, -0.03 + base_y + armsw * a1 * 0.42, -0.5 + 0.06 * max(0.0, a1) * (armsw / 0.4))
        p["er"] = (0.75, -0.65, -0.1)
        p["el"] = (-0.75, -0.65, -0.1)
    return f


DIRS = {"f": (0, 1), "b": (0, -1), "l": (-1, 0), "r": (1, 0)}
WALK_T, RUN_T = 0.96, 0.54
for nm, (dx, dy) in DIRS.items():
    C.bake("walk_" + nm, WALK_T, [(0, m(LOOSE, frt=0.0, flt=0.0, fing_r=0.5, fing_l=0.5)), (WALK_T, {})], loop=True,
           over=gait(WALK_T, 0.82 if dy else 0.5, 0.11, 0.6, dx, dy, -5.0 if dy >= 0 else 2.0, 0.02, 0.34, turn=-dx * 16.0))
    C.bake("run_" + nm, RUN_T, [(0, m(LOOSE, frt=0.0, flt=0.0, fing_r=0.9, fing_l=0.9, jaw=0.14, lip=0.5)), (RUN_T, {})], loop=True,
           over=gait(RUN_T, 1.5 if dy else 0.85, 0.15, 0.36, dx, dy, -19.0 if dy >= 0 else 5.0, 0.03, 0.56, back=0.3 if dy >= 0 else 0.12, turn=-dx * 24.0))

# ---------------------------------------------------------------------- the crouch (item 143)
# a boulder ready to roll: the huge fists hung forward by his knees, the back rounded, chin up; grinning, on the balls of his feet
CROUCH = m(LOOSE, pos=(0.0, -0.06, -0.5), hips=(-40, 6, -5), head=(30, -6, 6), hr=hand(0.14, 0.5, -0.7), hl=lhand(0.1, 0.42, -0.62),
           fr=(AX + 0.18, -0.28, AZ + 0.04), fl=(-AX - 0.16, 0.32, AZ + 0.02), frt=-14.0, flt=14.0, fra=-26.0, fla=-12.0, kr=(0.5, 1, 0), kl=(-0.5, 1, 0),
           er=(0.75, -0.65, -0.1), el=(-0.75, -0.65, -0.1), fing_r=1.0, fing_l=1.0, thumb_r=1.0, thumb_l=1.0, jaw=0.08, lip=0.6)
CROUCH_T = 0.68


def crouch_scan(t, p):
    """The breath and a slow look round; 3.6 s loop."""
    a, b = math.sin(t / 3.6 * tau), math.cos(t / 3.6 * tau)
    add(p, "pos", (0, 0, 0.006 * (1 - b)))
    add(p, "hips", (0.8 * (1 - b), 0, 0))
    add(p, "head", (0, 0, 16.0 * a))


def crouch_gait(dx, dy):
    g = gait(CROUCH_T, 0.74 if dy > 0 else 0.5, 0.09, 0.62, dx, dy, -40.0 if dy >= 0 else -28.0, 0.018, 0.0, turn=-dx * 12.0)

    def f(t, p):
        hr, hl = p["hr"], p["hl"]
        g(t, p)
        c1 = math.cos(t / CROUCH_T * tau)
        p["pos"] = (p["pos"][0], p["pos"][1] - 0.06, p["pos"][2] - 0.47)
        p["head"] = (30.0, 0, p["head"][2] * 0.4 - 4.0)
        p["hr"] = (hr[0], hr[1] + 0.03 * c1, hr[2])
        p["hl"] = (hl[0], hl[1] - 0.03 * c1, hl[2])
    return f


C.bake("crouch_idle", 3.6, [(0, CROUCH), (3.6, {})], loop=True, over=crouch_scan)
for nm, (dx, dy) in DIRS.items():
    C.bake("crouch_" + nm, CROUCH_T, [(0, m(CROUCH, frt=0.0, flt=0.0)), (CROUCH_T, {})], loop=True, over=crouch_gait(dx, dy))
CROUCH_DIP = m(CROUCH, pos=(0.0, -0.04, -0.56), hips=(-46, 6, -5), hr=hand(0.14, 0.42, -0.74), hl=lhand(0.1, 0.34, -0.66))
C.bake("crouch_in", 0.4, [(0, LOOSE), (0.2, CROUCH_DIP), (0.4, CROUCH)])
C.bake("crouch_out", 0.42, [(0, CROUCH), (0.08, CROUCH_DIP), (0.28, LOOSE), (0.42, LOOSE)])

# ---------------------------------------------------------------------- air
# a jump: tucked, one knee up, fists out for balance; the fall: legs reaching, arms up and loose, locs flying
JUMP = m(LOOSE, pos=(0, 0, 0.1), hips=(-10, 0, 4), head=(6, 0, 0), hr=hand(0.22, 0.2, -0.26), hl=lhand(0.26, -0.1, -0.4),
         fr=(AX, 0.25, AZ + 0.42), fl=(-AX, -0.2, AZ + 0.16), fra=20.0, fla=-35.0, frt=0.0, flt=0.0, lip=0.8, jaw=0.2, **FIGHT)
FALL = m(JUMP, pos=(0, 0, 0.14), hips=(4, 0, 0), head=(-8, 0, 0), hr=hand(0.34, 0.04, 0.02), hl=lhand(0.36, 0.0, 0.06),
         fr=(AX + 0.04, 0.1, AZ + 0.18), fl=(-AX - 0.04, -0.1, AZ + 0.28), fra=-16.0, fla=-22.0, fing_r=0.5, fing_l=0.5)


def hang(p1, p2):
    def f(t, p):
        s = math.sin(t / p1 * tau)
        add(p, "hips", (1.5 * s * p2, 0, 0))
        add(p, "hr", (0, 0, 0.02 * s * p2))
        add(p, "hl", (0, 0, 0.02 * math.sin(t / p1 * tau + 1) * p2))
    return f


C.bake("jump", 0.6, [(0, JUMP), (0.6, {})], over=hang(0.6, 1.0), loop=True)
C.bake("fall", 0.6, [(0, FALL), (0.6, {})], over=hang(0.6, 1.4), loop=True)
# the glider: both hands up on the bar, legs trailing long, chin up to feel the wind
GLIDE = m(LOOSE, pos=(0, 0, 0.02), hips=(-30, 0, 0), head=(26, 0, 0), hr=hand(-0.02, 0.1, 0.42), hl=lhand(-0.02, 0.1, 0.42), er=(0.9, -0.2, -0.2), el=(-0.9, -0.2, -0.2),
          fr=(AX, -0.5, AZ + 0.25), fl=(-AX, -0.58, AZ + 0.36), fra=-40.0, fla=-46.0, frt=0.0, flt=0.0, lip=1.0, jaw=0.3, fing_r=1.0, fing_l=1.0)
C.bake("glide", 1.2, [(0, GLIDE), (1.2, {})], over=hang(1.2, 1.2), loop=True)
# the sky-dive: spread flat, fists out wide
DIVE = m(GLIDE, hips=(-60, 0, 0), head=(46, 0, 0), hr=hand(0.5, 0.2, 0.1), hl=lhand(0.5, 0.2, 0.1), fr=(AX + 0.14, -0.7, AZ + 0.5), fl=(-AX - 0.14, -0.7, AZ + 0.5), fing_r=1.0, fing_l=1.0, jaw=0.5)
C.bake("dive", 0.8, [(0, DIVE), (0.8, {})], over=hang(0.8, 1.6), loop=True)

LOW = dict(pos=(0, 0, -0.42), hips=(-34, 0, 0), head=(26, 0, 0), fr=(AX + 0.22, -0.08, AZ), fl=(-AX - 0.24, 0.06, AZ), frt=-20.0, flt=20.0, fra=0.0, fla=0.0, kr=(0.7, 1, 0), kl=(-0.7, 1, 0))
C.bake("land", 0.42, [(0, m(LOOSE, FALL)), (0.05, m(LOOSE, LOW, hr=hand(0.3, 0.3, -0.42), hl=lhand(0.3, 0.3, -0.42), lip=-0.2, jaw=0.3, e="snap")),
                      (0.2, dict(pos=(0, 0, -0.3), hips=(-22, 0, 0))), (0.42, m(LOOSE))])

# ---------------------------------------------------------------------- hurt, down, up
# hurt: played on the torso over whatever the legs do, from the front and from behind
C.bake("hit_f", 0.4, [(0, LOOSE), (0.05, m(LOOSE, pos=(0, -0.05, -0.05), hips=(13, 4, 9), head=(-17, 0, 12), hr=hand(0.24, 0.12, -0.36), hl=lhand(0.22, 0.02, -0.5), lip=-1.0, jaw=0.5, fing_r=0.2, fing_l=0.2, e="snap")),
                      (0.18, dict(hips=(5, 2, 4), head=(-4, 0, 6), lip=-0.4, jaw=0.2)), (0.4, LOOSE)])
C.bake("hit_b", 0.4, [(0, LOOSE), (0.05, m(LOOSE, pos=(0, 0.05, -0.05), hips=(-16, -3, -7), head=(14, 0, -10), hr=hand(0.24, -0.1, -0.4), hl=lhand(0.22, -0.06, -0.44), lip=-1.0, jaw=0.5, fing_r=0.2, fing_l=0.2, e="snap")),
                      (0.18, dict(hips=(-6, -2, -3), head=(4, 0, -5), lip=-0.4, jaw=0.2)), (0.4, LOOSE)])
STUN = m(LOOSE, pos=(0, 0, -0.08), hips=(-14, 0, 0), head=(16, 0, 0), hr=hand(0.1, 0.1, -0.56), hl=lhand(0.1, 0.1, -0.56), fing_r=0.1, fing_l=0.1, lip=-0.3, jaw=0.4)


def stagger(t, p):
    a2 = t / 1.2 * tau
    add(p, "pos", (0.04 * math.sin(a2), 0.03 * math.cos(a2), 0))
    add(p, "hips", (2.0 * math.cos(a2), 5.0 * math.sin(a2), 0))
    add(p, "head", (5.0 * math.cos(a2 + 1), 12.0 * math.sin(a2 + 1), 0))


C.bake("stun", 1.2, [(0, STUN), (1.2, {})], over=stagger, loop=True)
# downed: on the knees with one fist on the ground, the other arm across the ribs, the head hanging
DOWNED = m(LOOSE, pos=(0, 0.02, -0.62), hips=(-26, 4, 6), head=(30, 6, 0), hr=hand(0.12, 0.42, -0.78), hl=lhand(0.0, 0.3, -0.36), er=(0.9, -0.3, 0), el=(-0.6, 0.2, -0.8),
           fr=(AX + 0.08, -0.34, AZ + 0.04), fl=(-AX - 0.08, 0.0, AZ), fra=-60.0, fla=-10.0, frt=0.0, flt=0.0, kr=(0.3, 1, 0), kl=(-0.3, 1, 0), lip=-0.7, jaw=0.32, fing_r=1.0, fing_l=0.6)
C.bake("downed", 1.8, [(0, DOWNED), (1.8, {})], over=breathe(1.8, 2.2), loop=True)
REV = m(DOWNED, pos=(0, 0.0, -0.46), hips=(-14, 0, 0), head=(2, 0, 0), hr=hand(0.1, 0.34, -0.3), hl=lhand(0.1, 0.34, -0.3), lip=0.1, jaw=0.1, fing_l=1.0)
# revive: kneeling over a friend, both stone fists pressing their chest in two heavy pushes (the Life.R revive is 4 s: a steady loop)
REV_P = m(REV, pos=(0, 0.02, -0.5), hips=(-22, 0, 0), head=(8, 0, 0), hr=hand(0.1, 0.34, -0.38), hl=lhand(0.1, 0.34, -0.38), jaw=0.2)
C.bake("revive", 1.2, [(0, REV), (0.2, m(REV_P, e="in")), (0.4, m(REV, e="out")), (0.6, REV), (0.8, m(REV_P, e="in")), (1.0, m(REV, e="out")), (1.2, REV)], over=breathe(1.2, 1.0), loop=True)
# stomp (one cycle = Life.R stomp_cycle 0.7 s, the stone boot lands at 0.7 of it): the weight rocks back onto the left leg, the right knee lifts
# high with the fists drawn up, hangs a beat, then the whole of him comes down through the boot
ST0 = m(STANCE, hr=hand(0.1, 0.12, -0.34), hl=lhand(0.06, 0.28, -0.34), jaw=0.15, lip=-0.6)
ST1 = m(ST0, pos=(-0.03, -0.02, -0.08), hips=(-6, 0, 4), head=(-2, -4, 12), fr=(AX + 0.04, 0.05, AZ + 0.18), fra=-20.0, frt=-10.0, kr=(0.4, 1, 0))
ST2 = m(ST1, pos=(-0.03, -0.02, -0.02), hips=(-2, 0, 6), head=(-10, -4, 12), hr=hand(0.14, 0.1, -0.26), hl=lhand(0.1, 0.2, -0.28), fr=(AX + 0.05, 0.16, AZ + 0.34), fra=-30.0, jaw=0.4, lip=-1.0)
ST3 = m(ST0, pos=(0.02, 0.03, -0.2), hips=(-24, 2, 2), head=(14, -4, 10), hr=hand(0.12, 0.26, -0.5), hl=lhand(0.08, 0.34, -0.5), fr=(AX + 0.08, 0.16, AZ), fra=0.0, frt=-18.0, jaw=0.7, lip=-1.0)
C.bake("stomp", 0.7, [(0, ST0), (0.16, m(ST1, e="out")), (0.38, m(ST2, e="out")), (0.49, m(ST3, e="in")), (0.58, m(ST3, pos=(0.02, 0.02, -0.15), hips=(-16, 1, 3)), ), (0.7, ST0)], loop=True)
# drink (Hunter.DRINK_TIME 1.1 s): the left fist brings the flask up under his chin, his head tips back, a long swallow, the flask lowers with a grunt of satisfaction
DR1 = m(LOOSE, hl=lhand(0.0, 0.2, -0.05), hips=(-2, -2.5, -4), head=(-3, 5, 7), fing_l=1.0, thumb_l=1.0)
DR2 = m(DR1, hl=lhand(-0.04, 0.16, 0.1), hips=(2, -2, -4), head=(-24, 4, 6), jaw=0.3, lip=0.4)
C.bake("drink", 1.1, [(0, LOOSE), (0.22, m(DR1, e="out")), (0.36, DR2), (0.8, m(DR2, head=(-28, 4, 6))), (0.9, m(DR1, head=(4, 5, 7), jaw=0.5, lip=0.8), ), (1.1, LOOSE)])
# death: buckles to the knees, falls on his side; ends lying still (a one-shot: DeathFX keeps the last frame)
SIDE = m(DOWNED, pos=(0.62, 0.0, 0.2), rot=(0, -84, 0), hips=(-6, 0, 0), head=(6, 10, 0), hr=hand(0.3, 0.3, -0.5), hl=lhand(0.3, -0.1, -0.5), fr=(0.66, -0.12, 0.3), fl=(0.56, 0.18, 0.13), fra=0.0, fla=0.0, fing_r=0.3, fing_l=0.3, jaw=0.2, lip=0.0)
C.bake("death", 1.6, [(0, LOOSE), (0.16, m(LOOSE, pos=(0, -0.05, -0.1), hips=(14, 0, 4), head=(-20, 0, 0), jaw=0.6, lip=-1.0, fing_r=0.1, fing_l=0.1, e="snap")),
                      (0.65, m(DOWNED, e="in")), (1.25, m(SIDE, e="in")), (1.42, m(SIDE, pos=(0.62, 0.0, 0.25))), (1.6, SIDE)])

# ---------------------------------------------------------------------- the kit (times: KMovesStone's beats)
# LMB tap, the boulder (0.55): twisted away, the right fist cocked out behind (0.07), hurled long (0.13), through (0.24)
COCK = m(STANCE, pos=(0.02, -0.06, -0.16), hips=(-6, 8, -38), head=(4, -6, 40), hr=hand(0.3, -0.34, -0.3), hl=lhand(0.1, 0.38, -0.3), lip=-0.3, jaw=0.1)
FLUNG = m(STANCE, pos=(-0.02, 0.1, -0.12), hips=(-20, -6, 34), head=(12, 0, -28), hr=hand(-0.06, 0.66, -0.08), hl=lhand(0.2, -0.22, -0.4), er=(0.7, -0.7, 0.1), lip=0.5, jaw=0.5, fing_r=0.05, thumb_r=0.1,
          fr=(AX + 0.12, -0.3, AZ), fl=(-AX - 0.1, 0.32, AZ), fra=-30.0)
THRU = m(FLUNG, hips=(-24, -4, 46), hr=hand(-0.3, 0.42, -0.34), hl=lhand(0.24, -0.26, -0.42), fing_r=0.5)
C.bake("lmb_throw", 0.55, [(0, STANCE), (0.07, m(COCK, e="out")), (0.13, m(FLUNG, e="lin")), (0.24, THRU), (0.55, STANCE)])
# LMB hold, the wind: sunk and twisted far, the right fist behind the hip, the left forearm up; it holds, trembling
WIND = m(STANCE, pos=(0.03, -0.1, -0.24), hips=(-12, 8, -44), head=(8, -8, 44), hr=hand(0.24, -0.5, -0.46), hl=lhand(-0.02, 0.36, 0.06), el=(-0.8, 0.0, -0.7), lip=-0.8, jaw=0.08,
         fr=(AX + 0.14, -0.34, AZ), fl=(-AX - 0.12, 0.3, AZ), fra=-18.0)


def tremble(t, p):
    if t > 0.24:
        s = math.sin(t * 46.0)
        add(p, "pos", (0.004 * s, 0, 0.003 * math.sin(t * 61.0)))
        add(p, "hips", (0.6 * s, 0, 0.8 * math.sin(t * 37.0)))
        add(p, "hr", (0.006 * s, 0, 0))


C.bake("lmb_wind", 0.64, [(0, STANCE), (0.1, m(WIND, e="out")), (0.24, m(WIND, pos=(0.03, -0.12, -0.27))), (0.44, m(WIND, pos=(0.03, -0.1, -0.26))), (0.64, m(WIND, pos=(0.03, -0.12, -0.27)))], over=tremble)
# LMB let go, the punch: the hips unwind into a straight drive, long on the hit (0.05), past the line (0.12), back (0.3)
PUNCH = m(STANCE, pos=(0, 0.3, -0.12), rot=(0, 0, 8), hips=(-26, -4, 30), head=(14, 0, -24), hr=hand(-0.06, 0.74, 0.02), hl=lhand(0.2, -0.3, -0.34), er=(0.8, -0.5, 0.1), lip=0.2, jaw=0.75,
          fr=(AX + 0.12, -0.5, AZ + 0.02), fl=(-AX - 0.1, 0.52, AZ), fra=-38.0, flt=0.0, frt=-10.0)
OVER = m(PUNCH, pos=(0, 0.38, -0.14), hips=(-32, -6, 42), hr=hand(-0.12, 0.78, -0.04), head=(18, 0, -34))
C.bake("lmb_punch", 0.6, [(0, WIND), (0.05, m(PUNCH, e="lin")), (0.12, OVER), (0.3, m(PUNCH, pos=(0, 0.2, -0.14), hips=(-20, -2, 12), hr=hand(0.02, 0.5, -0.1))), (0.6, STANCE)])
# RMB hold: a low gather, both fists drawn in at the hips
GATHER = m(STANCE, pos=(0, -0.04, -0.34), rot=(0, 0, 0), hips=(-24, 0, 0), head=(18, 0, 0), hr=hand(0.0, 0.2, -0.52), hl=lhand(0.0, 0.2, -0.52), er=(0.9, -0.5, 0), el=(-0.9, -0.5, 0),
           fr=(AX + 0.16, -0.06, AZ), fl=(-AX - 0.16, 0.06, AZ), frt=-16.0, flt=16.0, fra=0.0, fla=0.0, kr=(0.6, 1, 0), kl=(-0.6, 1, 0), lip=-0.7, jaw=0.06)
C.bake("rmb_gather", 0.46, [(0, STANCE), (0.08, m(GATHER, e="out")), (0.16, m(GATHER, pos=(0, -0.04, -0.38))), (0.31, m(GATHER, pos=(0, -0.04, -0.35))), (0.46, m(GATHER, pos=(0, -0.04, -0.38)))], over=tremble)
# jump while charging: tucked, fists rising overhead, leaning in
LEAP = m(JUMP, pos=(0, 0.04, 0.16), hips=(-20, 0, 0), head=(14, 0, 0), hr=hand(0.0, 0.2, 0.3), hl=lhand(0.0, 0.2, 0.3), fr=(AX, 0.2, AZ + 0.46), fl=(-AX, 0.12, AZ + 0.4), lip=0.6, jaw=0.4, **FIGHT)
C.bake("rmb_leap", 0.5, [(0, GATHER), (0.1, m(LEAP, pos=(0, 0.06, 0.1), e="out")), (0.3, LEAP), (0.5, m(LEAP, pos=(0, 0.04, 0.18)))])
# RMB let go, Quakefall (1.36, the hop a real 0.6 s arc, ext/kit-tarek-61-67): up off both legs (0.05), arched at the top,
# fists behind the head (0.3), over and down (0.5), the smash on landing (0.6, knees wide), a rebound in the crater (0.7),
# low over the fists (0.88), heaved up (1.12-1.36)
ARCH = m(LEAP, pos=(0, 0.0, 0.22), hips=(16, 0, 0), head=(-12, 0, 0), hr=hand(-0.06, -0.14, 0.58), hl=lhand(-0.06, -0.14, 0.58), er=(0.9, 0.2, 0.4), el=(-0.9, 0.2, 0.4), fr=(AX + 0.06, -0.14, AZ + 0.3), fl=(-AX - 0.06, -0.1, AZ + 0.34), jaw=0.5, lip=0.7)
SMASH = m(GATHER, pos=(0, 0.1, -0.56), hips=(-52, 0, 0), head=(36, 0, 0), hr=hand(-0.14, 0.72, -0.72), hl=lhand(-0.14, 0.72, -0.72), er=(0.8, -0.2, 0.4), el=(-0.8, -0.2, 0.4), fr=(AX + 0.26, -0.14, AZ), fl=(-AX - 0.26, -0.14, AZ), fra=-16.0, fla=-16.0, jaw=0.85, lip=-0.2)
REB = m(SMASH, pos=(0, 0.08, -0.5), hips=(-44, 0, 0), hr=hand(-0.12, 0.66, -0.6), hl=lhand(-0.12, 0.66, -0.6), jaw=0.3)
C.bake("rmb_slam", 1.36, [(0, GATHER), (0.05, m(LEAP, pos=(0, 0.02, 0.1), hr=hand(0.02, -0.2, -0.3), hl=lhand(0.02, -0.2, -0.3), fr=(AX, -0.06, AZ + 0.1), fl=(-AX, -0.06, AZ + 0.1), e="out")),
                          (0.3, ARCH), (0.5, m(ARCH, hips=(-14, 0, 0), hr=hand(-0.08, 0.44, 0.16), hl=lhand(-0.08, 0.44, 0.16), e="in")), (0.6, m(SMASH, e="out")), (0.7, REB),
                          (0.78, SMASH), (0.88, m(SMASH, pos=(0, 0.1, -0.53))), (1.12, m(GATHER, pos=(0, 0, -0.26))), (1.36, STANCE)])
DIVEFIST = m(ARCH, pos=(0, 0.0, 0.1), hips=(-34, 0, 0), head=(24, 0, 0), hr=hand(-0.04, 0.3, 0.42), hl=lhand(-0.04, 0.3, 0.42), fr=(AX, -0.1, AZ + 0.26), fl=(-AX, -0.1, AZ + 0.2))
C.bake("rmb_dive", 0.5, [(0, LEAP), (0.12, m(DIVEFIST, e="out")), (0.3, DIVEFIST), (0.5, m(DIVEFIST, hips=(-38, 0, 0)))])
C.bake("rmb_land", 0.75, [(0, SMASH), (0.1, m(REB, pos=(0, 0.1, -0.48))), (0.28, m(SMASH, pos=(0, 0.1, -0.5))), (0.75, STANCE)])
# a punch out of the charge: both fists thrown long off the back foot (0.05-0.16), back into the gather
LUNGE = m(PUNCH, pos=(0, 0.42, -0.2), rot=(0, 0, 0), hips=(-36, 0, 0), head=(26, 0, 0), hr=hand(-0.16, 0.74, -0.02), hl=lhand(-0.16, 0.74, -0.02), el=(-0.8, -0.5, 0.1), fr=(AX + 0.1, -0.56, AZ + 0.04), fl=(-AX - 0.08, 0.44, AZ), jaw=0.8)
C.bake("rmb_lunge", 0.36, [(0, GATHER), (0.05, m(LUNGE, e="lin")), (0.16, m(LUNGE, pos=(0, 0.46, -0.22))), (0.36, GATHER)])
# Shift, Rubble Leap (0.58): crouched on the rock (0.06), kicked off long, fists swept back (0.12), tucked at the top,
# fists overhead (0.3), legs reaching down (0.46), the fists-high drop the landing picks up (0.58)
C.bake("dash_leap", 0.58, [(0, STANCE), (0.06, m(GATHER, pos=(0, 0, -0.3), e="out")),
                           (0.12, m(GLIDE, pos=(0, 0.1, 0.14), hips=(-38, 0, 0), head=(26, 0, 0), hr=hand(0.1, -0.5, -0.32), hl=lhand(0.1, -0.5, -0.32), er=(0.7, 0.5, 0.3), el=(-0.7, 0.5, 0.3), fr=(AX, -0.5, AZ + 0.14), fl=(-AX, -0.3, AZ + 0.02), fra=-50.0, fla=-40.0, jaw=0.5, lip=0.9, **FIGHT)),
                           (0.3, m(LEAP, pos=(0, 0.02, 0.24), hips=(-12, 0, 0), hr=hand(-0.02, 0.14, 0.44), hl=lhand(-0.02, 0.14, 0.44), fr=(AX, 0.26, AZ + 0.5), fl=(-AX, 0.2, AZ + 0.56), jaw=0.4, lip=1.0)),
                           (0.46, m(ARCH, pos=(0, 0, 0.12), hips=(-4, 0, 0), hr=hand(-0.04, 0.1, 0.5), hl=lhand(-0.04, 0.1, 0.5), fr=(AX + 0.1, 0.16, AZ + 0.16), fl=(-AX - 0.1, 0.1, AZ + 0.12), fra=10.0, fla=10.0)),
                           (0.58, m(ARCH, pos=(0, 0.04, 0.04), hips=(-20, 0, 0), hr=hand(-0.08, 0.34, 0.26), hl=lhand(-0.08, 0.34, 0.26), fr=(AX + 0.14, 0.1, AZ + 0.04), fl=(-AX - 0.14, 0.06, AZ + 0.04), fra=0.0, fla=0.0))])
C.bake("dash_land", 0.75, [(0, m(SMASH, pos=(0, 0.04, -0.3))), (0.05, m(SMASH, pos=(0, 0.1, -0.56), e="snap")), (0.25, m(SMASH, pos=(0, 0.1, -0.53))), (0.5, m(GATHER, pos=(0, 0, -0.24))), (0.75, STANCE)])
# his air dash (0.23): a quick gather (0.03), a shoulder barge, lead fist low (0.08), held (0.18), knees up to land
BARGE = m(JUMP, pos=(0, 0.2, 0.04), rot=(0, 0, 26), hips=(-26, 12, 20), head=(14, 0, -30), hr=hand(-0.1, 0.46, -0.4), hl=lhand(-0.12, 0.2, -0.16), el=(-0.7, -0.3, -0.5), fr=(AX, -0.5, AZ + 0.08), fl=(-AX, -0.34, AZ + 0.2), fra=-50.0, fla=-40.0, lip=-0.5, jaw=0.4)
C.bake("dash_air", 0.23, [(0, JUMP), (0.03, m(JUMP, hr=hand(-0.14, 0.2, -0.2), hl=lhand(-0.14, 0.2, -0.2), hips=(-14, 0, -8), e="out")), (0.08, m(BARGE, e="snap")), (0.18, m(BARGE, pos=(0, 0.22, 0.04))),
                          (0.23, m(BARGE, fr=(AX, 0.1, AZ + 0.3), fl=(-AX, 0.0, AZ + 0.36), fra=-10.0, fla=-10.0, hips=(-12, 6, 10)))])
# E, Stone Row (0.95): reared back, fists high (0.06), slammed down on the tell (0.18), held, heaved up and out as the
# rocks rise (0.36), a proud settle
REAR = m(ARCH, pos=(0, -0.08, 0.02), hips=(14, 0, 0), head=(-12, 0, 0), fr=(AX + 0.14, -0.12, AZ), fl=(-AX - 0.14, 0.1, AZ), fra=0.0, fla=20.0, jaw=0.3, lip=0.6)
HEAVE = m(STANCE, pos=(0, 0.0, -0.06), rot=(0, 0, 0), hips=(8, 0, 0), head=(-12, 0, 0), hr=hand(0.3, 0.3, 0.38), hl=lhand(0.3, 0.3, 0.38), er=(0.9, -0.4, -0.4), el=(-0.9, -0.4, -0.4), lip=1.0, jaw=0.45, fr=(AX + 0.16, -0.02, AZ), fl=(-AX - 0.16, 0.02, AZ), frt=-20.0, flt=20.0)
C.bake("e_row", 0.95, [(0, STANCE), (0.06, m(REAR, e="out")), (0.18, m(SMASH, pos=(0, 0.06, -0.5), hr=hand(-0.12, 0.58, -0.7), hl=lhand(-0.12, 0.58, -0.7), e="snap")), (0.26, m(SMASH, pos=(0, 0.06, -0.47), hr=hand(-0.12, 0.58, -0.68), hl=lhand(-0.12, 0.58, -0.68))),
                       (0.38, m(HEAVE, e="out")), (0.6, m(HEAVE, pos=(0, 0, -0.04))), (0.95, STANCE)])
# X held, Basalt Spine: sunk wide, both fists out at the ground; he leans along the ridge being dragged
SPAIM = m(GATHER, pos=(0, 0, -0.44), hips=(-16, 0, 0), head=(10, 0, 0), hr=hand(0.5, 0.14, -0.62), hl=lhand(0.5, 0.14, -0.62), er=(0.5, -0.6, 0.6), el=(-0.5, -0.6, 0.6), fr=(AX + 0.3, -0.04, AZ), fl=(-AX - 0.3, 0.04, AZ), jaw=0.1, lip=-0.5)
C.bake("x_aim", 0.62, [(0, STANCE), (0.12, m(SPAIM, e="out")), (0.32, m(SPAIM, pos=(0, 0, -0.46))), (0.62, m(SPAIM, pos=(0, 0, -0.44)))], over=tremble)
# X let go (1.0): fists up (0.05), driven down (0.1, the cracks), held through the 0.2 s cracks and 0.4 s rise, heaved up
# as the ridge stands (0.7)
C.bake("x_spine", 1.0, [(0, SPAIM), (0.05, m(REAR, pos=(0, 0, -0.12), hr=hand(0.0, 0.2, 0.5), hl=lhand(0.0, 0.2, 0.5), e="out")), (0.1, m(SMASH, pos=(0, 0.04, -0.58), hr=hand(0.0, 0.56, -0.74), hl=lhand(0.0, 0.56, -0.74), e="snap")),
                        (0.55, m(SMASH, pos=(0, 0.04, -0.54), hr=hand(0.0, 0.56, -0.7), hl=lhand(0.0, 0.56, -0.7))), (0.7, m(HEAVE, e="out")), (1.0, STANCE)])
# Tremor Sense: a palm flat on the ground, the head cocked at what it feels, the other fist up
SENSE = m(GATHER, pos=(0, 0.02, -0.5), hips=(-34, 0, 10), head=(14, 16, -24), hr=hand(-0.04, 0.5, -0.66), hl=lhand(0.0, 0.3, -0.16), er=(0.8, -0.4, 0.2), el=(-0.7, -0.3, -0.6), fing_r=0.0, thumb_r=0.0, wr=(-50, 0, 0), lip=0.5, jaw=0.05)
C.bake("sense", 0.75, [(0, STANCE), (0.12, m(SENSE, e="out")), (0.45, SENSE), (0.75, STANCE)])

# Rock Hop (item 111, breah_hop, breah_skate): one hop off a rock that rises under the foot, low and fast (0.28), and the
# short skate on the rock as it rises, one foot forward, the stone arm out behind for balance (0.3)
SKATE = m(STANCE, pos=(0, 0, -0.2), rot=(0, 0, 58), hips=(-16, 0, -12), head=(10, 0, -46), hr=hand(0.26, -0.3, -0.14), hl=lhand(0.24, 0.26, -0.26), jaw=0.2, lip=1.0,
          fr=(AX + 0.18, -0.2, AZ), fl=(-AX - 0.14, 0.26, AZ), fra=-8.0, fla=10.0, frt=0.0, flt=0.0)
HOPUP = m(LEAP, pos=(0, 0.1, 0.1), hips=(-24, 0, 0), head=(16, 0, 0), hr=hand(0.14, -0.3, -0.3), hl=lhand(0.14, 0.2, -0.22), fr=(AX, -0.42, AZ + 0.18), fl=(-AX, 0.3, AZ + 0.34), fra=-46.0, fla=8.0, lip=1.0, jaw=0.3)
C.bake("dash_hop", 0.28, [(0, m(GATHER, pos=(0, 0, -0.24))), (0.06, m(HOPUP, e="out")), (0.16, m(HOPUP, pos=(0, 0.04, 0.16), fr=(AX, 0.05, AZ + 0.4), fl=(-AX, 0.2, AZ + 0.3), fra=0.0)),
                          (0.28, m(GATHER, pos=(0, 0.02, -0.22), hr=hand(0.14, 0.1, -0.34), hl=lhand(0.14, 0.2, -0.3)))])
C.bake("dash_skate", 0.3, [(0, m(GATHER, pos=(0, 0.02, -0.22))), (0.08, m(SKATE, e="out")), (0.22, m(SKATE, pos=(0, 0, -0.18))), (0.3, SKATE)])

# ---------------------------------------------------------------------- emote, Fusion
# the emote: he tosses a pebble from his palm, catches it behind his back without looking, and grins at you
EM1 = m(LOOSE, hl=lhand(-0.06, 0.34, -0.36), wl=(-70, 0, 0), fing_l=0.25, head=(-4, 0, 6))
EM2 = m(EM1, pos=(0, 0, 0.03), hips=(4, 0, 0), hl=lhand(-0.04, 0.4, -0.2), fing_l=0.0, head=(-22, 0, 4), lip=0.8)
EM3 = m(LOOSE, pos=(0.03, 0, -0.03), hips=(-5, 0, -16), head=(4, 8, 20), hl=lhand(-0.04, -0.28, -0.44), wl=(30, 0, 0), el=(-0.8, -0.2, 0.5), fing_l=0.8, lip=1.0, jaw=0.32)


def chuckle(t, p):
    if t > 1.05:
        s = math.sin(t * 15.0) * min(1.0, (t - 1.05) * 4) * min(1.0, (2.2 - t) * 4)
        add(p, "pos", (0, 0, 0.012 * abs(s)))
        add(p, "head", (2.0 * s, 0, 0))
        add(p, "jaw", 0.08 * s)


C.bake("emote_toss", 2.2, [(0, LOOSE), (0.3, EM1), (0.5, m(EM2, e="out")), (0.95, EM2), (1.05, m(EM3, e="snap")), (1.8, EM3), (2.2, LOOSE)], over=chuckle)
# Fusion: fists to the ground, the stone rises through him, he stands into it arms wide
C.bake("fuse", 0.8, [(0, LOOSE), (0.22, m(SPAIM, pos=(0, 0, -0.5))), (0.5, m(HEAVE, pos=(0, 0, 0.04), hr=hand(0.56, 0.1, 0.44), hl=lhand(0.56, 0.1, 0.44), jaw=0.7, lip=1.0, e="out")), (0.66, m(HEAVE, pos=(0, 0, 0.0))), (0.8, LOOSE)])

bpy.context.scene.render.fps = A.FPS
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
if OUT_GLB != "-":
    # (every clip on its own NLA track: the exporter's ACTIONS mode only finds the action in use)
    for act in list(bpy.data.actions):
        arm.animation_data.action = act
        arm.animation_data.action = None
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        st = tr.strips.new(act.name, 0, act)
        tr.mute = False
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=93, export_extras=False, export_force_sampling=False,
                              export_frame_range=False, export_optimize_animation_size=False, export_def_bones=False, export_bake_animation=False)
    print("exported", os.path.getsize(OUT_GLB))
print("clips", json.dumps(C.lengths))
