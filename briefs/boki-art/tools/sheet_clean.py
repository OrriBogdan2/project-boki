"""Remove stray blobs above/below the row of views on a turnaround sheet (run from the repo root):
python3 briefs/boki-art/tools/sheet_clean.py [--dry] Name ...   -> rewrites the live sheet only if something was removed, prints what.
The row = the vertical span of the biggest shape. Anything whose centre lies outside that span goes (ghost rows, cut-off feet, smears).
Parts beside a view inside the span (pebbles, rings, sparks) are kept."""
import sys,json,numpy as np
from PIL import Image
from scipy import ndimage
m=json.load(open('briefs/boki-art/LIVE_MANIFEST.json')); DRY='--dry' in sys.argv
for n in [x for x in sys.argv[1:] if not x.startswith('--')]:
    f=m[n]['sheet']; a=np.asarray(Image.open(f).convert('RGB')).astype(int)
    bg=np.median(np.concatenate([a[:16,:16],a[:16,-16:],a[-16:,:16],a[-16:,-16:]]).reshape(-1,3),axis=0)
    fg=ndimage.binary_closing(np.abs(a-bg).max(2)>14,iterations=2); lab,k=ndimage.label(fg)
    if k<=1: continue
    sz=ndimage.sum(fg,lab,range(1,k+1)); sl=ndimage.find_objects(lab); b=int(np.argmax(sz))
    # row span: union of the spans of every shape at least 40% as big as the biggest and overlapping it vertically
    y0,y1=sl[b][0].start,sl[b][0].stop
    for i in range(k):
        if sz[i]>=0.4*sz[b] and sl[i][0].start<y1 and sl[i][0].stop>y0: y0=min(y0,sl[i][0].start); y1=max(y1,sl[i][0].stop)
    cy=ndimage.center_of_mass(fg,lab,range(1,k+1))
    bad=[i+1 for i in range(k) if not (y0<=cy[i][0]<=y1)]
    px=int(sum(sz[i-1] for i in bad))
    if px<400: continue
    print(n,'removed' if not DRY else 'would remove',len(bad),'blobs',px,'px')
    if DRY: continue
    good=np.isin(lab,[i+1 for i in range(k) if (i+1) not in bad])
    kill=ndimage.binary_dilation(np.isin(lab,bad),iterations=10)&~ndimage.binary_dilation(good,iterations=3)
    out=a.copy(); out[kill]=bg.astype(int); Image.fromarray(out.astype('uint8')).save(f,quality=93)
