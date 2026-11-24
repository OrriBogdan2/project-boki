"""Hand skin weights of a Meshy auto-rig (include_fingers), cleaned so a curled hand does not tear. No Blender: it edits the
rig .glb's JOINTS_0/WEIGHTS_0 in place, after finger_roll.py has given every finger joint the same roll (local +z closes
toward the palm); the mesh and the joint positions stay as they were.

Why: Meshy weights every vertex of a hand on its own, and its skin is layered (crack plates over the base skin, finger
slabs that touch): two vertices a few mm apart carry different finger bones, so a fist pulls the layers apart and the
base skin shows through (red shards, dark patches). Each vertex near a hand is therefore re-weighted from the vertices
around it:
  1. a Gaussian blend (RADIUS x the model's height) of the weights of every vertex within reach of it, whichever piece
     of the mesh it is on, repeated PASSES times; only vertices that already carry a hand or finger bone are changed;
  2. vertices at the same point (the glTF export splits them per UV seam) share one result: weld before skin;
  3. at most 4 influences each (the glTF limit), normalised to 1.
Run: python3 tools/meshy/finger_weights.py <rig.glb> [out.glb]   (no out: edits in place, keeps <name>.raw.glb once)
Needs numpy and scipy. Check it with tools/meshy/finger_curl.py (edge stretch, skin that parts)."""

import os
import re
import shutil
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art1"))
import glb_add_clips as G  # noqa: E402  (the .glb reader/writer shared with the clip tools)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import finger_roll  # noqa: E402

RADIUS = 0.007  # x the model's height (1.7 m: 12 mm): vertices this close blend their weights
PASSES = 2
REGION = 0.14  # x the height: how far from a hand joint a vertex may still be changed
WELD = 1e-5  # m: vertices this close are one point
CTYPES = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32}


def strip(name):
    return name.removeprefix("mixamorig:")


