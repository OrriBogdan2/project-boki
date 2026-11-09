"""ART-1 animation kit: poses are written as targets (pelvis, torso, feet, the weapon's grip and blade line, a free hand,
brows, lids), sampled at 30 fps and solved to the contract's FK bones. Shared by every Hero: a Hero's clips file gives the
rest data (RIG) and the key poses. Space: armature, Z up, he faces +Y, +X his right."""
import math
import bpy
import numpy as np
from mathutils import Vector, Quaternion, Matrix

FPS = 30


def ang_dir(a, e=0.0):
    """A direction: a (degrees) round the body from forward, + to his left; e (degrees) up."""
    a, e = math.radians(a), math.radians(e)
    return (-math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))


def at(a, r, z):
    """A place round the body: a (degrees, as ang_dir), r metres out, z up."""
    d = ang_dir(a)
    return (d[0] * r, d[1] * r, z)


def eul(p):
    """(pitch forward, yaw left, roll to his right) radians -> quaternion."""
    return (Quaternion((0, 0, 1), p[1]) @ Quaternion((1, 0, 0), -p[0]) @ Quaternion((0, 1, 0), p[2]))


def ease(u, kind):
    if kind == "lin":
        return u
    if kind == "out":          # a snap that settles: strikes
        return 1 - (1 - u) ** 3
    if kind == "in":
        return u ** 2.4
    if kind == "hold":
        return 0.0
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    if a is None or b is None:
        return b if a is None else a
    if isinstance(a, (int, float)):
        return a + (b - a) * u
    return tuple(x + (y - x) * u for x, y in zip(a, b))


def frame_of(blade, edge):
    b = Vector(blade).normalized()
    e = Vector(edge)
    e = (e - b * e.dot(b)).normalized()
    n = b.cross(e)
    return Matrix((b, e, n)).transposed().to_quaternion()


VEC = ("pel", "G", "FL", "FR", "LP", "tip")
SCAL = ("prtP", "Lw", "brow", "lid", "fing", "skirt", "FLy", "FRy", "FLp", "FRp")


class Clip:
    """keys: list of (t, {params}, ease into this key). Each key inherits the last. loop: closes on the first key."""

    def __init__(self, name, dur, keys, base, loop=False):
        self.name, self.dur, self.loop = name, dur, loop
        cur = dict(base)
        self.keys = []
        for k in keys:
            t, p = k[0], k[1]
            e = k[2] if len(k) > 2 else "smooth"
            cur = dict(cur)
            cur.update(p)
            self.keys.append((t, cur, e))

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
                    if k == "BE":
                        qa, qb = frame_of(*va), frame_of(*vb)
                        out[k] = qa.slerp(qb, u)
                    else:
                        out[k] = lerp(va, vb, u)
                return out
        return dict(ks[-1][1])


class FnClip:
    """A clip written as a function of phase 0..1 (locomotion cycles)."""

    def __init__(self, name, dur, fn, loop=True):
        self.name, self.dur, self.fn, self.loop = name, dur, fn, loop

    def sample(self, t):
        return self.fn(t / self.dur)


