"""ART-1 Cinder's animation set (hand-keyed as targets, solved by posekit). Times match the kit: the kmove tables in
scripts/match/kmoves_pair.gd and content/archetypes/ashwick.json (lmb spool 0.2, flight 1.8 s). Personality: she is having the best
day of her life. Hips first, up on her toes, loose and quick; every blast is a treat; she laughs with her whole body.
Her hands are empty: fire comes from the right palm (LMB, RMB), so G is that palm's centre and LP the left wrist; "cast"/"castl" turn a hand
from hanging along the arm to palm out, fingers up.
Run: blender -b --python tools/art1/cinder_clips.py -- <cinder.blend> <out.glb> [clip,clip]"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from posekit import Clip, FnClip, Solver, bake, ang_dir as D, at, eul, FPS, frame_of
import cinder_pieces as K
import actionkit
import crouchkit

A_Z = K.ANKLE_Z


READY = {
    "pel": (0.022, 0.0, -0.034), "prt": (0.04, -0.14, 0.09), "tor": (0.05, 0.2, -0.1), "hed": (-0.04, -0.12, 0.12),
    "G": (0.3, 0.07, 0.82), "LP": (-0.285, 0.04, 0.87), "cast": 0.3, "castl": 0.2,
    "FL": (-0.085, 0.05, A_Z), "FR": (0.135, -0.05, A_Z), "FLy": 0.32, "FRy": -0.34, "FLp": 0.0, "FRp": 0.0,
    "brow": -0.25, "lid": 0.08, "fing": 0.25, "fistl": 0.0, "skirt": 0.0, "jaw": 0.05, "jet": 0.0,
}
OFFERED = {"G": (0.29, 0.16, 1.12), "cast": 1.0}          # the right hand up beside her, palm out: a flame she's showing off


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


END = {k: READY[k] for k in READY}


def idle(u):
    a = math.sin(u * 2 * math.pi)
    b = math.sin(u * 4 * math.pi)
    p = dict(READY)
    p["pel"] = (0.022 + 0.01 * a, 0.0, -0.034 - 0.008 * b)
    p["prt"] = (0.04, -0.14, 0.09 + 0.022 * a)
    p["tor"] = (0.05 + 0.02 * b, 0.2, -0.1 - 0.018 * a)
    p["hed"] = (-0.04 - 0.02 * b, -0.12 + 0.05 * math.sin(u * 2 * math.pi + 1), 0.12 + 0.04 * a)
    g = READY["G"]
    p["G"] = (g[0], g[1], g[2] - 0.006 * b)
    p["LP"] = (-0.285 + 0.004 * a, 0.04, 0.87 - 0.006 * b)
    p["lid"] = 1.0 if 0.30 < u < 0.33 or 0.72 < u < 0.745 else 0.08
    return p


def stance(u):
    """The sheet's pose: one hand raised, palm out, the other on her hip, the hip thrown out, chin up, delighted with herself."""
    a = math.sin(u * 2 * math.pi)
    b = math.sin(u * 4 * math.pi)
    p = dict(READY)
    p.update(OFFERED)
    p["pel"] = (0.04 + 0.008 * a, 0.0, -0.03)
    p["prt"] = (0.0, -0.2, 0.15)
    p["tor"] = (0.0 - 0.015 * b, 0.32, -0.17)
    p["hed"] = (-0.1, -0.2, 0.2 + 0.03 * a)
    p["FL"], p["FR"] = (-0.075, 0.09, A_Z), (0.155, -0.07, A_Z)
    p["FLy"], p["FRy"] = 0.42, -0.5
    p["G"] = (0.27, 0.2 + 0.004 * a, 1.2 - 0.006 * b)
    p["LP"] = (-0.225, 0.0, 0.93 - 0.004 * b)
    p["fing"] = 0.25
    p["brow"], p["lid"], p["jaw"] = -0.5, 0.14, 0.12
    p["lid"] = 1.0 if 0.52 < u < 0.545 else 0.14
    return p


