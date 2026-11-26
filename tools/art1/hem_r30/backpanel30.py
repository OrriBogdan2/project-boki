# backpanel30.py IN OUT [off=0.015 ylo=0.45 yhi=0.92 nz=0.25 side=Right] : Lace r30. Replaces the r28/r29 slit godet (the small
# skirt-lining23 prim spanning the slit edges as a membrane, which the swinging thigh crossed = white "shards" in the front slit)
# with a wine back-panel on the slit-side thigh: that leg's own faces (leg-meshy, rest y ylo..yhi, vertex normal z < nz, i.e.
# back + sides, not the front) pushed `off` m out along the normal, with the SAME joints/weights as those thigh verts, so the
# panel moves exactly with the thigh and can never cross it. Material skirt-liner (its texture is solid wine, so the leg UVs map
# to wine). Through the slit: the whole white thigh and knee in front, wine behind. Nothing else changes.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); f=lambda k,d: float(O.get(k,d))
off,ylo,yhi,nz=f('off',0.015),f('ylo',0.45),f('yhi',0.92),f('nz',0.25); side=O.get('side','Right')
j,b=glbio.load(src); b=bytearray(bytes(b)); rig=g.Rig(j,b); jn=rig.names
mat=lambda nm: next(i for i,m in enumerate(j['materials']) if m['name']==nm)
me=next(m for m in j['meshes'] if any(j['materials'][p['material']]['name']=='leg-meshy' for p in m['primitives']))
n0=len(me['primitives'])
me['primitives']=[p for p in me['primitives'] if not (j['materials'][p['material']]['name'].startswith('skirt-lining') and j['accessors'][p['attributes']['POSITION']]['count']<5000)]
print('godet prims dropped:',n0-len(me['primitives']))
lp=next(p for p in me['primitives'] if j['materials'][p['material']]['name']=='leg-meshy')
A=lambda k: glbio.acc(j,b,lp['attributes'][k])
P=A('POSITION').astype(float); N=A('NORMAL').astype(float); N/=np.linalg.norm(N,axis=1,keepdims=True)+1e-9
Jt=A('JOINTS_0').astype(int); Wt=A('WEIGHTS_0').astype(float); F=glbio.acc(j,b,lp['indices']).reshape(-1,3).astype(np.int64)
legb={jn.index(side+'UpLeg'),jn.index(side+'Leg')}
dom=Jt[np.arange(len(Jt)),Wt.argmax(1)]
vs=np.isin(dom,list(legb))&(P[:,1]>ylo)&(P[:,1]<yhi)&(N[:,2]<nz)
fs=vs[F].all(1); Fs=F[fs]; vid,inv=np.unique(Fs,return_inverse=True); Fn=inv.reshape(-1,3)
Q=P[vid]+off*N[vid]
EXT=bytearray()
def add(arr,typ,ct=5126,target=None):
    dt={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8}[ct]; raw=np.ascontiguousarray(arr.astype(dt)).tobytes()
    pad=(-(len(b)+len(EXT)))%4; EXT.extend(b'\0'*pad); o=len(b)+len(EXT); EXT.extend(raw); bv={'buffer':0,'byteOffset':o,'byteLength':len(raw)}
    if target: bv['target']=target
    j['bufferViews'].append(bv); a={'bufferView':len(j['bufferViews'])-1,'componentType':ct,'count':len(arr),'type':typ}
    if typ=='VEC3' and ct==5126 and target==34962: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
    j['accessors'].append(a); return len(j['accessors'])-1
jct=j['accessors'][lp['attributes']['JOINTS_0']]['componentType']
at={'POSITION':add(Q,'VEC3',target=34962),'NORMAL':add(N[vid],'VEC3',target=34962),'TEXCOORD_0':add(A('TEXCOORD_0')[vid].astype(float),'VEC2',target=34962),
    'JOINTS_0':add(Jt[vid],'VEC4',jct,34962),'WEIGHTS_0':add(Wt[vid],'VEC4',target=34962)}
me['primitives'].append({'attributes':at,'indices':add(Fn.ravel(),'SCALAR',5125,34963),'material':mat('skirt-liner'),'mode':4})
b=bytearray(bytes(b))+EXT; j['buffers'][0]['byteLength']=len(b); glbio.save(out,j,b)
print('backpanel30: %s leg faces %d verts %d, y %.2f..%.2f, z %.3f..%.3f, off %.3f -> %s'%(side,len(Fn),len(vid),Q[:,1].min(),Q[:,1].max(),Q[:,2].min(),Q[:,2].max(),off,out))
