"""fit.py K3 OUT.npz: search roll psi (about the left forearm axis at the wrist), offset t and a fist curl theta so the bow grip runs
through the mirrored right hand's fist tunnel along the knuckle row. Writes T (4x4 placement for graft.py) and theta."""
import sys,numpy as np; sys.path.insert(0,'tools'); from glbio import *
from scipy.spatial.transform import Rotation as Rot
j,b=load(sys.argv[1]); N=j['nodes']; sk=j['skins'][0]; names=[N[n]['name'] for n in sk['joints']]
IB=acc(j,b,sk['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1); G=np.linalg.inv(IB)
par={c:i for i,n in enumerate(N) for c in n.get('children',[])}; n2j={n:k for k,n in enumerate(sk['joints'])}; pj=lambda k:n2j[par[sk['joints'][k]]]
S=np.diag([-1.,1,1,1]); iLH,iRH,iLF=names.index('LeftHand'),names.index('RightHand'),names.index('LeftForeArm')
F4=('Index','Middle','Ring','Pinky')
ch={f:[names.index(f'RightHand{f}{i}') for i in (1,2,3)] for f in F4+('Thumb',)}
# right curl axes (local, right frames) from anim PCA
axis={}
for f,c in ch.items():
    for k in c:
        rest=Rot.from_matrix((np.linalg.inv(G[pj(k)])@G[k])[:3,:3]); D=[]
        for an in j['animations']:
            for cc in an['channels']:
                if cc['target']['node']==sk['joints'][k] and cc['target']['path']=='rotation':
                    D.append((rest.inv()*Rot.from_quat(acc(j,b,an['samplers'][cc['sampler']]['output']))).as_rotvec())
        D=np.concatenate(D); ax=np.linalg.svd(D,full_matrices=False)[2][0]; axis[k]=ax if (D@ax).mean()>0 else -ax
p=j['meshes'][1]['primitives'][2]; A=p['attributes']; P=acc(j,b,A['POSITION']).astype(float)
J=acc(j,b,A['JOINTS_0']).astype(int); W=acc(j,b,A['WEIGHTS_0']).astype(float); dom=J[np.arange(len(J)),W.argmax(1)]
R=[k for k,n in enumerate(names) if 'RightHand' in n]; hv=np.where(np.isin(dom,R))[0]
X=np.c_[P[hv],np.ones(len(hv))]; Jh=J[hv]; Wh=W[hv]
def curl(th,thT):
    Gp={}
    for f,c in ch.items():
        for k in c:
            M=np.linalg.inv(G[pj(k)])@G[k]; M=M.copy(); M[:3,:3]=M[:3,:3]@Rot.from_rotvec(axis[k]*np.radians(thT if f=='Thumb' else th)).as_matrix()
            Gp[k]=Gp.get(pj(k),G[pj(k)])@M
    Ms=np.stack([Gp.get(k,G[k])@IB[k] for k in range(len(names))])
    return np.einsum('nc,ncij,nj->ni',Wh,Ms[Jh],X)[:,:3]
# grip axis (bow verts near the left hand, bind pose)
BP=np.concatenate([acc(j,b,pp['attributes']['POSITION']) for pp in j['meshes'][0]['primitives']]).astype(float)
wL=G[iLH][:3,3]; near=BP[np.linalg.norm(BP-wL,axis=1)<0.10]; mu=near.mean(0); ag=np.linalg.svd(near-mu)[2][0]
print('grip pts',len(near),'grip centre',np.round(mu,3),'axis',np.round(ag,2))
fa=G[iLH][:3,3]-G[iLF][:3,3]; fa/=np.linalg.norm(fa)
T0=G[iLH]@np.linalg.inv(S@G[iRH]@S)
fing=np.isin(dom[hv],[k for f in F4 for k in ch[f][:2]])
kn=lambda: None
best=None
PSIS=[int(x) for x in sys.argv[3].split(',')] if len(sys.argv)>3 else range(-180,180,10)
for th in range(40,101,10):
    Y=curl(th,25); Yh=np.c_[Y,np.ones(len(Y))]
    for psi in PSIS:
        Rr=np.eye(4); Rr[:3,:3]=Rot.from_rotvec(fa*np.radians(psi)).as_matrix(); Tw=np.eye(4); Tw[:3,3]=wL; Ti=np.eye(4); Ti[:3,3]=-wL
        T=Tw@Rr@Ti@T0; Q=(Yh@(T@S).T)[:,:3]
        tc=Q[fing].mean(0)
        k1=(T@S@G[ch['Index'][0]]@S)[:3,3]; k4=(T@S@G[ch['Pinky'][0]]@S)[:3,3]; row=(k1-k4)/np.linalg.norm(k1-k4)
        v=tc-mu; dist=np.linalg.norm(v-(v@ag)*ag); ang=np.degrees(np.arccos(abs(row@ag)))
        sc=dist*100+ang/15
        print('th',th,'psi',psi,'dist %.1f ang %.0f'%(dist*100,ang)) if len(PSIS)<6 else None
        if best is None or sc<best[0]: best=(sc,th,psi,dist*100,ang,T,tc)
sc,th,psi,dist,ang,T,tc=best
# translate so the tunnel centre sits on the grip axis (cap 2.5 cm)
v=tc-mu; off=-(v-(v@ag)*ag); n=np.linalg.norm(off); off=off*min(1,0.025/max(n,1e-9))
Tt=np.eye(4); Tt[:3,3]=off; T=Tt@T
print('best theta',th,'psi',psi,'tunnel-axis dist %.2f cm, row-axis angle %.0f deg, shift %.2f cm'%(dist,ang,np.linalg.norm(off)*100))
np.savez(sys.argv[2],T=T,theta=th,thumb=25,psi=psi)
