# meas24.py GLB : skirt-only shape numbers per clip (15 fps, 8-influence skinning, raw accessors):
#  edges >3x / worst stretch (posed/bind length, bind >= 5 mm) = the "wing" hem tips;
#  notch = game-camera (0,21,9.4)->(0,0.8,0) silhouette of the skirt: (convex hull - filled silhouette) / hull, max over frames
#  = the "trouser" split (a V between the legs is hull area the skirt does not cover).
import sys,numpy as np
from scipy.spatial import ConvexHull
from scipy.ndimage import binary_fill_holes,binary_closing
sys.path.insert(0,'tools/anim'); import geo_check as g
j,b=g.read_glb(sys.argv[1]); rig=g.Rig(j,b)
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: g.accessor(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
Fc=g.accessor(j,b,p['indices'])[:,0].astype(np.int64).reshape(-1,3)
E=np.unique(np.sort(np.r_[Fc[:,[0,1]],Fc[:,[1,2]],Fc[:,[2,0]]],1),axis=0); L0=np.linalg.norm(P[E[:,0]]-P[E[:,1]],axis=1); E=E[L0>=0.005]; L0=L0[L0>=0.005]
cam=np.array([0,21,9.4]); tgt=np.array([0,0.8,0]); d=(tgt-cam)/np.linalg.norm(tgt-cam); ux=np.cross(d,[0,1,0]); ux/=np.linalg.norm(ux); uy=np.cross(ux,d)
rng=np.random.default_rng(1); fi=rng.integers(0,len(Fc),150000); u=rng.random((150000,2)); m=u.sum(1)>1; u[m]=1-u[m]
def skin(S):
    X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(8): o+=W[:,k,None]*np.einsum('vij,vj->vi',S[J[:,k]][:,:3,:],X)
    return o
tot=0
for an in j['animations']:
    Tm=max(g.accessor(j,b,an['samplers'][c['sampler']]['input'])[:,0].max() for c in an['channels'])
    T=np.unique(np.r_[np.arange(0,Tm,1/15),Tm]); S=rig.skin_mats(an,T); worst=0; n3=0; notch=0; nf=0
    for f in range(len(T)):
        V=skin(S[f]); r=np.linalg.norm(V[E[:,0]]-V[E[:,1]],axis=1)/L0; worst=max(worst,r.max()); n3=max(n3,(r>3).sum())
        X=V[Fc[fi,0]]+(V[Fc[fi,1]]-V[Fc[fi,0]])*u[:,:1]+(V[Fc[fi,2]]-V[Fc[fi,0]])*u[:,1:]
        q=np.c_[X@ux,X@uy]; q-=q.min(0); g2=(q/0.01).astype(int); im=np.zeros(g2.max(0)+3,bool); im[g2[:,0]+1,g2[:,1]+1]=True
        im=binary_fill_holes(binary_closing(im,np.ones((3,3)))); hull=ConvexHull(q).volume/1e-4
        nt=max(0,(hull-im.sum())/hull); notch=max(notch,nt); nf=f if nt>=notch else nf
    print('%-24s edges>3x(max frame) %5d  worst x%5.2f  notch max %.3f (f%d)'%(an['name'],n3,worst,notch,nf)); tot+=n3
print('sum edges>3x', tot)
