# graft21.py BASE.glb NEWSKIRT.glb OUT.glb [k=v ...] : replace the skirt-meshy prim (geometry+texture) of BASE with NEWSKIRT.
# Everything else (other prims, liner prims, skins, clips, textures) stays byte-identical. Fit: waist ring of the old skirt
# (top y, centre, width/depth), uniform height scale = mean waist scale * hs; yaw (+mirror) picked by the best match of the
# angular coverage profile between hip and knee (the slit stays where the shipped skirt has it). Weights: JOINTS/WEIGHTS 0+1
# copied from the nearest old skirt vertex in (arc length, height) space with height clamped to the old skirt's span per angle.
import sys,io,json,struct,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
from PIL import Image
base,new,out=sys.argv[1:4]; kv=dict(a.split('=') for a in sys.argv[4:]); f=lambda k,d: float(kv.get(k,d))
j,b=glbio.load(base); jn_,bn=glbio.load(new)
prim=next(p for p in j['meshes'][4]['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,prim['attributes'][k])
P0=A('POSITION'); F0=glbio.acc(j,b,prim['indices']).reshape(-1,3)
np_=jn_['meshes'][0]['primitives'][0]; N1=glbio.acc(jn_,bn,np_['attributes']['NORMAL']); P1=glbio.acc(jn_,bn,np_['attributes']['POSITION']); UV1=glbio.acc(jn_,bn,np_['attributes']['TEXCOORD_0']); F1=glbio.acc(jn_,bn,np_['indices']).reshape(-1,3)
def ring(P,band=0.03):
    t=P[:,1].max(); r=P[P[:,1]>t-band]; return t,r[:,0].mean(),r[:,2].mean(),np.ptp(r[:,0]),np.ptp(r[:,2])
t0,cx0,cz0,w0,d0=ring(P0); t1,cx1,cz1,w1,d1=ring(P1)
sx=w0/w1*f('ws',1); sz=d0/d1*f('ws',1); sy=(sx+sz)/2*f('hs',1)
if 'ymin' in kv: sy=(t0-f('ymin',0.3))/(t1-P1[:,1].min())
if 'wy' in kv:  # width fit in a band wy..wy+0.04 m below the waist top (after the vertical scale), x and z separately
    a0=P0[(P0[:,1]<t0-f('wy',0.04))&(P0[:,1]>t0-f('wy',0.04)-0.04)]; yy=(P1[:,1]-t1)*sy+t0
    a1=P1[(yy<t0-f('wy',0.04))&(yy>t0-f('wy',0.04)-0.04)]
    sx=np.ptp(a0[:,0])/np.ptp(a1[:,0])*f('ws',1); sz=np.ptp(a0[:,2])/np.ptp(a1[:,2])*f('ws',1)
    cx1,cz1=(a1[:,0].max()+a1[:,0].min())/2,(a1[:,2].max()+a1[:,2].min())/2; cx0,cz0=(a0[:,0].max()+a0[:,0].min())/2,(a0[:,2].max()+a0[:,2].min())/2
    print('width band: old w %.3f d %.3f'%(np.ptp(a0[:,0]),np.ptp(a0[:,2])))
Q=np.c_[(P1[:,0]-cx1)*sx,(P1[:,1]-t1)*sy+t0+f('dy',0),(P1[:,2]-cz1)*sz]
def cover(P,F,y0,y1,cx,cz,n=60000):
    rng=np.random.default_rng(0); fi=rng.integers(0,len(F),n); u=rng.random((n,2)); m=u.sum(1)>1; u[m]=1-u[m]
    X=P[F[fi,0]]+(P[F[fi,1]]-P[F[fi,0]])*u[:,:1]+(P[F[fi,2]]-P[F[fi,0]])*u[:,1:]
    s=(X[:,1]>y0)&(X[:,1]<y1); th=np.degrees(np.arctan2(X[s,0]-cx,X[s,2]-cz)); h,_=np.histogram(th,72,(-180,180)); return h/h.max()
c0=cover(P0,F0,f('cy0',0.62),f('cy1',0.88),cx0,cz0); best=None
for mir in (1,-1):
    for yaw in range(-40,41,5):
        a=np.radians(yaw); X=Q.copy(); X[:,0]=(Q[:,0])*mir
        R=np.c_[X[:,0]*np.cos(a)+X[:,2]*np.sin(a),X[:,1],-X[:,0]*np.sin(a)+X[:,2]*np.cos(a)]
        c1=cover(R+[cx0,0,cz0],F1,f('cy0',0.62),f('cy1',0.88),cx0,cz0); sc=np.corrcoef(c0,c1)[0,1]
        if best is None or sc>best[0]: best=(sc,mir,yaw,R)
if 'yaw' in kv: 
    mir=int(kv.get('mir',1)); a=np.radians(f('yaw',0)); X=Q.copy(); X[:,0]*=mir
    best=(0,mir,f('yaw',0),np.c_[X[:,0]*np.cos(a)+X[:,2]*np.sin(a),X[:,1],-X[:,0]*np.sin(a)+X[:,2]*np.cos(a)])
sc,mir,yaw,R=best
fl=f('fl',0); g=1+fl*np.clip((f('fy',0.85)-R[:,1])/(f('fy',0.85)-0.3),0,1); R=R*np.c_[g,np.ones_like(g),g]
P=R+[cx0,0,cz0]; print('fit sx %.3f sz %.3f sy %.3f  yaw %s mirror %s  coverage corr %.2f'%(sx,sz,sy,yaw,mir,sc))
N=N1.copy(); N[:,0]*=mir; a=np.radians(yaw); N=np.c_[N[:,0]*np.cos(a)+N[:,2]*np.sin(a),N[:,1],-N[:,0]*np.sin(a)+N[:,2]*np.cos(a)]
F=F1 if mir==1 else F1[:,[0,2,1]]
print('new skirt y %.3f..%.3f (old %.3f..%.3f), width %.2f (old %.2f), verts %d tris %d'%(P[:,1].min(),P[:,1].max(),P0[:,1].min(),P0[:,1].max(),np.ptp(P[:,0]),np.ptp(P0[:,0]),len(P),len(F)))
# weights: nearest old vertex in (arc, y) with y clamped to [old min y in that angular sector, top]
th0=np.arctan2(P0[:,0]-cx0,P0[:,2]-cz0); th=np.arctan2(P[:,0]-cx0,P[:,2]-cz0); rr=0.2
sec=((th0+np.pi)/(2*np.pi)*36).astype(int)%36; ymin=np.array([P0[sec==k,1].min() if (sec==k).any() else P0[:,1].min() for k in range(36)])
ys=np.maximum(P[:,1],ymin[((th+np.pi)/(2*np.pi)*36).astype(int)%36]+0.01)
from scipy.spatial import cKDTree
kd=cKDTree(np.c_[np.cos(th0)*rr,np.sin(th0)*rr,P0[:,1]]); _,nn=kd.query(np.c_[np.cos(th)*rr,np.sin(th)*rr,ys])
attrs={'POSITION':P.astype('<f4'),'NORMAL':(N/np.linalg.norm(N,axis=1,keepdims=True)).astype('<f4'),'TEXCOORD_0':UV1.astype('<f4')}
for k in ('JOINTS_0','JOINTS_1','WEIGHTS_0','WEIGHTS_1'):
    if k in prim['attributes']: attrs[k]=A(k)[nn]
CT={np.dtype('<f4'):5126,np.dtype('uint8'):5121,np.dtype('uint16'):5123,np.dtype('uint32'):5125}
def add(arr,typ,target=None,mm=False):
    global b
    arr=np.ascontiguousarray(arr); o=len(b); pad=(-o)%4; b+=b'\0'*pad; o=len(b); b+=arr.tobytes()
    bv={'buffer':0,'byteOffset':o,'byteLength':arr.nbytes}; 
    if target: bv['target']=target
    j['bufferViews'].append(bv); acc={'bufferView':len(j['bufferViews'])-1,'componentType':CT[arr.dtype],'count':len(arr),'type':typ}
    if mm: acc['min']=arr.min(0).tolist(); acc['max']=arr.max(0).tolist()
    j['accessors'].append(acc); return len(j['accessors'])-1
TY={1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}
for k,v in attrs.items(): prim['attributes'][k]=add(v,TY[v.shape[1]],34962,k=='POSITION')
prim['indices']=add(F.astype('<u4').ravel(),'SCALAR',34963)
# texture: new image + texture for skirt-meshy only
im=jn_['images'][jn_['textures'][jn_['materials'][np_['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
bv=jn_['bufferViews'][im['bufferView']]; o=bv.get('byteOffset',0); data=bytes(bn[o:o+bv['byteLength']])
if 'tex' in kv: data=open(kv['tex'],'rb').read()
o=len(b); b+=b'\0'*((-o)%4); o=len(b); b+=data; j['bufferViews'].append({'buffer':0,'byteOffset':o,'byteLength':len(data)})
j['images'].append({'bufferView':len(j['bufferViews'])-1,'mimeType':'image/jpeg' if data[:2]==b'\xff\xd8' else 'image/png','name':'skirt21'})
t8=j['materials'][prim['material']]['pbrMetallicRoughness']['baseColorTexture']['index']; t=dict(j['textures'][t8]); t['source']=len(j['images'])-1
j['textures'].append(t); j['materials'][prim['material']]['pbrMetallicRoughness']['baseColorTexture']['index']=len(j['textures'])-1
b+=b'\0'*((-len(b))%4); j['buffers'][0]['byteLength']=len(b)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
open(out,'wb').write(struct.pack('<III',0x46546C67,2,28+len(js)+len(b))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(b),0x004E4942)+bytes(b))
print('wrote',out)
