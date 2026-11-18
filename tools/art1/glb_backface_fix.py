"""Takes the black shards out of a shipped Hero .glb, in place (indices and normals only; nothing else changes).
The toon outline is an inverted hull, so a triangle that shows its back to the camera draws black. A v95 port leaves
three kinds: thin sheets and flaps the scan left floating (both sides open), patches wound the wrong way round (the
inside open, the outside walled in), and the needles, slivers and caps the swap's rip left at a fused contact. Each skin
triangle is tested by rays (RAYS directions in a cone on each side of it, RANGE m): a patch wound inside-out is flipped
(its vertices that no right-way triangle shares get their normal flipped too), a sheet open on both sides is made
degenerate (not drawn), and the first pass also drops the needles/slivers/caps in --zone.
Run: blender -b --factory-startup --python tools/art1/glb_backface_fix.py -- IN.glb OUT.glb [passes=3]
Uses Blender only for its BVH ray cast. Prints what each pass flipped and dropped."""
import json
import struct
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SKIN = "skin-v95"
RAYS = 24            # rays per side
RANGE = 0.6          # m: a ray that meets the mesh inside this is blocked
OFFSET = 2e-4        # m: rays start this far off the triangle
FLIP_GAP = 0.1       # back openness minus front openness above this: wound inside-out
SHEET_OPEN = 0.3     # open this much on both sides: a floating sheet
SLIVER = 40.0        # longest edge squared over area above this (and edge > SLIVER_EDGE): a needle of a triangle
SLIVER_EDGE = 0.04   # m
NEEDLE_EDGE = 0.04   # m: a tip vertex used by this one triangle only, with an edge longer than this
SCRAP = 12           # tris: a piece this small and low (below SCRAP_Y), cut off from the body by the passes, goes too
SCRAP_Y = 0.7        # m
ZONE_Y = 0.45        # m: needles, slivers and caps are taken out below this height, on the right side (x > 0)
CAP_FROM = 42700     # the swap's rip caps are the last triangles of the skin; the bones the caps of the right leg sit on
CAP_BONES = ("hook", "shin.R", "foot.R", "thigh.R")
CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}


def read(data, j, off, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    dt, n = np.dtype(CT[ac["componentType"]]), NC[ac["type"]]
    start = off + bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return np.frombuffer(data, dt, ac["count"] * n, start).reshape(ac["count"], n).copy(), start


def write(data, start, arr):
    data[start:start + arr.nbytes] = np.ascontiguousarray(arr).tobytes()


def openness(tree, pos, idx, rows):
    """[len(rows), 2]: the share of RAYS rays that get out within RANGE, from the front and from the back of each triangle."""
    rng = np.random.default_rng(1)
    cone = rng.normal(size=(RAYS, 3))
    cone[:, 2] = np.abs(cone[:, 2]) + 0.5
    cone /= np.linalg.norm(cone, axis=1)[:, None]
    out = np.zeros((len(rows), 2))
    for k, t in enumerate(rows):
        a, b, c = pos[idx[t]]
        n = np.cross(b - a, c - a)
        n /= np.linalg.norm(n)
        u = np.cross(n, (0, 0, 1) if abs(n[2]) < 0.9 else (1, 0, 0))
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
        mid = (a + b + c) / 3
        for side, sg in ((0, 1), (1, -1)):
            free = sum(tree.ray_cast(Vector(mid + n * sg * OFFSET),
                                     Vector(u * d[0] + v * d[1] + n * d[2] * sg), RANGE)[0] is None for d in cone)
            out[k, side] = free / RAYS
    return out


def shapes(pos, idx):
    a, b, c = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
    edge = np.stack([np.linalg.norm(b - a, axis=1), np.linalg.norm(c - b, axis=1), np.linalg.norm(a - c, axis=1)], 1)
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    return edge.max(1), area, (a + b + c) / 3


def main():
    src, dst = sys.argv[sys.argv.index("--") + 1:][:2]
    passes = int((sys.argv[sys.argv.index("--") + 1:] + ["3"])[2])
    data = bytearray(open(src, "rb").read())
    jlen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + jlen])
    off = 20 + jlen + 8
    prims = []
    for p in j["meshes"][0]["primitives"]:
        pos = read(data, j, off, p["attributes"]["POSITION"])[0].astype(float)
        prims.append((j["materials"][p["material"]]["name"], p, pos))
    name, prim, pos = next(x for x in prims if x[0] == SKIN)
    idx, idx_at = read(data, j, off, prim["indices"])
    idx = idx.reshape(-1, 3).astype(np.int64)
    normals, normals_at = read(data, j, off, prim["attributes"]["NORMAL"])
    names = [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]
    joints = read(data, j, off, prim["attributes"]["JOINTS_0"])[0].astype(int)
    weights = read(data, j, off, prim["attributes"]["WEIGHTS_0"])[0]
    main_bone = joints[np.arange(len(joints)), weights.argmax(1)]
    others = []
    for nm, p, ps in prims:
        if nm != SKIN:
            others.append((ps, read(data, j, off, p["indices"])[0].reshape(-1, 3).astype(np.int64)))
    for rnd in range(passes):
        live = shapes(pos, idx)[1] > 1e-10
        verts = [pos] + [ps for ps, _ in others]
        base = np.cumsum([0] + [len(v) for v in verts])
        faces = [idx[live]] + [ix + base[k + 1] for k, (_, ix) in enumerate(others)]
        tree = BVHTree.FromPolygons([tuple(v) for v in np.concatenate(verts)], [tuple(f) for f in np.concatenate(faces)])
        rows = np.nonzero(live)[0]
        op = openness(tree, pos, idx, rows)
        sheet = np.zeros(len(idx), bool)
        sheet[rows] = (op[:, 0] > SHEET_OPEN) & (op[:, 1] > SHEET_OPEN)
        flip = np.zeros(len(idx), bool)
        flip[rows] = (op[:, 1] - op[:, 0] > FLIP_GAP) & ~sheet[rows]
        gone = sheet.copy()
        if rnd == 0:
            gone |= junk(pos, idx, main_bone, names, live)
        flip &= ~gone
        idx[flip] = idx[flip][:, [0, 2, 1]]
        idx[gone] = idx[gone][:, [0, 0, 0]]
        stay = np.unique(idx[~flip & ~gone & live].ravel())
        turned = np.setdiff1d(np.unique(idx[flip].ravel()), stay)
        normals[turned] = -normals[turned]
        print("backface pass %d: flipped %d, dropped %d sheets + %d junk, %d normals turned"
              % (rnd + 1, flip.sum(), sheet.sum(), (gone & ~sheet).sum(), len(turned)), flush=True)
    scraps = scrap(pos, idx)
    idx[scraps] = idx[scraps][:, [0, 0, 0]]
    print("backface: %d scrap triangles dropped" % scraps.sum())
    write(data, idx_at, idx.astype(CT[j["accessors"][prim["indices"]]["componentType"]]))
    write(data, normals_at, normals)
    open(dst, "wb").write(data)


