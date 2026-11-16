"""ART-1 Grimble's animation set (keyed as targets, solved on tools/art1/posekit.py). Times are the kit's: scripts/match/kmoves_pair.gd
and content/archetypes/dredge.json. Personality: greedy, delighted, twitchy; a long-limbed scuttle, the hoard slung after him, a
grin that never leaves. The hook is his right hand; the left is the scrap fist; the blunderbuss swivels on his hip and the fist
slaps onto its stock to fire. Dashes are the junk ball. He rears up on one foot to gloat.
Run: blender -b --python tools/art1/grimble_clips.py -- <grimble_art1.blend> <out.glb> [clip,clip]"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import grimble_sculpt as G
import crouchkit
import skin_relax
from posekit import Clip, FnClip, Solver, ang_dir as D, at, eul, frame_of

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
J = G.joints(os.path.join(REPO, "art/wardens/src/dredge_rig.json"))
FPS = 30
A_Z = G.ANKLE
UP = (0, 0, 1)
PELVIS = 0.66
SHOULDER = float(J["upper_arm.R"][2])
GAUNT = 0.125        # m wrist to the fist's middle


def be(a, e, edge):
    """The hook's shank toward ang_dir(a, e), its mouth toward `edge`."""
    return (D(a, e), edge)


FLAT = (-0.75, 0.25, 0.6)           # the hook's plane laid over, so the J reads from above
READY = {
    "pel": (0.0, -0.015, -0.075), "prt": (0.12, 0.06, 0.0), "tor": (0.26, 0.06, 0.02), "hed": (-0.38, -0.06, 0.05),
    "G": (0.405, 0.335, 0.610), "BE": be(-30, -30, FLAT), "Lw": 0.0, "LP": (-0.385, 0.275, 0.590), "Lg": 0.0, "Lh": (0.25, 0.0, 0.0),
    "FL": (-0.175, 0.13, A_Z), "FR": (0.195, -0.11, A_Z), "FLy": 0.30, "FRy": -0.40, "FLp": 0.0, "FRp": 0.0,
    "brow": 0.2, "lid": 0.0, "jaw": 0.0, "fing": 0.45, "skirt": 0.0, "gw": 0.0, "gp": 0.0, "gl": (0, 0, 0), "hd": (0.0, 0.0, 0.0), "hl": (0, 0, 0), "hs": 1.0,
    "bs": 1.0, "bl": 0.0, "spin": 0.0, "rel": 0.0, "look": 0.0,
}
KEYS_END = {k: READY[k] for k in READY}
HOT = {"brow": 0.9, "lid": -0.15, "jaw": 0.35}          # eyes wide, grin split
GLEE = {"brow": -0.7, "lid": -0.3, "jaw": 0.7}


def C(name, dur, keys, loop=False, base=READY):
    return Clip(name, dur, keys, base, loop)


class GSolver(Solver):
    """posekit's Solver with the hook as the right hand's blade and a free scrap fist: LP the wrist, Lg 1 on the gun's stock; extra world
    bones: the swivelling gun, the hoard's lag, the ball, the face. `rel` 1: hands and feet are written in the root's frame (the roll)."""

    def __init__(self, arm):
        wr = tuple(float(a) for a in J["hand.R"])
        super().__init__(arm, {"pelvis": PELVIS, "grip_rest": wr, "blade_rest": (0, 0, -1), "edge_rest": (0, 1, 0), "hilt_l": 0.1,
                               "lhand": {"k": (0, 1, 0), "o": (1, 0, 0), "palm": tuple(float(a) for a in J["hand.L"])}})
        self.gun_rest = Vector(tuple(G.GUN_R[:, 1])).normalized()
        self.GA = Vector(tuple(G.GUN_AT))
        self.BA = Vector(tuple(G.BALL_AT))
        self.HB = Vector(tuple(G.HB))

    def solve(self, P):
        P = dict(P)
        piv = Vector((0, 0, PELVIS))
        q_root = eul(P["prt"])
        pel = Vector(P["pel"])
        root_at = piv + pel - q_root @ piv

        def R(x):
            return q_root @ (Vector(x) - self.H0["root"]) + root_at
        # the gun: rest, or swung to the aim; gp its pitch up (the kick), gl a shift in the root's frame
        aim = Vector(D(0, 0)) * 1.0
        q_aim = self.gun_rest.rotation_difference((Quaternion((1, 0, 0), P["gp"]) @ aim).normalized())
        q_g = Quaternion().slerp(q_aim, P["gw"])
        ga = self.GA + Vector(P["gl"]) * P["gw"]
        stock = ga + q_g @ (self.gun_rest * -0.115) + Vector((0, 0, -0.012))
        grip = R(stock) + q_root @ Vector((-0.035, -0.012, GAUNT * 0.86))
        rel = P.get("rel", 0.0)
        if rel > 0:
            for k in ("G", "LP", "FL", "FR"):
                P[k] = tuple(Vector(P[k]).lerp(R(P[k]), rel))
        P["LP"] = tuple(Vector(P["LP"]).lerp(grip, P["Lg"]))
        Q, root_at = super().solve(P)
        q_head = Q["head"]
        Q["hand.L"] = Q["forearm.L"] @ eul(P["Lh"])
        Q["gun"] = q_root @ q_g
        Q["hoard"] = Q["hips"] @ eul(P["hd"])
        Q["ball"] = q_root @ Quaternion((1, 0, 0), -P["spin"])
        Q["jaw"] = q_head @ Quaternion((1, 0, 0), -0.46 * P["jaw"])
        Q["lid"] = q_head @ Quaternion((1, 0, 0), -0.95 * P["lid"])
        Q["eye"] = q_head @ Quaternion((0, 0, 1), P["look"])
        Q["brow"] = q_head @ Quaternion((0, 1, 0), 0.16 * P["brow"])
        f = P["fing"]
        Q["fingers.L"] = Q["hand.L"] @ Quaternion((0, 1, 0), -1.05 * f + 0.28)
        Q["fingers2.L"] = Q["fingers.L"] @ Quaternion((0, 1, 0), -0.95 * f + 0.25)
        Q["thumb.L"] = Q["hand.L"] @ Quaternion((0, 1, 0), 0.5 * f - 0.15)
        Q["skirt"] = Q["hips"].slerp(q_root, 0.8) @ Quaternion((1, 0, 0), 0.4 * P["skirt"])
        L = {"brow": Vector((0, 0.003 * P["brow"], -0.0068 * P["brow"])),
             "ball": Vector((0, 0.05 - float(self.BA.y), PELVIS - float(self.BA.z))) * P["bl"], "gun": Vector(P["gl"]) * P["gw"],
             "hoard": Vector(P["hl"])}
        S = {"hoard": P["hs"], "ball": P["bs"]}
        return Q, root_at, L, S