def gait(speed_k, heading, stride, share, lift):
    """speed_k 0 walk .. 1 run. heading (deg, + left of facing). The walk leads with the hips; the run leans in, up on her toes, her arms pumping."""
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    back = max(0.0, -d.y)
    fwd = max(0.0, d.y)

    def foot(ph, sx):
        ph = ph % 1.0
        base = Vector((sx * 0.085, 0, A_Z))
        if ph < share:
            s = 1 - 2 * ph / share
            z, pit = 0.0, 0.25 * max(0.0, (ph / share - 0.65) / 0.35) * speed_k
        else:
            k = (ph - share) / (1 - share)
            sm = k * k * (3 - 2 * k)
            s = -1 + 2 * sm
            z = lift * math.sin(k * math.pi) ** 0.8
            pit = -0.8 * math.sin(k * math.pi) * (0.5 + 0.5 * speed_k)
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        p["FRp"], p["FLp"] = pr, pl
        hy = math.radians(heading) * 0.5
        p["FRy"], p["FLy"] = -0.08 + hy, 0.08 + hy
        s2 = math.sin(u * 4 * math.pi + 0.5)
        c1 = math.cos(u * 2 * math.pi)
        drop = -0.03 - 0.05 * speed_k + (0.014 + 0.026 * speed_k) * s2
        sway = (0.042 - 0.018 * speed_k) * c1
        p["pel"] = (sway, 0.03 * speed_k * fwd - 0.03 * back, drop)
        lean = (0.05 + 0.3 * speed_k) * fwd - 0.1 * back
        p["prt"] = (lean * 0.5, 0.2 * c1 * (0.8 - 0.3 * speed_k), (0.1 - 0.05 * speed_k) * -c1 + 0.14 * speed_k * d.x)
        p["tor"] = (lean * 0.75 + 0.02 * s2, -0.3 * c1 * (0.7 - 0.2 * speed_k), 0.08 * c1)
        p["hed"] = (-lean * 1.1 - 0.02, 0.14 * c1 + 0.04, -0.05 * c1)
        w = speed_k
        for key, sx, ph, k0 in (("G", 1.0, -c1, READY["G"]), ("LP", -1.0, c1, READY["LP"])):
            pump = (sx * 0.27, 0.14 - 0.26 * ph, 0.84 + 0.14 * max(0, ph))
            off = (k0[0], k0[1] + 0.05 * ph, k0[2])
            p[key] = tuple(off[i] + (pump[i] - off[i]) * min(1.0, 0.25 + w) for i in range(3))
        p["cast"], p["castl"] = READY["cast"] * (1 - w), READY["castl"] * (1 - w)
        p["fing"] = 0.5 * w + 0.3 * (1 - w)
        p["skirt"] = 0.2 * c1 * (0.5 + 0.5 * w)
        p["brow"], p["lid"], p["jaw"] = -0.3, 0.1, 0.05 + 0.2 * w
        return p
    return fn


# ---- the crouch (item 143): a giggling coil. Up on her toes, both hands low and open before her, hunting something to set on fire.
PILOT = dict(READY, **{
    "pel": (0.03, -0.04, -0.31), "prt": (0.40, -0.14, 0.05), "tor": (0.34, 0.18, -0.05), "hed": (-0.66, -0.10, 0.12),
    "G": (0.21, 0.36, 0.78), "LP": (-0.2, 0.3, 0.8), "cast": 0.55, "castl": 0.55,
    "FL": (-0.12, 0.24, A_Z + 0.03), "FR": (0.17, -0.22, A_Z + 0.06), "FLy": 0.3, "FRy": -0.5, "FLp": 0.25, "FRp": 0.55,
    "brow": -0.3, "lid": 0.0, "jaw": 0.22, "fing": 0.15,
})
CREEP = {"ankle": A_Z, "foot": 0.10, "width": 0.13, "stride": 0.31, "lift": 0.05, "toe": 0.28, "share": 0.6, "sway": 0.035, "bob": 0.016, "twist": 0.11, "T": 0.58, "toe_out": -0.22}


def crouch_set():
    return crouchkit.quick(C, END, PILOT, CREEP, hands=("G", "LP"), scan=0.36)


ACT = {"stomp": {"set": {"G": (0.4, 0.0, 0.96), "LP": (-0.4, 0.0, 0.96)}, "top": {"G": (0.5, 0.05, 1.0), "LP": (-0.5, 0.05, 1.0)}},
       "drink": {"hand": "LP"},
       "revive": {"kneel": {"G": (0.14, 0.46, 0.34), "LP": (-0.14, 0.46, 0.34), "fing": 0.1, "jaw": 0.3}}}


