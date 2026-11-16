"""Hair swap: a Meshy head/bust's hair replaces the hair of a live hunter glb (Meshy-made geometry on both sides).

The live face skin (texels, so the face stays pixel-identical) is not touched. The source bust is fitted to the live head
by a trimmed similarity ICP on the face skin points (the two faces match: one 2D design), its hair triangles (dark
desaturated texels) and hair pins (non-skin texels in the pin box) become one new primitive with the bust's own material,
and the live's hair triangles (+ pins, same rules) are dropped from the live head/body primitives. Other nodes (weapons)
are copied as they are. Pure numpy/scipy/cv2 (venv-img python), no Blender.
Run: python hair_swap.py LIVE.glb BUST.glb OUT.glb [--fit S,TX,TY,TZ] [--hair-bot Y] [--report]
"""
import argparse
import sys
import types

import cv2
import numpy as np
from scipy.spatial import cKDTree

for _m in ("bpy", "mathutils", "mathutils.bvhtree"):  # head_graft's glb reader/writer; bpy is only needed by its graft step
    sys.modules.setdefault(_m, types.ModuleType(_m))
sys.modules["mathutils"].Vector = object
sys.modules["mathutils.bvhtree"].BVHTree = object
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import head_graft as hg  # noqa: E402

FACE_LIVE = (0.665, 0.82, 0.075)  # live face-skin box: y lo, y hi, |x| max
FACE_BUST = (0.14, 0.52, 0.2)  # the same face in the bust frame (Meshy 1.9 m bust)
FACE_OVAL = (0.0, 0.745, 0.085, 0.10, 0.02)  # live frame: centre x, y, semi-axes x, y, and the z the face front starts at
CHOKER_BOX = (0.06, 0.615, 0.70)  # live: |x| < .13, z > 0, y in range: the choker stays
PIN_TOP = 0.86  # live y above which non-skin, non-hair triangles are hair pins
SIDE_X, SIDE_BOT, SIDE_TOP = 0.14, 0.55, 0.80  # old side-hair blocks next to the face that the colour classes miss
BACK_Z, BACK_K, BACK_Y0, BACK_Y1 = -0.06, 0.35, 0.60, 0.72  # back-hair depth squash (y below BACK_Y0 full, above BACK_Y1 none)
LIVE_X = 0.22  # |x| limit of the live hair swap region
HAIR_V, HAIR_S, SKIN_V, SKIN_S = 0.45, 0.55, 0.62, 0.35


