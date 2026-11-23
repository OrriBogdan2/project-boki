"""Pose-keyed clips on Meshy's own skeleton: the rig, a body pose from a few numbers, the glb writer, a stick sheet.

Used by ability_clips.py (Tenzo, Motley, Sable, Gil). Every clip is made facing +Z (Meshy's front); the game turns
the model to the aim. Nothing is retargeted: the rig is read from the hunter's own <art>_meshy.glb (bind pose from
its inverse bind matrices) and each frame is posed by limb directions (aim), two-bone reaches (ik) and world turns.
The file written holds the skeleton nodes and the clips only (no mesh): WardenNative.borrow lays the tracks on the
model's bones by name, and a bone with no track stays at its rest pose, so only the body bones below are keyed.

Body frame: A forward (+Z), Y up, S the character's left (+X). Angles in degrees; lengths in metres unless a
name ends in "o/u/f" for a hand (out, up, forward in arm lengths from the shoulder).
"""

import json
import math
import os
import struct

import numpy as np
from PIL import Image, ImageDraw

FPS = 30
Y = np.array([0.0, 1.0, 0.0])
A = np.array([0.0, 0.0, 1.0])
S = np.cross(Y, A)
KEYED = [
    "Hips", "Spine02", "Spine01", "Spine", "neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
]  # fmt: skip


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def rot(axis, deg):
    x, y, z = unit(axis)
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    t = 1 - c
    return np.array(
        [
            [t * x * x + c, t * x * y - s * z, t * x * z + s * y],
            [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
            [t * x * z - s * y, t * y * z + s * x, t * z * z + c],
        ]
    )


def euler(rx, ry, rz):
    """World rotation: X, then Y, then Z (degrees)."""
    return rot([0, 0, 1], rz) @ rot([0, 1, 0], ry) @ rot([1, 0, 0], rx)


def arc(a, b):
    """The shortest rotation taking direction a onto b."""
    a, b = unit(a), unit(b)
    ax = np.cross(a, b)
    s = np.linalg.norm(ax)
    if s < 1e-8:
        return np.eye(3) if a @ b > 0 else rot([1, 0, 0], 180)
    return rot(ax, math.degrees(math.atan2(s, a @ b)))


def quat(m):
    t = np.trace(m)
    if t > 0:
        s = 2 * math.sqrt(t + 1)
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(m)))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = 2 * math.sqrt(1 + m[i, i] - m[j, j] - m[k, k])
        q = [0.0] * 4
        q[i] = s / 4
        q[j] = (m[j, i] + m[i, j]) / s
        q[k] = (m[k, i] + m[i, k]) / s
        q[3] = (m[k, j] - m[j, k]) / s
    q = np.array(q)
    return q / np.linalg.norm(q)


class Rig:
    """The skeleton: names, parents, bind world rotations and positions, bone lengths."""

    def __init__(self, path):
        b = open(path, "rb").read()
        n = struct.unpack("<I", b[12:16])[0]
        js = json.loads(b[20 : 20 + n])
        buf = b[20 + n + 8 :]
        sk = js["skins"][0]
        acc = js["accessors"][sk["inverseBindMatrices"]]
        bv = js["bufferViews"][acc["bufferView"]]
        off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        ibm = np.frombuffer(buf, dtype="<f4", count=16 * acc["count"], offset=off).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.js = js
        self.joints = sk["joints"]
        self.name = {j: js["nodes"][j]["name"] for j in self.joints}
        self.id = {v: k for k, v in self.name.items()}
        self.par = {}
        for i, nd in enumerate(js["nodes"]):
            for c in nd.get("children", []):
                self.par[c] = i
        self.kids = {j: [c for c in js["nodes"][j].get("children", []) if c in self.name] for j in self.joints}
        self.bind = {j: np.linalg.inv(ibm[k]) for k, j in enumerate(self.joints)}
        self.order = []
        for j in self.joints:
            if self.par.get(j) not in self.name:
                self._walk(j)
        self.root = self.order[0]
        self.hips_t = np.array(js["nodes"][self.root].get("translation", [0, 0, 0]))
        self.local, self.off = {}, {}
        for j in self.joints:
            p = self.par.get(j)
            pw = self.bind[p] if p in self.name else np.eye(4)
            self.local[j] = (np.linalg.inv(pw) @ self.bind[j])[:3, :3]
            if p in self.name:
                self.off[j] = self.bind[p][:3, :3].T @ (self.bind[j][:3, 3] - self.bind[p][:3, 3])

    def _walk(self, j):
        self.order.append(j)
        for c in self.kids[j]:
            self._walk(c)

    def pos(self, nm):
        return self.bind[self.id[nm]][:3, 3]

    def length(self, nm):
        j = self.id[nm]
        return float(np.linalg.norm(self.bind[self.kids[j][0]][:3, 3] - self.bind[j][:3, 3]))