def action_set():
    return actionkit.clips(C, READY, A_Z, ("G", "LP"), (-0.04, 0.15, 1.42), ACT)


def clips():
    out = [FnClip("idle", 3.6, idle), FnClip("stance", 4.0, stance)]
    out += crouch_set()
    out += action_set()
    for nm, sp, sk, stride, share, lift in (("walk", 2.2, 0.0, 0.42, 0.58, 0.075), ("run", 4.6, 1.0, 0.6, 0.37, 0.2)):
        T = 2 * stride / (share * sp)
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            out.append(FnClip("%s_%s" % (nm, tag), T, gait(sk, hd, stride * (0.8 if tag in "lr" else 1.0), share, lift)))
    # LMB: the pilot's 0.2 s: the arm snaps out, palm first, feet set; then the roar throws her back a step and she leans in, teeth bared, the arm shaking
    braced = {"pel": (0.0, 0.03, -0.075), "prt": (0.04, -0.14, 0.0), "tor": (0.2, -0.3, 0.0), "hed": (-0.18, 0.42, 0.0), "brow": 0.55, "lid": 0.12, "jaw": 0.55, "fing": 0.05,
              "G": (0.16, 0.44, 1.2), "LP": (-0.28, -0.06, 0.98), "cast": 1.0, "castl": 0.5, "FL": (-0.11, 0.17, A_Z), "FR": (0.15, -0.17, A_Z), "FLy": 0.1, "FRy": -0.55}
    kick = dict(braced, G=(0.17, 0.36, 1.22), tor=(0.06, -0.26, 0.0), pel=(0.0, -0.035, -0.06), jaw=0.8)
    set_ = dict(braced, G=(0.2, 0.26, 1.08), jaw=0.2)
    buck = dict(braced, G=(0.16, 0.42, 1.21), tor=(0.17, -0.3, 0.0))
    out.append(C("lance", 0.465, [(0.0, END), (0.1, set_), (0.2, kick, "out"), (0.34, braced), (0.4025, buck, "lin"), (0.465, braced, "lin")]))
    fist = dict(braced, LP=(-0.14, 0.08, 1.68), fistl=1.0, tor=(0.0, -0.16, -0.08), hed=(-0.36, 0.3, 0.0), jaw=1.0, brow=-0.6, lid=0.3, G=(0.16, 0.5, 1.26))
    out.append(C("lance_stoke", 0.625, [(0.0, braced), (0.1, fist, "out"), (0.22, dict(fist, tor=(-0.08, 0.0, -0.05))), (0.5, braced), (0.5625, buck, "lin"), (0.625, braced, "lin")]))
    out.append(C("lance_end", 0.3, [(0.0, braced), (0.08, dict(braced, G=(0.2, 0.28, 1.04), jaw=0.3, tor=(0.1, -0.14, 0), cast=0.6), "out"), (0.3, END)]))
    # RMB: the palm up to eye level, sighting along her arm, one eye shut; the shot kicks it high; a little shimmy of delight
    aim = dict(braced, G=(0.12, 0.44, 1.28), hed=(0.04, 0.36, 0.2), tor=(0.1, -0.34, 0), brow=0.7, lid=0.18, jaw=0.08)
    out.append(C("aim", 0.3, [(0.0, END), (0.12, aim), (0.3, dict(aim, G=(0.12, 0.445, 1.282)))]))
    sh0 = dict(aim, G=(0.12, 0.34, 1.38), tor=(-0.1, -0.3, 0), hed=(-0.1, 0.3, 0.1), jaw=0.9, lid=0.08, brow=-0.4)
    out.append(C("shot", 0.48, [(0.0, aim), (0.06, sh0, "out"), (0.14, dict(sh0, G=(0.12, 0.38, 1.34)), "out"), (0.3, dict(aim, jaw=0.5, tor=(0.1, -0.2, 0.05))), (0.48, END)]))
    # Shift, Soot Ram: head first, horns of her own making: crouched, then flat out behind her own forehead, arms flung back, teeth first; the hit stops her dead and she bounces
    cr = {"pel": (0, -0.06, -0.2), "prt": (0.35, 0, 0), "tor": (0.35, 0, 0), "hed": (-0.3, 0, 0), "G": (0.25, -0.1, 0.76), "LP": (-0.24, -0.12, 0.74), "brow": 0.8, "lid": 0.1, "jaw": 0.2, "fing": 1.0,
          "FL": (-0.11, 0.14, A_Z), "FR": (0.12, -0.18, A_Z), "FRp": 0.5}
    ram = {"pel": (0, 0.2, -0.26), "prt": (0.95, 0, 0), "tor": (0.32, 0, 0), "hed": (-0.75, 0, 0), "G": (0.3, -0.42, 0.74), "LP": (-0.3, -0.42, 0.76), "jaw": 0.7, "brow": 0.9,
           "FL": (-0.1, 0.12, A_Z + 0.24), "FR": (0.12, -0.6, A_Z + 0.2), "FLp": 0.3, "FRp": 1.1, "FRy": -0.1, "skirt": -0.5}
    hit = dict(ram, pel=(0, 0.04, -0.2), prt=(0.34, 0, 0), tor=(-0.06, 0, 0), hed=(-0.36, 0.1, 0.1), G=(0.28, -0.05, 0.92), LP=(-0.3, 0.02, 1.0), jaw=1.0, FL=(-0.14, 0.2, A_Z), FR=(0.14, -0.2, A_Z + 0.02), FRp=0.2, skirt=0.3)
    out.append(C("leap", 0.55, [(0.0, END), (0.06, cr, "out"), (0.3, ram, "lin"), (0.36, hit, "out"), (0.42, dict(hit, pel=(0, 0.0, -0.13))), (0.55, END)]))
    # Shift in the air: a ball, one forward roll on the poof, then spread out on the launch, whooping
    ball = {"pel": (0, 0, 0.02), "prt": (-0.5, 0, 0), "tor": (0.5, 0, 0), "hed": (0.3, 0, 0), "G": (0.2, 0.14, 0.92), "LP": (-0.2, 0.16, 0.86), "FL": (-0.1, 0.16, 0.42), "FR": (0.12, 0.14, 0.44), "FLp": 1.0, "FRp": 1.0, "jaw": 0.5, }
    roll = dict(ball, prt=(-3.0, 0, 0))
    spread = {"pel": (0, 0, 0.0), "prt": (-6.283 + 0.35, 0, 0), "tor": (-0.1, 0, 0), "hed": (-0.1, 0, 0), "G": (0.36, 0.02, 1.03), "LP": (-0.42, 0.02, 1.08), "FL": (-0.24, -0.1, 0.32), "FR": (0.24, -0.16, 0.36), "FLp": 0.7, "FRp": 0.7, "jaw": 0.9, "lid": 0.05, "brow": -0.7}
    out.append(C("hop", 0.7, [(0.0, {"pel": (0, 0, -0.08), "FL": (-0.1, 0.1, 0.25), "FR": (0.12, 0.1, 0.26)}), (0.05, ball, "out"), (0.17, roll), (0.25, spread), (0.5, dict(spread, prt=(-6.283 + 0.45, 0, 0))), (0.7, dict(END, prt=(-6.283 + 0.04, -0.14, 0.09)))]))
    # E, Furnace Cloak (0.24): tuck for a blink, then everything flung wide, chest out, up on her toes, a shriek of joy
    tuck = {"pel": (0, 0, -0.1), "prt": (0.3, 0, 0), "tor": (0.3, 0, 0), "hed": (0.05, 0, 0), "G": (0.16, 0.16, 0.96), "LP": (-0.14, 0.14, 0.95), "fing": 1.0, "lid": 0.5, "jaw": 0.05}
    wide = {"pel": (0, 0, 0.03), "prt": (-0.12, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.4, 0, 0), "G": (0.42, 0.06, 1.12), "LP": (-0.44, 0.06, 1.14), "cast": 1.0, "castl": 1.0, "fing": 0.0, "jaw": 1.0, "lid": 0.05, "brow": -0.8,
            "FLp": 0.5, "FRp": 0.5, "FL": (-0.15, 0.05, A_Z + 0.045), "FR": (0.17, -0.05, A_Z + 0.045), "skirt": 0.3}
    out.append(C("cloak", 0.24, [(0.0, tuck), (0.06, wide), (0.13, dict(wide, pel=(0, 0, 0.0), LP=(-0.42, 0.03, 1.11))), (0.24, END)]))
    # a Flashover or a knock: the left fist punches up, a bounce on her heels, cackling
    pu = {"pel": (0, 0, -0.01), "tor": (-0.26, 0.15, 0.1), "hed": (-0.4, -0.2, 0.1), "G": (0.3, 0.1, 1.2), "LP": (-0.14, 0.08, 1.76), "cast": 1.0, "fistl": 1.0, "jaw": 1.0, "lid": 0.32, "brow": -0.7}
    out.append(C("stoke", 0.5, [(0.0, END), (0.1, pu, "out"), (0.22, dict(pu, pel=(0, 0, -0.09), LP=(-0.14, 0.08, 1.68))), (0.5, END)]))
    # X, Flue Flight: down into a crouch as the ring bursts, then up on the two heel jets: leaning into it with her arms back, legs trailing, howling
    up0 = {"pel": (0, 0, -0.14), "prt": (0.3, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.2, 0, 0), "G": (0.22, -0.05, 0.86), "LP": (-0.22, -0.06, 0.84), "FL": (-0.11, 0.08, A_Z), "FR": (0.12, -0.08, A_Z), "jet": 0.6, "jaw": 0.3}
    fly = {"pel": (0, 0.0, 0.0), "prt": (0.62, 0, 0.0), "tor": (-0.05, 0, 0.0), "hed": (-0.6, 0, 0.0), "G": (0.25, -0.2, 0.98), "LP": (-0.29, -0.2, 0.96), "FL": (-0.12, -0.14, 0.38), "FR": (0.13, -0.3, 0.52),
           "FLp": 0.8, "FRp": 1.1, "jet": 1.0, "jaw": 0.9, "brow": -0.6, "lid": 0.05, "skirt": -0.7, "fing": 0.8}
    f2 = dict(fly, prt=(0.56, 0, 0.05), FL=(-0.12, -0.2, 0.44), FR=(0.13, -0.24, 0.47), pel=(0, 0, 0.02), jet=0.88)
    f3 = dict(fly, prt=(0.66, 0, -0.05), jet=1.0)
    out.append(C("jet", 1.0, [(0.0, END), (0.08, up0, "out"), (0.22, fly, "out"), (0.45, f2), (0.72, f3), (1.0, fly)]))
    fl0 = dict(fly, pel=(0, 0, 0.1), jet=0.4, prt=(0.2, 0, 0), FL=(-0.12, 0.06, 0.34), FR=(0.13, -0.02, 0.36))
    sq = {"pel": (0, 0.0, -0.2), "prt": (0.32, 0, 0), "tor": (0.3, 0, 0), "hed": (-0.28, 0, 0), "G": (0.25, 0.04, 0.72), "LP": (-0.28, 0.1, 0.8), "FL": (-0.12, 0.1, A_Z), "FR": (0.13, -0.08, A_Z), "jet": 0.0, "jaw": 0.4, }
    out.append(C("jet_land", 0.36, [(0.0, fl0), (0.08, sq, "out"), (0.2, dict(sq, pel=(0, 0, -0.08))), (0.36, END)]))
    # air
    out.append(C("jump", 0.45, [(0.0, {"pel": (0, 0, -0.1), "prt": (0.2, 0, 0)}), (0.07, {"pel": (0, 0, 0.02), "prt": (-0.05, 0, 0), "tor": (-0.12, 0.1, 0), "FL": (-0.09, 0.2, 0.34), "FR": (0.12, -0.1, 0.2), "FLp": -0.4, "FRp": 0.5, "LP": (-0.3, 0.12, 1.1), "jaw": 0.3}, "out"),
                                (0.3, {"FL": (-0.09, 0.14, 0.38), "FR": (0.12, 0.0, 0.3)}), (0.45, {"FL": (-0.09, 0.1, 0.32), "FR": (0.12, -0.02, 0.28), })]))
    ri = {"pel": (0, 0, 0.02), "prt": (-0.04, 0, 0), "tor": (-0.08, 0.1, 0), "FL": (-0.09, 0.14, 0.36), "FR": (0.12, -0.02, 0.28), "FLp": -0.3, "FRp": 0.5, "LP": (-0.3, 0.1, 1.06), "jaw": 0.2}
    out.append(C("rise", 0.4, [(0.0, ri), (0.2, dict(ri, FL=(-0.09, 0.15, 0.38))), (0.4, ri)]))
    fa = {"pel": (0, 0, 0.03), "prt": (0.08, 0, 0), "tor": (-0.08, 0, 0), "hed": (0.06, 0, 0), "G": (0.3, 0.1, 0.96), "LP": (-0.36, 0.06, 1.04), "FL": (-0.11, 0.12, 0.25), "FR": (0.13, -0.08, 0.31), "FLp": 0.3, "FRp": 0.4, "fing": 0.1, "skirt": 0.35, "jaw": 0.2}
    out.append(C("fall", 0.6, [(0.0, fa), (0.3, dict(fa, FL=(-0.11, 0.09, 0.27), FR=(0.13, -0.05, 0.28), LP=(-0.36, 0.06, 1.08))), (0.6, fa)]))
    l2 = {"pel": (0, 0.02, -0.2), "prt": (0.3, 0, 0), "tor": (0.26, 0, 0), "hed": (-0.26, 0, 0), "G": (0.28, 0.08, 0.72), "LP": (-0.3, 0.06, 0.74), "FL": (-0.12, 0.08, A_Z), "FR": (0.13, -0.08, A_Z), "fing": 0.5}
    out.append(C("land", 0.4, [(0.0, dict(l2, pel=(0, 0, -0.04))), (0.08, l2, "out"), (0.4, END)]))
    sg = (K.SH - 0.02, -0.06, K.SHOULDER_Z + 0.36)
    gl = {"pel": (0, 0, 0.0), "prt": (0.12, 0, 0), "tor": (-0.02, 0, 0), "hed": (-0.08, 0, 0), "G": sg, "LP": (-sg[0], sg[1], sg[2] - 0.06), "FL": (-0.1, 0.0, 0.2), "FR": (0.12, -0.2, 0.26), "FLp": 0.4, "FRp": 0.5, "fing": 1.0, "skirt": -0.2, "jaw": 0.3, }
    out.append(C("glide", 1.6, [(0.0, gl), (0.8, dict(gl, pel=(0.01, 0, 0.012), FR=(0.12, -0.23, 0.27), FL=(-0.1, 0.03, 0.19))), (1.6, gl)]))
    # hits: she's light on her feet, it throws her; a flash of real outrage
    hf = {"pel": (0, -0.08, -0.08), "prt": (-0.16, 0.08, 0.06), "tor": (-0.34, -0.22, 0.14), "hed": (0.3, 0.3, 0.12), "brow": 1.0, "lid": 0.5, "jaw": 0.55, "G": (0.34, 0.02, 0.86), "LP": (-0.3, 0.1, 1.0), "FR": (0.15, -0.16, A_Z), "skirt": -0.3}
    out.append(C("hit_f", 0.42, [(0.0, END), (0.06, hf, "out"), (0.42, END)]))
    hb = dict(hf, pel=(0, 0.08, -0.09), prt=(0.32, -0.08, -0.05), tor=(0.46, 0.2, -0.1), hed=(-0.55, -0.2, 0), G=(0.3, 0.28, 0.78), LP=(-0.3, 0.2, 0.86), FR=(0.13, -0.05, A_Z), FL=(-0.09, 0.18, A_Z), skirt=0.3)
    out.append(C("hit_b", 0.42, [(0.0, END), (0.06, hb, "out"), (0.42, END)]))
    s1 = {"pel": (0.02, -0.02, -0.12), "prt": (0.14, 0.1, 0.1), "tor": (0.26, 0.1, 0.16), "hed": (0.46, 0.3, 0.3), "G": (0.3, 0.06, 0.66), "LP": (-0.28, 0.08, 0.72), "lid": 0.62, "brow": -1.0, "jaw": 0.6, "fing": 0.1}
    s2 = dict(s1, pel=(-0.02, -0.02, -0.12), prt=(0.14, -0.1, -0.1), tor=(0.26, -0.1, -0.16), hed=(0.46, -0.3, -0.3))
    out.append(C("stun", 1.2, [(0.0, s1), (0.6, s2), (1.2, s1)]))
    # downed: sat down hard on one hip, propped on her off hand, the tail limp, still furious
    dn = {"pel": (0.05, -0.08, -0.56), "prt": (-0.12, 0.2, -0.18), "tor": (0.42, 0.15, 0.2), "hed": (0.1, 0.1, 0.15), "G": (0.24, 0.3, 0.46), "LP": (-0.32, -0.16, 0.13), "FL": (-0.2, 0.5, 0.1), "FR": (0.2, 0.26, 0.1), "FLp": -0.7, "FRp": 0.2, "FRy": -0.5, "FLy": 0.4,
          "brow": 0.9, "lid": 0.4, "fing": 0.1, "jaw": 0.15, "skirt": 0.5}
    out.append(C("downed", 2.4, [(0.0, dn), (1.2, dict(dn, tor=(0.46, 0.15, 0.2), pel=(0.05, -0.08, -0.57), hed=(0.15, 0.1, 0.15))), (2.4, dn)]))
    # death: a last laugh dies in her throat; she staggers back, her knees go, she falls on her side and her hand falls open
    dead = {"pel": (0.05, -0.1, -0.66), "prt": (0.18, 0.2, 1.3), "tor": (0.2, 0.2, 0.2), "hed": (0.2, 0.3, 0.3), "G": (0.62, 0.44, 0.08), "LP": (-0.25, 0.32, 0.16), "FL": (0.3, 0.36, 0.1), "FR": (0.42, 0.1, 0.1), "FLp": 0.4, "FRp": 0.4, "lid": 1.0, "brow": -0.4, "fing": 0.0, "jaw": 0.3, "skirt": 0.3}
    out.append(C("death", 1.5, [(0.0, END), (0.18, {"pel": (0, -0.08, -0.06), "prt": (-0.2, 0, 0), "tor": (-0.3, 0, 0), "hed": (-0.5, 0, 0), "lid": 0.1, "brow": -1, "jaw": 0.8, "G": (0.34, 0.1, 0.78)}, "out"),
                                (0.6, {"pel": (0.02, -0.04, -0.38), "prt": (0.3, 0.1, 0.4), "tor": (0.4, 0.1, 0.1), "hed": (0.4, 0.2, 0.2), "G": (0.46, 0.34, 0.42), "LP": (-0.3, 0.24, 0.48), "FL": (-0.14, 0.12, A_Z), "FR": (0.2, 0.14, A_Z), "lid": 0.6, "jaw": 0.4}),
                                (1.05, dead, "in"), (1.25, dict(dead, pel=(0.05, -0.1, -0.645)), "out"), (1.5, dead)]))
    # Fusion: both hands up as the fire takes her, a deep breath in, then flung out
    fu0 = {"pel": (0, 0, -0.14), "prt": (0.2, 0, 0), "tor": (0.3, 0, 0), "hed": (0.1, 0, 0), "G": (0.1, 0.17, 1.02), "LP": (-0.12, 0.17, 1.04), "lid": 0.7, "jaw": 0.0}
    fu1 = {"pel": (0, 0, 0.0), "prt": (-0.14, 0, 0), "tor": (-0.32, 0, 0), "hed": (-0.5, 0, 0), "G": (0.48, 0.05, 1.3), "LP": (-0.48, 0.05, 1.32), "cast": 1.0, "castl": 1.0, "lid": 0.05, "jaw": 1.0, "brow": -0.7, "fing": 0.0, "jet": 0.8}
    out.append(C("fusion", 0.8, [(0.0, END), (0.18, fu0), (0.3, dict(fu0, pel=(0, -0.02, -0.2))), (0.45, fu1, "out"), (0.58, dict(fu1, pel=(0, 0, -0.02))), (0.8, END)]))
    # the emote: a flame held up, head thrown back, one long cackle she can't stop, shoulders shaking, the free hand on her belly
    em = dict(OFFERED, pel=(0.04, 0, -0.03), prt=(-0.06, -0.2, 0.12), tor=(-0.14, 0.28, -0.12), hed=(-0.5, -0.1, 0.1), LP=(-0.12, 0.17, 0.98), jaw=1.0, brow=-0.8, lid=0.72, fing=0.4, FL=(-0.075, 0.09, A_Z), FR=(0.155, -0.07, A_Z), FLy=0.42, FRy=-0.5)
    shake = []
    t = 0.45
    i = 0
    while t < 2.3:
        d = dict(em, tor=(-0.14 + (0.1 if i % 2 else -0.02), 0.28, -0.12), pel=(0.04, 0, -0.03 - (0.022 if i % 2 else 0)), jaw=0.45 if i % 2 else 1.0, hed=(-0.5 + (0.1 if i % 2 else 0.0), -0.1, 0.1))
        shake.append((t, d))
        t += 0.14
        i += 1
    out.append(C("emote", 3.0, [(0.0, END), (0.4, em, "out")] + shake + [(2.5, dict(em, hed=(-0.2, -0.2, 0.2), jaw=0.2, lid=0.15, tor=(0.0, 0.3, -0.15))), (3.0, END)]))
    return out


