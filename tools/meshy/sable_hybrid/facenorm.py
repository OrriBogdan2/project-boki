"""facenorm.py IN.glb OUT.glb : smooth Sable's face shading (sable-face-1123).

The face is two primitives (head above the graft plane, body prim below it). Their stored normals are custom
normals carried through decimation: 5-20 deg off the geometry, split along cheeks and jaw, and the graft seam is
open. This snaps the body seam ring onto the head ring, welds positions at 0.1 mm and writes area-weighted smooth
normals on the face (a 1 cm band blends back to the stored ones). Only POSITION (seam ring) and NORMAL bytes change:
triangles, UVs, weights, textures and clips stay byte-identical.
"""

import json
import struct
import sys

import numpy as np

SEAM_Y = 1.519  # m, graft plane (nose base)
SEAM_TOL = 0.004  # m, ring verts within this of the plane
SNAP_MAX = 0.012  # m, longest snap of a body ring vert onto the head ring
HEAD_TOP = 1.72  # m, head prim above this (antennae, hair tips) keeps its stored normals
BODY_BOTTOM = 1.40  # m, body prim verts below this (neck, shoulders) are not face
HEAD_W = 0.3  # body verts with at least this Head weight count as face
BAND = 0.010  # m, blend width from the face mask edge back to the stored normals
WELD = 1e-4  # m, positions closer than this share one normal
CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


class Glb:
    def __init__(self, path: str):
        self.raw = bytearray(open(path, "rb").read())
        jl, _ = struct.unpack("<II", self.raw[12:20])
        self.j = json.loads(self.raw[20 : 20 + jl])
        self.bin = 20 + jl + 8

    def view(self, idx: int) -> np.ndarray:
        a = self.j["accessors"][idx]
        bv = self.j["bufferViews"][a["bufferView"]]
        dt = np.dtype(CT[a["componentType"]])
        n = NC[a["type"]]
        off = self.bin + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        assert not bv.get("byteStride") or bv["byteStride"] == dt.itemsize * n
        return np.frombuffer(self.raw, dt, a["count"] * n, off).reshape(a["count"], n)


def snap_seam(P: list, mask: list) -> int:
    """Move the body ring verts onto the nearest head ring vert (positions only). Returns how many moved."""
    hr = np.where(mask[0] & (abs(P[0][:, 1] - SEAM_Y) < SEAM_TOL))[0]
    br = np.where(mask[1] & (abs(P[1][:, 1] - SEAM_Y) < SEAM_TOL))[0]
    d = np.linalg.norm(P[1][br][:, None] - P[0][hr][None], axis=2)
    k = d.argmin(1)
    ok = d[np.arange(len(br)), k] < SNAP_MAX
    P[1][br[ok]] = P[0][hr[k[ok]]]
    return int(ok.sum())


def smooth_normals(P: list, I: list, mask: list, N: list) -> None:
    """Area-weighted normals on welded positions over the masked triangles; blend the mask rim into the old ones."""
    keys = np.concatenate([np.round(p / WELD).astype(np.int64) for p in P])
    _, gid = np.unique(keys, axis=0, return_inverse=True)
    gid = gid.reshape(-1)
    off = [0, len(P[0])]
    acc = np.zeros((gid.max() + 1, 3))
    for s in (0, 1):
        t = I[s].reshape(-1, 3)
        t = t[mask[s][t].all(1)]
        fn = np.cross(P[s][t[:, 1]] - P[s][t[:, 0]], P[s][t[:, 2]] - P[s][t[:, 0]])  # length = 2 x area
        for c in range(3):
            np.add.at(acc, gid[off[s] + t[:, c]], fn)
    acc /= np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-12)
    for s in (0, 1):
        new = acc[gid[off[s] : off[s] + len(P[s])]]
        old = N[s].astype(np.float64)
        # vertices not in any masked triangle keep the stored normal
        has = np.linalg.norm(new, axis=1) > 0.5
        w = np.where(has, 1.0, 0.0)
        w = np.minimum(w, rim_weight(s, P[s], mask[s]))
        out = old * (1 - w[:, None]) + new * w[:, None]
        N[s][:] = (out / np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-12)).astype(np.float32)


def rim_weight(s: int, p: np.ndarray, m: np.ndarray) -> np.ndarray:
    """1 inside the mask, easing to 0 over BAND at its open edge (head prim: the top, body prim: the neck)."""
    d = (HEAD_TOP - p[:, 1]) if s == 0 else (p[:, 1] - BODY_BOTTOM)
    return np.where(m, np.clip(d / BAND, 0.0, 1.0), 0.0)


def main(src: str, dst: str) -> None:
    g = Glb(src)
    node = next(n for n in g.j["nodes"] if n.get("name") == "head_graft")
    prims = g.j["meshes"][node["mesh"]]["primitives"]
    joints = [g.j["nodes"][i].get("name") for i in g.j["skins"][node["skin"]]["joints"]]
    hid = np.array([n == "Head" for n in joints])
    P, N, I, mask = [], [], [], []
    for s, pr in enumerate(prims):
        at = pr["attributes"]
        P.append(g.view(at["POSITION"]))
        N.append(g.view(at["NORMAL"]))
        I.append(g.view(pr["indices"]).reshape(-1).astype(np.int64))
        if s == 0:
            mask.append(P[0][:, 1] < HEAD_TOP)
        else:
            hw = (g.view(at["WEIGHTS_0"]) * hid[g.view(at["JOINTS_0"])]).sum(1)
            mask.append((hw > HEAD_W) & (P[1][:, 1] > BODY_BOTTOM))
    n_snap = snap_seam(P, mask)
    smooth_normals(P, I, mask, N)
    print("snapped", n_snap, "face verts", [int(m.sum()) for m in mask])
    open(dst, "wb").write(g.raw)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
