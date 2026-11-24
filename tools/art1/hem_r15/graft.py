"""graft.py IN OUT MODE [ICP]: mirror Lace's right hand onto the left wrist (geometry, UV, weights, finger bone rests,
finger anim). MODE: mirror = left finger tracks = mirrored right tracks; delta = old left curl angles about the new
(mirrored right) curl axes. ICP 1 = refine placement on the old left palm."""
import sys,numpy as np; sys.path.insert(0,'tools'); from glbio import *
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as Rot
IN,OUT,MODE=sys.argv[1:4]; ICP=int(sys.argv[4]) if len(sys.argv)>4 else 1
j,b=load(IN); N=j['nodes']; sk=j['skins'][0]; names=[N[n]['name'] for n in sk['joints']]
IBacc=sk['inverseBindMatrices']; IB=acc(j,b,IBacc).reshape(-1,4,4).transpose(0,2,1); G=np.linalg.inv(IB)
S=np.diag([-1.,1,1,1])
L=[i for i,n in enumerate(names) if 'LeftHand' in n]; R=[i for i,n in enumerate(names) if 'RightHand' in n]
r2l={i:names.index(names[i].replace('Right','Left')) for i,n in enumerate(names) if 'Right' in n and names[i].replace('Right','Left') in names}
iLH=names.index('LeftHand'); iRH=names.index('RightHand')
p=j['meshes'][1]['primitives'][2]; A=p['attributes']
P=acc(j,b,A['POSITION']).astype(float); Nr=acc(j,b,A['NORMAL']).astype(float); UV=acc(j,b,A['TEXCOORD_0'])
C0=acc(j,b,A['COLOR_0']); C1=acc(j,b,A['COLOR_1']); J=acc(j,b,A['JOINTS_0']); W=acc(j,b,A['WEIGHTS_0']).astype(float)
F=acc(j,b,p['indices']).reshape(-1,3).astype(np.int64)
dom=J[np.arange(len(J)),W.argmax(1)]
inL=np.isin(dom,L); inR=np.isin(dom,R)
# faces: drop any face touching a left-hand vert; take faces touching a right-hand vert + a forearm tube (TUBE m) above the wrist
TUBE=float(sys.argv[5]) if len(sys.argv)>5 else 0.02; INSET=0.002
iLF=names.index('LeftForeArm'); iRF=names.index('RightForeArm')
def axial(ih,ifa):
    g=G[ih][:3,3]; fa=g-G[ifa][:3,3]; fa/=np.linalg.norm(fa); d=P-g; al=d@fa; return al,np.linalg.norm(d-np.outer(al,fa),axis=1)
alL,rL=axial(iLH,iLF); alR,rR=axial(iRH,iRF)
armL=inL|(dom==iLF); armR=inR|(dom==iRF)
CUTL=-0.025; CUTR=CUTL-TUBE
cutL=armL&(alL>CUTL); dropF=cutL[F].any(1)
takeR=armR&(alR>CUTR); takeF=takeR[F].all(1)|inR[F].any(1)
keepF=F[~dropF]
Rverts=np.unique(F[takeF]); idx={v:k for k,v in enumerate(Rverts)}
tube=~inR[Rverts]&(alR[Rverts]<CUTL)
h=lambda X:np.c_[X,np.ones(len(X))]
GmRH=S@G[iRH]@S; T=G[iLH]@np.linalg.inv(GmRH)
def place(T,X): return (h(X)@(T@S).T)[:,:3]
PR=P[Rverts]
if ICP==1:
    palmL=P[inL]; tree=cKDTree(palmL); sel=~tube
    for it in range(30):
        Q=place(T,PR[sel]); d,nn=tree.query(Q); m=d<np.percentile(d,80)
        a=Q[m]; c=palmL[nn[m]]; ma,mc=a.mean(0),c.mean(0); H=(a-ma).T@(c-mc); U,_,Vt=np.linalg.svd(H)
        Rr=Vt.T@U.T
        if np.linalg.det(Rr)<0: Vt[-1]*=-1; Rr=Vt.T@U.T
        D=np.eye(4); D[:3,:3]=Rr; D[:3,3]=mc-Rr@ma; T=D@T
    print('icp mean nn',round(float(d.mean())*100,2),'cm')
Q=place(T,PR)
if ICP==2:
    secL=armL&(np.abs(alL-(CUTL-0.005))<0.005); cR=Q[(np.abs(alR[Rverts]-(CUTL-0.005))<0.005)].mean(0); sh=P[secL].mean(0)-cR
    print('section shift %.2f cm'%(np.linalg.norm(sh)*100)); D=np.eye(4); D[:3,3]=sh; T=D@T; Q=place(T,PR)
