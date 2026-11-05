"""Hand-keyed clips for a Hunter whose weapon is both fists (ART-1, Tarek), in Blender's Python: the same key language
as Breaker's anim_kit.py (a key is a few readable numbers, a solver bakes bone rotations 30 times a second), with two
free hands. Model space: facing +Y, right +X, up +Z. Pose channels, all optional, a key inherits what it omits:
  pos (x, y, z) root offset    rot (x, y, z) root turn (deg)    hips (x, y, z) torso turn (deg): -x bows forward, +z turns left
  head (x, y, z) deg on the torso
  hr, hl wrist targets in the torso's rest frame      wr, wl wrist euler (deg) on the forearm      er, el elbow poles
  fing_r, fing_l fist 0 (open) .. 1 (clenched)         thumb_r, thumb_l (default: the fist's)
  fr, fl ankle targets in model space                  fra, fla foot pitch (deg, + toes up)         kr, kl knee poles
  jaw 0..1   lip -1 (grit) .. 0 (his grin) .. 1 (a bigger grin)     e ease into this key: io, in, out, lin, snap
"""
import math

import bpy
import numpy as np
from mathutils import Euler, Quaternion, Vector

FPS = 30


def qe(e):
    return Euler((math.radians(e[0]), math.radians(e[1]), math.radians(e[2])), "XYZ").to_quaternion()


def q_between(a, b):
    return a.normalized().rotation_difference(b.normalized())


def ease(u, kind):
    if kind == "lin":
        return u
    if kind == "in":
        return u * u * u
    if kind == "out":
        return 1.0 - (1.0 - u) ** 3
    if kind == "snap":
        return 1.0 - (1.0 - u) ** 5
    return u * u * (3.0 - 2.0 * u)


class Rig:
    def __init__(self, arm):
        self.arm = arm
        self.b = arm.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in self.b}
        self.R = {n: m.to_quaternion() for n, m in self.rest.items()}
        self.P = {n: m.to_translation() for n, m in self.rest.items()}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in self.b}
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.ul = (self.P["forearm.R"] - self.P["upper_arm.R"]).length
        self.fl = (self.P["hand.R"] - self.P["forearm.R"]).length
        self.tl = (self.P["shin.R"] - self.P["thigh.R"]).length
        self.sl = (self.P["foot.R"] - self.P["shin.R"]).length

    def two_bone(self, a, target, l1, l2, pole):
        d = target - a
        L = max(min(d.length, (l1 + l2) * 0.998), abs(l1 - l2) + 0.02)
        dn = d.normalized()
        end = a + dn * L
        c = (l1 * l1 - l2 * l2 + L * L) / (2 * L)
        h = math.sqrt(max(l1 * l1 - c * c, 0.0))
        side = pole - dn * pole.dot(dn)
        side = side.normalized() if side.length > 1e-4 else Vector((0, 1, 0))
        return a + dn * c + side * h, end

    def solve(self, k):
        G = {n: Quaternion() for n in self.b.keys()}
        down = Vector((0, 0, -1))
        rootp = Vector(k.get("pos", (0, 0, 0)))
        Gr = qe(k.get("rot", (0, 0, 0)))
        G["root"] = Gr
        H = Gr @ qe(k.get("hips", (0, 0, 0)))
        G["hips"] = H
        ph = rootp + Gr @ self.P["hips"]
        tors = lambda p: ph + H @ (Vector(p) - self.P["hips"])
        G["head"] = H @ qe(k.get("head", (0, 0, 0)))
        G["skirt"] = H
        for s, sg in (("R", 1.0), ("L", -1.0)):
            lo = s.lower()
            G["pauldron." + s] = H
            S = tors(self.P["upper_arm." + s])
            rest_h = self.P["hand." + s]
            target = tors(k.get("h" + lo, tuple(rest_h)))
            pole = H @ Vector(k.get("e" + lo, (0.7 * sg, -0.7, -0.2)))
            E, end = self.two_bone(S, target, self.ul, self.fl, pole)
            G["upper_arm." + s] = q_between(down, E - S)
            G["forearm." + s] = q_between(down, end - E)
            # a twist of the whole arm comes through the wrist key: fist axes stay on the forearm
            G["hand." + s] = G["forearm." + s] @ qe(k.get("w" + lo, (0, 0, 0)))
            cu = k.get("fing_" + lo, 0.0)
            th = k.get("thumb_" + lo, cu)
            # the fingers curl in toward the palm, which faces his body at rest (about the hand's front-back axis)
            ax = Vector((0, 1, 0))
            G["fingers." + s] = G["hand." + s] @ Quaternion(ax, -sg * math.radians(78) * cu)
            G["fingers2." + s] = G["fingers." + s] @ Quaternion(ax, -sg * math.radians(84) * cu)
            # (the thumb folds across the curled fingers)
            G["thumb." + s] = G["hand." + s] @ Quaternion(Vector((0, 0, 1)), sg * math.radians(66) * th)
            G["thumb2." + s] = G["thumb." + s] @ Quaternion(Vector((0, 0, 1)), sg * math.radians(44) * th)
            hip = rootp + Gr @ self.P["thigh." + s]
            ank = Vector(k.get("f" + lo, tuple(self.P["foot." + s])))
            kp = Vector(k.get("k" + lo, (0.1 * sg, 1.0, 0.0)))
            E, end = self.two_bone(hip, ank, self.tl, self.sl, Gr @ kp)
            G["thigh." + s] = q_between(down, E - hip)
            G["shin." + s] = q_between(down, end - E)
            G["foot." + s] = qe((k.get("f" + lo + "a", 0.0), 0, k.get("f" + lo + "t", 0.0)))
            G["lip." + s] = G["head"]
        G["jaw"] = G["head"] @ qe((-k.get("jaw", 0.0) * 22.0, 0, 0))
        out = {}
        for n in self.b.keys():
            if n.startswith("spring_"):
                continue
            p = self.parent[n]
            D = (G[p].inverted() @ G[n]) if p else G[n]
            out[n] = self.R[n].inverted() @ D @ self.R[n]
        return out, rootp


