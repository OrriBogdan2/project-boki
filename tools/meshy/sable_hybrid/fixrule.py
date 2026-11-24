"""PART-LOCK weight fix for Sable's Meshy rig. Skeleton untouched; only per-vertex JOINTS_0/WEIGHTS_0 change,
and only in the failing regions:
 R1 pistols/hands: finger-bone weights -> same-side Hand bone (sculpted grip stays closed, gun rigid);
    verts below the hand (the barrels) -> 100% Hand.
 R2 arm<->coat leak: coat-tail bone weight removed from arm verts; arm weight removed from coat verts.
 R3 coat tails: limit leg weight on coat verts to LEGCAP x tail weight, then Laplacian-smooth weights
    inside the coat mask (ITC iterations).
 R4 armpits: Laplacian-smooth weights in the arm/torso seam band (ITA iterations).
Everything outside these masks keeps Meshy's weights exactly."""

import numpy as np
from scipy import sparse


def run(J, W, bind, names, E, P=None):
    P = dict(dict(LEGCAP=99, ITC=4, ITA=3, LAM=0.5), **(P or {}))
    V, NB = len(J), len(names)
    key = np.round(bind * 1e4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.ravel()
    U = inv.max() + 1
    rows = np.repeat(np.arange(V), 4)
    D = sparse.csr_matrix((W.ravel(), (rows, J.ravel())), shape=(V, NB))
    # welded dense weights (first vertex of each weld group)
    first = np.full(U, -1)
    first[inv[::-1]] = np.arange(V)[::-1]
    M = D[first].toarray().astype(np.float64)
    B = bind[first]
    idx = {n: k for k, n in enumerate(names)}
    PROP = {
        "Left": ["Bone_027", "Bone_028", "Bone_029", "Bone_039"],
        "Right": ["Bone_033", "Bone_034", "Bone_035", "Bone_040"],
    }
    arm = [k for k, n in enumerate(names) if any(t in n for t in ("Arm", "Hand")) or n in PROP["Left"] + PROP["Right"]]
    tail = [
        k
        for k, n in enumerate(names)
        if n in ("Bone_006", "Bone_007", "Bone_008", "Bone_009", "Bone_010", "Bone_011", "Bone_012", "Bone_013")
    ]
    leg = [k for k, n in enumerate(names) if any(t in n for t in ("UpLeg", "Leg", "Foot", "Toe"))]
    leg = sorted(set(leg))
    torso = [idx[n] for n in ("Hips", "Spine02", "Spine01", "Spine")]
    M0 = M.copy()
    # R1
    for side in ("Left", "Right"):
        h = idx[side + "Hand"]
        fb = [idx[n] for n in PROP[side]]
        gun = M[:, fb].sum(1) > 0.5
        M[:, h] += M[:, fb].sum(1)
        M[:, fb] = 0
        M[gun] = 0
        M[gun, h] = 1  # the pistol is rigid on its hand
    # R1b: arm-dominant verts below the shoulders lose leg/hip/coat weight (Meshy bleeds UpLeg onto the hands at the hips)
    notarm = [k for k in range(NB) if k not in arm]
    a_low = (M[:, arm].sum(1) > 0.5) & (B[:, 1] < 1.1)
    M[np.ix_(a_low, notarm)] = 0
    # R2
    aw = M[:, arm].sum(1)
    tw = M[:, tail].sum(1)
    a_dom = aw > 0.5
    M[np.ix_(a_dom, tail)] = 0
    c_dom = (tw > 0.3) & (aw < 0.5) & (B[:, 1] < 1.05)
    M[np.ix_(c_dom, arm)] = 0
    # normalise
    M /= np.maximum(M.sum(1, keepdims=True), 1e-9)
    # adjacency on welded verts
    e = inv[E]
    e = e[e[:, 0] != e[:, 1]]
    A = sparse.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(U, U))
    A = (A + A.T).tocsr()
    A.data[:] = 1
    deg = np.asarray(A.sum(1)).ravel()
    Dinv = sparse.diags(1 / np.maximum(deg, 1))

    def smooth(mask, it):
        nonlocal M
        for _ in range(it):
            S = Dinv @ (A @ M)
            M[mask] = (1 - P["LAM"]) * M[mask] + P["LAM"] * S[mask]

    # R3 coat
    tw = M[:, tail].sum(1)
    lw = M[:, leg].sum(1)
    coat = (tw > 0.15) & (B[:, 1] < 1.0) & (M[:, arm].sum(1) < 0.2)
    over = coat & (lw > P["LEGCAP"] * tw)
    if over.any():
        f = P["LEGCAP"] * tw[over] / np.maximum(lw[over], 1e-9)
        M[np.ix_(over, leg)] *= f[:, None]
        M[over] /= M[over].sum(1, keepdims=True)
    cm = coat.copy()
    for _ in range(2):
        cm = cm | (A @ cm.astype(float) > 0) & (B[:, 1] < 1.0) & (M[:, arm].sum(1) < 0.2)
    smooth(cm, P["ITC"])
    # R4 armpits: verts with both arm and torso weight in chest band
    aw = M[:, arm].sum(1)
    ow = M[:, torso].sum(1)
    pit = (aw > 0.05) & (ow > 0.05) & (B[:, 1] > 1.0) & (B[:, 1] < 1.32) & (np.abs(B[:, 0]) < 0.28)
    for _ in range(3):
        pit = pit | (A @ pit.astype(float) > 0) & (B[:, 1] > 1.0) & (B[:, 1] < 1.32) & (np.abs(B[:, 0]) < 0.28)
    smooth(pit, P["ITA"])
    # R5 wrists: forearm/hand seam
    fa = [idx["LeftForeArm"], idx["RightForeArm"]]
    ha = [idx["LeftHand"], idx["RightHand"]]
    wr = (M[:, fa].sum(1) > 0.05) & (M[:, ha].sum(1) > 0.05)
    for _ in range(2):
        wr = wr | (A @ wr.astype(float) > 0) & (B[:, 1] < 1.0)
    smooth(wr, 3)
    # R6 contact bands: where the arm group touches the body below the armpit, spread the weight change over RINGS rings
    import os

    RINGS = int(os.environ.get("RINGS", 16))
    ITK = int(os.environ.get("ITK", 120))
    if RINGS:
        ag = (M[:, arm].sum(1) > 0.5).astype(float)
        low = B[:, 1] < 1.12
        mism = A @ ag - deg * ag
        mism = np.where(ag > 0.5, -mism, mism) > 0  # a neighbour in the other group
        band = mism & low
        for _ in range(RINGS):
            band = band | ((A @ band.astype(float) > 0) & low)
        smooth(band, ITK)
    # back to top-4 per vertex
    M[M < 1e-4] = 0
    o = np.argsort(-M, 1)[:, :4]
    w4 = np.take_along_axis(M, o, 1)
    w4 /= np.maximum(w4.sum(1, keepdims=True), 1e-9)
    J2 = o[inv]
    W2 = w4[inv]
    # verts nobody touched: keep Meshy's exact bytes
    same = np.abs(M - M0).max(1) < 1e-6
    keep = same[inv]
    J2[keep] = J[keep]
    W2[keep] = W[keep]
    stats = dict(
        R1_pistol_or_hand=int((np.abs(M - M0)[:, [idx["LeftHand"], idx["RightHand"]]].max(1) > 1e-6).sum()),
        coat_mask=int(cm.sum()),
        coat_legcapped=int(over.sum()),
        armpit_mask=int(pit.sum()),
        changed_welded=int((~same).sum()),
        welded=int(U),
    )
    return J2.astype(J.dtype), W2.astype(np.float32), stats
