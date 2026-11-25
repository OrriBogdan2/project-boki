# probe: dark texels under faces of a material in a rest-pose height band
import sys,io;sys.path.insert(0,'.');from glbio import *
from PIL import Image
G=sys.argv[1]
j,b=load(G)
def img(ti):
    im=j['images'][j['textures'][ti]['source']];bv=j['bufferViews'][im['bufferView']];o=bv.get('byteOffset',0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB')).astype(float)
for mi,pi in [(1,2),(4,2),(4,0),(4,1)]:
    p=j['meshes'][mi]['primitives'][pi];mat=j['materials'][p['material']]
    T=img(mat['pbrMetallicRoughness']['baseColorTexture']['index']);H,W,_=T.shape
    P=acc(j,b,p['attributes']['POSITION']);UV=acc(j,b,p['attributes']['TEXCOORD_0']);F=acc(j,b,p['indices']).reshape(-1,3)
    c=P[F].mean(1);uv=UV[F].mean(1)
    sel=(c[:,1]>0.45)&(c[:,1]<1.0)
    px=np.clip((uv[:,0]%1)*W,0,W-1).astype(int);py=np.clip((uv[:,1]%1)*H,0,H-1).astype(int)
    col=T[py,px];lum=col.mean(1)
    s=sel; print(mat['name'],'faces',s.sum(),'y-range',P[:,1].min().round(2),P[:,1].max().round(2),'dark<60',(lum[s]<60).sum(),'mid60-150',((lum[s]>=60)&(lum[s]<150)).sum(),'uv unique',len(np.unique(np.round(UV,3),axis=0)))
p=j['meshes'][1]['primitives'][2];T=img(6);H,W,_=T.shape
P=acc(j,b,p['attributes']['POSITION']);UV=acc(j,b,p['attributes']['TEXCOORD_0']);F=acc(j,b,p['indices']).reshape(-1,3)
c=P[F].mean(1);uv=UV[F].mean(1);px=np.clip((uv[:,0]%1)*W,0,W-1).astype(int);py=np.clip((uv[:,1]%1)*H,0,H-1).astype(int);lum=T[py,px].mean(1)
print('x range',c[:,0].min().round(2),c[:,0].max().round(2),'z',c[:,2].min().round(2),c[:,2].max().round(2))
for y0 in np.arange(0.3,1.05,0.05):
    s=(c[:,1]>=y0)&(c[:,1]<y0+0.05)&(np.abs(c[:,0])<0.25)
    print(round(y0,2),s.sum(),'dark',(lum[s]<60).sum(),'L(x>0)dark',((lum<60)&s&(c[:,0]>0)).sum(),'R dark',((lum<60)&s&(c[:,0]<0)).sum())