def reach(rig, upper, fore, start, target, pole):
    """Two-bone reach: the world directions of the upper and the fore bone for a hand at target (pole bends it)."""
    a, b = rig.length(upper), rig.length(fore)
    v = np.array(target, float) - start
    d = max(min(float(np.linalg.norm(v)), a + b - 1e-4), abs(a - b) + 1e-4)
    u = unit(v)
    along = (a * a - b * b + d * d) / (2 * d)
    h = math.sqrt(max(a * a - along * along, 0.0))
    side = pole - (pole @ u) * u
    side = unit(side) if np.linalg.norm(side) > 1e-6 else unit(np.cross(u, [0, 0, 1]))
    mid = start + u * along + side * h
    return unit(mid - start), unit(start + u * d - mid)


def fk(rig, pose):
    """Local rotations, world positions and world rotations of every joint for a pose dict (turn, hips, ik, keep)."""
    turn, keep, hold = pose.get("turn", {}), pose.get("keep", {}), pose.get("hold", {})
    ik = {u: (f, np.array(t, float), unit(pl)) for u, f, t, pl in pose.get("ik", [])}
    hip = rig.hips_t + np.array(pose.get("hips", (0, 0, 0)), float)
    W, P, L, fixed = {}, {}, {}, {}
    for j in rig.order:
        nm = rig.name[j]
        p = rig.par.get(j)
        has = p in rig.name
        pw = W[p] if has else np.eye(3)
        P[j] = P[p] + pw @ rig.off[j] if has else hip
        w = pw @ rig.local[j]
        if nm in fixed:
            w = arc(w @ Y, fixed[nm]) @ w
        elif nm in ik:
            f, tgt, pole = ik[nm]
            d1, d2 = reach(rig, nm, f, P[j], tgt, pole)
            w = arc(w @ Y, d1) @ w
            fixed[f] = d2
        if nm in turn:
            w = euler(*turn[nm]) @ w
        if nm in keep:
            w = euler(*keep[nm]) @ rig.bind[j][:3, :3]
        if nm in hold:
            w = hold[nm] @ rig.bind[j][:3, :3]
        W[j] = w
        L[j] = pw.T @ w
    return L, P, W


BASE = dict(
    hx=0.0, hy=0.0, hz=0.0, yaw=0.0, lean=0.0, roll=0.0, spin=0.0, hyaw=0.0, hpitch=0.0,
    lho=0.35, lhu=-0.85, lhf=0.15, rho=0.35, rhu=-0.85, rhf=0.15, lpu=-0.6, rpu=-0.6,
    lfo=0.0, lff=0.0, lfu=0.0, rfo=0.0, rff=0.0, rfu=0.0, lfy=0.0, rfy=0.0, lfp=0.0, rfp=0.0, gap=0.0, fb=0.0, hk=0.0, rwp=0.0, rwy=0.0, hl=0.0,
)  # fmt: skip
SPLIT = {"Hips": 0.40, "Spine02": 0.22, "Spine01": 0.22, "Spine": 0.16}  # the share of the torso turn each takes


