"""fishfit.py probe.json: fish-vs-body penetration per clip for the current grip, and an offline search of the
fish's placement in the RightHand bone frame (rotation + slide) that keeps the grip at the fist and clears the body."""
import json, sys, numpy as np
J = json.load(open(sys.argv[1]))
names = J["bones"]; par = J["parents"]; idx = {n: i for i, n in enumerate(names)}
def M(a):
    a = np.array(a); T = np.eye(4); T[:3,0]=a[0:3]; T[:3,1]=a[3:6]; T[:3,2]=a[6:9]; T[:3,3]=a[9:12]; return T
rest = [M(r) for r in J["rest"]]
EXCL = {"RightHand","RightForeArm"}
# capsules: segment bone origin -> mean child origin, radius = 80th pct of bind verts distance to the segment
kids = {i: [] for i in range(len(names))}
for i, p in enumerate(par):
    if p >= 0: kids[p].append(i)
caps = {}
bind = {}
for n, vs in J["bind_verts"].items():
    b = idx[n]; V = np.array(vs)
    a = rest[b][:3,3]
    c = np.mean([rest[k][:3,3] for k in kids[b]], 0) if kids[b] else V.mean(0)
    ab = c - a; L2 = max(ab @ ab, 1e-9)
    t = np.clip(((V - a) @ ab) / L2, 0, 1)
    d = np.linalg.norm(V - (a + t[:,None]*ab), axis=1)
    r = float(np.percentile(d, 70))
    caps[b] = (np.linalg.inv(rest[b]) @ np.append(a,1), np.linalg.inv(rest[b]) @ np.append(c,1), r)  # in bone frame
    bind[b] = V
H = idx["RightHand"]
fv = np.array(J["fish_verts"])
frames = J["frames"]
CL = ["idle","run","dash","jump","attack","hit"]
posesM = [[M(p) for p in f["pose"]] for f in frames]
Fcur = M(frames[0]["fish"])

def pen(F, fr_idx):
    """penetration depth (m) per fish vertex at frame: max over non-arm capsules of r - dist-to-segment"""
    P = posesM[fr_idx]
    Wf = (P[H] @ F @ np.c_[fv, np.ones(len(fv))].T).T[:,:3]
    fist = P[H][:3,3]
    out = np.zeros(len(Wf))
    for b,(a,c,r) in caps.items():
        if names[b] in EXCL or names[b].startswith("Right") and names[b] not in ("RightUpLeg","RightLeg","RightFoot","RightToeBase"): continue
        A = (P[b] @ a)[:3]; C = (P[b] @ c)[:3]
        ab = C-A; L2 = max(ab@ab,1e-9)
        t = np.clip(((Wf-A)@ab)/L2,0,1)
        d = np.linalg.norm(Wf-(A+t[:,None]*ab),axis=1)
        out = np.maximum(out, r-d)
    near = np.linalg.norm(Wf-fist,axis=1) < 0.18   # the held part itself is allowed in the hand
    out[near] = 0
    return out

def score(F, sel=None, per_clip=False):
    res = {c: [] for c in CL}
    for fi, f in enumerate(frames):
        if sel is not None and f["clip"] not in sel: continue
        p = pen(F, fi)
        res[f["clip"]].append((p > 0.03).sum() + 3*(p > 0.12).sum())
    return res if per_clip else sum(sum(v) for v in res.values())

if __name__ == "__main__":
    r = score(Fcur, per_clip=True)
    print("current", {c: (round(float(np.mean(v)),1), int(np.max(v))) for c, v in r.items() if v})
