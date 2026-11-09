# Portrait cut-out + two Bokidex styles (owner 22:47: "both").
# cutout(): flood-fill the flat background from the edges -> transparent PNG.
# light(): creature on flat light grey. dark(): creature on the website's dark navy card with a soft glow.
import numpy as np, cv2, sys, os
from PIL import Image, ImageFilter
def cutout(im, tol=38):
    # tol: colour distance to the edge background; dark sources with a glow need a larger tol
    a=np.array(im.convert('RGB')).astype(np.int16); h,w=a.shape[:2]
    border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]]); bg=np.median(border,0)
    diff=np.abs(a-bg).sum(2); cand=(diff<tol).astype(np.uint8)
    n,lab=cv2.connectedComponents(cand,connectivity=4)
    edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bgmask=np.isin(lab,list(edge))
    # enclosed background holes (inside tail loops etc.): large bg-coloured pockets not touching the edge
    sizes=np.bincount(lab.ravel())
    holes=[i for i in range(1,n) if i not in edge and sizes[i]>0.002*h*w]
    if holes: bgmask|=np.isin(lab,holes)
    alpha=(~bgmask).astype(np.uint8)*255
    alpha=cv2.morphologyEx(alpha,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
    alpha=cv2.GaussianBlur(alpha,(3,3),0)
    out=np.dstack([a.astype(np.uint8),alpha]); return Image.fromarray(out,'RGBA')
def frame(rgba, size=2048, fill=0.86):
    bb=rgba.getbbox(); c=rgba.crop(bb); s=fill*size/max(c.size)
    c=c.resize((max(1,int(c.width*s)),max(1,int(c.height*s))),Image.LANCZOS)
    o=Image.new('RGBA',(size,size),(0,0,0,0)); o.alpha_composite(c,((size-c.width)//2,(size-c.height)//2)); return o
def light(fr):
    o=Image.new('RGBA',fr.size,(242,242,244,255)); o.alpha_composite(fr); return o.convert('RGB')
def dark(fr):
    s=fr.size[0]; y,x=np.mgrid[0:s,0:s]; r=np.sqrt((x-s/2)**2+(y-s*0.45)**2)/(s*0.62)
    base=np.array([18,22,38]); glow=np.array([44,52,78]); t=np.clip(1-r,0,1)[...,None]**1.6
    bg=(base+(glow-base)*t).astype(np.uint8); o=Image.fromarray(bg,'RGB').convert('RGBA'); o.alpha_composite(fr); return o.convert('RGB')
def make_all(src, name, outdir):
    fr=frame(cutout(Image.open(src)))
    os.makedirs(outdir+'/cutout',exist_ok=True); os.makedirs(outdir+'/light',exist_ok=True); os.makedirs(outdir+'/dark',exist_ok=True)
    fr.save(f'{outdir}/cutout/{name}.png'); light(fr).save(f'{outdir}/light/{name}.jpg',quality=92); dark(fr).save(f'{outdir}/dark/{name}.jpg',quality=92)
if __name__=='__main__':
    make_all(sys.argv[1],sys.argv[2],sys.argv[3])
