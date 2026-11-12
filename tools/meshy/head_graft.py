"""Head graft: a new Meshy body under a kept head (a body pass that must not change the face).

The head glb's face primitive (the largest one: the Meshy body that carries the face) keeps its vertex buffers, UVs and
textures byte for byte; only its index buffer changes, to the triangles above the cut (and an overlap band below it).
The body glb's triangles below the cut become new primitives with their own material; the head's edge overlaps them by
OVERLAP. Put the cut where both meshes are one matching layer (Claire: 0.33, under the fur collar, so the live neck and
scarf stay whole). `--ramp M` pulls body vertices up to M under the cut onto the head's surface (fully at the cut, SINK
inside it); it closes a crack on a smooth single layer but crumples layered fur, hair or clips, so it is off by default.
`--keep-node NAME` copies a node of the head glb as it is (the live spear). `--compact` drops the head's unused
vertices (a game master; the site file keeps them so v95-promote's face lock sees the same face primitive).
Both glbs must share a frame (Meshy outputs of the same character: soles and crown at the same height).
Run: blender -b --factory-startup --python tools/meshy/head_graft.py -- HEAD_GLB BODY_GLB OUT_GLB --cut Y
     [--keep-node NAME]... [--compact] [--ramp M]"""

import argparse
import json
import struct
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

RAMP = 0.0  # m: default --ramp (0: no body vertex is moved)
OVERLAP = 0.006  # m: the head keeps its triangles this far under the cut, over the body
SINK = 0.0005  # m: body vertices in the overlap sit this far inside the head's surface
MAX_PRIM_VERTS = 200000  # body vertices per primitive (the head's face primitive stays the largest)
NEAR_CUT = 0.08  # m: head triangles this close to the cut (kept or not) are the surface the body is pulled onto
REACH = 0.03  # m: farthest a body vertex looks for its layer of the head surface
FACING = 0.5  # cos: the head surface a body vertex snaps to faces within ~60 deg of its own normal


def read(path):
    d = open(path, "rb").read()
    jl = struct.unpack_from("<I", d, 12)[0]
    bl = struct.unpack_from("<I", d, 20 + jl)[0]
    return json.loads(d[20 : 20 + jl]), d[28 + jl : 28 + jl + bl]


def view_bytes(j, bn, k):
    bv = j["bufferViews"][k]
    o = bv.get("byteOffset", 0)
    return bn[o : o + bv["byteLength"]]


def acc(j, bn, i):
    a = j["accessors"][i]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    bv = j["bufferViews"][a["bufferView"]]
    if bv.get("byteStride", n * np.dtype(dt).itemsize) != n * np.dtype(dt).itemsize:
        raise ValueError("accessor %d is interleaved" % i)
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    ar = np.frombuffer(bn, dt, a["count"] * n, o)
    return ar.reshape(-1, n) if n > 1 else ar


