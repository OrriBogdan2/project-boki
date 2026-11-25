# sway25.py (r25: sway24 + capc=Clip:deg,... per-clip tilt cap, matched by substring; r24's cap 80 lifted the Crouch skirt into a disc)
# sway24.py IN OUT [ytop=0.98 ybot=0.78 keep=0 kp=0 keept=keep ykt=0.86 ykb=0.62 margin=0.006 cap=60 dnb=18 iters=14 fps=15]
# Lace r24: the skirt panel rides the 8 SkirtSw sway bones (angle-interpolated between the two nearest bones, so neighbours never
# split into "trouser" tubes or "wing" panels) instead of following one thigh each (legfollow21 hmax 1.0). The sway bones' rotation
# keys are solved per clip frame, closed loop: each bone tilts outward about its own head just enough that no hip/thigh vertex
# (poke22's set: rest y 0.45-0.98, dominant Hips/UpLeg) pokes out through the skirt, with neighbour tilt difference <= dnb deg and
# tilt <= cap deg. Top band (y > ytop) keeps the shipped weights; ytop..ybot blends to sway. keep = share of the shipped thigh
# weights kept below ybot. Writes skirt JOINTS/WEIGHTS (the lining prim shares the accessors) and new SkirtSw rotation samplers.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); F=lambda k,d: float(O.get(k,d))
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names; nodes=j['nodes']
def prim(mn): return next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']==mn)
A=lambda p,k: glbio.acc(j,b,p['attributes'][k])
sk=prim('skirt-meshy'); P=A(sk,'POSITION').astype(float)
J0=np.c_[A(sk,'JOINTS_0'),A(sk,'JOINTS_1')].astype(int); W0=np.c_[A(sk,'WEIGHTS_0'),A(sk,'WEIGHTS_1')].astype(float)
sF=glbio.acc(j,b,sk['indices']).astype(np.int64).reshape(-1,3)
S0=rig.skin_mats(None,np.zeros(1))[0]; Grest=S0@np.linalg.inv(rig.ibm)       # rest globals of the joints
assert np.abs(S0-np.eye(4)).max()<1e-3, 'rest pose != bind pose'
ih=jn.index('Hips'); sw=[jn.index('SkirtSw%d'%k) for k in range(8)]
assert all(rig.parent[rig.joints[s]]==rig.joints[ih] for s in sw)
hc=Grest[ih][:3,3]; C=np.array([Grest[s][:3,3] for s in sw])               # pivots (bone heads)
phi=np.arctan2(C[:,0]-hc[0],C[:,2]-hc[2]); order=np.argsort(phi); assert (order==np.roll(order,0)).all()
def sector_w(a):                                                            # [n,8] linear-in-angle interpolation, wraps
    ph=phi[order]; ph2=np.r_[ph,ph[0]+2*np.pi]; a=(a-ph[0])%(2*np.pi)+ph[0]
    k=np.clip(np.searchsorted(ph2,a)-1,0,7); u=(a-ph2[k])/(ph2[k+1]-ph2[k]); Wt=np.zeros((len(a),8))
    Wt[np.arange(len(a)),order[k]]=1-u; Wt[np.arange(len(a)),order[(k+1)%8]]+=u; return Wt
