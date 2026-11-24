"""clear.py probe.json glb: per frame min distance (m) from the held fish's verts to the Head-bone mesh (hat + head + fin), per clip."""
import sys,json; sys.path.insert(0,'/home/boki/cj/20261122-122823-a2/tree/r5work')
import glbp,numpy as np
from scipy.spatial import cKDTree
pj=json.load(open(sys.argv[1])); gl=sys.argv[2]
names=pj['bones']; idx={n:i for i,n in enumerate(names)}
def M(a):
    a=np.array(a);T=np.eye(4);T[:3,0]=a[0:3];T[:3,1]=a[3:6];T[:3,2]=a[6:9];T[:3,3]=a[9:12];return T
rest=[M(r) for r in pj['rest']]
j,b=glbp.load(gl)
P=[];Jn=[];W=[]
for pr in j['meshes'][0]['primitives']:
    P.append(glbp.acc(j,b,pr['attributes']['POSITION']));Jn.append(glbp.acc(j,b,pr['attributes']['JOINTS_0']).astype(int));W.append(glbp.acc(j,b,pr['attributes']['WEIGHTS_0']))
P=np.concatenate(P);Jn=np.concatenate(Jn);W=np.concatenate(W)
jn=[j['nodes'][i]['name'] for i in j['skins'][0]['joints']]
hi=jn.index('Head'); wh=(W*(Jn==hi)).sum(1)
hv=P[wh>0.5]; print('head verts',len(hv))
H=idx['RightHand'];HD=idx['Head']
fv=np.array(pj['fish_verts']);
res={}
for fi,f in enumerate(pj['frames']):
    pose=[M(p) for p in f['pose']]
    S=pose[HD]@np.linalg.inv(rest[HD])
    hw=(S[:3,:3]@hv.T).T+S[:3,3]
    F=M(f['fish']); Wf=(pose[H]@F@np.c_[fv,np.ones(len(fv))].T).T[:,:3]
    d,_=cKDTree(hw).query(Wf)
    res.setdefault(f['clip'],[]).append(float(d.min()))
for c,v in res.items(): print(c,'frames',len(v),'min clearance %.3f'%min(v),'frames<5cm',sum(1 for x in v if x<0.05), 'idx of min',int(np.argmin(v)))
