"""Lace's bow clips on Meshy's own skeleton (art/wardens/hem/hem_clips.glb), written from poses, no retarget.

  /home/boki/venv-img/bin/python3 tools/meshy/lace_clips.py OUT.glb [--sheet DIR]

Reads hem_meshy.glb's skeleton (bind pose from its inverse bind matrices), poses it by limb directions (aim) and
two-bone reaches (ik), and keys every bone's rotation at 30 fps. The file holds the skeleton nodes and the clips only
(no mesh): WardenNative.borrow lays the tracks on the model's bones by name. Every release clip starts at full draw,
so the string lets go on its first frame step (the kit plays the move at the frame the arrow leaves).
--sheet writes a stick-figure side/front/top sheet of each clip's key frames for a check before any render.
"""

import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "art", "wardens", "hem", "hem_meshy.glb")
FPS = 30
Y = np.array([0.0, 1.0, 0.0])


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def rot(axis, deg):
    a = unit(axis)
    c, s, t = math.cos(math.radians(deg)), math.sin(math.radians(deg)), 1 - math.cos(math.radians(deg))
    x, y, z = a
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


def reach(rig, upper, fore, hand, start, target, pole):
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
    aim, turn, keep = pose.get("aim", {}), pose.get("turn", {}), pose.get("keep", {})
    ik = {u: (f, h, np.array(t, float), unit(pl)) for u, f, h, t, pl in pose.get("ik", [])}
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
            f, _, tgt, pole = ik[nm]
            d1, d2 = reach(rig, nm, f, ik[nm][1], P[j], tgt, pole)
            w = arc(w @ Y, d1) @ w
            fixed[f] = d2
        elif nm in aim:
            d, roll = aim[nm]
            w = rot(unit(d), roll) @ arc(w @ Y, d) @ w
        if nm in turn:
            w = euler(*turn[nm]) @ w
        if nm in keep:
            w = rot([0, 1, 0], keep[nm]) @ rig.bind[j][:3, :3]
        W[j] = w
        L[j] = pw.T @ w
    return L, P


def build(rig, q):
    """The pose of a bow stance from a few numbers q (yaw deg, lift/ext/draw/rel 0..1, crouch m, lean deg, tremor).

    Torso first (yaw split over hips and spine, the head turned back onto the target), then the arms reach for the
    bow hand and the string hand from where the shoulders ended up, the legs for planted feet."""
    yaw, lean, crouch = q["yaw"], q["lean"], q["crouch"]
    split = {"Hips": 0.40, "Spine02": 0.22, "Spine01": 0.22, "Spine": 0.16}
    torso = {k: (lean * v, yaw * v, 0.0) for k, v in split.items()}
    torso["neck"] = (0.0, -yaw * 0.45 + q.get("look", 0.0), 0.0)
    torso["Head"] = (0.0, -yaw * 0.55, 0.0)
    A = np.array([0.0, 0.0, 1.0])  # the aim: every clip is made facing +Z, the game turns the model to the target
    S = np.cross(Y, A)
    F = rot([0, 1, 0], yaw) @ np.array([0.0, 0.0, 1.0])
    base = {"turn": torso, "hips": (q.get("sway", 0.0), -crouch, 0.0)}
    pre = fk(rig, base)[1]
    shL, hd = pre[rig.id["LeftArm"]], pre[rig.id["Head"]]
    ext = q["ext"]
    bow = shL + A * (0.18 + 0.30 * ext) + Y * (-0.30 + 0.34 * q["lift"] + q.get("bowy", 0.0)) + S * (-0.03)
    bow = bow - A * q.get("kick", 0.0) + Y * q.get("kickup", 0.0)
    nock = bow - A * 0.13 - S * 0.02 + Y * (-0.02)
    anchor = hd + Y * 0.07 + A * 0.06 - S * 0.07
    away = -A * 0.32 - S * 0.16 + Y * 0.06
    hand = nock + (anchor - nock) * q["draw"]
    hand = hand + (anchor + away - hand) * q["rel"] + Y * q.get("handy", 0.0)
    tre = q.get("tremor", 0.0)
    hand = hand + np.array([tre * 0.4, tre, tre * 0.3])
    if "idle" in q:  # the casual stand: both hands down at her sides, the bow hanging from the left
        shR = pre[rig.id["RightArm"]]
        out = unit(shL - shR)
        bow = shL + out * 0.2 + A * q.get("bowfwd", 0.04) + Y * (-0.42 + q.get("bowy", 0.0))
        hand = shR - out * 0.17 + A * 0.03 + Y * -0.45 + np.array([tre * 0.4, tre, tre * 0.3])
    ankle = rig.pos("LeftFoot")[1]
    hip_xz = np.array([rig.hips_t[0], 0.0, rig.hips_t[2]])
    gap = q.get("gap", 0.21)
    lf = hip_xz + A * (gap + q.get("fl", 0.0)) + S * 0.04 + np.array([0, ankle + q.get("fly", 0.0), 0])
    rf = hip_xz - A * (gap - q.get("fl", 0.0)) - S * 0.04 + np.array([0, ankle + q.get("fry", 0.0), 0])
    if "idle" in q:  # feet where the bind pose has them, side by side
        lf, rf = rig.pos("LeftFoot") + Y * q.get("fly", 0.0), rig.pos("RightFoot") + Y * q.get("fry", 0.0)
    pose = dict(base)
    pose["ik"] = [
        ("LeftArm", "LeftForeArm", "LeftHand", bow, -S * 0.3 + Y * -1.0),
        ("RightArm", "RightForeArm", "RightHand", hand, -A * 0.9 - S * 0.5 + Y * 0.2 + Y * (1 - q["draw"]) * -0.8),
        ("LeftUpLeg", "LeftLeg", "LeftFoot", lf, F),
        ("RightUpLeg", "RightLeg", "RightFoot", rf, F),
    ]
    foot = 0.0 if "idle" in q else yaw * 1.3 - 20.0
    pose["keep"] = {"LeftFoot": foot, "RightFoot": foot, "LeftHand": 0.0}
    # the string rides the fingers while drawn and is back on the bow the moment it lets go
    pose["string"] = (nock + (anchor - nock) * q["draw"], min(q["draw"] * 4, 1.0) * (1.0 - min(q["rel"] * 4, 1.0)))
    return pose


