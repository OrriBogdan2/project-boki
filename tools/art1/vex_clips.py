"""ART-1 Vex's animation set. Times match the kit (scripts/match/kmoves_vv.gd). Personality: a hired gun with a street racer's swagger: loose hips, weight thrown to the
cannon side, chin up, she leans into the slide and enjoys it.
Her right arm IS the cannon, so it is not an IK hand: "BE" is the cannon's direction in MODEL space (D(az, el)) and "UA" the strut's, FK. The torso and the legs can
do what they like, the cannon stays on the aim (aims_in_dash: the runtime turns only the legs to the dash).
Run: blender -b --python tools/art1/vex_clips.py -- <vex.blend> <out.glb> [clip,clip]"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, at, eul, FPS, frame_of
import vex_cannon as VC, vex_arm as VA
import crouchkit

A_Z = 0.16
SP = 0.0
UP = (0, 0, 1)
HZ = VC.J("hips")[2]
ST = (0.125, 0.05)


def aim(a, e, roll=0.0):
    """The cannon's frame: along D(a, e), its top (rest forward) toward up, turned `roll` round the axis."""
    d = Vector(D(a, e))
    t = Vector(UP) - d * d.z
    t = Quaternion(d, roll) @ t.normalized()
    return (tuple(d), tuple(t))


READY = {
    "pel": (0.012, 0.0, -0.04), "prt": (0.0, 0.08, 0.05), "tor": (0.03, -0.1, -0.03), "hed": (-0.02, 0.1, 0.03),
    "G": (0.3, 0.1, 0.8), "Lw": 0.0, "LP": (-0.21, 0.07, 1.02), "LQ": (0.15, 0.0, 0.0),
    "BE": aim(-7, -68), "UA": (-14, -80), "LN": 0.0, "GS": 0.0, "CN": 0.0, "CF": 0.0,
    "FL": (-0.115, 0.075, A_Z), "FR": (0.15, -0.055, A_Z), "FLy": 0.12, "FRy": -0.34, "FLp": 0.0, "FRp": 0.0,
    "brow": 0.15, "lid": 0.12, "fing": 0.25,
}
ON_AIM = {"BE": aim(0, 2), "UA": (-22, -42)}
CARRY = {"BE": aim(-3, -22), "UA": (-18, -58)}
BRACE = {"pel": (0.0, -0.02, -0.14), "prt": (0.16, 0.14, 0.0), "tor": (0.12, -0.14, 0.0), "hed": (-0.2, 0.12, 0.0), "FL": (-0.15, 0.2, A_Z), "FR": (0.18, -0.16, A_Z), "FLy": 0.1, "FRy": -0.5}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


def idle(u):
    a, b = math.sin(u * 2 * math.pi), math.cos(u * 2 * math.pi)
    p = dict(READY)
    p["pel"] = (0.012 + 0.008 * b, 0.0, -0.04 - 0.006 * a)
    p["tor"] = (0.03 + 0.02 * a, -0.1, -0.03 + 0.008 * b)
    p["hed"] = (-0.02 - 0.016 * a, 0.1 + 0.04 * math.sin(u * 4 * math.pi), 0.03)
    p["BE"] = aim(-7 + 0.8 * b, -68 + 1.2 * a)
    p["LP"] = (-0.21, 0.07, 1.02 - 0.006 * a)
    p["lid"] = 1.0 if 0.40 < u < 0.43 or 0.8 < u < 0.83 else 0.12
    return p


