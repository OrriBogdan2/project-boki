"""Moves a built Boki's face (the Face mesh: eyes, lids, brows, mouth) onto its scan's head, in the .glb itself.

A scan row on "auto" fits the proxy's eyes onto the scan; when the body changes (the 11-18 swap to the Bokidex glb)
that fit can leave the eyes inside the head, and the game shows blank sockets. This keeps the body, its texture,
rig and clips byte for byte and only moves Face vertices (all on the head bone, so the move is rigid):
  - each eye with its two lids goes to EYES[id] (centre x, y; scale), its front `PROUD` m in front of the coat,
    as Vespyx's sit; the blend shapes (blink, moods) scale with it;
  - brows and the mouth move with the eyes (a brow by its eye's move and scale, the mouth by the eyes' mean), then each
    piece is set `SKIN` m in front of the coat;
  - MOUTH: the mouth's own scale where the eyes' scale leaves it wider than the head (zephyrak);
  - AXIS: a painted face off the model's x = 0 (thread-wyrm, zephyrak) mirrors the eyes about its own axis;
  - FACING: the coat patch the face looks at (radius round the eyes' midpoint, x y), so a coil in front of the face
    cannot win the surface sample (thread-wyrm); REWEIGHT: Face pieces move off `head` onto the bone owning the nearest
    body vertices, for bodies with no vertex on `head` (thread-wyrm: the knot follows root).
Prints the new eye centre for FRAME["head"] (scripts/match/boki_rig.gd). Run it once on a freshly built .glb.
    python3 tools/boki/face_refit.py puddlet burrlet
"""

import json
import os
import struct
import sys

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROUD = 0.012
SKIN = 0.002
# id: (x, y) of the right eye's centre on the scan (its painted eye, or the socket the cover painted out, read off a
# front orthographic render of the coat), and the scale on the lids' size that covers it
EYES = {
    "puddlet": ((0.080, 0.267), 1.29),
    "burrlet": ((0.070, 0.213), 1.0),
    "caecilith": ((0.0365, 0.405), 0.75),  # the sockets on the top of the head
    "threadwyrm": ((0.1565, 0.066), 0.55),  # the painted face on the pale rope end (low, off-centre)
    "thrumbird": ((0.040, 0.3475), 0.65),  # on the head side, behind the beak base
    "zephyrak": ((-0.0063, 0.336), 0.45),  # on the head, at the top of the neck
}
AXIS = {"threadwyrm": 0.1125, "zephyrak": -0.0275}  # x of the painted face's midline when it is off x = 0
FACING = {"threadwyrm": 0.12}
REWEIGHT = {"threadwyrm"}
MOUTH = {"zephyrak": 0.28}  # the mouth's own scale where the eyes' scale leaves it wider than the head


