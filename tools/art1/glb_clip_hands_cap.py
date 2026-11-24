"""Caps how high a clip lifts the hands: per key, the shoulder and upper-arm rotations are slerped toward another
clip's first pose (the Idle) just enough that both hand bones stay `margin` (model units) below the head bone; the
per-key amount is widened (max over +-2 keys) and smoothed so the arms do not jitter. Only those rotation values
change, written in place: the key times, every other track, mesh, skin and the rest of the file stay byte-identical.
Meeko's Meshy `Attack` swung both forearms up through her muzzle (PLAN meeko-comp-plan-1124 4A).
Run: python3 tools/art1/glb_clip_hands_cap.py IN.glb OUT.glb --clip=Attack --pose=Idle --margin=0.07
     [--head=Head] [--hands=LeftHand,RightHand] [--bones=LeftShoulder,LeftArm,RightShoulder,RightArm]"""

import json
import struct
import sys

import numpy as np


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array(
        [
            w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
            w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
            w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
            w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        ]
    )


def qmat(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def slerp(a, b, t):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        q = a + (b - a) * t
    else:
        th = np.arccos(d)
        q = (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)
    return q / np.linalg.norm(q)


def trs(t, r, s):
    m = np.eye(4)
    m[:3, :3] = qmat(r) * np.asarray(s)
    m[:3, 3] = t
    return m


def main():
    a = sys.argv[1:]
    src, out = a[0], a[1]
    opt = dict(x[2:].split("=", 1) for x in a[2:] if x.startswith("--"))
    clip, pose = opt.get("clip", "Attack"), opt.get("pose", "Idle")
    margin = float(opt.get("margin", 0.07))
    head = opt.get("head", "Head")
    hands = opt.get("hands", "LeftHand,RightHand").split(",")
    bones = opt.get("bones", "LeftShoulder,LeftArm,RightShoulder,RightArm").split(",")
    b = bytearray(open(src, "rb").read())
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    b0 = 20 + n + 8  # the BIN chunk's data

    def acc(i):
        ac = j["accessors"][i]
        bv = j["bufferViews"][ac["bufferView"]]
        nc = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
        assert ac["componentType"] == 5126 and not bv.get("byteStride")
        off = b0 + bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
        return off, np.frombuffer(bytes(b[off : off + ac["count"] * nc * 4]), np.float32).reshape(ac["count"], nc)

    nodes = j["nodes"]
    name = {nd.get("name"): i for i, nd in enumerate(nodes)}
    par = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    anims = {x["name"]: x for x in j["animations"]}
    tracks = {}  # (node, path) -> (times, values, value offset)
    for ch in anims[clip]["channels"]:
        s = anims[clip]["samplers"][ch["sampler"]]
        _, t = acc(s["input"])
        off, v = acc(s["output"])
        tracks[(ch["target"]["node"], ch["target"]["path"])] = (
            t[:, 0],
            v.copy(),
            off,
            s.get("interpolation", "LINEAR"),
        )
    first = {}
    for ch in anims[pose]["channels"]:
        if ch["target"]["path"] == "rotation":
            first[ch["target"]["node"]] = acc(anims[pose]["samplers"][ch["sampler"]]["output"])[1][0]
    times = tracks[(name[bones[0]], "rotation")][0]
    for bn in bones:
        tr = tracks[(name[bn], "rotation")]
        assert tr[3] == "LINEAR" and np.array_equal(tr[0], times), bn + ": needs the same LINEAR keys as " + bones[0]

    def at(tr, k):  # a track's value at key k's time (glTF LINEAR / STEP)
        tt, v, _, how = tr
        x = times[k]
        i = int(np.searchsorted(tt, x, side="right")) - 1
        if i < 0:
            return v[0]
        if i >= len(tt) - 1 or how == "STEP":
            return v[min(i, len(tt) - 1)]
        f = (x - tt[i]) / (tt[i + 1] - tt[i])
        return v[i] * (1 - f) + v[i + 1] * f

    rest = {
        i: (nd.get("translation", [0, 0, 0]), nd.get("rotation", [0, 0, 0, 1]), nd.get("scale", [1, 1, 1]))
        for i, nd in enumerate(nodes)
    }

    def local(i, k, over):
        t, r, s = rest[i]
        if (i, "translation") in tracks:
            t = at(tracks[(i, "translation")], k)
        if (i, "rotation") in tracks:
            r = at(tracks[(i, "rotation")], k)
            r = r / np.linalg.norm(r)
        if (i, "scale") in tracks:
            s = at(tracks[(i, "scale")], k)
        if i in over:
            r = over[i]
        return trs(t, r, s)

    def world(i, k, over, memo):
        if i not in memo:
            memo[i] = (world(par[i], k, over, memo) if i in par else np.eye(4)) @ local(i, k, over)
        return memo[i]

    def gap(k, amt):
        over = {}
        for bn in bones:
            i = name[bn]
            over[i] = slerp(tracks[(i, "rotation")][1][k], first.get(i, rest[i][1]), amt)
        memo = {}
        hy = world(name[head], k, over, memo)[1, 3]
        return hy - max(world(name[h], k, over, memo)[1, 3] for h in hands)

    need = np.zeros(len(times))
    before = []
    for k in range(len(times)):
        before.append(gap(k, 0.0))
        if before[-1] >= margin:
            continue
        lo, hi = 0.0, 1.0
        if gap(k, 1.0) < margin:
            need[k] = 1.0
            continue
        for _ in range(18):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if gap(k, mid) < margin else (lo, mid)
        need[k] = hi
    wide = np.array([need[max(0, k - 2) : k + 3].max() for k in range(len(need))])
    smooth = np.convolve(np.pad(wide, 2, mode="edge"), np.array([1, 2, 3, 2, 1]) / 9.0, "valid")
    amt = np.maximum(wide, smooth)
    for bn in bones:
        i = name[bn]
        _, v, off, how = tracks[(i, "rotation")]
        nv = np.array([slerp(v[k], first.get(i, rest[i][1]), amt[k]) for k in range(len(times))], np.float32)
        b[off : off + nv.nbytes] = nv.tobytes()
        tracks[(i, "rotation")] = (times, nv, off, how)
    after = [gap(k, 0.0) for k in range(len(times))]
    open(out, "wb").write(bytes(b))
    print(
        "glb_clip_hands_cap: %s, %d keys: hands below %s min %.3f -> %.3f (margin %.3f), max pull %.2f"
        % (clip, len(times), head, min(before), min(after), margin, amt.max())
    )


if __name__ == "__main__":
    main()
