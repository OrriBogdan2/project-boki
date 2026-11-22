# Remove floating bits (anchor bleed, stray effects) from a single-creature image: keep the largest foreground blob
# (plus anything touching it), paint everything else with the background colour.
import numpy as np
from PIL import Image
from scipy import ndimage
def declutter(im,thr=22,grow=6,min_keep_frac=0.0):
    a=np.asarray(im.convert('RGB')).astype(int)
    bg=np.median(np.concatenate([a[:16,:16],a[:16,-16:],a[-16:,:16],a[-16:,-16:]]).reshape(-1,3),axis=0)
    fg=np.abs(a-bg).max(axis=2)>thr
    fg=ndimage.binary_closing(fg,iterations=2)
    lab,n=ndimage.label(fg)
    if n<=1: return im,0
    sizes=ndimage.sum(fg,lab,range(1,n+1)); big=int(np.argmax(sizes))+1
    keep=ndimage.binary_dilation(lab==big,iterations=grow)
    out=a.copy(); kill=~keep
    out[kill]=bg.astype(int)
    removed=int((fg&kill).sum())
    return Image.fromarray(out.clip(0,255).astype('uint8')),removed
if __name__=='__main__':
    import sys
    im,r=declutter(Image.open(sys.argv[1])); im.save(sys.argv[2],quality=92); print('removed px',r)
