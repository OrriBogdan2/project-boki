"""armfix.py IN.glb PROBE.json BEST.npy CLIP OUT.json: FK of the glb clip; per frame, small right-arm rotation deltas
(RightArm, RightForeArm; wrist keeps its local rotation) that clear the fish from the body, smoothed; writes the new
local rotation keys for those two bones (and a before/after penetration report)."""
import json, struct, sys, numpy as np
src, probe, bestf, clip, outf = sys.argv[1:6]
sys.argv = [sys.argv[0], probe]
exec(open(__import__("os").path.join(__import__("os").path.dirname(__file__), "fishsearch.py")).read().split("sub = list")[0])
best = np.load(bestf); Fnew = build(best)
b = open(src, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; G = json.loads(b[20:20+n]); bl = b[20+n+8:]
nodes = G["nodes"]; byname = {x.get("name"): i for i, x in enumerate(nodes)}
gpar = {}
for i, x in enumerate(nodes):
    for c in x.get("children", []): gpar[c] = i
def acc(ai):
    a = G["accessors"][ai]; bv = G["bufferViews"][a["bufferView"]]
    k = {"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]]; o = bv.get("byteOffset",0)+a.get("byteOffset",0)
    return np.frombuffer(bl, "<f4", a["count"]*k, o).reshape(a["count"], k)
an = [a for a in G["animations"] if a["name"] == clip][0]
ch = {}
for c in an["channels"]:
    s = an["samplers"][c["sampler"]]; ch[(c["target"]["node"], c["target"]["path"])] = (acc(s["input"])[:,0], acc(s["output"]))
NF = len(ch[(byname["Hips"], "rotation")][0])
def q2m(q):
    x,y,z,w = q; return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def m2q(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t+1)*2; q = [(m[2,1]-m[1,2])/s,(m[0,2]-m[2,0])/s,(m[1,0]-m[0,1])/s,s/4]
    else:
        i = np.argmax(np.diag(m)); j=(i+1)%3; k=(i+2)%3
        s = np.sqrt(m[i,i]-m[j,j]-m[k,k]+1)*2; q=[0,0,0,0]; q[i]=s/4; q[j]=(m[j,i]+m[i,j])/s; q[k]=(m[k,i]+m[i,k])/s; q[3]=(m[k,j]-m[j,k])/s
    q = np.array(q); return q/np.linalg.norm(q)
def loc(node, f, rotover=None):
    T = np.eye(4); nd = nodes[node]
    cl = lambda a: a[min(f, len(a)-1)]
    r = cl(ch[(node,"rotation")][1]) if (node,"rotation") in ch else nd.get("rotation",[0,0,0,1])
    if rotover is not None and node in rotover: r = rotover[node]
    t = cl(ch[(node,"translation")][1]) if (node,"translation") in ch else nd.get("translation",[0,0,0])
    s = cl(ch[(node,"scale")][1]) if (node,"scale") in ch else nd.get("scale",[1,1,1])
    T[:3,:3] = q2m(r) @ np.diag(s); T[:3,3] = t; return T
def world(f, rotover=None):
    W = {}
    def go(i):
        if i in W: return W[i]
        p = gpar.get(i); W[i] = (go(p) if p is not None else np.eye(4)) @ loc(i, f, rotover); return W[i]
    for nm in names: go(byname[nm])
    return {nm: W[byname[nm]] for nm in names}
RA, RF, RH = byname["RightArm"], byname["RightForeArm"], byname["RightHand"]
def rotv_(v): return rotv(v)
def pen_at(Wd, F=Fnew):
    P = [Wd[nm] for nm in names]
    Wf = (P[H] @ F @ np.c_[fv, np.ones(len(fv))].T).T[:,:3]
    fist = P[H][:3,3]; out = np.zeros(len(Wf))
    for b_,(a,c,r) in caps.items():
        nmb = names[b_]
        if nmb in EXCL or (nmb.startswith("Right") and nmb not in ("RightUpLeg","RightLeg","RightFoot","RightToeBase")): continue
        A=(P[b_]@a)[:3]; C=(P[b_]@c)[:3]; ab=C-A; L2=max(ab@ab,1e-9)
        t=np.clip(((Wf-A)@ab)/L2,0,1); d=np.linalg.norm(Wf-(A+t[:,None]*ab),axis=1); out=np.maximum(out,r-d)
    out[np.linalg.norm(Wf-fist,axis=1) < 0.18] = 0
    return out
def cost(p):
    return (p > 0.03).sum() + 3*(p > 0.12).sum()
def with_delta(f, x):
    """world matrices with RightArm and RightForeArm local rotations changed by world-frame deltas x[:3], x[3:6]"""
    base = {}
    qa = ch[(RA,"rotation")][1][f]; qf = ch[(RF,"rotation")][1][f]
    W0 = world(f)
    Pw = W0[names[par[idx["RightArm"]]]][:3,:3]      # parent's world rotation
    Ra = rotv(x[:3])
    # arm: local' = Pw^-1 Ra Pw local
    qa2 = m2q(Pw.T @ Ra @ Pw @ q2m(qa))
    Wm = world(f, {RA: qa2})
    Pa = Wm["RightArm"][:3,:3]
    Rf = rotv(x[3:6]); qf2 = m2q(Wm["RightArm"][:3,:3].T @ Rf @ Wm["RightArm"][:3,:3] @ q2m(qf) ) if False else None
    # forearm: delta applied in the arm's local frame (simple): local' = Rloc local, Rloc = rotv(x[3:6])
    qf2 = m2q(rotv(x[3:6]) @ q2m(qf))
    return world(f, {RA: qa2, RF: qf2}), qa2, qf2
import glbp
from scipy.spatial import cKDTree
CLR = float(__import__("os").environ.get("CLR", "0.07"))
_j, _b = glbp.load(src)
_P=[];_J=[];_W=[]
for _pr in _j["meshes"][0]["primitives"]:
    _P.append(glbp.acc(_j,_b,_pr["attributes"]["POSITION"])); _J.append(glbp.acc(_j,_b,_pr["attributes"]["JOINTS_0"]).astype(int)); _W.append(glbp.acc(_j,_b,_pr["attributes"]["WEIGHTS_0"]))
_P=np.concatenate(_P);_J=np.concatenate(_J);_W=np.concatenate(_W)
_jn=[_j["nodes"][i]["name"] for i in _j["skins"][0]["joints"]]
_hv=_P[(_W*(_J==_jn.index("Head"))).sum(1)>0.5]
HTREE=cKDTree(_hv[::3])
HD_=idx["Head"]; Rinv_=np.linalg.inv(rest[HD_])
fvh=np.c_[fv,np.ones(len(fv))].T
def head_d(Wd, F=Fnew):
    Wf=(Wd["RightHand"]@F@fvh)
    Hm=np.linalg.inv(Wd["Head"]@Rinv_)
    pts=(Hm@Wf).T[:,:3]
    return float(HTREE.query(pts)[0].min())
_cost0 = cost
def hcost(Wd):
    return _cost0(pen_at(Wd)) + 600*max(0.0, CLR-head_d(Wd))
res = {"clip": clip, "arm": [], "fore": []}
rng = np.random.default_rng(3)
x = np.zeros(6); before = []; after = []
for f in range(NF):
    W0 = world(f); c0 = hcost(W0); before.append(round(head_d(W0),3))
    cx = lambda y: hcost(with_delta(f, y)[0]) + 40*(y@y) + 60*((y - x)@(y - x))
    s0 = cx(x); bx = x.copy(); sb = s0
    if c0 > 0.5 or s0 > 5:
        for it in range(300):
            cand = bx + rng.normal(0, 0.12 if it < 150 else 0.04, 6)
            sc_ = cx(cand)
            if sc_ < sb: bx, sb = cand, sc_
    x = bx
    Wn, qa2, qf2 = with_delta(f, x); after.append(round(head_d(Wn),3))
    res["arm"].append(qa2.tolist()); res["fore"].append(qf2.tolist())
print("before", before); print("after", after)
res["times"] = ch[(RA,"rotation")][0].tolist(); res["before"] = before; res["after"] = after
json.dump(res, open(outf, "w"))
