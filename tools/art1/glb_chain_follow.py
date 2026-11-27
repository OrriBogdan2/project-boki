"""Makes bone chains ride another bone in every clip, with no Blender and no change to the node tree: per key of the
clips, each chain root's local rotation and translation are re-keyed so that its world transform keeps its rest-pose
relation to the --follow bone (times the root's own keyed local motion, if any). The skin, mesh, node tree and every
other track stay byte-identical; the new keys are appended to the buffer (new samplers, old data pruned on write).
Meeko (11-24): Meshy hung her wings (chains Bone_048, Bone_051) under Head, so each head turn (up to 67 deg against
the chest in Idle, 79 in Attack) swung them through her body (wing-vs-torso 13.8 cm in Attack). --follow=Spine pins
them to the upper back. The key times are the --follow bone's ancestors' and the old parent's (their union).
--ref=<clip>@<s>: take the relation from that clip pose instead of the rest pose (Meeko: Idle@0, her stand, so the
wings sit exactly where every judge saw them in Idle; the rest pose holds the head 20+ deg off the stand).
Run: python3 tools/art1/glb_chain_follow.py IN.glb OUT.glb --roots=Bone_048,Bone_051 --follow=Spine [--ref=Idle@0]
     [--clips=a,b]"""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import prune, read, write

CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(CT[a["componentType"]])
    k = NC[a["type"]]
    st = bv.get("byteStride", dt.itemsize * k)
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    raw = np.frombuffer(bytes(b[off : off + st * a["count"]]), np.uint8).reshape(a["count"], st)
    return raw[:, : dt.itemsize * k].copy().view(dt).reshape(a["count"], k).astype(np.float64)