NR=(Nr[Rverts]@(T[:3,:3]@S[:3,:3]).T); NR/=np.linalg.norm(NR,axis=1,keepdims=True)
# push tube + wrist verts inside the kept left forearm surface (INSET), falloff over 1.5 cm into the hand
kv=np.unique(keepF); kv=kv[(P[kv,0]>0.15)&(np.linalg.norm(P[kv]-G[iLH][:3,3],axis=1)<0.15)]
tk=cKDTree(P[kv]); d,nn=tk.query(Q); pn=Nr[kv][nn]; sd=((Q-P[kv][nn])*pn).sum(1)
dW=cKDTree(Q[tube]).query(Q)[0] if tube.any() else np.full(len(Q),1.0)
fall=np.where(tube,1.0,np.clip(1-dW/0.015,0,1))
push=np.maximum(sd+INSET,0)*fall
print('tube verts',tube.sum(),'pushed',(push>1e-4).sum(),'max push %.2f cm'%(push.max()*100))
Q=Q-pn*push[:,None]
JR=J[Rverts].copy(); WR=W[Rverts].copy()
for k in range(4):
    JR[:,k]=[r2l.get(int(x),int(x)) for x in JR[:,k]]
JR[tube]=J[kv][nn[tube]]; WR[tube]=W[kv][nn[tube]]
bad=[names[x] for x in np.unique(JR[WR>0]) if 'Right' in names[x]]; print('unmapped right joints',bad)
newF=np.vectorize(idx.get)(F[takeF])+len(P); newF=newF[:,::-1]
P2=np.r_[P,Q]; N2=np.r_[Nr,NR]; UV2=np.r_[UV,UV[Rverts]]; C02=np.r_[C0,C0[Rverts]]; C12=np.r_[C1,C1[Rverts]]
J2=np.r_[J,JR]; W2=np.r_[W,WR]; F2=np.r_[keepF,newF]
used=np.unique(F2); remap=-np.ones(len(P2),np.int64); remap[used]=np.arange(len(used)); F2=remap[F2]
P2,N2,UV2,C02,C12,J2,W2=[x[used] for x in (P2,N2,UV2,C02,C12,J2,W2)]
print('left drop faces',dropF.sum(),'new faces',takeF.sum(),'verts',len(P2))
assert len(P2)<65535
for key,arr in [('POSITION',P2.astype(np.float32)),('NORMAL',N2.astype(np.float32)),('TEXCOORD_0',UV2),('COLOR_0',C02),('COLOR_1',C12),('JOINTS_0',J2),('WEIGHTS_0',W2.astype(np.float32))]:
    a=j['accessors'][A[key]]; dt=np.dtype(CT[a['componentType']]); b=replace_view(j,b,a['bufferView'],np.ascontiguousarray(arr.astype(dt)).tobytes()); a['count']=len(arr)
    if 'min' in a: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
a=j['accessors'][p['indices']]; b=replace_view(j,b,a['bufferView'],F2.astype(np.uint16).ravel().tobytes()); a['count']=F2.size
a.pop('min',None); a.pop('max',None)
# ---- finger bones: new rest = T S G_R S
nodeof={names[i]:sk['joints'][i] for i in range(len(names))}
par={c:i for i,n in enumerate(N) for c in n.get('children',[])}
newG={}
for ri,li in r2l.items():
    if li in L and li!=iLH: newG[li]=T@S@G[ri]@S
def gw(li): return newG.get(li,G[li])
def setlocal(li):
    ni=sk['joints'][li]; pn=par[ni]; pj=sk['joints'].index(pn); M=np.linalg.inv(gw(pj))@gw(li)
    N[ni]['translation']=[float(x) for x in M[:3,3]]; N[ni]['rotation']=[float(x) for x in Rot.from_matrix(M[:3,:3]).as_quat()]
    N[ni].pop('scale',None)
