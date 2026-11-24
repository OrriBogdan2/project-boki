"""snap3.py IN OUT [gap_cm=0.4] [ylo=0.90] [yfull=0.95] [thk_cm=1.0]: close the waist ring.
Skirt verts in the band get a direct target radius per angle bin: body max radius (Rb) + gap + min(own shell offset, thk),
blended by smoothstep(ylo..yfull); after a light displacement smoothing the max gap is re-clamped. Normals kept."""

import sys, os

sys.path.insert(0, sys.path[0])
import numpy as np  # noqa: E402
from glbio import acc, json, load, put, save  # noqa: E402,F401
from scipy.sparse import coo_matrix, diags

IN, OUT = sys.argv[1:3]
a_ = [float(x) for x in sys.argv[3:]] + [None] * 4
gap = (a_[0] or 0.4) / 100
ylo = a_[1] or 0.90
yfull = a_[2] or 0.95
thk = (a_[3] or 1.0) / 100
j, b = load(IN)
sk = j["meshes"][4]["primitives"][0]
bd = j["meshes"][1]["primitives"][2]
S = acc(j, b, sk["attributes"]["POSITION"]).astype(float)
B = acc(j, b, bd["attributes"]["POSITION"]).astype(float)
J = acc(j, b, bd["attributes"]["JOINTS_0"])
W = acc(j, b, bd["attributes"]["WEIGHTS_0"])
names = [j["nodes"][k]["name"] for k in j["skins"][0]["joints"]]
top = J[np.arange(len(J)), W.argmax(1)]
core = np.isin(top, [i for i, n in enumerate(names) if n.startswith(("Hips", "Spine", "LeftUpLeg", "RightUpLeg"))])
Bc = B[core & (B[:, 1] > 0.80) & (B[:, 1] < 1.12)]
cx, cz = np.median(Bc[(Bc[:, 1] > 0.95)][:, 0]), np.median(Bc[(Bc[:, 1] > 0.95)][:, 2])
NA = 72
DY = 0.01
ys = np.arange(0.80, 1.12, DY)
pol = lambda P: (np.arctan2(P[:, 2] - cz, P[:, 0] - cx), np.hypot(P[:, 0] - cx, P[:, 2] - cz))
ab, rb = pol(Bc)
ia = ((ab + np.pi) / (2 * np.pi) * NA).astype(int) % NA
Rb = np.full((NA, len(ys)), np.nan)
for k in range(NA):
    for m, y in enumerate(ys):
        sel = (np.abs(((ia - k + NA // 2) % NA) - NA // 2) <= 1) & (np.abs(Bc[:, 1] - y) < 0.012)
        if sel.any():
            Rb[k, m] = rb[sel].max()
for m in range(len(ys)):
    c = Rb[:, m]
    ok = ~np.isnan(c)
    if ok.sum() > 3:
        Rb[:, m] = np.interp(np.arange(NA), np.arange(NA)[ok], c[ok], period=NA)
a, r = pol(S)
ka = ((a + np.pi) / (2 * np.pi) * NA).astype(int) % NA
my = np.clip(np.round((S[:, 1] - ys[0]) / DY).astype(int), 0, len(ys) - 1)
Rsi = np.full((NA, len(ys)), np.inf)
np.minimum.at(Rsi, (ka, my), r)
d = np.clip(r - Rsi[ka, my], 0, None)  # offset outward of the inner shell at this bin
tgt = Rb[ka, my] + gap + np.minimum(d, thk)
t = np.clip((S[:, 1] - ylo) / (yfull - ylo), 0, 1)
t = t * t * (3 - 2 * t)
band = (t > 0) & ~np.isnan(tgt)
nr = r.copy()
nr[band] = r[band] + t[band] * (tgt[band] - r[band])
I0 = acc(j, b, sk["indices"]).reshape(-1, 3).astype(int)
key = np.round(S / 0.0005).astype(np.int64)
_, gg = np.unique(key, axis=0, return_inverse=True)
gg = gg.ravel()
ng = gg.max() + 1
cnt = np.bincount(gg)
e = gg[np.r_[I0[:, [0, 1]], I0[:, [1, 2]], I0[:, [2, 0]]]]
e = e[e[:, 0] != e[:, 1]]
E = np.r_[e, e[:, ::-1]]
A_ = coo_matrix((np.ones(len(E)), (E[:, 0], E[:, 1])), shape=(ng, ng)).tocsr()
A_.data[:] = 1
Mn = diags(1 / np.maximum(np.asarray(A_.sum(1)).ravel(), 1)) @ A_
dl = np.zeros(ng)
np.add.at(dl, gg, nr - r)
dl /= cnt
for _ in range(int(os.environ.get("SMOOTH", "15"))):
    dl = 0.5 * dl + 0.5 * (Mn @ dl)
nr2 = r + dl[gg]
full = band & (t > 0.999)
hi = tgt + 0.004
nr2[full] = np.minimum(nr2[full], hi[full])
nr2[full] = np.maximum(nr2[full], (Rb[ka, my] + 0.5 * gap)[full])
S2 = S.copy()
f = nr2 / np.maximum(r, 1e-6)
S2[:, 0] = cx + (S[:, 0] - cx) * f
S2[:, 2] = cz + (S[:, 2] - cz) * f
mv = np.linalg.norm(S2 - S, axis=1)


# folded faces check (normal flips vs original)
def fn(P):
    v = np.cross(P[I0[:, 1]] - P[I0[:, 0]], P[I0[:, 2]] - P[I0[:, 0]])
    return v / np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-12)


flip = ((fn(S) * fn(S2)).sum(1) < 0).sum()
print("moved", (mv > 0.001).sum(), "max cm", round(mv.max() * 100, 1), "flipped faces", flip)
put(j, b, sk["attributes"]["POSITION"], S2.astype(np.float32))
save(OUT, j, b)