def q2m(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def m2q(r):
    w = np.sqrt(max(0.0, 1 + r[0, 0] + r[1, 1] + r[2, 2])) / 2
    x = np.sqrt(max(0.0, 1 + r[0, 0] - r[1, 1] - r[2, 2])) / 2
    y = np.sqrt(max(0.0, 1 - r[0, 0] + r[1, 1] - r[2, 2])) / 2
    z = np.sqrt(max(0.0, 1 - r[0, 0] - r[1, 1] + r[2, 2])) / 2
    x = np.copysign(x, r[2, 1] - r[1, 2])
    y = np.copysign(y, r[0, 2] - r[2, 0])
    z = np.copysign(z, r[1, 0] - r[0, 1])
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def slerp(a, b, u):
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        q = a + u * (b - a)
        return q / np.linalg.norm(q)
    th = np.arccos(d)
    return (np.sin((1 - u) * th) * a + np.sin(u * th) * b) / np.sin(th)


def trs(t, r, s):
    m = np.eye(4)
    m[:3, :3] = q2m(np.asarray(r, float)) * np.asarray(s, float)
    m[:3, 3] = t
    return m


def rest(node):
    if "matrix" in node:
        return np.array(node["matrix"], float).reshape(4, 4).T
    return trs(node.get("translation", [0, 0, 0]), node.get("rotation", [0, 0, 0, 1]), node.get("scale", [1, 1, 1]))


class Clip:
    def __init__(self, j, b, an):
        self.tracks = {}
        for ch in an["channels"]:
            n = ch["target"].get("node")
            if n is None:
                continue
            s = an["samplers"][ch["sampler"]]
            self.tracks.setdefault(n, {})[ch["target"]["path"]] = (
                acc(j, b, s["input"]).ravel(),
                acc(j, b, s["output"]),
                s.get("interpolation", "LINEAR"),
            )

    def local(self, node, i, t):
        nd = node
        tt = nd.get("translation", [0, 0, 0])
        rr = nd.get("rotation", [0, 0, 0, 1])
        ss = nd.get("scale", [1, 1, 1])
        vals = {"translation": tt, "rotation": rr, "scale": ss}
        for path, (ti, v, interp) in self.tracks.get(i, {}).items():
            if interp == "CUBICSPLINE":
                v = v[1::3]
            k = np.searchsorted(ti, t, side="right") - 1
            if k < 0:
                val = v[0]
            elif k >= len(ti) - 1:
                val = v[-1]
            elif interp == "STEP":
                val = v[k]
            else:
                u = (t - ti[k]) / (ti[k + 1] - ti[k]) if ti[k + 1] > ti[k] else 0.0
                val = slerp(v[k], v[k + 1], u) if path == "rotation" else v[k] * (1 - u) + v[k + 1] * u
            vals[path] = val
        if "matrix" in node and not self.tracks.get(i):
            return rest(node)
        return trs(vals["translation"], vals["rotation"], vals["scale"])


def main():
    a = sys.argv[1:]
    src, dst = a[0], a[1]
    opt = dict(x[2:].split("=", 1) for x in a[2:] if x.startswith("--"))
    j, b = read(src)
    nodes = j["nodes"]
    par = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    byname = {n.get("name"): i for i, n in enumerate(nodes)}
    roots = [byname[r] for r in opt["roots"].split(",")]
    fol = byname[opt["follow"]]
    want = opt.get("clips", "").split(",") if opt.get("clips") else None

    def chain(i):
        out = []
        while i in par:
            i = par[i]
            out.append(i)
        return out

    def world(fn, i):
        m = fn(i)
        for p in chain(i):
            m = fn(p) @ m
        return m

    rw = lambda i: world(lambda k: rest(nodes[k]), i)  # noqa: E731
    if opt.get("ref"):
        rc, rt = opt["ref"].split("@")
        ref = Clip(j, b, next(x for x in j["animations"] if x.get("name") == rc))
        rw = lambda i: world(lambda k: ref.local(nodes[k], k, float(rt)), i)  # noqa: E731
    pad = lambda: b.extend(b"\0" * (-len(b) % 4))  # noqa: E731
    for an in j.get("animations", []):
        if want and an.get("name") not in want:
            continue
        clip = Clip(j, b, an)
        for r in roots:
            old_par = par[r]
            moving = set(chain(fol)) | {fol} | set(chain(r))
            times = sorted({float(x) for i in moving for (ti, _, _) in clip.tracks.get(i, {}).values() for x in ti})
            ts = np.array(times)
            rel = np.linalg.inv(rw(fol)) @ rw(old_par)  # old parent in the follow bone's frame, at rest
            rot, tra = [], []
            for t in ts:
                f = lambda k: clip.local(nodes[k], k, t)  # noqa: E731
                want_w = world(f, fol) @ rel @ f(r)
                loc = np.linalg.inv(world(f, old_par)) @ want_w
                sc = np.linalg.norm(loc[:3, :3], axis=0)
                q = m2q(loc[:3, :3] / sc)
                if rot and np.dot(q, rot[-1]) < 0:
                    q = -q
                rot.append(q)
                tra.append(loc[:3, 3])
            pad()
            o_in = len(b)
            b.extend(ts.astype(np.float32).tobytes())
            pad()
            o_r = len(b)
            b.extend(np.array(rot, np.float32).tobytes())
            pad()
            o_t = len(b)
            b.extend(np.array(tra, np.float32).tobytes())
            n = len(ts)
            bvs = j["bufferViews"]
            accs = j["accessors"]
            ids = []
            for off, ln, ty, mn, mx in (
                (o_in, n * 4, "SCALAR", [float(ts.min())], [float(ts.max())]),
                (o_r, n * 16, "VEC4", None, None),
                (o_t, n * 12, "VEC3", None, None),
            ):
                bvs.append({"buffer": 0, "byteOffset": off, "byteLength": ln})
                ac = {"bufferView": len(bvs) - 1, "componentType": 5126, "count": n, "type": ty}
                if mn is not None:
                    ac["min"], ac["max"] = mn, mx
                accs.append(ac)
                ids.append(len(accs) - 1)
            for ch in an["channels"]:
                if ch["target"].get("node") == r and ch["target"]["path"] in ("rotation", "translation"):
                    an["samplers"].append(
                        {
                            "input": ids[0],
                            "output": ids[1] if ch["target"]["path"] == "rotation" else ids[2],
                            "interpolation": "LINEAR",
                        }
                    )
                    ch["sampler"] = len(an["samplers"]) - 1
            have = {ch["target"]["path"] for ch in an["channels"] if ch["target"].get("node") == r}
            for path, k in (("rotation", 1), ("translation", 2)):
                if path not in have:
                    an["samplers"].append({"input": ids[0], "output": ids[k], "interpolation": "LINEAR"})
                    an["channels"].append({"sampler": len(an["samplers"]) - 1, "target": {"node": r, "path": path}})
            print("%s %s: %d keys, follows %s" % (an.get("name"), nodes[r]["name"], n, nodes[fol]["name"]))
    j["buffers"][0]["byteLength"] = len(b)
    b = prune(j, b)
    j["buffers"][0]["byteLength"] = len(b)
    write(dst, j, b)
    print("wrote", dst, len(b), "bytes bin")


if __name__ == "__main__":
    main()
