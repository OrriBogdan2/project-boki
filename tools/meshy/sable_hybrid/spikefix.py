"""spikefix.py IN.glb OUT.glb [--rounds=6] [--rings=3] [--it=8] [--lam=0.5] [--ratio=2.5] [--len=0.05] [--layer=0.008] [--lw=1] [--gap=0.015] [--armx=0.15]
Targeted weight smoothing for glbstretch spikes (sable r21). Every clip is skinned at 15 fps; edges that stretch past
--ratio x bind AND grow longer than --len x height seed a region (seed verts + --rings mesh rings, UV-seam welds
shared); weights are Laplacian-smoothed inside that region only (boundary fixed), cut to 4 influences, renormalised.
Layered surfaces (coat over torso, straps over coat: verts within --layer m in bind that are not mesh
neighbours, pairs touching the arm-contact band (arm weight --armx..0.5) or arm vs body, and coat vs leg pairs excluded, as in sable-polish-1122 fixlayers.py) are extra smoothing neighbours with
weight --lw, and pairs opening past --gap x height also seed the region (open pairs > 3%H reported). Repeats until no clip has a spike edge or --rounds is reached. Only JOINTS_0/WEIGHTS_0 bytes change."""

import os
import struct
import sys

import numpy as np
from scipy import sparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glbstretch as g  # noqa: E402

A = dict(rounds=6, rings=3, it=8, lam=0.5, ratio=2.5, len=0.05, layer=0.008, lw=1.0, gap=0.015, armx=0.15)
ARM = ("Arm", "Hand", "Shoulder", "Bone_027", "Bone_028", "Bone_029", "Bone_033", "Bone_034", "Bone_035", "Bone_039", "Bone_040")
COAT = [f"Bone_{k:03d}" for k in range(6, 14)]  # Meshy's two coat-tail chains (Bone_009/013 roots)
for a in sys.argv[3:]:
    k, v = a[2:].split("=")
    A[k] = type(A[k])(float(v))


def spikes(m, ratio, ln, prv=None, gap=0.015):
    """Seed verts (spike edges, and layer pairs opening > gap x height) and per clip worst (spike edges, pairs > 3%H)."""
    out, torn = set(), {}
    d0 = None if prv is None else np.linalg.norm(m.bind[prv[:, 0]] - m.bind[prv[:, 1]], axis=1)
    an = m.anims()
    for nm, a in an.items():
        dur = m.duration(a)
        n = max(2, int(dur * 15))
        worst, wg = 0, 0
        for i in range(n):
            X = m.skin(m.sample(a, min(i / 15, dur - 1e-4)))
            r = m.ratios(X)
            sp = (r > ratio) & m.ok & (m.lengths(X) > ln * m.height)
            hard = ((r > 3.0) & m.ok & (m.lengths(X) > 0.06 * m.height)).sum()
            worst = max(worst, int(hard))
            out.update(m.E[sp].ravel().tolist())
            if prv is not None:
                d = np.linalg.norm(X[prv[:, 0]] - X[prv[:, 1]], axis=1) - d0
                if gap > 0:
                    out.update(prv[d > gap * m.height].ravel().tolist())
                wg = max(wg, int((d > 0.03 * m.height).sum()))
        torn[nm] = (worst, wg) if prv is not None else worst
    return out, torn


