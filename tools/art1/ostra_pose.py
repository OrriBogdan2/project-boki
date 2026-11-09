"""Pose solver for Motley's hand-keyed clips (ART-1): a key is a dict of channels, interpolated per frame, then turned into bone rotations
on the armature: hands are placed by target (two-bone IK in the torso's frame, so a lean carries them), fingers by curl and spread,
the face by jaw, brow, cheek and lid. Blender space: z up, facing +y, +x his right."""
import math
import numpy as np
from mathutils import Matrix, Quaternion, Vector

SPINE_FR = 1.0
FINGERS = ("1", "2", "3", "4")

# what a clip's keys start from: every channel, so any key can leave any channel out and hold its last value
NEUTRAL = {
    "spine": (0.0, 0.0, 0.0),   # pitch forward, yaw (+ turns to his left), roll (+ to his right), degrees
    "lift": (0.0, 0.0, 0.0),    # the hips' offset
    "head": (0.0, 0.0, 0.0),    # pitch forward, yaw, roll
    "hR": (0.18, 0.06, 0.84), "hL": (-0.18, 0.06, 0.84),      # the wrists, in the torso's frame
    "eR": (1.0, -0.6, -0.3), "eL": (-1.0, -0.6, -0.3),        # where the elbows point
    "fR": (0.0, 0.1, -1.0), "fL": (0.0, 0.1, -1.0),           # the way the fingers point
    "pR": (-1.0, 0.0, 0.0), "pL": (1.0, 0.0, 0.0),            # the way the palms face
    "cR": 0.25, "cL": 0.25,     # curl 0 straight .. 1 claw shut
    "sR": 0.3, "sL": 0.3,       # spread 0 .. 1
    "wR": 0.0, "wL": 0.0,       # a ripple through the fingers (radians)
    "jaw": 0.0,                 # degrees open
    "brow": 0.0,                # -1 scowl .. 1 raised
    "browd": 0.0,               # + cocks his right brow, - his left
    "cheek": 0.0,               # 0 .. 1 the grin pulled wider
    "lid": 0.0,                 # 0 wide .. 1 narrowed
    "skirt": (0.0, 0.0),        # (unused on this model: the tails are spring chains)
    "pld": (0.0, 0.0),          # the collar's points: lift R, lift L, degrees
    "box": (0.0, 0.0),          # the box tilts: toward his front (+), his right (+), degrees
    "hop": 0.0,                 # the box's rise off his hover, m (a bound)
    "lidb": 0.0,                # the box's lid: 0 as modelled (open), 1 shut, -0.4 flung wide
    "crank": 0.0,               # the crank's turn, degrees
    "smoke": 0.0,               # void smoke round the spring: 0 gone (every still), 1 wound on
    "body": 1.0,                # the upper body's size: 0.02 is down inside the box
    "fan": 1.0,                 # the fan of cards in his off hand
}


def eul(p, y, r):
    """pitch forward (about -x: the head goes to +y), yaw, roll (about +y, leaning to +x), in degrees, as a quaternion"""
    qp = Quaternion((-1, 0, 0), math.radians(p))
    qy = Quaternion((0, 0, 1), math.radians(y))
    qr = Quaternion((0, 1, 0), math.radians(r))
    return qy @ qp @ qr


def norm(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-6)


def basis_q(x, y):
    """the rotation whose local x, y are these (y wins)"""
    y = norm(y)
    x = norm(x - y * (x @ y))
    z = np.cross(x, y)
    m = Matrix(((x[0], y[0], z[0]), (x[1], y[1], z[1]), (x[2], y[2], z[2])))
    return m.to_quaternion()


