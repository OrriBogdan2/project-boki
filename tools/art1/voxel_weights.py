"""`weights` "voxel" of a v95 swap spec (v95_swap.py): skin weights by distance through the master's voxel solid.

Bone heat runs on the fitted mesh, where the rig's rest pose hangs the arms on the hips and a scan's fused, non-manifold
surface lets the heat cross (a hand weighting the coat beside it, a thigh the pistol). Here the distances are measured in the
master's own pose (arms away from the body), through a voxel solid of the scan: a bone reaches a vertex only through the body
itself, never across the air between an arm and the hip. Each bone's share falls off with its distance past the nearest
bone's. What hangs below the pelvis away from the legs (coat tails, sashes, skirts) is weighted along a chain: the hips at
the belt, more of the nearest leg the lower it hangs. numpy only (Blender's Python has no scipy).

    names, W = voxel_weights.weights(P, tri, joints, bones, spec)

P [n, 3]: the master's vertices in the fit frame (front +Y, right +X, soles on z 0); tri [m, 3]; joints: the spec's `joints`;
bones: the rig's body bones. Spec keys (all optional): `voxel` (m, 0.012), `falloff` (m, 0.03), `cloth_len` (m, 0.35: how far
below the hip joints the hips' share of a hanging part falls to 1/e), `cloth_blend` (m, 0.07: the blend between the thighs'
shares of it), `cloth_at` (1: times a leg's radius, where hanging starts), `cloth_ramp` (1: times it, to fully hanging), `even`
(4: passes that take the voxel steps out of the distances). The lengths scale with the master's pelvis height over 0.9 m.
"""

import numpy as np

INF = np.int32(1 << 30)
UNIT = 5  # the chamfer steps (face, edge, corner) of one voxel: 5, 7, 9
# m through the solid (a boot's toe is the foot's): past these a part hangs
LIMB_RADIUS = {"thigh": 0.13, "shin": 0.10, "foot": 0.20}


def _steps(dims, corners=True):
    """The flat-index offsets to a voxel's 26 (or 6) neighbours and their chamfer costs."""
    offs, costs = [], []
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                n = abs(dx) + abs(dy) + abs(dz)
                if n and (corners or n == 1):
                    offs.append((dx * dims[1] + dy) * dims[2] + dz)
                    costs.append(UNIT + 2 * (n - 1))
    return offs, costs


def _spread(ok, seeds, steps):
    """Shortest path lengths (Dial's buckets, chamfer units) from the `seeds` over the voxels `ok` (both flat)."""
    dist = np.full(ok.size, INF, np.int32)
    dist[seeds] = 0
    todo = {0: [np.asarray(seeds)]}
    while todo:
        d = min(todo)
        idx = np.concatenate(todo.pop(d))
        idx = np.unique(idx[dist[idx] == d])
        for o, c in zip(*steps):
            n = idx + o
            n = n[ok[n] & (dist[n] > d + c)]
            if n.size:
                dist[n] = d + c
                todo.setdefault(d + c, []).append(n)
    return dist


def solid(P, tri, h):
    """The scan as voxels of size h: (inside [x, y, z] bool, the grid's low corner). The surface is sampled closer than a
    voxel; inside is whatever the air cannot reach from the grid's corner."""
    lo = P.min(0) - 2.5 * h
    dims = np.ceil((P.max(0) - lo) / h).astype(int) + 3
    occ = np.zeros(dims, bool)
    T = P[tri]
    n = np.ceil(np.linalg.norm(T - np.roll(T, 1, 1), axis=2).max(1) / (0.7 * h)).astype(int) + 1
    for k in np.unique(n):
        i, j = np.meshgrid(np.arange(k + 1), np.arange(k + 1), indexing="ij")
        m = i + j <= k
        b = np.stack([i[m], j[m], k - i[m] - j[m]], 1) / k
        c = ((np.einsum("sk,tkj->tsj", b, T[n == k]).reshape(-1, 3) - lo) / h).astype(int)
        occ[c[:, 0], c[:, 1], c[:, 2]] = True
    air = ~occ
    air[[0, -1]] = air[:, [0, -1]] = air[:, :, [0, -1]] = False  # (the rim stops the spread at the grid's edge)
    out = _spread(air.ravel(), np.array([(dims[1] + 1) * dims[2] + 1]), _steps(dims, False)) < INF
    ins = ~out.reshape(dims)
    ins[[0, -1]] = ins[:, [0, -1]] = ins[:, :, [0, -1]] = False
    return ins, lo


