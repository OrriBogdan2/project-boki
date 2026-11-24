"""Grimble (dredge) native model, round 22 stages on the r21 glb (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md).

  dredge_r22.py --strap OUT IN          strap rebuilt as one closed band per side, shoulder blade to belt, on the skin
  dredge_r22.py --slivers OUT IN        the long thin skin slivers (the ear/shoulder strand web) dropped
  dredge_r22.py --goo OUT IN            the goo arm root flared over the shoulder socket, the arm a little thicker
  dredge_r22.py --dome OUT IN           the socket dome's head weights moved to the shoulder (strand web)
  dredge_r22.py --dometex OUT IN        r23: the socket dome repainted from the nearby skin (its streaked bake = strand web)
  dredge_r22.py --posts OUT IN POST.glb  r23: the knob rod replaced by two hooked posts (bell, chain, lantern), one per side
  dredge_r22.py --loinpart OUT.glb IN   r24: the loincloth faces (atlas colour mask) cut out as a static glb for Meshy
  dredge_r22.py --loincloth OUT IN TEX  r24: a Meshy retexture of that part composited into the atlas inside the mask
  dredge_r22.py --horns OUT IN HORN.glb r24: the 2D's cream crescent horns along the goo arm (one Meshy part, rigid)
  dredge_r22.py --nodome OUT IN         variant: the socket dome removed
  dredge_r22.py --all OUT IN            every r22 stage in order

Every stage takes IN.glb and writes OUT.glb (dredge_post.rebuild_stages). numpy/scipy/PIL only.
"""

import sys

import dredge_post as d
import dredge_r14 as r14
import dredge_reskin as rs
import native_pack as n
import numpy as np
from scipy.spatial import cKDTree

STRAP_SIDES = (0.165, -0.165)  # m: strap centre plane x (gauntlet side first); r21 straps sat at +-0.17
STRAP_HALF = 0.026  # m: half the band width (2D: about the belt's height)
STRAP_TOP, STRAP_BOT = 0.010, 0.003  # m: band top / underside above the skin (closed slab: no open edge for the ink)
STRAP_KEEP_Y = 1.45  # r21 rows above this y (shoulder blade, shoulder top, upper chest) give the path; below: redone
STRAP_END_Y = 1.10  # m: the band ends on the belt (atlas belt band at x 0.15: y 0.97-1.19)
FRONT_DZ = 0.03  # m: a front station may sit at most this much ahead of the one above it
STRAP_STEP = 0.015  # m: station spacing along the band
STRAP_K = 8  # skin vertices whose weights a band vertex copies (inverse-distance)
STRAP_TEX = (64, 1024)  # px: u across, v along the whole band (no tiling)
BELT_BOX = ((0.06, 0.30), (0.98, 1.16))  # x, y of the atlas belt texels the leather colour is taken from
LOOK_DESAT = (0.48, 0.2)  # warden_look dredge: skin-native slot (the belt) vs strap-leather slot desat
LOOK_ALBEDO = 0.88  # skin-native slot albedo (strap-leather slot has 1.0)
SURF_MATS = ("skin-native", "skin-native-dome")
SLIVER_LEN, SLIVER_H, SLIVER_Y = 0.08, 0.01, 1.30  # m: skin faces longer than LEN and thinner than H above Y go


def _surface(js, b):
    """Skin + socket dome: face centroids, unit face normals, vertex ids, positions and dense weights."""
    prims = js["meshes"][0]["primitives"]
    C, N, P, Wd = [], [], [], []
    nb = len(js["skins"][0]["joints"])
    for p in prims:
        if js["materials"][p["material"]]["name"] not in SURF_MATS:
            continue
        if js["materials"][p["material"]].get("extras", {}).get("under"):
            continue
        V = n.floats(js, b, p["attributes"]["POSITION"])
        f = d.prim_faces(js, b, p)
        T = V[f]
        nr = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
        nr /= np.linalg.norm(nr, axis=1, keepdims=True) + 1e-12
        C.append(T.mean(1))
        N.append(nr)
        used = np.unique(f)
        J, W = r14.joints_weights(js, b, p["attributes"])
        P.append(V[used])
        Wd.append(rs.dense(J[used], W[used], nb))
    return np.concatenate(C), np.concatenate(N), np.concatenate(P), np.concatenate(Wd)


def _snap(pts, tree, C, N, k=6):
    """Nearest skin point (plane of the nearest faces) and its outward normal."""
    _, ii = tree.query(pts, k=k)
    nr = N[ii].mean(1)
    nr /= np.linalg.norm(nr, axis=1, keepdims=True) + 1e-12
    c0 = C[ii[:, 0]]
    n0 = N[ii[:, 0]]
    on = pts - ((pts - c0) * n0).sum(1, keepdims=True) * n0
    return on, nr


