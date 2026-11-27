# sep32.py GLB [r=0.02 ymin=0.55] : Lace r32 "panels part" measure. Outer-skirt vert pairs that are within r at rest (any island,
# so stacked/adjacent panels count) and above rest y ymin; per clip (24 frames) the posed distance growth. Prints p99 growth and
# the number of pairs that open by > 5 cm / > 10 cm in the worst frame. A joined skirt keeps these near 0.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial import cKDTree
src=sys.argv[1]; O=dict(a.split('=') for a in sys.argv[2:]); r=float(O.get('r',0.02)); ym=float(O.get('ymin',0.55))
clips=O.get('clips','Jump_Run,run,Idle,Attack,walk').split(',')
j,b=glbio.load(src); rig=g.Rig(j,b)
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='cloth-skirtmeshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
sel=np.where(P[:,1]>ym)[0]; pr=cKDTree(P[sel]).query_pairs(r,output_type='ndarray'); pr=sel[pr]
d0=np.linalg.norm(P[pr[:,0]]-P[pr[:,1]],axis=1); Ph=np.c_[P,np.ones(len(P))]; an={a['name']:a for a in j['animations']}
tot=0
for c in clips:
    a=an[c]; T=max(glbio.acc(j,b,s['input']).max() for s in [a['samplers'][ch['sampler']] for ch in a['channels']])
    S=rig.skin_mats(a,np.linspace(0,T,24)); worst=np.zeros(len(pr))
    for M in S:
        X=np.einsum('vk,vkij,vj->vi',W,M[J],Ph)[:,:3]; worst=np.maximum(worst,np.linalg.norm(X[pr[:,0]]-X[pr[:,1]],axis=1)-d0)
    n5,n10=(worst>0.05).sum(),(worst>0.10).sum(); tot+=n5
    print('%-9s pairs %d  p99 %.3f max %.3f  >5cm %d  >10cm %d'%(c,len(pr),np.percentile(worst,99),worst.max(),n5,n10))
print('sep32 total >5cm',tot)
