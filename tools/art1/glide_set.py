"""The glide set for every Hero's .glb (docs/art/anim_audit/GLIDE_SET.md), with no Blender: each new clip is made from
that Hero's own "fall" and "glide" clips, so the poses stay its own. A clip of the same name is replaced
(its old data stays in the buffer: run it on a fresh export, or once).
  glide_open    0.24 s  the double press: fall -> both arms throw up to the lines -> the canopy bites (knees tuck,
                        head drops) -> settles on the hold. The source opens "instantly": the catch lands by 0.13 s.
  glide_close   0.18 s  the let-go: the hands leave the lines and the body falls back into the fall pose.
  glide_lean_l  1 loop  the hold leaning into a left (right) turn: torso rolled in, head looking into it, legs swung
  glide_lean_r          out, the inside hand pulled down on its line. WardenGlide blends them by the steer.
  glide_burn    0.6 s   the overheat struggle: the hold sped up, arms yanking the lines in turn, legs kicking, head up
                        at the burning canopy (it still lifts you out of the abyss at half strength).
The model faces -Z, +X is its right, +Y up. Offsets are world-axis turns applied on the clip's own animated pose.
Run: python3 tools/art1/glide_set.py [art ...]   (default: every content/rules/warden_anim/<art>.json)"""
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from glb_add_clips import read, write  # noqa: E402

FPS = 60.0
OPEN_LEN = 0.24
OPEN_REACH = 0.07      # s: the hands are up on the lines
OPEN_CATCH = 0.13      # s: the canopy bites (Hunter.GLIDE_CATCH brakes a terminal fall in ~0.13 s)
CLOSE_LEN = 0.18
CLOSE_LET_GO = 0.06    # s: the hands leave the lines
BURN_LEN = 0.6
LEAN = {               # deg, for a right turn (a left turn mirrors it)
    "hips_roll": 10.0, "head_yaw": 14.0, "head_roll": 6.0, "legs_out": 14.0,
    "in_knee_up": 16.0, "in_shin": 20.0, "in_arm_down": 20.0, "out_arm_up": 8.0}
X, Y, Z = np.eye(3)
NAMES = ["glide_open", "glide_close", "glide_lean_l", "glide_lean_r", "glide_burn"]


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def qaxis(axis, deg):
    h = np.radians(deg) * 0.5
    return np.append(np.asarray(axis) * np.sin(h), np.cos(h))


def qrot(q, v):
    return qmul(qmul(q, np.append(v, 0.0)), qinv(q))[:3]


def slerp(a, b, k):
    d = float(np.dot(a, b))
    if d < 0.0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * k
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1 - k) * th) * a + np.sin(k * th) * b) / np.sin(th)


def ease(k):
    return k * k * (3.0 - 2.0 * k)


class Rig:
    """The .glb's node tree and one clip's channels, sampled at any time."""

    def __init__(self, j, b):
        self.j, self.b = j, b
        self.nodes = j["nodes"]
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        self.idx = {n.get("name"): i for i, n in enumerate(self.nodes)}

    def data(self, ai):
        ac = self.j["accessors"][ai]
        bv = self.j["bufferViews"][ac["bufferView"]]
        width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
        off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
        return np.frombuffer(bytes(self.b[off:off + ac["count"] * width * 4]), "<f4").reshape(ac["count"], width)

    def clip(self, name):
        anim = next(a for a in self.j["animations"] if a["name"] == name)
        ch = {}
        for c in anim["channels"]:
            s = anim["samplers"][c["sampler"]]
            ch[(c["target"]["node"], c["target"]["path"])] = (self.data(s["input"])[:, 0], self.data(s["output"]))
        return ch

    def rest(self, node, path):
        n = self.nodes[node]
        return np.array(n.get(path, {"rotation": [0, 0, 0, 1], "translation": [0, 0, 0], "scale": [1, 1, 1]}[path]))

    def sample(self, ch, node, path, t):
        if (node, path) not in ch:
            return self.rest(node, path)
        ts, vs = ch[(node, path)]
        t = min(max(t, ts[0]), ts[-1])
        i = int(np.clip(np.searchsorted(ts, t) - 1, 0, len(ts) - 2))
        k = 0.0 if ts[i + 1] <= ts[i] else (t - ts[i]) / (ts[i + 1] - ts[i])
        a, b = vs[i].astype(float), vs[i + 1].astype(float)
        return slerp(a, b, k) if path == "rotation" else a + (b - a) * k

    def length(self, ch):
        return max(float(ts[-1]) for ts, _ in ch.values())


