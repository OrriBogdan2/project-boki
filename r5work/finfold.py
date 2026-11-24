import json,sys,numpy as np
from glbp import *
j,b=load('r4.glb'); P=json.load(open('probe_r4.json'))
names=P['bones']
def M4(a):
    a=np.array(a).reshape(-1,4,3); o=np.tile(np.eye(4),(len(a),1,1)); o[:,:3,:3]=a[:,:3,:].transpose(0,2,1); o[:,:3,3]=a[:,3]; return o
rest=M4(P['rest'])
pr=prims(j,b)
pos=np.concatenate([x[0] for x in pr]); off=np.cumsum([0]+[len(x[0]) for x in pr])
idx=np.concatenate([x[1]+off[i] for i,x in enumerate(pr)])
J=np.concatenate([acc(j,b,x[3]['attributes']['JOINTS_0']) for x in pr]).astype(int); W=np.concatenate([acc(j,b,x[3]['attributes']['WEIGHTS_0']) for x in pr])
sk=j['skins'][0]['joints']; jn=[j['nodes'][i]['name'] for i in sk]
m=[names.index(n) for n in jn]  # map skin joint -> probe bone idx
print(len(pos),len(idx),jn[:3],rest.shape)
# fin region: head-dominant, behind (z<0), y>1.25
main=J[np.arange(len(J)),W.argmax(1)]
hb=np.array([jn[k]=='Head' for k in main])
fin=hb&(pos[:,2]<-0.02)&(pos[:,1]>1.25)
print('fin verts',fin.sum(), 'bbox',pos[fin].min(0),pos[fin].max(0))
def skinned(frame):
    pose=M4(frame['pose'])
    out=np.zeros_like(pos); ph=np.c_[pos,np.ones(len(pos))]
    for k in range(4):
        M=np.array([pose[m[a]]@np.linalg.inv(rest[m[a]]) for a in J[:,k]])
        out+=W[:,k:k+1]*np.einsum('nij,nj->ni',M,ph)[:,:3]
    return out
def fn(v):
    a,b_,c=v[idx[:,0]],v[idx[:,1]],v[idx[:,2]]; n=np.cross(b_-a,c-a); ar=np.linalg.norm(n,axis=1); return n/np.maximum(ar[:,None],1e-12),ar/2
n0,a0=fn(pos)
ff=fin[idx].any(1)
print('fin faces',ff.sum())
for cl in ('Idle','idle','Jump_Run','Attack','run'):
    fr=[f for f in P['frames'] if f['clip']==cl]
    if not fr: continue
    for f in fr[:: max(1,len(fr)//4)]:
        v=skinned(f); Hm=np.linalg.inv(M4(f['pose'])[names.index('Head')]@np.linalg.inv(rest[names.index('Head')])); v=(Hm[:3,:3]@v.T).T+Hm[:3,3]; n1,a1=fn(v)
        dot=(n0*n1).sum(1)
        fl=(dot<0)&ff; ratio=a1/np.maximum(a0,1e-12)
        print(cl,f['i'],'flipped fin faces',fl.sum(),'area ratio min/max (fin)',np.percentile(ratio[ff],[1,50,99]).round(2),'maxdisp',np.linalg.norm(v-pos,axis=1)[fin].max().round(3),'flipped total',((dot<0)).sum())
