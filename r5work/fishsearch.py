import sys, numpy as np, json
sys.argv = [sys.argv[0], sys.argv[1]]
from fishfit import *
rng = np.random.default_rng(1)
Sc = np.diag([1.6, 2.0, 2.2, 1.0])
Rb = np.eye(4); Rb[:3,:3] = Fcur[:3,:3] @ np.diag(1/np.array([1.6,2.0,2.2]))
f = np.array([0.007, 0.115, 0.003])
def rotv(v):
    th = np.linalg.norm(v)
    if th < 1e-9: return np.eye(3)
    k = v/th; K = np.array([[0,-k[2],k[1]],[k[2],0,-k[0]],[-k[1],k[0],0]])
    return np.eye(3)+np.sin(th)*K+(1-np.cos(th))*K@K
def build(x):
    rv, gx = x[:3], x[3]
    g = np.array([gx, -0.03, 0.0])
    R = np.eye(4); R[:3,:3] = rotv(rv)
    Tf = np.eye(4); Tf[:3,3] = f
    Tg = np.eye(4); Tg[:3,3] = -g
    return Tf @ R @ Rb @ Sc @ Tg
sub = list(range(0, len(frames), 3))
def sc(x):
    F = build(x); t = 0
    for fi in sub:
        p = pen(F, fi); t += (p > 0.03).sum() + 3*(p > 0.12).sum()
    return t/len(sub) + 20*np.linalg.norm(x[:3])**2
best = np.array([0,0,0,-0.175]); bs = sc(best)
print("start", bs)
for it in range(400):
    cand = best + rng.normal(0, [0.3,0.3,0.3,0.02]) * (0.5 if it > 200 else 1.0)
    cand[3] = np.clip(cand[3], -0.28, -0.08)
    s = sc(cand)
    if s < bs: best, bs = cand, s
print("best", best.round(3), round(bs,2))
F = build(best)
r = score(F, per_clip=True)
print("after", {c: (round(float(np.mean(v)),1), int(np.max(v))) for c, v in r.items() if v})
np.save("best.npy", best)
# print the fish in the hand frame for the data file: rotation delta as euler and the grip
print("rotvec", best[:3].round(3), "grip part x", best[3].round(3), "deg", np.degrees(np.linalg.norm(best[:3])).round(1))
