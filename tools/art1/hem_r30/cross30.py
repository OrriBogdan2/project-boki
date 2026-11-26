# cross30.py GLB : Lace r30 "thigh shards" measure. The slit's inner panel (godet = the small skirt-lining23 prim, < 5000 verts)
# vs the right thigh (leg-meshy verts, RightUpLeg-dominant, rest y 0.45..0.88). Cylinder bins (angle, height) around the Hips axis:
# a thigh vert is IN FRONT if its radius beats the godet's radius in that bin by > 2 mm, BEHIND if it is under it.
# Shards = the thigh is split by the panel (both sides present): per clip, frames with >= 5% of the binned thigh verts on the
# minority side, and the worst minority share. Clean = 0 frames (thigh wholly in front of the panel, or wholly behind it).
import sys,numpy as np
sys.path.insert(0,'tools/anim'); import geo_check as g
src=sys.argv[1]; j,b=g.read_glb(src); rig=g.Rig(j,b); names=np.array(rig.names)
def pd(p):
    A=lambda k: g.accessor(j,b,p['attributes'][k]).astype(float)
    J=[A('JOINTS_0').astype(int)]; W=[A('WEIGHTS_0')]
    if 'JOINTS_1' in p['attributes']: J.append(A('JOINTS_1').astype(int)); W.append(A('WEIGHTS_1'))
    J=np.hstack(J); W=np.hstack(W); return A('POSITION'),np.pad(J,((0,0),(0,8-J.shape[1]))),np.pad(W,((0,0),(0,8-W.shape[1])))
gd=lg=None
for m in j['meshes']:
    for p in m['primitives']:
        mn=j['materials'][p['material']]['name']; n=j['accessors'][p['attributes']['POSITION']]['count']
        if mn.startswith('skirt-godet') or (mn.startswith('skirt-lining') and n<5000): gd=pd(p)
        if mn=='leg-meshy': lg=pd(p)
assert gd is not None and lg is not None
P,J,W=lg; dom=names[J[np.arange(len(J)),W.argmax(1)]]
sel=(dom=='RightUpLeg')&(P[:,1]>0.45)&(P[:,1]<0.88); lg=(P[sel],J[sel],W[sel])
def skin(S,q):
    P,J,W=q; X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(8): o+=W[:,k,None]*np.einsum('vij,vj->vi',S[J[:,k]][:,:3,:],X)
    return o
hip=list(names).index('Hips'); NA,NH=180,40
for an in j['animations']:
    T=g.accessor(j,b,an['samplers'][0]['input'])[:,0].astype(float); tt=np.arange(0,T.max()+1e-6,1/15); S=rig.skin_mats(an,tt)
    bad=0; worst=0; front=[]
    for Sf in S:
        H=(Sf[hip]@np.linalg.inv(rig.ibm[hip]))[:3,3]; G=skin(Sf,gd); L=skin(Sf,lg)
        def bins(Y): return ((np.arctan2(Y[:,0]-H[0],Y[:,2]-H[2])+np.pi)/(2*np.pi)*NA).astype(int)%NA, np.clip(((Y[:,1]-0.25)/0.75*NH).astype(int),0,NH-1), np.hypot(Y[:,0]-H[0],Y[:,2]-H[2])
        a,h,r=bins(G); R=np.full((NA,NH),np.nan); 
        for aa,hh,rr in zip(a,h,r): R[aa,hh]=rr if np.isnan(R[aa,hh]) else min(R[aa,hh],rr)
        a2,h2,r2=bins(L); rg=R[a2,h2]; ok=~np.isnan(rg)
        if ok.sum()<20: front.append(np.nan); continue
        fr=(r2[ok]>rg[ok]+0.002).mean(); front.append(fr); mn=min(fr,1-fr)
        if mn>=0.05: bad+=1
        worst=max(worst,mn)
    print('%-24s frames %3d  shard-frames %3d  worst minority %.2f  thigh-in-front median %.2f'%(an['name'],len(tt),bad,worst,np.nanmedian(front) if np.any(~np.isnan(front)) else -1))
