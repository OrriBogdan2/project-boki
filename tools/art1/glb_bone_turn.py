"""Turns one bone through part of one clip of a .glb with no Blender: a rotation about an axis given in the model's own
frame (y up, the Hero faces -z), ramping in from t_in, full at t_peak, gone by t_out, so a strike's arm can land further
out while the clip keeps every other beat. The bone's keys are rewritten in place (every clip is keyed at 30 fps).
Run: python3 tools/art1/glb_bone_turn.py <glb> <clip> <bone> <x,y,z> <deg> <t_in:t_full[:t_held]:t_out> [out.glb]
  e.g. lmb_slam upper_arm.R 1,0,0 -14 0.0:0.067:0.2:0.3  (the arm pitched up about x, full from the impact to 0.2 s)"""
import math
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write


def floats(j, b, i, n):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return list(struct.unpack("<%df" % n, b[off:off + 4 * n]))


def store(j, b, i, vals):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    b[off:off + 4 * len(vals)] = struct.pack("<%df" % len(vals), *vals)


def qmul(a, c):
    ax, ay, az, aw = a
    cx, cy, cz, cw = c
    return [aw * cx + ax * cw + ay * cz - az * cy, aw * cy - ax * cz + ay * cw + az * cx,
            aw * cz + ax * cy - ay * cx + az * cw, aw * cw - ax * cx - ay * cy - az * cz]


def qinv(q):
    return [-q[0], -q[1], -q[2], q[3]]


def axis_angle(axis, deg):
    n = math.sqrt(sum(x * x for x in axis))
    s = math.sin(math.radians(deg) * 0.5)
    return [axis[0] / n * s, axis[1] / n * s, axis[2] / n * s, math.cos(math.radians(deg) * 0.5)]


def sample(j, b, anim, node, t):
    """The node's rotation at time t: its clip track held at the nearest key, else its rest."""
    for c in anim["channels"]:
        if c["target"]["node"] == node and c["target"]["path"] == "rotation":
            sm = anim["samplers"][c["sampler"]]
            n = j["accessors"][sm["input"]]["count"]
            ts = floats(j, b, sm["input"], n)
            k = min(range(n), key=lambda i: abs(ts[i] - t))
            return floats(j, b, sm["output"], n * 4)[k * 4:k * 4 + 4]
    return j["nodes"][node].get("rotation", [0, 0, 0, 1])


def tent(t, t_in, t_full, t_held, t_out):
    if t <= t_in or t >= t_out:
        return 0.0
    if t_full <= t <= t_held:
        return 1.0
    k = (t - t_in) / (t_full - t_in) if t < t_full else (t_out - t) / (t_out - t_held)
    return k * k * (3 - 2 * k)


def turn(j, b, clip, bone, axis, deg, window):
    anim = next(a for a in j["animations"] if a["name"] == clip)
    names = [n.get("name") for n in j["nodes"]]
    parent = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    node = names.index(bone)
    ch = next(c for c in anim["channels"] if c["target"]["node"] == node and c["target"]["path"] == "rotation")
    sm = anim["samplers"][ch["sampler"]]
    if [c["sampler"] for c in anim["channels"]].count(ch["sampler"]) > 1:
        sys.exit("%s's rotation sampler in %s is shared" % (bone, clip))
    n = j["accessors"][sm["input"]]["count"]
    ts = floats(j, b, sm["input"], n)
    vs = floats(j, b, sm["output"], n * 4)
    for k in range(n):
        w = tent(ts[k], *window)
        if w <= 0.0:
            continue
        # the parent's rotation in the model's frame at this key: the chain above the bone, posed by the clip
        p = [0, 0, 0, 1]
        up = parent.get(node)
        while up is not None:
            p = qmul(sample(j, b, anim, up, ts[k]), p)
            up = parent.get(up)
        d = axis_angle(axis, deg * w)
        local = qmul(qmul(qinv(p), d), p)      # the model-frame turn seen from the parent
        q = qmul(local, vs[k * 4:k * 4 + 4])
        m = math.sqrt(sum(x * x for x in q))
        vs[k * 4:k * 4 + 4] = [x / m for x in q]
    store(j, b, sm["output"], vs)


if __name__ == "__main__":
    path, clip, bone, axis, deg, window = sys.argv[1:7]
    glb, binary = read(path)
    w = [float(x) for x in window.split(":")]
    if len(w) == 3:
        w.insert(2, w[1])
    turn(glb, binary, clip, bone, [float(x) for x in axis.split(",")], float(deg), w)
    write(sys.argv[7] if len(sys.argv) > 7 else path, glb, binary)
    print("turned", bone, "in", clip, deg, "deg about", axis, "over", window)
