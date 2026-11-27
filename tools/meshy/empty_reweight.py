"""Knit the Empty's cloak to the rig: pin it to the body, then smooth the skin weights across the model's cracks.

The Empty models (art/wardens/empty_f, empty_m _meshy.glb: Meshy's own rig) are a Meshy surface decimated to 60k: it has ~18k open edges, so
neighbouring cloak vertices across a crack carry unrelated weights (thigh against arm against hips) and the skin
tears the cloak open when the rig moves; the cloak that hangs from the shoulders is bound to the arms and follows
their swing. First a cloth/trim vertex further than SLEEVE_NEAR from an arm gives up its arm weight (all of it from
SLEEVE_FAR): it takes the mean weights of the nearest vertices that are not on an arm. Then every cloth/trim vertex takes the distance-weighted mean of the weights of
all vertices within RADIUS of it (the other pieces count too: a sleeve follows its hand), SMOOTH_PASSES times, then
keeps its strongest 4 bones. Before that the hood's vertices (above the neck) move onto the Head bone (pin_head). Only the WEIGHTS_0 and JOINTS_0 buffers of the .glb change, in place.

    python3 tools/meshy/empty_reweight.py art/wardens/empty_f/empty_f_meshy.glb [radius_m] [passes]
"""

import json
import struct
import sys

import numpy as np
from scipy.spatial import cKDTree

ARM_BONES = ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand")
ARM_SEGMENTS = (("LeftArm", "LeftHand"), ("RightArm", "RightHand"))  # shoulder to hand, the sleeve's axis
SLEEVE_TIP = 0.12  # m: the sleeve's axis runs this far below the hand bone (the fingers)
SLEEVE_NEAR = 0.12  # m: from the arm's axis a vertex keeps its arm weight
SLEEVE_FAR = 0.2  # m: and further than this it has none
DONORS = 12  # nearest non-arm vertices a freed vertex takes its weights from
RADIUS = 0.08  # m: vertices this close in the rest pose share their weights
SMOOTH_PASSES = 4
SMOOTHED = ("cloth", "trim")  # material slots (the part of the material name before the dash)


def read(path):
    data = bytearray(open(path, "rb").read())
    jl = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20 : 20 + jl])
    bin_start = 20 + jl + 8
    return data, doc, bin_start


def view(data, doc, bin_start, index, dtype, width):
    acc = doc["accessors"][index]
    bv = doc["bufferViews"][acc["bufferView"]]
    start = bin_start + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"] * width
    return np.frombuffer(data, dtype=dtype, count=count, offset=start).reshape(acc["count"], width)


def segment_distance(points, a, b):
    t = np.clip(((points - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
    return np.linalg.norm(points - (a + t[:, None] * (b - a)), axis=1)


def pin_to_body(dense, pos, mask, names, heads):
    """Cloth/trim vertices away from both sleeves lose their arm weight to the nearest vertices that have none."""
    arm = [names.index(n) for n in ARM_BONES]
    reach = np.minimum(*[segment_distance(pos, heads[a], heads[b] - [0.0, SLEEVE_TIP, 0.0]) for a, b in ARM_SEGMENTS])
    keep = np.clip((SLEEVE_FAR - reach) / (SLEEVE_FAR - SLEEVE_NEAR), 0.0, 1.0)
    arm_w = dense[:, arm].sum(1)
    donors = np.flatnonzero(arm_w < 0.05)
    freed = np.flatnonzero(mask & (arm_w > 0.05) & (keep < 1.0))
    near = donors[cKDTree(pos[donors]).query(pos[freed], DONORS)[1]]
    body = dense[near].mean(1)
    new = dense[freed].copy()
    new[:, arm] *= keep[freed, None]
    new += body * (arm_w[freed] * (1.0 - keep[freed]))[:, None]
    dense[freed] = new


def pin_head(dense, pos, names, heads):
    """The hood and what it holds turn with the head: above the neck every vertex (any material) moves toward the Head
    bone alone, all of it half way from the neck to the head bone up (Meshy bound the hood to the spine and neck)."""
    head = names.index("Head")
    low = heads["neck"][1]
    span = 0.5 * (heads["Head"][1] - low) + 0.01
    t = np.clip((pos[:, 1] - low) / span, 0.0, 1.0)[:, None]
    only_head = np.zeros_like(dense)
    only_head[:, head] = 1.0
    dense[:] = dense * (1.0 - t) + only_head * t


def main():
    path = sys.argv[1]
    radius = float(sys.argv[2]) if len(sys.argv) > 2 else RADIUS
    passes = int(sys.argv[3]) if len(sys.argv) > 3 else SMOOTH_PASSES
    data, doc, bin_start = read(path)
    prims = doc["meshes"][0]["primitives"]
    n_joints = len(doc["skins"][0]["joints"])
    pos, joints, weights, smooth = [], [], [], []
    for pr in prims:
        a = pr["attributes"]
        pos.append(view(data, doc, bin_start, a["POSITION"], np.float32, 3))
        joints.append(view(data, doc, bin_start, a["JOINTS_0"], np.uint8, 4))
        weights.append(view(data, doc, bin_start, a["WEIGHTS_0"], np.float32, 4))
        slot = doc["materials"][pr["material"]]["name"].split("-")[0]
        smooth.append(slot in SMOOTHED)
    counts = [len(p) for p in pos]
    all_pos = np.concatenate(pos).astype(np.float64)
    dense = np.zeros((len(all_pos), n_joints))
    row = 0
    for j, w in zip(joints, weights):
        for k in range(4):
            np.add.at(dense, (np.arange(row, row + len(j)), j[:, k].astype(int)), w[:, k])
        row += len(j)
    names = [doc["nodes"][j]["name"] for j in doc["skins"][0]["joints"]]
    ibm = view(data, doc, bin_start, doc["skins"][0]["inverseBindMatrices"], np.float32, 16).reshape(-1, 4, 4)
    heads = {n: np.linalg.inv(ibm[i].T)[:3, 3] for i, n in enumerate(names)}
    mask = np.concatenate([np.full(c, s) for c, s in zip(counts, smooth)])
    pin_to_body(dense, all_pos, mask, names, heads)
    pin_head(dense, all_pos, names, heads)
    pairs = cKDTree(all_pos).query_ball_point(all_pos[mask], radius)
    idx = np.flatnonzero(mask)
    for _ in range(passes):
        nxt = dense.copy()
        for i, nb in zip(idx, pairs):
            d = np.linalg.norm(all_pos[nb] - all_pos[i], axis=1)
            k = 1.0 - d / radius
            nxt[i] = (dense[nb] * k[:, None]).sum(0) / k.sum()
        dense = nxt
    row = 0
    changed = 0
    for j, w in zip(joints, weights):
        part = dense[row : row + len(j)]
        top = np.argsort(-part, axis=1)[:, :4]
        tw = np.take_along_axis(part, top, 1)
        tw /= tw.sum(1, keepdims=True)
        changed += int((np.abs(w - tw).max(1) > 1e-4).sum())
        j[:] = top.astype(np.uint8)
        w[:] = tw.astype(np.float32)
        row += len(j)
    open(path, "wb").write(bytes(data))
    print("%s: %d vertices reweighted (radius %.3f m, %d passes)" % (path, changed, radius, passes))


if __name__ == "__main__":
    main()
