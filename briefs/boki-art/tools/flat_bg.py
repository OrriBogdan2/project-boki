"""Flatten a shaded card backdrop to plain #E8E8EE (run from the repo root): python3 briefs/boki-art/tools/flat_bg.py Name ...
Use when the hero cut-out (portraits/cutout_v2) shows grey bands or a box. Works row by row, so gradients go too; keeps detached parts
(rings, pebbles) bigger than a speck. Then run refresh_names.py for the same names."""
import sys,numpy as np
from PIL import Image
from scipy import ndimage
NOFILL="--nofill" in sys.argv  # use for Boki with an open ring or loop, so the background inside it is cleared too
for n in [x for x in sys.argv[1:] if not x.startswith("--")]:
    f=f'briefs/boki-art/cards/{n}.jpg'; a=np.asarray(Image.open(f).convert('RGB')).astype(np.float32); h,w=a.shape[:2]
    rowbg=np.median(np.concatenate([a[:,:40],a[:,-40:]],axis=1),axis=1)[:,None,:]
    fg=ndimage.binary_opening(np.abs(a-rowbg).max(2)>26,iterations=2); lab,k=ndimage.label(fg); sz=ndimage.sum(fg,lab,range(1,k+1))
    keep=np.isin(lab,[i+1 for i,s in enumerate(sz) if s>=0.0004*h*w]); keep=ndimage.binary_dilation(keep,iterations=3)
    if not NOFILL: keep=ndimage.binary_fill_holes(keep)
    al=ndimage.gaussian_filter(keep.astype(np.float32),1.2)[...,None]
    Image.fromarray((a*al+np.array([232,232,238],np.float32)*(1-al)).clip(0,255).astype('uint8')).save(f,quality=93); print(n,'kept',round(float(keep.mean()),3))