STANCE = dict(yaw=-25, lean=0, crouch=0.04, ext=0.55, lift=0.25, draw=0.0, rel=0.0, gap=0.17)
NOCK = dict(STANCE, yaw=-40, ext=0.85, lift=0.95, draw=0.0, crouch=0.06)
FULL = dict(STANCE, yaw=-55, ext=1.0, lift=1.0, draw=1.0, crouch=0.08, gap=0.22)
HALF = dict(FULL, draw=0.6, ext=0.95, yaw=-48)
CASUAL = dict(idle=1.0, yaw=-6, lean=0, crouch=0.015, ext=0, lift=0, draw=0.0, rel=0.0, gap=0.1)  # bow down at her side
READY = dict(STANCE, yaw=-30, ext=0.7, lift=0.55, crouch=0.05)  # bow forward, an arrow nocked, not drawn


def ease(u, kind):
    u = min(max(u, 0.0), 1.0)
    if kind == "snap":
        return 1 - (1 - u) ** 3
    if kind == "lin":
        return u
    if kind == "in":
        return u * u
    return u * u * (3 - 2 * u)


def track(keys, t):
    """keys: [(time, params, ease into it)]; numbers blend, the rest of the dict comes from the later key."""
    if t <= keys[0][0]:
        return dict(keys[0][1])
    for (t0, a, _), (t1, b, e) in zip(keys, keys[1:]):
        if t <= t1:
            k = ease((t - t0) / (t1 - t0), e)
            return {n: a.get(n, 0.0) + (b.get(n, 0.0) - a.get(n, 0.0)) * k for n in set(a) | set(b)}
    return dict(keys[-1][1])


def over(p, **kw):
    return dict(p, **kw)


# Release: the string lets go on the first frame step (t = 1/FPS) and the hand flies back; the bow hand kicks.
def released(p, back=1.0, kick=0.05, hold=0.4):
    return [
        (0.0, p, "lin"),
        (1 / FPS, over(p, rel=0.55 * back, kick=kick * 0.5), "snap"),
        (0.12, over(p, rel=back, kick=kick, kickup=0.04, yaw=p["yaw"] - 6, lean=-4, handy=0.04), "snap"),
        (
            0.12 + hold * 0.4,
            over(p, rel=0.6 * back, kick=kick * 0.4, yaw=p["yaw"] + 8, lift=0.7, ext=0.7, draw=0.2),
            "smooth",
        ),
    ]


def settle(keys, end, to=STANCE):
    return keys + [(end, over(to, rel=0.0), "smooth")]


