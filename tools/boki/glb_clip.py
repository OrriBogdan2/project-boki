#!/usr/bin/env python3
"""Adds (or replaces) clips from a species' *_anim.py in its live .glb, the model untouched: no Blender, no rebuild.
For a Bokidex-ported species whose model source (~/meshy/boki/<id>/dex) is not at hand, and so a new clip never
moves a vertex of the approved look. The keys are what boki_rig.make_clips + the Blender glTF export write:
a game-axis euler W on a bone turns it about its parent's rest frame, so its node rotation is P_rest^-1 W G_rest
(G the bone's armature-space rest rotation, P its parent's; game axes are glTF's), root/hips/hidden props move by
the parent-rest-frame offset, props scale 0.001 unless "on". `--check=<clip>` rebuilds a clip the .glb already has
and prints the largest difference (proof the keys match a Blender build).
  ~/venv-img/bin/python tools/boki/glb_clip.py <id> <clip>[,<clip>] [--check=idle] [--dry]
"""
import importlib
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
SPECS = {"cindle": "vespyx_anim", "puddlet": "prismander_anim", "burrlet": "mycroll_anim"}
FPS = 30
CLIP_SCALE = 0.95      # boki_rig.CLIP_SCALE


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def qaxis(axis, ang):
    s = math.sin(ang / 2)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, math.cos(ang / 2)])


def qrot(q, v):
    return qmul(qmul(q, np.array([v[0], v[1], v[2], 0.0])), qinv(q))[:3]


def game_quat(rx, ry, rz):
    """boki_rig.quat_of in glTF axes (the game's)."""
    return qmul(qmul(qaxis((0, 1, 0), ry), qaxis((1, 0, 0), rx)), qaxis((0, 0, 1), rz))


def read(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", d[off:off + 4])[0]
    return j, bytearray(d[off + 8:off + 8 + bl])


def write(path, j, bin_):
    while len(bin_) % 4:
        bin_ += b"\0"
    j["buffers"][0]["byteLength"] = len(bin_)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_)
    open(path, "wb").write(out)