def stance(u):
    """The signature: weight on the left leg, the cannon let hang, the coin thumbed up and caught, a smirk at it."""
    p = dict(READY)
    a = math.sin(u * 2 * math.pi)
    p["pel"] = (-0.02, 0.0, -0.05 - 0.005 * a)
    p["prt"] = (0.0, -0.1, -0.09)
    p["tor"] = (0.02, 0.16, 0.06 + 0.01 * a)
    p["FL"], p["FR"] = (-0.1, 0.03, A_Z), (0.2, 0.09, A_Z)
    p["FLy"], p["FRy"] = 0.1, -0.5
    p["LP"] = (-0.255, 0.21, 1.3)
    p["LQ"] = (-2.5, 0.2, 0.0)
    p["fing"] = 0.55
    # the flip: two per loop
    f = (u * 2) % 1.0
    air = 0.0
    if f < 0.46:
        k = f / 0.46
        air = 4 * k * (1 - k)
    p["CN"] = 0.26 * air
    p["CF"] = air * 15 if f < 0.46 else 0.0
    catch = 1.0 if 0.46 < f < 0.6 else 0.0
    p["LP"] = (-0.255, 0.21, 1.3 - 0.018 * catch + 0.012 * (1 - min(1.0, f / 0.05)))
    t = math.atan2(0.26 * air, 0.5)
    p["hed"] = (t * -1.0 - 0.02, 0.5, 0.06)
    p["lid"] = 0.2
    p["brow"] = -0.3
    p["BE"] = aim(-10, -72)
    return p