def clips():
    """name -> (length s, [(time, params, ease)], loop_from or None)."""
    out = {}
    out["lace_draw"] = (
        1.65,
        [(0.0, STANCE, "lin"), (0.12, NOCK, "smooth"), (1.15, FULL, "smooth")] + [(1.65, FULL, "lin")],
        1.15,
    )
    out["lace_over"] = (0.7, [(0.0, FULL, "lin"), (0.7, FULL, "lin")], 0.08)
    out["lace_tap"] = (0.5, settle(released(over(HALF, draw=0.45), back=0.7, kick=0.03, hold=0.35), 0.5), None)
    out["lace_loose"] = (0.44, settle(released(FULL), 0.44), None)
    out["lace_super"] = (0.5, settle(released(over(FULL, lean=6), back=1.2, kick=0.09, hold=0.5), 0.5), None)
    heavy = over(FULL, crouch=0.12, gap=0.26, yaw=-62, lean=8)
    out["lace_heavy_wind"] = (
        1.6,
        [(0.0, STANCE, "lin"), (0.15, NOCK, "smooth"), (1.1, heavy, "smooth"), (1.6, heavy, "lin")],
        1.1,
    )
    out["lace_heavy"] = (0.6, settle(released(heavy, back=1.4, kick=0.14, hold=0.7), 0.6), None)
    # Spirit Walk: low and light, the bow down at her side, the string hand empty; the legs step once a second
    low = over(STANCE, yaw=-12, crouch=0.14, lift=0.0, ext=0.35, lean=8, gap=0.12, bowy=-0.05)
    steps = [
        (0.0, over(low, fl=0.09, fly=0.0, fry=0.05), "lin"),
        (0.5, over(low, fl=-0.09, fly=0.05, fry=0.0), "smooth"),
    ]
    out["lace_spirit"] = (
        1.0,
        [(0.0, low, "lin"), (0.2, steps[0][1], "smooth")]
        + [(0.7, steps[1][1], "smooth"), (1.0, steps[0][1], "smooth")],
        0.2,
    )
    # the two stands (4 s loops, whole sine periods): casual with the bow hanging, ready with the bow up
    out["lace_idle"] = (4.0, [(0.0, CASUAL, "lin"), (4.0, CASUAL, "lin")], None)
    out["lace_idle_combat"] = (4.0, [(0.0, READY, "lin"), (4.0, READY, "lin")], None)
    out["lace_ult"] = (0.4, settle(released(over(FULL, draw=0.9), back=1.1, kick=0.08, hold=0.3), 0.4, NOCK), None)
    out["lace_ult_final"] = (0.55, settle(released(over(FULL, lean=5), back=1.3, kick=0.12, hold=0.5), 0.55), None)
    return out


def pose_at(name, t):
    length, keys, loop_from = clips()[name]
    q = track(keys, t)
    if name.startswith("lace_idle"):  # a weight shift, a breath and a slow look round
        ph = 2 * math.pi * t / length
        q["sway"] = 0.012 * math.sin(ph)
        q["lean"] = q["lean"] + 0.7 * math.sin(2 * ph)
        q["look"] = 9.0 * math.sin(ph)
    if loop_from is not None and t >= loop_from:
        # the hold: a breath and a faint tremor, closing on its own first frame (period = the loop)
        ph = (t - loop_from) / (length - loop_from)
        amp = 0.012 if name != "lace_over" else 0.03
        q["tremor"] = amp * math.sin(2 * math.pi * ph)
        q["lift"] = q["lift"] + 0.01 * math.sin(2 * math.pi * ph + 1.0)
        q["lean"] = q["lean"] + 0.6 * math.sin(2 * math.pi * ph)
    return q


def string_local(rig, loc, pos, pose):
    """StringMid's local offset from the bow bone that puts the string at the pulled point (or at rest)."""
    s, b = rig.id["StringMid"], rig.id["Bow"]
    rest = rig.off[s]
    pull, w = pose["string"]
    if w <= 0.0:
        return rest
    w_b = np.eye(3)
    for j in chain(rig, b):
        w_b = w_b @ loc[j]
    return rest + w * (w_b.T @ (pull - pos[s]))


def chain(rig, j):
    up = []
    while j in rig.name:
        up.append(j)
        j = rig.par.get(j)
    return up[::-1]