# --- weights
t=np.clip((F('ytop',0.98)-P[:,1])/(F('ytop',0.98)-F('ybot',0.78)),0,1); s=t*t*(3-2*t)
n=len(P); nJ=len(jn); D=np.zeros((n,nJ)); np.add.at(D,(np.repeat(np.arange(n),8),J0.ravel()),W0.ravel())
legs=[jn.index('LeftUpLeg'),jn.index('RightUpLeg')]
va=np.arctan2(P[:,0]-hc[0],P[:,2]-hc[2]); keep=F('keep',0)*np.abs(np.sin(va))**F('kp',0)   # kp>0: thigh share only at the sides (0 at front/back centre)
tk=np.clip((P[:,1]-F('ykb',0.62))/(F('ykt',0.86)-F('ykb',0.62)),0,1); keep=keep+(F('keept',F('keep',0))-keep)*tk*tk*(3-2*tk)   # keept: thigh share at the hip crease
Sw=sector_w(va)
D2=D*(1-s)[:,None]; D2[:,legs]+=D[:,legs]*(keep*s)[:,None]; D2[:,sw]+=Sw*(s*(1-keep*D[:,legs].sum(1)))[:,None]
D2/=D2.sum(1,keepdims=True)
SLIT=int(F('slit',0)); gc=np.radians(F('gapc',-40))
if SLIT:                                                                  # slit=1: 2 new joints SkirtSlitA (her side edge) / SkirtSlitB (front edge), rest = Hips
    da=np.degrees((va-gc+np.pi)%(2*np.pi)-np.pi); side=np.where(da<0,0,1)          # A: angles below the gap centre
    wb=np.clip((F('band1',50)-np.abs(da))/(F('band1',50)-F('band0',15)),0,1); wb=wb*wb*(3-2*wb)
    ty=np.clip((F('sy0',0.86)-P[:,1])/(F('sy0',0.86)-F('sy1',0.60)),0,1); wsl=wb*ty*ty*(3-2*ty)
    D2=np.c_[D2*(1-wsl)[:,None],np.zeros((n,2))]; D2[np.arange(n),nJ+side]=wsl
    print('slit verts w>0.5: A %d B %d'%(((wsl>.5)&(side==0)).sum(),((wsl>.5)&(side==1)).sum()))
idx=np.argsort(-D2,1)[:,:8]; ww=np.take_along_axis(D2,idx,1); ww/=ww.sum(1,keepdims=True)
# --- body points (poke22 set)
bp=[];bj=[];bw=[]
for me in j['meshes']:
    for p in me['primitives']:
        if j['materials'][p['material']]['name'] in ('body-retex','leg-meshy'):
            q=A(p,'POSITION').astype(float); jj=[A(p,'JOINTS_0')]; ws=[A(p,'WEIGHTS_0')]
            if 'JOINTS_1' in p['attributes']: jj.append(A(p,'JOINTS_1')); ws.append(A(p,'WEIGHTS_1'))
            jj=np.hstack(jj).astype(int); ws=np.hstack(ws).astype(float); pad=8-jj.shape[1]
            bp.append(q); bj.append(np.pad(jj,((0,0),(0,pad)))); bw.append(np.pad(ws,((0,0),(0,pad))))
bp=np.vstack(bp); bj=np.vstack(bj); bw=np.vstack(bw); dom=np.array(jn)[bj[np.arange(len(bj)),bw.argmax(1)]]
sel=(bp[:,1]>0.45)&(bp[:,1]<0.98)&np.isin(dom,['Hips','LeftUpLeg','RightUpLeg'])
if F('shin',0): sel|=(bp[:,1]>F('shiny',0.30))&(bp[:,1]<0.62)&np.isin(dom,['LeftLeg','RightLeg'])   # shin=1: shins above the hem too (geo_check skirt>shin)
bp,bj,bw=bp[sel],bj[sel],bw[sel]
def skin(S,P,J,W):
    X=np.c_[P,np.ones(len(P))]; o=np.zeros((len(P),3))
    for k in range(J.shape[1]):
        m=S[J[:,k]]; o+=W[:,k,None]*np.einsum('vij,vj->vi',m[:,:3,:],X)
    return o
def rotm(ax,th):
    ax=ax/np.linalg.norm(ax); K=np.array([[0,-ax[2],ax[1]],[ax[2],0,-ax[0]],[-ax[1],ax[0],0]]); return np.eye(3)+np.sin(th)*K+(1-np.cos(th))*K@K
rad=np.c_[np.sin(phi),np.zeros(8),np.cos(phi)]; axes=np.cross(rad,[0,1,0])           # tilt axis: bottom of the bone moves outward
def MD(k,th):
    M=np.eye(4); R=rotm(axes[k],th); M[:3,:3]=R; M[:3,3]=C[k]-R@C[k]; return M
