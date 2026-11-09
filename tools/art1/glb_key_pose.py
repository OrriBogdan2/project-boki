"""Re-keys one pose of a clip in a .glb with no Blender: a bone swings so that the line from it to an end bone points along a
model-space direction at a peak time (an arm that reaches where the match camera can see it, a torso that leans into the
strike). The swing eases in and out over [t0, t1] and is written onto the bone's local rotation track, so the elbow bend,
the twist and everything else the clip keyed stay. Every bone of a clip is keyed at the same times.
Run: python3 tools/art1/glb_key_pose.py <glb> <clip> <bone> <end> <t0> <peak> <t1> <dx,dy,dz> [<bone> <end> ...same args...]
Directions are glTF model space: +Y up, -Z the Hero's front, +X its right. Several swings may follow one another."""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write  # noqa: E402


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
            w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def qrot(q, v):
    return qmul(qmul(q, np.append(v, 0.0)), qinv(q))[:3]


def ease(t, t0, peak, t1):
    if t <= t0 or t >= t1:
        return 0.0
    u = (t - t0) / (peak - t0) if t < peak else (t1 - t) / (t1 - peak)
    return u * u * (3.0 - 2.0 * u)


def offset(j, accessor):
    ac = j["accessors"][accessor]
    return j["bufferViews"][ac["bufferView"]].get("byteOffset", 0) + ac.get("byteOffset", 0)


class Clip:
    def __init__(self, j, b, clip):
        self.j, self.b = j, b
        self.nodes = j["nodes"]
        self.names = {n.get("name"): i for i, n in enumerate(self.nodes)}
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        anim = next(a for a in j["animations"] if a["name"] == clip)
        self.rot, self.pos = {}, {}
        for ch in anim["channels"]:
            s = anim["samplers"][ch["sampler"]]
            where = self.rot if ch["target"]["path"] == "rotation" else self.pos if ch["target"]["path"] == "translation" else None
            if where is not None:
                where[ch["target"]["node"]] = (offset(j, s["input"]), offset(j, s["output"]), j["accessors"][s["output"]]["count"])

    def get(self, table, node, k, size, rest):
        if node not in table:
            return np.array(self.nodes[node].get(rest, [0, 0, 0, 1][:size]), float)
        o = table[node][1] + 4 * size * k
        return np.frombuffer(bytes(self.b[o:o + 4 * size]), "<f4").astype(float)

    def world(self, node, k):
        """(rotation, position) of a node in model space at key k."""
        q = self.get(self.rot, node, k, 4, "rotation")
        p = self.get(self.pos, node, k, 3, "translation")
        if node not in self.parent:
            return q, p
        pq, pp = self.world(self.parent[node], k)
        return qmul(pq, q), pp + qrot(pq, p)

    def swing(self, bone, end, t0, peak, t1, direction):
        node = self.names[bone]
        toff, voff, count = self.rot[node]
        times = np.frombuffer(bytes(self.b[toff:toff + 4 * count]), "<f4")
        d = np.asarray(direction, float) / np.linalg.norm(direction)
        for k in range(count):
            w = ease(float(times[k]), t0, peak, t1)
            if w == 0.0:
                continue
            pq, _ = self.world(self.parent[node], k)
            v = self.world(self.names[end], k)[1] - self.world(node, k)[1]
            v = v / np.linalg.norm(v)
            axis = np.cross(v, d)
            sin = np.linalg.norm(axis)
            if sin < 1e-6:
                continue
            half = np.arctan2(sin, float(v @ d)) * w / 2.0
            delta = np.append(axis / sin * np.sin(half), np.cos(half))
            q = qmul(qmul(qmul(qinv(pq), delta), pq), self.get(self.rot, node, k, 4, "rotation"))
            self.b[voff + 16 * k:voff + 16 * k + 16] = (q / np.linalg.norm(q)).astype("<f4").tobytes()


if __name__ == "__main__":
    glb, clip = sys.argv[1:3]
    rest = sys.argv[3:]
    j, b = read(glb)
    c = Clip(j, b, clip)
    for i in range(0, len(rest), 6):
        bone, end, t0, peak, t1, direction = rest[i:i + 6]
        c.swing(bone, end, float(t0), float(peak), float(t1), [float(x) for x in direction.split(",")])
    write(glb, j, b)