ORDER = ("root", "hips", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R",
         "shin.R", "foot.R", "gun", "hoard", "ball", "jaw", "lid", "eye", "brow", "fingers.L", "fingers2.L", "thumb.L", "hook", "skirt")


def bake(arm, clip, sv):
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    n = max(2, int(round(clip.dur * FPS)) + 1)
    pbs = arm.pose.bones
    for f in range(n):
        t = clip.dur * f / (n - 1)
        Q, root_at, L, S = sv.solve(clip.sample(t))
        for b in ORDER:
            if b not in Q:
                continue
            par = sv.b[b].parent.name if sv.b[b].parent else None
            dq_p = Q.get(par, Quaternion()) if par else Quaternion()
            q = sv.R0[b].inverted() @ dq_p.inverted() @ Q[b] @ sv.R0[b]
            pb = pbs[b]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q.normalized()
            pb.keyframe_insert("rotation_quaternion", frame=f)
        pbs["root"].location = sv.R0["root"].inverted() @ (root_at - sv.H0["root"])
        pbs["root"].keyframe_insert("location", frame=f)
        for b, d in L.items():
            pbs[b].location = sv.R0[b].inverted() @ d
            pbs[b].keyframe_insert("location", frame=f)
        for b, s in S.items():
            pbs[b].scale = (s, s, s)
            pbs[b].keyframe_insert("scale", frame=f)
    arm.animation_data.action = None
    return act


# ---- idle and stance
def idle(u):
    a, b = math.sin(u * 2 * math.pi), math.cos(u * 2 * math.pi)
    p = dict(READY)
    p["pel"] = (0.006 * b, -0.015, -0.075 - 0.011 * a)
    p["tor"] = (0.26 + 0.022 * a, 0.06 + 0.012 * b, 0.02)
    p["hed"] = (-0.38 - 0.022 * a, -0.06 + 0.08 * math.sin(u * 4 * math.pi + 0.7), 0.05 + 0.03 * b)
    g = READY["G"]
    p["G"] = (g[0], g[1] + 0.006 * b, g[2] - 0.012 * a)
    l = READY["LP"]
    p["LP"] = (l[0] - 0.004 * a, l[1], l[2] - 0.012 * a)
    p["hd"] = (0.016 * a, 0.014 * b, 0.0)
    p["fing"] = 0.45 + 0.16 * max(0, math.sin(u * 6 * math.pi))         # the fingers drum
    p["look"] = 0.10 * math.sin(u * 4 * math.pi)
    p["lid"] = 1.0 if 0.60 < u < 0.625 else 0.0                          # one quick blink
    p["jaw"] = 0.06 * (1 + math.sin(u * 8 * math.pi))
    return p


