"""Hand-keyed clips on the contract armature (ART-1), in Blender's Python. A key is a few readable numbers; the solver
turns each into bone rotations 30 times a second (two-bone IK for arms and legs, feet flat, the weapon's direction
held), so a swing is authored as where the weapon goes, not as a pile of euler curves.

Space: model, facing +Y, right +X, up +Z (see sculpt_kit). Pose keys, all optional; a key inherits what it omits:
  pos (x, y, z) root offset   rot (x, y, z) root turn (deg)     hips (x, y, z) torso turn (deg, about the waist)
  head (x, y, z) deg, on the torso        jaw, brow.., lid, fing_r, fing_l, thumb_r, thumb_l (0..1 curls)
  gr grip target, in the torso's frame    gd haft direction, ga the block's long axis (or set "wr": wrist euler)
  sh left hand target                     sn shield face normal, su shield up
  fr, fl ankle targets in model space     fra, fla foot pitch (deg)     er, el elbow pole direction (torso frame)
  eye "ease into this key": io (default), in (slow start), out (fast start, slow end), lin, snap"""
import math

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30


def qe(e):
    return Euler((math.radians(e[0]), math.radians(e[1]), math.radians(e[2])), "XYZ").to_quaternion()


def q_between(a, b):
    a, b = a.normalized(), b.normalized()
    return a.rotation_difference(b)


def q_basis(y, z):
    """The rotation taking +Y to y and +Z to (most of) z."""
    y = y.normalized()
    x = y.cross(z).normalized()
    z2 = x.cross(y).normalized()
    return Matrix((x, y, z2)).transposed().to_quaternion()


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
        self.sl = (self.P["x_foot.R"] - self.P["shin.R"]).length
        self.grip = self.P["x_weapon"] - self.P["hand.R"]
        self.sgrip = self.P["x_shield"] - self.P["hand.L"]

    def two_bone(self, a, target, l1, l2, pole):
        """Elbow or knee: (the middle joint, the clamped end)."""
        d = target - a
        L = min(d.length, (l1 + l2) * 0.995)
        dn = d.normalized()
        end = a + dn * L
        c = (l1 * l1 - l2 * l2 + L * L) / (2 * L)
        h = math.sqrt(max(l1 * l1 - c * c, 0.0))
        side = (pole - dn * pole.dot(dn))
        side = side.normalized() if side.length > 1e-4 else Vector((0, 1, 0))
        return a + dn * c + side * h, end

    def solve(self, k):
        """Global rotation deltas G (model frame) for every bone, from one evaluated pose k, -> {bone: quaternion D}, root pos."""
        G = {n: Quaternion() for n in self.b.keys()}
        down = Vector((0, 0, -1))
        rootp = Vector(k.get("pos", (0, 0, 0)))
        Gr = qe(k.get("rot", (0, 0, 0)))
        G["root"] = Gr
        G["hips"] = Gr @ qe(k.get("hips", (0, 0, 0)))
        ph = rootp + Gr @ self.P["hips"]
        H = G["hips"]
        tors = lambda p: ph + H @ (Vector(p) - self.P["hips"])
        tdir = lambda d: H @ Vector(d)
        G["head"] = H @ qe(k.get("head", (0, 0, 0)))
        G["skirt"] = H
        for s in ("L", "R"):
            G["pauldron." + s] = H
        # right arm
        S = tors(self.P["upper_arm.R"])
        gd, ga = tdir(k.get("gd", (0, 1, 0))), tdir(k.get("ga", (0, 0, 1)))
        Gh = q_basis(gd, ga) if "wr" not in k else H @ qe(k["wr"])
        target = tors(k.get("gr", (0.37, 0.0, 0.5))) - Gh @ self.grip
        pole = tdir(k.get("er", (0.6, -0.5, -0.5)))
        E, end = self.two_bone(S, target, self.ul, self.fl, pole)
        G["upper_arm.R"] = q_between(down, E - S)
        G["forearm.R"] = q_between(down, end - E)
        G["hand.R"] = Gh
        # left arm
        S = tors(self.P["upper_arm.L"])
        sn, su = tdir(k.get("sn", (-1, 0, 0))), tdir(k.get("su", (0, 0, 1)))
        # (the shield's bone: y along up, its rest face -X)
        Gs = q_basis(sn.cross(su), su)      # (at rest the face looks -X, up +Z: its +Y is square to both)
        target = tors(k.get("sh", (-0.385, 0.0, 0.6)))
        pole = tdir(k.get("el", (-0.6, -0.5, -0.5)))
        E, end = self.two_bone(S, target, self.ul, self.fl, pole)
        G["upper_arm.L"] = q_between(down, E - S)
        G["forearm.L"] = q_between(down, end - E)
        G["hand.L"] = Gs
        # legs
        for s, kf, ka in (("R", "fr", "fra"), ("L", "fl", "fla")):
            hip = rootp + Gr @ self.P["thigh." + s]
            rest_a = self.P["x_foot." + s]
            ank = Vector(k.get(kf, rest_a))
            pole = Gr @ Vector((0.12 * (1 if s == "R" else -1), 1.0, 0.0))
            E, end = self.two_bone(hip, ank, self.tl, self.sl, pole)
            G["thigh." + s] = q_between(down, E - hip)
            G["shin." + s] = q_between(down, end - E)
            G["x_foot." + s] = qe((k.get(ka, 0.0), 0, 0))
        for s in ("R", "L"):
            sign = 1.0 if s == "R" else -1.0
            cu = k.get("fing_" + s.lower(), 0.0)
            th = k.get("thumb_" + s.lower(), cu)
            axis = (0, 1, 0)
            Gh2 = G["hand." + s]
            # (the fingers curl in, palm side: about the hand's own long side axis)
            cq = Quaternion(Vector(axis), sign * math.radians(72) * cu)
            G["x_fing." + s] = Gh2 @ cq
            G["x_fing2." + s] = G["x_fing." + s] @ Quaternion(Vector(axis), sign * math.radians(70) * cu)
            G["x_thumb." + s] = Gh2 @ Quaternion(Vector((0, 0, 1)), sign * math.radians(45) * th)
        G["x_weapon"] = G["hand.R"] @ qe(k.get("wtw", (0, 0, 0)))
        G["x_shield"] = G["hand.L"]
        jw = k.get("jaw", 0.0)
        G["x_jaw"] = G["head"] @ qe((-jw * 26.0, 0, 0))
        for s in ("R", "L"):
            G["x_lid." + s] = G["head"] @ qe((k.get("lid", 0.0) * 34.0, 0, 0))
            G["x_brow." + s] = G["head"]
        out = {}
        for n in self.b.keys():
            if n.startswith("spring_") or n == "x_fish":
                continue
            p = self.parent[n]
            D = (G[p].inverted() @ G[n]) if p else G[n]
            out[n] = self.R[n].inverted() @ D @ self.R[n]
        return out, rootp, Gr

    def brow_pos(self, k):
        return k.get("brow", 0.0)


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
                if isinstance(a[1], (int, float)):
                    v = a[1] + (b[1] - a[1]) * u
                else:
                    v = tuple(x + (y - x) * u for x, y in zip(a[1], b[1]))
                break
        out[c] = v
    return out


