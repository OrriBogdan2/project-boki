"""Grimble (dredge) native r8-r9: loose islands deleted, cut holes closed, the goo's tail hung on a bone chain.

Runs on the r7 body (tools/meshy/dredge_reskin.py output) and writes the game glb:

- islands: every group of triangles that touches no other (vertices within ISLAND_TOL) and has fewer than MIN_TRIS
  triangles is deleted, per body primitive (skin, goo, leather pack; the brass fittings and the coin pile are made of
  many small pieces on purpose). `--islands FILE` counts them (the proof of "0 loose islands").
- holes (r9): Meshy grew the heel crescent out of the calf and left open slits on the calf's back; every open
  boundary loop that touches the cut or lies in CALF_BOX (and is on a piece that stays) gets a skin-coloured dome.
- tail chain: four bones (GooTail0..3) under RightHand at the goo's own centre line, the goo below the hand weighted
  along them by height (hat weights, so it bends between two bones and never shears against the hips). Baked into
  every clip: each segment keeps its rest direction (it hangs) and follows the bone above it by only TAIL_FOLLOW,
  with a lag that grows down the chain, so a swung arm drags the tail round instead of stretching it.

  python3 tools/meshy/dredge_post.py OUT.glb IN.glb
  python3 tools/meshy/dredge_post.py --islands FILE.glb

Needs numpy and scipy (the venv).
"""

import io
import sys

import dredge_reskin as rs
import native_pack as n
import numpy as np
import scipy.sparse as sp
from scipy.sparse.csgraph import connected_components
from PIL import Image
from scipy.spatial import cKDTree

ISLAND_TOL = 0.001  # m: vertices this close are one vertex (UV seams, decimation splits)
MIN_TRIS = 1000  # an island of fewer triangles is a loose chunk (the body, goo, pack and cap are all far larger)
CLEANED = ("skin-native", "skin-goo", "leather-pack")  # the primitives that must be one piece each
BLADE_X, BLADE_Y = (-0.17, 0.02), (0.10, 0.62)  # m: the pale crescent Meshy fused to the right heel (skin, rest pose)
CALF_BOX = (np.array([-0.32, 0.15, -0.36]), np.array([0.0, 0.6, -0.12]))  # m: right calf, back half (rest pose)
# holes closed after the cut: dome rings (big loops), bulge (share of the radius), smallest loop filled
FILL_RINGS, FILL_BULGE, FILL_MIN = 4, 0.25, 6
BLADE_GROW = 0.06  # m: pale triangles this close to the crescent's body go with it (its root at the foot)
HAND = "RightHand"
CHAIN_Y = (0.97, 0.70, 0.43, 0.16)  # m: rest height of GooTail0..3 (the first is the hand's own origin)
FADE_Y = 1.35  # m: the goo above this keeps its arm weights; between this and the hand it blends into GooTail0
# share of the bone above's turn each segment takes (the first is the hand's own); the rest it keeps hanging
TAIL_FOLLOW = (1.0, 0.6, 0.5, 0.5)
LAG = (0.0, 0.4, 0.5, 0.6)  # per frame carry-over of each segment's direction (a later swing down the chain)
FPS = 30.0
# the attack clip keeps this share of its head and upper-spine bend
# r10 right foot: replaced below FOOT_CUT (m) by the mirrored left one; FOOT_MID: |x| beyond which a triangle is a leg's
# and below FOOT_OUT (the hands hang at the knee: x 0.5 m and out)
FOOT_CUT, FOOT_MID, FOOT_OUT = 0.62, 0.08, 0.40
SEAM_BAND, SEAM_ITER = 0.05, 8  # m, rounds: the seam's relax
LUNGE_CLIP, LUNGE_BONES, LUNGE_KEEP = "Attack", ("Spine02", "Spine01", "neck", "Head"), 0.35
LEAN_FREE, LEAN_CUT = 12.0, 0.6  # deg, share: r10 the attack's forward lean past LEAN_FREE is cut by LEAN_CUT


def island_labels(pos, faces, tol=ISLAND_TOL):
    """Island index per triangle: triangles are one island when they share a vertex or vertices within tol."""
    used = np.unique(faces)
    slot = np.zeros(len(pos), np.int64)
    slot[used] = np.arange(len(used))
    pairs = cKDTree(pos[used]).query_pairs(tol, output_type="ndarray")
    f = slot[faces]
    e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], pairs])
    g = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), (len(used), len(used)))
    return connected_components(g, directed=False)[1][f[:, 0]]


def prim_faces(js, b, prim):
    ia = js["accessors"][prim["indices"]]
    dt = np.uint32 if ia["componentType"] == 5125 else np.uint16
    raw = np.frombuffer(n.view_bytes(js, b, ia["bufferView"]), dt, ia["count"], ia.get("byteOffset", 0))
    return raw.reshape(-1, 3).astype(np.int64)