def build(rig, q):
    """The pose for numbers q (BASE names): torso first, then the arms reach for their hand points from where the
    shoulders ended up, the legs for planted feet (bind foot place plus the foot offsets)."""
    q = dict(BASE, **q)
    torso = {k: (q["lean"] * v, q["yaw"] * v, q["roll"] * v) for k, v in SPLIT.items()}
    hx, hy, hz = q["hx"], q["hy"], q["hz"]
    sp = q["spin"]
    torso["Hips"] = (torso["Hips"][0] + q["hl"], torso["Hips"][1], torso["Hips"][2] + sp)  # (hl: more pitch on the hips)
    torso["neck"] = ((q["hpitch"] - q["lean"] - q["hl"]) * 0.5, (q["hyaw"] - q["yaw"]) * 0.5, -(q["roll"] + sp) * 0.5)
    torso["Head"] = torso["neck"]
    base = {"turn": torso, "hips": (hx, hy, hz)}
    P, W = fk(rig, base)[1:]
    sp_j = rig.id["Spine"]
    d = W[sp_j] @ rig.bind[sp_j][:3, :3].T  # the chest's turn since bind
    f, s, u = d @ A, d @ S, d @ Y
    reach_len = rig.length("LeftArm") + rig.length("LeftForeArm")
    ik = []
    for side, sg, ab in (("Left", 1.0, "l"), ("Right", -1.0, "r")):
        sh = P[rig.id[side + "Arm"]]
        o, up, fw = q[ab + "ho"], q[ab + "hu"], q[ab + "hf"]
        tgt = sh + (s * sg * o + u * up + f * fw) * reach_len
        pole = s * sg * 0.6 + u * q[ab + "pu"] - f * 0.4
        ik.append((side + "Arm", side + "ForeArm", tgt, pole))
    kn = rot([0, 1, 0], q["yaw"] * 0.5) @ A
    dh = W[rig.root] @ rig.bind[rig.root][:3, :3].T  # the hips' turn since bind: a leg that follows the body (fb)
    for side, sg, ab in (("Left", 1.0, "l"), ("Right", -1.0, "r")):
        b = rig.pos(side + "Foot")
        off = np.array([sg * q[ab + "fo"] + sg * q["gap"], q[ab + "fu"], q[ab + "ff"]])
        up_leg = rig.pos(side + "UpLeg")
        body = P[rig.id[side + "UpLeg"]] + dh @ (b - up_leg + off)
        ik.append((side + "UpLeg", side + "Leg", (b + off) + q["fb"] * (body - (b + off)), dh @ A if q["fb"] else kn))
    pose = dict(base)
    pose["ik"] = ik
    if q["hk"] > 0.5:  # the right hand holds its bind turn from the chest (a weapon laid along it keeps its line)
        pose["hold"] = {"RightHand": euler(q["rwp"], q["rwy"], 0.0) @ d}
    if q["fb"] == 0.0:  # (a planted foot stays flat; on a body-following leg the foot turns with the shin)
        pose["keep"] = {"LeftFoot": (q["lfp"], q["lfy"], 0.0), "RightFoot": (q["rfp"], q["rfy"], 0.0)}
    return pose


def ease(u, kind):
    u = min(max(u, 0.0), 1.0)
    if kind == "snap":
        return 1 - (1 - u) ** 3
    if kind == "lin":
        return u
    if kind == "in":
        return u * u
    if kind == "back":  # overshoots a little, then settles
        c = 1.4
        return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2
    return u * u * (3 - 2 * u)


def track(keys, t):
    """keys: [(time, params, ease into it)]; numbers blend, a missing name is its BASE value."""
    if t <= keys[0][0]:
        return dict(BASE, **keys[0][1])
    for (t0, a, _), (t1, b, e) in zip(keys, keys[1:]):
        if t <= t1:
            k = ease((t - t0) / (t1 - t0), e)
            a, b = dict(BASE, **a), dict(BASE, **b)
            return {n: a[n] + (b[n] - a[n]) * k for n in a}
    return dict(BASE, **keys[-1][1])


def sample(rig, length, keys):
    """Every frame of a clip: (times, {bone name: [local quats]}, [hips translations])."""
    n = int(round(length * FPS)) + 1
    times = [i / FPS for i in range(n)]
    out = {nm: [] for nm in KEYED}
    hips = []
    for t in times:
        pose = build(rig, track(keys, t))
        loc, pos, _ = fk(rig, pose)
        for nm in KEYED:
            out[nm].append(quat(loc[rig.id[nm]]))
        hips.append(pos[rig.root])
    for nm in KEYED:  # one hemisphere, so the blend between frames never takes the long way
        for i in range(1, n):
            if np.dot(out[nm][i], out[nm][i - 1]) < 0:
                out[nm][i] = -out[nm][i]
    return times, out, hips