class Glb:
    def __init__(self, path):
        raw = open(path, "rb").read()
        n = struct.unpack_from("<I", raw, 12)[0]
        self.doc = json.loads(raw[20 : 20 + n])
        bl = struct.unpack_from("<I", raw, 20 + n)[0]
        self.bin = bytearray(raw[20 + n + 8 : 20 + n + 8 + bl])

    def _view(self, i):
        a = self.doc["accessors"][i]
        v = self.doc["bufferViews"][a["bufferView"]]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
        k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        it = np.dtype(dt).itemsize
        st = v.get("byteStride", 0) // it or k
        flat = np.frombuffer(self.bin, dtype=dt, count=(a["count"] - 1) * st + k,
                             offset=v.get("byteOffset", 0) + a.get("byteOffset", 0))
        return np.lib.stride_tricks.as_strided(flat, (a["count"], k), (st * it, it))

    def _raw(self, view, dt, k, count, off=0):
        v = self.doc["bufferViews"][view]
        it = np.dtype(dt).itemsize
        st = v.get("byteStride", 0) // it or k
        flat = np.frombuffer(self.bin, dtype=dt, count=(count - 1) * st + k, offset=v.get("byteOffset", 0) + off)
        return np.lib.stride_tricks.as_strided(flat, (count, k), (st * it, it))

    def scale_morph(self, i, verts, k):
        """Scales a blend shape's deltas on `verts` by k (Blender writes them as sparse accessors)."""
        a = self.doc["accessors"][i]
        if "sparse" not in a:
            d = self._view(i)
            d[verts] *= k
            return
        sp = a["sparse"]
        idt = {5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[sp["indices"]["componentType"]]
        ids = self._raw(sp["indices"]["bufferView"], idt, 1, sp["count"], sp["indices"].get("byteOffset", 0))[:, 0]
        vals = self._raw(sp["values"]["bufferView"], np.float32, 3, sp["count"], sp["values"].get("byteOffset", 0))
        vals[np.isin(ids, verts)] *= k
        d = vals[: sp["count"]]
        a["min"] = [float(x) for x in np.minimum(d.min(0), 0)]
        a["max"] = [float(x) for x in np.maximum(d.max(0), 0)]

    def get(self, i):
        return self._view(i).copy()

    def put(self, i, data):
        self._view(i)[:] = data
        a = self.doc["accessors"][i]
        if "min" in a:
            a["min"] = [float(x) for x in data.min(0)]
            a["max"] = [float(x) for x in data.max(0)]

    def prims(self, mesh):
        m = next(m for m in self.doc["meshes"] if m["name"] == mesh)
        return {self.doc["materials"][p["material"]]["name"]: p for p in m["primitives"]}

    def save(self, path):
        js = json.dumps(self.doc, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        bn = bytes(self.bin) + b"\0" * (-len(self.bin) % 4)
        head = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(bn))
        open(path, "wb").write(head + struct.pack("<II", len(js), 0x4E4F534A) + js
                               + struct.pack("<II", len(bn), 0x004E4942) + bn)


def visible(g):
    """Body vertices as the clips show them: not those of the work props and parts (prop_*, part_*), which the clips
    collapse but the bind pose shows at full size."""
    attr = g.prims("Body")["boki_coat"]["attributes"]
    names = [g.doc["nodes"][j]["name"] for j in g.doc["skins"][0]["joints"]]
    hide = np.array([n.startswith(("prop_", "part_")) for n in names])
    j, w = g.get(attr["JOINTS_0"]), g.get(attr["WEIGHTS_0"])
    return g.get(attr["POSITION"])[~hide[j[np.arange(len(j)), w.argmax(1)]]]


def measure(g):
    """Face to nearest visible Body vertex, in mm: (median, max)."""
    from scipy.spatial import cKDTree

    body = visible(g)
    face = g.prims("Face")
    pts = np.vstack([g.get(face[m]["attributes"]["POSITION"]) for m in ("boki_face", "boki_eye")])
    d = cKDTree(body).query(pts)[0] * 1000
    return float(np.median(d)), float(d.max())


def reweight(g, prim, body_j, body_w, tree, pieces, pos):
    """Each piece of Face vertices rides the bone that owns most of its nearest body vertices (weight 1)."""
    attr = prim["attributes"]
    joints, weights = g.get(attr["JOINTS_0"]), g.get(attr["WEIGHTS_0"])
    used = set()
    for v in pieces:
        near = tree.query(pos[v], k=4)[1].ravel()
        b = int(np.bincount(body_j[near, np.argmax(body_w[near], axis=1)].astype(int)).argmax())
        joints[v] = (b, 0, 0, 0)
        weights[v] = (1, 0, 0, 0)
        used.add(b)
    g.put(attr["JOINTS_0"], joints)
    g.put(attr["WEIGHTS_0"], weights)
    return used


def surface_z(body, x, y, r=0.008):
    """The coat's front (lowest z: a Boki faces -Z) at x, y, or None off the body."""
    m = (np.abs(body[:, 0] - x) < r) & (np.abs(body[:, 1] - y) < r)
    return float(body[m, 2].min()) if m.any() else None


def parts(pos, idx):
    """Connected pieces of a primitive, as vertex index arrays."""
    par = np.arange(len(pos))

    def root(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a

    for t in idx.reshape(-1, 3):
        for a, b in ((t[0], t[1]), (t[1], t[2])):
            par[root(a)] = root(b)
    groups = {}
    for i in range(len(pos)):
        groups.setdefault(root(i), []).append(i)
    return [np.array(g) for g in groups.values()]


def refit(species):
    path = os.path.join(REPO, "art/kin", species, species + ".glb")
    g = Glb(path)
    bp = g.prims("Body")["boki_coat"]
    body = visible(g)
    before = measure(g)
    (tx, ty), k = EYES[species]
    ax = AXIS.get(species, 0.0)
    if species in FACING:  # sample only the coat patch the face looks at
        body = body[np.hypot(body[:, 0] - ax, body[:, 1] - ty) < FACING[species]]
    face = g.prims("Face")
    fp, ep = face["boki_face"], face["boki_eye"]
    fpos, epos = g.get(fp["attributes"]["POSITION"]), g.get(ep["attributes"]["POSITION"])
    pieces = parts(fpos, g.get(fp["indices"]).ravel())
    lids = [p for p in pieces if len(p) > 50]  # 2 per eye; the rest are brows (8), the mouth (22) and its corners (3)
    rest = [p for p in pieces if len(p) <= 50]
    eye_from, eye_to, groups = {}, {}, []  # per side, and the pieces that ride with it
    side = {}  # each eye's vertices and its lids', taken before anything moves
    for sx in (-1, 1):
        side[sx] = (
            np.where(np.sign(epos[:, 0]) == sx)[0],
            np.concatenate([p for p in lids if np.sign(fpos[p, 0].mean()) == sx]),
        )
    for sx in (-1, 1):
        ev, lv = side[sx]
        c = epos[ev].mean(0)
        to = np.array([sx * (tx - ax) + ax, ty, 0.0])
        front = (epos[ev, 2].min() - c[2]) * k
        to[2] = surface_z(body, to[0], to[1]) - PROUD - front
        for pos, prim, v in ((epos, ep, ev), (fpos, fp, lv)):
            pos[v] = (pos[v] - c) * k + to
            if k != 1.0:
                for t in prim.get("targets", []):
                    g.scale_morph(t["POSITION"], v, k)
        eye_from[sx], eye_to[sx] = c, to
        groups += [(ep, ev), (fp, lv)]
        print("%s eye %s: %s -> %s" % (species, "LR"[sx > 0], np.round(c, 3), np.round(to, 3)))
    mid_from = (eye_from[-1] + eye_from[1]) / 2
    mid_to = (eye_to[-1] + eye_to[1]) / 2
    for p in rest:  # brows ride their eye, the mouth and its corners the eyes' midpoint (move + scale)
        m = fpos[p].mean(0)
        sd = 1 if m[0] >= 0 else -1
        c0, c1 = (eye_from[sd], eye_to[sd]) if m[1] > mid_from[1] else (mid_from, mid_to)
        kp = k if m[1] > mid_from[1] else MOUTH.get(species, k)
        fpos[p] = (fpos[p] - c0) * kp + c1
        if kp != 1.0:
            for t in fp.get("targets", []):
                g.scale_morph(t["POSITION"], p, kp)
        groups.append((fp, p))
    for p in rest:  # each piece moves whole (no stretched triangles), by the median gap to the coat over its points
        gaps = [z - SKIN - fpos[i, 2] for i in p if (z := surface_z(body, fpos[i, 0], fpos[i, 1])) is not None]
        if gaps:
            fpos[p, 2] += float(np.median(gaps))
    g.put(fp["attributes"]["POSITION"], fpos)
    g.put(ep["attributes"]["POSITION"], epos)
    if species in REWEIGHT:
        from scipy.spatial import cKDTree

        full = g.get(bp["attributes"]["POSITION"])
        bj, bw = g.get(bp["attributes"]["JOINTS_0"]), g.get(bp["attributes"]["WEIGHTS_0"])
        keep = np.where(np.isin(full, visible(g)).all(1))[0]
        tree, bj, bw = cKDTree(full[keep]), bj[keep], bw[keep]
        names = [g.doc["nodes"][j]["name"] for j in g.doc["skins"][0]["joints"]]
        for prim, pos in ((fp, fpos), (ep, epos)):
            used = reweight(g, prim, bj, bw, tree, [v for pr, v in groups if pr is prim], pos)
            print("%s Face -> bones %s" % (species, sorted(names[b] for b in used)))
    g.save(path)
    after = measure(Glb(path))
    m = (species, before[0], after[0], before[1], after[1])
    print("%s Face nearest body: median %.1f -> %.1f mm, max %.1f -> %.1f mm" % m)
    print("%s FRAME head: Vector3(%.3g, %.3f, %.3f)" % (species, ax, ty, epos[:, 2].mean()))


if __name__ == "__main__":
    for sp in sys.argv[1:]:
        refit(sp)
