# slit34.py GLB : Lace r34 slit-lobe metric. Per clip, the skirt verts the slit bones (SkirtSlitA/B) dominate vs the rest of the
# skirt: how far the slit panel swings off its Hips-rigid place (p95 cm) and how far it sticks out past the skirt hull around it
# (radius from the hip axis minus the p90 radius of non-slit skirt verts in the same 20-deg x 5 cm bin; p95 cm, >0 = a lobe).
import sys,numpy as np
sys.path.insert(0,'tools/anim'); import geo_check as g
j,b=g.read_glb(sys.argv[1]); rig=g.Rig(j,b); N=np.array(rig.names)
p=[p for m in j['meshes'] for p in m['primitives'] if j['materials'][p['material']]['name']=='cloth-skirtmeshy'][0]
A=lambda k: g.accessor(j,b,p['attributes'][k]).astype(float)
P=A('POSITION'); J=[A('JOINTS_0').astype(int)]; W=[A('WEIGHTS_0')]
if 'JOINTS_1' in p['attributes']: J.append(A('JOINTS_1').astype(int)); W.append(A('WEIGHTS_1'))
J=np.hstack(J); W=np.hstack(W); dom=N[J[np.arange(len(J)),W.argmax(1)]]
sl=np.isin(dom,['SkirtSlitA','SkirtSlitB']); hip=rig.names.index('Hips')
def skin(S):
    X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(J.shape[1]): o+=W[:,k,None]*np.einsum('vij,vj->vi',S[J[:,k]][:,:3,:],X)
    return o
print('slit verts',sl.sum(),'of',len(P))
for an in j['animations']:
    T=g.accessor(j,b,an['samplers'][0]['input'])[:,0].astype(float); tt=np.arange(0,T.max()+1e-6,1/15); S=rig.skin_mats(an,tt)
    off=[];lobe=[]
    for Sf in S:
        H=Sf[hip]; X=skin(Sf); R=(H@np.c_[P,np.ones(len(P))].T).T[:,:3]   # Hips-rigid
        off.append(np.percentile(np.linalg.norm(X[sl]-R[sl],axis=1),95))
        Hm=(H@np.linalg.inv(rig.ibm[hip]))[:3,3]; d=X-Hm; ang=((np.arctan2(d[:,0],d[:,2])+np.pi)/np.radians(20)).astype(int); hy=(d[:,1]/0.05).astype(int); r=np.hypot(d[:,0],d[:,2])
        key=ang*1000+hy; ex=[]
        for k in np.unique(key[sl]):
            o=(key==k)&~sl
            if o.sum()>=5: ex.append(r[(key==k)&sl].max()-np.percentile(r[o],90))
        lobe.append(np.percentile(ex,95) if ex else 0)
    print('%-24s slit off p95 %.1f cm (max f %.1f)  lobe p95 %.1f cm (max %.1f)'%(an['name'],np.mean(off)*100,np.max(off)*100,np.mean(lobe)*100,np.max(lobe)*100))