class Clips:
    def __init__(self, arm):
        self.rig = Rig(arm)
        self.arm = arm
        self.lengths = {}
        self.remap = None      # a key's pose -> this rig's (keys written for another build)

    def bake(self, name, dur, keys, base=None, loop=False, over=None):
        """keys: [(t, pose)]; base: a pose merged under every key; over(t, pose): edits the pose per frame (breath, sway)."""
        rig = self.rig
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        n = int(round(dur * FPS)) + 1
        names = [b for b in rig.b.keys() if not b.startswith("spring_") and b != "x_fish"]
        data = {b: np.empty((n, 4), np.float32) for b in names}
        loc = {"root": np.empty((n, 3), np.float32)}
        kk = [(t, self.remap(p) if self.remap else p) for t, p in keys]
        for f in range(n):
            t = min(f / FPS, dur)
            pose = evaluate(kk, t)
            if over:
                over(t, pose)
            D, rp, _ = rig.solve(pose)
            for b in names:
                q = D[b]
                data[b][f] = (q.w, q.x, q.y, q.z)
            # (root offset in the bone's rest frame)
            loc["root"][f] = tuple(rig.R["root"].inverted() @ rp)
        # hemisphere-continuous quaternions
        for b in names:
            q = data[b]
            for f in range(1, n):
                if np.dot(q[f], q[f - 1]) < 0:
                    q[f] = -q[f]
        frames = np.arange(n, dtype=np.float32)
        slot_bag = None
        for b in names:
            for i in range(4):
                fc = act.fcurves.new('pose.bones["%s"].rotation_quaternion' % b, index=i, action_group=b)
                fc.keyframe_points.add(n)
                co = np.empty(n * 2, np.float32)
                co[0::2] = frames
                co[1::2] = data[b][:, i]
                fc.keyframe_points.foreach_set("co", co)
                fc.keyframe_points.foreach_set("interpolation", np.ones(n, np.int32))     # LINEAR
                fc.update()
        for i in range(3):
            fc = act.fcurves.new('pose.bones["root"].location', index=i, action_group="root")
            fc.keyframe_points.add(n)
            co = np.empty(n * 2, np.float32)
            co[0::2] = frames
            co[1::2] = loc["root"][:, i]
            fc.keyframe_points.foreach_set("co", co)
            fc.keyframe_points.foreach_set("interpolation", np.ones(n, np.int32))
            fc.update()
        self.lengths[name] = (n - 1) / FPS
        return act


def add_breath(arm, head, weight):
    """The rib cage's leaf bone x_breath under hips (IDLE_AUDIT "No chest"): a bone at head pointing +Y (its axes the
    model's, so BREATH_AXES read in model space), and the hips-skinned vertices moved onto it by weight(model point)
    (0..1, 1 where the chest swells whole). Run before Clips(arm); a rig that has one is left alone."""
    if "x_breath" in arm.data.bones:
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones.new("x_breath")
    eb.head = Vector(head)
    eb.tail = Vector(head) + Vector((0, 0.15, 0))
    eb.roll = 0.0
    eb.parent = arm.data.edit_bones["hips"]
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.data.objects:
        if o.type != "MESH" or "hips" not in o.vertex_groups:
            continue
        hips = o.vertex_groups["hips"]
        vg = o.vertex_groups.new(name="x_breath")
        for v in o.data.vertices:
            g = next((g for g in v.groups if g.group == hips.index), None)
            w = weight(o.matrix_world @ v.co) * g.weight if g else 0.0
            if w > 0.001:
                hips.add([v.index], g.weight - w, "REPLACE")
                vg.add([v.index], w, "REPLACE")
