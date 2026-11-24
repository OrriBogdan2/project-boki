"""Moves a built Boki's face (the Face mesh: eyes, lids, brows, mouth) onto its scan's head, in the .glb itself.

A scan row on "auto" fits the proxy's eyes onto the scan; when the body changes (the 11-18 swap to the Bokidex glb)
that fit can leave the eyes inside the head, and the game shows blank sockets. This keeps the body, its texture,
rig and clips byte for byte and only moves Face vertices (all on the head bone, so the move is rigid):
  - each eye with its two lids goes to EYES[id] (centre x, y; scale), its front `PROUD` m in front of the coat,
    as Vespyx's sit; the blend shapes (blink, moods) scale with it;
  - brows and the mouth keep x and y and are set `SKIN` m in front of the coat.
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
EYES = {"puddlet": ((0.080, 0.267), 1.29), "burrlet": ((0.070, 0.213), 1.0)}


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
    body = g.get(g.prims("Body")["boki_coat"]["attributes"]["POSITION"])
    face = g.prims("Face")
    (tx, ty), k = EYES[species]
    fp, ep = face["boki_face"], face["boki_eye"]
    fpos, epos = g.get(fp["attributes"]["POSITION"]), g.get(ep["attributes"]["POSITION"])
    pieces = parts(fpos, g.get(fp["indices"]).ravel())
    lids = [p for p in pieces if len(p) > 50]  # 2 per eye; the rest are brows (8), the mouth (22) and its corners (3)
    rest = [p for p in pieces if len(p) <= 50]
    for sx in (-1, 1):
        ev = np.where(np.sign(epos[:, 0]) == sx)[0]
        lv = np.concatenate([p for p in lids if np.sign(fpos[p, 0].mean()) == sx])
        c = epos[ev].mean(0)
        to = np.array([sx * tx, ty, 0.0])
        front = (epos[ev, 2].min() - c[2]) * k
        to[2] = surface_z(body, to[0], to[1]) - PROUD - front
        for pos, prim, v in ((epos, ep, ev), (fpos, fp, lv)):
            pos[v] = (pos[v] - c) * k + to
            if k != 1.0:
                for t in prim.get("targets", []):
                    g.scale_morph(t["POSITION"], v, k)
        print("%s eye %s: %s -> %s" % (species, "LR"[sx > 0], np.round(c, 3), np.round(to, 3)))
    for p in rest:  # each piece moves whole (no stretched triangles), by the median gap to the coat over its points
        gaps = [z - SKIN - fpos[i, 2] for i in p if (z := surface_z(body, fpos[i, 0], fpos[i, 1])) is not None]
        if gaps:
            fpos[p, 2] += float(np.median(gaps))
    g.put(fp["attributes"]["POSITION"], fpos)
    g.put(ep["attributes"]["POSITION"], epos)
    g.save(path)
    print("%s FRAME head: Vector3(0, %.3f, %.3f)" % (species, ty, epos[:, 2].mean()))


if __name__ == "__main__":
    for sp in sys.argv[1:]:
        refit(sp)