def write_glb(rig, clips, path, who):
    """Skeleton nodes (a skin over the joints, no mesh) plus one animation per clip: rotation tracks for the body
    bones and the hips' translation. clips: name -> (length s, keys)."""
    keep = list(rig.joints) + [rig.par[rig.root]]
    remap = {old: i for i, old in enumerate(keep)}
    nodes = []
    for old in keep:
        src = rig.js["nodes"][old]
        nd = {k: v for k, v in src.items() if k in ("name", "translation", "rotation", "scale")}
        kids = [remap[c] for c in src.get("children", []) if c in remap]
        if kids:
            nd["children"] = kids
        nodes.append(nd)
    blob, views, accs, anims = bytearray(), [], [], []

    def add(arr, typ, count):
        data = np.asarray(arr, "<f4").tobytes()
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        blob.extend(data)
        a = {"bufferView": len(views) - 1, "componentType": 5126, "count": count, "type": typ}
        if typ == "SCALAR":
            a.update(min=[float(np.min(arr))], max=[float(np.max(arr))])
        accs.append(a)
        return len(accs) - 1

    for name, (length, keys) in clips.items():
        times, rots, hips = sample(rig, length, keys)
        t_acc = add(times, "SCALAR", len(times))
        chans, samplers = [], []
        for nm in KEYED:
            samplers.append({"input": t_acc, "output": add(rots[nm], "VEC4", len(times)), "interpolation": "LINEAR"})
            chans.append({"sampler": len(samplers) - 1, "target": {"node": remap[rig.id[nm]], "path": "rotation"}})
        samplers.append({"input": t_acc, "output": add(hips, "VEC3", len(times)), "interpolation": "LINEAR"})
        chans.append({"sampler": len(samplers) - 1, "target": {"node": remap[rig.root], "path": "translation"}})
        anims.append({"name": name, "channels": chans, "samplers": samplers})
    js = {
        "asset": {"version": "2.0", "generator": "tools/meshy/ability_clips.py " + who},
        "scene": 0,
        "scenes": [{"name": "Scene", "nodes": [len(nodes) - 1]}],
        "nodes": nodes,
        "skins": [{"joints": [remap[j] for j in rig.joints]}],
        "animations": anims,
        "accessors": accs,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    while len(blob) % 4:
        blob.append(0)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob)))
        f.write(struct.pack("<II", len(j), 0x4E4F534A) + j)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


BONES = [
    ("Hips", "Spine02"), ("Spine02", "Spine01"), ("Spine01", "Spine"), ("Spine", "neck"), ("neck", "Head"),
    ("Spine", "LeftShoulder"), ("LeftShoulder", "LeftArm"), ("LeftArm", "LeftForeArm"), ("LeftForeArm", "LeftHand"),
    ("Spine", "RightShoulder"), ("RightShoulder", "RightArm"), ("RightArm", "RightForeArm"),
    ("RightForeArm", "RightHand"), ("Hips", "LeftUpLeg"), ("LeftUpLeg", "LeftLeg"), ("LeftLeg", "LeftFoot"),
    ("LeftFoot", "LeftToeBase"), ("Hips", "RightUpLeg"), ("RightUpLeg", "RightLeg"), ("RightLeg", "RightFoot"),
    ("RightFoot", "RightToeBase"),
]  # fmt: skip


def sheet(rig, clips, outdir, frames=7):
    """Stick figures per clip: side (x = forward), front and top views at `frames` times across the clip."""
    os.makedirs(outdir, exist_ok=True)
    views = [(2, 1, 110), (0, 1, 110)]  # (horizontal axis, vertical axis, scale) of world x/y/z
    for name, (length, keys) in clips.items():
        img = Image.new("RGB", (frames * 2 * 130, 260), "white")
        d = ImageDraw.Draw(img)
        for k in range(frames):
            t = length * k / (frames - 1)
            pos = fk(rig, build(rig, track(keys, t)))[1]
            for v, (hx, vy, sc) in enumerate(views):
                ox, oy = (k * 2 + v) * 130 + 65, 235
                for a, b in BONES:
                    p, q = pos[rig.id[a]], pos[rig.id[b]]
                    col = "red" if "Left" in b else "blue" if "Right" in b else "black"
                    d.line([ox + p[hx] * sc, oy - p[vy] * sc, ox + q[hx] * sc, oy - q[vy] * sc], fill=col, width=3)
            d.text((k * 260 + 4, 4), "%s t=%.2f" % (name, t), fill="black")
        img.save(os.path.join(outdir, name + ".png"))