class Solver:
    def __init__(self, arm, rig):
        """rig: {"grip_rest": point, "blade_rest", "edge_rest", "lhand": {...}, "pelvis": z}"""
        self.arm, self.rig = arm, rig
        self.b = {b.name: b for b in arm.data.bones}
        self.R0 = {n: b.matrix_local.to_quaternion() for n, b in self.b.items()}
        self.H0 = {n: b.head_local.copy() for n, b in self.b.items()}
        self.Y0 = {n: (b.matrix_local.to_3x3() @ Vector((0, 1, 0))).normalized() for n, b in self.b.items()}
        self.rest_frame = frame_of(rig["blade_rest"], rig["edge_rest"])

    def remap(self, P):
        """Keys written for one build, played on this Hero's rig: rig["dz"] lifts the hands and the grip with the shoulders, rig["leg_k"]
        stretches the feet's air height and pelvis drops with the leg."""
        dz, lk, a0, a1 = self.rig.get("dz", 0.0), self.rig.get("leg_k", 1.0), self.rig.get("ankle_keys", 0.0), self.rig.get("ankle", 0.0)
        if dz == 0.0 and lk == 1.0:
            return P
        P = dict(P)
        for k in ("G", "LP"):
            v = P[k]
            P[k] = (v[0], v[1], v[2] + dz)
        for k in ("FL", "FR"):
            v = P[k]
            P[k] = (v[0], v[1] * 1.15, a1 + (v[2] - a0) * lk)
        v = P["pel"]
        P["pel"] = (v[0], v[1], v[2] * lk)
        return P

    def arm_ik(self, side, S, W, pole, parent_q):
        up, fo = "upper_arm." + side, "forearm." + side
        hand = "hand." + side
        l1 = (self.H0[fo] - self.H0[up]).length
        l2 = (self.H0[hand] - self.H0[fo]).length
        E, W2 = two_bone(S, W, l1, l2, pole)
        q_up = (E - S).normalized().rotation_difference((E - S).normalized())  # identity
        yr = parent_q @ self.Y0[up]
        q_up = yr.rotation_difference((E - S).normalized()) @ parent_q
        yf = q_up @ self.Y0[fo]
        q_fo = yf.rotation_difference((W2 - E).normalized()) @ q_up
        return q_up, q_fo, W2

    def leg_ik(self, side, H, A, pole, parent_q):
        th, sh = "thigh." + side, "shin." + side
        ft = "foot." + side
        l1 = (self.H0[sh] - self.H0[th]).length
        l2 = (self.H0[ft] - self.H0[sh]).length
        K, A2 = two_bone(H, A, l1, l2, pole)
        yt = parent_q @ self.Y0[th]
        q_th = yt.rotation_difference((K - H).normalized()) @ parent_q
        ys = q_th @ self.Y0[sh]
        q_sh = ys.rotation_difference((A2 - K).normalized()) @ q_th
        return q_th, q_sh

    def solve(self, P):
        """-> {bone: world delta quaternion}, root location."""
        P = self.remap(P)
        H0 = self.H0
        pz = self.rig["pelvis"]
        piv = Vector((0, 0, pz))
        q_root = eul(P["prt"])
        pel = Vector(P["pel"])
        root_at = piv + pel - q_root @ piv                    # the root bone's head after the pelvis pose
        def D_root(x): return q_root @ (x - H0["root"]) + root_at
        hp = D_root(H0["hips"])
        q_hips = q_root @ eul(P["tor"])
        def D_hips(x): return q_hips @ (x - H0["hips"]) + hp
        q_head = q_hips @ eul(P["hed"])
        Q = {"root": q_root, "hips": q_hips, "head": q_head}
        # the sword hand
        fr = P["BE"] if isinstance(P["BE"], Quaternion) else frame_of(*P["BE"])
        q_hand = fr @ self.rest_frame.inverted()
        G = Vector(P["G"])
        W = G - q_hand @ (Vector(self.rig["grip_rest"]) - H0["hand.R"])
        S = D_hips(H0["upper_arm.R"])
        quR, qfR, W2 = self.arm_ik("R", S, W, Vector((0.65, -0.55, -0.45)), q_hips)
        Q["upper_arm.R"], Q["forearm.R"], Q["hand.R"] = quR, qfR, q_hand
        # the off hand: a free place, or on the hilt, by Lw
        bdir = (fr @ Vector((1, 0, 0))).normalized()
        n = (fr @ Vector((0, 0, 1))).normalized()
        hilt = G - bdir * self.rig["hilt_l"]
        q_on = self.lhand_on(bdir, hilt, S)
        free_W = Vector(P["LP"])
        lr = self.rig["lhand"]
        on_W = hilt - q_on @ (Vector(lr["palm"]) - H0["hand.L"])
        w = P.get("Lw", 0.0)
        Wl = free_W.lerp(on_W, w)
        q_free = q_hips.slerp(q_hips, 0.0)
        q_lh = q_free.slerp(q_on, w)
        Sl = D_hips(H0["upper_arm.L"])
        quL, qfL, _ = self.arm_ik("L", Sl, Wl, Vector((-0.65, -0.55, -0.45)), q_hips)
        Q["upper_arm.L"], Q["forearm.L"], Q["hand.L"] = quL, qfL, q_lh
        # legs
        for side, key in (("L", "FL"), ("R", "FR")):
            Hp = D_root(H0["thigh." + side])
            A = Vector(P[key])
            yaw = P.get(key + "y", 0.0)
            pole = Quaternion((0, 0, 1), yaw) @ Vector((0.18 * (1 if side == "R" else -1), 1, 0.2))
            qt, qs = self.leg_ik(side, Hp, A, pole, q_root)
            Q["thigh." + side], Q["shin." + side] = qt, qs
            Q["foot." + side] = Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), P.get(key + "p", 0.0)) \
                @ Quaternion((0, 1, 0), P.get(key + "r", 0.0))
        return Q, root_at

    def lhand_on(self, b, hilt, S):
        """The left hand closed round the hilt: its knuckle line along the blade, palm toward the hilt."""
        lr = self.rig["lhand"]
        k0, o0 = Vector(lr["k"]).normalized(), Vector(lr["o"]).normalized()
        a0 = k0.cross(o0)
        out = (hilt - S)
        o1 = (out - b * out.dot(b)).normalized()
        a1 = b.cross(o1)
        m0 = Matrix((k0, o0, a0)).transposed().to_quaternion()
        m1 = Matrix((b, o1, a1)).transposed().to_quaternion()
        return m1 @ m0.inverted()