class Pose:
    """One frame's local rotations (node -> quat), with world-axis turns of a bone on top of it."""

    def __init__(self, rig, rot):
        self.rig, self.rot = rig, rot

    def world(self, node):
        q = self.rot.get(node, self.rig.rest(node, "rotation"))
        p = self.rig.parent.get(node)
        return qmul(self.world(p), q) if p is not None else q

    def turn(self, name, axis, deg):
        """Turns the bone about a world axis through its head; its children follow."""
        node = self.rig.idx.get(name)
        if node is None or abs(deg) < 1e-4:
            return
        p = self.rig.parent.get(node)
        pw = self.world(p) if p is not None else np.array([0, 0, 0, 1.0])
        local = qmul(qmul(qinv(pw), qaxis(axis, deg)), pw)
        self.rot[node] = qmul(local, self.rot.get(node, self.rig.rest(node, "rotation")))

    def toward(self, name, goal, deg):
        """Swings the bone's length (its Y) up to deg toward a world direction."""
        node = self.rig.idx.get(name)
        if node is None:
            return
        y = qrot(self.world(node), Y)
        ax = np.cross(y, goal)
        n = np.linalg.norm(ax)
        if n < 1e-5:
            return
        ang = np.degrees(np.arctan2(n, float(np.dot(y, goal))))
        self.turn(name, ax / n, min(deg, ang))


def frames(rig, ch, t):
    return {node: rig.sample(ch, node, "rotation", t) for node, path in ch if path == "rotation"}


def blend(a, b, k):
    return {n: slerp(a.get(n, b[n]), b[n], k) for n in b}


def side(name, right):
    """The bone on the inside (right=True: the right side) of a turn."""
    return name + (".R" if right else ".L")


def lean(pose, right, k=1.0):
    s = 1.0 if right else -1.0
    L = LEAN
    pose.turn("hips", Z, -s * L["hips_roll"] * k)       # (about +Z, minus leans the head to +X: right)
    pose.turn("head", Y, -s * L["head_yaw"] * k)        # looks into the turn
    pose.turn("head", Z, s * L["head_roll"] * k)        # keeps the eyes nearer level than the torso
    for leg in ("thigh.L", "thigh.R"):
        pose.turn(leg, Z, s * L["legs_out"] * k)        # the legs swing out of the turn
    pose.turn(side("thigh", right), X, L["in_knee_up"] * k)
    pose.turn(side("shin", right), X, -L["in_shin"] * k)
    pose.toward(side("upper_arm", right), np.array([s, -1.0, 0.0]) / np.sqrt(2.0), L["in_arm_down"] * k)
    pose.toward(side("upper_arm", not right), Y, L["out_arm_up"] * k)


def reach(pose, k):
    """The hands thrown up to the lines, the chest open."""
    for arm in ("upper_arm.L", "upper_arm.R"):
        pose.toward(arm, Y, 18.0 * k)
    pose.turn("hips", X, 6.0 * k)


def catch(pose, k):
    """The canopy bites: knees jerk up, the head drops, the arms take the pull."""
    for leg, shin in (("thigh.L", "shin.L"), ("thigh.R", "shin.R")):
        pose.turn(leg, X, 20.0 * k)
        pose.turn(shin, X, -24.0 * k)
    pose.turn("head", X, -10.0 * k)
    pose.turn("hips", X, -5.0 * k)