class Rig:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}
        self.head = {b.name: np.array(b.head_local) for b in arm.data.bones}
        self.par = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        self.tail = {b.name: np.array(b.tail_local) for b in arm.data.bones}
        self.U = 0.21
        self.F = 0.235

    def about(self, bone, R):
        """B for a turn R (armature axes) about the bone's head, on its parent's pose"""
        q = self.rest[bone]
        return q.inverted() @ R @ q

    def arm_solve(self, side, target, pole, fdir, pdir):
        """-> upper, fore, hand B quaternions, solved in the torso's rest frame"""
        s = "R" if side > 0 else "L"
        S = self.head["upper_arm." + s]
        T = np.asarray(target, float)
        d = T - S
        L = np.linalg.norm(d)
        reach = self.U + self.F - 0.004
        if L > reach:
            T = S + d / L * reach
            d = T - S
            L = reach
        u = d / L
        cosa = (self.U ** 2 + L ** 2 - self.F ** 2) / (2 * self.U * L)
        cosa = min(max(cosa, -1), 1)
        sina = math.sqrt(1 - cosa * cosa)
        pl = np.asarray(pole, float)
        v = pl - u * (pl @ u)
        if np.linalg.norm(v) < 1e-4:
            v = np.array((side * 1.0, -0.5, 0.0)) - u * (np.array((side * 1.0, -0.5, 0.0)) @ u)
        v = norm(v)
        E = S + u * (self.U * cosa) + v * (self.U * sina)
        yu, yf = norm(E - S), norm(T - E)
        h = np.cross(yu, yf)
        if np.linalg.norm(h) < 1e-5:
            h = np.cross(yu, v)
        # (the rest arm's local x is -x: a bent elbow turns about it)
        Au = basis_q(-norm(h), yu)
        Af = basis_q(-norm(h), yf)
        ru, rf, rh = self.rest["upper_arm." + s], self.rest["forearm." + s], self.rest["hand." + s]
        Bu = ru.inverted() @ Au
        Bf = rf.inverted() @ ru @ Au.inverted() @ Af
        # the hand: fingers along fdir, palm toward pdir (local x is the palm of the right hand, minus x of the left)
        Ah = basis_q(np.asarray(pdir, float) * (1 if side > 0 else -1), np.asarray(fdir, float))
        Bh = rh.inverted() @ rf @ Af.inverted() @ Ah
        return Bu, Bf, Bh

    def fingers(self, side, curl, spread, wave, t):
        """-> {bone: B}"""
        s = "R" if side > 0 else "L"
        out = {}
        palm = np.array((-side, 0, 0.0))
        for i, nm in enumerate(FINGERS):
            a = "x_fing%s.%s" % (nm, s)
            b = "x_fing%sb.%s" % (nm, s)
            yd = norm(self.tail[a] - self.head[a])
            ax = norm(np.cross(yd, palm))      # curling turns the finger toward the palm
            c = curl + wave * math.sin(t * 7.0 + i * 1.3)
            sp = (i - 1.5) * spread * 0.16
            q1 = Quaternion(Vector(ax), c * 1.05) @ Quaternion(Vector(palm), sp * -side)
            q2 = Quaternion(Vector(ax), c * 1.2)
            out[a] = self.about(a, q1)
            out[b] = self.about(b, q2)
        a, b = "x_thumb." + s, "x_thumbb." + s
        yd = norm(self.tail[a] - self.head[a])
        ax = norm(np.cross(yd, palm))
        out[a] = self.about(a, Quaternion(Vector(ax), curl * 0.8))
        out[b] = self.about(b, Quaternion(Vector(ax), curl * 0.9))
        return out

    def solve(self, P, t):
        """a pose dict -> {bone: (B quaternion, translation or None, scale or None)}"""
        out = {}
        b = max(P["body"], 0.02)
        out["hips"] = (self.about("hips", eul(*P["spine"])), self.rest["hips"].inverted() @ Vector(P["lift"]), Vector((b, b, b)))
        out["head"] = (self.about("head", eul(*P["head"])), None, None)
        for side, s, h, e, f, p in ((1, "R", "hR", "eR", "fR", "pR"), (-1, "L", "hL", "eL", "fL", "pL")):
            Bu, Bf, Bh = self.arm_solve(side, P[h], P[e], P[f], P[p])
            out["upper_arm." + s] = (Bu, None, None)
            out["forearm." + s] = (Bf, None, None)
            out["hand." + s] = (Bh, None, None)
            for k, v in self.fingers(side, P["c" + s], P["s" + s], P["w" + s], t).items():
                out[k] = (v, None, None)
        out["x_jaw"] = (self.about("x_jaw", Quaternion((1, 0, 0), math.radians(-P["jaw"]))), None, None)
        for side, s in ((1, "R"), (-1, "L")):
            br = P["brow"] + side * P["browd"] - 0.4 * P["lid"]
            d = Vector((side * -0.004 * min(br, 0.0), 0, 0.012 * br))
            out["x_brow." + s] = (Quaternion(), self.rest["x_brow." + s].inverted() @ d, None)
            d = Vector((side * 0.012 * P["cheek"], 0, 0.012 * P["cheek"]))
            out["x_cheek." + s] = (Quaternion(), self.rest["x_cheek." + s].inverted() @ d, None)
        out["pauldron.R"] = (self.about("pauldron.R", Quaternion((0, 1, 0), math.radians(-P["pld"][0]))), None, None)
        out["pauldron.L"] = (self.about("pauldron.L", Quaternion((0, 1, 0), math.radians(P["pld"][1]))), None, None)
        bx = P["box"]
        out["x_box"] = (self.about("x_box", Quaternion((-1, 0, 0), math.radians(bx[0])) @ Quaternion((0, 1, 0), math.radians(bx[1]))),
                        self.rest["x_box"].inverted() @ Vector((0.0, 0.0, P["hop"])), None)
        out["x_boxlid"] = (self.about("x_boxlid", Quaternion((1, 0, 0), math.radians(-104.0 * P["lidb"]))), None, None)
        out["x_crank"] = (self.about("x_crank", Quaternion((1, 0, 0), math.radians(P["crank"]))), None, None)
        sm = max(P["smoke"], 0.001)
        out["x_smoke"] = (self.about("x_smoke", Quaternion((0, 0, 1), math.radians(P["smoke"] * 220.0))), None, Vector((sm, sm, sm)))
        v = min(max(P["body"], 0.02), 1.0)         # (the void goes down into the box with him)
        out["x_void"] = (Quaternion(), None, Vector((v, v, v)))
        fn = max(P["fan"], 0.02)
        out["x_fan"] = (Quaternion(), None, Vector((fn, fn, fn)))
        return out