def _path(js, b, x, tree, C, N):
    """Centre line of one band: the r21 strap's rows above STRAP_KEEP_Y (shoulder blade over the shoulder), then the
    front-most skin point in the plane x down to the belt."""
    prims = js["meshes"][0]["primitives"]
    st = next(p for p in prims if js["materials"][p["material"]]["name"] == "strap-leather")
    S = n.floats(js, b, st["attributes"]["POSITION"])
    rows = S.reshape(-1, d.STRAP_ACROSS, 3).mean(1)
    rows = rows[np.sign(rows[:, 0]) == np.sign(x)]
    top = rows[rows[:, 1] >= STRAP_KEEP_Y]
    # (r21 rows are already in path order: shoulder blade, shoulder top, chest)
    top[:, 0] = x
    sel = np.abs(C[:, 0] - x) < 0.012
    front, z = [], top[-1, 2]
    for y in np.arange(top[-1, 1] - 0.03, STRAP_END_Y - 1e-6, -0.02):
        # (the hunched head hangs in front of the chest at this x: only skin within FRONT_DZ of the last station)
        m = sel & (np.abs(C[:, 1] - y) < 0.012) & (N[:, 2] > 0.1) & (C[:, 2] < z + FRONT_DZ)
        if m.any():
            z = C[m, 2].max()
            front.append((x, y, z))
    pts = np.vstack([top, np.array(front)])
    # even stations, smoothed
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    s = np.arange(0, seg[-1], STRAP_STEP)
    pts = np.stack([np.interp(s, seg, pts[:, a]) for a in range(3)], 1)
    for _ in range(4):
        pts[1:-1] = 0.25 * pts[:-2] + 0.5 * pts[1:-1] + 0.25 * pts[2:]
    on, _ = _snap(pts, tree, C, N)
    on[:, 0] = x
    return on


