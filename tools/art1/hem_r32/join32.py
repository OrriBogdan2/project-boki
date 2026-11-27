# join32.py IN OUT [R=0.05 y0=0.62 y1=0.74] : Lace r32 rig-only "keep the skirt in one piece above mid-thigh" (r30/r31 review:
# the slit opens to the hip and the skirt parts into front/back flaps in dash/jump). The two slit edges near the top carry
# different joints (front edge RightUpLeg+SlitA, back edge Hips+SlitB), so a lifted thigh drags them apart. Each outer-skirt
# vertex's 8 weights are replaced by the mean weight vector of all outer-skirt verts within R (3D ball, rest pose, crossing the
# narrow top of the slit gap and stacked panels), blended in by height: 0 below y0, full above y1 (smoothstep). Below y0 (the
# knee window, kneefollow r28) nothing changes. The lining shares these accessors. Mesh, textures and clips untouched.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial import cKDTree
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); f=lambda k,d: float(O.get(k,d))
R,y0,y1=f('R',0.05),f('y0',0.62),f('y1',0.74)
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names; b=bytearray(bytes(b))
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='cloth-skirtmeshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
n=len(P); D=np.zeros((n,len(jn))); np.add.at(D,(np.repeat(np.arange(n),8),J.ravel()),W.ravel()); D/=D.sum(1,keepdims=True)
t=np.clip((P[:,1]-y0)/(y1-y0),0,1); t=t*t*(3-2*t); sel=np.where(t>0)[0]
tr=cKDTree(P); nb=tr.query_ball_point(P[sel],R); M=np.array([D[x].mean(0) for x in nb])
D2=D.copy(); D2[sel]=(1-t[sel,None])*D[sel]+t[sel,None]*M
o=np.argsort(-D2,1)[:,:8]; ww=np.take_along_axis(D2,o,1); ww/=ww.sum(1,keepdims=True)
lost=1-np.take_along_axis(D2,o,1).sum(1); print('join32: R %.3f y %.2f-%.2f verts %d, mean |dw| %.3f, max weight lost to 8-cap %.3f'%(R,y0,y1,len(sel),np.abs(D2-D)[sel].sum(1).mean(),lost.max()))
for k_,arr in (('JOINTS_0',o[:,:4]),('JOINTS_1',o[:,4:]),('WEIGHTS_0',ww[:,:4]),('WEIGHTS_1',ww[:,4:])):
    a=j['accessors'][p['attributes'][k_]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,p['attributes'][k_],arr.astype(dt))
glbio.save(out,j,b); print('wrote',out)