def evaluate(keys, t):
    """The pose at t: each channel keyed where its keys are, eased; omitted channels hold their last value."""
    chans = {}
    for tk, pose in keys:
        for c, v in pose.items():
            if c != "e":
                chans.setdefault(c, []).append((tk, v, pose.get("e", "io")))
    out = {}
    for c, ks in chans.items():
        if t <= ks[0][0]:
            out[c] = ks[0][1]
            continue
        v = ks[-1][1]
        for i in range(len(ks) - 1):
            a, b = ks[i], ks[i + 1]
            if a[0] <= t <= b[0]:
                u = ease((t - a[0]) / max(b[0] - a[0], 1e-4), b[2])
                v = a[1] + (b[1] - a[1]) * u if isinstance(a[1], (int, float)) else tuple(x + (y - x) * u for x, y in zip(a[1], b[1]))
                break
        out[c] = v
    return out


class Clips:
    def __init__(self, arm):
        self.rig = Rig(arm)
        self.arm = arm
        self.lengths = {}

    def bake(self, name, dur, keys, loop=False, over=None):
        """keys: [(t, pose)]; over(t, pose) edits the pose per frame (breath, sway, a gait). loop: the last frame is the
        first one again, so a loop never pops."""
        rig = self.rig
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        n = int(round(dur * FPS)) + 1
        names = [b for b in rig.b.keys() if not b.startswith("spring_")]
        rot = {b: np.empty((n, 4), np.float32) for b in names}
        lips = ("lip.L", "lip.R")
        loc = {b: np.zeros((n, 3), np.float32) for b in ("root",) + lips}
        for f in range(n):
            t = 0.0 if loop and f == n - 1 else min(f / FPS, dur)
            pose = evaluate(keys, t)
            if over:
                over(t, pose)
            D, rp = rig.solve(pose)
            for b in names:
                q = D[b]
                rot[b][f] = (q.w, q.x, q.y, q.z)
            loc["root"][f] = tuple(rig.R["root"].inverted() @ rp)
            # the mouth's corners slide on the face: up and out for the grin, down and in for a grit
            lp = pose.get("lip", 0.0)
            jw = pose.get("jaw", 0.0)
            for b, sg in ((lips[0], -1.0), (lips[1], 1.0)):
                v = Vector((sg * (0.008 * lp + 0.006 * jw), 0.0, 0.01 * lp - 0.016 * jw))
                loc[b][f] = tuple(rig.R[b].inverted() @ v)
        for b in names:
            q = rot[b]
            for f in range(1, n):
                if np.dot(q[f], q[f - 1]) < 0:
                    q[f] = -q[f]
        frames = np.arange(n, dtype=np.float32)
        slot = act

        def curves(path, arr, group):
            for i in range(arr.shape[1]):
                fc = slot.fcurves.new(path, index=i, action_group=group)
                fc.keyframe_points.add(n)
                co = np.empty(n * 2, np.float32)
                co[0::2] = frames
                co[1::2] = arr[:, i]
                fc.keyframe_points.foreach_set("co", co)
                fc.keyframe_points.foreach_set("interpolation", np.ones(n, np.int32))
                fc.update()

        for b in names:
            curves('pose.bones["%s"].rotation_quaternion' % b, rot[b], b)
        for b, a in loc.items():
            curves('pose.bones["%s"].location' % b, a, b)
        self.lengths[name] = (n - 1) / FPS
        return act
