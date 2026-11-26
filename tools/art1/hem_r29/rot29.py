# rot29.py IN OUT [deg=22] : Lace r29. The slit was cut at -40 deg (her right side), but her right knee swings forward at about
# -15..-20 deg, so every run/jump/dash pushed the knee into the panel beside the slit (r14-r28 fought that with keys/weights).
# The turnaround has the slit straight in front of her right leg. This turns the skirt shell (skirt-meshy + its lining prim, shared
# accessors) by `deg` about the hip axis (POSITION + NORMAL; UV/colour travel with the vertex). Weights stay fixed IN SPACE
# (each turned vertex takes the old weights at its new spot: thigh split, knee-follow, sway bones keep their places), except
# the slit joints (SkirtSlitA/B), whose share travels with the vertex so the slit edges keep their own joints.
# mix=M (default 1): share of the in-space weights; 0 = weights turn with the vertex (rigid).
# Run on the kneefollow output, BEFORE gusset.py (give gusset gapc=-40+deg). Body, clips, textures, other prims untouched.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial import cKDTree
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); deg=float(O.get('deg',22)); kn=int(O.get('k',4))
j,b=glbio.load(src); b=bytearray(bytes(b)); rig=g.Rig(j,b); jn=rig.names
S0=rig.skin_mats(None,np.zeros(1))[0]; hc=(S0@np.linalg.inv(rig.ibm))[jn.index('Hips')][:3,3]
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k])
P=A('POSITION').astype(float); N=A('NORMAL').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
n=len(P); D=np.zeros((n,len(jn))); np.add.at(D,(np.repeat(np.arange(n),8),J.ravel()),W.ravel())
t=np.radians(deg); c,s=np.cos(t),np.sin(t); R=np.array([[c,0,s],[0,1,0],[-s,0,c]])   # atan2(x,z) grows by deg
Q=(P-hc)@R.T+hc; Nq=N@R.T
ang=lambda X: np.degrees(np.arctan2(X[:,0]-hc[0],X[:,2]-hc[2]))
print('check: mean angle shift %.1f deg'%np.median(((ang(Q)-ang(P))+180)%360-180))
sl=[jn.index(x) for x in ('SkirtSlitA','SkirtSlitB')]
d,i=cKDTree(P).query(Q,k=kn); w=1/np.maximum(d,1e-4); w/=w.sum(1,keepdims=True)
Ds=(D[i]*w[...,None]).sum(1)                                     # old weights at the new spot
mix=float(O.get('mix',1.0))                                      # mix<1: blend toward the vertex's own (rigid) weights
Ds=mix*Ds+(1-mix)*D
own=D[:,sl].sum(1); Ds[:,sl]=0; Ds/=np.maximum(Ds.sum(1,keepdims=True),1e-9); Ds*=(1-own)[:,None]; Ds[:,sl]=D[:,sl]
o=np.argsort(-Ds,1)[:,:8]; ww=np.take_along_axis(Ds,o,1); ww/=ww.sum(1,keepdims=True)
print('slit-joint verts %d (share>0.05); mean nn dist %.4f m'%((own>0.05).sum(),d[:,0].mean()))
for k_,arr in (('POSITION',Q),('NORMAL',Nq),('JOINTS_0',o[:,:4]),('JOINTS_1',o[:,4:]),('WEIGHTS_0',ww[:,:4]),('WEIGHTS_1',ww[:,4:])):
    a=j['accessors'][p['attributes'][k_]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]
    if k_=='POSITION': a['min']=arr.min(0).tolist(); a['max']=arr.max(0).tolist()
    glbio.put(j,b,p['attributes'][k_],arr.astype(dt))
glbio.save(out,j,b); print('wrote',out)
