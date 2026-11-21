# Cutout v2 (owner 11-09: Bokidex heroes showed old/pixelated art).
# Source = the CURRENT card (flat light background). Soft alpha from colour distance
# inside the edge-connected background region, computed at full res -> no pixel fringe.
import numpy as np, cv2, sys, os, json
from PIL import Image
def cutout(im, lo=10, hi=42):
    a=np.array(im.convert('RGB')).astype(np.float32); h,w=a.shape[:2]
    border=np.concatenate([a[:4].reshape(-1,3),a[-4:].reshape(-1,3),a[:,:4].reshape(-1,3),a[:,-4:].reshape(-1,3)])
    bg=np.median(border,0); diff=np.abs(a-bg).sum(2)
    cand=(diff<hi).astype(np.uint8)
    n,lab=cv2.connectedComponents(cand,connectivity=4)
    edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    sizes=np.bincount(lab.ravel())
    keep=list(edge)+[i for i in range(1,n) if i not in edge and sizes[i]>0.003*h*w and diff[lab==i].mean()<lo*1.5]
    region=np.isin(lab,keep)
    alpha=np.ones((h,w),np.float32)
    soft=np.clip((diff-lo)/(hi-lo),0,1)
    alpha[region]=soft[region]
    alpha=cv2.GaussianBlur(alpha,(0,0),0.8)
    # de-matte: remove background colour bleed from semi-transparent pixels
    A=np.clip(alpha,1e-3,1)[...,None]; rgb=np.clip((a-bg*(1-A))/A,0,255)
    rgb=np.where(alpha[...,None]>0.02,rgb,a)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8),(alpha*255).astype(np.uint8)]),'RGBA')
def frame(rgba,size=1024,fill=0.9):
    bb=rgba.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox(); c=rgba.crop(bb); s=fill*size/max(c.size)
    c=c.resize((max(1,int(c.width*s)),max(1,int(c.height*s))),Image.LANCZOS)
    o=Image.new('RGBA',(size,size),(0,0,0,0)); o.alpha_composite(c,((size-c.width)//2,(size-c.height)//2)); return o
if __name__=='__main__':
    m=json.load(open('briefs/boki-art/LIVE_MANIFEST.json')); out='briefs/boki-art/portraits/cutout_v2'; os.makedirs(out,exist_ok=True); done=0
    for n,e in m.items():
        if not isinstance(e,dict) or not e.get('card') or not os.path.exists(e['card']): continue
        frame(cutout(Image.open(e['card']))).save(f'{out}/{n}.png',optimize=True); done+=1
    print(done,'cutouts')