def gait(speed_k, heading, T):
    """speed_k 0.45 walk .. 1 run. A racer's lope: long, low, hips loose; the cannon arm rides steady on the aim, the left arm pumps."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    stride = 0.17 + 0.33 * speed_k
    lift = 0.05 + 0.2 * speed_k
    share = 0.6 - 0.22 * speed_k
    back, fwd = max(0.0, -d.y), max(0.0, d.y)

    def foot(ph, sx):
        ph = ph % 1.0
        base = Vector((sx * 0.1, 0, A_Z))
        if ph < share:
            s = 1 - 2 * ph / share
            z, pit = 0.0, 0.0
        else:
            k = (ph - share) / (1 - share)
            sm = k * k * (3 - 2 * k)
            s = -1 + 2 * sm
            z = lift * math.sin(k * math.pi) ** 0.8
            pit = -0.7 * math.sin(k * math.pi) * speed_k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        p["FRp"], p["FLp"] = pr, pl
        h = math.radians(heading) * 0.5
        p["FRy"], p["FLy"] = -0.1 + h, 0.06 + h
        s2 = math.sin(u * 4 * math.pi + 0.5)
        c1 = math.cos(u * 2 * math.pi)
        p["pel"] = (0.03 * c1, 0.03 * speed_k * fwd - 0.03 * back, -0.05 - 0.05 * speed_k + (0.016 + 0.024 * speed_k) * s2)
        lean = (0.1 + 0.24 * speed_k) * fwd - 0.1 * back
        p["prt"] = (lean * 0.55, 0.2 * c1 * speed_k, -0.05 * c1 + 0.13 * speed_k * d.x)
        p["tor"] = (lean * 0.7 + 0.015 * s2, -0.3 * c1 * speed_k, 0.06 * c1)
        p["hed"] = (-lean * 1.1, 0.25 * c1 * speed_k, -0.05 * c1)
        w = min(1.0, speed_k * 1.3)
        aa, ee = -3 + 3 * c1 * (1 - speed_k), -30 + 6 * speed_k + 2.2 * s2
        p["BE"] = aim(aa, ee)
        p["UA"] = (-18, -62 + 3 * s2)
        pump = c1 * w
        p["LP"] = (-0.22 + 0.03 * pump, 0.05 + 0.24 * pump, 1.02 + 0.13 * max(0, pump) + 0.03 * s2 + 0.06 * w)
        p["LQ"] = (0.2 - 1.2 * max(0, pump), 0, 0)
        p["fing"] = 0.7
        return p
    return FnClip("x", T, fn)


def named(c, n):
    c.name = n
    return c


# ---- the crouch (item 143): a cocky half-kneel. The back knee nearly down, the front knee up with the cannon resting across it, chin up, the left hand loose on her thigh; bored by you.
KNEEL = dict(READY, **{
    "pel": (0.02, -0.08, -0.46), "prt": (0.16, 0.22, 0.03), "tor": (0.22, -0.24, -0.03), "hed": (-0.40, 0.14, 0.08),
    "LP": (-0.26, 0.20, 0.72), "LQ": (0.3, 0.0, 0.0), "BE": aim(-6, -10), "UA": (-26, -58),
    "FR": (0.16, 0.32, A_Z), "FL": (-0.13, -0.34, A_Z + 0.07), "FRy": -0.2, "FLy": 0.3, "FRp": 0.05, "FLp": 0.75,
    "brow": 0.2, "lid": 0.15,
})
PROWL = {"ankle": A_Z, "foot": 0.11, "width": 0.13, "stride": 0.32, "lift": 0.05, "toe": 0.26, "share": 0.6, "sway": 0.04, "bob": 0.016, "twist": 0.12, "T": 0.62, "toe_out": -0.24}


def crouch_set():
    return crouchkit.quick(C, READY, KNEEL, PROWL, hands=("LP",), scan=0.26, dip_t=0.2)


def clips():
    out = [FnClip("idle", 3.2, idle), FnClip("stance", 3.0, stance)]
    out += crouch_set()
    for nm, h in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
        out.append(named(gait(0.45, h, 0.86), "walk_" + nm))
        out.append(named(gait(1.0, h, 0.58), "run_" + nm))
    # ---- air
    jump = dict(CARRY, pel=(0, 0, 0.02), prt=(-0.1, 0, 0), tor=(-0.1, 0, 0), hed=(-0.2, 0, 0), FL=(-0.12, 0.14, A_Z + 0.22), FR=(0.14, -0.1, A_Z + 0.08), FLp=-0.5, FRp=0.4, LP=(-0.28, 0.1, 1.22), fing=0.2)
    out.append(C("jump", 0.4, [(0.0, jump), (0.4, dict(jump, FL=(-0.12, 0.1, A_Z + 0.28), FR=(0.14, -0.14, A_Z + 0.16)))]))
    fall = dict(CARRY, pel=(0, 0, 0.0), prt=(0.08, 0, 0), tor=(0.06, 0, 0), hed=(0.1, 0, 0), FL=(-0.13, 0.08, A_Z + 0.08), FR=(0.14, -0.16, A_Z + 0.16), FLp=-0.3, FRp=-0.6, LP=(-0.34, 0.02, 1.26), fing=0.1)
    out.append(C("fall", 0.6, [(0.0, fall), (0.3, dict(fall, LP=(-0.36, 0.0, 1.3))), (0.6, fall)], loop=True))
    ld = dict(READY, pel=(0, -0.02, -0.26), prt=(0.28, 0, 0), tor=(0.22, 0, 0), hed=(-0.3, 0, 0), FL=(-0.15, 0.13, A_Z), FR=(0.17, -0.12, A_Z), LP=(-0.34, 0.18, 0.9), BE=aim(0, -30), UA=(-18, -60))
    out.append(C("land", 0.4, [(0.0, ld), (0.12, ld), (0.4, READY)]))
    gl = dict(pel=(0, 0, 0.0), prt=(0.22, 0, 0), tor=(0.0, 0, 0), hed=(-0.2, 0, 0), LP=(-0.1, -0.06, 1.72), LQ=(-3.0, 0, 0), UA=(-10, 40), BE=aim(-6, 72), FL=(-0.09, -0.12, A_Z + 0.04), FR=(0.11, -0.24, A_Z + 0.1), FLp=-0.7, FRp=-0.9)
    out.append(C("glide", 1.0, [(0.0, gl), (0.5, dict(gl, FR=(0.11, -0.26, A_Z + 0.13))), (1.0, gl)], loop=True))

    # ---- LMB: the gatling's rounds; keys from gunslinger_lmb: the kick at 0.025, back on the aim by 0.09, the next round at 0.12, she eases out by 0.55
    base = dict(BRACE, **ON_AIM)
    base.update(LP=(-0.26, 0.2, 0.98), LQ=(0.3, 0, 0), brow=0.5, lid=0.1)
    spin = math.radians(60)
    kick = dict(base, BE=aim(0, 4.5), UA=(-18, -44), tor=(0.08, -0.14, 0.0), GS=spin * 0.3)
    out.append(C("lmb", 0.55, [(0.0, base), (0.025, kick, "out"), (0.09, dict(base, GS=spin * 0.75)), (0.12, dict(base, GS=spin)), (0.3, dict(base, GS=spin * 3.2)), (0.55, dict(READY, GS=spin * 4), "smooth")]))

    # ---- RMB Coin Blast: tap: the coin hand is cocked by the shoulder at the press, flicks it out along the aim by 0.07 (fingers forward and open, palm in), follows through, home by 0.5;
    # the cannon hangs low out of the throw
    r0 = dict(CARRY, LP=(-0.3, 0.0, 1.22), LQ=(2.2, 0, 0), fing=0.85, tor=(0.0, 0.12, -0.03), hed=(-0.08, 0.12, 0.0), brow=0.6, lid=0.2, FL=(-0.14, 0.2, A_Z))
    r1 = dict(r0, LP=(-0.16, 0.48, 1.3), LQ=(-1.8, 0, 0), fing=0.0, tor=(0.1, -0.22, -0.03), hed=(-0.12, -0.08, 0.0), pel=(0.012, 0.04, -0.08))
    out.append(C("rmb", 0.5, [(0.0, r0), (0.07, r1, "out"), (0.2, dict(r1, LP=(-0.12, 0.5, 1.22), LQ=(-1.5, 0, 0), fing=0.05)), (0.5, READY)]))

    # ---- Slipstep: her slide. On the legs' own heading (runtime: legs_heading) she drops feet first, the lead leg out, the back knee folded under, the left hand trailing on the ground; the torso
    # stays up and the cannon stays on the aim
    sl = dict(ON_AIM, pel=(0.0, -0.12, -0.52), prt=(-0.42, 0.0, 0.0), tor=(0.3, 0.0, 0.0), hed=(0.2, 0.0, 0.0), FR=(0.1, 0.62, A_Z + 0.02), FL=(-0.16, 0.08, A_Z + 0.02), FRp=0.5, FLp=0.9, FRy=0.0, FLy=0.5,
              LP=(-0.36, -0.28, 0.2), LQ=(-0.3, 0, 0), brow=0.3, lid=0.1, fing=0.0)
    out.append(C("dash", 0.85, [(0.0, dict(READY, **ON_AIM, pel=(0, 0, 0.01))), (0.08, sl, "out"), (0.45, dict(sl, pel=(0.0, -0.12, -0.5))), (0.62, dict(READY, **ON_AIM, pel=(0, 0.04, -0.12), prt=(0.2, 0, 0), FR=(0.12, 0.3, A_Z), FL=(-0.14, -0.1, A_Z))), (0.85, READY)]))
    # the air tap's barrel roll, the cannon held on the aim through it
    t0 = dict(ON_AIM, prt=(0.0, 0.0, 0.0), FL=(-0.1, 0.0, A_Z + 0.35), FR=(0.12, 0.05, A_Z + 0.42), FLp=-0.8, FRp=-0.8, LP=(-0.18, 0.1, 1.2), pel=(0, 0, 0.1))
    out.append(C("dash_ex", 0.5, [(0.0, dict(READY, **ON_AIM)), (0.05, t0), (0.22, dict(t0, prt=(0.0, 0.0, 6.283))), (0.36, dict(READY, **ON_AIM, prt=(0, 0, 6.283), pel=(0, 0, -0.14))), (0.5, dict(READY, prt=(0, 0, 6.283)))]))

    # ---- E Palm Lance: the cyborg left arm up by 0.15, the open palm square to the aim (LQ solved on the hips frame: fingers up and a little forward, palm out), the cannon
    # hanging; 0.6 s of charge pressing the palm out; the beam at 0.6 kicks the palm up and back, she settles by 1.05. The hips keep READY's turn (pel y and prt turn the LQ frame) so the palm stays square
    PALM = (0.018, -1.402, 2.892)
    e0 = dict(READY, LP=(-0.12, 0.38, 1.38), LQ=PALM, fing=0.0, pel=(0.012, 0.0, -0.08), hed=(-0.12, 0.1, 0.03), brow=1.0, lid=0.4)
    e1 = dict(e0, LP=(-0.12, 0.43, 1.38), pel=(0.012, 0.02, -0.1))
    e2 = dict(e0, LP=(-0.13, 0.28, 1.46), pel=(0.012, 0.0, -0.06), hed=(0.05, 0.1, 0.03), brow=-0.2, lid=0.05)
    out.append(C("e", 1.05, [(0.0, READY), (0.15, e0), (0.58, e1), (0.65, e2, "out"), (0.8, dict(e2, LP=(-0.13, 0.34, 1.41), pel=(0.012, 0.0, -0.08))), (1.05, READY)]))

    # ---- Cinderfall: the cannon snapped straight up by 0.1, the shot squashes her, held a beat, back on her aim by 0.6
    x0 = dict(BRACE, BE=aim(0, 78), UA=(-6, 28), pel=(0, -0.03, -0.06), tor=(-0.14, -0.12, -0.08), hed=(-0.34, 0.1, 0), LP=(-0.3, 0.14, 1.2), brow=0.8, lid=0.1)
    x1 = dict(x0, pel=(0, -0.05, -0.17), BE=aim(0, 66), tor=(0.0, -0.12, -0.08))
    out.append(C("x", 0.6, [(0.0, READY), (0.1, x0, "out"), (0.14, x1, "out"), (0.3, x0), (0.6, READY)]))

    # ---- a knock: the cannon kicked up to rest on her shoulder, chin up, a grin
    k0 = dict(READY, BE=aim(6, 58), UA=(-6, -6), tor=(-0.08, 0.16, 0.05), hed=(-0.26, -0.14, 0.05), brow=-0.5, lid=0.2, LP=(-0.26, 0.05, 1.0))
    out.append(C("knock", 0.6, [(0.0, READY), (0.1, k0, "out"), (0.35, k0), (0.6, READY)]))

    # ---- hits
    hf = dict(READY, pel=(0, -0.06, -0.08), prt=(-0.18, 0, 0.05), tor=(-0.3, -0.1, 0.1), hed=(0.26, 0.2, 0.1), LP=(-0.3, 0.02, 1.16), brow=-1.0, lid=0.75, BE=aim(-10, -52))
    hb = dict(READY, pel=(0, 0.06, -0.08), prt=(0.22, 0, 0), tor=(0.3, 0, 0), hed=(-0.34, 0, 0), LP=(-0.3, 0.2, 1.16), brow=-1.0, lid=0.75, BE=aim(-10, -48))
    out.append(C("hit_f", 0.42, [(0.0, READY), (0.08, hf, "out"), (0.42, READY)]))
    out.append(C("hit_b", 0.42, [(0.0, READY), (0.08, hb, "out"), (0.42, READY)]))
    stn = dict(READY, pel=(0, 0, -0.2), prt=(0.12, 0, 0.1), tor=(0.42, 0, 0.1), hed=(0.34, 0.3, 0.2), BE=aim(-12, -78), LP=(-0.24, 0.1, 0.86), lid=0.85, brow=-0.9, fing=0.0)
    out.append(C("stun", 1.2, [(0.0, stn), (0.6, dict(stn, tor=(0.42, -0.1, -0.05), hed=(0.34, -0.3, -0.1))), (1.2, stn)], loop=True))
    # ---- down: on her left hip, propped on the robot arm, the cannon's weight dragging
    dn = {"pel": (0, -0.08, -0.72), "prt": (-0.32, 0.3, 0.42), "tor": (0.2, 0, 0.0), "hed": (0.24, 0, 0.1), "FL": (-0.28, 0.42, A_Z - 0.03), "FR": (0.1, 0.5, A_Z - 0.03), "FLy": 0.6, "FRy": 0.2, "FLp": 0.5, "FRp": 0.4,
          "BE": aim(-40, -6), "UA": (-40, -30), "LP": (-0.34, -0.1, 0.22), "LQ": (0, 0, 0), "lid": 0.65, "brow": -0.8, "fing": 0.0}
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, dict(dn, tor=(0.3, 0, 0), hed=(0.38, 0, 0.1))), (2.4, dn)], loop=True))
    out.append(C("revive", 1.6, [(0.0, dn), (0.5, dict(dn, tor=(0.32, 0, 0.1), hed=(-0.1, 0, 0), lid=0.3, brow=0.8)), (0.95, dict(READY, pel=(0, -0.02, -0.26), prt=(0.32, 0, 0), tor=(0.3, 0, 0), hed=(-0.3, 0, 0), FR=(0.16, -0.28, A_Z), LP=(-0.3, 0.1, 0.62), BE=aim(-16, -42))), (1.6, READY)]))
    dead = {"pel": (0, -0.1, -0.86), "prt": (-1.35, 0.1, 0.1), "tor": (0.1, 0.1, -0.1), "hed": (-0.1, 0.4, 0.3), "FL": (-0.2, 0.6, A_Z - 0.04), "FR": (0.16, 0.68, A_Z - 0.04), "FLy": 0.4, "FRy": -0.4, "FLp": 0.6, "FRp": 0.6,
            "BE": aim(-58, 4), "UA": (-80, -2), "LP": (-0.42, -0.2, 0.2), "LQ": (0, 0, 0), "lid": 1.0, "brow": -0.3, "fing": 0.0}
    out.append(C("death", 1.5, [(0.0, READY), (0.16, dict(READY, pel=(0, -0.08, -0.08), tor=(-0.3, 0, 0.1), hed=(-0.4, 0, 0), lid=0.2, brow=-1, BE=aim(-20, -30)), "out"),
                                (0.62, dict(READY, pel=(0, -0.1, -0.46), prt=(-0.4, 0, 0.1), tor=(0.1, 0, 0.1), FL=(-0.2, 0.3, A_Z), FR=(0.2, 0.34, A_Z + 0.04), BE=aim(-30, -24), LP=(-0.36, 0.0, 0.5), lid=0.7)),
                                (1.05, dead), (1.2, dict(dead, pel=(0, -0.1, -0.83))), (1.5, dead)]))
    # ---- Fusion
    fu0 = dict(READY, pel=(0, -0.03, -0.26), prt=(0.42, 0, 0), tor=(0.5, 0, 0), hed=(0.45, 0, 0), LP=(-0.2, 0.2, 0.96), BE=aim(0, -40), fing=1.0, lid=0.9, brow=1.0)
    fu1 = dict(READY, pel=(0, 0, 0.0), prt=(-0.14, 0, 0), tor=(-0.28, 0, 0), hed=(-0.4, 0, 0), BE=aim(0, 62), UA=(-8, 20), LP=(-0.5, 0.06, 1.46), LQ=(-2.6, 0, 0), lid=0.0, fing=0.0)
    out.append(C("fusion", 0.8, [(0.0, READY), (0.18, fu0), (0.3, dict(fu0, pel=(0.006, -0.03, -0.28))), (0.45, fu1, "out"), (0.58, dict(fu1, pel=(0, 0, -0.01))), (0.8, READY)]))

    # ---- the emote: flips the coin high, catches it on the back of the robot hand, a slow wink at you, the cannon propped on her shoulder
    em = dict(READY, BE=aim(8, 62), UA=(-4, -8), pel=(-0.02, 0, -0.05), prt=(0, -0.1, -0.08), tor=(0.0, 0.16, 0.05), hed=(-0.08, 0.0, 0.08), LP=(-0.2, 0.3, 1.28), LQ=(-2.5, 0.2, 0), fing=0.55, brow=-0.3, lid=0.15, FL=(-0.1, 0.04, A_Z), FR=(0.19, 0.08, A_Z), FRy=-0.5)
    keys = [(0.0, READY), (0.4, em)]
    for t, h in ((0.55, 0.14), (0.72, 0.28), (0.88, 0.32), (1.05, 0.26), (1.2, 0.1), (1.3, 0.0)):
        keys.append((t, dict(em, CN=h, CF=t * 26, hed=(-0.08 - h * 0.7, 0.0, 0.08))))
    keys += [(1.5, dict(em, LP=(-0.2, 0.3, 1.24), hed=(-0.08, -0.1, 0.1))), (1.8, dict(em, lid=1.0, hed=(-0.08, -0.14, 0.14), brow=-0.6)), (2.1, dict(em, lid=1.0, hed=(-0.08, -0.14, 0.14), brow=-0.6)), (2.3, dict(em, lid=0.15)), (3.0, READY)]
    out.append(C("emote", 3.0, keys))
    return out


class VexSolver(Solver):
    def solve(self, P):
        P = dict(P)
        Q, root_at = Solver.solve(self, P)
        q_hips = Q["hips"]
        ua = Vector(D(P["UA"][0], P["UA"][1]))
        yr = q_hips @ self.Y0["upper_arm.R"]
        Q["upper_arm.R"] = yr.rotation_difference(ua) @ q_hips
        fr = P["BE"] if isinstance(P["BE"], Quaternion) else frame_of(P["BE"][0], P["BE"][1])
        q_c = fr @ self.cannon_rest.inverted()
        Q["forearm.R"] = q_c
        Q["hand.R"] = q_c
        Q["hand.L"] = q_hips @ eul(P["LQ"])
        return Q, root_at


def extras_for(arm):
    def ax(bone, world):
        b = arm.data.bones[bone]
        return (b.matrix_local.to_3x3().inverted() @ Vector(world)).normalized()
    lax = ax("launcher", (1, 0, 0))
    gax = ax("gatling", (0, 0, 1))
    cup = ax("coin", (0, 0, 1))
    cfl = ax("coin", (1, 0, 0))
    brow_ax, brow_up = {}, {}
    for side in "LR":
        brow_ax[side] = ax("brow." + side, (0, 1, 0))
        brow_up[side] = ax("brow." + side, (0, 0, 1))
    lid_ax = ax("lid.L", (1, 0, 0))
    fing_ax = ax("fingers.L", (0, 1, 0))
    thumb_ax = ax("thumb.L", (0, 1, 0))

    def extras(P):
        if not P:
            return {}
        b, l = P.get("brow", 0.0), P.get("lid", 0.12)
        out = {}
        for s, side in ((1.0, "R"), (-1.0, "L")):
            out["brow." + side] = (Quaternion(brow_ax[side], -s * 0.22 * b), brow_up[side] * (-0.0065 * b))
        out["lid.L"] = (Quaternion(lid_ax, -1.05 * max(0.0, l - 0.12) / 0.88), None)
        f = P.get("fing", 0.2)
        out["fingers.L"] = (Quaternion(fing_ax, 1.0 * f), None)
        out["thumb.L"] = (Quaternion(thumb_ax, 0.5 * f), None)
        out["launcher"] = (Quaternion(lax, -math.radians(178) * P.get("LN", 0.0)), None)
        out["gatling"] = (Quaternion(gax, P.get("GS", 0.0)), None)
        out["coin"] = (Quaternion(cfl, P.get("CF", 0.0)), cup * (-P.get("CN", 0.0)))
        return out
    return extras


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig = {"grip_rest": tuple(VC.J("hand.R")), "blade_rest": (0, 0, -1), "edge_rest": (0, 1, 0), "pelvis": VC.J("hips")[2], "hilt_l": 0.08,
           "lhand": {"k": (0, 1, 0), "o": (-1, 0, 0), "palm": tuple(VA.WR + np.array([0, 0, -0.05]))}}
    bpy.context.scene.render.fps = FPS
    sol = VexSolver(arm, rig)
    sol.cannon_rest = frame_of((0, 0, -1), (0, 1, 0))
    ex = extras_for(arm)
    bpy.context.view_layer.objects.active = arm
    names = []
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        bake(arm, c, sol, ex)
        names.append((c.name, round(c.dur, 3)))
    print("clips", len(names), names)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE", export_tangents=True,
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))
