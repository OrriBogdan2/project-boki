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

- r11 (`--r11`, on the r10 glb): Meshy hoard pack (open chest) replaces the bedroll (swap_pack); the open shoulder socket
  is domed (cap_shoulder); stray head/spine weights on the goo go to RightArm (clean_goo_weights); the chain's keys
  keep the forearm's twist (TAIL_TWIST, rebake_tail), which was the flat-ribbon collapse.

  python3 tools/meshy/dredge_post.py OUT.glb IN.glb
  python3 tools/meshy/dredge_post.py --islands FILE.glb
  python3 tools/meshy/dredge_post.py --r11 OUT.glb IN_R10.glb [PACK.glb]   # r11 stages on the r10 glb (never build() twice)
  python3 tools/meshy/dredge_post.py --r17 OUT.glb IN_R16.glb   # r17: goo arm at bind abduction +HANG_OUT, chain hangs (env HANG_KEEP/HANG_OUT/HANG_FOLLOW)
  python3 tools/meshy/dredge_post.py --r12 OUT.glb IN_R11.glb   # r12 tail gather (re-runnable on its own output)
  python3 tools/meshy/dredge_post.py --r13 OUT.glb IN_R12.glb [PACK.glb [UNDER.glb]]   # r13: skin weights, goo puddle, rim caps, retextured pack, straps
                                                     # r13b (same flag): rim caps split into simple cycles wound like their rims, faces
                                                     # below 1.2 m wound to their normals, strap ink room 0 (PACK = r13/pack/rt2/glb.glb)

Needs numpy and scipy (the venv).
"""

import io
import os
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
# r11: share of the hand's twist (turn about the arm's own axis) each segment keeps. Swing-only bones (r10) met the
# forearm's full twist inside the blend zone and the goo tube collapsed to a sheet (a twisted ellipse at 90 deg)
TAIL_TWIST = (1.0, 0.8, 0.55, 0.3)
# r12: the swung tail gathers (shorter along the chain, a little thicker): seen from the game's top-down camera a 1 m
# tail swung level reads as a long flat ribbon, while a hanging one is seen end-on. g rises (smoothstep) from 0 to 1 as
# GooTail0 swings GATHER_DEG away from hanging; the chain keeps 1 - GATHER * g of its length (GooTail1..3 offsets) and
# GooTail0 scales by 1 + (GATHER_THICK - 1) * g (uniform: the node's own frame is not the bind frame, so an axis scale
# would squeeze sideways). GATHER_LAG: per frame carry-over of g (no pops).
GATHER, GATHER_DEG, GATHER_THICK, GATHER_LAG = 0.4, (35.0, 80.0), 1.12, 0.5
TWIST_FROM = "RightForeArm"  # the bone whose twist the chain takes up (the hand's own twist is the wrist's: too much)
# r11: Meshy's goo carries head and spine weights near the shoulder (it follows the head and tears off the arm: the
# worst stretch edges in the attack). Those go to RightArm; this share of RightShoulder's weight goes there too.
STRAY = ("headfront", "Head", "neck", "head_end", "Spine", "Spine01", "Spine02", "Hips")
SHOULDER_TO_ARM = 0.5
# r11 pack: scale of the Meshy hoard (m; its box is about 1.65 x 1.45 x 1.9 m), the x of its centre, the height of its
# base, the z of the back surface it leans on, the texture size
SOCKET_BOX = (np.array([-0.3, 1.2, -0.5]), np.array([-0.05, 1.7, 0.1]))  # m: the open shoulder socket (rest pose)
SOCKET_MIN, SOCKET_RINGS, SOCKET_BULGE = 100, 4, 0.05
PACK_SCALE, PACK_X, PACK_BOTTOM, PACK_BACK_Z, PACK_TEX = 0.45, -0.02, 1.15, -0.25, 1024
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


def axis_turn(axis, ang):
    """Rotation matrix about unit vector axis by ang (Rodrigues)."""
    a = axis / np.linalg.norm(axis)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(ang) * k + (1 - np.cos(ang)) * k @ k


def twist_angle(carry, axis):
    """The angle of the hand's turn about axis once its swing (axis onto carry @ axis) is taken out."""
    tz = arc(axis, carry @ axis).T @ carry
    v = np.array([tz[2, 1] - tz[1, 2], tz[0, 2] - tz[2, 0], tz[1, 0] - tz[0, 1]]) / 2
    return float(np.arctan2(v @ axis, (np.trace(tz) - 1) / 2))


def tail_keys(rig, clip, rest_pts):
    """Local rotation keys (frames x bones x xyzw) of the chain in one clip (two passes round, so a loop is settled)."""
    ih = rig.names.index(HAND)
    r0, _ = rest_world(rig, HAND)
    it, rt0 = rig.names.index(TWIST_FROM), rest_world(rig, TWIST_FROM)[0]
    seg = rest_pts[1:] - rest_pts[:-1]
    length = np.linalg.norm(seg, axis=1)
    rest_dir = seg / length[:, None]
    times = clip_times(rig, clip)
    held = rest_dir.copy()
    keys = np.zeros((len(times), len(seg), 4))
    gathers = np.zeros(len(times))
    g = 0.0
    for rep in range(2):
        for ti, t in enumerate(times):
            world = rig.pose(clip, t)[ih] @ np.linalg.inv(rig.ibm[ih])
            rh = world[:3, :3]
            rh = rh / np.linalg.norm(rh, axis=0)
            carry = rh @ r0.T  # the hand's turn since rest
            wt = rig.pose(clip, t)[it] @ np.linalg.inv(rig.ibm[it])
            wt = wt[:3, :3] / np.linalg.norm(wt[:3, :3], axis=0)
            ang = twist_angle(wt @ rt0.T, rest_dir[0])
            prev = carry
            tf = FOLLOW_BY_CLIP.get(clip, TAIL_FOLLOW)
            for k in range(len(seg)):
                follow = prev @ rest_dir[k]
                u = tf[k] * follow + (1 - tf[k]) * rest_dir[k]
                u /= np.linalg.norm(u)
                held[k] = LAG[k] * held[k] + (1 - LAG[k]) * u
                held[k] /= np.linalg.norm(held[k])
                q = axis_turn(held[k], ang * TAIL_TWIST[k]) @ arc(rest_dir[k], held[k])
                keys[ti, k] = mat_quat(r0.T @ prev.T @ q @ r0)
                prev = q
                if k == 0:
                    ang0 = np.degrees(np.arccos(np.clip(held[0] @ rest_dir[0], -1, 1)))
                    x = np.clip((ang0 - GATHER_DEG[0]) / (GATHER_DEG[1] - GATHER_DEG[0]), 0, 1)
                    g = GATHER_LAG * g + (1 - GATHER_LAG) * x * x * (3 - 2 * x)
                    gathers[ti] = g
    tail_keys.gathers = gathers  # g per frame, read by gather_tail
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


def rebake_tail(js, b, out, rig):  # r11 stage
    """r11, on an r10 file (chain already in): the chain's keys baked again (twist kept); the old samplers' outputs are
    swapped, nothing else moves. (Never re-run build() on a file it already wrote: the chain bones would double.)"""
    first = rig.names.index("GooTail0")
    pos = n.floats(js, b, js["meshes"][0]["primitives"][0]["attributes"]["POSITION"])
    rest_pts = chain_points(pos[goo_vertices(js, b)], rest_world(rig, HAND)[1])
    for a in js["animations"]:
        _, keys = tail_keys(rig, a["name"], rest_pts)
        for k in range(len(CHAIN_Y)):
            ch = [c for c in a["channels"] if c["target"]["node"] == rig.joints[first + k]][0]
            a["samplers"][ch["sampler"]]["output"] = out.add_floats(keys[:, k], "VEC4")


def set_track(a, node, path, inp, out, vals, kind):
    """Swap the output of node's path channel in clip a, or add the channel (sharing the input times inp)."""
    old = [c for c in a["channels"] if c["target"]["node"] == node and c["target"]["path"] == path]
    if old:
        a["samplers"][old[0]["sampler"]]["output"] = out.add_floats(vals, kind)
        return
    a["samplers"].append({"input": inp, "output": out.add_floats(vals, kind), "interpolation": "LINEAR"})
    a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": {"node": node, "path": path}})