class Out:
    """A glb being written: buffers views appended to one binary chunk, objects copied with their indices remapped."""

    def __init__(self):
        self.j = {
            "asset": {"version": "2.0", "generator": "head_graft.py"},
            "scene": 0,
            "scenes": [{"nodes": []}],
            "nodes": [],
            "meshes": [],
            "materials": [],
            "textures": [],
            "images": [],
            "samplers": [],
            "accessors": [],
            "bufferViews": [],
            "buffers": [{}],
        }
        self.bin = bytearray()
        self.memo = {}

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        bv = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            bv["target"] = target
        self.bin += data
        self.j["bufferViews"].append(bv)
        return len(self.j["bufferViews"]) - 1

    def array(self, ar, kind):
        ar = np.ascontiguousarray(ar)
        is_index = kind == "SCALAR"
        a = {
            "bufferView": self.view(ar.tobytes(), 34963 if is_index else 34962),
            "componentType": 5125 if is_index else 5126,
            "count": len(ar),
            "type": kind,
        }
        if kind == "VEC3":
            a["min"] = ar.min(0).tolist()
            a["max"] = ar.max(0).tolist()
        self.j["accessors"].append(a)
        return len(self.j["accessors"]) - 1

    def copy(self, src, kind, i):
        """object `i` of list `kind` from glb src = (j, bn), with everything it points at; its index here."""
        key = (id(src[0]), kind, i)
        if key in self.memo:
            return self.memo[key]
        j, bn = src
        o = json.loads(json.dumps(j[kind][i]))
        if kind == "accessors":
            data = view_bytes(j, bn, o["bufferView"])
            o["bufferView"] = self.view(data, j["bufferViews"][o["bufferView"]].get("target"))
        elif kind == "images":
            o["bufferView"] = self.view(view_bytes(j, bn, o["bufferView"]))
        elif kind == "textures":
            o["source"] = self.copy(src, "images", o["source"])
            if "sampler" in o:
                o["sampler"] = self.copy(src, "samplers", o["sampler"])
        elif kind == "materials":
            for t in _texture_refs(o):
                t["index"] = self.copy(src, "textures", t["index"])
        self.j[kind].append(o)
        self.memo[key] = len(self.j[kind]) - 1
        return self.memo[key]

    def prim(self, src, pr, indices=None):
        p = {"attributes": {k: self.copy(src, "accessors", v) for k, v in pr["attributes"].items()}, "mode": 4}
        p["indices"] = (
            self.array(indices, "SCALAR") if indices is not None else self.copy(src, "accessors", pr["indices"])
        )
        if "material" in pr:
            p["material"] = self.copy(src, "materials", pr["material"])
        return p

    def node(self, name, prims):
        self.j["meshes"].append({"name": name, "primitives": prims})
        self.j["nodes"].append({"name": name, "mesh": len(self.j["meshes"]) - 1})
        self.j["scenes"][0]["nodes"].append(len(self.j["nodes"]) - 1)

    def write(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.j["buffers"][0]["byteLength"] = len(self.bin)
        for k in ("samplers", "textures", "images", "materials"):
            if not self.j[k]:
                del self.j[k]
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(self.bin)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


def _texture_refs(mat):
    pbr = mat.get("pbrMetallicRoughness", {})
    for t in (
        pbr.get("baseColorTexture"),
        pbr.get("metallicRoughnessTexture"),
        mat.get("normalTexture"),
        mat.get("occlusionTexture"),
        mat.get("emissiveTexture"),
    ):
        if t:
            yield t


def face_prim(j, bn):
    """(node index, primitive) of the largest primitive; the face lives on it. Nodes must carry no transform."""
    best = None
    for ni, nd in enumerate(j["nodes"]):
        if "mesh" not in nd:
            continue
        m = nd.get("matrix")
        if any(k in nd for k in ("translation", "rotation", "scale")) or (
            m and m != [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        ):
            raise ValueError("node %d has a transform" % ni)
        for pr in j["meshes"][nd["mesh"]]["primitives"]:
            n = j["accessors"][pr["attributes"]["POSITION"]]["count"]
            if not best or n > best[0]:
                best = (n, ni, pr)
    return best[1], best[2]


def _same_layer(bvh, p, n):
    """(point, triangle) of the head surface facing the same way as a body vertex (p, normal n): the nearer of the hits
    along +-n, else the nearest point; None if that faces away (a scarf must not snap onto the neck under it)."""
    best = None
    for d in (Vector(n), -Vector(n)):
        loc, fn, fi, dist = bvh.ray_cast(Vector(p), d, REACH)
        if loc is not None and fn.dot(Vector(n)) > FACING and (best is None or dist < best[2]):
            best = (np.array(loc), fi, dist)
    if best is None:
        loc, fn, fi, dist = bvh.find_nearest(Vector(p), REACH)
        if loc is None or fn.dot(Vector(n)) <= FACING:
            return None
        best = (np.array(loc), fi, dist)
    return best[0], best[1]


def interpolated_normal(P, N, tri, at):
    a, b, c = (P[k] for k in tri)
    v0, v1, v2 = b - a, c - a, at - a
    d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01 or 1e-12
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    n = (1 - v - w) * N[tri[0]] + v * N[tri[1]] + w * N[tri[2]]
    return n / (np.linalg.norm(n) or 1.0)


def graft(head_path, body_path, out_path, cut, keep_nodes, compact, ramp=RAMP):
    hj, hb = read(head_path)
    bj, bb = read(body_path)
    head_src, body_src = (hj, hb), (bj, bb)
    _, hp = face_prim(hj, hb)
    _, bp = face_prim(bj, bb)
    HP = acc(hj, hb, hp["attributes"]["POSITION"]).astype(np.float64)
    HN = acc(hj, hb, hp["attributes"]["NORMAL"]).astype(np.float64)
    HT = acc(hj, hb, hp["indices"]).reshape(-1, 3)
    BP = acc(bj, bb, bp["attributes"]["POSITION"]).astype(np.float64)
    BT = acc(bj, bb, bp["indices"]).reshape(-1, 3)

    head_tris = HT[HP[HT, 1].mean(1) > cut - OVERLAP]
    body_tris = BT[BP[BT, 1].mean(1) <= cut]

    near = HT[np.abs(HP[HT, 1].mean(1) - cut) < NEAR_CUT]
    bvh = BVHTree.FromPolygons([Vector(p) for p in HP], near.tolist(), all_triangles=True)
    used = np.unique(body_tris)
    pos = BP[used].copy()
    nrm = acc(bj, bb, bp["attributes"]["NORMAL"]).astype(np.float64)[used].copy()
    w = np.clip((pos[:, 1] - (cut - OVERLAP - ramp)) / ramp, 0.0, 1.0) if ramp > 0 else np.zeros(len(pos))
    w = w * w * (3 - 2 * w)
    moved = 0
    for k in np.nonzero(w > 0)[0]:
        hit = _same_layer(bvh, pos[k], nrm[k])
        if hit is None:
            continue
        loc, fi = hit
        n = interpolated_normal(HP, HN, near[fi], loc)
        pos[k] += w[k] * (loc - n * SINK - pos[k])
        v = nrm[k] + w[k] * (n - nrm[k])
        nrm[k] = v / (np.linalg.norm(v) or 1.0)
        moved += 1

    out = Out()
    head_attr = hp["attributes"]
    if compact:
        keep = np.unique(head_tris)
        remap = np.full(len(HP), -1, np.int64)
        remap[keep] = np.arange(len(keep))
        attrs = {k: out.array(acc(hj, hb, v)[keep], hj["accessors"][v]["type"]) for k, v in head_attr.items()}
        head = {
            "attributes": attrs,
            "indices": out.array(remap[head_tris].astype(np.uint32).ravel(), "SCALAR"),
            "mode": 4,
        }
        if "material" in hp:
            head["material"] = out.copy(head_src, "materials", hp["material"])
    else:
        head = out.prim(head_src, hp, head_tris.astype(np.uint32).ravel())
    out.j["materials"][head["material"]]["name"] = "head"

    body_mat = out.copy(body_src, "materials", bp["material"]) if "material" in bp else None
    if body_mat is not None:
        out.j["materials"][body_mat]["name"] = "body"
    uv = acc(bj, bb, bp["attributes"]["TEXCOORD_0"])[used]
    remap = np.full(len(BP), -1, np.int64)
    remap[used] = np.arange(len(used))
    tris = remap[body_tris]
    prims = []
    for part in np.array_split(np.argsort(pos[tris, 1].mean(1)), -(-len(used) // MAX_PRIM_VERTS)):
        t = tris[part]
        vs = np.unique(t)
        local = np.full(len(used), -1, np.int64)
        local[vs] = np.arange(len(vs))
        p = {
            "attributes": {
                "POSITION": out.array(pos[vs].astype(np.float32), "VEC3"),
                "NORMAL": out.array(nrm[vs].astype(np.float32), "VEC3"),
                "TEXCOORD_0": out.array(uv[vs], "VEC2"),
            },
            "indices": out.array(local[t].astype(np.uint32).ravel(), "SCALAR"),
            "mode": 4,
        }
        if body_mat is not None:
            p["material"] = body_mat
        prims.append(p)
    out.node("head_graft", [head] + prims)
    for name in keep_nodes:
        nd = next(n for n in hj["nodes"] if n.get("name") == name)
        out.node(name, [out.prim(head_src, pr) for pr in hj["meshes"][nd["mesh"]]["primitives"]])
    out.write(out_path)
    print(
        "HEADGRAFT head %d tris (of %d), body %d tris in %d prims, %d body verts pulled onto the head -> %s"
        % (len(head_tris), len(HT), len(body_tris), len(prims), moved, out_path),
        flush=True,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("head")
    ap.add_argument("body")
    ap.add_argument("out")
    ap.add_argument("--cut", type=float, required=True, help="glTF +Y of the seam (m)")
    ap.add_argument("--keep-node", action="append", default=[])
    ap.add_argument("--compact", action="store_true")
    ap.add_argument("--ramp", type=float, default=RAMP, help="m of body under the cut pulled onto the head (0 = none)")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1 :])
    graft(a.head, a.body, a.out, a.cut, a.keep_node, a.compact, a.ramp)


main()