def accessor(j, bin_, idx):
    """The accessor's data as a writable numpy view into bin_ [count, components]."""
    a = j["accessors"][idx]
    bv = j["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, **CTYPES}[a["componentType"]]
    n = {"MAT4": 16, "VEC4": 4, "VEC3": 3, "VEC2": 2, "SCALAR": 1}[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(bin_, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)


def rest_joints(j, bin_, skin):
    """Joint rest positions in the mesh's bind space: the inverse bind matrices' inverses' translations."""
    ibm = accessor(j, bin_, skin["inverseBindMatrices"]).reshape(-1, 4, 4)  # glTF stores column-major
    out = {}
    for k, ni in enumerate(skin["joints"]):
        out[strip(j["nodes"][ni]["name"])] = np.linalg.inv(ibm[k].T)[:3, 3].astype(np.float64)
    return out


def skinned(j, bin_):
    """Every skinned primitive as one mesh: positions P, joints JI, weights WT (copies), triangles tri (offset to match), and
    the views to write JI/WT back through: [(first vertex, JOINTS_0 view, WEIGHTS_0 view)]."""
    P, JI, WT, tri, views, n = [], [], [], [], [], 0
    for m in j["meshes"]:
        for prim in m["primitives"]:
            at = prim["attributes"]
            if "JOINTS_0" not in at:
                continue
            p = accessor(j, bin_, at["POSITION"])
            ji, wt = accessor(j, bin_, at["JOINTS_0"]), accessor(j, bin_, at["WEIGHTS_0"])
            P.append(p.astype(np.float64))
            JI.append(ji.astype(np.int64))
            WT.append(wt.astype(np.float64))
            if "indices" in prim:
                tri.append(accessor(j, bin_, prim["indices"]).reshape(-1, 3).astype(np.int64) + n)
            views.append((n, ji, wt))
            n += len(p)
    return np.concatenate(P), np.concatenate(JI), np.concatenate(WT), np.concatenate(tri), views


def dense_weights(JI, WT, nj):
    W = np.zeros((len(JI), nj))
    for k in range(4):
        np.add.at(W, (np.arange(len(JI)), JI[:, k].astype(np.int64)), WT[:, k])
    return W


def blend(P, W, reg, rad, passes):
    """Gaussian blend of the weights of reg's vertices over each other (positions P), `passes` times."""
    Pr = P[reg]
    pairs = cKDTree(Pr).query_pairs(rad, output_type="ndarray")
    pairs = np.concatenate([pairs, pairs[:, ::-1], np.repeat(np.arange(len(Pr))[:, None], 2, axis=1)])
    d = np.linalg.norm(Pr[pairs[:, 0]] - Pr[pairs[:, 1]], axis=1)
    k = np.exp(-((d / (rad * 0.5)) ** 2))
    norm = np.bincount(pairs[:, 0], weights=k, minlength=len(Pr))
    Wr = W[reg].copy()
    for _ in range(passes):
        out = np.zeros_like(Wr)
        np.add.at(out, pairs[:, 0], k[:, None] * Wr[pairs[:, 1]])
        Wr = out / norm[:, None]
    return Wr


def clean(j, bin_):
    """Re-weights the hands' vertices in bin_ (in place). Returns {side: vertices blended, "moved": vertices changed}."""
    rolled = finger_roll.orient(j, lambda idx: accessor(j, bin_, idx))  # first: rest pose of the finger bones
    skin = j["skins"][0]
    P, JI, WT, _, views = skinned(j, bin_)
    jn = [strip(j["nodes"][ni]["name"]) for ni in skin["joints"]]
    J = rest_joints(j, bin_, skin)
    W = dense_weights(JI, WT, len(jn))
    height = float(np.ptp(P[:, 1]))
    new = W.copy()
    report = {}
    for side in ("Left", "Right"):
        if side + "Hand" not in J:
            continue
        hand = [i for i, nm in enumerate(jn) if nm.startswith(side + "Hand")]  # the hand bone and its fingers
        near = np.linalg.norm(P - J[side + "Hand"], axis=1) < REGION * height
        reg = np.nonzero((W[:, hand].sum(1) > 0.01) & near)[0]
        if len(reg):
            new[reg] = blend(P, W, reg, RADIUS * height, PASSES)
            report[side] = len(reg)
    # weld: vertices at one point share one set of weights
    _, uid = np.unique(np.round(P / WELD).astype(np.int64), axis=0, return_inverse=True)
    uid = uid.reshape(-1)
    sel = np.isin(uid, np.unique(uid[np.abs(new - W).sum(1) > 1e-6]))
    sums = np.zeros((uid.max() + 1, new.shape[1]))
    np.add.at(sums, uid[sel], new[sel])
    new[sel] = sums[uid[sel]] / np.bincount(uid[sel], minlength=uid.max() + 1)[uid[sel]][:, None]
    changed = np.abs(new - W).sum(1) > 1e-6
    # at most 4 influences, normalised
    top = np.argsort(-new, axis=1)[:, :4]
    tw = np.take_along_axis(new, top, axis=1)
    tw /= np.maximum(tw.sum(1, keepdims=True), 1e-9)
    for n0, ji, wt in views:
        sel = changed[n0 : n0 + len(ji)]
        ji[sel] = top[n0 : n0 + len(ji)][sel].astype(ji.dtype)
        wt[sel] = tw[n0 : n0 + len(ji)][sel].astype(wt.dtype)
    report["moved"] = int(changed.sum())
    report["rolled"] = rolled
    return report


def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src
    j, bin_ = G.read(src)
    rep = clean(j, bin_)
    if dst == src:
        raw = re.sub(r"\.glb$", ".raw.glb", src)
        if not os.path.exists(raw):
            shutil.copyfile(src, raw)
    G.write(dst, j, bin_)
    blended = {k: v for k, v in rep.items() if k not in ("moved", "rolled")}
    print(
        "finger_weights: joints rolled %s, hand vertices blended %s, %d re-weighted -> %s"
        % (rep["rolled"], blended, rep["moved"], dst)
    )


if __name__ == "__main__":
    main()
