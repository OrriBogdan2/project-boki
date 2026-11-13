"""Grimble's Barge as one burst: re-keys the glb's `lunge` clip and adds `lunge_out`, with no Blender (the clips are
baked tracks on the finished rig, so any build of the model takes them; the .blend is not needed).
Before: each shove folded into the junk ball, rolled, popped open standing and folded again 0.1 s later (a stutter).
Now: `lunge` folds in (0.033 s), the shove rolls the ball (to 0.167 s, the measured 0.16 s shove), the ball keeps
rolling through the 0.22 s gap and holds closed from 0.40 s. Its closed pose is the pose at 0.033 s, so a chained
shove joins the clip there (DredgeKit.FOLD_T) and the ball never opens between shoves. `lunge_out` is the recovery,
played once after the last shove (0.17 s: the ball stops and pops open).
Run once on the glb as committed before this change (git checkout it to redo):
    python3 tools/art1/grimble_barge_clips.py art/wardens/dredge/dredge.glb [out.glb]"""
import json
import math
import struct
import sys

FPS = 60.0
FOLD_T = 1.0 / 30.0       # s: the old clip's second frame, the ball closed (= DredgeKit.FOLD_T)
SHOVE_END = 0.167         # s: the end of the shove (the measured 0.16 s, on a frame)
LUNGE_T = 0.40            # s: shove 0.167 + the gap 0.22 + a frame; the ball holds closed from here
SHOVE_TURNS = 1.5         # ball turns during the shove (about 1.2 rad a 60 fps frame: under a half turn, so it reads)
GAP_TURNS = 1.5           # ball turns while it slows through the gap, so the clip ends on a whole 3 turns
OUT_T = 10.0 / FPS        # s: the recovery
OUT_KEYS = (0.0, 0.0417, 0.1, OUT_T)   # old frames 8-11 (closed, closed, half open, standing) spread over it


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    at = 20 + n
    m = struct.unpack("<I", b[at:at + 4])[0]
    return j, bytearray(b[at + 8:at + 8 + m])


def write(path, j, bin_):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    bin_ += b"\0" * (-len(bin_) % 4)
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\0"))
        f.write(bin_)


def values(j, bin_, i):
    ac = j["accessors"][i]
    v = j["bufferViews"][ac["bufferView"]]
    nc = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
    o = v.get("byteOffset", 0) + ac.get("byteOffset", 0)
    flat = struct.unpack("<%df" % (ac["count"] * nc), bin_[o:o + 4 * ac["count"] * nc])
    return [flat[k * nc:(k + 1) * nc] for k in range(ac["count"])]


def mix(a, b, u, quat):
    if quat:
        if sum(x * y for x, y in zip(a, b)) < 0:
            b = [-x for x in b]
        r = [x + (y - x) * u for x, y in zip(a, b)]
        n = math.sqrt(sum(x * x for x in r))
        return tuple(x / n for x in r)
    return tuple(x + (y - x) * u for x, y in zip(a, b))


def sample(times, rows, t, quat):
    """The track's value at t: linear between its keys, held outside them."""
    if t <= times[0]:
        return rows[0]
    for k in range(1, len(times)):
        if t <= times[k]:
            return mix(rows[k - 1], rows[k], (t - times[k - 1]) / (times[k] - times[k - 1]), quat)
    return rows[-1]


def ball_turn(spin):
    """The ball's rotation for a roll of `spin` rad (0 = the old clip's rest): a half turn about Y, then the roll about X."""
    return (0.0, -math.cos(spin / 2), math.sin(spin / 2), 0.0)


def lunge_spin(t):
    """Roll angle at clip time t: 0.3 rad as the ball closes, fast through the shove, easing to a stop at 3 whole turns."""
    if t <= FOLD_T:
        return 0.3 * t / FOLD_T
    if t <= SHOVE_END:
        return 0.3 + SHOVE_TURNS * math.tau * (t - FOLD_T) / (SHOVE_END - FOLD_T)
    u = min(1.0, (t - SHOVE_END) / (LUNGE_T - SHOVE_END))
    return 0.3 + SHOVE_TURNS * math.tau + GAP_TURNS * math.tau * (1.0 - (1.0 - u) ** 2)


def out_spin(t):
    """The ball slows from the closed pose's 0.3 rad to a whole turn (the standing pose's) as it opens."""
    u = t / OUT_T
    return 0.3 + (math.tau - 0.3) * (1.0 - (1.0 - u) ** 2)


def add(j, bin_, rows, kind, with_range):
    """Append float rows to the binary as a new accessor and return its index."""
    nc = len(rows[0])
    while len(bin_) % 4:
        bin_.append(0)
    off = len(bin_)
    for r in rows:
        bin_ += struct.pack("<%df" % nc, *r)
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(rows) * nc * 4})
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(rows), "type": kind}
    if with_range:
        ac["min"] = [min(r[0] for r in rows)]
        ac["max"] = [max(r[0] for r in rows)]
    j["accessors"].append(ac)
    j["buffers"][0]["byteLength"] = len(bin_)
    return len(j["accessors"]) - 1


def build(j, bin_):
    old = next(a for a in j["animations"] if a["name"] == "lunge")
    ball = next(i for i, n in enumerate(j["nodes"]) if n.get("name") == "ball")
    times = [k[0] for k in values(j, bin_, old["samplers"][0]["input"])]
    tracks = [(ch["target"], values(j, bin_, old["samplers"][ch["sampler"]]["output"])) for ch in old["channels"]]

    def clip(name, length, pose):
        frames = [i / FPS for i in range(int(round(length * FPS)) + 1)]
        inp = add(j, bin_, [(t,) for t in frames], "SCALAR", True)
        a = {"name": name, "channels": [], "samplers": []}
        for tgt, rows in tracks:
            quat = tgt["path"] == "rotation"
            rolls = tgt["node"] == ball and quat
            out = [pose(rows, quat, rolls, t) for t in frames]
            a["samplers"].append({"input": inp, "interpolation": "LINEAR", "output": add(j, bin_, out, "VEC4" if quat else "VEC3", False)})
            a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": dict(tgt)})
        return a

    def lunge(rows, quat, rolls, t):
        return ball_turn(lunge_spin(t)) if rolls else sample(times, rows, min(t, FOLD_T), quat)

    def out(rows, quat, rolls, t):
        return ball_turn(out_spin(t)) if rolls else sample(list(OUT_KEYS), rows[8:12], t, quat)

    made = [clip("lunge", LUNGE_T, lunge), clip("lunge_out", OUT_T, out)]
    j["animations"] = [a for a in j["animations"] if a["name"] not in ("lunge", "lunge_out")] + made


if __name__ == "__main__":
    j, bn = read(sys.argv[1])
    build(j, bn)
    write(sys.argv[2] if len(sys.argv) > 2 else sys.argv[1], j, bn)
