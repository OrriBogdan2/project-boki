"""Grimble (dredge) native model, round 25 stages on the r24 glb (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md).

  dredge_r25.py --cap OUT IN      the socket dome resampled on a regular grid (the r11 ring dome's slivers were the
                                  earring-to-shoulder strand web), its goo-root ring filled
  dredge_r25.py --noball OUT IN   the pack's junk ball dropped (not in the 2D)
  dredge_r25.py --legs OUT IN     open rims on the legs/hips (the hip slit) fan-filled (dredge_post.cap_rims)
  dredge_r25.py --all OUT IN      every r25 stage in order

Every stage takes IN.glb and writes OUT.glb (dredge_post.rebuild_stages). numpy/scipy/PIL only.
"""

import sys

import dredge_post as d
import numpy as np
from scipy.spatial import cKDTree

CAP_STEP = 0.018  # UV units between resampled dome vertices (the dome's planar UVs: ~1.7 per m, so ~1.1 cm)
CAP_RIM_GAP = 0.6  # share of CAP_STEP a grid vertex keeps from the rim
CAP_SMOOTH = (8, 0.5)  # rounds, share: interior positions relaxed toward their neighbours (rim pinned)
CAP_MASK = 1024  # px: the UV raster the dome's cover is tested on
CAP_K = 8  # old vertices a vertex in the goo-root hole takes its values from (inverse distance)


def _loops(F):
    """The open-edge cycles of a face list as ordered vertex lists, longest first."""
    E = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
    u, c = np.unique(E, axis=0, return_counts=True)
    nb = {}
    for a, b in u[c == 1]:
        nb.setdefault(a, []).append(b)
        nb.setdefault(b, []).append(a)
    seen, loops = set(), []
    for s in nb:
        if s in seen:
            continue
        loop, prev, cur = [s], None, s
        seen.add(s)
        while True:
            nxt = [x for x in nb[cur] if x != prev and x not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            seen.add(cur)
            loop.append(cur)
        loops.append(loop)
    return sorted(loops, key=len, reverse=True)


def _locate(U, F, q, k=32):
    """For each 2D point q: (face, barycentric) of an old UV triangle holding it (unfolded first), face -1 if none."""
    T = U[F]
    ar = (T[:, 1, 0] - T[:, 0, 0]) * (T[:, 2, 1] - T[:, 0, 1]) - (T[:, 2, 0] - T[:, 0, 0]) * (T[:, 1, 1] - T[:, 0, 1])
    cand = cKDTree(T.mean(1)).query(q, k=k)[1]
    face = np.full(len(q), -1)
    bc = np.zeros((len(q), 3))
    for i, p in enumerate(q):
        c = cand[i][np.argsort(ar[cand[i]] <= 0, kind="stable")]  # front-facing (unfolded) faces first
        b = _bary(T[c], p)
        hit = np.where((b >= -1e-6).all(1))[0]
        if len(hit):
            face[i], bc[i] = c[hit[0]], b[hit[0]]
    return face, bc


def _bary(T, p):
    v0, v1, v2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0], p - T[:, 0]
    den = v0[:, 0] * v1[:, 1] - v1[:, 0] * v0[:, 1]
    den = np.where(np.abs(den) < 1e-15, 1e-15, den)
    b1 = (v2[:, 0] * v1[:, 1] - v1[:, 0] * v2[:, 1]) / den
    b2 = (v0[:, 0] * v2[:, 1] - v2[:, 0] * v0[:, 1]) / den
    return np.stack([1 - b1 - b2, b1, b2], 1)


def _uv_mask(U, F):
    """The old faces' UV cover rasterised, every hole in it filled (the goo-root ring, UV fold gaps)."""
    from PIL import Image, ImageDraw
    from scipy import ndimage

    im = Image.new("L", (CAP_MASK, CAP_MASK), 0)
    dr = ImageDraw.Draw(im)
    for t in U[F] * CAP_MASK:
        dr.polygon([tuple(p) for p in t], fill=255, outline=255)
    return ndimage.binary_fill_holes(np.array(im) > 0)


