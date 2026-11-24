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
from scipy import ndimage
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
        {
            "bufferView": out.add_view(keep.astype(np.uint32).tobytes()),
            "componentType": 5125,
            "count": len(keep) * 3,
            "type": "SCALAR",
        }
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
    for a, b_ in e[bd]:
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
    px = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0) :][: bv["byteLength"]])).convert("RGB")).astype(int)
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
        lt = np.concatenate(tris[-(2 * rings_n - 1) :]) - base
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
    return {
        k: (
            n.floats(js, b, a)
            if js["accessors"][a]["componentType"] == 5126
            else np.frombuffer(
                n.view_bytes(js, b, js["accessors"][a]["bufferView"]), np.uint16, js["accessors"][a]["count"] * 4
            )
            .reshape(-1, 4)
            .copy()
        )
        for k, a in att.items()
    }


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
            js["accessors"].append(
                {
                    "bufferView": out.add_view(full.astype(np.uint16).tobytes()),
                    "componentType": 5123,
                    "count": len(full),
                    "type": "VEC4",
                }
            )
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
            A, D = a0[s0 : s0 + 256], d_[s0 : s0 + 256]
            t_ = np.clip(
                np.einsum("pij,ij->pi", mp[ti][:, None] - A[None], D) / np.maximum((D * D).sum(1), 1e-12), 0, 1
            )
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
    js["accessors"].append(
        {
            "bufferView": out.add_view(keep.astype(np.uint32).tobytes()),
            "componentType": 5125,
            "count": len(keep) * 3,
            "type": "SCALAR",
        }
    )
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
        print(
            f"{js['materials'][prim['material']]['name']:14s} {len(f):6d} tris, {len(size)} islands, "
            f"{int((size < MIN_TRIS).sum())} under {MIN_TRIS} tris (largest {size.max()})"
        )


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
            {
                "bufferView": out.add_view(f[keep].astype(np.uint32).tobytes()),
                "componentType": 5125,
                "count": int(keep.sum()) * 3,
                "type": "SCALAR",
            }
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
    js["accessors"].append(
        {
            "bufferView": out.add_view(nj.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(nj),
            "type": "VEC4",
        }
    )
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
    hue = np.where(
        mx == r,
        60 * ((g - b_) / np.maximum(mx - mn, 1)),
        np.where(mx == g, 60 * (2 + (b_ - r) / np.maximum(mx - mn, 1)), 0),
    )
    gold = (
        (hue > 29) & (hue < 60) & ((mx - mn) / np.maximum(mx, 1) > 0.5) & (mx > 60)
    )  # this pack's coins sit at 30-40 deg, its wood at 20-26
    drop = low & gold
    F = F[~drop]
    # loose shards (what the decimation left of the planks at the base): tiny islands anywhere, small ones in the bottom 40 %
    lab = island_labels(P, F)
    size = np.bincount(lab)
    cen = P[F].mean(1)
    shard = (size[lab] < 6) | ((size[lab] < 30) & (cen[:, 1] < lo[1] + 0.3 * (hi[1] - lo[1])))
    print(
        "pile cut:",
        int(drop.sum()),
        "triangles; shards dropped:",
        int(shard.sum()),
        "of",
        len(F),
        "islands <6:",
        int((size < 6).sum()),
        "<30:",
        int((size < 30).sum()),
        "of",
        len(size),
    )
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
    big = Image.open(
        io.BytesIO(bytes(n.view_bytes(pj, pb, pj["images"][pj["textures"][tex0]["source"]]["bufferView"])))
    ).convert("RGB")
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
    js["materials"].append(
        {
            "name": "pack-meshy",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": len(js["textures"]) - 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.75,
            },
        }
    )
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "TEXCOORD_0": out.add_floats(UV, "VEC2"),
        "WEIGHTS_0": out.add_floats(wt, "VEC4"),
    }
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(P),
            "type": "VEC4",
        }
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    f = F.astype(np.uint32)  # a turn keeps the winding
    js["accessors"].append(
        {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
    )
    prims = js["meshes"][0]["primitives"]
    keep = [
        p
        for p in prims
        if js["materials"][p["material"]]["name"] not in ("leather-pack", "brass-pack", "pack-meshy", "pack-under")
    ]
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
        js["materials"].append(
            {
                "name": "pack-under",
                "doubleSided": True,
                "pbrMetallicRoughness": {
                    "baseColorFactor": list(UNDER_COLOUR) + [1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.9,
                },
            }
        )
        ua = {
            "POSITION": out.add_floats(UP.astype(np.float32), "VEC3"),
            "NORMAL": out.add_floats(UN.astype(np.float32), "VEC3"),
            "WEIGHTS_0": out.add_floats(uwt, "VEC4"),
        }
        js["accessors"][ua["POSITION"]].update(min=UP.min(0).tolist(), max=UP.max(0).tolist())
        js["accessors"].append(
            {
                "bufferView": out.add_view(ujn.astype(np.uint16).tobytes()),
                "componentType": 5123,
                "count": len(UP),
                "type": "VEC4",
            }
        )
        ua["JOINTS_0"] = len(js["accessors"]) - 1
        js["accessors"].append(
            {"bufferView": out.add_view(UF.tobytes()), "componentType": 5125, "count": int(UF.size), "type": "SCALAR"}
        )
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
    js["accessors"].append(
        {"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"}
    )
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
CAP_BULGE = (
    0.2  # a dome rises CAP_BULGE x the rim's thin width (m), at most CAP_MAX; rings: per CAPS entry (0 = a fan fill)
)
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
    js["accessors"].append(
        {
            "bufferView": out.add_view(J2.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(J2),
            "type": "VEC4",
        }
    )
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
    js["accessors"].append(
        {"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"}
    )
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
        g = sp.coo_matrix(
            (np.ones(len(bd)), ([slot[x] for x in bd[:, 0]], [slot[x] for x in bd[:, 1]])), (len(ids),) * 2
        )
        lab = connected_components(g, directed=False)[1]
        de = np.concatenate([fs[:, [0, 1]], fs[:, [1, 2]], fs[:, [2, 0]]])
        bset = set(map(tuple, bd.tolist()))
        dbd = [
            tuple(e_) for e_ in de.tolist() if e_[0] != e_[1] and tuple(sorted(e_)) in bset
        ]  # rim edges, face direction
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
            order = (
                vs if legacy else rep[np.array(cyc)][::-1]
            )  # against the kept faces' direction: the fill's own winding
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
                lum = (
                    np.asarray(tex)[
                        np.clip((uvs[:, 1] % 1 * tex.size[1]).astype(int), 0, tex.size[1] - 1),
                        np.clip((uvs[:, 0] % 1 * tex.size[0]).astype(int), 0, tex.size[0] - 1),
                    ]
                    .astype(float)
                    .sum(1)
                )
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
                    elif (
                        key.startswith("TEXCOORD") and m_ > 0 and fixed
                    ):  # one texel for the whole dome: no streaks along the rim
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
                print(
                    "cap",
                    name,
                    n_pts,
                    "verts at",
                    ctr.round(2),
                    "dia",
                    round(float(np.ptp((p - ctr) @ ax[0])), 2),
                    "bulge",
                    round(float(bulge), 3),
                )
        report.append("%s %d" % (name, n_caps))
    if not total:
        return "no loop found"
    append_attrs(js, out, att, arr, new)
    prims = js["meshes"][0]["primitives"]
    for pi, trs in add.items():
        if not trs:
            continue
        full = np.concatenate([prim_faces(js, b, prims[pi]).astype(np.uint32)] + [t.astype(np.uint32) for t in trs])
        js["accessors"].append(
            {
                "bufferView": out.add_view(full.tobytes()),
                "componentType": 5125,
                "count": int(full.size),
                "type": "SCALAR",
            }
        )
        prims[pi]["indices"] = len(js["accessors"]) - 1
    return "; ".join(report) + ", %d new vertices, %d fixed-direction caps against their winding" % (total, clash)


ORIENT_TOP = (
    1.2  # m (rest pose): above this (the goo mouth, its cap and the shoulder) turning faces reopened black slits
)


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
        js["accessors"].append(
            {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
        )
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
STRAP_PATH = (
    (1.22, -0.37),
    (1.32, -0.395),
    (1.45, -0.40),
    (1.56, -0.395),
    (1.65, -0.33),
    (1.71, -0.22),
    (1.70, -0.10),
    (1.64, -0.02),
    (1.55, 0.045),
    (1.45, 0.06),
    (1.36, 0.02),
    (1.28, -0.05),
    (1.20, -0.10),
)
STRAP_COLOUR = (0.22, 0.11, 0.045)


def catmull(pts, k):
    p = np.vstack([pts[0], pts, pts[-1]])
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, k, endpoint=False):
            out.append(
                0.5
                * (
                    (2 * p[i])
                    + (-p[i - 1] + p[i + 1]) * t
                    + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t
                    + (-p[i - 1] + 3 * p[i] - 3 * p[i + 1] + p[i + 2]) * t**3
                )
            )
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
    js["materials"].append(
        {
            "name": "strap-leather",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorFactor": list(STRAP_COLOUR) + [1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.8,
            },
        }
    )
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "WEIGHTS_0": out.add_floats(wt, "VEC4"),
    }
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(P),
            "type": "VEC4",
        }
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    js["accessors"].append(
        {"bufferView": out.add_view(F.tobytes()), "componentType": 5125, "count": int(F.size), "type": "SCALAR"}
    )
    prims = js["meshes"][0]["primitives"]
    prims[:] = [p for p in prims if js["materials"][p["material"]]["name"] != "strap-leather"]
    prims.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    return len(F)