def tex(j, bn, pr):
    m = j["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    im = j["images"][j["textures"][m]["source"]]
    b = np.frombuffer(hg.view_bytes(j, bn, im["bufferView"]), np.uint8)
    return cv2.cvtColor(cv2.imdecode(b, 1), cv2.COLOR_BGR2RGB).astype(np.float32) / 255


def colours(j, bn, pr, uv_at):
    px = tex(j, bn, pr)
    h, w = px.shape[:2]
    x = np.clip((uv_at[:, 0] % 1) * w, 0, w - 1).astype(int)
    y = np.clip((uv_at[:, 1] % 1) * h, 0, h - 1).astype(int)
    return px[y, x]


def classes(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / (mx + 1e-6)
    return (mx > SKIN_V) & (sat < SKIN_S), (mx < HAIR_V) & (sat < HAIR_S)


def tri_colours(j, bn, pr, T):
    uv = hg.acc(j, bn, pr["attributes"]["TEXCOORD_0"])
    return classes(colours(j, bn, pr, uv[T].mean(1)))


def umeyama(src, dst):
    ms, md = src.mean(0), dst.mean(0)
    A, B = src - ms, dst - md
    U, S, Vt = np.linalg.svd(B.T @ A / len(src))
    D = np.eye(3)
    if np.linalg.det(U) * np.linalg.det(Vt) < 0:
        D[2, 2] = -1
    R = U @ D @ Vt
    s = (S * np.diag(D)).sum() / A.var(0).sum()
    return s, R, md - s * R @ ms


def face_points(j, bn, pr, box, sel_from=None):
    P = hg.acc(j, bn, pr["attributes"]["POSITION"]).astype(np.float64)
    N = hg.acc(j, bn, pr["attributes"]["NORMAL"]).astype(np.float64)
    T = np.unique(hg.acc(j, bn, pr["indices"]))
    sk, _ = classes(colours(j, bn, pr, hg.acc(j, bn, pr["attributes"]["TEXCOORD_0"])))
    m = np.zeros(len(P), bool)
    m[T] = True
    return P, N, m & sk & (N[:, 2] > 0.3)


def fit_bust(live, bust, init):
    """similarity (s, R, t) bust -> live frame from the face skin."""
    lj, lb, lp = live
    bj, bb, bp = bust
    LP, LN, lm = face_points(lj, lb, lp, None)
    lm &= (LP[:, 1] > FACE_LIVE[0]) & (LP[:, 1] < FACE_LIVE[1]) & (np.abs(LP[:, 0]) < FACE_LIVE[2]) & (LP[:, 2] > 0.02)
    BP, BN, bm = face_points(bj, bb, bp, None)
    L = LP[lm]
    s0, tx, ty, tz = init
    # bust face box: keep the skin in front of the hair around the middle of the face (x +-0.3, above the neck)
    bm &= (BP[:, 1] > FACE_BUST[0]) & (BP[:, 1] < FACE_BUST[1]) & (np.abs(BP[:, 0]) < FACE_BUST[2])
    B = BP[bm]
    # init: matching centroids, scale s0
    s, R, t = s0, np.eye(3), L.mean(0) - s0 * B.mean(0) + np.array([tx, ty, tz])
    # bust y window: grow it until the chin lines match
    for it in range(60):
        Bt = s * (B @ R.T) + t
        tree = cKDTree(Bt)
        d, i = tree.query(L)
        keep = d < np.quantile(d, 0.7)
        s2, R2, t2 = umeyama(B[i[keep]], L[keep])
        s, R, t = s2, R2, t2
    Bt = s * (B @ R.T) + t
    d, _ = cKDTree(Bt).query(L)
    print("FIT scale %.4f rms(70%%) %.5f median %.5f n %d/%d" % (s, np.sqrt((np.sort(d)[: int(.7 * len(d))] ** 2).mean()), np.median(d), len(L), len(B)))
    return s, R, t


MIN_ISLAND = 1500


def drop_islands(T, sel, P, min_tris):
    """keep only vertex-connected groups of selected triangles with at least min_tris triangles (kills specks/shards)."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    _, inv = np.unique(np.round(P * 1e4).astype(np.int64), axis=0, return_inverse=True)
    nv = int(inv.max()) + 1
    idx = np.flatnonzero(sel)
    tv = inv[T[idx]]
    g = coo_matrix((np.ones(len(idx) * 2), (np.r_[tv[:, 0], tv[:, 0]], np.r_[tv[:, 1], tv[:, 2]])), shape=(nv, nv))
    _, lab = connected_components(g, directed=False)
    tl = lab[tv[:, 0]]
    cnt = np.bincount(tl, minlength=lab.max() + 1)
    out = sel.copy()
    out[idx[cnt[tl] < min_tris]] = False
    print("islands dropped: %d tris" % int((sel.sum() - out.sum())))
    return out


def weapon_comps(T, P, ha, min_tris=2000, max_hair=0.03):
    """tris of welded components that are big but carry (almost) no hair texels: weapons/props, never dropped."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    _, inv = np.unique(np.round(P * 1e4).astype(np.int64), axis=0, return_inverse=True)
    nv = int(inv.max()) + 1
    tv = inv[T]
    g = coo_matrix((np.ones(len(T) * 2), (np.r_[tv[:, 0], tv[:, 0]], np.r_[tv[:, 1], tv[:, 2]])), shape=(nv, nv))
    _, lab = connected_components(g, directed=False)
    tl = lab[tv[:, 0]]
    cnt = np.bincount(tl)
    hf = np.bincount(tl, weights=ha.astype(float)) / np.maximum(cnt, 1)
    prot = (cnt >= min_tris) & (hf <= max_hair)
    print("protected weapon comps: %d tris" % int(prot[tl].sum()))
    return prot[tl]


def in_face(c):
    """triangle centroids (live frame) inside the face oval: eyes, brows, lips, lashes stay the face's, not hair."""
    e = ((c[:, 0] - FACE_OVAL[0]) / FACE_OVAL[2]) ** 2 + ((c[:, 1] - FACE_OVAL[1]) / FACE_OVAL[3]) ** 2
    return (e < 1) & (c[:, 2] > FACE_OVAL[4])


def in_choker(c):
    return (np.abs(c[:, 0]) < CHOKER_BOX[0]) & (c[:, 2] > 0) & (c[:, 1] > CHOKER_BOX[1]) & (c[:, 1] < CHOKER_BOX[2])


def swap(live_path, bust_path, out_path, init, hair_bot, live_x=LIVE_X, other_top=PIN_TOP):
    global LIVE_X
    LIVE_X = live_x
    lj, lb = hg.read(live_path)
    bj, bb = hg.read(bust_path)
    lf, bp = hg.face_prim(lj, lb)[1], hg.face_prim(bj, bb)[1]
    s, R, t = fit_bust((lj, lb, lf), (bj, bb, bp), init)
    # --- the bust's hair triangles in the live frame
    BPos = hg.acc(bj, bb, bp["attributes"]["POSITION"]).astype(np.float64)
    BN = hg.acc(bj, bb, bp["attributes"]["NORMAL"]).astype(np.float64)
    BT = hg.acc(bj, bb, bp["indices"]).reshape(-1, 3)
    Wp = s * (BPos @ R.T) + t
    # the weapons cross just behind the live hair: flatten the new hair's back below the head so they stay in front
    w = np.clip((BACK_Y1 - Wp[:, 1]) / (BACK_Y1 - BACK_Y0), 0, 1)
    Wp[:, 2] = np.where(Wp[:, 2] < BACK_Z, BACK_Z + (Wp[:, 2] - BACK_Z) * (1 - w * (1 - BACK_K)), Wp[:, 2])
    Wn = BN @ R.T
    c = Wp[BT].mean(1)
    bsk, bha = tri_colours(bj, bb, bp, BT)
    in_zone = (c[:, 1] > hair_bot) & (np.abs(c[:, 0]) < LIVE_X) & ~in_face(c) & ~in_choker(c)
    pins = (~bsk) & (~bha) & (c[:, 1] > PIN_TOP) & (np.abs(c[:, 0]) < 0.2)
    bsel = in_zone & (bha | pins)
    bsel = drop_islands(BT, bsel, BPos, MIN_ISLAND)
    print("BUST hair tris %d (pins %d)" % (bsel.sum(), (pins & in_zone).sum()))
    out = hg.Out()
    # --- live primitives minus their hair
    live_prims = []
    dropped = 0
    for nd in lj["nodes"]:
        if "mesh" not in nd:
            continue
        prs = []
        for pr in lj["meshes"][nd["mesh"]]["primitives"]:
            if nd.get("name") == "head_graft":
                P = hg.acc(lj, lb, pr["attributes"]["POSITION"]).astype(np.float64)
                T = hg.acc(lj, lb, pr["indices"]).reshape(-1, 3)
                lc = P[T].mean(1)
                sk, ha = tri_colours(lj, lb, pr, T)
                zone = (lc[:, 1] > hair_bot) & (np.abs(lc[:, 0]) < LIVE_X)
                drop = zone & ~in_face(lc) & ~in_choker(lc) & (ha | ((~sk) & (~ha) & (lc[:, 1] > other_top)))
                # old side-hair blocks beside the face (head prim): non-skin, close to the head axis, below the crown
                drop |= (~sk) & ~in_face(lc) & ~in_choker(lc) & (np.abs(lc[:, 0]) < SIDE_X) & (lc[:, 1] > SIDE_BOT) & (lc[:, 1] < SIDE_TOP)
                drop &= ~weapon_comps(T, P, ha)
                dropped += int(drop.sum())
                prs.append(out.prim((lj, lb), pr, T[~drop].astype(np.uint32).ravel()))
            else:
                prs.append(out.prim((lj, lb), pr))
        live_prims.append((nd.get("name"), prs))
    print("LIVE hair tris dropped %d" % dropped)
    # --- new hair primitive (compact vertex set, transformed)
    used = np.unique(BT[bsel])
    remap = np.full(len(BPos), -1, np.int64)
    remap[used] = np.arange(len(used))
    uvs = hg.acc(bj, bb, bp["attributes"]["TEXCOORD_0"])[used]
    nrm = Wn[used] / np.maximum(np.linalg.norm(Wn[used], axis=1, keepdims=True), 1e-9)
    mat = out.copy((bj, bb), "materials", bp["material"])
    out.j["materials"][mat]["name"] = "hair_new"
    hair = {
        "attributes": {
            "POSITION": out.array(Wp[used].astype(np.float32), "VEC3"),
            "NORMAL": out.array(nrm.astype(np.float32), "VEC3"),
            "TEXCOORD_0": out.array(uvs, "VEC2"),
        },
        "indices": out.array(remap[BT[bsel]].astype(np.uint32).ravel(), "SCALAR"),
        "mode": 4,
        "material": mat,
    }
    for name, prs in live_prims:
        if name == "head_graft":
            prs = prs + [hair]
        out.node(name, prs)
    out.write(out_path)
    print("HAIRSWAP -> %s" % out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("live")
    ap.add_argument("bust")
    ap.add_argument("out")
    ap.add_argument("--fit", default="0.36,0,0,0", help="S,TX,TY,TZ initial scale and shift of the bust into the live frame")
    ap.add_argument("--live-x", type=float, default=LIVE_X, help="half-width of the swap zone")
    ap.add_argument("--other-top", type=float, default=PIN_TOP, help="live y above which non-skin non-hair triangles are also dropped (old hair highlights)")
    ap.add_argument("--hair-bot", type=float, default=0.20, help="live +Y below which no hair is swapped")
    a = ap.parse_args()
    swap(a.live, a.bust, a.out, [float(v) for v in a.fit.split(",")], a.hair_bot, a.live_x, a.other_top)


if __name__ == "__main__":
    main()
