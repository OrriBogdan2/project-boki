"""Re-binds a v95 hunter's hand onto its rig's hand bones, gives it volume and a thumb (Vex's left hand, 11-23).

Run: python3 -I tools/art1/hand_rebind.py in.glb out.glb [--side L] [--turn 0.75] [--swing DEG] [--plot out.png]

Why: v95_swap.py fits the master by its joints and keeps everything past the wrist rigid (`past_wrist`), so a hand the
master holds flat or splayed keeps that pose in the bind while the contract's hand.L/fingers.L/thumb.L hang straight
down. Then (Vex 11-23) the mesh fingers point 60 degrees away from the bones: the coin (on `coin`, under the
bones) floats
15-25 cm from the fingers, bone heat gives the fingers to the nearer thigh, and fingers.L/thumb.L get no weight: the
clips' finger curls (14 deg grip, 48 coin flick, 57 fusion) never show and the hand stays a flat claw.

What it does (every vertex outside the hand is untouched):
1. The hand: welded vertices below the mesh wrist that are >= 50 % on forearm/hand/fingers/thumb.
2. Turn: one rigid rotation about the mesh wrist that lays the hand's wrist-to-fingertip axis onto the bone axis
   (hand.<S> -> fingers.<S>) by --turn of the way, faded in over the first 2 cm so the cuff join does not kink; --swing
   then
   tilts it about the wrist across the palm (away from the thigh it rests on).
3. Volume: the scan's palm is a 9 mm card and its fingers 7 mm blades. Each vertex moves along the palm normal away from
   its inner face (1.5 cm cells), so the thickness grows by --k-palm / --k-fingers and the width does not (the
   fingers
   do not grow into each other); the normals are rebuilt.
4. Weights: wrist band forearm -> hand; palm hand; past the knuckles (fingers bone's depth along the axis) fingers; the
   thumb (a capsule from the palm's thumb-side edge to the most lateral vertex) thumb, each blended over 2 cm.
5. Skin: the scan paints the palm and wrist dark brown (the 'dark disc'). Dark UV islands of the palm and cuff get
   their
   UVs moved onto one flat texel of the skin (palm) or of the sleeve's tan (cuff): no pixel of the atlas changes.
"""

import argparse
import io
import json
import struct

import numpy as np