rng=np.random.default_rng(0); ns=120000; fi=rng.integers(0,len(sF),ns); u=rng.random((ns,2)); mm=u.sum(1)>1; u[mm]=1-u[mm]
NA,NH=96,60; marg=F('margin',0.006); cap=np.radians(F('cap',60)); dnb=np.radians(F('dnb',18)); fps=F('fps',15)
def poke(Sf,Hinv,hw):                                     # poke22's world cylinder test about the hips joint; angles for the sectors in hips space
    sv=skin(Sf,P,idx,ww); X=sv[sF[fi,0]]+(sv[sF[fi,1]]-sv[sF[fi,0]])*u[:,:1]+(sv[sF[fi,2]]-sv[sF[fi,0]])*u[:,1:]
    y0,y1=X[:,1].min(),X[:,1].max()
    def bins(Y):
        ai=((np.arctan2(Y[:,0]-hw[0],Y[:,2]-hw[2])+np.pi)/(2*np.pi)*NA).astype(int)%NA
        h=((Y[:,1]-y0)/(y1-y0+1e-9)*NH).astype(int); return ai,h,np.hypot(Y[:,0]-hw[0],Y[:,2]-hw[2])
    a,h,r=bins(X); R=np.full((NA,NH),-1.0); np.maximum.at(R,(a,np.clip(h,0,NH-1)),r)
    B=skin(Sf,bp,bj,bw); a2,h2,r2=bins(B); ok=(h2>=0)&(h2<NH)
    rr=np.where(ok,R[a2,np.clip(h2,0,NH-1)],-1); d=np.where(rr>0,r2-rr,-1)
    Bl=(Hinv@np.c_[B,np.ones(len(B))].T).T[:,:3]; return d,np.arctan2(Bl[:,0]-hc[0],Bl[:,2]-hc[2]),B[:,1]
