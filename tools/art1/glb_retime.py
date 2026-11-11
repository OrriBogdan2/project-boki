"""Re-times one clip of a .glb with no Blender: every track is sampled through a piecewise-linear time warp at 60 fps
(rotations by slerp, the rest linear), so a fast move spreads over more frames while the clip keeps its length. The
old key data stays in the file unused; the new keys are appended.
Run: python3 tools/art1/glb_retime.py <glb> <clip> <new:old>[,<new:old>...] [out.glb]
  e.g. lmb_punch 0:0,0.09:0.05,0.14:0.12  (the end maps to itself; the pose the clip had at 0.05 s now arrives at 0.09 s; the end keeps its time)"""
import math
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write

STEP = 1.0 / 60.0


def slerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0.0:
        b, d = [-x for x in b], -d
    if d > 0.9995:
        q = [x + (y - x) * t for x, y in zip(a, b)]
    else:
        th = math.acos(d)
        s = math.sin(th)
        wa, wb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
        q = [x * wa + y * wb for x, y in zip(a, b)]
    n = math.sqrt(sum(x * x for x in q))
    return [x / n for x in q]


def warp(anchors, t):
    for (n0, o0), (n1, o1) in zip(anchors, anchors[1:]):
        if t <= n1:
            return o0 + (o1 - o0) * (t - n0) / (n1 - n0)
    return anchors[-1][1]


def floats(j, b, i, n):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return struct.unpack("<%df" % n, b[off:off + 4 * n])


def append(j, b, vals, typ, lo=None):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": 4 * len(vals)})
    b.extend(struct.pack("<%df" % len(vals), *vals))
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(vals) // {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[typ], "type": typ}
    if lo:
        ac["min"], ac["max"] = [lo[0]], [lo[1]]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def retime(j, b, clip, anchors):
    anim = next(a for a in j["animations"] if a["name"] == clip)
    length = anchors[-1][0]
    times = [min(i * STEP, length) for i in range(int(round(length / STEP)) + 1)]
    if times[-1] < length - 1e-6:
        times.append(length)
    new_in = append(j, b, times, "SCALAR", (times[0], times[-1]))
    for sm in anim["samplers"]:
        n_in = j["accessors"][sm["input"]]["count"]
        ts = floats(j, b, sm["input"], n_in)
        typ = j["accessors"][sm["output"]]["type"]
        w = {"VEC3": 3, "VEC4": 4}[typ]
        vs = floats(j, b, sm["output"], n_in * w)
        out = []
        for t in times:
            o = min(max(warp(anchors, t), ts[0]), ts[-1])
            k = max(i for i in range(n_in) if ts[i] <= o + 1e-9)
            k1 = min(k + 1, n_in - 1)
            f = 0.0 if k1 == k else (o - ts[k]) / (ts[k1] - ts[k])
            a, c = vs[k * w:k * w + w], vs[k1 * w:k1 * w + w]
            out.extend(slerp(a, c, f) if w == 4 else [x + (y - x) * f for x, y in zip(a, c)])
        sm["input"] = new_in
        sm["output"] = append(j, b, out, typ)
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)


if __name__ == "__main__":
    path, clip, spec = sys.argv[1:4]
    glb, binary = read(path)
    first = next(a for a in glb["animations"] if a["name"] == clip)["samplers"][0]["input"]
    end = glb["accessors"][first]["max"][0]
    anchors = [tuple(float(x) for x in p.split(":")) for p in spec.split(",")] + [(end, end)]
    retime(glb, binary, clip, anchors)
    write(sys.argv[4] if len(sys.argv) > 4 else path, glb, binary)
    print("retimed", clip, "length", end)
