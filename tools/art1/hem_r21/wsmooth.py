# wsmooth.py IN OUT iters alpha [keep_top_m=0.03] : Laplacian smoothing of the skirt-meshy prim's skin weights (8 influences,
# JOINTS_0/1 + WEIGHTS_0/1) over the welded mesh graph; verts within keep_top_m of the waist top stay fixed. Positions untouched.
import sys,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
from scipy.sparse import coo_matrix,diags
src,out,it,al=sys.argv[1],sys.argv[2],int(sys.argv[3]),float(sys.argv[4]); keep=float(sys.argv[5]) if len(sys.argv)>5 else 0.03
j,b=glbio.load(src); p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION'); F=glbio.acc(j,b,p['indices']).reshape(-1,3)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
nJ=J.max()+1; n=len(P); D=np.zeros((n,nJ)); np.add.at(D,(np.repeat(np.arange(n),8),J.ravel()),W.ravel())
_,inv=np.unique(np.round(P/1e-4).astype(np.int64),axis=0,return_inverse=True); inv=inv.ravel(); m=inv.max()+1
G=F.ravel(); r=np.r_[G,inv]; c=np.r_[inv[G],np.arange(n)]  # vert -> welded id rows (both ways) via face edges
E=np.c_[F[:,[0,1]].T.ravel(),F[:,[1,2]].T.ravel()]; e=np.r_[np.c_[F[:,0],F[:,1]],np.c_[F[:,1],F[:,2]],np.c_[F[:,2],F[:,0]]]
a=inv[e[:,0]]; bb=inv[e[:,1]]; Adj=coo_matrix((np.ones(2*len(a)),(np.r_[a,bb],np.r_[bb,a])),shape=(m,m)).tocsr(); Adj.data[:]=1
deg=np.asarray(Adj.sum(1)).ravel(); deg[deg==0]=1
# welded weights = mean over duplicates
cnt=np.bincount(inv,minlength=m).astype(float); Wd=np.zeros((m,nJ)); np.add.at(Wd,inv,D); Wd/=cnt[:,None]
fix=np.zeros(m,bool); fix[inv[P[:,1]>P[:,1].max()-keep]]=True
for _ in range(it):
    L=diags(1/deg)@Adj@Wd; Wd[~fix]=(1-al)*Wd[~fix]+al*L[~fix]
D=Wd[inv]; idx=np.argsort(-D,1)[:,:8]; w=np.take_along_axis(D,idx,1); w/=w.sum(1,keepdims=True)
print('max weight change',np.abs(D-np.zeros_like(D)).max().round(3))
def put(k,arr):
    a=j['accessors'][p['attributes'][k]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,p['attributes'][k],arr.astype(dt))
put('JOINTS_0',idx[:,:4]); put('JOINTS_1',idx[:,4:]); put('WEIGHTS_0',w[:,:4]); put('WEIGHTS_1',w[:,4:])
glbio.save(out,j,b)
print('wrote',out)
