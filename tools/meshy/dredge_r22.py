"""Grimble (dredge) native model, round 22 stages on the r21 glb (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md).

  dredge_r22.py --strap OUT IN          strap rebuilt as one closed band per side, shoulder blade to belt, on the skin
  dredge_r22.py --slivers OUT IN        the long thin skin slivers (the ear/shoulder strand web) dropped
  dredge_r22.py --goo OUT IN            the goo arm root flared over the shoulder socket, the arm a little thicker
  dredge_r22.py --dome OUT IN           the socket dome's head weights moved to the shoulder (strand web)
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


STAGES = {"--strap": [("strap", strap_r22)], "--slivers": [("slivers", drop_slivers)]}
STAGES["--goo"] = [("goo flare", flare_goo)]
STAGES["--dome"] = [("dome weights", dome_weights)]
STAGES["--nodome"] = [("dome", drop_dome)]
STAGES["--all"] = STAGES["--strap"] + STAGES["--slivers"] + STAGES["--goo"] + STAGES["--dome"]

if __name__ == "__main__":
    d.rebuild_stages(sys.argv[2], sys.argv[3], STAGES[sys.argv[1]])
