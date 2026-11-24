"""grip.py IN(grafted, mirror mode) REF(k3, for right-hand curl axes) OUT [SCALE]: left finger tracks = rest * curl(theta_f*SCALE + old-anim variation);
theta_f per finger fitted so the finger wraps the bow grip at rest-hand pose."""
import sys,numpy as np; sys.path.insert(0,'tools'); from glbio import *
from scipy.spatial.transform import Rotation as Rot
IN,REF,OUT=sys.argv[1:4]; VAR=float(sys.argv[4]) if len(sys.argv)>4 else 0.3
j,b=load(IN); jr,br=load(REF); N=j['nodes']; sk=j['skins'][0]; names=[N[n]['name'] for n in sk['joints']]
IB=acc(j,b,sk['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1); G=np.linalg.inv(IB)
par={c:i for i,n in enumerate(N) for c in n.get('children',[])}; n2j={n:k for k,n in enumerate(sk['joints'])}
pj=lambda k:n2j[par[sk['joints'][k]]]
# curl axis per left finger joint: right-hand PCA of anim deltas (from REF), mirrored
IBr=acc(jr,br,jr['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1); Gr=np.linalg.inv(IBr); Nr_=jr['nodes']
fingers={f:[names.index(f'LeftHand{f}{i}') for i in (1,2,3)] for f in ('Index','Middle','Ring','Pinky','Thumb')}
axis={}; oldvar={}
for f,ch in fingers.items():
    for li in ch:
        ri=names.index(names[li].replace('Left','Right')); rrest=Rot.from_matrix((np.linalg.inv(Gr[pj(ri)])@Gr[ri])[:3,:3])
        D=[]
        for an in jr['animations']:
            for c in an['channels']:
                if c['target']['node']==sk['joints'][ri] and c['target']['path']=='rotation':
                    D.append((rrest.inv()*Rot.from_quat(acc(jr,br,an['samplers'][c['sampler']]['output']))).as_rotvec())
        D=np.concatenate(D); ax=np.linalg.svd(D,full_matrices=False)[2][0]
        if (D@ax).mean()<0: ax=-ax
        axis[li]=ax*np.array([1,-1,-1])
# mesh + bow grip
p=j['meshes'][1]['primitives'][2]; A=p['attributes']; P=acc(j,b,A['POSITION']).astype(float)
J=acc(j,b,A['JOINTS_0']); W=acc(j,b,A['WEIGHTS_0']).astype(float); dom=J[np.arange(len(J)),W.argmax(1)]
hand=[k for k,n in enumerate(names) if 'LeftHand' in n]; hv=np.where(np.isin(dom,hand))[0]
BP=np.concatenate([acc(j,b,pp['attributes']['POSITION']) for pp in j['meshes'][0]['primitives']]).astype(float)
c0=G[names.index('LeftHand')][:3,3]; near=BP[np.linalg.norm(BP-c0,axis=1)<0.07]
mu=near.mean(0); ax_g=ag_=np.linalg.svd(near-mu)[2][0]
def axd(X): v=X-mu; return np.linalg.norm(v-np.outer(v@ax_g,ax_g),axis=1)
r=np.percentile(axd(near),50); print('grip radius %.2f cm, n=%d'%(r*100,len(near)))
rest={k:np.linalg.inv(G[pj(k)])@G[k] for f in fingers for k in fingers[f]}
def pose(th):
    Gp={}
    for f,ch in fingers.items():
        for k in ch:
            M=rest[k].copy(); M[:3,:3]=M[:3,:3]@Rot.from_rotvec(axis[k]*np.radians(th[f])).as_matrix()
            Gp[k]=(Gp.get(pj(k),G[pj(k)]))@M
    return Gp
def skin(Gp):
    X=np.c_[P[hv],np.ones(len(hv))]; out=np.zeros((len(hv),3))
    for c in range(4):
        jj=J[hv,c]; M=np.stack([Gp.get(int(x),G[int(x)])@IB[int(x)] for x in jj]); out+=W[hv,c,None]*np.einsum('nij,nj->ni',M,X)[:,:3]
    return out
TH=float(sys.argv[5]) if len(sys.argv)>5 else 85; THT=float(sys.argv[6]) if len(sys.argv)>6 else 30
th={f:(THT if f=='Thumb' else TH) for f in fingers}
X=skin(pose(th)); fv=np.isin(dom[hv],[k for f in ('Index','Middle','Ring','Pinky') for k in fingers[f][:2]])
tc=X[fv].mean(0); v=tc-mu; off=-(v-(v@ag_)*ag_) if False else None
# write tracks: rest*curl(theta + VAR*old-variation is not kept: constant grip, small breathing from old Idle/Attack)
def newacc(arr,typ):
    global b
    raw=np.ascontiguousarray(arr.astype(np.float32)).tobytes(); off=len(b); b=b+bytearray(raw)+bytearray((-len(raw))%4)
    j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
    j['accessors'].append({'bufferView':len(j['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}); return len(j['accessors'])-1
for an in j['animations']:
    for c in an['channels']:
        k=n2j.get(c['target']['node'])
        if k is None or k not in rest or c['target']['path']!='rotation': continue
        f=[x for x in fingers if k in fingers[x]][0]; s=an['samplers'][c['sampler']]
        ri=names.index(names[k].replace('Left','Right'))
        # variation: mirrored right-hand angle about its axis in the same clip, minus its mean, times VAR
        n=j['accessors'][s['input']]['count']; vari=np.zeros(n)
        for c2 in an['channels']:
            if c2['target']['node']==sk['joints'][ri] and c2['target']['path']=='rotation':
                s2=an['samplers'][c2['sampler']]
                if s2['input']==s['input'] or j['accessors'][s2['input']]['count']==n:
                    rrest=Rot.from_matrix((np.linalg.inv(G[pj(ri)])@G[ri])[:3,:3])
                    a=(rrest.inv()*Rot.from_quat(acc(j,b,s2['output']))).as_rotvec()@(axis[k]*np.array([1,-1,-1])); vari=(a-a.mean())*VAR
        ang=np.radians(th[f])+vari
        q=(Rot.from_matrix(rest[k][:3,:3])*Rot.from_rotvec(ang[:,None]*axis[k][None])).as_quat()
        an['samplers'].append({'input':s['input'],'output':newacc(q,'VEC4'),'interpolation':s.get('interpolation','LINEAR')}); c['sampler']=len(an['samplers'])-1
LB=acc(j,b,j['meshes'][0]['primitives'][1]['attributes']['POSITION']).astype(float)
bm=LB.mean(0); bax=np.linalg.svd(LB-bm)[2][0]; tt=(LB-bm)@bax; hc=LB[np.argsort(np.abs(tt))[:24]].mean(0); print("handle verts |t| max %.1f cm"%(np.sort(np.abs(tt))[23]*100))
km=0.5*(G[names.index('LeftHandMiddle1')][:3,3]+G[names.index('LeftHandRing1')][:3,3]); kr=0.5*(Gr[names.index('LeftHandMiddle1')][:3,3]+Gr[names.index('LeftHandRing1')][:3,3]); dl=km-kr   # move the bow so its handle centre (middle 6 cm of the leather limb mesh) sits in the fist tunnel
BOWSH=float(sys.argv[7]) if len(sys.argv)>7 else 1.0; dl=dl*BOWSH
print('bow shift %.2f cm'%(np.linalg.norm(dl)*100))
bn=[k for k,n in enumerate(N) if n.get('name')=='Bow' and 'mesh' not in n][0]
sub=[];st=[bn]
while st: x=st.pop(); sub.append(x); st+=N[x].get('children',[])
subj=[n2j[x] for x in sub if x in n2j]
iLH=names.index('LeftHand'); dL=G[iLH][:3,:3].T@dl
N[bn]['translation']=list(np.array(N[bn].get('translation',[0,0,0]))+dL)
for an in j['animations']:
    for c in an['channels']:
        if c['target']['node']==bn and c['target']['path']=='translation':
            s_=an['samplers'][c['sampler']]; o=acc(j,b,s_['output']).astype(float)+dL
            an['samplers'].append({'input':s_['input'],'output':newacc(o,'VEC3'),'interpolation':s_.get('interpolation','LINEAR')}); c['sampler']=len(an['samplers'])-1
IB2=IB.copy(); Tm=np.eye(4); Tm[:3,3]=-dl
for k in subj: IB2[k]=IB[k]@Tm
put(j,b,sk['inverseBindMatrices'],IB2.transpose(0,2,1).reshape(-1,16).astype(np.float32))
for pp in j['meshes'][0]['primitives']:
    PP=acc(j,b,pp['attributes']['POSITION']).astype(float); put(j,b,pp['attributes']['POSITION'],(PP+dl).astype(np.float32))
save(OUT,j,b); print('saved',OUT,th)
