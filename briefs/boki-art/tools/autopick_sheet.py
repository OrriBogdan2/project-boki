"""Pick the cleanest of N rendered sheets automatically: python3 briefs/boki-art/tools/autopick_sheet.py job_id [runs]  -> prints the best run number.
A clean sheet has exactly four big shapes on one row, nothing above or below the row, nothing touching the top or bottom edge. Lowest penalty wins.
This is a screen, not a review: it cannot see wrong colours or a view that disagrees with the others."""
import sys,os,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); import bload
from scipy import ndimage
def score(stem):
    im=bload.load(stem); im.thumbnail((1000,1000)); a=np.asarray(im).astype(int)
    bg=np.median(np.concatenate([a[:8,:8],a[:8,-8:],a[-8:,:8],a[-8:,-8:]]).reshape(-1,3),axis=0)
    fg=ndimage.binary_closing(np.abs(a-bg).max(2)>14,iterations=2); lab,k=ndimage.label(fg)
    if k==0: return 99
    sz=ndimage.sum(fg,lab,range(1,k+1)); order=np.argsort(sz)[::-1]; big=[i for i in order if sz[i]>=0.25*sz[order[0]]]
    sl=ndimage.find_objects(lab); top=order[:4]; y0=min(sl[i][0].start for i in top); y1=max(sl[i][0].stop for i in top)
    cy=ndimage.center_of_mass(fg,lab,range(1,k+1)); off=sum(sz[i] for i in range(k) if i not in top and not (y0<=cy[i][0]<=y1))
    return abs(len(big)-4)*10+(5 if off>60 else 0)+(3 if (fg[0].any() or fg[-1].any()) else 0)
def best(job,runs=3):
    sc=[(score(f'{job}_{k}'),k) for k in range(1,runs+1)]; return min(sc)
if __name__=='__main__':
    p,k=best(sys.argv[1],int(sys.argv[2]) if len(sys.argv)>2 else 3); print(k,'penalty',p)