def _even(D, tri, passes):
    """D averaged with the mesh neighbours' `passes` times: takes the voxel steps out of the distances."""
    e = np.unique(np.sort(np.concatenate([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]]), axis=1), axis=0)
    n = np.maximum(np.bincount(e.ravel(), minlength=len(D)), 1)[:, None]
    for _ in range(passes):
        acc = np.zeros_like(D)
        np.add.at(acc, e[:, 0], D[e[:, 1]])
        np.add.at(acc, e[:, 1], D[e[:, 0]])
        D = 0.5 * D + 0.5 * acc / n
    return D


def arm_cuts(past_wrist):
    """The `detach` pairs every "voxel" spec gets: each forearm and hand (its `past_wrist` bone) from the hips and the
    legs. A scan fuses a hand to the hip or the holster it rests on, and the clips swing them apart: uncut, that is a web."""
    lower = ["hips"] + [b + sd for b in ("thigh.", "shin.", "foot.") for sd in "RL"]
    return [[a, b] for sd in "RL" for a in ("forearm." + sd, past_wrist.get(sd, "hand." + sd)) for b in lower]


def top4(W):
    """W with each row's fifth largest share taken off every share (none below 0), rows summing to 1 again: at most four
    bones a vertex, and no jump where the fourth and the fifth swap."""
    if W.shape[1] > 4:
        W = np.maximum(W - np.partition(W, -5, axis=1)[:, -5:-4], 0)
    return W / W.sum(1, keepdims=True)


def seg_dist(P, a, b):
    """Each point's distance to the segment a-b."""
    u = b - a
    t = np.clip(((P - a) @ u) / max(u @ u, 1e-12), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * u), axis=1)


def segments(J, bones, s):
    """{bone: [(a, b), ...]} in the master's frame, the bone's own segment first. The hips are a T: the spine to the neck,
    the line between the hip joints and one toward each shoulder (the contract has no spine or clavicles: a single line
    gives the chest to the arms). A hand reaches a palm past the wrist, a foot down to the heel and forward along the sole (the
    heel is the foot's, not half the shin's); a rig without hand or foot bones gives those to the forearm or shin."""
    J = {k: np.asarray(v, float) for k, v in J.items()}
    chest = J["pelvis"] + (J["neck"] - J["pelvis"]) * (J["shoulder.R"][2] - J["pelvis"][2]) / (
        J["neck"][2] - J["pelvis"][2]
    )
    out = {"hips": [(J["pelvis"], J["neck"]), (J["hip.R"], J["hip.L"])], "head": [(J["neck"], J["crown"])]}
    for sd in "RL":
        out["hips"].append((chest, chest + (J["shoulder." + sd] - chest) * 0.6))
        fore = J["wrist." + sd] - J["elbow." + sd]
        palm = (J["wrist." + sd], J["wrist." + sd] + fore / np.linalg.norm(fore) * 0.1 * s)
        heel = J["ankle." + sd] * (1, 1, 0.3)
        sole = [(J["ankle." + sd], heel), (heel, heel + (0, 0.12 * s, 0))]
        palm = [palm]
        out["upper_arm." + sd] = [(J["shoulder." + sd], J["elbow." + sd])]
        out["forearm." + sd] = [(J["elbow." + sd], J["wrist." + sd])]
        out["thigh." + sd] = [(J["hip." + sd], J["knee." + sd])]
        out["shin." + sd] = [(J["knee." + sd], J["ankle." + sd])]
        for bone, seg, to in (("hand." + sd, palm, "forearm." + sd), ("foot." + sd, sole, "shin." + sd)):
            if bone in bones:
                out[bone] = seg
            else:
                out[to] += seg
    return {b: out[b] for b in bones if b in out}