def gather_tail(js, b, out, rig):  # r12 stage (safe to re-run: swaps outputs, adds no bones)
    """r12: the chain's keys baked again; GooTail0 gets a uniform scale track and GooTail1..3 translation tracks per
    clip (the swung tail gathers)."""
    first = rig.names.index("GooTail0")
    pos = n.floats(js, b, js["meshes"][0]["primitives"][0]["attributes"]["POSITION"])
    rest_pts = chain_points(pos[goo_vertices(js, b)], rest_world(rig, HAND)[1])
    peak = {}
    for a in js["animations"]:
        times, keys = tail_keys(rig, a["name"], rest_pts)
        g = tail_keys.gathers[:, None]
        u = 1 + (GATHER_THICK - 1) * g
        lo = 1 - GATHER * g
        inp = None
        for k in range(len(CHAIN_Y)):
            node = rig.joints[first + k]
            ch = [c for c in a["channels"] if c["target"]["node"] == node and c["target"]["path"] == "rotation"][0]
            a["samplers"][ch["sampler"]]["output"] = out.add_floats(keys[:, k], "VEC4")
            inp = a["samplers"][ch["sampler"]]["input"]
            if k == 0:
                set_track(a, node, "scale", inp, out, np.repeat(u, 3, 1), "VEC3")
            else:
                t0 = np.array(js["nodes"][node]["translation"])
                set_track(a, node, "translation", inp, out, (lo / u) * t0[None, :], "VEC3")
        peak[a["name"]] = round(float(lo.min()), 2)
    return f"tail gather, least share of the chain length kept per clip: {peak}"


def clean_goo_weights(js, b, out, rig):
    """r11: stray head/spine weights and half of the shoulder's weight on the goo move to RightArm (one share per
    vertex, so a cross-section stays rigid and the tube does not collapse where those bones turn differently)."""
    prims = js["meshes"][0]["primitives"]
    gv = goo_vertices(js, b)
    _, joints, weights = rig.verts(0)
    d = rs.dense(joints, weights, len(rig.names))
    ix = rig.names.index
    stray = [ix(x) for x in STRAY]
    arm, sh = ix("RightArm"), ix("RightShoulder")
    g = d[gv]
    g[:, arm] += g[:, stray].sum(1) + SHOULDER_TO_ARM * g[:, sh]
    g[:, stray] = 0
    g[:, sh] *= 1 - SHOULDER_TO_ARM
    d[gv] = g
    nj, nw = rs.top4(d)
    rest = np.ones(len(nj), bool)
    rest[gv] = False
    nj[rest], nw[rest] = joints[rest], weights[rest]  # everything but the goo keeps its own rows
    js["accessors"].append({"bufferView": out.add_view(nj.astype(np.uint16).tobytes()), "componentType": 5123, "count": len(nj), "type": "VEC4"})
    jacc, wacc = len(js["accessors"]) - 1, out.add_floats(nw, "VEC4")
    for p in prims[:2]:
        p["attributes"]["JOINTS_0"], p["attributes"]["WEIGHTS_0"] = jacc, wacc


UNDER_COLOUR = (0.12, 0.06, 0.025)  # r13: linear colour of the pack underlay (dark wood)
PILE_LOW = 0.2  # r13: share of the pack's height below which gold-textured triangles (the coin pile Meshy spilled round
# the base of the stack) are dropped: it hung under the pack in the game as a ragged orange clump