def load(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    return j, bytearray(b[20 + n + 8 :]), b


def view(j, buf, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    ct = {5126: np.float32, 5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
    nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    assert bv.get("byteStride", 0) in (0, np.dtype(ct).itemsize * nc), "interleaved buffers not handled"
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(buf, ct, a["count"] * nc, o).reshape(a["count"], nc)


def save(path, j, buf):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    buf = bytes(buf) + b"\0" * (-len(buf) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(buf))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + buf
    open(path, "wb").write(out)


def rot(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = float(u @ v)
    ax = np.cross(u, v)
    s = np.linalg.norm(ax)
    if s < 1e-8:
        return np.eye(3)
    k = ax / s
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + s * K + (1 - c) * K @ K


def axis_rot(k, ang):
    k = k / np.linalg.norm(k)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + np.sin(ang) * K + (1 - np.cos(ang)) * K @ K


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def welded(P):
    key = np.round(P / 0.0005).astype(np.int64)
    return np.unique(key, axis=0, return_inverse=True)[1].ravel()


def texel_colours(j, buf, prims, UV):
    """The base-colour texel under every vertex, its image index, and the images (PIL is only needed here)."""
    from PIL import Image

    imgs, col, src, o = {}, np.zeros((len(UV), 3)), np.zeros(len(UV), int), 0
    for p in prims:
        n = j["accessors"][p["attributes"]["POSITION"]]["count"]
        si = j["textures"][j["materials"][p["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
        if si not in imgs:
            bv = j["bufferViews"][j["images"][si]["bufferView"]]
            raw = bytes(buf[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]])
            imgs[si] = np.asarray(Image.open(io.BytesIO(raw)).convert("RGB")).astype(float)
        t, u = imgs[si], UV[o : o + n]
        col[o : o + n] = t[
            (u[:, 1] * (t.shape[0] - 1)).astype(int).clip(0, t.shape[0] - 1),
            (u[:, 0] * (t.shape[1] - 1)).astype(int).clip(0, t.shape[1] - 1),
        ]
        src[o : o + n] = si
        o += n
    return col, src, imgs


def flattest_uv(UV, src, imgs, cand):
    """The UV of the candidate vertex whose 13x13 texel patch varies least: one flat colour of the atlas."""
    best = None
    for i in np.where(cand)[0]:
        t = imgs[src[i]]
        x, y = int(UV[i, 0] * (t.shape[1] - 1)), int(UV[i, 1] * (t.shape[0] - 1))
        pt = t[max(y - 6, 0) : y + 7, max(x - 6, 0) : x + 7].reshape(-1, 3)
        if best is None or pt.std(0).sum() < best[0]:
            best = (pt.std(0).sum(), UV[i].copy(), pt.mean(0))
    return best


def islands(T, n):
    """The UV islands: vertices joined by a triangle edge (the glb splits a vertex at every seam), by label passes."""
    lab = np.arange(n)
    e = np.concatenate([T[:, [0, 1]], T[:, [1, 2]]])
    while True:
        m = np.minimum(lab[e[:, 0]], lab[e[:, 1]])
        new = lab.copy()
        np.minimum.at(new, e[:, 0], m)
        np.minimum.at(new, e[:, 1], m)
        new = new[new]
        if (new == lab).all():
            return lab
        lab = new


def vertex_normals(P, T, inv):
    fn = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    acc = np.zeros((inv.max() + 1, 3))
    for c in range(3):
        np.add.at(acc, inv[T[:, c]], fn)
    return acc[inv] / (np.linalg.norm(acc[inv], axis=1, keepdims=True) + 1e-12)


def thickness(u, s, v, lo, hi, reach=0.012):
    """Median spread (p90 - p10) of the palm-normal coordinate within `reach` m of each vertex, in the palm plane."""
    sel = np.where((s > lo) & (s < hi))[0]
    d = np.hypot(u[sel][:, None] - u[sel][None], s[sel][:, None] - s[sel][None]) < reach
    spread = [np.ptp(np.percentile(v[sel][row], [10, 90])) for row in d if row.sum() >= 4]
    return float(np.median(spread)) if spread else 0.0


def prim_arrays(j, buf):
    """Per-vertex position, uv, joints, weights and the triangles of the whole mesh (primitives concatenated)."""
    out, off = {"P": [], "U": [], "J": [], "W": [], "T": []}, 0
    for p in j["meshes"][0]["primitives"]:
        at = p["attributes"]
        out["P"].append(view(j, buf, at["POSITION"]).astype(float))
        out["U"].append(view(j, buf, at["TEXCOORD_0"]).astype(float))
        out["J"].append(view(j, buf, at["JOINTS_0"]).astype(int))
        out["W"].append(view(j, buf, at["WEIGHTS_0"]).astype(float))
        out["T"].append(view(j, buf, p["indices"]).reshape(-1, 3).astype(int) + off)
        off += len(out["P"][-1])
    return {k: np.concatenate(v) for k, v in out.items()}


def rehang_fins(j, buf, live_path, max_edge):
    """#360 hung the scan's hip fins on the gun arm, which left a black hole in the right hip when the arm moves.
    The fin
    triangles that sit on the arm here and not in `live`, with no edge >= max_edge, take live's hip weights again (only
    the
    vertices no other triangle uses, so the sleeve does not stretch); the rest are the spikes drop_spikes deletes."""
    jl, bl, _ = load(live_path)
    mine, live = prim_arrays(j, buf), prim_arrays(jl, bl)
    names = [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]
    arm = [names.index(n) for n in ("upper_arm.R", "forearm.R", "gatling", "launcher", "hand.R")]
    top = lambda m: np.take_along_axis(m["J"], m["W"].argmax(1)[:, None], 1)[:, 0][m["T"]]
    fin = np.where(np.isin(top(mine), arm).all(1) & ~np.isin(top(live), arm).any(1))[0]
    corner = mine["P"][mine["T"][fin]]
    short = fin[np.linalg.norm(corner - np.roll(corner, 1, 1), axis=2).max(1) < max_edge]
    rest = np.setdiff1d(np.arange(len(mine["T"])), short)
    only = np.setdiff1d(np.unique(mine["T"][short]), np.unique(mine["T"][rest]))
    def key(m, i):
        return tuple(np.round(m["P"][i] / 0.0005).astype(int)), tuple(np.round(m["U"][i] / 0.0005).astype(int))

    twin = {key(live, i): i for i in range(len(live["P"]))}
    newJ, newW = mine["J"].copy(), mine["W"].copy()
    for v in only:
        t = twin.get(key(mine, v))
        if t is not None:
            newJ[v], newW[v] = live["J"][t], live["W"][t]
    o = 0
    for p in j["meshes"][0]["primitives"]:
        n = j["accessors"][p["attributes"]["POSITION"]]["count"]
        jv, wv = view(j, buf, p["attributes"]["JOINTS_0"]), view(j, buf, p["attributes"]["WEIGHTS_0"])
        jv[:] = newJ[o : o + n].astype(jv.dtype)
        scale = {np.dtype(np.uint8): 255.0, np.dtype(np.uint16): 65535.0}.get(wv.dtype, 1.0)
        wv[:] = np.round(newW[o : o + n] * scale).astype(wv.dtype) if scale > 1 else newW[o : o + n].astype(wv.dtype)
        o += n
    print("fins: %d short fin triangles (%d vertices) back on live's hip weights" % (len(short), len(only)))


def drop_spikes(j, buf, names, min_edge):
    """Deletes the scan's blade-like fins at the right hip / gun mount: a triangle in the hip box (x 0.03..0.30,
    y 0.75..1.30, |z| < 0.2 m)
    with an edge >= min_edge, or one joining the gun arm's skin to the hips' (it stretches whenever the arm moves).
    Vertices stay, so weights, UVs and the rest are as before."""
    arm = [names.index(n) for n in ("upper_arm.R", "forearm.R", "gatling", "launcher", "hand.R")]
    dropped = 0
    for p in j["meshes"][0]["primitives"]:
        at = p["attributes"]
        P = view(j, buf, at["POSITION"]).astype(float)
        best = view(j, buf, at["WEIGHTS_0"]).argmax(1)[:, None]
        dom = np.take_along_axis(view(j, buf, at["JOINTS_0"]).astype(int), best, 1)[:, 0]
        idx = view(j, buf, p["indices"])
        T = idx.reshape(-1, 3).astype(int)
        corner = P[T]
        c = corner.mean(1)
        box = (c[:, 0] > 0.03) & (c[:, 0] < 0.30) & (c[:, 1] > 0.75) & (c[:, 1] < 1.30) & (abs(c[:, 2]) < 0.2)
        on_arm = np.isin(dom[T], arm)
        spanning = on_arm.any(1) & ~on_arm.all(1)
        keep = ~(box & ((np.linalg.norm(corner - np.roll(corner, 1, 1), axis=2).max(1) >= min_edge) | spanning))
        n = int(keep.sum())
        idx.reshape(-1, 3)[:n] = T[keep]  # the kept triangles first, the accessor cut to them
        j["accessors"][p["indices"]]["count"] = n * 3
        dropped += len(T) - n
    print(
        "spikes: %d triangles (edge >= %.2f m, or joining the gun arm to the hips) deleted at the right hip"
        % (dropped, min_edge)
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--side", default="L")
    ap.add_argument("--thumb-z", type=float, default=-1.0, help="the thumb's side along glTF z (-1: her front)")
    ap.add_argument("--turn", type=float, default=0.75, help="share of the full turn onto the bone axis")
    ap.add_argument("--swing", type=float, default=-10.0, help="extra degrees about the wrist, fingers away from the thigh")
    ap.add_argument("--out", type=float, default=3.0, help="cm the hand moves away from the body (off the thigh)")
    ap.add_argument("--k-palm", type=float, default=3.0, help="palm thickness factor")
    ap.add_argument("--k-fingers", type=float, default=2.0, help="finger thickness factor")
    ap.add_argument("--spikes", type=float, default=0.06, help="m: delete hip triangles with an edge this long")
    ap.add_argument("--rehang", help="live glb: the hip fins hung on the gun arm take its hip weights again")
    ap.add_argument("--no-skin", action="store_true", help="keep the scan's dark palm texels")
    ap.add_argument("--plot")
    a = ap.parse_args()
    S = a.side
    j, buf, _ = load(a.src)
    sk = j["skins"][0]
    names = [j["nodes"][i]["name"] for i in sk["joints"]]
    IB = view(j, buf, sk["inverseBindMatrices"]).reshape(-1, 4, 4)

    def bpos(nm):
        return np.linalg.inv(IB[names.index(nm)].T)[:3, 3]

    FA, HA, FI, TH = (x + "." + S for x in ("forearm", "hand", "fingers", "thumb"))
    iFA, iHA, iFI, iTH = (names.index(x) for x in (FA, HA, FI, TH))
    prims = j["meshes"][0]["primitives"]
    Ps, Ns, Js, Ws, Us, Ts, off = [], [], [], [], [], [], 0
    for p in prims:
        at = p["attributes"]
        Ps.append(view(j, buf, at["POSITION"]))
        Ns.append(view(j, buf, at["NORMAL"]))
        Js.append(view(j, buf, at["JOINTS_0"]))
        Ws.append(view(j, buf, at["WEIGHTS_0"]))
        Us.append(view(j, buf, at["TEXCOORD_0"]))
        Ts.append(view(j, buf, p["indices"]).reshape(-1, 3).astype(int) + off)
        off += len(Ps[-1])
    P, J, W, UV, T = (np.concatenate(x).astype(float) for x in (Ps, Js, Ws, Us, Ts))
    J, T = J.astype(int), T.astype(int)
    inv = welded(P)
    arm = (W * np.isin(J, [iFA, iHA, iFI, iTH])).sum(1)
    armw = np.zeros(inv.max() + 1)
    np.maximum.at(armw, inv, arm)
    wrist_b = bpos(HA)
    bone_dir = bpos(FI) - wrist_b
    bone_dir /= np.linalg.norm(bone_dir)
    # the hand: the arm side below the mesh wrist (the cuff's lower edge sits ~1 cm above the bone's wrist)
    H = (armw[inv] > 0.5) & (P[:, 1] < wrist_b[1] + 0.02) & (np.linalg.norm(P - wrist_b, axis=1) < 0.4)
    q = P[H]
    C = q[q[:, 1] > q[:, 1].max() - 0.015].mean(0)
    tip = q[np.linalg.norm(q - C, axis=1) > np.percentile(np.linalg.norm(q - C, axis=1), 80)].mean(0) - C
    t_hat = tip / np.linalg.norm(tip)
    R = rot(tip, bone_dir)
    ang = np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)) * a.turn
    k = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]])
    k = k / np.linalg.norm(k) if np.linalg.norm(k) > 1e-9 else np.array([0.0, 0, 1])
    idx = np.where(H)[0]
    hdir = axis_rot(k, ang) @ t_hat  # the hand's axis after the turn
    nrm = np.linalg.svd((P[idx] - C) @ axis_rot(k, ang).T, full_matrices=False)[2][2]
    nrm = nrm - hdir * (nrm @ hdir)
    nrm /= np.linalg.norm(nrm)
    wid = np.cross(hdir, nrm)
    wid *= 1.0 if wid[2] * -np.sign(a.thumb_z) > 0 else -1.0  # the thumb side is u < 0
    nrm = np.cross(wid, hdir)
    away = np.array([np.sign(wrist_b[0]), 0.0, 0.0])
    f = smooth((P[idx] - C) @ t_hat, 0.0, 0.02)  # the turn and the move fade in over the first 2 cm below the wrist
    newP = P.copy()
    for t_i, vi in zip(f, idx):
        turn = axis_rot(wid, np.radians(a.swing) * t_i) @ axis_rot(k, ang * t_i)
        newP[vi] = C + turn @ (P[vi] - C) + t_i * a.out / 100 * away
    hdir = axis_rot(wid, np.radians(a.swing)) @ hdir
    nrm = np.cross(wid, hdir)
    # the palm normal points away from the body: the volume grows on the outer side
    nrm *= 1.0 if nrm @ away > 0 else -1.0
    r = newP[idx] - C
    s, u, v = r @ hdir, r @ wid, r @ nrm
    knuckle = float((bpos(FI) - wrist_b) @ bone_dir)
    # depth along the bone axis: windows and weights follow the bones, not the mesh
    sb = (newP[idx] - wrist_b) @ bone_dir
    print("hand %d verts, turn %.1f deg, swing %.1f, knuckle %.3f m" % (H.sum(), np.degrees(ang), a.swing, knuckle))
    # volume: grow the spread along the palm normal from each 1.5 cm cell's inner face (the side on the thigh)
    cid = np.floor(u / 0.015).astype(int) * 1000 + np.floor(s / 0.015).astype(int)
    ci = np.unique(cid, return_inverse=True)[1].ravel()
    cnt = np.bincount(ci)
    vmax, vmin = np.full(len(cnt), -9.0), np.full(len(cnt), 9.0)
    np.maximum.at(vmax, ci, v)
    np.minimum.at(vmin, ci, v)
    grow = a.k_palm + (a.k_fingers - a.k_palm) * smooth(sb, knuckle, knuckle + 0.06)
    thin = 1 - smooth((vmax - vmin)[ci], 0.04, 0.06)  # thick tubes (the wrist) stay
    grow = 1 + (grow - 1) * thin * smooth(sb, knuckle - 0.04, knuckle) * (cnt[ci] >= 3)
    v2 = vmin[ci] + (v - vmin[ci]) * grow
    newP[idx] += np.outer(v2 - v, nrm)
    # the palm card and the fingers, by depth along the bone axis
    pl, ph, fl = knuckle - 0.005, knuckle + 0.055, knuckle + 0.07
    p0, p1 = thickness(u, sb, v, pl, ph), thickness(u, sb, v2, pl, ph)
    f0, f1 = thickness(u, sb, v, fl, 1), thickness(u, sb, v2, fl, 1)
    width = float(np.ptp(np.percentile(u[(sb > pl) & (sb < ph)], [5, 95])))
    print("palm thickness %.1f -> %.1f mm (width %.1f mm, ratio %.2f -> %.2f), fingers %.1f -> %.1f mm" % (
        p0 * 1e3, p1 * 1e3, width * 1e3, p0 / width, p1 / width, f0 * 1e3, f1 * 1e3))
    newN = vertex_normals(newP, T, inv)
    # weights: forearm band -> palm -> fingers along the bone axis; the thumb: a capsule from the palm's thumb-side edge
    # to the most lateral vertex past the knuckles
    wrist_w = 1 - smooth(sb, -0.02, 0.015)
    fing = smooth(sb, knuckle - 0.02, knuckle + 0.02)
    out = np.where(s > 0.08)[0]
    tipv = out[np.argmin(u[out])]
    base = np.array([np.percentile(u[(s > 0.03) & (s < 0.07)], 5), 0.05])
    seg = np.array([u[tipv], s[tipv]]) - base
    rel = np.stack([u, s], 1) - base
    tt = np.clip(rel @ seg / (seg @ seg), 0, 1)
    thumb = (1 - smooth(np.linalg.norm(rel - np.outer(tt, seg), axis=1), 0.012, 0.022)) * smooth(tt, 0.05, 0.35)
    newW, newJ = np.zeros((len(idx), 4)), np.zeros((len(idx), 4), int)
    for n_ in range(len(idx)):
        fa, rest = wrist_w[n_], 1 - wrist_w[n_]
        th = rest * thumb[n_]
        fi = (rest - th) * fing[n_]
        ws = sorted([(fa, iFA), (rest - th - fi, iHA), (fi, iFI), (th, iTH)], reverse=True)
        tot = sum(w for w, _ in ws)
        for c, (w, b) in enumerate(ws):
            newW[n_, c], newJ[n_, c] = w / tot, b
    print(
        "weights: forearm band %d, palm %d, fingers %d, thumb %d"
        % (
            (wrist_w > 0.5).sum(),
            ((wrist_w <= 0.5) & (fing < 0.5) & (thumb < 0.5)).sum(),
            ((fing >= 0.5) & (thumb < 0.5)).sum(),
            (thumb >= 0.5).sum(),
        )
    )
    newUV = UV.copy()
    if not a.no_skin:
        col, src, imgs = texel_colours(j, buf, prims, UV)
        lum = col @ [0.3, 0.59, 0.11]
        lab = islands(T, len(P))
        s_all = (newP - C) @ hdir
        skin = H & (lum > 190) & (col[:, 0] - col[:, 2] > 15) & (col[:, 0] - col[:, 2] < 70)
        tan = (arm > 0.5) & ~H & (s_all < -0.01) & (s_all > -0.12) & (lum > 150) & (col[:, 0] - col[:, 2] > 50)
        b_skin, b_tan = flattest_uv(UV, src, imgs, skin), flattest_uv(UV, src, imgs, tan)
        # a dark island of the hand or cuff takes one flat texel: skin below the wrist, the sleeve's tan above it
        # (a whole island: its edge is a seam, so no triangle smears across the atlas; thigh islands are not touched)
        flat_n = {"palm": 0, "cuff": 0}
        for c in np.unique(lab[arm > 0.5]):
            m_ = lab == c
            if (arm[m_] > 0.5).mean() < 0.9 or abs(np.median(s_all[m_])) > 0.12 or P[m_, 1].min() < wrist_b[1] - 0.2:
                continue
            if (lum[m_] < 110).mean() > 0.15 or lum[m_].mean() < 140:
                key = "palm" if np.median(s_all[m_]) >= 0 else "cuff"
                newUV[m_], flat_n[key] = (b_skin if key == "palm" else b_tan)[1], flat_n[key] + m_.sum()
        print("skin: %d dark hand verts on one skin texel %s, %d dark cuff verts on the sleeve's tan %s" % (
            flat_n["palm"], b_skin[2].round(0), flat_n["cuff"], b_tan[2].round(0)))
    # write back
    o = 0
    for pi, p in enumerate(prims):
        n_ = len(Ps[pi])
        sel = (idx >= o) & (idx < o + n_)
        li = idx[sel] - o
        Ps[pi][li] = newP[idx[sel]].astype(np.float32)
        Ns[pi][li] = newN[idx[sel]].astype(np.float32)
        Js[pi][li] = newJ[sel].astype(Js[pi].dtype)
        Ws[pi][li] = newW[sel].astype(Ws[pi].dtype)
        Us[pi][:] = newUV[o : o + n_].astype(Us[pi].dtype)
        acc = j["accessors"][p["attributes"]["POSITION"]]
        acc["min"], acc["max"] = Ps[pi].min(0).tolist(), Ps[pi].max(0).tolist()
        o += n_
    if a.rehang:
        rehang_fins(j, buf, a.rehang, a.spikes)
    if a.spikes:
        drop_spikes(j, buf, names, a.spikes)
    save(a.dst, j, buf)
    if a.plot:
        plot(a.plot, u, v, s, newW, newJ, (iHA, iFI, iTH))


def plot(path, u, v, s, W, J, bones):
    from PIL import Image, ImageDraw

    im = Image.new("RGB", (1000, 760), "white")
    dr = ImageDraw.Draw(im)
    wt = [(W * (J == b)).sum(1) for b in bones]
    for ox, ax in ((0, u), (500, v)):
        for x, y, h, fi, th in zip(ax, s, *wt):
            c = (int(255 * fi), int(200 * th), int(255 * h))
            px, py = ox + 250 + x * 2200, 20 + y * 2200
            dr.rectangle((px - 2, py - 2, px + 2, py + 2), fill=c)
    note = "left: width u (thumb side <0) | right: thickness v. blue palm, red fingers, green thumb"
    dr.text((5, 740), note, fill="black")
    im.save(path)


main()
