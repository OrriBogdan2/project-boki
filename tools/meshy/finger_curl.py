"""Pose a rig .glb's fingers in numpy, as `--rig-hands-shots --curl` does in Godot (each finger joint 1..3's rest rotation
times a turn about its own local axis), and measure the tearing of the skinned mesh. No Blender, no renderer.
Run: python3 tools/meshy/finger_curl.py <rig.glb> [--curl=70] [--axis=z] [--posed=out.glb]
Prints, per hand: edge stretch (posed / rest length, p99 and max, how many edges over 2x and 3x), and the near-pair gap (vertex
pairs closer than 4 mm at rest that end up further apart than 5 mm / 10 mm: skin that parts). --posed writes the posed mesh,
unskinned, so any viewer shows the pose."""

import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import finger_weights as FWt  # noqa: E402

FING = re.compile(r"Hand(Thumb|Index|Middle|Ring|Pinky)[123]$")


def quat_mat(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def local(nd, extra=None):
    m = np.eye(4)
    if "matrix" in nd:
        return np.array(nd["matrix"]).reshape(4, 4).T
    r = quat_mat(nd.get("rotation", [0, 0, 0, 1]))
    if extra is not None:
        r = r @ extra
    m[:3, :3] = r * np.array(nd.get("scale", [1, 1, 1]))[None, :]
    m[:3, 3] = nd.get("translation", [0, 0, 0])
    return m


def world(j, extra):
    nd = j["nodes"]
    par = {c: i for i, n in enumerate(nd) for c in n.get("children", [])}
    out = {}

    def get(i):
        if i not in out:
            m = local(nd[i], extra.get(i))
            out[i] = get(par[i]) @ m if i in par else m
        return out[i]

    for i in range(len(nd)):
        get(i)
    return out


def axis_rot(axis, deg):
    a = np.radians(deg) / 2
    v = np.array({"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis]) * np.sin(a)
    return quat_mat((*v, np.cos(a)))


def posed(j, bin_, deg, axis, joints="123", thumb=1.0):
    """Skinned vertex positions with every finger joint 1..3 turned by deg about its local axis."""
    skin = j["skins"][0]
    P, JI, WT, tri, views = FWt.skinned(j, bin_)
    ibm = FWt.accessor(j, bin_, skin["inverseBindMatrices"]).reshape(-1, 4, 4).astype(np.float64)
    extra = {}
    for ni in skin["joints"]:
        nm = FWt.strip(j["nodes"][ni]["name"])
        if FING.search(nm) and nm[-1] in joints:
            d = deg[int(nm[-1]) - 1] if isinstance(deg, (list, tuple)) else deg
            extra[ni] = axis_rot(axis, d * (thumb if "Thumb" in nm else 1.0))
    W1 = world(j, extra)
    out = np.zeros_like(P)
    Ph = np.c_[P, np.ones(len(P))]
    for k, ni in enumerate(skin["joints"]):
        m = W1[ni] @ ibm[k].T
        sel = JI == k
        w = (WT * sel).sum(1)
        if w.any():
            out += w[:, None] * (Ph @ m.T)[:, :3]
    return P, out, tri, skin, views


def measure(j, bin_, deg=70, axis="z", joints="123", thumb=1.0):
    P, Q, tri, skin, views = posed(j, bin_, deg, axis, joints, thumb)
    J = FWt.rest_joints(j, bin_, skin)
    ed = np.unique(np.sort(np.concatenate([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]]), axis=1), axis=0)
    res = {}
    for side in ("Left", "Right"):
        hand = "%sHand" % side
        if hand not in J:
            continue
        m = np.linalg.norm(P - J[hand], axis=1) < 0.2
        e = ed[m[ed[:, 0]] & m[ed[:, 1]]]
        r0 = np.linalg.norm(P[e[:, 0]] - P[e[:, 1]], axis=1)
        e, r0 = e[r0 > 1e-6], r0[r0 > 1e-6]
        r = np.linalg.norm(Q[e[:, 0]] - Q[e[:, 1]], axis=1) / r0
        idx = np.nonzero(m)[0]
        from scipy.spatial import cKDTree

        pr = cKDTree(P[idx]).query_pairs(0.004, output_type="ndarray")
        a, b = idx[pr[:, 0]], idx[pr[:, 1]]
        g = np.linalg.norm(Q[a] - Q[b], axis=1) - np.linalg.norm(P[a] - P[b], axis=1)
        res[side] = dict(
            p99=float(np.percentile(r, 99)),
            mx=float(r.max()),
            o2=int((r > 2).sum()),
            o3=int((r > 3).sum()),
            g5=int((g > 0.005).sum()),
            g10=int((g > 0.01).sum()),
            gmax=float(g.max()),
            edges=len(e),
        )
    return res, P, Q, views


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    opt = dict(x[2:].split("=") for x in sys.argv[1:] if x.startswith("--") and "=" in x)
    from importlib import import_module

    G = import_module("glb_add_clips")
    j, bin_ = G.read(a[0])
    deg = [float(x) for x in opt.get("curl", "70").split(",")]
    res, P, Q, views = measure(
        j,
        bin_,
        deg if len(deg) > 1 else deg[0],
        opt.get("axis", "z"),
        opt.get("joints", "123"),
        float(opt.get("thumb", 1)),
    )
    for side, d in res.items():
        print(
            "curl %s: edges %d stretch p99 %.2f max %.2f, >2x %d >3x %d; near-pair gaps >5mm %d >10mm %d max %.1f mm"
            % (side, d["edges"], d["p99"], d["mx"], d["o2"], d["o3"], d["g5"], d["g10"], d["gmax"] * 1000)
        )
    if "posed" in opt:
        n0 = 0
        for m in j["meshes"]:
            for prim in m["primitives"]:
                if "JOINTS_0" in prim["attributes"]:
                    pos = FWt.accessor(j, bin_, prim["attributes"]["POSITION"])
                    pos[:] = Q[n0 : n0 + len(pos)].astype(np.float32)
                    n0 += len(pos)
                    for k in ("JOINTS_0", "WEIGHTS_0"):
                        prim["attributes"].pop(k, None)
        for nd in j["nodes"]:
            nd.pop("skin", None)
        j.pop("skins", None)
        G.write(opt["posed"], j, bin_)


if __name__ == "__main__":
    main()
