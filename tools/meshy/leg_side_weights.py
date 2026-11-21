# Blender (from the repo root): blender -b --factory-startup --python tools/meshy/leg_side_weights.py -- grafted.glb in.npz out.npz [ZC]
# After leg_graft.py + tools/art1/rig_test/mkweights.py (bone heat): cleans the weights of the NEW (cloth-v95p) trouser verts only.
# No arm bones (a hanging hand's reach is not the pants'); below ZC each connected leg piece keeps only its own leg's bones
# (the side is the piece's mean x, not each vertex's: the legs nearly touch, so an inner wall crosses x=0). Patch with patchglb.py.
import sys; sys.path.insert(0,'tools/art1/rig_test')
from rigkit import *
import numpy as np
a=sys.argv[sys.argv.index('--')+1:]; ZC=float(a[3]) if len(a)>3 else 1.0
arm,body,ms=load(a[0]); me=body.data
d=dict(np.load(a[1])); names=list(d['names']); W=d['W'].copy(); P=d['P']
co=np.array([v.co[:] for v in me.vertices]); assert np.abs(co-P).max()<1e-4
new=np.zeros(len(P),bool)
for p in me.polygons:
    if 'v95p' in me.materials[p.material_index].name: new[list(p.vertices)]=True
E=edges(body)
leg=lambda s: np.array([n.split('.')[0] in ('thigh','shin','foot','x_foot') and n.endswith(s) for n in names])
legL,legR=leg('.L'),leg('.R'); armb=np.array([n.startswith(('upper_arm','forearm','hand')) for n in names])
# weld by position so UV-split duplicates vote together
key={}; grp=np.array([key.setdefault(tuple(np.round(c,5)),i) for i,c in enumerate(P)])
act=new&(P[:,2]<ZC)
# components of welded NEW verts below ZC: one side per component (sign of its mean x); tiny/ambiguous comps fall back to per-vert x sign
par=np.arange(len(P))
def f(i):
    while par[i]!=i: par[i]=par[par[i]]; i=par[i]
    return i
for i,g in enumerate(grp): par[f(i)]=f(g)
for u,v in E:
    if act[u] and act[v]: par[f(u)]=f(v)
root=np.array([f(i) for i in range(len(P))])
side=np.sign(P[:,0]).astype(float)
import collections
cs=collections.Counter(root[act])
for r,n in cs.most_common():
    m=act&(root==r); mx=P[m,0].mean()
    if n>=30: side[m]=np.sign(mx)
    if n>=30: print('comp',n,'meanx %.3f'%mx,'z %.2f-%.2f'%(P[m,2].min(),P[m,2].max()),'x %.3f..%.3f'%(P[m,0].min(),P[m,0].max()))
print('comps',len(cs))
Wn=W[new].copy(); s=side[new]; lo=act[new]
Wn[:,armb]=0
Wn[np.ix_(lo&(s<0),legR)]=0; Wn[np.ix_(lo&(s>0),legL)]=0
bad=Wn.sum(1)<1e-6; z=P[new,2]
for k in np.where(bad)[0]:
    Wn[k,names.index(('thigh' if z[k]>0.696 else 'shin')+('.L' if s[k]<0 else '.R'))]=1
Wn/=Wn.sum(1,keepdims=True)
print('NEW',int(new.sum()),'fallback',int(bad.sum()),'L',int((s<0).sum()),'R',int((s>0).sum()))
W[new]=Wn; d['W']=W; np.savez(a[2],**d)
