# gusset.py IN OUT [ytop=0.60 hw=30 rot=80 inset=0.010 mat=skirt-lining23 fade=0.06 gapc=-40]
# Lace r28: the slit (rest gap ~35 deg at the hem, centre -40 deg, closing to 10 deg at y 0.75) lets the 66-deg game camera see
# the ground through the open hem (seethru 0.078 vs live 0.009) and parts like curtains in crouch. This adds an inner under-panel:
# the Meshy skirt's own faces from the closed side (wedge centred gapc+rot, half width hw, below ytop) copied with their UV/colour,
# yawed into the slit and pulled `inset` m inside the outer skirt, on its own primitive (material `mat`, existing skirt texture).
# Weights: per vertex, blend of the nearest outer-skirt vertex on each slit side (A = da<0, B = da>=0) by angular position across
# the panel, so it spans the slit like a membrane between the two edges. Top `fade` m: panel vertices pulled further inside.
# Nothing else changes (mesh, textures, other prims, clips byte-identical).
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial import cKDTree
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); f=lambda k,d: float(O.get(k,d))
ytop,hw,rot,inset,fade,gapc=f('ytop',0.60),f('hw',30),f('rot',80),f('inset',0.010),f('fade',0.06),f('gapc',-40); mat=O.get('mat','skirt-lining23')
j,b=glbio.load(src); b=bytearray(bytes(b)); rig=g.Rig(j,b); jn=rig.names; ih=jn.index('Hips')
S0=rig.skin_mats(None,np.zeros(1))[0]; hc=(S0@np.linalg.inv(rig.ibm))[ih][:3,3]
me=next(m for m in j['meshes'] if any(j['materials'][p['material']]['name']=='skirt-meshy' for p in m['primitives']))
sk=next(p for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,sk['attributes'][k])
P=A('POSITION').astype(float); N=A('NORMAL').astype(float); F=glbio.acc(j,b,sk['indices']).reshape(-1,3).astype(np.int64)
Jx=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); Wx=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
ang=lambda X: np.degrees(np.arctan2(X[:,0]-hc[0],X[:,2]-hc[2]))
wrap=lambda d: (d+180)%360-180
va=ang(P); cen=P[F].mean(1); ca=ang(cen)
sel=(np.abs(wrap(ca-(gapc+rot)))<=hw)&(cen[:,1]<ytop)
Fs=F[sel]; vid,inv=np.unique(Fs,return_inverse=True); Fn=inv.reshape(-1,3)
d=np.radians(-rot); c,s=np.cos(d),np.sin(d); R=np.array([[c,0,s],[0,1,0],[-s,0,c]])
Q=(P[vid]-hc)@R.T+hc; Nn=N[vid]@R.T
rr=np.hypot(Q[:,0]-hc[0],Q[:,2]-hc[2]); top=np.clip((Q[:,1]-(ytop-fade))/max(fade,1e-6),0,1)
k=np.maximum(rr-inset-0.012*top,0.02)/np.maximum(rr,1e-6); Q[:,0]=hc[0]+(Q[:,0]-hc[0])*k; Q[:,2]=hc[2]+(Q[:,2]-hc[2])*k
# weights: membrane between the two slit sides
n=len(P); D=np.zeros((n,len(jn))); np.add.at(D,(np.repeat(np.arange(n),8),Jx.ravel()),Wx.ravel())
da=wrap(va-gapc); qa=wrap(ang(Q)-gapc); sc=np.radians(1)*0.22
def near(mask):
    idx=np.where(mask)[0]; t=cKDTree(np.c_[P[idx,1],da[idx]*sc]); return idx[t.query(np.c_[Q[:,1],qa*sc])[1]]
iA=near(da<0); iB=near(da>=0); t=np.clip((qa+hw)/(2*hw),0,1); t=t*t*(3-2*t)
Dg=(1-t)[:,None]*D[iA]+t[:,None]*D[iB]
o=np.argsort(-Dg,1)[:,:8]; w=np.take_along_axis(Dg,o,1); w/=w.sum(1,keepdims=True)
EXT=bytearray()
def add(arr,typ,ct=5126,target=None):
    dt={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8}[ct]; raw=np.ascontiguousarray(arr.astype(dt)).tobytes()
    pad=(-(len(b)+len(EXT)))%4; EXT.extend(b'\0'*pad); off=len(b)+len(EXT); EXT.extend(raw); bv={'buffer':0,'byteOffset':off,'byteLength':len(raw)}
    if target: bv['target']=target
    j['bufferViews'].append(bv); a={'bufferView':len(j['bufferViews'])-1,'componentType':ct,'count':len(arr),'type':typ}
    if typ=='VEC3' and ct==5126 and target==34962: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
    j['accessors'].append(a); return len(j['accessors'])-1
mi=next(i for i,m in enumerate(j['materials']) if m['name']==mat)
at={'POSITION':add(Q,'VEC3',target=34962),'NORMAL':add(Nn,'VEC3',target=34962),'TEXCOORD_0':add(A('TEXCOORD_0')[vid].astype(float),'VEC2',target=34962),
    'JOINTS_0':add(o[:,:4],'VEC4',5123,34962),'JOINTS_1':add(o[:,4:],'VEC4',5123,34962),'WEIGHTS_0':add(w[:,:4],'VEC4',target=34962),'WEIGHTS_1':add(w[:,4:],'VEC4',target=34962)}
if 'COLOR_0' in sk['attributes']:
    ca0=j['accessors'][sk['attributes']['COLOR_0']]; C=A('COLOR_0')[vid]
    at['COLOR_0']=add(C.astype(float) if ca0['componentType']==5126 else C, ca0['type'], ca0['componentType'],34962)
    if ca0.get('normalized'): j['accessors'][at['COLOR_0']]['normalized']=True
me['primitives'].append({'attributes':at,'indices':add(Fn.ravel(),'SCALAR',5125,34963),'material':mi,'mode':4})
b=bytearray(bytes(b))+EXT; j['buffers'][0]['byteLength']=len(b); glbio.save(out,j,b)
print('gusset: faces %d verts %d (src wedge %+.0f..%+.0f deg, y<%.2f) -> slit %+.0f..%+.0f, inset %.3f, mat %s, y %.2f..%.2f; wrote %s'%(
  len(Fn),len(vid),gapc+rot-hw,gapc+rot+hw,ytop,gapc-hw,gapc+hw,inset,mat,Q[:,1].min(),Q[:,1].max(),out))