def sample(rig, name):
    """Every frame of a clip: (times, {joint: [local quats]}, [hips translations], [string offsets])."""
    length = clips()[name][0]
    n = int(round(length * FPS)) + 1
    times = [i / FPS for i in range(n)]
    out = {j: [] for j in rig.joints}
    hips, string = [], []
    for t in times:
        pose = build(rig, pose_at(name, t))
        loc, pos = fk(rig, pose)
        for j in rig.joints:
            out[j].append(quat(loc[j]))
        hips.append(pos[rig.root])
        string.append(string_local(rig, loc, pos, pose))
    for j in rig.joints:  # one hemisphere, so the blend between frames never takes the long way
        for i in range(1, n):
            if np.dot(out[j][i], out[j][i - 1]) < 0:
                out[j][i] = -out[j][i]
    return times, out, hips, string


def write_glb(rig, path, extra=(), own=True):
    """Skeleton nodes (a skin over the joints, no mesh: Godot makes a Skeleton3D from it, so the tracks name bones) plus
    one animation per clip, rotation tracks for every joint, and the hips and the string's translation.
    extra: more clips [(name, times, {joint: quats}, hips, {joint: translations})] (native_clips.py; no string track); own=False: only those
    (another Hunter's skeleton, without the bow)."""
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

    todo = [(n,) + sample(rig, n) for n in clips()] if own else []
    for name, times, rots, hips, *more in todo + [tuple(x) for x in extra]:
        string = more[0] if more and not isinstance(more[0], dict) else None
        moves = more[0] if more and isinstance(more[0], dict) else {}  # (native_clips riders: bone -> translations)
        t_acc = add(times, "SCALAR", len(times))
        chans, samplers = [], []
        for j in rig.joints:
            if rig.name[j].startswith("SkirtSw"):  # (Meshy's clips leave the skirt joints at rest; no track, as before)
                continue
            samplers.append({"input": t_acc, "output": add(rots[j], "VEC4", len(times)), "interpolation": "LINEAR"})
            chans.append({"sampler": len(samplers) - 1, "target": {"node": remap[j], "path": "rotation"}})
        samplers.append({"input": t_acc, "output": add(hips, "VEC3", len(times)), "interpolation": "LINEAR"})
        chans.append({"sampler": len(samplers) - 1, "target": {"node": remap[rig.root], "path": "translation"}})
        for j, tr in moves.items():
            samplers.append({"input": t_acc, "output": add(tr, "VEC3", len(times)), "interpolation": "LINEAR"})
            chans.append({"sampler": len(samplers) - 1, "target": {"node": remap[j], "path": "translation"}})
        if string is not None:
            samplers.append({"input": t_acc, "output": add(string, "VEC3", len(times)), "interpolation": "LINEAR"})
            chans.append(
                {"sampler": len(samplers) - 1, "target": {"node": remap[rig.id["StringMid"]], "path": "translation"}}
            )
        anims.append({"name": name, "channels": chans, "samplers": samplers})
    js = {
        "asset": {"version": "2.0", "generator": "tools/meshy/lace_clips.py" if own else "tools/meshy/native_clips.py"},
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


def sheet(rig, outdir):
    """Stick figures per clip: side (x = forward), front and top views, at 0, 1/4, 1/2, 3/4 and the end."""
    os.makedirs(outdir, exist_ok=True)
    views = [(2, 1, 130), (0, 1, 130), (0, 2, 100)]  # (horizontal axis, vertical axis, scale) of world x/y/z
    for name, (length, _, _) in clips().items():
        img = Image.new("RGB", (5 * 3 * 150, 330), "white")
        d = ImageDraw.Draw(img)
        for k in range(5):
            t = length * k / 4
            pos = fk(rig, build(rig, pose_at(name, t)))[1]
            for v, (hx, vy, sc) in enumerate(views):
                ox, oy = (k * 3 + v) * 150 + 75, (300 if v < 2 else 165)
                for a, b in BONES:
                    p, q = pos[rig.id[a]], pos[rig.id[b]]
                    col = "red" if "Left" in b else "blue" if "Right" in b else "black"
                    d.line([ox + p[hx] * sc, oy - p[vy] * sc, ox + q[hx] * sc, oy - q[vy] * sc], fill=col, width=3)
            d.text((k * 450 + 4, 4), "%s t=%.2f" % (name, t), fill="black")
        img.save(os.path.join(outdir, name + ".png"))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    rig = Rig(SRC)
    if "--sheet" in args:
        sheet(rig, args[args.index("--sheet") + 1])
    write_glb(rig, args[0])


if __name__ == "__main__":
    main()