def extras(P):
    if not P:
        return {}
    o = {}
    b, l = P.get("brow", 0.0), P.get("lid", 0.1)
    f = P.get("fing", 0.1)
    for s, side, c in ((1.0, "R", f), (-1.0, "L", max(f, P.get("fistl", 0.0)))):
        o["brow." + side] = (Quaternion((0, 1, 0), -s * 0.22 * b), Vector((0, -0.0055 * b, 0)))
        o["lid." + side] = (Quaternion((1, 0, 0), LID_SIGN * 1.3 * l), None)
        o["fingers." + side] = (Quaternion((1, 0, 0), 0.9 * c), None)
        o["thumb." + side] = (Quaternion((1, 0, 0), 0.4 * c), None)
    # the apron rides over the leading thigh
    lead = max(P["FL"][1], P["FR"][1], 0.0) * 1.15 + 0.5 * max(P["FL"][2] - A_Z, P["FR"][2] - A_Z, 0.0)
    o["skirt"] = (Quaternion((1, 0, 0), SKIRT_SIGN * (0.35 * P.get("skirt", 0.0) + min(lead, 0.6))), None)
    o["jaw"] = (Quaternion((1, 0, 0), JAW_SIGN * 0.2 * P.get("jaw", 0.0)), None)
    return o


