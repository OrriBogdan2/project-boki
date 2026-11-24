"""fill.py IN OUT: close the missing pelvis (body mesh has no surface between the corset bottom y~0.98 and the thigh tops y~0.78).
Adds 2 primitives to the Skirt mesh (body mesh bytes untouched): red inner shorts (skirt-meshy, Hips) and two porcelain upper-thigh
tubes (body-retex, UpLeg). Constant-UV on a solid texel of each texture."""

import sys, io

sys.path.insert(0, sys.path[0])
import numpy as np  # noqa: E402
from glbio import acc, json, load, put, save  # noqa: E402,F401
from PIL import Image

IN, OUT = sys.argv[1:3]
O = dict(a.split("=") for a in sys.argv[3:])
F = lambda k, d: float(O.get(k, d))
j, b = load(IN)
N = j["nodes"]
sk = j["skins"][0]
names = [N[k]["name"] for k in sk["joints"]]
IB = acc(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
G = np.linalg.inv(IB)
bd = j["meshes"][1]["primitives"][2]
sp = j["meshes"][4]["primitives"][0]
B = acc(j, b, bd["attributes"]["POSITION"]).astype(float)
BJ = acc(j, b, bd["attributes"]["JOINTS_0"])
BW = acc(j, b, bd["attributes"]["WEIGHTS_0"])
S = acc(j, b, sp["attributes"]["POSITION"]).astype(float)
dom = np.array(names)[BJ[np.arange(len(BJ)), BW.argmax(1)]]
iH = names.index("Hips")
iL = names.index("LeftUpLeg")
iR = names.index("RightUpLeg")
core = ~np.array([("Arm" in d) or ("Hand" in d) or ("Shoulder" in d) for d in dom])
cx, cz = np.median(B[core & (B[:, 1] > 0.98) & (B[:, 1] < 1.04)][:, [0, 2]], 0)
NA = 48
ang = np.linspace(-np.pi, np.pi, NA, endpoint=False)


def prof(P, c, y0, y1, fill=True):
    sel = (P[:, 1] >= y0) & (P[:, 1] <= y1)
    Q = P[sel]
    a = np.arctan2(Q[:, 2] - c[1], Q[:, 0] - c[0])
    r = np.hypot(Q[:, 0] - c[0], Q[:, 2] - c[1])
    k = ((a + np.pi) / (2 * np.pi) * NA).astype(int) % NA
    R = np.full(NA, np.nan)
    for i in range(NA):
        m = np.abs(((k - i + NA // 2) % NA) - NA // 2) <= 1
        if m.any():
            R[i] = r[m].max()
    ok = ~np.isnan(R)
    return np.interp(np.arange(NA), np.arange(NA)[ok], R[ok], period=NA)


def sinprof(P, c, y0, y1):  # inner wall of skirt: min radius
    sel = (P[:, 1] >= y0) & (P[:, 1] <= y1)
    Q = P[sel]
    a = np.arctan2(Q[:, 2] - c[1], Q[:, 0] - c[0])
    r = np.hypot(Q[:, 0] - c[0], Q[:, 2] - c[1])
    k = ((a + np.pi) / (2 * np.pi) * NA).astype(int) % NA
    R = np.full(NA, np.inf)
    np.minimum.at(R, k, r)
    return R


verts = []
faces = []
wts = []


def ring_mesh(rings, close_top, close_bot):
    """rings: list of (NA,3) arrays top->bottom; returns V,F (outward if rings CCW seen from above with +z front)"""
    V = np.concatenate(rings)
    n = len(rings)
    Fs = []
    for r in range(n - 1):
        for i in range(NA):
            a = r * NA + i
            c = r * NA + (i + 1) % NA
            d = (r + 1) * NA + i
            e = (r + 1) * NA + (i + 1) % NA
            Fs += [[a, d, c], [c, d, e]]
    if close_top:
        t = len(V)
        V = np.vstack([V, rings[0].mean(0) + [0, 0.004, 0]])
        Fs += [[t, i, (i + 1) % NA] for i in range(NA)]
    if close_bot:
        t = len(V)
        V = np.vstack([V, rings[-1].mean(0) - [0, 0.006, 0]])
        o = (n - 1) * NA
        Fs += [[t, o + (i + 1) % NA, o + i] for i in range(NA)]
    Fa = np.array(Fs)
    # orient outward: flip if mean normal points to centroid
    cen = V.mean(0)
    nr = np.cross(V[Fa[:, 1]] - V[Fa[:, 0]], V[Fa[:, 2]] - V[Fa[:, 0]])
    if (nr * (V[Fa].mean(1) - cen)).sum() < 0:
        Fa = Fa[:, [0, 2, 1]]
    return V, Fa


ss = lambda x: np.clip(x, 0, 1) ** 2 * (3 - 2 * np.clip(x, 0, 1))
# --- thigh tubes
HP = dict(np.load(O["hp"])) if "hp" in O else None
YB, YT = F("yb", 0.745), F("yt", 0.95)
tubes = []
_tc = [B[(dom == names[i]) & (B[:, 1] > 0.755) & (B[:, 1] < 0.80)][:, 0].mean() for i in (iL, iR)]
XM = (_tc[0] + _tc[1]) / 2
print("midplane x", round(XM, 3))
for side, ib in (("L", iL), ("R", iR)):
    sel = (dom == names[ib]) & (B[:, 1] > 0.755) & (B[:, 1] < 0.80)
    c0 = B[sel][:, [0, 2]].mean(0)
    r0 = prof(B[dom == names[ib]], c0, 0.755, 0.795)
    r0 = np.minimum(r0, np.median(r0) * 1.25)
    for _ in range(3):
        r0 = (np.roll(r0, 1) + 2 * r0 + np.roll(r0, -1)) / 4
    r0 = r0 + F("tpad", 0.002)
    jh = G[ib][:3, 3]
    rings = []
    ys = np.r_[np.linspace(YT, 0.86, 5), np.linspace(0.84, YB, 5)]
    for y in ys:
        s = (y - YB) / (0.84 - YB)
        c = c0 + (np.array([jh[0], jh[2]]) - c0) * ss(s) * F("tlean", 0.5)
        d = ss((y - 0.84) / (YT - 0.84))
        c = c + (np.array([jh[0], jh[2]]) - c) * d
        rr = r0 * (1 + F("tgrow", 0.10) * ss(s)) * (1 - F("dome", 0.75) * np.sqrt(d))
        if HP is not None:
            Q = HP[side][np.abs(HP[side][:, 1] - y) < 0.015]
            if len(Q):
                qa = np.arctan2(Q[:, 2] - c[1], Q[:, 0] - c[0])
                qr = np.hypot(Q[:, 0] - c[0], Q[:, 2] - c[1])
                da = np.abs((qa[None, :] - ang[:, None] + np.pi) % (2 * np.pi) - np.pi) < np.radians(14)
                lim = np.where(da, qr[None, :], 9).min(1) - F("hgap", 0.006)
                for _ in range(2):
                    lim = np.minimum(lim, np.minimum(np.roll(lim, 1), np.roll(lim, -1)) + 0.004)
                rr = np.maximum(np.minimum(rr, lim), rr * 0.55)
        px = c[0] + rr * np.cos(ang)
        px = np.maximum(px, XM + F("mgap", 0.004)) if side == "L" else np.minimum(px, XM - F("mgap", 0.004))
        rings.append(np.stack([px, np.full(NA, y), c[1] + rr * np.sin(ang)], 1))
    V, Fa = ring_mesh(rings, True, False)
    wl = np.ones(len(V))
    W = np.zeros((len(V), 4))
    Jn = np.zeros((len(V), 4), int)
    Jn[:, 0] = ib
    Jn[:, 1] = iH
    W[:, 0] = wl
    W[:, 1] = 1 - wl
    tubes.append((V, Fa, Jn, W, c0, r0))
    print(side, "thigh c", c0.round(3), "r", r0.min().round(3), r0.max().round(3))
# --- shorts (pelvis)
c = np.array([cx, cz])
Rtop = prof(B[core], c, 0.985, 1.01) - F("inset", 0.008)
YP0, YP1 = F("ytop", 1.0), F("ybot", 0.84)
allT = np.vstack([t[0][:-1] for t in tubes])
Rbot = prof(allT, c, YP1 - 0.03, YP1 + 0.03) + 0.006
Rsk = sinprof(S, c, 0.84, 1.0) - 0.008
rings = []
for y in np.linspace(YP0, YP1, 9):
    s = (YP0 - y) / (YP0 - YP1)
    rr = Rtop + (Rbot - Rtop) * ss(s) + F("bulge", 0.012) * np.sin(np.pi * s)
    rr = np.minimum(rr, np.where(np.isfinite(Rsk), Rsk, 9))
    rings.append(np.stack([cx + rr * np.cos(ang), np.full(NA, y), cz + rr * np.sin(ang)], 1))
V, Fa = ring_mesh(rings, False, True)
dx = V[:, 0] - cx
wl = 0.4 * ss((0.90 - V[:, 1]) / 0.06) * np.clip(np.abs(dx) / 0.06, 0, 1)
W = np.zeros((len(V), 4))
Jn = np.zeros((len(V), 4), int)
Jn[:, 0] = iH
Jn[:, 1] = np.where(dx > 0, iL, iR)
W[:, 0] = 1 - wl
W[:, 1] = wl
shorts = (V, Fa, Jn, W)
print(
    "shorts top r",
    Rtop.min().round(3),
    Rtop.max().round(3),
    "bot r",
    Rbot.min().round(3),
    Rbot.max().round(3),
    "clamped by skirt",
    (np.linspace(0, 0, 1)).size,
)


# --- UV: a solid texel of each texture
def texof(mi):
    ti = j["materials"][mi]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    im = j["images"][j["textures"][ti]["source"]]
    bv = j["bufferViews"][im["bufferView"]]
    o = bv.get("byteOffset", 0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[o : o + bv["byteLength"]]))).convert("RGB")).astype(float)


def pickuv(prim, mask, want):
    T = texof(prim["material"])
    h, w, _ = T.shape
    UV = acc(j, b, prim["attributes"]["TEXCOORD_0"])[mask]
    best = None
    for uv in UV[:: max(1, len(UV) // 3000)]:
        x = int(uv[0] % 1 * w)
        y = int(uv[1] % 1 * h)
        if x < 6 or y < 6 or x > w - 7 or y > h - 7:
            continue
        p = T[y - 6 : y + 7, x - 6 : x + 7].reshape(-1, 3)
        sc = np.abs(p.mean(0) - want).sum() + p.std(0).sum() * 2
        if best is None or sc < best[0]:
            best = (sc, uv, p.mean(0))
    print("uv", best[1].round(4), "rgb", best[2].round())
    return best[1]


SUV = acc(j, b, sp["attributes"]["TEXCOORD_0"])
T = texof(sp["material"])
h, w, _ = T.shape
med = np.median(T[(SUV[:, 1] % 1 * h).astype(int).clip(0, h - 1), (SUV[:, 0] % 1 * w).astype(int).clip(0, w - 1)], 0)
print("skirt median rgb", med)
uv_red = pickuv(sp, np.ones(len(S), bool), med)
thighm = np.isin(dom, ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]) & (B[:, 1] > 0.6) & (B[:, 1] < 0.76)
BT = texof(bd["material"])
BUV = acc(j, b, bd["attributes"]["TEXCOORD_0"])
bh, bw, _ = BT.shape
cols = BT[(BUV[thighm, 1] % 1 * bh).astype(int).clip(0, bh - 1), (BUV[thighm, 0] % 1 * bw).astype(int).clip(0, bw - 1)]
wmed = np.median(cols[cols.sum(1) > 500], 0)
print("thigh porcelain median rgb", wmed)
uv_white = pickuv(bd, thighm, wmed)


# --- append primitives
def addacc(arr, ct, typ, target=None, mm=False):
    raw = np.ascontiguousarray(arr).tobytes()
    pad = (-len(b)) % 4
    b.extend(b"\0" * pad)
    o = len(b)
    b.extend(raw)
    bv = {"buffer": 0, "byteOffset": o, "byteLength": len(raw)}
    if target:
        bv["target"] = target
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ct, "count": len(arr), "type": typ}
    if mm:
        a["min"] = [float(x) for x in arr.min(0)]
        a["max"] = [float(x) for x in arr.max(0)]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def vnorm(V, Fa):
    n = np.zeros_like(V)
    fn = np.cross(V[Fa[:, 1]] - V[Fa[:, 0]], V[Fa[:, 2]] - V[Fa[:, 0]])
    for k in range(3):
        np.add.at(n, Fa[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


def addprim(V, Fa, Jn, W, mat, uv):
    at = {
        "POSITION": addacc(V.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": addacc(vnorm(V, Fa).astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": addacc(np.tile(uv, (len(V), 1)).astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": addacc(Jn.astype(np.uint8), 5121, "VEC4", 34962),
        "WEIGHTS_0": addacc((W / W.sum(1, keepdims=True)).astype(np.float32), 5126, "VEC4", 34962),
    }
    j["meshes"][4]["primitives"].append(
        {"attributes": at, "indices": addacc(Fa.astype(np.uint16).ravel(), 5123, "SCALAR", 34963), "material": mat}
    )
    return len(Fa)


import copy


def dupmat(mi, name):
    m = copy.deepcopy(j["materials"][mi])
    m["name"] = name
    j["materials"].append(m)
    return len(j["materials"]) - 1


nt = addprim(*shorts, dupmat(sp["material"], "skirt-liner"), uv_red)
V = np.vstack([t[0] for t in tubes])
off = len(tubes[0][0])
Fa = np.vstack([tubes[0][1], tubes[1][1] + off])
nt += addprim(
    V,
    Fa,
    np.vstack([t[2] for t in tubes]),
    np.vstack([t[3] for t in tubes]),
    dupmat(bd["material"], "thigh-liner"),
    uv_white,
)
print("added tris", nt)
save(OUT, j, b)