def build(rig, fall, glide):
    gl = rig.length(glide)
    out = {}
    # the open: fall -> reach -> catch -> the hold
    keys = []
    for i in range(int(OPEN_LEN * FPS) + 1):
        t = i / FPS
        base = frames(rig, glide, t)
        if t <= OPEN_REACH:
            p = Pose(rig, dict(base))
            reach(p, 1.0)
            rot = blend(frames(rig, fall, 0.0), p.rot, ease(t / OPEN_REACH))
        elif t <= OPEN_CATCH:
            k = ease((t - OPEN_REACH) / (OPEN_CATCH - OPEN_REACH))
            p = Pose(rig, dict(base))
            reach(p, 1.0 - k)
            catch(p, k)
            rot = p.rot
        else:
            k = ease((t - OPEN_CATCH) / (OPEN_LEN - OPEN_CATCH))
            p = Pose(rig, dict(base))
            catch(p, 1.0 - k)
            rot = p.rot
        keys.append((t, rot))
    out["glide_open"] = keys
    # the close: hands off the lines, into the fall
    keys = []
    for i in range(int(CLOSE_LEN * FPS) + 1):
        t = i / FPS
        p = Pose(rig, frames(rig, glide, 0.0))
        if t <= CLOSE_LET_GO:
            reach(p, 0.6 * ease(t / CLOSE_LET_GO))
            rot = p.rot
        else:
            reach(p, 0.6)
            rot = blend(p.rot, frames(rig, fall, t), ease((t - CLOSE_LET_GO) / (CLOSE_LEN - CLOSE_LET_GO)))
        keys.append((t, rot))
    out["glide_close"] = keys
    # the leans: the hold's own loop, leaned
    for nm, right in (("glide_lean_l", False), ("glide_lean_r", True)):
        keys = []
        for i in range(int(round(gl * 30.0)) + 1):
            t = i / 30.0
            p = Pose(rig, frames(rig, glide, t))
            lean(p, right)
            keys.append((t, p.rot))
        out[nm] = keys
    # the struggle: the hold sped up to the burn's loop, the arms and legs fighting it
    keys = []
    for i in range(int(BURN_LEN * 30.0) + 1):
        t = i / 30.0
        ph = 2.0 * np.pi * t / BURN_LEN
        p = Pose(rig, frames(rig, glide, (t / BURN_LEN) * gl))
        p.toward("upper_arm.L", np.array([-0.4, -1.0, 0.0]), 16.0 * max(0.0, np.sin(2.0 * ph)))
        p.toward("upper_arm.R", np.array([0.4, -1.0, 0.0]), 16.0 * max(0.0, -np.sin(2.0 * ph)))
        p.turn("thigh.L", X, 22.0 * np.sin(ph))
        p.turn("thigh.R", X, -22.0 * np.sin(ph))
        p.turn("shin.L", X, -18.0 * (0.5 + 0.5 * np.cos(ph)))
        p.turn("shin.R", X, -18.0 * (0.5 - 0.5 * np.cos(ph)))
        p.turn("hips", X, 4.0 * np.sin(2.0 * ph))
        p.turn("head", X, 14.0)                          # looks up at the canopy
        p.turn("head", Z, 4.0 * np.sin(2.0 * ph))
        keys.append((t, p.rot))
    out["glide_burn"] = keys
    return out


def accessor(j, b, arr, typ, minmax):
    b.extend(b"\0" * (-len(b) % 4))
    raw = np.ascontiguousarray(arr, "<f4").tobytes()
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(raw)})
    b.extend(raw)
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if minmax:
        ac["min"], ac["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def store(rig, glide, name, keys):
    """Writes one clip: rotations from the keys, translation and scale resampled from the hold."""
    j, b = rig.j, rig.b
    ts = np.array([k[0] for k in keys])
    a = {"name": name, "channels": [], "samplers": []}
    t_in = accessor(j, b, ts, "SCALAR", True)
    turned = {n for k in keys for n in k[1]}       # (a turned bone the hold never keys gets its own channel)
    tracks = [c for c in glide if c[1] != "rotation"] + [(n, "rotation") for n in sorted(turned)]
    for node, path in tracks:
        if path == "rotation":
            vals = np.array([k[1].get(node, rig.rest(node, "rotation")) for k in keys])
        else:
            vals = np.array([rig.sample(glide, node, path, min(t, rig.length(glide))) for t in ts])
        a["samplers"].append({"input": t_in, "output": accessor(j, b, vals, "VEC4" if path == "rotation" else "VEC3",
                                                                False), "interpolation": "LINEAR"})
        a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": {"node": node, "path": path}})
    j["animations"].append(a)


def main(arts):
    for art in arts:
        cfg = json.load(open("content/rules/warden_anim/%s.json" % art))
        path = "art/wardens/%s/%s.glb" % (art, art)
        j, b = read(path)
        j["animations"] = [a for a in j["animations"] if a["name"] not in NAMES]
        rig = Rig(j, b)
        fall, glide = rig.clip(cfg["air"]["fall"]), rig.clip(cfg["air"]["glide"])
        for name, keys in build(rig, fall, glide).items():
            store(rig, glide, name, keys)
        j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
        write(path, j, b)
        print(art, "glide set written", os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main(sys.argv[1:] or sorted(os.path.basename(f)[:-5] for f in glob.glob("content/rules/warden_anim/*.json")))
