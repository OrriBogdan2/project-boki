"""Plants a rigged Boki's paws in its walk and run, in the .glb in place: while a paw is down it holds the ground
(as low as the leg reaches) and sweeps back at one steady speed, the same for every paw of the clip, so BokiRig's one
playback rate keeps it still (--boki-anim-audit). Each plant keeps its place in the stride and its reach; touch-down
and lift-off fall on whole keys. Between plants the paw eases forward at the clip's own height. The leg's joints are
re-solved per key (two-bone IK about the body's sideways axis, or swing and roll of a one-bone leg); the paw keeps
its turn in the world. Only the leg keys change; the mesh, atlas and other clips stay byte for byte.

    python3 tools/boki/plant_gait.py art/kin/<id>/<id>.glb walk run=1.3   (=: quicken, see plant())
build_boki.py runs it on export for a species whose clips module lists PLANT."""
import json
import struct
import sys

import numpy as np

BACK = 2              # model axis a paw sweeps along on the ground: +z (models face -z)
UP = 1
SIDEWAYS = np.array([1.0, 0.0, 0.0])      # the axis a leg swings along the body about
ALONG = np.array([0.0, 0.0, 1.0])         # the axis a leg rolls out to the side about
ITERS = 40            # IK steps per key
LIFT = 0.5            # of its own lift: a paw this low, moving back, is on the ground (the audit's PLANTED)
REACH = 0.97          # of the leg's length: the farthest a planted paw is from the hip (a knee never locks)
MAX_DUTY = 0.65       # of a stride: the longest a paw stays down
ARC = 0.6             # of its own lift: the least a swinging paw rises at the middle of its swing


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def quat_inv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def quat_axis(axis, angle):
    return np.concatenate([np.asarray(axis) * np.sin(angle / 2), [np.cos(angle / 2)]])