def _leather(js, b):
    """Band texture: the atlas belt's leather colour pre-graded for the strap slot (so it renders like the belt), grain
    from the belt texels, darker edges and stitch dashes like the 2D strap."""
    prims = js["meshes"][0]["primitives"]
    p = prims[0]
    V = n.floats(js, b, p["attributes"]["POSITION"])
    UV = n.floats(js, b, p["attributes"]["TEXCOORD_0"])
    f = d.prim_faces(js, b, p)
    ii = js["textures"][js["materials"][p["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    atlas = d._image(js, b, ii)[..., :3].astype(np.float32)
    H, W = atlas.shape[:2]
    c = V[f].mean(1)
    (x0, x1), (y0, y1) = BELT_BOX
    m = (np.abs(c[:, 0]) > x0) & (np.abs(c[:, 0]) < x1) & (c[:, 1] > y0) & (c[:, 1] < y1)
    uv = UV[f[m]].mean(1)
    px = atlas[(uv[:, 1] * H).astype(int) % H, (uv[:, 0] * W).astype(int) % W]
    lum = px.mean(1)
    belt = px[lum < np.percentile(lum, 40)]
    col = np.median(belt, 0)
    L = col.mean()
    keep = (1.0 - LOOK_DESAT[0]) / (1.0 - LOOK_DESAT[1])
    col = (L + (col - L) * keep) * LOOK_ALBEDO
    w, h = STRAP_TEX
    rng = np.random.default_rng(22)
    grain = rng.normal(0, 1, (h // 8, w // 4))
    grain = np.kron(grain, np.ones((8, 4)))
    from scipy import ndimage

    grain = ndimage.gaussian_filter(grain, (6, 1.2))
    img = col[None, None, :] * (1.0 + 0.10 * grain[..., None] / (grain.std() + 1e-6))
    u = (np.arange(w) + 0.5) / w
    edge = np.clip(1.0 - np.minimum(u, 1 - u) / 0.08, 0, 1)
    img *= (1.0 - 0.45 * edge)[None, :, None]
    stitch = (np.abs(np.minimum(u, 1 - u) - 0.15) < 0.025)[None, :] & ((np.arange(h) // 6) % 2 == 0)[:, None]
    img[stitch] = img[stitch] * 1.45 + 12
    return np.clip(img, 0, 255).astype(np.uint8), col


def _band(on, nr):
    """Tangent and across-band axes of the stations (the slab: top, outer side, underside, inner side, 2 caps)."""
    T = np.gradient(on, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    B = np.cross(nr, T)
    B /= np.linalg.norm(B, axis=1, keepdims=True)
    return T, B


def strap_r22(js, b, out, rig):
    """r22: the r21 strap (36 rows x 3, lower rows 5.6-8.3 cm off the chest = the black tab, grey bands) is replaced by
    one closed leather band per side from the shoulder blade (under the pack) over the shoulder to the belt, each vertex
    snapped to the skin at STRAP_TOP / STRAP_BOT and skinned with the weights of the skin under it."""
    prims = js["meshes"][0]["primitives"]
    si = next(i for i, p in enumerate(prims) if js["materials"][p["material"]]["name"] == "strap-leather")
    mat = prims[si]["material"]
    C, N, SP, SW = _surface(js, b)
    tree = cKDTree(C)
    vtree = cKDTree(SP)
    Ps, Ns, UVs, Fs, nv = [], [], [], [], 0
    gaps = []
    for x in STRAP_SIDES:
        on = _path(js, b, x, tree, C, N)
        _, nr = _snap(on, tree, C, N, k=12)
        T, B = _band(on, nr)
        ns = len(on)
        v = np.linspace(0.0, 1.0, ns)
        rings = {}
        corners = (("tl", -1, STRAP_TOP), ("tr", 1, STRAP_TOP), ("bl", -1, STRAP_BOT), ("br", 1, STRAP_BOT))
        for name, side, lift in corners:
            q, qn = _snap(on + side * STRAP_HALF * B, tree, C, N, k=12)
            rings[name] = q + qn * lift
        quads = (  # (a, b, normal, u a, u b)
            ("tl", "tr", nr, 0.0, 1.0),
            ("tr", "br", B, 1.0, 1.0),
            ("br", "bl", -nr, 1.0, 0.0),
            ("bl", "tl", -B, 0.0, 0.0),
        )
        for a, c, nn, ua, uc in quads:
            Ps += [rings[a], rings[c]]
            Ns += [nn, nn]
            UVs += [np.c_[np.full(ns, ua), v], np.c_[np.full(ns, uc), v]]
            i = np.arange(ns - 1) + nv
            j = i + ns
            Fs.append(np.c_[i, i + 1, j])
            Fs.append(np.c_[j, i + 1, j + 1])
            nv += 2 * ns
        for e, sgn in ((0, -1), (ns - 1, 1)):  # caps
            cap = np.array([rings["tl"][e], rings["tr"][e], rings["br"][e], rings["bl"][e]])
            Ps.append(cap)
            Ns.append(np.repeat((sgn * T[e])[None], 4, 0))
            UVs.append(np.array([[0, v[e]], [1, v[e]], [1, v[e]], [0, v[e]]]))
            fan = [[0, 2, 1], [0, 3, 2]] if sgn > 0 else [[0, 1, 2], [0, 2, 3]]
            Fs.append(np.array(fan) + nv)
            nv += 4
        gaps.append(np.linalg.norm(rings["bl"] - on, axis=1).max())
    P = np.vstack(Ps).astype(np.float32)
    NR = np.vstack(Ns).astype(np.float32)
    UV = np.vstack(UVs).astype(np.float32)
    F = np.vstack(Fs).astype(np.uint32)
    # outward winding: flip faces whose geometric normal disagrees with the vertex normal
    g = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    bad = (g * NR[F].mean(1)).sum(1) < 0
    F[bad] = F[bad][:, ::-1]
    dist, ii = vtree.query(P, k=STRAP_K)
    w = 1.0 / np.maximum(dist, 1e-4)
    dense = (SW[ii] * w[..., None]).sum(1) / w.sum(1, keepdims=True)
    jn, wt = rs.top4(dense)
    img, col = _leather(js, b)
    ti = js["materials"][mat]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    js["images"].append({})
    d._set_image(js, out, len(js["images"]) - 1, img)
    tex = {"source": len(js["images"]) - 1}
    if "sampler" in js["textures"][ti]:
        tex["sampler"] = js["textures"][ti]["sampler"]
    js["textures"].append(tex)
    js["materials"][mat]["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(js["textures"]) - 1}
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(NR, "VEC3"),
        "TEXCOORD_0": out.add_floats(UV, "VEC2"),
        "WEIGHTS_0": out.add_floats(wt.astype(np.float32), "VEC4"),
    }
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(P),
            "type": "VEC4",
        },
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    idx = F.reshape(-1)
    js["accessors"].append(
        {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
    )
    prims[si] = {"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": mat}
    return "strap: %d verts %d tris, belt colour %s, centre-line snap max %.4f m" % (
        len(P),
        len(F),
        np.round(col).astype(int).tolist(),
        max(gaps),
    )


def drop_slivers(js, b, out, rig):
    """r22: skin faces longer than SLIVER_LEN and thinner than SLIVER_H above SLIVER_Y (ear/earring to shoulder: the
    review's strand web) are dropped from the index list."""
    prims = js["meshes"][0]["primitives"]
    gone = 0
    for p in prims:
        if js["materials"][p["material"]]["name"] not in SURF_MATS:
            continue
        V = n.floats(js, b, p["attributes"]["POSITION"])
        f = d.prim_faces(js, b, p)
        T = V[f]
        e = np.stack([np.linalg.norm(T[:, a] - T[:, (a + 1) % 3], axis=1) for a in range(3)], 1)
        area = 0.5 * np.linalg.norm(np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]), axis=1)
        L = e.max(1)
        bad = (L > SLIVER_LEN) & (2 * area / np.maximum(L, 1e-9) < SLIVER_H) & (T[:, :, 1].min(1) > SLIVER_Y)
        if not bad.any():
            continue
        idx = f[~bad].reshape(-1).astype(np.uint32)
        js["accessors"].append(
            {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
        )
        p["indices"] = len(js["accessors"]) - 1
        gone += int(bad.sum())
    return "slivers dropped: %d" % gone


GOO_FLARE = (1.30, 1.62, 0.38)  # y from, y to, extra radius share at the top (the goo root widens over the socket)
GOO_THICK = (1.00, 0.10)  # y above which the whole goo arm gets this extra radius share (review: "thin tube")


def flare_goo(js, b, out, rig):
    """r22: the slim r18 goo arm met the socket dome with a blunt cap (review: arm root plugged on torn skin). Each
    vertex moves away from its 2 cm slice's centre (x/z plane): + GOO_THICK above its y, + up to GOO_FLARE[2] towards
    the root top, so the root covers the dome edge. Weights unchanged."""
    prims = js["meshes"][0]["primitives"]
    g = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-goo")
    V = n.floats(js, b, g["attributes"]["POSITION"]).copy()
    u = np.unique(d.prim_faces(js, b, g))
    G = V[u]
    edges = np.arange(G[:, 1].min(), G[:, 1].max() + 0.02, 0.02)
    k = np.clip(np.digitize(G[:, 1], edges) - 1, 0, len(edges) - 1)
    cen = np.zeros((len(edges), 2))
    for i in range(len(edges)):
        m = k == i
        cen[i] = G[m][:, [0, 2]].mean(0) if m.any() else np.nan
    ok = ~np.isnan(cen[:, 0])
    mid = edges + 0.01
    cx = np.interp(G[:, 1], mid[ok], cen[ok, 0])
    cz = np.interp(G[:, 1], mid[ok], cen[ok, 1])
    y0, y1, top = GOO_FLARE
    share = np.where(G[:, 1] > GOO_THICK[0], GOO_THICK[1], 0.0) + top * np.clip((G[:, 1] - y0) / (y1 - y0), 0, 1) ** 1.5
    G[:, 0] = cx + (G[:, 0] - cx) * (1 + share)
    G[:, 2] = cz + (G[:, 2] - cz) * (1 + share)
    V[u] = G
    a = out.add_floats(V.astype(np.float32), "VEC3")
    js["accessors"][a].update(min=V.min(0).tolist(), max=V.max(0).tolist())
    old = g["attributes"]["POSITION"]
    for p in prims:  # (prims sharing the goo's vertex array follow it)
        if p["attributes"].get("POSITION") == old:
            p["attributes"]["POSITION"] = a
    return "goo flare: %d verts, share %.2f-%.2f" % (len(u), share.min(), share.max())


def drop_dome(js, b, out, rig):
    """r22 variant (rejected: it opens black holes at the socket, r22b renders): the r11/r20 socket dome removed."""
    prims = js["meshes"][0]["primitives"]
    keep = [p for p in prims if js["materials"][p["material"]]["name"] != "skin-native-dome"]
    gone = len(prims) - len(keep)
    js["meshes"][0]["primitives"] = keep
    d.prune_materials(js)
    return "dome prims dropped: %d" % gone


DOME_HEAD = ("neck", "Head", "head_end", "headfront")  # bones whose dome weight moves to DOME_TO
DOME_TO = "RightShoulder"


def dome_weights(js, b, out, rig):
    """r22: the socket dome (a goo-side shoulder cover) carried 30 %% head weight (headfront 239, Head 58 of 1279
    vertex-weight units), so head turns dragged the shoulder cover with the head. Head weights move to
    RightShoulder. (The review's earring-to-shoulder strand web did NOT change with this: r22c renders; still open.)"""
    prims = js["meshes"][0]["primitives"]
    g = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-native-dome")
    J, W = r14.joints_weights(js, b, g["attributes"])
    dense = rs.dense(J, W, len(rig.names))
    head = [rig.names.index(x) for x in DOME_HEAD if x in rig.names]
    moved = dense[:, head].sum(1)
    dense[:, rig.names.index(DOME_TO)] += moved
    dense[:, head] = 0.0
    jn, wt = rs.top4(dense / dense.sum(1, keepdims=True))
    g["attributes"]["WEIGHTS_0"] = out.add_floats(wt.astype(np.float32), "VEC4")
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(jn),
            "type": "VEC4",
        },
    )
    g["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
    return "dome: %.1f head weight units moved to %s (%d vertices)" % (moved.sum(), DOME_TO, int((moved > 0).sum()))


DOME_K = 32  # skin faces whose colour a dome vertex takes (inverse-distance)
DOME_TONE = 26.0  # RGB distance from the shoulder's median skin colour above which a skin face is not used (socket,
# strap, earring and goo texels)
DOME_TEX = 512  # px
DOME_GRAIN = 3.0  # grain amplitude, 8-bit levels


def dome_texture(js, b, out, rig):
    """r23: the socket dome's own 512 px texture is a projection bake whose edges smear into radial streaks, with strap
    and earring texels baked in: at game view these read as the dark strands from the earring to the shoulder (review
    T1 STRAND WEB; r22's weight move did not change them). The dome gets a new texture: each vertex takes the colour
    of its nearest skin-tone faces of the main skin atlas, painted across the dome's UVs (barycentric), gaps filled
    from the nearest texel, softened, with a soft grain. Geometry and weights unchanged."""
    from scipy import ndimage

    prims = js["meshes"][0]["primitives"]
    sk = prims[0]
    dm = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-native-dome")
    SV = n.floats(js, b, sk["attributes"]["POSITION"])
    SU = n.floats(js, b, sk["attributes"]["TEXCOORD_0"])
    sf = d.prim_faces(js, b, sk)
    ti = js["materials"][sk["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    atlas = d._image(js, b, js["textures"][ti]["source"])[..., :3].astype(np.float32)
    H, W = atlas.shape[:2]
    cen = SV[sf].mean(1)
    uv = SU[sf].mean(1)
    col = atlas[(uv[:, 1] * H).astype(int) % H, (uv[:, 0] * W).astype(int) % W]
    DV = n.floats(js, b, dm["attributes"]["POSITION"])
    DU = n.floats(js, b, dm["attributes"]["TEXCOORD_0"])
    df = d.prim_faces(js, b, dm)
    u = np.unique(df)
    lo, hi = DV[u].min(0) - 0.12, DV[u].max(0) + 0.12
    near = np.all((cen > lo) & (cen < hi), axis=1)
    med = np.median(col[near], 0)
    ok = near & (np.linalg.norm(col - med, axis=1) < DOME_TONE)
    dist, idx = cKDTree(cen[ok]).query(DV[u], k=DOME_K)
    w = 1.0 / np.maximum(dist, 0.004)
    vc = np.zeros((len(DV), 3), np.float32)
    vc[u] = (col[ok][idx] * w[..., None]).sum(1) / w.sum(1, keepdims=True)
    S = DOME_TEX
    img = np.zeros((S, S, 3), np.float32)
    have = np.zeros((S, S), bool)
    P = DU * S - 0.5
    for t in df:
        a, bb, c = P[t]
        x0, y0 = np.floor(np.minimum(np.minimum(a, bb), c)).astype(int)
        x1, y1 = np.ceil(np.maximum(np.maximum(a, bb), c)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, S - 1), min(y1, S - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        den = (bb[1] - c[1]) * (a[0] - c[0]) + (c[0] - bb[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        l1 = ((bb[1] - c[1]) * (gx - c[0]) + (c[0] - bb[0]) * (gy - c[1])) / den
        l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        l3 = 1 - l1 - l2
        m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        img[gy[m], gx[m]] = l1[m, None] * vc[t[0]] + l2[m, None] * vc[t[1]] + l3[m, None] * vc[t[2]]
        have[gy[m], gx[m]] = True
    _, (iy, ix) = ndimage.distance_transform_edt(~have, return_indices=True)
    img = ndimage.gaussian_filter(img[iy, ix], (3, 3, 0))
    g = ndimage.gaussian_filter(np.random.default_rng(23).normal(0, 1, (S, S)), 1.5)  # soft skin grain (no tiling)
    img += (DOME_GRAIN * g / g.std())[..., None]
    ii = js["textures"][js["materials"][dm["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    d._set_image(js, out, ii, np.clip(img, 0, 255).astype(np.uint8))
    return "dome texture: %d skin faces sampled (median %s), %d of %d texels painted" % (
        int(ok.sum()),
        med.round().astype(int).tolist(),
        int(have.sum()),
        S * S,
    )


# r23 posts: the 2D pack carries two hooked posts (spike top, crossbar with a bell, chain to a lantern), one each side;
# r21 had one knobbed pole on his left. Both posts are the same Meshy part, the goo-side one mirrored.
POSTS = (  # (foot, top) in rest pose, m; the gauntlet side is the r21 rod's line (dredge_post.ROD_BASE/ROD_TOP)
    (np.array([0.20, 1.36, -0.70]), np.array([0.34, 2.06, -0.75])),
    (np.array([-0.20, 1.36, -0.70]), np.array([-0.34, 2.06, -0.75])),
)
POST_GRADE = (0.55, 0.78)  # post texture S x, V x (the toon light adds saturation: ungraded, the Meshy copper
# reads as hot orange at game view next to the dark-brown pack); lantern glass texels (bright yellow) keep theirs
POST_OUT = 0.35  # z share of the crossbar's direction pointing back (the rest points out along x)


def _frame(up, h):
    up = up / np.linalg.norm(up)
    h = h - up * (h @ up)
    h /= np.linalg.norm(h)
    return np.stack([up, h, np.cross(up, h)], 1)


def _grade_post(img):
    from PIL import Image

    hsv = np.asarray(Image.fromarray(img.astype(np.uint8)).convert("HSV")).astype(np.float32)
    glow = (hsv[..., 2] > 215) & (hsv[..., 0] > 22) & (hsv[..., 0] < 50)  # PIL hue 0-255: yellow ~ 30-45
    g = hsv.copy()
    g[..., 1] = np.where(glow, hsv[..., 1], hsv[..., 1] * POST_GRADE[0])
    g[..., 2] = np.where(glow, hsv[..., 2], hsv[..., 2] * POST_GRADE[1])
    return np.asarray(Image.fromarray(np.clip(g, 0, 255).astype(np.uint8), "HSV").convert("RGB"))


def posts(js, b, out, rig, part_path):
    """r23: the r21 knob rod (leather-rod) is replaced by two Meshy hooked posts rigid on the pack's bone. The part's
    up is glTF +y; its crossbar side = the horizontal offset of the upper half's centroid from the foot's; that side
    points outward (and a little back) on each side; scale = foot-to-top length / the part's height."""
    prims = js["meshes"][0]["primitives"]
    js["meshes"][0]["primitives"] = [p for p in prims if js["materials"][p["material"]]["name"] != "leather-rod"]
    d.prune_materials(js)
    P, N, UV, F, img = d._part(part_path)
    img = _grade_post(img)
    y0, y1 = P[:, 1].min(), P[:, 1].max()
    foot = P[P[:, 1] < y0 + 0.15 * (y1 - y0)].mean(0)
    upper = P[P[:, 1] > y0 + 0.5 * (y1 - y0)].mean(0)
    h = upper - foot
    h[1] = 0.0
    M = _frame(np.array([0.0, 1.0, 0.0]), h)
    foot[1] = y0
    msg = []
    for k, (a, top) in enumerate(POSTS):
        side = np.sign(a[0])
        T = _frame(top - a, np.array([side, 0.0, -POST_OUT]))
        R = T @ M.T
        sc = float(np.linalg.norm(top - a) / (y1 - y0))
        Q, Nq, Fq = P, N, F
        if side < 0:  # mirrored copy: x flipped after placing (a reflection), winding flipped
            R = (
                np.diag([-1.0, 1.0, 1.0])
                @ _frame(top * [-1, 1, 1] - a * [-1, 1, 1], np.array([1.0, 0, -POST_OUT]))
                @ M.T
            )
            Fq = F[:, ::-1]
        t = a - sc * foot @ R.T
        Pp = d.add_rigid(js, b, out, rig, (Q, Nq, UV, Fq, img), R, sc, t, d.ROD_BONE, "leather-rod")
        msg.append(
            "post %d: %d tris, top y %.2f, x %.2f..%.2f" % (k, len(F), Pp[:, 1].max(), Pp[:, 0].min(), Pp[:, 0].max())
        )
    return "; ".join(msg)


# r24 loincloth: the 2D cloth is brown leather; the r21 model's is skin-native atlas texels (H 333 S 0.36 V 0.53, thigh
# skin H 322 S 0.30 V 0.71). Faces are picked by colour inside the hip band, then the pick is smoothed over neighbours.
LOIN_BAND = (0.50, 0.98, 0.36)  # m: y from, y to (under the belt), |x| max
LOIN_HUE, LOIN_V = (327.0, 40.0), 0.62  # deg: hue above the first or below the second; value under LOIN_V


def _loin_faces(js, b):
    """Per skin-native primitive: (index, faces, picked mask)."""
    from PIL import Image

    img = d._image(js, b, 0)[..., :3]
    H, W = img.shape[:2]
    hsv = np.asarray(Image.fromarray(img).convert("HSV")).astype(np.float32)
    res = []
    for pi, p in enumerate(js["meshes"][0]["primitives"]):
        if js["materials"][p["material"]]["name"] != "skin-native":
            continue
        P = n.floats(js, b, p["attributes"]["POSITION"])
        U = n.floats(js, b, p["attributes"]["TEXCOORD_0"])
        f = d.prim_faces(js, b, p)
        c = P[f].mean(1)
        votes = np.zeros(len(f))
        for w in ((1 / 3, 1 / 3, 1 / 3), (0.6, 0.2, 0.2), (0.2, 0.6, 0.2), (0.2, 0.2, 0.6)):
            uv = np.einsum("j,fjk->fk", np.array(w), U[f])
            hv = hsv[(uv[:, 1] * H).astype(int) % H, (uv[:, 0] * W).astype(int) % W]
            hd, v = hv[:, 0] * 360 / 255, hv[:, 2] / 255
            votes += ((hd > LOIN_HUE[0]) | (hd < LOIN_HUE[1])) & (v < LOIN_V)
        band = (c[:, 1] > LOIN_BAND[0]) & (c[:, 1] < LOIN_BAND[1]) & (np.abs(c[:, 0]) < LOIN_BAND[2])
        sel = band & (votes >= 2)
        key = np.round(P / 0.002).astype(np.int64)  # weld UV-seam copies for the neighbour vote
        _, wid = np.unique(key, axis=0, return_inverse=True)
        wf = wid.ravel()[f]
        for _ in range(2):
            vs = np.zeros(wid.max() + 1)
            vc = np.zeros(wid.max() + 1)
            np.add.at(vs, wf.ravel(), np.repeat(sel, 3))
            np.add.at(vc, wf.ravel(), 1)
            share = (vs / np.maximum(vc, 1))[wf].mean(1)
            sel = band & ((sel & (share > 0.3)) | (~sel & (share > 0.65)))
        res.append((pi, f, sel, P, U))
    return res


def _write_glb(path, P, N, UV, F, img):
    import io
    import json
    import struct

    from PIL import Image

    buf = io.BytesIO()
    Image.fromarray(img).save(buf, "PNG")
    png = buf.getvalue()
    parts = [P.astype(np.float32).tobytes(), N.astype(np.float32).tobytes(), UV.astype(np.float32).tobytes()]
    parts += [F.astype(np.uint32).ravel().tobytes(), png]
    views, off = [], 0
    for k, raw in enumerate(parts):
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(raw)})
        off += (len(raw) + 3) // 4 * 4
    binb = b"".join(r + b"\0" * ((4 - len(r) % 4) % 4) for r in parts)
    acc = [
        {
            "bufferView": 0,
            "componentType": 5126,
            "count": len(P),
            "type": "VEC3",
            "min": P.min(0).tolist(),
            "max": P.max(0).tolist(),
        },
        {"bufferView": 1, "componentType": 5126, "count": len(P), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": len(P), "type": "VEC2"},
        {"bufferView": 3, "componentType": 5125, "count": F.size, "type": "SCALAR"},
    ]
    js = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0}],
        "meshes": [
            {"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}
        ],
        "materials": [
            {"name": "loincloth", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0}}
        ],
        "textures": [{"source": 0}],
        "images": [{"bufferView": 4, "mimeType": "image/png"}],
        "accessors": acc,
        "bufferViews": views,
        "buffers": [{"byteLength": len(binb)}],
    }
    j = json.dumps(js).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(binb)))
        fh.write(struct.pack("<II", len(j), 0x4E4F534A) + j)
        fh.write(struct.pack("<II", len(binb), 0x004E4942) + binb)


def loin_part(out_path, in_path):
    """r24: the picked loincloth faces of every skin-native primitive, with the atlas UVs, as one static glb."""
    js, b = n.load(in_path)
    Ps, Us, Fs, off = [], [], [], 0
    for pi, f, sel, P, U in _loin_faces(js, b):
        ff = f[sel]
        u, inv = np.unique(ff, return_inverse=True)
        Ps.append(P[u])
        Us.append(U[u])
        Fs.append(inv.reshape(-1, 3) + off)
        off += len(u)
        print("prim %d: %d of %d faces picked" % (pi, int(sel.sum()), len(f)))
    P, U, F = np.concatenate(Ps), np.concatenate(Us), np.concatenate(Fs)
    N = np.zeros_like(P)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    _write_glb(out_path, P, N, U, F, d._image(js, b, 0)[..., :3].copy())
    print("written", out_path, len(F), "tris")


def _raster(UVt, S):
    """UV triangles (n, 3, 2) -> bool texel mask (S x S), rows = v * S (glTF v down, as d._image reads it)."""
    m = np.zeros((S, S), bool)
    Pt = UVt * S - 0.5
    for a, bb, c in Pt:
        x0, y0 = np.floor(np.minimum(np.minimum(a, bb), c)).astype(int) - 1
        x1, y1 = np.ceil(np.maximum(np.maximum(a, bb), c)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, S - 1), min(y1, S - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        den = (bb[1] - c[1]) * (a[0] - c[0]) + (c[0] - bb[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((bb[1] - c[1]) * (gx - c[0]) + (c[0] - bb[0]) * (gy - c[1])) / den
        l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        l3 = 1 - l1 - l2
        e = 0.08  # a texel past the edge (bilinear reads at the island rim)
        m[gy, gx] |= (l1 >= -e) & (l2 >= -e) & (l3 >= -e)
    return m


LOIN_FEATHER = 1.5  # px: blur of the paste mask edge
LOIN_WRAP = 0.05  # UV extent over which a face is a wrapped seam face (never pasted)


def loincloth(js, b, out, rig, tex_path):
    """r24: the Meshy retexture (original UVs) of the loin part is pasted into the atlas inside the picked faces' UV
    triangles only; every other texel keeps its value."""
    from PIL import Image
    from scipy import ndimage

    atlas = d._image(js, b, 0)[..., :3].astype(np.float32)
    S = atlas.shape[0]
    tex = np.asarray(Image.open(tex_path).convert("RGB").resize((S, S), Image.LANCZOS)).astype(np.float32)
    m = np.zeros((S, S), bool)
    nf, good = 0, []
    picked = _loin_faces(js, b)
    for pi, f, sel, P, U in picked:
        ext = np.ptp(U[f], axis=1).max(1)
        ok = sel & (ext > 0) & (ext < LOIN_WRAP)  # (seam faces whose UVs span the atlas would paste across it)
        if ok.any():
            m |= _raster(U[f[ok]], S)
            good.append((P[f[ok]].mean(1), U[f[ok]].mean(1)))
        nf += int(ok.sum())
    gc, gu = np.concatenate([g[0] for g in good]), np.concatenate([g[1] for g in good])
    tree = cKDTree(gc)
    moved = 0
    for pi, f, sel, P, U in picked:  # one-texel faces (the hole fills): their texel -> the nearest pasted face's UV
        one = sel & (np.ptp(U[f], axis=1).max(1) == 0)
        if not one.any():
            continue
        _, k = tree.query(P[f[one]].mean(1))
        U2 = U.copy()
        U2[f[one]] = gu[k][:, None, :]
        prim = js["meshes"][0]["primitives"][pi]
        prim["attributes"]["TEXCOORD_0"] = out.add_floats(U2.astype(np.float32), "VEC2")
        moved += int(one.sum())
    a = ndimage.gaussian_filter(m.astype(np.float32), LOIN_FEATHER)
    a = np.clip(a * 2, 0, 1) * m  # inside the picked triangles only; soft at the rim
    img = atlas * (1 - a[..., None]) + tex * a[..., None]
    d._set_image(js, out, 0, np.clip(img, 0, 255).astype(np.uint8))
    return "loincloth: %d faces pasted (%d texels), %d one-texel faces re-pointed" % (nf, int(m.sum()), moved)


# r24 horns: the 2D goo arm carries big cream crescent horns along its outer edge (the goal-9 item). One Meshy horn
# (root at the part's lowest point, the goo collar), placed at stations (rest pose) on the goo prim's outermost point
# of a y slab, rigid on that slab's main bone: (slab y, direction root -> tip, length m, side of the slab: x min or z min)
HORNS = (  # r24b: lengths 1.8x r24a (2D horns ~0.3-0.35 m on a ~1.1 m arm; r24a's read as stubs at game view)
    (1.52, (-0.45, 1.0, -0.1), 0.30, "x"),
    (1.24, (-1.0, 0.55, -0.1), 0.34, "x"),
    (1.00, (-1.0, 0.45, -0.25), 0.36, "x"),
    (0.74, (-1.0, 0.35, -0.1), 0.32, "x"),
    (1.10, (-0.45, 0.45, -1.0), 0.26, "z"),
)
HORN_SINK = 0.04  # m: the root goes this far into the goo (its goo collar sits on the surface)
HORN_SLAB = 0.03  # m: half height of the slab a station's surface point is taken from


def horns(js, b, out, rig, part_path):
    """r24: HORNS placed on the goo arm (prim skin-goo), each a copy of one Meshy horn rigid on its slab's bone. The
    part's chord (lowest point -> point farthest from it) maps onto the station direction; its bend (mid-arc offset
    from the chord) points up/outward the way the station's up is."""
    prims = js["meshes"][0]["primitives"]
    gp = next(p for p in prims if js["materials"][p["material"]]["name"] == "skin-goo")
    A = d.read_attrs(js, b, gp["attributes"])
    G, J, W = A["POSITION"], A["JOINTS_0"], A["WEIGHTS_0"]
    top = J[np.arange(len(G)), W.argmax(1)].astype(int)
    P, N, UV, F, img = d._part(part_path)
    root = P[P[:, 1] < P[:, 1].min() + 0.06 * np.ptp(P[:, 1])].mean(0)
    tip = P[np.linalg.norm(P - root, axis=1).argmax()]
    chord = tip - root
    L = float(np.linalg.norm(chord))
    t = (P - root) @ chord / L**2
    mid = P[(t > 0.4) & (t < 0.6)].mean(0) - (root + 0.5 * chord)
    M = _frame(chord, mid)  # part frame: columns = chord, bend, normal
    msg = []
    first = len(js["materials"])  # (every horn shares the first horn's texture: add_rigid appends one per call)
    for y, dr, length, side in HORNS:
        m = np.abs(G[:, 1] - y) < HORN_SLAB
        k = np.where(m)[0][G[m, 0 if side == "x" else 2].argmin()]
        u, c = np.unique(top[m], return_counts=True)
        bone = rig.names[int(u[c.argmax()])]
        dv = np.array(dr, float)
        dv /= np.linalg.norm(dv)
        up = np.array([0.0, 1.0, 0.0]) if abs(dv[1]) < 0.9 else np.array([-1.0, 0.0, 0.0])
        T = _frame(dv, up)
        R = T @ M.T
        sc = length / L
        tt = G[k] - dv * HORN_SINK - sc * root @ R.T
        Q = d.add_rigid(js, b, out, rig, (P, N, UV, F, img), R, sc, tt, bone, "leather-horn")
        msg.append(
            "y %.2f %s %s tip %s" % (y, side, bone, Q[np.linalg.norm(Q - G[k], axis=1).argmax()].round(2).tolist())
        )
    tex = js["materials"][first]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    for mat in js["materials"][first + 1 :]:
        mat["pbrMetallicRoughness"]["baseColorTexture"]["index"] = tex
    del js["textures"][tex + 1 :], js["images"][js["textures"][tex]["source"] + 1 :]
    return "%d tris each; " % len(F) + "; ".join(msg)


STAGES = {"--strap": [("strap", strap_r22)], "--slivers": [("slivers", drop_slivers)]}
STAGES["--goo"] = [("goo flare", flare_goo)]
STAGES["--dome"] = [("dome weights", dome_weights)]
STAGES["--nodome"] = [("dome", drop_dome)]
STAGES["--dometex"] = [("dome texture", dome_texture)]
STAGES["--posts"] = [("posts", lambda js, b, out, rig: posts(js, b, out, rig, sys.argv[4]))]
STAGES["--loincloth"] = [("loincloth", lambda js, b, out, rig: loincloth(js, b, out, rig, sys.argv[4]))]
STAGES["--horns"] = [("horns", lambda js, b, out, rig: horns(js, b, out, rig, sys.argv[4]))]
STAGES["--all"] = STAGES["--strap"] + STAGES["--slivers"] + STAGES["--goo"] + STAGES["--dome"]

if __name__ == "__main__":
    if sys.argv[1] == "--loinpart":
        loin_part(sys.argv[2], sys.argv[3])
        sys.exit(0)
    d.rebuild_stages(sys.argv[2], sys.argv[3], STAGES[sys.argv[1]])
