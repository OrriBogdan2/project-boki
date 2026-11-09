"""Mantle and ledge clips for a Warden's .glb, with no Blender: key poses are written as where the hands and feet go
(metres, model space: +X his right, +Y up, forward is -Z, origin at his feet) plus a body lean, solved with two-bone IK
onto the rig's own bones and appended to the .glb (a clip of the same name is replaced, everything else stays byte for
byte). Poses sit on the hero's idle, so his own twist and proportions carry through. The game drives "mantle" by how far
up the face the body is (0..1, WardenClips), so the clip is a pose per progress, not a speed.
Run: python3 tools/art1/climb_clips.py <hero> [--sheet out.png] [--out other.glb]   (hero: ryzz breaker sable ostra)"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_add_clips import read, write  # noqa: E402
import struct  # noqa: E402

FPS = 30
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "wardens")


# ---------------------------------------------------------------- vectors and quaternions (x, y, z, w)
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def length(a): return math.sqrt(dot(a, a))
def unit(a):
    n = length(a)
    return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-9 else (0.0, 1.0, 0.0)
def lerp(a, b, u): return a + (b - a) * u
def lerpv(a, b, u): return tuple(lerp(x, y, u) for x, y in zip(a, b))


def qconj(q): return (-q[0], -q[1], -q[2], q[3])


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qinv(q): return (-q[0], -q[1], -q[2], q[3])
def qaxis(axis, deg):
    h = math.radians(deg) / 2.0
    s = math.sin(h)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(h))


def qrot(q, v):
    t = mul(cross(q[:3], v), 2.0)
    return add(add(v, mul(t, q[3])), cross(q[:3], t))


def qswing(a, b):
    """The shortest rotation taking direction a to direction b."""
    a, b = unit(a), unit(b)
    d = dot(a, b)
    if d < -0.99999:
        ax = unit(cross(a, (1, 0, 0)) if abs(a[0]) < 0.9 else cross(a, (0, 0, 1)))
        return (ax[0], ax[1], ax[2], 0.0)
    c = cross(a, b)
    n = math.sqrt(2.0 * (1.0 + d))
    return (c[0] / n, c[1] / n, c[2] / n, n / 2.0)


def qnorm(q):
    n = math.sqrt(sum(x * x for x in q))
    return tuple(x / n for x in q)


def euler(pitch, roll=0.0, yaw=0.0):
    """Degrees: pitch forward (+, leans him toward -Z), roll to his right (+), yaw to his left (+)."""
    return qmul(qaxis((0, 1, 0), yaw), qmul(qaxis((1, 0, 0), -pitch), qaxis((0, 0, 1), -roll)))


# ---------------------------------------------------------------- the rig
class Rig:
    def __init__(self, path):
        self.j, self.b = read(path)
        self.nodes = self.j["nodes"]
        self.idx = {n.get("name"): i for i, n in enumerate(self.nodes)}
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        idle = next(a for a in self.j["animations"] if a["name"] == "idle")
        self.rot = {}
        self.pos = {}
        for i, n in enumerate(self.nodes):
            self.rot[i] = tuple(n.get("rotation", (0, 0, 0, 1)))
            self.pos[i] = tuple(n.get("translation", (0, 0, 0)))
        self.animated = set()
        for ch in idle["channels"]:
            node = ch["target"]["node"]
            self.animated.add(node)
            smp = idle["samplers"][ch["sampler"]]
            v = self._acc(smp["output"])[0]
            if ch["target"]["path"] == "rotation":
                self.rot[node] = tuple(v)
            elif ch["target"]["path"] == "translation":
                self.pos[node] = tuple(v)
        self.order = self._topo()
        self.base = self.fk(self.rot, self.pos)

    def _acc(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return [struct.unpack_from("<%df" % n, self.b, off + k * 4 * n) for k in range(a["count"])]

    def _topo(self):
        out, seen = [], set()

        def visit(i):
            if i in seen:
                return
            if i in self.parent:
                visit(self.parent[i])
            seen.add(i)
            out.append(i)
        for i in range(len(self.nodes)):
            visit(i)
        return out

    def fk(self, rot, pos):
        wr, wp = {}, {}
        for i in self.order:
            p = self.parent.get(i)
            if p is None:
                wr[i], wp[i] = rot[i], pos[i]
            else:
                wr[i] = qmul(wr[p], rot[i])
                wp[i] = add(wp[p], qrot(wr[p], pos[i]))
        return wr, wp

    def n(self, name): return self.idx[name]

    def seg(self, name):
        """A bone's length: where its first child sits along it."""
        c = self.nodes[self.idx[name]].get("children", [])
        return length(self.pos[c[0]])