def cut_pile(F, P, UV, img, lo, hi):
    """Drops the triangles in the lowest PILE_LOW of the pack whose texel (at the UV centroid) is gold."""
    cen = P[F].mean(1)
    low = cen[:, 1] < lo[1] + PILE_LOW * (hi[1] - lo[1])
    uv = UV[F].mean(1)
    w, h = img.size
    px = np.asarray(img.resize((w // 4, h // 4)))
    xi = np.clip((uv[:, 0] % 1.0 * px.shape[1]).astype(int), 0, px.shape[1] - 1)
    yi = np.clip((uv[:, 1] % 1.0 * px.shape[0]).astype(int), 0, px.shape[0] - 1)
    r, g, b_ = (px[yi, xi, k].astype(float) for k in range(3))
    mx, mn = np.maximum(np.maximum(r, g), b_), np.minimum(np.minimum(r, g), b_)
    hue = np.where(mx == r, 60 * ((g - b_) / np.maximum(mx - mn, 1)), np.where(mx == g, 60 * (2 + (b_ - r) / np.maximum(mx - mn, 1)), 0))
    gold = (hue > 29) & (hue < 60) & ((mx - mn) / np.maximum(mx, 1) > 0.5) & (mx > 60)  # this pack's coins sit at 30-40 deg, its wood at 20-26
    drop = low & gold
    F = F[~drop]
    # loose shards (what the decimation left of the planks at the base): tiny islands anywhere, small ones in the bottom 40 %
    lab = island_labels(P, F)
    size = np.bincount(lab)
    cen = P[F].mean(1)
    base = cen[:, 1] < lo[1] + 0.4 * (hi[1] - lo[1])
    shard = (size[lab] < 6) | ((size[lab] < 30) & (cen[:, 1] < lo[1] + 0.3 * (hi[1] - lo[1])))
    print("pile cut:", int(drop.sum()), "triangles; shards dropped:", int(shard.sum()), "of", len(F), "islands <6:", int((size < 6).sum()), "<30:", int((size < 30).sum()), "of", len(size))
    return F[~shard]


def swap_pack(js, b, out, rig, pack_path, under_path=None):
    """r11: the leather bedroll and brass clasps (contract hoard) are replaced by Meshy's hoard pack (an image-to-3D of
    the turnaround's stacked chests, barrels, shield and lantern with the top chest open and full of coins, decimated in
    Blender to PACK_TRIS): turned about y so its flat back faces the hero's back, scaled and set on the spine, one rigid
    blend of the spine bones (as the old pack)."""
    pj, pb = n.load(pack_path)
    pp = pj["meshes"][0]["primitives"][0]
    at = pp["attributes"]
    P, N, UV = (n.floats(pj, pb, at[k]) for k in ("POSITION", "NORMAL", "TEXCOORD_0"))
    F = prim_faces(pj, pb, pp)
    lo, hi = P.min(0), P.max(0)
    tex0 = pj["materials"][pp["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    big = Image.open(io.BytesIO(bytes(n.view_bytes(pj, pb, pj["images"][pj["textures"][tex0]["source"]]["bufferView"])))).convert("RGB")
    F = cut_pile(F, P, UV, big, lo, hi)
    ctr = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    P = (P - ctr) * np.array([-1.0, 1.0, -1.0]) * PACK_SCALE  # 180 deg about y
    N = N * np.array([-1.0, 1.0, -1.0])
    depth = (hi[2] - lo[2]) * PACK_SCALE
    P += np.array([PACK_X, PACK_BOTTOM, PACK_BACK_Z - depth / 2])
    jn, wt = rs.pack_weights(P, rig.names)
    tex = pj["materials"][pp["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = pj["images"][pj["textures"][tex]["source"]]
    im = Image.open(io.BytesIO(bytes(n.view_bytes(pj, pb, img["bufferView"])))).convert("RGB")
    im.thumbnail((PACK_TEX, PACK_TEX))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append({"source": len(js["images"]) - 1})
    js["materials"].append({"name": "pack-meshy", "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorTexture": {"index": len(js["textures"]) - 1}, "metallicFactor": 0.0, "roughnessFactor": 0.75}})
    attrs = {"POSITION": out.add_floats(P, "VEC3"), "NORMAL": out.add_floats(N, "VEC3"),
             "TEXCOORD_0": out.add_floats(UV, "VEC2"), "WEIGHTS_0": out.add_floats(wt, "VEC4")}
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append({"bufferView": out.add_view(jn.astype(np.uint16).tobytes()), "componentType": 5123,
                            "count": len(P), "type": "VEC4"})
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    f = F.astype(np.uint32)  # a turn keeps the winding
    js["accessors"].append({"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"})
    prims = js["meshes"][0]["primitives"]
    keep = [p for p in prims if js["materials"][p["material"]]["name"] not in ("leather-pack", "brass-pack", "pack-meshy", "pack-under")]
    keep.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    if under_path:  # r13: a closed brown shell just inside the pack (voxel remesh, Blender): cracks in Meshy's planks show wood, not the ink hull
        uj, ub = n.load(under_path)
        up = uj["meshes"][0]["primitives"][0]
        UP, UN = (n.floats(uj, ub, up["attributes"][k]) for k in ("POSITION", "NORMAL"))
        UF = prim_faces(uj, ub, up).astype(np.uint32)
        UF = UF[UP[UF].mean(1)[:, 1] >= lo[1] + PILE_LOW * (hi[1] - lo[1])]  # none under the cut pile
        UP = (UP - ctr) * np.array([-1.0, 1.0, -1.0]) * PACK_SCALE
        UN = UN * np.array([-1.0, 1.0, -1.0])
        UP += np.array([PACK_X, PACK_BOTTOM, PACK_BACK_Z - depth / 2])
        ujn, uwt = rs.pack_weights(UP, rig.names)
        js["materials"].append({"name": "pack-under", "doubleSided": True, "pbrMetallicRoughness": {
            "baseColorFactor": list(UNDER_COLOUR) + [1.0], "metallicFactor": 0.0, "roughnessFactor": 0.9}})
        ua = {"POSITION": out.add_floats(UP.astype(np.float32), "VEC3"), "NORMAL": out.add_floats(UN.astype(np.float32), "VEC3"),
              "WEIGHTS_0": out.add_floats(uwt, "VEC4")}
        js["accessors"][ua["POSITION"]].update(min=UP.min(0).tolist(), max=UP.max(0).tolist())
        js["accessors"].append({"bufferView": out.add_view(ujn.astype(np.uint16).tobytes()), "componentType": 5123,
                                "count": len(UP), "type": "VEC4"})
        ua["JOINTS_0"] = len(js["accessors"]) - 1
        js["accessors"].append({"bufferView": out.add_view(UF.tobytes()), "componentType": 5125, "count": int(UF.size), "type": "SCALAR"})
        keep.append({"attributes": ua, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    js["meshes"][0]["primitives"] = keep
    return len(F)


def cap_shoulder(js, b, out, rig):
    """r11: Meshy cut the right arm off the torso and left its socket open (the goo hid it at rest; once the arm swung
    it showed as a black torn patch on the back/shoulder: the game's ink hull behind the hole). The open rim in
    SOCKET_BOX gets a dome (SOCKET_RINGS rings toward its centre, bulging outward by SOCKET_BULGE) skinned and
    textured like the nearest rim vertex, appended to the shared vertex arrays."""
    prim = js["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    arr = read_attrs(js, b, att)
    pos, f = arr["POSITION"], prim_faces(js, b, prim)
    first_goo = goo_vertices(js, b).min()
    q = np.round(pos / ISLAND_TOL).astype(np.int64)
    w = np.unique(q, axis=0, return_inverse=True)[1].ravel()
    fs = w[f[(f < first_goo).all(1)]]
    e = np.sort(np.concatenate([fs[:, [0, 1]], fs[:, [1, 2]], fs[:, [2, 0]]]), 1)
    u, c = np.unique(e, axis=0, return_counts=True)
    bd = u[c == 1]
    rep = np.zeros(w.max() + 1, np.int64)
    rep[w[::-1]] = np.arange(len(w))[::-1]  # first vertex index of each welded position
    lo, hi = SOCKET_BOX
    inside = ((pos[rep[bd]] >= lo) & (pos[rep[bd]] <= hi)).all(2).all(1)
    bd = bd[inside]
    ids = np.unique(bd)
    slot = {v: i for i, v in enumerate(ids)}
    g = sp.coo_matrix((np.ones(len(bd)), ([slot[x] for x in bd[:, 0]], [slot[x] for x in bd[:, 1]])), (len(ids),) * 2)
    lab = connected_components(g, directed=False)[1]
    new = {k: [] for k in arr}
    tris, base, total = [], len(pos), 0
    for l in range(lab.max() + 1):
        vs = rep[ids[lab == l]]
        if len(vs) < SOCKET_MIN:
            continue
        p = pos[vs]
        ctr = p.mean(0)
        ax = np.linalg.svd(p - ctr)[2]
        out_n = ax[2] if ax[2][0] < 0 else -ax[2]  # the opening faces away from the body (-x)
        order = vs[np.argsort(np.arctan2((p - ctr) @ ax[1], (p - ctr) @ ax[0]))]
        po = pos[order]
        for r in range(1, SOCKET_RINGS + 1):
            k = r / (SOCKET_RINGS + 1)
            P = ctr + (po - ctr) * (1 - k) + out_n * SOCKET_BULGE * np.sin(np.pi / 2 * k)
            for key, arrv in arr.items():
                piece = arrv[order].copy()
                if key == "POSITION":
                    piece = P
                elif key == "NORMAL":
                    piece = np.tile(out_n, (len(order), 1)) * k + piece * (1 - k)
                    piece /= np.linalg.norm(piece, axis=1, keepdims=True)
                new[key].append(piece)
        top = ctr + out_n * SOCKET_BULGE
        near = order[np.argmin(np.linalg.norm(po - ctr, axis=1))]
        for key, arrv in arr.items():
            piece = arrv[[near]].copy()
            if key == "POSITION":
                piece = top[None]
            elif key == "NORMAL":
                piece = out_n[None].astype(np.float32)
            new[key].append(piece)
        n_pts, m = len(order), SOCKET_RINGS
        ring_id = [order] + [base + total + n_pts * (r - 1) + np.arange(n_pts) for r in range(1, m + 1)]
        apex = base + total + n_pts * m
        quads = []
        for r in range(m):
            a_, b_ = ring_id[r], ring_id[r + 1]
            for i in range(n_pts):
                j = (i + 1) % n_pts
                quads += [(a_[i], a_[j], b_[j]), (a_[i], b_[j], b_[i])]
        for i in range(n_pts):
            quads.append((ring_id[m][i], ring_id[m][(i + 1) % n_pts], apex))
        tr = np.array(quads, np.int64)
        allp = np.concatenate([pos, np.concatenate([x for x in new["POSITION"]])])
        nrm = np.cross(allp[tr[:, 1]] - allp[tr[:, 0]], allp[tr[:, 2]] - allp[tr[:, 0]])
        flip = (nrm @ out_n) < 0
        tr[flip] = tr[flip][:, ::-1]
        tris.append(tr)
        total += n_pts * m + 1
        print("socket loop", len(order), "verts at", ctr.round(2), "ring dia", np.ptp(po, 0).round(2))
    if not tris:
        return "no loop found"
    append_attrs(js, out, att, arr, new)
    full = np.concatenate([f.astype(np.uint32)] + [t.astype(np.uint32) for t in tris])
    js["accessors"].append({"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"})
    prim["indices"] = len(js["accessors"]) - 1
    return int(sum(len(t) for t in tris))


# r13: open rims capped with a dome, per prim: (name, prim index, (box lo, box hi) on the loop centre in rest pose,
# smallest loop, largest diameter, direction of the dome: a unit vector, or None = along the rim's mean normal)
CAPS = (
    ("goo mouth at the shoulder", 1, ((-0.3, 1.2, -0.5), (-0.05, 1.9, 0.2)), 100, 0.6, (1.0, 0.0, 0.0), 3),
    ("skin crack on the shoulder top", 0, ((-0.3, 1.55, -0.45), (-0.05, 1.9, 0.0)), 40, 0.6, None, 3),
    ("goo tip end", 1, ((-1.0, 0.03, -1.0), (1.0, 0.25, 1.0)), 12, 0.9, (0.0, -1.0, 0.0), 3, 0.05),
    ("hip", 0, ((-0.45, 0.6, -0.5), (0.25, 1.1, 0.1)), 40, 0.3, None, 3),
    ("foot soles", 0, ((-0.6, -0.1, -0.5), (0.6, 0.2, 0.5)), 30, 0.3, None, 3),
    # every small hole left in Meshy's skin and goo (toe gaps, tears at the hip): a fan fill from the rim's centre
    ("small skin holes", 0, ((-1.0, -0.2, -1.0), (1.0, 2.0, 1.0)), 6, 0.06, None, 0),
    ("small goo holes", 1, ((-1.0, -0.2, -1.0), (1.0, 2.0, 1.0)), 6, 0.06, None, 0),
)
PUDDLE_Y = 0.08  # m: goo triangles lower than this (rest pose) are dropped: the flat puddle round the foot that swung up as a ring
CAP_BULGE = 0.2  # a dome rises CAP_BULGE x the rim's thin width (m), at most CAP_MAX; rings: per CAPS entry (0 = a fan fill)
CAP_MAX = 0.05
LEGACY_CAPS = ("goo mouth at the shoulder", "skin crack on the shoulder top")  # r13b: kept exactly as r13 built them


WELD_GOO = False  # r13: the goo's seams keep their weights (welding them pulled the tail into spikes)


def weld_weights(js, b, out, rig):
    """r13: vertices at one rest position (Meshy splits them along UV seams and every cut) get one skin weight set (the
    first vertex's). Split vertices carried slightly different weights, so a seam opened as a black tear once a bone
    turned: the toes of the foot, the neck, the hip."""
    prims = js["meshes"][0]["primitives"]
    att = prims[0]["attributes"]
    arr = read_attrs(js, b, att)
    pos, J, W = arr["POSITION"], arr["JOINTS_0"], arr["WEIGHTS_0"]
    q = np.round(pos / ISLAND_TOL).astype(np.int64)
    goo = np.zeros(len(pos), np.int64)
    goo[goo_vertices(js, b)] = 1  # the goo is its own sleeve: its vertices only group with each other
    q = np.concatenate([q, goo[:, None]], 1)
    _, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    J2, W2 = J[first][inv], W[first][inv]
    if not WELD_GOO:
        J2[goo == 1], W2[goo == 1] = J[goo == 1], W[goo == 1]
    diff = (np.abs(W2 - W).sum(1) > 0.02) | (J2 != J).any(1) & (W > 0.02).any(1)
    old = att["JOINTS_0"]
    jacc = len(js["accessors"])
    js["accessors"].append({"bufferView": out.add_view(J2.astype(np.uint16).tobytes()), "componentType": 5123, "count": len(J2), "type": "VEC4"})
    wacc = out.add_floats(W2.astype(np.float32), "VEC4")
    for p in prims:
        if p["attributes"].get("JOINTS_0") == old:
            p["attributes"]["JOINTS_0"], p["attributes"]["WEIGHTS_0"] = jacc, wacc
    return "%d of %d vertices took their position group's weights" % (int(diff.sum()), len(pos))


def prim_texture(js, b, pi):
    """The base-colour image of primitive pi, as an RGB PIL image (downscaled to 512)."""
    mat = js["materials"][js["meshes"][0]["primitives"][pi]["material"]]
    img = js["images"][js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    im = Image.open(io.BytesIO(bytes(n.view_bytes(js, b, img["bufferView"])))).convert("RGB")
    im.thumbnail((512, 512))
    return im


def trim_puddle(js, b, out, rig):
    """r13: drops the goo's flat puddle round the foot (rest-pose triangles below PUDDLE_Y)."""
    prim = js["meshes"][0]["primitives"][1]
    pos = read_attrs(js, b, prim["attributes"])["POSITION"]
    f = prim_faces(js, b, prim)
    keep = pos[f].mean(1)[:, 1] >= PUDDLE_Y
    full = f[keep].astype(np.uint32)
    js["accessors"].append({"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"})
    prim["indices"] = len(js["accessors"]) - 1
    return "%d goo triangles dropped" % int((~keep).sum())


def rim_cycles(dedges, ring):
    """r13b: the directed rim edges (each in its kept face's direction) of one rim, split into simple cycles: walk the
    out-edges; where the walk meets a vertex already on its path, that stretch is one cycle (a figure-8 rim gives two).
    A walk that dead-ends (the faces round it disagree on winding) is dropped."""
    outs = {}
    for a_, b_ in dedges:
        if a_ in ring:
            outs.setdefault(a_, []).append(b_)
    cycles = []
    while True:
        start = next((v for v, o in outs.items() if o), None)
        if start is None:
            return cycles
        path, at = [start], {start: 0}
        while True:
            o = outs.get(path[-1])
            if not o:
                break
            nx = o.pop()
            if nx in at:
                i = at[nx]
                cycles.append(path[i:])
                for v in path[i:]:
                    at.pop(v, None)
                path = path[:i]
                if not path:
                    break
                continue
            at[nx] = len(path)
            path.append(nx)


def cap_rims(js, b, out, rig):
    """r13: every open rim listed in CAPS gets a dome (rings toward the centre, bulging outward), skinned and textured
    like its rim vertices. The goo's mouth at the shoulder (a flat D cut where the arm was parted from the torso) was the
    black slit at the neck: once the arm swung, the game's ink hull behind the open sleeve showed black."""
    prims = js["meshes"][0]["primitives"]
    att = prims[0]["attributes"]
    arr = read_attrs(js, b, att)
    pos, nrm = arr["POSITION"], arr["NORMAL"]
    new = {k: [] for k in arr}
    add = {0: [], 1: []}
    base, total = len(pos), 0
    report = []
    capped = set()
    clash = 0
    for name, pi, (lo, hi), minv, maxd, d, m, *fixed in CAPS:
        f = prim_faces(js, b, prims[pi])
        used = np.unique(f)
        q = np.round(pos[used] / ISLAND_TOL).astype(np.int64)
        uq, inv = np.unique(q, axis=0, return_inverse=True)
        w = np.zeros(len(pos), np.int64)
        w[used] = inv.ravel()
        rep = np.zeros(len(uq), np.int64)
        rep[w[used][::-1]] = used[::-1]
        fs = w[f]
        e = np.sort(np.concatenate([fs[:, [0, 1]], fs[:, [1, 2]], fs[:, [2, 0]]]), 1)
        e = e[e[:, 0] != e[:, 1]]
        u, c = np.unique(e, axis=0, return_counts=True)
        bd = u[c == 1]
        ids = np.unique(bd)
        slot = {v: i for i, v in enumerate(ids)}
        g = sp.coo_matrix((np.ones(len(bd)), ([slot[x] for x in bd[:, 0]], [slot[x] for x in bd[:, 1]])), (len(ids),) * 2)
        lab = connected_components(g, directed=False)[1]
        de = np.concatenate([fs[:, [0, 1]], fs[:, [1, 2]], fs[:, [2, 0]]])
        bset = set(map(tuple, bd.tolist()))
        dbd = [tuple(e_) for e_ in de.tolist() if e_[0] != e_[1] and tuple(sorted(e_)) in bset]  # rim edges, face direction
        todo = []
        n_caps = 0
        for l in range(lab.max() + 1):
            vs = rep[ids[lab == l]]
            if len(vs) < minv:
                continue
            if capped.intersection(vs.tolist()):
                continue
            p = pos[vs]
            ctr = p.mean(0)
            if not ((ctr >= np.array(lo)) & (ctr <= np.array(hi))).all():
                continue
            ax = np.linalg.svd(p - ctr)[2]
            if np.ptp((p - ctr) @ ax[0]) > maxd:
                continue
            # r13b: the rim is split into simple cycles along the kept faces' own edge direction (a rim that pinches
            # through one vertex is a figure 8: one angle-sorted dome over it folded over itself), and each cycle's fill
            # runs against that direction, so it always winds like its neighbours. r13 sorted the rim by angle and
            # turned each fill triangle by out_n: skin faces with clashing winding 1,105 -> 14,827 (r12 -> r13), the
            # black toe/hip flecks (the culled side showing the ink shell)
            ring = set(ids[lab == l].tolist())
            if name in LEGACY_CAPS:  # r13's one angle-sorted dome, its triangles turned by out_n (the closed neck slit)
                ang = np.arctan2((p - ctr) @ ax[1], (p - ctr) @ ax[0])
                todo.append((None, name, pi, m, d, fixed, vs[np.argsort(ang)]))
            else:
                todo.extend([(c_, name, pi, m, d, fixed, vs) for c_ in rim_cycles(dbd, ring) if len(c_) >= 3])
            capped.update(vs.tolist())
            n_caps += 1
        for cyc, name, pi_, m, d, fixed, vs in todo:
            legacy = cyc is None
            order = vs if legacy else rep[np.array(cyc)][::-1]  # against the kept faces' direction: the fill's own winding
            p = pos[order]
            ctr = p.mean(0)
            ax = np.linalg.svd(p - ctr)[2]
            width = np.ptp((p - ctr) @ ax[1]) if len(order) > 2 else 0.0
            av = np.cross(p - ctr, np.roll(p, -1, 0) - ctr).sum(0)
            wn = av / max(np.linalg.norm(av), 1e-12)  # the fill's normal from its winding
            if legacy and d is None:
                out_n = ax[2] if ax[2] @ nrm[order].mean(0) >= 0 else -ax[2]
            elif d is None:  # the dome rises along the rim's own (Meshy) normals; orient_faces winds it to match
                mn = nrm[order].mean(0)
                out_n = wn if wn @ mn >= 0 else -wn
            else:
                out_n = np.array(d, float)
                clash += int(wn @ out_n < 0)
            bulge = fixed[0] if fixed else min(CAP_MAX, CAP_BULGE * max(width, 0.01))
            if len(order) < 6:
                m_ = 0
            else:
                m_ = m
            po = pos[order]
            near = order[np.argmin(np.linalg.norm(po - ctr, axis=1))]
            if fixed and "TEXCOORD_0" in arr:  # a dome that shows one colour: the darkest texel on its rim
                tex = prim_texture(js, b, pi_)
                uvs = arr["TEXCOORD_0"][order]
                lum = np.asarray(tex)[np.clip((uvs[:, 1] % 1 * tex.size[1]).astype(int), 0, tex.size[1] - 1),
                                      np.clip((uvs[:, 0] % 1 * tex.size[0]).astype(int), 0, tex.size[0] - 1)].astype(float).sum(1)
                near = order[np.argmin(lum)]
            n_pts = len(order)
            for r in range(1, m_ + 1):
                k = r / (m_ + 1)
                P = ctr + (po - ctr) * (1 - k) + out_n * bulge * np.sin(np.pi / 2 * k)
                for key, arrv in arr.items():
                    piece = arrv[order].copy()
                    if key == "POSITION":
                        piece = P
                    elif key == "NORMAL":
                        piece = np.tile(out_n, (n_pts, 1)) * k + piece * (1 - k)
                        piece /= np.linalg.norm(piece, axis=1, keepdims=True)
                    elif key.startswith("TEXCOORD") and m_ > 0 and fixed:  # one texel for the whole dome: no streaks along the rim
                        piece = np.tile(arrv[near], (n_pts, 1))
                    new[key].append(piece)
            for key, arrv in arr.items():
                piece = arrv[[near]].copy()
                if key == "POSITION":
                    piece = (ctr + out_n * bulge)[None]
                elif key == "NORMAL":
                    piece = out_n[None].astype(np.float32)
                new[key].append(piece)
            ring_id = [order] + [base + total + n_pts * (r - 1) + np.arange(n_pts) for r in range(1, m_ + 1)]
            apex = base + total + n_pts * m_
            quads = []
            for r in range(m_):
                a_, b_ = ring_id[r], ring_id[r + 1]
                for i in range(n_pts):
                    j = (i + 1) % n_pts
                    quads += [(a_[i], a_[j], b_[j]), (a_[i], b_[j], b_[i])]
            for i in range(n_pts):
                quads.append((ring_id[m_][i], ring_id[m_][(i + 1) % n_pts], apex))
            tr = np.array(quads, np.int64)
            if legacy:
                allp = np.concatenate([pos, np.concatenate(new["POSITION"])])
                nn = np.cross(allp[tr[:, 1]] - allp[tr[:, 0]], allp[tr[:, 2]] - allp[tr[:, 0]])
                flip = (nn @ out_n) < 0
                tr[flip] = tr[flip][:, ::-1]
            add[pi_].append(tr)
            total += n_pts * m_ + 1
            if m_:
                print("cap", name, n_pts, "verts at", ctr.round(2), "dia", round(float(np.ptp((p - ctr) @ ax[0])), 2), "bulge", round(float(bulge), 3))
        report.append("%s %d" % (name, n_caps))
    if not total:
        return "no loop found"
    append_attrs(js, out, att, arr, new)
    prims = js["meshes"][0]["primitives"]
    for pi, trs in add.items():
        if not trs:
            continue
        full = np.concatenate([prim_faces(js, b, prims[pi]).astype(np.uint32)] + [t.astype(np.uint32) for t in trs])
        js["accessors"].append({"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"})
        prims[pi]["indices"] = len(js["accessors"]) - 1
    return "; ".join(report) + ", %d new vertices, %d fixed-direction caps against their winding" % (total, clash)



ORIENT_TOP = 1.2  # m (rest pose): above this (the goo mouth, its cap and the shoulder) turning faces reopened black slits


def orient_faces(js, b, out, rig):
    """r13b: every body material is double-sided, and Godot draws a face wound against its normals as a back face
    (its normal negated: the toon light's dark side) while the ink shell (cull front) shows black over it. Meshy's skin
    has 1,676 such faces (r12) and r13's caps raised that to 5,996: the black toe, hip and shoulder flecks. Each skin
    and goo face below ORIENT_TOP whose winding normal points against the sum of its vertex normals is turned round."""
    prims = js["meshes"][0]["primitives"]
    pos = n.floats(js, b, prims[0]["attributes"]["POSITION"])
    nrm = n.floats(js, b, prims[0]["attributes"]["NORMAL"])
    res = []
    for pi in (0, 1):
        f = prim_faces(js, b, prims[pi]).astype(np.uint32).copy()
        fn = np.cross(pos[f[:, 1]] - pos[f[:, 0]], pos[f[:, 2]] - pos[f[:, 0]])
        bad = ((fn * nrm[f].sum(1)).sum(1) < 0) & (pos[f].mean(1)[:, 1] < ORIENT_TOP)
        f[bad] = f[bad][:, ::-1]
        js["accessors"].append({"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"})
        prims[pi]["indices"] = len(js["accessors"]) - 1
        res.append("%s %d of %d" % (js["materials"][prims[pi]["material"]]["name"], int(bad.sum()), len(f)))
    return "faces turned to their normals: " + ", ".join(res)


def strap_ink(js, b, out, rig):
    """r13b: the straps are a one-layer ribbon; with no COLOR_0 the game's ink shell grows the full 0.02 m and is seen
    from behind as a black slab (the black line at the strap/shoulder in attack and hit). Room 0, native_ink's rule
    for an open sheet."""
    for p in js["meshes"][0]["primitives"]:
        if js["materials"][p["material"]]["name"] == "strap-leather":
            cnt = js["accessors"][p["attributes"]["POSITION"]]["count"]
            col = np.ones((cnt, 4), np.float32)
            col[:, 3] = 0.0
            p["attributes"]["COLOR_0"] = out.add_floats(col, "VEC4")
            return "strap ink room 0 on %d vertices" % cnt
    return "no strap"


# r13: the two shoulder straps (the pack's carry straps, which the r11 swap of the bedroll took away): ribbons that
# follow the torso from the pack's back over each shoulder crest and down the chest to the belt line. Waypoints are
# (y, z) of the torso surface in the rest pose at |x| = STRAP_X, already offset outward by STRAP_LIFT.
STRAP_X, STRAP_W, STRAP_LIFT = 0.17, 0.085, 0.014
STRAP_PATH = ((1.22, -0.37), (1.32, -0.395), (1.45, -0.40), (1.56, -0.395), (1.65, -0.33), (1.71, -0.22),
              (1.70, -0.10), (1.64, -0.02), (1.55, 0.045), (1.45, 0.06), (1.36, 0.02), (1.28, -0.05), (1.20, -0.10))
STRAP_COLOUR = (0.22, 0.11, 0.045)


def catmull(pts, k):
    p = np.vstack([pts[0], pts, pts[-1]])
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, k, endpoint=False):
            out.append(0.5 * ((2 * p[i]) + (-p[i - 1] + p[i + 1]) * t + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t
                              + (-p[i - 1] + 3 * p[i] - 3 * p[i + 1] + p[i + 2]) * t ** 3))
    out.append(p[-2])
    return np.array(out)


def add_straps(js, b, out, rig):
    """r13: both shoulder straps as one primitive (flat leather colour, rigid on the spine like the pack)."""
    path = catmull(np.array(STRAP_PATH), 6)
    d = np.gradient(path, axis=0)
    nrm = np.stack([d[:, 1], -d[:, 0]], 1)  # outward normal in (y, z): perpendicular to the path
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    mid = path.mean(0)
    flip = ((path - mid) * nrm).sum(1).mean() < 0
    nrm = -nrm if flip else nrm
    P, N, F = [], [], []
    for side in (-1, 1):
        x0 = side * STRAP_X
        base = len(P)
        for (y, z), (ny, nz) in zip(path, nrm):
            for dx in (-STRAP_W / 2, STRAP_W / 2):
                P.append([x0 + dx, y + ny * STRAP_LIFT, z + nz * STRAP_LIFT])
                N.append([0.0, ny, nz])
        for i in range(len(path) - 1):
            a0, a1, b0, b1 = base + 2 * i, base + 2 * i + 1, base + 2 * i + 2, base + 2 * i + 3
            F += [(a0, a1, b1), (a0, b1, b0)]
    P, N, F = np.array(P, np.float32), np.array(N, np.float32), np.array(F, np.uint32)
    tn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    F[(tn * N[F[:, 0]]).sum(1) < 0] = F[(tn * N[F[:, 0]]).sum(1) < 0][:, ::-1]  # faces turned outward
    jn, wt = rs.pack_weights(P, rig.names)
    js["materials"].append({"name": "strap-leather", "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorFactor": list(STRAP_COLOUR) + [1.0], "metallicFactor": 0.0, "roughnessFactor": 0.8}})
    attrs = {"POSITION": out.add_floats(P, "VEC3"), "NORMAL": out.add_floats(N, "VEC3"), "WEIGHTS_0": out.add_floats(wt, "VEC4")}
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append({"bufferView": out.add_view(jn.astype(np.uint16).tobytes()), "componentType": 5123,
                            "count": len(P), "type": "VEC4"})
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    js["accessors"].append({"bufferView": out.add_view(F.tobytes()), "componentType": 5125, "count": int(F.size), "type": "SCALAR"})
    prims = js["meshes"][0]["primitives"]
    prims[:] = [p for p in prims if js["materials"][p["material"]]["name"] != "strap-leather"]
    prims.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    return len(F)



# r15: Meshy's run/walk/jump swing the right (goo) arm up past the chest and the tail chain follows the hand, so the goo
# lay over the torso like a sash in run/dash/jump (art-gate r13/r14). Those clips' right-arm keys are turned back toward
# the Idle clip's first-frame pose (keep ARM_KEEP of the swing); the tail is then baked again (gather_tail).
ARM_CLIPS, ARM_BONES, ARM_KEEP = ("run", "walk", "Jump_Run", "Crouch_Walk_with_Torch"), \
    ("RightShoulder", "RightArm", "RightForeArm", "RightHand"), float(__import__("os").environ.get("ARM_KEEP", "0.3"))


def calm_goo_arm(js, b, out, rig):  # r15 stage (re-running it calms the swing again: run it once per source file)
    idle = next(a for a in js["animations"] if a["name"] == "Idle")
    target = {}
    for ch in idle["channels"]:
        node = js["nodes"][ch["target"]["node"]]
        if node.get("name") in ARM_BONES and ch["target"]["path"] == "rotation":
            target[ch["target"]["node"]] = n.floats(js, b, idle["samplers"][ch["sampler"]]["output"])[0].astype(float)
    done = 0
    for a in js["animations"]:
        if a["name"] not in ARM_CLIPS:
            continue
        for ch in a["channels"]:
            t = target.get(ch["target"]["node"])
            if t is None or ch["target"]["path"] != "rotation":
                continue
            smp = a["samplers"][ch["sampler"]]
            keys = n.floats(js, b, smp["output"]).astype(float)
            smp["output"] = out.add_floats(slerp_to(keys, t / np.linalg.norm(t), ARM_KEEP), "VEC4")
            done += 1
    return f"{done} right-arm tracks kept {ARM_KEEP} of their swing"


# r17: r15 turned the run arm toward the ORIGINAL Idle's first frame (the side-on fighting stance; r16 only fixed Idle
# after it), so the arm stayed pulled in and the chain, which follows the hand fully, swung the goo diagonally across the
# body (the sash in run 2 / dash 2). r17 turns the right-arm keys of the moving clips toward the bind pose (the A-pose the
# Meshy goo was modelled hanging in: arm out at the side), and in those clips the chain follows the hand less, so the goo
# hangs down beside the leg as in the turnaround ref. Attack keeps its full follow (the swing must carry the goo).
_E = __import__("os").environ
HANG_CLIPS = ARM_CLIPS + ("Idle",)
HANG_KEEP = float(_E.get("HANG_KEEP", "0.4"))  # share of each clip's own arm swing kept (relative to the bind pose)
HANG_OUT = float(_E.get("HANG_OUT", "12"))  # degrees the upper arm is lifted out to the side past that (goo off the hip)
HANG_FOLLOW = tuple(float(x) for x in _E.get("HANG_FOLLOW", "0.7,0.3,0.2,0.15").split(","))
FOLLOW_BY_CLIP = {}  # clip -> chain follow per segment (empty: every clip uses TAIL_FOLLOW, as before r17)


def hang_goo_arm(js, b, out, rig):  # r17 stage (run once per source file)
    pw = rest_world(rig, "RightShoulder")[0]
    pw = pw / np.linalg.norm(pw, axis=0)
    lift = mat_quat(pw.T @ axis_turn(np.array([0.0, 0.0, 1.0]), -np.radians(HANG_OUT)) @ pw)  # local pre-turn
    done = 0
    for a in js["animations"]:
        if a["name"] not in HANG_CLIPS:
            continue
        for ch in a["channels"]:
            node = js["nodes"][ch["target"]["node"]]
            if node.get("name") not in ARM_BONES[:2] or ch["target"]["path"] != "rotation":
                continue
            rest = np.array(node.get("rotation", [0.0, 0.0, 0.0, 1.0]), float)
            smp = a["samplers"][ch["sampler"]]
            keys = n.floats(js, b, smp["output"]).astype(float)
            keys = slerp_to(keys, rest / np.linalg.norm(rest), HANG_KEEP)
            if node["name"] == "RightArm" and HANG_OUT:
                keys = qmul(lift, keys)
            smp["output"] = out.add_floats(keys, "VEC4")
            done += 1
    return f"{done} shoulder/upper-arm tracks kept {HANG_KEEP} of their swing about the bind pose"


def qmul(a, q):
    """a (xyzw) times every key q (frames x xyzw)."""
    ax, ay, az, aw = a
    x, y, z, w = q.T
    return np.stack([aw * x + ax * w + ay * z - az * y, aw * y - ax * z + ay * w + az * x,
                     aw * z + ax * y - ay * x + az * w, aw * w - ax * x - ay * y - az * z], 1)


def hang_tail(js, b, out, rig):  # r17 stage: gather_tail with the moving clips' chain following the hand less
    FOLLOW_BY_CLIP.update({c: HANG_FOLLOW for c in HANG_CLIPS})
    try:
        return gather_tail(js, b, out, rig)
    finally:
        FOLLOW_BY_CLIP.clear()


# r16: the Idle clip stands (it was a side-on fighting stance: the chest turned up to 88 deg off the facing, hunched),
# and Jump_Run, which also plays for the glide, becomes a held leaping pose instead of a run cycle.
IDLE_KEEP = {"Spine": 0.5, "Spine01": 0.5, "Spine02": 0.5, "neck": 0.25, "Head": 0.25}  # share of Idle's own sway kept
JUMP_TURNS = (  # (bone, degrees about the world X axis; the model faces +Z, so a negative turn lifts a thigh forward)
    ("LeftUpLeg", -48), ("LeftLeg", 82), ("LeftFoot", -20),
    ("RightUpLeg", -48), ("RightLeg", 82), ("RightFoot", -20),
    ("Spine", 6), ("Spine01", 4),
)
JUMP_SWAY = 3.0  # degrees the thighs rock either way over the clip (it loops: the glide holds it)


def _track(js, b, a, node, path):
    for c in a["channels"]:
        if c["target"]["node"] == node and c["target"]["path"] == path:
            return c, n.floats(js, b, a["samplers"][c["sampler"]]["output"]).astype(float)
    return None, None


def _clip(js, name):
    return next(a for a in js["animations"] if a["name"] == name)


def fix_idle(js, b, out, rig):  # r16 stage: run once per source file
    from scipy.spatial.transform import Rotation as Rot
    idle, walk = _clip(js, "Idle"), _clip(js, "walk")
    done = 0
    for ch in idle["channels"]:
        node, path = ch["target"]["node"], ch["target"]["path"]
        nm = js["nodes"][node].get("name", "")
        if nm in ARM_BONES or nm.startswith("GooTail") or path == "scale":
            continue
        _, own = _track(js, b, idle, node, path)
        _, base = _track(js, b, walk, node, path)
        if base is None:
            continue
        if path == "translation":  # Hips: the walk's standing height, Idle's own bob
            vals = base[0][None, :] + (own - own.mean(0))
        else:
            keep = IDLE_KEEP.get(nm, 0.0)
            q0 = Rot.from_quat(base[0])
            if keep:
                m = Rot.from_quat(own).mean()
                dev = (m.inv() * Rot.from_quat(own)).as_rotvec() * keep
                vals = (q0 * Rot.from_rotvec(dev)).as_quat()
            else:
                vals = np.repeat(base[0][None, :], len(own), 0)
        idle["samplers"][ch["sampler"]]["output"] = out.add_floats(vals, "VEC3" if path == "translation" else "VEC4")
        done += 1
    return f"{done} Idle tracks stand on the walk's neutral frame"


def fix_jump(js, b, out, rig):  # r16 stage: run once per source file
    from scipy.spatial.transform import Rotation as Rot
    jump, walk, idle = _clip(js, "Jump_Run"), _clip(js, "walk"), _clip(js, "Idle")
    par = {c: i for i, nd in enumerate(js["nodes"]) for c in nd.get("children", [])}
    name = {js["nodes"][i].get("name"): i for i in range(len(js["nodes"]))}
    loc = {}
    for nm, i in name.items():  # local rotation of every bone: the walk's neutral frame; Idle's goo arm
        a = idle if nm in ARM_BONES else walk
        _, k = _track(js, b, a, i, "rotation")
        loc[i] = Rot.from_quat(k[0]) if k is not None else Rot.from_quat(js["nodes"][i].get("rotation", [0, 0, 0, 1]))

    def world(i):
        return (world(par[i]) * loc[i]) if i in par else loc[i]

    for nm, deg in JUMP_TURNS:  # parent first: each turn is made in the world frame of the already turned parent
        i = name[nm]
        pw = world(par[i]) if i in par else Rot.identity()
        loc[i] = pw.inv() * Rot.from_rotvec([np.radians(deg), 0, 0]) * pw * loc[i]
    frames = len(n.floats(js, b, jump["samplers"][0]["output"]))
    ph = np.sin(np.linspace(0, 2 * np.pi, frames, endpoint=False))
    sway = {"LeftUpLeg": JUMP_SWAY, "RightUpLeg": -JUMP_SWAY}
    done = 0
    for ch in jump["channels"]:
        node, path = ch["target"]["node"], ch["target"]["path"]
        nm = js["nodes"][node].get("name", "")
        if nm.startswith("GooTail") or nm not in name:
            continue
        smp = jump["samplers"][ch["sampler"]]
        if path == "rotation":
            q = loc[node]
            if nm in sway:  # a thigh rocks about the model's X axis (child bones follow)
                pw = world(par[node])
                qs = [(pw.inv() * Rot.from_rotvec([np.radians(sway[nm] * p), 0, 0]) * pw * q).as_quat() for p in ph]
            else:
                qs = [q.as_quat()] * frames
            vals = np.array(qs)
        elif path == "translation":
            _, k = _track(js, b, walk, node, "translation")
            if k is None:
                continue
            vals = np.repeat(k[0][None, :], frames, 0)
            if nm == "Hips":
                vals[:, 1] += 0.02 * ph
        else:
            continue
        smp["output"] = out.add_floats(vals, "VEC3" if path == "translation" else "VEC4")
        done += 1
    return f"{done} Jump_Run tracks hold the leap pose"


# r18: the goo arm is replaced by a slim Meshy arm (image-to-3D of a slim goo-arm drawing made from the turnaround's arm).
# Fit: length ARM_TOP..ARM_BOT (m), thickness x ARM_THICK, set ARM_Z behind the old line, bent along the chain's rest line.
ARM_TOP, ARM_BOT, ARM_THICK, ARM_Z, ARM_TEX, ARM_PUDDLE, ARM_GAIN = 1.66, 0.30, 1.5, -0.10, 2048, 0.045, "1.45,0.9,1.15"
ARM_BULB, ARM_BULB_Y, ARM_SOCKET = 1.0, 1.36, "-0.17,-0.12"  # bulb 1 = none (a goo shoulder flare read as a wing, r18 try d/e)


def poly_xz(pts, y):
    """x and z of the polyline pts (top to bottom, y falling) at heights y; linear beyond both ends."""
    ys = pts[:, 1]
    k = np.clip(np.searchsorted(-ys, -np.asarray(y)) - 1, 0, len(pts) - 2)
    f = (ys[k] - y) / (ys[k] - ys[k + 1])
    return pts[k, 0] + f * (pts[k + 1, 0] - pts[k, 0]), pts[k, 2] + f * (pts[k + 1, 2] - pts[k, 2])


def swap_goo_arm(js, b, out, rig, arm_path):
    """r18: both goo primitives (skin and liner shell) are dropped; the Meshy slim arm is set along the goo chain's rest
    line (RightArm, RightForeArm, GooTail0..3 origins), weighted arm/forearm above FADE_Y and on the chain below."""
    top, bot = float(os.environ.get("ARM_TOP", ARM_TOP)), float(os.environ.get("ARM_BOT", ARM_BOT))
    thick, az = float(os.environ.get("ARM_THICK", ARM_THICK)), float(os.environ.get("ARM_Z", ARM_Z))
    flip = os.environ.get("ARM_FLIP", "0") == "1"
    aj, ab = n.load(arm_path)
    ap = aj["meshes"][0]["primitives"][0]
    at = ap["attributes"]
    P, N, UV = (n.floats(aj, ab, at[k]) for k in ("POSITION", "NORMAL", "TEXCOORD_0"))
    F = prim_faces(aj, ab, ap).astype(np.int64)
    lo, hi = P.min(0), P.max(0)
    H = hi[1] - lo[1]
    F = F[P[F].mean(1)[:, 1] >= lo[1] + ARM_PUDDLE * H]  # the flat slime puddle under the hook
    used = np.unique(F)
    remap = np.full(len(P), -1)
    remap[used] = np.arange(len(used))
    P, N, UV, F = P[used], N[used], UV[used], remap[F]
    lo, hi = P.min(0), P.max(0)
    s = (top - bot) / (hi[1] - lo[1])
    mid = P[P[:, 1] > lo[1] + 0.4 * (hi[1] - lo[1])][:, [0, 2]].mean(0)
    cx, cz = (lo[0] + hi[0]) / 2, mid[1]
    if flip:
        P[:, 0], N[:, 0] = -(P[:, 0] - mid[0]) + mid[0], -N[:, 0]
        F = F[:, ::-1]
    first = rig.names.index("GooTail0")
    pts = [rest_world(rig, nm)[1] for nm in ("RightArm", "RightForeArm", "GooTail0", "GooTail1", "GooTail2", "GooTail3")]
    pts = np.array(pts)
    # tip: one more step down the chain's last segment
    pts = np.vstack([pts, pts[-1] + (pts[-1] - pts[-2])])
    y = bot + (P[:, 1] - lo[1]) * s
    px, pz = poly_xz(pts, y)
    bulb, by = float(os.environ.get("ARM_BULB", ARM_BULB)), float(os.environ.get("ARM_BULB_Y", ARM_BULB_Y))
    g = np.clip((y - by) / (top - by), 0, 1)
    g = 1 + (bulb - 1) * g * g * (3 - 2 * g)  # a goo shoulder mass over the open socket (the turnaround's goo arm is bulky there)
    w = (g - 1) / max(bulb - 1, 1e-6)  # 0 on the arm, 1 at the top: the mass is centred on the socket
    sx, sz = (float(v) for v in os.environ.get("ARM_SOCKET", ARM_SOCKET).split(","))
    px, pz = px + w * (sx - px), pz + w * (sz - pz - az)
    Q = np.stack([px + (P[:, 0] - mid[0]) * s * thick * g, y, pz + az + (P[:, 2] - mid[1]) * s * thick * g], 1)
    N = N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    ys = np.array([rest_world(rig, f"GooTail{k}")[1][1] for k in range(4)])
    nb = first + len(CHAIN_Y)
    d = np.zeros((len(Q), nb))
    arm, fore = rig.names.index("RightArm"), rig.names.index("RightForeArm")
    elbow = pts[1][1]
    t = np.clip((pts[0][1] - 0.1 - Q[:, 1]) / (pts[0][1] - 0.1 - elbow), 0, 1)
    t = t * t * (3 - 2 * t)
    d[:, arm], d[:, fore] = 1 - t, t
    c = np.clip((FADE_Y - Q[:, 1]) / (FADE_Y - ys[0]), 0, 1)
    c = (c * c * (3 - 2 * c))[:, None]
    d = (1 - c) * d
    d[:, first:] = c * hat_weights(Q[:, 1], ys)
    jn, wt = rs.top4(d)
    tex = aj["materials"][ap["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = aj["images"][aj["textures"][tex]["source"]]
    im = Image.open(io.BytesIO(bytes(n.view_bytes(aj, ab, img["bufferView"])))).convert("RGB")
    im.thumbnail((ARM_TEX, ARM_TEX))
    gain = np.array([float(x) for x in os.environ.get("ARM_GAIN", ARM_GAIN).split(",")])  # albedo level match to the body's goo atlas
    im = Image.fromarray(np.clip(np.asarray(im, np.float32) * gain, 0, 255).astype(np.uint8))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append({"source": len(js["images"]) - 1})
    js["materials"].append({"name": "skin-goo", "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorTexture": {"index": len(js["textures"]) - 1}, "metallicFactor": 0.0, "roughnessFactor": 0.6}})
    col = np.ones((len(Q), 4), np.float32)
    col[:, 3] = float(os.environ.get("ARM_INK", "0.5"))
    attrs = {"POSITION": out.add_floats(Q, "VEC3"), "NORMAL": out.add_floats(N, "VEC3"),
             "TEXCOORD_0": out.add_floats(UV, "VEC2"), "WEIGHTS_0": out.add_floats(wt, "VEC4"),
             "COLOR_0": out.add_floats(col, "VEC4")}
    js["accessors"][attrs["POSITION"]].update(min=Q.min(0).tolist(), max=Q.max(0).tolist())
    js["accessors"].append({"bufferView": out.add_view(jn.astype(np.uint16).tobytes()), "componentType": 5123,
                            "count": len(Q), "type": "VEC4"})
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    f = F.astype(np.uint32)
    js["accessors"].append({"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"})
    prims = js["meshes"][0]["primitives"]
    keep = [p for p in prims if js["materials"][p["material"]]["name"] != "skin-goo"]
    keep.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    js["meshes"][0]["primitives"] = keep
    return len(F), Q.min(0).round(2).tolist(), Q.max(0).round(2).tolist()


def rebuild_r11(out_path, in_path, pack_path=None):
    """The r11 stages on an r10 glb; each one writes the file and the next reloads it (new arrays live in the new
    file's buffer)."""
    stages = [("shoulder socket cap (tris)", cap_shoulder),
              ("goo weights", clean_goo_weights), ("tail keys", rebake_tail)]
    if pack_path:
        stages.insert(0, ("pack tris", lambda js, b, out, rig: swap_pack(js, b, out, rig, pack_path)))
    rebuild_stages(out_path, in_path, stages)


def rebuild_stages(out_path, in_path, stages):
    """Each stage writes the file and the next reloads it (new arrays live in the new file's buffer)."""
    src = in_path
    for name, fn in stages:
        rig = rs.Rig(src)
        out = n.Out(rig.js, rig.b)
        res = fn(rig.js, rig.b, out, rig)
        rs.compact(out)
        out.write(out_path)
        src = out_path
        print(name, res if res is not None else "ok")
    print("written", out_path)


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
    elif sys.argv[1] == "--r13":  # the r13 stages on the r12 glb
        pk = sys.argv[4] if len(sys.argv) > 4 else None
        un = sys.argv[5] if len(sys.argv) > 5 else None
        st = [("weights", weld_weights), ("puddle", trim_puddle), ("rim caps", cap_rims)]
        if pk:
            st.append(("pack tris", lambda js, b, out, rig: swap_pack(js, b, out, rig, pk, un)))
        st.append(("straps tris", add_straps))
        st += [("face winding", orient_faces), ("strap ink", strap_ink)]
        rebuild_stages(sys.argv[2], sys.argv[3], st)
    elif sys.argv[1] == "--r15":  # r15: calm the goo arm's swing in run/walk/jump, then the tail baked again
        rebuild_stages(sys.argv[2], sys.argv[3], [("goo arm", calm_goo_arm), ("tail gather", gather_tail)])
    elif sys.argv[1] == "--r16":  # r16: standing Idle, held jump/glide pose, then the tail baked again
        rebuild_stages(sys.argv[2], sys.argv[3], [("idle", fix_idle), ("jump", fix_jump), ("tail gather", gather_tail)])
    elif sys.argv[1] == "--r17":  # r17 (on an r16 file): goo arm hangs at its bind abduction, chain hangs, tail baked again
        rebuild_stages(sys.argv[2], sys.argv[3], [("goo arm", hang_goo_arm), ("tail gather", hang_tail)])
    elif sys.argv[1] == "--r18":  # r18: the slim Meshy goo arm swapped in (argv: OUT IN ARM.glb); the chain's clips stay
        rebuild_stages(sys.argv[2], sys.argv[3], [("goo arm swap", lambda js, b, out, rig: swap_goo_arm(js, b, out, rig, sys.argv[4]))])
    elif sys.argv[1] == "--r12":  # the r12 stage on the r11 glb (re-runnable)
        rebuild_stages(sys.argv[2], sys.argv[3], [("tail gather", gather_tail)])
    elif sys.argv[1] == "--r11":
        rebuild_r11(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    else:
        build(sys.argv[1], sys.argv[2])