def stance(u):
    """Signature: the fist brought up to the monocle, appraising a coin in it, the hook hanging slack; a twitch of a grin."""
    a = math.sin(u * 2 * math.pi)
    p = dict(READY)
    p.update({"pel": (0.02, 0.0, -0.075 - 0.008 * a), "prt": (0.12, 0.20, 0.02), "tor": (0.26, 0.12, 0.05), "hed": (-0.40, -0.22, -0.16),
              "LP": (-0.19, 0.40, 1.24 - 0.008 * a), "Lh": (2.4, 0.1, 0.4), "fing": 0.74, "G": (0.42, 0.14, 0.60), "BE": be(-30, -60, FLAT),
              "brow": 0.45, "lid": 0.0, "jaw": 0.25 + 0.2 * max(0, math.sin(u * 4 * math.pi)), "look": -0.12,
              "FL": (-0.17, 0.16, A_Z), "FR": (0.20, -0.13, A_Z), "hd": (0.012 * a, 0.0, 0.0)})
    return p


# ---- locomotion: a loping scuttle, the long arms swinging, the hoard rocking after him
def gait(k, heading):
    d = Vector((-math.sin(math.radians(heading)), math.cos(math.radians(heading)), 0))
    stride = 0.15 + 0.25 * k
    lift = 0.05 + 0.15 * k
    share = 0.60 - 0.2 * k
    back, fwd = max(0.0, -d.y), max(0.0, d.y)

    def foot(ph, sx):
        ph = ph % 1.0
        base = Vector((sx * 0.155, 0, A_Z))
        if ph < share:
            q = ph / share
            s, z, pit = 1 - 2 * q, 0.0, 0.0
        else:
            q = (ph - share) / (1 - share)
            sm = q * q * (3 - 2 * q)
            s = -1 + 2 * sm
            z = lift * math.sin(q * math.pi) ** 0.8
            pit = -0.8 * math.sin(q * math.pi) * k
        return base + d * s * stride + Vector((0, 0, z)), pit

    def fn(u):
        p = dict(READY)
        rp, pr = foot(u, 1.0)
        lp, pl = foot(u + 0.5, -1.0)
        p["FR"], p["FL"] = tuple(rp), tuple(lp)
        p["FRp"], p["FLp"] = pr, pl
        p["FRy"], p["FLy"] = -0.14 + math.radians(heading) * 0.5, 0.14 + math.radians(heading) * 0.5
        s2 = math.sin(u * 4 * math.pi + 0.5)
        c1 = math.cos(u * 2 * math.pi)
        drop = -0.085 - 0.04 * k + (0.024 + 0.034 * k) * s2
        lean = (0.20 + 0.34 * k) * fwd - 0.10 * back
        p["pel"] = (0.03 * c1, 0.03 * k * fwd - 0.03 * back, drop)
        p["prt"] = (lean * 0.55 + 0.06, 0.16 * c1 * k, -0.04 * c1 + 0.14 * k * d.x)
        p["tor"] = (lean * 0.7 + 0.22 + 0.02 * s2, -0.28 * c1 * k + 0.06, 0.06 * c1)
        p["hed"] = (-lean * 1.05 - 0.40, 0.22 * c1 * k - 0.06, -0.05 * c1)
        # the hoard lags a beat and rocks
        s2b = math.sin(u * 4 * math.pi - 0.9)
        p["hd"] = (0.05 * s2b * (0.4 + k) - 0.05 * k, 0.05 * math.sin(u * 2 * math.pi - 0.8) * (0.4 + k), 0.04 * math.sin(u * 2 * math.pi - 0.8))
        # the hook swings long and low, trailing at speed; the fist pumps
        sw = -c1 * (0.18 + 0.26 * k)
        p["G"] = (0.40 + 0.03 * k, 0.22 + sw - 0.24 * k, 0.60 + 0.08 * abs(sw) + 0.03 * k)
        trail = -34 - 112 * k
        p["BE"] = be(trail - 16 * c1 * k, -38 + 24 * k, FLAT)
        p["LP"] = (-0.385, 0.20 + c1 * (0.16 + 0.26 * k), 0.60 + 0.12 * max(0, c1) * (0.5 + k))
        p["Lh"] = (0.3 + 0.5 * k, 0, 0)
        p["fing"] = 0.5 + 0.35 * k
        p["skirt"] = 0.3 * c1 * k - 0.35 * k
        p["brow"], p["lid"], p["jaw"] = 0.15 + 0.3 * k, 0.0, 0.1 + 0.15 * k
        return p
    return fn


# ---- the crouch (item 143): a greedy scuttle. Spider low, the long arms spread over the floor, hook out, scrap fist out, the hoard riding his back, grinning at what's yours.
SCUTTLE = dict(READY, **{
    "pel": (0.0, -0.05, -0.21), "prt": (0.40, 0.08, 0.0), "tor": (0.42, 0.06, 0.02), "hed": (-0.76, -0.06, 0.05),
    "G": (0.46, 0.44, 0.34), "LP": (-0.44, 0.40, 0.33), "Lh": (0.4, 0.0, 0.0),
    "FL": (-0.22, 0.20, A_Z + 0.03), "FR": (0.24, -0.18, A_Z + 0.05), "FLy": 0.4, "FRy": -0.5, "FLp": 0.25, "FRp": 0.5,
    "brow": 0.4, "lid": -0.15, "jaw": 0.35, "fing": 0.7,
})
SKITTER = {"ankle": A_Z, "foot": 0.09, "width": 0.19, "stride": 0.25, "lift": 0.05, "toe": 0.24, "share": 0.58, "sway": 0.03, "bob": 0.014, "twist": 0.1, "T": 0.5, "toe_out": -0.34}