def write(m, src, dst, J, W):
    raw = bytearray(open(src, "rb").read())
    jl, _ = struct.unpack("<II", raw[12:20])
    binoff = 20 + jl + 8
    ats = [pr["attributes"] for n in m.j["nodes"] if "skin" in n and "mesh" in n
           for pr in m.j["meshes"][n["mesh"]]["primitives"]]
    base = 0
    for at in ats:
        cnt = m.j["accessors"][at["POSITION"]]["count"]
        for key, arr in (("JOINTS_0", J[base:base + cnt]), ("WEIGHTS_0", W[base:base + cnt])):
            ac = m.j["accessors"][at[key]]
            bv = m.j["bufferViews"][ac["bufferView"]]
            dt = np.dtype(g.CT[ac["componentType"]])
            off = binoff + bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
            st = bv.get("byteStride") or dt.itemsize * 4
            assert ac["count"] == cnt and (dt != np.uint8 or arr.max() < 256) and not ac.get("normalized")
            x = np.ascontiguousarray(arr.astype(dt)).view(np.uint8).reshape(cnt, -1)
            n = (cnt - 1) * st + dt.itemsize * 4
            buf = np.frombuffer(bytes(raw[off:off + n]), np.uint8).copy()
            np.lib.stride_tricks.as_strided(buf, shape=(cnt, dt.itemsize * 4), strides=(st, 1))[:] = x
            raw[off:off + n] = buf.tobytes()
        base += cnt
    assert base == len(J)
    open(dst, "wb").write(raw)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    m = g.Model(src)
    V, NB = len(m.P), len(m.names)
    key = np.round(m.bind * 1e4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.ravel()
    U = inv.max() + 1
    rows = np.repeat(np.arange(V), 4)
    D = sparse.csr_matrix((m.W.ravel(), (rows, m.J.ravel())), shape=(V, NB)).toarray()
    cnt = np.bincount(inv, minlength=U).astype(float)
    M = np.zeros((U, NB))
    np.add.at(M, inv, D)
    M /= cnt[:, None]  # welded weights
    e = np.unique(np.sort(inv[m.E], 1), axis=0)
    e = e[e[:, 0] != e[:, 1]]
    Adj = sparse.csr_matrix((np.ones(len(e) * 2), (np.r_[e[:, 0], e[:, 1]], np.r_[e[:, 1], e[:, 0]])), shape=(U, U))
    prv = None
    if A["layer"] > 0:
        from scipy.spatial import cKDTree
        first = np.full(U, -1)
        first[inv[::-1]] = np.arange(V)[::-1]
        pr = cKDTree(m.bind[first]).query_pairs(A["layer"], output_type="ndarray")
        pr = pr[np.asarray(Adj[pr[:, 0], pr[:, 1]]).ravel() == 0]
        arm = [k for k, n in enumerate(m.names) if any(t in n for t in ARM)]
        armw = M[:, arm].sum(1)
        pr = pr[(armw[pr[:, 0]] < A["armx"]) & (armw[pr[:, 1]] < A["armx"]) | (armw[pr[:, 0]] > 0.5) & (armw[pr[:, 1]] > 0.5)]
        coat = M[:, [k for k, n in enumerate(m.names) if n in COAT]].sum(1) > 0.5
        leg = M[:, [k for k, n in enumerate(m.names) if any(t in n for t in ("Leg", "Foot", "Toe"))]].sum(1) > 0.5
        pr = pr[~((coat[pr[:, 0]] & leg[pr[:, 1]]) | (leg[pr[:, 0]] & coat[pr[:, 1]]))]  # a loose coat may leave the legs
        print("layer pairs", len(pr))
        prv = first[pr]
        Adj = Adj + A["lw"] * sparse.csr_matrix((np.ones(len(pr) * 2), (np.r_[pr[:, 0], pr[:, 1]], np.r_[pr[:, 1], pr[:, 0]])), shape=(U, U))
    deg = np.asarray(Adj.sum(1)).ravel()
    J0, W0 = m.J.copy(), m.W.copy()
    touched = np.zeros(U, bool)
    for rnd in range(int(A["rounds"])):
        sv, torn = spikes(m, A["ratio"], A["len"], prv, A["gap"])
        print(f"round {rnd}: seed verts {len(sv)} | worst (spike edges, open pairs) per clip {torn}", flush=True)
        if not sv:
            break
        reg = np.zeros(U, bool)
        reg[inv[list(sv)]] = True
        for _ in range(int(A["rings"])):
            reg |= (Adj @ reg.astype(float)) > 0
        touched |= reg
        for _ in range(int(A["it"])):
            L = (Adj @ M) / np.maximum(deg, 1)[:, None]
            M[reg] = (1 - A["lam"]) * M[reg] + A["lam"] * L[reg]
        # cut to 4 influences
        Mv = M[inv]
        top = np.argsort(-Mv, 1)[:, :4]
        w = np.take_along_axis(Mv, top, 1)
        w /= np.maximum(w.sum(1, keepdims=True), 1e-9)
        ch = touched[inv]
        m.J = np.where(ch[:, None], top, J0)
        m.W = np.where(ch[:, None], w, W0)
    print("verts changed", int(touched[inv].sum()), "of", V)
    write(m, src, dst, m.J.astype(np.uint16 if m.J.max() > 255 else np.uint8), m.W.astype(np.float32))
    m2 = g.Model(dst)
    _, torn = spikes(m2, A["ratio"], A["len"], prv, A["gap"])
    print("after: worst (spike edges, open pairs) per clip", torn)


if __name__ == "__main__":
    main()