LID_SIGN, SKIRT_SIGN, JAW_SIGN = 1.0, 1.0, -1.0
JET_BONES = ("jet.0", "jet.1")


class CastSolver(Solver):
    """Her empty hands: each hangs along its arm, or by "cast"/"castl" turns palm out, fingers up. The base solver's sword hand is the right palm; the left is set after it."""
    RELAXED = {"R": ("G", 1.0), "L": ("LP", -1.0)}

    def hand_q(self, side, P, c):
        key, sx = self.RELAXED[side]
        f = (Vector(P[key]) - self.H0["upper_arm." + side]).normalized()
        k = max(f.y, 0.0)
        edge = Vector((-sx * k, 1.0 - k, 0.0)).normalized()
        relaxed = frame_of(tuple(edge.cross(f).normalized() * sx), tuple(edge))
        cast = frame_of(D(0, 4), (-sx * 0.9, 0.0, 0.45))
        return relaxed.slerp(cast, c) @ frame_of((-sx, 0, 0), (0, 1, 0)).inverted()

    def solve(self, P):
        P = dict(P, BE=self.hand_q("R", P, P.get("cast", 0.0)) @ self.rest_frame)
        Q, at_ = super().solve(P)
        Q["hand.L"] = self.hand_q("L", P, P.get("castl", 0.0))
        return Q, at_


