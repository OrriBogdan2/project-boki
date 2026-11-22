"""Remove a faded ghost row above the real four views of a sheet. topclean(img)->(img,cut_y or None)."""
import numpy as np
from PIL import Image
from scipy.ndimage import uniform_filter1d
def topclean(im):
    a=np.asarray(im.convert('RGB')).astype(int); H,W=a.shape[:2]
    bg=np.median(np.concatenate([a[:,:8].reshape(-1,3),a[:,-8:].reshape(-1,3)]),axis=0)
    fg=np.abs(a-bg).sum(2)>36
    c=uniform_filter1d(fg.mean(1),max(3,H//200))
    ys=np.where(c>0.02)[0]
    if len(ys)==0: return im,None
    # main band: grow from the densest row
    pk=int(np.argmax(uniform_filter1d(fg.mean(1),H//8)))
    y=pk
    while y>0 and c[y]>0.012: y-=1
    if y<=H*0.02 or fg[:y].mean()<0.002: return im,None   # nothing above the gap
    out=a.copy(); out[:y]=bg
    # soften: also clear faint haze just above the cut
    return Image.fromarray(out.astype(np.uint8)),y
if __name__=='__main__':
    import sys
    for p in sys.argv[1:]:
        im,y=topclean(Image.open(p)); print(p,y)
        if y: im.save(p,quality=93)