def scrap(pos, idx):
    """The triangles of connected pieces (welded vertices) of at most SCRAP triangles, below SCRAP_Y."""
    live = shapes(pos, idx)[1] > 1e-10
    _, weld = np.unique(np.round(pos / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    t = weld.ravel()[idx[live]]
    parent = list(range(t.max() + 1))

    def root(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for a, b, c in t.tolist():
        parent[root(b)] = root(a)
        parent[root(c)] = root(a)
    label = np.array([root(v) for v in t[:, 0].tolist()])
    label = np.unique(label, return_inverse=True)[1].ravel()
    size = np.bincount(label)
    low = np.zeros(len(size), bool)
    np.logical_or.at(low, label, pos[idx[live]][:, :, 1].mean(1) < SCRAP_Y)
    out = np.zeros(len(idx), bool)
    out[np.nonzero(live)[0]] = (size[label] <= SCRAP) & low[label]
    return out


def junk(pos, idx, main_bone, names, live):
    """Needles and slivers low on the right, tip vertices of one triangle with a long edge, and the rip caps of the right leg."""
    longest, area, mid = shapes(pos, idx)
    zone = (mid[:, 1] < ZONE_Y) & (mid[:, 0] > 0.0)
    gone = ((longest ** 2 > SLIVER * np.maximum(area, 1e-12)) & (longest > SLIVER_EDGE) & zone) & live
    key = np.round(pos / 1e-5).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    t = weld[idx]
    used = np.bincount(t[live].ravel(), minlength=weld.max() + 1)
    at = np.zeros((weld.max() + 1, 3))
    at[weld] = pos
    for k in range(3):
        tip, o1, o2 = t[:, k], t[:, (k + 1) % 3], t[:, (k + 2) % 3]
        long_edge = np.maximum(np.linalg.norm(at[tip] - at[o1], axis=1), np.linalg.norm(at[tip] - at[o2], axis=1))
        gone |= (used[tip] == 1) & (long_edge > NEEDLE_EDGE) & (at[tip][:, 1] < 0.5) & live
    caps = np.arange(len(idx)) >= CAP_FROM
    bone = np.array([np.bincount(main_bone[tri]).argmax() for tri in idx])
    gone |= caps & np.isin(bone, [names.index(b) for b in CAP_BONES]) & live
    return gone


if __name__ == "__main__":
    main()
