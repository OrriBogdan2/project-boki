# seethru.py GLB [yaws=-45,0,45] : game-camera "ground seen through the skirt" share. Camera (0,21,9.4)->(0,0.8,0) (near-ortho, fov 8).
# Per clip, per frame (10 fps), per model yaw: hull = convex hull of the skirt's projection below the waist band; covered = raster of
# ALL character prims (skirt, lining, legs, body, liners); seethru = (hull - covered)/hull. A slit V that shows the ground counts here.
import sys,numpy as np
from scipy.spatial import ConvexHull
from scipy.ndimage import binary_closing
from scipy.spatial import Delaunay
sys.path.insert(0,'tools/anim'); import geo_check as g
j,b=g.read_glb(sys.argv[1]); rig=g.Rig(j,b); yaws=[float(x) for x in (sys.argv[2] if len(sys.argv)>2 else '-45,0,45').split(',')]
PR=[]
for me in j['meshes']:
    for p in me['primitives']:
        mn=j['materials'][p['material']]['name']
        if mn not in ('skirt-meshy','skirt-lining23','leg-meshy','body-retex','skirt-liner','thigh-liner','body-hand17'): continue
        A=lambda k: g.accessor(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
        J=[A('JOINTS_0')]; W=[A('WEIGHTS_0')]
        if 'JOINTS_1' in p['attributes']: J.append(A('JOINTS_1')); W.append(A('WEIGHTS_1'))
        J=np.hstack(J).astype(int); W=np.hstack(W).astype(float); F=g.accessor(j,b,p['indices'])[:,0].astype(np.int64).reshape(-1,3)
        n=max(20000,len(F)*3); rng=np.random.default_rng(len(F)); fi=rng.integers(0,len(F),n); u=rng.random((n,2)); m=u.sum(1)>1; u[m]=1-u[m]
        PR.append((mn,P,J,W,F,fi,u))
def skin(S,P,J,W):
    X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(J.shape[1]): o+=W[:,k,None]*np.einsum('vij,vj->vi',S[J[:,k]][:,:3,:],X)
    return o
cam=np.array([0,21,9.4]); tgt=np.array([0,0.8,0]); d=(tgt-cam)/np.linalg.norm(tgt-cam); ux=np.cross(d,[0,1,0]); ux/=np.linalg.norm(ux); uy=np.cross(ux,d)
R=0.01; out={}
import os; DUMP=os.environ.get('DUMP'); DUMP=(DUMP.split(':')[0],float(DUMP.split(':')[1]),float(DUMP.split(':')[2]),DUMP.split(':')[3]) if DUMP else None
for an in j['animations']:
    Tm=max(g.accessor(j,b,an['samplers'][c['sampler']]['input'])[:,0].max() for c in an['channels'])
    T=np.unique(np.r_[np.arange(0,Tm,0.1),Tm]); S=rig.skin_mats(an,T); vals=[]
    for f in range(len(T)):
        pts={}
        for mn,P,J,W,F,fi,u in PR:
            V=skin(S[f],P,J,W); X=V[F[fi,0]]+(V[F[fi,1]]-V[F[fi,0]])*u[:,:1]+(V[F[fi,2]]-V[F[fi,0]])*u[:,1:]; pts.setdefault(mn=='skirt-meshy',[]).append(X)
        sk=np.vstack(pts[True]); al=np.vstack(pts[True]+pts[False]); ytop=sk[:,1].max()-0.12; sk=sk[sk[:,1]<ytop]
        for yw in yaws:
            c,s=np.cos(np.radians(yw)),np.sin(np.radians(yw)); Ry=np.array([[c,0,s],[0,1,0],[-s,0,c]])
            q=lambda X: np.c_[(X@Ry.T)@ux,(X@Ry.T)@uy]
            qs=q(sk); qa=q(al); lo=qs.min(0)-0.05; hi=qs.max(0)+0.05; sh=((hi-lo)/R).astype(int)+1
            im=np.zeros(sh,bool); ga=((qa-lo)/R).astype(int); ok=(ga>=0).all(1)&(ga<sh).all(1); im[ga[ok,0],ga[ok,1]]=True; im=binary_closing(im,np.ones((3,3)))
            hull=ConvexHull(qs); hp=Delaunay(qs[hull.vertices]); gx,gy=np.mgrid[0:sh[0],0:sh[1]]; cen=np.c_[gx.ravel(),gy.ravel()]*R+lo+R/2
            inh=(hp.find_simplex(cen)>=0).reshape(sh); vals.append(((inh&~im).sum()/max(inh.sum(),1),yw,f))
            if DUMP and an['name'].startswith(DUMP[0]) and abs(T[f]-DUMP[1])<0.051 and yw==DUMP[2]:
                from PIL import Image; rgb=np.zeros(tuple(sh)+(3,),np.uint8); rgb[im]=(200,60,60); rgb[inh&~im]=(0,255,0); Image.fromarray(np.flipud(rgb.transpose(1,0,2))).resize((sh[0]*3,sh[1]*3)).save(DUMP[3]); print('dumped',DUMP[3])
    v=np.array([x[0] for x in vals]); w=max(vals); out[an['name']]=(v.mean(),w)
    print('%-34s seethru mean %.3f  max %.3f (yaw %+.0f, t %.1f)'%(an['name'][:34],v.mean(),w[0],w[1],T[w[2]]),flush=True)
print('MEAN all clips %.3f'%np.mean([x[0] for x in out.values()]))