def ik2(s, t, l1, l2, pole):
    """Elbow (knee) for a two-bone limb from s to t, bent toward pole; the target is pulled in when out of reach."""
    d = sub(t, s)
    dist = min(max(length(d), abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    dn = unit(d)
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    pp = sub(pole, mul(dn, dot(pole, dn)))
    perp = unit(pp) if length(pp) > 1e-6 else (0, 0, -1)
    return add(add(s, mul(dn, a)), mul(perp, h)), add(s, mul(dn, dist))


LIMBS = {"arm": ("upper_arm", "forearm", "hand"), "leg": ("thigh", "shin", "foot")}


def solve(rig, pose, legs=True, foot_names=None):
    """One frame: local rotations (and the root's offset) for a pose dict."""
    rot, pos = dict(rig.rot), dict(rig.pos)
    root = rig.n("root")
    dy, dz, dx = pose.get("lift", 0.0), pose.get("fwd", 0.0), pose.get("side", 0.0)
    pos[root] = (dx, dy, -dz)
    rot[root] = euler(*pose.get("body", (0, 0, 0)))
    hips = rig.n("hips")
    rot[hips] = qmul(euler(*pose.get("hips", (0, 0, 0))), rig.rot[hips])
    head = rig.n("head")
    rot[head] = qmul(euler(*pose.get("head", (0, 0, 0))), rig.rot[head])
    wr, wp = rig.fk(rot, pos)
    if "shoulder" in pose:      # (height, forward) the shoulders sit at: the body pivots over the hands, not the feet
        mid = mul(add(wp[rig.n("upper_arm.L")], wp[rig.n("upper_arm.R")]), 0.5)
        pos[root] = add(pos[root], (0.0, pose["shoulder"][0] - mid[1], -pose["shoulder"][1] - mid[2]))
        wr, wp = rig.fk(rot, pos)
    for side in "LR":
        for limb in ("arm", "leg") if legs else ("arm",):
            up, lo, end = (n + "." + side for n in LIMBS[limb][:3])
            if end not in rig.idx and limb == "leg":
                end = (foot_names or {}).get(end, end)
            key = ("hand_" if limb == "arm" else "foot_") + side
            if key not in pose:
                continue
            iu, il, ie = rig.n(up), rig.n(lo), rig.n(end)
            s, t = wp[iu], pose[key]
            knee, tip = ik2(s, t, length(rig.pos[il]), length(rig.pos[ie]), pose.get("pole_" + key, (0, 0, -1)))
            for bone, tail_from, tail_to in ((iu, s, knee), (il, knee, tip)):
                p = rig.parent[bone]
                cur = qrot(qmul(wr[p], rot[bone]), (0, 1, 0))
                want = qmul(qswing(cur, sub(tail_to, tail_from)), qmul(wr[p], rot[bone]))
                rot[bone] = qnorm(qmul(qinv(wr[p]), want))
                wr, wp = rig.fk(rot, pos)
            if limb == "leg":
                pitch = pose.get("foot_pitch_" + side, 0.0)
                p = rig.parent[ie]
                flat = qmul(euler(pitch), rig.base[0][ie])
                rot[ie] = qnorm(qmul(qinv(wr[p]), flat))
                wr, wp = rig.fk(rot, pos)
    return rot, pos, wr, wp


# ---------------------------------------------------------------- keys -> frames
def ease(u, kind):
    if kind == "lin":
        return u
    if kind == "out":
        return 1 - (1 - u) ** 2
    if kind == "in":
        return u * u
    return u * u * (3 - 2 * u)


def blend(a, b, u):
    out = {}
    for k in a:
        if k not in b:
            out[k] = a[k]
        elif isinstance(a[k], float) or isinstance(a[k], int):
            out[k] = lerp(a[k], b[k], u)
        else:
            out[k] = lerpv(a[k], b[k], u)
    return out


def sample(keys, t):
    """keys: [(time, pose, ease-into-next)]; the pose dicts hold every channel the clip uses in every key."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, p0, e), (t1, p1, _) in zip(keys, keys[1:]):
        if t <= t1:
            return blend(p0, p1, ease((t - t0) / (t1 - t0), e))
    return keys[-1][1]


def fold_root(rig, frame):
    """A Hero whose root stays on the rig (warden_anim "rig_root": Motley's hover drives it, its keys are dropped)
    carries the lift and lean on the hips instead (his "offset_bones" keep the hips' translation): same pose."""
    rot, pos = dict(frame[0]), dict(frame[1])
    r, h = rig.n("root"), rig.n("hips")
    rr, rp = qmul(rot[r], qconj(rig.rot[r])), sub(pos[r], rig.pos[r])
    pos[h], rot[h] = add(rp, qrot(rr, pos[h])), qmul(rr, rot[h])
    rot[r], pos[r] = rig.rot[r], rig.pos[r]
    return rot, pos


def build(rig, name, keys, legs, foot_names):
    """The animation dict (channels and samplers over new accessors) for the keys."""
    dur = keys[-1][0]
    n = int(round(dur * FPS)) + 1
    times = [min(i / FPS, dur) for i in range(n)]
    frames = [solve(rig, sample(keys, t), legs, foot_names) for t in times]
    if "root" not in [rig.nodes[i].get("name") for i in rig.animated]:
        frames = [fold_root(rig, f) for f in frames]
    j, b = rig.j, rig.b
    anim = {"name": name, "channels": [], "samplers": []}

    def accessor(values, kind):
        b.extend(b"\0" * (-len(b) % 4))
        comp = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[kind]
        flat = [x for v in values for x in (v if comp > 1 else (v,))]
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": 4 * len(flat)})
        b.extend(struct.pack("<%df" % len(flat), *flat))
        acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(values), "type": kind}
        if kind == "SCALAR":
            acc["min"], acc["max"] = [min(values)], [max(values)]
        j["accessors"].append(acc)
        return len(j["accessors"]) - 1

    t_in = accessor(times, "SCALAR")
    t_const = accessor([0.0, dur], "SCALAR")
    for node in sorted(rig.animated):
        for path, kind, series in (("translation", "VEC3", [f[1][node] for f in frames]), ("rotation", "VEC4", [f[0][node] for f in frames]),
                                   ("scale", "VEC3", None)):
            if path == "scale":
                v = tuple(rig.nodes[node].get("scale", (1, 1, 1)))
                anim["samplers"].append({"input": t_const, "output": accessor([v, v], kind), "interpolation": "LINEAR"})
            elif all(max(abs(x - y) for x, y in zip(series[0], s)) < 1e-6 for s in series):
                anim["samplers"].append({"input": t_const, "output": accessor([series[0], series[0]], kind), "interpolation": "LINEAR"})
            else:
                if path == "rotation":
                    for i in range(1, len(series)):
                        if dot(series[i], series[i - 1]) < 0:
                            series[i] = tuple(-x for x in series[i])
                anim["samplers"].append({"input": t_in, "output": accessor(series, kind), "interpolation": "LINEAR"})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}})
    j["animations"] = [a for a in j["animations"] if a["name"] != name] + [anim]
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
    return frames, times