# r15: Meshy's run/walk/jump swing the right (goo) arm up past the chest and the tail chain follows the hand, so the goo
# lay over the torso like a sash in run/dash/jump (art-gate r13/r14). Those clips' right-arm keys are turned back toward
# the Idle clip's first-frame pose (keep ARM_KEEP of the swing); the tail is then baked again (gather_tail).
ARM_CLIPS, ARM_BONES, ARM_KEEP = (
    ("run", "walk", "Jump_Run", "Crouch_Walk_with_Torch"),
    ("RightShoulder", "RightArm", "RightForeArm", "RightHand"),
    float(__import__("os").environ.get("ARM_KEEP", "0.3")),
)


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
HANG_OUT = float(
    _E.get("HANG_OUT", "12")
)  # degrees the upper arm is lifted out to the side past that (goo off the hip)
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
    return np.stack(
        [
            aw * x + ax * w + ay * z - az * y,
            aw * y - ax * z + ay * w + az * x,
            aw * z + ax * y - ay * x + az * w,
            aw * w - ax * x - ay * y - az * z,
        ],
        1,
    )


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
    ("LeftUpLeg", -48),
    ("LeftLeg", 82),
    ("LeftFoot", -20),
    ("RightUpLeg", -48),
    ("RightLeg", 82),
    ("RightFoot", -20),
    ("Spine", 6),
    ("Spine01", 4),
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
ARM_BULB, ARM_BULB_Y, ARM_SOCKET = (
    1.0,
    1.36,
    "-0.17,-0.12",
)  # bulb 1 = none (a goo shoulder flare read as a wing, r18 try d/e)


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
    if flip:
        P[:, 0], N[:, 0] = -(P[:, 0] - mid[0]) + mid[0], -N[:, 0]
        F = F[:, ::-1]
    first = rig.names.index("GooTail0")
    pts = [
        rest_world(rig, nm)[1] for nm in ("RightArm", "RightForeArm", "GooTail0", "GooTail1", "GooTail2", "GooTail3")
    ]
    pts = np.array(pts)
    # tip: one more step down the chain's last segment
    pts = np.vstack([pts, pts[-1] + (pts[-1] - pts[-2])])
    y = bot + (P[:, 1] - lo[1]) * s
    px, pz = poly_xz(pts, y)
    bulb, by = float(os.environ.get("ARM_BULB", ARM_BULB)), float(os.environ.get("ARM_BULB_Y", ARM_BULB_Y))
    g = np.clip((y - by) / (top - by), 0, 1)
    g = 1 + (bulb - 1) * g * g * (
        3 - 2 * g
    )  # a goo shoulder mass over the open socket (the turnaround's goo arm is bulky there)
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
    gain = np.array(
        [float(x) for x in os.environ.get("ARM_GAIN", ARM_GAIN).split(",")]
    )  # albedo level match to the body's goo atlas
    im = Image.fromarray(np.clip(np.asarray(im, np.float32) * gain, 0, 255).astype(np.uint8))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append({"source": len(js["images"]) - 1})
    js["materials"].append(
        {
            "name": "skin-goo",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": len(js["textures"]) - 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.6,
            },
        }
    )
    col = np.ones((len(Q), 4), np.float32)
    col[:, 3] = float(os.environ.get("ARM_INK", "0.5"))
    attrs = {
        "POSITION": out.add_floats(Q, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "TEXCOORD_0": out.add_floats(UV, "VEC2"),
        "WEIGHTS_0": out.add_floats(wt, "VEC4"),
        "COLOR_0": out.add_floats(col, "VEC4"),
    }
    js["accessors"][attrs["POSITION"]].update(min=Q.min(0).tolist(), max=Q.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(Q),
            "type": "VEC4",
        }
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    f = F.astype(np.uint32)
    js["accessors"].append(
        {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
    )
    prims = js["meshes"][0]["primitives"]
    keep = [p for p in prims if js["materials"][p["material"]]["name"] != "skin-goo"]
    keep.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    js["meshes"][0]["primitives"] = keep
    return len(F), Q.min(0).round(2).tolist(), Q.max(0).round(2).tolist()


def rebuild_r11(out_path, in_path, pack_path=None):
    """The r11 stages on an r10 glb; each one writes the file and the next reloads it (new arrays live in the new
    file's buffer)."""
    stages = [
        ("shoulder socket cap (tris)", cap_shoulder),
        ("goo weights", clean_goo_weights),
        ("tail keys", rebake_tail),
    ]
    if pack_path:
        stages.insert(0, ("pack tris", lambda js, b, out, rig: swap_pack(js, b, out, rig, pack_path)))
    rebuild_stages(out_path, in_path, stages)


# r19: the r11 socket dome (cap_shoulder) copied each ring's UV from its nearest rim vertex, so its fan showed the
# rim's strap/goo texels smeared into grey/black streaks once the r18 slim arm stopped hiding it. Its triangles are
# found by their near-zero UV area in SOCKET_BOX; their vertices are duplicated with one UV: the most uniform
# skin texel of the left shoulder (closest to its median skin colour), so the dome reads as plain skin.
SKIN_UV_RATIO, SKIN_TOL = 0.01, 25.0  # dome = UV/3D area below this x the median; skin = albedo within this of SKIN_RGB
SKIN_MODE = os.environ.get("SKIN_MODE", "mirror")  # mirror: the left shoulder's UVs (one island); flat: one texel
SKIN_BOX = (np.array([0.0, 1.15, -0.5]), np.array([0.45, 1.75, 0.15]))  # m: the left shoulder (UV source, rest pose)


def skin_socket(js, b, out, rig):
    prim = js["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    arr = read_attrs(js, b, att)
    P, UV, f = arr["POSITION"], arr["TEXCOORD_0"], prim_faces(js, b, prim).astype(np.int64)
    a3 = np.linalg.norm(np.cross(P[f[:, 1]] - P[f[:, 0]], P[f[:, 2]] - P[f[:, 0]]), axis=1) / 2
    u = UV[f]
    a2 = (
        np.abs(
            (u[:, 1, 0] - u[:, 0, 0]) * (u[:, 2, 1] - u[:, 0, 1])
            - (u[:, 2, 0] - u[:, 0, 0]) * (u[:, 1, 1] - u[:, 0, 1])
        )
        / 2
    )
    ratio = a2 / np.maximum(a3, 1e-12)
    lo, hi = SOCKET_BOX
    c = P[f].mean(1)
    dome = ((c >= lo) & (c <= hi)).all(1) & (ratio < SKIN_UV_RATIO * np.median(ratio[a3 > 0]))
    mat = js["materials"][prim["material"]]
    img = js["images"][js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    tex = np.asarray(Image.open(io.BytesIO(bytes(n.view_bytes(js, b, img["bufferView"])))).convert("RGB"), np.float32)
    th, tw = tex.shape[:2]
    col = tex[np.clip((UV[:, 1] % 1) * th, 0, th - 1).astype(int), np.clip((UV[:, 0] % 1) * tw, 0, tw - 1).astype(int)]
    used = np.zeros(len(P), bool)
    used[f[~dome]] = True
    slo, shi = SKIN_BOX
    src = np.where(used & ((P >= slo) & (P <= shi)).all(1))[0]
    skin_rgb = np.median(col[src], 0)
    src = src[np.linalg.norm(col[src] - skin_rgb, axis=1) < SKIN_TOL]
    dv = np.unique(f[dome])
    new = {k: [arr[k][dv]] for k in arr}
    if SKIN_MODE == "mirror":  # UVs of the mirrored point on the left shoulder's biggest UV island (smooth, textured)
        keep = np.zeros(len(P), bool)
        keep[src] = True
        sf = f[~dome][keep[f[~dome]].all(1)]
        g = sp.coo_matrix((np.ones(len(sf) * 2), (np.r_[sf[:, 0], sf[:, 1]], np.r_[sf[:, 1], sf[:, 2]])), (len(P),) * 2)
        lab = connected_components(g, directed=False)[1]
        isl = np.bincount(lab[src]).argmax()
        src = src[lab[src] == isl]
        near = src[cKDTree(P[src]).query(P[dv] * np.array([-1.0, 1.0, 1.0]))[1]]
        new["TEXCOORD_0"] = [UV[near]]
        return_note = ("mirror island", len(src))
    else:  # one texel for the whole dome: per-vertex UVs from scattered atlas islands interpolate into noise
        tu = np.clip((UV[src, 0] % 1) * tw, 4, tw - 5).astype(int)
        tv = np.clip((UV[src, 1] % 1) * th, 4, th - 5).astype(int)
        std = np.array([tex[y - 4 : y + 5, x - 4 : x + 5].std((0, 1)).sum() for x, y in zip(tu, tv)])
        best = src[np.argmin(std + np.linalg.norm(col[src] - skin_rgb, axis=1))]
        new["TEXCOORD_0"] = [np.repeat(UV[best][None], len(dv), 0)]
        return_note = ("flat texel", col[best].round().tolist())
    remap = np.full(len(P), -1)
    remap[dv] = len(P) + np.arange(len(dv))
    f2 = f.copy()
    f2[dome] = remap[f[dome]]
    append_attrs(js, out, att, arr, new)
    full = f2.astype(np.uint32).ravel()
    js["accessors"].append(
        {"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    return int(dome.sum()), len(dv), skin_rgb.round().tolist(), return_note


STRAP_MAX_LIFT = 0.03  # m: a strap row never moves further than this
STRAP_BACK_Z = (
    0.05  # m: only rows behind this z (the shoulder top and back) lift; the chest rows already clear the skin
)
STRAP_ACROSS = 3  # r14 strap: 3 vertices across, rows of them, one strap after the other (right one first)


def lift_strap(js, b, out, rig):
    """r19: the right shoulder strap (add_straps, r14 layout: 3 across x rows, right strap first) ran under the r11
    socket dome. Each row is lifted as a whole along its middle vertex's normal until its worst column clears the skin
    (dome included) by STRAP_LIFT, then smoothed along the path. Chest rows (z >= STRAP_BACK_Z) are left alone."""
    prims = js["meshes"][0]["primitives"]
    sp_ = next(p for p in prims if js["materials"][p["material"]]["name"] == "strap-leather")
    skin = prims[0]
    B = n.floats(js, b, skin["attributes"]["POSITION"])[np.unique(prim_faces(js, b, skin))]
    lo, hi = SOCKET_BOX
    B = B[((B >= lo) & (B <= hi)).all(1)]  # only the dome side's shoulder (not the jaw/ear the strap passes)
    S = n.floats(js, b, sp_["attributes"]["POSITION"]).copy()
    N = n.floats(js, b, sp_["attributes"]["NORMAL"])
    k = STRAP_ACROSS
    rows = len(S) // k
    lifts = np.zeros(rows)
    for r in range(rows):
        V, nn = S[k * r : k * r + k], N[k * r + k // 2] / np.linalg.norm(N[k * r + k // 2])
        if V[:, 2].mean() >= STRAP_BACK_Z:
            continue
        need = 0.0
        for v in V:
            d = B - v
            h = d @ nn
            near = (np.linalg.norm(d - h[:, None] * nn, axis=1) < 0.03) & (np.abs(h) < STRAP_MAX_LIFT + STRAP_LIFT)
            if near.any():
                need = max(need, h[near].max() + STRAP_LIFT)
        lifts[r] = min(STRAP_MAX_LIFT, max(0.0, need))
    side_rows = rows // 2  # rows of the first strap, then the second
    for s_ in range(2):
        seg = lifts[s_ * side_rows : (s_ + 1) * side_rows]
        sm = np.maximum(seg, np.convolve(np.pad(seg, 1, mode="edge"), np.ones(3) / 3, "valid"))
        lifts[s_ * side_rows : (s_ + 1) * side_rows] = sm
    S += np.repeat(lifts, k)[:, None] * N / np.linalg.norm(N, axis=1, keepdims=True)
    acc = out.add_floats(S.astype(np.float32), "VEC3")
    js["accessors"][acc].update(min=S.min(0).tolist(), max=S.max(0).tolist())
    sp_["attributes"]["POSITION"] = acc
    return np.round(lifts.max(), 3), int((lifts > 0.002).sum())


def drop_under(js, b, out, rig):
    """r19: the 'under' skin layer (prim 4) shows through the socket dome as a grey sheet: its triangles inside
    SOCKET_BOX are removed (the dome and the skin around it cover the shoulder)."""
    prim = next(
        p for p in js["meshes"][0]["primitives"] if js["materials"][p["material"]].get("extras", {}).get("under")
    )
    P = n.floats(js, b, prim["attributes"]["POSITION"])
    f = prim_faces(js, b, prim).astype(np.int64)
    lo, hi = SOCKET_BOX
    c = P[f].mean(1)
    gone = ((c >= lo) & (c <= hi)).all(1)
    full = f[~gone].astype(np.uint32).ravel()
    js["accessors"].append(
        {"bufferView": out.add_view(full.tobytes()), "componentType": 5125, "count": int(full.size), "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    return int(gone.sum())


# r20: the r11 socket dome is a flat disc of 2198 triangles over the whole right torso side (y 1.20-1.71, z -0.41-0.10 m)
# with a quarter of its weight on the head bones (headfront/Head), so once the slim arm stopped hiding it it read as a
# flat grey panel that slid with the head in the attack. Its vertices move onto the mirrored left torso/shoulder (the
# Meshy surface there) and take the mirrored left skin weights, both fading in over DOME_BLEND from the open rim (the
# rim stays welded to Meshy's skin round it).
DOME_SMOOTH = (40, 6)  # rounds: offset smoothing, position relax
DOME_BLEND, DOME_MAX_MOVE, DOME_CORE = 0.05, 0.12, (0.06, (1.30, 1.62), -0.15)  # m; core: x, y clamp, z (left space)


def mirror_name(s):
    return s.replace("Left", "\0").replace("Right", "Left").replace("\0", "Right")


def reshape_socket(js, b, out, rig):
    prim = js["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    arr = read_attrs(js, b, att)
    P, f = arr["POSITION"].copy(), prim_faces(js, b, prim).astype(np.int64)
    lo, hi = SOCKET_BOX
    c = P[f].mean(1)
    inbox = ((c >= lo) & (c <= hi)).all(1)
    g = sp.coo_matrix(
        (np.ones(len(f) * 3), (np.r_[f[:, 0], f[:, 1], f[:, 2]], np.r_[f[:, 1], f[:, 2], f[:, 0]])), (len(P),) * 2
    )
    lab = connected_components(g, directed=False)[1]
    flab = lab[f[:, 0]]
    cnt, cin = np.bincount(flab, minlength=lab.max() + 1), np.bincount(flab, inbox, minlength=lab.max() + 1)
    domes = np.where((cnt >= 500) & (cin == cnt))[0]  # a vertex-separate island wholly in the socket box: r19's dome
    dome = np.isin(flab, domes)
    dv = np.unique(f[dome])
    rest = np.unique(f[~dome])
    tree = cKDTree(P[rest])
    rim_d = cKDTree(P[dv[tree.query(P[dv])[0] < ISLAND_TOL]]).query(P[dv])[0]  # distance to the welded rim
    a = np.clip(rim_d / DOME_BLEND, 0, 1)
    a = a * a * (3 - 2 * a)
    flip = np.array([-1.0, 1.0, 1.0])
    lf = f[~dome & (P[f].mean(1)[:, 0] > 0.02)]  # the left side's skin (no dome there)
    tri = P[lf]
    tri = tri[(tri.mean(1)[:, 1] > 1.0)]
    e1, e2 = tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]
    moved = 0
    disp = np.zeros((len(dv), 3))
    for i, v in enumerate(P[dv]):
        vm = v * flip
        o = np.array([DOME_CORE[0], np.clip(vm[1], *DOME_CORE[1]), DOME_CORE[2]])
        d = vm - o
        r0 = np.linalg.norm(d)
        d /= r0
        h = np.cross(d, e2)
        det = (e1 * h).sum(1)
        ok = np.abs(det) > 1e-9
        ia = np.where(ok, 1 / np.where(ok, det, 1), 0)
        s = o - tri[:, 0]
        q = np.cross(s, e1)
        u, w, t = ia * (s * h).sum(1), ia * (q * d).sum(1), ia * (e2 * q).sum(1)
        t = t[ok & (u >= 0) & (w >= 0) & (u + w <= 1) & (t > 0)]
        if not len(t):
            continue
        t = t[np.argmin(np.abs(t - r0))]  # the left surface nearest the dome's own radius (not an inner layer)
        if abs(t - r0) > DOME_MAX_MOVE:
            continue
        disp[i] = a[i] * (((o + d * t) * flip) - v)
        moved += 1
    # the offsets are smoothed over the dome (rim pinned at 0): per-vertex hits jump between surface layers and fold the
    # cap; then the positions relax a little (same pin), which also unfolds the r11 rings
    df = f[dome]
    li = {v: i for i, v in enumerate(dv)}
    e = np.array([[li[x] for x in r] for r in df])
    A = sp.coo_matrix(
        (
            np.ones(len(e) * 6),
            (
                np.r_[e[:, 0], e[:, 1], e[:, 2], e[:, 1], e[:, 2], e[:, 0]],
                np.r_[e[:, 1], e[:, 2], e[:, 0], e[:, 0], e[:, 1], e[:, 2]],
            ),
        ),
        (len(dv),) * 2,
    ).tocsr()
    A.data[:] = 1.0
    deg = np.maximum(np.asarray(A.sum(1)).ravel(), 1)[:, None]
    free = (rim_d > ISLAND_TOL)[:, None]
    for _ in range(DOME_SMOOTH[0]):
        disp = np.where(free, 0.5 * disp + 0.5 * (A @ disp) / deg, 0.0)
    Q = P[dv] + disp
    for _ in range(DOME_SMOOTH[1]):
        Q = np.where(free, 0.6 * Q + 0.4 * (A @ Q) / deg, Q)
    P[dv] = Q
    # weights and normals of the mirrored left vertex nearest each moved point
    lv = np.unique(lf)
    near = lv[cKDTree(P[lv] * flip).query(P[dv])[1]]
    nb = len(rig.names)
    remap = np.array(
        [rig.names.index(mirror_name(s)) if mirror_name(s) in rig.names else k for k, s in enumerate(rig.names)]
    )
    mj = remap[arr["JOINTS_0"][near].astype(np.int64)]
    dm = rs.dense(mj, arr["WEIGHTS_0"][near], nb)
    do = rs.dense(arr["JOINTS_0"][dv].astype(np.int64), arr["WEIGHTS_0"][dv], nb)
    nj, nw = rs.top4((1 - a[:, None]) * do + a[:, None] * dm)
    arr["JOINTS_0"][dv], arr["WEIGHTS_0"][dv] = nj, nw
    if "NORMAL" in arr:
        nm = arr["NORMAL"][near] * flip
        nn = (1 - a[:, None]) * arr["NORMAL"][dv] + a[:, None] * nm
        arr["NORMAL"][dv] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
    uv_note = ""
    if "TEXCOORD_0" in arr:  # the dome gets its own texture: the mirrored left skin baked onto planar UVs
        uv_note = bake_dome(js, b, out, prim, arr, P, f, dome, dv, lf)
    arr["POSITION"] = P
    for k, acc in list(att.items()):  # rewrite in place (same count): every primitive sharing the arrays follows
        v = arr[k]
        if js["accessors"][acc]["componentType"] == 5126:
            new = out.add_floats(v.astype(np.float32), js["accessors"][acc]["type"])
            if k == "POSITION":
                js["accessors"][new].update(min=v.min(0).tolist(), max=v.max(0).tolist())
        else:
            js["accessors"].append(
                {
                    "bufferView": out.add_view(v.astype(np.uint16).tobytes()),
                    "componentType": 5123,
                    "count": len(v),
                    "type": "VEC4",
                }
            )
            new = len(js["accessors"]) - 1
        for p2 in js["meshes"][0]["primitives"]:
            if p2["attributes"].get(k) == acc:
                p2["attributes"][k] = new
    head = sum(
        nw[:, j][np.isin(nj[:, j], [rig.names.index(s) for s in STRAY if s in rig.names])].sum() for j in range(4)
    )
    return "dome tris %d, verts %d, moved %d, head/spine weight left %.0f; %s" % (
        dome.sum(),
        len(dv),
        moved,
        head,
        uv_note,
    )


DOME_UV_CORE_X = 0.15  # m: x of the point the dome's UV angles are taken from
DOME_TEX = 512  # px: the dome's own baked texture (its planar UVs, 2% margin)


def bake_dome(js, b, out, prim, arr, P, f, dome, dv, lf):
    """Per-vertex UVs taken from the atlas interpolate across Meshy's UV islands (stripes, and the brass/strap texels gave
    r19's bronze sheen). The dome instead gets planar UVs (its own two main axes) and a DOME_TEX texture where each texel
    holds the atlas colour of the mirrored point on the left skin (closest left triangle, barycentric UV, so texels never
    straddle islands). Its triangles move to their own primitive: a copy of the skin material with that texture, no normal
    map, the skin's median roughness/metal as constants."""
    flip = np.array([-1.0, 1.0, 1.0])
    D = P[dv]
    ctr = D.mean(0)
    core = np.array([DOME_UV_CORE_X, ctr[1], ctr[2]])  # angles seen from inside the torso: the dome wraps the shoulder,
    d = D - core  # so a flat projection folds; from the core it is star-shaped
    uv = np.c_[np.arctan2(d[:, 2], -d[:, 0]), np.arctan2(d[:, 1], np.hypot(d[:, 0], d[:, 2]))]
    uv = (uv - uv.min(0)) / np.ptp(uv, 0).max()
    uv = 0.02 + 0.96 * uv
    mat = js["materials"][prim["material"]]

    def tex_of(ti):
        img = js["images"][js["textures"][ti]["source"]]
        return np.asarray(
            Image.open(io.BytesIO(bytes(n.view_bytes(js, b, img["bufferView"])))).convert("RGB"), np.float32
        )

    atlas = tex_of(mat["pbrMetallicRoughness"]["baseColorTexture"]["index"])
    UV = arr["TEXCOORD_0"]
    lt = P[lf]
    lc = cKDTree(lt.mean(1))
    S = DOME_TEX
    img = np.zeros((S, S, 3), np.float32)
    have = np.zeros((S, S), bool)
    slot = {v: i for i, v in enumerate(dv)}
    for tri3 in f[dome]:
        t2 = uv[[slot[v] for v in tri3]] * S
        x0, y0 = np.floor(t2.min(0)).astype(int)
        x1, y1 = np.ceil(t2.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, S)), np.arange(max(y0, 0), min(y1 + 1, S)))
        pts = np.c_[xs.ravel() + 0.5, ys.ravel() + 0.5]
        m = np.c_[t2[1] - t2[0], t2[2] - t2[0]]
        if abs(np.linalg.det(m)) < 1e-9:
            continue
        bc = np.linalg.solve(m, (pts - t2[0]).T).T
        w = np.c_[1 - bc.sum(1), bc]
        inside = (w >= -0.02).all(1)
        if not inside.any():
            continue
        q = (w[inside] @ P[tri3]) * flip  # the texel's 3D point, mirrored onto the left side
        k = lc.query(q, k=4)[1]
        best = np.zeros((len(q), 2))
        bd = np.full(len(q), np.inf)
        for j in range(4):  # closest point among the 4 nearest left triangles, as barycentric UV
            T = lt[k[:, j]]
            e0, e1 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
            d = q - T[:, 0]
            a00, a01, a11 = (e0 * e0).sum(1), (e0 * e1).sum(1), (e1 * e1).sum(1)
            b0, b1 = (d * e0).sum(1), (d * e1).sum(1)
            den = np.maximum(a00 * a11 - a01 * a01, 1e-12)
            s_, t_ = np.clip((a11 * b0 - a01 * b1) / den, 0, 1), np.clip((a00 * b1 - a01 * b0) / den, 0, 1)
            over = s_ + t_ > 1
            s_[over], t_[over] = s_[over] / (s_ + t_)[over], t_[over] / (s_ + t_)[over]
            dist = np.linalg.norm(T[:, 0] + s_[:, None] * e0 + t_[:, None] * e1 - q, axis=1)
            u3 = UV[lf[k[:, j]]]
            uvq = u3[:, 0] * (1 - s_ - t_)[:, None] + u3[:, 1] * s_[:, None] + u3[:, 2] * t_[:, None]
            nearer = dist < bd
            best[nearer], bd[nearer] = uvq[nearer], dist[nearer]
        th, tw = atlas.shape[:2]
        px = np.clip((best[:, 0] % 1) * tw, 0, tw - 1).astype(int)
        py = np.clip((best[:, 1] % 1) * th, 0, th - 1).astype(int)
        gx, gy = xs.ravel()[inside], ys.ravel()[inside]
        img[gy, gx] = atlas[py, px]
        have[gy, gx] = True
    idx = ndimage.distance_transform_edt(~have, return_distances=False, return_indices=True)
    img = img[idx[0], idx[1]]  # empty texels take the nearest filled one (filter/mip margin)
    img = ndimage.gaussian_filter(img, (0.7, 0.7, 0))  # one-texel soften: neighbouring atlas islands shade apart
    buf = io.BytesIO()
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(buf, "JPEG", quality=92)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append(
        {
            "source": len(js["images"]) - 1,
            **({"sampler": js["textures"][0]["sampler"]} if "sampler" in js["textures"][0] else {}),
        }
    )
    pbr = dict(mat["pbrMetallicRoughness"])
    pbr["baseColorTexture"] = {"index": len(js["textures"]) - 1}
    rough = 0.85
    if "metallicRoughnessTexture" in pbr:
        mr = tex_of(pbr.pop("metallicRoughnessTexture")["index"])
        su = UV[np.unique(lf)]
        g_ = mr[
            np.clip((su[:, 1] % 1) * mr.shape[0], 0, mr.shape[0] - 1).astype(int),
            np.clip((su[:, 0] % 1) * mr.shape[1], 0, mr.shape[1] - 1).astype(int),
        ]
        rough = float(np.median(g_[:, 1]) / 255)
        pbr["metallicFactor"], pbr["roughnessFactor"] = float(np.median(g_[:, 2]) / 255), rough
    dm = {k: v for k, v in mat.items() if k not in ("normalTexture", "pbrMetallicRoughness", "name")}
    dm.update(name="skin-native-dome", pbrMetallicRoughness=pbr)
    js["materials"].append(dm)
    arr["TEXCOORD_0"][dv] = uv.astype(np.float32)
    keep = f[~dome].astype(np.uint32).ravel()
    js["accessors"].append(
        {"bufferView": out.add_view(keep.tobytes()), "componentType": 5125, "count": int(keep.size), "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    dp_ = {k: v for k, v in prim.items() if k not in ("indices", "material")}
    dfl = f[dome].astype(np.uint32).ravel()
    js["accessors"].append(
        {"bufferView": out.add_view(dfl.tobytes()), "componentType": 5125, "count": int(dfl.size), "type": "SCALAR"}
    )
    dp_.update(indices=len(js["accessors"]) - 1, material=len(js["materials"]) - 1)
    js["meshes"][0]["primitives"].append(dp_)  # (attributes are repointed below with the skin's: same dict objects)
    u2 = uv[np.array([slot[v] for v in f[dome].ravel()])].reshape(-1, 3, 2)
    a2 = (u2[:, 1, 0] - u2[:, 0, 0]) * (u2[:, 2, 1] - u2[:, 0, 1]) - (u2[:, 2, 0] - u2[:, 0, 0]) * (
        u2[:, 1, 1] - u2[:, 0, 1]
    )
    folds = int(min((a2 < 0).sum(), (a2 > 0).sum()))
    return "dome texture %dpx, %d texels, uv folds %d, roughness %.2f" % (S, int(have.sum()), folds, rough)


# r20: the r19 grey sheet at the right shoulder was the RIGHT STRAP itself (a recoloured render shows it): r14 cast each
# of its three columns onto the skin separately, the right ones landed at uneven depths on the old socket dome, so its
# rows were 0.13-0.16 m across (left 0.06-0.07) and tilted into a wide wedge that the arm swings up in the attack.
# The right rows become the x-mirror of the clean left rows, each moved as a whole along its normal onto the right skin.
MIRROR_LIFT, MIRROR_CAP, MIRROR_PROBE = 0.006, 0.04, 0.08  # m: clearance off the skin, largest move, search half-depth


def mirror_strap(js, b, out, rig):
    """r20: right strap rows = mirrored left rows (column order reversed so UVs and winding stay), each row shifted rigidly
    along its normal to sit MIRROR_LIFT over the outermost right skin under its columns; r14's weights (mean of the
    STRAP_K skin vertices nearest the row middle) taken again on the right."""
    import dredge_r14 as r14

    prims = js["meshes"][0]["primitives"]
    st = next(p for p in prims if js["materials"][p["material"]]["name"] == "strap-leather")
    skin = prims[0]
    S = n.floats(js, b, st["attributes"]["POSITION"]).copy()
    N = n.floats(js, b, st["attributes"]["NORMAL"]).copy()
    k, rows = STRAP_ACROSS, len(S) // STRAP_ACROSS
    half = rows // 2  # rows of the right strap (first), then the left
    sp_ = n.floats(js, b, skin["attributes"]["POSITION"])
    sf = prim_faces(js, b, skin).astype(np.int64)
    tri = sp_[sf]
    c = tri.mean(1)
    tri = tri[(c[:, 0] < 0.0) & (c[:, 0] > -0.45) & (c[:, 1] > 1.0)]
    flip = np.array([-1.0, 1.0, 1.0])
    shifts = []
    for r in range(half):
        L = S[k * (half + r) : k * (half + r) + k][::-1] * flip
        nn = N[k * (half + r) + k // 2] * flip
        nn = nn / np.linalg.norm(nn)
        need = []
        for v in L:
            o = v - MIRROR_PROBE * nn
            e1, e2 = tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]
            h = np.cross(nn, e2)
            a = (e1 * h).sum(1)
            ok = np.abs(a) > 1e-9
            ia = np.where(ok, 1 / np.where(ok, a, 1), 0)
            s = o - tri[:, 0]
            q = np.cross(s, e1)
            u, w, t = ia * (s * h).sum(1), ia * (q * nn).sum(1), ia * (e2 * q).sum(1)
            t = t[ok & (u >= 0) & (w >= 0) & (u + w <= 1) & (t > 0) & (t < 2 * MIRROR_PROBE)]
            if len(t):
                need.append(t.max() - MIRROR_PROBE)  # the outermost skin layer's offset from v along nn
        sh = float(np.clip(max(need) + MIRROR_LIFT, -MIRROR_CAP, MIRROR_CAP)) if need else 0.0
        shifts.append(sh)
        S[k * r : k * r + k] = L + sh * nn
        N[k * r : k * r + k] = nn
    shifts = np.array(shifts)
    sm = np.convolve(np.pad(shifts, 1, mode="edge"), np.ones(3) / 3, "valid")  # no step between neighbour rows
    for r in range(half):
        S[k * r : k * r + k] += (sm[r] - shifts[r]) * N[k * r + k // 2]
    sj, sw = r14.joints_weights(js, b, skin["attributes"])
    ids = np.unique(sf)
    near = ids[cKDTree(sp_[ids]).query(S[1 : k * half : k], k=r14.STRAP_K)[1]]
    dn = rs.dense(sj, sw, len(rig.names))
    jn, wt = rs.top4(dn[near].mean(1))
    J, W = r14.joints_weights(js, b, st["attributes"])
    J, W = J.astype(np.uint16).copy(), W.copy()
    J[: k * half], W[: k * half] = jn.repeat(k, axis=0), wt.repeat(k, axis=0)
    acc = out.add_floats(S.astype(np.float32), "VEC3")
    js["accessors"][acc].update(min=S.min(0).tolist(), max=S.max(0).tolist())
    st["attributes"]["POSITION"] = acc
    st["attributes"]["NORMAL"] = out.add_floats(N.astype(np.float32), "VEC3")
    st["attributes"]["WEIGHTS_0"] = out.add_floats(W.astype(np.float32), "VEC4")
    js["accessors"].append(
        {"bufferView": out.add_view(J.tobytes()), "componentType": 5123, "count": len(J), "type": "VEC4"}
    )
    st["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
    width = np.linalg.norm(S[0 : k * half : k] - S[k - 1 : k * half : k], axis=1)
    return "right rows %d, width %.3f-%.3f m, shift %.3f..%.3f m" % (half, width.min(), width.max(), sm.min(), sm.max())


# r21: the second junk ball trio (r16b left a copy 23 cm further back), strap UVs on the dark leather and spine/shoulder
# weights only, the socket dome's texture matched to the body round it, and the skin/goo grade toward the turnaround.
BALL_DROP_Z = -0.9  # m (rest pose): ball prims centred behind this are the stray copy (the r16b one sits at z -0.75)
STRAP_U = (0.3, 0.5, 0.7)  # strap texture columns: inside the two light stitch lines (u 0.19 and 0.81)
STRAP_BONES = ("Spine02", "Spine01", "LeftShoulder", "RightShoulder")
SKIN_HUE = (290.0, 355.0)  # deg: atlas texels in this hue band (and S > SKIN_MIN_S) are skin
SKIN_MIN_S = 0.15
SKIN_DS, SKIN_DV = -0.10, 0.07  # turnaround skin S 0.38 vs r20 0.48 (PLAN 2.5)
GOO_DH = float(_E.get("GOO_DH", "-7"))  # deg: r18 goo texture hue turn (turnaround goo H 301, r20 310-323)


def _image(js, b, ii):
    return np.asarray(Image.open(io.BytesIO(bytes(n.view_bytes(js, b, js["images"][ii]["bufferView"])))).convert("RGB"))


def _set_image(js, out, ii, arr):
    buf = io.BytesIO()
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(buf, "JPEG", quality=92)
    js["images"][ii]["bufferView"] = out.add_view(buf.getvalue())
    js["images"][ii]["mimeType"] = "image/jpeg"


def _mat_image(js, name):
    mat = next(
        m for m in js["materials"] if m["name"] == name and "baseColorTexture" in m.get("pbrMetallicRoughness", {})
    )
    return js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]


def prune_materials(js):
    """Drops the materials, textures and images no primitive uses (indices remapped)."""
    prims = js["meshes"][0]["primitives"]
    mats = sorted({p["material"] for p in prims})
    mmap = {o: i for i, o in enumerate(mats)}
    js["materials"] = [js["materials"][i] for i in mats]
    for p in prims:
        p["material"] = mmap[p["material"]]
    tex = sorted(
        {
            m["pbrMetallicRoughness"]["baseColorTexture"]["index"]
            for m in js["materials"]
            if "baseColorTexture" in m.get("pbrMetallicRoughness", {})
        }
    )
    tmap = {o: i for i, o in enumerate(tex)}
    js["textures"] = [js["textures"][i] for i in tex]
    for m in js["materials"]:
        bc = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if bc:
            bc["index"] = tmap[bc["index"]]
    imgs = sorted({t["source"] for t in js["textures"]})
    imap = {o: i for i, o in enumerate(imgs)}
    js["images"] = [js["images"][i] for i in imgs]
    for t in js["textures"]:
        t["source"] = imap[t["source"]]


def drop_ball_copy(js, b, out, rig):
    prims = js["meshes"][0]["primitives"]
    keep, gone = [], 0
    for p in prims:
        z = n.floats(js, b, p["attributes"]["POSITION"])[np.unique(prim_faces(js, b, p))][:, 2].mean()
        if js["materials"][p["material"]]["name"].endswith("-ball") and z < BALL_DROP_Z:
            gone += len(prim_faces(js, b, p))
        else:
            keep.append(p)
    js["meshes"][0]["primitives"] = keep
    prune_materials(js)
    return "ball copy tris dropped %d" % gone


def strap_r21(js, b, out, rig):
    import dredge_r14 as r14

    prims = js["meshes"][0]["primitives"]
    st = next(p for p in prims if js["materials"][p["material"]]["name"] == "strap-leather")
    skin = prims[0]
    S = n.floats(js, b, st["attributes"]["POSITION"])
    UV = n.floats(js, b, st["attributes"]["TEXCOORD_0"]).copy()
    UV[:, 0] = np.array(STRAP_U)[np.arange(len(UV)) % STRAP_ACROSS]
    st["attributes"]["TEXCOORD_0"] = out.add_floats(UV.astype(np.float32), "VEC2")
    sp_ = n.floats(js, b, skin["attributes"]["POSITION"])
    ids = np.unique(prim_faces(js, b, skin))
    sj, sw = r14.joints_weights(js, b, skin["attributes"])
    dn = rs.dense(sj, sw, len(rig.names))
    near = ids[cKDTree(sp_[ids]).query(S, k=r14.STRAP_K)[1]]
    w = dn[near].mean(1)
    allow = np.zeros(len(rig.names), bool)
    allow[[rig.names.index(x) for x in STRAP_BONES]] = True
    w[:, ~allow] = 0.0
    empty = w.sum(1) < 1e-6
    w[empty, rig.names.index("Spine02")] = 1.0
    jn, wt = rs.top4(w / w.sum(1, keepdims=True))
    st["attributes"]["WEIGHTS_0"] = out.add_floats(wt.astype(np.float32), "VEC4")
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(jn),
            "type": "VEC4",
        }
    )
    st["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
    k = STRAP_ACROSS
    width = np.linalg.norm(S[0::k] - S[k - 1 :: k], axis=1)
    return "strap u %s, weights on %s only (%d fell back to Spine02), width %.3f-%.3f m" % (
        STRAP_U,
        "/".join(STRAP_BONES),
        int(empty.sum()),
        width.min(),
        width.max(),
    )


def _hsv(a):
    """RGB 0-255 -> HSV 0-1 (numpy)."""
    a = a / 255.0
    mx, mn = a.max(-1), a.min(-1)
    d = np.where(mx > mn, mx - mn, 1.0)
    r, g, bl = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, (g - bl) / d, np.where(mx == g, 2.0 + (bl - r) / d, 4.0 + (r - g) / d))
    h = np.where(mx > mn, (h / 6.0) % 1.0, 0.0)
    return np.stack([h, np.where(mx > 0, (mx - mn) / np.where(mx > 0, mx, 1), 0.0), mx], -1)


def _rgb(hsv):
    """HSV 0-1 -> RGB 0-255 (numpy)."""
    h, s, v = (np.clip(hsv[..., i], 0, 1) for i in range(3))
    i = np.floor(h * 6.0) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    sel = [i == k for k in range(6)]
    r = np.select(sel, [v, q, p, p, t, v])
    g = np.select(sel, [t, v, v, q, p, p])
    bl = np.select(sel, [p, p, t, v, v, q])
    return np.stack([r, g, bl], -1) * 255.0


def grade_r21(js, b, out, rig):
    """Skin texels of the body atlas and the dome: S + SKIN_DS, V + SKIN_DV. The dome's texture first takes the body's
    median colour along its rim (per-channel gain: its inner median was greener, its rim darker = the line on the shoulder
    crest). The r18 goo arm texture: hue + GOO_DH."""
    prims = js["meshes"][0]["primitives"]
    skin = prims[0]
    atlas, dome_i, goo_i = _mat_image(js, "skin-native"), _mat_image(js, "skin-native-dome"), _mat_image(js, "skin-goo")
    msg = []
    A = _image(js, b, atlas).astype(float)
    dome = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-native-dome")
    f = prim_faces(js, b, dome).astype(np.int64)
    e = np.sort(np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]]), 1)
    u, c = np.unique(e, axis=0, return_counts=True)
    rim = np.unique(u[c == 1])
    D = _image(js, b, dome_i).astype(float)
    duv = n.floats(js, b, dome["attributes"]["TEXCOORD_0"])
    sp_, suv = n.floats(js, b, skin["attributes"]["POSITION"]), n.floats(js, b, skin["attributes"]["TEXCOORD_0"])
    ids = np.unique(prim_faces(js, b, skin))
    near = ids[cKDTree(sp_[ids]).query(n.floats(js, b, dome["attributes"]["POSITION"])[rim], k=8)[1]].ravel()

    def texel(img, uv):
        h, w = img.shape[:2]
        return img[(uv[:, 1] * h).astype(int).clip(0, h - 1), (uv[:, 0] * w).astype(int).clip(0, w - 1)]

    body = np.median(texel(A, suv[near]), 0)
    inner = np.median(texel(D, duv[np.setdiff1d(np.unique(f), rim)]), 0)
    D = D * (body / np.maximum(inner, 1))
    msg.append("dome gain %s" % np.round(body / np.maximum(inner, 1), 2).tolist())
    for name, img, ii in (("atlas", A, atlas), ("dome", D, dome_i)):
        hsv = _hsv(img)
        m = (hsv[..., 0] * 360 >= SKIN_HUE[0]) & (hsv[..., 0] * 360 <= SKIN_HUE[1]) & (hsv[..., 1] > SKIN_MIN_S)
        before = np.median(hsv[..., 1][m])
        hsv[..., 1] = np.where(m, hsv[..., 1] + SKIN_DS, hsv[..., 1])
        hsv[..., 2] = np.where(m, hsv[..., 2] + SKIN_DV, hsv[..., 2])
        _set_image(js, out, ii, _rgb(hsv))
        msg.append("%s skin texels %.0f%% S %.2f->%.2f" % (name, 100 * m.mean(), before, np.median(hsv[..., 1][m])))
    G = _image(js, b, goo_i).astype(float)
    hsv = _hsv(G)
    m = hsv[..., 1] > 0.2
    before = np.median(hsv[..., 0][m]) * 360
    hsv[..., 0] = np.where(m, (hsv[..., 0] + GOO_DH / 360.0) % 1.0, hsv[..., 0])
    _set_image(js, out, goo_i, _rgb(hsv))
    msg.append("goo texture H %.0f->%.0f" % (before, np.median(hsv[..., 0][m]) * 360))
    return "; ".join(msg)


# r21 graft: Meshy parts (decimated in Blender only) added rigid on one bone, each with its own texture (add_ball's
# path, generalised). The gauntlet fist replaces the r20 one (the LeftHand-dominant skin and liner triangles: cuff and
# fist): fitted to the old one's points (principal axes, the best of 24 turns x 12 rolls, then ICP), uniform scale by
# the mean principal extent, so the size stays within 5 % of r20. The rod stands in the pack on his left.
FIST_BONE = "LeftHand"
RIGID_TEX = 1024  # px: a grafted part's texture
CUFF_BAND = (0.06, 0.12)  # m past the wrist joint down the arm: above the first the fist part is all forearm (the
# cuff ring), past the second all hand; geo_check's hand = the LeftHand vertices, and with the
# smooth cuff on them the hand's outline was a convex block (sep 0.13 on r20 and on this fist)
FIST_GRADE = (0.6, 0.10)  # fist texture S x, V +: the turnaround gauntlet is S 0.21 (= the Meshy map), but the toon
# light adds ~0.08 S as on the skin, so unshifted it melts into the skin at game view
ROD_BASE = np.array(
    [0.20, 1.40, -0.70]
)  # m (rest pose): the rod's foot, inside the pack behind the barrels on his left
ROD_TOP = np.array(
    [0.36, 2.02, -0.74]
)  # m: its knob (about 0.45 m above the barrel tops, leaning out like the turnaround)
ROD_BONE = "Spine"  # the pack's own bone (the Meshy rig's top spine joint), so the rod never slides on the pack


def _part(path):
    """A Meshy part glb -> positions, normals, UVs, faces (all primitives) and its base colour image (RGB array)."""
    pj, pb = n.load(path)
    P, N, UV, F, off = [], [], [], [], 0
    img = None
    for mesh in pj["meshes"]:
        for p in mesh["primitives"]:
            at = p["attributes"]
            P.append(n.floats(pj, pb, at["POSITION"]))
            N.append(n.floats(pj, pb, at["NORMAL"]))
            UV.append(n.floats(pj, pb, at["TEXCOORD_0"]))
            F.append(prim_faces(pj, pb, p).astype(np.int64) + off)
            off += len(P[-1])
            if img is None:
                img = _image(pj, pb, _mat_image(pj, pj["materials"][p["material"]]["name"]))
                img = np.asarray(Image.fromarray(img).resize((RIGID_TEX, RIGID_TEX), Image.LANCZOS))
    return np.concatenate(P), np.concatenate(N), np.concatenate(UV), np.concatenate(F), img


def _turns():
    out = []
    for perm in ((0, 1, 2), (1, 2, 0), (2, 0, 1), (1, 0, 2), (0, 2, 1), (2, 1, 0)):
        for sg in ((1, 1, 1), (1, -1, -1), (-1, 1, -1), (-1, -1, 1), (-1, 1, 1), (1, -1, 1), (1, 1, -1), (-1, -1, -1)):
            m = np.zeros((3, 3))
            m[range(3), perm] = sg
            if np.linalg.det(m) > 0:
                out.append(m)
    return out


def _axes(pts):
    c = pts.mean(0)
    w, v = np.linalg.eigh(np.cov((pts - c).T))
    v = v[:, ::-1]
    if np.linalg.det(v) < 0:
        v[:, 2] *= -1
    q = (pts - c) @ v
    return c, v, q.max(0) - q.min(0)


def fit_part(src, dst, rolls=12, icp=15):
    """Similarity transform (R, s, t) putting src points on dst points: dst ~ s * src @ R.T + t."""
    cs, vs, es = _axes(src)
    cd, vd, ed = _axes(dst)
    s = float(ed.mean() / es.mean())
    tree = cKDTree(dst)
    sub = src[np.random.default_rng(0).choice(len(src), min(len(src), 3000), replace=False)]
    dsub = dst[np.random.default_rng(1).choice(len(dst), min(len(dst), 3000), replace=False)]
    best = None
    for m in _turns():
        for k in range(rolls):
            a = 2 * np.pi * k / rolls
            roll = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])
            R = vd @ roll @ m @ vs.T
            q = s * (sub - cs) @ R.T + cd
            err = tree.query(q)[0].mean() + cKDTree(q).query(dsub)[0].mean()
            if best is None or err < best[0]:
                best = (err, R)
    R, t = best[1], cd - s * cs @ best[1].T
    for _ in range(icp):
        q = s * sub @ R.T + t
        d = dst[tree.query(q)[1]]
        qc, dc = q.mean(0), d.mean(0)
        u, _, vt = np.linalg.svd((q - qc).T @ (d - dc))
        dR = (u @ vt).T
        if np.linalg.det(dR) < 0:
            u[:, -1] *= -1
            dR = (u @ vt).T
        R, t = dR @ R, dR @ (t - qc) + dc
    q = s * sub @ R.T + t
    return R, s, t, float(tree.query(q)[0].mean() + cKDTree(q).query(dsub)[0].mean())


def add_rigid(js, b, out, rig, part, R, s, t, bone, mat_name, blend=None):
    """Appends a part (from _part) as one primitive rigid on bone: positions s * P @ R.T + t, its texture at RIGID_TEX."""
    P, N, UV, F, img = part
    P = (s * P @ R.T + t).astype(np.float32)
    N = (N @ R.T).astype(np.float32)
    js["images"].append({})
    _set_image(js, out, len(js["images"]) - 1, img)
    js["textures"].append({"source": len(js["images"]) - 1})
    js["materials"].append(
        {
            "name": mat_name,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": len(js["textures"]) - 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
            },
        }
    )
    w = np.zeros((len(P), 4), np.float32)
    w[:, 0] = 1.0
    j = np.zeros((len(P), 4), np.uint16)
    j[:, 0] = rig.names.index(bone)
    if blend is not None:  # (second bone, its weight per vertex of the placed part)
        share = blend[1](P)
        w[:, 0], w[:, 1], j[:, 1] = 1.0 - share, share, rig.names.index(blend[0])
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "TEXCOORD_0": out.add_floats(UV.astype(np.float32), "VEC2"),
        "WEIGHTS_0": out.add_floats(w, "VEC4"),
    }
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {"bufferView": out.add_view(j.tobytes()), "componentType": 5123, "count": len(P), "type": "VEC4"}
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    idx = F.reshape(-1).astype(np.uint32)
    js["accessors"].append(
        {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
    )
    js["meshes"][0]["primitives"].append(
        {"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1}
    )
    return P


def _bone_faces(js, b, p, bone_i):
    import dredge_r14 as r14

    J, W = r14.joints_weights(js, b, p["attributes"])
    dom = J[np.arange(len(J)), W.argmax(1)] == bone_i
    f = prim_faces(js, b, p).astype(np.int64)
    return f, dom[f].any(1)


def swap_fist(js, b, out, rig, part_path):
    prims = js["meshes"][0]["primitives"]
    bi = rig.names.index(FIST_BONE)
    skin = [p for p in prims if js["materials"][p["material"]]["name"] == "skin-native"]
    f0, hit0 = _bone_faces(js, b, skin[0], bi)
    old = n.floats(js, b, skin[0]["attributes"]["POSITION"])[np.unique(f0[hit0])]
    part = _part(part_path)
    hsv = _hsv(part[4].astype(float))
    hsv[..., 1] *= FIST_GRADE[0]
    hsv[..., 2] += FIST_GRADE[1]
    part = part[:4] + (_rgb(hsv).astype(np.uint8),)
    R, s, t, err = fit_part(part[0], old)
    gone = 0
    for p in skin:
        f, hit = _bone_faces(js, b, p, bi)
        keep = f[~hit].astype(np.uint32).ravel()
        js["accessors"].append(
            {
                "bufferView": out.add_view(keep.tobytes()),
                "componentType": 5125,
                "count": int(keep.size),
                "type": "SCALAR",
            }
        )
        p["indices"] = len(js["accessors"]) - 1
        gone += int(hit.sum())
    wrist = rest_world(rig, FIST_BONE)[1]
    down = wrist - rest_world(rig, "LeftForeArm")[1]
    down /= np.linalg.norm(down)

    def cuff_share(
        P,
    ):  # the cuff ring rides the forearm (a gauntlet's cuff is strapped on it), the plated fist the hand
        x = np.clip(((P - wrist) @ down - CUFF_BAND[0]) / (CUFF_BAND[1] - CUFF_BAND[0]), 0, 1)
        return 1.0 - x * x * (3 - 2 * x)

    P = add_rigid(js, b, out, rig, part, R, s, t, FIST_BONE, "metal-fist", ("LeftForeArm", cuff_share))
    size_old, size_new = _axes(old)[2], _axes(P)[2]
    return "fist %s: %d tris out, %d in, fit %.3f m, size %s -> %s m (%.0f%%)" % (
        os.path.basename(os.path.dirname(part_path)),
        gone,
        len(part[3]),
        err,
        np.round(size_old, 3).tolist(),
        np.round(size_new, 3).tolist(),
        100 * (size_new.mean() / size_old.mean() - 1),
    )


def add_rod(js, b, out, rig, part_path):
    """The rod's long axis on ROD_BASE -> ROD_TOP (its knob end = the end with the wider cross-section)."""
    part = _part(part_path)
    c, v, e = _axes(part[0])
    q = (part[0] - c) @ v[:, 0]
    wide_top = (
        np.ptp(((part[0] - c) @ v)[q > 0.4 * q.max()][:, 1:], 0).mean()
        > np.ptp(((part[0] - c) @ v)[q < 0.4 * q.min()][:, 1:], 0).mean()
    )
    ax = v[:, 0] if wide_top else -v[:, 0]
    want = ROD_TOP - ROD_BASE
    s = float(np.linalg.norm(want) / e[0])
    R = dp_align(ax, want / np.linalg.norm(want))
    foot = c + ((part[0] - c) @ ax).min() * ax  # the foot end on the axis (the mean sits toward the dense knob)
    t = ROD_BASE - s * foot @ R.T
    P = add_rigid(js, b, out, rig, part, R, s, t, ROD_BONE, "leather-rod")
    return "rod %d tris, length %.2f m, top y %.2f, on %s" % (
        len(part[3]),
        np.linalg.norm(want),
        P[:, 1].max(),
        ROD_BONE,
    )


def dp_align(a, b_):
    """Rotation matrix turning unit vector a onto unit vector b_."""
    v, c = np.cross(a, b_), float(np.dot(a, b_))
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


# r21 keys: geo_check's held pairs on r20 (gauntlet and gun into the left shin in Idle/walk/run, the gauntlet at the face in
# run f12, the heels into the seat and the own thigh in run f8/f18, the goo tail through the right foot and the floor in
# crouch and run). Each rule eases one bone's keys: "rest" pulls its local rotation back toward the bind pose (the A-pose
# knee is straight) by the least share that keeps the clearance between the parts it carries and the obstacle parts at
# that key; "out" swings the bone outward (away from the body) about the hips' forward axis by the least angle that does
# (the gauntlet off the left shin in the hunched Idle; the goo chain, its tip also over TAIL_FLOOR). A point that is nearer than that in the bind pose (calf on hamstring) only may not get
# nearer than it was there less 5 mm. The shares are eased over KEY_EASE keys either side so nothing pops.
LEFT_ARM = ("LeftArm", "LeftForeArm", "LeftHand")
HEAD = ("Head", "head_end", "headfront")
TORSO = ("Hips", "Spine02", "Spine01", "Spine")
LEG_L, LEG_R = (
    ("LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"),
    ("RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"),
)
GOO_LOW = ("GooTail1", "GooTail2", "GooTail3")
KEY_RULES = (  # (clips, bone, kind, moving bones, obstacle bones, clearance m, least share kept | most degrees out)
    (("Idle", "walk", "run", "Crouch_Walk_with_Torch"), "LeftArm", "out", LEFT_ARM[1:], LEG_L + HEAD, 0.05, 15.0),
    (
        ("run", "walk", "Crouch_Walk_with_Torch"),
        "RightLeg",
        "rest",
        ("RightLeg", "RightFoot", "RightToeBase"),
        TORSO + ("LeftUpLeg", "LeftLeg", "RightUpLeg"),
        0.02,
        0.35,
    ),
    (
        ("run", "walk", "Crouch_Walk_with_Torch"),
        "LeftLeg",
        "rest",
        ("LeftLeg", "LeftFoot", "LeftToeBase"),
        TORSO + ("RightUpLeg", "RightLeg", "LeftUpLeg"),
        0.02,
        0.35,
    ),
    (
        ("Idle", "walk", "run", "Crouch_Walk_with_Torch", "Attack", "Jump_Run"),
        "GooTail1",
        "out",
        GOO_LOW,
        LEG_R + LEG_L + LEFT_ARM,
        0.03,
        35.0,
    ),
)
KEY_RULES_2 = (  # on the pass-1 keys: the run's forward arm swing (gauntlet at the face, gun on the shin) eased toward rest
    (("run",), "LeftArm", "rest", LEFT_ARM[1:], LEG_L + HEAD, 0.06, 0.3),
)
PIVOT_SKIP = 0.12  # m: moving points this near the bone's own joint are not tested (the knee meets its thigh)
TAIL_FLOOR = 0.05  # m: the goo tip never goes below this
KEY_EASE = 3  # keys either side a share eases over
SAMPLE = 1500  # points per part set


def _posed(M, V, J, W):
    out = np.zeros_like(V)
    h = np.c_[V, np.ones(len(V))]
    for k in range(4):
        out += W[:, k : k + 1] * np.einsum("nij,nj->ni", M[J[:, k]], h)[:, :3]
    return out


def _bone_points(js, b, rig, bones):
    """Vertices (all skinned prims) whose dominant joint is one of bones: rest positions, joints, weights (sampled)."""
    import dredge_r14 as r14

    ids = [rig.names.index(x) for x in bones]
    Vs, Js, Ws = [], [], []
    for p in js["meshes"][0]["primitives"]:
        if js["materials"][p["material"]].get("extras", {}).get("under"):
            continue
        P = n.floats(js, b, p["attributes"]["POSITION"])
        J, W = r14.joints_weights(js, b, p["attributes"])
        used = np.unique(prim_faces(js, b, p))
        dom = J[used, W[used].argmax(1)]
        sel = used[np.isin(dom, ids)]
        Vs.append(P[sel])
        Js.append(J[sel].astype(np.int64))
        Ws.append(W[sel])
    V, J, W = np.concatenate(Vs), np.concatenate(Js), np.concatenate(Ws)
    pick = np.random.default_rng(0).choice(len(V), min(len(V), SAMPLE), replace=False)
    return V[pick], J[pick], W[pick]


def _ease(share, worse_is_low):
    """Per-key shares spread to KEY_EASE neighbours (min for 'rest', max for 'out') then smoothed (cyclic)."""
    k = KEY_EASE
    pad = np.r_[share[-k:], share, share[:k]]
    win = np.lib.stride_tricks.sliding_window_view(pad, 2 * k + 1)
    spread = win.min(1) if worse_is_low else win.max(1)
    pad = np.r_[spread[-k:], spread, spread[:k]]
    return np.convolve(pad, np.ones(2 * k + 1) / (2 * k + 1), "valid")


def clear_keys(js, b, out, rig, rules=KEY_RULES):
    msg, writes = [], []
    for clips, bone, kind, moving, obst, clear, least in rules:
        bi = rig.names.index(bone)
        node = rig.joints[bi]
        mv, ob = _bone_points(js, b, rig, moving), _bone_points(js, b, rig, obst)
        need_d = np.minimum(clear, cKDTree(ob[0]).query(mv[0])[0] - 0.005)
        rest_q = np.array(js["nodes"][node].get("rotation", [0, 0, 0, 1]), float)
        for clip in clips:
            a = _clip(js, clip)
            ch, q = _track(js, b, a, node, "rotation")
            if ch is None:
                continue
            times = n.floats(js, b, a["samplers"][ch["sampler"]]["input"])[:, 0]
            need = np.zeros(len(times)) if kind == "out" else np.ones(len(times))
            for ti, t in enumerate(times):
                M = rig.pose(clip, t)
                W_ = M @ np.linalg.inv(rig.ibm)
                piv = W_[bi][:3, 3]
                pm, po = _posed(M, *mv), _posed(M, *ob)
                far = np.linalg.norm(pm - piv, axis=1) > PIVOT_SKIP
                tree = cKDTree(po)
                if kind == "rest":
                    par = (
                        rig.names.index(js["nodes"][rig.parent[node]]["name"])
                        if rig.parent.get(node) in rig.joints
                        else None
                    )
                    pr = W_[par][:3, :3] / np.linalg.norm(W_[par][:3, :3], axis=0) if par is not None else np.eye(3)
                    cur = pr @ quat_mat_(q[ti])
                    for keep in np.linspace(1.0, least, 17):
                        new = pr @ quat_mat_(slerp_to(q[ti : ti + 1], rest_q, keep)[0])
                        d = new @ cur.T
                        pts = (pm[far] - piv) @ d.T + piv
                        if (tree.query(pts)[0] >= need_d[far]).all():
                            break
                    need[ti] = keep
                else:
                    hips = W_[rig.names.index("Hips")]
                    fwd = hips[:3, 2] / np.linalg.norm(hips[:3, 2])
                    side = hips[:3, 0] / np.linalg.norm(hips[:3, 0])
                    away = np.sign((pm.mean(0) - hips[:3, 3]) @ side)  # the goo's side of the body
                    for ang in np.radians(np.arange(0, least + 0.1, 2.5)):
                        best = None
                        for sg in (1.0, -1.0):
                            pts = (pm - piv) @ axis_turn(fwd, sg * ang).T + piv
                            reach = away * ((pts.mean(0) - hips[:3, 3]) @ side)
                            if best is None or reach > best[0]:
                                best = (reach, sg, pts)
                        if (tree.query(best[2])[0] >= need_d).all() and best[2][:, 1].min() >= TAIL_FLOOR:
                            break
                    need[ti] = np.degrees(ang) * best[1]
            if kind == "rest":
                share = _ease(need, True)
                vals = np.array([slerp_to(q[i : i + 1], rest_q, share[i])[0] for i in range(len(q))])
                msg.append("%s %s least %.2f" % (clip, bone, share.min()))
            else:
                mag = _ease(np.abs(need), False)
                sg = np.sign(need[np.argmax(np.abs(need))]) if np.abs(need).max() > 0 else 1.0
                vals = []
                for i in range(len(q)):
                    M = rig.pose(clip, times[i])
                    W_ = M @ np.linalg.inv(rig.ibm)
                    par = rig.names.index(js["nodes"][rig.parent[node]]["name"])
                    pr = W_[par][:3, :3] / np.linalg.norm(W_[par][:3, :3], axis=0)
                    hips = W_[rig.names.index("Hips")][:3, :3]
                    fwd = hips[:, 2] / np.linalg.norm(hips[:, 2])
                    loc = pr.T @ axis_turn(fwd, sg * np.radians(mag[i])) @ pr @ quat_mat_(q[i])
                    vals.append(mat_quat(loc))
                vals = np.array(vals)
                msg.append("%s %s out max %.1f deg" % (clip, bone, mag.max()))
            writes.append((a["samplers"][ch["sampler"]], vals))
    for sm, vals in writes:  # after every rule has posed the source keys
        sm["output"] = out.add_floats(vals, "VEC4")
    return "; ".join(msg)


def quat_mat_(q):
    return rs.quat_mat(q)


_DT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def drop_unused(js, b, out, rig):
    """r21: every primitive keeps only the vertices its triangles use. The r18 goo swap and the r20 dome left the old fat
    goo's ~80k vertices in the shared body buffer (weighted to GooTail*, no triangles): geo_check samples a part's
    vertices, so they showed as 'outfit:tail' clipping 16 cm through the right foot that nothing in the game draws."""
    before = after = 0
    for p in js["meshes"][0]["primitives"]:
        f = prim_faces(js, b, p).astype(np.int64)
        used, inv = np.unique(f, return_inverse=True)
        before += js["accessors"][p["attributes"]["POSITION"]]["count"]
        after += len(used)
        attrs = {}
        for k, ai in p["attributes"].items():
            a = js["accessors"][ai]
            raw = n.view_bytes(js, b, a["bufferView"])
            arr = np.frombuffer(raw, _DT[a["componentType"]], a["count"] * _NC[a["type"]], a.get("byteOffset", 0))
            arr = np.ascontiguousarray(arr.reshape(a["count"], _NC[a["type"]])[used])
            new = {kk: v for kk, v in a.items() if kk in ("componentType", "type", "normalized")}
            new.update(bufferView=out.add_view(arr.tobytes()), count=len(used))
            if k == "POSITION":
                new.update(min=arr.min(0).tolist(), max=arr.max(0).tolist())
            js["accessors"].append(new)
            attrs[k] = len(js["accessors"]) - 1
        p["attributes"] = attrs
        idx = inv.reshape(-1).astype(np.uint32)
        js["accessors"].append(
            {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
        )
        p["indices"] = len(js["accessors"]) - 1
    return "vertices %d -> %d (unreferenced ones dropped)" % (before, after)


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
    print(
        f"right foot: {foot[0]} tris replaced by {foot[1]} mirrored (shift {foot[2]} m, {foot[3]} rim vertices "
        f"welded, largest move {foot[4]} m)"
    )
    print(
        f"heel crescent {blade} tris ({holes} holes filled), {gone[0]} islands ({gone[1]} tris), "
        f"chain at {np.round(ys, 2).tolist()}"
    )
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
    elif (
        sys.argv[1] == "--r17"
    ):  # r17 (on an r16 file): goo arm hangs at its bind abduction, chain hangs, tail baked again
        rebuild_stages(sys.argv[2], sys.argv[3], [("goo arm", hang_goo_arm), ("tail gather", hang_tail)])
    elif (
        sys.argv[1] == "--r18"
    ):  # r18: the slim Meshy goo arm swapped in (argv: OUT IN ARM.glb); the chain's clips stay
        rebuild_stages(
            sys.argv[2],
            sys.argv[3],
            [("goo arm swap", lambda js, b, out, rig: swap_goo_arm(js, b, out, rig, sys.argv[4]))],
        )
    elif sys.argv[1] == "--r19":  # r19: r18 glb: socket dome skin UVs, strap lift, under layer cut (argv: OUT IN)
        rebuild_stages(
            sys.argv[2],
            sys.argv[3],
            [("socket skin", skin_socket), ("strap lift", lift_strap), ("under layer", drop_under)],
        )
    elif sys.argv[1] == "--r20":  # r20: r19b glb: right strap = mirrored left strap on the right skin (argv: OUT IN)
        rebuild_stages(sys.argv[2], sys.argv[3], [("socket reshape", reshape_socket), ("strap mirror", mirror_strap)])
    elif (
        sys.argv[1] == "--r21"
    ):  # r21: r20 glb: stray ball copy, strap UVs/weights, dome + skin/goo grade (argv: OUT IN)
        rebuild_stages(
            sys.argv[2],
            sys.argv[3],
            [
                ("ball copy", drop_ball_copy),
                ("unused vertices", drop_unused),
                ("strap", strap_r21),
                ("grade", grade_r21),
            ],
        )
    elif sys.argv[1] == "--r21-keys":  # r21: keys eased off the held clip pairs (argv: OUT IN)
        rebuild_stages(
            sys.argv[2],
            sys.argv[3],
            [("keys", clear_keys), ("keys 2", lambda js, b, out, rig: clear_keys(js, b, out, rig, KEY_RULES_2))],
        )
    elif sys.argv[1] == "--r21-graft":  # r21: the Meshy gauntlet fist and rod (argv: OUT IN FIST.glb ROD.glb)
        rebuild_stages(
            sys.argv[2],
            sys.argv[3],
            [
                ("fist", lambda js, b, out, rig: swap_fist(js, b, out, rig, sys.argv[4])),
                ("rod", lambda js, b, out, rig: add_rod(js, b, out, rig, sys.argv[5])),
                ("unused vertices", drop_unused),
            ],
        )
    elif sys.argv[1] == "--r12":  # the r12 stage on the r11 glb (re-runnable)
        rebuild_stages(sys.argv[2], sys.argv[3], [("tail gather", gather_tail)])
    elif sys.argv[1] == "--r11":
        rebuild_r11(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    else:
        build(sys.argv[1], sys.argv[2])
