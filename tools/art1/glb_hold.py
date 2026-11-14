"""Holds a baked clip on its pose at <at> s for <secs> s in a .glb, the keys after <at> played that much later: the baked
twin of a hold key added to a *_clips.py table, for when the rig's .blend is not at hand. Everything else in the file
stays byte for byte; the clip's old accessors are left unused, as glb_add_clips.py does.
Run: python3 tools/art1/glb_hold.py <target.glb> <clip> <at> <secs> [out.glb]"""
import math
import struct
import sys

from glb_add_clips import read, write


def slerp(a, b, u):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0.0:
        b, d = [-x for x in b], -d
    if d > 0.9995:
        q = [x + (y - x) * u for x, y in zip(a, b)]
    else:
        th = math.acos(d)
        s = math.sin(th)
        q = [(math.sin((1 - u) * th) * x + math.sin(u * th) * y) / s for x, y in zip(a, b)]
    n = math.sqrt(sum(x * x for x in q))
    return [x / n for x in q]


def sample(ts, vs, t, rot):
    """The clip's value at t (glTF LINEAR: slerp for rotations)."""
    i = max(k for k in range(len(ts)) if ts[k] <= t)
    if i + 1 >= len(ts) or ts[i] == t:
        return list(vs[i])
    u = (t - ts[i]) / (ts[i + 1] - ts[i])
    if rot:
        return slerp(vs[i], vs[i + 1], u)
    return [x + (y - x) * u for x, y in zip(vs[i], vs[i + 1])]


def floats(j, b, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    w = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    flat = struct.unpack_from("<%df" % (ac["count"] * w), b, off)
    return [list(flat[k * w:(k + 1) * w]) for k in range(ac["count"])], ac["type"]


def put(j, b, rows, typ):
    b.extend(b"\0" * (-len(b) % 4))
    data = struct.pack("<%df" % sum(len(r) for r in rows), *[x for r in rows for x in r])
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(data)})
    b.extend(data)
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(rows), "type": typ}
    if typ == "SCALAR":
        ac["min"], ac["max"] = [min(r[0] for r in rows)], [max(r[0] for r in rows)]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def hold(j, b, clip, at, secs):
    a = next(x for x in j["animations"] if x["name"] == clip)
    inputs = {}
    for sm in a["samplers"]:
        ch = next(c for c in a["channels"] if a["samplers"][c["sampler"]] is sm)
        ts = [r[0] for r in floats(j, b, sm["input"])[0]]
        vs, typ = floats(j, b, sm["output"])
        v = sample(ts, vs, at, ch["target"]["path"] == "rotation")
        before = [k for k in range(len(ts)) if ts[k] < at - 1e-6]
        after = [k for k in range(len(ts)) if ts[k] > at + 1e-6]
        nt = [ts[k] for k in before] + [at, at + secs] + [ts[k] + secs for k in after]
        nv = [vs[k] for k in before] + [v, v] + [vs[k] for k in after]
        key = tuple(nt)
        if key not in inputs:
            inputs[key] = put(j, b, [[t] for t in nt], "SCALAR")
        sm["input"], sm["output"] = inputs[key], put(j, b, nv, typ)
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
    return max(max(k) for k in inputs)


if __name__ == "__main__":
    target, clip, at, secs = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
    out = sys.argv[5] if len(sys.argv) > 5 else target
    j, b = read(target)
    end = hold(j, b, clip, at, secs)
    write(out, j, b)
    print("held", clip, "at", at, "for", secs, "length", round(end, 3))
