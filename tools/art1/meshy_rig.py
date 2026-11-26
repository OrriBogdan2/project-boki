"""A Meshy rig read from its .glb: bone tree, rest, a clip's sampled pose, forward kinematics, and a clips-only writer.

Poses are given as world directions (glTF space of the Meshy build: it faces +Z, its left is +X, up is +Y): a bone is
swung so its own +Y (Meshy keys every bone along +Y toward its child) points the way you name, with an optional twist
about that axis, and its children follow with the locals they already had. Used by tools/art1/kael_native_clips.py."""

import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_add_clips  # noqa: E402
import glb_clips_only  # noqa: E402

FPS = 30.0


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def qinv(q):
    return (-q[0], -q[1], -q[2], q[3])


def qnorm(q):
    n = math.sqrt(sum(x * x for x in q))
    return tuple(x / n for x in q)


def qrot(q, v):
    p = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qinv(q))
    return (p[0], p[1], p[2])


def axis_angle(axis, deg):
    n = math.sqrt(sum(x * x for x in axis))
    s = math.sin(math.radians(deg) / 2.0) / n
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(math.radians(deg) / 2.0))


def swing(a, b):
    """The shortest rotation taking direction a onto direction b."""
    a, b = unit(a), unit(b)
    d = sum(x * y for x, y in zip(a, b))
    if d < -0.999999:
        side = (1.0, 0.0, 0.0) if abs(a[0]) < 0.9 else (0.0, 0.0, 1.0)
        return axis_angle(cross(a, side), 180.0)
    c = cross(a, b)
    return qnorm((c[0], c[1], c[2], 1.0 + d))


def slerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0.0:
        b, d = tuple(-x for x in b), -d
    if d > 0.9995:
        return qnorm(tuple(x + (y - x) * t for x, y in zip(a, b)))
    th = math.acos(d)
    s = math.sin(th)
    ka, kb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
    return tuple(ka * x + kb * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    n = math.sqrt(sum(x * x for x in v))
    return (v[0] / n, v[1] / n, v[2] / n)


class Rig:
    def __init__(self, path):
        self.j, self.bin = glb_add_clips.read(path)
        self.path = path
        nodes = self.j["nodes"]
        joints = self.j["skins"][0]["joints"]
        self.names = {i: nodes[i].get("name") for i in joints}
        self.index = {n: i for i, n in self.names.items()}
        self.parent = {}
        for i, n in enumerate(nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        self.order = []  # bones, parents first
        for i in joints:
            self._add(i)
        self.rest = {self.names[i]: tuple(nodes[i].get("rotation", (0.0, 0.0, 0.0, 1.0))) for i in self.order}
        self.rest_t = {self.names[i]: tuple(nodes[i].get("translation", (0.0, 0.0, 0.0))) for i in self.order}
        self.up = {self.names[i]: self.names.get(self.parent.get(i)) for i in self.order}

    def _add(self, i):
        if i in self.order or i not in self.names:
            return
        if self.parent.get(i) in self.names:
            self._add(self.parent[i])
        self.order.append(i)

    def sample(self, clip, t):
        """A clip of the build sampled at second t: ({bone: local rotation}, {bone: local translation})."""
        a = next(x for x in self.j["animations"] if x["name"] == clip)
        rots, trans = {}, {}
        for ch in a["channels"]:
            nm = self.names.get(ch["target"]["node"])
            path = ch["target"]["path"]
            if nm is None or path == "scale":
                continue
            sm = a["samplers"][ch["sampler"]]
            times, _ = self._acc(sm["input"])
            vals, n = self._acc(sm["output"])
            k = max(i for i, x in enumerate(times) if x <= t) if t >= times[0] else 0
            k2 = min(k + 1, len(times) - 1)
            f = 0.0 if k2 == k else (t - times[k]) / (times[k2] - times[k])
            v0, v1 = vals[k * n:(k + 1) * n], vals[k2 * n:(k2 + 1) * n]
            if path == "rotation":
                rots[nm] = slerp(tuple(v0), tuple(v1), f)
            else:
                trans[nm] = tuple(x + (y - x) * f for x, y in zip(v0, v1))
        return rots, trans

    def _acc(self, i):
        ac = self.j["accessors"][i]
        bv = self.j["bufferViews"][ac["bufferView"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
        off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
        return list(struct.unpack_from("<%df" % (ac["count"] * n), self.bin, off)), n

    def world(self, local):
        """Every bone's world rotation from the locals."""
        out = {}
        for i in self.order:
            nm = self.names[i]
            p = self.up[nm]
            out[nm] = qmul(out[p], local[nm]) if p else local[nm]
        return out

    def pose(self, base, spec, hips_at):
        """base locals with the spec's bones swung: {bone: {"q": a world rotation, "aim": dir, "twist": deg about the bone, "rot": (x, y, z deg
        about the world axes)}}; a bone with no entry keeps its local, so it rides its parent. spec["ik"]: {end bone:
        {"at": world point, "pole": world direction the middle joint bends toward}} for a two-bone limb (arm or leg),
        solved when its first bone comes up. hips_at: the Hips' translation. Returns (locals, world positions)."""
        local = dict(base)
        world, pos = {}, {}
        ik = spec.get("ik", {})
        roots = {self.up[self.up[e]]: e for e in ik}
        pending = {}
        for i in self.order:
            nm = self.names[i]
            p = self.up[nm]
            pw = world[p] if p else (0.0, 0.0, 0.0, 1.0)
            at = qrot(pw, self.rest_t[nm]) if p else (0.0, 0.0, 0.0)
            pos[nm] = tuple(x + y for x, y in zip(pos[p], at)) if p else hips_at
            w = qmul(pw, local[nm])
            s = dict(spec.get(nm, {}))
            s.update(pending.pop(nm, {}))
            if nm in roots:
                end = roots[nm]
                mid = self.up[end]
                pending[mid] = self._solve(pos[nm], nm, mid, end, ik[end])
                s["aim"] = pending[mid].pop("root")
            if s:
                if "q" in s:
                    w = qmul(s["q"], w)
                if "aim" in s:
                    w = qmul(swing(qrot(w, (0, 1, 0)), s["aim"]), w)
                if "twist" in s:
                    w = qmul(axis_angle(qrot(w, (0, 1, 0)), s["twist"]), w)
                if "rot" in s:
                    for ax, deg in zip(((1, 0, 0), (0, 1, 0), (0, 0, 1)), s["rot"]):
                        if deg:
                            w = qmul(axis_angle(ax, deg), w)
                local[nm] = qnorm(qmul(qinv(pw), w))
            world[nm] = qmul(pw, local[nm])
        return local, pos

    def _solve(self, root_at, root, mid, end, want):
        """Two-bone IK: the root's aim and the middle bone's, to put `end` at want["at"] with the bend toward the pole."""
        l1 = math.sqrt(sum(x * x for x in self.rest_t[mid]))
        l2 = math.sqrt(sum(x * x for x in self.rest_t[end]))
        to = tuple(t - r for t, r in zip(want["at"], root_at))
        dist = min(max(math.sqrt(sum(x * x for x in to)), abs(l1 - l2) + 1e-3), l1 + l2 - 1e-3)
        along = unit(to)
        a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
        h = math.sqrt(max(l1 * l1 - a * a, 0.0))
        pole = want.get("pole", (0.0, 0.0, 1.0))
        d = sum(x * y for x, y in zip(pole, along))
        side = unit(tuple(x - d * y for x, y in zip(pole, along)))
        elbow = tuple(r + a * u + h * v for r, u, v in zip(root_at, along, side))
        reach = tuple(r + dist * u for r, u in zip(root_at, along))
        return {"root": tuple(e - r for e, r in zip(elbow, root_at)), "aim": tuple(t - e for t, e in zip(reach, elbow))}

    def write_clips(self, dest, clips):
        """A clips-only .glb (the rig's nodes and skin, no mesh): clips = {name: {"t": [s], "rot": {bone: [quat]},
        "pos": {bone: [xyz]}}}. A bone whose rotation never moves in a clip is written as two keys."""
        j, b = glb_clips_only.rig_only(self.j, self.bin)
        j["animations"] = []
        names = {n: i for i, n in self.names.items()}

        def accessor(vals, typ, count, minmax=None):
            b.extend(b"\0" * (-len(b) % 4))
            j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": 4 * len(vals)})
            b.extend(struct.pack("<%df" % len(vals), *vals))
            ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": count, "type": typ}
            if minmax:
                ac["min"], ac["max"] = minmax
            j["accessors"].append(ac)
            return len(j["accessors"]) - 1

        for name, c in clips.items():
            an = {"name": name, "channels": [], "samplers": []}
            times = c["t"]
            t_all = accessor(times, "SCALAR", len(times), ([min(times)], [max(times)]))
            t_two = accessor([times[0], times[-1]], "SCALAR", 2, ([times[0]], [times[-1]]))
            for path, data, typ in (("rotation", c["rot"], "VEC4"), ("translation", c["pos"], "VEC3")):
                for bone, vals in data.items():
                    flat = len(set(vals)) == 1
                    keys = [vals[0], vals[-1]] if flat else vals
                    out = accessor([x for v in keys for x in v], typ, len(keys))
                    an["samplers"].append({"input": t_two if flat else t_all, "output": out, "interpolation": "LINEAR"})
                    an["channels"].append(
                        {"sampler": len(an["samplers"]) - 1, "target": {"node": names[bone], "path": path}}
                    )
            j["animations"].append(an)
        j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
        glb_add_clips.write(dest, j, b)
        return os.path.getsize(dest)
