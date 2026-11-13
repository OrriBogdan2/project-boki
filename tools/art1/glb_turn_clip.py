"""Adds a diagonal loop to a .glb: a shipped loop turned about the vertical through the armature origin, its root (and so
the legs and their steps) turned, the hips turned back so the chest keeps the source's facing. Every key stays as timed,
so the new loop has its source's length and strike and keeps time with it in a synced ring. No Blender: for a rig the
gait recipe can't step (Albert: 14 cm legs under hips 9 cm up). The model faces -Z, so +deg turns the loop to his left
(fl from f at 45, bl from b at -45). A clip of the same name is replaced; the rest of the file stays byte for byte.
Run: python3 tools/art1/glb_turn_clip.py <model.glb> <name>=<source>:<deg>[,...]"""
import math
import sys

import numpy as np

from glb_add_clips import read, write

COMPONENTS = {"VEC3": 3, "VEC4": 4}


def q_mul(a, b):
    """Hamilton product of xyzw quaternion rows."""
    x1, y1, z1, w1 = a.T
    x2, y2, z2, w2 = b.T
    return np.stack([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2], -1)


def q_inv(q):
    return q * np.array([-1.0, -1.0, -1.0, 1.0])


def output(j, bin_, sampler):
    """A sampler's output keys as float rows."""
    a = j["accessors"][sampler["output"]]
    v = j["bufferViews"][a["bufferView"]]
    at = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = COMPONENTS[a["type"]]
    return np.frombuffer(bytes(bin_[at:at + a["count"] * n * 4]), dtype=np.float32).reshape(a["count"], n).astype(float)


def set_output(j, bin_, sampler, rows):
    """Appends `rows` to the buffer as a new accessor and points the sampler's output at it."""
    data = np.ascontiguousarray(rows, dtype=np.float32)
    bin_ += b"\0" * (-len(bin_) % 4)
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(bin_), "byteLength": data.nbytes})
    bin_ += data.tobytes()
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(data),
                           "type": "VEC4" if data.shape[1] == 4 else "VEC3"})
    sampler["output"] = len(j["accessors"]) - 1


def turn(j, bin_, name, source, deg):
    src = next(a for a in j["animations"] if a["name"] == source)
    clip = {"name": name, "channels": [dict(c, target=dict(c["target"])) for c in src["channels"]],
            "samplers": [dict(s) for s in src["samplers"]]}
    sampler = {(j["nodes"][c["target"]["node"]]["name"], c["target"]["path"]): clip["samplers"][c["sampler"]]
               for c in clip["channels"]}
    half = math.radians(deg) / 2.0
    up = np.array([0.0, math.sin(half), 0.0, math.cos(half)])
    root_q = output(j, bin_, sampler["root", "rotation"])
    turned_q = q_mul(np.tile(up, (len(root_q), 1)), root_q)
    hips_q = output(j, bin_, sampler["hips", "rotation"])     # (keyed with the root: one key list per clip)
    set_output(j, bin_, sampler["hips", "rotation"], q_mul(q_inv(turned_q), q_mul(root_q, hips_q)))
    set_output(j, bin_, sampler["root", "rotation"], turned_q)
    root_t = output(j, bin_, sampler["root", "translation"])
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    set_output(j, bin_, sampler["root", "translation"],
               np.stack([c * root_t[:, 0] + s * root_t[:, 2], root_t[:, 1], c * root_t[:, 2] - s * root_t[:, 0]], -1))
    j["animations"] = [a for a in j["animations"] if a["name"] != name] + [clip]


def main():
    j, bin_ = read(sys.argv[1])
    for spec in sys.argv[2].split(","):
        name, rest = spec.split("=")
        source, deg = rest.split(":")
        turn(j, bin_, name, source, float(deg))
        print("TURNED %s from %s, %s deg" % (name, source, deg))
    write(sys.argv[1], j, bin_)


if __name__ == "__main__":
    main()
