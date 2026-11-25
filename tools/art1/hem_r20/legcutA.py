"""legcutA.py GLB OUT.npz [y0 y1]: legs-only Meshy part (r20 m/A): keep faces with all verts in y0..y1 (boot top-5cm .. mid-thigh)."""
import sys; sys.path.insert(0, __file__.rsplit('/',1)[0])
from glbio import *
j,b=load(sys.argv[1]); p=j['meshes'][0]['primitives'][0]
P=acc(j,b,p['attributes']['POSITION']); I=acc(j,b,p['indices']).reshape(-1,3)
y0,y1=(float(sys.argv[3]),float(sys.argv[4])) if len(sys.argv)>4 else (-0.27,0.44)
inb=(P[:,1]>y0)&(P[:,1]<y1); fm=inb[I].all(1) & ((P[I,0]>0).all(1)|(P[I,0]<0).all(1))
print('faces',fm.sum(),'of',len(I)); np.savez(sys.argv[2],fm=fm)
