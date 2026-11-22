"""coathit.py GLB... : per clip at 15 fps, coat verts (>=50% weight on the 16 coat-tail bones) that are below the floor
(bind sole - 1 cm) or inside the leg volume (closer to the UpLeg->Leg / Leg->Foot axis than 85% of the leg's own
median skin radius). Prints worst-frame and mean counts."""

import sys, numpy as np

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import glbstretch as g


def segd(P, A, B):
    ab = B - A
    t = np.clip(((P - A) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (A + t[:, None] * ab), axis=1)


for p in sys.argv[1:]:
    m = g.Model(p)
    N = m.nodes
    nid = {n["name"]: i for i, n in enumerate(N)}
    ix = {n: i for i, n in enumerate(m.names)}
    coat = [ix[f"Bone_{k:03d}"] for k in range(6, 14)]
    wc = sum((m.W * (m.J == c)).sum(1) for c in coat)
    C = wc >= 0.5

    def G(over):
        Gm = {}

        def f(i):
            if i not in Gm:
                L = g.local(N[i], over.get(i, {}))
                Gm[i] = f(m.par[i]) @ L if i in m.par else L
            return Gm[i]

        return f

    F0 = G({})
    segs = []
    for s in ("Left", "Right"):
        for a, b in ((s + "UpLeg", s + "Leg"), (s + "Leg", s + "Foot")):
            w = (m.W * (m.J == ix[a])).sum(1) > 0.8
            r = np.median(segd(m.bind[w], F0(nid[a])[:3, 3], F0(nid[b])[:3, 3])) * 0.85
            segs.append((a, b, r))
    tot = {}
    for nm, an in m.anims().items():
        T = np.arange(0, m.duration(an) + 1e-6, 1 / 15.0)
        fl, lg = [], []
        for t in T:
            o = m.sample(an, float(t))
            X = m.skin(o)[C]
            F = G(o)
            fl.append(int((X[:, 1] < m.y0 - 0.01).sum()))
            inside = np.zeros(len(X), bool)
            for a, b, r in segs:
                inside |= segd(X, F(nid[a])[:3, 3], F(nid[b])[:3, 3]) < r
            lg.append(int(inside.sum()))
        print(
            f"{p.split('/')[-1]:22s} {nm[:24]:24s} coat verts {C.sum()} | below floor max {max(fl):5d} mean {np.mean(fl):7.1f} | in legs max {max(lg):5d} mean {np.mean(lg):7.1f} | frames w/ >=50 hits {sum(1 for a, b in zip(fl, lg) if a + b >= 50)}/{len(T)}"
        )
