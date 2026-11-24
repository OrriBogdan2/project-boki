"""Stretch re-measure straight from the raw accessors (no weld): posed edge / bind edge, bind edges >= 5 mm."""
import sys, numpy as np
from collections import Counter
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[3])
import glb_add_clips, glb_relax
from zerow import acc
j, bin_ = glb_add_clips.read(sys.argv[2])
print("skins", len(j["skins"]), "mesh nodes", [(n.get("name"), n.get("skin")) for n in j["nodes"] if "mesh" in n])
skin = j["skins"][0]; pz, parent = glb_relax.poses(j, bin_, skin)
names = [j["nodes"][jt]["name"] for jt in skin["joints"]]
tot = Counter(); per_clip = {}; pairs = Counter()
for m in j["meshes"]:
    for pi, pr in enumerate(m["primitives"]):
        at = pr["attributes"]
        if "WEIGHTS_0" not in at: continue
        pos = acc(j, bin_, at["POSITION"]); w = acc(j, bin_, at["WEIGHTS_0"]); jt = acc(j, bin_, at["JOINTS_0"]).astype(int)
        w = w / np.maximum(w.sum(1, keepdims=True), 1e-9)
        idx = acc(j, bin_, pr["indices"]).astype(int).reshape(-1, 3)
        e = np.unique(np.sort(np.r_[idx[:, [0, 1]], idx[:, [1, 2]], idx[:, [2, 0]]], axis=1), axis=0)
        bl = np.linalg.norm(pos[e[:, 0]] - pos[e[:, 1]], axis=1); keep = bl >= 0.005; e, bl = e[keep], bl[keep]
        if not len(e): continue
        vh = np.c_[pos, np.ones(len(pos))]; dom = jt[np.arange(len(w)), w.argmax(1)]
        mw = np.zeros(len(e)); mg = np.zeros(len(e)); wc = {}
        for cn, mats in pz:
            cn = cn if isinstance(cn, str) else cn[0]
            M = np.einsum("nk,nkij->nij", w, mats[jt]); p = np.einsum("nij,nj->ni", M[:, :3], vh)
            L = np.linalg.norm(p[e[:, 0]] - p[e[:, 1]], axis=1); r = L / bl
            mw = np.maximum(mw, r); mg = np.maximum(mg, L - bl)
            d = per_clip.setdefault(cn, [0.0, Counter()]); d[0] = max(d[0], float(r.max()))
            wc[cn] = np.maximum(wc.get(cn, 0), r)
        for cn, r in wc.items(): per_clip[cn][1]["o3"] += int((r > 3).sum()); per_clip[cn][1]["o13"] += int((r > 1.3).sum())
        mat = j["materials"][pr["material"]]["name"]
        print("%-15s %-17s edges %6d worst x%5.2f grow %.2fm  >1.3x %5d  >2x %4d  >3x %4d" % (m["name"], mat, len(e), mw.max(), mg.max(), (mw > 1.3).sum(), (mw > 2).sum(), (mw > 3).sum()))
        for k, t in (("edges", len(e)), (">1.3", (mw > 1.3).sum()), (">2", (mw > 2).sum()), (">3", (mw > 3).sum()), (">5", (mw > 5).sum())): tot[k] += int(t)
        pairs.update((names[dom[e[k, 0]]], names[dom[e[k, 1]]]) for k in np.where(mw > 3)[0])
print(dict(tot)); print("top bone pairs >3x:", pairs.most_common(8))
v = sorted(x[0] for x in per_clip.values()); print("clips %d worst x%.2f median x%.2f clips over 3x: %d" % (len(v), v[-1], v[len(v)//2], sum(x > 3 for x in v)))
for k in sorted(per_clip): print("%-26s x%.2f  edges>3x %d  >1.3x %d" % (k, per_clip[k][0], per_clip[k][1]["o3"], per_clip[k][1]["o13"]))
