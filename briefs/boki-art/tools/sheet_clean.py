"""Remove stray blobs above/below the row of views on a turnaround sheet (run from the repo root):
python3 briefs/boki-art/tools/sheet_clean.py Name ...   -> rewrites the live sheet only if something was removed, prints what.
Keeps the four biggest shapes and anything whose centre lies inside their vertical span (pebbles, rings, sparks beside a view)."""
import sys,json,numpy as np
from PIL import Image
from scipy import ndimage
m=json.load(open('briefs/boki-art/LIVE_MANIFEST.json'))
for n in sys.argv[1:]:
    f=m[n]['sheet']; a=np.asarray(Image.open(f).convert('RGB')).astype(int)
    bg=np.median(np.concatenate([a[:16,:16],a[:16,-16:],a[-16:,:16],a[-16:,-16:]]).reshape(-1,3),axis=0)
    fg=ndimage.binary_closing(np.abs(a-bg).max(2)>14,iterations=2); lab,k=ndimage.label(fg)
    if k<=4: continue
    sz=ndimage.sum(fg,lab,range(1,k+1)); top=np.argsort(sz)[::-1][:4]+1
    sl=ndimage.find_objects(lab); y0=min(sl[i-1][0].start for i in top); y1=max(sl[i-1][0].stop for i in top)
    cy=ndimage.center_of_mass(fg,lab,range(1,k+1))
    bad=[i+1 for i in range(k) if (i+1) not in top and not (y0<=cy[i][0]<=y1)]
    px=int(sum(sz[i-1] for i in bad))
    if px<400: continue
    kill=ndimage.binary_dilation(np.isin(lab,bad),iterations=10)&~ndimage.binary_dilation(np.isin(lab,list(top)),iterations=3)
    out=a.copy(); out[kill]=bg.astype(int); Image.fromarray(out.astype('uint8')).save(f,quality=93); print(n,'removed',len(bad),'blobs',px,'px')