# ---------------------------------------------------------------- stick figures (a check you can look at)
def sheet(rig, frames, times, path, picks=6):
    from PIL import Image, ImageDraw
    pairs = [("hips", "head"), ("upper_arm.L", "forearm.L"), ("forearm.L", "hand.L"), ("upper_arm.R", "forearm.R"),
             ("forearm.R", "hand.R"), ("thigh.L", "shin.L"), ("shin.L", "foot.L"), ("thigh.R", "shin.R"), ("shin.R", "foot.R")]
    sc, w, h = 150, 260, 330
    img = Image.new("RGB", (w * picks, h), "white")
    d = ImageDraw.Draw(img)
    for k in range(picks):
        f = frames[round(k * (len(frames) - 1) / (picks - 1))]
        ox = w * k + w // 2
        d.line([(ox - 100, h - 20), (ox + 100, h - 20)], fill=(150, 150, 150))
        d.text((ox - 40, 4), "t=%.2f" % times[round(k * (len(frames) - 1) / (picks - 1))], fill="black")
        for a, b2 in pairs:
            if a not in rig.idx or b2 not in rig.idx:
                continue
            pa, pb = f[3][rig.idx[a]], f[3][rig.idx[b2]]
            col = "red" if ".L" in a else ("blue" if ".R" in a else "black")
            d.line([(ox - pa[2] * sc, h - 20 - pa[1] * sc), (ox - pb[2] * sc, h - 20 - pb[1] * sc)], fill=col, width=3)
    img.save(path)


def main():
    import climb_data
    hero = sys.argv[1]
    spec = climb_data.HEROES[hero]
    path = os.path.join(ROOT, hero, hero + ".glb")
    rig = Rig(path)
    for name, keys in spec["clips"](rig).items():
        frames, times = build(rig, name, keys, spec.get("legs", True), spec.get("foot_names"))
        if "--sheet" in sys.argv:
            sheet(rig, frames, times, sys.argv[sys.argv.index("--sheet") + 1].replace(".png", "_%s.png" % name))
    write(sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else path, rig.j, rig.b)
    print(hero, "mantle + ledge written")


if __name__ == "__main__":
    main()