def append(jj,bb,arr,typ,mm=False):
    raw=np.ascontiguousarray(arr.astype(np.float32)).tobytes(); bb+=b'\0'*((-len(bb))%4); off=len(bb); bb+=raw
    jj['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
    a={'bufferView':len(jj['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}
    if mm: a['min']=[float(arr.min())]; a['max']=[float(arr.max())]
    jj['accessors'].append(a); return len(jj['accessors'])-1
CAPC={kv.split(':')[0]:np.radians(float(kv.split(':')[1])) for kv in O.get('capc','').split(',') if kv}
FOLC={kv.split(':')[0]:float(kv.split(':')[1]) for kv in O.get('folc','').split(',') if kv}
from scipy.spatial.transform import Rotation as _R
iL,iR=jn.index('LeftUpLeg'),jn.index('RightUpLeg'); pL,pR=Grest[iL][:3,3],Grest[iR][:3,3]
frontk=np.maximum(np.cos(phi),0)**F('fpow',0.5); fLk=frontk*(1+np.sin(phi))/2; fRk=frontk*(1-np.sin(phi))/2   # +x = her left
def follow(G,f,share):                                    # per sway bone: rest-hips-space rotation by a share of each thigh's own swing, about the thigh heads
    Hm=G[f,ih]@np.linalg.inv(Grest[ih]); Fm=np.tile(np.eye(4),(8,1,1))
    if share<=0: return Fm
    def rv(i): D=np.linalg.inv(Hm)@G[f,i]@np.linalg.inv(Grest[i]); R=D[:3,:3]/np.linalg.norm(D[:3,:3],axis=0); return _R.from_matrix(R).as_rotvec()
    rl,rr=rv(iL),rv(iR)
    for k in range(8):
        a,c=share*fLk[k],share*fRk[k]
        if a+c<1e-6: continue
        R=_R.from_rotvec(a*rl+c*rr).as_matrix(); pv=(a*pL+c*pR)/(a+c); Fm[k][:3,:3]=R; Fm[k][:3,3]=pv-R@pv
    return Fm
IBM=np.concatenate([rig.ibm,np.repeat(rig.ibm[ih:ih+1],2,0)]) if SLIT else rig.ibm
CLOC={kv.split(':')[0]:float(kv.split(':')[1]) for kv in O.get('cloc','').split(',') if kv}
pivr=np.linalg.norm((C-hc)[:,[0,2]],axis=1).mean(); pivy=C[:,1].mean()
def Yaw(psi):
    M=np.eye(4); R=rotm(np.array([0.,1,0]),psi); M[:3,:3]=R; M[:3,3]=hc-R@hc; return M
def MDat(al,th):
    rd=np.array([np.sin(al),0,np.cos(al)]); ax=np.cross(rd,[0,1,0]); pv=np.array([hc[0],pivy,hc[2]])+pivr*rd
    M=np.eye(4); R=rotm(ax,th); M[:3,:3]=R; M[:3,3]=pv-R@pv; return M
def slitmats(G,f,share,thf,clo):                     # world-rest deltas of SlitA/B: sway at the edge angle (follow + tilt), then yaw closed by clo
    out=[]
    for e,(al,sg) in enumerate(((np.radians(F('edgeA',-52)),1),(np.radians(F('edgeB',-28)),-1))):
        wt=sector_w(np.array([al]))[0]; thv=float(wt@thf); fr=max(np.cos(al),0)**F('fpow',0.5); a,c=share*fr*(1+np.sin(al))/2,share*fr*(1-np.sin(al))/2
        Fm=np.eye(4)
        if share>0 and a+c>1e-6:
            Hm=G[f,ih]@np.linalg.inv(Grest[ih])
            def rv(i): D=np.linalg.inv(Hm)@G[f,i]@np.linalg.inv(Grest[i]); R=D[:3,:3]/np.linalg.norm(D[:3,:3],axis=0); return _R.from_matrix(R).as_rotvec()
            R=_R.from_rotvec(a*rv(iL)+c*rv(iR)).as_matrix(); pv=(a*pL+c*pR)/(a+c); Fm[:3,:3]=R; Fm[:3,3]=pv-R@pv
        out.append(Fm@MDat(al,thv)@Yaw(sg*clo*np.radians(F('psi',15))))
    return out
def solve(name,T,S):
    clo=next((v for k,v in CLOC.items() if k.lower() in name.lower()),F('clo',0)) if SLIT else 0
    if SLIT: S=np.concatenate([S,np.repeat(S[:,ih:ih+1],2,1)],1)          # slots for the 2 slit joints (rest = Hips)
    share=next((v for k,v in FOLC.items() if k.lower() in name.lower()),F('fol',0))
    cap=next((v for k,v in CAPC.items() if k.lower() in name.lower()),np.radians(F('cap',60))); nf=len(T); G=S@np.linalg.inv(IBM)[None]; Hinv=Grest[ih][None]@np.linalg.inv(G[:,ih])      # world -> rest-hips space
    exs=any(k.lower() in name.lower() for k in O.get('exslit','').split(',') if k)   # exslit=Clip,...: the right thigh may pass through the open slit (design), not a poke
    FM=np.array([follow(G,f,share) for f in range(nf)]); th=np.zeros((nf,8)); log=''; SM=None
    for it in range(int(F('iters',14))):
        need=np.zeros((nf,8)); tot=0; worst=0
        for f in range(nf):
            Sf=S[f].copy()
            for k in range(8): Sf[sw[k]]=G[f,ih]@np.linalg.inv(Grest[ih])@FM[f,k]@MD(k,th[f,k])
            if SLIT:
                for e,M in enumerate(slitmats(G,f,share,th[f],clo)): Sf[nJ+e]=G[f,ih]@np.linalg.inv(Grest[ih])@M
            d,ang,yb=poke(Sf,Hinv[f],G[f,ih][:3,3]); d=np.where(exs&(np.abs(np.degrees((ang-gc+np.pi)%(2*np.pi)-np.pi))<F('exw',30)),-1,d); pk=d>0.002; tot+=pk.sum(); worst=max(worst,d.max())
            if pk.any():
                lev=np.maximum(G[f,ih][1,3]+C[0,1]-hc[1]-yb[pk],0.15); dth=(d[pk]+marg)/lev; need[f]=np.max(sector_w(ang[pk])*dth[:,None],0)
        log='%s it %d poked %d worst %.1f cm max tilt %.0f deg'%(name,it,tot,worst*100,np.degrees(th.max()))
        if tot==0 and it>0: break
        th=th+need*1.15
        th=np.maximum(th,np.r_[th[1:],th[-1:]]); th=np.maximum(th,np.r_[th[:1],th[:-1]])                    # dilate 1 frame
        th=(np.r_[th[:1],th[:-1]]+2*th+np.r_[th[1:],th[-1:]])/4                                             # smooth in time
        for _ in range(8):                                                                                  # neighbour cap
            for k in range(8):
                for kk in ((k+1)%8,(k-1)%8): th[:,kk]=np.maximum(th[:,kk],th[:,k]-dnb)
        th=np.minimum(th,cap)
    if SLIT: SM=np.array([slitmats(G,f,share,th[f],clo) for f in range(nf)])
    log+=' cap %.0f fol %.2f clo %.2f'%(np.degrees(cap),share,clo); print(log); return th,FM,SM
def times(jj,bb,an):
    Tm=max(glbio.acc(jj,bb,an['samplers'][c['sampler']]['input'])[:,0].max() for c in an['channels']); return np.unique(np.r_[np.arange(0,Tm,1/fps),Tm])
for an in j['animations']:
    T=times(j,b,an); an['_th']=(T,)+solve(an['name'],T,rig.skin_mats(an,T))
# kit-move clips (clips=PATH clipsout=PATH): the animation-only file the game borrows by bone name; solved on this rig
if 'clips' in O:
    jc,bc=glbio.load(O['clips']); assert 'inverseBindMatrices' not in jc['skins'][0]      # no binds: skin_mats = globals
    import copy; jt=copy.deepcopy(jc); bt=bytearray(bytes(bc)); jt['skins'][0]['inverseBindMatrices']=append(jt,bt,np.tile(np.eye(4).ravel(),(len(jt['skins'][0]['joints']),1)),'MAT4')
    rc=g.Rig(jt,bytes(bt)); cmap=[rc.names.index(nm) if nm in rc.names else -1 for nm in jn]
    for an in jc['animations']:
        T=times(jc,bc,an); Sc=rc.skin_mats(an,T); S=np.tile(np.eye(4),(len(T),nJ,1,1))
        for k in range(nJ):
            if cmap[k]>=0: S[:,k]=Sc[:,cmap[k]]@rig.ibm[k]
        an['_th']=(T,)+solve(an['name'],T,S)
# --- write weights + keys
b=bytearray(bytes(b))
def putw(k,arr):
    a=j['accessors'][sk['attributes'][k]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,sk['attributes'][k],arr.astype(dt))
putw('JOINTS_0',idx[:,:4]); putw('JOINTS_1',idx[:,4:]); putw('WEIGHTS_0',ww[:,:4]); putw('WEIGHTS_1',ww[:,4:])
def mat2q(M):
    from scipy.spatial.transform import Rotation; return Rotation.from_matrix(M).as_quat()
def keyq(k,th,FM):
    L=[np.linalg.inv(Grest[ih])@FM[f,k]@MD(k,x)@Grest[sw[k]] for f,x in enumerate(th)]
    q=np.array([mat2q(M[:3,:3]/np.linalg.norm(M[:3,:3],axis=0)) for M in L]); return q*np.sign(q[:,3:4]+1e-9),np.array([M[:3,3] for M in L])
def write_keys(jj,bb):
    nn=jj['nodes']
    for an in jj['animations']:
        T,th,FM,SM=an.pop('_th'); ti=append(jj,bb,T.reshape(-1,1),'SCALAR',True); done=set()
        if SM is not None:
            for e,nm in enumerate(('SkirtSlitA','SkirtSlitB')):
                ni=next(i for i,nd in enumerate(nn) if nd['name']==nm); L=[np.linalg.inv(Grest[ih])@M@Grest[ih] for M in SM[:,e]]
                q=np.array([mat2q(M[:3,:3]/np.linalg.norm(M[:3,:3],axis=0)) for M in L]); q=q*np.sign(q[:,3:4]+1e-9)
                for pth,arr,ty in (('rotation',q,'VEC4'),('translation',np.array([M[:3,3] for M in L]),'VEC3')):
                    an['samplers'].append({'input':ti,'output':append(jj,bb,arr,ty),'interpolation':'LINEAR'}); an['channels'].append({'sampler':len(an['samplers'])-1,'target':{'node':ni,'path':pth}})
        KQ={k:keyq(k,th[:,k],FM) for k in range(8)}
        for c in an['channels']:
            nm=nn[c['target']['node']]['name']; pth=c['target']['path']
            if nm.startswith('SkirtSw') and pth in ('rotation','translation'):
                k=int(nm[7:]); an['samplers'][c['sampler']]={'input':ti,'output':append(jj,bb,KQ[k][0] if pth=='rotation' else KQ[k][1],'VEC4' if pth=='rotation' else 'VEC3'),'interpolation':'LINEAR'}; done.add((k,pth))
        for k in range(8):
            for pth in ('rotation','translation'):
                if (k,pth) in done: continue
                ni=next(i for i,nd in enumerate(nn) if nd['name']=='SkirtSw%d'%k)
                an['samplers'].append({'input':ti,'output':append(jj,bb,KQ[k][0] if pth=='rotation' else KQ[k][1],'VEC4' if pth=='rotation' else 'VEC3'),'interpolation':'LINEAR'})
                an['channels'].append({'sampler':len(an['samplers'])-1,'target':{'node':ni,'path':pth}})
    jj['buffers'][0]['byteLength']=len(bb)
def add_slit_nodes(jj,ibm_bb=None):
    hn=next(i for i,nd in enumerate(jj['nodes']) if nd['name']=='Hips'); skn=jj['skins'][0]
    for nm in ('SkirtSlitA','SkirtSlitB'):
        if any(nd.get('name')==nm for nd in jj['nodes']): continue
        jj['nodes'].append({'name':nm,'translation':[0.0,0.0,0.0]}); jj['nodes'][hn].setdefault('children',[]).append(len(jj['nodes'])-1); skn['joints'].append(len(jj['nodes'])-1)
    if ibm_bb is not None: skn['inverseBindMatrices']=append(jj,ibm_bb,np.array([M.T.ravel() for M in IBM]),'MAT4')
if SLIT: assert len(j['skins'][0]['joints'])==nJ; add_slit_nodes(j,b)
write_keys(j,b)
j['buffers'][0]['byteLength']=len(b); glbio.save(out,j,b); print('wrote',out)
if 'clips' in O:
    bc=bytearray(bytes(bc)); hn=next(i for i,nd in enumerate(jc['nodes']) if nd['name']=='Hips'); sk_c=jc['skins'][0]
    for k in range(8):
        if any(nd['name']=='SkirtSw%d'%k for nd in jc['nodes']): continue
        src_n=next(nd for nd in nodes if nd['name']=='SkirtSw%d'%k); jc['nodes'].append({x:src_n[x] for x in ('name','rotation','translation','scale') if x in src_n})
        jc['nodes'][hn].setdefault('children',[]).append(len(jc['nodes'])-1); sk_c['joints'].append(len(jc['nodes'])-1)
    if SLIT: add_slit_nodes(jc)
    write_keys(jc,bc); glbio.save(O['clipsout'],jc,bc); print('wrote',O['clipsout'],'joints',len(sk_c['joints']))
