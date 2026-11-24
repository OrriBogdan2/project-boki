"""topo.py GLB: skirt (meshes[4]) boundary loops after position weld; top ring gap to body."""

import sys

sys.path.insert(0, sys.path[0])
import numpy as np  # noqa: E402
from glbio import acc, json, load, put, save  # noqa: E402,F401
from collections import defaultdict

j, b = load(sys.argv[1])
for mi, m in enumerate(j["meshes"]):
    for pi, p in enumerate(m["primitives"]):
        print(
            mi,
            pi,
            m.get("name"),
            j["materials"][p["material"]].get("name") if "material" in p else "-",
            j["accessors"][p["attributes"]["POSITION"]]["count"],
            j["accessors"][p["indices"]]["count"] // 3,
        )
sk = j["meshes"][4]["primitives"][0]
P = acc(j, b, sk["attributes"]["POSITION"]).astype(float)
F = acc(j, b, sk["indices"]).reshape(-1, 3).astype(np.int64)
q = np.round(P / 1e-4).astype(np.int64)
_, wid = np.unique(q, axis=0, return_inverse=True)
wid = wid.ravel()
Fw = wid[F]
E = np.sort(np.concatenate([Fw[:, [0, 1]], Fw[:, [1, 2]], Fw[:, [2, 0]]]), 1)
ue, cnt = np.unique(E, axis=0, return_counts=True)
bnd = ue[cnt == 1]
print("welded verts", wid.max() + 1, "edges", len(ue), "boundary", len(bnd), "nonmanifold(>2)", (cnt > 2).sum())
Pw = np.zeros((wid.max() + 1, 3))
Pw[wid] = P
adj = defaultdict(list)
for a, c in bnd:
    adj[a].append(c)
    adj[c].append(a)
seen = set()
loops = []
for s in adj:
    if s in seen:
        continue
    st = [s]
    comp = []
    while st:
        v = st.pop()
        if v in seen:
            continue
        seen.add(v)
        comp.append(v)
        st += adj[v]
    loops.append(comp)
loops.sort(key=len, reverse=True)
print("loops", len(loops))
for L in loops[:25]:
    X = Pw[L]
    print(
        f"n {len(L):5d} y {X[:, 1].min():.3f}-{X[:, 1].max():.3f} x {X[:, 0].min():+.3f}..{X[:, 0].max():+.3f} z {X[:, 2].min():+.3f}..{X[:, 2].max():+.3f} span {np.ptp(X, 0).max() * 100:.1f}cm"
    )
sz = np.array([len(L) for L in loops])
print(
    "loop size hist <=4",
    (sz <= 4).sum(),
    "5-20",
    ((sz > 4) & (sz <= 20)).sum(),
    "21-100",
    ((sz > 20) & (sz <= 100)).sum(),
    ">100",
    (sz > 100).sum(),
)
