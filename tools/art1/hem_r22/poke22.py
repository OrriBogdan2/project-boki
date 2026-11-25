# poke22.py GLB [out.npz] : body/leg points that poke OUT through the skirt in every clip frame (8-influence skinning, which
# geo_check does not read for the skirt). Cylinder test around the hip axis: per (angle, height) bin, the skirt's outer radius
# (from dense triangle samples); a body vertex whose radius is beyond it by > 2 mm in a bin the skirt covers is poking out.
# Bins with no skirt (the slit) are skipped. Prints per clip: frames, poked verts (max), worst depth, and the rest-pose
# height band of the poking verts.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); import geo_check as g
src=sys.argv[1]; j,b=g.read_glb(src); rig=g.Rig(j,b)
def prim_data(p):
    A=lambda k: g.accessor(j,b,p['attributes'][k]).astype(float) if k in p['attributes'] else None
    P=A('POSITION'); J=[A('JOINTS_0').astype(int)]; W=[A('WEIGHTS_0')]
    if 'JOINTS_1' in p['attributes']: J.append(A('JOINTS_1').astype(int)); W.append(A('WEIGHTS_1'))
    F=g.accessor(j,b,p['indices'])[:,0].astype(np.int64).reshape(-1,3); return P,np.hstack(J),np.hstack(W),F
sk=bd=None; parts=[]
for m in j['meshes']:
    for p in m['primitives']:
        mn=j['materials'][p['material']]['name']
        if mn=='skirt-meshy': sk=prim_data(p)
        elif mn in ('body-retex','leg-meshy'): parts.append(prim_data(p))
P=np.vstack([q[0] for q in parts]); J=np.vstack([np.pad(q[1],((0,0),(0,8-q[1].shape[1]))) for q in parts]); W=np.vstack([np.pad(q[2],((0,0),(0,8-q[2].shape[1]))) for q in parts])
def skin(S,P,J,W):
    X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(J.shape[1]):
        m=S[J[:,k]]; o+=W[:,k,None]*np.einsum('vij,vj->vi',m[:,:3,:],X)
    return o
hip=rig.names.index('Hips'); rng=np.random.default_rng(0)
sP,sJ,sW,sF=sk; ns=200000; fi=rng.integers(0,len(sF),ns); u=rng.random((ns,2)); mm=u.sum(1)>1; u[mm]=1-u[mm]
dom=np.array(rig.names)[J[np.arange(len(J)),W.argmax(1)]]
sel_body=(P[:,1]>0.45)&(P[:,1]<0.98)&np.isin(dom,['Hips','LeftUpLeg','RightUpLeg'])   # rest height band under the skirt (hem tips 0.30; legs below the knee are mostly seen)
pb=P[sel_body]; jb=J[sel_body]; wb=W[sel_body]
NA,NH=96,60; res={}
for an in j['animations']:
    T=g.accessor(j,b,an['samplers'][0]['input'])[:,0].astype(float); tt=np.arange(0,T.max()+1e-6,1/15)
    S=rig.skin_mats(an,tt); G=None
    worst=[]; pokedv=np.zeros(len(pb),bool)
    for fi_,Sf in enumerate(S):
        sv=skin(Sf,sP,sJ,sW); X=sv[sF[fi,0]]+(sv[sF[fi,1]]-sv[sF[fi,0]])*u[:,:1]+(sv[sF[fi,2]]-sv[sF[fi,0]])*u[:,1:]
        # axis: hips joint world position
        Hm=(Sf[hip]@np.linalg.inv(rig.ibm[hip]))[:3,3]
        y0,y1=X[:,1].min(),X[:,1].max()
        def bins(Y):
            a=((np.arctan2(Y[:,0]-Hm[0],Y[:,2]-Hm[2])+np.pi)/(2*np.pi)*NA).astype(int)%NA
            h=np.clip(((Y[:,1]-y0)/(y1-y0+1e-9)*NH).astype(int),-1,NH); return a,h,np.hypot(Y[:,0]-Hm[0],Y[:,2]-Hm[2])
        a,h,r=bins(X); R=np.full((NA,NH),-1.0); np.maximum.at(R,(a,np.clip(h,0,NH-1)),r)
        B=skin(Sf,pb,jb,wb); a2,h2,r2=bins(B); ok=(h2>=0)&(h2<NH)
        rr=np.where(ok,R[a2,np.clip(h2,0,NH-1)],-1); d=np.where(rr>0,r2-rr,-1)
        # need the skirt present in the bin and its neighbours (not a slit edge)
        pk=d>0.002; pokedv|=pk; worst.append((pk.sum(),d.max()*100 if pk.any() else 0))
    w=np.array(worst); f_=int(w[:,0].argmax())
    hb=pb[pokedv,1]
    print('%-24s frames %3d  poked-frames %3d  max verts %4d (f%d)  worst %.1f cm  rest y of poked: %s'%(an['name'],len(tt),(w[:,0]>0).sum(),w[:,0].max(),f_,w[:,1].max(),
          ('%.2f..%.2f med %.2f n %d'%(hb.min(),hb.max(),np.median(hb),len(hb))) if len(hb) else '-'))
    res[an['name']]=pokedv
if len(sys.argv)>2: np.savez(sys.argv[2],sel=np.where(sel_body)[0],**res)