def seeds(segs, ins, lo, h, cells):
    """The flat voxels a bone's segments start from: each sample along them, or the nearest inside voxel when the sample is
    in the air (a joint read a little off the limb). Returns (voxels, how many samples were moved)."""
    pts = np.concatenate(
        [a + np.linspace(0, 1, int(np.linalg.norm(b - a) / (0.5 * h)) + 2)[:, None] * (b - a) for a, b in segs]
    )
    c = np.clip(((pts - lo) / h).astype(int), 0, np.array(ins.shape) - 1)
    off = ~ins[c[:, 0], c[:, 1], c[:, 2]]
    for i in np.nonzero(off)[0]:
        c[i] = cells[np.argmin(((cells - c[i]) ** 2).sum(1))]
    return np.unique((c[:, 0] * ins.shape[1] + c[:, 1]) * ins.shape[2] + c[:, 2]), int(off.sum())


def weights(P, tri, J, bones, spec, log=print):
    """(names, W [vertex, bone]): each vertex's shares of the body bones, rows summing to 1 (see the module's text)."""
    s = float(J["pelvis"][2]) / 0.9
    h, tau = spec.get("voxel", 0.012) * s, spec.get("falloff", 0.03) * s
    ins, lo = solid(P, tri, h)
    cells = np.argwhere(ins)
    steps = _steps(ins.shape)
    segs = segments(J, bones, s)
    names = list(segs)
    c = ((P - lo) / h).astype(int)
    vox = (c[:, 0] * ins.shape[1] + c[:, 1]) * ins.shape[2] + c[:, 2]
    D = np.zeros((len(P), len(names)))  # through the solid
    E = np.zeros((len(P), len(names)))  # through the air
    moved = {}
    for i, nm in enumerate(names):
        sd, moved[nm] = seeds(segs[nm], ins, lo, h, cells)
        d = _spread(ins.ravel(), sd, steps)[vox]
        E[:, i] = np.min([seg_dist(P, a, b) for a, b in segs[nm]], axis=0)
        # (a loose piece the solid does not reach: by air)
        D[:, i] = np.where(d < INF, d * (h / UNIT), E[:, i] + 4 * tau)
    D = _even(D, tri, int(spec.get("even", 4)))
    W = np.exp(-(D - D.min(1, keepdims=True)) / tau)
    W /= W.sum(1, keepdims=True)
    # what hangs below the hip joints, further from every leg than a leg is thick, and is no arm's: the hips-to-thighs chain
    legs = [i for i, nm in enumerate(names) if nm.split(".")[0] in LIMB_RADIUS]
    thighs = [i for i, nm in enumerate(names) if nm.split(".")[0] == "thigh"]
    # (no foot bone: the shin has the foot's radius)
    part = [nm if nm.replace("shin", "foot") in names else nm.replace("shin", "foot") for nm in names]
    rad = np.array([LIMB_RADIUS[part[i].split(".")[0]] * s for i in legs]) * spec.get("cloth_at", 1.0)
    over = ((D[:, legs] - rad) / (spec.get("cloth_ramp", 1.0) * rad)).min(1)
    top = max(J["hip.R"][2], J["hip.L"][2])
    arm = np.array([nm.split(".")[0] in ("upper_arm", "forearm", "hand") for nm in names])
    hang = np.clip(over, 0, 1) * np.clip((top - P[:, 2]) / (0.05 * s), 0, 1) * ~arm[D.argmin(1)]
    hang = hang * hang * (3 - 2 * hang)
    hips = np.exp(-np.maximum(top - P[:, 2], 0) / (spec.get("cloth_len", 0.35) * s))
    L = np.exp(-(E[:, thighs] - E[:, thighs].min(1, keepdims=True)) / (spec.get("cloth_blend", 0.07) * s))
    C = np.zeros_like(W)
    C[:, thighs] = L / L.sum(1, keepdims=True) * (1 - hips[:, None])
    C[:, names.index("hips")] = hips
    W = top4(W * (1 - hang[:, None]) + C * hang[:, None])
    log(
        "voxel weights: %d voxels of %.1f mm inside, %d vertices hanging, samples moved inside %s"
        % (len(cells), h * 1000, int((hang > 0.5).sum()), {k: v for k, v in moved.items() if v})
    )
    return names, W