def crouch_set():
    return crouchkit.quick(C, READY, SCUTTLE, SKITTER, scan=0.3)


def clips():
    o = []
    o.append(FnClip("idle", 3.0, idle))
    o.append(FnClip("stance", 4.0, stance))
    o += crouch_set()
    for nm, k, T in (("walk", 0.45, 1.0), ("run", 1.0, 0.62)):
        for tag, hd in (("f", 0), ("b", 180), ("l", 90), ("r", -90)):
            o.append(FnClip("%s_%s" % (nm, tag), T, gait(k, hd)))
    END = dict(KEYS_END)

    # LMB: the fist slaps the stock, the gun swings forward, and it kicks him back on his heels. 0.36 s, a shot each 0.5 s
    sh0 = {"gw": 1.0, "Lg": 1.0, "fing": 0.95, "tor": (0.26, 0.02, 0.0), "hed": (-0.40, 0.0, 0.0), "gl": (0.0, 0.04, 0.06), "gp": 0.0, "brow": 0.8, "lid": -0.2, "jaw": 0.3, "G": (0.42, 0.10, 0.70), "BE": be(-80, -30, FLAT)}
    sh1 = dict(sh0, tor=(0.08, -0.12, 0.05), pel=(0.0, -0.05, -0.085), prt=(0.04, 0.05, 0.0), hed=(-0.28, 0.12, 0.0), gp=0.34, hd=(-0.12, 0.0, 0.03), jaw=0.8, lid=-0.3, brow=1.0)
    sh2 = dict(sh0, tor=(0.20, -0.04, 0.02), pel=(0.0, -0.03, -0.085), gp=0.12, hd=(0.06, 0.0, 0.0), jaw=0.5)
    o.append(C("shot", 0.36, [(0.0, sh0), (0.05, sh1, "out"), (0.14, sh2), (0.24, sh0), (0.36, dict(sh0, Lg=0.0, gw=0.25, fing=0.45, tor=READY["tor"], gl=(0, 0, 0)))]))

    # RMB: the hook slung: a coil behind him, a whip over the shoulder, the arm stays out along the chain while it flies
    th0 = {"pel": (0, -0.06, -0.11), "prt": (0.05, -0.32, 0), "tor": (0.08, -0.46, 0.08), "hed": (-0.30, 0.72, 0.0), "G": (0.50, -0.26, 1.04), "BE": be(-150, 34, (0, 0, 1)), "LP": (-0.30, 0.34, 0.92), "fing": 0.8, "brow": 0.9, "lid": -0.15, "jaw": 0.3, "hd": (0.0, 0.10, 0.03)}
    th1 = {"pel": (0, 0.12, -0.13), "prt": (0.34, 0.34, 0), "tor": (0.34, 0.42, -0.08), "hed": (-0.62, -0.70, 0.06), "G": at(-14, 0.76, 1.02), "BE": be(-10, -4, (0, 0, 1)), "LP": (-0.36, -0.16, 0.76), "FL": (-0.18, 0.32, A_Z), "FR": (0.20, -0.30, A_Z), "jaw": 0.8, "lid": -0.3, "hd": (0.10, -0.12, -0.04)}
    th2 = dict(th1, G=at(-12, 0.74, 1.00), hd=(0.0, -0.06, 0), jaw=0.45)
    o.append(C("throw", 0.7, [(0.0, END), (0.08, th0, "out"), (0.14, th1, "out"), (0.22, th2), (0.45, dict(th2, G=at(-12, 0.71, 0.97), pel=(0, 0.09, -0.12))), (0.7, END)]))
    # the reel, hold: braced, the arm hauled in over and over (two hauls in a loop, HAUL_T 0.26)
    r1 = {"pel": (0, -0.08, -0.17), "prt": (0.12, -0.30, 0.02), "tor": (0.0, -0.42, 0.08), "hed": (-0.20, 0.70, -0.04), "G": (0.42, -0.22, 0.96), "BE": be(-40, 14, (0, 0, 1)), "LP": (-0.30, 0.42, 0.82), "fing": 1.0, "FL": (-0.20, 0.32, A_Z), "FR": (0.22, -0.30, A_Z), "brow": 1.0, "lid": -0.15, "jaw": 0.6, "hd": (-0.08, 0.12, 0.03)}
    r2 = dict(r1, pel=(0, 0.04, -0.14), prt=(0.26, 0.10, 0.0), tor=(0.26, 0.10, 0.0), hed=(-0.50, -0.05, 0.03), G=at(-22, 0.62, 1.0), BE=be(-22, -2, (0, 0, 1)), LP=(-0.34, 0.08, 0.84), hd=(0.08, -0.08, -0.03), jaw=0.3)
    o.append(C("reel", 0.70, [(0.0, th2), (0.18, r1, "out"), (0.44, r2), (0.70, r1)]))
    # the catch: he snatches the catch in and grins over it
    o.append(C("pullend", 0.36, [(0.0, r1), (0.08, dict(r2, G=(0.34, 0.42, 0.86), BE=be(-20, -30, FLAT), LP=(-0.30, 0.46, 0.80), jaw=0.9, lid=-0.3), "out"), (0.22, dict(r2, G=(0.36, 0.34, 0.80), hd=(0.04, 0, 0))), (0.36, END)]))

    # E: the scrap fist: raised through the wind-up (0.38), slammed into the cone ahead, a long drag home
    up = {"pel": (0.02, -0.06, -0.06), "prt": (-0.02, 0.26, 0), "tor": (-0.14, 0.34, 0.05), "hed": (-0.14, -0.40, 0.02), "LP": (-0.24, 0.10, 1.54), "Lh": (0.5, 0, 0), "fing": 1.0, "G": (0.46, -0.08, 0.84), "BE": be(-120, -6, FLAT), "brow": 1.0, "lid": -0.3, "jaw": 0.7, "FL": (-0.22, 0.28, A_Z), "FR": (0.22, -0.26, A_Z), "hd": (0.0, 0.0, 0.0)}
    up2 = dict(up, pel=(0.02, -0.09, -0.03), tor=(-0.24, 0.40, 0.06), LP=(-0.20, -0.02, 1.60), hd=(-0.10, 0, 0))
    hit = {"pel": (-0.04, 0.26, -0.27), "prt": (0.62, 0.0, 0.0), "tor": (0.52, -0.30, -0.06), "hed": (-0.86, 0.26, 0.08), "LP": (-0.14, 0.86, 0.21), "Lh": (0.0, 0, 0), "G": (0.50, -0.10, 0.92), "BE": be(-140, 0, FLAT), "FL": (-0.22, 0.44, A_Z), "FR": (0.26, -0.34, A_Z), "FRp": -0.5, "jaw": 1.0, "skirt": 0.5, "hd": (0.18, 0.0, 0.0)}
    o.append(C("anchor", 1.0, [(0.0, END), (0.12, up), (0.30, up2), (0.38, hit, "out"), (0.48, dict(hit, pel=(-0.04, 0.24, -0.25), hd=(-0.06, 0, 0)), "out"), (0.75, dict(hit, pel=(0.0, 0.14, -0.18), prt=(0.36, 0, 0), tor=(0.38, 0, 0), LP=(-0.22, 0.64, 0.38), hd=(0.0, 0, 0), jaw=0.5)), (1.0, END)]))
    # E in the air: the fist under him, legs flung up behind, held till the ground
    dv = {"pel": (0, 0.0, 0.10), "prt": (0.95, 0, 0), "tor": (0.32, 0, 0), "hed": (-0.95, 0, 0), "LP": (-0.10, 0.44, 0.30), "Lh": (0, 0, 0), "fing": 1.0, "G": (0.46, -0.02, 0.98), "BE": be(-150, 10, FLAT), "FL": (-0.14, -0.42, 0.50), "FR": (0.16, -0.52, 0.56), "FLp": 0.9, "FRp": 0.9, "brow": 1, "lid": -0.3, "jaw": 1.0, "hd": (-0.16, 0, 0)}
    o.append(C("dive", 0.3, [(0.0, END), (0.12, dv, "out"), (0.3, dict(dv, pel=(0.01, 0.0, 0.115)))]))
    o.append(C("quake", 0.75, [(0.0, dict(hit, LP=(-0.06, 0.62, 0.22), pel=(0, 0.10, -0.32))), (0.3, dict(hit, pel=(0, 0.10, -0.26), LP=(-0.1, 0.60, 0.26), hd=(-0.05, 0, 0)), "out"), (0.55, dict(hit, pel=(0, 0.06, -0.17), prt=(0.32, 0, 0), tor=(0.34, 0, 0), LP=(-0.26, 0.42, 0.46))), (0.75, END)]))

    # the junk ball: he folds up inside it (a dash is 0.16 s of travel, the clip tucks fast and opens as he stops). Hands and feet in the root's frame
    tuck = {"rel": 1.0, "prt": (0.0, 0, 0), "tor": (0.85, 0, 0), "hed": (-0.42, 0, 0), "pel": (0, 0.0, -0.14), "G": (0.15, 0.24, 0.74), "BE": be(-5, -40, FLAT), "LP": (-0.15, 0.24, 0.74), "Lh": (0.2, 0, 0), "fing": 1.0,
            "FL": (-0.12, 0.20, 0.44), "FR": (0.12, 0.20, 0.44), "FLp": -0.5, "FRp": -0.5, "hs": 0.42, "hl": (0, 0.18, -0.10), "hd": (0.0, 0, 0), "bs": 4.2, "bl": 1.0, "jaw": 0.9, "lid": -0.3, "brow": 0.8, "gw": 0.0}
    # (only the ball turns: he is folded still inside it, the root never spins, so a crossfade can't swing him off his line)
    t0 = dict(tuck, prt=(0.45, 0, 0), spin=0.3)
    t1 = dict(t0, spin=2 * math.tau)
    t2 = dict(t0, spin=2.8 * math.tau)
    start = dict(END, hs=0.8, bs=2.0, bl=0.6, rel=0.5, pel=(0, 0, -0.12), tor=(0.5, 0, 0))
    o.append(C("lunge", 0.38, [(0.0, start), (0.04, t0, "out"), (0.18, t1, "lin"), (0.30, t2, "out"), (0.38, dict(END, spin=3 * math.tau))]))
    # the pounce: the same ball in the air, a slower turn
    a0 = dict(t0, pel=(0, 0, 0.0))
    o.append(C("pounce", 0.38, [(0.0, start), (0.05, a0, "out"), (0.24, dict(a0, spin=1.5 * math.tau), "lin"), (0.38, dict(END, spin=2 * math.tau))]))

    # the Salvage flex: rocks his whole pile and cackles
    fx = {"tor": (-0.05, 0.0, 0.0), "pel": (0, -0.02, -0.03), "prt": (0.0, 0, 0), "hed": (-0.34, 0.0, 0.08), "jaw": 1.0, "lid": -0.3, "brow": -0.6, "hd": (-0.16, 0.0, 0.08), "LP": (-0.44, 0.10, 0.84), "G": (0.46, 0.14, 0.86), "BE": be(-70, -20, FLAT), "fing": 1.0}
    o.append(C("flex", 0.55, [(0.0, END), (0.1, fx, "out"), (0.22, dict(fx, hd=(0.12, 0, -0.06), jaw=0.5, hed=(-0.28, 0.1, -0.05))), (0.36, dict(fx, hd=(-0.06, 0, 0.03))), (0.55, END)]))

    # R: the blunderbuss hauled up to the hip, the hook jammed under the barrel to brace it; it swells with charge (1.1 s); two blasts at 1.1 and 1.7 that shove him
    bb = {"gw": 1.0, "gl": (0.08, 0.14, 0.20), "gp": 0.06, "Lg": 1.0, "fing": 1.0, "tor": (0.16, 0.0, 0.0), "prt": (0.12, 0, 0), "pel": (0, -0.05, -0.16), "hed": (-0.34, 0, 0), "G": (0.17, 0.52, 0.76), "BE": be(40, 34, (0, 0, 1)), "FL": (-0.22, 0.26, A_Z), "FR": (0.22, -0.28, A_Z), "brow": 1.0, "lid": -0.2, "jaw": 0.5, "hd": (0.04, 0, 0)}
    b2 = dict(bb, pel=(0, -0.08, -0.21), gp=0.10, jaw=0.7, tor=(0.12, 0, 0))
    k1 = dict(bb, pel=(0, -0.13, -0.17), tor=(-0.14, 0, 0.04), prt=(-0.06, 0, 0), hed=(-0.16, 0, 0), gp=0.44, jaw=1.0, lid=-0.3, hd=(-0.22, 0, 0.05), G=(0.20, 0.44, 0.92))
    k2 = dict(bb, pel=(0, -0.09, -0.18), hd=(0.08, 0, 0))
    o.append(C("blast", 2.1, [(0.0, END), (0.15, dict(bb, gw=0.8, pel=(0, -0.03, -0.12))), (0.5, bb), (1.0, b2), (1.1, k1, "out"), (1.24, k2), (1.6, b2), (1.7, k1, "out"), (1.85, k2), (2.1, END)]))

    # air
    jm = {"pel": (0, 0, -0.18), "prt": (0.34, 0, 0), "tor": (0.40, 0, 0), "hd": (0.10, 0, 0), "LP": (-0.36, 0.0, 0.62), "G": (0.42, 0.02, 0.66)}
    ju = {"pel": (0, 0, 0.0), "prt": (0.0, 0, 0), "tor": (-0.10, 0.08, 0), "hed": (-0.20, 0, 0), "FL": (-0.15, 0.20, 0.34), "FR": (0.16, 0.0, 0.25), "FLp": -0.5, "FRp": 0.2, "LP": (-0.46, 0.10, 1.0), "G": (0.50, 0.08, 0.98), "BE": be(-60, -6, FLAT), "hd": (-0.14, 0, 0), "jaw": 0.5, "lid": -0.3, "fing": 0.2}
    o.append(C("jump", 0.55, [(0.0, jm), (0.1, ju, "out"), (0.4, dict(ju, hd=(0.08, 0, 0))), (0.55, dict(ju, FL=(-0.15, 0.12, 0.30), FR=(0.16, -0.04, 0.26)))]))
    fa = dict(ju, tor=(0.12, 0, 0), hd=(0.12, 0, 0), LP=(-0.46, 0.12, 1.02), G=(0.50, 0.10, 1.02), FL=(-0.15, 0.08, 0.27), FR=(0.16, -0.08, 0.24), FLp=0.3, FRp=0.3, jaw=0.2)
    o.append(C("fall", 0.6, [(0.0, fa), (0.3, dict(fa, LP=(-0.47, 0.12, 1.05), G=(0.50, 0.10, 1.05))), (0.6, fa)]))
    ld = {"pel": (0, 0.03, -0.31), "prt": (0.46, 0, 0), "tor": (0.42, 0, 0), "hed": (-0.62, 0, 0), "LP": (-0.36, 0.34, 0.26), "G": (0.42, 0.36, 0.34), "hd": (0.20, 0, 0), "FL": (-0.20, 0.20, A_Z), "FR": (0.22, -0.14, A_Z), "FLp": 0, "FRp": 0, "jaw": 0.3}
    o.append(C("land", 0.4, [(0.0, ld), (0.14, dict(ld, pel=(0, 0.03, -0.33), hd=(-0.10, 0, 0)), "out"), (0.4, END)]))
    # the glide: both arms up on the glider's grips, the pile hanging under him
    wz = SHOULDER + 0.36
    sx = float(J["upper_arm.R"][0]) - 0.02
    gl = {"pel": (0, 0, 0), "prt": (0.20, 0, 0), "tor": (0.02, 0, 0), "hed": (-0.26, 0, 0), "G": (sx, -0.06, wz), "BE": be(-170, -66, (0, 0, 1)), "LP": (-sx, -0.06, wz + 0.04), "Lh": (3.0, 0, 0), "fing": 1.0, "FL": (-0.13, -0.06, 0.20), "FR": (0.14, -0.20, 0.26), "FLp": 0.4, "FRp": 0.6, "hd": (0.0, 0, 0), "skirt": -0.4, "jaw": 0.3}
    o.append(C("glide", 1.2, [(0.0, gl), (0.6, dict(gl, pel=(0.01, 0, 0.012), hd=(0.04, 0.03, 0))), (1.2, gl)]))

    # hit reacts, stun, down
    hf = {"pel": (0, -0.08, -0.13), "prt": (-0.16, 0.10, 0.05), "tor": (-0.36, -0.26, 0.12), "hed": (0.24, 0.3, 0.12), "brow": -0.8, "lid": 0.55, "jaw": 0.9, "hd": (-0.24, 0.08, 0.05), "LP": (-0.46, 0.14, 0.84), "G": (0.50, 0.12, 0.84)}
    o.append(C("hit_f", 0.42, [(0.0, END), (0.06, hf, "out"), (0.16, dict(hf, hd=(0.12, -0.05, 0)), "out"), (0.42, END)]))
    hb = {"pel": (0, 0.08, -0.13), "prt": (0.46, -0.10, -0.05), "tor": (0.58, 0.2, -0.1), "hed": (-0.72, -0.2, 0.0), "brow": -0.8, "lid": 0.55, "jaw": 0.9, "hd": (0.26, -0.08, -0.04)}
    o.append(C("hit_b", 0.42, [(0.0, END), (0.06, hb, "out"), (0.16, dict(hb, hd=(-0.1, 0.05, 0)), "out"), (0.42, END)]))
    s1 = {"pel": (0.03, 0, -0.16), "prt": (0.26, 0.1, 0.14), "tor": (0.46, 0.0, 0.10), "hed": (-0.14, 0.3, 0.3), "LP": (-0.36, 0.12, 0.50), "G": (0.38, 0.20, 0.52), "BE": be(-10, -80, FLAT), "fing": 0.1, "lid": 0.5, "brow": -1, "jaw": 0.9, "hd": (0.06, 0.08, 0.08), "look": 0.3}
    s2 = dict(s1, pel=(-0.03, 0, -0.17), prt=(0.26, -0.1, -0.14), tor=(0.46, 0.0, -0.10), hed=(-0.14, -0.3, -0.3), hd=(0.06, -0.08, -0.08), look=-0.3)
    o.append(C("stun", 1.2, [(0.0, s1), (0.6, s2), (1.2, s1)]))
    fl = {"pel": (0, 0.1, -0.46), "prt": (0.95, 0.1, 0.1), "tor": (0.30, 0.2, 0.0), "hed": (-0.75, 0.3, 0.1), "LP": (-0.34, 0.52, 0.19), "G": (0.34, 0.30, 0.20), "BE": be(-20, -8, FLAT), "fing": 0.5, "FL": (-0.20, -0.14, 0.10), "FR": (0.22, -0.38, 0.10), "FLp": 0.8, "FRp": 0.9, "brow": -1, "lid": 0.6, "jaw": 0.6, "hd": (0.1, 0.05, 0.0)}
    o.append(C("downed", 2.4, [(0.0, fl), (1.2, dict(fl, LP=(-0.34, 0.58, 0.19), pel=(0, 0.12, -0.45), jaw=0.3)), (2.4, fl)]))
    o.append(C("revive", 1.6, [(0.0, fl), (0.5, dict(fl, tor=(0.5, 0.1, 0.1), hed=(-0.3, 0, 0), lid=0.2, brow=0.6)), (1.1, dict(END, pel=(0, 0.02, -0.26), prt=(0.45, 0, 0), jaw=0.5)), (1.6, END)]))
    # death: he reels back, the pile takes him over, he lies on it, one last grin
    d1 = {"pel": (0, -0.08, -0.10), "prt": (-0.22, 0, 0), "tor": (-0.34, 0, 0), "hed": (0.2, 0.0, 0.0), "lid": 0.2, "brow": -1, "jaw": 1.0, "LP": (-0.46, 0.05, 0.92), "G": (0.5, 0.05, 0.92), "BE": be(-90, 10, FLAT), "fing": 0.1, "hd": (-0.3, 0, 0)}
    d2 = {"pel": (0, -0.30, -0.42), "prt": (-1.22, 0, 0.05), "tor": (-0.02, 0.1, 0), "hed": (0.36, 0.5, 0.2), "lid": 1.0, "brow": -1, "jaw": 0.55, "LP": (-0.62, 0.06, 0.20), "G": (0.62, -0.02, 0.16), "BE": be(-60, -2, FLAT), "fing": 0.05, "FL": (-0.22, 0.26, 0.14), "FR": (0.20, 0.36, 0.20), "FLp": -0.6, "FRp": -0.8, "hd": (0.14, 0.06, 0.08)}
    o.append(C("death", 1.5, [(0.0, END), (0.18, d1, "out"), (0.62, d2, "in"), (0.74, dict(d2, pel=(0, -0.30, -0.39), hd=(-0.10, 0, 0))), (0.9, d2), (1.5, d2)]))
    # Fusion: hunched in, the pile flung up
    f0 = {"pel": (0, -0.03, -0.27), "prt": (0.52, 0, 0), "tor": (0.48, 0, 0), "hed": (-0.5, 0, 0), "LP": (-0.3, 0.32, 0.58), "G": (0.3, 0.32, 0.58), "BE": be(-5, -30, FLAT), "fing": 1, "brow": 1, "lid": 0.0, "jaw": 0.8}
    f1 = {"pel": (0, 0, -0.03), "prt": (-0.24, 0, 0), "tor": (-0.26, 0, 0), "hed": (-0.08, 0, 0), "LP": (-0.54, 0.0, 1.1), "G": (0.56, 0.0, 1.1), "BE": be(-90, 30, (0, 0, 1)), "jaw": 1.0, "lid": -0.3, "fing": 0.1, "hd": (-0.2, 0, 0)}
    o.append(C("fusion", 0.8, [(0.0, END), (0.18, f0), (0.3, dict(f0, pel=(0.006, -0.03, -0.28))), (0.45, f1, "out"), (0.58, dict(f1, pel=(0, 0, -0.01))), (0.8, END)]))
    # emote: rears up tall on one foot (sheet panel c), peers through the monocle with a hand on it, and cackles
    reF = {"pel": (0.05, 0.0, 0.075), "prt": (-0.05, 0.14, -0.13), "tor": (0.02, 0.16, 0.02), "hed": (-0.26, -0.10, -0.18), "FL": (-0.075, 0.03, A_Z), "FR": (0.21, 0.30, 0.46), "FRp": -0.6, "FRy": -0.3, "FLy": 0.2, "LP": (-0.20, 0.36, 1.40), "Lh": (2.6, 0.2, 0.4), "fing": 0.55, "G": (0.56, 0.0, 0.92), "BE": be(-110, -14, FLAT), "brow": -0.4, "lid": -0.3, "jaw": 0.8, "hd": (-0.06, 0, 0.02)}
    ch = [(0.0, END), (0.3, dict(END, pel=(0, 0, -0.17), prt=(0.3, 0, 0))), (0.6, reF, "out"), (0.75, dict(reF, pel=(0.05, 0, 0.055)))]
    for i in range(6):
        ch.append((0.95 + i * 0.25, dict(reF, pel=(0.05, 0.0, 0.075 - 0.012 * (i % 2)), jaw=0.3 + 0.7 * (i % 2), hed=(-0.26 - 0.06 * (i % 2), -0.10, -0.18), hd=(-0.06 + 0.1 * (i % 2), 0, 0.02))))
    ch += [(2.6, reF), (3.0, END)]
    o.append(C("emote", 3.0, ch))
    return o


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=a[0])
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    sv = GSolver(arm)
    bpy.context.scene.render.fps = FPS       # (the exporter times keys by the scene: at its default 24 fps every clip ran 25% long)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    wanted = a[2].split(",") if len(a) > 2 and a[2] else None
    done = []
    for c in clips():
        if wanted and c.name not in wanted:
            continue
        bake(arm, c, sv)
        done.append((c.name, round(c.dur, 3)))
    bpy.ops.object.mode_set(mode="OBJECT")
    print("clips", len(done), done)
    if not wanted:
        skin_relax.relax(arm)       # no edge may stretch past 1.3x its rest length in any clip (tools/stretch_check.gd)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(a[1])[0] + "_anim.blend")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", os.path.getsize(a[1]))