def pale_tris(js, b, prim, pos, faces):
    """Triangles whose texture is the goo's pale pink (the crescent's colour; the skin proper is darker)."""
    tex = js["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    bv = js["bufferViews"][js["images"][js["textures"][tex]["source"]]["bufferView"]]
    px = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0) :][: bv["byteLength"]])).convert("RGB"))
    uv = n.floats(js, b, prim["attributes"]["TEXCOORD_0"])[faces].mean(1)
    h, w = px.shape[:2]
    c = px[(np.clip(uv[:, 1], 0, 0.999) * h).astype(int), (np.clip(uv[:, 0] % 1, 0, 0.999) * w).astype(int)].astype(int)
    return (c[:, 0] > 170) & (c[:, 1] > 110) & (c[:, 2] > 150)


def drop_blade(js, b, out):
    """Deletes the pale crescent on the right heel (a sheet of skin rising beside the shin); returns its triangles."""
    prim = js["meshes"][0]["primitives"][0]
    pos = n.floats(js, b, prim["attributes"]["POSITION"])
    f = prim_faces(js, b, prim)
    pale = pale_tris(js, b, prim, pos, f)
    c = pos[f].mean(1)
    core = pale & (c[:, 0] > BLADE_X[0]) & (c[:, 0] < BLADE_X[1]) & (c[:, 1] > BLADE_Y[0]) & (c[:, 1] < BLADE_Y[1])
    idx = np.flatnonzero(core)
    lab = island_labels(pos, f[idx], 0.006)
    body = np.zeros(len(f), bool)
    body[idx[lab == np.bincount(lab).argmax()]] = True  # the crescent is the biggest pale piece in the box
    near = cKDTree(pos[np.unique(f[body])]).query(c)[0] < BLADE_GROW
    gone = body | (near & pale & (c[:, 1] > 0.02))
    patch, holes = fill_cut(js, b, out, prim, pos, f, gone)
    keep = np.concatenate([f[~gone], patch])
    js["accessors"].append(
        {"bufferView": out.add_view(keep.astype(np.uint32).tobytes()), "componentType": 5125,
         "count": len(keep) * 3, "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    return int(gone.sum()), holes


def rim_loops(f, gone, w, pos):
    """The cut's rim: every open boundary of the kept triangles (welded) that touches a deleted triangle, as
    loops of real vertices (taken from the kept side), ordered by walking, or by angle round the loop's centre
    where the boundary is not one clean cycle."""
    kf = f[~gone]
    e = np.concatenate([kf[:, [0, 1]], kf[:, [1, 2]], kf[:, [2, 0]]])
    ew = np.sort(w[e], 1)
    u, inv, cnt = np.unique(ew, axis=0, return_inverse=True, return_counts=True)
    bd = cnt[inv.ravel()] == 1
    m = int(w.max()) + 1
    k, lab = connected_components(sp.coo_matrix((np.ones(bd.sum()), (ew[bd, 0], ew[bd, 1])), (m, m)), directed=False)
    cutv = np.zeros(m, bool)
    cutv[w[f[gone]].ravel()] = True
    rep = {}
    for (a, b_) in e[bd]:
        rep.setdefault(w[a], a), rep.setdefault(w[b_], b_)
    nb = {}
    for wa, wb in ew[bd]:
        nb.setdefault(wa, []).append(wb), nb.setdefault(wb, []).append(wa)
    bv = np.unique(ew[bd])
    isl = island_labels(pos, kf)  # a loop on a piece the island pass will delete is left open
    big = np.zeros(m, bool)
    big[w[kf[np.bincount(isl)[isl] >= MIN_TRIS]].ravel()] = True
    loops = []
    p0 = np.zeros((m, 3))
    p0[w] = pos
    inbox = np.all((p0 > CALF_BOX[0]) & (p0 < CALF_BOX[1]), 1)  # Meshy's own open slits on the back of the calf
    for l in np.unique(lab[bv[cutv[bv] | inbox[bv]]]):
        vs = bv[lab[bv] == l]
        if len(vs) < FILL_MIN or not big[vs].all():
            continue
        loop, prev, cur = [vs[0]], None, vs[0]
        while len(loop) <= len(vs):
            nxt = [x for x in nb[cur] if x != prev]
            if len(nb[cur]) != 2 or not nxt or nxt[0] == vs[0]:
                break
            prev, cur = cur, nxt[0]
            loop.append(cur)
        if len(loop) != len(vs) or any(len(nb[x]) != 2 for x in vs):  # not a clean cycle: order by angle
            p = pos[[rep[x] for x in vs]]
            c = p.mean(0)
            ax = np.linalg.svd(p - c)[2]
            ang = np.arctan2((p - c) @ ax[1], (p - c) @ ax[0])
            loop = list(vs[np.argsort(ang)])
        loops.append([rep[x] for x in loop])
    return loops


def fill_cut(js, b, out, prim, pos, f, gone):
    """Closes the holes the deletion opened (Meshy grew the crescent out of the calf, no skin is left under it):
    each rim loop gets a dome of FILL_RINGS rings bulging along the rim's normal, skinned like the nearest rim
    vertex and coloured by one skin texel (the median rim colour), appended to the shared vertex arrays."""
    att = prim["attributes"]
    q = np.round(pos / ISLAND_TOL).astype(np.int64)
    w = np.unique(q, axis=0, return_inverse=True)[1].ravel()
    loops = rim_loops(f, gone, w, pos)
    arr = read_attrs(js, b, att)
    tex = js["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    bv = js["bufferViews"][js["images"][js["textures"][tex]["source"]]["bufferView"]]
    px = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0):][: bv["byteLength"]])).convert("RGB")).astype(int)
    h, wd = px.shape[:2]
    new = {k: [] for k in arr}
    base, tris = len(pos), []
    for loop in loops:
        r = np.array(loop)
        rings_n = 1 if len(r) < 16 else 2 if len(r) < 60 else FILL_RINGS
        uv = arr["TEXCOORD_0"][r]
        col = px[(np.clip(uv[:, 1], 0, 0.999) * h).astype(int), (np.clip(uv[:, 0] % 1, 0, 0.999) * wd).astype(int)]
        skin_uv = uv[np.argmin(np.abs(col - np.median(col, 0)).sum(1))]
        p = pos[r]
        c = p.mean(0)
        nrm = arr["NORMAL"][r].mean(0)
        nrm /= np.linalg.norm(nrm)
        rad = np.linalg.norm(p - c, axis=1).mean()
        rings = []
        for k in range(rings_n + 1):  # ring 0 is a copy of the rim (new uv), the last ring is the centre
            t = k / rings_n
            ring = p * (1 - t) + c * t + nrm * FILL_BULGE * rad * np.sqrt(max(0.0, 1 - (1 - t) ** 2))
            rings.append(ring[:1] if k == rings_n else ring)
        pts = np.concatenate(rings)
        near = r[cKDTree(p).query(pts)[1]]
        for k in arr:
            v = arr[k][near].copy()
            if k == "POSITION":
                v = pts
            elif k == "NORMAL":
                v = np.repeat(nrm[None], len(pts), 0)
            elif k == "TEXCOORD_0":
                v = np.repeat(skin_uv[None], len(pts), 0)
            new[k].append(v)
        m = len(r)
        idx = [base + k * m + np.arange(m) for k in range(rings_n)] + [np.array([base + rings_n * m])]
        for k in range(rings_n):
            a0, a1 = idx[k], np.roll(idx[k], -1)
            if k == rings_n - 1:
                tris += [np.stack([a0, a1, np.repeat(idx[-1], m)], 1)]
            else:
                b0, b1 = idx[k + 1], np.roll(idx[k + 1], -1)
                tris += [np.stack([a0, a1, b1], 1), np.stack([a0, b1, b0], 1)]
        lt = np.concatenate(tris[-(2 * rings_n - 1):]) - base
        fn = np.cross(pts[lt[:, 1]] - pts[lt[:, 0]], pts[lt[:, 2]] - pts[lt[:, 0]]).sum(0)
        if fn @ nrm < 0:  # wound against the skin: flip this loop's triangles
            for j in range(len(tris) - (2 * rings_n - 1), len(tris)):
                tris[j] = tris[j][:, [0, 2, 1]]
        base += len(pts)
    if not loops:
        return np.zeros((0, 3), np.int64), 0
    append_attrs(js, out, att, arr, new)
    return np.concatenate(tris), len(loops)


