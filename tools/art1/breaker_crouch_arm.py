"""Albert's crouch loops with the hammer forearm held on one side of a half turn off its rest. Godot 4.6 blends a bone as
a turn off its rest, and crouch_f/b/l/r/bl/br swing forearm.R through 179..189 deg of it (the idle holds 177): across that
half turn a partial blend weight flips the arm (every crouch start and stop snapped, docs/art/LOCO_DIR.md). Each key past
LIMIT is turned back to it about its own axis (at most 12 deg of forearm roll on a fist that hardly moves). Nothing else
in the .glb changes, byte for byte.
Run: python3 tools/art1/breaker_crouch_arm.py art/wardens/breaker/breaker.glb"""
import math
import sys

import numpy as np

from glb_add_clips import read, write

CLIPS = ("crouch_f", "crouch_b", "crouch_l", "crouch_r", "crouch_bl", "crouch_br")   # (the four loops share one track)
NODE, LIMIT = "forearm.R", math.radians(177.0)   # the idle's own turn off the rest; the loops start past it


def mul(a, b):
    """Quaternions (x, y, z, w) a * b."""
    av, bv = a[:3], b[:3]
    return np.append(a[3] * bv + b[3] * av + np.cross(av, bv), a[3] * b[3] - av @ bv)


def turn_off(q, rest):
    """The key's turn off the rest in the form with w > 0 (the way the idle holds it): its angle and axis."""
    d = mul(np.append(-rest[:3], rest[3]), q)
    d = d if d[3] >= 0 else -d
    return 2 * math.acos(min(1.0, d[3])), d[:3] / np.linalg.norm(d[:3])


def clamp(q, rest, idle_axis):
    """The key q with its turn off the rest at most LIMIT. A turn past a half turn reads, in that form, as the shorter
    turn about the opposite axis (189 deg about a is 171 about -a): the angle is taken about the idle's axis."""
    angle, axis = turn_off(q, rest)
    about = 1.0 if axis @ idle_axis >= 0 else -1.0
    if (angle if about > 0 else 2 * math.pi - angle) <= LIMIT:
        return q
    return mul(rest, np.append(idle_axis * math.sin(LIMIT / 2), math.cos(LIMIT / 2)))


def track(a, node, j, b):
    """The clip's rotation keys of the node, as float32 rows over its bytes: (rows, start, byte count)."""
    ch = next(c for c in a["channels"] if c["target"] == {"node": node, "path": "rotation"})
    ac = j["accessors"][a["samplers"][ch["sampler"]]["output"]]
    bv = j["bufferViews"][ac["bufferView"]]
    at = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return np.frombuffer(bytes(b[at:at + ac["count"] * 16]), np.float32).reshape(-1, 4).astype(np.float64), at, ac["count"] * 16


path = sys.argv[1]
j, b = read(path)
node = next(i for i, n in enumerate(j["nodes"]) if n.get("name") == NODE)
rest = np.array(j["nodes"][node]["rotation"], np.float64)
clips = {a["name"]: a for a in j["animations"]}
idle_axis = turn_off(track(clips["crouch_idle"], node, j, b)[0][0], rest)[1]
for name in CLIPS:
    keys, at, size = track(clips[name], node, j, b)
    out = np.array([clamp(q, rest, idle_axis) for q in keys], np.float32)
    print("%s %s: %d keys, %d clamped" % (name, NODE, len(keys), int((out != keys.astype(np.float32)).any(axis=1).sum())))
    b[at:at + size] = out.tobytes()
write(path, j, b)