def _laplace(P, F, free, rounds, share, only=None):
    """Moves the free vertices toward their neighbours' mean (only: the vertices solved, others fixed)."""
    import scipy.sparse as sp

    m = len(P)
    r = np.r_[F[:, 0], F[:, 1], F[:, 2], F[:, 1], F[:, 2], F[:, 0]]
    c = np.r_[F[:, 1], F[:, 2], F[:, 0], F[:, 0], F[:, 1], F[:, 2]]
    A = sp.coo_matrix((np.ones(len(r)), (r, c)), (m, m)).tocsr()
    A.data[:] = 1.0
    deg = np.maximum(np.asarray(A.sum(1)).ravel(), 1)[:, None]
    mv = (free if only is None else only)[:, None]
    for _ in range(rounds):
        P = np.where(mv, (1 - share) * P + share * (A @ P) / deg, P)
    return P


def cap_dome(js, b, out, rig):
    """r25: the socket dome (r11 rings toward a centre, r20 pushed onto the mirrored left shoulder) is 67 %% slivers
    (1379 of 2051 faces longer than 4 cm and under 6 mm high): at game view they are the review's dark strands from the
    earring to the goo root, and its open inner ring where the goo enters is the see-through root hole. The dome is
    resampled on a regular grid in its own planar UVs (same shape, same r23 texture, same r22 weights, read off the
    old faces by barycentric weights), its outer rim vertices kept exactly (still sealed to the skin), the inner ring
    filled (Laplace), Delaunay faces, then a light relax."""
    from scipy.spatial import Delaunay

    prims = js["meshes"][0]["primitives"]
    dm = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-native-dome")
    A = d.read_attrs(js, b, dm["attributes"])
    F0 = d.prim_faces(js, b, dm).astype(np.int64)
    U0 = A["TEXCOORD_0"][:, :2].astype(float)
    E = np.sort(np.concatenate([F0[:, [0, 1]], F0[:, [1, 2]], F0[:, [2, 0]]]), 1)
    u, c = np.unique(E, axis=0, return_counts=True)
    ring = _loops(F0)[0]  # the closed inner ring round the goo root (the outer rim has bow-tie vertices: no walk)
    rim = np.setdiff1d(np.unique(u[c == 1]), ring)
    mask = _uv_mask(U0, F0)

    def inside(X):
        ij = np.clip((X * CAP_MASK).astype(int), 0, CAP_MASK - 1)
        return mask[ij[:, 1], ij[:, 0]]

    lo, hi = U0.min(0), U0.max(0)
    gx, gy = np.meshgrid(np.arange(lo[0], hi[0], CAP_STEP), np.arange(lo[1], hi[1], CAP_STEP * 0.866))
    gx = gx + (np.arange(gx.shape[0])[:, None] % 2) * CAP_STEP / 2  # hexagonal grid: equilateral faces
    G = np.c_[gx.ravel(), gy.ravel()]
    G = G[cKDTree(U0[rim]).query(G)[0] > CAP_RIM_GAP * CAP_STEP]
    G = G[inside(G)]
    Q = np.r_[U0[rim], G]
    tri = Delaunay(Q).simplices
    F = tri[inside(Q[tri].mean(1))]
    nr = len(rim)
    face, bc = _locate(U0, F0, G)
    hole = face < 0  # the goo-root ring and UV fold gaps: values from the nearest old vertices, positions by Laplace
    nb = len(rig.names)
    W0 = np.zeros((len(U0), nb))
    for s in range(4):
        np.add.at(W0, (np.arange(len(U0)), A["JOINTS_0"][:, s].astype(int)), A["WEIGHTS_0"][:, s])
    vals = {k: v for k, v in A.items() if k not in ("JOINTS_0", "WEIGHTS_0")}
    vals["W"] = W0
    new = {}
    for k, v in vals.items():
        g = np.zeros((len(G),) + v.shape[1:])
        g[~hole] = (v[F0[face[~hole]]] * bc[~hole][..., None]).sum(1)
        if hole.any():  # the old inner ring's hole: nearest-rim values, then the Laplace fill below
            dd, ii = cKDTree(U0).query(G[hole], k=CAP_K)
            w = 1 / np.maximum(dd, 1e-6)
            g[hole] = (v[ii] * (w / w.sum(1, keepdims=True))[..., None]).sum(1)
        new[k] = np.r_[v[rim], g]
    new["TEXCOORD_0"] = Q.astype(np.float32)
    pinned = np.r_[np.ones(nr, bool), np.zeros(len(G), bool)]
    holev = np.r_[np.zeros(nr, bool), hole]
    P = _laplace(new["POSITION"], F, ~pinned, 200, 1.0, only=holev)
    P = _laplace(P, F, ~pinned, *CAP_SMOOTH)
    T = P[F]
    fn = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    if (fn * new["NORMAL"][F].mean(1)).sum() < 0:
        F = F[:, [0, 2, 1]]
        fn = -fn
    N = np.zeros_like(P)
    for j in range(3):
        np.add.at(N, F[:, j], fn)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    new["POSITION"], new["NORMAL"] = P, N
    top = np.argsort(-new["W"], 1)[:, :4]
    tw = np.take_along_axis(new.pop("W"), top, 1)
    new["JOINTS_0"] = top.astype(np.uint16)
    new["WEIGHTS_0"] = tw / tw.sum(1, keepdims=True)
    if "TANGENT" in new:
        t = new["TANGENT"]
        t[:, :3] /= np.maximum(np.linalg.norm(t[:, :3], axis=1, keepdims=True), 1e-9)
        t[:, 3] = np.where(t[:, 3] < 0, -1.0, 1.0)
    for k, arr in new.items():
        a = dm["attributes"][k]
        if js["accessors"][a]["componentType"] == 5126:
            acc = out.add_floats(np.asarray(arr, np.float32), js["accessors"][a]["type"])
            if k == "POSITION":
                js["accessors"][acc].update(min=arr.min(0).tolist(), max=arr.max(0).tolist())
        else:
            js["accessors"].append(
                {"bufferView": out.add_view(arr.tobytes()), "componentType": 5123, "count": len(arr), "type": "VEC4"}
            )
            acc = len(js["accessors"]) - 1
        dm["attributes"][k] = acc
    idx = F.reshape(-1).astype(np.uint32)
    js["accessors"].append(
        {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
    )
    dm["indices"] = len(js["accessors"]) - 1
    e = np.stack([np.linalg.norm(T[:, a] - T[:, (a + 1) % 3], axis=1) for a in range(3)], 1)
    h = np.linalg.norm(fn, axis=1) / np.maximum(e.max(1), 1e-9)
    thin = int(((e.max(1) > 0.04) & (h < 0.006)).sum())
    return "dome %d faces -> %d (slivers %d), rim %d kept, %d grid verts (%d in the old goo-root hole), loops %d" % (
        len(F0),
        len(F),
        thin,
        nr,
        len(G),
        int(hole.sum()),
        len(_loops(F)),
    )


def drop_ball(js, b, out, rig):
    """r25: the pack's last junk ball (leather/metal/brass-ball prims; r21 dropped its copy, dredge_post.drop_ball_copy)
    reads from the back as a blue/orange noise ball with a black hole and a yellow ring; the 2D pack has crates and a
    barrel, no ball. Its prims go."""
    prims = js["meshes"][0]["primitives"]
    keep = [p for p in prims if not js["materials"][p["material"]]["name"].endswith("-ball")]
    gone = sum(len(d.prim_faces(js, b, p)) for p in prims if p not in keep)
    js["meshes"][0]["primitives"] = keep
    d.prune_materials(js)
    return "ball tris dropped %d" % gone


# r25: open rims on the legs and hips wider than r13's "small skin holes" (6 cm), e.g. the 10 cm hip slit, fan-filled.
# (The review's knee notch is not a hole: the Idle knee bend folds the thigh skin behind the shin; weights, r26.)
LEG_HOLES = (("leg and hip holes", 0, ((-0.45, 0.3, -0.5), (0.45, 1.1, 0.3)), 6, 0.12, None, 0),)


def leg_holes(js, b, out, rig):
    return "leg/hip fill tris %s" % d.cap_rims(js, b, out, rig, LEG_HOLES)


STAGES = {"--cap": [("cap dome", cap_dome)], "--noball": [("ball", drop_ball)]}
STAGES["--legs"] = [("leg holes", leg_holes)]
STAGES["--all"] = STAGES["--cap"] + STAGES["--noball"] + STAGES["--legs"]

if __name__ == "__main__":
    d.rebuild_stages(sys.argv[2], sys.argv[3], STAGES[sys.argv[1]])