for li in newG: setlocal(li)
IB2=IB.copy()
for li,M in newG.items(): IB2[li]=np.linalg.inv(M)
put(j,b,IBacc,IB2.transpose(0,2,1).reshape(-1,16).astype(np.float32))
# ---- anim: constant C for first-level fingers (parent LeftHand)
C=np.linalg.inv(G[iLH])@T@S@G[iRH]@S
def first(li): return par[sk['joints'][li]]==nodeof['LeftHand']
def newacc(arr,typ):
    global b
    raw=np.ascontiguousarray(arr.astype(np.float32)).tobytes(); off=len(b); b=b+bytearray(raw)+bytearray((-len(raw))%4)
    j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
    j['accessors'].append({'bufferView':len(j['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}); return len(j['accessors'])-1
node2j={n:k for k,n in enumerate(sk['joints'])}
def mq(q): return q*np.array([1,-1,-1,1])
for an in j['animations']:
    ch={(c['target']['node'],c['target']['path']):c for c in an['channels']}
    for li in newG:
        ri=[r for r,l in r2l.items() if l==li][0]
        for path in ('rotation','translation','scale'):
            cl=ch.get((sk['joints'][li],path)); cr=ch.get((sk['joints'][ri],path))
            if cl is None: continue
            sl=an['samplers'][cl['sampler']]
            if MODE=='mirror' and cr is not None:
                sr=an['samplers'][cr['sampler']]; out=acc(j,b,sr['output']).astype(float)
                if path=='rotation':
                    q=mq(out)
                    if first(li): q=Rot.from_matrix(np.einsum('ij,njk->nik',C[:3,:3],Rot.from_quat(q).as_matrix())).as_quat()
                elif path=='translation':
                    t=out*np.array([-1,1,1]); q=(t@C[:3,:3].T+C[:3,3]) if first(li) else t
                else: q=out
                an['samplers'].append({'input':sr['input'],'output':newacc(q,'VEC4' if path=='rotation' else 'VEC3'),'interpolation':sr.get('interpolation','LINEAR')})
                cl['sampler']=len(an['samplers'])-1
            elif path=='translation':
                n=j['accessors'][sl['input']]['count']; sl2={'input':sl['input'],'output':newacc(np.tile(N[sk['joints'][li]]['translation'],(n,1)),'VEC3'),'interpolation':'LINEAR'}
                an['samplers'].append(sl2); cl['sampler']=len(an['samplers'])-1
            elif path=='rotation' and MODE=='delta':
                pass  # filled by delta pass below
            elif path=='scale':
                pass
if MODE=='delta':
    # old local delta rotvecs (rest^-1 * anim) per left finger bone; principal axis; signed angle -> new axis from right deltas
    oldrest={li:Rot.from_matrix((np.linalg.inv(G[sk['joints'].index(par[sk['joints'][li]])] if False else np.linalg.inv(G[node2j[par[sk['joints'][li]]]]))@G[li])[:3,:3]) for li in newG}
    for li in newG:
        ri=[r for r,l in r2l.items() if l==li][0]
        rrest=Rot.from_matrix((np.linalg.inv(G[node2j[par[sk['joints'][ri]]]])@G[ri])[:3,:3])
        newrest=Rot.from_quat(N[sk['joints'][li]]['rotation'])
        dl=[];dr=[]
        for an in j['animations']:
            ch={(c['target']['node'],c['target']['path']):c for c in an['channels']}
            cl=ch.get((sk['joints'][li],'rotation')); cr=ch.get((sk['joints'][ri],'rotation'))
            if cl is not None: dl.append((oldrest[li].inv()*Rot.from_quat(acc(j,b,an['samplers'][cl['sampler']]['output']))).as_rotvec())
            if cr is not None: dr.append((rrest.inv()*Rot.from_quat(acc(j,b,an['samplers'][cr['sampler']]['output']))).as_rotvec())
        if not dl or not dr: continue
        DL=np.concatenate(dl); DR=np.concatenate(dr)
        axL=np.linalg.svd(DL,full_matrices=False)[2][0]; axR=np.linalg.svd(DR,full_matrices=False)[2][0]
        if (DL@axL).mean()<0: axL=-axL
        if (DR@axR).mean()<0: axR=-axR
        axN=axR*np.array([1,-1,-1])  # mirrored pseudo-vector, in the new local frame (S-conj); first-level frames carry C
        for an in j['animations']:
            ch={(c['target']['node'],c['target']['path']):c for c in an['channels']}
            cl=ch.get((sk['joints'][li],'rotation'))
            if cl is None: continue
            sl=an['samplers'][cl['sampler']]; ang=(oldrest[li].inv()*Rot.from_quat(acc(j,b,sl['output']))).as_rotvec()@axL
            q=(newrest*Rot.from_rotvec(ang[:,None]*axN[None])).as_quat()
            an['samplers'].append({'input':sl['input'],'output':newacc(q,'VEC4'),'interpolation':sl.get('interpolation','LINEAR')}); cl['sampler']=len(an['samplers'])-1
save(OUT,j,b); print('saved',OUT,len(P2),'verts',len(F2),'faces in body prim')