def bake_jets(arm, clip, act):
    """The heels' flames stretch with "jet", and all but vanish at rest: a scale track on their own bones (variant bones keep their scale under the clips)."""
    arm.animation_data.action = act
    n = max(2, int(round(clip.dur * FPS)) + 1)
    pbs = arm.pose.bones
    for f in range(n):
        t = clip.dur * f / (n - 1)
        j = clip.sample(t).get("jet", 0.0)
        for i, nm in enumerate(JET_BONES):
            w = 0.25 + j * 1.1
            ln = 0.06 + j * (3.0 + 0.5 * math.sin(t * 37.0 + i * 2.0))
            pbs[nm].scale = (w, ln, w)
            pbs[nm].keyframe_insert("scale", frame=f)
    arm.animation_data.action = None


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig = {"grip_rest": tuple(bpy.context.scene["palm"]), "blade_rest": tuple(K.GUN_B), "edge_rest": tuple(K.GUN_E), "pelvis": K.HIPS_Z + 0.03, "hilt_l": -K.FORE,
           "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": (-K.SH + 0.005, 0.0, K.HAND_Z - 0.05)}}
    bpy.context.scene.render.fps = FPS
    sol = CastSolver(arm, rig)
    bpy.context.view_layer.objects.active = arm
    names = []
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        act = bake(arm, c, sol, extras)
        bake_jets(arm, c, act)
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