def accessor(j, bin_, arr, typ):
    arr = np.ascontiguousarray(arr, np.float32)
    while len(bin_) % 4:
        bin_ += b"\0"
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(bin_), "byteLength": arr.nbytes})
    bin_ += arr.tobytes()
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR":
        a["min"], a["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def read_acc(j, bin_, i):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    o = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(bytes(bin_[o:o + a["count"] * n * 4]), np.float32).reshape(a["count"], n)


class Rig:
    def __init__(self, j):
        self.j = j
        self.nodes = j["nodes"]
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        self.bones = j["skins"][0]["joints"]
        self.name = {i: self.nodes[i]["name"] for i in self.bones}
        self.glob = {}
        for i in self.bones:
            self._g(i)

    def rest(self, i):
        n = self.nodes[i]
        return np.array(n.get("rotation", [0, 0, 0, 1.0])), np.array(n.get("translation", [0, 0, 0.0]))

    def _g(self, i):
        """Armature-space rest rotation (the skeleton's parent node, "Rig", is the identity)."""
        if i not in self.glob:
            p = self.parent.get(i)
            r = self.rest(i)[0]
            self.glob[i] = qmul(self._g(p), r) if p in self.bones else r
        return self.glob[i]

    def bone_scale(self, i, sc):
        """boki_rig._bone_scale: a squash along game x, y, z on the bone's closest local axes."""
        out = np.ones(3)
        cols = [qrot(self._g(i), e) for e in np.eye(3)]
        for k, v in enumerate(np.eye(3)):
            out[int(np.argmax([abs(c @ v) for c in cols]))] = sc[k]
        return out

    def keys(self, fn, frames, hide_at):
        """{node: {"rotation": [N,4], "translation": [N,3], "scale": [N,3]}} for poses fn(f / frames)."""
        out = {i: {"rotation": [], "translation": [], "scale": []} for i in self.bones}
        for f in range(frames + 1):
            pose = fn(f / frames)
            for i in self.bones:
                nm = self.name[i]
                p = self.parent.get(i)
                pg = self._g(p) if p in self.bones else np.array([0, 0, 0, 1.0])
                rot = pose.get(nm, (0, 0, 0))
                rot = (0, 0, 0) if rot == "on" else rot
                q = qmul(qmul(qinv(pg), game_quat(*rot)), self._g(i))
                out[i]["rotation"].append(q / np.linalg.norm(q))
                r0, t0 = self.rest(i)
                off = np.zeros(3)
                hide = hide_at.get(nm)
                if p not in self.bones or nm == "hips" or hide:
                    o = pose.get(nm + "_at", (0, 0, 0))
                    if hide and pose.get(nm) != "on":
                        o = hide
                    off = qrot(qinv(pg), np.array(o, float) * CLIP_SCALE)
                out[i]["translation"].append(t0 + off)
                sc = np.ones(3)
                if nm.startswith("prop_"):
                    sc = np.ones(3) if pose.get(nm) == "on" else np.full(3, 0.001)
                elif nm.startswith("part_"):
                    sc = np.full(3, 0.001)
                elif pose.get(nm + "_sc") is not None:
                    sc = self.bone_scale(i, pose[nm + "_sc"])
                out[i]["scale"].append(sc)
        return {i: {k: np.array(v) for k, v in d.items()} for i, d in out.items()}


def baked(j, bin_, name):
    """{node: {path: values}} of a clip in the .glb."""
    a = next(x for x in j["animations"] if x["name"] == name)
    out = {}
    for c in a["channels"]:
        s = a["samplers"][c["sampler"]]
        out.setdefault(c["target"]["node"], {})[c["target"]["path"]] = read_acc(j, bin_, s["output"])
    return out


def anchor(rig, k, like, like_k):
    """A bone's baked translation is not always its node's rest (props, grown parts, the hidden berry): keep only
    the clip's move, laid on the baked idle's first key."""
    for i in rig.bones:
        if "translation" in like.get(i, {}):
            k[i]["translation"] = like[i]["translation"][0] + (k[i]["translation"] - like_k[i]["translation"][0])
    return k


def add_clip(j, bin_, rig, name, seconds, fn, hide_at, like, like_k):
    frames = max(2, int(round(seconds * FPS)))
    if any(fn(f / frames).get(b) == "on" for b in hide_at for f in range(frames + 1)):
        raise SystemExit("glb_clip: %s shows a hidden prop (%s): its keys need the Blender build" % (name, hide_at))
    k = anchor(rig, rig.keys(fn, frames, hide_at), like, like_k)
    j["animations"] = [a for a in j["animations"] if a["name"] != name]
    times = accessor(j, bin_, np.arange(frames + 1) / FPS, "SCALAR")
    anim = {"name": name, "channels": [], "samplers": []}
    for i in rig.bones:
        for path in ("translation", "rotation", "scale"):
            if path not in like.get(i, {}):
                continue
            anim["samplers"].append({"input": times, "interpolation": "LINEAR",
                                     "output": accessor(j, bin_, k[i][path], "VEC4" if path == "rotation" else "VEC3")})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": i, "path": path}})
    j["animations"].append(anim)
    j["animations"].sort(key=lambda a: a["name"])
    return k


def idle_keys(rig, anim):
    return rig.keys(anim.CLIPS["idle"][2], 2, anim.HIDE_AT)


def check(j, bin_, rig, anim, name):
    seconds, loop, fn = anim.CLIPS[name]
    frames = max(2, int(round(seconds * FPS)))
    have = baked(j, bin_, name)
    k = anchor(rig, rig.keys(fn, frames, anim.HIDE_AT), baked(j, bin_, "idle"), idle_keys(rig, anim))
    worst = {"rotation": 0.0, "translation": 0.0, "scale": 0.0}
    for i, paths in have.items():
        for path, v in paths.items():
            mine = k[i][path]
            if len(v) != len(mine):         # Blender keeps a constant channel as 2 keys
                v = np.repeat(v[:1], len(mine), 0)
            if path == "rotation":
                d = 1 - np.abs(np.sum(v * mine, 1)).clip(0, 1)
                err = float(np.degrees(2 * np.arccos(1 - d.max())))
            else:
                err = float(np.abs(v - mine).max())
            worst[path] = max(worst[path], err)
    print("CHECK %s: rotation %.3f deg, translation %.5f m, scale %.5f" % (
        name, worst["rotation"], worst["translation"], worst["scale"]))
    return worst


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[1:] if a.startswith("--"))
    species, clips = args[0], args[1].split(",") if len(args) > 1 else []
    anim = importlib.import_module(SPECS[species])
    path = os.path.join(REPO, "art", "kin", species, species + ".glb")
    j, bin_ = read(path)
    rig = Rig(j)
    if "check" in opts:
        w = check(j, bin_, rig, anim, opts["check"])
        if w["rotation"] > 0.5 or w["translation"] > 0.002:
            raise SystemExit("glb_clip: %s does not match its baked %s" % (species, opts["check"]))
    like, like_k = baked(j, bin_, "idle"), idle_keys(rig, anim)
    for name in clips:
        seconds, loop, fn = anim.CLIPS[name]
        add_clip(j, bin_, rig, name, seconds, fn, anim.HIDE_AT, like, like_k)
        print("ADDED %s %s %.2fs" % (species, name, seconds))
    if clips and "dry" not in opts:
        write(path, j, bin_)


if __name__ == "__main__":
    main()