def two_bone(a, c, l1, l2, pole):
    d = c - a
    dist = d.length
    mx = (l1 + l2) * 0.995
    if dist > mx:
        c = a + d.normalized() * mx
        d = c - a
        dist = mx
    dist = max(dist, abs(l1 - l2) + 0.01)
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - x * x, 0.0))
    u = d.normalized()
    p = pole - u * pole.dot(u)
    if p.length < 1e-4:
        p = Vector((0, 1, 0))
    p = p.normalized()
    return a + u * x + p * h, c


def bake(arm, clip, solver, extras):
    """One clip into an action: every contract bone keyed each frame. extras(params) -> {bone: (rot quat or None, loc[, scale])}:
    a scale (x_breath, the idle's breath) is the optional third item; a bone the rig lacks is skipped."""
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    n = max(2, int(round(clip.dur * FPS)) + 1)
    pbs = arm.pose.bones
    names = [b for b in ("root", "hips", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
                         "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R") if b in pbs]
    R0, Par = solver.R0, {}
    for b in names + list(extras({}).keys() if False else []):
        pass
    for f in range(n):
        t = clip.dur * f / (n - 1)
        P = clip.sample(t)
        Q, root_at = solver.solve(P)
        for b in names:
            par = solver.b[b].parent.name if solver.b[b].parent else None
            dq_p = Q[par] if par else Quaternion()
            q = R0[b].inverted() @ dq_p.inverted() @ Q[b] @ R0[b]
            pb = pbs[b]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q.normalized()
            pb.keyframe_insert("rotation_quaternion", frame=f)
        loc = R0["root"].inverted() @ (root_at - solver.H0["root"])
        pbs["root"].location = loc
        pbs["root"].keyframe_insert("location", frame=f)
        for b, v in extras(P).items():
            if b not in pbs:
                continue
            q, l = v[0], v[1]
            pb = pbs[b]
            pb.rotation_mode = "QUATERNION"
            if q is not None:
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
            if l is not None:
                pb.location = l
                pb.keyframe_insert("location", frame=f)
            if len(v) > 2 and v[2] is not None:
                pb.scale = v[2]
                pb.keyframe_insert("scale", frame=f)
    arm.animation_data.action = None
    return act