def quat_matrix(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def quat_rotate(q, v):
    return quat_mul(quat_mul(q, np.concatenate([v, [0.0]])), quat_inv(q))[:3]


class Glb:
    def __init__(self, path):
        self.path = path
        data = open(path, "rb").read()
        n = struct.unpack("<I", data[12:16])[0]
        self.head = data[:12]
        self.json_raw = data[12:20 + n]
        self.gltf = json.loads(data[20:20 + n])
        self.bin = bytearray(data[20 + n + 8:])
        self.bin_head = data[20 + n:20 + n + 8]
        self.nodes = self.gltf["nodes"]
        self.parent = {c: i for i, nd in enumerate(self.nodes) for c in nd.get("children", [])}
        self.by_name = {nd.get("name"): i for i, nd in enumerate(self.nodes)}

    def view(self, acc_i):
        acc = self.gltf["accessors"][acc_i]
        bv = self.gltf["bufferViews"][acc["bufferView"]]
        width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[acc["type"]]
        start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return np.frombuffer(self.bin, np.float32, acc["count"] * width, start).reshape(acc["count"], width)

    def write(self, acc_i, values):
        acc = self.gltf["accessors"][acc_i]
        bv = self.gltf["bufferViews"][acc["bufferView"]]
        start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        raw = np.asarray(values, np.float32).tobytes()
        self.bin[start:start + len(raw)] = raw

    def save(self):
        with open(self.path, "wb") as f:
            f.write(self.head + self.json_raw + self.bin_head + bytes(self.bin))


class Clip:
    """One clip's keys: per node and path, the (frames, n) values, and the accessors to write them back to."""

    def __init__(self, glb, name):
        self.glb = glb
        anim = next(a for a in glb.gltf["animations"] if a["name"] == name)
        self.keys = {}
        self.out = {}
        for ch in anim["channels"]:
            s = anim["samplers"][ch["sampler"]]
            k = (ch["target"]["node"], ch["target"]["path"])
            self.keys[k] = glb.view(s["output"]).copy()
            self.out[k] = s["output"]
        self.frames = len(glb.view(anim["samplers"][0]["input"]))

    def trs(self, node, f):
        nd = self.glb.nodes[node]
        out = []
        for key, rest in (("translation", [0, 0, 0]), ("rotation", [0, 0, 0, 1]), ("scale", [1, 1, 1])):
            keys = self.keys.get((node, key))
            # a channel the exporter left with fewer keys holds still
            out.append(np.asarray(nd.get(key, rest) if keys is None else keys[min(f, len(keys) - 1)], float))
        return out

    def world(self, node, f):
        """(position, turn) of the node in the model's frame at key f. The turn leaves out the squash a parent's
        scale keys add, which the position keeps."""
        chain = []
        while node is not None:
            chain.append(node)
            node = self.glb.parent.get(node)
        m, q = np.eye(4), np.array([0.0, 0, 0, 1])
        for n in reversed(chain):
            t, r, s = self.trs(n, f)
            local = np.eye(4)
            local[:3, :3] = quat_matrix(r) * s
            local[:3, 3] = t
            m = m @ local
            q = quat_mul(q, r)
        return m[:3, 3], q

    def save(self, nodes):
        for n in nodes:
            k = (n, "rotation")
            self.glb.write(self.out[k], self.keys[k])


def stances(z, y):
    """Each run of keys a paw is down: low (under LIFT of its lift) at both ends of a step that moves it back, as
    --boki-anim-audit counts a planted paw. A clip may hold more than one stride."""
    n = len(z)
    low = y <= y.min() + LIFT * (y.max() - y.min()) + 1e-4
    down = [low[k] and low[(k + 1) % n] and z[(k + 1) % n] > z[k] for k in range(n)]
    if all(down) or not any(down):
        return []
    first = next(k for k in range(n) if down[k] and not down[k - 1])
    runs = []
    for i in range(n):
        k = (first + i) % n
        if down[k] and not down[k - 1]:
            runs.append([k])
        if down[k]:
            runs[-1].append((k + 1) % n)
    return runs


def solve(clip, f, leg, target, start):
    """Turns the leg's joints until its paw is at target (its height and its place along the body), starting from
    the turns `start` that solved the key before, so the knee stays on its side. Returns the miss and the turns."""
    def at():
        return clip.world(leg.paw, f)[0][[UP, BACK]]

    def turn(node, axis, angle):
        q_parent = clip.world(clip.glb.parent[node], f)[1]
        k = (node, "rotation")
        clip.keys[k][f] = quat_mul(quat_axis(quat_rotate(quat_inv(q_parent), axis), angle), clip.keys[k][f])

    keep = clip.world(leg.paw, f)[1]
    goal = target[[UP, BACK]]
    total = np.array(start, float)
    for joint, angle in zip(leg.joints, total):
        turn(*joint, angle)
    for _ in range(ITERS):
        err = goal - at()
        if np.linalg.norm(err) < 1e-5:
            break
        jac = np.zeros((2, 2))
        for j, joint in enumerate(leg.joints):
            turn(*joint, 1e-4)
            jac[:, j] = (at() - goal + err) / 1e-4
            turn(*joint, -1e-4)
        step = np.clip(np.linalg.solve(jac.T @ jac + 1e-6 * np.eye(2), jac.T @ err), -0.2, 0.2)
        for joint, angle in zip(leg.joints, step):
            turn(*joint, angle)
        total += step
    if leg.paw in leg.keyed:
        q_parent = clip.world(clip.glb.parent[leg.paw], f)[1]
        clip.keys[(leg.paw, "rotation")][f] = quat_mul(quat_inv(q_parent), keep)
    return float(np.linalg.norm(goal - at())), total


def ease(x):
    return x * x * (3 - 2 * x)


class Leg:
    """One paw's chain and its path in the clip as baked: per key, the paw's and the hip's place in the model."""

    def __init__(self, clip, paw):
        g = clip.glb
        self.paw = paw
        lower = g.parent[paw]
        upper = g.parent[lower]
        n = clip.frames - 1
        self.path = np.array([clip.world(paw, f)[0] for f in range(n)])
        if "leg" in g.nodes[upper]["name"]:
            # hip and knee both swing it along the body; seen from the side it reaches as far as both bones are long
            self.joints = [(upper, SIDEWAYS), (lower, SIDEWAYS)]
            self.hip = np.array([clip.world(upper, f)[0] for f in range(n)])
            knee = clip.world(lower, 0)[0]
            side = [UP, BACK]
            long = np.linalg.norm((knee - self.hip[0])[side]) + np.linalg.norm((self.path[0] - knee)[side])
        else:
            # one bone to the paw: it swings along the body and rolls out to the side to lift (Mossgrade)
            self.joints = [(lower, SIDEWAYS), (lower, ALONG)]
            self.hip = np.array([clip.world(lower, f)[0] for f in range(n)])
            long = np.linalg.norm(self.path[0] - self.hip[0])
        self.reach = REACH * long
        self.keyed = [node for node in (upper, lower, paw)
                      if len(clip.keys.get((node, "rotation"), [])) == clip.frames]
        for node, _ in self.joints:
            assert node in self.keyed, "%s has a held key" % g.nodes[node]["name"]
        z, y = self.path[:, BACK], self.path[:, UP]
        runs = [d for d in stances(z, y) if len(d) >= 3]
        # (middle key, front z, back z) of each plant, and the model units per key it moves back at as baked
        self.plants = [((d[0] + (len(d) - 1) / 2) % n, z[d[0]], z[d[-1]]) for d in runs]
        self.sweeps = [(z[d[-1]] - z[d[0]]) / (len(d) - 1) for d in runs]
        self.lift = y.max() - y.min()
        self.ground = min((y[k] for d in runs for k in d), default=y.min())

    def settle(self, clip, f, target, before):
        """Solves key f from the clip's own pose and from the turns that solved the key before; keeps the one that
        reaches, and of two that do, the one nearer the key before (no knee flips between keys)."""
        rots = [(node, clip.keys[(node, "rotation")]) for node in self.keyed]
        baked = [r[f].copy() for _, r in rots]
        tries = []
        for start in (np.zeros(2), before):
            for (_, r), q in zip(rots, baked):
                r[f] = q
            miss, turns = solve(clip, f, self, target, start)
            prev = [r[f - 1] for _, r in rots]
            jump = sum(1.0 - abs(float(np.dot(r[f], q))) for (_, r), q in zip(rots, prev))
            tries.append((round(miss, 3), jump, turns, [r[f].copy() for _, r in rots]))
        miss, _, turns, keys = min(tries, key=lambda t: t[:2])
        for (_, r), q in zip(rots, keys):
            r[f] = q
        return miss, turns

    def floor(self, f, z):
        """The lowest the paw reaches at key f and z, with the leg not quite straight."""
        h = self.hip[f]
        return h[UP] - np.sqrt(max(self.reach ** 2 - (z - h[BACK]) ** 2, 0.0))

    def targets(self, n, speed):
        """Per key, where the paw goes: on the ground sweeping back at `speed` per key through each plant, eased
        forward through the air between plants."""
        period = n / len(self.plants)
        spans = []
        for mid, front, back in self.plants:
            # whole keys, so the touch-down and lift-off fall on a key and no sample straddles them
            length = max(2, min(round((back - front) / speed), int(MAX_DUTY * period)))
            start = round(mid - length / 2)
            sweep = speed * length
            centre = 0.5 * (front + back)
            spans.append((start, start + length, centre - sweep / 2, centre + sweep / 2))
        out = self.path.copy()
        for f in range(n):
            for i, (t0, t1, z0, z1) in enumerate(spans):
                u = (f - t0) % n
                if u <= t1 - t0:
                    z, y = z0 + speed * u, self.ground
                    break
                nt0, _, nz0, _ = spans[(i + 1) % len(spans)]
                gap = (nt0 - t1) % n
                v = (f - t1) % n
                if v < gap:
                    w = v / gap
                    # the clip's own height through the air, met to the ground at both ends, and at least an arc
                    y0, y1 = self.path[t1 % n, UP], self.path[nt0 % n, UP]
                    own = self.path[f, UP] + (self.ground - y0) * (1 - w) + (self.ground - y1) * w
                    # the key either side of the plant keeps its speed (a paw meets the ground already moving back)
                    if v == 1 or v == gap - 1 or gap < 4:
                        z = z1 + speed * v if v < gap / 2 else nz0 - speed * (gap - v)
                    else:
                        z = z1 + speed + (nz0 - z1 - 2 * speed) * ease((v - 1) / (gap - 2))
                    y = max(own, self.ground + ARC * self.lift * np.sin(np.pi * w))
                    break
            out[f, UP] = max(y, self.floor(f, z))
            out[f, BACK] = z
        return out


def plant(glb, name, quicken=1.0):
    """Re-keys one clip's legs. `quicken` scales the shared plant speed past the paws' own (a shorter plant at the
    same reach: a longer stride per step where BokiRig's MAX_CADENCE caps a short-stepping clip)."""
    clip = Clip(glb, name)
    n = clip.frames - 1               # the last key repeats the first
    legs = [Leg(clip, i) for i, nd in enumerate(glb.nodes) if "paw" in nd.get("name", "")]
    legs = [leg for leg in legs if leg.plants]
    # one speed (model units per key) for every paw: the median of their own sweeps
    speed = quicken * float(np.median([s for leg in legs for s in leg.sweeps]))
    worst = 0.0
    for leg in legs:
        aim = leg.targets(n, speed)
        turns = np.zeros(2)
        # around the loop from the middle of a plant, where the leg's pose is best defined
        first = int(leg.plants[0][0])
        for f in [(first + i) % n for i in range(n)]:
            miss, turns = leg.settle(clip, f, aim[f], turns)
            worst = max(worst, miss)
        for node in leg.keyed:
            clip.keys[(node, "rotation")][n] = clip.keys[(node, "rotation")][0]
        clip.save(leg.keyed)
    print("%s %s: %d paws planted, %.4f per key, worst miss %.4f" % (glb.path, name, len(legs), speed, worst))


def plant_file(path, clips):
    """clips: name -> quicken."""
    glb = Glb(path)
    for name, quicken in clips.items():
        plant(glb, name, quicken)
    glb.save()


def main():
    plant_file(sys.argv[1], {a.partition("=")[0]: float(a.partition("=")[2] or 1.0) for a in sys.argv[2:]})


if __name__ == "__main__":
    main()
