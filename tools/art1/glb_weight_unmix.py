#!/usr/bin/env python3
"""glb_weight_unmix.py IN.glb OUT.glb BONE FROM[,FROM..] [--keep 0.3] [--shift-keep 0.5]
Untangles one bone's skin weights from bones it touches but must not move with, touching nothing else in the glb
(Meeko r3b: her big tail lies along her left shin and right thigh, so v95_swap's 30 smoothing passes blend tail with
leg; in downed/revive the leg and the tail swing apart and those blended vertices stretch 11.9x, tail>tail). Per vertex
with BONE's weight w and FROM-bones' (name prefix: thigh matches thigh.L and thigh.R) weight f:
  w >= keep: the FROM weight goes to BONE (the tail stays whole, it may brush the leg instead of tearing);
  0 < w < keep and f > 0: BONE's weight goes to the vertex's largest FROM bone (the leg stays a leg).
Weights to other bones (the hips at the tail's root) stay as they are, so the root keeps its soft blend.
--shift-keep: a vertex whose FROM share of its non-BONE weight is above this is untangled; below it (mostly hips) it
is left alone. Prints how many vertices moved each way."""
import argparse
import json
import struct

import numpy as np

CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def view(j, binary, i):
    """A writable (count, n) numpy view of accessor i inside the bin chunk."""
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(CT[a["componentType"]])
    c = NC[a["type"]]
    st = v.get("byteStride", dt.itemsize * c)
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    assert st == dt.itemsize * c, "strided accessor"
    return np.frombuffer(binary, dt, count=a["count"] * c, offset=off).reshape(a["count"], c), a.get("normalized", False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("bone")
    ap.add_argument("frm")
    ap.add_argument("--keep", type=float, default=0.3)
    ap.add_argument("--shift-keep", type=float, default=0.5)
    ap.add_argument("--smooth", type=int, default=0, help="instead: N Laplacian passes over the contact zone")
    ap.add_argument("--rings", type=int, default=3, help="--smooth zone: the mixed vertices grown by this many rings")
    o = ap.parse_args()
    b = open(o.src, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    at = 20 + n
    blen = struct.unpack("<I", b[at:at + 4])[0]
    binary = bytearray(b[at + 8:at + 8 + blen])
    names = [j["nodes"][k]["name"] for k in j["skins"][0]["joints"]]
    bi = names.index(o.bone)
    frm = np.array([any(nm == f or nm.startswith(f + ".") for f in o.frm.split(",")) for nm in names])
    if o.smooth:
        smooth(j, binary, names, bi, frm, o)
        write(o, j, binary)
        return
    whole = toleg = 0
    for m in j["meshes"]:
        for p in m["primitives"]:
            if "WEIGHTS_0" not in p["attributes"]:
                continue
            J, _ = view(j, binary, p["attributes"]["JOINTS_0"])
            Wr, norm = view(j, binary, p["attributes"]["WEIGHTS_0"])
            scale = float(np.iinfo(Wr.dtype).max) if Wr.dtype != np.float32 else 1.0
            W = Wr.astype(np.float64) / scale
            on = J == bi
            isf = frm[J]
            w = (W * on).sum(1)
            f = (W * isf).sum(1)
            rest = 1.0 - w
            share = np.where(rest > 1e-6, f / np.maximum(rest, 1e-6), 0.0)
            hit = (f > 0) & (w > 0) & (share >= o.shift_keep)
            a = hit & (w >= o.keep)          # tail takes the leg's weight
            c = hit & (w < o.keep)           # the leg takes the tail's weight
            for v in np.nonzero(a)[0]:
                k = np.nonzero(on[v])[0][0]
                W[v, k] += f[v]
                W[v, isf[v]] = 0.0
            for v in np.nonzero(c)[0]:
                k = np.nonzero(isf[v])[0][np.argmax(W[v, isf[v]])]
                W[v, k] += w[v]
                W[v, on[v]] = 0.0
            whole += int(a.sum())
            toleg += int(c.sum())
            W /= W.sum(1, keepdims=True)
            if scale == 1.0:
                Wr[:] = W.astype(np.float32)
            else:
                q = np.round(W * scale)
                q[np.arange(len(q)), np.argmax(q, 1)] += scale - q.sum(1)     # sums stay exact
                Wr[:] = q.astype(Wr.dtype)
    print("unmix %s from %s: %d vertices whole to %s, %d to the leg" % (o.bone, o.frm, whole, o.bone, toleg))
    write(o, j, binary)


def smooth(j, binary, names, bi, frm, o):
    """--smooth: the vertices where BONE and FROM bones mix (grown by --rings, welded across seams and primitives by
    position) get N passes of w = (w + mean of neighbours) / 2 on their full weight vector, then the top 4 kept. A wider,
    softer blend: the fused tail/leg surface spreads its stretch over more edges instead of a few."""
    prims = [p for m in j["meshes"] for p in m["primitives"] if "WEIGHTS_0" in p["attributes"]]
    Ps, Js, Ws, Ts, base = [], [], [], [], 0
    for p in prims:
        P, _ = view(j, binary, p["attributes"]["POSITION"])
        I, _ = view(j, binary, p["indices"])
        Ps.append(P.astype(np.float64))
        Ts.append(I.reshape(-1, 3).astype(np.int64) + base)
        base += len(P)
    P = np.concatenate(Ps)
    T = np.concatenate(Ts)
    _, weld = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    weld = weld.ravel()
    nw = weld.max() + 1
    D = np.zeros((nw, len(names)))
    cnt = np.zeros(nw)
    views = []
    at = 0
    for p in prims:
        J, _ = view(j, binary, p["attributes"]["JOINTS_0"])
        Wr, _ = view(j, binary, p["attributes"]["WEIGHTS_0"])
        scale = float(np.iinfo(Wr.dtype).max) if Wr.dtype != np.float32 else 1.0
        W = Wr.astype(np.float64) / scale
        idx = weld[at:at + len(J)]
        for k in range(J.shape[1]):
            np.add.at(D, (idx, J[:, k].astype(np.int64)), W[:, k])
        np.add.at(cnt, idx, 1)
        views.append((J, Wr, scale, idx))
        at += len(J)
    D /= cnt[:, None]
    E = np.concatenate([weld[T[:, [0, 1]]], weld[T[:, [1, 2]]], weld[T[:, [2, 0]]]])
    E = E[E[:, 0] != E[:, 1]]
    zone = (D[:, bi] > 0.01) & (D[:, frm].sum(1) > 0.01)
    print("smooth zone: %d mixed vertices" % zone.sum())
    for _ in range(o.rings):
        g = zone.copy()
        g[E[zone[E[:, 0]], 1]] = True
        g[E[zone[E[:, 1]], 0]] = True
        zone = g
    deg = np.bincount(E.ravel(), minlength=nw).astype(np.float64)
    for _ in range(o.smooth):
        S = np.zeros_like(D)
        np.add.at(S, E[:, 0], D[E[:, 1]])
        np.add.at(S, E[:, 1], D[E[:, 0]])
        M = S / np.maximum(deg, 1)[:, None]
        D[zone] = 0.5 * (D[zone] + M[zone])
    print("smooth: %d passes over %d vertices" % (o.smooth, zone.sum()))
    for J, Wr, scale, idx in views:
        z = zone[idx]
        if not z.any():
            continue
        top = np.argsort(-D[idx[z]], 1)[:, :J.shape[1]]
        w = np.take_along_axis(D[idx[z]], top, 1)
        w /= w.sum(1, keepdims=True)
        J[z] = top.astype(J.dtype)
        if scale == 1.0:
            Wr[z] = w.astype(np.float32)
        else:
            q = np.round(w * scale)
            q[np.arange(len(q)), np.argmax(q, 1)] += scale - q.sum(1)
            Wr[z] = q.astype(Wr.dtype)


def write(o, j, binary):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<I", len(js)) + b"JSON" + js + struct.pack("<I", len(binary)) + b"BIN\x00" + bytes(binary)
    open(o.out, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


if __name__ == "__main__":
    main()