def read_attrs(js, b, att):
    """Every vertex array of a primitive (floats, or the uint16 joints) by attribute name."""
    return {k: (n.floats(js, b, a) if js["accessors"][a]["componentType"] == 5126 else
                np.frombuffer(n.view_bytes(js, b, js["accessors"][a]["bufferView"]), np.uint16,
                              js["accessors"][a]["count"] * 4).reshape(-1, 4).copy()) for k, a in att.items()}


def append_attrs(js, out, att, arr, new):
    """Writes arr + the new vertices (lists of arrays per attribute) as new accessors, repointing every primitive
    that shared the old ones (the goo shares the skin's vertex arrays)."""
    for k, a in list(att.items()):
        full = np.concatenate([arr[k]] + new[k])
        if js["accessors"][a]["componentType"] == 5126:
            acc = out.add_floats(full, js["accessors"][a]["type"])
            if k == "POSITION":
                js["accessors"][acc]["min"], js["accessors"][acc]["max"] = full.min(0).tolist(), full.max(0).tolist()
        else:
            js["accessors"].append({"bufferView": out.add_view(full.astype(np.uint16).tobytes()),
                                    "componentType": 5123, "count": len(full), "type": "VEC4"})
            acc = len(js["accessors"]) - 1
        for p2 in js["meshes"][0]["primitives"]:
            if p2["attributes"].get(k) == a:
                p2["attributes"][k] = acc


def open_rim(f, w, sel):
    """Welded ids of the vertices on the open boundary of triangles f[sel]."""
    e = np.sort(w[np.concatenate([f[sel][:, [0, 1]], f[sel][:, [1, 2]], f[sel][:, [2, 0]]])], 1)
    u, cnt = np.unique(e, axis=0, return_counts=True)
    return np.unique(u[cnt == 1])


