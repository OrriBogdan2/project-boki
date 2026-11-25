# legfollow21.py IN OUT [hmax=0.6 front=1.0 back=0.3 lat=25 pw=1.3 ytop=0.95 ybot=0.45] : numpy port of hem_r10/legfollow.py
# (weights only, written in place: no Blender re-export). Skirt-meshy vert share w of Left/RightUpLeg (split by side with a
# logistic of x about the leg midline), w = hmax * smoothstep((ytop-y)/(ytop-ybot))^pw * facing(front..back); others scaled by 1-w.
import sys,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); F=lambda k,d: float(O.get(k,d))
j,b=glbio.load(src); p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION')
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
jn=[j['nodes'][k]['name'] for k in j['skins'][0]['joints']]; iL,iR=jn.index('LeftUpLeg'),jn.index('RightUpLeg')
ib=glbio.acc(j,b,j['skins'][0]['inverseBindMatrices']).reshape(-1,4,4); xL=np.linalg.inv(ib[iL].T)[0,3]; xR=np.linalg.inv(ib[iR].T)[0,3]; xm=(xL+xR)/2
t=np.clip((F('ytop',0.95)-P[:,1])/(F('ytop',0.95)-F('ybot',0.45)),0,1); s=t*t*(3-2*t)
cz=P[:,2].mean(); th=np.arctan2(P[:,0]-xm,P[:,2]-cz); fac=F('back',0.3)+(F('front',1.0)-F('back',0.3))*(np.cos(th)+1)/2
w=F('hmax',0.6)*s**F('pw',1.3)*fac; left=1/(1+np.exp(-(P[:,0]-xm)*F('lat',25)*np.sign(xL-xR)))
n=len(P); nJ=max(J.max(),iL,iR)+1; D=np.zeros((n,nJ)); np.add.at(D,(np.repeat(np.arange(n),8),J.ravel()),W.ravel())
D*=(1-w)[:,None]; D[:,iL]+=w*left; D[:,iR]+=w*(1-left)
idx=np.argsort(-D,1)[:,:8]; ww=np.take_along_axis(D,idx,1); ww/=ww.sum(1,keepdims=True)
def put(k,arr):
    a=j['accessors'][p['attributes'][k]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,p['attributes'][k],arr.astype(dt))
put('JOINTS_0',idx[:,:4]); put('JOINTS_1',idx[:,4:]); put('WEIGHTS_0',ww[:,:4]); put('WEIGHTS_1',ww[:,4:])
glbio.save(out,j,b); print('legfollow: mean w %.3f max %.3f, verts w>0.2: %d ->'%(w.mean(),w.max(),(w>0.2).sum()),out)