def ease(x, kind):
    if kind == "linear":
        return x
    if kind == "in":        # slow out of the last key, snapping into this one
        return x * x * x
    if kind == "out":       # snaps out, settling into this key
        return 1 - (1 - x) ** 3
    if kind == "snap":
        return 1 - (1 - x) ** 5
    return x * x * (3 - 2 * x)


def lerp_val(a, b, k):
    if isinstance(a, tuple):
        return tuple(x + (y - x) * k for x, y in zip(a, b))
    return a + (b - a) * k


def channel_keys(keys, base):
    """the keys with every channel carried forward: [(t, pose, easing)]"""
    out = []
    cur = dict(NEUTRAL)
    cur.update(base)
    for key in keys:
        t, d = key[0], dict(key[1])
        e = key[2] if len(key) > 2 else "smooth"
        cur = dict(cur)
        cur.update(d)
        out.append((t, cur, e))
    return out


def sample(keys, t):
    if t <= keys[0][0]:
        return dict(keys[0][1])
    for i in range(1, len(keys)):
        if t <= keys[i][0]:
            t0, a, _ = keys[i - 1]
            t1, b, e = keys[i]
            k = ease((t - t0) / max(t1 - t0, 1e-5), e)
            return {c: lerp_val(a[c], b[c], k) for c in a}
    return dict(keys[-1][1])