def contour_at(pts, ctr, ang):
    """Radius of the closed contour pts (x, z) round ctr at the angles ang (polar interpolation)."""
    a = np.arctan2(pts[:, 1] - ctr[1], pts[:, 0] - ctr[0])
    r = np.linalg.norm(pts - ctr, axis=1)
    o = np.argsort(a)
    a, r = a[o], r[o]
    return np.interp(ang, np.r_[a - 2 * np.pi, a, a + 2 * np.pi], np.r_[r, r, r])


def shells(pos, f, tris):
    """The big islands (>= MIN_TRIS/10 triangles) among triangles tris, outermost first (mean distance from their
    common centre, in x and z)."""
    lab = island_labels(pos, f[tris])
    ctr = pos[f[tris]].reshape(-1, 3).mean(0)
    big = [k for k in range(lab.max() + 1) if (lab == k).sum() >= MIN_TRIS // 10]
    reach = {k: np.linalg.norm((pos[f[tris[lab == k]]].reshape(-1, 3) - ctr)[:, [0, 2]], axis=1).mean() for k in big}
    return [tris[lab == k] for k in sorted(big, key=lambda k: -reach[k])]


def replace_foot(js, b, out):
    """r10: Meshy fused a cluster of dark spiky shards into the right instep and layered torn flaps up the shin
    (skin, not goo; deleting or snapping them in r9 left gaps or strands). The right leg below FOOT_CUT (lower
    thigh, where it is clean again) is replaced by a mirror copy of the clean left one: x flipped (normals and
    tangents too), Left* bones swapped for Right*, moved by the offset that best fits it to the right thigh.
    Both legs are two shells 4 mm apart; each copied shell is welded to its own right shell along a flat seam:
    both rims go onto the copy's cross-section at FOOT_CUT and snap onto each other's vertices, normals shared,
    so the leg stays one piece. Returns (tris removed, tris added, shift, rim vertices, largest move)."""
    prim = js["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    arr = read_attrs(js, b, att)
    pos, f = arr["POSITION"], prim_faces(js, b, prim)
    c = pos[f].mean(1)
    leg_r = (c[:, 0] < -FOOT_MID) & (c[:, 0] > -FOOT_OUT)
    leg_l = (c[:, 0] > FOOT_MID) & (c[:, 0] < FOOT_OUT)
    gone = leg_r & (c[:, 1] < FOOT_CUT)
    # fit: shift the mirrored left thigh onto the right one in the band above the cut (nearest-point median)
    band_r = pos[np.unique(f[leg_r & (c[:, 1] > FOOT_CUT) & (c[:, 1] < FOOT_CUT + 0.08)])]
    band_l = pos[np.unique(f[leg_l & (c[:, 1] > FOOT_CUT) & (c[:, 1] < FOOT_CUT + 0.08)])] * [-1.0, 1.0, 1.0]
    shift, tree = np.zeros(3), cKDTree(band_r)
    for _ in range(5):
        shift = np.median(band_r[tree.query(band_l + shift)[1]] - band_l, 0)
    shift[1] = 0.0  # the sole stays on the ground
    q = np.round(pos / ISLAND_TOL).astype(np.int64)
    w = np.unique(q, axis=0, return_inverse=True)[1].ravel()
    shells_l = shells(pos, f, np.flatnonzero(leg_l & (c[:, 1] < FOOT_CUT)))
    src = np.zeros(len(f), bool)
    for t in shells_l:
        src[t] = True
    sv = np.unique(f[src])
    slot = np.zeros(len(pos), np.int64)
    slot[sv] = np.arange(len(sv))
    mp = pos[sv] * [-1.0, 1.0, 1.0] + shift
    nrm_l = arr["NORMAL"][sv] * [-1.0, 1.0, 1.0]
    shells_r = shells(pos, f, np.flatnonzero(leg_r & (c[:, 1] > FOOT_CUT) & (c[:, 1] < FOOT_CUT + 0.1)))
    rim_all = np.isin(w, open_rim(f, w, ~gone & leg_r)) & (np.abs(pos[:, 1] - FOOT_CUT) < 0.04)
    moved, nrim = [0.0], 0
    for tl, tr in zip(shells_l, shells_r):
        sel = np.zeros(len(f), bool)
        sel[tl] = True
        lv = slot[np.unique(f[tl])]
        ti = lv[np.isin(w[sv[lv]], open_rim(f, w, sel)) & (mp[lv, 1] > FOOT_CUT - 0.04)]
        mp[ti, 1] = FOOT_CUT
        ctr = mp[ti][:, [0, 2]].mean(0)
        rv = np.unique(f[tr])
        rim = rv[rim_all[rv]]
        nrim += len(rim)
        ang = np.arctan2(pos[rim, 2] - ctr[1], pos[rim, 0] - ctr[0])
        rad = contour_at(mp[ti][:, [0, 2]], ctr, ang)
        on = np.c_[ctr[0] + rad * np.cos(ang), np.full(len(rim), FOOT_CUT), ctr[1] + rad * np.sin(ang)]
        j = ti[cKDTree(mp[ti]).query(on)[1]]
        moved.append(float(np.linalg.norm(mp[j] - pos[rim], axis=1).max()))
        arr["POSITION"][rim] = mp[j]
        # and back: every copy rim vertex onto the nearest point of the thigh's rim edges (exact T-junctions: no
        # crack for the inner shell to show through), normals shared
        kept = ~gone & leg_r
        ke = np.concatenate([f[kept][:, [0, 1]], f[kept][:, [1, 2]], f[kept][:, [2, 0]]])
        kw = np.sort(w[ke], 1)
        u, inv, cnt = np.unique(kw, axis=0, return_inverse=True, return_counts=True)
        rw = np.zeros(int(w.max()) + 1, bool)
        rw[w[rim]] = True
        be = ke[(cnt[inv.ravel()] == 1) & rw[w[ke[:, 0]]] & rw[w[ke[:, 1]]]]
        a0, a1 = pos[be[:, 0]], pos[be[:, 1]]
        d_ = a1 - a0
        best = np.full(len(ti), np.inf)
        proj = mp[ti].copy()
        for s0 in range(0, len(be), 256):
            A, D = a0[s0:s0 + 256], d_[s0:s0 + 256]
            t_ = np.clip(np.einsum("pij,ij->pi", mp[ti][:, None] - A[None], D) / np.maximum((D * D).sum(1), 1e-12), 0, 1)
            pt = A[None] + t_[..., None] * D[None]
            dist = np.linalg.norm(pt - mp[ti][:, None], axis=2)
            k_ = dist.argmin(1)
            better = dist[np.arange(len(ti)), k_] < best
            best[better] = dist[np.arange(len(ti)), k_][better]
            proj[better] = pt[np.arange(len(ti)), k_][better]
        moved.append(float(best.max()))
        mp[ti] = proj
        kk = cKDTree(pos[rim]).query(mp[ti])[1]
        for a_, b_ in list(zip(ti, rim[kk])) + list(zip(j, rim)):
            m_ = arr["NORMAL"][b_] + nrm_l[a_]
            arr["NORMAL"][b_] = nrm_l[a_] = m_ / max(np.linalg.norm(m_), 1e-9)
    names = [js["nodes"][jn]["name"] for jn in js["skins"][0]["joints"]]
    swap = np.arange(max(len(names), int(arr["JOINTS_0"].max()) + 1))
    for i, nm in enumerate(names):
        if nm.startswith("Left") and "Right" + nm[4:] in names:
            swap[i] = names.index("Right" + nm[4:])
    new = {}
    for k in arr:
        v = arr[k][sv].copy()
        if k == "POSITION":
            v = mp
        elif k == "NORMAL":
            v = nrm_l
        elif k == "TANGENT":
            v[:, 0] *= -1
            v[:, 3] *= -1
        elif k == "JOINTS_0":
            v = swap[v]
        new[k] = [v]
    added = (len(pos) + slot[f[src]])[:, [0, 2, 1]]  # mirrored: wind the other way
    append_attrs(js, out, att, arr, new)
    keep = np.concatenate([f[~gone], added])
    js["accessors"].append({"bufferView": out.add_view(keep.astype(np.uint32).tobytes()), "componentType": 5125,
                            "count": len(keep) * 3, "type": "SCALAR"})
    prim["indices"] = len(js["accessors"]) - 1
    return int(gone.sum()), int(src.sum()), np.round(shift, 3).tolist(), nrim, round(max(moved), 3)


def relax_seam(js, b, out):
    """Umbrella smoothing (welded, SEAM_ITER rounds) of the right leg's skin within SEAM_BAND of the seam: untangles
    the folds where the thigh's rim met the copy (flipped triangles 48 -> see the log) and softens the step."""
    prim = js["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    arr = read_attrs(js, b, att)
    pos, f = arr["POSITION"], prim_faces(js, b, prim)
    q = np.round(pos / ISLAND_TOL).astype(np.int64)
    w = np.unique(q, axis=0, return_inverse=True)[1].ravel()
    m = int(w.max()) + 1
    wf = w[f]
    e = np.concatenate([wf[:, [0, 1]], wf[:, [1, 2]], wf[:, [2, 0]]])
    adj = sp.coo_matrix((np.ones(len(e) * 2), (np.r_[e[:, 0], e[:, 1]], np.r_[e[:, 1], e[:, 0]])), (m, m)).tocsr()
    adj.data[:] = 1.0
    deg = np.asarray(adj.sum(1)).ravel()
    p = np.zeros((m, 3))
    p[w] = pos
    used = np.zeros(m, bool)
    used[wf.ravel()] = True
    move = used & (p[:, 0] < -FOOT_MID) & (p[:, 0] > -FOOT_OUT) & (np.abs(p[:, 1] - FOOT_CUT) < SEAM_BAND)
    t = 1 - np.abs(p[:, 1] - FOOT_CUT) / SEAM_BAND  # full strength at the seam, none at the band's edge
    for _ in range(SEAM_ITER):
        avg = (adj @ p) / np.maximum(deg, 1)[:, None]
        p[move] += 0.5 * t[move, None] * (avg[move] - p[move])
    arr["POSITION"] = p[w]
    # the inner shell near the seam wears the outer shell's texture: a crack shows skin, not the dark inside
    c = arr["POSITION"][f].mean(1)
    band = np.flatnonzero((c[:, 0] < -FOOT_MID) & (c[:, 0] > -FOOT_OUT) & (np.abs(c[:, 1] - FOOT_CUT) < 2 * SEAM_BAND))
    sh = shells(arr["POSITION"], f, band)
    if len(sh) > 1:
        ov = np.unique(f[sh[0]])
        iv = np.unique(np.concatenate([f[t].ravel() for t in sh[1:]]))
        arr["TEXCOORD_0"][iv] = arr["TEXCOORD_0"][ov[cKDTree(arr["POSITION"][ov]).query(arr["POSITION"][iv])[1]]]
    keys = {k: att[k] for k in ("POSITION", "TEXCOORD_0")}
    append_attrs(js, out, keys, {k: arr[k] for k in keys}, {k: [] for k in keys})
    return int(move.sum())


def straighten_lunge(rig, out):
    """r10: after the spine cut the attack still leans 36 deg forward at the slam (idle and run 10): the Hips
    pitch it in. Spine02's keys get a counter-turn about the world's side axis (x) of LEAN_CUT of the lean past
    LEAN_FREE, so the upper body rises and the legs keep their plant. Returns the old and new peak lean."""
    js, b = rig.js, rig.b
    clip = next(a for a in js["animations"] if a["name"] == LUNGE_CLIP)
    s02 = rig.names.index("Spine02")
    node = rig.joints[s02]
    hips = rig.names.index("Hips")
    head = rig.names.index("Head")
    ch = next(c for c in clip["channels"] if c["target"]["node"] == node and c["target"]["path"] == "rotation")
    smp = clip["samplers"][ch["sampler"]]
    times = n.floats(js, b, smp["input"])[:, 0]
    keys = n.floats(js, b, smp["output"]).astype(float)

    def world(t, i):
        return rig.pose(LUNGE_CLIP, t)[i] @ np.linalg.inv(rig.ibm[i])

    def lean(t):
        v = world(t, head)[:3, 3] - world(t, s02)[:3, 3]
        return np.degrees(np.arctan2(v[2], v[1]))

    before = [lean(t) for t in times]
    for k, t in enumerate(times):
        corr = np.radians(LEAN_CUT * max(0.0, before[k] - LEAN_FREE))
        if corr <= 0:
            continue
        hr = world(t, hips)[:3, :3]
        hr = hr / np.linalg.norm(hr, axis=0)
        cx = np.array([[1, 0, 0], [0, np.cos(-corr), -np.sin(-corr)], [0, np.sin(-corr), np.cos(-corr)]])
        keys[k] = mat_quat(hr.T @ cx @ hr @ rs.quat_mat(keys[k]))
    smp["output"] = out.add_floats(keys, "VEC4")
    return round(max(before)), times, keys


def slerp_to(q, rest, keep):
    """Keys q (frames x xyzw) turned back toward the rest rotation: keep = 1 leaves them, 0 is the rest pose."""
    q = q * np.where((q @ rest) < 0, -1.0, 1.0)[:, None]
    d = np.clip(q @ rest, -1, 1)
    th = np.arccos(d)
    a = np.where(th < 1e-5, 1.0, np.sin(keep * th) / np.maximum(np.sin(th), 1e-9))
    c = np.where(th < 1e-5, 1.0, np.sin((1 - keep) * th) / np.maximum(np.sin(th), 1e-9))
    out = a[:, None] * q + c[:, None] * rest
    return out / np.linalg.norm(out, axis=1, keepdims=True)


def soften_lunge(js, b, out):
    """Meshy's lunge folds the spine forward: the attack clip's bend turned back toward upright by 1 - LUNGE_KEEP."""
    clip = next(a for a in js["animations"] if a["name"] == LUNGE_CLIP)
    for ch in clip["channels"]:
        node = js["nodes"][ch["target"]["node"]]
        if node.get("name") in LUNGE_BONES and ch["target"]["path"] == "rotation":
            smp = clip["samplers"][ch["sampler"]]
            keys = n.floats(js, b, smp["output"]).astype(float)
            rest = np.array(node.get("rotation", [0, 0, 0, 1]))
            smp["output"] = out.add_floats(slerp_to(keys, rest, LUNGE_KEEP), "VEC4")


def count_islands(path):
    js, b = n.load(path)
    for i, prim in enumerate(js["meshes"][0]["primitives"]):
        pos = n.floats(js, b, prim["attributes"]["POSITION"])
        f = prim_faces(js, b, prim)
        size = np.bincount(island_labels(pos, f))
        print(f"{js['materials'][prim['material']]['name']:14s} {len(f):6d} tris, {len(size)} islands, "
              f"{int((size < MIN_TRIS).sum())} under {MIN_TRIS} tris (largest {size.max()})")


def drop_islands(js, b, out):
    """Deletes the small islands of every primitive; returns the number of islands and triangles removed."""
    gone = [0, 0]
    for prim in js["meshes"][0]["primitives"]:
        if js["materials"][prim["material"]]["name"] not in CLEANED:
            continue
        pos = n.floats(js, b, prim["attributes"]["POSITION"])
        f = prim_faces(js, b, prim)
        lab = island_labels(pos, f)
        size = np.bincount(lab)
        keep = size[lab] >= MIN_TRIS
        gone[0] += int((size < MIN_TRIS).sum())
        gone[1] += int((~keep).sum())
        js["accessors"].append(
            {"bufferView": out.add_view(f[keep].astype(np.uint32).tobytes()), "componentType": 5125,
             "count": int(keep.sum()) * 3, "type": "SCALAR"}
        )
        prim["indices"] = len(js["accessors"]) - 1
    return gone


def arc(a, b):
    """The rotation matrix turning unit vector a onto unit vector b (the short way)."""
    v, c = np.cross(a, b), float(a @ b)
    if c < -0.9999:
        axis = np.cross(a, [1.0, 0, 0] if abs(a[0]) < 0.9 else [0, 1.0, 0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def mat_quat(m):
    """Quaternion (x, y, z, w) of a rotation matrix."""
    t = np.trace(m)
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(m)))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + m[i, i] - m[j, j] - m[k, k])
        q = [0.0] * 4
        q[i], q[3] = s / 4, (m[k, j] - m[j, k]) / s
        q[j], q[k] = (m[j, i] + m[i, j]) / s, (m[k, i] + m[i, k]) / s
    q = np.array(q)
    return q / np.linalg.norm(q)


def goo_vertices(js, b):
    """Indices of the goo primitive's vertices (own copy: no other primitive uses them)."""
    prims = js["meshes"][0]["primitives"]
    goo = np.unique(prim_faces(js, b, prims[1]))
    other = np.unique(prim_faces(js, b, prims[0]))
    assert not np.intersect1d(goo, other).size, "goo shares vertices with the skin"
    return goo


def chain_points(pos, hand):
    """Rest origins of GooTail0..3 and the tip: the hand's, then the goo's centre (x, z) in a slab at each height."""
    pts = [hand]
    for y in CHAIN_Y[1:]:
        near = pos[np.abs(pos[:, 1] - y) < 0.06]
        pts.append(np.array([near[:, 0].mean(), y, near[:, 2].mean()]))
    tip = pos[pos[:, 1] < 0.1]
    pts.append(np.array([tip[:, 0].mean(), 0.0, tip[:, 2].mean()]))
    return np.array(pts)


def hat_weights(y, ys):
    """Weights of GooTail0..3 at heights y: 1 above the first and below the last, linear between two bones."""
    w = np.zeros((len(y), len(ys)))
    yc = np.clip(y, ys[-1], ys[0])
    k = np.clip(np.searchsorted(-ys, -yc) - 1, 0, len(ys) - 2)
    f = (ys[k] - yc) / (ys[k] - ys[k + 1])
    w[np.arange(len(y)), k], w[np.arange(len(y)), k + 1] = 1 - f, f
    return w


def new_goo_weights(joints, weights, pos, first, ys):
    """Goo weights (vertices x 4 joints): the arm's above FADE_Y, the tail chain's below the hand."""
    nb = first + len(CHAIN_Y)
    d = rs.dense(joints, weights, nb)
    c = np.clip((FADE_Y - pos[:, 1]) / (FADE_Y - ys[0]), 0, 1)
    c = (c * c * (3 - 2 * c))[:, None]
    d = (1 - c) * d
    d[:, first:] = c * hat_weights(pos[:, 1], ys)
    return rs.top4(d)


def rest_world(rig, name):
    m = np.linalg.inv(rig.ibm[rig.names.index(name)])
    return m[:3, :3], m[:3, 3]


def clip_times(rig, clip):
    top = max(n.floats(rig.js, rig.b, s["input"])[:, 0].max() for s in rig.clips[clip]["samplers"])
    return np.unique(np.r_[np.arange(0, top, 1 / FPS), top])


def tail_keys(rig, clip, rest_pts):
    """Local rotation keys (frames x bones x xyzw) of the chain in one clip (two passes round, so a loop is settled)."""
    ih = rig.names.index(HAND)
    r0, _ = rest_world(rig, HAND)
    seg = rest_pts[1:] - rest_pts[:-1]
    length = np.linalg.norm(seg, axis=1)
    rest_dir = seg / length[:, None]
    times = clip_times(rig, clip)
    held = rest_dir.copy()
    keys = np.zeros((len(times), len(seg), 4))
    for rep in range(2):
        for ti, t in enumerate(times):
            world = rig.pose(clip, t)[ih] @ np.linalg.inv(rig.ibm[ih])
            rh = world[:3, :3]
            rh = rh / np.linalg.norm(rh, axis=0)
            carry = rh @ r0.T  # the hand's turn since rest
            prev = carry
            for k in range(len(seg)):
                follow = prev @ rest_dir[k]
                u = TAIL_FOLLOW[k] * follow + (1 - TAIL_FOLLOW[k]) * rest_dir[k]
                u /= np.linalg.norm(u)
                held[k] = LAG[k] * held[k] + (1 - LAG[k]) * u
                held[k] /= np.linalg.norm(held[k])
                q = arc(rest_dir[k], held[k])
                keys[ti, k] = mat_quat(r0.T @ prev.T @ q @ r0)
                prev = q
    return times, keys


def add_chain(js, b, out, rig, rest_pts):
    """The chain's nodes, skin joints and inverse bind matrices; returns the first new joint index."""
    r0, _ = rest_world(rig, HAND)
    hand_node = rig.joints[rig.names.index(HAND)]
    first = len(rig.joints)
    parent, ibm = hand_node, []
    for k in range(len(CHAIN_Y)):
        node = {"name": f"GooTail{k}", "rotation": [0.0, 0.0, 0.0, 1.0]}
        node["translation"] = (r0.T @ (rest_pts[k] - rest_pts[k - 1])).tolist() if k else [0.0, 0.0, 0.0]
        js["nodes"].append(node)
        idx = len(js["nodes"]) - 1
        js["nodes"][parent].setdefault("children", []).append(idx)
        js["skins"][0]["joints"].append(idx)
        world = np.eye(4)
        world[:3, :3], world[:3, 3] = r0, rest_pts[k]
        ibm.append(np.linalg.inv(world).T.reshape(16))
        parent = idx
    old = n.floats(js, b, js["skins"][0]["inverseBindMatrices"])
    js["skins"][0]["inverseBindMatrices"] = out.add_floats(np.concatenate([old, np.array(ibm)]), "MAT4")
    return first


def add_tail_clips(js, out, baked, first):
    for a, (times, keys) in zip(js["animations"], baked):
        tin = out.add_floats(times, "SCALAR")
        for k in range(len(CHAIN_Y)):
            smp = {"input": tin, "output": out.add_floats(keys[:, k], "VEC4"), "interpolation": "LINEAR"}
            a["samplers"].append(smp)
            node = js["skins"][0]["joints"][first + k]
            a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": {"node": node, "path": "rotation"}})


def build(out_path, in_path):
    rig = rs.Rig(in_path)
    out = n.Out(rig.js, rig.b)
    blade, holes = drop_blade(rig.js, rig.b, out)
    soften_lunge(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)  # (each stage writes and reloads: a new index array lives in the new file's buffer)
    rig = rs.Rig(out_path)
    out = n.Out(rig.js, rig.b)
    foot = replace_foot(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)
    rig = rs.Rig(out_path)
    out = n.Out(rig.js, rig.b)
    relax_seam(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)
    rig = rs.Rig(out_path)
    out = n.Out(rig.js, rig.b)
    gone = drop_islands(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)  # the cleaned body first: the chain stage reads the new index arrays from the file
    rig = rs.Rig(out_path)
    out = n.Out(rig.js, rig.b)
    lean0 = straighten_lunge(rig, out)[0]
    rs.compact(out)
    out.write(out_path)
    rig = rs.Rig(out_path)
    js, b = rig.js, rig.b
    out = n.Out(js, b)
    gv = goo_vertices(js, b)
    prims = js["meshes"][0]["primitives"]
    pos = n.floats(js, b, prims[0]["attributes"]["POSITION"])
    _, joints, weights = rig.verts(0)
    hand = rest_world(rig, HAND)[1]
    rest_pts = chain_points(pos[gv], hand)
    ys = rest_pts[:-1, 1]
    baked = [tail_keys(rig, a["name"], rest_pts) for a in js["animations"]]  # before the new joints exist
    first = add_chain(js, b, out, rig, rest_pts)
    nj, nw = rs.top4(rs.dense(joints, weights, first + len(CHAIN_Y)))
    gj, gw = new_goo_weights(joints[gv], weights[gv], pos[gv], first, ys)
    nj[gv], nw[gv] = gj, gw
    view = out.add_view(nj.astype(np.uint16).tobytes())
    js["accessors"].append({"bufferView": view, "componentType": 5123, "count": len(nj), "type": "VEC4"})
    jacc, wacc = len(js["accessors"]) - 1, out.add_floats(nw, "VEC4")
    for p in prims[:2]:
        p["attributes"]["JOINTS_0"], p["attributes"]["WEIGHTS_0"] = jacc, wacc
    add_tail_clips(js, out, baked, first)
    rs.compact(out)
    out.write(out_path)
    print(f"attack lean peak {lean0} deg before the spine counter-turn")
    print(f"right foot: {foot[0]} tris replaced by {foot[1]} mirrored (shift {foot[2]} m, {foot[3]} rim vertices "
          f"welded, largest move {foot[4]} m)")
    print(f"heel crescent {blade} tris ({holes} holes filled), {gone[0]} islands ({gone[1]} tris), "
          f"chain at {np.round(ys, 2).tolist()}")
    print("written", out_path)


if __name__ == "__main__":
    if sys.argv[1] == "--islands":
        count_islands(sys.argv[2])
    else:
        build(sys.argv[1], sys.argv[2])
