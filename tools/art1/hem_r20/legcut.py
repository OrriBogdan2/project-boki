"""legcut.py BGLB OUT.npz [r0=0.068 r1=0.095 y0=-0.34 y1=0.38 k=1.10]: pick Meshy B's two legs (crotch to 4 cm inside the boot) by a per-height cylinder
around each leg's centre line (measured on B's porcelain verts); keeps all faces with 3 verts inside. Writes face mask + stats."""
import sys; sys.path.insert(0, __file__.rsplit('/',1)[0])
from glbio import *
O=dict(a.split('=') for a in sys.argv[3:]); F=lambda k,d: float(O.get(k,d))
j,b=load(sys.argv[1]); p=j['meshes'][0]['primitives'][0]
P=acc(j,b,p['attributes']['POSITION']); I=acc(j,b,p['indices']).reshape(-1,3)
y=P[:,1]; Y0,Y1=F('y0',-0.34),F('y1',0.38)
t=np.clip((y+0.05)/0.40,0,1)
R=(F('r0',0.068)+(F('r1',0.095)-F('r0',0.068))*t)*np.where(y<0,F('kl',1.0),F('k',1.08))
inside=np.zeros(len(P),bool)
for s in (1,-1):
    cx=s*(0.087+np.clip(y+0.05,0,None)*0.05); cz=np.where(y<-0.18,0.05-np.clip(-0.18-y,0,None)*0.3,0.052)
    d=np.hypot(P[:,0]-cx,P[:,2]-cz)
    inside|= (d<R)&(y>Y0)&(y<Y1)&(P[:,0]*s>0.004)
fm=inside[I].all(1)
print('faces',fm.sum(),'of',len(I))
np.savez(sys.argv[2],fm=fm)
