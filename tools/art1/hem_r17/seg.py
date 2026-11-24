import sys,io; sys.path.insert(0,'tools'); from glbio import *
from PIL import Image
def loadhand(p):
    j,b=load(p); pr=j['meshes'][0]['primitives'][0]; A=pr['attributes']
    P=acc(j,b,A['POSITION']).astype(float); UV=acc(j,b,A['TEXCOORD_0']); F=acc(j,b,pr['indices']).reshape(-1,3)
    Nm=acc(j,b,A['NORMAL']).astype(float)
    m=j['materials'][pr['material']]; ti=m['pbrMetallicRoughness']['baseColorTexture']['index']; im=j['textures'][ti]['source']
    bv=j['bufferViews'][j['images'][im]['bufferView']]; o=bv.get('byteOffset',0)
    I=Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB')
    # node transform (meshy root usually identity)
    return P,Nm,UV,F,I
def vcol(I,UV):
    A=np.asarray(I).astype(int); h,w,_=A.shape
    return A[(np.clip(UV[:,1],0,.999)*h).astype(int),(np.clip(UV[:,0],0,.999)*w).astype(int)]
if __name__=='__main__':
    P,Nm,UV,F,I=loadhand(sys.argv[1]); c=vcol(I,UV)
    red=(c[:,0]-c[:,1]>50)&(c[:,0]-c[:,2]>30)
    cream=(~red)&(c[:,0]-c[:,2]>18)&(c.mean(1)>140)
    print('verts',len(P),'bbox',P.min(0).round(3),P.max(0).round(3),'red',red.sum(),'cream',cream.sum(),'tex',I.size)
    Q=P[red]; cq=Q.mean(0); ax=np.linalg.svd(Q-cq,full_matrices=False)[2][0]; d=Q-cq; r=np.linalg.norm(d-np.outer(d@ax,ax),axis=1)
    print('handle c',cq.round(3),'ax',ax.round(3),'len',np.ptp(d@ax).round(3),'radius med',np.median(r).round(3))
    w=P[~red]; dw=w-cq; aw=dw@ax; rw=np.linalg.norm(dw-np.outer(aw,ax),axis=1)
    print('white span along axis',np.percentile(aw,[2,98]).round(3),'max radial',rw.max().round(3))
    if cream.any(): print('cream c',P[cream].mean(0).round(3),'dist to axis',np.linalg.norm((P[cream].mean(0)-cq)-((P[cream].mean(0)-cq)@ax)*ax).round(3))
