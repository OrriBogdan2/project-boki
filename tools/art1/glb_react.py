"""Re-keys one clip of a .glb with no Blender, for the hit reactions (docs/art/REACT_AUDIT.md). Every track of the clip
is resampled at 60 fps like glb_retime.py; the old key data stays in the file unused.
Run: python3 tools/art1/glb_react.py <glb> <clip> scale <factor> [<bone>,...]
       every listed bone's travel from its first key is scaled (rotations by slerp past the key), all bones if none
     python3 tools/art1/glb_react.py <glb> <clip> nudge <bone> <x,y,z deg> <peak_s> [<ease>]
       a rotation bump on the bone's own axes: nothing at 0, full at peak_s, back to nothing by the end along
       1 - u^ease (ease 2: a heavy body carries the hit a while; 0.5: a light one snaps back)"""
import math
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write
from glb_retime import STEP, append, floats, slerp


def _quat(deg):
    x, y, z = (math.radians(d) for d in deg)
    cx, sx, cy, sy, cz, sz = math.cos(x / 2), math.sin(x / 2), math.cos(y / 2), math.sin(y / 2), math.cos(z / 2), math.sin(z / 2)
    return [sx * cy * cz + cx * sy * sz, cx * sy * cz - sx * cy * sz, cx * cy * sz - sx * sy * cz, cx * cy * cz + sx * sy * sz]


def _mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def _tracks(j, b, anim, times):
    """Every sampler of the clip resampled at `times`: (channel, type, [value per time])."""
    names = [n.get("name") for n in j["nodes"]]
    out = []
    for ch in anim["channels"]:
        sm = anim["samplers"][ch["sampler"]]
        n_in = j["accessors"][sm["input"]]["count"]
        ts = floats(j, b, sm["input"], n_in)
        typ = j["accessors"][sm["output"]]["type"]
        w = {"VEC3": 3, "VEC4": 4}[typ]
        vs = floats(j, b, sm["output"], n_in * w)
        vals = []
        for t in times:
            o = min(max(t, ts[0]), ts[-1])
            k = max(i for i in range(n_in) if ts[i] <= o + 1e-9)
            k1 = min(k + 1, n_in - 1)
            f = 0.0 if k1 == k else (o - ts[k]) / (ts[k1] - ts[k])
            a, c = vs[k * w:k * w + w], vs[k1 * w:k1 * w + w]
            vals.append(slerp(a, c, f) if w == 4 else [x + (y - x) * f for x, y in zip(a, c)])
        out.append((ch, names[ch["target"]["node"]], typ, vals))
    return out


def _store(j, b, anim, times, tracks):
    new_in = append(j, b, times, "SCALAR", (times[0], times[-1]))
    for ch, _, typ, vals in tracks:
        sm = anim["samplers"][ch["sampler"]]
        sm["input"] = new_in
        sm["output"] = append(j, b, [x for v in vals for x in v], typ)
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)


def rekey(j, b, clip, edit):
    anim = next(a for a in j["animations"] if a["name"] == clip)
    length = max(j["accessors"][sm["input"]]["max"][0] for sm in anim["samplers"])
    times = [min(i * STEP, length) for i in range(int(round(length / STEP)) + 1)]
    if times[-1] < length - 1e-6:
        times.append(length)
    tracks = _tracks(j, b, anim, times)
    for ch, bone, typ, vals in tracks:
        edit(ch["target"]["path"], bone, typ, times, vals, length)
    _store(j, b, anim, times, tracks)
    return length


def scale(factor, bones):
    def edit(path, bone, typ, times, vals, length):
        if bones and bone not in bones or path == "scale":
            return
        v0 = vals[0]
        for i, v in enumerate(vals):
            vals[i] = slerp(v0, v, factor) if typ == "VEC4" else [a + (c - a) * factor for a, c in zip(v0, v)]
    return edit


def nudge(bone, deg, peak, ease):
    def edit(path, b, typ, times, vals, length):
        if b != bone or path != "rotation":
            return
        for i, t in enumerate(times):
            k = t / peak if t < peak else 1.0 - ((t - peak) / max(length - peak, 1e-6)) ** ease
            vals[i] = _mul(vals[i], _quat([d * max(k, 0.0) for d in deg]))
    return edit


if __name__ == "__main__":
    path, clip, op = sys.argv[1:4]
    glb, binary = read(path)
    if op == "scale":
        edit = scale(float(sys.argv[4]), sys.argv[5].split(",") if len(sys.argv) > 5 else [])
    else:
        edit = nudge(sys.argv[4], [float(x) for x in sys.argv[5].split(",")], float(sys.argv[6]),
                     float(sys.argv[7]) if len(sys.argv) > 7 else 2.0)
    print(op, clip, "length", rekey(glb, binary, clip, edit))
    write(path, glb, binary)
